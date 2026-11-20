// Input validators.

abstract final class Validators {
  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email address is required';
    }
    final email = value.trim();
    if (email.length > 254) {
      return 'Email address must be 254 characters or fewer';
    }
    final emailPattern = RegExp(
      r"^[A-Za-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[A-Za-z0-9!#$%&'*+/=?^_`{|}~-]+)*@(?:[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z]{2,63}$",
    );
    if (!emailPattern.hasMatch(email)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  static String? password(String? value, {int minLength = 8}) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < minLength) {
      return 'Use at least $minLength characters';
    }
    if (value.length > 72) {
      return 'Password must be 72 characters or fewer';
    }
    return null;
  }

  static String? confirmPassword(String? value, String? passwordValue) {
    final passwordError = password(value);
    if (passwordError != null) return passwordError;
    if (value != passwordValue) {
      return 'Passwords do not match';
    }
    return null;
  }

  static String? name(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Full name is required';
    }
    if (value.trim().length > 100) {
      return 'Name must be less than 100 characters';
    }
    return null;
  }

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }
    final phone = value.trim().replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (phone.length < 10 || phone.length > 15) {
      return 'Enter a valid phone number';
    }
    if (!RegExp(r'^(\+?254|0)?[17]\d{8}$').hasMatch(phone)) {
      return 'Enter a valid Kenyan phone number';
    }
    return null;
  }

  static String? otp(String? value, {int length = 6}) {
    if (value == null || value.trim().isEmpty) {
      return 'Code is required';
    }
    final code = value.trim();
    if (code.length != length) {
      return 'Enter the $length-digit code';
    }
    if (!RegExp(r'^\d+$').hasMatch(code)) {
      return 'Code must contain only numbers';
    }
    return null;
  }

  static String? recoveryCode(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Recovery code is required';
    }
    final code = value.trim().toUpperCase().replaceAll(RegExp(r'[-\s]'), '');
    if (code.length < 8 ||
        code.length > 32 ||
        !RegExp(r'^[A-Z0-9]+$').hasMatch(code)) {
      return 'Enter a valid recovery code';
    }
    return null;
  }

  static String? required(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  static String? minLength(String? value, int min, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    if (value.trim().length < min) {
      return '$fieldName must be at least $min characters';
    }
    return null;
  }

  static String? maxLength(String? value, int max, String fieldName) {
    if (value != null && value.length > max) {
      return '$fieldName must be less than $max characters';
    }
    return null;
  }

  static String? termsAccepted(bool? value) {
    if (value != true) {
      return 'You must accept the terms and privacy policy';
    }
    return null;
  }
}

extension ValidatorExtensions on String? {
  String? get email => Validators.email(this);
  String? get password => Validators.password(this);
  String? confirmPassword(String? password) =>
      Validators.confirmPassword(this, password);
  String? get name => Validators.name(this);
  String? get phone => Validators.phone(this);
  String? otp({int length = 6}) => Validators.otp(this, length: length);
  String? get recoveryCode => Validators.recoveryCode(this);
}
