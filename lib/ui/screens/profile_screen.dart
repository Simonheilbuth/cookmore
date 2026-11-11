import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../models/profile.dart';
import '../../services/sync_service.dart';
import '../../viewmodels/pantry_view_model.dart';
import '../../viewmodels/session_view_model.dart';
import '../widgets/ingredient_input.dart';
import '../widgets/profile_widgets.dart';
import '../widgets/state_views.dart';

/// Settings for the current profile: diet, theme, pantry and cloud backup.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final services = context.read<AppServices>();
    final profile = context.read<SessionViewModel>().current!;
    return ChangeNotifierProvider(
      create: (_) => PantryViewModel(services.pantry, profile.id)..load(),
      child: const _ProfileView(),
    );
  }
}

class _ProfileView extends StatelessWidget {
  const _ProfileView();

  Future<void> _edit(BuildContext context, Profile profile) async {
    final result = await ProfileFormDialog.show(context, initial: profile);
    if (result == null || !context.mounted) return;
    final error = await context.read<SessionViewModel>().updateCurrent(
          nickname: result.nickname,
          avatar: result.avatar,
        );
    if (error != null && context.mounted) showSnack(context, error);
  }

  Future<void> _delete(BuildContext context, Profile profile) async {
    if (!await confirmDeleteProfile(context, profile)) return;
    if (!context.mounted) return;
    await context.read<SessionViewModel>().deleteProfile(profile);
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionViewModel>();
    final profile = session.current;
    if (profile == null) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  ProfileAvatar(avatar: profile.avatar, radius: 32),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(profile.nickname,
                        style: theme.textTheme.headlineSmall),
                  ),
                  IconButton(
                    tooltip: 'Edit profile',
                    onPressed: () => _edit(context, profile),
                    icon: const Icon(Icons.edit),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _Section(
                title: 'Diet preference',
                child: _ChoiceRow<DietPreference>(
                  values: DietPreference.values,
                  selected: profile.diet,
                  labelOf: (diet) => diet.label,
                  onSelected: (diet) => session.updateCurrent(diet: diet),
                ),
              ),
              _Section(
                title: 'Appearance',
                child: _ChoiceRow<ThemePreference>(
                  values: ThemePreference.values,
                  selected: profile.themePreference,
                  labelOf: (mode) => mode.label,
                  onSelected: (mode) =>
                      session.updateCurrent(themePreference: mode),
                ),
              ),
              const _Section(title: 'My pantry', child: _PantryEditor()),
              const _Section(title: 'Cloud backup', child: _SyncStatus()),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: session.switchProfile,
                    icon: const Icon(Icons.swap_horiz),
                    label: const Text('Switch profile'),
                  ),
                  TextButton.icon(
                    onPressed: () => _delete(context, profile),
                    style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.error),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete profile'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

/// A row of choice chips. Chips wrap to a new line on narrow screens, so
/// they never overflow on small phones.
class _ChoiceRow<T> extends StatelessWidget {
  const _ChoiceRow({
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
  });

  final List<T> values;
  final T selected;
  final String Function(T value) labelOf;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final value in values)
          ChoiceChip(
            label: Text(labelOf(value)),
            selected: value == selected,
            onSelected: (_) {
              if (value != selected) onSelected(value);
            },
          ),
      ],
    );
  }
}

class _PantryEditor extends StatelessWidget {
  const _PantryEditor();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PantryViewModel>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ingredients you usually have at home. Recipes show which '
          'ingredients you are missing.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        IngredientInput(
          hintText: 'Add to pantry, e.g. rice',
          errorText: vm.inputError,
          onSubmit: vm.add,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final item in vm.items)
              InputChip(
                label: Text(item),
                onDeleted: () => vm.remove(item),
                deleteButtonTooltipMessage: 'Remove $item',
              ),
          ],
        ),
      ],
    );
  }
}

class _SyncStatus extends StatelessWidget {
  const _SyncStatus();

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncService>();
    final theme = Theme.of(context);

    final String status;
    final IconData icon;
    if (!sync.isConfigured) {
      status = '${sync.setupProblem ?? 'Cloud backup is not set up.'} '
          'Your data is saved on this device.';
      icon = Icons.cloud_off;
    } else if (sync.isSyncing) {
      status = 'Backing up…';
      icon = Icons.cloud_upload_outlined;
    } else if (sync.pendingCount > 0) {
      status = sync.lastAttemptFailed
          ? 'Changes are saved on this device and will be backed up when '
              "you're online."
          : 'Changes waiting to be backed up.';
      icon = Icons.cloud_queue;
    } else {
      status = 'Your profile is backed up.';
      icon = Icons.cloud_done_outlined;
    }

    return Row(
      children: [
        Icon(icon, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(child: Text(status)),
        if (sync.isConfigured)
          TextButton(
            onPressed: sync.isSyncing ? null : sync.syncNow,
            child: const Text('Sync now'),
          ),
      ],
    );
  }
}
