// Flutter malt Bedienelemente nur über das Straßenbild. Den Klick bekommt im Browser trotzdem das
// HTML-Element darunter, und Google läuft dorthin. Ein leeres HTML-Element unter dem Bedienelement
// fängt den Klick ab, Flutter bekommt ihn weiterhin.
import 'package:material_ui/material_ui.dart';

class PointerShield extends StatelessWidget {
  const PointerShield({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned.fill(child: HtmlElementView.fromTagName(tagName: 'div', isVisible: false)),
      child,
    ],
  );
}
