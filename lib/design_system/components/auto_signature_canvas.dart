import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_radius.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';

/// Controller for [AutoSignatureCanvas] to track stroke paths,
/// query emptiness, clear strokes, and export transparent PNG bytes.
class AutoSignatureController extends ChangeNotifier {
  final List<List<Offset>> _strokes = [];
  Size? _canvasSize;

  List<List<Offset>> get strokes => List.unmodifiable(_strokes);

  bool get isEmpty =>
      _strokes.isEmpty || _strokes.every((stroke) => stroke.isEmpty);

  bool get isNotEmpty => !isEmpty;

  int get strokeCount => _strokes.where((s) => s.isNotEmpty).length;

  void updateCanvasSize(Size size) {
    _canvasSize = size;
  }

  void startStroke(Offset point) {
    _strokes.add([point]);
    notifyListeners();
  }

  void addPoint(Offset point) {
    if (_strokes.isEmpty) {
      _strokes.add([point]);
    } else {
      // Avoid duplicate consecutive points
      if (_strokes.last.isNotEmpty &&
          (_strokes.last.last - point).distanceSquared < 1.0) {
        return;
      }
      _strokes.last.add(point);
    }
    notifyListeners();
  }

  void endStroke() {
    notifyListeners();
  }

  void clear() {
    _strokes.clear();
    notifyListeners();
  }

  /// Exports the drawn strokes to transparent PNG bytes.
  /// Defaults to dark navy/black ink suitable for embedding on white PDFs.
  Future<Uint8List?> toPngBytes({
    double width = 600,
    double height = 240,
    Color penColor = const Color(0xFF0F172A),
    double strokeWidth = 3.5,
  }) async {
    if (isEmpty) return null;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, width, height),
    );

    // Calculate scale factor relative to the rendered canvas size
    final double srcW = _canvasSize?.width ?? width;
    final double srcH = _canvasSize?.height ?? height;
    final double scaleX = srcW > 0 ? width / srcW : 1.0;
    final double scaleY = srcH > 0 ? height / srcH : 1.0;

    canvas.scale(scaleX, scaleY);

    final paint = Paint()
      ..color = penColor
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    for (final stroke in _strokes) {
      if (stroke.isEmpty) continue;
      if (stroke.length == 1) {
        canvas.drawCircle(
          stroke.first,
          strokeWidth / 2,
          paint..style = PaintingStyle.fill,
        );
        paint.style = PaintingStyle.stroke;
      } else {
        final path = Path();
        path.moveTo(stroke.first.dx, stroke.first.dy);
        for (int i = 1; i < stroke.length - 1; i++) {
          final p0 = stroke[i];
          final p1 = stroke[i + 1];
          final mid = Offset((p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
          path.quadraticBezierTo(p0.dx, p0.dy, mid.dx, mid.dy);
        }
        path.lineTo(stroke.last.dx, stroke.last.dy);
        canvas.drawPath(path, paint);
      }
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }
}

/// An interactive, high-contrast signature pad component.
/// Provides smooth Bézier strokes, touch/mouse/stylus input, and a clear button.
class AutoSignatureCanvas extends StatefulWidget {
  final AutoSignatureController controller;
  final double height;
  final Color backgroundColor;
  final Color penColor;
  final double strokeWidth;
  final String? placeholderText;
  final VoidCallback? onSigned;
  final VoidCallback? onCleared;

  const AutoSignatureCanvas({
    super.key,
    required this.controller,
    this.height = 180,
    this.backgroundColor = const Color(0xFFFFFFFF),
    this.penColor = const Color(0xFF0F172A),
    this.strokeWidth = 3.0,
    this.placeholderText = 'Sign above with finger or stylus',
    this.onSigned,
    this.onCleared,
  });

  @override
  State<AutoSignatureCanvas> createState() => _AutoSignatureCanvasState();
}

class _AutoSignatureCanvasState extends State<AutoSignatureCanvas> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChange);
  }

  @override
  void didUpdateWidget(covariant AutoSignatureCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChange);
      widget.controller.addListener(_handleControllerChange);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChange);
    super.dispose();
  }

  void _handleControllerChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        widget.controller.updateCanvasSize(
          Size(constraints.maxWidth, widget.height),
        );

        return Container(
          decoration: BoxDecoration(
            color: widget.backgroundColor,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: widget.controller.isNotEmpty
                  ? AppColors.primary
                  : AppColors.borderSubtle,
              width: widget.controller.isNotEmpty ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            height: widget.height,
            width: constraints.maxWidth,
            child: Stack(
              children: [
                // Signature Guideline & Hint
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 38,
                  child: IgnorePointer(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Text(
                              '✕',
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                height: 1,
                                color: Colors.grey.shade300,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.placeholderText ?? 'Sign above',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),

                // Interactive Drawing Canvas with immediate exclusive gesture capture
                RawGestureDetector(
                  behavior: HitTestBehavior.opaque,
                  gestures: <Type, GestureRecognizerFactory>{
                    _ImmediateSignatureGestureRecognizer:
                        GestureRecognizerFactoryWithHandlers<_ImmediateSignatureGestureRecognizer>(
                      () => _ImmediateSignatureGestureRecognizer(),
                      (_ImmediateSignatureGestureRecognizer instance) {
                        instance
                          ..onStart = (point) {
                            final clamped = Offset(
                              point.dx.clamp(0.0, constraints.maxWidth),
                              point.dy.clamp(0.0, widget.height),
                            );
                            widget.controller.startStroke(clamped);
                            widget.onSigned?.call();
                          }
                          ..onUpdate = (point) {
                            final clamped = Offset(
                              point.dx.clamp(0.0, constraints.maxWidth),
                              point.dy.clamp(0.0, widget.height),
                            );
                            widget.controller.addPoint(clamped);
                          }
                          ..onEnd = () {
                            widget.controller.endStroke();
                          };
                      },
                    ),
                  },
                  child: CustomPaint(
                    size: Size(constraints.maxWidth, widget.height),
                    painter: _SignaturePainter(
                      strokes: widget.controller.strokes,
                      penColor: widget.penColor,
                      strokeWidth: widget.strokeWidth,
                    ),
                  ),
                ),

                // Clear Button (Top Right)
                if (widget.controller.isNotEmpty)
                  Positioned(
                    top: AppSpacing.xs,
                    right: AppSpacing.xs,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          widget.controller.clear();
                          widget.onCleared?.call();
                        },
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.refresh_rounded,
                                size: 14,
                                color: Colors.grey.shade700,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Clear',
                                style: AppTypography.caption.copyWith(
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final Color penColor;
  final double strokeWidth;

  const _SignaturePainter({
    required this.strokes,
    required this.penColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = penColor
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    for (final stroke in strokes) {
      if (stroke.isEmpty) continue;
      if (stroke.length == 1) {
        canvas.drawCircle(
          stroke.first,
          strokeWidth / 2,
          paint..style = PaintingStyle.fill,
        );
        paint.style = PaintingStyle.stroke;
      } else {
        final path = Path();
        path.moveTo(stroke.first.dx, stroke.first.dy);
        for (int i = 1; i < stroke.length - 1; i++) {
          final p0 = stroke[i];
          final p1 = stroke[i + 1];
          final mid = Offset((p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
          path.quadraticBezierTo(p0.dx, p0.dy, mid.dx, mid.dy);
        }
        path.lineTo(stroke.last.dx, stroke.last.dy);
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) {
    return true;
  }
}

/// Custom gesture recognizer that claims the arena immediately on pointer down,
/// preventing parent scroll views from intercepting vertical drag gestures while drawing.
class _ImmediateSignatureGestureRecognizer extends OneSequenceGestureRecognizer {
  ValueChanged<Offset>? onStart;
  ValueChanged<Offset>? onUpdate;
  VoidCallback? onEnd;

  _ImmediateSignatureGestureRecognizer()
      : super(debugOwner: '_ImmediateSignatureGestureRecognizer');

  @override
  void addAllowedPointer(PointerDownEvent event) {
    startTrackingPointer(event.pointer, event.transform);
    resolve(GestureDisposition.accepted);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerDownEvent) {
      onStart?.call(event.localPosition);
    } else if (event is PointerMoveEvent) {
      onUpdate?.call(event.localPosition);
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      onEnd?.call();
      stopTrackingPointer(event.pointer);
    }
  }

  @override
  String get debugDescription => 'immediate_signature_gesture_recognizer';

  @override
  void didStopTrackingLastPointer(int pointer) {}
}
