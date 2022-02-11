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



## ABOUT THE NAME


## SEE ALSO

1. There is a built-in `repl` command, which will pause execution
and drop to a repl.  (But it's not possible to step through
the program.)

2. [rakudo-debugger](https://github.com/jnthn/rakudo-debugger) -- which
provides a separate executable.  Techniques there provided inspiration for
this module.

## BUGS

The debugger won't work if it is the last statement in a file.
