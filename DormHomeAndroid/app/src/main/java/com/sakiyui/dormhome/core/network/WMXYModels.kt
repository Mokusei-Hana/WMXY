package com.sakiyui.dormhome.core.network

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import java.util.UUID

// MARK: - 错误类型

sealed class WMXYError(override val message: String) : Exception(message) {
    class Crypto(msg: String) : WMXYError(msg)
    class Network(msg: String) : WMXYError("网络连接失败：$msg")
    class InvalidResponse(msg: String) : WMXYError("服务返回异常：$msg")
    class Server(msg: String) : WMXYError(msg.ifEmpty { "服务暂时不可用，请稍后再试" })
    data object NewDeviceVerification : WMXYError("检测到新设备登录，请使用短信验证码验证")
    data object InvalidSession : WMXYError("登录已过期，请重新登录")
    data object MissingParams : WMXYError("登录授权失败，请重试")
    data object LoginRequired : WMXYError("请先登录完美校园账号")
}

// MARK: - 门锁设备

@Serializable
data class DoorDevice(
    val deviceId: String,
    val serialNo: String,
    val name: String,
    val typeName: String,
    val battery: Int? = null,
    val isOnline: Boolean = true,
    val supportMode: String? = null,
    val roomName: String? = null
) {
    companion object {
        val demo = DoorDevice(
            deviceId = "demo-412",
            serialNo = "SN-DEMO-0412",
            name = "3栋 412 宿舍门锁",
            typeName = "智能宿舍门锁",
            battery = 86,
            isOnline = true,
            supportMode = "1,2,4",
            roomName = "3栋 412"
        )

        fun parse(raw: JsonObject): DoorDevice? {
            val deviceId = raw.stringValue("deviceId")?.takeIf { it.isNotEmpty() } ?: return null
            val sn = raw.stringValue("sn") ?: raw.stringValue("serialNo") ?: ""
            val name = raw.stringValue("deviceName")
                ?: raw.stringValue("name")
                ?: "宿舍门锁"
            val typeName = raw.stringValue("deviceTypeName")
                ?: raw.stringValue("deviceType")
                ?: "智能门锁"

            val battery = raw.intValue("battery") ?: raw.stringValue("battery")?.filter { it.isDigit() }?.toIntOrNull()
            val online = raw.boolValue("onlineStatus") ?: raw.boolValue("online") ?: true

            return DoorDevice(
                deviceId = deviceId,
                serialNo = sn,
                name = name,
                typeName = typeName,
                battery = battery,
                isOnline = online,
                supportMode = raw.stringValue("supportMode"),
                roomName = raw.stringValue("roomName") ?: raw.stringValue("room")
            )
        }
    }
}

// MARK: - 开门记录

@Serializable
enum class DoorAction(val title: String) {
    UNLOCK("开锁"),
    LOCK("上锁")
}

@Serializable
enum class UnlockChannel(val title: String) {
    REMOTE("远程开锁"),
    AUTO_RELOCK("自动上锁"),
    DEMO("演示"),
    LOCAL("手动上锁")
}

@Serializable
data class UnlockRecord(
    val id: String = UUID.randomUUID().toString(),
    val timestampMillis: Long = System.currentTimeMillis(),
    val deviceID: String,
    val deviceName: String,
    val action: DoorAction,
    val channel: UnlockChannel,
    val success: Boolean = true,
    val detail: String,
    val isDemo: Boolean = false
)

// MARK: - 演示用电趋势点

@Serializable
data class ElectricityUsagePoint(
    val id: String = UUID.randomUUID().toString(),
    val dateMillis: Long,
    val kwh: Double
)

// MARK: - 登录结果

data class WMXYLoginResult(
    val sessionId: String,
    val outid: String,
    val userName: String?,
    val phone: String,
    val devices: List<DoorDevice>,
    val loginTimestampMillis: Long = System.currentTimeMillis()
)

// MARK: - JsonObject 兼容读取辅助

fun JsonObject.stringValue(key: String): String? {
    val el = this[key] ?: return null
    if (el is JsonNull) return null
    if (el is JsonPrimitive) return el.content
    return null
}

fun JsonObject.intValue(key: String): Int? {
    val str = stringValue(key) ?: return null
    return str.toIntOrNull() ?: str.toDoubleOrNull()?.toInt()
}

fun JsonObject.boolValue(key: String): Boolean? {
    val el = this[key] ?: return null
    if (el is JsonNull) return null
    if (el is JsonPrimitive) {
        val content = el.content.lowercase()
        if (content in setOf("1", "true", "yes", "online", "在线", "on")) return true
        if (content in setOf("0", "false", "no", "offline", "离线", "off")) return false
    }
    return null
}

fun JsonObject.objectValue(key: String): JsonObject? = this[key] as? JsonObject

fun JsonObject.objectArrayValue(key: String): List<JsonObject>? {
    val arr = this[key] as? JsonArray ?: return null
    return arr.mapNotNull { it as? JsonObject }
}

fun JsonElement.asJsonObjectOrNull(): JsonObject? = this as? JsonObject
