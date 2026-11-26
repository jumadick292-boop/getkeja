import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_keja_mobile/features/provider/presentation/state/provider_state.dart';

/// Provider organizations (foundation): list organizations the user belongs to
/// and invite staff. Real API-backed; full role management arrives later.
class ProviderOrganizationsPage extends ConsumerStatefulWidget {
  const ProviderOrganizationsPage({super.key});

  @override
  ConsumerState<ProviderOrganizationsPage> createState() =>
      _ProviderOrganizationsPageState();
}

class _ProviderOrganizationsPageState
    extends ConsumerState<ProviderOrganizationsPage> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () => ref.read(providerOrganizationsProvider.notifier).load(),
    );
  }

  Future<void> _invite(BuildContext context, String orgId) async {
    final emailController = TextEditingController();
    final role = ValueNotifier<String>('member');
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Invite staff'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            ValueListenableBuilder<String>(
              valueListenable: role,
              builder: (_, value, child) => DropdownButton<String>(
                value: value,
                items: const [
                  DropdownMenuItem(value: 'member', child: Text('Member')),
                  DropdownMenuItem(value: 'staff', child: Text('Staff')),
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                ],
                onChanged: (v) => role.value = v ?? 'member',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (result != true) return;
    try {
      await ref.read(providerRepositoryProvider).inviteStaff(orgId, {
        'email': emailController.text.trim(),
        'role': role.value,
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invitation sent')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(providerOrganizationsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Organizations')),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (organizations) => organizations.isEmpty
            ? const Center(child: Text('No organizations yet'))
            : ListView.builder(
                itemCount: organizations.length,
                itemBuilder: (context, index) {
                  final org = organizations[index];
                  final orgId = org['id'] as String?;
                  return Card(
                    child: ListTile(
                      title: Text(org['name'] as String? ?? 'Organization'),
                      subtitle: Text(org['type'] as String? ?? ''),
                      trailing: orgId == null
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.person_add),
                              onPressed: () => _invite(context, orgId),
                            ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}