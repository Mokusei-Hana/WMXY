# 宿享 · DormHome

一款使用 SwiftUI 与 iOS 26 Liquid Glass 构建的智能宿舍生活 App。默认以演示模式运行，登录完美校园账号后可复用完整协议链路：RSA 密钥交换、3DES 登录、H5 授权、AES 门锁列表与远程开门。

- Deployment Target：iOS 26.0
- Bundle Identifier：`com.sakiyui.dormhome`
- App 显示名：宿享
- 零第三方依赖：SwiftUI、CryptoKit、CommonCrypto、Security、Charts

## 功能

- **门锁 Hero 卡片**：164pt 液态玻璃锁芯、按压/成功/失败触觉反馈、SF Symbol 锁芯动画、开锁中扫描弧光、自动回锁倒计时进度环、远程开锁 / 立即上锁双控。
- **Apple Home Bento 服务网格**：水电费、开门记录、空调控温、校园一卡通四个模块，由 `ModuleRegistry` 驱动，可在设置中开关。
- **水电费页**：已接入完美校园 SWAE 只读水电查询（`SWAEServlet`），支持登录后自动同步绑定宿舍实时电/水余量、近 7 日 `Swift Charts` 用量趋势，以及校区 → 楼栋 → 楼层 → 房间四级联选。
- **开门记录**：按日分组，记录开锁/上锁时间、设备、通道、状态；支持单条删除与清空。
- **演示模式**：首次打开即有一条 3栋 412 门锁（86% 电量）与预置演示记录，不触达真实硬件。
- **账号登录**：账密 / 短信验证码；新设备风控识别与短信切换引导；密码保存在 Keychain；固定设备 ID；会话失效自动续登。
- **外观**：跟随系统 / 浅色 / 深色即时切换，3×3 MeshGradient 氛围背景随门锁状态平滑过渡。
- **生活 Tab**：账单总览 + 服务模块扩展中心；**设置 Tab**：账号、会话、设备 ID、外观、自动回锁时长、模块开关、安全与隐私。

## 目录结构

```
DormHome/
├── DormHome.xcodeproj
├── DormHome/
│   ├── App/
│   │   ├── DormHomeApp.swift
│   │   └── MainTabView.swift
│   ├── Core/
│   │   ├── AppModel/DormAppModel.swift
│   │   ├── Crypto/WMXYCrypto.swift
│   │   ├── Network/WMXYClient.swift
│   │   ├── Network/WMXYModels.swift
│   │   ├── Storage/DormStore.swift
│   │   ├── Modules/DormServiceModule.swift
│   │   └── Theme/{AppTheme,AmbientBackgroundView}.swift
│   ├── Features/
│   │   ├── Home/{HomeView,DoorHeroCard,ServiceTileView}.swift
│   │   ├── Door/UnlockHistoryView.swift
│   │   ├── Utilities/UtilitiesView.swift
│   │   ├── Auth/LoginSheetView.swift
│   │   └── Settings/SettingsView.swift
│   ├── Assets.xcassets/
│   └── PrivacyInfo.xcprivacy
├── Screenshots/
└── Tools/
```

## 构建

```bash
# 本地编译未签名 Release（与 GitHub Actions 一致）
xcodebuild -project DormHome/DormHome.xcodeproj \
  -scheme DormHome \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  AD_HOC_CODE_SIGNING_ALLOWED=NO \
  build
```

工程使用 `PBXFileSystemSynchronizedRootGroup`，`DormHome/DormHome` 下的 Swift 文件与资源自动纳入编译。

## 完美校园协议实现

| 步骤 | 实现 |
|---|---|
| ① `exchangeSecretkey.action` | `SecKeyCreateRandomKey` 生成 RSA-1024；`SecKeyCopyExternalRepresentation` 导出 PKCS#1 并手工封装 X.509 SubjectPublicKeyInfo；PKCS#1 v1.5 解密取得 `session` / `appKey[:24]` |
| ② `loginnew.action` | 密码逐 Unicode 标量 3DES-CBC 加密；参数对象再整体 3DES；对实际发送的 JSON 字节计算 SHA-256 小写十六进制 `campusSign` |
| ③ `authorize` | 独立 `URLSession` + `HTTPCookieStorage`；`URLSessionTaskDelegate` 返回 `nil` 阻止自动重定向，手动最多跟随 8 跳，逐跳携带 `UA_WEB`，兼容相对路径 `Location` |
| ④ `loginCheck` | 从最终 URL query / fragment 中提取 `params`，严格百分号编码 POST；AES-128-ECB 解密双层 JSON 取 `outid` |
| ⑤ `postAuth` / ⑥ `pageList` / ⑦ `remotelyOpen` | AES-128-ECB 加密「紧凑 JSON + `&` + 毫秒时间戳」，严格 RFC 3986 编码 `param`；支持完整门锁列表与 `mode: "0"` 开门 |
| 登录态 | `deviceId`、`session`、`outid`、门锁缓存、历史持久化；失效时自动回落账密重登（Keychain 凭证） |

密码学一致性验证见 [`Tools/README.md`](Tools/README.md)：
3DES、AES、SHA-256 与 `wanxiao_door.py` 输出完全一致；RSA SPKI 可被 OpenSSL 与 Python 识别，跨语言加密/解密互通。

## 截图

浅色与深色模式的首页锁定/开锁、生活、设置、登录等截图位于 [`Screenshots/`](Screenshots/)：

| 文件 | 内容 |
|---|---|
| `01-home-locked-light.png` | 浅色 · 首页已上锁 |
| `02-home-unlocked-light.png` | 浅色 · 首页已开锁（自动回锁倒计时） |
| `03-home-locked-dark.png` | 深色 · 首页已上锁 |
| `04-home-unlocked-dark.png` | 深色 · 首页已开锁 |
| `05-life-dark.png` | 深色 · 生活页 |
| `06-utilities-dark.png` | 深色 · 水电费查询（Swift Charts） |
| `07-settings-dark.png` | 深色 · 设置页 |
| `08-login-dark.png` | 深色 · 登录 Sheet |
| `09-life-light.png` | 浅色 · 生活页 |
| `10-utilities-light.png` | 浅色 · 水电费查询 |
| `11-settings-light.png` | 浅色 · 设置页 |
| `12-login-light.png` | 浅色 · 登录 Sheet |
| `13-history-light.png` | 浅色 · 开门记录 |

## 已知限制

- 真实账号登录与 H5 授权链路已按参考实现完整编写，但仓库不包含可用账号凭证；自动化测试仅验证到服务器接受 `loginnew` 请求并返回业务错误（说明 RSA/SPKI/3DES/campusSign 全链路正确）。
- 水电费、空调、一卡通当前使用本地演示数据，页面中已标注「演示数据 / 即将接入」及预留 API 接入点。
- 宿舍门锁通常自动回锁，App 内「上锁」为状态复位并写入本地日志；若硬件支持远程上锁，可在 `WMXYClient.openDoor` 扩展 `mode`。
- 自动回锁倒计时为演示时长（设置中 10–60 秒），真实门锁的物理回锁时间以硬件为准。

## 免责声明

仅供学习与个人自动化使用。请只登录本人账号、操作本人有权限的门禁设备，并遵守学校门禁管理规定。
