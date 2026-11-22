//
//  WMXYClient.swift
//  DormHome
//
//  完美校园远程开门客户端，链路严格对齐 wanxiao_door.py：
//  exchangeSecretkey → loginnew / sms → authorize(H5) → loginCheck
//  → postAuth → pageList → remotelyOpen
//

import Foundation

final class WMXYClient {

    // MARK: - 常量

    private let appBase = URL(string: "https://app.17wanxiao.com/campus/cam_iface46")!
    private let h5Base = URL(string: "https://xqh5.17wanxiao.com/keychainService2019")!
    private let authURL = URL(string: "https://open.17wanxiao.com/api/authorize")!
    private let clientID = "75dd569e9b1e4362ab92628eddda0f4b"
    private let customerCode = "2502"
    private let appVersion = 1050837101
    private let versionCode = 10589101
    private let timeout: TimeInterval = 30

    private let uaWeb = "Mozilla/5.0 (Linux; Android 12; 2206122SC Build/V417IR; wv) AppleWebKit/537.36 "
        + "(KHTML, like Gecko) Version/4.0 Chrome/110.0.5481.154 Mobile Safari/537.36 "
        + "Wanxiao/5.8.9 Wmxy/5.8.37"
    private let uaApp = "Dalvik/2.1.0 (Linux; U; Android 12; 2206122SC Build/f9139cc.1)"

    // MARK: - 会话状态

    private(set) var sessionId: String?
    private(set) var appKey: String?
    private(set) var outid: String?
    private var finalURL: URL?
    private var rsaPrivateKey: SecKey?

    private let redirectDelegate = RedirectBlockingDelegate()
    private lazy var h5Session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout * 2
        configuration.httpCookieStorage = .shared
        configuration.httpShouldSetCookies = true
        configuration.httpCookieAcceptPolicy = .always
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        return URLSession(configuration: configuration, delegate: redirectDelegate, delegateQueue: nil)
    }()

    func reset() {
        sessionId = nil
        appKey = nil
        outid = nil
        finalURL = nil
        rsaPrivateKey = nil
        clearCookies()
    }

    // MARK: - 登录

    func loginPassword(phone: String, password: String, deviceId: String) async throws -> WMXYLoginResult {
        try await exchangeSecret()

        let args: [String: Any] = [
            "appCode": "M002",
            "deviceId": deviceId,
            "netWork": "wifi",
            "password": password.unicodeScalars.map {
                WMXYCrypto.des3EncryptBase64(String($0), key: appKey ?? "") ?? ""
            },
            "qudao": "guanwang",
            "requestMethod": "cam_iface46/loginnew.action",
            "shebeixinghao": "2206122SC",
            "systemType": "android",
            "telephoneInfo": "12",
            "telephoneModel": "2206122SC",
            "type": "1",
            "userName": phone,
            "wanxiaoVersion": appVersion
        ]
        let response = try await postSigned(path: "loginnew.action", args: args)
        try validateLogin(response)
        return try await completeLogin(phone: phone)
    }

    func sendSMSCode(phone: String, deviceId: String) async throws {
        try await exchangeSecret()
        let args: [String: Any] = [
            "action": "registAndLogin",
            "deviceId": deviceId,
            "mobile": phone,
            "requestMethod": "cam_iface46/gainMatrixCaptcha.action",
            "type": "sms"
        ]
        let response = try await postSigned(path: "gainMatrixCaptcha.action", args: args)
        if response.boolValue("result_") == false {
            throw WMXYError.server(response.stringValue("message_") ?? "验证码发送失败")
        }
    }

    func loginSMS(phone: String, code: String, deviceId: String) async throws -> WMXYLoginResult {
        if appKey == nil || sessionId == nil {
            try await exchangeSecret()
        }
        let args: [String: Any] = [
            "appCode": "M002",
            "deviceId": deviceId,
            "netWork": "wifi",
            "qudao": "guanwang",
            "requestMethod": "cam_iface46/registerUsersByTelAndLoginNew.action",
            "shebeixinghao": "2206122SC",
            "sms": code,
            "systemType": "android",
            "telephoneInfo": "12",
            "telephoneModel": "2206122SC",
            "mobile": phone,
            "type": "2",
            "wanxiaoVersion": appVersion
        ]
        let response = try await postSigned(path: "registerUsersByTelAndLoginNew.action", args: args)
        try validateLogin(response)
        return try await completeLogin(phone: phone)
    }

    /// 复用缓存 session，只走 ③ 授权 → ④ loginCheck → ⑤ postAuth → ⑥ pageList。
    func resume(sessionId: String, phone: String) async throws -> WMXYLoginResult {
        self.sessionId = sessionId
        self.appKey = nil
        return try await completeLogin(phone: phone)
    }

    private func completeLogin(phone: String) async throws -> WMXYLoginResult {
        guard let sessionId else { throw WMXYError.invalidSession }
        try await openH5Session()
        let check = try await loginCheck()
        try await postAuth()
        let devices = try await fetchDevices()
        return WMXYLoginResult(
            sessionId: sessionId,
            outid: check.outid,
            userName: check.name,
            phone: phone,
            devices: devices,
            loginDate: Date()
        )
    }

    private func validateLogin(_ response: [String: Any]) throws {
        let success = response.boolValue("result_") ?? false
        guard success else {
            let code = response.stringValue("code_")
            let message = response.stringValue("message_") ?? "登录失败，请检查账号或密码"
            if code == "5" && message.contains("新设备") {
                throw WMXYError.newDeviceVerification
            }
            throw WMXYError.server(message)
        }
    }

    // MARK: - ① RSA 密钥交换

    private func exchangeSecret() async throws {
        let keys = try WMXYCrypto.generateRSAKeyPair(bits: 1024)
        rsaPrivateKey = keys.privateKey
        let publicKey = try WMXYCrypto.rsaPublicKeySPKIBase64(keys.publicKey)

        let body = try JSONSerialization.data(withJSONObject: ["key": publicKey], options: [])
        var request = URLRequest(url: appBase.appendingPathComponent("exchangeSecretkey.action"))
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json;charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.setValue(uaApp, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = body

        let (data, _) = try await perform(request)
        guard let text = String(data: data, encoding: .utf8) else {
            throw WMXYError.invalidResponse("密钥交换响应无法解析")
        }
        let compact = text.components(separatedBy: .whitespacesAndNewlines).joined()
        guard let cipher = Data(base64Encoded: compact) else {
            throw WMXYError.invalidResponse("密钥交换响应不是合法 Base64")
        }
        guard let plain = WMXYCrypto.rsaDecryptPKCS1(cipher, privateKey: keys.privateKey) else {
            throw WMXYError.crypto("RSA 解密失败，无法取得会话密钥")
        }
        let info = try jsonObject(plain)
        guard let session = info.stringValue("session"),
              let key = info.stringValue("key"), key.count >= 24 else {
            throw WMXYError.invalidResponse("会话密钥字段缺失")
        }
        sessionId = session
        appKey = String(key.prefix(24))
        outid = nil
        finalURL = nil
    }

    // MARK: - ② 签名请求

    private func postSigned(path: String, args: [String: Any]) async throws -> [String: Any] {
        guard let sessionId, let appKey else { throw WMXYError.invalidSession }
        guard let argsData = try? JSONSerialization.data(withJSONObject: args, options: []),
              let argsText = String(data: argsData, encoding: .utf8),
              let encrypted = WMXYCrypto.des3EncryptBase64(argsText, key: appKey) else {
            throw WMXYError.crypto("请求参数加密失败")
        }

        let upload: [String: Any] = ["session": sessionId, "data": encrypted]
        let body = try JSONSerialization.data(withJSONObject: upload, options: [])
        let signature = WMXYCrypto.sha256Hex(body)

        var request = URLRequest(url: appBase.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json;charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.setValue(signature, forHTTPHeaderField: "campusSign")
        request.setValue(uaApp, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = body

        let (data, _) = try await perform(request)
        guard !data.isEmpty else { throw WMXYError.invalidResponse("登录接口返回空响应") }
        return try jsonObject(data)
    }

    // MARK: - ③ H5 授权重定向

    private func openH5Session() async throws {
        guard let sessionId else { throw WMXYError.invalidSession }
        clearCookies()

        var components = URLComponents(url: authURL, resolvingAgainstBaseURL: false)
        let pairs: [(String, String)] = [
            ("client_id", clientID),
            ("response_type", "code"),
            ("redirect_uri", h5Base.absoluteString + "/OpenCampus?apply=accessH5New"),
            ("versionnum", String(appVersion)),
            ("customerId", customerCode),
            ("systemType", "Android"),
            ("UAinfo", "wanxiao"),
            ("versioncode", String(versionCode)),
            ("token", sessionId)
        ]
        components?.percentEncodedQuery = pairs
            .map { "\($0.0)=\(WMXYCrypto.strictPercentEncode($0.1))" }
            .joined(separator: "&")
        guard let startURL = components?.url else {
            throw WMXYError.invalidResponse("授权地址构造失败")
        }

        var currentURL = startURL
        // 初始请求 + 最多 8 跳手动重定向；delegate 返回 nil 阻止 URLSession 自动跟随。
        for _ in 0...8 {
            var request = URLRequest(url: currentURL)
            request.httpMethod = "GET"
            request.timeoutInterval = timeout
            request.setValue(uaWeb, forHTTPHeaderField: "User-Agent")
            request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                             forHTTPHeaderField: "Accept")
            request.setValue("zh-CN,zh;q=0.9", forHTTPHeaderField: "Accept-Language")

            let (_, response) = try await perform(request, session: h5Session, allowRedirectStatus: true)
            if let headerFields = response.allHeaderFields as? [String: String] {
                let cookies = HTTPCookie.cookies(withResponseHeaderFields: headerFields, for: currentURL)
                for cookie in cookies {
                    h5Session.configuration.httpCookieStorage?.setCookie(cookie)
                }
            }
            if (300..<400).contains(response.statusCode),
               let location = response.value(forHTTPHeaderField: "Location"),
               !location.isEmpty,
               let next = URL(string: location, relativeTo: currentURL)?.absoluteURL {
                currentURL = next
                continue
            }
            break
        }
        finalURL = currentURL
    }

    // MARK: - ④ loginCheck

    private func loginCheck() async throws -> (outid: String, name: String?) {
        guard let params = extractParams(from: finalURL), !params.isEmpty else {
            throw WMXYError.missingParams
        }

        let body = Data("data=\(WMXYCrypto.strictPercentEncode(params))".utf8)
        var request = URLRequest(url: h5Base.appendingPathComponent("loginCheck"))
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.httpBody = body
        applyH5Headers(to: &request)

        let (data, _) = try await perform(request, session: h5Session)
        guard !data.isEmpty else { throw WMXYError.invalidSession }

        let top = try jsonObject(data)
        guard let resultData = top.stringValue("resultdata"),
              let decrypted = WMXYCrypto.aesECBDecryptBase64(resultData) else {
            throw WMXYError.invalidResponse("loginCheck 返回结构异常")
        }
        let inner = try jsonObject(Data(decrypted.utf8))
        guard let bodyText = inner.stringValue("body"),
              let outer = try? jsonObject(Data(bodyText.utf8)) else {
            throw WMXYError.invalidResponse("loginCheck 密文结构异常")
        }
        let payload = outer.dictionaryValue("data") ?? [:]
        guard let resolved = payload.stringValue("outid"), !resolved.isEmpty else {
            throw WMXYError.invalidResponse("未取得 outid")
        }
        outid = resolved
        return (resolved, payload.stringValue("name"))
    }

    private func extractParams(from url: URL?) -> String? {
        guard let url, let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        if let value = components.queryItems?.first(where: { $0.name == "params" })?.value, !value.isEmpty {
            return value
        }
        guard let fragment = components.fragment, let mark = fragment.firstIndex(of: "?") else { return nil }
        let query = String(fragment[fragment.index(after: mark)...])
        return URLComponents(string: "?" + query)?.queryItems?.first(where: { $0.name == "params" })?.value
    }

    // MARK: - ⑤⑥⑦ H5 业务

    private func postAuth() async throws {
        guard let outid else { throw WMXYError.invalidSession }
        _ = try await invoke(method: "postAuth", requestData: ["userId": outid])
    }

    private func fetchDevices() async throws -> [DoorDevice] {
        guard let outid else { throw WMXYError.invalidSession }
        guard let response = try await invoke(
            method: "pageList",
            requestData: [
                "currentPage": 1,
                "pageSize": 20,
                "userId": outid,
                "status": 0
            ]
        ) else {
            throw WMXYError.invalidSession
        }
        let data = response.dictionaryValue("data") ?? [:]
        let list = data.arrayValue("list") ?? response.arrayValue("list") ?? []
        return list.compactMap(DoorDevice.parse)
    }

    @discardableResult
    func openDoor(_ device: DoorDevice, mode: String = "0") async throws -> String {
        guard outid != nil else { throw WMXYError.invalidSession }
        let requestData: [String: Any] = [
            "deviceId": Int(device.deviceId) ?? device.deviceId,
            "serialNo": device.serialNo,
            "mode": mode
        ]
        guard let response = try await invoke(method: "remotelyOpen", requestData: requestData) else {
            throw WMXYError.server("开门指令未收到服务回执，请确认门锁在线")
        }
        let message = extractMessage(from: response) ?? "开门指令已下发"
        if message.contains("成功") || response.stringValue("code") == "0" {
            return message
        }
        throw WMXYError.server(message)
    }

    func fetchDevicesAfterLogin() async throws -> [DoorDevice] {
        try await fetchDevices()
    }

    private func invoke(method: String, requestData: [String: Any]) async throws -> [String: Any]? {
        var payloadData = requestData
        if let outid, payloadData["outid"] == nil {
            payloadData["outid"] = outid
        }
        if payloadData["customerCode"] == nil {
            payloadData["customerCode"] = customerCode
        }
        let payload: [String: Any] = ["request_data": payloadData, "method": method]

        let json = try JSONSerialization.data(withJSONObject: payload, options: [.withoutEscapingSlashes])
        guard let jsonText = String(data: json, encoding: .utf8) else {
            throw WMXYError.invalidResponse("业务参数序列化失败")
        }
        let milliseconds = Int64((Date().timeIntervalSince1970 * 1000).rounded(.down))
        let plain = jsonText + "&" + String(milliseconds)
        guard let encrypted = WMXYCrypto.aesECBEncryptBase64(plain) else {
            throw WMXYError.crypto("H5 请求加密失败")
        }

        let form = "method=AccessH5&param=\(WMXYCrypto.strictPercentEncode(encrypted))&customercode=\(customerCode)"
        var request = URLRequest(url: h5Base.appendingPathComponent("WXInvokFront"))
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.httpBody = Data(form.utf8)
        applyH5Headers(to: &request)

        let (data, _) = try await perform(request, session: h5Session)
        guard !data.isEmpty else { return nil }
        let top = try jsonObject(data)
        if let bodyText = top.stringValue("body"), !bodyText.isEmpty {
            return try? jsonObject(Data(bodyText.utf8))
        }
        return top
    }

    // MARK: - 请求辅助

    private func applyH5Headers(to request: inout URLRequest) {
        request.setValue(uaWeb, forHTTPHeaderField: "User-Agent")
        request.setValue("application/x-www-form-urlencoded;charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.setValue("https://xqh5.17wanxiao.com", forHTTPHeaderField: "Origin")
        request.setValue(h5Base.absoluteString + "/accessH5New/index.html", forHTTPHeaderField: "Referer")
        request.setValue("com.newcapec.mobile.ncp", forHTTPHeaderField: "X-Requested-With")
        request.setValue("application/json, text/javascript, */*; q=0.01", forHTTPHeaderField: "Accept")
    }

    private func perform(
        _ request: URLRequest,
        session: URLSession = .shared,
        allowRedirectStatus: Bool = false
    ) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw WMXYError.invalidResponse("非 HTTP 响应")
            }
            let validRange = allowRedirectStatus ? (200..<400) : (200..<300)
            guard validRange.contains(http.statusCode) else {
                throw WMXYError.network("HTTP \(http.statusCode)")
            }
            return (data, http)
        } catch let error as WMXYError {
            throw error
        } catch {
            throw WMXYError.network(error.localizedDescription)
        }
    }

    private func jsonObject(_ data: Data) throws -> [String: Any] {
        guard let object = try? JSONSerialization.jsonObject(with: data),
              let dictionary = object as? [String: Any] else {
            throw WMXYError.invalidResponse("JSON 解析失败")
        }
        return dictionary
    }

    private func extractMessage(from response: [String: Any]) -> String? {
        if let data = response.dictionaryValue("data") {
            if let text = data.stringValue("data"), !text.isEmpty { return text }
            if let text = data.stringValue("msg"), !text.isEmpty { return text }
            if let text = data.stringValue("message"), !text.isEmpty { return text }
        }
        if let text = response.stringValue("data"), !text.isEmpty { return text }
        if let text = response.stringValue("msg"), !text.isEmpty { return text }
        if let text = response.stringValue("message"), !text.isEmpty { return text }
        return nil
    }

    private func clearCookies() {
        guard let cookies = HTTPCookieStorage.shared.cookies else { return }
        for cookie in cookies {
            HTTPCookieStorage.shared.deleteCookie(cookie)
        }
    }
}

// MARK: - 阻止自动重定向

private final class RedirectBlockingDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}
