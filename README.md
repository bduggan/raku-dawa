## NAME

Dawa -- A debugger for Raku

## SYNOPSIS

    use Dawa;

    my $x = 100;
    $x = $x + 1;
    stop;
    $x = $x + 10000;

## DESCRIPTION

Dawa provides functionality that is inspired by
Ruby's [pry](https://github.com/pry/pry) and Python's
[import pdb; pdb.set_trace()](https://docs.python.org/3/library/pdb.html)
idiom.

It exports a subroutine `stop` will which pause execution
of the current thread of the program, and allow for introspecting
the stack, and stepping through subsequent statements.

Using this module is heavy-handed -- currently just the `use`
command will add a lot of unused extra statements to the AST.
(This implementation may change in the future.)

## USAGE

After `stop` is reached, a repl is started, which has a few
commands.  Type `h` to see them.  Currently, these are the commands:

       n or [return] : advance to the next statement
             c or ^D : continue execution of this thread
                   w : show the current stack and code location
                   h : this help

## ABOUT THE NAME

The word `dawa` can refer to either medicine or poison in Swahili.  In the
latter sense, it would be used to describe bug spray, i.e. a debugger -- but
hopefully it'll also help be a cure for any ailments in your programs.

## SEE ALSO

1. There is a built-in `repl` command, which will pause execution
and drop to a repl.  (But it's not possible to step through
the program.)

2. [rakudo-debugger](https://github.com/jnthn/rakudo-debugger) -- which
provides a separate executable.  Techniques there provided inspiration for
this module.

## ENVIRONMENT

The readline history is stored in `DAWA_HISTORY_FILE`, ~/.dawa-history by default.

## BUGS

The `stop`routine won't work if it is the last statement in a file.

There are probably other bugs -- let me know and send a patch!

## AUTHOR

Brian Duggan (bduggan at matatu.org)
