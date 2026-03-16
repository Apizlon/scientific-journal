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
        -title    => 'Ошибка входа',
        -lang     => 'ru',
        -encoding => 'utf-8',
        -style    => { src => '/assets/css/style.css' }
    );
    print '<div class="container"><main class="card">';
    print h1('Ошибка входа');
    print p('Заполните логин и пароль.');
    print p( a( { href => '/login.html' }, 'Вернуться ко входу' ) );
    print p( a( { href => '/index.html' }, 'На главную' ) );
    print '</main></div>';
    print end_html();
    exit;
}

my $dbh = Journal::DB::connect_db();
Journal::DB::ensure_schema($dbh);

my $row = $dbh->selectrow_hashref(
    'SELECT id, username, password_hash, role FROM users WHERE username = ?',
    undef,
    $login
);

if ($row && $row->{password_hash} eq $password) {
    # Простейший вариант: пробрасываем пользователя через query param (как в quiz-примере)
    my $user = $row->{username};
    print start_html(
        -title    => 'Успешный вход',
        -lang     => 'ru',
        -encoding => 'utf-8',
        -style    => { src => '/assets/css/style.css' }
    );
    print '<div class="container"><main class="card">';
    print h1("Добро пожаловать, $user!");
    print p( qq{Вы можете перейти к выпускам или продолжить просмотр сайта.} );
    print p( a( { href => '/cgi-bin/issue.pl' }, 'Список выпусков (CGI)' ) );
    print p( a( { href => '/index.html' }, 'На главную' ) );
    print '</main></div>';
    print end_html();
}
else {
    print start_html(
        -title    => 'Неверный логин или пароль',
        -lang     => 'ru',
        -encoding => 'utf-8',
        -style    => { src => '/assets/css/style.css' }
    );
    print '<div class="container"><main class="card">';
    print h1('Неверный логин или пароль');
    print p('Проверьте данные или зарегистрируйтесь.');
    print p( a( { href => '/login.html' }, 'Вернуться ко входу' ) );
    print p( a( { href => '/register.html' }, 'Регистрация' ) );
    print '</main></div>';
    print end_html();
}

