// Für Tests und spätere Apps: MapillaryJS läuft nur im Browser.
import 'package:material_ui/material_ui.dart';

import '../../../domain/models/models.dart';
import 'street_view_controller.dart';

class StreetView extends StatelessWidget {
  const StreetView({super.key, this.start, this.spot, this.controller});

  final ({double lat, double lng})? start;
  final GeoBingoSpot? spot;
  final StreetViewController? controller;

  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('Straßenbilder gibt es nur im Browser.', textAlign: TextAlign.center));
}
