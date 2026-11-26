import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:get_keja_mobile/app/theme/design_system.dart';
import 'package:get_keja_mobile/core/widgets/design_widgets.dart';
import 'package:get_keja_mobile/features/house_seeker/domain/entities/house_seeker_models.dart';
import 'package:get_keja_mobile/features/house_seeker/presentation/state/house_seeker_state.dart';
import 'package:get_keja_mobile/features/house_seeker/presentation/widgets/format_utils.dart';
import 'package:get_keja_mobile/l10n/generated/app_localizations.dart';

class HouseSeekerSavedSearchesPage extends ConsumerWidget {
  const HouseSeekerSavedSearchesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final searchesAsync = ref.watch(houseSeekerSavedSearchesProvider);
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(title: Text(l10n.savedSearches)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _saveCurrentSearch(context, ref, l10n),
        icon: const Icon(Icons.bookmark_add_outlined),
        label: Text(l10n.saveCurrentSearch),
      ),
      body: searchesAsync.when(
        data: (searches) => searches.isEmpty
            ? const _EmptySavedSearches()
            : ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: searches.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final search = searches[index];
                  return _SavedSearchTile(
                    search: search,
                    l10n: l10n,
                    onOpen: () => _open(context, ref, search),
                    onToggleAlerts: () =>
                        _toggleAlerts(context, ref, search, l10n),
                    onEdit: () => _editSearch(context, ref, search, l10n),
                    onDelete: () => _delete(context, ref, search),
                    onRun: () => _runSearch(context, ref, search, l10n),
                  );
                },
              ),
        loading: () => const AppListSkeleton(rows: 4),
        error: (error, _) => AppNotice(
          message: l10n.couldNotLoadSavedSearches,
          type: NoticeType.error,
          actionLabel: l10n.retry,
          onAction: () => ref.invalidate(houseSeekerSavedSearchesProvider),
        ),
      ),
    );
  }

  Future<void> _saveCurrentSearch(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final criteria = ref.read(houseSeekerSearchProvider).filter.toCriteria();
    if (criteria.isEmpty ||
        (criteria.length == 1 && criteria.containsKey('sort'))) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Set some search filters first, then save the search.',
            ),
          ),
        );
      }
      return;
    }
    final nameController = TextEditingController();
    String? selectedFrequency;
    bool alertsEnabled = true;
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.nameThisSearch),
        content: StatefulBuilder(
          builder: (context, setState) {
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  AppTextField(
                    controller: nameController,
                    label: l10n.nameThisSearch,
                    hintText: 'e.g. 2-bedroom flats in Nairobi under 40k',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(l10n.alertFrequency, style: AppTypography.labelMedium),
                  const SizedBox(height: AppSpacing.xs),
                  DropdownButtonFormField<String>(
                    value: selectedFrequency,
                    decoration: InputDecoration(
                      labelText: l10n.howOftenToAlert,
                      border: OutlineInputBorder(),
                    ),
                    items: <String>['immediate', 'daily', 'weekly']
                        .map(
                          (f) => DropdownMenuItem<String>(
                            value: f,
                            child: Text(_frequencyLabel(f, l10n)),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (v) => setState(() => selectedFrequency = v),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SwitchListTile(
                    title: Text(l10n.sendNotifications),
                    value: alertsEnabled,
                    onChanged: (v) => setState(() => alertsEnabled = v),
                  ),
                ],
              ),
            );
          },
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(nameController.text.trim()),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    try {
      await ref
          .read(houseSeekerRepositoryProvider)
          .createSavedSearch(
            name: name,
            criteria: criteria,
            alertsEnabled: alertsEnabled,
            alertFrequency: selectedFrequency,
          );
      ref.invalidate(houseSeekerSavedSearchesProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.searchSaved)));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.couldNotSaveSearch(error.toString()))),
        );
      }
    }
  }

  void _open(BuildContext context, WidgetRef ref, SavedSearchModel search) {
    ref
        .read(houseSeekerSearchProvider.notifier)
        .applyFilter(HouseSeekerFilter.fromCriteria(search.criteria));
    context.pushNamed('house-seeker-search');
  }

  Future<void> _editSearch(
    BuildContext context,
    WidgetRef ref,
    SavedSearchModel search,
    AppLocalizations l10n,
  ) async {
    final nameController = TextEditingController(text: search.name);
    String? selectedFrequency = search.alertFrequency;
    bool alertsEnabled = search.alertsEnabled;
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.editSavedSearch),
        content: StatefulBuilder(
          builder: (context, setState) {
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  AppTextField(
                    controller: nameController,
                    label: l10n.nameThisSearch,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(l10n.alertFrequency, style: AppTypography.labelMedium),
                  const SizedBox(height: AppSpacing.xs),
                  DropdownButtonFormField<String>(
                    value: selectedFrequency,
                    decoration: InputDecoration(
                      labelText: l10n.howOftenToAlert,
                      border: OutlineInputBorder(),
                    ),
                    items: <String>['immediate', 'daily', 'weekly']
                        .map(
                          (f) => DropdownMenuItem<String>(
                            value: f,
                            child: Text(_frequencyLabel(f, l10n)),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (v) => setState(() => selectedFrequency = v),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SwitchListTile(
                    title: Text(l10n.sendNotifications),
                    value: alertsEnabled,
                    onChanged: (v) => setState(() => alertsEnabled = v),
                  ),
                ],
              ),
            );
          },
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(nameController.text.trim()),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    try {
      await ref
          .read(houseSeekerRepositoryProvider)
          .updateSavedSearch(
            searchId: search.id,
            name: name,
            alertsEnabled: alertsEnabled,
            alertFrequency: selectedFrequency,
          );
      ref.invalidate(houseSeekerSavedSearchesProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.searchUpdated)));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.couldNotUpdateSearch)));
      }
    }
  }

  Future<void> _runSearch(
    BuildContext context,
    WidgetRef ref,
    SavedSearchModel search,
    AppLocalizations l10n,
  ) async {
    try {
      await ref.read(houseSeekerRepositoryProvider).runSavedSearch(search.id);
      ref.invalidate(houseSeekerSavedSearchesProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.searchMatched)));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.couldNotRunSearch)));
      }
    }
  }

  Future<void> _toggleAlerts(
    BuildContext context,
    WidgetRef ref,
    SavedSearchModel search,
    AppLocalizations l10n,
  ) async {
    try {
      await ref
          .read(houseSeekerRepositoryProvider)
          .updateSavedSearch(
            searchId: search.id,
            alertsEnabled: !search.alertsEnabled,
          );
      ref.invalidate(houseSeekerSavedSearchesProvider);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.couldNotUpdateAlerts)));
      }
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    SavedSearchModel search,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteSavedSearch),
        content: Text('“${search.name}” ${l10n.searchWillBeRemoved}'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.keep),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              l10n.deleteSearch,
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(houseSeekerRepositoryProvider)
          .deleteSavedSearch(search.id);
      ref.invalidate(houseSeekerSavedSearchesProvider);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.couldNotDeleteSearch)));
      }
    }
  }

  static String _frequencyLabel(String frequency, AppLocalizations l10n) {
    switch (frequency) {
      case 'immediate':
        return l10n.alertImmediately;
      case 'daily':
        return l10n.alertDaily;
      case 'weekly':
        return l10n.alertWeekly;
      default:
        return frequency;
    }
  }
}

class _SavedSearchTile extends StatelessWidget {
  const _SavedSearchTile({
    required this.search,
    required this.l10n,
    required this.onOpen,
    required this.onToggleAlerts,
    required this.onEdit,
    required this.onDelete,
    required this.onRun,
  });

  final SavedSearchModel search;
  final AppLocalizations l10n;
  final VoidCallback onOpen;
  final VoidCallback onToggleAlerts;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onRun;

  @override
  Widget build(BuildContext context) {
    final chips = _criteriaChips(search.criteria);
    return AppCard(
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  search.name,
                  style: AppTypography.titleSmall.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, color: AppColors.brand),
                tooltip: l10n.edit,
              ),
              IconButton(
                onPressed: onRun,
                icon: const Icon(Icons.refresh, color: AppColors.brand),
                tooltip: l10n.runNow,
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, color: AppColors.error),
                tooltip: l10n.deleteSearch,
              ),
            ],
          ),
          if (chips.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: chips
                  .map((c) => _Chip(label: c))
                  .toList(growable: false),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              Icon(
                search.alertsEnabled
                    ? Icons.notifications_active
                    : Icons.notifications_off_outlined,
                size: 16,
                color: search.alertsEnabled
                    ? AppColors.brand
                    : AppColors.mutedText,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      search.alertsEnabled ? l10n.alertsOn : l10n.alertsOff,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.mutedText,
                      ),
                    ),
                    if (search.alertFrequency != null && search.alertsEnabled)
                      Text(
                        'Alerts: ${HouseSeekerSavedSearchesPage._frequencyLabel(search.alertFrequency!, l10n)}',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.mutedText,
                        ),
                      ),
                  ],
                ),
              ),
              TextButton(
                onPressed: onToggleAlerts,
                child: Text(
                  search.alertsEnabled ? l10n.turnOffAlerts : l10n.turnOnAlerts,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<String> _criteriaChips(Map<String, dynamic> criteria) {
    final result = <String>[];
    criteria.forEach((key, value) {
      if (key == 'sort' || value == null) return;
      if (value is String && value.isEmpty) return;
      final label = key == 'rentMin'
          ? 'From ${formatPriceCompact(value is num ? value : null)}'
          : key == 'rentMax'
          ? 'Up to ${formatPriceCompact(value is num ? value : null)}'
          : key == 'bedrooms'
          ? '$value beds'
          : key == 'bathrooms'
          ? '$value baths'
          : '$key: $value';
      result.add(label);
    });
    return result;
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.brandTint,
        borderRadius: AppBorderRadius.roundRadius,
      ),
      child: Text(
        label,
        style: AppTypography.labelSmall.copyWith(color: AppColors.brand),
      ),
    );
  }
}

class _EmptySavedSearches extends StatelessWidget {
  const _EmptySavedSearches();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.bookmark_border,
              size: 56,
              color: AppColors.inactive,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(l10n.noSavedSearchesYet, style: AppTypography.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.applyFiltersSaveSearch,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.mutedText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
