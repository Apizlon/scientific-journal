#!/usr/bin/perl -CS
use strict;
use warnings;
use utf8;

use CGI qw(:standard);
use lib "/opt/app/lib";

use Journal::DB;

binmode(STDIN,  ':utf8');
binmode(STDOUT, ':utf8');

my $login    = param('login')    // '';
my $password = param('password') // '';

print header(-charset => 'utf-8');

if ($login eq '' || $password eq '') {
    print start_html(
        -title    => 'Ошибка регистрации',
        -lang     => 'ru',
        -encoding => 'utf-8',
        -style    => { src => '/assets/css/style.css' }
    );
    print '<div class="container"><main class="card">';
    print h1('Ошибка регистрации');
    print p('Заполните логин и пароль.');
    print p( a( { href => '/register.html' }, 'Вернуться к регистрации' ) );
    print p( a( { href => '/index.html' }, 'На главную' ) );
    print '</main></div>';
    print end_html();
    exit;
}

if ( length($login) < 3 || length($password) < 3 ) {
    print start_html(
        -title    => 'Ошибка регистрации',
        -lang     => 'ru',
        -encoding => 'utf-8',
        -style    => { src => '/assets/css/style.css' }
    );
    print '<div class="container"><main class="card">';
    print h1('Ошибка регистрации');
    print p('Логин и пароль должны быть не короче 3 символов.');
    print p( a( { href => '/register.html' }, 'Вернуться к регистрации' ) );
    print p( a( { href => '/index.html' }, 'На главную' ) );
    print '</main></div>';
    print end_html();
    exit;
}

my $dbh = Journal::DB::connect_db();
Journal::DB::ensure_schema($dbh);

my ($exists) = $dbh->selectrow_array(
    'SELECT COUNT(*) FROM users WHERE username = ?',
    undef,
    $login
);

if ( ($exists || 0) > 0 ) {
    print start_html(
        -title    => 'Ошибка регистрации',
        -lang     => 'ru',
        -encoding => 'utf-8',
        -style    => { src => '/assets/css/style.css' }
    );
    print '<div class="container"><main class="card">';
    print h1("Пользователь '$login' уже существует");
    print p('Выберите другой логин.');
    print p( a( { href => '/register.html' }, 'Вернуться к регистрации' ) );
    print p( a( { href => '/index.html' }, 'На главную' ) );
    print '</main></div>';
    print end_html();
    exit;
}

# Простейший вариант: храним пароль как есть (аналогично эталонной работе).
$dbh->do(
    'INSERT INTO users(username, password_hash, role) VALUES (?,?,?)',
    undef,
    $login,
    $password,
    'buyer'
);

print start_html(
    -title    => 'Регистрация выполнена',
    -lang     => 'ru',
    -encoding => 'utf-8',
    -style    => { src => '/assets/css/style.css' }
);
print '<div class="container"><main class="card">';
print h1("Пользователь '$login' зарегистрирован");
print p( a( { href => '/login.html' }, 'Перейти ко входу' ) );
print p( a( { href => '/index.html' }, 'На главную' ) );
print '</main></div>';
print end_html();

