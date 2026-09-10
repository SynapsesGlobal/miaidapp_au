正式环境建议使用Stripe Connect Express Account。平台负责技术接入和订单分账，商户通过Stripe页面完成实名、资质和银行账户认证。

## 一、MIAID平台需要做什么

### 1. 申请开通Stripe Connect

在MIAID生产Stripe账户中：

Stripe Dashboard
→ Settings
→ Connect
→ Get started

提交：

- MIAID澳洲公司资料
- ABN、注册地址、负责人信息
- App和网站地址
- 平台业务模式
- 商户类型和商品类型
- 预计交易量
- 退款与争议处理方式

建议在业务描述中如实说明：

> MIAID is an Australian marketplace platform that allows customers to purchase products or services from individual Australian merchants. Each order belongs to one merchant.
> MIAID charges a platform commission and distributes the remaining proceeds to the merchant through Stripe Connect.

由于涉及药房，需要向Stripe书面确认：

- 是否允许在线药房入驻
- 处方药、OTC、保健品分别是否支持
- 是否允许MIAID代收并分账
- 是否允许使用Destination Charges
- 是否允许Alipay参与Connect分账


### 2. 配置生产环境

后端配置：

STRIPE_SECRET_KEY=sk_live_xxx
STRIPE_WEBHOOK_SECRET=whsec_xxx

Flutter只能配置：

STRIPE_PUBLISHABLE_KEY=pk_live_xxx

严禁将sk_live_放入App。

同时配置：

- Stripe Connect平台名称和Logo
- 客服联系方式
- 隐私政策
- 服务条款
- Merchant Statement Descriptor
- Payout规则
- Connect Webhook

### 3. 为每个商户创建Connected Account

商户在MIAID申请入驻后，后端创建：

$account = $stripe->accounts->create([
'type' => 'express',
'country' => 'AU',
'email' => $merchant->email,
'business_type' => 'company',
'capabilities' => [
'card_payments' => ['requested' => true],
'transfers' => ['requested' => true],
],
'metadata' => [
'merchant_id' => (string) $merchant->id,
],
]);

MIAID保存：

merchant_id
stripe_account_id = acct_xxx
charges_enabled
payouts_enabled
Connect审核状态

正式环境不能使用sandbox命令中的Custom测试账户、btok_au或模拟身份信息。

### 4. 给商户生成入驻链接

后端生成Stripe Account Link：

$link = $stripe->accountLinks->create([
'account' => $merchant->stripe_account_id,
'refresh_url' => 'https://miaid.../connect/refresh',
'return_url' => 'https://miaid.../connect/return',
'type' => 'account_onboarding',
]);

MIAID将链接提供给商户。

注意：

- 链接是一次性的。
- 链接会过期。
- 返回MIAID不代表审核通过。
- 审核结果必须通过API或account.updated webhook确认。

### 5. 控制商户是否可以销售

只有满足以下条件，才允许商户接收订单：

details_submitted = true
charges_enabled = true
payouts_enabled = true
没有past_due或阻断性requirements

如果Stripe要求补交资料，MIAID应提示商户重新进入Onboarding。

### 6. 用户下单时自动分账

例如：

订单总额：AUD 100
平台佣金：AUD 10
商户收入：AUD 90

MIAID后端创建Destination Charge：

$intent = $stripe->paymentIntents->create([
'amount' => 10000,
'currency' => 'aud',
'payment_method_types' => ['card'],
'application_fee_amount' => 1000,
'transfer_data' => [
'destination' => $merchant->stripe_account_id,
],
'metadata' => [
'order_id' => (string) $order->id,
'merchant_id' => (string) $merchant->id,
],
]);

Apple Pay仍使用card类型；Alipay使用alipay，前提是Stripe已批准。

### 7. 处理Webhook

平台至少监听：

account.updated
payment_intent.succeeded
payment_intent.payment_failed
charge.refunded
refund.updated
refund.failed
payout.paid
payout.failed

收到付款成功通知后：

验签
→ 校验订单、金额、币种和商户
→ 幂等更新支付状态
→ 更新订单
→ 扣库存
→ 发送邮件和通知

### 8. 处理退款与异常

MIAID负责：

- 审核退款
- 调用Stripe Refund API
- 撤回商户资金
- 决定是否退平台佣金
- 处理商户余额不足
- 处理重复付款和失败Payout
- 财务对账和客服查询

## 二、商户需要做什么

### 1. 在MIAID提交入驻申请

商户提供：

- 公司名称
- ABN
- 联系人和邮箱
- 药房名称及地址
- 网站或店铺信息
- 药房许可证
- 商品类别
- 退款和配送信息

MIAID审核基本资料后，创建Connected Account。

### 2. 打开Stripe入驻链接

商户进入Stripe托管页面，不需要MIAID代填敏感资料。

### 3. 完成身份和公司认证

Stripe通常要求：

- 公司注册名称
- ABN和注册地址
- 公司类型
- 董事和实际控制人
- 负责人身份证明
- 出生日期和地址
- 联系电话及邮箱
- 网站和商品说明
- 药房或行业许可证

具体字段由Stripe动态决定。

### 4. 绑定银行账户

商户在Stripe页面填写自己的澳洲银行账户：

- Account name
- BSB
- Account number

银行账户应属于商户或获得Stripe认可的法律主体。MIAID不应收集或保存完整银行资料。

### 5. 接受Stripe协议

商户需要接受：

- Stripe Connected Account协议
- 付款和结算条款
- MIAID平台服务及佣金协议
- 退款、负余额和争议责任条款

### 6. 补交资料

如果Stripe状态显示：

requirements.currently_due
requirements.past_due
payouts_enabled = false

商户需要重新打开入驻链接补交资料。未补齐时可能不能收款或提现。

### 7. 查看结算

商户可以通过Stripe Express Dashboard查看：

- 订单收入
- MIAID平台佣金
- 可用余额
- Pending余额
- 退款
- Payout状态
- 银行到账记录

商户不需要为每笔订单手动申请转账。Stripe按照Payout计划自动结算。

## 三、生产环境完整流程

MIAID开通Stripe Connect
↓
MIAID创建商户A的Express Account
↓
商户A完成Stripe实名、资质和银行账户认证
↓
Stripe审核通过
↓
MIAID允许商户A上线销售
↓
用户购买AUD 100商品
↓
MIAID创建Destination Charge
↓
用户完成付款
↓
Stripe自动分配：
商户A AUD 90
MIAID AUD 10
↓
Webhook确认订单成功
↓
Stripe按结算周期将商户余额
转入商户A银行账户

## 四、正式上线前双方确认清单

MIAID平台：

- [ ] Connect生产权限已经开通
- [ ] 药房和商品获得Stripe书面批准
- [ ] Destination Charges获得确认
- [ ] Alipay Connect获得确认
- [ ] live密钥和webhook配置完成
- [ ] 支付、退款、分账具备幂等处理
- [ ] 平台佣金及Stripe手续费承担方明确
- [ ] 商户状态异常会阻止新订单
- [ ] 财务对账与告警已经部署

商户：

- [ ] Connected Account入驻完成
- [ ] 公司和负责人验证完成
- [ ] 药房资质审核通过
- [ ] 银行账户绑定完成
- [ ] charges_enabled=true
- [ ] payouts_enabled=true
- [ ] 已接受平台佣金、退款和负余额条款
- [ ] 已完成一笔小额生产验证交易

建议先选择一家商户进行小额生产试运行，完整验证付款、AUD 90分账、退款和银行到账后，再开放其他商户。

https://claude.ai/code/artifact/76ec43c6-6760-432e-ad67-7b5589e69a7d?via=auto_preview