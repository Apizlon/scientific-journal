#!/usr/bin/perl -CS
use strict;
use warnings;
use utf8;

use FindBin qw($Bin);
use lib "$Bin/../perl/lib";

use Journal::DB;

my $dbh = Journal::DB::connect_db();
Journal::DB::ensure_schema($dbh);
Journal::DB::seed_if_empty($dbh);

print "OK: SQLite initialized at " . Journal::DB::db_path() . "\n";


