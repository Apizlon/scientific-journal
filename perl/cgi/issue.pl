#!/usr/bin/perl -CS
use strict;
use warnings;
use utf8;

use CGI qw(:standard);
use lib "/opt/app/lib";

use Journal::DB;

binmode(STDIN,  ':utf8');
binmode(STDOUT, ':utf8');

print header(-charset => 'utf-8');

my $dbh = Journal::DB::connect_db();
Journal::DB::ensure_schema($dbh);
Journal::DB::seed_if_empty($dbh);

my $issue_id = param('issue');
$issue_id = undef if defined($issue_id) && $issue_id !~ /^\d+$/;

my $issues = $dbh->selectall_arrayref(
    'SELECT id, number, year, COALESCE(published_at, "") AS published_at FROM issues ORDER BY year DESC, number DESC',
    { Slice => {} }
);

my $articles;
if (defined $issue_id) {
    $articles = $dbh->selectall_arrayref(
        'SELECT id, title, abstract, price FROM articles WHERE issue_id = ? ORDER BY id DESC',
        { Slice => {} },
        $issue_id
    );
}

print start_html(
    -title    => 'Архив выпусков',
    -lang     => 'ru',
    -encoding => 'utf-8',
    -style    => { src => '/assets/css/style.css' }
);

print '<body class="page with-bg">';
print '<div class="container">';
print '<header class="site-header">';
print h1('Архив выпусков');
print '<nav class="nav">';
print a({ href => '/index.html' }, 'Главная');
print a({ href => '/issues.html' }, 'Выпуски');
print '</nav>';
print '</header>';

print '<main class="card">';
print p('Выберите выпуск, чтобы посмотреть список материалов.');

print '<h2>Список выпусков</h2>';
print '<ul>';
for my $it (@$issues) {
    my $label = 'Выпуск №' . $it->{number} . ' (' . $it->{year} . ')';
    print '<li>' . a({ href => '/cgi-bin/issue.pl?issue=' . $it->{id} }, $label) . '</li>';
}
print '</ul>';

print '<hr />';

if (defined $issue_id) {
    print '<h2>Статьи выпуска</h2>';
    if (!$articles || !@$articles) {
        print p('Пока нет статей.');
    } else {
        for my $a (@$articles) {
            print '<div style="margin: 12px 0; padding: 12px; background: white; border-radius: 12px; border: 1px solid rgba(148,163,184,0.35);">';
            print '<h3 style="margin:0 0 6px 0;">' . escapeHTML($a->{title}) . '</h3>';
            print '<p style="margin:0 0 6px 0; color:#475569;">' . escapeHTML($a->{abstract}) . '</p>';
            print '<p style="margin:0;"><strong>Цена:</strong> ' . int($a->{price}) . ' ₽</p>';
            print '</div>';
        }
    }

    print '<button type="button" onclick="showHint()" style="margin-top: 10px;">Подробнее</button>';
    print qq{<script>function showHint(){alert("Для оформления заказа добавьте материалы в корзину.");}</script>};
}

print '<p class="links">' . a({ href => '/index.html' }, 'На главную') . '</p>';
print '</main>';
print '</div>';
print '</body>';
print end_html();

