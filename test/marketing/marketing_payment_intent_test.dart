import 'package:flutter_test/flutter_test.dart';
import 'package:miaid/services/marketing_payment_service.dart';

void main() {
  const full = <String, dynamic>{
    'payment_intent_client_secret': 'pi_1_secret_x',
    'ephemeral_key_secret': 'ek_test',
    'stripe_customer_id': 'cus_1',
    'paymentIntentId': 'pi_1',
    'paymentMethod': 'apple_pay',
    'orderId': 12,
    'orderNbr': 'ORD-20261020-0001',
    'amount': '17.98',
    'currency': 'AUD',
  };

  group('MarketingPaymentMethod', () {
    test('api values match the backend payment_method column', () {
      expect(MarketingPaymentMethod.card.apiValue, 'stripe');
      expect(MarketingPaymentMethod.applePay.apiValue, 'apple_pay');
      expect(MarketingPaymentMethod.alipay.apiValue, 'alipay');
    });
  });

  group('MarketingPaymentService.isRmb', () {
    test('only CNY / RMB products get the Alipay option', () {
      expect(MarketingPaymentService.isRmb('CNY'), isTrue);
      expect(MarketingPaymentService.isRmb('rmb'), isTrue);
      expect(MarketingPaymentService.isRmb(' cny '), isTrue);
      expect(MarketingPaymentService.isRmb('AUD'), isFalse);
      expect(MarketingPaymentService.isRmb(''), isFalse);
      expect(MarketingPaymentService.isRmb(null), isFalse);
    });
  });

  group('MarketingAlipayPayload.fromJson', () {
    const payload = <String, dynamic>{
      'orderString': 'app_id=1&sign=abc',
      'outTradeNo': 'MAORD0000000012',
      'orderId': 12,
      'orderNbr': 'ORD-20261105-0001',
      'paymentMethod': 'alipay',
      'amount': '200.00',
      'currency': 'CNY',
    };

    test('parses the full response', () {
      final parsed = MarketingAlipayPayload.fromJson(payload);

      expect(parsed.orderString, 'app_id=1&sign=abc');
      expect(parsed.outTradeNo, 'MAORD0000000012');
      expect(parsed.orderId, 12);
      expect(parsed.orderNbr, 'ORD-20261105-0001');
      expect(parsed.amount, '200.00');
      expect(parsed.currency, 'CNY');
    });

    test('tolerates the old response shape (orderString, outTradeNo, orderId, currency only)', () {
      final parsed = MarketingAlipayPayload.fromJson(const {
        'orderString': 'x',
        'outTradeNo': 'MAORD0000000001',
        'orderId': '1',
        'currency': 'RMB',
      });

      expect(parsed.orderId, 1);
      expect(parsed.orderNbr, isNull);
      expect(parsed.amount, isNull);
    });

    test('rejects a response without an order string or trade number', () {
      expect(
        () => MarketingAlipayPayload.fromJson(const {'outTradeNo': 'MAORD0000000001'}),
        throwsFormatException,
      );
      expect(
        () => MarketingAlipayPayload.fromJson(const {'orderString': 'x', 'outTradeNo': ''}),
        throwsFormatException,
      );
    });
  });

  group('MarketingPaymentIntent.fromJson', () {
    test('parses the full response', () {
      final intent = MarketingPaymentIntent.fromJson(full, MarketingPaymentMethod.applePay);

      expect(intent.clientSecret, 'pi_1_secret_x');
      expect(intent.ephemeralKeySecret, 'ek_test');
      expect(intent.customerId, 'cus_1');
      expect(intent.paymentIntentId, 'pi_1');
      expect(intent.orderId, 12);
      expect(intent.orderNbr, 'ORD-20261020-0001');
      expect(intent.method, MarketingPaymentMethod.applePay);
      expect(intent.applePayCurrencyCode, 'AUD');
      expect(intent.displayAmount, '17.98');
    });

    test('rejects a response without a client secret', () {
      expect(
        () => MarketingPaymentIntent.fromJson(const {'stripe_customer_id': 'cus_1'}, MarketingPaymentMethod.card),
        throwsFormatException,
      );
      expect(
        () => MarketingPaymentIntent.fromJson(const {'payment_intent_client_secret': ''}, MarketingPaymentMethod.card),
        throwsFormatException,
      );
    });

    test('tolerates the old response shape (Stripe fields only)', () {
      final intent = MarketingPaymentIntent.fromJson(const {
        'payment_intent_client_secret': 'secret',
        'ephemeral_key_secret': 'ek',
        'stripe_customer_id': 'cus',
      }, MarketingPaymentMethod.card);

      expect(intent.orderId, isNull);
      expect(intent.amount, isNull);
      expect(intent.displayAmount, '0.00', reason: 'never crash the Apple Pay sheet on a missing amount');
      expect(intent.applePayCurrencyCode, 'AUD', reason: 'AU edition default');
    });

    test('maps RMB to CNY for the Apple Pay sheet and normalises case', () {
      MarketingPaymentIntent withCurrency(String? currency) => MarketingPaymentIntent.fromJson(
            {'payment_intent_client_secret': 's', 'currency': currency},
            MarketingPaymentMethod.applePay,
          );

      expect(withCurrency('RMB').applePayCurrencyCode, 'CNY');
      expect(withCurrency('rmb').applePayCurrencyCode, 'CNY');
      expect(withCurrency('cny').applePayCurrencyCode, 'CNY');
      expect(withCurrency(' aud ').applePayCurrencyCode, 'AUD');
      expect(withCurrency(null).applePayCurrencyCode, 'AUD');
    });

    test('formats the display amount with two decimals', () {
      MarketingPaymentIntent withAmount(dynamic amount) => MarketingPaymentIntent.fromJson(
            {'payment_intent_client_secret': 's', 'amount': amount},
            MarketingPaymentMethod.applePay,
          );

      expect(withAmount('8.9').displayAmount, '8.90');
      expect(withAmount(1000).displayAmount, '1000.00');
      expect(withAmount('abc').displayAmount, '0.00');
      expect(withAmount(null).displayAmount, '0.00');
    });
  });

  test('MarketingPaymentException carries a user-facing message', () {
    final e = MarketingPaymentException('[Hair transplant] is out of stock.');
    expect(e.message, '[Hair transplant] is out of stock.');
    expect(e.toString(), '[Hair transplant] is out of stock.');
  });
}
