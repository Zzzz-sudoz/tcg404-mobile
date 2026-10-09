String? validatePayment(
  String method,
  Map<String, String> fields, {
  DateTime? now,
}) {
  if (method == 'gcash') {
    return RegExp(r'^(09\d{9}|\+639\d{9})$').hasMatch(fields['mobile'] ?? '')
        ? null
        : 'Enter a Philippine GCash mobile number.';
  }
  if (method != 'card') return 'Choose a payment method.';
  final number = (fields['number'] ?? '').replaceAll(RegExp(r'[ -]'), '');
  if (!RegExp(r'^\d{13,19}$').hasMatch(number)) {
    return 'Enter a valid card number.';
  }
  var sum = 0;
  for (var i = 0; i < number.length; i++) {
    var digit = int.parse(number[number.length - 1 - i]);
    if (i.isOdd) digit *= 2;
    sum += digit > 9 ? digit - 9 : digit;
  }
  if (sum % 10 != 0) return 'Enter a valid card number.';
  if ((fields['holder'] ?? '').trim().isEmpty ||
      fields['holder']!.length > 100) {
    return 'Enter the name on your card.';
  }
  final expiry = fields['expiry'] ?? '';
  if (!RegExp(r'^(0[1-9]|1[0-2])/\d{2}$').hasMatch(expiry)) {
    return 'Enter expiry as MM/YY.';
  }
  final today = now ?? DateTime.now();
  if (!DateTime(
    2000 + int.parse(expiry.substring(3)),
    int.parse(expiry.substring(0, 2)) + 1,
  ).isAfter(today)) {
    return 'Your card has expired.';
  }
  if (!RegExp(r'^\d{3,4}$').hasMatch(fields['cvc'] ?? '')) {
    return 'Enter a three or four digit CVC.';
  }
  return null;
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
