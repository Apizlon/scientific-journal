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

my $action = $cgi->param('action') // '';
if ($action eq 'set_role') {
    my $user_id = $cgi->param('user_id') // '';
    my $role = $cgi->param('role') // '';
    if ($user_id =~ /^\d+$/ && $role =~ /^(buyer|editor|admin)$/) {
        $dbh->do('UPDATE users SET role = ? WHERE id = ?', undef, $role, $user_id);
    }
}

my $users = $dbh->selectall_arrayref(
    'SELECT id, email, first_name, last_name, role FROM users ORDER BY id',
    { Slice => {} }
);

my $html = '';
$html .= '<section class="card">';
$html .= '<h1>Пользователи</h1>';
$html .= '<p class="muted">Управляйте ролями пользователей системы.</p>';
$html .= '<div class="table-wrap">';
$html .= '<table class="data-table">';
$html .= '<thead><tr><th>Почта</th><th>Имя</th><th>Фамилия</th><th>Роль</th></tr></thead><tbody>';
for my $row (@$users) {
    my $email = escapeHTML($row->{email});
    my $first_name = escapeHTML($row->{first_name});
    my $last_name = escapeHTML($row->{last_name});
    my $role = $row->{role};
    $html .= '<tr>';
    $html .= "<td>$email</td>";
    $html .= "<td>$first_name</td>";
    $html .= "<td>$last_name</td>";
    $html .= '<td>';
    $html .= qq{<form method="post" class="inline-form">};
    $html .= qq{<input type="hidden" name="action" value="set_role" />};
    $html .= qq{<input type="hidden" name="user_id" value="$row->{id}" />};
    $html .= '<select name="role">';
    for my $opt (['buyer','Клиент'], ['editor','Редколлегия'], ['admin','Админ']) {
        my ($value, $label) = @$opt;
        my $selected = ($role eq $value) ? 'selected' : '';
        $html .= qq{<option value="$value" $selected>$label</option>};
    }
    $html .= '</select>';
    $html .= '<button class="primary-btn" type="submit">Сохранить</button>';
    $html .= '</form>';
    $html .= '</td>';
    $html .= '</tr>';
}
$html .= '</tbody></table></div>';
$html .= '</section>';

Journal::Web::render_page('Админ • Пользователи', $user, $html, { active => 'Пользователи' });
