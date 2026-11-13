import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/utils/format.dart';
import '../workout/domain/strength.dart';
import '../sleep/domain/sleep_estimate.dart';
import 'report_data.dart';

const _primary = PdfColor.fromInt(0xFF7041B8);
const _deep = PdfColor.fromInt(0xFF2B1B43);
const _lavender = PdfColor.fromInt(0xFFF1EAFD);
const _muted = PdfColor.fromInt(0xFF7B7290);
const _line = PdfColor.fromInt(0xFFE4DAF3);

String _n(double v, [int d = 1]) =>
    v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(d).replaceAll('.', ',');
String _date(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
String _phase(String? s) => switch (s) {
      'done' || 'alreadyDone' => 'Sí',
      'skipped' => 'No',
      _ => '-',
    };

/// Foto incluida en el reporte (solo si la usuaria lo elige).
class ReportPhoto {
  const ReportPhoto(this.label, this.bytes);
  final String label;
  final Uint8List bytes;
}

/// [rest]: noches estimadas por el uso del teléfono; [mornings]: rutinas matutinas del periodo.
Future<Uint8List> renderReportPdf(
  ReportData d, {
  List<ReportPhoto> photos = const [],
  RestSummary? rest,
  int mornings = 0,
}) async {
  final doc = pw.Document(title: 'Reporte FitMakyp', author: 'FitMakyp');

  pw.Widget section(String title) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 16, bottom: 6),
        child: pw.Text(title, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: _deep)),
      );

  pw.Widget stat(String value, String label) => pw.Expanded(
        child: pw.Container(
          margin: const pw.EdgeInsets.only(right: 6),
          padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: pw.BoxDecoration(color: _lavender, borderRadius: pw.BorderRadius.circular(8)),
          child: pw.Column(children: [
            pw.Text(value, style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: _primary)),
            pw.SizedBox(height: 2),
            pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: _muted), textAlign: pw.TextAlign.center),
          ]),
        ),
      );

  pw.Widget table(List<String> headers, List<List<String>> rows, {Map<int, pw.TableColumnWidth>? widths}) =>
      pw.TableHelper.fromTextArray(
        headers: headers,
        data: rows,
        columnWidths: widths,
        headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
        headerDecoration: const pw.BoxDecoration(color: _primary),
        cellStyle: const pw.TextStyle(fontSize: 9, color: _deep),
        cellAlignments: {for (var i = 1; i < headers.length; i++) i: pw.Alignment.center},
        oddRowDecoration: const pw.BoxDecoration(color: _lavender),
        border: const pw.TableBorder(horizontalInside: pw.BorderSide(color: _line, width: 0.5)),
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      );

  pw.Widget empty(String text) =>
      pw.Text(text, style: const pw.TextStyle(fontSize: 9, color: _muted));

  final adherence = d.adherencePct;
  final sortedMuscles = d.muscleSets.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(36, 32, 36, 36),
      footer: (ctx) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Generado con FitMakyp. Valores orientativos, no es un diagnóstico médico.',
              style: const pw.TextStyle(fontSize: 7, color: _muted)),
          pw.Text('${ctx.pageNumber} / ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 7, color: _muted)),
        ],
      ),
      build: (ctx) => [
        pw.Container(
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            gradient: const pw.LinearGradient(colors: [_deep, _primary]),
            borderRadius: pw.BorderRadius.circular(12),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('REPORTE DE PROGRESO', style: const pw.TextStyle(fontSize: 9, color: PdfColors.white, letterSpacing: 1.5)),
                    pw.SizedBox(height: 4),
                    pw.Text(d.name, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                    pw.SizedBox(height: 2),
                    pw.Text('${d.period.label}: ${_date(d.from)} - ${_date(d.to)}',
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.white)),
                  ],
                ),
              ),
              pw.Text('FitMakyp', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
            ],
          ),
        ),
        section('Resumen'),
        pw.Row(children: [
          stat('${d.workouts.length}', 'entrenamientos'),
          stat(adherence == null ? '-' : '$adherence %', 'constancia\n(${d.trainedDays} de ${d.plannedDays} días)'),
          stat('${d.totalSets}', 'series'),
          stat(formatDurationShort(Duration(minutes: d.totalMinutes)), 'tiempo total'),
          stat('${d.currentStreak} / ${d.bestStreak}', 'racha actual / mejor'),
        ]),
        pw.SizedBox(height: 6),
        pw.Text(
          'Calentamiento en ${d.warmups} de ${d.workouts.length} entrenamientos · Estiramientos en ${d.cooldowns} de ${d.workouts.length}.',
          style: const pw.TextStyle(fontSize: 9, color: _deep),
        ),
        section('Entrenamientos'),
        if (d.workouts.isEmpty)
          empty('Sin entrenamientos en este periodo.')
        else
          table(
            ['Fecha', 'Día', 'Series', 'Min', 'Calent.', 'Estir.'],
            [
              for (final w in d.workouts)
                [_date(w.date), w.title, '${w.sets}/${w.planned}', '${w.minutes}', _phase(w.warmup), _phase(w.cooldown)],
            ],
            widths: const {0: pw.FixedColumnWidth(62), 1: pw.FlexColumnWidth(3)},
          ),
        section('Series por músculo'),
        if (sortedMuscles.isEmpty)
          empty('Sin datos.')
        else
          table(
            ['Músculo', 'Series', 'Series / semana'],
            [
              for (final e in sortedMuscles) [e.key.label, _n(e.value), _n(e.value / d.weeks)],
            ],
          ),
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 3),
          child: pw.Text('Series completadas: 1 para el músculo principal y 0,5 para los secundarios.',
              style: const pw.TextStyle(fontSize: 7, color: _muted)),
        ),
        section('Fuerza'),
        if (d.strength.isEmpty)
          empty('No se anotó peso en este periodo.')
        else
          table(
            ['Ejercicio', 'Peso máx.', 'Periodo anterior', '1RM estimado', 'Sesiones'],
            [
              for (final s in d.strength)
                [
                  s.name,
                  formatKg(s.best),
                  s.previous == null
                      ? '-'
                      : '${formatKg(s.previous!)} (${s.best >= s.previous! ? '+' : ''}${_n(s.best - s.previous!)})',
                  s.e1rm == null ? '-' : formatKg((s.e1rm! * 2).round() / 2),
                  '${s.sessions}',
                ],
            ],
            widths: const {0: pw.FlexColumnWidth(3)},
          ),
        section('Medidas'),
        if (d.measures.isEmpty)
          empty('Sin registros de medidas.')
        else
          table(
            ['Medida', 'Inicio', 'Actual', 'Cambio'],
            [
              for (final m in d.measures)
                [
                  m.measure.label,
                  '${_n(m.start)} ${m.measure.unit} (${_date(m.startDate)})',
                  '${_n(m.end)} ${m.measure.unit}',
                  '${m.change > 0 ? '+' : ''}${_n(m.change)} ${m.measure.unit}',
                ],
            ],
            widths: const {0: pw.FlexColumnWidth(2), 1: pw.FlexColumnWidth(3)},
          ),
        section('Bienestar'),
        if (d.checkins == 0)
          empty('Sin registros diarios de ánimo y energía.')
        else
          pw.Text(
            'Promedio de ${d.checkins} ${d.checkins == 1 ? 'registro diario' : 'registros diarios'} (escala 1 a 5): ánimo ${_n(d.moodAvg!)}, energía ${_n(d.energyAvg!)}, sueño ${_n(d.sleepAvg!)}.',
            style: const pw.TextStyle(fontSize: 9, color: _deep),
          ),
        if (rest != null && !rest.isEmpty) ...[
          pw.SizedBox(height: 4),
          pw.Text(
            'Descanso estimado (${rest.nights.length} ${rest.nights.length == 1 ? 'noche' : 'noches'} con datos): '
            '${formatHm(rest.average)} sin usar el teléfono de media; primera activación hacia las '
            '${formatClockMinutes(rest.averageWake!)}, último uso hacia las ${formatClockMinutes(rest.averageLastUse!)}.',
            style: const pw.TextStyle(fontSize: 9, color: _deep),
          ),
        ],
        if (mornings > 0) ...[
          pw.SizedBox(height: 4),
          pw.Text(
            'Rutina matutina de hipopresivos: $mornings ${mornings == 1 ? 'mañana' : 'mañanas'} en el periodo.',
            style: const pw.TextStyle(fontSize: 9, color: _deep),
          ),
        ],
        if (d.notes.trim().isNotEmpty) ...[
          section('Notas para el entrenador'),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: _line), borderRadius: pw.BorderRadius.circular(8)),
            child: pw.Text(d.notes.trim(), style: const pw.TextStyle(fontSize: 10, color: _deep)),
          ),
        ],
        if (photos.isNotEmpty) ...[
          section('Fotos de progreso'),
          pw.Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in photos)
                pw.Column(children: [
                  pw.ClipRRect(
                    horizontalRadius: 6,
                    verticalRadius: 6,
                    child: pw.Image(pw.MemoryImage(p.bytes), width: 150, height: 200, fit: pw.BoxFit.cover),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(p.label, style: const pw.TextStyle(fontSize: 8, color: _muted)),
                ]),
            ],
          ),
        ],
      ],
    ),
  );
  return doc.save();
}
