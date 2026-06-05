import 'package:flutter_test/flutter_test.dart';
import 'package:miaid/utils/card_utils.dart';
import 'package:miaid/payment/card_details.dart';
import 'package:flutter/foundation.dart';
import 'package:stream_chat_flutter_core/stream_chat_flutter_core.dart';

void main() {
  setUpAll() {}
  group('test master card utils test', () {
    test("", () {
      //CardType out = validateCardType("5431 1111 1111 1111");
      //debugPrint(
      //    'movieTitle: $out info:${CardType.Master == validateCardType("5431 1111 1111 1111")}');
      expect(validateCardType('2223 0000 1000 0005'.replaceAll(' ', '')),
          CardType.Master);
      expect(validateCardType('5431 1111 1111 1301'.replaceAll(' ', '')),
          CardType.Master);

      expect(validateCardType('4065 9301 0900 0002'.replaceAll(' ', '')),
          isNot(CardType.Master));
      expect(validateCardType('4111 1111 1111 1111'.replaceAll(' ', '')),
          isNot(CardType.Master));
    });
  });

  group('test visa card utils test', () {
    test('', () {
      expect(validateCardType('4065 9301 0900 0002'.replaceAll(' ', '')),
          CardType.Visa);
      expect(validateCardType('4111 1111 1111 1111'.replaceAll(' ', '')),
          CardType.Visa);

      expect(validateCardType('2223 0000 1000 0005'.replaceAll(' ', '')),
          isNot(CardType.Visa));
      expect(validateCardType('5431 1111 1111 1301'.replaceAll(' ', '')),
          isNot(CardType.Visa));
    });
  });

  group('test verve card utils test', () {
    test('', () {
      expect(validateCardType('5061408794901079'), CardType.Verve);
      expect(validateCardType('5431 1111 1111 1301'), isNot(CardType.Verve));
    });
  });

  group('test Discover card utils test', () {
    test('', () {
      expect(validateCardType('6011 1111 1111 1117'), CardType.Discover);
      expect(validateCardType('5431 1111 1111 1301'), isNot(CardType.Discover));
    });
  });

  group('test Discover card utils test', () {
    test('', () {
      expect(validateCardType('371093631983000'), CardType.AmericanExpress);
      expect(validateCardType('5431 1111 1111 1301'),
          isNot(CardType.AmericanExpress));
    });
  });
  group('test DinersClub card utils test', () {
    test('', () {
      expect(validateCardType('36700102000000'), CardType.DinersClub);
      expect(
          validateCardType('5431 1111 1111 1301'), isNot(CardType.DinersClub));
    });
  });

  group('test Jcb card utils test', () {
    test('', () {
      expect(validateCardType('3559395779850992'), CardType.Jcb);
      expect(validateCardType('5431 1111 1111 1301'), isNot(CardType.Jcb));
    });
  });

  group('test Others card utils test', () {
    test('', () {
      expect(validateCardType('3559395779850992'), isNot(CardType.Others));
      expect(validateCardType('5431 1111 1111 1301'), isNot(CardType.Others));
    });
  });

  group('test Invalid card utils test', () {
    test('', () {
      expect(validateCardType('23dsfslewr234ewewr2'), CardType.Invalid);
      expect(validateCardType('111111111111000000000000000'), CardType.Invalid);
      expect(validateCardType('5431 1111 1111 1301'), isNot(CardType.Invalid));
    });
  });
}
