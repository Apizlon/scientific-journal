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
if ($action eq 'submit_article') {
    my $title = $cgi->param('title') // '';
    my $abstract = $cgi->param('abstract') // '';
    my $content = $cgi->param('content') // '';
    my $author_name = $cgi->param('author_name') // '';
    my $theme_id = $cgi->param('theme_id') // '';
    if ($title ne '' && $abstract ne '' && $content ne '' && $author_name ne '' && $theme_id =~ /^\d+$/) {
        $dbh->do(
            'INSERT INTO articles(title, abstract, content, author_name, theme_id, status, created_by_user_id, created_at) VALUES (?,?,?,?,?,?,?,?)',
            undef,
            $title,
            $abstract,
            $content,
            $author_name,
            $theme_id,
            'pending',
            $user->{id},
            Journal::DB::now_ts()
        );
    }
}

my $themes = $dbh->selectall_arrayref(
    'SELECT id, name FROM themes ORDER BY name',
    { Slice => {} }
);

my $submissions = $dbh->selectall_arrayref(
    q{
        SELECT a.title, a.abstract, a.status, t.name AS theme_name
        FROM articles a
        JOIN themes t ON t.id = a.theme_id
        WHERE a.created_by_user_id = ?
        ORDER BY a.created_at DESC
    },
    { Slice => {} },
    $user->{id}
);

my $html = '';
$html .= '<section class="card">';
$html .= '<h1>Заявки на публикацию</h1>';
$html .= '<p class="muted">Отправьте статью в редакцию и отслеживайте статус рассмотрения.</p>';

$html .= '<form method="post" class="panel">';
$html .= '<input type="hidden" name="action" value="submit_article" />';
$html .= '<h3>Новая заявка</h3>';
$html .= '<label>Название статьи<input type="text" name="title" required></label>';
$html .= '<label>Автор<input type="text" name="author_name" required></label>';
$html .= '<label>Тематика<select name="theme_id" required>';
for my $theme (@$themes) {
    my $name = escapeHTML($theme->{name});
    $html .= qq{<option value="$theme->{id}">$name</option>};
}
$html .= '</select></label>';
$html .= '<label>Краткие тезисы<textarea name="abstract" rows="4" required></textarea></label>';
$html .= '<label>Полный текст<textarea name="content" rows="6" required></textarea></label>';
$html .= '<button class="primary-btn" type="submit">Отправить</button>';
$html .= '</form>';

if (!@$submissions) {
    $html .= '<p>Вы ещё не подавали статьи.</p>';
} else {
    $html .= '<div class="table-wrap">';
    $html .= '<table class="data-table">';
    $html .= '<thead><tr><th>Статья</th><th>Тематика</th><th>Статус</th></tr></thead><tbody>';
    for my $row (@$submissions) {
        my $title = escapeHTML($row->{title});
        my $theme = escapeHTML($row->{theme_name});
        my $status_label = $row->{status} eq 'approved' ? 'Утверждена' : $row->{status} eq 'rejected' ? 'Отклонена' : 'На проверке';
        $html .= "<tr><td>$title</td><td>$theme</td><td>$status_label</td></tr>";
    }
    $html .= '</tbody></table></div>';
}

$html .= '</section>';

Journal::Web::render_page('Кабинет • Заявки', $user, $html, { active => 'Заявки' });
