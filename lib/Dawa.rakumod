use nqp;
use Dawa::Debugger;
use QAST:from<NQP>;
use Terminal::ANSI::OO 't';

my Bool %debugging;
my %breakpoints;

my $debugger = Dawa::Debugger.new;

sub stop is export {
  $debugger.stop-thread;
  %debugging{ $*THREAD.id } = True;
}

my Lock $repl-lock .= new;

sub maybe-stop($context) is hidden-from-backtrace {
  stop if $debugger.breakpoint(callframe(1).file,callframe(1).line);
  return unless %debugging{ $*THREAD.id };
  my $stack = Backtrace.new;
  $repl-lock.protect: {
    $debugger.run-repl(:$context,:$stack);
  }
  $debugger.update-state(:%debugging);
};

sub EXPORT(|) {
  role Dawa {
    method statement(Mu $/) {
      $/.make:
        QAST::Stmts.new(
          callsame,
          QAST::Op.new( :op('call'), QAST::WVal.new( :value(&maybe-stop) ),
            # pseudostash:
            QAST::Op.new(
               :op('callmethod'), :name('new'),
               QAST::WVal.new( :value($*W.find_single_symbol('PseudoStash')))
            )
          )
        );
    }
  }
  $*LANG.define_slang: 'MAIN', $*LANG.slang_grammar('MAIN'), $*LANG.actions.^mixin(Dawa);
  {}
}
