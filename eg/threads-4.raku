use Dawa;

my $x = 10;
start {
  stop;
  $x++;
}
stop;
say "x is $x";

