unit class Dawa::Debugger;

use Terminal::ANSI::OO 't';
use Dawa::Debugger::Commands;
use Dawa::Helpers;
use Readline;

my $history-file = %*ENV<DAWA_HISTORY_FILE> // $*HOME.child('.dawa-history');
my $r = Readline.new;
$r.using-history;
$r.read-history("$history-file") if $history-file.e;

my %COLORS =
  message => t.green;

has Bool $.should-stop = False;
has $!first = True;
has $.cmd handles <set-breakpoint> = Dawa::Debugger::Commands.new;

method update-state(:%debugging) {
  %debugging{ $*THREAD.id } = $!should-stop;
}

sub show-line($stack, :%snippets, :$file, :$line) {
  unless $file.IO.e {
    note "could not open $file";
    return;
  }
  my $snip = %snippets{ $file }{ $line };
  my $min = $snip.from-line;
  my $max = $snip.to-line;

  for $min - 4 .. $min - 1 {
    next unless $_ >= 0;
    my $text = $file.IO.lines[$_ - 1] // last;
    put ($_).fmt("%3d      │ ") ~ " $text";
  }
  for $min .. $max -> $line {
    my $text = $file.IO.lines[$line - 1] // "<missing>";
    my $symbol = '▷';
    put ($line).fmt("{t.cyan}%3d {$symbol.fmt('%-4s')} │ ") ~ " $text" ~ t.text-reset;
  }
  for $max + 1 .. $max + 3 {
    my $text = $file.IO.lines[$_ - 1] // last;
    put ($_).fmt("%3d      │ ") ~ " $text";
  }
}

my $said-help;

method run-repl(:$context,:$stack,:%tracking,:%snippets, :$file, :$line) {
  if $!first {
    $!cmd.run-command("where","where",:$stack,:$context,:%tracking,:%snippets, :$file, :$line);
    $!first = False;
  } else {
    show-line($stack, :%snippets, :$file, :$line);
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

    # Enter
    if $cmd.chars == 0 {
        note "no command, type h for help";
        redo;
    }

    if $cmd eq <n next>.any {
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
    $!should-stop = True if $run eq 's' | 'step';
    $!cmd.run-command($run, $cmd, :$context, :$stack, :%tracking, :%snippets, :$file, :$line);
  }
}

method stop-thread {
  $!cmd.stdout-lock.protect: {
    put %COLORS<message> ~ "∙ Stopping thread { $*THREAD.gist }" ~ t.text-reset;
  }
}

method breakpoint($file,$line) {
  with $!cmd.breakpoints{ $file.IO.resolve }{ $line } -> $how {
    return $how eq 'break';
  }
  return False;
}
