import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../../../../core/storage/secure_storage.dart';

class ServicesOnboardingPage extends ConsumerStatefulWidget {
  const ServicesOnboardingPage({super.key});

  @override
  ConsumerState<ServicesOnboardingPage> createState() =>
      _ServicesOnboardingPageState();
}

class _ServicesOnboardingPageState
    extends ConsumerState<ServicesOnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isFinishing = false;

  static const _slides = [
    _ServiceSlide(
      title: 'Find a place to call home',
      description:
          'Explore homes and rentals, and make your next move with more confidence.',
      image: 'assets/images/HOMELIST.jpeg',
      imageDescription: 'Home keys being handed over',
    ),
    _ServiceSlide(
      title: 'Laundry, made easier',
      description:
          'Find convenient laundry services to help take care of your everyday essentials.',
      image: 'assets/images/LAUNDARY.jpeg',
      imageDescription: 'Laundry service illustration',
    ),
    _ServiceSlide(
      title: 'Make moving day simpler',
      description:
          'Connect your move with local routes and services for a smoother transition.',
      image: 'assets/images/ROUTE.jpeg',
      imageDescription: 'Route leading to a location pin',
    ),
    _ServiceSlide(
      title: 'Keep your neighbourhood clean',
      description:
          'Discover waste collection services for a cleaner home and community.',
      image: 'assets/images/GARBAGE.jpeg',
      imageDescription: 'Waste collection service',
    ),
    _ServiceSlide(
      title: 'Support for rental management',
      description:
          'Tools and services to help property owners manage their rentals.',
      image: 'assets/images/rms.jpeg',
      imageDescription: 'Rental management and home handover',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLastPage = _currentPage == _slides.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Image.asset(
                    'assets/images/brand/wordmark.png',
                    height: 34,
                    fit: BoxFit.contain,
                    semanticLabel: 'GetKeja',
                  ),
                  TextButton(
                    onPressed: _isFinishing ? null : _finishOnboarding,
                    child: const Text('Skip'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _slides.length,
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                  },
                  itemBuilder: (context, index) => _OnboardingSlideView(
                    slide: _slides[index],
                    textColor: theme.colorScheme.onSurface,
                    mutedTextColor: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _slides.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: index == _currentPage ? 24 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: index == _currentPage
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _isFinishing
                      ? null
                      : isLastPage
                      ? _finishOnboarding
                      : _goToNextPage,
                  child: _isFinishing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(isLastPage ? 'Get started' : 'Next'),
                ),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  void _goToNextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  Future<void> _finishOnboarding() async {
    setState(() => _isFinishing = true);
    try {
      await ref
          .read(secureStorageServiceProvider)
          .write(AppConstants.onboardingCompletedKey, 'true');
      if (mounted) context.go('/welcome');
    } on StorageException catch (error) {
      if (!mounted) return;
      setState(() => _isFinishing = false);
      debugPrint('Unable to save onboarding preference: $error');
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Could not save your progress. Please try again.'),
          ),
        );
    }
  }
}

class _ServiceSlide {
  const _ServiceSlide({
    required this.title,
    required this.description,
    required this.image,
    required this.imageDescription,
  });

  final String title;
  final String description;
  final String image;
  final String imageDescription;
}

class _OnboardingSlideView extends StatelessWidget {
  const _OnboardingSlideView({
    required this.slide,
    required this.textColor,
    required this.mutedTextColor,
  });

  final _ServiceSlide slide;
  final Color textColor;
  final Color mutedTextColor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final imageHeight = (constraints.maxHeight * 0.53)
            .clamp(170.0, 300.0)
            .toDouble();
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: imageHeight,
                  width: double.infinity,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.brandTint,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Image.asset(
                        slide.image,
                        fit: BoxFit.contain,
                        semanticLabel: slide.imageDescription,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  slide.title,
                  style: AppTypography.headlineSmall.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  slide.description,
                  style: AppTypography.bodyLarge.copyWith(
                    color: mutedTextColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
