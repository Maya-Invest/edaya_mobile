import 'package:intl/intl.dart';

int parseMinorUnits(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.round();
  }
  if (value is Map) {
    return parseMinorUnits(value['amount']);
  }
  return 0;
}

String requireFinanceCurrency(Object? value) {
  if (value is! String || !RegExp(r'^[A-Z]{3}$').hasMatch(value)) {
    throw const FormatException('A financial record is missing its currency');
  }
  return value;
}

int currencyFractionDigits(String currency) {
  return NumberFormat.currency(
        name: requireFinanceCurrency(currency),
      ).decimalDigits ??
      2;
}
