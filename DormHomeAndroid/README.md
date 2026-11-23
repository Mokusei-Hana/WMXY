# 宿享 · DormHome（Android）

使用 Kotlin、Jetpack Compose 与 Material 3 构建的智能宿舍生活 Android 客户端。功能与 iOS 版 `DormHome` 100% 对齐，UI 面向安卓重新设计为 **Material 3 Expressive + 动态氛围光背景** 风格。

- Min SDK：26（Android 8.0）
- Target / Compile SDK：35
- Application ID：`com.sakiyui.dormhome`
- App 显示名：宿享
- 技术栈：Kotlin 2.1 · Jetpack Compose · Material 3 · OkHttp 4 · Kotlinx Serialization · Coroutines

---

## 功能

- **门锁主控卡片**：中心触控锁芯圆盘（锁定呼吸光环、开锁中扫描弧光、已开锁倒计时进度环与脉冲扩散）、触觉反馈、多门锁下拉切换、电量/在线状态、远程开锁 / 立即上锁双控。
- **动态氛围背景与主题**：支持跟随系统 / 浅色 / 深色三态即时切换（同步适配系统状态栏与导航栏图标反色），背景氛围光随门锁「已上锁 / 开锁中 / 已开锁」平滑切换色相。
- **Bento 生活服务网格**：水电费、开门记录、空调控温、校园一卡通四个模块，由 `ModuleRegistry` 驱动，可在设置中自由开关。
- **实时水电费（SWAE 只读）**：接入 `SWAEServlet`，支持绑定宿舍自动同步、校区 → 楼栋 → 楼层 → 房间四级联选弹窗、多表计切换、自绘可交互滑动/点击的近 7 日平滑贝塞尔曲线图、低余量提醒与资费注脚。
- **开门记录**：按日分组展示开锁/上锁记录与本周统计概览，支持长按单条删除与一键清空。
- **账号与安全**：账密 / 短信验证码双模式登录与新设备风控一键切换引导；密码经 `AndroidKeyStore`（AES-256-GCM）加密存储；固定 `deviceId`；会话失效自动续登；未登录时可在设置中手动开启演示模式。

---

## 目录结构

```text
DormHomeAndroid/
├── settings.gradle.kts
├── build.gradle.kts
├── gradle.properties
├── app/
│   ├── build.gradle.kts
│   └── src/
│       ├── main/
│       │   ├── AndroidManifest.xml
│       │   ├── java/com/sakiyui/dormhome/
│       │   │   ├── MainActivity.kt
│       │   │   ├── core/
│       │   │   │   ├── crypto/WMXYCrypto.kt
│       │   │   │   ├── modules/DormServiceModule.kt
│       │   │   │   ├── network/{WMXYClient,WMXYModels,SWAEClient,SWAEModels}.kt
│       │   │   │   ├── storage/{CredentialVault,DormStore}.kt
│       │   │   │   └── viewmodel/DormAppViewModel.kt
│       │   │   └── ui/
│       │   │       ├── DormHomeRoot.kt
│       │   │       ├── components/AtmosphericComponents.kt
│       │   │       ├── theme/DormTheme.kt
│       │   │       └── screens/
│       │   │           ├── HomeScreen.kt
│       │   │           ├── LoginSheet.kt
│       │   │           ├── UtilitiesScreens.kt
│       │   │           ├── RoomPickerSheet.kt
│       │   │           ├── UnlockHistoryScreen.kt
│       │   │           └── SettingsScreen.kt
│       │   └── res/
│       └── test/java/com/sakiyui/dormhome/WMXYCryptoTest.kt
└── screenshots/
```

---

## 构建与测试

1. 使用 **Android Studio** 直接打开 `DormHomeAndroid/` 目录，Sync 后即可运行到模拟器或真机。
2. 或通过命令行构建与运行单元测试（需 JDK 17/21 与 Android SDK）：

```bash
cd DormHomeAndroid

# 运行密码学与 SWAE 解析单元测试
gradle testDebugUnitTest

# 构建 Debug APK（输出至 app/build/outputs/apk/debug/app-debug.apk）
gradle assembleDebug

# 安装到已连接的模拟器或真机
adb install -r app/build/outputs/apk/debug/app-debug.apk
```

---

## 截图

Android 模拟器实测截图位于 [`screenshots/`](screenshots/)：

| 文件 | 内容 |
|---|---|
| `01_home_initial.png` | 浅色 · 首页未登录引导 |
| `02_login_sheet.png` | 浅色 · 账密/短信登录弹窗 |
| `03_settings.png` / `04_settings_dark.png` | 浅色 / 深色 · 设置页 |
| `05_home_demo_locked_dark.png` | 深色 · 演示模式已上锁 |
| `06_home_demo_unlocked_dark.png` | 深色 · 演示模式已开锁（倒计时进度环） |
| `07_life_demo_dark.png` | 深色 · 生活页与 7 日用电曲线图 |
| `08_history_dark.png` | 深色 · 开门记录（含自动回锁记录） |

---

## 免责声明

仅供学习与个人自动化使用。请只登录本人账号、操作本人有权限的门禁设备，并遵守学校门禁管理规定。
