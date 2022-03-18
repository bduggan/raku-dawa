unit class Dawa::Exception is Exception;

has Int $.defer-to;
has Bool $.should-continue = False;

