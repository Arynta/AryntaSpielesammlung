// Außerhalb des Browsers liegt kein HTML unter Flutter, es gibt nichts abzufangen.
import 'package:material_ui/material_ui.dart';

class PointerShield extends StatelessWidget {
  const PointerShield({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
