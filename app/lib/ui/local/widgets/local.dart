// Ansichten für den lokalen Modus: ein Handy, das reihum weitergegeben wird.
import 'package:material_ui/material_ui.dart';

import '../view_model/local_controller.dart';
import 'local_setup.dart';
import 'local_cards.dart';
import 'local_tabu.dart';
import 'local_nobody_is_perfect.dart';

export 'local_setup.dart';
export 'local_cards.dart';
export 'local_tabu.dart';
export 'local_nobody_is_perfect.dart';

List<Widget> localView(BuildContext context, LocalController local) => switch (local.stage) {
  Stage.setup => localSetupView(context, local),
  Stage.pass => localPassView(local),
  Stage.card => localCardView(local),
  Stage.table => local.impostor != null ? localImpostorTable(local) : localWerwolfTable(local),
  Stage.reveal => localImpostorReveal(local),
  Stage.tabuReady => localTabuReady(local, local.match!),
  Stage.tabuTurn => localTabuTurn(local, local.match!),
  Stage.tabuOver => localTabuOver(local, local.match!),
  Stage.fibPass => localFibPass(local, local.fib!),
  Stage.fibWrite => localFibWrite(local, local.fib!),
  Stage.fibGuess => localFibGuess(local, local.fib!),
  Stage.fibReveal || Stage.fibOver => localFibReveal(local, local.fib!),
};
