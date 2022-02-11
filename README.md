## NAME

Dawa -- A runtime debugger for Raku programs

## SYNOPSIS

In example.raku:

    use Dawa;

    my $x = 100;
    $x = $x + 1;
    stop;
    $x = $x + 10000;
    $x++;
    $x++;
    $x++;

Then:

    % raku example.raku
    ∙ Stopping thread Thread #1 (Initial thread)

    --- current stack ---
        in sub <unit> at example.raku line 5

    -- current location --
      1 │ use Dawa;
      2 │
      3 │ my $x = 100;
      4 │ $x = $x + 1;
      5 ◀ stop;
      6 ▶ $x = $x + 10000;
      7 │ $x++;
      8 │ $x++;
      9 │ $x++;
     10 │

    Type h for help
    dawa> $x
    101
    dawa> n
      7 ▶ $x++;
    dawa> $x
    10101
    dawa> n
      8 ▶ $x++;
    dawa> $x
    10102
    dawa> c
    %

## DESCRIPTION

Dawa provides functionality that is inspired by
Ruby's [pry](https://github.com/pry/pry) and Python's
[import pdb; pdb.set_trace()](https://docs.python.org/3/library/pdb.html)
idiom.

It exports a subroutine `stop` which will pause execution
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

Anything else is treated as a Raku statement: it will be evaluated,
the result will be shown.

## ABOUT THE NAME

The word `dawa` can refer to either medicine or poison in Swahili.  In the
latter sense, it would be used to describe bug spray, i.e. a debugger -- but
hopefully it'll also help be a cure for any ailments in your programs.

## SEE ALSO

1. There is a built-in `repl` statement, which will pause execution
and start a repl loop at the current location.

2. [rakudo-debugger](https://github.com/jnthn/rakudo-debugger) provides
a separate executable for debugging.  Techniques there inspired
this module.

## ENVIRONMENT

The readline history is stored in `DAWA_HISTORY_FILE`, ~/.dawa-history by default.

## BUGS

The `stop` routine won't work if it is the last statement in a file.

There are probably other bugs -- let me know and send a patch!

## AUTHOR

Brian Duggan (bduggan at matatu.org)
