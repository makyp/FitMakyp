import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'body_figure.dart';

/// Miniatura de ejercicio con su número de orden.
class ExerciseThumb extends StatelessWidget {
  const ExerciseThumb({super.key, required this.src, required this.number});
  final String? src;
  final int? number;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 64,
    height: 48,
    child: Stack(
      children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ColoredBox(
              color: FmColors.line,
              child: src == null
                  ? const SizedBox()
                  : src!.startsWith('figure:')
                  ? FigureThumb(src: src!)
                  : Image.asset(
                      src!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox(),
                    ),
            ),
          ),
        ),
        if (number != null)
          Positioned(
            left: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: FmColors.primary,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomRight: Radius.circular(8),
                ),
              ),
              child: Text(
                '$number',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
