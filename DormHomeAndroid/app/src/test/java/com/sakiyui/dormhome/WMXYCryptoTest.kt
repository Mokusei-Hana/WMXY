package com.sakiyui.dormhome

import com.sakiyui.dormhome.core.crypto.WMXYCrypto
import com.sakiyui.dormhome.core.network.SWAEParsing
import com.sakiyui.dormhome.core.network.SWAERoomOption
import com.sakiyui.dormhome.core.network.SWAERoomVerify
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.security.KeyFactory
import java.security.spec.X509EncodedKeySpec
import java.util.Base64
import javax.crypto.Cipher

class WMXYCryptoTest {

    @Test
    fun des3RoundTripAndDeterministic() {
        val key = "123456789012345678901234"
        val enc = WMXYCrypto.des3EncryptBase64("hello-wanxiao", key)
        assertNotNull(enc)
        val dec = WMXYCrypto.des3DecryptBase64(enc!!, key)
        assertEquals("hello-wanxiao", dec)
    }

    @Test
    fun aesEcbRoundTrip() {
        val sample = """{"request_data":{"deviceId":647,"mode":"0"},"method":"remotelyOpen"}&1700000000000"""
        val enc = WMXYCrypto.aesECBEncryptBase64(sample)
        assertNotNull(enc)
        val dec = WMXYCrypto.aesECBDecryptBase64(enc!!)
        assertEquals(sample, dec)
    }

    @Test
    fun sha256MatchesStandardVector() {
        assertEquals(
            "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824",
            WMXYCrypto.sha256Hex("hello")
        )
    }

    @Test
    fun rsa1024SpkiAndPkcs1Decrypt() {
        val kp = WMXYCrypto.generateRSAKeyPair(1024)
        val spkiB64 = WMXYCrypto.rsaPublicKeySPKIBase64(kp.public)
        val decodedPub = KeyFactory.getInstance("RSA")
            .generatePublic(X509EncodedKeySpec(Base64.getDecoder().decode(spkiB64)))

        val secretJson = """{"session":"abc-123","key":"0123456789abcdef0123456789"}"""
        val encryptCipher = Cipher.getInstance("RSA/ECB/PKCS1Padding")
        encryptCipher.init(Cipher.ENCRYPT_MODE, decodedPub)
        val cipherBytes = encryptCipher.doFinal(secretJson.toByteArray(Charsets.UTF_8))

        val plainBytes = WMXYCrypto.rsaDecryptPKCS1(cipherBytes, kp.private)
        assertNotNull(plainBytes)
        assertEquals(secretJson, String(plainBytes!!, Charsets.UTF_8))
    }

    @Test
    fun strictPercentEncodeFollowsRfc3986() {
        assertEquals("abc-._~123%2B%2F%3D%26", WMXYCrypto.strictPercentEncode("abc-._~123+/=&"))
    }

    @Test
    fun swaeParsingHandlesMixedTypes() {
        val raw = Json.parseToJsonElement(
            """
            {
              "roomverify": "1-2--3-412",
              "roomfullname": "3栋412",
              "modlist": [
                {
                  "devicename": "DDS1354电表",
                  "mac": "AA11",
                  "businesstype": "0",
                  "status": 1,
                  "odd": "42.8",
                  "todayuse": 2.4,
                  "weekuselist": [
                    {"date": "2026-11-22", "use": "3.2"},
                    {"date": "2026-11-23", "use": 2.4}
                  ]
                }
              ]
            }
            """.trimIndent()
        ).jsonObject

        val detail = SWAEParsing.detail(raw)
        assertNotNull(detail)
        assertEquals("3栋412", detail!!.roomFullName)
        assertEquals(1, detail.meters.size)
        assertEquals(42.8, detail.meters[0].remaining, 0.001)
        assertEquals(2, detail.meters[0].weekUseList.size)

        val candidates = SWAERoomVerify.candidates(1, 2, 3, SWAERoomOption(412, "412房间"))
        assertTrue(candidates.contains("1-2--3-412"))
    }
}
