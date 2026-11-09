import 'package:flutter/material.dart';

enum DrawingTool { pen, highlighter, eraser }

class InkStroke {
  InkStroke({required this.points, required this.color, required this.width,
    required this.tool});
  final List<Offset> points;
  final Color color;
  final double width;
  final DrawingTool tool;

  Map<String, Object?> toJson() => {
    'points': points.map((p) => [p.dx, p.dy]).toList(),
    'color': color.toARGB32(), 'width': width, 'tool': tool.name,
  };
  factory InkStroke.fromJson(Map<String, dynamic> json) => InkStroke(
    points: (json['points'] as List).map((p) =>
      Offset((p[0] as num).toDouble(), (p[1] as num).toDouble())).toList(),
    color: Color((json['color'] as num).toInt()),
    width: (json['width'] as num).toDouble(),
    tool: DrawingTool.values.firstWhere((e) => e.name == json['tool'],
      orElse: () => DrawingTool.pen));
}

class DrawingCanvas extends StatelessWidget {
  const DrawingCanvas({super.key, required this.strokes, required this.onStart,
    required this.onMove, required this.onEnd, required this.tool,
    required this.color, required this.width});
  final List<InkStroke> strokes;
  final ValueChanged<Offset> onStart;
  final ValueChanged<Offset> onMove;
  final VoidCallback onEnd;
  final DrawingTool tool;
  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onPanStart: (d) => onStart(d.localPosition),
    onPanUpdate: (d) => onMove(d.localPosition),
    onPanEnd: (_) => onEnd(),
    child: RepaintBoundary(child: CustomPaint(
      painter: _StrokePainter(strokes), size: Size.infinite)),
  );
}

class _StrokePainter extends CustomPainter {
  _StrokePainter(this.strokes);
  final List<InkStroke> strokes;
  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      if (stroke.points.isEmpty) continue;
      final erasing = stroke.tool == DrawingTool.eraser;
      final paint = Paint()
        ..color = erasing ? Colors.white : stroke.color
        ..strokeWidth = erasing ? stroke.width * 3 : stroke.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..isAntiAlias = true
        ..blendMode = BlendMode.srcOver;
      if (stroke.tool == DrawingTool.highlighter) {
        paint.color = stroke.color.withValues(alpha: 0.28);
        paint.strokeWidth = stroke.width * 3;
      }
      if (stroke.points.length == 1) {
        canvas.drawCircle(stroke.points.first, paint.strokeWidth / 2, paint..style = PaintingStyle.fill);
      } else {
        final path = Path()..moveTo(stroke.points.first.dx, stroke.points.first.dy);
        for (final point in stroke.points.skip(1)) {
          path.lineTo(point.dx, point.dy);
        }
        canvas.drawPath(path, paint);
      }
    }
  }
  @override
  bool shouldRepaint(covariant _StrokePainter old) => old.strokes != strokes;
}
