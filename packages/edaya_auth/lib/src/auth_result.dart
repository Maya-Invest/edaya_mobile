import 'auth_error.dart';

class AuthResult<T> {
  const AuthResult({this.data, this.error});

  const AuthResult.success(T value) : data = value, error = null;

  const AuthResult.failure(AuthError value) : data = null, error = value;

  final T? data;
  final AuthError? error;

  bool get isSuccess => error == null;
}
