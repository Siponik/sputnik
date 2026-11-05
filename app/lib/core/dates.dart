// Даты, как их хранит Спутник. Порт дата-помощников из tracker/src/lib/api.js (ymd, dueToYmd, ymdToDue).
// День задачи — строка 'ГГГГ-ММ-ДД' (местная дата); Google Tasks хранит срок как 'ГГГГ-ММ-ДДT00:00:00.000Z'.

/// 'ГГГГ-ММ-ДД' по местной дате.
String ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Срок задачи из Google → 'ГГГГ-ММ-ДД' (или '' без срока).
String dueToYmd(String? due) => (due == null || due.isEmpty) ? '' : due.substring(0, 10);

/// 'ГГГГ-ММ-ДД' → срок для Google (или null).
String? ymdToDue(String? s) => (s == null || s.isEmpty) ? null : '${s}T00:00:00.000Z';
