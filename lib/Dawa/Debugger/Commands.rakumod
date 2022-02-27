
unit class Dawa::Debugger::Commands;
use Terminal::ANSI::OO 't';

# filename => linenumber => True
has %.breakpoints;

my %aliases;
my %commands;
my sub alias(*%kv) { %aliases.push: %kv }
my sub cmd(*%kv) { %commands.push: %kv }

method run-command($cmd, $line, :$context, :$stack, :%tracking) {
  my $actual = %aliases{ $cmd } // $cmd;
  if %commands{ $actual } {
    self."$actual"($line.subst(/^^ $cmd \s+/,''), :$context, :$stack,:%tracking);
  } else {
    self.eval($line,:$context,:$stack,:%tracking);
  }
}

alias t => 'threads';
cmd threads => '[id] show threads being tracked [or just thread #id]';
method threads($str,:$context,:$stack,:%tracking) {
  with %tracking{ $str } {
    say "thread $str";
    say .backtrace.full;
    return;
  }
  for %tracking.kv -> $k, $v {
    say "--- thread $k ---";
    say $v.Str.indent(2);
  }
}

alias e => 'eval';
cmd eval => '[id] evaluate code in the current context [or in thread #id]';
method eval($str!,:$context!,:$stack,:%tracking) {
  use MONKEY-SEE-NO-EVAL;
  my $thread-context;
  my $thread-eval;
  with $str.words[0] -> $id {
    if %tracking{ $id }:exists {
      put t.color('#779977') ~ "evaluating in thread $id" ~ t.text-reset;
      $thread-eval = $str.subst( / ^^ $id \s+ /, '' );
      $thread-context = %tracking{ $id }.context;
    }
  }
  try {
    put ( EVAL ($thread-eval // $str), :context( $thread-context // $context) ).raku;
    CATCH {
      default {
        put $_;
      }
    }
  }
}

alias l => 'ls';
cmd ls => '[-a] [id] show [all] lexical variables in the current scope [or in thread #id]';
method ls($cmd, :$context!, :%tracking) {
  if ($cmd.words[1] // '') eq '-a' {
    say $context.keys.sort.join(' ');
    return;
  }
  my $thread-context;
  with $cmd.words[*-1] {
    with %tracking{ $_ } {
      $thread-context = .context;
    }
  }
  my %hidden = set <!UNIT_MARKER $! $/ $=finish $=pod $?PACKAGE $_ $¢ &stop ::?PACKAGE Dawa EXPORT GLOBALish TrackingState>;
  put ($thread-context // $context).keys.grep({!%hidden{ $_ } }).sort.join(' ');
}

alias h => 'help';
cmd help => 'this help';
method help(|args) {
  put "";
  put t.bright-white ~ "-- Welcome to Dawa! --" ~ t.text-reset;
  put "";
  put "The following commands are available: ";
  my %all-commands = %commands;
  my %all-aliases = %aliases;
  %all-commands<next> = "run the next statement";
  %all-aliases<n> = 'next';
  %all-commands<continue> = "continue execution of this thread";
  push %all-aliases, (c => 'continue');
  push %all-aliases, ('^D' => 'continue');
  (my %lookup).push: %all-aliases.invert;
  for %all-commands.sort -> (:$key is copy, :$value) {
    with %lookup{ $key }.?join(', ') {
      $key ~= " ($_)";
    }
    put t.bright-yellow ~ $key.fmt('%20s') ~ t.white ~ ' : ' ~ t.bright-green ~ $value ~ t.text-reset;
  }

  put "";
  put "A blank line (Enter) is equivalent to 'n'.";
  put "Anything else will be evaluated as a Raku expression in the current context.";
  put "";
}

alias n => 'next';
cmd next => 'go to next statement';
method next($cmd,:%extra) {
  %extra<should-stop> = True;
  %extra<should-return> = True;
}

alias w => 'where';
cmd where => 'show a stack trace and the current location in the code';
method where($cmd,:$context!,:stack($b)!,:%tracking) {
  my %colors;
  put "\n--- current stack --- ";
  put $b.Str;
  my %leaders;
  for %.breakpoints.keys -> $file {
    for %.breakpoints{ $file }.keys -> $line {
      %colors{ $file }{ $line } //= t.bright-magenta;
      %leaders{ $file }{ $line } //= '■';
    }
  }
  for %tracking.kv -> $k, $v {
    %colors{ $v.file }{ $v.line } //= t.color('#FFA500');
    %leaders{ $v.file }{ $v.line } //= '';
    %leaders{ $v.file }{ $v.line } ~= "[$k]";
  }
  my $frame = @$b.first: {
    !.is-setting && !.is-hidden && .file ne $?FILE
  }
  my $file = $frame.file.subst(/' ' '(' <-[(]>+ ')' \s* $$/,'');
  %leaders{ $file }{ $frame.line } ~= '▶';
  %colors{ $file }{ $frame.line } = t.bright-yellow;
  show-file($file, $frame.line, :%colors, :%leaders);
}

alias b => 'break';
cmd break => '[N [filename] ] add a breakpoint at line N [in filename]';
method break($cmd, :$context, :$stack) {
  my $file;
  my $line;
  if $cmd ~~ /^^ \d+ $$/ {
    $line = +$cmd;
    $file = $stack.tail.file;
  } else {
    note "missing line number for breakpoint";
    return;
  }
  %.breakpoints{ $file }{ $line } = True;
  say "Added breakpoint at line $line in $file";
}

sub show-file(Str $file, Int $line, :%colors, :%leaders) {
  put "-- current location --";
  my $width := $line.chars + 2; # width of line numbers
  my $top   := 5;               # extra lines to show at the top
  my $first = min(
     $line - $top,
     |(  %colors{$file}.keys >>->> $top ),
     |( %leaders{$file}.keys >>->> $top )
  );
  for $file.IO.lines.kv -> $i, $l {
    next if $i < $first;
    my $flags = %leaders{ $file }{ $i + 1 } // "";
    my $sep = $flags.fmt('│ %5s │');
    with %colors{ $file }{ $i + 1 } -> $c {
       put ($i + 1).fmt("$c%{$width}d $sep") ~ " $l" ~ t.text-reset;
    } else {
       put ($i + 1).fmt("%{$width}d $sep") ~ " $l";
    }
    last if $i > $line + 10;
  }
  put "";
}
