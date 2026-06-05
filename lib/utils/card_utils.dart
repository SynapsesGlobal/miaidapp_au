import 'package:flutter/material.dart';
import 'package:miaid/payment/card_details.dart';

CardType validateCardType(String value) {
  if (value.startsWith(RegExp(
      r'((5[1-5])|(222[1-9]|22[3-9][0-9]|2[3-6][0-9]{2}|27[01][0-9]|2720))'))) {
    return CardType.Master;
  } else if (value.startsWith(RegExp(r'[4]'))) {
    return CardType.Visa;
  } else if (value.startsWith(RegExp(r'((506(0|1))|(507(8|9))|(6500))'))) {
    return CardType.Verve;
  } else if (value.startsWith(RegExp(r'((34)|(37))'))) {
    return CardType.AmericanExpress;
  } else if (value.startsWith(RegExp(r'((6[45])|(6011))'))) {
    return CardType.Discover;
  } else if (value.startsWith(RegExp(r'((30[0-5])|(3[89])|(36)|(3095))'))) {
    return CardType.DinersClub;
  } else if (value.startsWith(RegExp(r'(352[89]|35[3-8][0-9])'))) {
    return CardType.Jcb;
  } else if (value.length <= 8) {
    return CardType.Others;
  } else {
    return CardType.Invalid;
  }
}

Widget getCardIcon(CardType cardType) {

  var img = '';
  Icon? icon;
  switch (cardType) {
    case CardType.Master:
      img = 'ic_payment_mastercard.png';
      break;
    case CardType.Visa:
      img = 'ic_payment_visa.png';
      break;
    case CardType.Verve:
      img = 'ic_payment_card.png';
      break;
    case CardType.Discover:
      img = 'ic_payment_card.png';
      break;
    case CardType.AmericanExpress:
      img = 'ic_payment_amex.png';
      break;
    case CardType.DinersClub:
      img = 'ic_payment_card.png';
      break;
    case CardType.Jcb:
      img = 'ic_payment_card.png';
      break;
    case CardType.Others:
      icon = Icon(
        Icons.credit_card,
        size: 40.0,
        color: Colors.grey[600],
      );
      break;
    case CardType.Invalid:
      icon = Icon(
        Icons.warning,
        color: Colors.grey[600],
      );
      break;
  }

  Widget widget;
  if (img.isNotEmpty) {
    widget = Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Image.asset(
        'assets/images/$img',
      ),
    );
  } else {
    widget = icon ?? Container();
  }
  return widget;
}
