import '../../../shared/widgets/body_figure.dart';
import 'package:flutter/material.dart';

import '../../../app_scope.dart';
import '../../../core/models/exercise.dart';
import '../../../core/theme/app_theme.dart';
import 'exercise_detail_screen.dart';
import 'exercise_form_screen.dart';

/// Biblioteca de ejercicios. En [pickMode] devuelve el ejercicio elegido.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key, this.pickMode = false});
  final bool pickMode;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  String _query = '';
  MuscleGroup? _muscle;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return ListenableBuilder(
      listenable: scope.library,
      builder: (context, _) {
        final all = scope.library.all;
        final muscles = {for (final e in all) e.primaryMuscle}.toList()..sort((a, b) => a.index.compareTo(b.index));
        final q = _query.toLowerCase();
        final items = all
            .where((e) => _muscle == null || e.primaryMuscle == _muscle || e.secondaryMuscles.contains(_muscle))
            .where((e) => q.isEmpty || e.name.toLowerCase().contains(q))
            .toList();

        return Scaffold(
          appBar: AppBar(title: Text(widget.pickMode ? 'Elige un ejercicio' : 'Biblioteca de ejercicios')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () async {
              final created = await Navigator.push<Exercise>(
                context,
                MaterialPageRoute(builder: (_) => const ExerciseFormScreen()),
              );
              if (created != null && widget.pickMode && context.mounted) Navigator.pop(context, created);
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text('Nuevo'),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded),
                    hintText: 'Buscar ejercicio',
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    ChoiceChip(label: const Text('Todos'), selected: _muscle == null, onSelected: (_) => setState(() => _muscle = null)),
                    for (final m in muscles)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: ChoiceChip(
                          label: Text(m.label),
                          selected: _muscle == m,
                          onSelected: (_) => setState(() => _muscle = _muscle == m ? null : m),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final e = items[i];
                    return Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 72,
                            height: 52,
                            color: FmColors.line,
                            child: e.media.src != null
                                ? (e.media.kind == MediaKind.figure
                                    ? FigureThumb(src: e.media.endSrc ?? e.media.src!)
                                    : Image.asset(e.media.src!, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox()))
                                : const Icon(Icons.fitness_center_rounded, color: FmColors.lilac),
                          ),
                        ),
                        title: Text(e.name),
                        subtitle: Text(
                          '${e.primaryMuscle.label} · ${e.suggestedTarget.label}${e.custom ? ' · propio' : ''}',
                        ),
                        trailing: Icon(widget.pickMode ? Icons.add_circle_outline_rounded : Icons.chevron_right_rounded,
                            color: FmColors.primary),
                        onTap: () {
                          if (widget.pickMode) {
                            Navigator.pop(context, e);
                          } else {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => ExerciseDetailScreen(exerciseId: e.id)));
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
