// Flaggen selbst gezeichnet: Die Seite lädt keine Bilder von Dritten, und Flaggen-Emoji fehlen in der Schrift.
import 'package:material_ui/material_ui.dart';

import '../../../../domain/models/models.dart';

/// Deutschland-Flagge für Deutsch, Union Jack für Englisch.
class FlagPainter extends CustomPainter {
  const FlagPainter(this.language);

  final Language language;

  @override
  void paint(Canvas canvas, Size size) => switch (language) {
    Language.de => _germany(canvas, size),
    Language.en => _unionJack(canvas, size),
  };

  void _germany(Canvas canvas, Size size) {
    const stripes = [Color(0xFF000000), Color(0xFFDD0000), Color(0xFFFFCE00)];
    final height = size.height / stripes.length;
    for (final (i, color) in stripes.indexed) {
      canvas.drawRect(Rect.fromLTWH(0, i * height, size.width, height), Paint()..color = color);
    }
  }

  /// Gezeichnet auf 60 × 30 Einheiten wie die amtliche Vorlage, dann auf [size] gestreckt.
  void _unionJack(Canvas canvas, Size size) {
    const blue = Color(0xFF012169);
    const red = Color(0xFFC8102E);
    canvas.save();
    canvas.scale(size.width / 60, size.height / 30);
    canvas.drawRect(const Rect.fromLTWH(0, 0, 60, 30), Paint()..color = blue);

    final diagonals = Path()
      ..moveTo(0, 0)
      ..lineTo(60, 30)
      ..moveTo(60, 0)
      ..lineTo(0, 30);
    canvas.drawPath(diagonals, _stroke(Colors.white, 6));
    // Die roten Schrägstreifen liegen versetzt, deshalb nur in je einem Dreieck pro Ecke
    canvas.save();
    canvas.clipPath(
      Path()
        ..moveTo(30, 15)
        ..lineTo(60, 15)
        ..lineTo(60, 30)
        ..close()
        ..moveTo(30, 15)
        ..lineTo(30, 30)
        ..lineTo(0, 30)
        ..close()
        ..moveTo(30, 15)
        ..lineTo(0, 15)
        ..lineTo(0, 0)
        ..close()
        ..moveTo(30, 15)
        ..lineTo(30, 0)
        ..lineTo(60, 0)
        ..close(),
    );
    canvas.drawPath(diagonals, _stroke(red, 4));
    canvas.restore();

    final cross = Path()
      ..moveTo(30, 0)
      ..lineTo(30, 30)
      ..moveTo(0, 15)
      ..lineTo(60, 15);
    canvas.drawPath(cross, _stroke(Colors.white, 10));
    canvas.drawPath(cross, _stroke(red, 6));
    canvas.restore();
  }

  static Paint _stroke(Color color, double width) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width;

  @override
  bool shouldRepaint(FlagPainter oldDelegate) => oldDelegate.language != language;
}
