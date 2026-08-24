<p align="center">
  <a href="README.en.md">English</a> · 中文
</p>

<p align="center">
  <img src="docs/images/icon.png" alt="DS Balance Monitor" width="96">
</p>

<p align="center">
  <img src="docs/images/preview.png" alt="DS Balance Monitor 预览" width="920">
</p>

<h1 align="center">DS Balance Monitor</h1>
<p align="center">DeepSeek 余额监控 · macOS 菜单栏应用</p>

<p align="center">
  <a href="https://github.com/mo2g/ds-balance-monitoring/releases"><img src="https://img.shields.io/badge/platform-macOS%2014%2B-blue" alt="macOS 14+"></a>
  <a href="#"><img src="https://img.shields.io/badge/Swift-5.10-orange" alt="Swift 5.10"></a>
  <a href="https://github.com/mo2g/ds-balance-monitoring/actions/workflows/ci.yml"><img src="https://github.com/mo2g/ds-balance-monitoring/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-green" alt="MIT"></a>
</p>

**DS Balance Monitor** 是一个常驻 macOS 菜单栏的原生 SwiftUI 应用：每 60 秒通过
[DeepSeek 余额 API](https://api-docs.deepseek.com/zh-cn/api/get-user-balance)
拉取一次余额，按分钟记录消耗，并用「月 / 天 / 时 / 分」四档图表直观展示余额
都花在了哪里。

> English: [README.en.md](README.en.md)

---

## ✨ 功能

- **余额监控**：每 60 秒拉取一次余额，失败指数退避（1→2→4→5 分钟），菜单栏实时显示，异常时显示 ⚠️
- **四档图表**：月 / 天 / 时 / 分 聚合视图，支持 年份、币种（CNY/USD/全部）、口径（余额曲线 / 消耗量）切换
- **最新优先 + 按需分页**：「分 / 时」默认打开最新一批数据，向左拖动自动加载更早数据；「天」默认锚定最新 30 天；长期回看历史时新数据不打断，可一键「回到最新」
- **节点明细**：悬停任意节点查看该时段的起始/结束余额、消耗量与充值标记（固定高度详情面板，切换不跳动）
- **中英双语**：界面支持 中文 / English，可跟随系统或手动切换
- **低余额通知**：默认阈值 ¥5，余额跌破时发系统通知；充值回升后自动复位，可再次触发
- **菜单栏样式**：图标 + 数字 / 仅图标 / 仅数字；优先币种可切换
- **其他**：开机自启、系统唤醒后立即补拉、按年分表存储（自动建表）

## 📦 快速开始

### 方式一：下载 Release（推荐）

1. 到 [Releases](https://github.com/mo2g/ds-balance-monitoring/releases) 下载 `DSBalanceMonitor-*-macOS.zip`；
2. 解压后把 `DSBalanceMonitor.app` 拖入「应用程序」；
3. 由于应用使用 ad-hoc 签名（未公证），首次运行前去除隔离标记：

```bash
xattr -dr com.apple.quarantine /Applications/DSBalanceMonitor.app
```

4. 双击启动，菜单栏出现「¥ 余额」图标；
5. 点图标 → **设置** → 粘贴 DeepSeek API Key（`sk-...`）→ 保存。

### 方式二：从源码构建

要求：macOS 14.0+、[Xcode 15.4+](https://developer.apple.com/xcode/)、
[XcodeGen](https://github.com/yonaskolb/XcodeGen)。

```bash
brew install xcodegen
git clone https://github.com/mo2g/ds-balance-monitoring.git
cd ds-balance-monitoring

./scripts/run.sh      # 结束旧实例 → 干净重建 → 启动新实例
```

也可以分步执行：

```bash
./scripts/build.sh
open -n build/DSBalanceMonitor.app   # 必须加 -n，否则只会聚焦已运行的旧实例
```

## 🖥 使用

1. 点击菜单栏图标 → **设置** → 粘贴 API Key → 保存（立即刷新余额）；
2. 菜单栏实时显示余额，点击图标可打开迷你面板；
3. 点「打开完整窗口」查看图表：切换 年份 / 币种 / 粒度 / 口径，悬停查看节点明细；
4. 「分 / 时」粒度向左拖动可加载更早数据，右上角「回到最新」一键跳回；
5. 在设置里可把界面语言切换为 **中文 / English / 跟随系统**。

## 🔒 数据与隐私

| 数据 | 位置 | 说明 |
|---|---|---|
| 余额快照 | `~/Library/Application Support/DSBalanceMonitor/balances.sqlite` | 按年分表 `balance_samples_2025`、`balance_samples_2026`… |
| API Key | 本机 UserDefaults（`dsbalance.secret.deepseek_api_key`） | **明文存储**，仅保存在本机；除请求 `api.deepseek.com` 外不会上传任何数据 |

> 明文存储的原因：ad-hoc 签名的 app 每次重建 CDHash 都会变化，导致 Keychain ACL
> 失效读不到密钥。正式签名/公证发布后可迁移回 Keychain。如果你在共享机器上使用，
> 请勿保存 API Key，用完可在设置中清空。

## ❓ 常见问题

<details>
<summary>菜单栏里看不到图标？</summary>

先检查 Bartender 4 等菜单栏管理工具是否把它收纳进隐藏栏，把「DS Balance Monitor」
设为常驻显示。退出：弹窗里的「退出」按钮，或 ⌘Q。
</details>

<details>
<summary>提示「app 已损坏，无法打开」？</summary>

应用是 ad-hoc 签名、未经公证，macOS Gatekeeper 会拦截。执行：

```bash
xattr -dr com.apple.quarantine /Applications/DSBalanceMonitor.app
```

或在「系统设置 → 隐私与安全性」中点击「仍要打开」。
</details>

<details>
<summary>菜单栏一直显示 ⚠️？</summary>

通常是 API Key 未配置、失效（401）或网络不可用。到设置里重新保存 Key 即可立即重试。
</details>

<details>
<summary>支持 Intel Mac 吗？</summary>

支持。Release 构建的是 arm64 + x86_64 通用二进制；本地 `build.sh` 只构建当前机器架构以加快速度。
</details>

## 🏗 架构

```
MenuBarExtra（菜单栏：图标 + 余额）
  ├─ MiniDashboardView   迷你面板 / 打开完整窗口 / 设置 / 退出
  ├─ MainChartView       主窗口：月/天/时/分 图表 + 分页状态机
  └─ SettingsView        API Key / 阈值 / 菜单栏样式 / 语言 / 开机自启 / 通知

Core
  PollingScheduler      每 60 秒轮询；唤醒补拉；失败退避
  BalanceAPIClient      GET https://api.deepseek.com/user/balance
  BalanceRepository     GRDB/SQLite 按年分表 + 聚合查询（半开区间分页）
  ChartPaging           纯函数分页窗口（最新优先、页边界对齐、触发阈值）
  Localization          中英双语词典 + 语言偏好管理
  AlertEngine           低余额通知与充值复位
  SettingsStore         UserDefaults 设置
```

目录结构：

```
App/       SwiftUI 界面（菜单栏、面板、主窗口、设置、图表）
Core/      业务逻辑（API 客户端、仓储、分页、本地化、调度、告警、密钥）
Models/    数据模型
Tests/     XCTest 测试（72 个）
scripts/   构建 / 测试 / 发布脚本
docs/      文档与截图
```

## 🧪 开发

```bash
./scripts/test.sh       # 运行全部测试（72 个 XCTest）
xcodegen generate       # 从 project.yml 重新生成 Xcode 工程
./scripts/release.sh    # 构建通用二进制并打包 zip（用于本地验证 Release 流程）
```

CI 会在每次 push / PR 时运行测试；打 `v*` 标签会触发 Release 工作流，自动构建并上传
通用二进制 zip 草稿。

## 🚧 已知限制（v1）

- 仅支持**单账户**；无数据导出；轮询间隔固定 60 秒
- 仅支持 macOS 14.0+
- API Key 明文存于本机偏好设置（详见「数据与隐私」）

## 📄 License

[MIT](LICENSE) © 2026 mo2g

应用图标来自 DeepSeek 官方 favicon（[cdn.deepseek.com/platform/favicon.png](https://cdn.deepseek.com/platform/favicon.png)），版权归 DeepSeek 所有。
