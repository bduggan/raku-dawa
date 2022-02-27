#!/usr/bin/env raku

use Dawa;

my $x = 10;

stop;

start loop {
  my $y = 10;
  $x += 5;
  $x += 11;
  sleep 0.3;
  $x = 100;
}

stop;

say "done";

