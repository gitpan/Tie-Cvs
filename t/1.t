# -*- cperl -*-

use Test::More tests => 1 + 2 * 18;

BEGIN { use_ok('Tie::Cvs') }

# norm and norminv are inverse one from the other

my %data = (
	    # NORMAL
	    "teste"       => "teste",

	    # SPACE
	    "foo bar"     => 'foo%spacebar',
            ' '           => '%space',

	    # PERCENT
	    "foo%bar"     => 'foo%percentbar',
	    "foo%percent" => 'foo%percentpercent',
	    "foo %"       => 'foo%space%percent',
            "%"           => '%percent',

	    # SLASH
            "foo/bar"     => 'foo%slashbar',
            '/'           => '%slash',
	    '%slash'      => '%percentslash',

	    # CVS e CVSROOT
	    'CVS'         => '%CVS',
	    'CVSROOT'     => '%CVSROOT',
	    ' CVS'        => '%spaceCVS',
            'aCVS'        => 'aCVS',
            '%CVS'        => '%percentCVS',
            '%CVSROOT'    => '%percentCVSROOT',
	    # TAB
            "\t"          => '%tab',

	    # MISC
	    " %/\t"         => '%space%percent%slash%tab',
	   );

for $a (keys %data) {
  is(Tie::Cvs::norm($a),$data{$a});
  is(Tie::Cvs::norminv(Tie::Cvs::norm($a)), $a)
}


