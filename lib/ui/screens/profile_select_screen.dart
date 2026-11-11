import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/profile.dart';
import '../../viewmodels/session_view_model.dart';
import '../widgets/profile_widgets.dart';
import '../widgets/state_views.dart';

/// "Who's cooking?" – pick or create a profile. No password is needed.
class ProfileSelectScreen extends StatelessWidget {
  const ProfileSelectScreen({super.key});

  Future<void> _create(BuildContext context) async {
    final result = await ProfileFormDialog.show(context);
    if (result == null || !context.mounted) return;
    final error = await context.read<SessionViewModel>().createProfile(
          nickname: result.nickname,
          avatar: result.avatar,
          diet: result.diet,
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
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                children: [
                  Text('CookMore',
                      style: theme.textTheme.displaySmall
                          ?.copyWith(color: theme.colorScheme.primary)),
                  const SizedBox(height: 8),
                  Text("Who's cooking?", style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 20,
                    runSpacing: 20,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final profile in session.profiles)
                        _ProfileTile(
                          label: profile.nickname,
                          avatar: ProfileAvatar(avatar: profile.avatar, radius: 36),
                          onTap: () => session.select(profile),
                          onLongPress: () => _delete(context, profile),
                        ),
                      _ProfileTile(
                        label: 'New',
                        avatar: CircleAvatar(
                          radius: 36,
                          child: Icon(Icons.add,
                              size: 32, color: theme.colorScheme.primary),
                        ),
                        onTap: () => _create(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Profiles keep your favourites, pantry and settings. '
                    'They have no password, so anyone using this device can '
                    'open them – only your nickname and cooking data are stored.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                  if (session.profiles.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Long-press a profile to delete it.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.label,
    required this.avatar,
    required this.onTap,
    this.onLongPress,
  });

  final String label;
  final Widget avatar;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: SizedBox(
          width: 90,
          child: Column(
            children: [
              avatar,
              const SizedBox(height: 8),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}
