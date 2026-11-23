package com.sakiyui.dormhome.core.network

import com.sakiyui.dormhome.core.crypto.WMXYCrypto
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.concurrent.TimeUnit

/**
 * 完美校园「智能水电（SWAE）」只读客户端，严格对齐 iOS SWAEClient.swift。
 * 端点：POST https://xqh5.17wanxiao.com/smartWaterAndElectricityService/SWAEServlet
 */
class SWAEClient {

    companion object {
        const val CUSTOMER_CODE = "2502"
        const val COMMAND = "JBSWaterElecService"
        private const val ENDPOINT = "https://xqh5.17wanxiao.com/smartWaterAndElectricityService/SWAEServlet"
        private const val USER_AGENT =
            "Mozilla/5.0 (Linux; Android 14; wv) AppleWebKit/537.36 " +
                "(KHTML, like Gecko) Version/4.0 Chrome/127.0.0.0 Mobile Safari/537.36 Wanxiao/5.8.6"
        private val FORM_MEDIA = "application/x-www-form-urlencoded;charset=UTF-8".toMediaType()
        private val SHANGHAI_ZONE = ZoneId.of("Asia/Shanghai")
        private val TS17_FMT = DateTimeFormatter.ofPattern("yyyyMMddHHmmss")
    }

    private val json = Json { ignoreUnknownKeys = true; isLenient = true }
    private val httpClient = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .writeTimeout(30, TimeUnit.SECONDS)
        .build()

    suspend fun fetchBoundRooms(account: String): List<SWAERoomSummary> = withContext(Dispatchers.IO) {
        val inner = invoke(
            cmd = "getbindroom",
            payload = mapOf("timestamp" to JsonPrimitive(System.currentTimeMillis().toString())),
            account = account
        )
        SWAEParsing.boundRooms(inner)
    }

    suspend fun fetchRoomDetail(roomverify: String, account: String): SWAERoomDetail = withContext(Dispatchers.IO) {
        val inner = invoke(
            cmd = "h5_getstuindexpage",
            payload = mapOf(
                "roomverify" to JsonPrimitive(roomverify),
                "timestamp" to JsonPrimitive(timestamp17())
            ),
            account = account
        )
        SWAEParsing.detail(inner, requestedVerify = roomverify)
            ?: throw WMXYError.InvalidResponse("水电详情为空，房间可能尚未绑定表计")
    }

    suspend fun fetchRoomDetail(
        room: SWAERoomOption,
        zoneID: Int,
        buildID: Int,
        floorID: Int,
        preferredVerify: String? = null,
        account: String
    ): SWAERoomDetail = withContext(Dispatchers.IO) {
        val candidates = SWAERoomVerify.candidates(
            zoneID = zoneID,
            buildID = buildID,
            floorID = floorID,
            room = room,
            preferredVerify = preferredVerify
        )
        if (candidates.isEmpty()) {
            throw WMXYError.Server("该房间缺少 roomverify，无法查询水电")
        }

        var lastError: Throwable? = null
        for (candidate in candidates) {
            try {
                return@withContext fetchRoomDetail(candidate, account)
            } catch (e: WMXYError.Network) {
                throw e
            } catch (e: Throwable) {
                lastError = e
            }
        }

        if (lastError is WMXYError.Server && lastError.message.contains("接收数据异常")) {
            throw WMXYError.Server("该房间暂无可读取的水电表计，或尚未在完美校园绑定该房间")
        }
        throw lastError ?: WMXYError.Server("未能读取该房间水电，请确认房间是否存在")
    }

    suspend fun fetchZones(account: String): List<SWAEZone> = withContext(Dispatchers.IO) {
        SWAEParsing.zones(invoke("getzonelist", emptyMap(), account))
    }

    suspend fun fetchBuildings(zoneId: Int, account: String): List<SWAEBuilding> = withContext(Dispatchers.IO) {
        SWAEParsing.buildings(invoke("getbuildlist", mapOf("zoneid" to JsonPrimitive(zoneId)), account))
    }

    suspend fun fetchFloors(buildId: Int, account: String): List<SWAEFloor> = withContext(Dispatchers.IO) {
        SWAEParsing.floors(invoke("getfloorlist", mapOf("buildid" to JsonPrimitive(buildId)), account))
    }

    suspend fun fetchRooms(floorId: Int, account: String): List<SWAERoomOption> = withContext(Dispatchers.IO) {
        SWAEParsing.rooms(invoke("getroomnumlist", mapOf("floorid" to JsonPrimitive(floorId)), account))
    }

    suspend fun fetchH5Config(account: String): SWAEConfig = withContext(Dispatchers.IO) {
        SWAEParsing.config(invoke("geth5config", emptyMap(), account))
    }

    private fun invoke(
        cmd: String,
        payload: Map<String, JsonPrimitive>,
        account: String
    ): JsonObject {
        val bodyJson = buildJsonObject {
            for ((k, v) in payload) put(k, v)
            put("cmd", cmd)
            put("account", account)
        }.toString()

        val form = listOf(
            "param=${WMXYCrypto.strictPercentEncode(bodyJson)}",
            "customercode=$CUSTOMER_CODE",
            "method=${WMXYCrypto.strictPercentEncode(cmd)}",
            "command=$COMMAND"
        ).joinToString("&")

        val request = Request.Builder()
            .url(ENDPOINT)
            .post(form.toByteArray(Charsets.UTF_8).toRequestBody(FORM_MEDIA))
            .header("Origin", "https://xqh5.17wanxiao.com")
            .header("Referer", "https://xqh5.17wanxiao.com/userwaterelecmini/index.html")
            .header("X-Requested-With", "com.newcapec.mobile.ncp")
            .header("User-Agent", USER_AGENT)
            .header("Accept", "*/*")
            .header("Accept-Language", "zh-CN,zh;q=0.9")
            .build()

        val responseBytes = try {
            httpClient.newCall(request).execute().use { resp ->
                if (resp.code !in 200..299) {
                    if (resp.code == 403 || resp.code == 405) {
                        throw WMXYError.Network("水电服务拒绝请求（HTTP ${resp.code}），请检查请求头")
                    }
                    throw WMXYError.Network("水电服务 HTTP ${resp.code}")
                }
                resp.body?.bytes() ?: ByteArray(0)
            }
        } catch (e: WMXYError) {
            throw e
        } catch (e: Exception) {
            throw WMXYError.Network(e.localizedMessage ?: e.javaClass.simpleName)
        }

        if (responseBytes.isEmpty()) {
            throw WMXYError.InvalidResponse("水电服务返回空响应（可能被 WAF 拦截）")
        }

        val envelope = runCatching {
            json.parseToJsonElement(String(responseBytes, Charsets.UTF_8)).asJsonObjectOrNull()
        }.getOrNull() ?: throw WMXYError.InvalidResponse("水电响应不是合法 JSON")

        val code = SWAEParsing.int(envelope, "code_")
        if (code != null && code != 0) {
            throw WMXYError.Server(SWAEParsing.string(envelope, "message_") ?: "水电服务返回异常（code $code）")
        }
        if (SWAEParsing.string(envelope, "result_")?.lowercase() != "true") {
            throw WMXYError.Server(SWAEParsing.string(envelope, "message_") ?: "水电服务返回失败")
        }

        val inner = SWAEParsing.string(envelope, "body")?.let { bodyText ->
            runCatching { json.parseToJsonElement(bodyText).asJsonObjectOrNull() }.getOrNull()
        } ?: envelope.objectValue("body")
            ?: throw WMXYError.InvalidResponse("水电响应 body 解析失败")

        val result = SWAEParsing.string(inner, "result") ?: "0"
        if (result != "0") {
            val msg = SWAEParsing.string(inner, "message")
                ?: SWAEParsing.string(envelope, "message_")
                ?: "水电业务返回失败（result $result）"
            throw WMXYError.Server(msg)
        }
        return inner
    }

    private fun timestamp17(): String {
        return Instant.now().atZone(SHANGHAI_ZONE).format(TS17_FMT) + "000"
    }
}
