package com.sakiyui.dormhome.core.network

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import java.util.UUID
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.roundToInt

// MARK: - 表计分类

enum class SWAEMeterKind(
    val title: String,
    val unit: String,
    val statusOnText: String,
    val statusOffText: String
) {
    ELECTRICITY("电表", "kWh", "通电中", "已断电"),
    COLD_WATER("冷水表", "t", "供水正常", "已关阀"),
    HOT_WATER("热水表", "t", "供水正常", "已关阀"),
    AIR_CONDITIONER("空调", "kWh", "通电中", "已断电"),
    OTHER("表计", "", "在线", "离线")
}

// MARK: - 级联选择模型

@Serializable
data class SWAEZone(val id: Int, val name: String)

@Serializable
data class SWAEBuilding(val id: Int, val name: String)

@Serializable
data class SWAEFloor(val id: Int, val name: String)

@Serializable
data class SWAERoomOption(
    val id: Int,
    val name: String,
    val roomverify: String? = null
)

// MARK: - 用量

@Serializable
data class SWAEDailyUsage(
    val id: String = UUID.randomUUID().toString(),
    val dateText: String,
    val weekday: String? = null,
    val use: Double
) {
    val shortDateText: String
        get() {
            val parts = dateText.split("-")
            return if (parts.size >= 2) "${parts[parts.size - 2]}-${parts[parts.size - 1]}" else dateText
        }
}

@Serializable
data class SWAEMonthlyUsage(
    val id: String = UUID.randomUUID().toString(),
    val yearMonth: String,
    val use: Double
)

// MARK: - 表计

@Serializable
data class SWAEMeterDetail(
    val deviceName: String,
    val mac: String,
    val businessType: Int,
    val status: Int,
    val remaining: Double,
    val used: Double? = null,
    val todayUse: Double = 0.0,
    val accode: String = "",
    val sumBuy: Double? = null,
    val sumSub: Double? = null,
    val isShowPay: Boolean = false,
    val weekUseList: List<SWAEDailyUsage> = emptyList(),
    val monthUseList: List<SWAEMonthlyUsage> = emptyList()
) {
    val id: String
        get() {
            val key = mac.ifEmpty { "$deviceName-$accode" }
            return "$key-$businessType-$deviceName"
        }

    val isOn: Boolean get() = status == 1

    val kind: SWAEMeterKind
        get() {
            if (deviceName.contains("空调")) return SWAEMeterKind.AIR_CONDITIONER
            if (accode.contains("51101") || accode.contains("51102")) return SWAEMeterKind.ELECTRICITY
            if (accode.contains("51201") || accode.contains("51202")) return SWAEMeterKind.COLD_WATER
            return when (businessType) {
                0 -> SWAEMeterKind.ELECTRICITY
                1 -> SWAEMeterKind.COLD_WATER
                2 -> SWAEMeterKind.HOT_WATER
                else -> SWAEMeterKind.OTHER
            }
        }

    val weeklyTotal: Double get() = weekUseList.sumOf { it.use }

    val dailyAverage: Double
        get() = if (weekUseList.isEmpty()) max(0.0, todayUse) else weeklyTotal / weekUseList.size

    val estimatedDays: Int?
        get() {
            val avg = dailyAverage
            if (avg <= 0.0001 || remaining < 0) return null
            return max(0, (remaining / avg).roundToInt())
        }
}

// MARK: - 房间

@Serializable
data class SWAERoomSummary(
    val roomFullName: String,
    val roomVerify: String,
    val accountNum: String? = null,
    val meterDetails: List<SWAEMeterDetail> = emptyList()
) {
    val electricMeter: SWAEMeterDetail?
        get() = meterDetails.firstOrNull { it.businessType == 0 && !it.deviceName.contains("空调") }
            ?: meterDetails.firstOrNull { it.businessType == 0 }

    val primaryMeter: SWAEMeterDetail?
        get() = electricMeter ?: meterDetails.firstOrNull()
}

@Serializable
data class SWAERoomDetail(
    val roomFullName: String,
    val roomVerify: String,
    val roomNum: String? = null,
    val meters: List<SWAEMeterDetail> = emptyList(),
    val updatedAtMillis: Long = System.currentTimeMillis(),
    val hasSubsidy: Boolean = false
) {
    val electricMeter: SWAEMeterDetail?
        get() = meters.firstOrNull { it.kind == SWAEMeterKind.ELECTRICITY }
            ?: meters.firstOrNull { it.businessType == 0 && !it.deviceName.contains("空调") }

    val primaryMeter: SWAEMeterDetail?
        get() = electricMeter ?: meters.firstOrNull()

    fun kindFor(meter: SWAEMeterDetail): SWAEMeterKind {
        if (meter.kind == SWAEMeterKind.AIR_CONDITIONER) return SWAEMeterKind.AIR_CONDITIONER
        if (roomFullName.contains("空调") && meter.businessType == 0) return SWAEMeterKind.AIR_CONDITIONER
        return meter.kind
    }

    fun displayNameFor(meter: SWAEMeterDetail): String {
        val meterKind = kindFor(meter)
        val hasCold = meters.any { kindFor(it) == SWAEMeterKind.COLD_WATER }
        val hasHot = meters.any { kindFor(it) == SWAEMeterKind.HOT_WATER }

        val base = when (meterKind) {
            SWAEMeterKind.ELECTRICITY -> "电表"
            SWAEMeterKind.COLD_WATER -> if (hasHot) "冷水表" else "水表"
            SWAEMeterKind.HOT_WATER -> if (hasCold) "热水表" else "热水"
            SWAEMeterKind.AIR_CONDITIONER -> "空调"
            SWAEMeterKind.OTHER -> "表计"
        }

        val sameKind = meters.filter { kindFor(it) == meterKind }
        if (sameKind.size <= 1) return base
        val idx = sameKind.indexOfFirst { it.id == meter.id }
        return if (idx >= 0) "$base ${idx + 1}" else base
    }
}

// MARK: - 配置

@Serializable
data class SWAEConfig(
    val systemName: String,
    val electricPriceHint: String,
    val coldWaterPriceHint: String,
    val hotWaterPriceHint: String,
    val payEnabled: Boolean = true,
    val hasSubsidy: Boolean = false
) {
    val electricityUnitPrice: Double? get() = extractPrice(electricPriceHint)
    val coldWaterUnitPrice: Double? get() = extractPrice(coldWaterPriceHint)
    val hotWaterUnitPrice: Double? get() = extractPrice(hotWaterPriceHint)

    companion object {
        val fallback = SWAEConfig(
            systemName = "物联网水电管理系统",
            electricPriceHint = "电费收费标准为0.65元/度",
            coldWaterPriceHint = "冷水费收费标准为1.5元/吨",
            hotWaterPriceHint = "热水费收费标准为2.5元/吨",
            payEnabled = true,
            hasSubsidy = false
        )

        private val priceRegex = Regex("([0-9]+(?:\\.[0-9]+)?)\\s*元\\s*[/／]?\\s*(度|吨)")

        private fun extractPrice(text: String): Double? {
            return priceRegex.find(text)?.groupValues?.getOrNull(1)?.toDoubleOrNull()
        }
    }
}

// MARK: - 兼容解析器

object SWAEParsing {

    private val numberRegex = Regex("[-+]?[0-9]*\\.?[0-9]+")

    fun string(obj: JsonObject, key: String): String? {
        val el = obj[key] ?: return null
        if (el is JsonNull) return null
        return (el as? JsonPrimitive)?.content
    }

    fun double(obj: JsonObject, key: String): Double? {
        val raw = string(obj, key) ?: return null
        val cleaned = raw.trim().replace(",", "")
        cleaned.toDoubleOrNull()?.let { return it }
        return numberRegex.find(cleaned)?.value?.toDoubleOrNull()
    }

    fun int(obj: JsonObject, key: String): Int? {
        return double(obj, key)?.roundToInt()
    }

    fun bool(obj: JsonObject, key: String): Boolean? {
        val raw = string(obj, key)?.lowercase() ?: return null
        if (raw in setOf("1", "true", "yes", "on")) return true
        if (raw in setOf("0", "false", "no", "off")) return false
        return null
    }

    private fun entities(inner: JsonObject): List<Pair<Int, String>> {
        val list = inner.objectArrayValue("data")
            ?: inner.objectArrayValue("list")
            ?: inner.objectArrayValue("zonelist")
            ?: emptyList()
        return list.mapNotNull { item ->
            val id = int(item, "id") ?: return@mapNotNull null
            val name = string(item, "name")?.takeIf { it.isNotEmpty() } ?: return@mapNotNull null
            id to name
        }
    }

    fun zones(inner: JsonObject): List<SWAEZone> = entities(inner).map { SWAEZone(it.first, it.second) }
    fun buildings(inner: JsonObject): List<SWAEBuilding> = entities(inner).map { SWAEBuilding(it.first, it.second) }
    fun floors(inner: JsonObject): List<SWAEFloor> = entities(inner).map { SWAEFloor(it.first, it.second) }

    fun rooms(inner: JsonObject): List<SWAERoomOption> {
        val list = inner.objectArrayValue("data")
            ?: inner.objectArrayValue("list")
            ?: inner.objectArrayValue("roomnumlist")
            ?: emptyList()
        return list.mapNotNull { item ->
            val id = int(item, "id") ?: return@mapNotNull null
            val name = string(item, "name")?.takeIf { it.isNotEmpty() } ?: return@mapNotNull null
            val verify = string(item, "roomverify")?.takeIf { it.isNotEmpty() }
            SWAERoomOption(id = id, name = name, roomverify = verify)
        }
    }

    fun boundRooms(inner: JsonObject): List<SWAERoomSummary> {
        val flag = string(inner, "existflag") ?: "0"
        val list = inner.objectArrayValue("roomlist")
        if (!list.isNullOrEmpty()) {
            return list.mapNotNull { room(it) }
        }
        if (flag == "1") {
            return listOfNotNull(room(inner))
        }
        return emptyList()
    }

    private fun room(raw: JsonObject): SWAERoomSummary? {
        val verify = string(raw, "roomverify")?.takeIf { it.isNotEmpty() } ?: return null
        val name = string(raw, "roomfullname")?.takeIf { it.isNotEmpty() } ?: verify
        val meters = (raw.objectArrayValue("detaillist") ?: emptyList()).mapNotNull { meter(it) }
        return SWAERoomSummary(
            roomFullName = name,
            roomVerify = verify,
            accountNum = string(raw, "account_num")?.takeIf { it.isNotEmpty() },
            meterDetails = meters
        )
    }

    fun meter(raw: JsonObject): SWAEMeterDetail? {
        val businessType = int(raw, "businesstype") ?: int(raw, "businessType") ?: 0
        val deviceName = string(raw, "devicename")
            ?: string(raw, "deviceName")
            ?: defaultDeviceName(businessType)
        val mac = string(raw, "mac") ?: ""
        val accode = string(raw, "accode") ?: string(raw, "ecardacccode") ?: ""
        val remaining = double(raw, "odd") ?: double(raw, "remaining") ?: 0.0
        val status = int(raw, "status") ?: 1

        val weekSource = raw.objectArrayValue("weekuselist")
            ?: raw.objectArrayValue("weekUseList")
            ?: raw.objectArrayValue("dayuselist")
            ?: emptyList()
        val weeks = weekSource.mapNotNull { dailyUsage(it) }

        val monthSource = raw.objectArrayValue("monthuselist")
            ?: raw.objectArrayValue("monthUseList")
            ?: emptyList()
        val months = monthSource.mapNotNull { monthlyUsage(it) }

        val hasSignal = raw.containsKey("devicename") ||
            raw.containsKey("deviceName") ||
            raw.containsKey("odd") ||
            raw.containsKey("mac") ||
            weeks.isNotEmpty()
        if (!hasSignal) return null

        return SWAEMeterDetail(
            deviceName = deviceName,
            mac = mac,
            businessType = businessType,
            status = status,
            remaining = remaining,
            used = double(raw, "use"),
            todayUse = double(raw, "todayuse") ?: double(raw, "todayUse") ?: 0.0,
            accode = accode,
            sumBuy = double(raw, "sumbuy") ?: double(raw, "sumBuy"),
            sumSub = double(raw, "sumsub") ?: double(raw, "sumSub"),
            isShowPay = bool(raw, "isshowpay") ?: bool(raw, "isShowPay") ?: false,
            weekUseList = weeks,
            monthUseList = months
        )
    }

    private fun dailyUsage(raw: JsonObject): SWAEDailyUsage? {
        val dateText = string(raw, "date")
            ?: string(raw, "daydate")
            ?: string(raw, "dayDate")
            ?: ""
        val use = double(raw, "use") ?: double(raw, "dayuse") ?: double(raw, "dayUse") ?: 0.0
        if (dateText.isEmpty() && use <= 0) return null
        return SWAEDailyUsage(
            dateText = dateText,
            weekday = string(raw, "weekday"),
            use = use
        )
    }

    private fun monthlyUsage(raw: JsonObject): SWAEMonthlyUsage? {
        val ym = string(raw, "yearmonth")
            ?: string(raw, "yearMonth")
            ?: string(raw, "month")
            ?: ""
        val use = double(raw, "monthuse") ?: double(raw, "monthUse") ?: 0.0
        if (ym.isEmpty() && use <= 0) return null
        return SWAEMonthlyUsage(yearMonth = ym, use = use)
    }

    fun detail(
        inner: JsonObject,
        requestedVerify: String? = null,
        fetchedAtMillis: Long = System.currentTimeMillis()
    ): SWAERoomDetail? {
        val verify = string(inner, "roomverify")?.takeIf { it.isNotEmpty() }
            ?: requestedVerify
            ?: ""
        val list = inner.objectArrayValue("modlist")
            ?: inner.objectArrayValue("modList")
            ?: emptyList()
        val meters = list.mapNotNull { meter(it) }
        if (meters.isEmpty() && verify.isEmpty()) return null

        val name = string(inner, "roomfullname")?.takeIf { it.isNotEmpty() } ?: verify
        return SWAERoomDetail(
            roomFullName = name,
            roomVerify = verify,
            roomNum = string(inner, "roomnum")?.takeIf { it.isNotEmpty() },
            meters = meters,
            updatedAtMillis = fetchedAtMillis,
            hasSubsidy = bool(inner, "isshowsubsidy") ?: false
        )
    }

    fun config(inner: JsonObject): SWAEConfig {
        val data = inner.objectValue("data") ?: inner
        val systemName = string(data, "system_name")?.takeIf { it.isNotEmpty() } ?: "物联网水电管理系统"
        val electric = stripHTML(string(data, "h5_fixed_d_remind") ?: "")
        val cold = stripHTML(string(data, "h5_fixed_colds_remind") ?: "")
        val hot = stripHTML(string(data, "h5_fixed_hots_remind") ?: "")

        return SWAEConfig(
            systemName = systemName,
            electricPriceHint = electric.ifEmpty { SWAEConfig.fallback.electricPriceHint },
            coldWaterPriceHint = cold.ifEmpty { SWAEConfig.fallback.coldWaterPriceHint },
            hotWaterPriceHint = hot.ifEmpty { SWAEConfig.fallback.hotWaterPriceHint },
            payEnabled = bool(data, "h5_pay_switch") ?: true,
            hasSubsidy = bool(data, "subOrNot") ?: bool(inner, "isshowsubsidy") ?: false
        )
    }

    private fun stripHTML(html: String): String {
        return html
            .replace(Regex("<[^>]+>"), " ")
            .replace("&nbsp;", " ")
            .replace("&amp;", "&")
            .replace("&lt;", "<")
            .replace("&gt;", ">")
            .replace("&quot;", "\"")
            .replace("&#39;", "'")
            .replace(Regex("\\s+"), " ")
            .trim()
    }

    private fun defaultDeviceName(businessType: Int): String = when (businessType) {
        0 -> "电控"
        1 -> "冷水表"
        2 -> "热水表"
        else -> "表计"
    }
}

object UtilityRoomName {
    fun matches(bound: String, selected: String): Boolean {
        if (bound.isEmpty() || selected.isEmpty()) return false
        if (bound == selected || bound.contains(selected)) return true
        val cleaned = selected.replace("房间", "").trim()
        if (cleaned.isEmpty()) return false
        return bound == cleaned ||
            bound.endsWith("_$cleaned") ||
            bound.endsWith("-$cleaned") ||
            bound.endsWith(" $cleaned")
    }
}

object SWAERoomVerify {
    fun candidates(
        zoneID: Int,
        buildID: Int,
        floorID: Int,
        room: SWAERoomOption,
        preferredVerify: String? = null
    ): List<String> {
        val values = LinkedHashSet<String>()
        if (!preferredVerify.isNullOrEmpty()) values.add(preferredVerify)
        if (!room.roomverify.isNullOrEmpty()) values.add(room.roomverify)

        val cleanedName = room.name.replace("房间", "").trim()
        val roomKeys = listOf(cleanedName, room.id.toString()).filter { it.isNotEmpty() }
        for (key in roomKeys) {
            values.add("$zoneID-$buildID--$floorID-$key")
            values.add("$zoneID-$buildID-$floorID-$key")
        }
        return values.toList()
    }
}

fun Double.formatSwae(): String {
    if (this == kotlin.math.round(this) || abs(this) >= 1000.0) {
        return String.format("%.0f", this)
    }
    return String.format("%.1f", this)
}
