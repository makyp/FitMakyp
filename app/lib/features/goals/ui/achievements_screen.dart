import '../../../core/utils/gender.dart';
import 'package:flutter/material.dart';

import '../../../app_scope.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/common.dart';
import '../domain/achievements.dart';

/// Mis insignias: conseguidas a color, pendientes en gris con su avance.
class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final rewards = AppScope.of(context).rewards;
    return ListenableBuilder(
      listenable: rewards,
      builder: (context, _) {
        final t = Theme.of(context).textTheme;
        final all = rewards.achievementStatus;
        final got = all.where((a) => a.unlocked).length;
        return Scaffold(
          appBar: AppBar(title: const Text('Mis insignias')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$got de ${all.length} insignias', style: t.titleLarge),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: all.isEmpty ? 0 : got / all.length,
                          minHeight: 8,
                          backgroundColor: FmColors.line,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Cada insignia suma puntos para tu mascota. Nunca se pierden.',
                          style: t.bodySmall?.copyWith(color: FmColors.muted)),
                    ],
                  ),
                ),
              ),
              for (final g in AchievementGroup.values) ...[
                SectionTitle(g.label),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.95,
                  children: [
                    for (final a in all.where((x) => x.achievement.group == g)) _AchievementTile(status: a),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({required this.status});
  final AchievementStatus status;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final a = status.achievement;
    final on = status.unlocked;
    return Card(
      color: on ? FmColors.lavender : FmColors.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          children: [
            Opacity(
              opacity: on ? 1 : 0.35,
              child: ColorFiltered(
                colorFilter: on
                    ? const ColorFilter.mode(Colors.transparent, BlendMode.dst)
                    : const ColorFilter.matrix(<double>[
                        0.33, 0.33, 0.33, 0, 0, //
                        0.33, 0.33, 0.33, 0, 0,
                        0.33, 0.33, 0.33, 0, 0,
                        0, 0, 0, 1, 0,
                      ]),
                child: Text(a.emoji, style: const TextStyle(fontSize: 38)),
              ),
            ),
            const SizedBox(height: 6),
            Text(context.g(a.title), style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Expanded(
              child: Text(
                a.description,
                style: t.bodySmall?.copyWith(color: FmColors.muted),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (on)
              Text(a.points > 0 ? '✓ Conseguida · +${a.points} ⭐' : '✓ Conseguida',
                  style: t.labelSmall?.copyWith(color: FmColors.primary, fontWeight: FontWeight.w800))
            else ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(value: status.fraction, minHeight: 6, backgroundColor: FmColors.line),
              ),
              const SizedBox(height: 4),
              Text(
                a.points > 0 ? '${status.progressText} · +${a.points} ⭐' : status.progressText,
                style: t.labelSmall?.copyWith(color: FmColors.muted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
