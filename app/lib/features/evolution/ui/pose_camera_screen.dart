import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app_scope.dart';
import '../../../core/models/body.dart';
import '../../../core/theme/app_theme.dart';
import 'pose_guide.dart';

/// Abre la cámara con la silueta guía. Devuelve la foto (JPEG) o null si se canceló.
Future<Uint8List?> takeGuidedPhoto(BuildContext context, PhotoAngle angle, {Uint8List? previous}) =>
    Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => PoseCameraScreen(angle: angle, previous: previous)),
    );

enum _Overlay { silueta, anterior }

class PoseCameraScreen extends StatefulWidget {
  const PoseCameraScreen({super.key, required this.angle, this.previous});
  final PhotoAngle angle;

  /// Última foto de este ángulo, para encajar en la misma postura.
  final Uint8List? previous;

  @override
  State<PoseCameraScreen> createState() => _PoseCameraScreenState();
}

class _PoseCameraScreenState extends State<PoseCameraScreen> with WidgetsBindingObserver {
  List<CameraDescription> _cams = const [];
  CameraController? _ctrl;
  int _camIndex = 0;
  String? _error;
  _Overlay _overlay = _Overlay.silueta;
  double _ghost = 0.4;
  int _timer = 5;
  int? _countdown;
  bool _busy = false;
  Uint8List? _shot;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setPreferredOrientations([]);
    _tick?.cancel();
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _ctrl;
    if (c == null || !c.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _ctrl = null;
      c.dispose();
      if (mounted) setState(() {});
    } else if (state == AppLifecycleState.resumed) {
      _open(_camIndex);
    }
  }

  Future<void> _init() async {
    try {
      _cams = await availableCameras();
      if (_cams.isEmpty) {
        setState(() => _error = 'No se encontró ninguna cámara.');
        return;
      }
      // Empieza con la trasera (mejor calidad); se puede cambiar a la frontal.
      final back = _cams.indexWhere((c) => c.lensDirection == CameraLensDirection.back);
      await _open(back < 0 ? 0 : back);
    } on CameraException catch (e) {
      setState(() => _error = _message(e));
    }
  }

  String _message(CameraException e) => switch (e.code) {
        'CameraAccessDenied' || 'CameraAccessDeniedWithoutPrompt' || 'CameraAccessRestricted' =>
          'FitMakyp necesita permiso de cámara para la foto guiada. Puedes darlo en Ajustes del teléfono o usar la cámara normal.',
        _ => 'No se pudo abrir la cámara (${e.description ?? e.code}).',
      };

  Future<void> _open(int index) async {
    final old = _ctrl;
    _ctrl = null;
    if (mounted) setState(() {});
    await old?.dispose();
    final c = CameraController(_cams[index], ResolutionPreset.high, enableAudio: false, imageFormatGroup: ImageFormatGroup.jpeg);
    try {
      await c.initialize();
      await c.lockCaptureOrientation(DeviceOrientation.portraitUp);
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() {
        _ctrl = c;
        _camIndex = index;
        _error = null;
      });
    } on CameraException catch (e) {
      await c.dispose();
      if (mounted) setState(() => _error = _message(e));
    }
  }

  bool get _front => _cams.isNotEmpty && _cams[_camIndex].lensDirection == CameraLensDirection.front;

  void _switch() {
    if (_cams.length < 2) return;
    final want = _front ? CameraLensDirection.back : CameraLensDirection.front;
    final i = _cams.indexWhere((c) => c.lensDirection == want);
    _open(i < 0 ? (_camIndex + 1) % _cams.length : i);
  }

  void _shoot() {
    if (_busy || _countdown != null) return;
    if (_timer == 0) {
      _capture();
      return;
    }
    final workout = AppScope.of(context).workout;
    setState(() => _countdown = _timer);
    workout.say('Foto en $_timer segundos.');
    _tick = Timer.periodic(const Duration(seconds: 1), (t) {
      final left = (_countdown ?? 1) - 1;
      if (left <= 0) {
        t.cancel();
        setState(() => _countdown = null);
        _capture();
        return;
      }
      HapticFeedback.selectionClick();
      if (left <= 3) workout.say('$left');
      setState(() => _countdown = left);
    });
  }

  Future<void> _capture() async {
    final c = _ctrl;
    if (c == null || !c.value.isInitialized || c.value.isTakingPicture) return;
    setState(() => _busy = true);
    try {
      final file = await c.takePicture();
      final bytes = await file.readAsBytes();
      HapticFeedback.mediumImpact();
      if (mounted) setState(() => _shot = bytes);
    } on CameraException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo tomar la foto: ${e.description ?? e.code}')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Map<Measure, double> _measures() {
    final body = AppScope.of(context).body;
    return {
      for (final m in Measure.values) m: ?body.latestValue(m),
    };
  }

  @override
  Widget build(BuildContext context) {
    final body = AppScope.of(context).body;
    return Theme(
      data: Theme.of(context).copyWith(scaffoldBackgroundColor: Colors.black),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: _shot != null ? _review(body.heightCm ?? 165) : _camera(body.heightCm ?? 165),
        ),
      ),
    );
  }

  Widget _topBar(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Cerrar',
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            Expanded(
              child: Text(title,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      );

  /// Alto/ancho de la foto en vertical: el de la cámara (así la guía coincide con la foto guardada).
  double get _ratio {
    final c = _ctrl;
    if (c == null || !c.value.isInitialized) return _lastRatio;
    return _lastRatio = c.value.aspectRatio;
  }

  double _lastRatio = 4 / 3;

  /// Rectángulo vertical donde se muestran la cámara y la guía, con la misma forma que la foto guardada.
  Widget _frame({required Widget child}) => LayoutBuilder(
        builder: (context, box) {
          final r = _ratio;
          var w = box.maxWidth;
          var h = w * r;
          if (h > box.maxHeight) {
            h = box.maxHeight;
            w = h / r;
          }
          return Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(width: w, height: h, child: child),
            ),
          );
        },
      );

  Widget _camera(double heightCm) {
    final c = _ctrl;
    return Column(
      children: [
        _topBar('Foto ${widget.angle.label.toLowerCase()}'),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(poseTip(widget.angle), style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ),
        Expanded(
          child: _error != null
              ? _errorView()
              : _frame(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (c == null || !c.value.isInitialized)
                        const ColoredBox(color: Color(0xFF1E1729), child: Center(child: CircularProgressIndicator()))
                      else
                        CameraPreview(c),
                      if (_overlay == _Overlay.anterior && widget.previous != null)
                        Opacity(
                          opacity: _ghost,
                          child: Transform.flip(
                            flipX: _front,
                            child: Image.memory(widget.previous!, fit: BoxFit.cover, gaplessPlayback: true),
                          ),
                        ),
                      CustomPaint(
                        painter: PoseGuidePainter(
                          angle: widget.angle,
                          measures: _measures(),
                          heightCm: heightCm,
                          mirror: _front,
                          showLines: true,
                        ),
                      ),
                      if (_countdown != null)
                        Center(
                          child: Text('$_countdown',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 120,
                                fontWeight: FontWeight.w900,
                                shadows: [Shadow(blurRadius: 16, color: Colors.black54)],
                              )),
                        ),
                    ],
                  ),
                ),
        ),
        if (widget.previous != null) _overlayChooser(),
        _controls(),
      ],
    );
  }

  Widget _overlayChooser() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: Column(
          children: [
            SegmentedButton<_Overlay>(
              style: SegmentedButton.styleFrom(
                foregroundColor: Colors.white,
                selectedForegroundColor: FmColors.deep,
                selectedBackgroundColor: const Color(0xFFDCCBFA),
                side: const BorderSide(color: Colors.white38),
              ),
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: _Overlay.silueta, label: Text('Solo silueta')),
                ButtonSegment(value: _Overlay.anterior, label: Text('+ Foto anterior')),
              ],
              selected: {_overlay},
              onSelectionChanged: (v) => setState(() => _overlay = v.first),
            ),
            if (_overlay == _Overlay.anterior)
              Row(
                children: [
                  const Icon(Icons.opacity_rounded, color: Colors.white70, size: 18),
                  Expanded(
                    child: Slider(
                      value: _ghost,
                      min: 0.15,
                      max: 0.7,
                      onChanged: (v) => setState(() => _ghost = v),
                    ),
                  ),
                ],
              ),
          ],
        ),
      );

  Widget _controls() => Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _RoundButton(
              icon: Icons.timer_outlined,
              label: _timer == 0 ? 'Sin temporizador' : '${_timer}s',
              onTap: () => setState(() => _timer = switch (_timer) { 0 => 5, 5 => 10, _ => 0 }),
            ),
            GestureDetector(
              onTap: _error == null ? _shoot : null,
              child: Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4)),
                padding: const EdgeInsets.all(5),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _countdown != null || _busy ? const Color(0xFFDCCBFA) : Colors.white,
                  ),
                ),
              ),
            ),
            _RoundButton(
              icon: Icons.flip_camera_android_rounded,
              label: _front ? 'Frontal' : 'Trasera',
              onTap: _cams.length > 1 && _countdown == null ? _switch : null,
            ),
          ],
        ),
      );

  Widget _errorView() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.no_photography_outlined, color: Colors.white70, size: 56),
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Volver')),
            ],
          ),
        ),
      );

  Widget _review(double heightCm) => Column(
        children: [
          _topBar('¿Te gusta cómo quedó?'),
          Expanded(
            child: _frame(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(_shot!, fit: BoxFit.cover),
                  CustomPaint(
                    painter: PoseGuidePainter(
                      angle: widget.angle,
                      measures: _measures(),
                      heightCm: heightCm,
                      showLines: false,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54)),
                    onPressed: () => setState(() => _shot = null),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Repetir'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(context, _shot),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Usar foto'),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 90,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton.filledTonal(
              onPressed: onTap,
              style: IconButton.styleFrom(backgroundColor: Colors.white24, foregroundColor: Colors.white),
              icon: Icon(icon),
            ),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11), textAlign: TextAlign.center),
          ],
        ),
      );
}
