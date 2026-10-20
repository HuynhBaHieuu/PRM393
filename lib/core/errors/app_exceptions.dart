/// Base class for errors whose [message] is safe to show to the user.
abstract class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

class StorageException extends AppException {
  const StorageException([
    super.message = 'Your changes could not be saved. Please try again.',
  ]);
}

class InvalidImageException extends AppException {
  const InvalidImageException([
    super.message = 'This image could not be used. Try another photo.',
  ]);
}

class ImagePickException extends AppException {
  const ImagePickException([
    super.message = 'Could not access your photos. Check app permissions.',
  ]);
}

class ValidationException extends AppException {
  const ValidationException(super.message);
}

/// Sign-in or registration failed for a reason the user can fix.
class AuthException extends AppException {
  const AuthException(super.message);
}

/// The AI stylist could not produce suggestions.
class AiException extends AppException {
  const AiException(super.message);
}

/// Weather could not be loaded.
class WeatherException extends AppException {
  const WeatherException(super.message);
}

/// The action needs Premium, e.g. adding past the Free wardrobe limit.
class PlanLimitException extends AppException {
  const PlanLimitException(super.message);
}

/// A Premium payment could not be started or checked.
class PaymentException extends AppException {
  const PaymentException(super.message);
}

class NotFoundException extends AppException {
  const NotFoundException([super.message = 'This item no longer exists.']);
}

const String genericErrorMessage = 'Something went wrong. Please try again.';

/// Converts any error into a user-facing message.
String describeError(Object error) =>
    error is AppException ? error.message : genericErrorMessage;
