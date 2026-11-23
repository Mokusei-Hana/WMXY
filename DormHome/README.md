# 宿享 · DormHome（iOS）

使用 SwiftUI 与 iOS 26 Liquid Glass 构建的智能宿舍生活 App。未登录时默认引导连接完美校园账号，亦可在设置中手动开启演示模式；登录后完整复用完美校园门禁协议链路与 SWAE 实时水电查询。

- Deployment Target：iOS 26.0
- Bundle Identifier：`com.sakiyui.dormhome`
- App 显示名：宿享
- 零第三方依赖：SwiftUI、CryptoKit、CommonCrypto、Security、Charts

---

## 功能

- **门锁 Hero 卡片**：164pt 液态玻璃锁芯、按压/成功/失败触觉反馈、SF Symbol 锁芯动画、开锁中扫描弧光、自动回锁倒计时进度环、多锁切换、远程开锁 / 立即上锁双控。
- **Apple Home Bento 服务网格**：水电费、开门记录、空调控温、校园一卡通四个模块，由 `ModuleRegistry` 驱动，可在设置中自由开关。
- **实时水电费（SWAE 只读）**：接入 `SWAEServlet`，支持登录后自动同步绑定宿舍实时电/水余量、今日用量、预计可用天数、低余量提醒、近 7 日 `Swift Charts` 可交互趋势图，以及校区 → 楼栋 → 楼层 → 房间四级联选。
- **开门记录**：按日分组记录开锁/上锁时间、设备、通道与状态，支持单条删除与清空。
- **账号与安全**：账密 / 短信验证码双模式登录；新设备风控识别与一键切换短信引导；密码加密保存于系统 Keychain；固定 `deviceId`；会话失效自动续登。
- **演示模式与外观**：未登录时可在设置中手动开启演示模式预览 3栋 412 模拟门锁与水电；支持跟随系统 / 浅色 / 深色即时切换，3×3 `MeshGradient` 氛围背景随门锁状态平滑过渡。

---

## 目录结构

```text
DormHome/
├── DormHome.xcodeproj
├── DormHome/
│   ├── App/
│   │   ├── DormHomeApp.swift
│   │   └── MainTabView.swift
│   ├── Core/
│   │   ├── AppModel/DormAppModel.swift
│   │   ├── Crypto/WMXYCrypto.swift
│   │   ├── Modules/DormServiceModule.swift
│   │   ├── Network/
│   │   │   ├── WMXYClient.swift
│   │   │   ├── WMXYModels.swift
│   │   │   ├── SWAEClient.swift
│   │   │   └── SWAEModels.swift
│   │   ├── Storage/DormStore.swift
│   │   └── Theme/{AppTheme,AmbientBackgroundView}.swift
│   ├── Features/
│   │   ├── Auth/LoginSheetView.swift
│   │   ├── Door/UnlockHistoryView.swift
│   │   ├── Home/{HomeView,DoorHeroCard,ServiceTileView}.swift
│   │   ├── Settings/SettingsView.swift
│   │   └── Utilities/{UtilitiesView,RoomPickerSheetView}.swift
│   ├── Assets.xcassets/
│   └── PrivacyInfo.xcprivacy
├── Screenshots/
└── Tools/
```

---

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

---

## 完美校园协议实现

| 步骤 | 实现 |
|---|---|
| ① `exchangeSecretkey.action` | `SecKeyCreateRandomKey` 生成 RSA-1024；导出 PKCS#1 并手工封装 X.509 SPKI；PKCS#1 v1.5 解密取得 `session` / `appKey[:24]` |
| ② `loginnew.action` | 密码逐 Unicode 标量 3DES-CBC 加密；参数对象再整体 3DES；对实际发送的 JSON 字节计算 SHA-256 小写十六进制 `campusSign` |
| ③ `authorize` | 独立 `URLSession` + `HTTPCookieStorage`；手动最多跟随 8 跳重定向，逐跳携带 `UA_WEB`，兼容相对路径 `Location` |
| ④ `loginCheck` | 从最终 URL query / fragment 提取 `params`，严格百分号编码 POST；AES-128-ECB 解密双层 JSON 取 `outid` |
| ⑤–⑦ `postAuth` / `pageList` / `remotelyOpen` | AES-128-ECB 加密「紧凑 JSON + `&` + 毫秒时间戳」，严格 RFC 3986 编码 `param` |
| SWAE 水电 | `SWAEServlet` 只读查询：`getbindroom`、`h5_getstuindexpage`、四级级联选房、`geth5config` |

密码学一致性验证见 [`Tools/README.md`](Tools/README.md)。

---

## 截图

浅色与深色模式截图位于 [`Screenshots/`](Screenshots/)：

| 文件 | 内容 |
|---|---|
| `01-home-locked-light.png` / `03-home-locked-dark.png` | 浅色 / 深色 · 首页已上锁 |
| `02-home-unlocked-light.png` / `04-home-unlocked-dark.png` | 浅色 / 深色 · 首页已开锁（自动回锁倒计时） |
| `09-life-light.png` / `05-life-dark.png` | 浅色 / 深色 · 生活页 |
| `10-utilities-light.png` / `06-utilities-dark.png` | 浅色 / 深色 · 水电费查询（Swift Charts） |
| `11-settings-light.png` / `07-settings-dark.png` | 浅色 / 深色 · 设置页 |
| `12-login-light.png` / `08-login-dark.png` | 浅色 / 深色 · 登录 Sheet |
| `13-history-light.png` | 浅色 · 开门记录 |

---

## 已知限制

- 空调控温与校园一卡通当前为扩展占位模块，待后续接入真实接口。
- 宿舍门锁通常自动回锁，App 内「上锁」为状态复位并写入本地日志；自动回锁倒计时（10–60 秒）仅作界面状态提示，物理回锁时间以硬件为准。

---

## 免责声明

仅供学习与个人自动化使用。请只登录本人账号、操作本人有权限的门禁设备，并遵守学校门禁管理规定。
