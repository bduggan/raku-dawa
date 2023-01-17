## NAME

Dawa -- A runtime debugger for Raku programs

## EXAMPLES

Use from the command line with the `dawa` command:

<img width="509" alt="dawa-2" src="https://user-images.githubusercontent.com/58956/212915084-05cfc734-2ec7-4eb5-9a0d-dc17cbed7fce.png">

Use from within a program with the `stop` statement:

<img width="558" alt="dawa-1" src="https://user-images.githubusercontent.com/58956/212917285-f34269fe-a4ba-4128-ba28-30ec56b74c0e.png">

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
      in block <unit> at eg/example.raku line 5

    -- current location --
      1 │       │     use Dawa;
      2 │       │
      3 │       │     my $x = 100;
      4 │       │     $x = $x + 1;
      5 │  [1]▶ │     stop;
      6 │       │     $x = $x + 10000;
      7 │       │     $x++;
      8 │       │     $x++;
      9 │       │     $x++;
     10 │       │

    Type h for help
    dawa [1]> $x
    101
    dawa [1]> n
      2      │
      3      │      my $x = 100;
      4      │      $x = $x + 1;
      5      │      stop;
      6 ▷    │      $x = $x + 10000;
      7      │      $x++;
      8      │      $x++;
      9      │      $x++;
    dawa [1]> $x
    10101
    dawa [1]>

In the example above `[1]▶` indicates that this is the most
recent statement that was executed on thread 1.

After typing "n", the `▷` indicates the statement that
was just executed.

Continue typing "n", and statements will continue to
be executed.

A command line program, `dawa`, will run a program and
stop after running a statement on the first line.

## DESCRIPTION

Dawa is a run-time debugger for Raku programs.

It exports one subroutine: `stop`, which will pause
execution of the current thread of the program, and
allow for introspecting the stack, and stepping through
subsequent statements.  It also supports debugging of
multi-threaded programs.

Importing `Dawa` adds extra ops to the AST that is
generated during compilation.  Specifically, it adds
at most one extra node per line.  There is a significant
perforance penalty for this, as well as a risk that your
program will break.  Patches welcome!

The functionality of `dawa` is inspired by
Ruby's [pry](https://github.com/pry/pry) and Python's
[pdb](https://docs.python.org/3/library/pdb.html).

## USAGE

After `stop` is reached, a repl is started, which has a few
commands.  Type `h` to see them.  Currently, these are the commands:

           break (b) : [N [filename] ] add a breakpoint at line N [in filename]
    continue (c, ^D) : continue execution of this thread
           defer (d) : [n] Defer to thread [n], or the next waiting one
            eval (e) : [id] evaluate code in the current context [or in thread #id]
            help (h) : this help
              ls (l) : [-a] [id] show [all] lexical variables in the current scope [or in thread #id]
            next (n) : run the next statement in any thread
            quit (q) : terminate the program (exit)
            step (s) : execute the next statement in the same thread
         threads (t) : [id] show threads being tracked [or just thread #id]
           where (w) : show a stack trace and the current location in the code

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
thread-specific.  The triangle (▶) is the line of code that
was just executed.  The `[1]` indicates that this is thread 1.
The `[1]` in the prompt indicates that statements will currently
be evaluated in the context of thread 1 by default.

## Details of "next"

In Raku, there can be multiple statements per line, and multiple
"statements" within a statement, which makes it tricky to debug a
program by stepping through "statements" or stepping through "lines".
Dawa has a number of heuristics for when to stop, but the idea is to
stop at most once per line and at most once per statement.  Typing "n"
may sometimes stay within the same block of code, if a statement containing
other statements spans several lines.  The display will indicate
the block of code containing the statement that was just executed.

## Multiple Threads

If several threads are stopped at once, a lock is used in order to
only have one repl at a time.  Threads wait for this lock.  After
either continuing or going on to the next statement, another thread
that is waiting for the lock may potentially become active in the repl.
i.e. "next" advances to the next statement in any thread.  To stay in
the same thread, use "step".

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
      10 │  [1]▶ │ stop;
      11 │       │ say 'bye!';
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

The `defer` command can be used to switch to another stopped thread.  Here is an example:

### Switching between threads

When multiple threads are stopped, `defer` will switch from one to another.
For instance, the example below has `eg/defer.raku`, with threads 7-11 stopped,
as well as thread 1.  After looking at the stack in thread 1, typing `d 8`
will change to thread 8, and subsequent commands will run in the context
of that thread.  (also note that if a lot of threads are stopped at the same
line of code, they are shown in a footnote)

    dawa [1]> w

    --- current stack ---
      in block <unit> at eg/defer.raku line 16

    -- current location --
       4 │       │   start {
       5 │       │     my $x = 10;
       6 │       │     loop {
       7 │       │       stop;
       8 │   (a) │       $x++;
       9 │       │     }
      10 │       │   }
      11 │       │ }
      12 │       │
      13 │       │ my $y = 100;
      14 │       │ loop {
      15 │       │   stop;
      16 │  [1]▶ │   say "y is $y";
      17 │       │   $y += 111;
      18 │       │   last if $y > 500;
      19 │       │ }
      20 │       │
    ────────────────────────────────────────
    (a) : [8][9][7][10][11]
    ────────────────────────────────────────

    dawa [1]> d 8
      8 ▶       $x++;
    dawa [8]> w

    --- current stack ---
      in block  at eg/defer.raku line 8

    -- current location --
      4 │       │   start {
      5 │       │     my $x = 10;
      6 │       │     loop {
      7 │       │       stop;
      8 │  (a)▶ │       $x++;
      9 │       │     }
     10 │       │   }
     11 │       │ }
     12 │       │
     13 │       │ my $y = 100;
     14 │       │ loop {
     15 │       │   stop;
     16 │   [1] │   say "y is $y";
     17 │       │   $y += 111;
     18 │       │   last if $y > 500;
     19 │       │ }
     20 │       │
    ────────────────────────────────────────
    (a) : [8][9][7][10][11]
    ────────────────────────────────────────

    dawa [8]> $x
    10

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
