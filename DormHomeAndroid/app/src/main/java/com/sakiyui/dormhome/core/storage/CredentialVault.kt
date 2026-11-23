package com.sakiyui.dormhome.core.storage

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.security.KeyStore
import java.util.Base64
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * 使用 AndroidKeyStore AES-256-GCM 加密保存账号密码，对应 iOS Keychain CredentialVault。
 */
class CredentialVault(context: Context) {

    @Serializable
    data class Credentials(
        val phone: String,
        val password: String
    )

    companion object {
        private const val PREFS_NAME = "dormhome.vault.v1"
        private const val KEY_BLOB = "credentials_blob"
        private const val KEY_ALIAS = "com.sakiyui.dormhome.vault.aes"
        private const val ANDROID_KEYSTORE = "AndroidKeyStore"
    }

    private val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    private val json = Json { ignoreUnknownKeys = true }

    fun save(phone: String, password: String) {
        runCatching {
            val plain = json.encodeToString(Credentials(phone, password)).toByteArray(Charsets.UTF_8)
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.ENCRYPT_MODE, getOrCreateSecretKey())
            val iv = cipher.iv
            val encrypted = cipher.doFinal(plain)
            val combined = ByteArray(1 + iv.size + encrypted.size)
            combined[0] = iv.size.toByte()
            System.arraycopy(iv, 0, combined, 1, iv.size)
            System.arraycopy(encrypted, 0, combined, 1 + iv.size, encrypted.size)
            val encoded = Base64.getEncoder().encodeToString(combined)
            prefs.edit().putString(KEY_BLOB, encoded).apply()
        }
    }

    fun load(): Credentials? {
        return runCatching {
            val encoded = prefs.getString(KEY_BLOB, null) ?: return null
            val combined = Base64.getDecoder().decode(encoded)
            if (combined.size < 2) return null
            val ivLen = combined[0].toInt() and 0xFF
            if (combined.size <= 1 + ivLen) return null
            val iv = combined.copyOfRange(1, 1 + ivLen)
            val encrypted = combined.copyOfRange(1 + ivLen, combined.size)

            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.DECRYPT_MODE, getOrCreateSecretKey(), GCMParameterSpec(128, iv))
            val plain = cipher.doFinal(encrypted)
            json.decodeFromString<Credentials>(String(plain, Charsets.UTF_8))
        }.getOrNull()
    }

    fun clear() {
        prefs.edit().remove(KEY_BLOB).apply()
    }

    private fun getOrCreateSecretKey(): SecretKey {
        val keyStore = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
        val existing = keyStore.getKey(KEY_ALIAS, null) as? SecretKey
        if (existing != null) return existing

        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, ANDROID_KEYSTORE)
        val spec = KeyGenParameterSpec.Builder(
            KEY_ALIAS,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
        )
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(256)
            .build()
        generator.init(spec)
        return generator.generateKey()
    }
}
