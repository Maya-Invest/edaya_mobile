import 'package:edaya_guardian/features/fees/models/money_amount.dart';
import 'package:edaya_guardian/features/fees/models/payment_record.dart';
import 'package:edaya_guardian/features/fees/models/student_charge_line.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
  });
  test('configured currencies retain their actual minor-unit precision', () {
    expect(currencyFractionDigits('XOF'), 0);
    expect(currencyFractionDigits('EUR'), 2);
    expect(currencyFractionDigits('KWD'), 3);
  });
}
