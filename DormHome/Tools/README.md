# DormHome 密码学自测

本目录用于验证 `WMXYCrypto` 与仓库根目录 `wanxiao_door.py` 的字节级一致性。

## 1. 3DES / AES / SHA-256

在 `DormHome/` 目录下编译测试程序：

```bash
xcrun swiftc -parse-as-library \
  -o /tmp/dormhome-cryptotest \
  Tools/CryptoSelfTest.swift \
  DormHome/Core/Crypto/WMXYCrypto.swift \
  DormHome/Core/Network/WMXYModels.swift \
  -framework Security

/tmp/dormhome-cryptotest
```

输出：

```
3DES=mxoKg4P/MsoLpDcAkzBQSg/IexCn/3KHJZ/XB/we5YHOUG9tCLjWSrq+pro/xXO4Y0xEFH8N3hrouqxX4pGisN5tVkUxWTF1
AES=4zWxD/Qk6+E++SSsGs1L4dCK0QQ/0RGZLL25ZahB/MKjqDazdGqRaXilL/nAMG5W9dKVV5lx2ll+ZN7ufgMiEa5gDecmTOVKOqKH9LgcQO3JE7i5/9fk8g0fYZVsDndDlEF2JzCaKF0b8uKM0veAaFlSfhhMsQdS+Ui5T+utyq0vLaU/ugFyK2klkWwAA2hqEQ2+9/fipczCNDb93SiH3Q==
SHA=06c9df2a849f11a8013aec9d3cc08f69095066cd59b9614797057fac39382e41
ENC=a%2Bb%2Fc%3D%3D%20%E4%B8%AD%E6%96%87
```

安装 `pycryptodome` 后运行 Python 参考实现：

```bash
python3 -m venv /tmp/wmxyvenv
/tmp/wmxyvenv/bin/pip install pycryptodome
/tmp/wmxyvenv/bin/python Tools/crypto_compare.py
```

结果：

```
PY_3DES=mxoKg4P/MsoLpDcAkzBQSg/IexCn/3KHJZ/XB/we5YHOUG9tCLjWSrq+pro/xXO4Y0xEFH8N3hrouqxX4pGisN5tVkUxWTF1
PY_AES=4zWxD/Qk6+E++SSsGs1L4dCK0QQ/0RGZLL25ZahB/MKjqDazdGqRaXilL/nAMG5W9dKVV5lx2ll+ZN7ufgMiEa5gDecmTOVKOqKH9LgcQO3JE7i5/9fk8g0fYZVsDndDlEF2JzCaKF0b8uKM0veAaFlSfhhMsQdS+Ui5T+utyq0vLaU/ugFyK2klkWwAA2hqEQ2+9/fipczCNDb93SiH3Q==
PY_SHA=06c9df2a849f11a8013aec9d3cc08f69095066cd59b9614797057fac39382e41
PY_IV=66666666
```

Swift 与 Python 的 3DES、AES、SHA-256 输出逐字节一致。

## 2. RSA-1024 / X.509 SPKI 互通

```bash
# 1. Swift 生成密钥对：SPKI(Base64) + PKCS#1 私钥
/tmp/dormhome-cryptotest gen /tmp/spki.txt /tmp/private.der

# 2. Python(pycryptodome) 读取 SPKI，PKCS#1 v1.5 加密 JSON → /tmp/cipher.txt
python3 - <<'PY'
import base64
from Crypto.PublicKey import RSA
from Crypto.Cipher import PKCS1_v1_5

spki = base64.b64decode(open("/tmp/spki.txt").read().strip())
pub = RSA.import_key(spki)
payload = b'{"session":"swift-rsa-interop","key":"0123456789abcdefghijklmn-extra"}'
cipher = PKCS1_v1_5.new(pub).encrypt(payload)
open("/tmp/cipher.txt", "w").write(base64.b64encode(cipher).decode())
print("bits:", pub.size_in_bits())
PY

# 3. Swift 使用私钥解密
/tmp/dormhome-cryptotest decrypt /tmp/private.der /tmp/cipher.txt

# 4. OpenSSL 验证 SPKI DER 合法
base64 -D -i /tmp/spki.txt -o /tmp/spki.der
openssl pkey -pubin -inform DER -in /tmp/spki.der -noout -text
```

结果：OpenSSL 识别为 `RSA Public-Key: (1024 bit)`，Python 加密的 JSON 被 Swift 正确解密，SPKI DER 总长 162 字节。
