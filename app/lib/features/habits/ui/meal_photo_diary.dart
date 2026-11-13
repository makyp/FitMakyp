import 'package:flutter/material.dart';

import '../../../app_scope.dart';
import '../../../core/models/habits.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../shared/widgets/progress_photo.dart';
import 'meal_sheet.dart';

/// Todas las fotos de tus platos, por día.
class MealPhotoDiary extends StatelessWidget {
  const MealPhotoDiary({super.key});

  @override
  Widget build(BuildContext context) {
    final h = AppScope.of(context).habits;
    return ListenableBuilder(
      listenable: h,
      builder: (context, _) {
        final t = Theme.of(context).textTheme;
        final byDay = <DateTime, List<MealEntry>>{};
        for (final m in h.recentWithPhotos) {
          byDay.putIfAbsent(dateOnly(m.at), () => []).add(m);
        }
        final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
        return Scaffold(
          appBar: AppBar(title: const Text('Diario de fotos')),
          body: days.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('📸', style: TextStyle(fontSize: 56)),
                        const SizedBox(height: 10),
                        Text('Aún no hay fotos de platos', style: t.titleLarge),
                        const SizedBox(height: 6),
                        Text(
                          'Al añadir una comida toca "Foto del plato". Ver tus platos juntos ayuda a notar patrones sin contar nada.',
                          textAlign: TextAlign.center,
                          style: t.bodyMedium?.copyWith(color: FmColors.muted),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  children: [
                    for (final d in days) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
                        child: Text(formatLongDate(d), style: t.titleSmall),
                      ),
                      GridView.count(
                        crossAxisCount: 3,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 6,
                        crossAxisSpacing: 6,
                        children: [
                          for (final m in byDay[d]!)
                            GestureDetector(
                              onTap: () => showMealSheet(context, day: d, existing: m),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    ProgressPhoto(photoId: m.photoId!),
                                    Positioned(
                                      left: 0,
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        padding: const EdgeInsets.fromLTRB(6, 10, 6, 4),
                                        decoration: const BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [Color(0x00000000), Color(0xAA000000)],
                                          ),
                                        ),
                                        child: Text(
                                          '${m.type.emoji} ${m.portions?.short ?? m.description}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
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
