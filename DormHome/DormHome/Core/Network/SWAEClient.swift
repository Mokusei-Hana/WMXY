//
//  SWAEClient.swift
//  DormHome
//
//  完美校园「智能水电（SWAE）」只读客户端。
//
//  端点：POST https://xqh5.17wanxiao.com/smartWaterAndElectricityService/SWAEServlet
//  只实现查询能力，不包含 bindroom / unbindroom / placeorder / 控电等写操作。
//

import Foundation

final class SWAEClient {

    // MARK: - 常量

    static let customerCode = "2502"
    static let command = "JBSWaterElecService"
    static let systemName = "物联网水电管理系统"

    private let endpoint = URL(
        string: "https://xqh5.17wanxiao.com/smartWaterAndElectricityService/SWAEServlet"
    )!
    private let timeout: TimeInterval = 30
    private let userAgent = "Mozilla/5.0 (Linux; Android 14; wv) AppleWebKit/537.36 "
        + "(KHTML, like Gecko) Version/4.0 Chrome/127.0.0.0 Mobile Safari/537.36 Wanxiao/5.8.6"

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - 房间绑定

    /// getbindroom：完整兼容 existflag = 0 / 1 / 2。
    func fetchBoundRooms(account: String) async throws -> [SWAERoomSummary] {
        let inner = try await invoke(
            cmd: "getbindroom",
            payload: ["timestamp": Self.millisecondTimestamp()],
            account: account
        )
        return SWAEParsing.boundRooms(from: inner)
    }

    /// h5_getstuindexpage：单房间详情、剩余量、今日用量与近 7 日趋势。
    func fetchRoomDetail(roomverify: String, account: String) async throws -> SWAERoomDetail {
        let inner = try await invoke(
            cmd: "h5_getstuindexpage",
            payload: [
                "roomverify": roomverify,
                "timestamp": Self.timestamp17()
            ],
            account: account
        )
        guard let detail = SWAEParsing.detail(
            from: inner,
            requestedVerify: roomverify,
            fetchedAt: Date()
        ) else {
            throw WMXYError.invalidResponse("水电详情为空，房间可能尚未绑定表计")
        }
        return detail
    }

    /// 手动选房：级联接口不返回 roomverify 时，按 2502 的已知格式依次只读探测。
    func fetchRoomDetail(
        room: SWAERoomOption,
        zoneID: Int,
        buildID: Int,
        floorID: Int,
        preferredVerify: String? = nil,
        account: String
    ) async throws -> SWAERoomDetail {
        let candidates = SWAERoomVerify.candidates(
            zoneID: zoneID,
            buildID: buildID,
            floorID: floorID,
            room: room,
            preferredVerify: preferredVerify
        )
        guard !candidates.isEmpty else {
            throw WMXYError.server("该房间缺少 roomverify，无法查询水电")
        }

        var lastError: Error?
        for candidate in candidates {
            do {
                return try await fetchRoomDetail(roomverify: candidate, account: account)
            } catch let error as WMXYError {
                lastError = error
                if case .network = error { throw error }
            } catch {
                lastError = error
            }
        }

        if let lastError {
            if let swaeError = lastError as? WMXYError,
               case .server(let message) = swaeError,
               message.contains("接收数据异常") {
                throw WMXYError.server("该房间暂无可读取的水电表计，或尚未在完美校园绑定该房间")
            }
            throw lastError
        }
        throw WMXYError.server("未能读取该房间水电，请确认房间是否存在")
    }

    // MARK: - 级联选房

    func fetchZones(account: String) async throws -> [SWAEZone] {
        let inner = try await invoke(cmd: "getzonelist", account: account)
        return SWAEParsing.zones(from: inner)
    }

    func fetchBuildings(zoneId: Int, account: String) async throws -> [SWAEBuilding] {
        let inner = try await invoke(
            cmd: "getbuildlist",
            payload: ["zoneid": zoneId],
            account: account
        )
        return SWAEParsing.buildings(from: inner)
    }

    func fetchFloors(buildId: Int, account: String) async throws -> [SWAEFloor] {
        let inner = try await invoke(
            cmd: "getfloorlist",
            payload: ["buildid": buildId],
            account: account
        )
        return SWAEParsing.floors(from: inner)
    }

    func fetchRooms(floorId: Int, account: String) async throws -> [SWAERoomOption] {
        let inner = try await invoke(
            cmd: "getroomnumlist",
            payload: ["floorid": floorId],
            account: account
        )
        return SWAEParsing.rooms(from: inner)
    }

    // MARK: - 配置

    func fetchH5Config(account: String) async throws -> SWAEConfig {
        let inner = try await invoke(cmd: "geth5config", account: account)
        return SWAEParsing.config(from: inner)
    }

    // MARK: - 请求与二次解析

    private func invoke(
        cmd: String,
        payload: [String: Any] = [:],
        account: String
    ) async throws -> [String: Any] {
        var body = payload
        body["cmd"] = cmd
        body["account"] = account

        let json = try JSONSerialization.data(
            withJSONObject: body,
            options: [.withoutEscapingSlashes]
        )
        guard let jsonText = String(data: json, encoding: .utf8) else {
            throw WMXYError.invalidResponse("水电参数序列化失败")
        }

        let form = [
            "param=" + WMXYCrypto.strictPercentEncode(jsonText),
            "customercode=" + Self.customerCode,
            "method=" + WMXYCrypto.strictPercentEncode(cmd),
            "command=" + Self.command
        ].joined(separator: "&")

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.httpBody = Data(form.utf8)
        request.setValue(
            "application/x-www-form-urlencoded;charset=UTF-8",
            forHTTPHeaderField: "Content-Type"
        )
        request.setValue("https://xqh5.17wanxiao.com", forHTTPHeaderField: "Origin")
        request.setValue(
            "https://xqh5.17wanxiao.com/userwaterelecmini/index.html",
            forHTTPHeaderField: "Referer"
        )
        request.setValue("com.newcapec.mobile.ncp", forHTTPHeaderField: "X-Requested-With")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue("zh-CN,zh;q=0.9", forHTTPHeaderField: "Accept-Language")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw WMXYError.network(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw WMXYError.invalidResponse("非 HTTP 响应")
        }
        guard (200..<300).contains(http.statusCode) else {
            if http.statusCode == 403 || http.statusCode == 405 {
                throw WMXYError.network("水电服务拒绝请求（HTTP \(http.statusCode)），请检查请求头")
            }
            throw WMXYError.network("水电服务 HTTP \(http.statusCode)")
        }
        guard !data.isEmpty else {
            throw WMXYError.invalidResponse("水电服务返回空响应（可能被 WAF 拦截）")
        }

        guard let top = try? JSONSerialization.jsonObject(with: data),
              let envelope = top as? [String: Any] else {
            throw WMXYError.invalidResponse("水电响应不是合法 JSON")
        }

        if let code = SWAEParsing.int(envelope["code_"]), code != 0 {
            let message = SWAEParsing.string(envelope["message_"])
                ?? "水电服务返回异常（code \(code)）"
            throw WMXYError.server(message)
        }
        guard SWAEParsing.string(envelope["result_"])?.lowercased() == "true" else {
            let message = SWAEParsing.string(envelope["message_"])
                ?? "水电服务返回失败"
            throw WMXYError.server(message)
        }

        let inner: [String: Any]
        if let bodyText = SWAEParsing.string(envelope["body"]),
           let bodyData = bodyText.data(using: .utf8),
           let parsed = try? JSONSerialization.jsonObject(with: bodyData),
           let dictionary = parsed as? [String: Any] {
            inner = dictionary
        } else if let dictionary = envelope["body"] as? [String: Any] {
            inner = dictionary
        } else {
            throw WMXYError.invalidResponse("水电响应 body 解析失败")
        }

        let result = SWAEParsing.string(inner["result"]) ?? "0"
        guard result == "0" else {
            let message = SWAEParsing.string(inner["message"])
                ?? SWAEParsing.string(envelope["message_"])
                ?? "水电业务返回失败（result \(result)）"
            throw WMXYError.server(message)
        }
        return inner
    }

    // MARK: - 时间戳

    /// 17 位：yyyyMMddHHmmss000，按服务端所在的中国时区生成。
    static func timestamp17(now: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
        formatter.dateFormat = "yyyyMMddHHmmss"
        return formatter.string(from: now) + "000"
    }

    static func millisecondTimestamp(now: Date = Date()) -> String {
        String(Int64((now.timeIntervalSince1970 * 1000).rounded(.down)))
    }
}
