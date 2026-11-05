// «Когда» словами → день и время. Порт tracker/src/lib/when.js (результаты должны совпадать с ним,
// это проверяют золотые тесты test/golden/when.json).
//   parseWhen('завтра 15:00', today)    → day '2026-10-21', time '15:00', rest ''
//   parseWhen('скетч в пятницу 17.30')  → day <ближайшая пятница>, time '17:30', rest 'скетч'

import 'dates.dart';

class WhenResult {
  const WhenResult({this.day, this.time, this.allDay = false, this.rest = ''});

  /// 'ГГГГ-ММ-ДД' или null.
  final String? day;

  /// 'ЧЧ:ММ' или null.
  final String? time;
  final bool allDay;

  /// Нераспознанная часть текста.
  final String rest;
}

final _week = <RegExp>[
  RegExp(r'^(?:в|во)?\s*(понедельник|пн)$'),
  RegExp(r'^(?:в|во)?\s*(вторник|вт)$'),
  RegExp(r'^(?:в|во)?\s*(сред[ау]|ср)$'),
  RegExp(r'^(?:в|во)?\s*(четверг|чт)$'),
  RegExp(r'^(?:в|во)?\s*(пятниц[ау]|пт)$'),
  RegExp(r'^(?:в|во)?\s*(суббот[ау]|сб)$'),
  RegExp(r'^(?:в|во)?\s*(воскресенье|вс)$'),
];
final _weekWord = RegExp(
  r'(?:^|\s)(?:(?:в|во)\s+)?(понедельник|вторник|сред[ау]|четверг|пятниц[ау]|суббот[ау]|воскресенье|пн|вт|ср|чт|пт|сб|вс)(?=\s|$|[,.!?])',
  caseSensitive: false,
);
const _months = ['янв', 'фев', 'мар', 'апр', 'ма', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];

DateTime _addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);
int _dowMon(DateTime d) => d.weekday - 1; // пн = 0

String _hhmm(String h, String m) => '${h.padLeft(2, '0')}:$m';

/// Разбирает фразу. [today] — «сегодня» (по умолчанию сейчас).
WhenResult parseWhen(String? text, [DateTime? today]) {
  var t = ' ${(text ?? '').replaceAll(RegExp(r'\s+'), ' ')} ';
  final base = _addDays(today ?? DateTime.now(), 0);
  DateTime? day;
  String? time;
  var allDay = false;

  bool take(RegExp re, void Function(RegExpMatch m) fn) {
    final m = re.firstMatch(t);
    if (m == null) return false;
    fn(m);
    t = t.replaceFirst(m[0]!, ' ');
    return true;
  }

  take(RegExp(r'\s(весь день)(?=\s)', caseSensitive: false), (_) => allDay = true);
  // Время: 15:00 (двоеточие — всегда время), 15.00 / 17.30 (точка — время, только если час 6–23 и минуты кратны 5,
  // иначе это дата: «3.11» — 3 ноября), «в 15».
  take(RegExp(r'\s(?:в\s)?([01]?\d|2[0-3]):([0-5]\d)(?=\s|[,.!?]\s)'), (m) => time = _hhmm(m[1]!, m[2]!)) ||
      take(
        RegExp(r'\s(?:в\s)?([6-9]|0[6-9]|1\d|2[0-3])\.([0-5][05])(?=\s|[,!?]\s)'),
        (m) => time = _hhmm(m[1]!, m[2]!),
      ) ||
      take(
        RegExp(
          r'\sв\s([01]?\d|2[0-3])(?=\s)(?!\s*(?:янв|фев|мар|апр|ма|июн|июл|авг|сен|окт|ноя|дек))',
          caseSensitive: false,
        ),
        (m) => time = _hhmm(m[1]!, '00'),
      );

  take(RegExp(r'\s(послезавтра)(?=\s|[,.!?])', caseSensitive: false), (_) => day = _addDays(base, 2)) ||
      take(RegExp(r'\s(завтра)(?=\s|[,.!?])', caseSensitive: false), (_) => day = _addDays(base, 1)) ||
      take(RegExp(r'\s(сегодня)(?=\s|[,.!?])', caseSensitive: false), (_) => day = base) ||
      take(
        RegExp(r'\sчерез\s(\d{1,3}|неделю|день)\s?(дн[еяй]+|день|недел[июь]+)?(?=\s|[,.!?])', caseSensitive: false),
        (m) {
          final unit = m[2] ?? '';
          final n = m[1] == 'неделю'
              ? 7
              : m[1] == 'день'
              ? 1
              : int.parse(m[1]!) * (RegExp('недел', caseSensitive: false).hasMatch(unit) ? 7 : 1);
          day = _addDays(base, n);
        },
      ) ||
      take(
        RegExp(
          r'\s(\d{1,2})\s(янв|фев|мар|апр|мая|май|июн|июл|авг|сен|окт|ноя|дек)[а-я]*\.?(?=\s|[,!?])',
          caseSensitive: false,
        ),
        (m) {
          final k = m[2]!.toLowerCase();
          final mi = RegExp(r'^ма[йя]').hasMatch(k) ? 4 : _months.indexOf(k.substring(0, 3)); // «марта» — март, не май
          day = _nearestDate(base, mi, int.parse(m[1]!));
        },
      ) ||
      take(RegExp(r'\s(\d{1,2})\.(\d{1,2})(?:\.(\d{2,4}))?(?=\s|[,!?])'), (m) {
        final y = m[3];
        if (y != null) {
          day = DateTime(int.parse(y.length == 2 ? '20$y' : y), int.parse(m[2]!), int.parse(m[1]!));
        } else {
          day = _nearestDate(base, int.parse(m[2]!) - 1, int.parse(m[1]!));
        }
      }) ||
      take(_weekWord, (m) {
        final w = m[1]!.toLowerCase();
        final i = _week.indexWhere((re) => re.hasMatch(w));
        final diff = (i - _dowMon(base) + 7) % 7;
        day = _addDays(base, diff == 0 ? 7 : diff);
      });

  if (allDay) time = null;
  return WhenResult(
    day: day == null ? null : ymd(day!),
    time: time,
    allDay: allDay,
    rest: t.replaceAll(RegExp(r'\s+'), ' ').trim(),
  );
}

const _monthsGen = [
  'января',
  'февраля',
  'марта',
  'апреля',
  'мая',
  'июня',
  'июля',
  'августа',
  'сентября',
  'октября',
  'ноября',
  'декабря',
];
const _wds = ['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'];

/// Подпись поля «Срок»: date 'Завтра, 21 октября', time '15:00–16:00' | 'весь день' | ''.
({String date, String time}) whenText(String? day, ({String s, String e})? slot, [DateTime? today]) {
  if (day == null || day.isEmpty) return (date: 'Без срока', time: '');
  final p = day.split('-').map(int.parse).toList();
  final y = p[0], m = p[1], d = p[2];
  final x = DateTime(y, m, d);
  final t0 = _addDays(today ?? DateTime.now(), 0);
  // Разница в днях без учёта перехода на летнее время: считаем по UTC-полуночам.
  final diff = DateTime.utc(x.year, x.month, x.day).difference(DateTime.utc(t0.year, t0.month, t0.day)).inDays;
  final wd = _wds[_dowMon(x)];
  final rel = diff == 0
      ? 'Сегодня'
      : diff == 1
      ? 'Завтра'
      : diff == 2
      ? 'Послезавтра'
      : diff == -1
      ? 'Вчера'
      : wd[0].toUpperCase() + wd.substring(1);
  final year = y != t0.year ? ' $y' : '';
  return (
    date: '$rel, $d ${_monthsGen[m - 1]}$year',
    time: slot != null && slot.s.isNotEmpty ? '${slot.s}–${slot.e}' : 'весь день',
  );
}

/// «25 окт» без года — ближайшее такое число: в этом году или, если уже прошло, в следующем.
DateTime _nearestDate(DateTime base, int month, int date) {
  final d = DateTime(base.year, month + 1, date);
  return d.isBefore(base) ? DateTime(base.year + 1, month + 1, date) : d;
}
