# 宿享 · WMXY（完美校园门禁与水电助手）

对完美校园（`com.newcapec.mobile.ncp` v5.8.37）门禁与智能水电（SWAE）接口的协议分析、Python 自动化脚本，以及原生 **iOS** / **Android** 客户端实现。

> 用途：将「远程开门」与「宿舍水电余量查询」轻量化、脚本化，供本人账号、本人门禁与本人宿舍的日常使用及自动化联动（如 ESP32 按钮）。请勿用于非本人设备或批量调用。

---

## 项目组成

| 目录 / 文件 | 说明 | 文档 |
|---|---|---|
| `DormHome/` | **iOS 客户端**（SwiftUI · iOS 26 Liquid Glass · 零第三方依赖） | [DormHome/README.md](DormHome/README.md) |
| `DormHomeAndroid/` | **Android 客户端**（Kotlin · Jetpack Compose · Material 3 Expressive） | [DormHomeAndroid/README.md](DormHomeAndroid/README.md) |
| `wanxiao_door.py` | **Python CLI / 库**，支持账密/短信登录、会话复用与远程开门 | 见下文 |
| `UTILITIES_API.md` | 完美校园智能水电（SWAE）只读接口分析文档 | [UTILITIES_API.md](UTILITIES_API.md) |
| `DESIGN_SPEC.md` | 宿享视觉与交互设计规范 | [DESIGN_SPEC.md](DESIGN_SPEC.md) |
| `tools/` | 抓包流量解密辅助脚本 | — |

---

## 核心能力

- **远程开门**：完整实现 RSA-1024 密钥交换 → 3DES 登录（账密 / 短信 + 新设备风控识别）→ H5 授权重定向 → AES-128-ECB 门锁列表与远程开锁指令下发；支持登录态缓存与自动续登。
- **实时水电查询（SWAE 只读）**：接入 `SWAEServlet`，支持已绑定宿舍自动同步、校区 → 楼栋 → 楼层 → 房间四级联选、剩余电/水量、今日用量、近 7 日交互式趋势图与低余量提醒。
- **本地记录与安全存储**：固定 `deviceId` 避免频繁触发新设备风控；iOS 使用 Keychain、Android 使用 `AndroidKeyStore`（AES-256-GCM）加密保存凭证；本地记录每一次开锁与自动回锁。
- **演示模式**：未登录时默认引导登录，可在设置中手动开启演示模式预览模拟门锁与水电，不触达真实硬件。

---

## 门禁协议链路

```text
① exchangeSecretkey   POST app.17wanxiao.com   RSA-1024 公钥交换 → session + 3DES key
② loginnew            POST app.17wanxiao.com   3DES 加密登录 → token (= session)
③ authorize           GET  open.17wanxiao.com  token 换 accessH5New cookie（手动跟随重定向）
④ loginCheck          POST xqh5.17wanxiao.com  用跳转 URL 中的 params 换 outid
⑤ postAuth            POST xqh5.17wanxiao.com  用户权限初始化
⑥ pageList            POST xqh5.17wanxiao.com  门锁列表（deviceId / sn / 电量 / 模式）
⑦ remotelyOpen        POST xqh5.17wanxiao.com  下发开门指令（mode: "0"）
```

服务端返回 `命令发送成功` 即表示指令已下发，门锁通常 2–5 秒内动作。

### 加密细节速览

1. **RSA-1024 密钥交换**：本地生成 RSA-1024 密钥对，发送 X.509 SPKI Base64 公钥；响应体为 RSA PKCS#1 v1.5 密文，解密得 `session` 与 `key`（取前 24 字节作为 3DES 密钥）。
2. **3DES-CBC 登录**：密码逐 Unicode 字符 3DES-CBC 加密（IV 固定 `66666666`），整体参数再 3DES 加密放入 `data`；请求头 `campusSign` 为实际发送请求体的 SHA-256 小写十六进制。短信登录走 `gainMatrixCaptcha.action` + `registerUsersByTelAndLoginNew.action`（`type: "2"`）。
3. **AES-128-ECB 开门接口**：对 `紧凑 JSON + "&" + 毫秒时间戳` 做 AES-128-ECB + PKCS#7 加密，严格 RFC 3986 百分号编码后提交至 `WXInvokFront`。

---

## Python 脚本使用

```bash
pip install -r requirements.txt

# 账密登录，查看设备列表
python wanxiao_door.py 手机号 密码

# 登录并开门（第一台设备）
python wanxiao_door.py 手机号 密码 --open

# 指定门锁 / 强制重新登录
python wanxiao_door.py 手机号 密码 --open --device 647
python wanxiao_door.py 手机号 密码 --fresh

# 新设备首次登录（短信验证码）
python wanxiao_door.py 手机号 --sms
```

首次运行会在同目录生成 `.wanxiao_state.json` 保存 `deviceId` 与 `session` 缓存（已在 `.gitignore` 忽略），请勿提交到仓库。

```python
from wanxiao_door import WanxiaoDoor

door = WanxiaoDoor("手机号")
door.connect(password="******")
devices = door.list_devices()["data"]["list"]
door.open_door(devices[0]["deviceId"], devices[0]["sn"])
```

---

## ESP32 移植与抓包参考

- **ESP32 移植**：mbedtls 原生提供 RSA-1024、SPKI DER、3DES-CBC、SHA-256、AES-128-ECB。建议将 RSA 密钥对与 `session` 缓存进 NVS，NTP 对时后复用 ③–⑦ 链路以缩短开门耗时。
- **抓包复现**：在已 root 的 Android 12 模拟器（如 MuMu 12）中将 mitmproxy 根证书挂载为系统证书，设置代理后使用 `tools/decrypt_flows.py` 解密 H5 请求。

---

## 免责声明

仅供学习与个人自动化使用。请只登录本人账号、操作本人有权限的门禁设备，并遵守学校门禁与宿舍管理规定。
