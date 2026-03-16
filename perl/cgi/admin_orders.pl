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
if ($action eq 'set_status') {
    my $order_id = $cgi->param('order_id') // '';
    my $status = $cgi->param('status') // '';
    if ($order_id =~ /^\d+$/ && $status =~ /^(pending|paid)$/) {
        $dbh->do('UPDATE orders SET status = ? WHERE id = ?', undef, $status, $order_id);
    }
}

my $orders = $dbh->selectall_arrayref(
    q{
        SELECT o.id, o.status, o.total_amount, o.created_at,
               u.email AS buyer_email
        FROM orders o
        JOIN users u ON u.id = o.user_id
        ORDER BY o.created_at DESC
    },
    { Slice => {} }
);

my $html = '';
$html .= '<section class="card">';
$html .= '<h1>Заказы</h1>';
$html .= '<p class="muted">Все заказы клиентов и управление статусами оплаты.</p>';

if (!@$orders) {
    $html .= '<p>Пока нет заказов.</p>';
} else {
    $html .= '<div class="table-wrap">';
    $html .= '<table class="data-table">';
    $html .= '<thead><tr><th>Номер</th><th>Почта</th><th>Сумма</th><th>Статус</th></tr></thead><tbody>';
    for my $row (@$orders) {
        my $email = escapeHTML($row->{buyer_email});
        my $status = $row->{status};
        $html .= '<tr>';
        $html .= '<td>#' . $row->{id} . '</td>';
        $html .= "<td>$email</td>";
        $html .= '<td>' . int($row->{total_amount}) . ' ₽</td>';
        $html .= '<td>';
        $html .= qq{<form method="post" class="inline-form">};
        $html .= qq{<input type="hidden" name="action" value="set_status" />};
        $html .= qq{<input type="hidden" name="order_id" value="$row->{id}" />};
        $html .= '<select name="status">';
        my @opts = (
            ['pending', 'Ожидает оплаты'],
            ['paid', 'Оплачен'],
        );
        for my $opt (@opts) {
            my ($value, $label) = @$opt;
            my $selected = ($status eq $value) ? 'selected' : '';
            $html .= qq{<option value="$value" $selected>$label</option>};
        }
        $html .= '</select>';
        $html .= '<button class="primary-btn" type="submit">Сохранить</button>';
        $html .= '</form>';
        $html .= '</td>';
        $html .= '</tr>';
    }
    $html .= '</tbody></table></div>';
}

$html .= '</section>';

Journal::Web::render_page('Админ • Заказы', $user, $html, { active => 'Заказы' });
