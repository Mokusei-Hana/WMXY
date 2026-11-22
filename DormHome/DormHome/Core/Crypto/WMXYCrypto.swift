//
//  WMXYCrypto.swift
//  DormHome
//
//  完美校园协议所需的密码学原语。
//  与 wanxiao_door.py 保持字节级一致：
//  - 3DES-CBC / PKCS#7，IV = "66666666"
//  - AES-128-ECB / PKCS#7，Key = "r8xRjp877LzkoVUt"
//  - SHA-256 小写十六进制
//  - RSA-1024 PKCS#1 v1.5，公钥以 X.509 SubjectPublicKeyInfo 导出
//

import Foundation
import CryptoKit
import CommonCrypto
import Security

enum WMXYCrypto {

    // MARK: - 常量

    static let desIV = "66666666"
    static let h5AESKey = "r8xRjp877LzkoVUt"

    // MARK: - 3DES-CBC

    /// 3DES-CBC + PKCS#7，输出 Base64（与 Python `des3_encrypt` 一致）。
    static func des3EncryptBase64(_ plaintext: String, key: String, iv: String = desIV) -> String? {
        guard let data = plaintext.data(using: .utf8),
              let encrypted = des3Crypt(CCOperation(kCCEncrypt), data: data, key: key, iv: iv) else {
            return nil
        }
        return encrypted.base64EncodedString()
    }

    /// 3DES-CBC + PKCS#7，输入 Base64（与 Python `des3_decrypt` 一致）。
    static func des3DecryptBase64(_ base64: String, key: String, iv: String = desIV) -> String? {
        guard let data = Data(base64Encoded: base64),
              let decrypted = des3Crypt(CCOperation(kCCDecrypt), data: data, key: key, iv: iv) else {
            return nil
        }
        return String(data: decrypted, encoding: .utf8)
    }

    private static func des3Crypt(_ operation: CCOperation, data: Data, key: String, iv: String) -> Data? {
        let keyBytes = Array(key.utf8.prefix(24))
        let ivBytes = Array(iv.utf8.prefix(8))
        guard keyBytes.count == 24, ivBytes.count == 8, !data.isEmpty else { return nil }

        var output = Data(count: data.count + kCCBlockSize3DES)
        var moved = 0
        let capacity = output.count
        let status: CCCryptorStatus = keyBytes.withUnsafeBytes { keyPtr in
            ivBytes.withUnsafeBytes { ivPtr in
                data.withUnsafeBytes { inputPtr in
                    output.withUnsafeMutableBytes { outputPtr in
                        CCCrypt(
                            operation,
                            CCAlgorithm(kCCAlgorithm3DES),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyPtr.baseAddress, keyBytes.count,
                            ivPtr.baseAddress,
                            inputPtr.baseAddress, data.count,
                            outputPtr.baseAddress, capacity,
                            &moved
                        )
                    }
                }
            }
        }
        guard status == kCCSuccess else { return nil }
        output.count = moved
        return output
    }

    // MARK: - AES-128-ECB

    /// AES-128-ECB + PKCS#7，输出 Base64（与 Python `aes_ecb_encrypt_b64` 一致）。
    static func aesECBEncryptBase64(_ plaintext: String, key: String = h5AESKey) -> String? {
        guard let data = plaintext.data(using: .utf8),
              let encrypted = aesECBCrypt(CCOperation(kCCEncrypt), data: data, key: key) else {
            return nil
        }
        return encrypted.base64EncodedString()
    }

    /// AES-128-ECB + PKCS#7，输入 Base64（与 Python `aes_ecb_decrypt_b64` 一致）。
    static func aesECBDecryptBase64(_ base64: String, key: String = h5AESKey) -> String? {
        guard let data = Data(base64Encoded: base64),
              let decrypted = aesECBCrypt(CCOperation(kCCDecrypt), data: data, key: key) else {
            return nil
        }
        return String(data: decrypted, encoding: .utf8)
    }

    private static func aesECBCrypt(_ operation: CCOperation, data: Data, key: String) -> Data? {
        let keyBytes = Array(key.utf8)
        guard keyBytes.count == kCCKeySizeAES128, !data.isEmpty else { return nil }

        var output = Data(count: data.count + kCCBlockSizeAES128)
        var moved = 0
        let capacity = output.count
        let status: CCCryptorStatus = keyBytes.withUnsafeBytes { keyPtr in
            data.withUnsafeBytes { inputPtr in
                output.withUnsafeMutableBytes { outputPtr in
                    CCCrypt(
                        operation,
                        CCAlgorithm(kCCAlgorithmAES),
                        CCOptions(kCCOptionPKCS7Padding | kCCOptionECBMode),
                        keyPtr.baseAddress, keyBytes.count,
                        nil,
                        inputPtr.baseAddress, data.count,
                        outputPtr.baseAddress, capacity,
                        &moved
                    )
                }
            }
        }
        guard status == kCCSuccess else { return nil }
        output.count = moved
        return output
    }

    // MARK: - SHA-256

    static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func sha256Hex(_ string: String) -> String {
        sha256Hex(Data(string.utf8))
    }

    // MARK: - URL 编码

    /// RFC 3986 严格百分号编码：只保留 unreserved 字符（A-Z a-z 0-9 - . _ ~）。
    static func strictPercentEncode(_ value: String) -> String {
        let unreserved = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~".utf8)
        var result = ""
        result.reserveCapacity(value.utf8.count * 3)
        for byte in value.utf8 {
            if unreserved.contains(byte) {
                result.append(Character(UnicodeScalar(byte)))
            } else {
                result += String(format: "%%%02X", byte)
            }
        }
        return result
    }

    // MARK: - RSA

    /// 生成临时 RSA 密钥对（不写入 Keychain），默认 1024 位。
    static func generateRSAKeyPair(bits: Int = 1024) throws -> (privateKey: SecKey, publicKey: SecKey) {
        let attributes: [CFString: Any] = [
            kSecAttrKeyType: kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits: bits,
            kSecAttrIsPermanent: false
        ]
        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error),
              let publicKey = SecKeyCopyPublicKey(privateKey) else {
            let message = (error?.takeRetainedValue()).map { CFErrorCopyDescription($0) as String } ?? "RSA 密钥生成失败"
            throw WMXYError.crypto(message)
        }
        return (privateKey, publicKey)
    }

    /// 将 Security 导出的 PKCS#1 `RSAPublicKey` 包装为 X.509 SubjectPublicKeyInfo DER。
    static func subjectPublicKeyInfoDER(pkcs1: Data) -> Data {
        // rsaEncryption OID + NULL
        let algorithmIdentifier = Data([
            0x30, 0x0D,
            0x06, 0x09, 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x01,
            0x05, 0x00
        ])
        // BIT STRING 首字节 0x00 表示无 unused bits
        let bitString = derWrap(tag: 0x03, content: Data([0x00]) + pkcs1)
        return derWrap(tag: 0x30, content: algorithmIdentifier + bitString)
    }

    /// 返回 Base64(X.509 SPKI)，与 Python `RSA.export_key()` 去掉 PEM 头尾后的内容等价。
    static func rsaPublicKeySPKIBase64(_ publicKey: SecKey) throws -> String {
        var error: Unmanaged<CFError>?
        guard let pkcs1 = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
            let message = (error?.takeRetainedValue()).map { CFErrorCopyDescription($0) as String } ?? "导出 RSA 公钥失败"
            throw WMXYError.crypto(message)
        }
        return subjectPublicKeyInfoDER(pkcs1: pkcs1).base64EncodedString()
    }

    /// PKCS#1 v1.5 解密（对应 Python `PKCS1_v1_5.new(key).decrypt`）。
    static func rsaDecryptPKCS1(_ ciphertext: Data, privateKey: SecKey) -> Data? {
        var error: Unmanaged<CFError>?
        guard let plain = SecKeyCreateDecryptedData(privateKey, .rsaEncryptionPKCS1, ciphertext as CFData, &error) else {
            return nil
        }
        return plain as Data
    }

    private static func derWrap(tag: UInt8, content: Data) -> Data {
        var result = Data([tag])
        result.append(derLength(content.count))
        result.append(content)
        return result
    }

    private static func derLength(_ length: Int) -> Data {
        if length < 0x80 {
            return Data([UInt8(length)])
        }
        var bytes: [UInt8] = []
        var value = length
        while value > 0 {
            bytes.insert(UInt8(value & 0xFF), at: 0)
            value >>= 8
        }
        return Data([0x80 | UInt8(bytes.count)] + bytes)
    }
}
