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

BEGIN { $CGI::PARAM_UTF8 = 1; }
my $cgi = CGI->new;
my $dbh = Journal::DB::connect_db();
Journal::DB::ensure_schema($dbh);
Journal::DB::seed_if_empty($dbh);

my $user = Journal::Web::require_login($cgi, $dbh);
if ($user->{role} ne 'editor') {
    print redirect('/cgi-bin/index.pl');
    exit;
}

my $action = $cgi->param('action') // '';
if ($action eq 'create_issue') {
    my $number = $cgi->param('number') // '';
    my $year = $cgi->param('year') // '';
    my $title = $cgi->param('title') // '';
    my $price = $cgi->param('price') // '';
    if ($number =~ /^\d+$/ && $year =~ /^\d+$/ && $title ne '' && $price =~ /^\d+$/) {
        $dbh->do(
            'INSERT INTO issues(number, year, title, status, price) VALUES (?,?,?,?,?)',
            undef,
            $number,
            $year,
            $title,
            'draft',
            $price
        );
    }
}

if ($action eq 'publish') {
    my $issue_id = $cgi->param('issue_id') // '';
    if ($issue_id =~ /^\d+$/) {
        $dbh->do(
            'UPDATE issues SET status = ?, published_at = ? WHERE id = ?',
            undef,
            'published',
            Journal::DB::now_ts(),
            $issue_id
        );
    }
}

my $issues = $dbh->selectall_arrayref(
    q{
        SELECT i.id, i.number, i.year, i.title, i.status, i.price,
               COUNT(a.id) AS articles_count
        FROM issues i
        LEFT JOIN articles a ON a.issue_id = i.id AND a.status = 'approved'
        GROUP BY i.id
        ORDER BY i.year DESC, i.number DESC
    },
    { Slice => {} }
);

my $html = '';
$html .= '<section class="card">';
$html .= '<h1>Выпуски</h1>';
$html .= '<p class="muted">Создавайте выпуски и переводите их в статус «Выпущен».</p>';

$html .= '<div class="form-grid">';
$html .= '<form method="post" class="panel">';
$html .= '<input type="hidden" name="action" value="create_issue" />';
$html .= '<h3>Новый выпуск</h3>';
$html .= '<label>Номер<input type="number" name="number" min="1" required></label>';
$html .= '<label>Год<input type="number" name="year" min="2000" max="2100" required></label>';
$html .= '<label>Название<input type="text" name="title" required></label>';
$html .= '<label>Цена, ₽<input type="number" name="price" min="0" required></label>';
$html .= '<button class="primary-btn" type="submit">Создать выпуск</button>';
$html .= '</form>';
$html .= '</div>';

if (!@$issues) {
    $html .= '<p>Нет выпусков.</p>';
} else {
    $html .= '<div class="table-wrap">';
    $html .= '<table class="data-table">';
    $html .= '<thead><tr><th>Выпуск</th><th>Статус</th><th>Статей</th><th>Цена</th><th>Действие</th></tr></thead><tbody>';
    for my $row (@$issues) {
        my $label = '№' . $row->{number} . ' (' . $row->{year} . ')';
        my $title = escapeHTML(Journal::Web::clean_text($row->{title}));
        my $status_label = $row->{status} eq 'published' ? 'Выпущен' : 'Формируется';
        $html .= '<tr>';
        $html .= "<td><strong>$label</strong><div class=\"muted small\">$title</div></td>";
        $html .= "<td>$status_label</td>";
        $html .= '<td>' . ($row->{articles_count} || 0) . '</td>';
        $html .= '<td>' . int($row->{price}) . ' ₽</td>';
        $html .= '<td>';
        if ($row->{status} eq 'draft') {
            $html .= qq{<form method="post" class="inline-form">};
            $html .= qq{<input type="hidden" name="action" value="publish" />};
            $html .= qq{<input type="hidden" name="issue_id" value="$row->{id}" />};
            $html .= qq{<button class="primary-btn" type="submit">Выпустить</button>};
            $html .= '</form>';
        } else {
            $html .= '<span class="muted">Опубликован</span>';
        }
        $html .= '</td>';
        $html .= '</tr>';
    }
    $html .= '</tbody></table></div>';
}

$html .= '</section>';

Journal::Web::render_page('Редколлегия • Выпуски', $user, $html, { active => 'Выпуски' });
