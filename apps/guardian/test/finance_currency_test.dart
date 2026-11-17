import 'package:edaya_guardian_v2/features/fees/models/fee_formatting.dart';
import 'package:edaya_guardian_v2/features/fees/models/money_amount.dart';
import 'package:edaya_guardian_v2/features/fees/models/payment_record.dart';
import 'package:edaya_guardian_v2/features/fees/models/student_charge_line.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cash amounts retain minor units and use the selected language', () {
    expect(formatMoney(123450, 'EUR', 'en'), '€1,234.50');
    expect(formatMoney(123450, 'EUR', 'fr').replaceAll(RegExp(r'[\s\u202f]+'), ' '), '1 234,50 €');
    expect(formatMoney(12345, 'KWD', 'fr'), contains('12,345'));
  });
  test('finance summaries and charges require explicit currency', () {
    expect(
      () => FeesSummary.fromJson({
        'available': 0,
        'outstanding': 0,
        'overdue': 0,
      }),
      throwsFormatException,
    );
    expect(
      () =>
          StudentChargeLine.fromJson({'id': 'charge', 'expectedAmount': 1200}),
      throwsFormatException,
    );
    expect(
      StudentChargeLine.fromJson({
        'id': 'charge',
        'expectedAmount': {'amount': 1200, 'currency': 'XOF'},
      }).currency,
      'XOF',
    );
    expect(
      FeesSummary.fromJson({
        'currency': 'EUR',
        'available': 25,
        'outstanding': 100,
        'overdue': 50,
      }).currency,
      'EUR',
    );
  });
  test('payment currency must agree with the school summary', () {
    final payment = <String, dynamic>{
      'id': 'payment',
      'currency': 'USD',
      'amount': 1200,
      'paymentDate': '2026-09-24',
    };
    expect(
      () =>
          PaymentRecord.fromJson(payment, feeLabel: 'Tuition', currency: 'EUR'),
      throwsFormatException,
    );
    expect(
      PaymentRecord.fromJson(
        payment,
        feeLabel: 'Tuition',
        currency: 'USD',
      ).currency,
      'USD',
    );
    expect(
      PaymentRecord.fromJson(
        {
          'id': 'payment',
          'amount': {'amount': 1200, 'currency': 'XOF'},
          'paymentDate': '2026-09-24',
        },
        feeLabel: 'Tuition',
        currency: 'XOF',
      ).currency,
      'XOF',
    );
  });
  test('configured currencies retain their actual minor-unit precision', () {
    expect(currencyFractionDigits('XOF'), 0);
    expect(currencyFractionDigits('EUR'), 2);
    expect(currencyFractionDigits('KWD'), 3);
  });
}
