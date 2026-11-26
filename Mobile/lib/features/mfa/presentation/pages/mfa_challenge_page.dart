// MFA challenge page for authenticator, SMS, email, and recovery codes.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/widgets/design_widgets.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../../../../core/validators/validators.dart';
import '../../../authentication/presentation/state/auth_state.dart';
import '../../../authentication/presentation/state/auth_navigation.dart';

class MfaChallengePage extends ConsumerStatefulWidget {
  const MfaChallengePage({
    required this.challengeId,
    required this.availableMethods,
    super.key,
  });

  final String challengeId;
  final List<String> availableMethods;

  @override
  ConsumerState<MfaChallengePage> createState() => _MfaChallengePageState();
}

class _MfaChallengePageState extends ConsumerState<MfaChallengePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Map<String, TextEditingController> _codeControllers = {
    'totp': TextEditingController(),
    'sms': TextEditingController(),
    'email': TextEditingController(),
    'recovery_codes': TextEditingController(),
  };
  final Map<String, GlobalKey<FormState>> _formKeys = {
    'totp': GlobalKey<FormState>(),
    'sms': GlobalKey<FormState>(),
    'email': GlobalKey<FormState>(),
    'recovery_codes': GlobalKey<FormState>(),
  };
  final Set<String> _requestedMethods = {};
  int _lastTabIndex = 0;
  bool _isVerifying = false;

  List<String> get _methods => const [
    'totp',
    'sms',
    'email',
    'recovery_codes',
  ].where(widget.availableMethods.contains).toList();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _getTabCount(), vsync: this)
      ..addListener(_onTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final method = _selectedMethod;
      if (method == 'sms' || method == 'email') _requestCode(method!);
    });
  }

  int _getTabCount() => _methods.length.clamp(1, 4);

  String? get _selectedMethod => _methods.isEmpty
      ? null
      : _methods[_tabController.index.clamp(0, _methods.length - 1)];

  void _onTabChanged() {
    if (_tabController.index == _lastTabIndex || _methods.isEmpty) return;
    _lastTabIndex = _tabController.index;
    final method = _selectedMethod;
    if (method == 'sms' || method == 'email') _requestCode(method!);
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (final controller in _codeControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _verifyCode(String methodType) async {
    if (_isVerifying || !_formKeys[methodType]!.currentState!.validate()) {
      return;
    }
    setState(() => _isVerifying = true);
    final notifier = ref.read(authNotifierProvider.notifier);
    try {
      await notifier.verifyMfaLoginCode(
        challengeId: widget.challengeId,
        methodType: methodType,
        code: _codeControllers[methodType]!.text.trim(),
      );
      if (!mounted) return;
      navigateForAuthState(context, ref.read(authNotifierProvider));
    } on AppException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _requestCode(String methodType) async {
    if (_requestedMethods.contains(methodType)) return;
    _requestedMethods.add(methodType);
    try {
      await ref
          .read(authNotifierProvider.notifier)
          .requestMfaLoginCode(
            challengeId: widget.challengeId,
            methodType: methodType,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            methodType == 'sms'
                ? 'A sign-in code was sent by text.'
                : 'A sign-in code was sent by email.',
          ),
        ),
      );
    } on AppException catch (error) {
      _requestedMethods.remove(methodType);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authNotifierProvider);
    final tabViews = _buildTabViews(theme);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back button
              IconButton(
                onPressed: () => context.go('/sign-in'),
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: 'Back to sign in',
              ),
              const SizedBox(height: 8),

              // Logo
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

              // Title
              Text(
                'Verify your identity',
                style: AppTypography.titleLarge.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose an available method and enter its verification code.',
                style: AppTypography.bodyLarge.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),

              // Method tabs
              if (_methods.length > 1) ...[
                TabBar(
                  controller: _tabController,
                  tabs: _buildTabs(),
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  dividerColor: Colors.transparent,
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelStyle: AppTypography.labelMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  unselectedLabelStyle: AppTypography.labelMedium.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Tab content
              Expanded(
                child: tabViews.isEmpty
                    ? _buildUnsupportedMethodView(theme)
                    : _methods.length > 1
                    ? TabBarView(controller: _tabController, children: tabViews)
                    : tabViews.first,
              ),

              // Error message
              if (authState.errorMessage case final error?) ...[
                AppNotice(message: error, type: NoticeType.error),
                const SizedBox(height: 16),
              ],

              // Help text
              Text(
                'Having trouble? ',
                style: AppTypography.bodyMedium.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUnsupportedMethodView(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'This sign-in challenge has no supported verification method.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyLarge.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => context.go('/sign-in'),
            child: const Text('Return to sign in'),
          ),
        ],
      ),
    );
  }

  List<Tab> _buildTabs() {
    return _methods
        .map(
          (method) => Tab(
            text: switch (method) {
              'totp' => 'Authenticator',
              'sms' => 'Text message',
              'email' => 'Email',
              _ => 'Recovery code',
            },
          ),
        )
        .toList();
  }

  List<Widget> _buildTabViews(ThemeData theme) {
    return _methods.map((method) => _buildCodeView(theme, method)).toList();
  }

  Widget _buildCodeView(ThemeData theme, String methodType) {
    final isRecovery = methodType == 'recovery_codes';
    final title = switch (methodType) {
      'totp' => 'Authenticator app',
      'sms' => 'Text message code',
      'email' => 'Email code',
      _ => 'Recovery code',
    };
    final instructions = switch (methodType) {
      'totp' =>
        'Open your authenticator app and enter the current 6-digit code.',
      'sms' => 'We will send a sign-in code to your enrolled phone number.',
      'email' => 'We will send a sign-in code to your verified account email.',
      _ => 'Enter one unused backup code. Each recovery code works once.',
    };
    return SingleChildScrollView(
      child: Form(
        key: _formKeys[methodType],
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
            const SizedBox(height: 8),
            Text(
              instructions,
              style: AppTypography.bodyMedium.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            AppTextField(
              controller: _codeControllers[methodType]!,
              label: isRecovery ? 'Recovery code' : 'Verification code',
              keyboardType: isRecovery
                  ? TextInputType.text
                  : TextInputType.number,
              textInputAction: TextInputAction.done,
              validator: (value) {
                final code = value?.trim() ?? '';
                if (isRecovery) return code.recoveryCode;
                final lengthIsValid = methodType == 'totp'
                    ? code.length == 6
                    : code.length >= 4 && code.length <= 8;
                return lengthIsValid && RegExp(r'^\d+$').hasMatch(code)
                    ? null
                    : 'Enter the numeric code you received';
              },
              autofillHints: const [AutofillHints.oneTimeCode],
              autocapitalization: isRecovery
                  ? TextCapitalization.characters
                  : TextCapitalization.none,
              onSubmitted: (_) => _verifyCode(methodType),
            ),
            const SizedBox(height: 24),
            if (methodType == 'sms' || methodType == 'email')
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _isVerifying
                      ? null
                      : () {
                          _requestedMethods.remove(methodType);
                          _requestCode(methodType);
                        },
                  child: const Text('Resend code'),
                ),
              ),
            PrimaryButton(
              label: 'Verify',
              isLoading: _isVerifying,
              onPressed: _isVerifying ? null : () => _verifyCode(methodType),
            ),
          ],
        ),
      ),
    );
  }
}
