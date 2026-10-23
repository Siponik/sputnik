// Пересказ новостей бесплатной или дешёвой моделью. Один запрос в день.
// GEMINI_API_KEY — Gemini (бесплатный уровень Google AI Studio), модель GEMINI_MODEL (по умолчанию gemini-flash-latest).
// Иначе LLM_KEY + LLM_URL + LLM_MODEL — любой сервис с API как у OpenAI (DeepSeek, OpenRouter).
// Нет ключа или модель не ответила — build.mjs берёт отбор без ИИ (fallbackPick).

export function prompt(cands, sections, dotaTitle) {
  const secs = sections.map((s) => `${s.id} — «${s.title}», до ${s.max}`).join('; ');
  const list = cands.map((c) => ({ id: c.id, sec: c.sec, src: c.src, date: c.date, title: c.title, text: c.text }));
  return `Ты собираешь утреннюю ленту новостей для 3D-художника и дизайнера игрового арта. Пиши по-русски, просто и живо, без канцелярита.
Из кандидатов ниже выбери всего 25–30 самых интересных пунктов и разложи по разделам (id раздела — поле sec): ${secs}.
Правила:
- cg: 3D-софт, аддоны, бесплатные инструменты, брейкдауны и интервью художников, стилизация, игровой арт, VFX. Dota 2 сюда не ставить.
- industry: анонсы, трейлеры, переносы, студии и издатели, Steam, ИИ в геймдеве, интервью разработчиков. Приоритет — то, что интересно художнику игр.
- releases: только игры, которые выходят сегодня или до воскресенья этой недели.
- updates: заметные патчи, сезоны, новые герои, дополнения. Хотфиксы без изменений не брать.
- hype: самое обсуждаемое — технологии, ИИ, гаджеты, интернет-культура, кино, сериалы, аниме. Без политики, войны, криминала и трагедий.
- Киберспорт, скидки, гороскопы и рекламу не брать. Один сюжет — один пункт, без повторов между разделами.
- Можно переставить пункт в другой раздел, если он туда подходит лучше.${dotaTitle ? `\n- Большое обновление Dota 2 «${dotaTitle}» уже показано отдельно — не включай его.` : ''}
Для каждого выбранного пункта: title — заголовок своими словами, до 10 слов; text — одно предложение: суть и чем это интересно. Ничего не выдумывай сверх данных кандидата.
headline — одна короткая фраза о самом главном в сегодняшней ленте.
Ответ — только JSON: {"headline":"…","items":[{"id":"…","sec":"…","title":"…","text":"…"}]}

Кандидаты:
${JSON.stringify(list)}`;
}

function jsonOf(text) {
  const t = String(text || '').replace(/^```(?:json)?\s*|\s*```$/g, '');
  const a = t.indexOf('{'), b = t.lastIndexOf('}');
  return JSON.parse(a >= 0 ? t.slice(a, b + 1) : t);
}

export async function retell(text, env = process.env) {
  if (env.GEMINI_API_KEY) {
    const model = env.GEMINI_MODEL || 'gemini-flash-latest';
    const r = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`, {
      method: 'POST',
      headers: { 'content-type': 'application/json', 'x-goog-api-key': env.GEMINI_API_KEY },
      body: JSON.stringify({ contents: [{ role: 'user', parts: [{ text }] }], generationConfig: { responseMimeType: 'application/json', temperature: 0.4 } }),
      signal: AbortSignal.timeout(120e3),
    });
    if (!r.ok) throw new Error(`Gemini ${r.status}: ${(await r.text()).slice(0, 300)}`);
    const j = await r.json();
    return jsonOf(j.candidates?.[0]?.content?.parts?.map((p) => p.text).join('') || '');
  }
  if (env.LLM_KEY && env.LLM_URL) {
    const r = await fetch(env.LLM_URL, {
      method: 'POST',
      headers: { 'content-type': 'application/json', authorization: 'Bearer ' + env.LLM_KEY },
      body: JSON.stringify({ model: env.LLM_MODEL || 'deepseek-chat', temperature: 0.4, response_format: { type: 'json_object' }, messages: [{ role: 'user', content: text }] }),
      signal: AbortSignal.timeout(180e3),
    });
    if (!r.ok) throw new Error(`LLM ${r.status}: ${(await r.text()).slice(0, 300)}`);
    const j = await r.json();
    return jsonOf(j.choices?.[0]?.message?.content || '');
  }
  return null;
}
