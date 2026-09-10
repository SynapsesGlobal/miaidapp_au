# 支付宝 App 支付（药房订单、旅行套餐、加购问诊）

分支 `feature/alipay-pharmacy`（药房）与 `feature/alipay-packages`（套餐 / 加购问诊，含后端同名分支）。
在 AU 版 App 的支付弹窗里增加"支付宝"入口，
走后端已有的境内支付宝接口（`openapi.alipay.com`，`alipay.trade.app.pay`），
不经过 Stripe，刷卡与 Apple Pay 流程不变。实现参考 CN 版 `miaidapp_cn`。

目标用户是身处中国大陆、在支付宝里绑定了境外银行卡的用户。支付宝对境内商户的
"外卡内用"完全透明：商户不需要额外签约，费率与国内用户一致，人民币结算。
背景调研见本次调研报告（支付宝境外用户支付调研）。

## 改动清单

| 文件 | 内容 |
| --- | --- |
| `pubspec.yaml` | 新增 `tobias: 5.2.0`（支付宝官方 SDK 的 Flutter 封装）及 `tobias:` 配置段 |
| `lib/services/alipay_service.dart` | 创建支付宝订单 → 唤起支付宝 → 向后端确认支付状态 |
| `lib/payment/e_shop_payment_bottom_sheet.dart` | 支付方式列表新增支付宝一行（仅药房币种为人民币 RMB/CNY 且设备已安装支付宝时显示，其他币种或未安装时不显示任何内容）及 `_startAlipayProcess` |
| `lib/payment/payment_bottom_sheet.dart` | 旅行套餐与加购问诊共用的支付弹窗，同样规则新增支付宝一行；成功后复用 `recheckActiveSubscription` 轮询后端 payment 状态 |
| `lib/l10n/intl_*.arb` | 4 个新文案：未安装提示、支付成功、处理中、境外卡手续费说明 |
| `ios/Runner/Info.plist` | URL type `alipay`（scheme `com.em.bright.miaid.alipay`），`LSApplicationQueriesSchemes` 加 `alipay`/`alipays` |
| `ios/Podfile.lock` | `pod install` 后新增 tobias |
| `android/build.gradle` | 根工程原本把所有插件模块的 Kotlin jvmTarget 强制成 1.8，tobias 自身声明 Java 11，两者不一致会编译失败；只对 tobias 放开到 11 |

Android 端除上述 jvmTarget 外不需要改：tobias 自带的 manifest 已声明支付宝包名的 `<queries>`，
不使用 `QUERY_ALL_PACKAGES`。

## 支付流程

### 药房订单

```
用户点"支付宝"
→ POST /api/v1/alipay/createPharmacyOrder {orderId, currency, subject}
   后端：ExchangeService 把订单币种换算成人民币（App 端只对人民币药房显示入口，实际不会发生换算） → 建 Payment(type=ALIPAY) → 返回签名后的 orderString + outTradeNo
→ tobias.pay(orderString) 唤起支付宝 App，用户付款后回跳（iOS 靠 URL scheme）
→ resultStatus 9000/8000/6004 时 GET /api/v1/alipay/query?outTradeNo=… 最多查 3 次
   已支付 → 埋点、提示成功、关闭购物车；未确认 → 提示"处理中，稍后查看订单"，购物车不关
→ 支付宝异步 notify 打到后端 /alipay/pharmacyOrder/notify，后端落库、发邮件、扣库存
```

resultStatus 对应：9000 成功；8000 处理中；6004 结果未知；6001 用户取消（不提示）；
4000/5000/6002 失败（`Could not complete payment [14]`）；接口异常 `[15]`。

### 旅行套餐 / 加购问诊（后端分支 `feature/alipay-packages`）

```
用户点"支付宝"
→ POST /api/v1/alipay/createPackageOrder {packageId, packageType, currency, countryCode}
   packageType 与 Stripe 路径一致：travel-packages / calls
   后端：resolvePurchaseContext 按用户所在国家取价（必须是人民币，否则 422）
        → persistPendingPurchase 落库（与 Stripe 完全同一套：customer_subscription_details / call_purchases / payments）
        → 返回 orderString + outTradeNo + paymentId
→ tobias.pay(orderString) 唤起支付宝，回跳后向后端 /alipay/query 确认
   已支付 → recheckActiveSubscription(paymentId)：轮询 /subscriptions/payments/{id}，刷新订阅、弹成功提示、埋点
   未确认 → 提示"处理中，稍后查看"
→ 支付宝异步 notify 打到 /alipay/travePackageOrder/notify 或 /alipay/servicePackageOrder/notify
   后端：验签 → 锁定 payment → 幂等标记 PAID → SubscriptionPaymentFulfillment（激活订阅、发票邮件、免费问诊）
```

失败码：`Could not complete payment [16]`（支付宝返回失败）、`[17]`（接口异常或定位失败）。

后端改造要点（miaid.com 分支 `feature/alipay-packages`）：

- `SubscriptionsController` 抽出 `resolvePurchaseContext()` 与 `persistPendingPurchase()`，Stripe 路径行为不变。
- `AlipaySubscriptionController` 继承 `SubscriptionsController` 复用上述方法，旧的复制代码全部删除；
  `out_trade_no` 在落库前生成（`TORD`/`SORD` + 时间戳 + 随机数），作为 `PresentFreeSubscription.payment_intent_key`。
- `SubscriptionPaymentFulfillment` 统一了 Stripe webhook 与支付宝 notify 的支付成功履约。
- 药房接口的收银台标题不再写死"测试商品"，改用 App 传的 subject。
- 新增迁移 `2026_09_09_000000_normalize_alipay_trade_no_columns_on_payments`：把 `payments.alipay_out_trade_no` /
  `alipay_trade_no` 统一成 varchar(64) 并加索引（本地开发库里这两列是 decimal(10,2)，存不下订单号，支付宝下单会直接失败；
  线上若已是字符串类型则迁移不做改动）。部署时按 README 执行 `php artisan migrate --database migrations`。

后端回归方式：本地库用事务回滚的方式实际执行了重构后的 Stripe 下单逻辑（旅行套餐、加购问诊）与支付宝接口，
落库记录与库里真实的 Stripe 支付记录形态一致；AUD 套餐调用支付宝接口返回 422，人民币套餐返回 orderString / outTradeNo / paymentId。

## tobias 的 pod install 副作用（已规避）

tobias 的 podspec 在 `pod install` 时会执行 `tobias_setup.rb`，按 `pubspec.yaml` 里的
`tobias:` 配置改写 Runner 的 Info.plist 和 entitlements：

- 若 Info.plist 没有名为 `alipay` 的 URL type，就用 Plist 库整体重写 Info.plist（格式会被打乱）。
  已预先手工登记，脚本检测到存在就不动。
- 若 `LSApplicationQueriesSchemes` 缺 `alipays`，同样重写。已预先加入。
- 默认会把 `NSAllowsArbitraryLoads` / `NSAllowsArbitraryLoadsInWebContent` 改为 true。
  已通过 `ios.ignore_security: true` 关闭，这两个键不应为 true，否则 App Store 审核会追问。
- 会把 `ios.universal_link` 的 host 作为 `applinks:` 写进每个 build configuration 的 entitlements。
  留空时会写入无效的 `applinks:`，所以填了已存在的 `https://admin.mi-aid.com.au/app/`，
  6 个 entitlements 都已有 `applinks:admin.mi-aid.com.au`，脚本不会再改。

升级 tobias 或改动上述配置后，`pod install` 完要 `git diff ios/` 确认没有被脚本重写。

另外：脚本用系统 Ruby 运行，需要 `plist` 和 `xcodeproj` 两个 gem；本机系统 Ruby 缺 `plist` 时
脚本会打印 `cannot load such file -- plist` 后退出，pod install 本身不受影响（podspec 用 `system` 调用，
不检查返回值）。因为 Info.plist 已手工配好，脚本跑不跑结果一样。

## 上线前的外部配置

### 支付宝开放平台

1. 在持有境内商户号的主体下，创建"移动应用"并签约"App 支付"。
   iOS 填 Bundle ID `com.em.bright.miaid`（测试包 `com.em.bright.miaid.test`
   见 sandbox-test-app-split），Android 填包名 `com.em.bright.miaid` 和
   Google Play 托管签名证书的 MD5（不是本地上传密钥）。
2. 应用下载链接填澳洲 App Store / Google Play 链接即可，不要求在中国应用商店上架。
3. 与 CN 版是否共用同一个支付宝应用（APP_ID）需决定；共用则密钥、回调一致，改动最小。
4. 药品类目需要药品经营许可证等资质，以开放平台签约页面的要求为准。

### 后端（miaid.com，AU 站点）

后端代码已有，只需配置 AU 站点的环境变量：

```
ALIPAY_APP_ID
ALIPAY_APP_PRIVATE_KEY
ALIPAY_ALIPAY_PUBLIC_KEY
ALIPAY_GATEWAY_URL=https://openapi.alipay.com
ALIPAY_NOTIFY_URL   （notify 实际用 config('app.url') + /alipay/pharmacyOrder/notify）
AUD_RMB             （ExchangeService 用的固定汇率）
```

一个已知的后端问题，与本分支无关但会影响药房订单体验：

- 药房订单的汇率是 `.env` 固定值，AUD 波动会造成每单人民币金额与实际汇率偏差，退款按同一固定汇率退。
  套餐 / 加购问诊不受影响，因为只允许人民币计价的套餐用支付宝，不做换算。

### App Store 审核

- 药品属于实物商品，按审核指南 3.1.3(e) 使用第三方支付，与现有 Stripe 相同，不涉及内购。
- Review Notes 写明：支付宝仅在设备安装了支付宝 App 时显示，用于身处中国大陆的用户购买实物药品，附截图。
  审核员一般没有支付宝账号，无法实际走完支付。
- App Privacy 标签补充支付宝 SDK 采集的设备信息。tobias 5.2.0 自带 `PrivacyInfo.xcprivacy`。
- 隐私政策补充：支付数据会传输给支付宝（蚂蚁集团，中国）。

## 测试

支付宝没有可用的沙箱 App 支付账号时，用真实小额订单验证：

1. 人民币结算的药房、设备已安装支付宝，支付弹窗出现"支付宝"行；卸载支付宝或药房币种为 AUD 等其他币种时整行不出现，也没有提示文字。
2. 用境外手机号注册、只绑 Visa/Mastercard 的支付宝账号，下单 ≤ ¥200 和 > ¥200 各一笔，
   后者收银台应显示 3% 手续费；两笔后端 `payments.status` 都应为 PAID。
3. 在支付宝收银台取消，App 无提示，订单可重新支付。
4. 后端在药房后台批准退款，确认 `alipay.trade.refund` 原路退回。
5. 刷卡和 Apple Pay 回归：两条路径不受影响。
6. 套餐 / 加购问诊：定位在中国、套餐以人民币计价时支付弹窗出现支付宝；付款后应弹出与刷卡相同的成功提示，
   "我的套餐"里出现新套餐，附赠免费问诊次数正确；AUD 计价的套餐不出现支付宝。

沙箱环境：`ALIPAY_GATEWAY_URL` 指向 `https://openapi-sandbox.dl.alipaydev.com/gateway.do`，
Android 需安装支付宝沙箱版（包名 `com.eg.android.AlipayGphoneRC`，tobias 的 `<queries>` 已包含）。
