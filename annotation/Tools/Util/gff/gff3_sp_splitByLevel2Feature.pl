#!/usr/bin/env perl

my $header = qq{
########################################################
# NBIS 2015 - Sweden                                   #
# jacques.dainat\@nbis.se                               #
# Please cite NBIS (www.nbis.se) when using this tool. #
########################################################
};


use strict;
use Pod::Usage;
use Getopt::Long;
use BILS::Handler::GXFhandler qw(:Ok);
use BILS::Handler::GFF3handler qw(:Ok);
use Bio::Tools::GFF;

my $start_run = time();
my $opt_gfffile;
my $opt_output;
my $opt_help = 0;

# OPTION MANAGMENT
if ( !GetOptions( 'g|gff=s' => \$opt_gfffile,
                  'o|output=s'      => \$opt_output,

                  'h|help!'         => \$opt_help ) )
{
    pod2usage( { -message => 'Failed to parse command line',
                 -verbose => 1,
                 -exitval => 1 } );
}

# Print Help and exit
if ($opt_help) {
    pod2usage( { -verbose => 1,
                 -exitval => 0,
                 -message => "$header \n" } );
}

if (! defined($opt_gfffile) ){
    pod2usage( {
           -message => "$header\nAt least 1 parameter is mandatory:\nInput reference gff file (-g).\n\n".
           "Ouptut is optional. Look at the help documentation to know more.\n",
           -verbose => 0,
           -exitval => 1 } );
}

######################
# Manage output file #

my $gffout;
if ($opt_output) {
  $opt_output=~ s/.gff//g;
  }
else{
  print "Default output name: split_result\n";
  $opt_output="split_result";
}

if (-d $opt_output){
  print "The output directory choosen already exists. Please give me another Name.\n";exit();
}
mkdir $opt_output;

                #####################
                #     MAIN          #
                #####################

######################
### Parse GFF input #
my ($hash_omniscient, $hash_mRNAGeneLink) = slurp_gff3_file_JD({ input => $opt_gfffile
                                                              });
print ("GFF3 file parsed\n");


my %handlers;
my $gffout;
#################
# == LEVEL 1 == #
foreach my $tag_l1 (keys %{$hash_omniscient->{'level1'}}){ # primary_tag_key_level1 = gene or repeat etc...
  foreach my $key_l1 (keys %{$hash_omniscient->{'level1'}{$tag_l1}}){
      
    #################
    # == LEVEL 2 == #
    my $level1_printed=undef;
    foreach my $tag_l2 (keys %{$hash_omniscient->{'level2'}}){ # primary_tag_key_level2 = mrna or mirna or ncrna or trna etc...

      if ( exists ($hash_omniscient->{'level2'}{$tag_l2}{$key_l1} ) ){
        foreach my $feature_level2 ( @{$hash_omniscient->{'level2'}{$tag_l2}{$key_l1}}) {
          #manage handler
          if(! exists ( $handlers{$tag_l2} ) ) {
            open(my $fh, '>', $opt_output."/".$tag_l2.".gff") or die "Could not open file '$tag_l2' $!";
            $gffout= Bio::Tools::GFF->new(-fh => $fh, -gff_version => 3 );
            $handlers{$tag_l2}=$gffout;
          }
          $gffout = $handlers{$tag_l2};

          #################
          # == LEVEL 1 == #
          if(! $level1_printed){
            $gffout->write_feature($hash_omniscient->{'level1'}{$tag_l1}{$key_l1}); # print feature
            $level1_printed=1;
          }

          #################
          # == LEVEL 2 == #
          $gffout->write_feature($feature_level2);

          #################
          # == LEVEL 3 == #
          my $level2_ID = lc($feature_level2->_tag_value('ID'));

          ###########
          # Before tss
          if ( exists_keys($hash_omniscient,('level3','tss',$level2_ID)) ){
            foreach my $feature_level3 ( @{$hash_omniscient->{'level3'}{'tss'}{$level2_ID}}) {
              $gffout->write_feature($feature_level3);
            }
          }

          ######
          # FIRST EXON
          if ( exists_keys($hash_omniscient,('level3','exon',$level2_ID)) ){
            foreach my $feature_level3 ( @{$hash_omniscient->{'level3'}{'exon'}{$level2_ID}}) {
              $gffout->write_feature($feature_level3);
            }
          }
          ###########
          # SECOND CDS
          if ( exists_keys($hash_omniscient,('level3','cds',$level2_ID)) ){
            foreach my $feature_level3 ( @{$hash_omniscient->{'level3'}{'cds'}{$level2_ID}}) {
              $gffout->write_feature($feature_level3);
            }
          }

          ###########
          # Last tts
          if ( exists_keys($hash_omniscient,('level3','tts',$level2_ID)) ){
            foreach my $feature_level3 ( @{$hash_omniscient->{'level3'}{'tts'}{$level2_ID}}) {
              $gffout->write_feature($feature_level3);
            }
          }

          ###########
          # The rest
          foreach my $primary_tag_key_level3 (keys %{$hash_omniscient->{'level3'}}){ # primary_tag_key_level3 = cds or exon or start_codon or utr etc...
            if( ($primary_tag_key_level3 ne 'cds') and ($primary_tag_key_level3 ne 'exon') and ($primary_tag_key_level3 ne 'tss') and ($primary_tag_key_level3 ne 'tts')){
              if ( exists ($hash_omniscient->{'level3'}{$primary_tag_key_level3}{$level2_ID} ) ){
                foreach my $feature_level3 ( @{$hash_omniscient->{'level3'}{$primary_tag_key_level3}{$level2_ID}}) {
                  $gffout->write_feature($feature_level3);
                }
              }
            }
          }
        }
      }
    }
  }
}


my $end_run = time();
my $run_time = $end_run - $start_run;
print "Job done in $run_time seconds\n";
__END__

=head1 NAME

gff3_fix_cds_frame.pl -
The script will split the gff input file into different files according to the different Level2 feature that it contains.

=head1 SYNOPSIS

    ./gff3_sp_splitByLevel2Feature.pl -g infile.gff [ -o outfolder ]
    ./gff3_sp_splitByLevel2Feature.pl --help

=head1 OPTIONS

=over 8

=item B<-g>, B<--gff> or B<-ref>

Input GFF3 file that will be read (and sorted)

=item B<-o> or B<--output>

Output folder.  If no output folder provided, the default name will be <split_result>.

=item B<-h> or B<--help>

Display this helpful text.

=back

=cut
