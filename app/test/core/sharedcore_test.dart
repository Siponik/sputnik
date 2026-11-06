import 'package:flutter_test/flutter_test.dart';
import 'package:sputnik_app/core/sharedcore.dart' as sh;

import '../golden_util.dart';

typedef J = Map<String, dynamic>;

void main() {
  final cases = golden('sharedcore.json');
  final recs = (cases.firstWhere((x) => x['fn'] == 'setup')['a'] as List)[0] as J;
  final people = sh.membersOf(recs);
  String name(Object? c) => const {'review': 'Ревью', 'doing': 'В работе'}[c] ?? '$c';
  final now = DateTime(2026, 10, 21, 14).millisecondsSinceEpoch;
  for (final (i, x) in cases.indexed) {
    final a = x['a'] as List;
    test('sharedcore ${x['fn']} #$i', () {
      final Object? got = switch (x['fn']) {
        'setup' => null,
        'same' => sh.same(a[0], a[1]),
        'sameU' => sh.same(null, null),
        'newKey' => () {
          final vals = (a[1] as List).cast<num>();
          var j = 0;
          return sh.newKey(a[0], () => vals[j++].toDouble());
        }(),
        'kindOf' => sh.kindOf(a[0]),
        'memberKey' => sh.memberKey(a[0]),
        'ids' => [sh.isSharedId(a[0]), sh.listKey(a[0]), sh.calOfSphere(a[0])],
        'listId' => sh.listId(a[0]),
        'sphereId' => sh.sphereId(a[0]),
        'make' => sh.make(a[0], a[1], a[2]),
        'edit' => sh.edit(a[0], a[1], a[2]),
        'mergeRec' => sh.mergeRec(a[0], a[1]),
        'lastTime' => sh.lastTime(a[0]),
        'toEvent' => sh.toEvent(a[0]),
        'fromEvent' => sh.fromEvent(a[0]),
        'newPos' => sh.newPos((a[0] as num).toInt()),
        'taskView' => sh.taskView(a[0]),
        'listView' => sh.listView(a[0], a[1]),
        'taskPatch' => sh.taskPatch(a[0], a[1]),
        'layerOf' => sh.layerOf(a[0]),
        'sharedOf' => sh.sharedOf(a[0], a[1]),
        'reconcile' => sh.reconcile(a[0], a[1], a[2]),
        'reconcileList' => sh.reconcile(a[0], a[1], a[2], 'list'),
        'reconcileSphere' => sh.reconcileSphere(a[0], a[1], a[2]),
        'tasksOf' => sh.tasksOf(recs, a[0]),
        'listsOf' => sh.listsOf(recs, a[0]),
        'withChildren' => sh.withChildren(recs, a[0]),
        'isSphereCal' => sh.isSphereCal(a[0]),
        'membersOf' => people,
        'membersOf0' => sh.membersOf(null),
        'okPic' => sh.okPic(a[0]),
        'profilePatch' => sh.profilePatch(a[0], a[1]),
        'profileFields' => sh.profileFields(a[0]),
        'nameOf' => sh.nameOf(a[0]),
        'nextOrder' => sh.nextOrder(recs),
        'nextOrder0' => sh.nextOrder({}),
        'whoOf' => sh.whoOf(a[0]),
        'assignedMatch' => sh.assignedMatch(a[0], a[1], a[2]),
        'handoff' => sh.handoff(a[0], a[1]),
        'setStageWho' => sh.setStageWho(a[0], a[1], a[2]),
        'stagePass' => sh.stagePass(a[0], a[1], a[2], a[3], a[4]),
        'isTogether' => sh.isTogether((a[0] as List).cast<Map>()),
        'seenText' => sh.seenText(a[0], a[1]),
        'parseEmails' => sh.parseEmails(a[0]),
        'memberOf' => sh.memberOf(people, a[0]),
        'whoOptions' => sh.whoOptions(people, a[0], a[1], a[2]),
        'whoByDigit' => () {
          final r = sh.whoByDigit(people, a[0], a[1]);
          return identical(r, sh.noWho) ? '<undefined>' : r;
        }(),
        'memberByWord' => sh.memberByWord(people, a[0]),
        'editOf' => sh.editOf(a[0]),
        'changeText' => sh.changeText(a[0], people, a[1], name, now),
        'assignedToMe' => sh.assignedToMe(a[0], a[1], a[2]),
        'whoCounts' => sh.whoCounts((a[0] as List).cast<Map>(), a[1]),
        'whoTally' => sh.whoTally((a[0] as List).cast<Map>(), a[1], a[2]),
        'WHO_MODES' => sh.whoModes,
        'forMe' => sh.forMe(a[0], a[1], a[2], (id) => id != 'L2'),
        'passText' => sh.passText(a[0], people, a[1], name),
        'nextHint' => sh.nextHint(a[0], a[1], a[2], people),
        'stageCrew' => sh.stageCrew(a[0], (a[1] as List).cast<Map>(), a[2]),
        'isInvite' => sh.isInvite(a[0], a[1]),
        'inviteInfo' => sh.inviteInfo(a[0], a[1]),
        'waitingFor' => sh.waitingFor(a[0], people, a[1]),
        'unseenBy' => sh.unseenBy(recs, people, a[0]),
        'seenDue' => sh.seenDue(a[0], a[1], a[2]),
        'askAccessText' => sh.askAccessText(a[0], a[1]),
        'consts' => [
          sh.mark,
          sh.summary,
          sh.prefix,
          sh.notesMax,
          sh.sphereFields,
          sh.sphereKey,
          sh.memberColors,
          sh.nameMax,
          sh.picMax,
        ],
        _ => throw 'нет ${x['fn']}',
      };
      expect(js(got), js(x['out']));
    });
  }
}
