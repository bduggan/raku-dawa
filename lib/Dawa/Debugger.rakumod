unit class Dawa::Debugger;

use Terminal::ANSI::OO 't';
use Dawa::Debugger::Commands;
use Readline;

my $history-file = %*ENV<DAWA_HISTORY_FILE> // $*HOME.child('.dawa-history');
my $r = Readline.new;
$r.using-history;
$r.read-history("$history-file") if $history-file.e;

my %COLORS =
  message => t.bright-green;

has Bool $.should-stop = False;
has $!first = True;
has $.cmd = Dawa::Debugger::Commands.new;

method update-state(:%debugging) {
  %debugging{ $*THREAD.id } = $!should-stop;
}

sub show-line($stack) {
  my $frame = $stack.first: { !.is-setting && !.is-hidden }
  my $file = $frame.file.subst(/' ' '(' <-[(]>+ ')' \s* $$/,'');
  my $line = $frame.line;
  my $text = $file.IO.lines[$line - 1] // return;
  put ($line).fmt("{t.bright-yellow}%3d ▶") ~ " $text" ~ t.text-reset;
}

my $said-help;

method run-repl(:$context,:$stack,:%tracking) {
  if $!first {
    $!cmd.run-command("where","where",:$stack,:$context,:%tracking);
    $!first = False;
  } else {
    show-line($stack);
  }
  say %COLORS<message> ~ "Type h for help" ~ t.text-reset unless $said-help++;
  loop {
    my $cmd = $r.readline("dawa [{$*THREAD.id}]> ");

    # ^D
    if !defined($cmd) {
        $!should-stop = False;
        $!first = True;
        return;
    }

    # Enter (next)
    if $cmd.chars == 0 || $cmd eq <n next>.any {
        $!should-stop = True;
        return;
    }

    # continue
    if $cmd eq any <c continue> {
        $!should-stop = False;
        $!first = True;
        return;
    }

    $r.add-history($cmd);
    $r.write-history("$history-file");

    # anything else
    my $run = $cmd.words[0];
    $!should-stop = True if $run eq 's'  | 'step';
    $!cmd.run-command($run, $cmd, :$context, :$stack, :%tracking);
  }
}

method stop-thread {
  $!cmd.stdout-lock.protect: {
    put %COLORS<message> ~ "∙ Stopping thread { $*THREAD.gist }" ~ t.text-reset;
  }
}

method breakpoint($file,$line) {
  $!cmd.breakpoints{ $file }{ $line }
}
