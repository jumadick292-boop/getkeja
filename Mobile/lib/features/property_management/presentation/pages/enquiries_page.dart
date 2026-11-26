library features.property_management.presentation.pages.enquiries_page;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:get_keja_mobile/app/theme/design_system.dart';
import 'package:get_keja_mobile/core/widgets/design_widgets.dart';
import 'package:get_keja_mobile/features/property_management/presentation/state/property_state.dart';
import 'package:get_keja_mobile/features/property_management/presentation/widgets/enquiry_card.dart';

class EnquiriesPage extends ConsumerStatefulWidget {
  const EnquiriesPage({super.key});

  @override
  ConsumerState<EnquiriesPage> createState() => _EnquiriesPageState();
}

class _EnquiriesPageState extends ConsumerState<EnquiriesPage> {
  String? _statusFilter;

  static const _statusOptions = <String?>[
    null,
    'new',
    'contacted',
    'viewing_scheduled',
    'converted',
    'closed',
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(propertyNotifierProvider.notifier).loadEnquiries(),
    );
  }

  Future<void> _reload() {
    return ref
        .read(propertyNotifierProvider.notifier)
        .loadEnquiries(status: _statusFilter);
  }

  @override
  Widget build(BuildContext context) {
    final enquiries = ref.watch(enquiriesProvider);
    final isLoading = ref.watch(propertyLoadingProvider);
    final error = ref.watch(propertyErrorProvider);
    final notifier = ref.read(propertyNotifierProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Enquiries'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _reload,
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _reload,
          child: SingleChildScrollView(
            padding: AppSpacing.screenPadding,
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (error != null)
                  AppNotice(
                    message: error,
                    type: NoticeType.error,
                    onDismiss: notifier.clearError,
                  ),
                _StatusFilter(
                  value: _statusFilter,
                  options: _statusOptions,
                  onChanged: (value) {
                    setState(() => _statusFilter = value);
                    _reload();
                  },
                ),
                const SizedBox(height: 16),
                if (isLoading && enquiries.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (enquiries.isEmpty)
                  _EmptyState()
                else
                  ...enquiries.map(
                    (enquiry) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: EnquiryCard(enquiry: enquiry),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/landlord/enquiries/new'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New enquiry'),
      ),
    );
  }
}

class _StatusFilter extends StatelessWidget {
  const _StatusFilter({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String? value;
  final List<String?> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final option = options[index];
          final selected = option == value;
          final spaced = option?.replaceAll('_', ' ') ?? '';
          final label = option == null
              ? 'All'
              : spaced.isEmpty
              ? spaced
              : spaced[0].toUpperCase() + spaced.substring(1);
          return ChoiceChip(
            label: Text(label),
            selected: selected,
            onSelected: (_) => onChanged(option),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: AppSpacing.cardPadding,
      child: Column(
        children: [
          Icon(
            Icons.contacts_outlined,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No enquiries yet',
            style: AppTypography.titleMedium.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Prospective renter enquiries will appear here.',
            style: AppTypography.bodyMedium.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
