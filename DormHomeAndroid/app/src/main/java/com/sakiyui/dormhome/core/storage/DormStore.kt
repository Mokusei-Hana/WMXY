package com.sakiyui.dormhome.core.storage

import android.content.Context
import com.sakiyui.dormhome.core.modules.ModuleRegistry
import com.sakiyui.dormhome.core.network.DoorAction
import com.sakiyui.dormhome.core.network.DoorDevice
import com.sakiyui.dormhome.core.network.ElectricityUsagePoint
import com.sakiyui.dormhome.core.network.SWAERoomDetail
import com.sakiyui.dormhome.core.network.SWAERoomSummary
import com.sakiyui.dormhome.core.network.UnlockRecord
import com.sakiyui.dormhome.core.network.WMXYLoginResult
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.time.DayOfWeek
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.temporal.TemporalAdjusters
import kotlin.math.roundToInt

@Serializable
enum class ThemeMode(val title: String) {
    SYSTEM("跟随系统"),
    LIGHT("浅色"),
    DARK("深色")
}

@Serializable
data class PersistedState(
    val schemaVersion: Int = 2,
    val deviceId: String,
    val sessionId: String? = null,
    val sessionTimestampMillis: Long? = null,
    val outid: String? = null,
    val userName: String? = null,
    val phone: String? = null,
    val isLoggedIn: Boolean = false,
    val devices: List<DoorDevice> = emptyList(),
    val history: List<UnlockRecord> = emptyList(),
    val themeMode: ThemeMode = ThemeMode.SYSTEM,
    val enabledModuleIDs: List<String> = ModuleRegistry.defaultEnabledIds,
    val autoRelockSeconds: Int = 30,
    val rememberCredentials: Boolean = true,
    val electricityKWh: Double = 42.6,
    val waterBalance: Double = 18.3,
    val cardBalance: Double = 128.5,
    val electricityUsage: List<ElectricityUsagePoint> = emptyList(),
    val boundRooms: List<SWAERoomSummary> = emptyList(),
    val selectedRoomVerify: String? = null,
    val selectedRoomName: String? = null,
    val roomDetail: SWAERoomDetail? = null,
    val lastUtilitySyncMillis: Long? = null,
    val demoModeEnabled: Boolean = false
) {
    val isDemoMode: Boolean get() = !isLoggedIn && demoModeEnabled

    val activeDevices: List<DoorDevice>
        get() = when {
            isLoggedIn -> devices
            isDemoMode -> listOf(DoorDevice.demo)
            else -> emptyList()
        }

    val roomName: String
        get() {
            activeDevices.firstOrNull()?.let { first ->
                if (!first.roomName.isNullOrEmpty()) return first.roomName
                val parts = first.name.split(" ")
                if (parts.size > 1) return parts.dropLast(1).joinToString(" ")
                return first.name
            }
            if (!selectedRoomName.isNullOrEmpty()) return selectedRoomName
            return if (isDemoMode) "3栋 412" else "我的宿舍"
        }

    val sessionStatusText: String
        get() = when {
            isLoggedIn -> "已连接"
            isDemoMode -> "演示模式"
            else -> "未登录"
        }

    val visibleHistory: List<UnlockRecord>
        get() = (if (isDemoMode) history else history.filter { !it.isDemo })
            .sortedByDescending { it.timestampMillis }

    val historyThisWeekCount: Int
        get() {
            val startOfWeekMillis = startOfWeekMillis()
            return visibleHistory.count { it.timestampMillis >= startOfWeekMillis }
        }

    val unlockThisWeekCount: Int
        get() {
            val startOfWeekMillis = startOfWeekMillis()
            return visibleHistory.count { it.timestampMillis >= startOfWeekMillis && it.action == DoorAction.UNLOCK }
        }

    val averageElectricity: Double
        get() = if (electricityUsage.isEmpty()) 0.0 else electricityUsage.sumOf { it.kwh } / electricityUsage.size

    val estimatedElectricityDays: Int
        get() {
            val avg = averageElectricity
            return if (avg > 0) (electricityKWh / avg).roundToInt() else 0
        }

    val hasLiveUtilities: Boolean get() = roomDetail != null

    val lastUtilitySyncText: String
        get() {
            val ts = lastUtilitySyncMillis ?: return "暂未更新"
            val zone = ZoneId.systemDefault()
            val dt = Instant.ofEpochMilli(ts).atZone(zone)
            val today = LocalDate.now(zone)
            val fmt = if (dt.toLocalDate() == today) {
                DateTimeFormatter.ofPattern("HH:mm")
            } else {
                DateTimeFormatter.ofPattern("M月d日 HH:mm")
            }
            return "更新于 ${dt.format(fmt)}"
        }

    private fun startOfWeekMillis(): Long {
        val zone = ZoneId.systemDefault()
        val monday = LocalDate.now(zone).with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY))
        return monday.atStartOfDay(zone).toInstant().toEpochMilli()
    }

    companion object {
        fun fresh(): PersistedState {
            val zone = ZoneId.systemDefault()
            val today = LocalDate.now(zone)
            val samples = listOf(3.1, 2.6, 4.2, 3.0, 2.2, 3.7, 2.4)
            val usage = samples.mapIndexed { idx, kwh ->
                val date = today.plusDays((idx - 6).toLong())
                ElectricityUsagePoint(
                    dateMillis = date.atStartOfDay(zone).toInstant().toEpochMilli(),
                    kwh = kwh
                )
            }
            return PersistedState(
                deviceId = "wx-door-${System.currentTimeMillis() / 1000}",
                electricityUsage = usage
            )
        }
    }
}

class DormStore(context: Context) {

    companion object {
        private const val PREFS_NAME = "dormhome.store.v1"
        private const val KEY_STATE = "dormhome.state.v1"
    }

    val vault = CredentialVault(context)
    private val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }

    private val _state: MutableStateFlow<PersistedState>
    val state: StateFlow<PersistedState> get() = _state.asStateFlow()

    init {
        val raw = prefs.getString(KEY_STATE, null)
        var loaded = raw?.let {
            runCatching { json.decodeFromString<PersistedState>(it) }.getOrNull()
        } ?: PersistedState.fresh()

        if (loaded.deviceId.isEmpty()) {
            loaded = loaded.copy(deviceId = "wx-door-${System.currentTimeMillis() / 1000}")
        }
        if (loaded.autoRelockSeconds < 10) {
            loaded = loaded.copy(autoRelockSeconds = 30)
        }
        if (loaded.isLoggedIn || !loaded.demoModeEnabled) {
            loaded = loaded.copy(history = loaded.history.filter { !it.isDemo })
        }
        _state = MutableStateFlow(loaded)
        persist(loaded)
    }

    val current: PersistedState get() = _state.value

    private fun update(transform: (PersistedState) -> PersistedState) {
        val next = transform(_state.value)
        _state.value = next
        persist(next)
    }

    private fun persist(value: PersistedState) {
        runCatching {
            prefs.edit().putString(KEY_STATE, json.encodeToString(value)).apply()
        }
    }

    fun setThemeMode(mode: ThemeMode) = update { it.copy(themeMode = mode) }

    fun setModule(id: String, enabled: Boolean) = update { cur ->
        val set = cur.enabledModuleIDs.toMutableSet()
        if (enabled) set.add(id) else set.remove(id)
        val ordered = ModuleRegistry.all.map { it.id }.filter { it in set }
        cur.copy(enabledModuleIDs = ordered)
    }

    fun setAutoRelockSeconds(seconds: Int) = update {
        it.copy(autoRelockSeconds = seconds.coerceIn(10, 60))
    }

    fun setRememberCredentials(enabled: Boolean) {
        if (!enabled) vault.clear()
        update { it.copy(rememberCredentials = enabled) }
    }

    fun applyLogin(result: WMXYLoginResult) = update { cur ->
        cur.copy(
            sessionId = result.sessionId,
            sessionTimestampMillis = result.loginTimestampMillis,
            outid = result.outid,
            userName = result.userName,
            phone = result.phone,
            isLoggedIn = true,
            demoModeEnabled = false,
            devices = result.devices,
            history = cur.history.filter { !it.isDemo }
        )
    }

    fun setDemoMode(enabled: Boolean) = update { cur ->
        if (cur.isLoggedIn) {
            cur.copy(demoModeEnabled = false, history = cur.history.filter { !it.isDemo })
        } else {
            cur.copy(
                demoModeEnabled = enabled,
                history = if (!enabled) cur.history.filter { !it.isDemo } else cur.history
            )
        }
    }

    fun updateDevices(devices: List<DoorDevice>) = update { cur ->
        if (!cur.isLoggedIn) cur else cur.copy(devices = devices)
    }

    fun applyBoundRooms(rooms: List<SWAERoomSummary>) = update { cur ->
        val merged = rooms.toMutableList()
        val selVerify = cur.selectedRoomVerify
        val selName = cur.selectedRoomName
        if (!selVerify.isNullOrEmpty() && merged.none { it.roomVerify == selVerify } && !selName.isNullOrEmpty()) {
            val meters = if (cur.roomDetail?.roomVerify == selVerify) cur.roomDetail.meters else emptyList()
            merged.add(SWAERoomSummary(selName, selVerify, null, meters))
        }
        val nextVerify = selVerify ?: rooms.firstOrNull()?.roomVerify
        val nextName = if (selVerify == null) rooms.firstOrNull()?.roomFullName else selName
        val nextDetail = if (rooms.isEmpty() && nextVerify == null) null else cur.roomDetail
        cur.copy(
            boundRooms = merged,
            selectedRoomVerify = nextVerify,
            selectedRoomName = nextName,
            roomDetail = nextDetail
        )
    }

    fun selectUtilityRoom(room: SWAERoomSummary) = update { cur ->
        val nextRooms = if (cur.boundRooms.none { it.roomVerify == room.roomVerify }) {
            cur.boundRooms + room
        } else {
            cur.boundRooms
        }
        cur.copy(
            selectedRoomVerify = room.roomVerify,
            selectedRoomName = room.roomFullName,
            roomDetail = null,
            boundRooms = nextRooms
        )
    }

    fun selectUtilityRoom(roomVerify: String, name: String) = update { cur ->
        cur.copy(
            selectedRoomVerify = roomVerify,
            selectedRoomName = name,
            roomDetail = null
        )
    }

    fun applyRoomDetail(detail: SWAERoomDetail) = update { cur ->
        cur.copy(
            roomDetail = detail,
            selectedRoomVerify = detail.roomVerify.ifEmpty { cur.selectedRoomVerify },
            selectedRoomName = detail.roomFullName.ifEmpty { cur.selectedRoomName },
            lastUtilitySyncMillis = detail.updatedAtMillis
        )
    }

    fun markUtilitySynced(millis: Long = System.currentTimeMillis()) = update {
        it.copy(lastUtilitySyncMillis = millis)
    }

    fun signOut() {
        vault.clear()
        update { cur ->
            cur.copy(
                isLoggedIn = false,
                demoModeEnabled = false,
                sessionId = null,
                sessionTimestampMillis = null,
                outid = null,
                userName = null,
                phone = null,
                devices = emptyList(),
                boundRooms = emptyList(),
                selectedRoomVerify = null,
                selectedRoomName = null,
                roomDetail = null,
                lastUtilitySyncMillis = null,
                history = cur.history.filter { !it.isDemo }
            )
        }
    }

    fun record(record: UnlockRecord) = update { cur ->
        val next = (listOf(record) + cur.history).take(120)
        cur.copy(history = next)
    }

    fun clearHistory() = update { it.copy(history = emptyList()) }

    fun deleteHistory(id: String) = update { cur ->
        cur.copy(history = cur.history.filter { it.id != id })
    }
}
