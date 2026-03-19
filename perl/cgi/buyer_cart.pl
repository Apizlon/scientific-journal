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
if ($action eq 'remove_item') {
    my $issue_id = $cgi->param('issue_id') // '';
    if ($issue_id =~ /^\d+$/) {
        $dbh->do(
            'DELETE FROM cart_items WHERE user_id = ? AND issue_id = ?',
            undef,
            $user->{id},
            $issue_id
        );
    }
}

if ($action eq 'checkout') {
    my $items = $dbh->selectall_arrayref(
        q{
            SELECT c.issue_id, i.title, i.price
            FROM cart_items c
            JOIN issues i ON i.id = c.issue_id
            WHERE c.user_id = ?
        },
        { Slice => {} },
        $user->{id}
    );

    if (@$items) {
        my $total = 0;
        $total += $_->{price} for @$items;

        $dbh->do(
            'INSERT INTO orders(user_id,status,total_amount,created_at) VALUES (?,?,?,?)',
            undef,
            $user->{id},
            'pending',
            $total,
            Journal::DB::now_ts()
        );
        my ($order_id) = $dbh->selectrow_array('SELECT last_insert_rowid()');

        for my $item (@$items) {
            $dbh->do(
                'INSERT INTO order_items(order_id,issue_id,price) VALUES (?,?,?)',
                undef,
                $order_id,
                $item->{issue_id},
                $item->{price}
            );
        }

        $dbh->do('DELETE FROM cart_items WHERE user_id = ?', undef, $user->{id});

        my $payer = Journal::Web::clean_text($user->{first_name}) . ' ' . Journal::Web::clean_text($user->{last_name});
        my $content = "Квитанция на оплату заказа #$order_id\n";
        $content .= "Плательщик: $payer\n";
        $content .= "Сумма: $total ₽\n";
        $content .= "Счет получателя: 40817810000000000001\n";
        $content .= "Получатель: ООО \"Научный журнал\"\n";
        $content .= "Назначение: Оплата заказа #$order_id\n";

        print header(
            -type        => 'text/plain',
            -charset     => 'utf-8',
            -attachment  => "receipt-order-$order_id.txt"
        );
        print $content;
        exit;
    }
}

my $items = $dbh->selectall_arrayref(
    q{
        SELECT i.id, i.title, i.price
        FROM cart_items c
        JOIN issues i ON i.id = c.issue_id
        WHERE c.user_id = ?
        ORDER BY c.created_at DESC
    },
    { Slice => {} },
    $user->{id}
);

my $total_amount = 0;
$total_amount += $_->{price} for @$items;

my $html = '';
$html .= '<section class="card">';
$html .= '<h1>Корзина</h1>';
$html .= '<p class="muted">Оформите заказ и получите квитанцию для оплаты.</p>';

if (!@$items) {
    $html .= '<p>Корзина пуста.</p>';
} else {
    $html .= '<div class="table-wrap">';
    $html .= '<table class="data-table">';
    $html .= '<thead><tr><th>Выпуск</th><th>Цена</th><th>Действие</th></tr></thead><tbody>';
    for my $item (@$items) {
        my $title = escapeHTML(Journal::Web::clean_text($item->{title}));
        $html .= '<tr>';
        $html .= "<td>$title</td>";
        $html .= '<td>' . int($item->{price}) . ' ₽</td>';
        $html .= '<td>';
        $html .= qq{<form method="post" class="inline-form">};
        $html .= qq{<input type="hidden" name="action" value="remove_item" />};
        $html .= qq{<input type="hidden" name="issue_id" value="$item->{id}" />};
        $html .= qq{<button class="ghost-btn" type="submit">Убрать</button>};
        $html .= '</form>';
        $html .= '</td>';
        $html .= '</tr>';
    }
    $html .= '</tbody></table></div>';
    $html .= '<div class="summary">';
    $html .= '<div class="summary-total">Итого: ' . int($total_amount) . ' ₽</div>';
    $html .= qq{<form method="post">};
    $html .= qq{<input type="hidden" name="action" value="checkout" />};
    $html .= qq{<button class="primary-btn" type="submit">Оформить заказ</button>};
    $html .= '</form>';
    $html .= '</div>';
}

$html .= '</section>';

Journal::Web::render_page('Кабинет • Корзина', $user, $html, { active => 'Корзина' });
