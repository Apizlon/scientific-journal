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

my $orders = $dbh->selectall_arrayref(
    q{
        SELECT id, status, total_amount, created_at
        FROM orders
        WHERE user_id = ?
        ORDER BY created_at DESC
    },
    { Slice => {} },
    $user->{id}
);

my $html = '';
$html .= '<section class="card">';
$html .= '<h1>Заказы</h1>';
$html .= '<p class="muted">Отслеживайте статус оплаты и доступ к полным текстам.</p>';

if (!@$orders) {
    $html .= '<p>У вас пока нет заказов.</p>';
} else {
    for my $order (@$orders) {
        my $status_label = $order->{status} eq 'paid' ? 'Оплачен' : 'Ожидает оплаты';
        $html .= '<div class="order-card">';
        $html .= '<div class="order-header">';
        $html .= '<div>';
        $html .= '<h2>Заказ #' . $order->{id} . '</h2>';
        $html .= '<div class="muted">Создан: ' . $order->{created_at} . '</div>';
        $html .= '</div>';
        $html .= '<div class="order-status">';
        $html .= '<span class="badge">' . $status_label . '</span>';
        $html .= '<div class="price">' . int($order->{total_amount}) . ' ₽</div>';
        $html .= '</div>';
        $html .= '</div>';

        my $items = $dbh->selectall_arrayref(
            q{
                SELECT i.id, i.title
                FROM order_items oi
                JOIN issues i ON i.id = oi.issue_id
                WHERE oi.order_id = ?
            },
            { Slice => {} },
            $order->{id}
        );

        if (!@$items) {
            $html .= '<p class="muted">Нет позиций.</p>';
        } else {
            $html .= '<ul class="list">';
            for my $item (@$items) {
                my $title = escapeHTML($item->{title});
                $html .= "<li>$title</li>";
            }
            $html .= '</ul>';
        }

        if ($order->{status} eq 'paid') {
            my $articles = $dbh->selectall_arrayref(
                q{
                    SELECT a.title, a.content, a.author_name
                    FROM articles a
                    JOIN order_items oi ON oi.issue_id = a.issue_id
                    WHERE oi.order_id = ? AND a.status = 'approved'
                    ORDER BY a.id
                },
                { Slice => {} },
                $order->{id}
            );
            $html .= '<div class="divider"></div>';
            $html .= '<h3>Полные статьи</h3>';
            if (!@$articles) {
                $html .= '<p class="muted">Пока нет статей в этом заказе.</p>';
            } else {
                $html .= '<div class="article-list">';
                for my $article (@$articles) {
                    my $title = escapeHTML($article->{title});
                    my $content = escapeHTML($article->{content});
                    my $author = escapeHTML($article->{author_name});
                    $html .= '<div class="article-item">';
                    $html .= "<h4>$title</h4>";
                    $html .= "<p class=\"muted\">$content</p>";
                    $html .= "<span class=\"badge\">$author</span>";
                    $html .= '</div>';
                }
                $html .= '</div>';
            }
        } else {
            $html .= '<p class="muted">Полные статьи станут доступны после оплаты.</p>';
        }

        $html .= '</div>';
    }
}

$html .= '</section>';

Journal::Web::render_page('Кабинет • Заказы', $user, $html, { active => 'Заказы' });
