// Dashboard page - main authenticated screen.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../l10n/generated/app_localizations.dart';

import '../../../../app/theme/design_system.dart';
import '../../../profile/presentation/widgets/profile_photo_avatar.dart';
import '../../../authentication/presentation/state/auth_state.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final user = authState.user;
    final l10n = AppLocalizations.of(context)!;

    final tabs = [
      _HomeTab(
        user: user,
        onNotificationTap: () => context.push('/notifications'),
      ),
      _ExploreTab(),
      _SiteVisitsTab(),
      _ProfileTab(user: user),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: l10n.home,
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore_rounded),
            label: l10n.explore,
          ),
          NavigationDestination(
            icon: Icon(Icons.event_outlined),
            selectedIcon: Icon(Icons.event_rounded),
            label: l10n.visits,
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person_rounded),
            label: l10n.profile,
          ),
        ],
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({this.user, required this.onNotificationTap});

  final AuthUser? user;
  final VoidCallback onNotificationTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          _HomeHeader(onNotifications: onNotificationTap),
          const SizedBox(height: 20),
          _HeroCard(),
          const SizedBox(height: 24),
          const _SectionTitle(title: 'What do you need?'),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _ServiceTile(
                label: 'Properties',
                icon: Icons.home_outlined,
                onTap: () => context.push('/house-seeker'),
              ),
              _ServiceTile(
                label: 'Laundries',
                icon: Icons.local_laundry_service_outlined,
                onTap: () => context.push('/laundry/orders'),
              ),
              _ServiceTile(
                label: 'Movers',
                icon: Icons.local_shipping_outlined,
                onTap: () => context.push('/moving/jobs'),
              ),
              _ServiceTile(
                label: 'Garbage',
                icon: Icons.delete_outline_rounded,
                onTap: () => context.push('/garbage/jobs'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SectionTitle(
            title: 'Find available homes',
            action: 'Search',
            onAction: () => context.push('/house-seeker'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => context.push('/house-seeker'),
            icon: const Icon(Icons.search_outlined),
            label: const Text('Discover, search & save rental homes'),
          ),
          const SizedBox(height: 20),
          _SectionTitle(title: 'Site visit safety'),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => context.push('/location-sharing'),
            icon: const Icon(Icons.location_searching),
            label: const Text('Manage temporary location sharing'),
          ),
          const SizedBox(height: 24),
          const _SectionTitle(title: 'For landlords'),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => context.push('/landlord'),
            icon: const Icon(Icons.business_center_outlined),
            label: const Text('Manage your properties'),
          ),
          const SizedBox(height: 24),
          const _SectionTitle(title: 'For providers'),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => context.push('/provider/onboarding'),
            icon: const Icon(Icons.assignment_turned_in_outlined),
            label: const Text('Provider onboarding & setup'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => context.push('/provider/dashboard'),
            icon: const Icon(Icons.dashboard_outlined),
            label: const Text('Open provider dashboard'),
          ),
        ],
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.onNotifications});

  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Container(
          width: 148,
          height: 52,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Image.asset(
            'assets/images/brand/wordmark.png',
            fit: BoxFit.contain,
            semanticLabel: 'Get Keja logo',
            errorBuilder: (_, _, _) => Center(
              child: Text(
                'GetKeja',
                style: AppTypography.titleLarge.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.place_outlined,
                    size: 13,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 2),
                  Flexible(
                    child: Text(
                      'Nairobi, Kenya',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onNotifications,
          tooltip: 'Notifications',
          style: IconButton.styleFrom(
            backgroundColor: theme.colorScheme.surface,
            foregroundColor: theme.colorScheme.primary,
            side: BorderSide(color: theme.colorScheme.outline),
          ),
          icon: const Icon(Icons.notifications_none_rounded),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Find your next home',
            style: AppTypography.headlineSmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Verified listings, trusted landlords and honest prices across Nairobi.',
            style: AppTypography.bodySmall.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 18),
          SearchBar(
            hintText: 'Search suburb, estate or price',
            onSubmitted: (query) => context.push(
              '/properties/nearby?q=${Uri.encodeQueryComponent(query)}',
            ),
            leading: const Icon(Icons.search_rounded, color: AppColors.brand),
            constraints: const BoxConstraints(minHeight: 52),
            elevation: const WidgetStatePropertyAll<double?>(0),
            backgroundColor: WidgetStatePropertyAll<Color?>(
              theme.colorScheme.surface,
            ),
            side: const WidgetStatePropertyAll<BorderSide?>(BorderSide.none),
            shape: const WidgetStatePropertyAll<OutlinedBorder?>(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
            ),
            padding: const WidgetStatePropertyAll<EdgeInsetsGeometry?>(
              EdgeInsets.symmetric(horizontal: 16),
            ),
            hintStyle: WidgetStatePropertyAll<TextStyle?>(
              TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        if (action != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.navy,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(action!),
          ),
      ],
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.outline),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: theme.colorScheme.onPrimaryContainer,
                  size: 24,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExploreTab extends StatelessWidget {
  const _ExploreTab();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.brand,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    Icons.explore_outlined,
                    color: AppColors.navy,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Explore',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.explore_outlined,
                        size: 32,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Browse neighbourhoods, compare rents and save the homes you like.',
                      textAlign: TextAlign.center,
                      style: textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => context.push('/house-seeker/search'),
                      icon: const Icon(Icons.search),
                      label: const Text('Browse homes'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SiteVisitsTab extends StatelessWidget {
  const _SiteVisitsTab();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.brand,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    Icons.event_available_outlined,
                    color: AppColors.navy,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Site visits',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.event_available_outlined,
                        size: 32,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Book viewings with landlords and keep track of every visit.',
                      textAlign: TextAlign.center,
                      style: textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => context.push('/house-seeker/visits'),
                      icon: const Icon(Icons.event_available),
                      label: const Text('View site visits'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileTab extends ConsumerWidget {
  const _ProfileTab({this.user});

  final AuthUser? user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final name = [
      user?.firstName,
      user?.lastName,
    ].whereType<String>().where((part) => part.isNotEmpty).join(' ');
    final email = user?.email;
    final initialsSource = name.isNotEmpty ? name : email;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 24),
          Center(
            child: ProfilePhotoAvatar(
              radius: 34,
              initials: initialsSource?.isNotEmpty == true
                  ? initialsSource![0].toUpperCase()
                  : 'G',
            ),
          ),
          const SizedBox(height: 16),
          Text(
            name.isNotEmpty ? name : 'GetKeja member',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            email ?? '',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 28),
          OutlinedButton.icon(
            onPressed: () => context.push('/profile'),
            icon: const Icon(Icons.person_outline_rounded),
            label: const Text('View profile'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => context.push('/account'),
            icon: const Icon(Icons.settings_outlined),
            label: const Text('Settings'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              try {
                await ref
                    .read(authNotifierProvider.notifier)
                    .handleAction(const AuthAction.logout());
              } on Exception {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Signed out on this device, but the server session could not be revoked.',
                    ),
                  ),
                );
              } finally {
                if (context.mounted) context.go('/welcome');
              }
            },
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Sign out'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              foregroundColor: Theme.of(context).colorScheme.error,
              side: BorderSide(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}
