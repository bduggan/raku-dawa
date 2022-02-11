use nqp;
use Dawa::Debugger;

use QAST:from<NQP>;

my Bool $debugging = False;
my $debugger = Dawa::Debugger.new;

sub stop is export {
  $debugging = True;
}

sub maybe-stop($context) is hidden-from-backtrace {
  return unless $debugging;
  my $stack = Backtrace.new;
  $debugger.run-repl(:$context,:$stack);
  $debugging = so $debugger.should-stop;
};

sub EXPORT(|) {
  role Dawa {
    method statement(Mu $/) {
      $/.make:
        QAST::Stmts.new(
          QAST::Op.new( :op('call'), QAST::WVal.new( :value(&maybe-stop) ),
            # pseudostash:
            QAST::Op.new(
               :op('callmethod'), :name('new'),
               QAST::WVal.new( :value($*W.find_single_symbol('PseudoStash')))
            )
          ),
          callsame
        );
    }
  }
  $*LANG.define_slang: 'MAIN', $*LANG.slang_grammar('MAIN'), $*LANG.actions.^mixin(Dawa);
  {}
}
