use nqp;
use experimental :rakuast;
use Dawa::Debugger;
use Dawa::Exception;
use QAST:from<NQP>;
use Terminal::ANSI::OO 't';

my Bool %debugging;
my %tracking;

my %breakpoints;
my %snippets;

my $debugger = Dawa::Debugger.new;

class Snippet {
  has Str $.file;
  has Str $.line-text handles <lines>;
  has Int $.from;
  has Int $.to;
  has Int $.from-line;
  has Int $.to-line;
  has Str $.orig;
  method TWEAK {
    without $!orig {
      $!to = 0;
      $!to-line = 0;
      $!from-line = 0;
      return;
    }
    $!to-- while ($!orig.subst($!to,1) // ' ') eq ' ' | "\n" && $!to > 0;
    $!line-text .= trim-trailing;
    $!from-line = substr( $!orig, 0, $!from ).comb.grep(/"\n"/).elems + 1;
    $!to-line = $!from-line + self.lines - 1;
    $!orig = Nil; # not actually needed
  }
}

class TrackingState {
  has $.context;
  has $!backtrace;
  has $.thread-gist = $*THREAD.gist;
  has $.file;
  has $.line;
  has $.snippet is rw;

  method backtrace is hidden-from-backtrace { $!backtrace }
  method TWEAK is hidden-from-backtrace {
    $!backtrace //= Backtrace.new;
    with $!backtrace.list.first( { !.is-setting && !.is-hidden } ) {
      $!file = .file;
      $!line = .line;
    }
  }
  method Str {
    join "\n",
     $.thread-gist, |$.backtrace.list.grep( {
       !.is-setting && !.is-hidden
     } ).map: {
       .Str.trim-trailing
     }
  }
}

sub stop is export is hidden-from-backtrace {
  $debugger.set-breakpoint(callframe(1).file,callframe(1).line, 'stop');
  $debugger.stop-thread;
  %debugging{ $*THREAD.id } = True;
  my $tracking = TrackingState.new;
  %tracking{ $*THREAD.id } = $tracking;
}

my Lock $repl-lock .= new;
my atomicint $deferred-to;

my $stopped-once = False;
sub maybe-stop($context, $file, $line) is hidden-from-backtrace {
  my $snippet = %snippets{$file}{$line};
  stop if %*ENV<DAWA_STOP> && !$stopped-once;
  $stopped-once = True;
  my $tracking = TrackingState.new(:$context);
  %tracking{ $*THREAD.id } = $tracking;

  if $debugger.breakpoint(callframe(1).file,callframe(1).line) {
    say "encountered breakpoint at " ~ callframe(1).file ~ ' line ' ~ callframe(1).line;
    stop;
  }
  return unless %debugging{ $*THREAD.id };
  my $stack = Backtrace.new;
  my $start-repl = True;
  my $delay = 0;
  while $start-repl {
    sleep $delay if $delay > 0;
    $delay = 0;
    $start-repl = False;
    try {
      # note "waiting for lock in thread { $*THREAD.id }";
      $repl-lock.protect: {
        if !$deferred-to or $deferred-to == $*THREAD.id {
          $debugger.run-repl(:$context, :$stack, :%tracking, :%snippets, :$file, :$line);
          $deferred-to = 0;
        } else {
          $delay = 1;
          $start-repl = True;
        }
      }
      CATCH {
          when Dawa::Exception {
            with .defer-to -> $n {
              $deferred-to = $n;
              when $n == $*THREAD.id {
                $start-repl = True unless .should-continue;
              }
              default {
                # note "{$*THREAD.id} will defer so that thread $n can take this";
                $start-repl = True;
                $delay = 1;
              }
            }
         }
         default {
            note "error $_"; exit;
        }
      }
    }
  }
  $debugger.update-state(:%debugging);
};

my %added-lines;

# is this a stop point?
my sub stop-point(Mu $/, IO::Path $file) {
  return Nil if %debugging{ $*THREAD.id };
  my $line-text   = substr($/.orig, $/.from, $/.to - $/.from);
  my $line-number = substr($/.orig, 0, $/.from).comb.grep("\n").elems + 1;
  return Nil if %added-lines{ $file }{ $line-number };
  # only instrument statements that begin at the start of a line
  return Nil unless so substr($/.orig, 0, $/.from) ~~ / [ \n | ^ ] \s* $ /;
  # stopping right before an await deadlocks the debugger REPL against it
  return Nil if $line-text.trim ~~ / ^ 'await' >> /;
  %snippets{ $file }{ $line-number } = Snippet.new:
    :$line-text, from => $/.from, to => $/.to, orig => $/.orig.Str;
  %added-lines{ $file }{ $line-number } = True;
  $line-number;
}

# `$target(@args)` (or `$target.$method(@args)` with :method) in RakuAST
my sub rakuast-call(Mu $target, *@args, Str :$method) {
  my $operand = $target ~~ RakuAST::Node ?? $target !! RakuAST::Literal.from-value($target);
  my $postfix = $method
    ?? RakuAST::Call::Method.new(
         name => RakuAST::Name.from-identifier($method),
         args => RakuAST::ArgList.new(|@args))
    !! RakuAST::Call::Term.new(args => RakuAST::ArgList.new(|@args));
  RakuAST::ApplyPostfix.new(:$operand, :$postfix)
}

# Actions mixin for the legacy (QAST) frontend: rewrite each eligible statement
# into  Stmts( maybe-stop(PseudoStash.new, $file, $line); <original statement> ).
my role LegacyActions {
  method statement(Mu $/) {
    callsame;
    my $inner := $/.made;
    return if $inner.^name eq 'NQPMu';
    return if $inner.^name ne 'QAST::Op';
    return if $inner.op eq 'while';
    return if $inner.op eq 'call' && $inner.name eq '&await';
    # a Pair inside a block becomes a hash, a list of statements turns it into a block
    return if $inner.returns.isa(Pair);

    my $file = $*W.current_file.IO.resolve;
    with stop-point($/, $file) -> $line {
      $/.make: QAST::Stmts.new(
        :resultchild(1),
        :returns($inner.returns),
        QAST::Op.new( :op('call'), QAST::WVal.new( :value(&maybe-stop) ),
          # pseudostash: caller's lexical scope, for the REPL
          QAST::Op.new( :op('callmethod'), :name('new'),
            QAST::WVal.new( :value(PseudoStash) ),
          ),
          QAST::SVal.new( :value($file) ),
          QAST::IVal.new( :value($line) ),
        ),
        $inner,
      );
    }
  }
}

# Actions mixin for the RakuAST frontend.
my role Actions {
  method statement(Mu $/) {
    callsame;
    my $made := $/.made;
    return unless nqp::istype($made, RakuAST::Statement::Expression);
    my $expr := $made.expression;
    return without $expr;
    # a bare fat-arrow statement is hash-vs-block disambiguation; leave it alone
    return if nqp::istype($expr, RakuAST::FatArrow);

    my $file = $*ORIGIN-SOURCE.original-file.IO.resolve;
    with stop-point($/, $file) -> $line {
      my $call := rakuast-call(&maybe-stop,
        rakuast-call(PseudoStash, :method<new>),   # caller's lexical scope, for the REPL
        RakuAST::StrLiteral.new($file.Str),
        RakuAST::IntLiteral.new($line),
      );
      $/.make: RakuAST::Statement::Expression.new(
        expression => RakuAST::Circumfix::Parentheses.new(
          RakuAST::SemiList.new(
            RakuAST::Statement::Expression.new(expression => $call),
            $made,
          )
        )
      );
    }
  }
}

use Slangify Mu, Actions, Mu, LegacyActions;
