class ApiError implements Exception {
  ApiError(this.status, this.body) : message = 'API request failed ($status)';

  final int status;
  final Object? body;
  final String message;

  @override
  String toString() => message;
}
