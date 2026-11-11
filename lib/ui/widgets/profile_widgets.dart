import 'package:flutter/material.dart';

import '../../models/profile.dart';
import '../../utils/validators.dart';

/// Round avatar showing the profile's emoji.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.avatar, this.radius = 20});

  final String avatar;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      child: Text(avatar, style: TextStyle(fontSize: radius)),
    );
  }
}

/// Values entered in [ProfileFormDialog].
class ProfileFormResult {
  const ProfileFormResult(this.nickname, this.avatar, this.diet);

  final String nickname;
  final String avatar;
  final DietPreference diet;
}

/// Dialog for creating or editing a profile (no password).
class ProfileFormDialog extends StatefulWidget {
  const ProfileFormDialog({super.key, this.initial});

  /// The profile to edit, or null to create a new one.
  final Profile? initial;

  static Future<ProfileFormResult?> show(
    BuildContext context, {
    Profile? initial,
  }) {
    return showDialog<ProfileFormResult>(
      context: context,
      builder: (_) => ProfileFormDialog(initial: initial),
    );
  }

  @override
  State<ProfileFormDialog> createState() => _ProfileFormDialogState();
}

class _ProfileFormDialogState extends State<ProfileFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nickname =
      TextEditingController(text: widget.initial?.nickname ?? '');
  late String _avatar = widget.initial?.avatar ?? Profile.avatars.first;
  late DietPreference _diet = widget.initial?.diet ?? DietPreference.none;

  bool get _isNew => widget.initial == null;

  @override
  void dispose() {
    _nickname.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(ProfileFormResult(_nickname.text, _avatar, _diet));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(_isNew ? 'New profile' : 'Edit profile'),
      content: SizedBox(
        width: 360,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _nickname,
                  autofocus: _isNew,
                  maxLength: Validators.nicknameMaxLength,
                  decoration: const InputDecoration(labelText: 'Nickname'),
                  validator: Validators.nickname,
                  onFieldSubmitted: (_) => _save(),
                ),
                const SizedBox(height: 8),
                Text('Avatar', style: theme.textTheme.labelLarge),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final avatar in Profile.avatars)
                      ChoiceChip(
                        label: Text(avatar, style: const TextStyle(fontSize: 20)),
                        selected: _avatar == avatar,
                        onSelected: (_) => setState(() => _avatar = avatar),
                      ),
                  ],
                ),
                if (_isNew) ...[
                  const SizedBox(height: 12),
                  Text('Diet', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    children: [
                      for (final diet in DietPreference.values)
                        ChoiceChip(
                          label: Text(diet.label),
                          selected: _diet == diet,
                          onSelected: (_) => setState(() => _diet = diet),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  'No password needed. Please don\'t use your full name or '
                  'other personal information.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(_isNew ? 'Create' : 'Save'),
        ),
      ],
    );
  }
}

/// Asks the user to confirm deleting a profile. Returns true if confirmed.
Future<bool> confirmDeleteProfile(BuildContext context, Profile profile) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Delete ${profile.nickname}?'),
      content: const Text(
        'The profile, its favourites, pantry and shopping list will be '
        'deleted from this device and from the cloud backup.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
