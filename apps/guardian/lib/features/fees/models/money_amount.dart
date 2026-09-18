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

int currencyFractionDigits(String currency) {
  switch (currency.toUpperCase()) {
    case 'XOF':
    case 'XAF':
    case 'JPY':
    case 'KRW':
    case 'GNF':
      return 0;
    default:
      return 2;
  }
}
