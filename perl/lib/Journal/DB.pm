package Journal::DB;

use strict;
use warnings;
use utf8;

use DBI;

sub db_path {
    return $ENV{JOURNAL_DB_PATH} || '/data/app.db';
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

sub ensure_schema {
    my ($dbh) = @_;

    # Пользователи
    $dbh->do(q{
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT NOT NULL UNIQUE,
            password_hash TEXT NOT NULL,
            role TEXT NOT NULL CHECK(role IN ('buyer','editor','admin'))
        )
    });

    # Выпуски журнала
    $dbh->do(q{
        CREATE TABLE IF NOT EXISTS issues (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            number INTEGER NOT NULL,
            year INTEGER NOT NULL,
            published_at TEXT
        )
    });

    # Статьи
    $dbh->do(q{
        CREATE TABLE IF NOT EXISTS articles (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            issue_id INTEGER NOT NULL,
            title TEXT NOT NULL,
            abstract TEXT NOT NULL,
            price INTEGER NOT NULL DEFAULT 0,
            pdf_path TEXT,
            created_by_user_id INTEGER,
            FOREIGN KEY(issue_id) REFERENCES issues(id) ON DELETE CASCADE,
            FOREIGN KEY(created_by_user_id) REFERENCES users(id) ON DELETE SET NULL
        )
    });

    # Тематики
    $dbh->do(q{
        CREATE TABLE IF NOT EXISTS themes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE
        )
    });

    # Связь статья-тематика
    $dbh->do(q{
        CREATE TABLE IF NOT EXISTS article_themes (
            article_id INTEGER NOT NULL,
            theme_id INTEGER NOT NULL,
            PRIMARY KEY(article_id, theme_id),
            FOREIGN KEY(article_id) REFERENCES articles(id) ON DELETE CASCADE,
            FOREIGN KEY(theme_id) REFERENCES themes(id) ON DELETE CASCADE
        )
    });

    # Заказы
    $dbh->do(q{
        CREATE TABLE IF NOT EXISTS orders (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            status TEXT NOT NULL DEFAULT 'new',
            total_amount INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL,
            FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
        )
    });

    # Позиции заказа
    $dbh->do(q{
        CREATE TABLE IF NOT EXISTS order_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            order_id INTEGER NOT NULL,
            article_id INTEGER NOT NULL,
            price INTEGER NOT NULL,
            FOREIGN KEY(order_id) REFERENCES orders(id) ON DELETE CASCADE,
            FOREIGN KEY(article_id) REFERENCES articles(id) ON DELETE CASCADE
        )
    });

    # Подачи тезисов / статей
    $dbh->do(q{
        CREATE TABLE IF NOT EXISTS submissions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            title TEXT NOT NULL,
            abstract TEXT NOT NULL,
            file_path TEXT,
            status TEXT NOT NULL DEFAULT 'new',
            created_at TEXT NOT NULL,
            FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
        )
    });
}

sub seed_if_empty {
    my ($dbh) = @_;

    my ($users_count) = $dbh->selectrow_array('SELECT COUNT(*) FROM users');
    if (($users_count || 0) == 0) {
        $dbh->do(
            'INSERT INTO users(username,password_hash,role) VALUES (?,?,?)',
            undef,
            'admin',
            'admin',
            'admin'
        );
    }

    my ($issues_count) = $dbh->selectrow_array('SELECT COUNT(*) FROM issues');
    if (($issues_count || 0) == 0) {
        $dbh->do('INSERT INTO issues(number,year,published_at) VALUES (?,?,datetime("now"))', undef, 1, 2026);
        $dbh->do('INSERT INTO issues(number,year,published_at) VALUES (?,?,datetime("now"))', undef, 2, 2026);
    }

    my ($themes_count) = $dbh->selectrow_array('SELECT COUNT(*) FROM themes');
    if (($themes_count || 0) == 0) {
        $dbh->do('INSERT INTO themes(name) VALUES (?)', undef, 'Информатика');
        $dbh->do('INSERT INTO themes(name) VALUES (?)', undef, 'Физика');
        $dbh->do('INSERT INTO themes(name) VALUES (?)', undef, 'Математика');
    }

    my ($articles_count) = $dbh->selectrow_array('SELECT COUNT(*) FROM articles');
    if (($articles_count || 0) == 0) {
        $dbh->do(
            'INSERT INTO articles(issue_id,title,abstract,price,pdf_path,created_by_user_id) VALUES (?,?,?,?,?,?)',
            undef,
            1,
            'Пример статьи №1',
            'Короткие тезисы/аннотация для примера (SQLite).',
            150,
            undef,
            1
        );
        $dbh->do(
            'INSERT INTO articles(issue_id,title,abstract,price,pdf_path,created_by_user_id) VALUES (?,?,?,?,?,?)',
            undef,
            1,
            'Пример статьи №2',
            'Ещё один пример аннотации (SQLite).',
            50,
            undef,
            1
        );
    }
}

1;

