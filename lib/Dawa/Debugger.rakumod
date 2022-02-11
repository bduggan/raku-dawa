unit class Dawa::Debugger;

use Terminal::ANSI::OO 't';
use Readline;

my $history-file = %*ENV<DAWA_HISTORY_FILE> // $*HOME.child('.dawa-history');
my $r = Readline.new;
$r.using-history;
$r.read-history("$history-file") if $history-file.e;

my %COLORS =
  message => t.bright-green;

has Bool $.should-stop = False;
has $!first = True;

method update-state(:%debugging) {
  %debugging{ $*THREAD.id } = $!should-stop;
}

method show-help {
  say "";
  say "-- Welcome to Dawa! --";
  say "";
  say "The following commands are available: ";
  say "  n or [return] : advance to the next statement";
  say "        c or ^D : continue execution of this thread";
  say "              w : show the current stack and code location";
  say "              h : this help";
  say "";
  say "Anything else will be evaluated as a Raku expression in the current context.";
  say "";
}

sub show-line($stack) {
  my $frame = $stack.first: { !.is-setting && !.is-hidden }
  my $file = $frame.file.subst(/' ' '(' <-[(]>+ ')' \s* $$/,'');
  my $line = $frame.line;
  my $text = $file.IO.lines[$line] // return;
  put ($line + 1).fmt("{t.bright-yellow}%3d ▶") ~ " $text" ~ t.text-reset;
}

my $said-help;

method run-repl(:$context,:$stack) {
  if $!first {
    show-stack($stack);
    $!first = False;
  } else {
    show-line($stack);
  }
  say %COLORS<message> ~ "Type h for help" ~ t.text-reset unless $said-help++;
  loop {
    my $cmd = $r.readline("dawa> ");
    if !defined($cmd) {
        $!should-stop = False;
        $!first = True;
        return;
    }
    if $cmd.chars == 0 {
        $!should-stop = True;
        return;
    }
    $r.add-history($cmd);
    $r.write-history("$history-file");
    given $cmd {
      when 'n' {
        $!should-stop = True;
        return;
      }
      when 'c' {
        $!should-stop = False;
        $!first = True;
        return;
      }
      when 'h' {
        self.show-help;
        next;
      }
      when 'w' {
        show-stack($stack);
        next;
      }
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
  my $done;
  for @$b {
    next if .is-setting || .is-hidden;
    my $c;
    %colors{ .file }{ .line } = t.bright-green;
    unless $done++ {
      %colors{ .file }{ .line } = t.bright-cyan;
      %colors{ .file }{ .line + 1 } = t.bright-yellow;
    }
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
    $sep = "◀" if $i + 1 == $line;
    $sep = "▶" if $i + 1 == $line + 1;
    with %colors{ $file }{ $i + 1 } -> $c {
       put ($i + 1).fmt("$c%{$width}d $sep") ~ " $l" ~ t.text-reset;
    } else {
       put ($i + 1).fmt("%{$width}d $sep") ~ " $l";
    }
    last if $i > $line + 10;
  }
  put "";
}

method stop-thread {
  put %COLORS<message> ~ "∙ Stopping thread { $*THREAD.gist }" ~ t.text-reset;
}
