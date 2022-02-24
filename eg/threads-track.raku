#!/usr/bin/env raku

use Dawa;

my $x = 10;

stop;

start loop {
  track;
  $x += 5;
  sleep 1;
  track;
  sleep 1;
  track;
  sleep 1;
}

stop;

say "done";

