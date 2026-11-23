package com.sakiyui.dormhome.core.crypto

import java.security.KeyPair
import java.security.KeyPairGenerator
import java.security.MessageDigest
import java.security.PrivateKey
import java.security.PublicKey
import java.util.Base64
import javax.crypto.Cipher
import javax.crypto.spec.IvParameterSpec
import javax.crypto.spec.SecretKeySpec

/**
 * 完美校园协议所需的密码学原语，与 wanxiao_door.py / iOS WMXYCrypto.swift 保持字节级一致：
 * - 3DES-CBC / PKCS#7，IV = "66666666"
 * - AES-128-ECB / PKCS#7，Key = "r8xRjp877LzkoVUt"
 * - SHA-256 小写十六进制
 * - RSA-1024 PKCS#1 v1.5，公钥以 X.509 SubjectPublicKeyInfo 导出
 */
object WMXYCrypto {

    const val DES_IV = "66666666"
    const val H5_AES_KEY = "r8xRjp877LzkoVUt"

    // MARK: - 3DES-CBC

    fun des3EncryptBase64(plaintext: String, key: String, iv: String = DES_IV): String? {
        return runCatching {
            val data = plaintext.toByteArray(Charsets.UTF_8)
            if (data.isEmpty()) return null
            val keyBytes = key.toByteArray(Charsets.UTF_8).copyOfRange(0, minOf(24, key.toByteArray(Charsets.UTF_8).size))
            val ivBytes = iv.toByteArray(Charsets.UTF_8).copyOfRange(0, minOf(8, iv.toByteArray(Charsets.UTF_8).size))
            if (keyBytes.size != 24 || ivBytes.size != 8) return null

            val cipher = Cipher.getInstance("DESede/CBC/PKCS5Padding")
            cipher.init(Cipher.ENCRYPT_MODE, SecretKeySpec(keyBytes, "DESede"), IvParameterSpec(ivBytes))
            Base64.getEncoder().encodeToString(cipher.doFinal(data))
        }.getOrNull()
    }

    fun des3DecryptBase64(base64: String, key: String, iv: String = DES_IV): String? {
        return runCatching {
            val data = Base64.getDecoder().decode(base64)
            if (data.isEmpty()) return null
            val keyBytes = key.toByteArray(Charsets.UTF_8).copyOfRange(0, minOf(24, key.toByteArray(Charsets.UTF_8).size))
            val ivBytes = iv.toByteArray(Charsets.UTF_8).copyOfRange(0, minOf(8, iv.toByteArray(Charsets.UTF_8).size))
            if (keyBytes.size != 24 || ivBytes.size != 8) return null

            val cipher = Cipher.getInstance("DESede/CBC/PKCS5Padding")
            cipher.init(Cipher.DECRYPT_MODE, SecretKeySpec(keyBytes, "DESede"), IvParameterSpec(ivBytes))
            String(cipher.doFinal(data), Charsets.UTF_8)
        }.getOrNull()
    }

    // MARK: - AES-128-ECB

    fun aesECBEncryptBase64(plaintext: String, key: String = H5_AES_KEY): String? {
        return runCatching {
            val data = plaintext.toByteArray(Charsets.UTF_8)
            val keyBytes = key.toByteArray(Charsets.UTF_8)
            if (keyBytes.size != 16 || data.isEmpty()) return null

            val cipher = Cipher.getInstance("AES/ECB/PKCS5Padding")
            cipher.init(Cipher.ENCRYPT_MODE, SecretKeySpec(keyBytes, "AES"))
            Base64.getEncoder().encodeToString(cipher.doFinal(data))
        }.getOrNull()
    }

    fun aesECBDecryptBase64(base64: String, key: String = H5_AES_KEY): String? {
        return runCatching {
            val data = Base64.getDecoder().decode(base64)
            val keyBytes = key.toByteArray(Charsets.UTF_8)
            if (keyBytes.size != 16 || data.isEmpty()) return null

            val cipher = Cipher.getInstance("AES/ECB/PKCS5Padding")
            cipher.init(Cipher.DECRYPT_MODE, SecretKeySpec(keyBytes, "AES"))
            String(cipher.doFinal(data), Charsets.UTF_8)
        }.getOrNull()
    }

    // MARK: - SHA-256

    fun sha256Hex(data: ByteArray): String {
        val digest = MessageDigest.getInstance("SHA-256").digest(data)
        val sb = StringBuilder(digest.size * 2)
        for (b in digest) {
            sb.append(String.format("%02x", b.toInt() and 0xFF))
        }
        return sb.toString()
    }

    fun sha256Hex(text: String): String = sha256Hex(text.toByteArray(Charsets.UTF_8))

    // MARK: - RFC 3986 严格百分号编码

    fun strictPercentEncode(value: String): String {
        val bytes = value.toByteArray(Charsets.UTF_8)
        val sb = StringBuilder(bytes.size * 3)
        for (byte in bytes) {
            val c = byte.toInt() and 0xFF
            val isUnreserved = (c in 'A'.code..'Z'.code) ||
                (c in 'a'.code..'z'.code) ||
                (c in '0'.code..'9'.code) ||
                c == '-'.code || c == '.'.code || c == '_'.code || c == '~'.code
            if (isUnreserved) {
                sb.append(c.toChar())
            } else {
                sb.append(String.format("%%%02X", c))
            }
        }
        return sb.toString()
    }

    // MARK: - RSA-1024

    fun generateRSAKeyPair(bits: Int = 1024): KeyPair {
        val generator = KeyPairGenerator.getInstance("RSA")
        generator.initialize(bits)
        return generator.generateKeyPair()
    }

    /** Java RSAPublicKey.encoded 即为 X.509 SubjectPublicKeyInfo DER。 */
    fun rsaPublicKeySPKIBase64(publicKey: PublicKey): String {
        return Base64.getEncoder().encodeToString(publicKey.encoded)
    }

    fun rsaDecryptPKCS1(ciphertext: ByteArray, privateKey: PrivateKey): ByteArray? {
        return runCatching {
            val cipher = Cipher.getInstance("RSA/ECB/PKCS1Padding")
            cipher.init(Cipher.DECRYPT_MODE, privateKey)
            cipher.doFinal(ciphertext)
        }.getOrNull()
    }
}
