#!/usr/bin/env raku

use Dawa;

my $x = 1;

my $promise = start loop {
  $x += 5;
  stop;
  sleep 3;
  last if $x > 14;
}

say $promise.WHAT;

say DateTime.now;
say "waiting";
await $promise;
say DateTime.now;
say "done";


