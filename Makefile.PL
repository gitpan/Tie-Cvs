use 5.006;
use ExtUtils::MakeMaker;

WriteMakefile(
    'NAME'		=> 'Tie::Cvs',
    'VERSION_FROM'	=> 'Cvs.pm',
    'PREREQ_PM'		=> {},

    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM => 'Cvs.pm'):()),
);
