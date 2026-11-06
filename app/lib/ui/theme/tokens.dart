// Токены «Системы G» (docs/design-g.md, утверждена 05.11): цвета, шрифты, скругления, движение.
// Тёмная тема — основная. Шрифты Onest и JetBrains Mono пока не вшиты в сборку — до тех пор берутся
// системные Segoe UI и Consolas/Cascadia Mono (из сети шрифты не грузим).
import 'package:flutter/material.dart';

abstract final class SpColors {
  static const ground = Color(0xFF191A1E); // холст под нодами, с точками
  static const bg = Color(0xFF1C1D21); // шапка, поля ввода
  static const node = Color(0xFF25262B); // нода, меню, окно
  static const nodeHover = Color(0xFF2C2D33); // строка под курсором, серая плашка
  static const line = Color(0xFF3A3B42);
  static const lineSoft = Color(0xFF303137);
  static const lineStrong = Color(0xFF6E7079);
  static const ink = Color(0xFFE2E3E8);
  static const ink2 = Color(0xFFC9CAD0); // строки второго уровня в дереве
  static const body = Color(0xFFD4D5DA); // текст заметки
  static const muted = Color(0xFF9A9CA6);
  static const dim = Color(0xFF7A7C86);
  static const accent = Color(0xFFF0A04B);
  static const accentInk = Color(0xFFFFD29C);
  static const accentWash = Color(0xFF2E2722);
  static const accentLine = Color(0xFF6A5238);
  static const onAccent = Color(0xFF2A1A0A);

  static const blue = Color(0xFF6FA2F2);
  static const violet = Color(0xFFB48CF0);
  static const green = Color(0xFF7FD18C);
  static const gold = Color(0xFFE8C65A);
  static const grey = Color(0xFFA3A5AE);
  static const red = Color(0xFFF0785F);

  /// Цветные шапки нод (тёмный оттенок цвета сферы), главная нода — [headMain].
  static const headOrange = Color(0xFF8A5320);
  static const headBlue = Color(0xFF2F4F86);
  static const headViolet = Color(0xFF5E3F92);
  static const headGreen = Color(0xFF2E6B3E);
  static const headGold = Color(0xFF7A6620);
  static const headGrey = Color(0xFF3D3E45);
  static const headRed = Color(0xFF8A3A2E);
  static const headMain = Color(0xFF9A5A22);

  /// Цвета папок «Знаний» по порядку (как сферы).
  static const hues = [grey, accent, violet, blue, green, gold, red];

  /// Тёмные шапки тех же цветов, по тому же порядку, что [hues].
  static const heads = [headGrey, headOrange, headViolet, headBlue, headGreen, headGold, headRed];

  /// Точки холста: 1 px через 24 px, белый 7 %.
  static const dot = Color(0x12FFFFFF);
}

abstract final class SpType {
  static const sans = 'Onest';
  static const sansFallback = ['Segoe UI', 'Roboto', 'sans-serif'];
  static const mono = 'JetBrains Mono';
  static const monoFallback = ['Cascadia Mono', 'Consolas', 'monospace'];

  static TextStyle text(double size, {FontWeight w = FontWeight.w400, Color color = SpColors.ink, double? height}) =>
      TextStyle(
        fontFamily: sans,
        fontFamilyFallback: sansFallback,
        fontSize: size,
        fontWeight: w,
        color: color,
        height: height == null ? null : height / size,
      );

  /// Служебное: шапки нод ЗАГЛАВНЫМИ с разрядкой, счётчики, время.
  static TextStyle label(
    double size, {
    FontWeight w = FontWeight.w400,
    Color color = SpColors.muted,
    double spacing = .12,
  }) => TextStyle(
    fontFamily: mono,
    fontFamilyFallback: monoFallback,
    fontSize: size,
    fontWeight: w,
    color: color,
    letterSpacing: size * spacing,
  );
}

abstract final class SpRadius {
  static const node = 8.0;
  static const hub = 12.0;
  static const button = 6.0;
  static const socket = 3.0;
}

abstract final class SpMotion {
  static const fast = Duration(milliseconds: 120);
  static const base = Duration(milliseconds: 200);
  static const slow = Duration(milliseconds: 320);
  static const ease = Curves.easeOutCubic;
}

ThemeData spTheme() => ThemeData(
  brightness: Brightness.dark,
  useMaterial3: true,
  scaffoldBackgroundColor: SpColors.bg,
  fontFamily: SpType.sans,
  fontFamilyFallback: SpType.sansFallback,
  colorScheme: const ColorScheme.dark(
    primary: SpColors.accent,
    onPrimary: SpColors.onAccent,
    surface: SpColors.node,
    onSurface: SpColors.ink,
    outline: SpColors.line,
    error: SpColors.red,
  ),
  textSelectionTheme: const TextSelectionThemeData(cursorColor: SpColors.accent, selectionColor: Color(0x556A5238)),
  tooltipTheme: const TooltipThemeData(
    decoration: BoxDecoration(color: SpColors.node, borderRadius: BorderRadius.all(Radius.circular(SpRadius.button))),
    textStyle: TextStyle(color: SpColors.ink, fontSize: 12),
  ),
);

/// Холст с точками (фон под нодами).
class DotGround extends StatelessWidget {
  const DotGround({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _Dots(), child: child);
}

class _Dots extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = SpColors.ground);
    final p = Paint()..color = SpColors.dot;
    for (var y = 12.0; y < size.height; y += 24) {
      for (var x = 12.0; x < size.width; x += 24) {
        canvas.drawRect(Rect.fromLTWH(x, y, 1, 1), p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
