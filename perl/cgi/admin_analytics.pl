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
my $dbh = Journal::DB::connect_db();
Journal::DB::ensure_schema($dbh);
Journal::DB::seed_if_empty($dbh);

my $user = Journal::Web::require_login($cgi, $dbh);
if ($user->{role} ne 'admin') {
    print redirect('/cgi-bin/index.pl');
    exit;
}

my $issues_stats = $dbh->selectall_arrayref(
    q{
        SELECT i.id, i.title,
               SUM(CASE WHEN o.status = 'paid' THEN 1 ELSE 0 END) AS sales_count,
               SUM(CASE WHEN o.status = 'paid' THEN oi.price ELSE 0 END) AS revenue
        FROM issues i
        LEFT JOIN order_items oi ON oi.issue_id = i.id
        LEFT JOIN orders o ON o.id = oi.order_id
        GROUP BY i.id
        ORDER BY i.year DESC, i.number DESC
    },
    { Slice => {} }
);

my $author_stats = $dbh->selectall_arrayref(
    q{
        SELECT a.author_name,
               SUM(CASE WHEN o.status = 'paid' THEN 1 ELSE 0 END) AS sales_count
        FROM articles a
        LEFT JOIN issues i ON i.id = a.issue_id
        LEFT JOIN order_items oi ON oi.issue_id = i.id
        LEFT JOIN orders o ON o.id = oi.order_id
        GROUP BY a.author_name
        ORDER BY sales_count DESC, a.author_name
    },
    { Slice => {} }
);

my $theme_stats = $dbh->selectall_arrayref(
    q{
        SELECT t.name AS theme_name,
               SUM(CASE WHEN o.status = 'paid' THEN 1 ELSE 0 END) AS sales_count
        FROM articles a
        JOIN themes t ON t.id = a.theme_id
        LEFT JOIN issues i ON i.id = a.issue_id
        LEFT JOIN order_items oi ON oi.issue_id = i.id
        LEFT JOIN orders o ON o.id = oi.order_id
        GROUP BY t.name
        ORDER BY sales_count DESC, t.name
    },
    { Slice => {} }
);

my $html = '';
$html .= '<section class="card">';
$html .= '<h1>Аналитика</h1>';
$html .= '<p class="muted">Статистика продаваемости по выпускам, авторам и тематикам.</p>';

$html .= '<h2>По выпускам</h2>';
$html .= '<div class="table-wrap">';
$html .= '<table class="data-table">';
$html .= '<thead><tr><th>Выпуск</th><th>Продажи</th><th>Выручка</th></tr></thead><tbody>';
for my $row (@$issues_stats) {
    my $title = escapeHTML($row->{title});
    my $count = $row->{sales_count} || 0;
    my $revenue = $row->{revenue} || 0;
    $html .= "<tr><td>$title</td><td>$count</td><td>$revenue ₽</td></tr>";
}
$html .= '</tbody></table></div>';

$html .= '<h2>По авторам</h2>';
$html .= '<div class="table-wrap">';
$html .= '<table class="data-table">';
$html .= '<thead><tr><th>Автор</th><th>Продажи</th></tr></thead><tbody>';
for my $row (@$author_stats) {
    my $name = escapeHTML($row->{author_name});
    my $count = $row->{sales_count} || 0;
    $html .= "<tr><td>$name</td><td>$count</td></tr>";
}
$html .= '</tbody></table></div>';

$html .= '<h2>По тематикам</h2>';
$html .= '<div class="table-wrap">';
$html .= '<table class="data-table">';
$html .= '<thead><tr><th>Тематика</th><th>Продажи</th></tr></thead><tbody>';
for my $row (@$theme_stats) {
    my $name = escapeHTML($row->{theme_name});
    my $count = $row->{sales_count} || 0;
    $html .= "<tr><td>$name</td><td>$count</td></tr>";
}
$html .= '</tbody></table></div>';
$html .= '</section>';

Journal::Web::render_page('Админ • Аналитика', $user, $html, { active => 'Аналитика' });
