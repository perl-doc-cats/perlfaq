use strict;
use warnings;

use Test::More;
plan skip_all => 'xt/release/changes_has_content.t is missing' if not -e 'xt/release/changes_has_content.t';

# skip for master branch, only for travis
if (($ENV{TRAVIS_PULL_REQUEST} || '') eq 'false') {
    chomp(my $branch_name = ($ENV{TRAVIS_BRANCH} || `git rev-parse --abbrev-ref HEAD`));
    $TODO = 'Changes need not have content for this release yet if this is only the master branch'
        if ($branch_name || '') eq 'master';
}

do './xt/release/changes_has_content.t';
die $@ if $@;
