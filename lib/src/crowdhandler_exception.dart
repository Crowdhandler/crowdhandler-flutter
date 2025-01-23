/// A custom exception type for CrowdHandler-related errors.
class CrowdHandlerException implements Exception {
  final String message;
  final String? details;

  CrowdHandlerException(this.message, [this.details]);

  @override
  String toString() {
    return 'CrowdHandlerException: $message\nDetails: $details';
  }
}
