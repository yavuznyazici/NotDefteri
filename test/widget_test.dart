import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:dijital_not_defteri/widgets/drawing_canvas.dart';

void main() {
  test('stroke JSON round-trip preserves points and tool style', () {
    final original = InkStroke(points: const [Offset(1, 2), Offset(3, 4)],
      color: const Color(0xFF123456), width: 4.5, tool: DrawingTool.highlighter);
    final restored = InkStroke.fromJson(original.toJson());
    expect(restored.points, original.points);
    expect(restored.color.toARGB32(), original.color.toARGB32());
    expect(restored.width, 4.5);
    expect(restored.tool, DrawingTool.highlighter);
  });
}
