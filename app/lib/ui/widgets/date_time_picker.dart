// Свой выбор даты и времени по макету G_DateTime (вместо системных окон Material).
// Слева — «словами» (core/when.dart), быстрые чипы и месяц с понедельника; справа — сетка часов 00–23
// по 6 в ряд (ночь / утро / день / вечер, занятый час — с полоской), минуты :00/:15/:30/:45 и «чч:мм», «До».
// Окно открывается рядом с полем, по которому щёлкнули (anchor), а не по центру экрана.
import 'package:flutter/material.dart';

import '../../core/dates.dart';
import '../../core/when.dart';
import '../../state/app_state.dart';
import '../g/kit.dart';
import '../theme/tokens.dart';

/// Итог выбора. `cleared` — «Без срока».
class DtResult {
  const DtResult({this.day, this.time, this.end, this.cleared = false});
  final String? day, time, end;
  final bool cleared;
}

const _months = [
  'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь', //
  'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь',
];
const _monthsGen = [
  'января', 'февраля', 'марта', 'апреля', 'мая', 'июня', //
  'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря',
];
const _wdFull = ['понедельник', 'вторник', 'среда', 'четверг', 'пятница', 'суббота', 'воскресенье'];
const _wdShort = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

String _two(int x) => x.toString().padLeft(2, '0');
DateTime _p(String d) => DateTime.parse(d);
int _min(String t) => int.parse(t.substring(0, 2)) * 60 + int.parse(t.substring(3, 5));
String _hm(int m) => m >= 24 * 60 ? '23:59' : '${_two(m ~/ 60)}:${_two(m % 60)}';

/// Открыть выбор рядом с [anchor] (обычно `context` поля). [busy] — занятые часы дня.
Future<DtResult?> pickDateTime(
  BuildContext anchor, {
  String? day,
  String? time,
  String? end,
  bool withTime = true,
  bool withEnd = true,
  bool allowClear = true,
  String title = 'Срок',
  String? about,
  Set<int> Function(String day)? busy,
}) {
  final box = anchor.findRenderObject() as RenderBox?;
  final at = box == null || !box.hasSize ? null : box.localToGlobal(Offset.zero) & box.size;
  return showGeneralDialog<DtResult>(
    context: anchor,
    barrierDismissible: true,
    barrierLabel: 'Закрыть',
    barrierColor: Colors.black38,
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (c, _, _) => _Place(
      at: at,
      width: withTime ? 740.0 : 340.0,
      child: _Picker(
        day: day,
        time: time,
        end: end,
        withTime: withTime,
        withEnd: withEnd,
        allowClear: allowClear,
        title: title,
        about: about,
        busy: busy,
      ),
    ),
    transitionBuilder: (c, a, _, w) => FadeTransition(
      opacity: CurvedAnimation(parent: a, curve: const Cubic(.2, .8, .2, 1)),
      child: ScaleTransition(
        scale: Tween(begin: .97, end: 1.0).animate(CurvedAnimation(parent: a, curve: const Cubic(.2, .8, .2, 1))),
        child: w,
      ),
    ),
  );
}

/// Ставит окно под полем (или над, если снизу не влезает), не вылезая за экран.
class _Place extends StatelessWidget {
  const _Place({required this.at, required this.width, required this.child});
  final Rect? at;
  final double width;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final scr = MediaQuery.sizeOf(context);
    final w = width.clamp(0.0, scr.width - 24);
    final room = at == null ? 0.0 : (scr.height - at!.bottom > at!.top ? scr.height - at!.bottom : at!.top);
    if (at == null || room < 320 || at!.height > scr.height / 2) {
      return Center(
        child: SizedBox(width: w, child: child),
      );
    }
    final left = at!.left.clamp(12.0, (scr.width - w - 12).clamp(12.0, double.infinity));
    final below = scr.height - at!.bottom;
    final top = below > 470 || below > at!.top ? at!.bottom + 6 : null;
    return Stack(
      children: [
        Positioned(
          left: left,
          top: top,
          bottom: top == null ? scr.height - at!.top + 6 : null,
          width: w,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: (top == null ? at!.top : below) - 18),
            child: child,
          ),
        ),
      ],
    );
  }
}

class _Picker extends StatefulWidget {
  const _Picker({
    this.day,
    this.time,
    this.end,
    required this.withTime,
    required this.withEnd,
    required this.allowClear,
    required this.title,
    this.about,
    this.busy,
  });
  final String? day, time, end, about;
  final bool withTime, withEnd, allowClear;
  final String title;
  final Set<int> Function(String day)? busy;
  @override
  State<_Picker> createState() => _PickerState();
}

class _PickerState extends State<_Picker> {
  late final today = ymd(DateTime.now());
  late String? day = (widget.day == null || widget.day!.isEmpty) ? null : widget.day;
  late String? time = widget.time;
  late int? dur = widget.time != null && widget.end != null ? _min(widget.end!) - _min(widget.time!) : null;
  late DateTime shown = DateTime(_p(day ?? today).year, _p(day ?? today).month);
  final words = TextEditingController();
  final exact = TextEditingController();
  String? understood;

  @override
  void initState() {
    super.initState();
    exact.text = time ?? '';
  }

  void _setDay(String d) => setState(() {
    day = d;
    shown = DateTime(_p(d).year, _p(d).month);
  });

  void _words(String v) {
    final r = parseWhen(v);
    setState(() {
      if (r.day != null) {
        day = r.day;
        shown = DateTime(_p(r.day!).year, _p(r.day!).month);
      }
      if (r.time != null && widget.withTime) {
        time = r.time;
        exact.text = r.time!;
      }
      understood = r.day == null && r.time == null ? null : _say(r.day ?? day, r.time ?? time);
    });
  }

  String _say(String? d, String? t) {
    if (d == null) return t ?? '';
    final x = _p(d);
    return '${_wdFull[x.weekday - 1]}, ${x.day} ${_monthsGen[x.month - 1]}${t == null ? '' : ', $t'}';
  }

  String get _summary {
    if (day == null) return 'Без срока';
    final x = _p(day!);
    final t = time == null ? '' : ' · $time${dur == null ? '' : '–${_hm(_min(time!) + dur!)}'}';
    return '${_wdShort[x.weekday - 1]}, ${x.day} ${_monthsGen[x.month - 1]}$t';
  }

  void _done() => Navigator.pop(
    context,
    DtResult(day: day, time: time, end: time == null || dur == null ? null : _hm(_min(time!) + dur!)),
  );

  @override
  Widget build(BuildContext context) {
    final left = _left();
    return Material(
      type: MaterialType.transparency,
      child: GNode(
        hub: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GHead(
              hub: true,
              name: widget.withTime ? '${widget.title} · выбор даты и времени' : '${widget.title} · выбор даты',
              kind: widget.about,
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                child: widget.withTime
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: 262, child: left),
                          const SizedBox(width: 22),
                          Expanded(child: _right()),
                        ],
                      )
                    : left,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: SpColors.line)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _summary,
                      style: SpType.text(12.5, color: SpColors.muted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GBtn('Отмена', onTap: () => Navigator.pop(context)),
                  const SizedBox(width: 8),
                  GBtn('Готово', kind: BtnKind.acc, onTap: _done),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _left() {
    final t = _p(today);
    String add(int n) => ymd(DateTime(t.year, t.month, t.day + n));
    final sat = add((6 - t.weekday + 7) % 7);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: words,
          autofocus: true,
          style: SpType.text(14),
          decoration: InputDecoration(
            hintText: 'словами: «в пятницу 17:00»',
            hintStyle: SpType.text(14, color: SpColors.dim),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: SpColors.line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: SpColors.accent, width: 1.3),
            ),
          ),
          onChanged: _words,
          onSubmitted: (_) => _done(),
        ),
        const SizedBox(height: 8),
        Text(
          understood == null ? 'Можно написать: завтра, в пт 15:30, 12.11' : 'Понял: $understood',
          style: SpType.text(12, color: SpColors.muted),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            GPick('Сегодня', on: day == today, onTap: () => _setDay(today)),
            GPick('Завтра', on: day == add(1), onTap: () => _setDay(add(1))),
            GPick('В выходные', on: day == sat, onTap: () => _setDay(sat)),
            GPick('Через неделю', on: day == add(7), onTap: () => _setDay(add(7))),
            if (widget.allowClear)
              GPick('Без срока', onTap: () => Navigator.pop(context, const DtResult(cleared: true))),
          ],
        ),
        const SizedBox(height: 16),
        _month(),
      ],
    );
  }

  Widget _month() {
    final first = shown;
    final lead = first.weekday - 1; // неделя с понедельника
    final start = DateTime(first.year, first.month, 1 - lead);
    final days = DateTime(first.year, first.month + 1, 0).day;
    final weeks = ((lead + days) / 7).ceil();
    Widget nav(String t, int d) => InkWell(
      onTap: () => setState(() => shown = DateTime(shown.year, shown.month + d)),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 28,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: SpColors.line),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(t, style: SpType.text(13, color: SpColors.ink2)),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('${_months[first.month - 1]} ${first.year}', style: SpType.text(13.5, w: FontWeight.w600)),
            ),
            nav('‹', -1),
            const SizedBox(width: 6),
            nav('›', 1),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final w in ['ПН', 'ВТ', 'СР', 'ЧТ', 'ПТ', 'СБ', 'ВС'])
              Expanded(
                child: Text(w, textAlign: TextAlign.center, style: gMicro()),
              ),
          ],
        ),
        const SizedBox(height: 4),
        for (var r = 0; r < weeks; r++)
          Row(
            children: [
              for (var c = 0; c < 7; c++)
                () {
                  final d = DateTime(start.year, start.month, start.day + r * 7 + c);
                  final s = ymd(d), on = s == day, isT = s == today, out = d.month != first.month;
                  return Expanded(
                    child: InkWell(
                      onTap: () => _setDay(s),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        height: 32,
                        margin: const EdgeInsets.all(1.5),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: on ? SpColors.accent : null,
                          borderRadius: BorderRadius.circular(6),
                          border: isT && !on ? Border.all(color: SpColors.accent) : null,
                        ),
                        child: Text(
                          '${d.day}',
                          style: SpType.text(
                            13,
                            w: on ? FontWeight.w600 : FontWeight.w400,
                            color: on ? SpColors.onAccent : (out ? SpColors.dim : SpColors.ink),
                          ),
                        ),
                      ),
                    ),
                  );
                }(),
            ],
          ),
      ],
    );
  }

  Widget _right() {
    final busy = widget.busy?.call(day ?? today) ?? const <int>{};
    final h = time == null ? null : int.parse(time!.substring(0, 2));
    final m = time == null ? null : int.parse(time!.substring(3, 5));
    void setT(int hh, int mm) => setState(() {
      time = '${_two(hh)}:${_two(mm)}';
      exact.text = time!;
      day ??= today;
    });
    Widget hour(int x) {
      final on = x == h;
      return Expanded(
        child: InkWell(
          onTap: () => setT(x, m ?? 0),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            height: 32,
            margin: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: on ? SpColors.accent : null,
              borderRadius: BorderRadius.circular(6),
              border: on ? null : Border.all(color: SpColors.line),
            ),
            child: Stack(
              children: [
                Center(
                  child: Text(
                    _two(x),
                    style: gMono(
                      12,
                      c: on ? SpColors.onAccent : SpColors.ink2,
                      w: on ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                if (busy.contains(x) && !on)
                  Positioned(left: 10, right: 10, bottom: 3, child: Container(height: 2, color: SpColors.lineStrong)),
              ],
            ),
          ),
        ),
      );
    }

    Widget lbl(String t) => Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Text(t, style: SpType.text(12.5, color: SpColors.muted)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Время · серая полоска — час уже занят', style: SpType.text(12.5, color: SpColors.muted)),
        const SizedBox(height: 8),
        for (final (i, part) in ['Ночь', 'Утро', 'День', 'Вечер'].indexed)
          Row(
            children: [
              SizedBox(
                width: 56,
                child: Text(part, style: SpType.text(12.5, color: SpColors.muted)),
              ),
              for (var k = 0; k < 6; k++) hour(i * 6 + k),
            ],
          ),
        lbl('Минуты'),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final mm in [0, 15, 30, 45]) GPick(':${_two(mm)}', on: m == mm, onTap: () => setT(h ?? 10, mm)),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('или точно', style: SpType.text(12.5, color: SpColors.muted)),
            ),
            SizedBox(
              width: 70,
              height: 32,
              child: TextField(
                controller: exact,
                style: gMono(13),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: 'чч:мм',
                  hintStyle: gMono(12, c: SpColors.dim),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: SpColors.line),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: SpColors.accent),
                  ),
                ),
                onChanged: (v) {
                  final r = RegExp(r'^(\d{1,2})[:.]?(\d{2})$').firstMatch(v.trim());
                  if (r == null) return;
                  final hh = int.parse(r[1]!), mm = int.parse(r[2]!);
                  if (hh < 24 && mm < 60) {
                    setState(() {
                      time = '${_two(hh)}:${_two(mm)}';
                      day ??= today;
                    });
                  }
                },
              ),
            ),
            if (time != null)
              GPick(
                'Без времени',
                onTap: () => setState(() {
                  time = null;
                  exact.text = '';
                }),
              ),
          ],
        ),
        if (widget.withEnd && time != null) ...[
          lbl('До'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              GPick('Без конца', on: dur == null, onTap: () => setState(() => dur = null)),
              for (final (n, t) in [(30, '30 мин'), (60, '1 час'), (120, '2 часа')])
                GPick(
                  dur == n ? '$t · до ${_hm(_min(time!) + n)}' : t,
                  on: dur == n,
                  onTap: () => setState(() => dur = n),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Занятые часы дня: события Google со временем и задачи со временем (slot) на этот день.
Set<int> busyHours(AppState s, String day) {
  final out = <int>{};
  for (final e in s.events) {
    final a = DateTime.tryParse(((e['start'] as Map?)?['dateTime'] ?? '') as String)?.toLocal();
    final b = DateTime.tryParse(((e['end'] as Map?)?['dateTime'] ?? '') as String)?.toLocal();
    if (a == null || ymd(a) != day) continue;
    final last = b == null || ymd(b) != day ? a.hour : (b.minute == 0 ? b.hour - 1 : b.hour);
    for (var h = a.hour; h <= last.clamp(a.hour, 23); h++) {
      out.add(h);
    }
  }
  for (final l in s.boardLists) {
    for (final t in s.tasks[l['id']] ?? const <Json>[]) {
      if (dueToYmd(t['due'] as String?) != day) continue;
      final sl = s.layTask(t['id'] as String)['slot'];
      if (sl is Map && sl['s'] is String) out.add(int.parse((sl['s'] as String).substring(0, 2)));
    }
  }
  return out;
}
