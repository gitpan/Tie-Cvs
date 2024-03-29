# -*- cperl -*-

use Test::More tests => 2 + 25 ;

BEGIN { use_ok('Tie::Cvs') }

# =

`perl -MExtUtils::Command -e rm_rf /tmp/tmpcvs /tmp/tmpcvs.co`;

my %tie;
tie %tie, 'Tie::Cvs', "/tmp/tmpcvs";

for(1..25) {
  $tie{"chave $_"} = "Valor de $_$_$_\n";
  ok(1); 			# para mostrar progresso
}

open(R,">_out");
for(keys %tie) { print R "$_\n $tie{$_}\n"};
close R;

$l = 0;
open R, "_out";
while(<R>) { $l++ }
close R;
is($l,75);

unlink "_out";
