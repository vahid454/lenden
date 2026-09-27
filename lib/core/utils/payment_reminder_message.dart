import 'app_formatters.dart';

class PaymentReminderMessage {
  PaymentReminderMessage._();

  static String buildBilingual({
    required String customerName,
    required String ownerName,
    required String businessName,
    required double amount,
  }) {
    final name = customerName.trim().isEmpty ? 'Customer' : customerName.trim();
    final owner = ownerName.trim().isEmpty ? 'the owner' : ownerName.trim();
    final business = businessName.trim().isEmpty ? owner : businessName.trim();
    final balance = amount.abs();
    final amountText = AppFormatters.rupee(balance);
    final wholeRupees = balance.floor();
    final paise = ((balance - wholeRupees) * 100).round();
    final englishAmount = _englishNumber(wholeRupees);
    final hindiAmount = _hindiNumber(wholeRupees);
    final englishWords = paise == 0
        ? '$englishAmount rupees'
        : '$englishAmount rupees and $paise paise';
    final hindiWords = paise == 0
        ? '$hindiAmount rupaye'
        : '$hindiAmount rupaye aur $paise paise';

    if (amount < 0) {
      return 'Hello $name Ji,\n\nNamaste,\n'
          '$business ke khate ke anusaar $owner ke aapko $amountText ($hindiWords) dene baaki hain. '
          'Kripya suvidha anusar bhugtan svikaar karne ki kripa karein.\n'
          'Dhanyavaad,\n$owner\n\n'
          'English:\nHello $name Ji,\n\n'
          '$amountText ($englishWords) is owed to you by $owner from $business. '
          'Please collect it at your convenience.\n'
          'Thank you,\n$owner';
    }

    return 'Hello $name Ji,\n\nNamaste,\n'
        '$business ke aapke khate mein $amountText ($hindiWords) baaki hain. '
        'Kripya $owner ko jald se jald bhugtan karne ki kripa karein.\n'
        'Dhanyavaad,\n$owner\n\n'
        'English:\nHello $name Ji,\n\n'
        '$amountText ($englishWords) is currently pending on your account at $business. '
        'Kindly pay $owner at your earliest convenience.\n'
        'Thank you,\n$owner';
  }

  static String build({
    required String customerName,
    required String senderName,
    required double amount,
    required bool ownerOwes,
    DateTime? dueDate,
  }) {
    final name = customerName.trim();
    final sender = senderName.trim().isEmpty ? 'LenDen' : senderName.trim();
    final amountText = AppFormatters.rupee(amount.abs());

    if (ownerOwes) {
      return 'Hi $name, I owe you $amountText. I will settle it soon. - $sender';
    }

    final dueText =
        dueDate == null ? '' : ', due ${AppFormatters.shortDate(dueDate)}';
    return 'Hi $name, you owe me $amountText$dueText. '
        'Kindly arrange the payment. - $sender';
  }

  static String _englishNumber(int value) {
    const small = [
      'Zero',
      'One',
      'Two',
      'Three',
      'Four',
      'Five',
      'Six',
      'Seven',
      'Eight',
      'Nine',
      'Ten',
      'Eleven',
      'Twelve',
      'Thirteen',
      'Fourteen',
      'Fifteen',
      'Sixteen',
      'Seventeen',
      'Eighteen',
      'Nineteen',
    ];
    const tens = [
      '',
      '',
      'Twenty',
      'Thirty',
      'Forty',
      'Fifty',
      'Sixty',
      'Seventy',
      'Eighty',
      'Ninety',
    ];
    String underHundred(int number) => number < 20
        ? small[number]
        : '${tens[number ~/ 10]}${number % 10 == 0 ? '' : ' ${small[number % 10]}'}';
    String underThousand(int number) {
      final hundreds = number ~/ 100;
      final remainder = number % 100;
      return [
        if (hundreds > 0) '${small[hundreds]} Hundred',
        if (remainder > 0) underHundred(remainder),
      ].join(' ');
    }

    if (value == 0) return small.first;
    if (value >= 1000000000) return value.toString();
    final groups = <String>[];
    var remaining = value;
    for (final scale in const [
      (10000000, 'Crore'),
      (100000, 'Lakh'),
      (1000, 'Thousand'),
    ]) {
      final count = remaining ~/ scale.$1;
      if (count > 0) {
        groups.add('${underThousand(count)} ${scale.$2}');
        remaining %= scale.$1;
      }
    }
    if (remaining > 0) groups.add(underThousand(remaining));
    return groups.join(' ');
  }

  static String _hindiNumber(int value) {
    const words = [
      'Shunya',
      'Ek',
      'Do',
      'Teen',
      'Chaar',
      'Paanch',
      'Chhah',
      'Saat',
      'Aath',
      'Nau',
      'Das',
      'Gyarah',
      'Barah',
      'Terah',
      'Chaudah',
      'Pandrah',
      'Solah',
      'Satrah',
      'Atharah',
      'Unnees',
      'Bees',
      'Ikkis',
      'Baais',
      'Teis',
      'Chaubis',
      'Pachchis',
      'Chhabis',
      'Sattais',
      'Atthais',
      'Untis',
      'Tees',
      'Ikattis',
      'Battis',
      'Taintis',
      'Chauntis',
      'Paintis',
      'Chhattis',
      'Saintis',
      'Adtis',
      'Untalis',
      'Chalis',
      'Iktalis',
      'Bayalis',
      'Taintalis',
      'Chawalis',
      'Paintalis',
      'Chiyalis',
      'Saintalis',
      'Atthalis',
      'Unchaas',
      'Pachaas',
      'Ikyavan',
      'Bavan',
      'Tirpan',
      'Chauvan',
      'Pachpan',
      'Chhappan',
      'Sattavan',
      'Athavan',
      'Unsath',
      'Saath',
      'Iksath',
      'Basath',
      'Tirsath',
      'Chaunsath',
      'Painsath',
      'Chhiyasath',
      'Sadsath',
      'Adsath',
      'Unhattar',
      'Sattar',
      'Ikhattar',
      'Bahattar',
      'Tihattar',
      'Chauhattar',
      'Pachhattar',
      'Chihattar',
      'Satahattar',
      'Athhattar',
      'Unasi',
      'Assi',
      'Ikyasi',
      'Bayasi',
      'Tirasi',
      'Chaurasi',
      'Pachasi',
      'Chhiyasi',
      'Sattasi',
      'Athasi',
      'Navasi',
      'Nabbe',
      'Ikyaanve',
      'Baanve',
      'Tiraanve',
      'Chauraanve',
      'Pachaanve',
      'Chhiyaanve',
      'Sattaanve',
      'Athaanve',
      'Ninyaanve',
    ];
    String underHundred(int number) => words[number];
    String underThousand(int number) {
      final hundreds = number ~/ 100;
      final remainder = number % 100;
      return [
        if (hundreds > 0) '${words[hundreds]} Sau',
        if (remainder > 0) underHundred(remainder),
      ].join(' ');
    }

    if (value == 0) return words.first;
    if (value >= 1000000000) return value.toString();
    final groups = <String>[];
    var remaining = value;
    for (final scale in const [
      (10000000, 'Crore'),
      (100000, 'Lakh'),
      (1000, 'Hazar'),
    ]) {
      final count = remaining ~/ scale.$1;
      if (count > 0) {
        groups.add('${underThousand(count)} ${scale.$2}');
        remaining %= scale.$1;
      }
    }
    if (remaining > 0) groups.add(underThousand(remaining));
    return groups.join(' ');
  }
}
