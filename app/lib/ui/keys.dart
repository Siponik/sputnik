// Горячие клавиши по физической клавише (как e.code в старом трекере): работают в любой раскладке.
// Один глобальный обработчик в AppShell; экраны регистрируют свои клавиши через [PageKeys].
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Сочетание по физической клавише. Модификаторы сверяются точно.
class PKey extends ShortcutActivator {
  const PKey(this.key, {this.ctrl = false, this.shift = false, this.alt = false});
  final PhysicalKeyboardKey key;
  final bool ctrl, shift, alt;

  bool matches(KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return false;
    if (e.physicalKey != key) return false;
    final k = HardwareKeyboard.instance;
    return (k.isControlPressed || k.isMetaPressed) == ctrl && k.isShiftPressed == shift && k.isAltPressed == alt;
  }

  @override
  bool accepts(KeyEvent event, HardwareKeyboard state) => matches(event);

  @override
  Iterable<LogicalKeyboardKey>? get triggers => null;

  @override
  String debugDescribeKeys() => '${ctrl ? 'Ctrl+' : ''}${alt ? 'Alt+' : ''}${shift ? 'Shift+' : ''}${key.debugName}';
}

/// Курсор стоит в поле ввода — одиночные буквы и цифры не перехватываем.
bool typing() {
  final ctx = FocusManager.instance.primaryFocus?.context;
  if (ctx == null) return false;
  if (ctx.widget is EditableText) return true;
  return ctx.findAncestorWidgetOfExactType<EditableText>() != null;
}

const digits = [
  PhysicalKeyboardKey.digit1,
  PhysicalKeyboardKey.digit2,
  PhysicalKeyboardKey.digit3,
  PhysicalKeyboardKey.digit4,
  PhysicalKeyboardKey.digit5,
  PhysicalKeyboardKey.digit6,
  PhysicalKeyboardKey.digit7,
  PhysicalKeyboardKey.digit8,
  PhysicalKeyboardKey.digit9,
];

/// Клавиши открытого экрана: экран кладёт сюда свою карту, AppShell вызывает её из глобального обработчика.
class PageKeys {
  static final Map<Object, Map<PKey, VoidCallback>> _by = {};
  static Object? active;

  static void set(Object owner, Map<PKey, VoidCallback> keys) {
    _by[owner] = keys;
    active = owner;
  }

  static void clear(Object owner) {
    _by.remove(owner);
    if (active == owner) active = null;
  }

  /// true — клавиша обработана.
  static bool handle(KeyEvent e) {
    final m = _by[active];
    if (m == null) return false;
    for (final MapEntry(:key, :value) in m.entries) {
      if (key.matches(e)) {
        if (!key.ctrl && !key.alt && typing()) return false;
        value();
        return true;
      }
    }
    return false;
  }
}
