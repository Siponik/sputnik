import 'package:flutter/material.dart';

import '../state/app_state.dart';

class TodayPage extends StatelessWidget {
  const TodayPage({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final items = state.today;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Спутник · Сегодня'),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Center(
                  child: Text(
                    'загрузка ${state.loadMs} мс · отклик на нажатие ${state.lastTapMs} мс',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
              IconButton(onPressed: state.load, icon: const Icon(Icons.refresh), tooltip: 'Обновить'),
            ],
          ),
          body: state.loggingIn
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Открыл браузер: войди в Google и вернись сюда'),
                      const SizedBox(height: 16),
                      OutlinedButton(onPressed: state.cancelLogin, child: const Text('Отмена')),
                    ],
                  ),
                )
              : state.loading
              ? const Center(child: CircularProgressIndicator())
              : state.error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(state.error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        if (state.needLogin)
                          FilledButton(onPressed: state.login, child: const Text('Войти в Google'))
                        else
                          OutlinedButton(onPressed: state.load, child: const Text('Повторить')),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    if (state.toast != null) MaterialBanner(content: Text(state.toast!), actions: const [SizedBox()]),
                    Expanded(
                      child: items.isEmpty
                          ? const Center(child: Text('На сегодня ничего нет'))
                          : ListView.builder(
                              itemCount: items.length,
                              itemBuilder: (context, i) {
                                final t = items[i];
                                return CheckboxListTile(
                                  value: t.done,
                                  onChanged: (_) => state.toggle(t),
                                  title: Text(
                                    t.title,
                                    style: t.done ? const TextStyle(decoration: TextDecoration.lineThrough) : null,
                                  ),
                                  subtitle: Text('${state.listNames[t.listId] ?? ''} · ${t.day}'),
                                  controlAffinity: ListTileControlAffinity.leading,
                                );
                              },
                            ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}
