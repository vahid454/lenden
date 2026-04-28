/// App-level exception that carries a human-readable message.
/// Bridges Firebase exceptions → clean Failure objects.
class AppException implements Exception {
  final String message;
  final String? code;

  const AppException(this.message, {this.code});

  @override
  String toString() => 'AppException($code): $message';
}
