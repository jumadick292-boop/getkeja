import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_theme.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  static const List<Widget> _tabs = [
    _HomeTab(),
    _ComingSoonTab(
      icon: Icons.explore_outlined,
      title: 'Explore',
      message: 'Browse neighbourhoods, compare rents and save the homes you like.',
    ),
    _ComingSoonTab(
      icon: Icons.event_available_outlined,
      title: 'Site visits',
      message: 'Book viewings with landlords and keep track of every visit.',
    ),
    _ComingSoonTab(
      icon: Icons.person_outline,
      title: 'Profile',
      message: 'Manage your account, saved homes and preferences.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore_rounded),
            label: 'Explore',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_outlined),
            selectedIcon: Icon(Icons.event_rounded),
            label: 'Visits',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab();

  void _notify(BuildContext context, String feature) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$feature is coming soon')));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          _HomeHeader(onNotifications: () => _notify(context, 'Notifications')),
          const SizedBox(height: 20),
          _HeroCard(onSearch: (query) => _notify(context, 'Search')),
          const SizedBox(height: 24),
          const _SectionTitle(title: 'What do you need?'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ServiceTile(
                  icon: Icons.apartment_rounded,
                  label: 'Properties',
                  onTap: () => _notify(context, 'Properties'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ServiceTile(
                  icon: Icons.local_laundry_service_rounded,
                  label: 'Laundries',
                  onTap: () => _notify(context, 'Laundries'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ServiceTile(
                  icon: Icons.local_shipping_rounded,
                  label: 'Movers',
                  onTap: () => _notify(context, 'Movers'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ServiceTile(
                  icon: Icons.delete_outline_rounded,
                  label: 'Garbage',
                  onTap: () => _notify(context, 'Garbage'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SectionTitle(
            title: 'Featured homes',
            action: 'See all',
            onAction: () => _notify(context, 'The full listing'),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 214,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 2),
              children: [
                _PropertyCard(
                  title: '2 bedroom apartment',
                  location: 'Kilimani',
                  price: 'KES 45,000',
                  icon: Icons.apartment_rounded,
                  tint: const Color(0xFFE4F1EA),
                  accent: AppTheme.brand,
                  onTap: () => _notify(context, 'This listing'),
                ),
                const SizedBox(width: 12),
                _PropertyCard(
                  title: 'Cosy bedsitter',
                  location: 'Kasarani',
                  price: 'KES 12,500',
                  icon: Icons.cottage_rounded,
                  tint: const Color(0xFFFDF3E3),
                  accent: const Color(0xFFB7791F),
                  onTap: () => _notify(context, 'This listing'),
                ),
                const SizedBox(width: 12),
                _PropertyCard(
                  title: '3 bedroom townhouse',
                  location: 'Ruiru',
                  price: 'KES 65,000',
                  icon: Icons.home_rounded,
                  tint: const Color(0xFFE8EEFB),
                  accent: const Color(0xFF2B5CA8),
                  onTap: () => _notify(context, 'This listing'),
                ),
              ],
            ),
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
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppTheme.brand,
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(
            Icons.home_work_rounded,
            color: Colors.white,
            size: 22,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'GetKeja',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 1),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.place_outlined,
                    size: 13,
                    color: AppTheme.mutedText,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    'Nairobi, Kenya',
                    style: textTheme.bodySmall?.copyWith(
                      color: AppTheme.mutedText,
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
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF111827),
            side: const BorderSide(color: AppTheme.border),
          ),
          icon: const Icon(Icons.notifications_none_rounded),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.onSearch});

  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.brandDark, AppTheme.brand],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Find your next home',
            style: textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Verified listings, trusted landlords and honest prices across Nairobi.',
            style: textTheme.bodySmall?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 18),
          SearchBar(
            hintText: 'Search suburb, estate or price',
            onSubmitted: onSearch,
            leading: const Icon(Icons.search_rounded, color: AppTheme.brand),
            constraints: const BoxConstraints(minHeight: 52),
            elevation: const WidgetStatePropertyAll<double?>(0),
            backgroundColor: const WidgetStatePropertyAll<Color?>(Colors.white),
            side: const WidgetStatePropertyAll<BorderSide?>(BorderSide.none),
            shape: const WidgetStatePropertyAll<OutlinedBorder?>(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
            ),
            padding: const WidgetStatePropertyAll<EdgeInsetsGeometry?>(
              EdgeInsets.symmetric(horizontal: 16),
            ),
            hintStyle: const WidgetStatePropertyAll<TextStyle?>(
              TextStyle(color: AppTheme.mutedText, fontSize: 14),
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
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        if (action != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.brand,
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
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: AppTheme.brandTint,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: AppTheme.brand),
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PropertyCard extends StatelessWidget {
  const _PropertyCard({
    required this.title,
    required this.location,
    required this.price,
    required this.icon,
    required this.tint,
    required this.accent,
    required this.onTap,
  });

  final String title;
  final String location;
  final String price;
  final IconData icon;
  final Color tint;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SizedBox(
      width: 212,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 96,
                  color: tint,
                  child: Stack(
                    children: [
                      Center(
                        child: Icon(icon, size: 42, color: accent),
                      ),
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified_rounded, size: 12, color: accent),
                              const SizedBox(width: 3),
                              Text(
                                'Verified',
                                style: textTheme.labelSmall?.copyWith(
                                  color: accent,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(
                            Icons.place_outlined,
                            size: 13,
                            color: AppTheme.mutedText,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            location,
                            style: textTheme.bodySmall?.copyWith(
                              color: AppTheme.mutedText,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              price,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppTheme.brand,
                              ),
                            ),
                          ),
                          const Text(
                            '/month',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.mutedText,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ComingSoonTab extends StatelessWidget {
  const _ComingSoonTab({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

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
                    color: AppTheme.brand,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
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
                      decoration: const BoxDecoration(
                        color: AppTheme.brandTint,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, size: 32, color: AppTheme.brand),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Coming soon',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppTheme.mutedText,
                      ),
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
