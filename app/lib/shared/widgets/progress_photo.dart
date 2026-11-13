import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/theme/app_theme.dart';

/// Muestra una foto de progreso guardada en el dispositivo.
class ProgressPhoto extends StatefulWidget {
  const ProgressPhoto({super.key, required this.photoId, this.fit = BoxFit.cover});
  final String photoId;
  final BoxFit fit;

  @override
  State<ProgressPhoto> createState() => _ProgressPhotoState();
}

class _ProgressPhotoState extends State<ProgressPhoto> {
  Future<Uint8List?>? _bytes;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bytes ??= AppScope.of(context).body.photos.load(widget.photoId);
  }

  @override
  void didUpdateWidget(ProgressPhoto old) {
    super.didUpdateWidget(old);
    if (old.photoId != widget.photoId) _bytes = AppScope.of(context).body.photos.load(widget.photoId);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
        future: _bytes,
        builder: (context, snap) {
          final b = snap.data;
          if (b == null) {
            return ColoredBox(
              color: FmColors.line,
              child: Center(
                child: snap.connectionState == ConnectionState.done
                    ? const Icon(Icons.broken_image_outlined, color: FmColors.lilac)
                    : const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            );
          }
          return Image.memory(b, fit: widget.fit, gaplessPlayback: true, width: double.infinity, height: double.infinity);
        },
      );
}
