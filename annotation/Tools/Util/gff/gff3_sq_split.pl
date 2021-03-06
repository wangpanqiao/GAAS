#!/usr/bin/env perl

###################################################
# Jacques Dainat 01/2016                          #  
# Bioinformatics Infrastructure for Life Sciences #
# jacques.dainat@bils.se                          #
###################################################

use Carp;
use strict;
use warnings;
use Pod::Usage;
use Getopt::Long;
use IO::File ;
use Bio::Tools::GFF;
use BILS::Handler::GFF3handler qw(:Ok);
use BILS::Handler::GXFhandler qw(:Ok);

my $start_run = time();

my $inputFile=undef;
my $outfolder=undef;
my $opt_help = 0;
my $interval=1000;
my $feature_type="gene";

Getopt::Long::Configure ('bundling');
if ( !GetOptions ('file|input|gff=s' => \$inputFile,
      'ft|feature_type=s' => \$feature_type,
      'i|interval=i' => \$interval,
      'o|output=s' => \$outfolder,
      'h|help!'         => \$opt_help )  )
{
    pod2usage( { -message => 'Failed to parse command line',
                 -verbose => 1,
                 -exitval => 1 } );
}

if ($opt_help) {
    pod2usage( { -verbose => 2,
                 -exitval => 0 } );
}

if ( !(defined($inputFile)) or !(defined($outfolder)) ){
   pod2usage( { -message => 'at least 2 parameters are mandatory: -i inputFile and -o $outfolder',
                 -verbose => 1,
                 -exitval => 1 } );
}

# Manage input fasta file
my $ref_in = Bio::Tools::GFF->new(-file => $inputFile, -gff_version => 3);

# Manage Output
if (-d $outfolder) {
  print "The output directory <$outfolder> already exists.\n";exit;
} 
else{
  print "Creating the $outfolder folder\n";
  mkdir $outfolder;
}

print "I will split the file into files containing $interval group of feature. The top feature of the group of feature is currenlty defined by <$feature_type>.\n";

#time to calcul progression
my $startP=time;
my $nbLine=`wc -l < $inputFile`;
$nbLine =~ s/ //g;
chomp $nbLine;
print "$nbLine line to process...\n";
my $line_cpt=0;

#my $fh=undef;
my $count_feature=0;
my $count_file=1;
my $file_name=$inputFile;
$file_name=~ s/.gff//g;
$file_name=~ s/.gff3//g;
my $gffout;
open(my $fh, '>', $outfolder."/".$file_name."_".$count_file.".gff") or die "Could not open file $file_name.'_'.$count_file.'.gff' $!";
$gffout= Bio::Tools::GFF->new(-fh => $fh, -gff_version => 3 );

while (my $feature = $ref_in->next_feature() ) {
  $line_cpt++;

  #What do we follow
  if($feature->primary_tag eq $feature_type){
    if($count_feature == $interval){
      close $fh;
      $count_file++;
      open(my $fh, '>', $outfolder."/".$file_name."_".$count_file.".gff") or die "Could not open file $file_name.'_'.$count_file.'.gff' $!";
      $gffout= Bio::Tools::GFF->new(-fh => $fh, -gff_version => 3 );
      $count_feature=0;
    }
    $count_feature++;
  }
  $gffout->write_feature($feature);
  #print $fh $feature->gff_string()."\n";

  #Display progression
  if ((30 - (time - $startP)) < 0) {
    my $done = ($line_cpt*100)/$nbLine;
    $done = sprintf ('%.0f', $done);
        print "\rProgression : $done % processed.\n";
    $startP= time;
  }
}
close $fh;

my $end_run = time();
my $run_time = $end_run - $start_run;
print "Job done in $run_time seconds\n";

__END__

=head1 NAME

gff3_sq_split.pl -
split gff3 file into several files.
By default we create files containing 1000 genes and all sub-features associated. GFF3 input file must be sequential.

=head1 SYNOPSIS

    gff3_sq_split.pl -i <input file> -o <output file>
    gff3_sq_split.pl --help

=head1 OPTIONS

=over 8

=item B<--gff>, B<--file> or B<--input>

STRING: Input gff file that will be read.

=item B<-i> or B<--interval>
Integer.  Number of group of feature to include in each file. 1000 by default.

=item B<--ft> or B<--feature_type>
The top feature of the feature group. By default "gene".

=item B<-o> or B<--output> 

STRING: Output file.  If no output file is specified, the output will be written to STDOUT. The result is in tabulate format.

=item B<--help> or B<-h>

Display this helpful text.

=back

=cut
