// Für Tests und spätere Apps: Google Street View und MapillaryJS laufen hier nur im Browser.
import 'package:material_ui/material_ui.dart';

import '../../../domain/models/models.dart';
import '../../../l10n/l10n.dart';
import 'street_view_controller.dart';

class StreetView extends StatelessWidget {
  const StreetView({super.key, required this.source, required this.start, this.focus, this.controller});

  final StreetViewSource source;
  final ({double lat, double lng}) start;
  final GeoBingoSpot? focus;
  final StreetViewController? controller;

  @override
  Widget build(BuildContext context) => Center(child: Text(texts.streetViewBrowserOnly, textAlign: TextAlign.center));
}
