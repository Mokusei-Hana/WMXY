//
//  CryptoSelfTest.swift
//  DormHome Tools
//
//  在 macOS 上直接编译运行，验证 WMXYCrypto 与 Python 参考实现的字节级对齐。
//  详细命令见同目录 README.md。
//

import Foundation
import Security

@main
struct CryptoSelfTest {
    static func main() throws {
        let arguments = CommandLine.arguments
        let mode = arguments.count > 1 ? arguments[1] : "vectors"

        switch mode {
        case "gen":
            guard arguments.count >= 4 else {
                print("usage: CryptoSelfTest gen <spki.txt> <private.der>")
                return
            }
            let pair = try WMXYCrypto.generateRSAKeyPair(bits: 1024)
            let spki = try WMXYCrypto.rsaPublicKeySPKIBase64(pair.publicKey)
            var error: Unmanaged<CFError>?
            guard let privatePKCS1 = SecKeyCopyExternalRepresentation(pair.privateKey, &error) as Data? else {
                fatalError("private key export failed")
            }
            try spki.write(toFile: arguments[2], atomically: true, encoding: .utf8)
            try privatePKCS1.write(to: URL(fileURLWithPath: arguments[3]))
            print("SPKI_BYTES=\(Data(base64Encoded: spki)!.count)")

        case "decrypt":
            guard arguments.count >= 4 else {
                print("usage: CryptoSelfTest decrypt <private.der> <cipher.b64>")
                return
            }
            let privatePKCS1 = try Data(contentsOf: URL(fileURLWithPath: arguments[2]))
            let cipherB64 = try String(contentsOfFile: arguments[3], encoding: .utf8)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard let cipher = Data(base64Encoded: cipherB64) else {
                fatalError("invalid base64 ciphertext")
            }
            let attributes: [CFString: Any] = [
                kSecAttrKeyType: kSecAttrKeyTypeRSA,
                kSecAttrKeyClass: kSecAttrKeyClassPrivate
            ]
            var error: Unmanaged<CFError>?
            guard let key = SecKeyCreateWithData(privatePKCS1 as CFData, attributes as CFDictionary, &error) else {
                fatalError("private key import failed")
            }
            guard let plain = WMXYCrypto.rsaDecryptPKCS1(cipher, privateKey: key) else {
                fatalError("RSA decrypt failed")
            }
            print(String(data: plain, encoding: .utf8)!)

        default:
            let key = "0123456789abcdefghijklmn"
            let plain = "{\"appCode\":\"M002\",\"password\":\"密码测试\",\"userName\":\"13800000000\"}"
            let aesPlain = "{\"request_data\":{\"deviceId\":647,\"serialNo\":\"SN1234567890\",\"mode\":\"0\",\"outid\":\"abc\",\"customerCode\":\"2502\"},\"method\":\"remotelyOpen\"}&1710000000000"
            let shaInput = "{\"session\":\"sess-123\",\"data\":\"QUJDREVGRw==\"}"

            print("3DES=\(WMXYCrypto.des3EncryptBase64(plain, key: key)!)")
            print("AES=\(WMXYCrypto.aesECBEncryptBase64(aesPlain)!)")
            print("SHA=\(WMXYCrypto.sha256Hex(shaInput))")
            print("ENC=\(WMXYCrypto.strictPercentEncode("a+b/c== 中文"))")
            print("ROUND=\(WMXYCrypto.des3DecryptBase64(WMXYCrypto.des3EncryptBase64(plain, key: key)!, key: key)!)")
            print("SPKI_HEADER=\(WMXYCrypto.subjectPublicKeyInfoDER(pkcs1: Data([0x30, 0x03, 0x02, 0x01, 0x01])).prefix(19).map { String(format: "%02X", $0) }.joined(separator: " "))")
        }
    }
}
