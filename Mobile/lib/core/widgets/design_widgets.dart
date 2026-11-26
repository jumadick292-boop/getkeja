// Reusable UI widgets for the design system.

import 'package:flutter/material.dart';

import '../../app/theme/design_system.dart';
import '../../l10n/generated/app_localizations.dart';

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.onPressed,
    required this.label,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = true,
    this.style,
    super.key,
  });

  final VoidCallback? onPressed;
  final String label;
  final Widget? icon;
  final bool isLoading;
  final bool isFullWidth;
  final ButtonStyle? style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buttonStyle =
        theme.filledButtonTheme.style?.copyWith(
          minimumSize: const WidgetStatePropertyAll<Size>(Size(64, 52)),
        ) ??
        FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          padding: AppSpacing.buttonPadding,
          shape: RoundedRectangleBorder(
            borderRadius: AppBorderRadius.mediumRadius,
          ),
          textStyle: AppTypography.labelLarge.copyWith(
            fontWeight: FontWeight.w700,
          ),
        );

    final child = isLoading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: theme.colorScheme.onPrimary,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[icon!, const SizedBox(width: 8)],
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  softWrap: true,
                ),
              ),
            ],
          );

    final button = FilledButton(
      onPressed: isLoading ? null : onPressed,
      style: style?.merge(buttonStyle) ?? buttonStyle,
      child: Material(
        color: Colors.transparent,
        borderRadius: AppBorderRadius.largeRadius,
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
    return isFullWidth
        ? SizedBox(width: double.infinity, child: button)
        : button;
  }
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    required this.onPressed,
    required this.label,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = true,
    this.style,
    super.key,
  });

  final VoidCallback? onPressed;
  final String label;
  final Widget? icon;
  final bool isLoading;
  final bool isFullWidth;
  final ButtonStyle? style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buttonStyle =
        theme.outlinedButtonTheme.style?.copyWith(
          minimumSize: const WidgetStatePropertyAll<Size>(Size(64, 52)),
        ) ??
        OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          padding: AppSpacing.buttonPadding,
          shape: RoundedRectangleBorder(
            borderRadius: AppBorderRadius.mediumRadius,
          ),
          textStyle: AppTypography.labelLarge.copyWith(
            fontWeight: FontWeight.w700,
          ),
        );

    final child = isLoading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: theme.colorScheme.primary,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[icon!, const SizedBox(width: 8)],
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  softWrap: true,
                ),
              ),
            ],
          );

    final button = OutlinedButton(
      onPressed: isLoading ? null : onPressed,
      style: style?.merge(buttonStyle) ?? buttonStyle,
      child: Material(
        color: Colors.transparent,
        borderRadius: AppBorderRadius.largeRadius,
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
    return isFullWidth
        ? SizedBox(width: double.infinity, child: button)
        : button;
  }
}

class TertiaryButton extends StatelessWidget {
  const TertiaryButton({
    required this.onPressed,
    required this.label,
    this.icon,
    this.isLoading = false,
    this.style,
    super.key,
  });

  final VoidCallback? onPressed;
  final String label;
  final Widget? icon;
  final bool isLoading;
  final ButtonStyle? style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buttonStyle =
        theme.textButtonTheme.style ??
        TextButton.styleFrom(
          minimumSize: const Size(48, 44),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: AppBorderRadius.mediumRadius,
          ),
          textStyle: AppTypography.labelLarge.copyWith(
            fontWeight: FontWeight.w700,
          ),
        );

    final child = isLoading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: theme.colorScheme.primary,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[icon!, const SizedBox(width: 8)],
              Text(label),
            ],
          );

    return TextButton(
      onPressed: isLoading ? null : onPressed,
      style: style?.merge(buttonStyle) ?? buttonStyle,
      child: child,
    );
  }
}

class DestructiveButton extends StatelessWidget {
  const DestructiveButton({
    required this.onPressed,
    required this.label,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = true,
    super.key,
  });

  final VoidCallback? onPressed;
  final String label;
  final Widget? icon;
  final bool isLoading;
  final bool isFullWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buttonStyle = FilledButton.styleFrom(
      minimumSize: isFullWidth ? Size.infinite : const Size(64, 52),
      padding: AppSpacing.buttonPadding,
      shape: RoundedRectangleBorder(borderRadius: AppBorderRadius.mediumRadius),
      textStyle: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.w700),
      backgroundColor: theme.colorScheme.error,
      foregroundColor: theme.colorScheme.onError,
    );

    final child = isLoading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: theme.colorScheme.onError,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[icon!, const SizedBox(width: 8)],
              Text(label),
            ],
          );

    return FilledButton(
      onPressed: isLoading ? null : onPressed,
      style: buttonStyle,
      child: child,
    );
  }
}

class AppTextField extends StatefulWidget {
  const AppTextField({
    required this.controller,
    required this.label,
    this.hintText,
    this.keyboardType,
    this.obscureText = false,
    this.textInputAction,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.prefixIcon,
    this.suffixIcon,
    this.enabled = true,
    this.readOnly = false,
    this.maxLines = 1,
    this.maxLength,
    this.autofillHints,
    this.autocorrect = false,
    this.autocapitalization = TextCapitalization.none,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final String? hintText;
  final TextInputType? keyboardType;
  final bool obscureText;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool enabled;
  final bool readOnly;
  final int maxLines;
  final int? maxLength;
  final Iterable<String>? autofillHints;
  final bool autocorrect;
  final TextCapitalization autocapitalization;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _obscureText;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TextFormField(
      controller: widget.controller,
      keyboardType: widget.keyboardType,
      obscureText: _obscureText,
      textInputAction: widget.textInputAction,
      validator: widget.validator,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onSubmitted,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      maxLines: widget.maxLines,
      maxLength: widget.maxLength,
      autofillHints: widget.autofillHints,
      autocorrect: widget.autocorrect,
      textCapitalization: widget.autocapitalization,
      style: AppTypography.bodyLarge.copyWith(
        color: theme.colorScheme.onSurface,
      ),
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hintText,
        prefixIcon: widget.prefixIcon,
        suffixIcon: widget.obscureText
            ? IconButton(
                icon: Icon(
                  _obscureText
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  size: 20,
                ),
                onPressed: () => setState(() => _obscureText = !_obscureText),
                tooltip: _obscureText ? 'Show password' : 'Hide password',
              )
            : widget.suffixIcon,
        counterText: widget.maxLength != null ? null : '',
      ),
    );
  }
}

class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.onTap,
    this.padding = AppSpacing.cardPadding,
    this.margin,
    this.elevation = 0,
    this.border,
    this.color,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double elevation;
  final Border? border;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? theme.colorScheme.surface,
        borderRadius: AppBorderRadius.mediumRadius,
        border:
            border ??
            Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.65),
              width: 0.75,
            ),
        boxShadow: elevation > 0 ? AppElevation.level1 : null,
      ),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppBorderRadius.largeRadius,
          child: card,
        ),
      );
    }

    return Padding(padding: margin ?? EdgeInsets.zero, child: card);
  }
}

class AppCardSection extends StatelessWidget {
  const AppCardSection({
    required this.title,
    this.subtitle,
    this.action,
    this.onAction,
    this.children = const [],
    this.padding = AppSpacing.cardPadding,
    super.key,
  });

  final String title;
  final String? subtitle;
  final String? action;
  final VoidCallback? onAction;
  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.titleMedium.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: AppTypography.bodySmall.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (action != null && onAction != null)
                TextButton(onPressed: onAction, child: Text(action!)),
            ],
          ),
          if (children.isNotEmpty) ...[const SizedBox(height: 16), ...children],
        ],
      ),
    );
  }
}

class AppNotice extends StatelessWidget {
  const AppNotice({
    required this.message,
    this.type = NoticeType.info,
    this.onDismiss,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String message;
  final NoticeType type;
  final VoidCallback? onDismiss;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (backgroundColor, foregroundColor, icon) = switch (type) {
      NoticeType.error => (
        theme.colorScheme.errorContainer,
        theme.colorScheme.onErrorContainer,
        Icons.error_outline_rounded,
      ),
      NoticeType.warning => (
        theme.colorScheme.tertiaryContainer,
        theme.colorScheme.onTertiaryContainer,
        Icons.warning_amber_rounded,
      ),
      NoticeType.success => (
        theme.colorScheme.secondaryContainer,
        theme.colorScheme.onSecondaryContainer,
        Icons.check_circle_outline_rounded,
      ),
      NoticeType.info => (
        theme.colorScheme.primaryContainer,
        theme.colorScheme.onPrimaryContainer,
        Icons.info_outline_rounded,
      ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: AppBorderRadius.mediumRadius,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: foregroundColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: AppTypography.bodyMedium.copyWith(color: foregroundColor),
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: 12),
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
          if (onDismiss != null) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.close_rounded, color: foregroundColor, size: 20),
              onPressed: onDismiss,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ],
      ),
    );
  }
}

class AppListSkeleton extends StatelessWidget {
  const AppListSkeleton({this.rows = 5, super.key});

  final int rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fill = theme.colorScheme.outlineVariant.withValues(alpha: 0.34);

    Widget line(double width, double height) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: AppBorderRadius.roundRadius,
      ),
    );

    return Semantics(
      label: 'Loading content',
      child: ExcludeSemantics(
        child: ListView(
          padding: AppSpacing.compactScreenPadding,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 16),
              child: line(136, 18),
            ),
            for (var index = 0; index < rows; index++)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: AppSpacing.compactCardPadding,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                  borderRadius: AppBorderRadius.mediumRadius,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: fill,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          line(index.isEven ? 150 : 116, 13),
                          const SizedBox(height: 8),
                          line(index.isEven ? 210 : 174, 10),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

enum NoticeType { info, success, warning, error }

class AppLoadingIndicator extends StatelessWidget {
  const AppLoadingIndicator({
    this.size = 24,
    this.strokeWidth = 2.5,
    this.color,
    super.key,
  });

  final double size;
  final double strokeWidth;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        color: color ?? theme.colorScheme.primary,
      ),
    );
  }
}

class AppOverlayLoader extends StatelessWidget {
  const AppOverlayLoader({
    required this.isLoading,
    required this.child,
    this.message,
    super.key,
  });

  final bool isLoading;
  final Widget child;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: theme.colorScheme.surface.withValues(alpha: 0.8),
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: AppBorderRadius.largeRadius,
                  boxShadow: AppElevation.level2,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppLoadingIndicator(size: 32, strokeWidth: 3),
                    if (message != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        message!,
                        style: AppTypography.bodyMedium.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class AppDivider extends StatelessWidget {
  const AppDivider({
    this.height = 1,
    this.thickness = 1,
    this.indent = 0,
    this.endIndent = 0,
    this.color,
    super.key,
  });

  final double height;
  final double thickness;
  final double indent;
  final double endIndent;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Divider(
      height: height,
      thickness: thickness,
      indent: indent,
      endIndent: endIndent,
      color: color ?? theme.colorScheme.outline,
    );
  }
}

class AppSpacer extends StatelessWidget {
  const AppSpacer(this.size, {super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: size);
  }
}

class AppPageFrame extends StatelessWidget {
  const AppPageFrame({
    required this.title,
    this.description,
    this.leading,
    this.actions,
    required this.children,
    this.scrollable = true,
    this.padding = AppSpacing.screenPadding,
    super.key,
  });

  final String title;
  final String? description;
  final Widget? leading;
  final List<Widget>? actions;
  final List<Widget> children;
  final bool scrollable;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (leading != null || actions != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                if (leading != null) leading!,
                const Spacer(),
                if (actions != null) ...actions!,
              ],
            ),
          ),
        const SizedBox(height: 8),
        Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: AppBorderRadius.mediumRadius,
          ),
          child: Icon(
            Icons.home_work_rounded,
            color: theme.colorScheme.onPrimary,
            size: 28,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          title,
          style: AppTypography.headlineMedium.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: theme.colorScheme.onSurface,
          ),
        ),
        if (description != null) ...[
          const SizedBox(height: 8),
          Text(
            description!,
            style: AppTypography.bodyLarge.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 28),
        ...children,
      ],
    );

    if (scrollable) {
      return Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(padding: padding, child: content),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(padding: padding, child: content),
      ),
    );
  }
}

class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    required this.title,
    this.subtitle,
    this.action,
    this.onAction,
    super.key,
  });

  final String title;
  final String? subtitle;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.titleMedium.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: AppTypography.bodySmall.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (action != null && onAction != null)
              TextButton(onPressed: onAction, child: Text(action!)),
          ],
        ),
      ],
    );
  }
}

class AppTile extends StatelessWidget {
  const AppTile({
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.isDense = false,
    this.contentPadding,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool isDense;
  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding:
            contentPadding ??
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: leading,
        title: Text(
          title,
          style: AppTypography.bodyLarge.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle!,
                style: AppTypography.bodyMedium.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            : null,
        trailing: trailing,
        onTap: onTap,
        dense: isDense,
        visualDensity: isDense ? VisualDensity.compact : VisualDensity.standard,
        shape: RoundedRectangleBorder(
          borderRadius: AppBorderRadius.mediumRadius,
        ),
        tileColor: onTap != null ? theme.colorScheme.surface : null,
        selectedTileColor: theme.colorScheme.primaryContainer,
      ),
    );
  }
}

class AppListSection extends StatelessWidget {
  const AppListSection({
    required this.children,
    this.header,
    this.footer,
    this.divider = true,
    super.key,
  });

  final List<Widget> children;
  final Widget? header;
  final Widget? footer;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (header != null) ...[header!, const SizedBox(height: 12)],
        ...children.asMap().entries.map((entry) {
          final index = entry.key;
          final child = entry.value;
          return Column(
            children: [
              child,
              if (divider && index < children.length - 1)
                Divider(
                  height: 1,
                  thickness: 1,
                  color: theme.colorScheme.outline,
                  indent: 16,
                  endIndent: 16,
                ),
            ],
          );
        }).toList(),
        if (footer != null) ...[const SizedBox(height: 12), footer!],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// House Seeker design system components
// ---------------------------------------------------------------------------

/// A reusable property search field for House Seeker discovery screens.
class AppSearchField extends StatelessWidget {
  const AppSearchField({
    required this.controller,
    required this.onSubmit,
    this.hintText,
    this.prefixIcon = Icons.search,
    this.suffixIcon,
    super.key,
  });

  final TextEditingController controller;
  final VoidCallback onSubmit;
  final String? hintText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => onSubmit(),
      style: AppTypography.bodyLarge.copyWith(
        color: theme.colorScheme.onSurface,
      ),
      decoration: InputDecoration(
        hintText: hintText ?? l10n.searchSuburbEstatePrice,
        hintStyle: AppTypography.bodyMedium.copyWith(
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
        ),
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 20) : null,
        suffixIcon: suffixIcon != null
            ? IconButton(icon: suffixIcon!, onPressed: onSubmit)
            : null,
        filled: true,
        fillColor: theme.colorScheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: AppBorderRadius.largeRadius,
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

/// A reusable category selector chip for property types.
class AppCategoryChip extends StatelessWidget {
  const AppCategoryChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FilterChip(
      avatar: Icon(
        icon,
        size: 16,
        color: isSelected ? theme.colorScheme.onPrimary : AppColors.navy,
      ),
      label: Text(
        label,
        style: AppTypography.labelMedium.copyWith(
          color: isSelected
              ? theme.colorScheme.onPrimary
              : theme.colorScheme.onSurface,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      selected: isSelected,
      onSelected: (_) => onTap(),
      backgroundColor: theme.colorScheme.surface,
      selectedColor: theme.colorScheme.primary,
      checkmarkColor: theme.colorScheme.onPrimary,
      side: BorderSide(
        color: isSelected
            ? theme.colorScheme.primary
            : theme.colorScheme.outline,
        width: 1,
      ),
      shape: RoundedRectangleBorder(borderRadius: AppBorderRadius.roundRadius),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );
  }
}

/// A hero banner showing a personalized greeting, saved location, and notifications.
class AppHeroBanner extends StatelessWidget {
  const AppHeroBanner({
    required this.greeting,
    required this.subtitle,
    required this.locationLabel,
    required this.onLocationChange,
    required this.onNotificationsTap,
    this.hasLocation = true,
    super.key,
  });

  final String greeting;
  final String subtitle;
  final String locationLabel;
  final VoidCallback onLocationChange;
  final VoidCallback onNotificationsTap;
  final bool hasLocation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: AppBorderRadius.xlargeRadius,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        greeting,
                        style: AppTypography.headlineSmall.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    if (hasLocation)
                      _LocationPill(
                        label: locationLabel,
                        onTap: onLocationChange,
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle,
                  style: AppTypography.bodyMedium.copyWith(
                    color: theme.colorScheme.onPrimaryContainer.withValues(
                      alpha: 0.85,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          _NotificationsButton(onTap: onNotificationsTap),
        ],
      ),
    );
  }
}

/// A location pill showing the saved location with a change action.
class _LocationPill extends StatelessWidget {
  const _LocationPill({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: AppBorderRadius.roundRadius,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.15),
          borderRadius: AppBorderRadius.roundRadius,
          border: Border.all(
            color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.location_on_outlined,
              size: 14,
              color: Colors.white,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTypography.labelSmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// A notifications entry point button.
class _NotificationsButton extends StatelessWidget {
  const _NotificationsButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.15),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.all(AppSpacing.sm),
          child: Icon(
            Icons.notifications_outlined,
            size: 20,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// A location setup prompt shown when no saved location exists.
class AppLocationPrompt extends StatelessWidget {
  const AppLocationPrompt({required this.onSetLocation, super.key});

  final VoidCallback onSetLocation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppBorderRadius.largeRadius,
        border: Border.all(color: theme.colorScheme.outline, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.location_off_outlined,
                size: 20,
                color: AppColors.mutedText,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      l10n.locationNotSet,
                      style: AppTypography.titleMedium.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      l10n.noSavedLocationDescription,
                      style: AppTypography.bodyMedium.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              onPressed: onSetLocation,
              label: l10n.setLocation,
              icon: const Icon(Icons.add_location, size: 20),
              isFullWidth: true,
            ),
          ),
        ],
      ),
    );
  }
}

/// A reusable property listing badge (verified, featured, etc.).
class AppListingBadge extends StatelessWidget {
  const AppListingBadge({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: AppBorderRadius.roundRadius,
      ),
      child: Text(
        label,
        style: AppTypography.labelSmall.copyWith(
          color: theme.colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
