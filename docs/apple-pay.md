# Apple Pay 集成

分支：前端 `miaidapp_au` / 后端 `miaid.com` 均为 `feature/apple-pay`（后端基于 master）。

覆盖三个支付场景，均走现有 Stripe 通道（Platform Pay），不引入新 SDK：

| 场景 | 前端入口 | 后端 intent 接口 |
|---|---|---|
| eshop 药品购买 | `lib/payment/e_shop_payment_bottom_sheet.dart` | `POST /orders/{id}/intent`（`Pharmacies\PaymentController@getIntent`） |
| 旅行套餐（travel packages） | 共用 `lib/payment/payment_bottom_sheet.dart` | `POST /subscriptions/travel-packages/{id}/stripe-payment-intent`（`SubscriptionsController`） |
| 其他服务（additional services） | 共用 `lib/payment/payment_bottom_sheet.dart` | `POST /subscriptions/calls/{id}/stripe-payment-intent`（同上） |

## 实现方式

前端（两个支付弹窗做法一致）：

- “Credit or Debit” 行下方新增 **Apple Pay 列表项**（`Icons.apple` + 与刷卡行一致的
  ListTile 样式；未用原生 PKPaymentButton，支付方式列表场景苹果允许此做法）。
- 仅 iOS 且 `Stripe.instance.isPlatformPaySupported()` 为 true 时显示；该检查等价于
  “Wallet 已添加 Visa/Mastercard/Amex 等 Stripe 支持的卡”（**银联卡不算**）。
  debug 构建下不满足条件会显示灰色提示文字说明原因，release 直接隐藏。
- 点击后以 `payment_method_type=apple_pay` 创建 intent（store 各加了
  `createApplePayPaymentIntent`：`lib/store/e_shop/e_shop_payment_store.dart`、
  `lib/store/payment/payment_store.dart`，均未改 generated_api_code、无需 build_runner），
  随后 `confirmPlatformPayPaymentIntent` 唤起 Apple Pay 面板。
- 订阅场景支付成功后的 `recheckActiveSubscription` 轮询、成功弹窗、`onSuccess` 回调
  与刷卡流程完全一致；返回值语义不变（travel 页 await 的 bool）。
- 原刷卡（PaymentSheet）、Square POS、支付宝/微信通道完全未动；Android 无任何变化。
- 人民币场景：Apple Pay 面板的 currencyCode 做了 RMB→CNY 映射（与后端建 intent 一致）。

后端（miaid.com）：

- `Pharmacies\PaymentController@getIntent` 与 `SubscriptionsController@createStripePaymentIntent`：
  接受 `apple_pay`（Stripe 侧仍按 `card` 建 intent），`payments.payment_type` 记为
  `Payment::APPLE_PAY = 5`，药房/管理后台通过 `Payment::typeName()` 显示 “Apple Pay”。
- `StripeWebhookController`：`payment_intent.succeeded` 时对 pharmacy + Apple Pay 的订单
  补发订单确认邮件并扣减库存（对齐支付宝/微信 notify 行为；刷卡订单历史上不触发，保持原样）。
  订阅场景走原有 `category=subscription` 分支，与 payment_type 无关，无需改动。
- `Pharmacy\RefundController@executeGatewayRefund`：`APPLE_PAY` 按 Stripe 退款
  （`stripe_charge_id` 由 webhook 写入，退款快照已通用携带）。

## 上线前的外部配置（代码之外，必须完成，否则支付失败）

1. Apple Developer：创建 Merchant ID `merchant.au.com.mi-aid`，并在 App ID
   （com.em.bright.miaid 及 dev/test 变体）上开启 Apple Pay capability、勾选该 merchant，
   重新生成 Provisioning Profile。entitlements（6 个文件）已包含
   `com.apple.developer.in-app-payments = merchant.au.com.mi-aid`。
2. Stripe Dashboard → Settings → Payment methods → Apple Pay：为该 Merchant ID 生成 CSR、
   在 Apple 后台创建 Payment Processing Certificate 并回传给 Stripe（dev/prod 两套 Stripe
   账号都要配）。
3. 注意：按钮是否显示只取决于设备 Wallet（见上），与 1/2 无关；但没配 1/2 时点击
   按钮唤起面板/付款会失败。

## 真机测试

- Wallet 需有 Visa/Mastercard/Amex 卡；**只有银联卡时按钮不会出现**（见下文银联结论）。
- 没有外卡时用 Apple 沙箱：App Store Connect 创建沙箱测试员（邮箱不能是已注册过的
  Apple ID，可用 `xx+sandbox@` 别名；地区选澳洲）→ 测试机改地区为澳洲、退出真实
  iCloud 并用沙箱账号登录 → Wallet 手动输入官方测试卡
  （developer.apple.com/apple-pay/sandbox-testing/，如 Visa `4622 9431 2318 9285`
  exp 12/2028 CVV 096）。
- 沙箱测试卡只在 Stripe 测试密钥下能支付成功：**用 dev flavor 测支付**；prod 包只能
  验证按钮显示与面板唤起。
- Flutter 3.19.6 + Xcode 26 真机 debug 会报
  “Timed out waiting for CONFIGURATION_BUILD_DIR”，装机用
  `flutter run --release --flavor dev`，或从 Xcode（Product → Run）跑 debug。

## 关于中国银联卡

- Stripe 官方：UnionPay **不支持钱包**（Apple Pay/Google Pay）。所以不要把
  `ChinaUnionPay` 加进 Apple Pay 网络列表——面板能显示但 Stripe 必拒付。
- 收银联卡的正确姿势：Stripe 的银联支持覆盖 AU 账号，走普通 `card` 通道。在 Stripe
  Dashboard 申请开启 UnionPay 后，现有「Credit or Debit」表单直接输银联卡号即可，
  前后端零改动。
- 服务中国用户更实际的方案是支付宝/微信：后端药房订单的支付宝/微信通道已齐备
  （`/alipay/createPharmacyOrder`、`/wechatpay/createPharmacyOrder` 及 notify/退款），
  AU 版 app 的支付弹窗尚未放入口，需要时前端加一行即可。

## 注意

- `Stripe.merchantIdentifier`（`lib/main.dart`）已由公司显示名改为
  `merchant.au.com.mi-aid`，此值仅用于 Apple Pay，不影响刷卡。
- 金额展示：Apple Pay 面板金额取自订单/套餐金额（元），实际扣款以后端
  PaymentIntent（分）为准。
- 已知历史缺口（本分支未改，避免影响现网行为）：刷卡支付的药房订单在 webhook 中
  从不发确认邮件、不扣库存，仅 Apple Pay/支付宝/微信会触发。如需统一，把
  `StripeWebhookController` 中 pharmacy 分支的 `APPLE_PAY` 限制去掉即可。
