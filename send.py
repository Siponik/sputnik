#!/usr/bin/env python3
"""Спутник: отправляет в Telegram уведомление о готовой утренней сводке.

Без внешних зависимостей, только стандартная библиотека Python 3.

Переменные окружения:
  TELEGRAM_BOT_TOKEN  токен бота от @BotFather (обязательно)
  TELEGRAM_CHAT_ID    ваш chat id, например от @userinfobot (обязательно)
  BRIEF_URL           ссылка на страницу сводки (обязательно)
"""

import json
import os
import sys
import urllib.error
import urllib.request

MESSAGE = "🛰 Спутник · утренняя сводка готова"
BUTTON = "Открыть сводку"


def env(name: str) -> str:
    value = os.environ.get(name, "").strip()
    if not value:
        sys.exit(f"Ошибка: не задана переменная {name}")
    return value


def main() -> None:
    token = env("TELEGRAM_BOT_TOKEN")
    chat_id = env("TELEGRAM_CHAT_ID")
    brief_url = env("BRIEF_URL")

    payload = {
        "chat_id": chat_id,
        "text": MESSAGE,
        "disable_web_page_preview": True,
        "reply_markup": {
            "inline_keyboard": [[{"text": BUTTON, "url": brief_url}]]
        },
    }

    request = urllib.request.Request(
        f"https://api.telegram.org/bot{token}/sendMessage",
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )

    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            result = json.load(response)
    except urllib.error.HTTPError as error:
        details = error.read().decode("utf-8", "replace")
        sys.exit(f"Telegram вернул ошибку {error.code}: {details}")
    except urllib.error.URLError as error:
        sys.exit(f"Не удалось связаться с Telegram: {error.reason}")

    if not result.get("ok"):
        sys.exit(f"Telegram не принял сообщение: {result}")

    print("Сообщение отправлено.")


if __name__ == "__main__":
    main()
