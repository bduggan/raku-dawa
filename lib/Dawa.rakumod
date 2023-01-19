use nqp;
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
  $debugger.stop-thread;
  %debugging{ $*THREAD.id } = True;
  my $tracking = TrackingState.new;
  %tracking{ $*THREAD.id } = $tracking;
}

my Lock $repl-lock .= new;
my atomicint $deferred-to;

my $stopped-once = False;
sub maybe-stop($context, $file, $line) is hidden-from-backtrace {
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

sub EXPORT(|) {
  role Dawa {
    method statement(Mu $/) {
      callsame;
      return if %debugging{ $*THREAD.id };
      my $inner := $/.made;
      my $file = $*W.current_file.IO.resolve;
      my $line-text = substr($/.orig,$/.from,$/.to - $/.from);
      my $line-number = substr($/.orig,0,$/.from).comb.grep("\n").elems + 1;
      if %added-lines{ $file }{ $line-number } {
        return
      }
      return if $inner.^name eq 'NQPMu';
      return if $inner.^name ne 'QAST::Op';
      return if $inner.op eq 'while';
      my $prev := substr($/.orig,0,$/.from);
      my $ok = so $prev ~~ / [ \n | ^ ] \s* $/;
      return unless $ok;
      return if $inner.op eq 'call' && $inner.name eq '&await';

      # a Pair inside a block becomes a hash, a list of statements turns it into a block
      return if $inner.returns.isa(Pair);
      %snippets{ $file }{ $line-number } = Snippet.new: :$line-text, from => $/.from, to => $/.to, orig => $/.orig.Str;
      %added-lines{ $file }{ $line-number } = True;
      my $ast := QAST::Stmts.new(
                    :resultchild(1),
                    :returns($inner.returns),
                    QAST::Op.new( :op('call'), QAST::WVal.new( :value(&maybe-stop) ),
                      # pseudostash:
                      QAST::Op.new(
                         :op('callmethod'), :name('new'),
                         QAST::WVal.new( :value($*W.find_single_symbol('PseudoStash')))
                      ),
                      # also pass snippet index as an argument
                      QAST::SVal.new(:value($file)),
                      QAST::IVal.new(:value($line-number)),
                    ),
                    $inner
                );
      $/.make: $ast;
    }
  }
  $*LANG.define_slang: 'MAIN', $*LANG.slang_grammar('MAIN'), $*LANG.actions.^mixin(Dawa);
  {}
}
