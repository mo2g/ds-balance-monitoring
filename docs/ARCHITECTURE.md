# 架构说明

本文档描述当前 main 分支的实际实现，供贡献者快速上手。

## 1. 技术栈

- Swift 5.10 / SwiftUI / Swift Charts（macOS 14.0+）
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)：`project.yml` 生成工程
- [GRDB.swift](https://github.com/groue/GRDB.swift) 6.29：SQLite 数据层（SPM）
- XCTest：核心逻辑 TDD，72 个测试

## 2. 运行时组件

```
AppDelegate
  └─ 循环 Task：pollAndApply() → sleep(60s)
       ├─ PollingScheduler.pollOnce()
       │    ├─ DeepSeekBalanceClient.fetchBalance()   // GET /user/balance
       │    └─ BalanceRepository.record(...)           // 写入年度表
       ├─ AppState.apply(response)                     // 菜单栏文本
       ├─ AlertEngine.evaluate(balances)               // 低余额通知
       └─ AppServices.samplesDidChange.send(Date())    // 通知图表刷新尾部

NSWorkspace.didWakeNotification → 立即补拉一次
AppServices.pollRequests → 保存 API Key 后立即拉取
```

## 3. 数据模型

快照表按年分表：`balance_samples_<year>`，字段：

| 字段 | 类型 | 说明 |
|---|---|---|
| timestamp | INTEGER | Unix 秒（UTC） |
| currency | TEXT | CNY / USD … |
| total_balance / granted_balance / topped_up_balance | REAL | 三种余额 |
| consumed | REAL | 相对上一快照的消耗（≥0） |
| is_recharge | INTEGER | 余额上升 = 充值事件 |

`consumed` / `is_recharge` 在写入时计算：余额下降为消耗；上升为充值；不变为 0。
「上一快照」先查当前年份表，无结果回退上一年表（跨年首条）。

## 4. 图表分页（最新优先）

- **分**：每页 6 小时，可见域 2 小时；**时**：每页 7 天，可见域 24 小时。
  打开即锚定数据库最新样本，接近已加载窗口左边界 30% 时自动加载上一页。
- **天**：全年全量（≤366 点），可见域 30 天，默认锚定最新。
- **月**：全年全量（12 点，消耗口径下补零），不滚动。

关键约定见 `Core/ChartPaging.swift`：

- 所有查询区间为**左闭右开** `[start, end)`，页边界对齐到分钟/小时桶，避免桶被拆分；
- `chartScrollPosition(x:)` 的绑定值 = 可见域左边缘 `scrollAnchor`；
- prepend 更早数据时 `scrollAnchor` 不变，画面位置稳定；
- 停在最新端时新样本自动追加并跟随；回看历史时只置 `hasNewData`，不移动画面；
- 长休眠导致尾部缺口超过一页时直接重置初始窗口。

`MainChartViewModel` 维护 `points`（按 `start` 去重 upsert、升序）、`loadedRange`、
`hasMoreEarlier`、`isLoadingEarlier`、`hasNewData`、`scrollAnchor` 等状态。

## 5. 密钥与存储

- 余额库：`~/Library/Application Support/DSBalanceMonitor/balances.sqlite`
- API Key：`UserDefaultsSecretStore`（明文，key `dsbalance.secret.deepseek_api_key`）。
  保留 `KeychainSecretStore` 实现，正式签名后可切换。

## 6. 测试

`./scripts/test.sh` 运行全部 72 个测试，覆盖：API 解码、仓储（分表/半开区间/最新时间戳）、
聚合、分页纯逻辑、ViewModel 分页状态机、双语本地化、告警、轮询退避、菜单栏展示、窗口生命周期。
UI 层以手工验证为主，不做自动化 UI 测试。
