use 5.006;
use ExtUtils::MakeMaker;

print "Some of the Tie::Cvs tests take some time (about 1 or 2 minutes)\n";
print "Do you want to skip these tests? [no] ";
my $op = <STDIN>;
chomp($op);

if ($op =~ m!yes!i || $op eq "y") {
	# remove if they exist;
	unlink "t/2.t" if -f "t/2.t";
	unlink "t/3.t" if -f "t/3.t";
	print "Skipping!\n";
} else {
	# cp the .t.demorado to .t
	`perl -MExtUtils::Command -e cp "t/2.t.demorado" "t/2.t"`;
	`perl -MExtUtils::Command -e cp "t/3.t.demorado" "t/3.t"`;
	print "Not skipping!\n";
}

WriteMakefile(
    'NAME'		=> 'Tie::Cvs',
    'VERSION_FROM'	=> 'Cvs.pm',
    'PREREQ_PM'		=> {},

    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM => 'Cvs.pm'):()),
);
