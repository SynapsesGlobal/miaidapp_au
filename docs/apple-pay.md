# Apple Pay（eshop 药品购买）

分支：前端 `miaidapp_au` / 后端 `miaid.com` 均为 `feature/apple-pay`（后端基于 master）。

## 实现方式

Apple Pay 走现有 Stripe 通道（Platform Pay），不引入新 SDK：

- 购物车 Checkout 后的支付弹窗（`lib/payment/e_shop_payment_bottom_sheet.dart`）在
  “Credit or Debit” 下方新增原生 Apple Pay 按钮，仅 iOS 且设备支持
  （`Stripe.instance.isPlatformPaySupported()`）时显示。
- 点击后调用 `POST /orders/{id}/intent`，`payment_method_type=apple_pay`
  （`lib/store/e_shop/e_shop_payment_store.dart` 新增 `createApplePayPaymentIntent`，
  未改动 generated_api_code），随后 `confirmPlatformPayPaymentIntent` 唤起 Apple Pay 面板。
- 原刷卡（PaymentSheet）流程完全未动；Android 无任何变化。

后端（miaid.com）：

- `PaymentController@getIntent`：接受 `apple_pay`（Stripe 侧仍按 `card` 建 intent），
  `payments.payment_type` 记为 `Payment::APPLE_PAY = 5`，药房后台订单/退款列表显示 “Apple Pay”。
- `StripeWebhookController`：`payment_intent.succeeded` 时对 pharmacy + Apple Pay 的订单
  补发订单确认邮件并扣减库存（对齐支付宝/微信 notify 行为；刷卡订单历史上不触发，保持原样）。
- `Pharmacy/RefundController@executeGatewayRefund`：`APPLE_PAY` 按 Stripe 退款
  （`stripe_charge_id` 由 webhook 写入，退款快照已通用携带）。

## 上线前的外部配置（代码之外，必须完成，否则按钮不出现/支付失败）

1. Apple Developer：创建 Merchant ID `merchant.au.com.mi-aid`，并在 App ID
   （com.em.bright.miaid 及 dev/test 变体）上开启 Apple Pay capability、勾选该 merchant，
   重新生成 Provisioning Profile。entitlements（6 个文件）已包含
   `com.apple.developer.in-app-payments = merchant.au.com.mi-aid`。
2. Stripe Dashboard → Settings → Payment methods → Apple Pay：为该 Merchant ID 生成 CSR、
   在 Apple 后台创建 Payment _Processing_ Certificate 并回传给 Stripe（dev/prod 两套 Stripe
   账号都要配）。
3. 真机测试：iOS 需已在 Wallet 添加卡片；沙箱可用 Apple sandbox tester 账号。

## 注意

- `Stripe.merchantIdentifier`（`lib/main.dart`）已由公司显示名改为
  `merchant.au.com.mi-aid`，此值仅用于 Apple Pay，不影响刷卡。
- 金额展示：Apple Pay 面板金额取 `order.orderTotal`（元），实际扣款以后端
  PaymentIntent（分）为准。
- 已知历史缺口（本分支未改，避免影响现网行为）：刷卡支付的药房订单在 webhook 中
  从不发确认邮件、不扣库存，仅 Apple Pay/支付宝/微信会触发。如需统一，把
  `StripeWebhookController` 中 pharmacy 分支的 `APPLE_PAY` 限制去掉即可。
