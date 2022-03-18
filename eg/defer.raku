use Dawa;

for 1..5 {
  start {
    my $x = 10;
    loop {
      stop;
      $x++;
      put "x is now $x";
      put "x is still $x";
    }
  }
}

my $y = 100;
loop {
  stop;
  say "y is $y";
  $y += 111;
  last if $y > 500;
}

