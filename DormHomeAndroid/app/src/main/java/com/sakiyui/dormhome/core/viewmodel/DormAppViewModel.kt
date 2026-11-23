package com.sakiyui.dormhome.core.viewmodel

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.sakiyui.dormhome.core.modules.DormServiceModule
import com.sakiyui.dormhome.core.modules.ServiceModuleKind
import com.sakiyui.dormhome.core.network.DoorAction
import com.sakiyui.dormhome.core.network.DoorDevice
import com.sakiyui.dormhome.core.network.SWAEBuilding
import com.sakiyui.dormhome.core.network.SWAEClient
import com.sakiyui.dormhome.core.network.SWAEConfig
import com.sakiyui.dormhome.core.network.SWAEFloor
import com.sakiyui.dormhome.core.network.SWAERoomOption
import com.sakiyui.dormhome.core.network.SWAERoomSummary
import com.sakiyui.dormhome.core.network.SWAEZone
import com.sakiyui.dormhome.core.network.UnlockChannel
import com.sakiyui.dormhome.core.network.UnlockRecord
import com.sakiyui.dormhome.core.network.UtilityRoomName
import com.sakiyui.dormhome.core.network.WMXYClient
import com.sakiyui.dormhome.core.network.WMXYError
import com.sakiyui.dormhome.core.network.WMXYLoginResult
import com.sakiyui.dormhome.core.storage.DormStore
import com.sakiyui.dormhome.core.storage.PersistedState
import com.sakiyui.dormhome.core.storage.ThemeMode
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.util.UUID

enum class AppTab(val title: String) {
    HOME("首页"),
    LIFE("生活"),
    SETTINGS("设置")
}

enum class DoorVisualState {
    LOCKED,
    UNLOCKING,
    UNLOCKED
}

enum class ToastStyle {
    SUCCESS,
    INFO,
    ERROR
}

data class ToastMessage(
    val id: String = UUID.randomUUID().toString(),
    val message: String,
    val style: ToastStyle
)

data class AppUiState(
    val selectedTab: AppTab = AppTab.HOME,
    val doorState: DoorVisualState = DoorVisualState.LOCKED,
    val selectedDeviceId: String? = null,
    val isBusy: Boolean = false,
    val isRefreshing: Boolean = false,
    val unlockCountdown: Int? = null,
    val showLogin: Boolean = false,
    val loginNotice: String? = null,
    val toast: ToastMessage? = null,
    val lastOperationText: String? = null,
    val isUtilitiesLoading: Boolean = false,
    val utilitiesError: String? = null,
    val utilityConfig: SWAEConfig? = null
)

class DormAppViewModel(application: Application) : AndroidViewModel(application) {

    val store = DormStore(application.applicationContext)
    val persistedState: StateFlow<PersistedState> = store.state

    private val client = WMXYClient()
    private val swae = SWAEClient()

    private val _ui = MutableStateFlow(
        AppUiState(selectedDeviceId = store.current.activeDevices.firstOrNull()?.deviceId)
    )
    val ui: StateFlow<AppUiState> = _ui.asStateFlow()

    private var isSessionReady = false
    private var relockJob: Job? = null
    private var toastJob: Job? = null

    init {
        if (store.current.isLoggedIn && !store.current.outid.isNullOrEmpty()) {
            scheduleUtilitiesRefresh()
        }
    }

    fun selectTab(tab: AppTab) {
        _ui.update { it.copy(selectedTab = tab) }
    }

    fun selectedDevice(persisted: PersistedState = store.current): DoorDevice? {
        val selId = _ui.value.selectedDeviceId
        if (selId != null) {
            persisted.activeDevices.firstOrNull { it.deviceId == selId }?.let { return it }
        }
        return persisted.activeDevices.firstOrNull()
    }

    // MARK: - 开锁 / 上锁

    fun toggleDoor() {
        if (_ui.value.doorState == DoorVisualState.UNLOCKED) {
            lock(auto = false)
        } else {
            unlock()
        }
    }

    fun unlock() {
        val curUi = _ui.value
        if (curUi.isBusy || curUi.doorState == DoorVisualState.UNLOCKING) return

        val persisted = store.current
        if (!persisted.isLoggedIn && !persisted.isDemoMode) {
            openLogin()
            return
        }
        val device = selectedDevice(persisted)
        if (device == null) {
            showToast("未找到可用门锁，请尝试刷新", ToastStyle.ERROR)
            return
        }
        if (!device.isOnline) {
            showToast("门锁当前离线", ToastStyle.ERROR)
            return
        }

        _ui.update {
            it.copy(
                doorState = DoorVisualState.UNLOCKING,
                isBusy = true,
                lastOperationText = null
            )
        }

        viewModelScope.launch {
            try {
                val successMessage: String
                if (store.current.isLoggedIn) {
                    prepareSession()
                    client.openDoor(device)
                    successMessage = "开锁成功"
                } else {
                    delay(900)
                    successMessage = "演示开锁成功"
                }

                store.record(
                    UnlockRecord(
                        deviceID = device.deviceId,
                        deviceName = device.name,
                        action = DoorAction.UNLOCK,
                        channel = if (store.current.isLoggedIn) UnlockChannel.REMOTE else UnlockChannel.DEMO,
                        detail = successMessage,
                        isDemo = !store.current.isLoggedIn
                    )
                )
                _ui.update {
                    it.copy(
                        doorState = DoorVisualState.UNLOCKED,
                        isBusy = false,
                        lastOperationText = successMessage
                    )
                }
                startRelockCountdown()
            } catch (e: Throwable) {
                _ui.update {
                    it.copy(doorState = DoorVisualState.LOCKED, isBusy = false)
                }
                handleFailure(e)
            }
        }
    }

    fun lock(auto: Boolean = false) {
        stopRelockCountdown()
        val device = selectedDevice()
        if (device != null) {
            store.record(
                UnlockRecord(
                    deviceID = device.deviceId,
                    deviceName = device.name,
                    action = DoorAction.LOCK,
                    channel = if (auto) UnlockChannel.AUTO_RELOCK else UnlockChannel.LOCAL,
                    detail = if (auto) "自动上锁" else "手动上锁",
                    isDemo = !store.current.isLoggedIn
                )
            )
        }
        _ui.update {
            it.copy(
                doorState = DoorVisualState.LOCKED,
                unlockCountdown = null,
                lastOperationText = if (auto) "已自动上锁" else "已手动上锁"
            )
        }
    }

    fun selectDevice(device: DoorDevice) {
        if (device.deviceId == _ui.value.selectedDeviceId) return
        if (_ui.value.doorState == DoorVisualState.UNLOCKED) {
            lock(auto = false)
        }
        _ui.update {
            it.copy(selectedDeviceId = device.deviceId, doorState = DoorVisualState.LOCKED)
        }
    }

    private fun startRelockCountdown() {
        stopRelockCountdown()
        val total = maxOf(1, store.current.autoRelockSeconds)
        _ui.update { it.copy(unlockCountdown = total) }
        relockJob = viewModelScope.launch {
            var remaining = total
            while (remaining > 0) {
                delay(1000)
                remaining -= 1
                _ui.update { it.copy(unlockCountdown = remaining) }
            }
            lock(auto = true)
        }
    }

    private fun stopRelockCountdown() {
        relockJob?.cancel()
        relockJob = null
    }

    // MARK: - 刷新门锁

    fun refreshDevices() {
        if (_ui.value.isRefreshing || _ui.value.isBusy) return
        val persisted = store.current
        if (!persisted.isLoggedIn && !persisted.isDemoMode) {
            openLogin()
            return
        }
        _ui.update { it.copy(isRefreshing = true) }
        viewModelScope.launch {
            try {
                if (store.current.isLoggedIn) {
                    prepareSession()
                    val list = client.fetchDevicesAfterLogin()
                    store.updateDevices(list)
                    if (selectedDevice() == null) {
                        _ui.update { it.copy(selectedDeviceId = list.firstOrNull()?.deviceId) }
                    }
                    showToast("门锁列表已同步 · ${list.size} 把", ToastStyle.SUCCESS)
                } else {
                    delay(500)
                    showToast("门锁状态已刷新", ToastStyle.INFO)
                }
            } catch (e: Throwable) {
                handleFailure(e)
            } finally {
                _ui.update { it.copy(isRefreshing = false) }
            }
        }
    }

    // MARK: - 实时水电

    private val utilityAccount: String get() = store.current.outid ?: ""

    fun scheduleUtilitiesRefresh() {
        viewModelScope.launch { refreshUtilities(silent = true) }
    }

    suspend fun refreshUtilities(silent: Boolean = false) {
        if (_ui.value.isUtilitiesLoading) return
        _ui.update { it.copy(isUtilitiesLoading = true) }
        val account = utilityAccount
        try {
            val rooms = swae.fetchBoundRooms(account)
            store.applyBoundRooms(rooms)
            val verify = store.current.selectedRoomVerify
            if (!verify.isNullOrEmpty()) {
                try {
                    val detail = swae.fetchRoomDetail(verify, account)
                    store.applyRoomDetail(detail)
                } catch (e: Throwable) {
                    val fallback = rooms.firstOrNull()
                    if (rooms.none { it.roomVerify == verify } && fallback != null) {
                        val detail = swae.fetchRoomDetail(fallback.roomVerify, account)
                        store.selectUtilityRoom(fallback)
                        store.applyRoomDetail(detail)
                    } else {
                        throw e
                    }
                }
            } else {
                store.markUtilitySynced()
            }
            _ui.update { it.copy(utilitiesError = null) }
            if (!silent) showToast("水电数据已更新", ToastStyle.SUCCESS)
        } catch (e: Throwable) {
            val msg = e.message ?: "水电同步失败"
            _ui.update { it.copy(utilitiesError = msg) }
            if (!silent) showToast("水电同步失败 · $msg", ToastStyle.ERROR)
        } finally {
            _ui.update { it.copy(isUtilitiesLoading = false) }
        }

        runCatching { swae.fetchH5Config(account) }.getOrNull()?.let { cfg ->
            _ui.update { it.copy(utilityConfig = cfg) }
        }
    }

    fun selectUtilityRoom(room: SWAERoomSummary) {
        store.selectUtilityRoom(room)
        viewModelScope.launch { reloadSelectedRoom(announce = true) }
    }

    private suspend fun reloadSelectedRoom(announce: Boolean) {
        if (_ui.value.isUtilitiesLoading) return
        val verify = store.current.selectedRoomVerify
        if (verify.isNullOrEmpty()) {
            if (announce) showToast("请先选择宿舍房间", ToastStyle.INFO)
            return
        }
        _ui.update { it.copy(isUtilitiesLoading = true) }
        try {
            val detail = swae.fetchRoomDetail(verify, utilityAccount)
            store.applyRoomDetail(detail)
            _ui.update { it.copy(utilitiesError = null) }
            if (announce) showToast("已更新 ${detail.roomFullName}", ToastStyle.SUCCESS)
        } catch (e: Throwable) {
            val msg = e.message ?: "水电查询失败"
            _ui.update { it.copy(utilitiesError = msg) }
            if (announce) showToast("水电查询失败 · $msg", ToastStyle.ERROR)
        } finally {
            _ui.update { it.copy(isUtilitiesLoading = false) }
        }
    }

    suspend fun selectUtilityRoom(
        room: SWAERoomOption,
        zone: SWAEZone,
        building: SWAEBuilding,
        floor: SWAEFloor
    ) {
        if (_ui.value.isUtilitiesLoading) return
        _ui.update { it.copy(isUtilitiesLoading = true) }
        try {
            val preferredVerify = store.current.boundRooms.firstOrNull {
                UtilityRoomName.matches(it.roomFullName, room.name)
            }?.roomVerify
            val detail = swae.fetchRoomDetail(
                room = room,
                zoneID = zone.id,
                buildID = building.id,
                floorID = floor.id,
                preferredVerify = preferredVerify,
                account = utilityAccount
            )
            store.selectUtilityRoom(detail.roomVerify, detail.roomFullName)
            store.applyRoomDetail(detail)
            _ui.update { it.copy(utilitiesError = null) }
            showToast("已切换 · ${detail.roomFullName}", ToastStyle.SUCCESS)
        } catch (e: Throwable) {
            _ui.update { it.copy(utilitiesError = e.message) }
            throw e
        } finally {
            _ui.update { it.copy(isUtilitiesLoading = false) }
        }
    }

    suspend fun loadZones(): List<SWAEZone> = swae.fetchZones(utilityAccount)
    suspend fun loadBuildings(zone: SWAEZone): List<SWAEBuilding> = swae.fetchBuildings(zone.id, utilityAccount)
    suspend fun loadFloors(building: SWAEBuilding): List<SWAEFloor> = swae.fetchFloors(building.id, utilityAccount)
    suspend fun loadRooms(floor: SWAEFloor): List<SWAERoomOption> = swae.fetchRooms(floor.id, utilityAccount)

    // MARK: - 登录 / 退出 / 演示

    suspend fun loginWithPassword(phone: String, password: String) {
        val result = client.loginPassword(phone, password, store.current.deviceId)
        applyLogin(result, password)
    }

    suspend fun requestSMSCode(phone: String) {
        if (!isValidPhone(phone)) throw WMXYError.Server("请输入 11 位手机号")
        client.sendSMSCode(phone, store.current.deviceId)
    }

    suspend fun loginWithSMS(phone: String, code: String) {
        if (!isValidPhone(phone)) throw WMXYError.Server("请输入 11 位手机号")
        if (code.length !in 4..8) throw WMXYError.Server("请输入有效的短信验证码")
        val result = client.loginSMS(phone, code, store.current.deviceId)
        applyLogin(result, null)
    }

    private fun applyLogin(result: WMXYLoginResult, password: String?) {
        store.applyLogin(result)
        if (store.current.rememberCredentials && !password.isNullOrEmpty()) {
            store.vault.save(result.phone, password)
        } else {
            store.vault.clear()
        }
        isSessionReady = true
        stopRelockCountdown()
        _ui.update {
            it.copy(
                doorState = DoorVisualState.LOCKED,
                unlockCountdown = null,
                selectedDeviceId = result.devices.firstOrNull()?.deviceId,
                showLogin = false,
                loginNotice = null,
                lastOperationText = null
            )
        }
        showToast("登录成功，已同步 ${result.devices.size} 把门锁", ToastStyle.SUCCESS)
        scheduleUtilitiesRefresh()
    }

    fun setDemoMode(enabled: Boolean) {
        stopRelockCountdown()
        store.setDemoMode(enabled)
        _ui.update {
            it.copy(
                doorState = DoorVisualState.LOCKED,
                unlockCountdown = null,
                selectedDeviceId = store.current.activeDevices.firstOrNull()?.deviceId,
                lastOperationText = null
            )
        }
        showToast(if (enabled) "已开启演示模式" else "已关闭演示模式", ToastStyle.INFO)
    }

    fun signOut() {
        client.reset()
        isSessionReady = false
        stopRelockCountdown()
        store.signOut()
        _ui.update {
            it.copy(
                doorState = DoorVisualState.LOCKED,
                unlockCountdown = null,
                selectedDeviceId = null,
                utilityConfig = null,
                utilitiesError = null,
                lastOperationText = null
            )
        }
        showToast("已退出登录", ToastStyle.INFO)
    }

    fun openLogin(notice: String? = null) {
        _ui.update { it.copy(showLogin = true, loginNotice = notice) }
    }

    fun dismissLogin() {
        _ui.update { it.copy(showLogin = false, loginNotice = null) }
    }

    fun consumeLoginNotice(): String? {
        val current = _ui.value.loginNotice
        if (current != null) _ui.update { it.copy(loginNotice = null) }
        return current
    }

    fun setThemeMode(mode: ThemeMode) = store.setThemeMode(mode)
    fun setModule(id: String, enabled: Boolean) = store.setModule(id, enabled)
    fun setAutoRelockSeconds(seconds: Int) = store.setAutoRelockSeconds(seconds)
    fun setRememberCredentials(enabled: Boolean) = store.setRememberCredentials(enabled)

    fun clearHistory() {
        store.clearHistory()
        showToast("开门记录已清空", ToastStyle.INFO)
    }

    fun deleteHistory(id: String) {
        store.deleteHistory(id)
    }

    private suspend fun prepareSession() {
        if (!store.current.isLoggedIn || isSessionReady) return
        val cached = store.current.sessionId
        if (!cached.isNullOrEmpty()) {
            try {
                val result = client.resume(cached, store.current.phone ?: "")
                isSessionReady = true
                store.applyLogin(result)
                scheduleUtilitiesRefresh()
                return
            } catch (_: Throwable) {
                isSessionReady = false
            }
        }
        val creds = if (store.current.rememberCredentials) store.vault.load() else null
        if (creds == null) throw WMXYError.InvalidSession
        val result = client.loginPassword(creds.phone, creds.password, store.current.deviceId)
        isSessionReady = true
        store.applyLogin(result)
        scheduleUtilitiesRefresh()
    }

    private fun isValidPhone(phone: String): Boolean =
        phone.length == 11 && phone.all { it.isDigit() } && phone.startsWith("1")

    private fun handleFailure(error: Throwable) {
        val message = error.message ?: "操作失败"
        _ui.update { it.copy(lastOperationText = "操作失败 · $message") }
        showToast(message, ToastStyle.ERROR)
        if (error is WMXYError.InvalidSession || error is WMXYError.NewDeviceVerification) {
            openLogin(message)
        }
    }

    fun showToast(message: String, style: ToastStyle, durationMillis: Long = 2800L) {
        _ui.update { it.copy(toast = ToastMessage(message = message, style = style)) }
        toastJob?.cancel()
        toastJob = viewModelScope.launch {
            delay(durationMillis)
            _ui.update { it.copy(toast = null) }
        }
    }

    // MARK: - 服务模块展示文案

    fun valueFor(module: DormServiceModule, persisted: PersistedState): String {
        return when (module.kind) {
            ServiceModuleKind.UTILITIES -> {
                val detail = persisted.roomDetail
                val meter = detail?.primaryMeter
                if (detail != null && meter != null) {
                    val kind = detail.kindFor(meter)
                    "${formatUtility(meter.remaining)} ${kind.unit}"
                } else if (persisted.isDemoMode) {
                    String.format("%.1f kWh", persisted.electricityKWh)
                } else {
                    "—"
                }
            }
            ServiceModuleKind.HISTORY -> "${persisted.historyThisWeekCount} 条"
            ServiceModuleKind.CLIMATE -> "26°C"
            ServiceModuleKind.CAMPUS_CARD -> if (persisted.isDemoMode) {
                String.format("¥%.1f", persisted.cardBalance)
            } else {
                "—"
            }
        }
    }

    fun detailFor(module: DormServiceModule, persisted: PersistedState): String {
        return when (module.kind) {
            ServiceModuleKind.UTILITIES -> {
                val detail = persisted.roomDetail
                val meter = detail?.primaryMeter
                if (detail != null && meter != null) {
                    val kind = detail.kindFor(meter)
                    "今日 ${formatUtility(meter.todayUse)} ${kind.unit}"
                } else if (persisted.isDemoMode) {
                    "约可用 ${persisted.estimatedElectricityDays} 天"
                } else {
                    "选择宿舍查询"
                }
            }
            ServiceModuleKind.HISTORY -> if (persisted.unlockThisWeekCount > 0) {
                "本周开锁 ${persisted.unlockThisWeekCount} 次"
            } else {
                "暂无记录"
            }
            ServiceModuleKind.CLIMATE -> "未连接"
            ServiceModuleKind.CAMPUS_CARD -> "未接入"
        }
    }

    private fun formatUtility(value: Double): String {
        if (value >= 1000.0) return String.format("%.0f", value)
        if (value >= 100.0) return String.format("%.1f", value)
        return if (value == kotlin.math.round(value)) {
            String.format("%.0f", value)
        } else {
            String.format("%.1f", value)
        }
    }
}
