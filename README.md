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

    ∙ Stopping thread Thread #1 (Initial thread)

    --- current stack ---
      in block <unit> at eg/example.raku line 6

    -- current location --
      2 │       │
      3 │       │     my $x = 100;
      4 │       │     $x = $x + 1;
      5 │       │     stop;
      6 │  [1]▶ │     $x = $x + 10000;
      7 │       │     $x++;
      8 │       │     $x++;
      9 │       │     $x++;
     10 │       │

    Type h for help
    dawa [1]> $x
    101
    dawa [1]> n
      7 ▶     $x++;
    dawa [1]> $x
    10101
    dawa [1]> n
      8 ▶     $x++;
    dawa [1]> $x
    10102
    dawa [1]> c

In the example above `[1]▶` indicates that this is the next
statement that will be executed by thread 1.  After advancing
one statement (with `n`), the statement that has not yet been
executed (and is coming up next) will be shown.

## DESCRIPTION

Dawa provides functionality that is inspired by
Ruby's [pry](https://github.com/pry/pry) and Python's
[import pdb; pdb.set_trace()](https://docs.python.org/3/library/pdb.html)
idiom.

It exports one subroutine: `stop`, which will pause
execution of the current thread of the program, and
allow for introspecting the stack, and stepping through
subsequent statements.

Using this module is heavy-handed -- currently just the `use`
command will add a lot of unused extra statements to the AST.
(This implementation may change in the future.)

## USAGE

After `stop` is reached, a repl is started, which has a few
commands.  Type `h` to see them.  Currently, these are the commands:

           break (b) : [N [filename] ] add a breakpoint at line N [in filename]
    continue (^D, c) : continue execution of this thread
            eval (e) : evaluate code in the current context
            help (h) : this help
              ls (l) : [-a] show [all] lexical variables in the current scope
            next (n) : run the next statement
         threads (t) : [id] show all threads that have been seen [or details of thread #id]
           where (w) : show a stack trace and the current location in the code

Pressing [enter] by itself on a blank line is the same as `next`.

Anything else is treated as a Raku statement: it will be evaluated,
the result will be shown.

### Breakpoints

Breakpoints can be set with `b`, for example:

dawa [1]> b 13
Added breakpoint at line 13 in eg/debug.raku
dawa [1]> w

      10 │       │
      11 │  [1]▶ │ say "three";
      12 │       │ say "four";
      13 │     ■ │ $x = $x + 11;
      14 │       │ say "five";
      15 │       │ say "x is $x";
      16 │       │ say "bye";
      17 │       │

As shown above, breakpoints are indicated using `■` and are not
thread-specific.  The triangle (▶) is the next line of code that
will be executed.  The `[1]` indicates the next statement to be executed
by thread 1.  The `[1]` in the prompt indicates that statements
will currently be evaluated in the context of thread 1 by default.

## Multiple Threads

If several threads are stopped at once, a lock is used in order to
only have one repl at a time.  Threads wait for this lock.  The
id of the thread will be in the prompt, as shown above.  Other threads'
positions will also be indicated.

    ∙ Stopping thread Thread #1 (Initial thread)

    --- current stack ---
      in block <unit> at example.raku line 11

    -- current location --
       3 │       │ my $i = 1;
       4 │       │
       5 │       │ start loop {
       6 │       │   $i++;
       7 │   [7] │   $i++;
       8 │       │ }
       9 │       │
      10 │       │ stop;
      11 │  [1]▶ │ say 'bye!';
      12 │       │

    Type h for help
    dawa [1]>

Note that in this situation thread 7 continues to run even while the repl
is active.  To also stop thread 7 while debugging, you can add a breakpoint
(since breakpoints apply to all threads).

The `eval` command can be used to evaluate expression in another thread.  For instance,
`eval 7 $i` will evaluate the `$i` in thread 7.

The `ls` command can show lexical variables in another thread.  Note that only variables
in the innermost lexical scope will be shown.

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

Since this relies on undocumented behavior, it could break at any time.  Modifying
the AST may also cause your program to behave in unexpected ways.  It may be
possible to improve this once the AST work in Raku is available.

The `stop` routine won't work if it is the last statement in a file.

There are probably other bugs -- let me know and send a patch!  Also
a mailing list is available to discuss features and send patches:

  https://lists.sr.ht/~bduggan/raku-dawa

## AUTHOR

Brian Duggan (bduggan at matatu.org)
