unit class Dawa::Debugger;

use Terminal::ANSI::OO 't';
has Bool $.should-stop = False;

method update-state(:%debugging) {
  %debugging{ $*THREAD.id } = $!should-stop;
}

method run-repl(:$context,:$stack) {
  show-stack($stack);
  loop {
    my $cmd = prompt "dawa> " or last;
    # Next step in this thread
    if $cmd eq 'n' {
      $!should-stop = True;
      return;
    }
    # Continue just this thread
    if $cmd eq 'c' {
      $!should-stop = False;
      return;
    }
    use MONKEY-SEE-NO-EVAL;
    try {
      put ( EVAL $cmd, :$context ).raku;
      CATCH {
        default {
          put $_;
        }
      }
    }
  }
}

sub show-stack($b) {
  my %colors;
  put "\n--- current stack --- ";
  for @$b {
    next if .is-setting || .is-hidden;
    next if .file eq $?FILE and .is-routine and .subname eq 'debug';
    my $c;
    %colors{ .file }{ .line } = t.bright-green;
    %colors{ .file }{ .line } = t.bright-yellow unless $++;
    $c = %colors{ .file }{ .line };
    say "    in sub {.subname} at {$c}{.file} line {.line}" ~ t.text-reset;
  }
  put "";
  for @$b {
    next if .is-setting || .is-hidden;
    next if .file eq $?FILE and .is-routine and .subname eq 'debug';
    show-file-line(.file, .line, :%colors);
    last;
  }
}

sub show-file-line($file is copy, $line, :%colors) {
  $file .= subst(/' ' '(' <-[(]>+ ')' \s* $$/,'');
  put "-- current location --";
  my $width = $line.chars + 2;
  for $file.IO.lines.kv -> $i, $l {
    next if $i < $line - 10;
    my $sep = "│";
    $sep = ">" if $i + 1 == $line;
    with %colors{ $file }{ $i + 1 } -> $c {
       put ($i + 1).fmt("$c%{$width}d $sep") ~ " $l" ~ t.text-reset;
    } else {
       put ($i + 1).fmt("%{$width}d $sep") ~ " $l";
    }
    last if $i > $line + 10;
  }
  put "";
}
