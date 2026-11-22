# 完美校园 水电费 / 控电 / 房间绑定 接口分析

> 目标：为 `DormHome` 接入「宿舍水电费查询」做准备。
>
> 样本：
> - iOS：`完美校园.ipa`，`Payload/NCP.app`，`CFBundleShortVersionString = 5.8.37`
> - Android：`完美校园.apk`，包名 `com.newcapec.mobile.ncp`
>
> 结论先行：**学生侧水电查询走的是独立于门禁的 SWAE 体系**。
> 查询已绑定房间只需要 `customerCode + 学号/工号`，**不需要 `sessionId`，也不需要 `accessH5New`**。
> 门禁链路里的 `outid` 可以直接复用为水电接口的 `account`。
> 「控电/合闸/断电」不在学生 H5 里，而在运维控制台，需要 `userInfo.type == 1` 的运维权限，普通学生账号不可用。

---

## 0. 核心结论

| 项目 | 结论 | 证据等级 |
|---|---|---|
| 学生水电查询主接口 | `POST https://xqh5.17wanxiao.com/smartWaterAndElectricityService/SWAEServlet` | 已实测 |
| 查询已绑定房间 | `cmd=getbindroom`，参数 `account` | 已实测（空账号返回 `existflag=0`） |
| 查询单房间详情/剩余量 | `cmd=h5_getstuindexpage`，参数 `roomverify + account + timestamp` | 公开文档 + H5 代码 + 端点实测 |
| 查询用量趋势 | `cmd=getusedetail` / `cmd=gettimeusedetail` | H5 代码 + 端点实测 |
| 查询学校/校区/楼栋/楼层/房间 | `getzonelist` / `getbuildlist` / `getfloorlist` / `getroomnumlist` | 已实测 |
| 绑定房间 | `cmd=bindroom`，参数 `zoneid/buildid/floorid/roomnum` | H5 代码确认，未做写操作实测 |
| 解绑房间 | `cmd=unbindroom`，参数 `roomverifylist` | H5 代码确认 |
| 认证方式 | 明文 `SWAEServlet` 读接口**无登录态**；写接口/新版 H5 走 AES 加密 `SWAEEncryptServlet` | 已实测 + H5 代码 |
| 加密方式 | 新版：AES-128-ECB/PKCS7，密钥 = 时间戳 6 位 + 10 位随机串；`loginCheck` 另有固定 AES key | H5 代码 |
| `customerCode = 2502` | 实测可用；返回厦门华厦学院宿舍区（嘉禾苑/鼓浪苑/半月楼/励志楼） | 已实测 + 公开信息比对 |
| `outid` 复用 | 学生 H5 登录后明确执行 `account = outid` | H5 代码 |
| 控电 | 仅运维 H5 `smartwaterandelectricity`，需 `type=1`；学生 H5 无控电命令 | H5 代码 |
| CloudPayment | 旧体系 `getRoom.do / getRoomState.do`，当前用随机 `payProId` 返回「系统繁忙」 | 已实测，判定为遗留/不可靠 |
| 静态包 | IPA 主二进制 FairPlay 加密（`cryptid 1`）；APK dex 被 360 加固壳保护，均无法直接提取 API 字符串 | 已检查 |

---

## 1. 安装包静态分析结果

### 1.1 iOS IPA

- 解压结构：`Payload/NCP.app/`
- 主二进制：`Payload/NCP.app/NCP`，arm64，约 70 MB。
- FairPlay 加密检查：

```text
cmd LC_ENCRYPTION_INFO_64
cmdsize 24
cryptoff 16384
cryptsize 57901056
cryptid 1
```

`cryptid = 1` 表示主二进制仍处于 App Store 加密状态，`strings`/`rg` 无法读取业务字符串。

- 已尝试的搜索：
  - `smartWaterAndElectricityService`、`SWAEServlet`、`CloudPayment`、`waterAndElectricity`
  - `水电`、`电费`、`水费`、`购电`、`控电`、`宿舍`、`剩余电量`
  - `17wanxiao`、`cam_iface46`、`ykt5g`
- 结果：**均无命中**。
- IPA 内没有打包水电 H5 的 `.html/.js` 资源；只有支付/广告/登录等 SDK 资源。
- `Info.plist` 中可见的 URL Scheme 主要是支付相关：
  - `apipay.17wanxiao.com`
  - `newcapecalipay`
  - `newcapecbestpay`
  - `NewcapecWanXiao`
  - 微信 `wx10511c69412a565e`
- 结论：**iOS 端水电业务是远程 H5，不在包内；主二进制加密导致无法做静态接口提取。**

### 1.2 Android APK

- `classes.dex` 约 22.4 MB，但为加固壳：
  - `assets/.jgapp`
  - `assets/libjiagu.so`
  - `assets/libjiagu_vip*.so`
  - `lib/arm64-v8a/libjgdtc.so`（字符串中包含 `attachBaseContext`、`ChangeTopApplication` 等壳特征）
- `classes.dex` 中可读字符串基本是 360 加固加载器，不含业务 API。
- `assets/` 下只有加固文件，没有 H5/JS。
- `resources.arsc` 中只发现：
  - `https://apipay.17wanxiao.com/PayService`
  - 银联/百度等通用 URL
- 中文关键词 `水电/电费/水费/购电/控电/宿舍` 在 `classes.dex`、`resources.arsc` 中均无命中。
- 结论：**Android dex 被加密，无法从静态包提取水电接口；需要动态脱壳或直接分析远程 H5。**

### 1.3 因此采用的替代方法

1. 从公开 H5 入口直接拉取学生端「智能水电」前端代码：
   - `https://xqh5.17wanxiao.com/userwaterelecmini/index.html`
2. 从 H5 JS 中还原命令、参数、加密算法。
3. 用学校代码 `2502` 对只读接口做最小化实测（空账号/假账号，不查询他人数据）。
4. 交叉核对公开文档与开源项目。

---

## 2. 学生侧智能水电（主链路）

### 2.1 服务入口

| 入口 | URL | 用途 |
|---|---|---|
| 学生端新版 H5 | `https://xqh5.17wanxiao.com/userwaterelecmini/index.html` | 我的房间、充值、用量、低电量提醒 |
| 学生端旧版 H5 | `https://xqh5.17wanxiao.com/smartwaterandelectricity/index.html#/login?` | 旧版入口/部分学校 |
| 运维/宿管控制台 | `https://xqh5.17wanxiao.com/smartwaterandelectricity/index.html#/login?` | 房间设备、集中器、控电（需权限） |
| 管理端 H5 | `https://xqh5.17wanxiao.com/userwaterelemanager/index.html` | 告警房间、购电/补贴统计（需权限） |
| 用量分析 H5 | `https://xqh5.17wanxiao.com/energy-analyse/index.html#/` | 用量图表 |

学生端 H5 是 uni-app 打包，主 JS：
- `static/js/index.b36ccd67.js`
- `static/js/chunk-vendors.15518c52.js`

### 2.2 明文 `SWAEServlet`（推荐用于只读查询）

#### 端点

```http
POST https://xqh5.17wanxiao.com/smartWaterAndElectricityService/SWAEServlet
Content-Type: application/x-www-form-urlencoded;charset=UTF-8
```

#### 请求参数

可以放在 **form body**（推荐，避免 URL 过长/编码问题）：

| 字段 | 必填 | 说明 |
|---|---|---|
| `param` | 是 | JSON 字符串，至少包含 `cmd` 和 `account` |
| `customercode` | 是 | 学校代码，本项目为 `2502` |
| `method` | 是 | 与 `param.cmd` 相同 |
| `command` | 否 | 业务命令字，学生端默认 `JBSWaterElecService`；部分学校为 `OWNWaterElecService` |

也可以把上述字段放在 URL query 中（公开文章的做法），服务端同样接受。

#### 推荐 Header

```http
Content-Type: application/x-www-form-urlencoded;charset=UTF-8
User-Agent: Mozilla/5.0 (Linux; Android 14; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/127.0.0.0 Mobile Safari/537.36 Wanxiao/5.8.6
Origin: https://xqh5.17wanxiao.com
Referer: https://xqh5.17wanxiao.com/userwaterelecmini/index.html
X-Requested-With: com.newcapec.mobile.ncp
Accept: */*
```

说明：
- 实测不带 Cookie 也能查询。
- 服务端会下发 WAF Cookie：`acw_tc`（约 30 分钟）、`SERVERID`。使用 `URLSession` 的共享 CookieStorage 即可。
- `Origin/Referer/X-Requested-With` 建议保留，降低 WAF 误判概率。

#### 响应信封

```json
{
  "code_": 0,
  "sign": "A13A1F64F8AB4C42",
  "result_": "true",
  "body": "{\"result\":\"0\",\"message\":\"操作成功\"}",
  "message_": "获取成功！"
}
```

| 字段 | 类型 | 说明 |
|---|---|---|
| `code_` | int | 传输层状态，`0` 表示成功 |
| `result_` | string | `"true"` 表示业务层受理 |
| `body` | string | **JSON 字符串**，需要二次解析 |
| `message_` | string | 服务端消息 |
| `sign` | string | 16 位十六进制响应签名；客户端不需要校验 |

内层 `body.result`：
- `"0"`：业务成功
- 其他字符串/负数：业务失败，读取 `message`

#### 最小请求示例

```bash
curl -sS -X POST \
  -H 'Content-Type: application/x-www-form-urlencoded;charset=UTF-8' \
  -H 'Origin: https://xqh5.17wanxiao.com' \
  -H 'Referer: https://xqh5.17wanxiao.com/userwaterelecmini/index.html' \
  -H 'X-Requested-With: com.newcapec.mobile.ncp' \
  --data-urlencode 'param={"cmd":"getbindroom","account":"00000000"}' \
  --data 'customercode=2502' \
  --data 'method=getbindroom' \
  'https://xqh5.17wanxiao.com/smartWaterAndElectricityService/SWAEServlet'
```

空账号返回（已实测）：

```json
{
  "code_": 0,
  "sign": "A13A1F64F8AB4C42",
  "result_": "true",
  "body": "{\"result\":\"0\",\"ver\":2,\"isshowsubsidy\":\"0\",\"existflag\":\"0\",\"message\":\"操作成功\"}",
  "message_": "获取成功！"
}
```

### 2.3 命令总表（学生侧）

| `cmd` | 用途 | 关键参数 | 是否需登录态 | 证据 |
|---|---|---|---|---|
| `getbindroom` | 查询账号已绑定房间 | `account` | 否 | 已实测 |
| `h5_getstuindexpage` | 单房间详情：剩余量、今日用量、周/月趋势 | `roomverify`, `account`, `timestamp` | 否 | 文档 + H5 代码 + 端点实测 |
| `getusedetail` | 按月查询每日用量 | `roomverify`, `businesstype`, `yearmonth` | 否 | H5 代码 + 端点实测 |
| `gettimeusedetail` | 按日期区间查询每日用量 | `roomverify`, `businesstype`, `startdate`, `enddate` | 否 | H5 代码 + 端点实测 |
| `getzonelist` | 校区/宿舍区列表 | `account`（H5 统一附加） | 否 | 已实测 |
| `getbuildlist` | 楼栋列表 | `zoneid` | 否 | 已实测 |
| `getfloorlist` | 楼层列表 | `buildid` | 否 | 已实测 |
| `getroomnumlist` | 楼层房间列表 | `floorid` | 否 | 已实测 |
| `getroombyaccountnum` | 按房间户号反查房间 | `account_num` | 否 | H5 代码 + 端点实测 |
| `bindroom` | 绑定房间 | `zoneid`, `buildid`, `floorid`, `roomnum` | 未验证（写操作；H5 仅带 `account`） | H5 代码 |
| `unbindroom` | 解绑房间 | `roomverifylist` | 未验证（写操作；H5 仅带 `account`） | H5 代码 |
| `geth5config` | 学校水电配置/菜单/价格提示 | `account` | 否 | 已实测 |
| `getLocalParam` | 获取帮助、支付、管理端 URL | `outid` | 否 | 已实测 |
| `placeorder` | 充值下单 | `txamt`, `subject`, `outid`, `roomverify`, `userid` | 需支付上下文 | H5 代码，未实测 |
| `login` | 运维端登录校验 | `outid` | 是 | H5 代码 + 端点实测 |
| `getbindmsg` | 独立部署模式用户信息 | `userid` | 未验证 | H5 代码 |
| `getPayOrderDetailList` | 旧支付订单查询 | 由支付页面传 | 未验证 | H5 代码 |

> `command` 字段：学生 H5 默认使用 `JBSWaterElecService`。`getbindroom`、`getzonelist` 等明文接口实测不传 `command` 也能成功；`h5_getstuindexpage` 建议带上，值取登录返回的 `command`，缺省用 `JBSWaterElecService`。

### 2.4 `getbindroom`：查询已绑定房间

请求：

```json
{
  "cmd": "getbindroom",
  "account": "<学号或工号>",
  "timestamp": "20261122230000000"
}
```

`timestamp` 可省略；学生 H5 会加 13 位毫秒时间戳。

响应内层 `body`：

```json
{
  "result": "0",
  "ver": 2,
  "isshowsubsidy": "0",
  "existflag": "2",
  "roomlist": [
    {
      "roomfullname": "西区12栋-12619",
      "roomverify": "<zone>-<build>--<floor>-<roomnum>",
      "account_num": "12619",
      "detaillist": [
        {
          "use": "10066.2",
          "odd": "196.86",
          "businesstype": "0",
          "status": "1",
          "sumbuy": "484.6",
          "sumsub": "17994.57"
        }
      ]
    }
  ],
  "message": "操作成功"
}
```

字段说明：

| 字段 | 说明 |
|---|---|
| `existflag` | `"0"` 未绑定；`"1"` 只绑定一个房间（字段在顶层）；`"2"` 绑定多个房间（`roomlist` 数组） |
| `roomfullname` | 房间全名，如 `西区12栋-12619`、`南珠校区_2#空调_6层_29603` |
| `roomverify` | **房间唯一键**，后续详情/用量接口必须使用；由服务端生成，不要自行拼接 |
| `account_num` | 房间户号（部分学校/房间才有） |
| `detaillist` | 该房间下按业务类型拆分的表计 |
| `detaillist[].use` | 已用量 |
| `detaillist[].odd` | **剩余量**（电=度，水=吨；不是金额） |
| `detaillist[].businesstype` | `0` 电；`1` 冷水；`2` 热水/其他 |
| `detaillist[].status` | `1` 通电/开阀；`0` 断电/关阀 |
| `detaillist[].sumbuy` | 自购剩余（部分学校返回） |
| `detaillist[].sumsub` | 补贴剩余（部分学校返回） |

> `existflag=1` 时，顶层会直接带 `roomfullname`、`roomverify`、`detaillist`、`account_num`，而不是 `roomlist`。客户端两种结构都要兼容。

### 2.5 `h5_getstuindexpage`：单房间详情

请求：

```json
{
  "cmd": "h5_getstuindexpage",
  "roomverify": "<getbindroom 返回的 roomverify>",
  "account": "<学号或工号>",
  "timestamp": "20261122230000000"
}
```

`timestamp` 使用 17 位格式：`yyyyMMddHHmmss000`。

响应内层 `body`（节选）：

```json
{
  "result": "0",
  "ver": 3,
  "roomfullname": "西区12栋-12619",
  "roomnum": "12619",
  "roomverify": "<zone>-<build>--<floor>-<roomnum>",
  "isshowsubsidy": "0",
  "subornot": "0,0,0,1,1,0",
  "modlist": [
    {
      "devicename": "电控",
      "mac": 78063,
      "businesstype": 0,
      "status": 1,
      "odd": 232.7,
      "todayuse": 14.8,
      "accode": 51101,
      "ecardacccode": 216,
      "accgroup": 51101,
      "isshowpay": 1,
      "charge_switch": 0,
      "isble": 0,
      "bluopen": 0,
      "blunum": "078063",
      "weekuselist": [
        {
          "date": "09-10",
          "daydate": "09-10",
          "weekday": "星期二",
          "use": 14.8,
          "dayuse": 14.8
        }
      ],
      "monthuselist": [
        { "yearmonth": "2022.06", "monthuse": 585.9 }
      ],
      "sumsub": 17994.57,
      "sumbuy": 484.6,
      "totalamount": 0,
      "expplancount": 0
    }
  ],
  "message": "操作成功"
}
```

关键字段：

| 字段 | 说明 |
|---|---|
| `modlist` | 一个房间可能有多块表：电、冷水、热水、空调 |
| `modlist[].devicename` | `电控`、`电表`、`预付费水表`、`空调` 等 |
| `modlist[].mac` | 表计/模块编号；可用于设备标识 |
| `modlist[].businesstype` | `0` 电；`1` 冷水；`2` 热水/其他 |
| `modlist[].odd` | **剩余量** |
| `modlist[].todayuse` | 今日用量 |
| `modlist[].weekuselist` | 最近 7 天每日用量，字段 `date/daydate/weekday/use/dayuse` |
| `modlist[].monthuselist` | 月度用量，字段 `yearmonth/monthuse` |
| `modlist[].sumsub` / `sumbuy` | 补贴/自购剩余（按学校返回） |
| `modlist[].status` | `1` 通电/开阀；`0` 断电/关阀 |
| `modlist[].accode` | 账户/表计编码；前缀可判断业务类型 |
| `modlist[].isshowpay` | 是否允许充值 |
| `modlist[].charge_switch` | 充值开关 |

`accode` 前缀与业务类型（学生 H5 充值页逻辑）：

| `accode` 前缀 | `businesstype` | 含义 |
|---|---|---|
| `51101` / `51102` | `0` | 电 |
| `51201` / `51202` | `1` | 水 |
| 其他 | `2` | 热水/其他（按学校配置） |

> 空调可能不是独立 `businesstype`，而是 `roomfullname` 里带「空调」的独立房间/表计（公开示例：`南珠校区_2#空调_6层_29603`，`businesstype=0`）。UI 上应结合 `roomfullname`、`devicename`、`accode` 判断，不要只看 `businesstype`。

### 2.6 用量趋势

#### 按月

```json
{
  "cmd": "getusedetail",
  "roomverify": "<roomverify>",
  "businesstype": 0,
  "yearmonth": "2026-11"
}
```

#### 按日期区间

```json
{
  "cmd": "gettimeusedetail",
  "roomverify": "<roomverify>",
  "businesstype": 0,
  "startdate": "2026-11-16",
  "enddate": "2026-11-22"
}
```

H5 解析字段：

```json
{
  "result": "0",
  "sumuse": 123.4,
  "dayuselist": [
    { "date": "2026-11-16", "use": 18.2 },
    { "date": "2026-11-17", "use": 16.9 }
  ]
}
```

- `dayuselist` 中同时兼容 `date/use` 与 `daydate/dayuse`。
- `sumuse` 为区间总用量。
- 该接口为只读；无效 `roomverify` 返回 `接收数据异常: null`，说明参数结构正确但房间不存在。

### 2.7 配置与 URL

#### `geth5config`

请求：

```json
{ "cmd": "geth5config", "account": "<学号或工号>" }
```

`customerCode=2502` 实测返回（节选）：

```json
{
  "result": "0",
  "ver": 3,
  "message": "参数获取成功",
  "data": {
    "system_name": "物联网水电管理系统",
    "h5_user_falg": "1,1,1,1,1,0,1,0,1,0,0",
    "h5_pay_switch": 1,
    "h5_room_pay_type": 0,
    "h5_pay_business": "1,1,1",
    "subOrNot": "0,0,0,1,0,0",
    "open_app_bindroom_num": -1,
    "h5_fixed_charge_d": "0",
    "h5_fixed_d_remind": "…电费收费标准为0.65元/度…购电度数为10的倍数…",
    "h5_fixed_colds_remind": "…冷水费收费标准为1.5元/度…",
    "h5_fixed_hots_remind": "…热水费收费标准为2.5元/度…"
  }
}
```

用途：
- `h5_user_falg`：菜单开关组合，决定「我的房间 / 充值记录 / 退费 / 低电量提醒」等入口是否显示。
- `h5_pay_switch`：是否允许充值。
- `h5_pay_business`：可充值的业务类型。
- `subOrNot`：补贴/自购拆分开关。
- `h5_fixed_*_remind`：学校自定义价格/规则提示，适合直接展示在充值页。

#### `getLocalParam`

请求：

```json
{ "cmd": "getLocalParam", "outid": "<outid>" }
```

`customerCode=2502` 实测返回：

```json
{
  "result": 0,
  "message": "本地数据查询成功",
  "analyseUrl": "https://xqh5.17wanxiao.com/energy-analyse/index.html#/",
  "operationUrl": "https://xqh5.17wanxiao.com/smartwaterandelectricity/index.html#/login?",
  "baseurl": "https://h5cloud.17wanxiao.com:18443",
  "alipayBaseurl": "https://cloudpaygateway.59wanmei.com:8087",
  "userNewUrl": "https://xqh5.17wanxiao.com/userwaterelecmini/index.html",
  "h5_help": "https://xqh5.17wanxiao.com/smartWaterAndElectricityService/help/h5_help.html",
  "userManagerUrl": "https://xqh5.17wanxiao.com/userwaterelemanager/index.html"
}
```

`baseurl` 就是旧支付/CloudPayment 网关的地址。

### 2.8 房间绑定 / 解绑

#### 绑定层级数据

```text
getzonelist  → [{ id, name }]                        校区/宿舍区
getbuildlist → { zoneid } → [{ id, name }]           楼栋
getfloorlist → { buildid } → [{ id, name }]          楼层
getroomnumlist → { floorid } → [{ id, name }]        房间
```

参数示例：

```json
{ "cmd": "getzonelist", "account": "<学号或工号>" }
{ "cmd": "getbuildlist", "zoneid": 102 }
{ "cmd": "getfloorlist", "buildid": 15 }
{ "cmd": "getroomnumlist", "floorid": 104 }
```

#### 按房间户号反查

```json
{ "cmd": "getroombyaccountnum", "account_num": "<房间户号>" }
```

成功时返回 `zoneid`、`buildid`、`floorid`、`room_num` 等字段；H5 再用这些字段调用 `bindroom`。

#### 绑定

```json
{
  "cmd": "bindroom",
  "zoneid": 102,
  "buildid": 15,
  "floorid": 104,
  "roomnum": 101
}
```

> 注意：`getroomnumlist` 返回的 `id` 直接作为 `roomnum`；`getroombyaccountnum` 返回的字段名是 `room_num`（带下划线）。

响应内层会返回：

```json
{
  "result": "0",
  "ver": 3,
  "existflag": "1",
  "roomfullname": "…",
  "roomverify": "…",
  "detaillist": [ … ],
  "account_num": "…"
}
```

#### 解绑

```json
{
  "cmd": "unbindroom",
  "roomverifylist": "<roomverify>"
}
```

`roomverifylist` 从命名看支持多个；H5 当前传单个 `roomverify`。若要支持多选，先按逗号拼接测试。

> **写操作注意**：`bindroom` / `unbindroom` 会修改服务端绑定关系。建议首版只读，房间绑定引导用户去「完美校园」完成；确需内置时，必须二次确认，并只允许操作当前登录账号。

### 2.9 新版加密 `SWAEEncryptServlet`

当前学生 H5 的 `serviceApi` 实际走的是加密端点：

```http
POST https://xqh5.17wanxiao.com/smartWaterAndElectricityService/SWAEEncryptServlet
Content-Type: application/x-www-form-urlencoded
```

#### 请求字段

| 字段 | 说明 |
|---|---|
| `encryptData` | Base64(AES-128-ECB/PKCS7(明文 JSON)) |
| `randomStr` | 10 位随机串，字符集 `0-9A-Z` |
| `timestamp` | 毫秒时间戳字符串 |
| `method` | 命令名，如 `getbindroom` |

#### 加密前的明文

```json
{
  "param": "{\"cmd\":\"getbindroom\",\"account\":\"<学号>\",\"timestamp\":\"<ms>\"}",
  "customercode": "2502",
  "method": "getbindroom",
  "command": "JBSWaterElecService"
}
```

注意 `param` 是**字符串**，不是嵌套对象。

#### 密钥派生

```js
// H5 源码逻辑
function deriveKey(timestamp, randomStr) {
  // 逐位累加后对 8 取模
  let n = 0;
  for (const ch of timestamp) n = (10 * n + parseInt(ch, 10)) % 8;
  const prefix = (n % 2 === 1)
    ? timestamp.substring(0, 6)
    : timestamp.substring(timestamp.length - 6);
  return prefix + randomStr; // 6 + 10 = 16 字符
}
```

- 算法：AES-128-ECB / PKCS7。
- Key：16 个 ASCII 字符，直接作为 16 字节密钥。
- 输出：Base64 密文。

#### 响应

```json
{
  "encryptData": "<base64>",
  "randomStr": "<10 chars>",
  "timestamp": "<ms>"
}
```

客户端用响应里的 `timestamp + randomStr` 重新派生 key，解密 `encryptData`，得到：

```json
{
  "code_": 0,
  "result_": "true",
  "body": "{…}",
  "message_": "获取成功！"
}
```

然后再按 2.2 的信封解析。

#### H5 中的固定 AES key

学生 H5 的 `44b9` 模块还包含两个固定 key：

```text
1234567812345678   // decrypt / 默认 encrypt
1234567887654321   // encrypt(e, true) 时使用
```

它们用于旧参数和登录/跳转数据，**不是** `serviceApi` 的动态 key。

**水电 `loginCheck` 的 `resultdata` 使用 `1234567812345678` 解密**，不是门禁 H5 的 `r8xRjp877LzkoVUt`。本轮已用一个无效 `data` 的响应验证：

```text
明文 = {"result_":"false","message_":"请求错误，验证失败"}
```

因此：

```swift
// 水电 loginCheck
WMXYCrypto.aesECBDecryptBase64(resultdata, key: "1234567812345678")

// 门禁 keychain loginCheck
WMXYCrypto.aesECBDecryptBase64(resultdata, key: WMXYCrypto.h5AESKey)
```

两者不要混用。`WMXYCrypto.aesECBDecryptBase64(_:key:)` 已支持传入自定义 key，可直接复用。

#### 选型建议

| 场景 | 建议 |
|---|---|
| 只读查询（房间、详情、用量） | 优先明文 `SWAEServlet`；已实测稳定、实现简单 |
| 只读接口未来被关闭 | 回退到 `SWAEEncryptServlet` |
| 绑定/解绑/充值 | 按当前 H5 走 `SWAEEncryptServlet`（或对应支付接口）；明文写操作未验证 |
| 登录 `loginCheck` | 固定 key AES，复用现有解密逻辑 |

---

## 3. `customerCode = 2502` 实测数据

### 3.1 学校识别

`customerCode=2502` 调用 `getzonelist` 返回：

```json
[
  { "id": 102, "name": "校内宿舍" },
  { "id": 99,  "name": "嘉禾苑校外宿舍区" }
]
```

`getbuildlist`：

| zoneid | 楼栋 |
|---|---|
| 102 | 半月楼(11)、励志楼(12)、鼓浪苑3号楼(13)、鼓浪苑4号楼(14)、鼓浪苑1号楼(15)、鼓浪苑2号楼(16) |
| 99 | 1号楼(1) ~ 10号楼(10) |

结合公开招生信息中的「鼓浪苑 / 嘉禾苑 / 半月楼 / 励志楼」宿舍区名称，可判断 **`2502` 对应厦门华厦学院**。这只是辅助识别，代码中仍应以登录返回/现有常量为准。

### 3.2 配置

- 系统名称：`物联网水电管理系统`
- 电费提示：`0.65 元/度`，购电度数为 10 的倍数
- 冷水提示：`1.5 元/度`
- 热水提示：`2.5 元/度`
- `h5_pay_switch = 1`（允许充值）
- `open_app_bindroom_num = -1`（不限制绑定数量）

### 3.3 对 DormHome 的意义

- 「水电费」模块可以做成真实的电/水双表卡片。
- 房间选择器可以动态拉取校区→楼栋→楼层→房间，不必硬编码。
- 充值页可直接展示学校价格提示，但**不要自行计算账单金额**；以服务端返回为准。

---

## 4. 控电 / 运维控制台（需权限）

### 4.1 入口与权限门

运维 H5：

```text
https://xqh5.17wanxiao.com/smartwaterandelectricity/index.html#/login?
```

加载流程（H5 源码）：

1. 从 URL query 读取 `params` 或 `customerid/outid/command/schoolname`。
2. 若有 `params`：
   - `POST /smartWaterAndElectricityService/loginCheck`，`data=<params>`
   - 解密 `resultdata`，得到 `outid/customerCode/command/type/schoolname`
3. 调用 `cmd=login`，参数 `outid`。
4. 读取 `userInfo.type`：
   - `type == 1`：进入运维首页 `home-operation`
   - 其他：显示「您暂无权限访问运维服务」

因此：
- **普通学生账号没有控电权限。**
- 即使明文 `SWAEServlet` 暴露了命令，服务端仍会按账号权限/设备归属拦截。
- 不要尝试用他人 `outid` 或管理账号绕过权限。

### 4.2 控电相关命令

| `cmd` | 用途 | 关键参数 |
|---|---|---|
| `modcutsendon` | 对单个模块/房间送电、断电、开阀、关阀 | `manageip`, `modid`, `businesstype`, `flg`, `cutsendtype`, `roomnum`, `linenums`, `username`, `password` |
| `modcutsendbytype` | 按房间类型/集中器/楼层批量控电 | `flag`, `selectid`, `cutsendtype`, `linenums`, `businesstype` |
| `modcutsendtest` | 控电测试 | `manageip`, `businesstype`, `modid`, `roomnum` |
| `getroommodlist` | 查询房间模块列表 | `zoneid`, `buildid`, `floorid`, `roomnum`, `devicetype`, `page_index`, `page_rows`, `linkstatus` |
| `getroommodinfo` | 查询房间电/冷水/热水模块详情 | `zoneid`, `buildid`, `floorid`, `roomnum` |
| `getmodinfo` | 查询单个模块详情 | `modid` |
| `getroommodprop` | 查询模块属性/历史 | `mac`, `devicetype`, `starttime`, `endtime` |
| `getroommoddata` | 查询模块数据 | `mac`, `devicetype`, `starttime`, `endtime` |
| `getroommodcommand` | 查询模块指令记录 | `mac`, `devicetype`, `starttime`, `endtime`, `commandType` |
| `updatedormlinkagestatus` | 启用/关闭宿管联动 | `manageid`, `linkagestatus`, `command` |

### 4.3 `modcutsendon` 参数语义

H5 源码中的状态选项：

```text
电：一般送电 / 一般断电 / 应急送电 / 应急断电
水：一般开阀 / 一般关阀 / 应急开阀 / 应急关阀
```

映射逻辑（从源码推断）：

| 参数 | 值 | 含义 |
|---|---|---|
| `flg` | `0` | 一般操作 |
| `flg` | `1` | 应急操作 |
| `cutsendtype` | `1` | 送电 / 开阀 |
| `cutsendtype` | `0` | 断电 / 关阀 |
| `linenums` | 数组 | 线路号；单相/多路时使用 |
| `username` / `password` | 字符串 | 仅 `userInfo.ver < 2` 的旧版本需要 |

`modcutsendbytype` 的 `flag`：

| `flag` | 含义 | `selectid` |
|---|---|---|
| `0` | 按房间类型 | 房间类型 ID |
| `1` | 按集中器 | 集中器 ID |
| `2` | 按楼层 | `zoneid-buildid-floorid` |

### 4.4 设备类型映射

运维 H5 的 `deviceName` 过滤器：

| `devicetype` | 名称 |
|---|---|
| `0` | 电控 |
| `2` | 电表 |
| `3` | 预付费水表 |
| `4` | 三相电表 |
| `6` | CJ/T188 水表 |
| `7` | DDS1351 电控 |
| `8` | MBUS 预付费水表 |
| `10` | DDSU1354 导轨电表 |
| `242` | NB 水表 |
| `243` | NB 电表 |
| `244` | NB 远传冷水表 |
| `245` | NB 三相电表 |

### 4.5 运维端传输方式

- 大部分命令：`SWAEEncryptServlet`，加密方式与学生端相同，`command` 通常为 `JBSWaterElecService`。
- 部分监控接口：`DataServlet`，form 字段 `param/customercode/method/code/url`，明文 JSON。
- 管理端 `userwaterelemanager` 则直接使用明文 `SWAEServlet`，命令包括：
  - `getalarmroomlist`（告警房间）
  - `getmodinfolist`（模块信息）
  - `getbuytradelist`（购电记录）
  - `getsubtradelist`（补贴记录）
  - `getenergyuselist`（能耗）
  - `getschoolemppage`（学校员工页）

### 4.6 结论

- **控电不是学生侧功能**；没有学校运维授权时不要接入。
- 如果未来确实要接入（例如你是宿管），应先确认账号 `type == 1`，并在服务端权限范围内操作。
- 任何「断电/送电」按钮都必须有二次确认、操作日志和失败回滚提示。

---

## 5. CloudPayment / 旧体系 / 门禁体系

### 5.1 CloudPayment（旧水电缴费）

公开资料中的旧接口：

```http
GET http://h5cloud.17wanxiao.com:8080/CloudPayment/user/getRoom.do
  ?payProId=<订单ID>
  &schoolcode=<学校代码>
  &optype=<1|2|4>
  &areaid=<校区ID>
  &buildid=<楼栋ID>
  &unitid=<单元ID>
  &levelid=<层级ID>
  &businesstype=2
```

`optype`：

| 值 | 用途 |
|---|---|
| `1` | 获取校区信息（`areaid=0, buildid=0, unitid=0, levelid=0`） |
| `2` | 获取楼栋信息（传 `areaid`） |
| `4` | 获取寝室信息（传 `areaid/buildid`，`unitid=0, levelid=-1`） |

查询电费：

```http
GET http://h5cloud.17wanxiao.com:8080/CloudPayment/user/getRoomState.do
  ?payProId=<订单ID>
  &schoolcode=<学校代码>
  &businesstype=2
  &roomverify=<寝室编号>
```

实测（2026-11）：

- 使用随机 `payProId`、`schoolcode=2502/792/11/1631`，端口 `8080` 和 `18443` 均返回：

```text
RspBaseVO [code=ERROR, msg=系统繁忙，请稍后重试, subCode=null, subMsg=null]
```

- 说明该接口很可能需要**真实支付订单上下文**，或已下线/仅部分学校启用。
- `getLocalParam.baseurl` 指向 `https://h5cloud.17wanxiao.com:18443`，说明支付网关仍在，但查询接口不应作为主方案。

**结论：不作为 DormHome 水电查询主接口，仅作为遗留兼容线索。**

### 5.2 `cam_iface46` 门禁体系

现有 `WMXYClient.swift` 的链路：

```text
exchangeSecretkey → loginnew → authorize → loginCheck → postAuth → pageList → remotelyOpen
```

- 域名：`app.17wanxiao.com/campus/cam_iface46`
- H5：`xqh5.17wanxiao.com/keychainService2019`
- 授权：`open.17wanxiao.com/api/authorize`

在静态包、公开资料和本轮 H5 分析中，**没有发现 `cam_iface46` 下的水电查询接口**。门禁和水电是两套独立服务：

| 能力 | 门禁 | 水电 |
|---|---|---|
| 域名 | `app.17wanxiao.com` / `keychainService2019` | `smartWaterAndElectricityService` |
| 登录态 | `sessionId` + `accessH5New` | 读接口无登录态；写接口用 `account` |
| 加密 | RSA + 3DES + AES | 读接口明文；写接口 AES-128-ECB |
| 用户标识 | `outid` | `account`（H5 明确 `account = outid`） |
| 学校代码 | `customerCode` | `customercode` |

### 5.3 水电话 `loginCheck`

学生 H5 的登录路径：

```http
POST https://xqh5.17wanxiao.com/smartWaterAndElectricityService/loginCheck
Content-Type: application/x-www-form-urlencoded

data=<authorize 跳转 URL 中的 params>
```

响应：

```json
{ "resultdata": "<base64 AES 密文>" }
```

解密：
- 算法：AES-128-ECB / PKCS7
- Key：`1234567812345678`（水电 H5 的固定 key；**不是** `r8xRjp877LzkoVUt`）
- 解密后是 JSON，可能再包一层 `body` 字符串
- 返回字段包含 `outid`、`customerCode`、`command`、`token`、`type`、`schoolname` 等

这与门禁 `loginCheck` 的**响应结构**相似，但 key 不同。可直接复用 `WMXYCrypto.aesECBDecryptBase64(_:key:)`，传入水电 key。

### 5.4 授权跳转

门禁现有参数（已实现）：

```text
GET https://open.17wanxiao.com/api/authorize
  ?client_id=75dd569e9b1e4362ab92628eddda0f4b
  &response_type=code
  &redirect_uri=https://xqh5.17wanxiao.com/keychainService2019/OpenCampus?apply=accessH5New
  &versionnum=1050837101
  &customerId=2502
  &systemType=Android
  &UAinfo=wanxiao
  &versioncode=10589101
  &token=<sessionId>
```

水电 H5 的授权跳转**未完全确认**。H5 代码只表明它接受：

- `params` query（优先）
- 或 `code` query + `OpenCampusMini`
- 或直接 `customerid/outid/command/schoolname` query

候选 `redirect_uri`：

```text
https://xqh5.17wanxiao.com/userwaterelecmini/index.html
https://xqh5.17wanxiao.com/smartWaterAndElectricityService/OpenCampus?apply=...
```

由于缺少有效 `sessionId`，本轮无法确认真实跳转后的 `params`。**首版不需要授权跳转**：直接用门禁登录得到的 `outid` 作为 `account` 即可。

---

## 6. 与 DormHome / `WMXYClient.swift` 的复用关系

### 6.1 字段复用

| 现有字段 | 水电用途 | 说明 |
|---|---|---|
| `customerCode = "2502"` | `customercode` | 已实测；建议抽成共享常量 |
| `outid` | `account` | 学生 H5 登录后执行 `account = outid`；若某校 `outid` 不是学号，再让用户手填学号 |
| `sessionId` | 可选 | 只读查询不需要；仅用于换取水电 `params` 或刷新 `outid` |
| `accessH5New` | 不需要 | 门禁 H5 专用；水电读接口不校验 |
| `appKey` | 不需要 | 水电写接口用动态 AES key，不是 3DES `appKey` |
| `phone` | 不需要 | 水电接口用学号/工号，不用手机号 |

### 6.2 建议的 Swift 分层

新增 `DormHome/DormHome/Core/Network/UtilitiesAPI.swift`（或扩展 `WMXYClient`）：

```swift
struct UtilityRoom: Identifiable, Codable, Hashable {
    var roomFullName: String
    var roomVerify: String
    var accountNumber: String?
    var meters: [UtilityMeter]
    var id: String { roomVerify }
}

struct UtilityMeter: Codable, Hashable {
    var businessType: Int      // 0 电, 1 水, 2 热水/其他
    var use: Double
    var remaining: Double      // odd
    var status: Int            // 1 通电/开阀, 0 断电/关阀
    var sumBuy: Double?
    var sumSub: Double?
}

struct UtilityDevice: Identifiable, Codable, Hashable {
    var deviceName: String
    var mac: String
    var businessType: Int
    var remaining: Double
    var todayUse: Double
    var weekly: [UtilityUsagePoint]
    var monthly: [UtilityUsagePoint]
    var status: Int
    var accode: String
    var id: String { mac + "-\(businessType)" }
}
```

接口方法：

```swift
func fetchUtilityRooms(account: String) async throws -> [UtilityRoom]
func fetchUtilityDetail(roomVerify: String, account: String) async throws -> [UtilityDevice]
func fetchUtilityMonthlyUsage(roomVerify: String, businessType: Int, yearMonth: String) async throws -> [UtilityUsagePoint]
func fetchUtilityDailyUsage(roomVerify: String, businessType: Int, start: String, end: String) async throws -> [UtilityUsagePoint]
func fetchUtilityConfig(account: String) async throws -> UtilityConfig
```

### 6.3 明文调用骨架

```swift
private let utilitiesBase = URL(
    string: "https://xqh5.17wanxiao.com/smartWaterAndElectricityService/SWAEServlet"
)!
private let utilityCustomerCode = "2502"
private let utilityCommand = "JBSWaterElecService"

private func utilityInvoke(
    cmd: String,
    payload: [String: Any],
    account: String
) async throws -> [String: Any] {
    var body = payload
    body["cmd"] = cmd
    body["account"] = account
    if body["timestamp"] == nil {
        body["timestamp"] = String(Int(Date().timeIntervalSince1970 * 1000))
    }

    let json = try JSONSerialization.data(withJSONObject: body, options: [.withoutEscapingSlashes])
    guard let jsonText = String(data: json, encoding: .utf8) else {
        throw WMXYError.invalidResponse("水电参数序列化失败")
    }

    let form = [
        "param=" + WMXYCrypto.strictPercentEncode(jsonText),
        "customercode=" + utilityCustomerCode,
        "method=" + WMXYCrypto.strictPercentEncode(cmd),
        "command=" + utilityCommand
    ].joined(separator: "&")

    var request = URLRequest(url: utilitiesBase)
    request.httpMethod = "POST"
    request.timeoutInterval = 30
    request.httpBody = Data(form.utf8)
    request.setValue("application/x-www-form-urlencoded;charset=UTF-8", forHTTPHeaderField: "Content-Type")
    request.setValue("https://xqh5.17wanxiao.com", forHTTPHeaderField: "Origin")
    request.setValue(
        "https://xqh5.17wanxiao.com/userwaterelecmini/index.html",
        forHTTPHeaderField: "Referer"
    )
    request.setValue("com.newcapec.mobile.ncp", forHTTPHeaderField: "X-Requested-With")
    request.setValue("*/*", forHTTPHeaderField: "Accept")

    let (data, response) = try await URLSession.shared.data(for: request)
    guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
        throw WMXYError.network("水电服务 HTTP 异常")
    }

    let top = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    guard top.stringValue("result_") == "true" else {
        throw WMXYError.server(top.stringValue("message_") ?? "水电服务返回失败")
    }
    guard let bodyText = top.stringValue("body"),
          let bodyData = bodyText.data(using: .utf8),
          let inner = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any] else {
        throw WMXYError.invalidResponse("水电响应 body 解析失败")
    }
    guard inner.stringValue("result") == "0" else {
        throw WMXYError.server(inner.stringValue("message") ?? "水电业务返回失败")
    }
    return inner
}
```

解析 `getbindroom`：

```swift
let inner = try await utilityInvoke(cmd: "getbindroom", payload: [:], account: account)
let flag = inner.stringValue("existflag") ?? "0"
if flag == "0" { return [] }

if flag == "1" {
    return [parseRoom(inner)]
}
return (inner.arrayValue("roomlist") ?? []).map(parseRoom)
```

解析 `h5_getstuindexpage`：

```swift
let inner = try await utilityInvoke(
    cmd: "h5_getstuindexpage",
    payload: [
        "roomverify": roomVerify,
        "timestamp": timestamp17()
    ],
    account: account
)
let devices = (inner.arrayValue("modlist") ?? []).compactMap(parseDevice)
```

### 6.4 加密调用骨架（写操作/回退）

现有 `WMXYCrypto` 已经支持 AES-128-ECB，只需补动态 key：

```swift
private func utilityKey(timestamp: String, random: String) -> String {
    var n = 0
    for ch in timestamp {
        guard let d = ch.wholeNumberValue else { continue }
        n = (10 * n + d) % 8
    }
    let prefix = (n % 2 == 1)
        ? String(timestamp.prefix(6))
        : String(timestamp.suffix(6))
    return prefix + random
}

private func randomUtilityString() -> String {
    let alphabet = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ")
    return String((0..<10).map { _ in alphabet.randomElement()! })
}
```

加密请求：

```swift
let ts = String(Int(Date().timeIntervalSince1970 * 1000))
let random = randomUtilityString()
let key = utilityKey(timestamp: ts, random: random)

let container: [String: Any] = [
    "param": jsonText,                 // cmd/account/timestamp 的 JSON 字符串
    "customercode": utilityCustomerCode,
    "method": cmd,
    "command": utilityCommand
]
let plain = try JSONSerialization.data(withJSONObject: container, options: [.withoutEscapingSlashes])
let plainText = String(data: plain, encoding: .utf8)!
let encrypted = WMXYCrypto.aesECBEncryptBase64(plainText, key: key)!

let form = [
    "encryptData=" + WMXYCrypto.strictPercentEncode(encrypted),
    "randomStr=" + random,
    "timestamp=" + ts,
    "method=" + WMXYCrypto.strictPercentEncode(cmd)
].joined(separator: "&")
```

解密响应：

```swift
let responseKey = utilityKey(
    timestamp: top.stringValue("timestamp") ?? "",
    random: top.stringValue("randomStr") ?? ""
)
let plain = WMXYCrypto.aesECBDecryptBase64(
    top.stringValue("encryptData") ?? "",
    key: responseKey
)
```

### 6.5 UI 映射建议

| UI | 数据 |
|---|---|
| 首页「水电费」瓷砖 | 优先展示电表 `odd`；副标题显示 `roomfullname` 或「约可用 N 天」 |
| 水电费页主卡片 | 电/水各一张；`remaining` + 单位（度/吨） |
| 近 7 日趋势 | `h5_getstuindexpage.modlist[].weekuselist` 或 `gettimeusedetail.dayuselist` |
| 月度趋势 | `getusedetail` 或 `monthuselist` |
| 通电状态 | `status == 1`；断电时显示橙色提示 |
| 低电量提醒 | `odd` 低于本地阈值；不要自行预测天数，除非有历史用量 |
| 房间切换 | `getbindroom.roomlist`；`roomfullname` 作为标题 |
| 充值入口 | `isshowpay == 1 && h5_pay_switch == 1`；跳转完美校园或后续接入 `placeorder` |

### 6.6 缓存与错误处理

- 房间列表：缓存 5–10 分钟；进入水电页时后台刷新。
- 房间详情：缓存 2–5 分钟；下拉刷新。
- 用量历史：按 `roomverify + businesstype + 月份` 缓存。
- `existflag=0`：显示「尚未绑定房间」，提供跳转完美校园的说明，不要报错。
- `result=-1000213` / `接收数据异常`：`roomverify` 失效或房间未绑定，提示重新同步房间。
- HTTP 403/405：WAF/方法错误；检查是否 POST、Header 是否完整。
- 空响应：可能是 WAF 拦截或会话问题；重试一次并提示。

---

## 7. 待确认清单

### P0（接真实账号前必须确认）

1. **`outid` 是否等于学号/工号**
   - H5 明确 `account = outid`，但门禁的 `outid` 在部分学校可能是内部 ID。
   - 用真实账号调用 `getbindroom`，看是否能返回房间。
   - 若不能，增加「学号/工号」输入框，默认填 `outid`。

2. **真实房间的 `getbindroom` 结构**
   - 确认 `existflag` 是 `1` 还是 `2`。
   - 确认 `detaillist` 中电/水/热水的 `businesstype` 和 `accode`。
   - 确认 `roomverify` 的实际格式，不要自行拼接。

3. **`h5_getstuindexpage` 的真实返回**
   - 确认 `modlist` 数量与顺序。
   - 确认 `odd` 的单位（电=度、水=吨）。
   - 确认 `status` 的取值（是否只有 0/1）。
   - 确认 `weekuselist` 的日期范围（最近 7 天还是自然周）。

4. **`command` 值**
   - 学校 2502 是 `JBSWaterElecService` 还是 `OWNWaterElecService`。
   - 可从水电话 `loginCheck` 返回的 `command` 读取；首版可用默认值并在失败时回退。

### P1（影响功能完整度）

5. **水电授权跳转的精确 `redirect_uri` / `apply`**
   - 若首版直接使用 `outid`，可暂不实现。
   - 若需要刷新 `outid` 或支持未登录用户，需要补这一环。

6. **`bindroom` / `unbindroom` 的写操作**
   - 是否允许普通学生自助绑定；是否有绑定数量限制。
   - 当前 H5 的写操作走 `SWAEEncryptServlet`；如自行实现，需二次确认并验证服务端是否接受明文写操作。

7. **`businesstype=2` 的含义**
   - 是热水、空调还是其他；不同学校可能不同。
   - 以 `roomfullname`、`devicename`、`accode` 综合判断。

8. **明文 `SWAEServlet` 的生命周期**
   - 当前可用，但新版 H5 已切到加密 `SWAEEncryptServlet`。
   - 建议实现「明文优先、加密回退」，避免未来接口关闭。

### P2（非首版）

9. **CloudPayment `getRoom.do` 的 `payProId` 规则**
   - 随机值返回「系统繁忙」；需要真实订单或已下线。
   - 不建议投入。

10. **控电权限**
    - 学校是否给普通学生/宿管开放 `type=1`。
    - 未授权不要接入 `modcutsendon`。

---

## 8. 安全与合规

- **该读接口目前不校验登录态**：只要知道学校代码和学号，就可能查询到绑定房间与用量。这是服务端的设计问题，不是我们可以利用的授权。
- DormHome 发布版应：
  - 只查询当前登录账号的 `outid`；
  - 不提供「输入任意学号查询」的入口；
  - 不记录/上报学号、房间号、用量等个人信息；
  - 对房间列表和用量做本地缓存时限，避免高频轮询。
- 控电命令属于**特权操作**：
  - 没有学校书面授权，不要实现「远程断电/送电」；
  - 即使有权限，也必须二次确认、记录操作人、展示失败原因。
- 请遵守学校宿舍管理规定和完美校园用户协议；仅用于本人账号、本人房间的查询与自动化。

---

## 9. 附录：实测响应样例

### A. `getzonelist`（customerCode=2502）

```json
{
  "code_": 0,
  "result_": "true",
  "body": "{\"result\":\"0\",\"ver\":3,\"data\":[{\"id\":102,\"name\":\"校内宿舍\"},{\"id\":99,\"name\":\"嘉禾苑校外宿舍区\"}],\"message\":\"操作成功\"}",
  "message_": "获取成功！"
}
```

### B. `getbuildlist`（zoneid=102）

```json
{
  "result": "0",
  "ver": 3,
  "data": [
    { "id": 11, "name": "半月楼" },
    { "id": 12, "name": "励志楼" },
    { "id": 13, "name": "鼓浪苑3号楼" },
    { "id": 16, "name": "鼓浪苑2号楼" },
    { "id": 14, "name": "鼓浪苑4号楼" },
    { "id": 15, "name": "鼓浪苑1号楼" }
  ],
  "message": "操作成功"
}
```

### C. `geth5config`（customerCode=2502，节选）

```json
{
  "result": "0",
  "ver": 3,
  "message": "参数获取成功",
  "data": {
    "system_name": "物联网水电管理系统",
    "h5_user_falg": "1,1,1,1,1,0,1,0,1,0,0",
    "h5_pay_switch": 1,
    "h5_room_pay_type": 0,
    "h5_pay_business": "1,1,1",
    "subOrNot": "0,0,0,1,0,0",
    "h5_fixed_charge_d": "0",
    "h5_fixed_d_remind": "…电费收费标准为0.65元/度…",
    "h5_fixed_colds_remind": "…冷水费收费标准为1.5元/度…",
    "h5_fixed_hots_remind": "…热水费收费标准为2.5元/度…"
  }
}
```

### D. `getLocalParam`（customerCode=2502）

```json
{
  "result": 0,
  "message": "本地数据查询成功",
  "analyseUrl": "https://xqh5.17wanxiao.com/energy-analyse/index.html#/",
  "operationUrl": "https://xqh5.17wanxiao.com/smartwaterandelectricity/index.html#/login?",
  "baseurl": "https://h5cloud.17wanxiao.com:18443",
  "alipayBaseurl": "https://cloudpaygateway.59wanmei.com:8087",
  "userNewUrl": "https://xqh5.17wanxiao.com/userwaterelecmini/index.html",
  "h5_help": "https://xqh5.17wanxiao.com/smartWaterAndElectricityService/help/h5_help.html",
  "userManagerUrl": "https://xqh5.17wanxiao.com/userwaterelemanager/index.html"
}
```

---

## 10. 参考来源

- 学生端 H5：`https://xqh5.17wanxiao.com/userwaterelecmini/index.html`（`static/js/index.b36ccd67.js`）
- 运维端 H5：`https://xqh5.17wanxiao.com/smartwaterandelectricity/index.html`（`static/js/app.901e7efaa4a7075e57fa.js`）
- Apifox 公开文档：`https://s.apifox.cn/ad1e6ba6-6cd2-4b6e-88b2-a1ca1577e14c`
- 开源示例：`https://github.com/zuwei522/perfect-campus_electricity-alert`
- 旧 CloudPayment 说明：`https://github.com/cxyzzz/HUT_API`（`README.md` 电费查询章节）
