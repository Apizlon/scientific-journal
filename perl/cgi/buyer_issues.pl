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
if ($user->{role} ne 'buyer') {
    print redirect('/cgi-bin/index.pl');
    exit;
}

my $action = $cgi->param('action') // '';
if ($action eq 'add_to_cart') {
    my $issue_id = $cgi->param('issue_id') // '';
    if ($issue_id =~ /^\d+$/) {
        $dbh->do(
            'INSERT OR IGNORE INTO cart_items(user_id, issue_id, created_at) VALUES (?,?,?)',
            undef,
            $user->{id},
            $issue_id,
            Journal::DB::now_ts()
        );
    }
}

my $issues = $dbh->selectall_arrayref(
    q{
        SELECT id, number, year, title, price
        FROM issues
        WHERE status = 'published'
        ORDER BY year DESC, number DESC
    },
    { Slice => {} }
);

my $articles_by_issue = {};
if (@$issues) {
    my @issue_ids = map { $_->{id} } @$issues;
    my $placeholders = join(',', ('?') x @issue_ids);
    my $articles = $dbh->selectall_arrayref(
        qq{
            SELECT id, issue_id, title, abstract, author_name
            FROM articles
            WHERE issue_id IN ($placeholders) AND status = 'approved'
            ORDER BY id
        },
        { Slice => {} },
        @issue_ids
    );
    for my $article (@$articles) {
        push @{ $articles_by_issue->{ $article->{issue_id} } }, $article;
    }
}

my $html = '';
$html .= '<section class="card">';
$html .= '<h1>Выпуски</h1>';
$html .= '<p class="muted">Доступны все выпущенные номера журнала. Добавьте нужные в корзину.</p>';

if (!@$issues) {
    $html .= '<p>Пока нет опубликованных выпусков.</p>';
} else {
    for my $issue (@$issues) {
        my $label = '№' . $issue->{number} . ' (' . $issue->{year} . ')';
        my $title = escapeHTML(Journal::Web::clean_text($issue->{title}));
        my $articles = $articles_by_issue->{ $issue->{id} } || [];
        $html .= '<div class="issue-card">';
        $html .= "<div class=\"issue-header\"><div><h2>$label</h2><div class=\"muted\">$title</div></div>";
        $html .= '<div class="issue-meta">';
        $html .= '<div class="price">' . int($issue->{price}) . ' ₽</div>';
        $html .= qq{<form method="post">};
        $html .= qq{<input type="hidden" name="action" value="add_to_cart" />};
        $html .= qq{<input type="hidden" name="issue_id" value="$issue->{id}" />};
        $html .= qq{<button class="primary-btn" type="submit">В корзину</button>};
        $html .= '</form>';
        $html .= '</div></div>';
        if (!@$articles) {
            $html .= '<p class="muted">Статей пока нет.</p>';
        } else {
            $html .= '<div class="article-list">';
            for my $article (@$articles) {
                my $a_title = escapeHTML(Journal::Web::clean_text($article->{title}));
                my $a_abstract = escapeHTML(Journal::Web::clean_text($article->{abstract}));
                my $a_author = escapeHTML(Journal::Web::clean_text($article->{author_name}));
                $html .= '<div class="article-item">';
                $html .= "<h3>$a_title</h3>";
                $html .= "<p class=\"muted\">$a_abstract</p>";
                $html .= "<span class=\"badge\">$a_author</span>";
                $html .= '</div>';
            }
            $html .= '</div>';
        }
        $html .= '</div>';
    }
}

$html .= '</section>';

Journal::Web::render_page('Кабинет • Выпуски', $user, $html, { active => 'Выпуски' });
