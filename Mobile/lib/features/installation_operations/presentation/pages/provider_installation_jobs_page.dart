// Provider installation jobs list + detail (Task 13.14).
// Surfaces real staff assignment, equipment/materials, testing and evidence
// workflows (not just backend endpoints).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/widgets/design_widgets.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../state/installation_operations_state.dart';

class ProviderInstallationJobsPage extends ConsumerWidget {
  const ProviderInstallationJobsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final jobsAsync = ref.watch(providerInstallationJobsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.installationOperations)),
      body: jobsAsync.when(
        data: (jobs) {
          if (jobs.isEmpty) {
            return Center(child: Text(l10n.installationOperationsEmpty, style: AppTypography.bodyMedium));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(providerInstallationJobsProvider),
            child: ListView.builder(
              padding: AppSpacing.screenPadding,
              itemCount: jobs.length,
              itemBuilder: (context, i) {
                final job = jobs[i];
                return AppCard(
                  margin: const EdgeInsets.only(bottom: 12),
                  onTap: () => context.push('/installation-operations/provider/jobs/${job['id']}'),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(job['categoryId']?.toString() ?? '', style: AppTypography.titleMedium),
                    const SizedBox(height: 4),
                    Text('${job['status']}', style: AppTypography.bodySmall),
                  ]),
                );
              },
            ),
          );
        },
        loading: () => const AppListSkeleton(rows: 5),
        error: (_, __) => AppNotice(
          message: l10n.couldNotLoadNotifications,
          type: NoticeType.error,
          actionLabel: l10n.retry,
          onAction: () => ref.invalidate(providerInstallationJobsProvider),
        ),
      ),
    );
  }
}

class ProviderInstallationJobDetailPage extends ConsumerStatefulWidget {
  const ProviderInstallationJobDetailPage({super.key, required this.jobId});

  final String jobId;

  @override
  ConsumerState<ProviderInstallationJobDetailPage> createState() =>
      _ProviderInstallationJobDetailPageState();
}

class _ProviderInstallationJobDetailPageState
    extends ConsumerState<ProviderInstallationJobDetailPage> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(providerInstallationJobDetailProvider(widget.jobId));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.couldNotLoadNotifications)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _progress(String to) =>
      _run(() => ref.read(installationOperationsRemoteDataSourceProvider).updateProgress(widget.jobId, to));

  Future<void> _complete() =>
      _run(() => ref.read(installationOperationsRemoteDataSourceProvider).submitCompletion(widget.jobId));

  Future<void> _assess() => _run(() => ref
      .read(installationOperationsRemoteDataSourceProvider)
      .recordAssessment(widget.jobId, <String, dynamic>{
        'complete': true,
        'findings': 'Assessed',
        'customerVisibleReport': 'Assessed on site',
      }));

  Future<void> _prompt(String title, Future<void> Function(Map<String, dynamic>) onSubmit,
      {List<(String, String)> fields = const []}) async {
    final controllers = <String, TextEditingController>{
      for (final f in fields) f.$1: TextEditingController(),
    };
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final f in fields)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextField(
                    controller: controllers[f.$1],
                    decoration: InputDecoration(labelText: f.$2),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(AppLocalizations.of(context)!.cancel)),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(<String, dynamic>{
              for (final f in fields) f.$1: controllers[f.$1]!.text.trim(),
            }),
            child: Text(AppLocalizations.of(context)!.save),
          ),
        ],
      ),
    );
    if (result != null) await onSubmit(result);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final detailAsync = ref.watch(providerInstallationJobDetailProvider(widget.jobId));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.installationOperations)),
      body: detailAsync.when(
        data: (job) {
          final status = job['status']?.toString() ?? '';
          final assessments = (job['assessments'] as List<dynamic>? ?? <dynamic>[]);
          final plans = (job['plans'] as List<dynamic>? ?? <dynamic>[]);
          final equipment = (job['equipment'] as List<dynamic>? ?? <dynamic>[]);
          final tests = (job['tests'] as List<dynamic>? ?? <dynamic>[]);
          final staff = (job['staff'] as List<dynamic>? ?? <dynamic>[]);
          return ListView(
            padding: AppSpacing.screenPadding,
            children: [
              AppCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(job['categoryId']?.toString() ?? '', style: AppTypography.titleMedium),
                  const SizedBox(height: 4),
                  Text(status, style: AppTypography.bodyMedium),
                  if ((job['serviceAddress']?.toString() ?? '').isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(job['serviceAddress'].toString(), style: AppTypography.bodySmall),
                  ],
                ]),
              ),
              const SizedBox(height: 8),
              if (assessments.isEmpty)
                PrimaryButton(label: l10n.recordAssessment, onPressed: _busy ? null : _assess),
              if (plans.isEmpty)
                PrimaryButton(
                  label: l10n.addPlan,
                  onPressed: _busy
                      ? null
                      : () => _prompt(l10n.addPlan, (data) async {
                          await ref.read(installationOperationsRemoteDataSourceProvider).createPlan(widget.jobId, <String, dynamic>{
                            'summary': data['summary'],
                            'deliverables': data['deliverables'],
                          });
                        }, fields: [( 'summary', l10n.summary ), ( 'deliverables', l10n.deliverables )]),
                ),
              PrimaryButton(
                label: l10n.addEquipment,
                onPressed: _busy
                    ? null
                    : () => _prompt(l10n.addEquipment, (data) async {
                        await ref.read(installationOperationsRemoteDataSourceProvider).addEquipment(widget.jobId, <String, dynamic>{
                          'description': data['description'],
                          'quantity': int.tryParse(data['quantity'] ?? '') ?? 1,
                          'serialOrId': data['serialOrId'],
                        });
                      }, fields: [( 'description', l10n.description ), ( 'quantity', l10n.quantity ), ( 'serialOrId', l10n.serialOrId )]),
              ),
              PrimaryButton(
                label: l10n.recordTest,
                onPressed: _busy
                    ? null
                    : () => _prompt(l10n.recordTest, (data) async {
                        await ref.read(installationOperationsRemoteDataSourceProvider).recordTest(widget.jobId, <String, dynamic>{
                          'name': data['name'],
                          'outcome': data['outcome'],
                        });
                      }, fields: [( 'name', l10n.testName ), ( 'outcome', l10n.outcome )]),
              ),
              PrimaryButton(
                label: l10n.uploadEvidence,
                onPressed: _busy
                    ? null
                    : () => _prompt(l10n.uploadEvidence, (data) async {
                        await ref.read(installationOperationsRemoteDataSourceProvider).addAttachment(widget.jobId, <String, dynamic>{
                          'documentId': data['documentId'],
                          'kind': data['kind'],
                        });
                      }, fields: [( 'documentId', l10n.documentId ), ( 'kind', l10n.evidenceKind )]),
              ),
              PrimaryButton(
                label: l10n.assignStaff,
                onPressed: _busy
                    ? null
                    : () => _prompt(l10n.assignStaff, (data) async {
                        await ref.read(installationOperationsRemoteDataSourceProvider).assignStaff(widget.jobId, data['userId']!, label: data['label']);
                      }, fields: [( 'userId', l10n.staffUserId ), ( 'label', l10n.label )]),
              ),
              if (equipment.isNotEmpty) ...[
                AppSectionHeader(title: l10n.equipment),
                for (final e in equipment) ...[
                  AppCard(child: Text('${(e as Map)['description'] ?? ''} x${e['quantity'] ?? ''}')),
                ],
              ],
              if (tests.isNotEmpty) ...[
                AppSectionHeader(title: l10n.testingCommissioning),
                for (final t in tests) ...[
                  AppCard(child: Text('${(t as Map)['name'] ?? ''}: ${t['outcome'] ?? ''}')),
                ],
              ],
              if (staff.isNotEmpty) ...[
                AppSectionHeader(title: l10n.staff),
                for (final s in staff.where((s) => (s as Map)['isActive'] == true)) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text((s as Map)['label']?.toString() ?? s['userId'].toString()),
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: _busy
                          ? null
                          : () => _run(() => ref.read(installationOperationsRemoteDataSourceProvider).revokeStaff(widget.jobId, s['userId'] as String)),
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 8),
              if (status == 'confirmed' || status == 'scheduled' || status == 'assigned')
                PrimaryButton(label: l10n.startWork, onPressed: _busy ? null : () => _progress('in_progress')),
              if (status == 'in_progress' || status == 'awaiting_equipment')
                PrimaryButton(label: l10n.startTesting, onPressed: _busy ? null : () => _progress('testing')),
              if (status == 'testing')
                PrimaryButton(label: l10n.readyForHandover, onPressed: _busy ? null : () => _progress('awaiting_handover')),
              if (status == 'awaiting_handover')
                PrimaryButton(label: l10n.confirmCompletion, onPressed: _busy ? null : _complete),
            ],
          );
        },
        loading: () => const AppListSkeleton(rows: 4),
        error: (_, __) => AppNotice(
          message: l10n.couldNotLoadNotifications,
          type: NoticeType.error,
          actionLabel: l10n.retry,
          onAction: () => ref.invalidate(providerInstallationJobDetailProvider(widget.jobId)),
        ),
      ),
    );
  }
}