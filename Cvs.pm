package Tie::Cvs;

use 5.006;
use strict;
use warnings;
use Carp;

require Exporter;

our @ISA = qw(Exporter);
our %EXPORT_TAGS = ( 'all' => [ qw( ) ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw( );
our $VERSION = '0.02';

my $DEBUG=0;

sub TIEHASH {
  my $class = shift;
  my $dir = shift || croak "usage: Tie::Cvs DIR [permission]";
  my $chmod = shift || 0644;

  my %del_versions = ();

  croak "usage: Tie::Cvs DIR" if @_;
  croak "absolute DIR expected" unless ($dir =~ m{^/});

  unless ( (-d $dir) && (-d "$dir/CVSROOT")){
    # Create CVS directory, and directory for check-out
    mkdir $dir;
    mkdir("$dir.co") ;

    # Initialize the CVS directory
    mysystem("cvs -d $dir -Q init");

    # Check-out CVS directory (empty, hopefully)
    mysystem("cd $dir.co; cvs -d $dir -Q co .");

    # Create a file for previous deleted versions
    open DEL, ">$dir.co/CVSROOT/tiecvs.deleted" or croak "foo\n";
    print DEL "## DELETED VERSIONS FROM TIE::CVS\n";
    close DEL;

    # Add the created file
    mysystem("cd $dir.co/CVSROOT; cvs -Q add tiecvs.deleted;
              cvs ci -m 'created and added by Tie::Cvs' tiecvs.deleted");
  } else {
    # update the CVS checkout directory
    mysystem("cd $dir.co; cvs -Q update");

    # read the tiecvs.deleted file and create cache
    open DEL, "$dir.co/CVSROOT/tiecvs.deleted" or croak "Cannot open tiecvs.deleted file\n";
    my $l;
    while($l = <DEL>) {
      next if $l =~ m!^\#!;
      chomp $l;
      my @l = split /\s+/, $l;
      my $file = shift @l;
      push @{$del_versions{$file}}, @l;
    }
    close DEL;
  }

  # create our object and return it
  my $self = { copia    => "$dir.co",
               deleted => \%del_versions,
               chmod => $chmod,
               dir      => $dir, };
  return bless $self, $class;
}


sub FETCH {
  my $self = shift;
  my $file = $self->{copia}."/".norm(shift(@_));
  return (-f $file)?cat($file):undef;
}

sub STORE {
  my ($self,$key,$value) = @_;
  $key = norm($key);

  my $cop = $self->{copia};
  my $ex = (-f "$cop/$key");

  open(F, "> $cop/$key") || croak "can't open $cop/$key: $!";
  print F $value;
  close(F);
  chmod($self->{'chmod'},"$cop/$key");

  if ($ex) {
    mysystem("cd $cop; cvs -Q update; cvs -Q ci -m 'changed by tie' $key")
  } else {
    mysystem("cd $cop; cvs -Q add $key; cvs -Q ci -m 'added by tie' $key")
  }
  $value
}

sub DELETE {
  my $self = shift;
  my $key = norm(shift(@_));
  my $cop = $self->{copia};
  my $ex = (-f "$cop/$key");

  if ($ex) {
    # Get our current version
    open E, "$cop/CVS/Entries" or croak "Cannot open Entries file: $!";
    my $pv = undef; # current version
    my $v  = undef; # previous version
    while (<E>) {
      if (m!^/$key/([^/]+)/!) { $pv = $1 }
    }
    close E;

    # Get deleted versions, if they exists
    my @delvers = ();
    @delvers = @{$self->{deleted}{$key}} if exists $self->{deleted}{$key};

    # Rollback our version
    $v = roll_back($pv, @delvers);

    # Add each one of the versions to the deleted ones, if it exists
    push @{$self->{deleted}{$key}}, $pv if $pv;
    push @{$self->{deleted}{$key}}, $v  if $v;

    # Save deleted versions file
    $self->save_deleted();

    # debug...
    print STDERR "** ROLLBACK FROM $pv TO $v\n" if $DEBUG;
    print STDERR "** DELETED: ",join(" ",@{$self->{deleted}{$key}}),"\n" if $DEBUG;

    # If there is still a version...
    if ($v) {
      # rollback
      mysystem("cd $cop;
                cvs -Q update -j $pv -j $v $key;
                cvs -Q ci -m 'rollback by tie' $key");
    } else {
      # remove file
      unlink("$cop/$key");
      mysystem("cd $cop;
                cvs -Q remove $key; cvs -Q ci -m 'del by tie' $key");
    }
  }
  return $ex
}

sub roll_back {
  my ($v, @delvers) = @_;
  return $v unless $v;

  do {
    return undef if $v eq "1.1.1.1" || $v eq "1.1";
    $v -= 0.1;
  } while(grep {$_ eq $v} @delvers);

  return $v;
}

sub CLEAR {
  # ??
}

sub EXISTS   {
  my $self = shift;
  my $key = norm(shift(@_));
  return (-f "$self->{copia}/$key")
}

sub FIRSTKEY {
  my $self = shift;
  my $cop = $self->{copia};
  $self->{keys} = [map { s{.*/}{} ; $_ } grep {-f $_ } < $cop/* > ];
  my $key = shift @{$self->{keys}};

  return (wantarray)?( norminv($key), $self->FETCH($key)):norminv($key)
}


sub NEXTKEY  {
  my $self = shift;
  my $key = shift @{$self->{keys}};

  if ($key){
    return (wantarray)?( norminv($key), $self->FETCH($key)):norminv($key);
  } else {
    return undef
  }
}


sub DESTROY  {
  # Here we do not need to do anything at all!
}

sub norm {
  my $str = shift;
  return '%CVS' if $str eq "CVS";
  return '%CVSROOT' if $str eq "CVSROOT";
  for ($str) {
    s/\%/\%\%/g;
    s/_/\%_/g;
    s/\ /_/g;
    s/\t/\%t/g;
    s/\//\%s/g;
  }
  $str
}

sub norminv {
  my $str = shift;
  return 'CVS' if $str eq "%CVS";
  return 'CVSROOT' if $str eq "%CVSROOT";
  for ($str) {
    s/\%\%/\x01/g;
    s/\%s/\//g;
    s/\%t/\t/g;
    s/(?<!%)_/ /g;
    s/\%_/_/g;
    s/\x01/\%/g;
  }
  $str;
}

sub cat {
  my $file = shift;
  my $text;
  local $/;
  open F, "$file" or croak "Cannot open $file.\n";
  $text = <F>;
  close F;
  return $text
}

sub mysystem {
  my $cmd = shift;
  print STDERR "** EXECUTING: $cmd\n" if $DEBUG;
  ##system($cmd);
  `$cmd`;
}

sub save_deleted {
  my $self = shift;
  open DEL, "> $self->{copia}/CVSROOT/tiecvs.deleted" or croak "Cannot create tiecvs.deleted file: $!\n";
  print DEL "## DELETED VERSIONS FROM TIE::CVS\n";
  for (keys %{$self->{deleted}}) {
    print DEL "$_ ",join(" ",@{$self->{deleted}{$_}}),"\n";
  }
  close DEL;
  mysystem("cd $self->{copia}/CVSROOT; cvs -Q update tiecvs.deleted;
            cvs -Q ci -m 'created' tiecvs.deleted");
}

1;
__END__


=head1 NAME

Tie::Cvs - Perl extension to tie Hashes to CVS trees

=head1 SYNOPSIS

  use Tie::Cvs;

  tie %cvs, 'Tie::Cvs', "/root/mycvsroot";

=head1 ABSTRACT

  Tie::Cvs is a module to tie Perl hashes with a CVS Tree.  It uses
  CVS versioning system such that the hash will have value versions.

=head1 DESCRIPTION

Use it normally, as any other tie.

=head2 Complete deletion of a key

Each time you call delete on a key, the current version will be
deleted, and the value will roll back to the previous version in
CVS. If there is no previous version, the file will be deleted.

If you want to delete completly a key (delete the file) use something
like:

  while(delete($cvs{$key})) {}

=head1 SEE ALSO

perltie

=head1 AUTHOR

Jose Joao Dias de Almeida, E<lt>jj@di.uminho.ptE<gt>
Alberto Manuel B. Sim�es, E<lt>albie@alfarrabio.di.uminho.ptE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2003 by Projecto Natura

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
