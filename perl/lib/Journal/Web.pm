package Journal::Web;

use strict;
use warnings;
use utf8;

use CGI qw(:standard);
use CGI::Cookie;
use Digest::SHA qw(sha1_hex);
use Encode qw(decode encode);
use POSIX qw(strftime);

use Journal::DB;

sub now_ts {
    return strftime('%Y-%m-%d %H:%M:%S', localtime);
}

sub token_for {
    my ($seed) = @_;
    return sha1_hex($seed . rand() . time());
}

sub create_session {
    my ($dbh, $user_id) = @_;
    my $token = token_for($user_id);
    my $created_at = now_ts();
    my $expires_at = strftime('%Y-%m-%d %H:%M:%S', localtime(time() + 60 * 60 * 24 * 7));
    $dbh->do(
        'INSERT INTO sessions(user_id, token, created_at, expires_at) VALUES (?,?,?,?)',
        undef,
        $user_id,
        $token,
        $created_at,
        $expires_at
    );
    return ($token, $expires_at);
}

sub session_cookie {
    my ($token) = @_;
    return CGI::Cookie->new(
        -name    => 'sj_session',
        -value   => $token,
        -path    => '/',
        -expires => '+7d'
    );
}

sub clear_cookie {
    return CGI::Cookie->new(
        -name    => 'sj_session',
        -value   => '',
        -path    => '/',
        -expires => '-1d'
    );
}

sub current_user {
    my ($cgi, $dbh) = @_;
    my %cookies = CGI::Cookie->fetch;
    return undef unless $cookies{sj_session};
    my $token = $cookies{sj_session}->value;
    return undef unless $token;

    my $row = $dbh->selectrow_hashref(
        q{
            SELECT u.id, u.email, u.first_name, u.last_name, u.role
            FROM sessions s
            JOIN users u ON u.id = s.user_id
            WHERE s.token = ?
              AND s.expires_at > datetime('now')
            LIMIT 1
        },
        undef,
        $token
    );
    return $row;
}

sub require_login {
    my ($cgi, $dbh) = @_;
    my $user = current_user($cgi, $dbh);
    return $user if $user;

    my $clear = clear_cookie();
    print redirect(-uri => '/login.html', -cookie => $clear);
    exit;
}

sub role_label {
    my ($role) = @_;
    return 'Админ'    if $role eq 'admin';
    return 'Редколлегия' if $role eq 'editor';
    return 'Клиент';
}

sub clean_text {
    my ($value) = @_;
    return '' unless defined $value;
    # Heuristic: fix common UTF-8 -> Latin-1 mojibake (Ð/Ñ sequences)
    if ($value =~ /[ÐÑ][\x80-\xBF]/) {
        return decode('UTF-8', encode('latin1', $value));
    }
    return $value;
}

sub nav_links {
    my ($role) = @_;
    return [
        { href => '/cgi-bin/admin_orders.pl',    label => 'Заказы' },
        { href => '/cgi-bin/admin_users.pl',     label => 'Пользователи' },
        { href => '/cgi-bin/admin_analytics.pl', label => 'Аналитика' },
    ] if $role eq 'admin';

    return [
        { href => '/cgi-bin/editor_articles.pl', label => 'Статьи' },
        { href => '/cgi-bin/editor_issues.pl',   label => 'Выпуски' },
    ] if $role eq 'editor';

    return [
        { href => '/cgi-bin/buyer_issues.pl',     label => 'Выпуски' },
        { href => '/cgi-bin/buyer_cart.pl',       label => 'Корзина' },
        { href => '/cgi-bin/buyer_orders.pl',     label => 'Заказы' },
        { href => '/cgi-bin/buyer_submissions.pl', label => 'Заявки' },
    ];
}

sub render_page {
    my ($title, $user, $content_html, $opts) = @_;
    $opts ||= {};
    my $links = nav_links($user->{role});
    my $role_label = role_label($user->{role});

    print header(-charset => 'utf-8');
    print start_html(
        -title    => $title,
        -lang     => 'ru',
        -encoding => 'utf-8',
        -style    => { src => '/assets/css/style.css' }
    );
    print '<div class="page-shell">';
    print '<header class="topbar">';
    print '<div class="brand">';
    print '<img src="/assets/images/journal.svg" alt="" />';
    print '<div>';
    print '<div class="brand-title">Научный журнал</div>';
    print '<div class="brand-subtitle">Личный кабинет</div>';
    print '</div>';
    print '</div>';
    print '<div class="user-chip">';
    my $first_name = clean_text($user->{first_name});
    my $last_name = clean_text($user->{last_name});
    print '<span>' . escapeHTML($first_name) . ' ' . escapeHTML($last_name) . '</span>';
    print '<em>' . $role_label . '</em>';
    print '</div>';
    print '<a class="ghost-link" href="/cgi-bin/logout.pl">Выйти</a>';
    print '</header>';

    print '<nav class="tabs">';
    for my $link (@$links) {
        my $active = ($opts->{active} && $opts->{active} eq $link->{label}) ? 'active' : '';
        print qq{<a class="tab $active" href="$link->{href}">$link->{label}</a>};
    }
    print '</nav>';

    print '<main class="content">';
    print $content_html;
    print '</main>';

    print '<footer class="footer">';
    print '<button type="button" class="icon-btn" onclick="showHint()">';
    print '<img src="/assets/images/list.svg" alt="" />';
    print '<span>Подсказка</span>';
    print '</button>';
    print '<a class="ghost-link" href="/cgi-bin/index.pl">Домой</a>';
    print '</footer>';
    print '<button type="button" class="scroll-btn up" onclick="scrollToTop()" aria-label="Наверх">↑</button>';
    print '<button type="button" class="scroll-btn down" onclick="scrollToBottom()" aria-label="Вниз">↓</button>';

    print '</div>';
    print qq{
<script>
function showHint() {
    alert("Подсказка: используйте вкладки сверху для навигации по личному кабинету.");
}
function scrollToTop() {
    window.scrollTo({ top: 0, behavior: "smooth" });
}
function scrollToBottom() {
    window.scrollTo({ top: document.body.scrollHeight, behavior: "smooth" });
}
</script>
};
    print end_html();
}

1;
