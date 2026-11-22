# DormHome（宿享）iOS 26 视觉与交互设计规范（Gemini Design Spec）

> 本规范定义了 `DormHome` 的完整视觉语言、色彩系统、空间比例、Liquid Glass 材质层级与动效曲线。所有 SwiftUI 视图必须严格遵循本规范的参数与层级，以达到 Apple Home 级别的克制、通透与高级感。

---

## 1. 视觉理念：Apple Home × iOS 26 Liquid Glass

- **克制留白**：拒绝廉价霓虹、重阴影、高饱和渐变堆叠。大面积留白 + 柔和环境光晕 + 精准玻璃折射高光。
- **材质分层原则（防“糊玻璃”）**：
  1. **Layer 0（环境光层）**：全屏 `MeshGradient` 柔和氛围背景，随门锁状态缓慢呼吸与切换色相。
  2. **Layer 1（液态玻璃容器层）**：主控 Hero 卡片、服务瓷砖、顶部状态胶囊，使用 iOS 26 原生 `.glassEffect(.regular, in: ...)` 或 `.glassEffect(.regular.interactive(), in: ...)`，配合 `GlassEffectContainer` 让相邻玻璃元素产生自然融合感。
  3. **Layer 2（前景内容层）**：高对比度主标题、等宽数字（`.monospacedDigit()`）、清晰 SF Symbols，绝不在玻璃上再叠不透明色块破坏通透感。

---

## 2. 精准色彩系统（Dark / Light 双模式）

### 2.1 动态氛围背景色板（3×3 `MeshGradient`）

#### 状态 A：已上锁（Locked — 静谧深海 / 清透晨雾）
- **Dark Mode**:
  - 基底深空黑蓝：`#070B14`, `#0C1426`, `#09111F`
  - 中部微光靛青：`#10203A`, `#162C4E`, `#0F1D36`
  - 底部沉稳墨蓝：`#080D18`, `#0B1322`, `#060911`
- **Light Mode**:
  - 顶部晨雾蓝白：`#EEF4FC`, `#E4EFFC`, `#F2F6FC`
  - 中部冰川微蓝：`#DCEBFA`, `#EAF3FD`, `#E3EEFA`
  - 底部纯净云白：`#F5F7FA`, `#F2F5F9`, `#F7F9FC`

#### 状态 B：开锁中（Unlocking — 流光青蓝 / 琥珀脉冲）
- **Dark Mode**:
  - `#081422`, `#0E2A42`, `#0A1A2E`
  - `#103B56`, `#1A4F6E`, `#12344D`
  - `#07111D`, `#0B1C2D`, `#060D16`
- **Light Mode**:
  - `#E6F5FA`, `#D6EFFA`, `#EBF7FC`
  - `#CCEAF8`, `#E0F4FC`, `#D4EEF9`
  - `#F2F8FB`, `#EEF6FA`, `#F5FAFC`

#### 状态 C：已开锁（Unlocked — 温润翡翠 / 薄荷微光）
- **Dark Mode**:
  - `#061612`, `#0A2920`, `#071C17`
  - `#0E3B2D`, `#144D3B`, `#0C3025`
  - `#05120E`, `#081D16`, `#040D0B`
- **Light Mode**:
  - `#E8F8F1`, `#D9F3E7`, `#EDF9F4`
  - `#CEF0E1`, `#E2F6ED`, `#D6F2E5`
  - `#F3FAF7`, `#EFF8F4`, `#F6FBF9`

### 2.2 语义强调色（Accent Tokens）
| 用途 | Dark Mode | Light Mode | 说明 |
|---|---|---|---|
| **主操作 / 锁芯激活** | `#5AC8FA` → `#0A84FF` | `#007AFF` → `#34AADC` | Apple 系统蓝青渐变 |
| **已开锁 / 在线状态** | `#30D158` | `#28CD41` | Apple Home 翡翠绿 |
| **开锁中 / 警告低电** | `#FF9F0A` | `#FF9500` | 琥珀暖橙 |
| **异常 / 离线** | `#FF453A` | `#FF3B30` | 系统红 |
| **水电服务图标色** | `#FFD60A`（电） / `#64D2FF`（水） | `#F5A623` / `#0A84FF` | 温暖辨识度 |
| **空调服务图标色** | `#64D2FF` | `#007AFF` | 清爽冷暖色 |
| **校园卡图标色** | `#BF5AF2` | `#AF52DE` | 柔和紫 |
| **开门记录图标色** | `#30D158` | `#34C759` | 安全绿 |

---

## 3. 排版与空间节奏（Typography & Spacing）

- **屏幕左右边距**：`20pt`
- **模块垂直间距**：`20pt`
- **服务瓷砖网格间距**：`14pt`（2 列等宽 `GridItem(.flexible(), spacing: 14)`）
- **圆角体系（Continuous Squircle）**：
  - 门锁 Hero 主卡片：`RoundedRectangle(cornerRadius: 34, style: .continuous)`
  - 生活服务瓷砖：`RoundedRectangle(cornerRadius: 24, style: .continuous)`
  - 顶部状态胶囊 & 操作按钮：`Capsule(style: .continuous)`
- **字体层级**：
  - 顶部页面大标题：`system(size: 30, weight: .bold, design: .rounded)`
  - 问候副标题：`system(size: 13, weight: .medium)`，`.secondary`
  - 门锁名称：`system(size: 20, weight: .semibold, design: .rounded)`
  - 门锁状态主文案：`system(size: 15, weight: .medium)`
  - 服务瓷砖核心数值：`system(size: 22, weight: .bold, design: .rounded).monospacedDigit()`
  - 服务瓷砖标题：`system(size: 14, weight: .semibold)`
  - 辅助说明/时间戳：`system(size: 12, weight: .regular)`，`.secondary`

---

## 4. 核心组件精确设计规范

### 4.1 首页顶部栏（Home Header）
- 左侧两行：
  - 上行小字：时间问候语（如 `晚上好 · 3栋 412`）
  - 下行大标题：`宿享`（或当前宿舍名）
- 右侧：`GlassEffectContainer` 内放置精致胶囊按钮：
  - 显示状态小圆点（演示模式为柔和琥珀点，已登录为翡翠绿点）+ 简短文案（`演示模式` 或 用户名/已连接），点击平滑弹出 `LoginSheetView`。

### 4.2 核心门锁主控卡片（`DoorHeroCard` — 视觉焦点）
- 卡片内部 padding：`22pt`，高度自然舒展（约 `330–360pt`），采用 `.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 34, style: .continuous))`。
- **顶部信息行**：
  - 左侧：门锁名称（如 `宿舍主门`）+ 若有多把门锁时带 `chevron.up.chevron.down` 可切换菜单；下方一行小字展示 `在线`（绿点）· 电量图标与百分比（如 `86%`）· 序列号末 4 位。
  - 右侧：刷新按钮（`arrow.clockwise`，带旋转状态）。
- **视觉中心：164pt 液态玻璃核心锁芯圆环（Interactive Lock Orb）**：
  - 外圈：微弱发光呼吸光环（开锁中旋转扫描弧光，已开锁显示 `6s` 自动回锁倒计时圆形进度条 `trim(from: 0, to: progress)`）。
  - 主体：`136pt × 136pt` 圆形液态玻璃交互按钮（`.glassEffect(.regular.interactive(), in: .circle)`），内部叠加极轻的径向高光（随状态呈现蓝/青/翡翠色调）。
  - 中心图标：`44pt` SF Symbol（上锁 `lock.fill` / 开锁中 `lock.rotation` 或脉冲 / 已开锁 `lock.open.fill`），使用 `.contentTransition(.symbolEffect(.replace.magic(fallback: .downUp)))`。
  - 图标下方紧跟简洁状态标签（`轻触开锁` / `正在下发…` / `已开锁 · 5s`）。
  - 点击即触发远程开锁（已开锁时点击可立即复位上锁）。
- **底部双控操作条（Glass Action Bar）**：
  - `GlassEffectContainer(spacing: 12)` 内并排放置两个胶囊按钮：
    - 主按钮（占宽约 62%）：`远程开锁`（`lock.open.fill`），使用 `.buttonStyle(.glassProminent)` 并根据状态 `.tint(...)`（上锁态蓝青色，已开锁态翡翠绿）。
    - 副按钮（占宽约 38%）：`上锁`（`lock.fill`），使用 `.buttonStyle(.glass)`，点击执行状态复位/上锁并记录日志，附带清晰的微提示。
- **底部微状态条**：
  - 单行极简状态提示（如 `登录态已复用 · 3 分钟前` 或 `命令发送成功 · 耗时 1.2s`），无多余边框。

### 4.3 模块化生活服务网格（Apple Home Bento Tiles）
- 分区标题行：左侧 `生活服务`（`17pt semibold`），右侧 `全部 ›` 切换至生活页。
- 2 列网格，每块瓷砖高度约 `122pt`，padding `16pt`，使用 `.glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 24, style: .continuous))`：
  - **左上角**：`36pt × 36pt` 圆形/圆角图标徽章（对应语义色 16% 透明底 + 鲜明 SF Symbol）。
  - **右上角**：极简角标（如 `即将接入` 小胶囊或 `chevron.right` 细箭头）。
  - **左下角**：
    - 上行大字数值（如 `42.8 kWh` / `3 条记录` / `26°C` / `¥128.5`）
    - 下行标题与微副标（如 `水电费查询 · 约可用 14 天`）

### 4.4 动效与触觉反馈规范
- **状态切换弹簧**：`.spring(response: 0.45, dampingFraction: 0.78)`
- **背景色相过渡**：`.easeInOut(duration: 0.85)`
- **触觉反馈序列**：
  - 按下开锁：`UIImpactFeedbackGenerator(style: .medium).impactOccurred()`
  - 开锁成功：`UINotificationFeedbackGenerator().notificationOccurred(.success)`
  - 上锁复位：`UIImpactFeedbackGenerator(style: .light).impactOccurred()`
  - 请求失败：`UINotificationFeedbackGenerator().notificationOccurred(.error)`

### 4.5 底部导航与页面转场
- 原生 iOS 26 悬浮液态玻璃 `TabView`（3 个 Tab：`首页 house.fill`、`生活 square.grid.2x2.fill`、`设置 gearshape.fill`），列表滚动时自然呈现系统玻璃浮层质感。
- 页面二级跳转采用原生 `NavigationStack`，登录弹窗采用 `.sheet` 搭配 `.presentationBackground(.ultraThinMaterial)` 与 `.presentationCornerRadius(32)`。
