#!/usr/bin/env raku

use Dawa;

my $x = 10;

stop;

start {
  my $y = 11;
  loop {
    my $z = 100;
    $x += 5;
    $y += 9;
    sleep 1;
  }
}

stop;

say "done";

