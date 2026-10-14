String? validatePayment(
  String method,
  Map<String, String> fields, {
  DateTime? now,
}) {
  if (method != 'card' && method != 'gcash') return 'Choose a payment method.';
  for (final field
      in method == 'gcash'
          ? ['mobile']
          : ['number', 'holder', 'expiry', 'cvc']) {
    final error = validatePaymentField(field, fields[field], now: now);
    if (error != null) return error;
  }
  return null;
}

String? validatePaymentField(String field, String? value, {DateTime? now}) {
  final text = value ?? '';
  switch (field) {
    case 'mobile':
      return RegExp(r'^(09\d{9}|\+639\d{9})$').hasMatch(text)
          ? null
          : 'Enter a Philippine GCash mobile number.';
    case 'number':
      final number = text.replaceAll(RegExp(r'[ -]'), '');
      if (!RegExp(r'^\d{12,19}$').hasMatch(number)) {
        return 'Enter a valid card number with 12 to 19 digits.';
      }
      var sum = 0;
      for (var i = 0; i < number.length; i++) {
        var digit = int.parse(number[number.length - 1 - i]);
        if (i.isOdd) digit *= 2;
        sum += digit > 9 ? digit - 9 : digit;
      }
      return sum % 10 == 0 ? null : 'Enter a valid card number.';
    case 'holder':
      return text.trim().isEmpty || text.length > 100
          ? 'Enter the name on your card.'
          : null;
    case 'expiry':
      if (!RegExp(r'^(0[1-9]|1[0-2])/\d{2}$').hasMatch(text)) {
        return 'Enter expiry as MM/YY.';
      }
      return DateTime(
            2000 + int.parse(text.substring(3)),
            int.parse(text.substring(0, 2)) + 1,
          ).isAfter(now ?? DateTime.now())
          ? null
          : 'Your card has expired.';
    case 'cvc':
      return RegExp(r'^\d{3,4}$').hasMatch(text)
          ? null
          : 'Enter a three or four digit CVC.';
    default:
      return null;
  }
}

Map<String, String> paymentReference(
  String method,
  Map<String, String> fields,
) {
  final number = method == 'gcash'
      ? fields['mobile']!
      : fields['number']!.replaceAll(RegExp(r'[ -]'), '');
  return {
    'method': method,
    'brand': method == 'gcash'
        ? 'gcash'
        : number.startsWith('4')
        ? 'visa'
        : RegExp(r'^(5[1-5]|2[2-7])').hasMatch(number)
        ? 'mastercard'
        : 'card',
    'last4': number.substring(number.length - 4),
  };
}
