
unit class Dawa::Debugger::Commands;
use Terminal::ANSI::OO 't';

my %aliases;
my %commands;
my sub alias(*%kv) { %aliases.push: %kv }
my sub cmd(*%kv) { %commands.push: %kv }

method run-command($cmd, $line, :$context, :$stack) {
  my $actual = %aliases{ $cmd } // $cmd;
  if %commands{ $actual } {
    self."$actual"($line, :$context, :$stack);
  } else {
    self.eval($cmd,:$context,:$stack);
  }
}

sub rest($initial,$str) {
  $str.subst(/^^ $initial \s+ /,'');
}

alias e => 'eval';
cmd eval => 'evaluate code in the current context';
method eval($cmd!,:$context!,:$stack) {
  my $eval = rest('eval',$cmd);
  use MONKEY-SEE-NO-EVAL;
  try {
    put ( EVAL $eval, :$context ).raku;
    CATCH {
      default {
        put $_;
      }
    }
  }
}

alias l => 'ls';
cmd ls => 'show lexical variables in the current scope (-a for all)';
method ls($cmd, :$context!) {
  if ($cmd.words[1] // '') eq '-a' {
    say $context.keys.sort.join(' ');
    return;
  }
  my %hidden = set <!UNIT_MARKER $! $/ $=finish $=pod $?PACKAGE $_ $¢ &stop ::?PACKAGE Dawa EXPORT GLOBALish>;
  say $context.keys.grep({!%hidden{ $_ } }).sort.join(' ');
}

alias h => 'help';
cmd help => 'this help';
method help(|args) {
  say "";
  say t.bright-white ~ "-- Welcome to Dawa! --" ~ t.text-reset;
  say "";
  say "The following commands are available: ";
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
    say t.bright-yellow ~ $key.fmt('%20s') ~ t.white ~ ' : ' ~ t.bright-green ~ $value ~ t.text-reset;
  }

  say "";
  say "Anything else will be evaluated as a Raku expression in the current context.";
  say "";
}

alias n => 'next';
cmd next => 'go to next statement';
method next($cmd,:%extra) {
  %extra<should-stop> = True;
  %extra<should-return> = True;
}

alias w => 'where';
cmd where => 'show a stack trace and the current location in the code';
method where($cmd,:$context!,:stack($b)!) {
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
