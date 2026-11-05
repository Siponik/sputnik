import 'package:flutter_test/flutter_test.dart';
import 'package:sputnik_app/core/oauth.dart';
import 'package:sputnik_app/core/today_tasks.dart';

void main() {
  test('PKCE по примеру из RFC 7636', () {
    expect(pkceChallenge('dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk'), 'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM');
  });
  test('недостающие доступы', () {
    expect(missingScopes('https://www.googleapis.com/auth/tasks https://www.googleapis.com/auth/calendar'), [
      'https://www.googleapis.com/auth/drive.file',
      'https://www.googleapis.com/auth/drive.appdata',
    ]);
    expect(missingScopes(requiredScopes.join(' ')), isEmpty);
  });
  test('ключ клиента', () {
    expect(
      parseSecret('{"installed":{"client_id":"x.apps.googleusercontent.com","client_secret":"s"}}')?.id,
      'x.apps.googleusercontent.com',
    );
    expect(parseSecret('{"installed":{"client_id":"bad"}}'), isNull);
    expect(parseSecret('не json'), isNull);
  });
  test('списки в «Сегодня»', () {
    final layer = {
      'lists': {
        'h': {'hidden': true},
        'q': {'quiet': true},
      },
    };
    expect(showList({'id': 'a', 'title': 'Работа'}, layer), isTrue);
    expect(showList({'id': 'p', 'title': 'Привычки'}, layer), isFalse);
    expect(showList({'id': 'h', 'title': 'X'}, layer), isFalse);
    expect(showList({'id': 'q', 'title': 'Y'}, layer), isFalse);
  });
}
