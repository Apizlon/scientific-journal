#!/usr/bin/perl -CS
use strict;
use warnings;
use utf8;

use CGI qw(:standard);
use lib "/opt/app/lib";

use Journal::DB;
use Journal::Web;

binmode(STDIN,  ':utf8');
binmode(STDOUT, ':utf8');

my $cgi = CGI->new;
my $email    = $cgi->param('email')    // '';
my $password = $cgi->param('password') // '';

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
    print '<a class="primary-link" href="/login.html">Вернуться ко входу</a>';
    print '<a class="ghost-link" href="/register.html">Регистрация</a>';
    print '</div>';
    print '</div>';
    print '</div>';
    print end_html();
    exit;
}

if ($email eq '' || $password eq '') {
    render_error('Ошибка входа', 'Заполните почту и пароль.');
}

my $row = $dbh->selectrow_hashref(
    'SELECT id, email, password_hash, first_name, last_name, role FROM users WHERE email = ?',
    undef,
    $email
);

if (!$row || $row->{password_hash} ne $password) {
    render_error('Неверный логин или пароль', 'Проверьте данные или зарегистрируйтесь.');
}

my ($token) = Journal::Web::create_session($dbh, $row->{id});
my $cookie = Journal::Web::session_cookie($token);

print redirect(-uri => '/cgi-bin/index.pl', -cookie => $cookie);
