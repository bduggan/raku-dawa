unit class Dawa::Debugger;

has Bool $.should-stop = False;

method run-repl(:$context,:$stack) {
  loop {
    my $cmd = prompt "debug> " or last;
    if $cmd eq 'n' {
      $!should-stop = True;
      return;
    }
    if $cmd eq 'c' {
      $!should-stop = False;
      return;
    }
    use MONKEY-SEE-NO-EVAL;
    put ( EVAL $cmd, :$context ).raku;
  }
}
