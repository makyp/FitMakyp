import '../../core/utils/gender.dart';
import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../shared/widgets/pet_avatar.dart';
import '../goals/domain/rewards.dart';
import '../pet/domain/pet_items.dart';
import 'domain/challenges.dart';

/// Retos de la semana, el premio que viene y las semanas anteriores.
class ChallengesScreen extends StatelessWidget {
  const ChallengesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([scope.rewards, scope.pet]),
      builder: (context, _) {
        final t = Theme.of(context).textTheme;
        final now = DateTime.now();
        final input = scope.rewards.challenges;
        final monday = weekStart(now);
        final week = weekStatus(monday, input);
        final summary = summarize(input, now);
        final next = summary.perfectWeeks < challengePrizes.length ? petItemById(challengePrizes[summary.perfectWeeks]) : null;
        final daysLeft = 7 - (dateOnly(now).difference(monday).inDays);
        final doneCount = week.where((s) => s.done).length;

        return Scaffold(
          appBar: AppBar(title: const Text('Retos de la semana')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            children: [
              Text(
                doneCount == week.length
                    ? '¡Semana perfecta! 🎉'
                    : 'Quedan $daysLeft ${daysLeft == 1 ? 'día' : 'días'} · $doneCount de ${week.length} cumplidos',
                style: t.titleMedium,
              ),
              const SizedBox(height: 10),
              for (final s in week) ChallengeTile(status: s),
              const SizedBox(height: 8),
              Text(
                'Cada reto cumplido suma +${PointRules.challenge} puntos. Se cuentan solos con lo que ya registras.',
                style: t.bodySmall?.copyWith(color: FmColors.muted),
              ),
              const SizedBox(height: 18),
              Card(
                color: FmColors.lavender,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      PetAvatar(
                        size: 96,
                        mood: PetMood.celebrating,
                        look: next == null ? scope.pet.look : scope.pet.look.wearing(next.slot, next.id),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('🏆 Premio de la semana perfecta', style: t.labelLarge?.copyWith(color: FmColors.ink)),
                            const SizedBox(height: 4),
                            Text(
                              next == null ? '¡Ya tienes todos los premios! Eres imparable.' : context.g(next.name),
                              style: t.titleMedium?.copyWith(color: FmColors.ink, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Cumple los 3 retos de una semana y ${scope.pet.name} lo estrena. '
                              'Llevas ${summary.perfectWeeks} ${summary.perfectWeeks == 1 ? 'semana perfecta' : 'semanas perfectas'}.',
                              style: t.bodySmall?.copyWith(color: FmColors.ink),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text('Semanas anteriores', style: t.titleMedium),
              const SizedBox(height: 6),
              Card(
                child: Column(
                  children: [
                    for (var k = 1; k <= 6; k++)
                      Builder(builder: (_) {
                        final m = DateTime(monday.year, monday.month, monday.day - 7 * k);
                        final st = weekStatus(m, input);
                        final d = st.where((s) => s.done).length;
                        return ListTile(
                          dense: true,
                          title: Text('Semana del ${formatShortDate(m)}'),
                          subtitle: Text(st.map((s) => '${s.kind.emoji} ${s.progress}/${s.kind.target}').join('   ')),
                          trailing: Text(
                            d == st.length ? '🏆' : '$d/${st.length}',
                            style: t.titleMedium?.copyWith(color: FmColors.primary),
                          ),
                        );
                      }),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text('Retos cumplidos en total: ${summary.completed}', style: t.bodySmall?.copyWith(color: FmColors.muted)),
            ],
          ),
        );
      },
    );
  }
}

class ChallengeTile extends StatelessWidget {
  const ChallengeTile({super.key, required this.status, this.compact = false});
  final ChallengeStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final k = status.kind;
    final bar = ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: LinearProgressIndicator(
        value: status.progress / k.target,
        minHeight: compact ? 6 : 8,
        backgroundColor: FmColors.line,
        color: status.done ? const Color(0xFF3FBF9F) : FmColors.primary,
      ),
    );
    if (compact) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Text(k.emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Expanded(child: bar),
            const SizedBox(width: 8),
            SizedBox(
              width: 34,
              child: Text(status.done ? '✓' : '${status.progress}/${k.target}', textAlign: TextAlign.right, style: t.labelMedium),
            ),
          ],
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: status.done ? const Color(0x333FBF9F) : FmColors.lavender,
                shape: BoxShape.circle,
              ),
              child: Text(status.done ? '✅' : k.emoji, style: const TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(k.title, style: t.titleSmall),
                  const SizedBox(height: 6),
                  bar,
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text('${status.progress}/${k.target}', style: t.titleMedium?.copyWith(color: FmColors.primary)),
          ],
        ),
      ),
    );
  }
}
