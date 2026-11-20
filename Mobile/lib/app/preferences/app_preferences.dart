import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:intl/intl.dart';

class AppPreferences {
  const AppPreferences({
    this.language = 'en',
    this.theme = 'system',
    this.currency = 'KES',
    this.timezone = 'Africa/Nairobi',
    this.dateFormat = 'dd/MM/yyyy',
    this.numberFormat = 'en-KE',
    this.pushNotifications = true,
    this.emailNotifications = true,
    this.smsNotifications = true,
  });

  final String language;
  final String theme;
  final String currency;
  final String timezone;
  final String dateFormat;
  final String numberFormat;
  final bool pushNotifications;
  final bool emailNotifications;
  final bool smsNotifications;

  ThemeMode get themeMode => switch (theme) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  Locale get locale => Locale(language);

  factory AppPreferences.fromJson(Map<String, dynamic> json) => AppPreferences(
    language: json['language'] as String? ?? 'en',
    theme: json['theme'] as String? ?? 'system',
    currency: json['currency'] as String? ?? 'KES',
    timezone: json['timezone'] as String? ?? 'Africa/Nairobi',
    dateFormat: json['dateFormat'] as String? ?? 'dd/MM/yyyy',
    numberFormat: json['numberFormat'] as String? ?? 'en-KE',
    pushNotifications: json['pushNotifications'] as bool? ?? true,
    emailNotifications: json['emailNotifications'] as bool? ?? true,
    smsNotifications: json['smsNotifications'] as bool? ?? true,
  );
}

final appPreferencesProvider = StateProvider<AppPreferences>(
  (ref) => const AppPreferences(),
);

class AppFormatters {
  AppFormatters._();

  static AppPreferences _preferences = const AppPreferences();

  static void update(AppPreferences preferences) {
    _preferences = preferences;
    Intl.defaultLocale = preferences.numberFormat;
  }

  static String currency(num amount, {int? decimalDigits}) {
    return NumberFormat.currency(
      locale: _preferences.numberFormat,
      name: _preferences.currency,
      decimalDigits: decimalDigits,
    ).format(amount);
  }

  static String number(num value, {int? decimalDigits}) {
    final formatter = NumberFormat.decimalPattern(_preferences.numberFormat);
    if (decimalDigits != null) formatter.maximumFractionDigits = decimalDigits;
    return formatter.format(value);
  }

  static String date(DateTime value) {
    return DateFormat(
      _preferences.dateFormat,
      _preferences.numberFormat,
    ).format(_toPreferenceTimezone(value));
  }

  static String dateTime(DateTime value) {
    return DateFormat(
      '${_preferences.dateFormat} HH:mm',
      _preferences.numberFormat,
    ).format(_toPreferenceTimezone(value));
  }

  static String relativeTime(DateTime value, {DateTime? now}) {
    final difference = (now ?? DateTime.now()).difference(value);
    if (difference.isNegative) {
      return _preferences.language == 'sw' ? 'baadaye' : 'in the future';
    }
    final locale = _preferences.language;
    if (difference.inDays > 0) {
      final days = number(difference.inDays);
      return locale == 'sw' ? 'siku $days zilizopita' : '$days d ago';
    }
    if (difference.inHours > 0) {
      final hours = number(difference.inHours);
      return locale == 'sw' ? 'saa $hours zilizopita' : '$hours h ago';
    }
    if (difference.inMinutes > 0) {
      final minutes = number(difference.inMinutes);
      return locale == 'sw' ? 'dakika $minutes zilizopita' : '$minutes m ago';
    }
    return locale == 'sw' ? 'sasa hivi' : 'Just now';
  }

  static String remainingTime(DateTime value, {DateTime? now}) {
    final difference = value.difference(now ?? DateTime.now());
    if (difference.isNegative) {
      return _preferences.language == 'sw' ? 'Muda umeisha' : 'Expired';
    }
    final locale = _preferences.language;
    if (difference.inDays > 0) {
      final days = number(difference.inDays);
      final hours = number(difference.inHours % 24);
      return locale == 'sw' ? 'siku $days saa $hours' : '${days}d ${hours}h';
    }
    if (difference.inHours > 0) {
      final hours = number(difference.inHours);
      final minutes = number(difference.inMinutes % 60);
      return locale == 'sw'
          ? 'saa $hours dakika $minutes'
          : '${hours}h ${minutes}m';
    }
    final minutes = number(difference.inMinutes);
    return locale == 'sw' ? 'dakika $minutes' : '${minutes}m';
  }

  static DateTime _toPreferenceTimezone(DateTime value) {
    final utc = value.toUtc();
    final offset = switch (_preferences.timezone) {
      'UTC' => Duration.zero,
      _ => const Duration(hours: 3),
    };
    return utc.add(offset);
  }
}
