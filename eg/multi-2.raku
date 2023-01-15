#!/usr/bin/env raku

use Dawa;

my @forest;

my \row = 1;
my \col = 1;
my $scenic-score = 2;
my \height = 1;
my \N = 2;

stop;

my $x = 1;

  $scenic-score max= [*] [
    @forest[row;^col].reverse, @forest[row;col^..N],
    @forest[^row;col].reverse, @forest[row^..N;col]
  ] X+ height;

say 'nother';
say 'hi';
