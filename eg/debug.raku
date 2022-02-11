#!/usr/bin/env raku

use Dawa;  # line 3

say "one";
say "two";
my $x = 99;
stop;      # line 8
say "three";
say "four";
$x = $x + 11;
say "five";
say "x is $x";
say "bye";

