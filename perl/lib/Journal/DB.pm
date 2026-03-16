package Journal::DB;

use strict;
use warnings;
use utf8;

use DBI;
use POSIX qw(strftime);

sub db_path {
    return $ENV{JOURNAL_DB_PATH} || '/data/app.db';
}

sub now_ts {
    return strftime('%Y-%m-%d %H:%M:%S', localtime);
}

sub connect_db {
    my $path = db_path();
    my $dbh = DBI->connect(
        "dbi:SQLite:dbname=$path",
        "",
        "",
        {
            RaiseError                       => 1,
            PrintError                       => 0,
            sqlite_unicode                   => 1,
            sqlite_use_immediate_transaction => 1,
        }
    );
    $dbh->do('PRAGMA foreign_keys = ON');
    return $dbh;
}

sub table_exists {
    my ($dbh, $table) = @_;
    my ($exists) = $dbh->selectrow_array(
        'SELECT COUNT(*) FROM sqlite_master WHERE type = ? AND name = ?',
        undef,
        'table',
        $table
    );
    return ($exists || 0) > 0;
}

sub ensure_version {
    my ($dbh, $version) = @_;

    if (!table_exists($dbh, 'schema_version')) {
        $dbh->do('CREATE TABLE schema_version (version INTEGER NOT NULL)');
        $dbh->do('INSERT INTO schema_version(version) VALUES (?)', undef, $version);
        return;
    }

    my ($current) = $dbh->selectrow_array('SELECT version FROM schema_version LIMIT 1');
    $current ||= 0;
    if ($current < $version) {
        $dbh->do('UPDATE schema_version SET version = ?', undef, $version);
    }
}

sub ensure_schema {
    my ($dbh) = @_;

    my $schema_version = 3;
    my $needs_recreate = 0;

    if (!table_exists($dbh, 'schema_version')) {
        $needs_recreate = 1;
    }

    if (!$needs_recreate) {
        my ($current) = $dbh->selectrow_array('SELECT version FROM schema_version LIMIT 1');
        $current ||= 0;
        if ($current < $schema_version) {
            $needs_recreate = 1;
        }
    }

    if ($needs_recreate) {
        $dbh->do('PRAGMA foreign_keys = OFF');
        for my $table (qw(
            sessions
            cart_items
            order_items
            orders
            articles
            themes
            issues
            users
        )) {
            next unless table_exists($dbh, $table);
            $dbh->do("DROP TABLE $table");
        }
        $dbh->do('PRAGMA foreign_keys = ON');
    }

    $dbh->do(q{
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            email TEXT NOT NULL UNIQUE,
            password_hash TEXT NOT NULL,
            first_name TEXT NOT NULL,
            last_name TEXT NOT NULL,
            role TEXT NOT NULL CHECK(role IN ('buyer','editor','admin')),
            created_at TEXT NOT NULL
        )
    });

    $dbh->do(q{
        CREATE TABLE IF NOT EXISTS sessions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            token TEXT NOT NULL UNIQUE,
            created_at TEXT NOT NULL,
            expires_at TEXT NOT NULL,
            FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
        )
    });

    $dbh->do(q{
        CREATE TABLE IF NOT EXISTS issues (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            number INTEGER NOT NULL,
            year INTEGER NOT NULL,
            title TEXT NOT NULL,
            status TEXT NOT NULL CHECK(status IN ('draft','published')),
            price INTEGER NOT NULL DEFAULT 0,
            published_at TEXT
        )
    });

    $dbh->do(q{
        CREATE TABLE IF NOT EXISTS themes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE
        )
    });

    $dbh->do(q{
        CREATE TABLE IF NOT EXISTS articles (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            issue_id INTEGER,
            title TEXT NOT NULL,
            abstract TEXT NOT NULL,
            content TEXT NOT NULL,
            author_name TEXT NOT NULL,
            theme_id INTEGER NOT NULL,
            status TEXT NOT NULL CHECK(status IN ('pending','approved','rejected')),
            created_by_user_id INTEGER,
            created_at TEXT NOT NULL,
            FOREIGN KEY(issue_id) REFERENCES issues(id) ON DELETE SET NULL,
            FOREIGN KEY(theme_id) REFERENCES themes(id) ON DELETE RESTRICT,
            FOREIGN KEY(created_by_user_id) REFERENCES users(id) ON DELETE SET NULL
        )
    });

    $dbh->do(q{
        CREATE TABLE IF NOT EXISTS orders (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            status TEXT NOT NULL CHECK(status IN ('pending','paid')),
            total_amount INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL,
            FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
        )
    });

    $dbh->do(q{
        CREATE TABLE IF NOT EXISTS order_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            order_id INTEGER NOT NULL,
            issue_id INTEGER NOT NULL,
            price INTEGER NOT NULL,
            FOREIGN KEY(order_id) REFERENCES orders(id) ON DELETE CASCADE,
            FOREIGN KEY(issue_id) REFERENCES issues(id) ON DELETE CASCADE
        )
    });

    $dbh->do(q{
        CREATE TABLE IF NOT EXISTS cart_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            issue_id INTEGER NOT NULL,
            created_at TEXT NOT NULL,
            UNIQUE(user_id, issue_id),
            FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE,
            FOREIGN KEY(issue_id) REFERENCES issues(id) ON DELETE CASCADE
        )
    });

    ensure_version($dbh, $schema_version);
}

sub seed_if_empty {
    my ($dbh) = @_;

    my ($users_count) = $dbh->selectrow_array('SELECT COUNT(*) FROM users');
    if (($users_count || 0) == 0) {
        $dbh->do(
            'INSERT INTO users(email,password_hash,first_name,last_name,role,created_at) VALUES (?,?,?,?,?,?)',
            undef,
            'admin',
            'admin',
            'Админ',
            'Системный',
            'admin',
            now_ts()
        );
        $dbh->do(
            'INSERT INTO users(email,password_hash,first_name,last_name,role,created_at) VALUES (?,?,?,?,?,?)',
            undef,
            'redact',
            'redact',
            'Редактор',
            'Коллегии',
            'editor',
            now_ts()
        );
    }

    my ($issues_count) = $dbh->selectrow_array('SELECT COUNT(*) FROM issues');
    if (($issues_count || 0) == 0) {
        $dbh->do(
            'INSERT INTO issues(number,year,title,status,price,published_at) VALUES (?,?,?,?,?,?)',
            undef,
            1,
            2026,
            'Выпуск 1. Цифровые исследования',
            'published',
            390,
            now_ts()
        );
        $dbh->do(
            'INSERT INTO issues(number,year,title,status,price,published_at) VALUES (?,?,?,?,?,?)',
            undef,
            2,
            2026,
            'Выпуск 2. Новые материалы',
            'published',
            420,
            now_ts()
        );
        $dbh->do(
            'INSERT INTO issues(number,year,title,status,price) VALUES (?,?,?,?,?)',
            undef,
            3,
            2026,
            'Выпуск 3. На согласовании',
            'draft',
            450
        );
    }

    my ($themes_count) = $dbh->selectrow_array('SELECT COUNT(*) FROM themes');
    if (($themes_count || 0) == 0) {
        $dbh->do('INSERT INTO themes(name) VALUES (?)', undef, 'Информатика');
        $dbh->do('INSERT INTO themes(name) VALUES (?)', undef, 'Физика');
        $dbh->do('INSERT INTO themes(name) VALUES (?)', undef, 'Математика');
        $dbh->do('INSERT INTO themes(name) VALUES (?)', undef, 'Биотехнологии');
        $dbh->do('INSERT INTO themes(name) VALUES (?)', undef, 'Материаловедение');
        $dbh->do('INSERT INTO themes(name) VALUES (?)', undef, 'Экология');
    }

    my ($articles_count) = $dbh->selectrow_array('SELECT COUNT(*) FROM articles');
    if (($articles_count || 0) == 0) {
        $dbh->do(
            'INSERT INTO articles(issue_id,title,abstract,content,author_name,theme_id,status,created_by_user_id,created_at) VALUES (?,?,?,?,?,?,?,?,?)',
            undef,
            1,
            'Методы анализа больших данных',
            'Краткие тезисы о новых подходах к обработке наборов данных.',
            'Полный текст статьи о методах анализа больших данных и практических сценариях.',
            'Илья Савин',
            1,
            'approved',
            1,
            now_ts()
        );
        $dbh->do(
            'INSERT INTO articles(issue_id,title,abstract,content,author_name,theme_id,status,created_by_user_id,created_at) VALUES (?,?,?,?,?,?,?,?,?)',
            undef,
            1,
            'Материалы для гибких датчиков',
            'Обзор разработки тонкопленочных сенсоров и перспективы использования.',
            'Подробный обзор свойств материалов и применяемых технологий для гибких датчиков.',
            'Мария Белова',
            5,
            'approved',
            1,
            now_ts()
        );
        $dbh->do(
            'INSERT INTO articles(issue_id,title,abstract,content,author_name,theme_id,status,created_by_user_id,created_at) VALUES (?,?,?,?,?,?,?,?,?)',
            undef,
            2,
            'Экологический мониторинг городов',
            'Краткое описание модели оценки загрязнения.',
            'Полный текст о методах сбора данных и моделировании загрязнения.',
            'Никита Орлов',
            6,
            'approved',
            1,
            now_ts()
        );
    }
}

1;
