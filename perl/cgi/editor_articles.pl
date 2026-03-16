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
if ($user->{role} ne 'editor') {
    print redirect('/cgi-bin/index.pl');
    exit;
}

my $action = $cgi->param('action') // '';
if ($action eq 'set_status') {
    my $article_id = $cgi->param('article_id') // '';
    my $status = $cgi->param('status') // '';
    if ($article_id =~ /^\d+$/ && $status =~ /^(pending|approved|rejected)$/) {
        $dbh->do('UPDATE articles SET status = ? WHERE id = ?', undef, $status, $article_id);
    }
}

if ($action eq 'assign_issue') {
    my $article_id = $cgi->param('article_id') // '';
    my $issue_id = $cgi->param('issue_id') // '';
    if ($article_id =~ /^\d+$/ && $issue_id =~ /^\d+$/) {
        my ($status) = $dbh->selectrow_array('SELECT status FROM articles WHERE id = ?', undef, $article_id);
        if ($status && $status eq 'approved') {
            $dbh->do('UPDATE articles SET issue_id = ? WHERE id = ?', undef, $issue_id, $article_id);
        }
    }
}

my $draft_issues = $dbh->selectall_arrayref(
    'SELECT id, number, year, title FROM issues WHERE status = ? ORDER BY year DESC, number DESC',
    { Slice => {} },
    'draft'
);

my $articles = $dbh->selectall_arrayref(
    q{
        SELECT a.id, a.title, a.abstract, a.author_name, a.status,
               t.name AS theme_name,
               i.title AS issue_title
        FROM articles a
        JOIN themes t ON t.id = a.theme_id
        LEFT JOIN issues i ON i.id = a.issue_id
        ORDER BY a.created_at DESC
    },
    { Slice => {} }
);

my $html = '';
$html .= '<section class="card">';
$html .= '<h1>Статьи</h1>';
$html .= '<p class="muted">Управляйте публикациями и назначайте утверждённые статьи в формируемые выпуски.</p>';

if (!@$articles) {
    $html .= '<p>Нет статей для отображения.</p>';
} else {
    $html .= '<div class="table-wrap">';
    $html .= '<table class="data-table">';
    $html .= '<thead><tr><th>Статья</th><th>Автор</th><th>Тематика</th><th>Статус</th><th>Выпуск</th><th>Действие</th></tr></thead><tbody>';
    for my $row (@$articles) {
        my $title = escapeHTML(Journal::Web::clean_text($row->{title}));
        my $author = escapeHTML(Journal::Web::clean_text($row->{author_name}));
        my $theme = escapeHTML(Journal::Web::clean_text($row->{theme_name}));
        my $issue_title = $row->{issue_title} ? escapeHTML(Journal::Web::clean_text($row->{issue_title})) : '—';
        my $status = $row->{status};
        $html .= '<tr>';
        $html .= "<td><strong>$title</strong><div class=\"muted small\">" . escapeHTML(Journal::Web::clean_text($row->{abstract})) . "</div></td>";
        $html .= "<td>$author</td>";
        $html .= "<td>$theme</td>";
        $html .= '<td>';
        $html .= qq{<form method="post" class="inline-form">};
        $html .= qq{<input type="hidden" name="action" value="set_status" />};
        $html .= qq{<input type="hidden" name="article_id" value="$row->{id}" />};
        $html .= '<select name="status">';
        for my $opt (['pending','На проверке'], ['approved','Утверждена'], ['rejected','Отклонена']) {
            my ($value, $label) = @$opt;
            my $selected = ($status eq $value) ? 'selected' : '';
            $html .= qq{<option value="$value" $selected>$label</option>};
        }
        $html .= '</select>';
        $html .= '<button class="ghost-btn" type="submit">Ок</button>';
        $html .= '</form>';
        $html .= '</td>';
        $html .= "<td>$issue_title</td>";
        $html .= '<td>';
        if (@$draft_issues) {
            $html .= qq{<form method="post" class="inline-form">};
            $html .= qq{<input type="hidden" name="action" value="assign_issue" />};
            $html .= qq{<input type="hidden" name="article_id" value="$row->{id}" />};
            $html .= '<select name="issue_id">';
            for my $issue (@$draft_issues) {
                my $label = '№' . $issue->{number} . ' (' . $issue->{year} . ')';
                $html .= qq{<option value="$issue->{id}">$label</option>};
            }
            $html .= '</select>';
            $html .= '<button class="primary-btn" type="submit">Назначить</button>';
            $html .= '</form>';
        } else {
            $html .= '<span class="muted">Нет формируемых выпусков</span>';
        }
        $html .= '</td>';
        $html .= '</tr>';
    }
    $html .= '</tbody></table></div>';
}

$html .= '</section>';

Journal::Web::render_page('Редколлегия • Статьи', $user, $html, { active => 'Статьи' });
