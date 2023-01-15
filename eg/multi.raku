#!/usr/bin/env raku

use Dawa;

stop;

sub first { 1 }
sub second { 2 }
sub third { 3 }

my $a = sum
  1 + 2,
  2 - 100,
  12;

my $b = max
   first(),
   second(),
   third();

say 'done';
