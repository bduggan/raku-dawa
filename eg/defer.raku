use Dawa;

for 1..5 {
  start {
    my $x = 10;
    loop {
      stop;
      $x++;
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

