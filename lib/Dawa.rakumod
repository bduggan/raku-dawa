use nqp;
use Dawa::Debugger;
use Dawa::Exception;
use QAST:from<NQP>;
use Terminal::ANSI::OO 't';

my Bool %debugging;
my %tracking;

my %breakpoints;

my $debugger = Dawa::Debugger.new;

class TrackingState {
  has $.context;
  has $!backtrace;
  has $.thread-gist = $*THREAD.gist;
  has $.file;
  has $.line;

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
  %tracking{ $*THREAD.id } = TrackingState.new;
}

my Lock $repl-lock .= new;
my atomicint $deferred-to;

sub maybe-stop($context) is hidden-from-backtrace {
  %tracking{ $*THREAD.id } = TrackingState.new(:$context);
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
          $debugger.run-repl(:$context,:$stack, :%tracking);
          $deferred-to = 0;
        } else {
          $delay = 1;
          $start-repl = True;
        }
      }
      CATCH {
          when Dawa::Exception {
            given .defer-to -> $n {
              $deferred-to = $n;
              when $n == $*THREAD.id {
                $start-repl = True;
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

sub EXPORT(|) {
  role Dawa {
    method statement(Mu $/) {
      my $inner := callsame;
      my $ast := QAST::Stmts.new(
                    QAST::Op.new( :op('call'), QAST::WVal.new( :value(&maybe-stop) ),
                      # pseudostash:
                      QAST::Op.new(
                         :op('callmethod'), :name('new'),
                         QAST::WVal.new( :value($*W.find_single_symbol('PseudoStash')))
                      )
                    ),
                     $inner
                );
      if nqp::istype($inner,QAST::Op) {
        $ast.sunk(1) unless $inner.op eq 'callmethod';
      }
      $/.make: $ast;
    }
  }
  $*LANG.define_slang: 'MAIN', $*LANG.slang_grammar('MAIN'), $*LANG.actions.^mixin(Dawa);
  {}
}
