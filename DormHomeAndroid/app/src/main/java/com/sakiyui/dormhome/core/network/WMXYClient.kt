package com.sakiyui.dormhome.core.network

import com.sakiyui.dormhome.core.crypto.WMXYCrypto
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import okhttp3.Cookie
import okhttp3.CookieJar
import okhttp3.HttpUrl
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.net.URLDecoder
import java.security.PrivateKey
import java.util.Base64
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.TimeUnit

/**
 * 完美校园远程开门客户端，链路严格对齐 wanxiao_door.py 与 iOS WMXYClient.swift：
 * ① exchangeSecretkey → ② loginnew / sms → ③ authorize(H5) → ④ loginCheck
 * → ⑤ postAuth → ⑥ pageList → ⑦ remotelyOpen
 */
class WMXYClient {

    companion object {
        private const val APP_BASE = "https://app.17wanxiao.com/campus/cam_iface46/"
        private const val H5_BASE = "https://xqh5.17wanxiao.com/keychainService2019/"
        private const val AUTH_URL = "https://open.17wanxiao.com/api/authorize"
        private const val CLIENT_ID = "75dd569e9b1e4362ab92628eddda0f4b"
        private const val CUSTOMER_CODE = "2502"
        private const val APP_VERSION = 1050837101
        private const val VERSION_CODE = 10589101

        private const val UA_WEB =
            "Mozilla/5.0 (Linux; Android 12; 2206122SC Build/V417IR; wv) AppleWebKit/537.36 " +
                "(KHTML, like Gecko) Version/4.0 Chrome/110.0.5481.154 Mobile Safari/537.36 " +
                "Wanxiao/5.8.9 Wmxy/5.8.37"
        private const val UA_APP =
            "Dalvik/2.1.0 (Linux; U; Android 12; 2206122SC Build/f9139cc.1)"

        private val JSON_MEDIA = "application/json;charset=UTF-8".toMediaType()
        private val FORM_MEDIA = "application/x-www-form-urlencoded;charset=UTF-8".toMediaType()
    }

    private val json = Json { ignoreUnknownKeys = true; isLenient = true }
    private val cookieJar = InMemoryCookieJar()

    private val appClient: OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .writeTimeout(30, TimeUnit.SECONDS)
        .build()

    private val h5Client: OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .writeTimeout(30, TimeUnit.SECONDS)
        .cookieJar(cookieJar)
        .followRedirects(false)
        .followSslRedirects(false)
        .build()

    @Volatile var sessionId: String? = null
        private set
    @Volatile var appKey: String? = null
        private set
    @Volatile var outid: String? = null
        private set
    @Volatile private var finalUrl: HttpUrl? = null
    @Volatile private var rsaPrivateKey: PrivateKey? = null

    fun reset() {
        sessionId = null
        appKey = null
        outid = null
        finalUrl = null
        rsaPrivateKey = null
        cookieJar.clear()
    }

    // MARK: - 登录

    suspend fun loginPassword(phone: String, password: String, deviceId: String): WMXYLoginResult =
        withContext(Dispatchers.IO) {
            exchangeSecret()
            val key = appKey ?: throw WMXYError.InvalidSession
            val passwordChars = buildJsonArray {
                var i = 0
                while (i < password.length) {
                    val cp = password.codePointAt(i)
                    val charStr = String(Character.toChars(cp))
                    add(JsonPrimitive(WMXYCrypto.des3EncryptBase64(charStr, key) ?: ""))
                    i += Character.charCount(cp)
                }
            }
            val args = buildJsonObject {
                put("appCode", "M002")
                put("deviceId", deviceId)
                put("netWork", "wifi")
                put("password", passwordChars)
                put("qudao", "guanwang")
                put("requestMethod", "cam_iface46/loginnew.action")
                put("shebeixinghao", "2206122SC")
                put("systemType", "android")
                put("telephoneInfo", "12")
                put("telephoneModel", "2206122SC")
                put("type", "1")
                put("userName", phone)
                put("wanxiaoVersion", APP_VERSION)
            }
            val response = postSigned("loginnew.action", args)
            validateLogin(response)
            completeLogin(phone)
        }

    suspend fun sendSMSCode(phone: String, deviceId: String) = withContext(Dispatchers.IO) {
        exchangeSecret()
        val args = buildJsonObject {
            put("action", "registAndLogin")
            put("deviceId", deviceId)
            put("mobile", phone)
            put("requestMethod", "cam_iface46/gainMatrixCaptcha.action")
            put("type", "sms")
        }
        val response = postSigned("gainMatrixCaptcha.action", args)
        if (response.boolValue("result_") == false) {
            throw WMXYError.Server(response.stringValue("message_") ?: "验证码发送失败")
        }
    }

    suspend fun loginSMS(phone: String, code: String, deviceId: String): WMXYLoginResult =
        withContext(Dispatchers.IO) {
            if (appKey == null || sessionId == null) {
                exchangeSecret()
            }
            val args = buildJsonObject {
                put("appCode", "M002")
                put("deviceId", deviceId)
                put("netWork", "wifi")
                put("qudao", "guanwang")
                put("requestMethod", "cam_iface46/registerUsersByTelAndLoginNew.action")
                put("shebeixinghao", "2206122SC")
                put("sms", code)
                put("systemType", "android")
                put("telephoneInfo", "12")
                put("telephoneModel", "2206122SC")
                put("mobile", phone)
                put("type", "2")
                put("wanxiaoVersion", APP_VERSION)
            }
            val response = postSigned("registerUsersByTelAndLoginNew.action", args)
            validateLogin(response)
            completeLogin(phone)
        }

    suspend fun resume(sessionId: String, phone: String): WMXYLoginResult =
        withContext(Dispatchers.IO) {
            this@WMXYClient.sessionId = sessionId
            this@WMXYClient.appKey = null
            completeLogin(phone)
        }

    private fun completeLogin(phone: String): WMXYLoginResult {
        val sid = sessionId ?: throw WMXYError.InvalidSession
        openH5Session()
        val (resolvedOutId, resolvedName) = loginCheck()
        postAuth()
        val devices = fetchDevices()
        return WMXYLoginResult(
            sessionId = sid,
            outid = resolvedOutId,
            userName = resolvedName,
            phone = phone,
            devices = devices
        )
    }

    private fun validateLogin(response: JsonObject) {
        val success = response.boolValue("result_") ?: false
        if (!success) {
            val code = response.stringValue("code_")
            val message = response.stringValue("message_") ?: "登录失败，请检查账号或密码"
            if (code == "5" && message.contains("新设备")) {
                throw WMXYError.NewDeviceVerification
            }
            throw WMXYError.Server(message)
        }
    }

    // MARK: - ① RSA 密钥交换

    private fun exchangeSecret() {
        val keyPair = try {
            WMXYCrypto.generateRSAKeyPair(1024)
        } catch (e: Exception) {
            throw WMXYError.Crypto("RSA 密钥生成失败：${e.message}")
        }
        rsaPrivateKey = keyPair.private
        val pubB64 = WMXYCrypto.rsaPublicKeySPKIBase64(keyPair.public)
        val bodyStr = buildJsonObject { put("key", pubB64) }.toString()

        val request = Request.Builder()
            .url(APP_BASE + "exchangeSecretkey.action")
            .post(bodyStr.toByteArray(Charsets.UTF_8).toRequestBody(JSON_MEDIA))
            .header("User-Agent", UA_APP)
            .header("Accept", "application/json")
            .build()

        val (data, _) = perform(request, appClient)
        val compact = String(data, Charsets.UTF_8).replace(Regex("\\s+"), "")
        val cipher = runCatching { Base64.getDecoder().decode(compact) }.getOrNull()
            ?: throw WMXYError.InvalidResponse("密钥交换响应不是合法 Base64")
        val plain = WMXYCrypto.rsaDecryptPKCS1(cipher, keyPair.private)
            ?: throw WMXYError.Crypto("RSA 解密失败，无法取得会话密钥")

        val info = parseJsonObject(plain)
        val sid = info.stringValue("session")
        val key = info.stringValue("key")
        if (sid.isNullOrEmpty() || key == null || key.length < 24) {
            throw WMXYError.InvalidResponse("会话密钥字段缺失")
        }
        sessionId = sid
        appKey = key.substring(0, 24)
        outid = null
        finalUrl = null
    }

    // MARK: - ② 签名请求

    private fun postSigned(path: String, args: JsonObject): JsonObject {
        val sid = sessionId ?: throw WMXYError.InvalidSession
        val key = appKey ?: throw WMXYError.InvalidSession
        val encrypted = WMXYCrypto.des3EncryptBase64(args.toString(), key)
            ?: throw WMXYError.Crypto("请求参数加密失败")

        val bodyBytes = buildJsonObject {
            put("session", sid)
            put("data", encrypted)
        }.toString().toByteArray(Charsets.UTF_8)
        val signature = WMXYCrypto.sha256Hex(bodyBytes)

        val request = Request.Builder()
            .url(APP_BASE + path)
            .post(bodyBytes.toRequestBody(JSON_MEDIA))
            .header("campusSign", signature)
            .header("User-Agent", UA_APP)
            .header("Accept", "application/json")
            .build()

        val (data, _) = perform(request, appClient)
        if (data.isEmpty()) throw WMXYError.InvalidResponse("登录接口返回空响应")
        return parseJsonObject(data)
    }

    // MARK: - ③ H5 授权重定向

    private fun openH5Session() {
        val sid = sessionId ?: throw WMXYError.InvalidSession
        cookieJar.clear()

        val pairs = listOf(
            "client_id" to CLIENT_ID,
            "response_type" to "code",
            "redirect_uri" to "${H5_BASE}OpenCampus?apply=accessH5New",
            "versionnum" to APP_VERSION.toString(),
            "customerId" to CUSTOMER_CODE,
            "systemType" to "Android",
            "UAinfo" to "wanxiao",
            "versioncode" to VERSION_CODE.toString(),
            "token" to sid
        )
        val query = pairs.joinToString("&") { (k, v) -> "$k=${WMXYCrypto.strictPercentEncode(v)}" }
        var currentUrl = "$AUTH_URL?$query".toHttpUrl()

        for (hop in 0..8) {
            val request = Request.Builder()
                .url(currentUrl)
                .get()
                .header("User-Agent", UA_WEB)
                .header("Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8")
                .header("Accept-Language", "zh-CN,zh;q=0.9")
                .build()

            val (_, responseCode, location) = performForRedirect(request, h5Client)
            if (responseCode in 300..399 && !location.isNullOrEmpty()) {
                val next = currentUrl.resolve(location)
                if (next != null) {
                    currentUrl = next
                    continue
                }
            }
            break
        }
        finalUrl = currentUrl
    }

    // MARK: - ④ loginCheck

    private fun loginCheck(): Pair<String, String?> {
        val params = extractParams(finalUrl)
        if (params.isNullOrEmpty()) throw WMXYError.MissingParams

        val formBody = "data=${WMXYCrypto.strictPercentEncode(params)}"
        val request = buildH5Request(H5_BASE + "loginCheck", formBody)
        val (data, _) = perform(request, h5Client)
        if (data.isEmpty()) throw WMXYError.InvalidSession

        val top = parseJsonObject(data)
        val resultData = top.stringValue("resultdata")
            ?: throw WMXYError.InvalidResponse("loginCheck 返回结构异常")
        val decrypted = WMXYCrypto.aesECBDecryptBase64(resultData)
            ?: throw WMXYError.InvalidResponse("loginCheck 返回结构异常")

        val inner = parseJsonObject(decrypted.toByteArray(Charsets.UTF_8))
        val bodyText = inner.stringValue("body")
            ?: throw WMXYError.InvalidResponse("loginCheck 密文结构异常")
        val outer = parseJsonObject(bodyText.toByteArray(Charsets.UTF_8))
        val payload = outer.objectValue("data") ?: JsonObject(emptyMap())
        val resolved = payload.stringValue("outid")
        if (resolved.isNullOrEmpty()) throw WMXYError.InvalidResponse("未取得 outid")

        outid = resolved
        return resolved to payload.stringValue("name")
    }

    private fun extractParams(url: HttpUrl?): String? {
        if (url == null) return null
        url.queryParameter("params")?.takeIf { it.isNotEmpty() }?.let { return it }

        val fragment = url.fragment ?: return null
        val qIdx = fragment.indexOf('?')
        if (qIdx < 0 || qIdx + 1 >= fragment.length) return null
        val queryStr = fragment.substring(qIdx + 1)
        for (pair in queryStr.split("&")) {
            val eq = pair.indexOf('=')
            if (eq > 0) {
                val key = pair.substring(0, eq)
                if (key == "params") {
                    val rawVal = pair.substring(eq + 1)
                    return runCatching { URLDecoder.decode(rawVal, "UTF-8") }.getOrDefault(rawVal)
                }
            }
        }
        return null
    }

    // MARK: - ⑤⑥⑦ H5 业务

    private fun postAuth() {
        val uid = outid ?: throw WMXYError.InvalidSession
        invoke("postAuth", buildJsonObject { put("userId", uid) })
    }

    private fun fetchDevices(): List<DoorDevice> {
        val uid = outid ?: throw WMXYError.InvalidSession
        val response = invoke(
            "pageList",
            buildJsonObject {
                put("currentPage", 1)
                put("pageSize", 20)
                put("userId", uid)
                put("status", 0)
            }
        ) ?: throw WMXYError.InvalidSession

        val data = response.objectValue("data") ?: JsonObject(emptyMap())
        val list = data.objectArrayValue("list") ?: response.objectArrayValue("list") ?: emptyList()
        return list.mapNotNull(DoorDevice::parse)
    }

    suspend fun fetchDevicesAfterLogin(): List<DoorDevice> = withContext(Dispatchers.IO) {
        fetchDevices()
    }

    suspend fun openDoor(device: DoorDevice, mode: String = "0"): String = withContext(Dispatchers.IO) {
        if (outid == null) throw WMXYError.InvalidSession
        val reqData = buildJsonObject {
            val intId = device.deviceId.toIntOrNull()
            if (intId != null) put("deviceId", intId) else put("deviceId", device.deviceId)
            put("serialNo", device.serialNo)
            put("mode", mode)
        }
        val response = invoke("remotelyOpen", reqData)
            ?: throw WMXYError.Server("开门指令未收到服务回执，请确认门锁在线")
        val message = extractMessage(response) ?: "开门指令已下发"
        if (message.contains("成功") || response.stringValue("code") == "0") {
            return@withContext message
        }
        throw WMXYError.Server(message)
    }

    private fun invoke(method: String, requestData: JsonObject): JsonObject? {
        val uid = outid
        val mergedData = buildJsonObject {
            for ((k, v) in requestData) put(k, v)
            if (uid != null && !requestData.containsKey("outid")) put("outid", uid)
            if (!requestData.containsKey("customerCode")) put("customerCode", CUSTOMER_CODE)
        }
        val payload = buildJsonObject {
            put("request_data", mergedData)
            put("method", method)
        }
        val plain = "${payload}&${System.currentTimeMillis()}"
        val encrypted = WMXYCrypto.aesECBEncryptBase64(plain)
            ?: throw WMXYError.Crypto("H5 请求加密失败")

        val form = "method=AccessH5&param=${WMXYCrypto.strictPercentEncode(encrypted)}&customercode=$CUSTOMER_CODE"
        val request = buildH5Request(H5_BASE + "WXInvokFront", form)
        val (data, _) = perform(request, h5Client)
        if (data.isEmpty()) return null

        val top = parseJsonObject(data)
        val bodyText = top.stringValue("body")
        if (!bodyText.isNullOrEmpty()) {
            return runCatching { parseJsonObject(bodyText.toByteArray(Charsets.UTF_8)) }.getOrNull()
        }
        return top
    }

    // MARK: - HTTP 辅助

    private fun buildH5Request(url: String, formBody: String): Request {
        return Request.Builder()
            .url(url)
            .post(formBody.toByteArray(Charsets.UTF_8).toRequestBody(FORM_MEDIA))
            .header("User-Agent", UA_WEB)
            .header("Origin", "https://xqh5.17wanxiao.com")
            .header("Referer", "${H5_BASE}accessH5New/index.html")
            .header("X-Requested-With", "com.newcapec.mobile.ncp")
            .header("Accept", "application/json, text/javascript, */*; q=0.01")
            .build()
    }

    private fun perform(request: Request, client: OkHttpClient): Pair<ByteArray, Int> {
        try {
            client.newCall(request).execute().use { response ->
                val code = response.code
                if (code !in 200..299) {
                    throw WMXYError.Network("HTTP $code")
                }
                val bytes = response.body?.bytes() ?: ByteArray(0)
                return bytes to code
            }
        } catch (e: WMXYError) {
            throw e
        } catch (e: Exception) {
            throw WMXYError.Network(e.localizedMessage ?: e.javaClass.simpleName)
        }
    }

    private fun performForRedirect(request: Request, client: OkHttpClient): Triple<ByteArray, Int, String?> {
        try {
            client.newCall(request).execute().use { response ->
                val code = response.code
                if (code !in 200..399) {
                    throw WMXYError.Network("HTTP $code")
                }
                val location = response.header("Location")
                val bytes = response.body?.bytes() ?: ByteArray(0)
                return Triple(bytes, code, location)
            }
        } catch (e: WMXYError) {
            throw e
        } catch (e: Exception) {
            throw WMXYError.Network(e.localizedMessage ?: e.javaClass.simpleName)
        }
    }

    private fun parseJsonObject(bytes: ByteArray): JsonObject {
        return runCatching {
            json.parseToJsonElement(String(bytes, Charsets.UTF_8)).asJsonObjectOrNull()
        }.getOrNull() ?: throw WMXYError.InvalidResponse("JSON 解析失败")
    }

    private fun extractMessage(response: JsonObject): String? {
        response.objectValue("data")?.let { data ->
            data.stringValue("data")?.takeIf { it.isNotEmpty() }?.let { return it }
            data.stringValue("msg")?.takeIf { it.isNotEmpty() }?.let { return it }
            data.stringValue("message")?.takeIf { it.isNotEmpty() }?.let { return it }
        }
        response.stringValue("data")?.takeIf { it.isNotEmpty() }?.let { return it }
        response.stringValue("msg")?.takeIf { it.isNotEmpty() }?.let { return it }
        response.stringValue("message")?.takeIf { it.isNotEmpty() }?.let { return it }
        return null
    }
}

private class InMemoryCookieJar : CookieJar {
    private val store = ConcurrentHashMap<String, Cookie>()

    override fun saveFromResponse(url: HttpUrl, cookies: List<Cookie>) {
        val now = System.currentTimeMillis()
        for (cookie in cookies) {
            val key = "${cookie.domain}|${cookie.path}|${cookie.name}"
            if (cookie.expiresAt < now) {
                store.remove(key)
            } else {
                store[key] = cookie
            }
        }
    }

    override fun loadForRequest(url: HttpUrl): List<Cookie> {
        val now = System.currentTimeMillis()
        val matched = mutableListOf<Cookie>()
        val expiredKeys = mutableListOf<String>()
        for ((key, cookie) in store) {
            if (cookie.expiresAt < now) {
                expiredKeys.add(key)
            } else if (cookie.matches(url)) {
                matched.add(cookie)
            }
        }
        expiredKeys.forEach { store.remove(it) }
        return matched
    }

    fun clear() {
        store.clear()
    }
}
