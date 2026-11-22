# 完美校园「开门助手」远程开门

对 App `com.newcapec.mobile.ncp` v5.8.37 的接口分析结果与可用实现。

用途：把「远程开门」这个动作脚本化，供本人账号、本人门禁的自动化使用（例如 ESP32 联动按钮）。
请勿用于非本人门禁或批量调用。

---

## 一、整体链路

```
① exchangeSecretkey   POST app.17wanxiao.com   RSA-1024 公钥交换 → session + 3DES key
② loginnew            POST app.17wanxiao.com   3DES 加密登录 → token(= session)
③ authorize           GET  open.17wanxiao.com  token 换 accessH5New cookie
④ loginCheck          POST xqh5.17wanxiao.com  用跳转 URL 里的 params 换 outid
⑤ postAuth            POST xqh5.17wanxiao.com  用户权限初始化
⑥ pageList            POST xqh5.17wanxiao.com  门锁列表（deviceId / sn / 模式）
⑦ remotelyOpen        POST xqh5.17wanxiao.com  下发开门指令
```

服务端返回 `命令发送成功` 即表示指令已下发，门锁通常 2-5 秒内动作。

---

## 二、加密细节

### 1. 密钥交换（RSA）

客户端本地生成 RSA-1024 密钥对，只把公钥（PEM 去掉头尾、保留 base64 的 SubjectPublicKeyInfo）发过去：

```http
POST /campus/cam_iface46/exchangeSecretkey.action
Content-Type: application/json

{"key": "<base64 公钥>"}
```

响应体是**整段 RSA 密文**（不是 JSON），用自己私钥做 PKCS#1 v1.5 解密后得到：

```json
{"session": "<uuid>", "key": "<24 位 3DES 密钥 + 其它>"}
```

`appKey = key[:24]`，`session` 就是后续的 token。

### 2. 登录（3DES）

- 密码**逐字符**用 3DES-CBC 加密，IV 固定 `66666666`，拼成数组
- 整个参数对象再 3DES 加密一次，放进 `data`
- 请求头 `campusSign` = **对请求体的 SHA-256**（十六进制小写）

```http
POST /campus/cam_iface46/loginnew.action
campusSign: <sha256(body)>
Content-Type: application/json

{"session": "<session>", "data": "<3DES 密文>"}
```

登录参数：

```json
{
  "appCode": "M002",
  "deviceId": "<设备号>",
  "netWork": "wifi",
  "password": ["<逐字符密文>", "..."],
  "qudao": "guanwang",
  "requestMethod": "cam_iface46/loginnew.action",
  "shebeixinghao": "2206122SC",
  "systemType": "android",
  "telephoneInfo": "12",
  "telephoneModel": "2206122SC",
  "type": "1",
  "userName": "<手机号>",
  "wanxiaoVersion": 1050837101
}
```

短信登录走 `gainMatrixCaptcha.action`（发码）+ `registerUsersByTelAndLoginNew.action`（登录），`type` 为 `"2"`，参数换成 `sms` / `mobile`。

### 3. 开门接口（AES）

H5 页面 `accessH5New` 用的是**硬编码 AES-128 密钥 + ECB + PKCS7**，密钥写在页面 JS 里：

```js
key = CryptoJS.enc.Utf8.parse("<16 字节>")
AES ECB / Pkcs7
```

> 注意：`loginCheck` 的请求参数 `data` **不是**这套 AES（解不开），它是 App 在授权跳转时直接塞进 URL 的 `params`，原样透传即可，不需要解密。

请求格式：

```http
POST https://xqh5.17wanxiao.com/keychainService2019/WXInvokFront
Content-Type: application/x-www-form-urlencoded;charset=UTF-8
Cookie: accessH5New=<...>

method=AccessH5&param=<base64 密文>&customercode=2502
```

加密前的明文 = **紧凑 JSON** + `&` + 毫秒时间戳：

```json
{"request_data":{"deviceId":647,"serialNo":"<sn>","mode":"0","outid":"<uid>","customerCode":"2502"},"method":"remotelyOpen"}&手机号48
```

各业务方法：

| method | 说明 | request_data 关键字段 |
|---|---|---|
| `postAuth` | 权限初始化 | `userId`, `outid` |
| `pageList` | 门锁列表 | `currentPage`, `pageSize`, `userId`, `status` |
| `remotelyOpen` | **开门** | `deviceId`, `serialNo`, `mode` |

`mode` 为 `"0"` 时是远程开门；门锁 `supportMode` 字段（如 `"1,2,4"`）表示支持的开锁方式组合。

---

## 三、使用方法

```bash
pip install -r requirements.txt

# 账密登录，只看设备列表
python wanxiao_door.py 手机号 密码

# 登录并开门（第一台设备）
python wanxiao_door.py 手机号 密码 --open

# 指定门锁
python wanxiao_door.py 手机号 密码 --open --device 647

# 新设备首次登录（会触发短信验证）
python wanxiao_door.py 手机号 --sms
```

首次运行会在同目录生成 `.wanxiao_state.json` 保存 `deviceId`。
**务必保留这个文件**：设备号变了会触发「新设备登录」短信验证。

### 作为库调用

```python
from wanxiao_door import WanxiaoDoor

door = WanxiaoDoor("手机号")
door.connect(password="******")
devices = door.list_devices()["data"]["list"]
door.open_door(devices[0]["deviceId"], devices[0]["sn"])
```

---

## 四、已知限制

| 问题 | 说明 |
|---|---|
| **deviceId 绑定** | 换设备号会触发短信验证；脚本用本地文件固定 deviceId |
| **H5 会话不可外部复用** | `accessH5New` cookie 与请求上下文绑定，抓包重放会返回空响应，必须走完整链路 |
| **每次开门都要完整登录** | 目前实现是「登录 → 授权 → 开门」一条龙，约 2-4 秒。若追求速度，可复用 `session`（同一 session 在有效期内可重复走 ③-⑦，无需重新登录） |
| **接口可能变更** | 服务端升级后字段或加密方式可能调整 |

### 提速思路

`session`（token）在有效期内可重复使用，不必每次重新 RSA + 登录。脚本已内置登录态缓存：

- 登录成功后把 `session` 和时间戳写进 `.wanxiao_state.json`
- 下次运行先尝试复用，成功会打印「复用登录态成功（登录于 X 分钟前）」
- 失败自动回落到完整登录
- `--fresh` 可强制重新登录

```bash
python wanxiao_door.py 手机号 密码          # 自动判断复用还是重登
python wanxiao_door.py 手机号 密码 --fresh  # 强制重新登录
```

### 有效期实测参考

| 凭证 | 有效期 | 来源 |
|---|---|---|
| `accessH5New`（H5 会话 cookie） | 30 分钟，每次请求滑动续期 | 响应头 `Max-Age=1800` |
| `acw_tc`（WAF 指纹） | 30 分钟 | 响应头 |
| `olid` | 7 天 | 响应头 `max-age=604800` |
| 登录 `session`（token） | 服务端控制，抓包看不出，靠脚本缓存实测 | — |

`session` 失效的表现：`loginCheck` 返回空响应，或 `authorize` 跳转后拿不到 `params`。脚本会捕获并自动重登。

---

## 五、ESP32 移植要点

需要的密码学原语 mbedtls 全部自带：

| 环节 | mbedtls 接口 |
|---|---|
| RSA-1024 生成 | `mbedtls_rsa_gen_key` |
| 公钥导出（SPKI DER） | `mbedtls_pk_write_pubkey_der` |
| RSA 解密（PKCS#1 v1.5） | `mbedtls_rsa_pkcs1_decrypt` |
| 3DES-CBC | `mbedtls_des3_set3key_enc` + `mbedtls_des3_crypt_cbc` |
| SHA-256 | `mbedtls_sha256` |
| AES-128-ECB | `mbedtls_aes_setkey_enc` + `mbedtls_aes_crypt_ecb` |
| HTTPS | `esp_http_client` + `esp_crt_bundle_attach` |
| JSON | `cJSON` |

注意事项：

1. RSA 密钥对**只需生成一次**，存进 NVS，之后复用（省 1-3 秒）
2. `campusSign` 必须对**实际发送的字节**计算 SHA-256，先拼好 body 再签名
3. Cookie 手动维护，尤其 `accessH5New` 和 WAF 的 `acw_tc`
4. 时间戳是毫秒级，ESP32 需要 NTP 对时
5. 建议把 `session` 也缓存进 NVS，下次只走 ③-⑦

---

## 六、抓包复现方法（自己重新分析用）

1. 模拟器（MuMu 12，Android 12，已 root）装 App 并登录
2. 宿主跑 `mitmdump -p 8080 -w flows.mitm`
3. 把 mitmproxy 根证书装成**系统证书**（Android 12 用 tmpfs 覆盖）：
   ```bash
   adb shell su -c 'mkdir -p /data/local/tmp/cacerts;
     cp /system/etc/security/cacerts/* /data/local/tmp/cacerts/;
     cp /data/local/tmp/<hash>.0 /data/local/tmp/cacerts/;
     mount -t tmpfs tmpfs /system/etc/security/cacerts;
     cp /data/local/tmp/cacerts/* /system/etc/security/cacerts/'
   ```
4. 设备设代理 `10.0.2.2:8080`，打开「开门助手」并执行一次开门
5. 用 `tools/decrypt_flows.py` 解密抓到的 H5 请求

App 本身没有证书固定（SSL Pinning），加固壳也不影响 H5 部分，抓包很顺畅。

---

## 七、免责

仅供学习与个人自动化使用。请只操作本人账号与本人有权限的门禁设备。
