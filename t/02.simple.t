# -*- cperl -*-

use Test::More tests => 2 + 20*25;

BEGIN { use_ok('Tie::Cvs') }


my %tie;

tie %tie, 'Tie::Cvs', "/tmp/tmpcvs";

open(R, ">_out");
for(1..20) {
  for(keys %tie) { print R "$_\n $tie{$_}\n"; ok(1)};
}
close R;

$l = 0;
open R, "_out";
while(<R>) { $l++ }
close R;
is($l,1500);

`perl -MExtUtils::Command -e rm_rf /tmp/tmpcvs /tmp/tmpcvs.co`;
