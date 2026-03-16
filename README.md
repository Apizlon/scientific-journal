# scientific-journal

## Запуск (Docker)
- **Требуется**: Docker + Docker Compose.
- **Данные SQLite**: лежат на хосте в `./data/` (папка в `.gitignore`) и переживают перезапуск контейнера.

### Старт
```bash
docker compose up --build
```

Откройте:
- `http://localhost:8080/` (главная: `static/index.html`)
- `http://localhost:8080/cgi-bin/issue.pl` (динамика CGI + SQLite)

SQLite создаётся автоматически при первом заходе на CGI (файл: `./data/app.db`).

### Структура
- `static/` — статичные страницы (`*.html`)
- `assets/` — стили/JS/картинки
- `perl/cgi/` — CGI-скрипты (`*.pl`, будут доступны как `/cgi-bin/...`)
- `perl/lib/` — общие Perl-модули
- `scripts/` — утилиты (инициализация БД и т.п.)
- `data/` — SQLite-файлы (монтируется в контейнер как `/data`)
