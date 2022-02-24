#!/usr/bin/env raku

use Dawa;

my $x = 10;

stop;

start loop {
  track;
  $x += 5;
  sleep 0.3;
  track;
  track;
  sleep 0.3;
  $x += 11;
  track;
  sleep 0.3;
}

stop;

say "done";

