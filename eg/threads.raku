#!/usr/bin/env raku

use Dawa;

my $x = 10;

stop;

start loop {
  $x += 5;
  sleep 1;
}

stop;

say "done";

