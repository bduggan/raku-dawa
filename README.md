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
    dawa (1)> $x
    101
    dawa (1)> n
      7 ▶ $x++;
    dawa (1)> $x
    10101
    dawa (1)> n
      8 ▶ $x++;
    dawa (1)> $x
    10102
    dawa (1)> c
    %

## DESCRIPTION

Dawa provides functionality that is inspired by
Ruby's [pry](https://github.com/pry/pry) and Python's
[import pdb; pdb.set_trace()](https://docs.python.org/3/library/pdb.html)
idiom.

It exports a subroutine `stop` which will pause execution
of the current thread of the program, and allow for introspecting
the stack, and stepping through subsequent statements.

Using this module is heavy-handed -- currently just the `use` command will add a lot of unused extra statements to the AST.
(This implementation may change in the future.)

## USAGE

After `stop` is reached, a repl is started, which has a few
commands.  Type `h` to see them.  Currently, these are the commands:

           break (b) : add a breakpoint (line + optional file)
    continue (c, ^D) : continue execution of this thread
            eval (e) : evaluate code in the current context
            help (h) : this help
              ls (l) : show lexical variables in the current scope (-a for all)
            next (n) : run the next statement
           where (w) : show a stack trace and the current location in the code

Pressing [enter] by itself on a blank line is the same as `next`.

Anything else is treated as a Raku statement: it will be evaluated,
the result will be shown.

### Breakpoints

Breakpoints can be set with `b`, for example:

     dawa (1)> b 13
     Added breakpoint at line 13 in eg/debug.raku
     dawa (1)> w
     ...
      12 │ say "four";
      13 ■ $x = $x + 11;
      14 │ say "five";
      15 │ say "x is $x";

As shown above, breakpoints are indicated using `■` in the code
listing, and are not thread-specific.

## Multiple Threads

If several threads are stopped at once, a lock is used in order to
only have one repl at a time.  Threads wait for this lock.  The
id of the thread will be in the prompt.  For example:

    use Dawa;

    my $x = 10;
    start {
      stop;
      $x++;
    }
    stop;
    say "x is $x";

can result in :

    ∙ Stopping thread Thread #1 (Initial thread)
    ∙ Stopping thread Thread #7 (GeneralWorker)

    --- current stack ---
        in sub  at eg/threads-4.raku line 5

    -- current location --
      1 │ use Dawa;
      2 │
      3 │ my $x = 10;
      4 │ start {
      5 ◀   stop;
      6 ▶   $x++;
      7 │ }
      8 │ stop;
      9 │ say "x is $x";
     10 │

    Type h for help
    dawa (7)> $x
    10
    dawa (7)> continue

    --- current stack ---
        in sub <unit> at eg/threads-4.raku line 8

    -- current location --
      1 │ use Dawa;
      2 │
      3 │ my $x = 10;
      4 │ start {
      5 │   stop;
      6 │   $x++;
      7 │ }
      8 ◀ stop;
      9 ▶ say "x is $x";
     10 │

    dawa (1)> $x
    11
    dawa (1)> continue
    x is 11


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

There are probably other bugs -- let me know and send a patch!  Also
a mailing list is available to discuss features and send patches:

  https://lists.sr.ht/~bduggan/raku-dawa

## AUTHOR

Brian Duggan (bduggan at matatu.org)
