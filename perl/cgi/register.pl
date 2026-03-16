#!/usr/bin/perl -CS
use strict;
use warnings;
use utf8;

use CGI qw(:standard);
use lib "/opt/app/lib";

use Journal::DB;

binmode(STDIN,  ':utf8');
binmode(STDOUT, ':utf8');

$CGI::PARAM_UTF8 = 1;
my $cgi = CGI->new;

my $first_name = $cgi->param('first_name') // '';
my $last_name  = $cgi->param('last_name')  // '';
my $email      = $cgi->param('email')      // '';
my $password   = $cgi->param('password')   // '';

my $dbh = Journal::DB::connect_db();
Journal::DB::ensure_schema($dbh);
Journal::DB::seed_if_empty($dbh);

sub render_error {
    my ($title, $message) = @_;
    print header(-charset => 'utf-8');
    print start_html(
        -title    => $title,
        -lang     => 'ru',
        -encoding => 'utf-8',
        -style    => { src => '/assets/css/style.css' }
    );
    print '<div class="auth-shell">';
    print '<div class="auth-card">';
    print "<h1>$title</h1>";
    print "<p>$message</p>";
    print '<div class="auth-links">';
    print '<a class="primary-link" href="/register.html">Вернуться к регистрации</a>';
    print '<a class="ghost-link" href="/login.html">Войти</a>';
    print '</div>';
    print '</div>';
    print '</div>';
    print end_html();
    exit;
}

if ($first_name eq '' || $last_name eq '' || $email eq '' || $password eq '') {
    render_error('Ошибка регистрации', 'Все поля обязательны.');
}

my ($exists) = $dbh->selectrow_array(
    'SELECT COUNT(*) FROM users WHERE email = ?',
    undef,
    $email
);

if (($exists || 0) > 0) {
    render_error('Пользователь уже существует', 'Укажите другую почту.');
}

$dbh->do(
    'INSERT INTO users(email,password_hash,first_name,last_name,role,created_at) VALUES (?,?,?,?,?,?)',
    undef,
    $email,
    $password,
    $first_name,
    $last_name,
    'buyer',
    Journal::DB::now_ts()
);

print header(-charset => 'utf-8');
print start_html(
    -title    => 'Регистрация выполнена',
    -lang     => 'ru',
    -encoding => 'utf-8',
    -style    => { src => '/assets/css/style.css' }
);
print '<div class="auth-shell">';
print '<div class="auth-card">';
print '<h1>Регистрация выполнена</h1>';
print '<p>Теперь вы можете войти в систему.</p>';
print '<div class="auth-links">';
print '<a class="primary-link" href="/login.html">Перейти ко входу</a>';
print '</div>';
print '</div>';
print '</div>';
print end_html();
