// Окна списков и сфер: новый список, настройки списка (название, сфера, шаблон, вид, порядок, «Сегодня», архив, удалить),
// новая/правка сферы.
import 'package:flutter/material.dart';

import '../../core/spheres.dart' as sph;
import '../../core/templates.dart' as tpl;
import '../../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

Widget _label(String t) => Padding(
  padding: const EdgeInsets.only(top: 12, bottom: 6),
  child: Text(t.toUpperCase(), style: SpType.label(10.5)),
);

Widget _sphereChips(AppState s, String? cur, void Function(String?) on) => Wrap(
  spacing: 6,
  runSpacing: 6,
  children: [
    ChoiceChip(label: const Text('Без сферы'), selected: cur == null, onSelected: (_) => on(null)),
    for (final sp in s.spheres)
      ChoiceChip(
        avatar: CircleAvatar(radius: 5, backgroundColor: cssColor(sph.sphereColor(sp))),
        label: Text((sp['name'] ?? '') as String),
        selected: cur == sp['id'],
        onSelected: (_) => on(sp['id'] as String),
      ),
  ],
);

Future<String?> newListDialog(BuildContext context, AppState s, {String? sphere}) => showDialog<String>(
  context: context,
  builder: (_) => _NewList(s: s, sphere: sphere),
);

class _NewList extends StatefulWidget {
  const _NewList({required this.s, this.sphere});
  final AppState s;
  final String? sphere;
  @override
  State<_NewList> createState() => _NewListState();
}

class _NewListState extends State<_NewList> {
  final name = TextEditingController();
  String template = 'work';
  late String? sphere = widget.sphere;
  bool busy = false;

  Future<void> _go() async {
    if (name.text.trim().isEmpty || busy) return;
    setState(() => busy = true);
    final id = await widget.s.createList(name.text.trim(), template: template, sphere: sphere);
    if (mounted) Navigator.pop(context, id);
  }

  @override
  Widget build(BuildContext context) {
    final tpls = tpl.templatesFrom(widget.s.layer);
    return AlertDialog(
      backgroundColor: SpColors.node,
      title: const Text('Новый список'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: name,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Название'),
              onSubmitted: (_) => _go(),
            ),
            _label('Шаблон'),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in tpls)
                  ChoiceChip(
                    label: Text((t['name'] ?? '') as String),
                    tooltip: (t['hint'] ?? '') as String,
                    selected: template == t['id'],
                    onSelected: (_) => setState(() => template = t['id'] as String),
                  ),
              ],
            ),
            _label('Сфера'),
            _sphereChips(widget.s, sphere, (v) => setState(() => sphere = v)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
        FilledButton(onPressed: busy ? null : _go, child: const Text('Создать')),
      ],
    );
  }
}

Future<void> listSettings(BuildContext context, AppState s, String listId) => showDialog<void>(
  context: context,
  builder: (_) => _ListSettings(s: s, listId: listId),
);

class _ListSettings extends StatefulWidget {
  const _ListSettings({required this.s, required this.listId});
  final AppState s;
  final String listId;
  @override
  State<_ListSettings> createState() => _ListSettingsState();
}

class _ListSettingsState extends State<_ListSettings> {
  late final name = TextEditingController(text: widget.s.listName(widget.listId));

  @override
  Widget build(BuildContext context) {
    final s = widget.s, id = widget.listId;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final L = s.layList(id);
        final b = s.board(id);
        final tpls = tpl.templatesFrom(s.layer);
        return AlertDialog(
          backgroundColor: SpColors.node,
          title: const Text('Настройки списка'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Название'),
                    onSubmitted: (v) {
                      if (v.trim().isNotEmpty) s.renameList(id, v.trim());
                    },
                  ),
                  _label('Сфера'),
                  _sphereChips(s, s.sphereOf(id), (v) => s.setListField(id, {'sphere': v})),
                  _label('Колонки из шаблона'),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final t in tpls)
                        ChoiceChip(
                          label: Text((t['name'] ?? '') as String),
                          selected: (L['template'] ?? 'work') == t['id'] && b['own'] != true,
                          onSelected: (_) => s.switchTemplate(id, t['id'] as String),
                        ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Сейчас: ${[for (final c in b['cols'] as List) c['name']].join(' → ')}',
                      style: SpType.text(12, color: SpColors.muted),
                    ),
                  ),
                  _label('Порядок задач'),
                  Wrap(
                    spacing: 6,
                    children: [
                      for (final o in tpl.sorts)
                        ChoiceChip(
                          label: Text(o['name'] as String),
                          selected: tpl.sortOf(L) == o['id'],
                          onSelected: (_) => s.setListField(id, {'sort': o['id']}),
                        ),
                    ],
                  ),
                  _label('Архив'),
                  Wrap(
                    spacing: 6,
                    children: [
                      for (final d in [0, 3, 7])
                        ChoiceChip(
                          label: Text(d == 0 ? 'Сразу' : 'Через $d дн.'),
                          selected: tpl.archiveDays(L) == d,
                          onSelected: (_) => s.setListField(id, {'archive': d}),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Тихий список'),
                    subtitle: const Text('Не в «Сегодня», не в счётчике и не в снимке для бота'),
                    value: L['quiet'] == true,
                    onChanged: (v) => s.setListField(id, {'quiet': v}),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Скрыть'),
                    subtitle: const Text('Не показывать список нигде (вернуть — Настройки → Что показывать)'),
                    value: L['hidden'] == true,
                    onChanged: (v) => s.setListField(id, {'hidden': v}),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: Text('Удалить «${s.listName(id)}»?'),
                    content: const Text('Список и его задачи удалятся из Google Tasks насовсем.'),
                    actions: [
                      TextButton(
                        autofocus: true,
                        onPressed: () => Navigator.pop(c, false),
                        child: const Text('Отмена'),
                      ),
                      FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Удалить')),
                    ],
                  ),
                );
                if (ok == true) {
                  await s.deleteList(id);
                  if (context.mounted) Navigator.pop(context);
                }
              },
              icon: const Icon(Icons.delete_outline, size: 16),
              label: const Text('Удалить список'),
            ),
            FilledButton(
              onPressed: () {
                if (name.text.trim().isNotEmpty && name.text.trim() != s.listName(id)) {
                  s.renameList(id, name.text.trim());
                }
                Navigator.pop(context);
              },
              child: const Text('Готово'),
            ),
          ],
        );
      },
    );
  }
}

Future<void> sphereDialog(BuildContext context, AppState s, [Json? sp]) => showDialog<void>(
  context: context,
  builder: (_) => _Sphere(s: s, sp: sp),
);

class _Sphere extends StatefulWidget {
  const _Sphere({required this.s, this.sp});
  final AppState s;
  final Json? sp;
  @override
  State<_Sphere> createState() => _SphereState();
}

class _SphereState extends State<_Sphere> {
  late final name = TextEditingController(text: (widget.sp?['name'] ?? '') as String);
  late String color = (widget.sp?['color'] ?? 'clay') as String;
  late String icon = (widget.sp?['icon'] ?? 'star') as String;

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: SpColors.node,
    title: Text(widget.sp == null ? 'Новая сфера' : 'Сфера'),
    content: SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: name,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Работа, Дом, Учёба…'),
          ),
          _label('Цвет'),
          Wrap(
            spacing: 8,
            children: [
              for (final c in sph.sphereColors)
                InkWell(
                  onTap: () => setState(() => color = c['id'] as String),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: cssColor(c['v']),
                      shape: BoxShape.circle,
                      border: Border.all(color: color == c['id'] ? SpColors.ink : Colors.transparent, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          _label('Значок'),
          Wrap(
            spacing: 6,
            children: [
              for (final e in sph.sphereIcons.entries)
                ChoiceChip(
                  label: Text(e.value['name'] as String),
                  selected: icon == e.key,
                  onSelected: (_) => setState(() => icon = e.key),
                ),
            ],
          ),
        ],
      ),
    ),
    actions: [
      if (widget.sp != null)
        TextButton(
          onPressed: () {
            widget.s.deleteSphere(widget.sp!['id'] as String);
            Navigator.pop(context);
          },
          child: const Text('Удалить сферу'),
        ),
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
      FilledButton(
        onPressed: () {
          if (name.text.trim().isEmpty) return;
          widget.s.saveSphere(widget.sp?['id'] as String?, {'name': name.text.trim(), 'color': color, 'icon': icon});
          Navigator.pop(context);
        },
        child: const Text('Сохранить'),
      ),
    ],
  );
}
