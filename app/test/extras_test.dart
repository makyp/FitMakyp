import 'dart:io';

import 'package:fitmakyp/core/data/seed_exercises.dart';
import 'package:fitmakyp/core/models/body.dart';
import 'package:fitmakyp/core/models/exercise.dart';
import 'package:fitmakyp/core/models/plan.dart';
import 'package:fitmakyp/core/models/session.dart';
import 'package:fitmakyp/core/models/settings.dart';
import 'package:fitmakyp/core/sound/voice_coach.dart';
import 'package:fitmakyp/features/goals/domain/achievements.dart';
import 'package:fitmakyp/features/goals/domain/rewards.dart';
import 'package:fitmakyp/features/report/report_data.dart';
import 'package:fitmakyp/features/report/report_pdf.dart';
import 'package:fitmakyp/features/workout/domain/workout_machine.dart';
import 'package:flutter_test/flutter_test.dart';

final _squat = seedExercises.firstWhere((e) => e.primaryMuscle == MuscleGroup.cuadriceps);

WorkoutSession _done(String id, DateTime at, List<(int, double?)> sets, {String? warmup, String? cooldown}) =>
    WorkoutSession(
      id: id,
      planId: 'p',
      dayId: 'd',
      dayTitle: 'Lunes · Piernas',
      status: SessionStatus.completed,
      startedAt: at,
      finishedAt: at.add(const Duration(minutes: 45)),
      warmup: warmup,
      cooldown: cooldown,
      exercises: [
        SessionExercise(
          workoutExerciseId: 'w',
          exerciseId: _squat.id,
          name: _squat.name,
          plannedSets: sets.length,
          target: const SetTarget.reps(10, max: 12),
          restSeconds: 60,
          sets: [
            for (final (i, (r, w)) in sets.indexed)
              ExerciseSetLog(setNumber: i + 1, result: SetResult.completed, repsDone: r, weightKg: w, finishedAt: at),
          ],
        ),
      ],
    );

void main() {
  group('voz', () {
    test('duraciones habladas', () {
      expect(spokenDuration(60), '1 minuto');
      expect(spokenDuration(90), '1 minuto y 30 segundos');
      expect(spokenDuration(45), '45 segundos');
    });

    test('avisos en cada cambio del entrenamiento', () {
      final day = WorkoutDay(
        id: 'd',
        weekday: 1,
        kind: DayKind.training,
        title: 'Piernas',
        exercises: [
          WorkoutExercise(id: 'a', exerciseId: _squat.id, sets: 2, target: const SetTarget.reps(10), restSeconds: 60),
          WorkoutExercise(id: 'b', exerciseId: 'plancha_frontal', sets: 1, target: const SetTarget.seconds(30), restSeconds: 45),
        ],
      );
      final now = DateTime(2026, 11, 10, 18);
      var s = createSession(
        id: 's',
        planId: 'p',
        day: day,
        exerciseName: (id) => id == _squat.id ? 'Sentadilla' : 'Plancha',
        defaultRestSeconds: 60,
        now: now,
      );
      String? step(WorkoutEvent e) {
        final next = reduce(s, e, now);
        final cue = voiceCue(s, next);
        s = next;
        return cue;
      }

      expect(step(const StartWorkout()), 'Empezamos. Sentadilla. Serie 1 de 2.');
      expect(step(const CompleteSet()), '¡Bien! Descansa 1 minuto.');
      expect(step(const FinishRest()), contains('Última serie de Sentadilla'));
      expect(step(const CompleteSet()), '¡Bien! Descansa 1 minuto. Después: Plancha.');
      expect(step(const FinishRest()), 'Plancha. Serie 1 de 1.');
      expect(step(const CompleteSet()), contains('completado'));
    });

    test('ajustes de tema y voz se guardan', () {
      final s = AppSettings.fromJson(const AppSettings(themeMode: 'oscuro', voiceEnabled: false).toJson());
      expect(s.themeMode, 'oscuro');
      expect(s.voiceEnabled, isFalse);
      expect(AppSettings.fromJson(const {}).themeMode, 'sistema');
    });
  });

  group('insignias', () {
    RewardsInput input(List<WorkoutSession> sessions, {int best = 0, Set<DateTime> water = const {}}) => RewardsInput(
          sessions: sessions,
          records: const [],
          checkins: const [],
          goals: const [],
          currentStreak: 0,
          bestStreak: best,
          now: DateTime(2026, 11, 10),
          waterGoalDays: water,
        );

    test('sin nada, ninguna conseguida', () {
      expect(evaluateAchievements(input(const [])).where((a) => a.unlocked), isEmpty);
    });

    test('se desbloquean y suman puntos', () {
      final sessions = [
        _done('1', DateTime(2026, 11, 2, 7), [(10, 20), (10, 20)], warmup: 'done'),
        _done('2', DateTime(2026, 11, 5, 22), [(12, 22.5), (12, 22.5)], cooldown: 'skipped'),
      ];
      final st = {for (final a in evaluateAchievements(input(sessions, best: 3))) a.achievement.id: a};
      expect(st['entreno_1']!.unlocked, isTrue);
      expect(st['madrugadora']!.unlocked, isTrue);
      expect(st['nocturna']!.unlocked, isTrue);
      expect(st['record_1']!.unlocked, isTrue, reason: 'subió de 20 a 22,5 kg');
      expect(st['racha_3']!.unlocked, isTrue);
      expect(st['entreno_10']!.current, 2);
      expect(st['calienta_10']!.current, 1);
      expect(st['estira_10']!.current, 0, reason: 'omitido no cuenta');
      final pts = earnedPoints(input(sessions, best: 3));
      expect(pts.any((p) => p.reason == 'Insignia: Primer paso'), isTrue);
      expect(pts.where((p) => p.reason.contains('Arrancando')), isEmpty, reason: 'las de racha no suman doble');
    });
  });

  group('reporte', () {
    final now = DateTime(2026, 11, 10, 20);
    final sessions = [
      _done('a', DateTime(2026, 9, 20, 18), [(10, 15)]),
      _done('b', DateTime(2026, 10, 20, 18), [(10, 20), (10, 20)], warmup: 'done', cooldown: 'alreadyDone'),
      _done('c', DateTime(2026, 11, 3, 18), [(12, 22.5), (10, 22.5)], warmup: 'skipped'),
    ];
    final records = [
      ProgressRecord(id: 'r1', date: DateTime(2026, 10, 1), values: const {Measure.peso: 64, Measure.cintura: 72}),
      ProgressRecord(id: 'r2', date: DateTime(2026, 11, 1), values: const {Measure.peso: 63.2, Measure.cintura: 70.5}),
    ];
    ReportData data() => buildReportData(
          name: 'Makyp',
          period: ReportPeriod.mes,
          now: now,
          sessions: sessions,
          exerciseById: (id) => seedExercises.where((e) => e.id == id).firstOrNull,
          trainingWeekdays: const {1, 3, 5},
          records: records,
          checkins: [DailyCheckin(date: DateTime(2026, 11, 2), mood: 4, energy: 5, sleep: 3)],
          currentStreak: 2,
          bestStreak: 5,
          notes: 'Me molestó la rodilla',
        );

    test('datos del último mes', () {
      final d = data();
      expect(d.workouts.map((w) => w.date.day), [20, 3], reason: 'el de septiembre queda fuera');
      expect(d.totalSets, 4);
      expect(d.warmups, 1);
      expect(d.cooldowns, 1);
      expect(d.plannedDays, inInclusiveRange(12, 14));
      expect(d.adherencePct, isNotNull);
      final sq = d.strength.single;
      expect(sq.best, 22.5);
      expect(sq.previous, 15, reason: 'periodo anterior de igual duración');
      expect(d.muscleSets[MuscleGroup.cuadriceps], 4);
      final peso = d.measures.firstWhere((m) => m.measure == Measure.peso);
      expect(peso.start, 64);
      expect(peso.end, 63.2);
      expect(d.moodAvg, 4);
    });

    test('la constancia cuenta desde el primer entrenamiento', () {
      final d = buildReportData(
        name: 'Makyp',
        period: ReportPeriod.mes,
        now: now,
        sessions: [_done('n', DateTime(2026, 11, 9, 18), [(10, null)])], // lunes 9
        exerciseById: (id) => null,
        trainingWeekdays: const {1, 3, 5},
        records: const [],
        checkins: const [],
        currentStreak: 1,
        bestStreak: 1,
      );
      expect(d.plannedDays, 1, reason: 'solo el lunes 9 (el 10 es martes)');
      expect(d.adherencePct, 100);
    });

    test('genera un PDF válido', () async {
      final bytes = await renderReportPdf(data());
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      expect(bytes.length, greaterThan(2000));
      final out = Platform.environment['FM_PDF_OUT'];
      if (out != null) File(out).writeAsBytesSync(bytes);
    });
  });
}
