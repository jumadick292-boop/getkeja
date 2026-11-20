// App theme using Material 3 and design system.

import 'package:flutter/material.dart';

import '../theme/design_system.dart';

abstract final class AppTheme {
  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
      onPrimary: isDark ? AppColors.darkOnPrimary : AppColors.lightOnPrimary,
      secondary: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
      onSecondary: isDark ? AppColors.darkOnSecondary : AppColors.lightOnSecondary,
      tertiary: isDark ? AppColors.darkTertiary : AppColors.lightTertiary,
      onTertiary: isDark ? AppColors.darkOnTertiary : AppColors.lightOnTertiary,
      primaryContainer: isDark ? AppColors.darkPrimaryContainer : AppColors.lightPrimaryContainer,
      onPrimaryContainer: isDark ? AppColors.darkOnPrimaryContainer : AppColors.lightOnPrimaryContainer,
      secondaryContainer: isDark ? AppColors.darkSuccessContainer : AppColors.lightSuccessContainer,
      onSecondaryContainer: isDark ? AppColors.darkOnSuccessContainer : AppColors.lightOnSuccessContainer,
      tertiaryContainer: isDark ? AppColors.darkErrorContainer : AppColors.lightErrorContainer,
      onTertiaryContainer: isDark ? AppColors.darkOnErrorContainer : AppColors.lightOnErrorContainer,
      surface: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      onSurface: isDark ? AppColors.darkOnSurface : AppColors.lightOnSurface,
      onSurfaceVariant: isDark ? AppColors.darkOnSurfaceVariant : AppColors.lightOnSurfaceVariant,
      outline: isDark ? AppColors.darkOutline : AppColors.lightOutline,
      outlineVariant: isDark ? AppColors.darkOutline : AppColors.lightOutline,
      error: isDark ? AppColors.darkError : AppColors.lightError,
      onError: isDark ? AppColors.darkOnErrorContainer : AppColors.lightOnErrorContainer,
      errorContainer: isDark ? AppColors.darkErrorContainer : AppColors.lightErrorContainer,
      onErrorContainer: isDark ? AppColors.darkOnErrorContainer : AppColors.lightOnErrorContainer,
      surfaceContainerHighest: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      surfaceContainerHigh: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      surfaceContainer: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      surfaceContainerLow: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      surfaceContainerLowest: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      scrim: Colors.black,
      shadow: Colors.black,
      inverseSurface: isDark ? AppColors.lightSurface : AppColors.darkSurface,
      onInverseSurface: isDark ? AppColors.lightOnSurface : AppColors.darkOnSurface,
      inversePrimary: isDark ? AppColors.lightPrimary : AppColors.darkPrimary,
      surfaceTint: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: AppTypography.fontFamily,
      scaffoldBackgroundColor: isDark ? AppColors.navy : AppColors.pageBackground,
    );

    return base.copyWith(
      brightness: brightness,
      textTheme: _textTheme(base.textTheme, isDark),
      appBarTheme: _appBarTheme(colorScheme, isDark),
      cardTheme: _cardTheme(colorScheme, isDark),
      inputDecorationTheme: _inputDecorationTheme(colorScheme, isDark),
      filledButtonTheme: _filledButtonTheme(colorScheme),
      outlinedButtonTheme: _outlinedButtonTheme(colorScheme),
      textButtonTheme: _textButtonTheme(colorScheme, isDark),
      elevatedButtonTheme: _elevatedButtonTheme(colorScheme),
      navigationBarTheme: _navigationBarTheme(colorScheme, isDark),
      bottomNavigationBarTheme: _bottomNavigationBarTheme(colorScheme, isDark),
      dialogTheme: _dialogTheme(colorScheme, isDark),
      bottomSheetTheme: _bottomSheetTheme(colorScheme, isDark),
      snackBarTheme: _snackBarTheme(colorScheme, isDark),
      dividerTheme: _dividerTheme(colorScheme, isDark),
      chipTheme: _chipTheme(colorScheme, isDark),
      tabBarTheme: _tabBarTheme(colorScheme, isDark),
      progressIndicatorTheme: _progressIndicatorTheme(colorScheme),
      checkboxTheme: _checkboxTheme(colorScheme),
      radioTheme: _radioTheme(colorScheme),
      switchTheme: _switchTheme(colorScheme),
      sliderTheme: _sliderTheme(colorScheme),
      listTileTheme: _listTileTheme(colorScheme, isDark),
      tooltipTheme: _tooltipTheme(colorScheme, isDark),
    );
  }

  static TextTheme _textTheme(TextTheme base, bool isDark) {
    final foreground = isDark ? AppColors.pageBackground : AppColors.text;
    final onSurfaceVariant = isDark ? AppColors.darkOnSurfaceVariant : AppColors.lightOnSurfaceVariant;

    return base.apply(
      bodyColor: foreground,
      displayColor: foreground,
    ).copyWith(
      displayLarge: AppTypography.displayLarge.copyWith(color: foreground),
      displayMedium: AppTypography.displayMedium.copyWith(color: foreground),
      displaySmall: AppTypography.displaySmall.copyWith(color: foreground),
      headlineLarge: AppTypography.headlineLarge.copyWith(color: foreground),
      headlineMedium: AppTypography.headlineMedium.copyWith(color: foreground),
      headlineSmall: AppTypography.headlineSmall.copyWith(color: foreground),
      titleLarge: AppTypography.titleLarge.copyWith(color: foreground),
      titleMedium: AppTypography.titleMedium.copyWith(color: foreground),
      titleSmall: AppTypography.titleSmall.copyWith(color: foreground),
      bodyLarge: AppTypography.bodyLarge.copyWith(color: foreground),
      bodyMedium: AppTypography.bodyMedium.copyWith(color: foreground),
      bodySmall: AppTypography.bodySmall.copyWith(color: onSurfaceVariant),
      labelLarge: AppTypography.labelLarge.copyWith(color: foreground),
      labelMedium: AppTypography.labelMedium.copyWith(color: onSurfaceVariant),
      labelSmall: AppTypography.labelSmall.copyWith(color: onSurfaceVariant),
    );
  }

  static AppBarTheme _appBarTheme(ColorScheme colors, bool isDark) {
    return AppBarTheme(
      backgroundColor: isDark ? AppColors.navy : AppColors.surfaceWhite,
      foregroundColor: isDark ? AppColors.pageBackground : AppColors.text,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: AppTypography.titleLarge.copyWith(
        color: isDark ? AppColors.pageBackground : AppColors.text,
        fontWeight: FontWeight.w700,
      ),
      iconTheme: IconThemeData(
        color: isDark ? AppColors.pageBackground : AppColors.text,
        size: 24,
      ),
      actionsIconTheme: IconThemeData(
        color: isDark ? AppColors.pageBackground : AppColors.text,
        size: 24,
      ),
    );
  }

  static CardThemeData _cardTheme(ColorScheme colors, bool isDark) {
    return CardThemeData(
      color: colors.surface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: AppBorderRadius.largeRadius,
        side: BorderSide(color: colors.outline, width: 1),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
    );
  }

  static InputDecorationTheme _inputDecorationTheme(ColorScheme colors, bool isDark) {
    final outlineColor = colors.outline;
    final focusColor = colors.primary;

    return InputDecorationTheme(
      filled: true,
      fillColor: colors.surface,
      contentPadding: AppSpacing.inputPadding,
      border: OutlineInputBorder(
        borderRadius: AppBorderRadius.mediumRadius,
        borderSide: BorderSide(color: outlineColor, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppBorderRadius.mediumRadius,
        borderSide: BorderSide(color: outlineColor, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppBorderRadius.mediumRadius,
        borderSide: BorderSide(color: focusColor, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppBorderRadius.mediumRadius,
        borderSide: BorderSide(color: colors.error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: AppBorderRadius.mediumRadius,
        borderSide: BorderSide(color: colors.error, width: 1.5),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: AppBorderRadius.mediumRadius,
        borderSide: BorderSide(color: outlineColor.withValues(alpha: 0.5), width: 1),
      ),
      labelStyle: AppTypography.bodyMedium.copyWith(color: colors.onSurfaceVariant),
      floatingLabelStyle: AppTypography.bodySmall.copyWith(color: focusColor),
      hintStyle: AppTypography.bodyMedium.copyWith(color: colors.onSurfaceVariant.withValues(alpha: 0.6)),
      errorStyle: AppTypography.bodySmall.copyWith(color: colors.error),
      helperStyle: AppTypography.bodySmall.copyWith(color: colors.onSurfaceVariant),
      counterStyle: AppTypography.bodySmall.copyWith(color: colors.onSurfaceVariant),
      prefixIconColor: colors.onSurfaceVariant,
      suffixIconColor: colors.onSurfaceVariant,
    );
  }

  static FilledButtonThemeData _filledButtonTheme(ColorScheme colors) {
    return FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 52),
        padding: AppSpacing.buttonPadding,
        shape: RoundedRectangleBorder(
          borderRadius: AppBorderRadius.mediumRadius,
        ),
        textStyle: AppTypography.labelLarge.copyWith(
          fontWeight: FontWeight.w700,
        ),
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        disabledBackgroundColor: colors.primary.withValues(alpha: 0.38),
        disabledForegroundColor: colors.onPrimary.withValues(alpha: 0.38),
      ),
    );
  }

  static OutlinedButtonThemeData _outlinedButtonTheme(ColorScheme colors) {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 52),
        padding: AppSpacing.buttonPadding,
        shape: RoundedRectangleBorder(
          borderRadius: AppBorderRadius.mediumRadius,
        ),
        textStyle: AppTypography.labelLarge.copyWith(
          fontWeight: FontWeight.w700,
        ),
        foregroundColor: colors.primary,
        side: BorderSide(color: colors.outline, width: 1),
        disabledForegroundColor: colors.onSurfaceVariant.withValues(alpha: 0.38),
      ),
    );
  }

  static TextButtonThemeData _textButtonTheme(ColorScheme colors, bool isDark) {
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 44),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: AppBorderRadius.mediumRadius,
        ),
        textStyle: AppTypography.labelLarge.copyWith(
          fontWeight: FontWeight.w700,
        ),
        foregroundColor: isDark ? colors.primary : AppColors.navy,
        disabledForegroundColor: colors.onSurfaceVariant.withValues(alpha: 0.38),
      ),
    );
  }

  static ElevatedButtonThemeData _elevatedButtonTheme(ColorScheme colors) {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(64, 52),
        padding: AppSpacing.buttonPadding,
        shape: RoundedRectangleBorder(
          borderRadius: AppBorderRadius.mediumRadius,
        ),
        textStyle: AppTypography.labelLarge.copyWith(
          fontWeight: FontWeight.w700,
        ),
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        elevation: 0,
        shadowColor: Colors.transparent,
        disabledBackgroundColor: colors.primary.withValues(alpha: 0.38),
        disabledForegroundColor: colors.onPrimary.withValues(alpha: 0.38),
      ),
    );
  }

  static NavigationBarThemeData _navigationBarTheme(ColorScheme colors, bool isDark) {
    return NavigationBarThemeData(
      backgroundColor: colors.surface,
      indicatorColor: isDark ? colors.primary : colors.primaryContainer,
      iconTheme: WidgetStateProperty.resolveWith<IconThemeData?>((states) {
        final isSelected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: isSelected
              ? (isDark ? AppColors.navy : AppColors.navy)
              : (isDark ? AppColors.darkOnSurfaceVariant : AppColors.mutedText),
          size: 24,
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>((states) {
        final isSelected = states.contains(WidgetState.selected);
        return AppTypography.labelSmall.copyWith(
          color: isSelected
              ? (isDark ? AppColors.pageBackground : AppColors.navy)
              : (isDark ? AppColors.darkOnSurfaceVariant : AppColors.mutedText),
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
        );
      }),
      elevation: 0,
      height: 68,
      surfaceTintColor: Colors.transparent,
    );
  }

  static BottomNavigationBarThemeData _bottomNavigationBarTheme(ColorScheme colors, bool isDark) {
    return BottomNavigationBarThemeData(
      backgroundColor: colors.surface,
      selectedItemColor: isDark ? AppColors.pageBackground : AppColors.navy,
      unselectedItemColor: isDark ? AppColors.darkOnSurfaceVariant : AppColors.mutedText,
      selectedLabelStyle: AppTypography.labelSmall.copyWith(fontWeight: FontWeight.w600),
      unselectedLabelStyle: AppTypography.labelSmall,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      landscapeLayout: BottomNavigationBarLandscapeLayout.centered,
    );
  }

  static DialogThemeData _dialogTheme(ColorScheme colors, bool isDark) {
    return DialogThemeData(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: AppBorderRadius.xlargeRadius,
      ),
      titleTextStyle: AppTypography.titleLarge.copyWith(color: colors.onSurface),
      contentTextStyle: AppTypography.bodyMedium.copyWith(color: colors.onSurface),
      alignment: Alignment.center,
    );
  }

  static BottomSheetThemeData _bottomSheetTheme(ColorScheme colors, bool isDark) {
    return BottomSheetThemeData(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      modalBackgroundColor: colors.surface,
      constraints: const BoxConstraints(maxWidth: 600),
    );
  }

  static SnackBarThemeData _snackBarTheme(ColorScheme colors, bool isDark) {
    return SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.text,
      contentTextStyle: AppTypography.bodyMedium.copyWith(color: AppColors.pageBackground),
      actionTextColor: AppColors.brand,
      shape: RoundedRectangleBorder(
        borderRadius: AppBorderRadius.mediumRadius,
      ),
      elevation: 4,
    );
  }

  static DividerThemeData _dividerTheme(ColorScheme colors, bool isDark) {
    return DividerThemeData(
      color: colors.outline,
      thickness: 1,
      space: 1,
      indent: 0,
      endIndent: 0,
    );
  }

  static ChipThemeData _chipTheme(ColorScheme colors, bool isDark) {
    return ChipThemeData(
      backgroundColor: colors.surfaceContainerHighest,
      selectedColor: colors.primaryContainer,
      disabledColor: colors.surfaceContainerHighest.withValues(alpha: 0.38),
      labelStyle: AppTypography.labelMedium.copyWith(color: colors.onSurface),
      secondaryLabelStyle: AppTypography.labelMedium.copyWith(color: colors.onPrimaryContainer),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: AppBorderRadius.roundRadius,
        side: BorderSide(color: colors.outline),
      ),
      selectedShadowColor: Colors.transparent,
      showCheckmark: false,
      pressElevation: 0,
      elevation: 0,
    );
  }

  static TabBarThemeData _tabBarTheme(ColorScheme colors, bool isDark) {
    return TabBarThemeData(
      labelColor: colors.primary,
      unselectedLabelColor: colors.onSurfaceVariant,
      indicatorColor: colors.primary,
      indicatorSize: TabBarIndicatorSize.label,
      labelStyle: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.w700),
      unselectedLabelStyle: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.w500),
      dividerColor: Colors.transparent,
      overlayColor: WidgetStateProperty.all(Colors.transparent),
      splashFactory: NoSplash.splashFactory,
    );
  }

  static ProgressIndicatorThemeData _progressIndicatorTheme(ColorScheme colors) {
    return ProgressIndicatorThemeData(
      color: colors.primary,
      linearTrackColor: colors.primaryContainer,
      circularTrackColor: colors.primaryContainer,
      refreshBackgroundColor: colors.surfaceContainerHighest,
    );
  }

  static CheckboxThemeData _checkboxTheme(ColorScheme colors) {
    return CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return colors.primary;
        return Colors.transparent;
      }),
      checkColor: WidgetStateProperty.all(colors.onPrimary),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.hovered)) return colors.primary.withValues(alpha: 0.08);
        if (states.contains(WidgetState.focused)) return colors.primary.withValues(alpha: 0.12);
        return Colors.transparent;
      }),
      side: BorderSide(color: colors.outline, width: 1.5),
      shape: RoundedRectangleBorder(
        borderRadius: AppBorderRadius.smallRadius,
      ),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  static RadioThemeData _radioTheme(ColorScheme colors) {
    return RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return colors.primary;
        return colors.outline;
      }),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.hovered)) return colors.primary.withValues(alpha: 0.08);
        if (states.contains(WidgetState.focused)) return colors.primary.withValues(alpha: 0.12);
        return Colors.transparent;
      }),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  static SwitchThemeData _switchTheme(ColorScheme colors) {
    return SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return colors.primary;
        return colors.outline;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return colors.primary.withValues(alpha: 0.5);
        return colors.outline.withValues(alpha: 0.5);
      }),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.hovered)) return colors.primary.withValues(alpha: 0.08);
        if (states.contains(WidgetState.focused)) return colors.primary.withValues(alpha: 0.12);
        return Colors.transparent;
      }),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    );
  }

  static SliderThemeData _sliderTheme(ColorScheme colors) {
    return SliderThemeData(
      activeTrackColor: colors.primary,
      inactiveTrackColor: colors.primaryContainer,
      thumbColor: colors.primary,
      overlayColor: colors.primary.withValues(alpha: 0.12),
      valueIndicatorColor: colors.primary,
      valueIndicatorTextStyle: AppTypography.labelSmall.copyWith(color: colors.onPrimary),
      trackHeight: 4,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
    );
  }

  static ListTileThemeData _listTileTheme(ColorScheme colors, bool isDark) {
    return ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: AppBorderRadius.mediumRadius,
      ),
      tileColor: Colors.transparent,
      selectedTileColor: colors.primaryContainer,
      iconColor: colors.onSurfaceVariant,
      textColor: colors.onSurface,
      titleTextStyle: AppTypography.bodyLarge.copyWith(color: colors.onSurface),
      subtitleTextStyle: AppTypography.bodyMedium.copyWith(color: colors.onSurfaceVariant),
      leadingAndTrailingTextStyle: AppTypography.bodyMedium.copyWith(color: colors.onSurfaceVariant),
      dense: false,
      visualDensity: VisualDensity.standard,
      horizontalTitleGap: 16,
      minLeadingWidth: 40,
    );
  }

  static TooltipThemeData _tooltipTheme(ColorScheme colors, bool isDark) {
    return TooltipThemeData(
      decoration: BoxDecoration(
        color: isDark ? AppColors.text : AppColors.navy,
        borderRadius: AppBorderRadius.smallRadius,
      ),
      textStyle: AppTypography.labelSmall.copyWith(color: AppColors.pageBackground),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      verticalOffset: 8,
      preferBelow: true,
      excludeFromSemantics: false,
    );
  }
}