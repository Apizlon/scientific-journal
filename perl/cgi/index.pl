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

if ($user->{role} eq 'admin') {
    print redirect('/cgi-bin/admin_orders.pl');
    exit;
}

if ($user->{role} eq 'editor') {
    print redirect('/cgi-bin/editor_articles.pl');
    exit;
}

print redirect('/cgi-bin/buyer_issues.pl');
