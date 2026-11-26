// Die Farben hängen an der Spielphase: Dämmerung (Start/Lobby), Nacht, Tag.
import 'package:material_ui/material_ui.dart';

import '../logic/models.dart';

const bodyFont = 'Atkinson Hyperlegible';
const bodyFallback = ['Atkinson Hyperlegible Ext'];
const displayFont = 'Grenze';
const displayFallback = ['Grenze Ext'];

/// Schrift für Überschriften und alles Große.
TextStyle display(double size, {double height = 1, Color? color, double? letterSpacing}) => TextStyle(
  fontFamily: displayFont,
  fontFamilyFallback: displayFallback,
  fontWeight: FontWeight.w800,
  fontSize: size,
  height: height,
  color: color,
  letterSpacing: letterSpacing,
);

const teamColors = [Color(0xFFE0614F), Color(0xFF4F8FE0), Color(0xFF4FB86D), Color(0xFFE3C24A)];
const dangerColor = Color(0xFFB3261E);
const dangerBorder = Color(0xFFD3463D);

class Palette extends ThemeExtension<Palette> {
  const Palette({
    required this.brightness,
    required this.bg,
    required this.surface,
    required this.line,
    required this.text,
    required this.muted,
    required this.accent,
    required this.onAccent,
    required this.wolfNote,
    required this.neutralNote,
    required this.villageNote,
  });

  static const dusk = Palette(
    brightness: Brightness.dark,
    bg: Color(0xFF2F2747),
    surface: Color(0xFF3C3359),
    line: Color(0xFF57497C),
    text: Color(0xFFF1ECF8),
    muted: Color(0xFFBCB1D3),
    accent: Color(0xFFF0B45C),
    onAccent: Color(0xFF2A1D07),
    wolfNote: Color(0xFFFF9A8A),
    neutralNote: Color(0xFFC9B8FF),
    villageNote: Color(0xFF9FD8A2),
  );

  static const night = Palette(
    brightness: Brightness.dark,
    bg: Color(0xFF1D1F3D),
    surface: Color(0xFF2A2D55),
    line: Color(0xFF3F4378),
    text: Color(0xFFE8EAF6),
    muted: Color(0xFFA3A8CF),
    accent: Color(0xFFF1DC93),
    onAccent: Color(0xFF1D1F3D),
    wolfNote: Color(0xFFFF9A8A),
    neutralNote: Color(0xFFC9B8FF),
    villageNote: Color(0xFF9FD8A2),
  );

  static const day = Palette(
    brightness: Brightness.light,
    bg: Color(0xFFDCE9F1),
    surface: Color(0xFFFFFFFF),
    line: Color(0xFFB4C7D4),
    text: Color(0xFF1F2A3A),
    muted: Color(0xFF4C5C70),
    accent: Color(0xFF9A4F0E),
    onAccent: Color(0xFFFFFFFF),
    wolfNote: Color(0xFFA12A1C),
    neutralNote: Color(0xFF4A3D8C),
    villageNote: Color(0xFF2F6332),
  );

  final Brightness brightness;
  final Color bg;
  final Color surface;
  final Color line;
  final Color text;
  final Color muted;
  final Color accent;
  final Color onAccent;
  final Color wolfNote;
  final Color neutralNote;
  final Color villageNote;

  @override
  Palette copyWith() => this;

  @override
  Palette lerp(Palette? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return Palette(
      brightness: t < 0.5 ? brightness : other.brightness,
      bg: mix(bg, other.bg),
      surface: mix(surface, other.surface),
      line: mix(line, other.line),
      text: mix(text, other.text),
      muted: mix(muted, other.muted),
      accent: mix(accent, other.accent),
      onAccent: mix(onAccent, other.onAccent),
      wolfNote: mix(wolfNote, other.wolfNote),
      neutralNote: mix(neutralNote, other.neutralNote),
      villageNote: mix(villageNote, other.villageNote),
    );
  }
}

extension PaletteContext on BuildContext {
  Palette get palette => Theme.of(this).extension<Palette>()!;

  /// Null, wenn das Gerät um weniger Bewegung bittet.
  Duration motion(int milliseconds) =>
      MediaQuery.disableAnimationsOf(this) ? Duration.zero : Duration(milliseconds: milliseconds);
}

ThemeData _theme(Palette p) {
  final body = TextStyle(
    fontFamily: bodyFont,
    fontFamilyFallback: bodyFallback,
    fontSize: 17,
    height: 1.5,
    color: p.text,
    letterSpacing: 0,
  );
  return ThemeData(
    brightness: p.brightness,
    fontFamily: bodyFont,
    fontFamilyFallback: bodyFallback,
    scaffoldBackgroundColor: p.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: p.accent,
      brightness: p.brightness,
    ).copyWith(primary: p.accent, onPrimary: p.onAccent, surface: p.surface, onSurface: p.text),
    textTheme: TextTheme(bodyLarge: body, bodyMedium: body),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: p.accent,
      selectionColor: p.accent.withValues(alpha: 0.35),
      selectionHandleColor: p.accent,
    ),
    extensions: [p],
  );
}

final duskTheme = _theme(Palette.dusk);
final nightTheme = _theme(Palette.night);
final dayTheme = _theme(Palette.day);

ThemeData themeFor(Phase? phase) => switch (phase) {
  Phase.night => nightTheme,
  Phase.day => dayTheme,
  _ => duskTheme,
};
