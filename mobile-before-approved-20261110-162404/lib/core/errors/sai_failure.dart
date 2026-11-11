class SaiFailure implements Exception {
  const SaiFailure(this.message, {this.cause});
  final String message;
  final Object? cause;
  @override
  String toString() => 'SaiFailure: $message';
}
