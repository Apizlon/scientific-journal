#!/usr/bin/perl -CS
use strict;
use warnings;
use utf8;

use CGI qw(:standard);
use CGI::Cookie;
use lib "/opt/app/lib";

use Journal::DB;
use Journal::Web;

binmode(STDIN,  ':utf8');
binmode(STDOUT, ':utf8');

my $cgi = CGI->new;
my %cookies = CGI::Cookie->fetch;
my $token = $cookies{sj_session} ? $cookies{sj_session}->value : undef;

if ($token) {
    my $dbh = Journal::DB::connect_db();
    Journal::DB::ensure_schema($dbh);
    $dbh->do('DELETE FROM sessions WHERE token = ?', undef, $token);
}

my $clear_cookie = Journal::Web::clear_cookie();
print redirect(-uri => '/login.html', -cookie => $clear_cookie);
