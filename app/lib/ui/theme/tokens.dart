// Токены «Системы G» (docs/design-g.md, утверждена 05.11): цвета, шрифты, скругления, движение.
// Тёмная тема — основная. Шрифты Onest и JetBrains Mono пока не вшиты в сборку — до тех пор берутся
// системные Segoe UI и Consolas/Cascadia Mono (из сети шрифты не грузим).
import 'package:flutter/material.dart';

/// Цвета темы. Не `const`: тема (тёмная/светлая) и акцент меняются в Настройки → Вид — [SpColors.apply].
abstract final class SpColors {
  static bool light = false;
  static Color ground = const Color(0xFF191A1E); // холст под нодами, с точками
  static Color bg = const Color(0xFF1C1D21); // шапка, поля ввода
  static Color node = const Color(0xFF25262B); // нода, меню, окно
  static Color nodeHover = const Color(0xFF2C2D33); // строка под курсором, серая плашка
  static Color line = const Color(0xFF3A3B42);
  static Color lineSoft = const Color(0xFF303137);
  static Color lineStrong = const Color(0xFF6E7079);
  static Color ink = const Color(0xFFE2E3E8);
  static Color ink2 = const Color(0xFFC9CAD0); // строки второго уровня в дереве
  static Color body = const Color(0xFFD4D5DA); // текст заметки
  static Color muted = const Color(0xFF9A9CA6);
  static Color dim = const Color(0xFF7A7C86);
  static Color accent = const Color(0xFFF0A04B);
  static Color accentInk = const Color(0xFFFFD29C);
  static Color accentWash = const Color(0xFF2E2722);
  static Color accentLine = const Color(0xFF6A5238);
  static Color onAccent = const Color(0xFF2A1A0A);

  static Color blue = const Color(0xFF6FA2F2);
  static Color violet = const Color(0xFFB48CF0);
  static Color green = const Color(0xFF7FD18C);
  static Color gold = const Color(0xFFE8C65A);
  static Color grey = const Color(0xFFA3A5AE);
  static Color red = const Color(0xFFF0785F);

  /// Цветные шапки нод (тёмный оттенок цвета сферы), главная нода — [headMain].
  static Color headOrange = const Color(0xFF8A5320);
  static Color headBlue = const Color(0xFF2F4F86);
  static Color headViolet = const Color(0xFF5E3F92);
  static Color headGreen = const Color(0xFF2E6B3E);
  static Color headGold = const Color(0xFF7A6620);
  static Color headGrey = const Color(0xFF3D3E45);
  static Color headRed = const Color(0xFF8A3A2E);
  static Color headMain = const Color(0xFF9A5A22);

  /// Цвета папок «Знаний» по порядку (как сферы).
  static List<Color> get hues => [grey, accent, violet, blue, green, gold, red];

  /// Тёмные шапки тех же цветов, по тому же порядку, что [hues].
  static List<Color> get heads => [headGrey, headOrange, headViolet, headBlue, headGreen, headGold, headRed];

  /// Точки холста: 1 px через 24 px.
  static Color dot = const Color(0x12FFFFFF);

  /// Наборы акцента: id → (цвет, шапка главной ноды).
  static const accents = <String, (String, Color, Color)>{
    'orange': ('Янтарь', Color(0xFFF0A04B), Color(0xFF9A5A22)),
    'clay': ('Глина', Color(0xFFD9774F), Color(0xFF8A4228)),
    'gold': ('Золото', Color(0xFFE0B24A), Color(0xFF7A6020)),
    'green': ('Мята', Color(0xFF6FCF97), Color(0xFF2E6B48)),
    'blue': ('Небо', Color(0xFF6FA2F2), Color(0xFF2F4F86)),
    'violet': ('Сирень', Color(0xFFB48CF0), Color(0xFF5E3F92)),
    'rose': ('Роза', Color(0xFFEC7FA9), Color(0xFF8A3A5E)),
  };

  /// Применить тему (`dark` | `light`) и акцент (id из [accents]). После вызова приложение перестраивается.
  static void apply({String theme = 'dark', String accentId = 'orange'}) {
    light = theme == 'light';
    final a = accents[accentId] ?? accents['orange']!;
    if (!light) {
      ground = const Color(0xFF191A1E);
      bg = const Color(0xFF1C1D21);
      node = const Color(0xFF25262B);
      nodeHover = const Color(0xFF2C2D33);
      line = const Color(0xFF3A3B42);
      lineSoft = const Color(0xFF303137);
      lineStrong = const Color(0xFF6E7079);
      ink = const Color(0xFFE2E3E8);
      ink2 = const Color(0xFFC9CAD0);
      body = const Color(0xFFD4D5DA);
      muted = const Color(0xFF9A9CA6);
      dim = const Color(0xFF7A7C86);
      dot = const Color(0x12FFFFFF);
      blue = const Color(0xFF6FA2F2);
      violet = const Color(0xFFB48CF0);
      green = const Color(0xFF7FD18C);
      gold = const Color(0xFFE8C65A);
      grey = const Color(0xFFA3A5AE);
      red = const Color(0xFFF0785F);
      headGrey = const Color(0xFF3D3E45);
    } else {
      ground = const Color(0xFFEDEBE6);
      bg = const Color(0xFFF6F5F2);
      node = const Color(0xFFFFFFFF);
      nodeHover = const Color(0xFFF1EFEB);
      line = const Color(0xFFDCD9D2);
      lineSoft = const Color(0xFFE7E4DE);
      lineStrong = const Color(0xFFA9A6A0);
      ink = const Color(0xFF1E1F24);
      ink2 = const Color(0xFF34353B);
      body = const Color(0xFF2A2B30);
      muted = const Color(0xFF6B6D76);
      dim = const Color(0xFF8D8F98);
      dot = const Color(0x1A000000);
      blue = const Color(0xFF2F6BD0);
      violet = const Color(0xFF7A4FC8);
      green = const Color(0xFF2E8A4A);
      gold = const Color(0xFFA07A10);
      grey = const Color(0xFF6E7079);
      red = const Color(0xFFC8442C);
      headGrey = const Color(0xFF55565E);
    }
    final hsl = HSLColor.fromColor(a.$2);
    accent = light ? hsl.withLightness((hsl.lightness - .14).clamp(.3, .6)).toColor() : a.$2;
    headMain = a.$3;
    accentInk = light ? hsl.withLightness(.32).toColor() : hsl.withLightness(.8).toColor();
    accentWash = light ? hsl.withLightness(.94).withSaturation(.5).toColor() : Color.alphaBlend(a.$2.withValues(alpha: .1), bg);
    accentLine = light ? hsl.withLightness(.7).toColor() : Color.alphaBlend(a.$2.withValues(alpha: .4), bg);
    onAccent = light ? const Color(0xFFFFFFFF) : hsl.withLightness(.1).toColor();
  }
}

abstract final class SpType {
  static const sans = 'Onest';
  static const sansFallback = ['JetBrains Mono', 'Segoe UI', 'Segoe UI Symbol', 'Roboto', 'sans-serif'];
  static const mono = 'JetBrains Mono';
  static const monoFallback = ['Cascadia Mono', 'Consolas', 'monospace'];

  static TextStyle text(double size, {FontWeight w = FontWeight.w400, Color? color, double? height}) =>
      TextStyle(
        fontFamily: sans,
        fontFamilyFallback: sansFallback,
        fontSize: size,
        fontWeight: w,
        color: color ?? SpColors.ink,
        height: height == null ? null : height / size,
      );

  /// Служебное: шапки нод ЗАГЛАВНЫМИ с разрядкой, счётчики, время.
  static TextStyle label(
    double size, {
    FontWeight w = FontWeight.w400,
    Color? color,
    double spacing = .12,
  }) => TextStyle(
    fontFamily: mono,
    fontFamilyFallback: monoFallback,
    fontSize: size,
    fontWeight: w,
    color: color ?? SpColors.muted,
    letterSpacing: size * spacing,
  );
}

abstract final class SpRadius {
  static const node = 8.0;
  static const hub = 12.0;
  static const button = 6.0;
  static const socket = 3.0;
}

/// Движение (G_Motion): двигаются только сдвиг, масштаб и прозрачность; уход быстрее появления.
/// [mode] ставит оболочка из настройки «Анимации»: full | min | off; системное «уменьшить движение» = min.
abstract final class SpMotion {
  static const fast = Duration(milliseconds: 120);
  static const base = Duration(milliseconds: 200);
  static const slow = Duration(milliseconds: 320);
  static const ease = Curves.easeOutCubic;

  static const dur1 = Duration(milliseconds: 120);
  static const dur2 = Duration(milliseconds: 180);
  static const dur3 = Duration(milliseconds: 260);
  static const dur4 = Duration(milliseconds: 420);
  static const easeOut = Cubic(.2, .8, .2, 1);
  static const easeIn = Cubic(.4, 0, 1, 1);
  static const easePop = Cubic(.3, 1.4, .5, 1);

  static String mode = 'full';

  /// Текущий уровень с учётом системного «уменьшить движение».
  static String level(BuildContext c) {
    if (mode == 'off') return 'off';
    if (mode == 'min' || (MediaQuery.maybeDisableAnimationsOf(c) ?? false)) return 'min';
    return 'full';
  }

  /// Длительность для уровня: min — затухание не дольше 120 мс, off — ноль.
  static Duration d(BuildContext c, Duration full) => switch (level(c)) {
    'off' => Duration.zero,
    'min' => full < dur1 ? full : dur1,
    _ => full,
  };

  /// Можно ли сдвигать и масштабировать (только при «полных»).
  static bool moves(BuildContext c) => level(c) == 'full';
}

ThemeData spTheme() => ThemeData(
  brightness: SpColors.light ? Brightness.light : Brightness.dark,
  useMaterial3: true,
  scaffoldBackgroundColor: SpColors.bg,
  fontFamily: SpType.sans,
  fontFamilyFallback: SpType.sansFallback,
  colorScheme: (SpColors.light ? ColorScheme.light : ColorScheme.dark)(
    primary: SpColors.accent,
    onPrimary: SpColors.onAccent,
    surface: SpColors.node,
    onSurface: SpColors.ink,
    outline: SpColors.line,
    error: SpColors.red,
  ),
  textSelectionTheme: TextSelectionThemeData(cursorColor: SpColors.accent, selectionColor: SpColors.accentLine.withValues(alpha: .5)),
  tooltipTheme: TooltipThemeData(
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
