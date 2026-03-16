# scientific-journal

## Запуск (Docker)
- **Требуется**: Docker + Docker Compose.
- **Данные**: лежат на хосте в `./data/` (папка в `.gitignore`) и переживают перезапуск контейнера.

### Старт
```bash
docker compose up --build
```

Откройте:
- `http://localhost:8080/` (главная: `static/index.html`)
- `http://localhost:8080/cgi-bin/issue.pl` (архив выпусков)

База создаётся автоматически при первом заходе в архив (файл: `./data/app.db`).

### Структура
- `static/` — статичные страницы (`*.html`)
- `assets/` — стили/скрипты/картинки
- `perl/cgi/` — серверные скрипты (`*.pl`, будут доступны как `/cgi-bin/...`)
- `perl/lib/` — общие Perl-модули
- `scripts/` — утилиты (инициализация БД и т.п.)
- `data/` — файлы базы (монтируется в контейнер как `/data`)
