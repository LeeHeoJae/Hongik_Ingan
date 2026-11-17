part of 'auth_service.dart';

class AttendanceSessionException implements Exception {
  const AttendanceSessionException(
    this.message, {
    this.sessionExpired = false,
    this.ssoIntegrationError = false,
  });

  final String message;
  final bool sessionExpired;
  final bool ssoIntegrationError;
}

class SecurityCodeException implements Exception {
  const SecurityCodeException();
}

class SsoValidationResult {
  const SsoValidationResult(
    this.isAccepted,
    this.message, {
    this.isCredentialRejection = false,
    this.requiresSecurityCode = false,
  });

  final bool isAccepted;
  final String message;
  final bool isCredentialRejection;
  final bool requiresSecurityCode;

  factory SsoValidationResult.fromJson(Map<String, dynamic> json) {
    final message = json['result_msg']?.toString() ?? 'Login failed';
    return SsoValidationResult(
      json['result_code'] == 'Y',
      message,
      requiresSecurityCode: json['pin_use']?.toString() == '1',
      isCredentialRejection:
          json['result_code'] == 'N' &&
          !AttendanceSessionResponse(message).integrationError,
    );
  }
}
