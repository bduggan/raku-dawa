unit module Dawa::Debugger::Helpers;

sub find-snippets(:$line,:$file,:%snippets) is export {
  my $f = $file.IO.resolve;
  my $snippet = %snippets{ $f }{ $line };
  my @snippets = $snippet;
  unless %snippets{ $f } {
    note "file $f not found in " ~ %snippets.keys.join(',');
    return;
  }
  if $snippet.lines > 1 {
    for 1..$snippet.lines - 1 {
      with %snippets{ $f }{ $line + $_ } -> $s {
        push @snippets, $s;
      }
    }
  }
  @snippets;
}
