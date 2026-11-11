import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/timer_view_model.dart';

/// Cooking timer controls shown on the recipe screen.
///
/// When the time is up, a local notification is shown, also when the app
/// is in the background.
class CookingTimerCard extends StatelessWidget {
  const CookingTimerCard({super.key, required this.label});

  /// Name shown in the notification, normally the recipe name.
  final String label;

  static String format(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final timer = context.watch<TimerViewModel>();
    final theme = Theme.of(context);
    final busyElsewhere =
        (timer.isRunning || timer.justFinished) && timer.label != label;

    return Card(
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.timer_outlined),
                const SizedBox(width: 8),
                Text(
                  format(timer.remaining),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'One minute less',
                  onPressed: timer.isRunning
                      ? null
                      : () => timer.setMinutes(timer.minutes - 1),
                  icon: const Icon(Icons.remove),
                ),
                IconButton(
                  tooltip: 'One minute more',
                  onPressed: timer.isRunning
                      ? null
                      : () => timer.setMinutes(timer.minutes + 1),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            if (busyElsewhere)
              Text('Timer is running for "${timer.label}".',
                  style: theme.textTheme.bodySmall),
            if (timer.justFinished)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text("Time's up!",
                    style: theme.textTheme.titleMedium
                        ?.copyWith(color: theme.colorScheme.primary)),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (timer.justFinished)
                  FilledButton.icon(
                    onPressed: timer.dismissFinished,
                    icon: const Icon(Icons.check),
                    label: const Text('OK'),
                  )
                else if (timer.isRunning)
                  FilledButton.icon(
                    onPressed: timer.pause,
                    icon: const Icon(Icons.pause),
                    label: const Text('Pause'),
                  )
                else
                  FilledButton.icon(
                    onPressed: () => timer.start(label),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start'),
                  ),
                OutlinedButton.icon(
                  onPressed: timer.reset,
                  icon: const Icon(Icons.replay),
                  label: const Text('Reset'),
                ),
              ],
            ),
            if (timer.notificationsBlocked)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Notifications are turned off, so the timer can only alert '
                  'you while CookMore is open. You can allow notifications '
                  'in your device settings.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
