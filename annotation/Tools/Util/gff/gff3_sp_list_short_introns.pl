#!/usr/bin/env perl

use strict;
use warnings;
use POSIX qw(strftime);
use List::MoreUtils  qw(natatime);;
use Carp;
use Getopt::Long;
use Pod::Usage;
use Clone 'clone';
use BILS::Handler::GXFhandler qw(:Ok);
use BILS::Handler::GFF3handler qw(:Ok);
use Bio::Tools::GFF;
use BILS::GFF3::Statistics qw(:Ok);

my $header = qq{
########################################################
# NBIS 2018 - Sweden                                   #  
# jacques.dainat\@nbis.se                               #
# Please cite BILS (www.nbis.se) when using this tool. #
########################################################
};




my $opt_file;
my $INTRON_LENGTH = 10;
my $opt_output=undef;
my $opt_help = 0;

my @copyARGV=@ARGV;
if ( !GetOptions( 'f|gff|ref|reffile=s' => \$opt_file,
                  'o|out|output=s' => \$opt_output,
                  "size|s=i" => \$INTRON_LENGTH,
                  'h|help!'         => \$opt_help ) )
{
    pod2usage( { -message => 'Failed to parse command line',
                 -verbose => 1,
                 -exitval => 1 } );
}

if ($opt_help) {
    pod2usage( { -verbose => 2,
                 -exitval => 2,
                 -message => "$header\n" } );
}

if ( ! defined( $opt_file) ) {
    pod2usage( {
           -message => "$header\nMust specify at least 1 parameters:\nReference data gff3 file (--gff)\n",
           -verbose => 0,
           -exitval => 1 } );
}

# #######################
# # START Manage Option #
# #######################
my $fh;
if ($opt_output) {
  open($fh, '>', $opt_output) or die "Could not open file '$opt_output' $!";
  }
else{
  $fh = *STDOUT;
}


# #####################################
# # END Manage OPTION  
# #####################################



                                                      #######################
                                                      #        MAIN         #
#                     >>>>>>>>>>>>>>>>>>>>>>>>>       #######################       <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

#PART 1
###################################
# Read input gff3 files one by one and save value in hash of list


  ######################
  ### Parse GFF input #
  my ($hash_omniscient, $hash_mRNAGeneLink) = slurp_gff3_file_JD({ input => $opt_file
                                                              });
  print("Parsing Finished\n\n");
  ### END Parse GFF input #
  #########################

  #print statistics
  my ($stat, $distri) = gff3_statistics($hash_omniscient);
  #print statistics
  foreach my $infoList (@$stat){
    foreach my $info (@$infoList){
      print "$info";
    }
    print "\n";
  }

  print $fh "List introns inferior to $INTRON_LENGTH nucleotides:\n\n";
  print $fh "Seq_id\tGene_name\tintron_start\tintron_size\n";

my $total_intron = 0;
my %total_gene;
my %result;

  ######################
  ### Parse GFF input #
  # get nb of each feature in omniscient;
  foreach my $tag_l2 (keys %{$hash_omniscient->{'level2'}}){
    foreach my $id_l1 (keys %{$hash_omniscient->{'level2'}{$tag_l2}}){
      my $one_f2 = $hash_omniscient->{'level2'}{$tag_l2}{$id_l1}[0];

      #######################
      #get feature1 and info
      my $feature_l1=undef;
      my $tag_l1;
      foreach my $tag_level1 (keys %{$hash_omniscient->{'level1'}}){
        if (exists ($hash_omniscient->{'level1'}{$tag_level1}{$id_l1})){
          $feature_l1=$hash_omniscient->{'level1'}{$tag_level1}{$id_l1};
          $tag_l1=$tag_level1;
          last;
        }
      }
      if(! $feature_l1){print "Problem ! We didnt retrieve the level1 feature with id $id_l1\n";exit;}

      #####
      # get all level2
      my $All_l2_single=1;
      foreach my $feature_l2 ( @{$hash_omniscient->{'level2'}{$tag_l2}{$id_l1}} ){

        my @introns=();
        my $feature_example;

        ######
        #get all level3
        my $id_l2=lc($feature_l2->_tag_value('ID'));

        if(exists_keys($hash_omniscient, ('level3','exon',$id_l2) ) ){

        my $counterL3=-1;
        #Initialize intron to 0 to avoid error during printing results
        my $indexLast = $#{$hash_omniscient->{'level3'}{'exon'}{$id_l2}};
        
        my @sortedList = sort {$a->start <=> $b->start} @{$hash_omniscient->{'level3'}{'exon'}{$id_l2}};
        
          foreach my $feature_l3 ( @sortedList ){

            #count number feature of tag_l3 type
            $counterL3++;

            ################
            #Manage Introns# 
            # from the second intron to the last (from index 1 to last index of the table sortedList) 
            # We go inside this loop only if we have more than 1 feature.
            if($counterL3 > 0 and $counterL3 <= $indexLast){
              my $intronStart = $sortedList[$counterL3-1]->end+1;
              my $intronEnd = $sortedList[$counterL3]->start-1;
              my $intron_size = ($intronEnd - $intronStart + 1);
              if ($intron_size < $INTRON_LENGTH){
                my $seqid = $feature_l1->seq_id();
                
                $total_intron++;
                $total_gene{$id_l1}++;
                $result{$seqid}{$total_intron} = "$seqid\t$id_l1\t$intronStart\t$intron_size\n";

              } 
            }
          }# END FOREACH L3
        }
      }
    }
  }
foreach my $seqid (keys %result){
  foreach my $cpt (keys $result{$seqid}){
    print $fh $result{$seqid}{$cpt};
  }
}

my $gene_number = keys %total_gene;
print $fh "\n$total_intron introns found for $gene_number uniq genes\n";
      ######################### 
      ######### END ###########
      #########################


#######################################################################################################################
        ####################
         #     methods    #
          ################
           ##############
            ############
             ##########
              ########
               ######
                ####
                 ##



__END__

my $opt_file;
my $INTRON_LENGTH = 10;
my $opt_output=undef;
my $opt_help = 0;

my @copyARGV=@ARGV;
if ( !GetOptions( 'f|gff|ref|reffile=s' => \$opt_file,
                  'o|out|output=s' => \$opt_output,
                  "size|s=i" => \$INTRON_LENGTH,
                  'h|help!'         => \$opt_help ) )

=head1 NAME
 
gff3_sp_list_short_introns.pl
The script aims to list all the introns inferior to a certain size. Introns are calculated on the fly from exons. (intron feature will not be used) 

=head1 SYNOPSIS

    ./gff3_sp_list_short_introns.pl --gff=infile --out=outFile 
    ./gff3_sp_list_short_introns.pl --help

=head1 OPTIONS

=over 8

=item B<--gff>, B<-f>, B<--ref> or B<-reffile>

Input GFF3 file correponding to gene build.

=item B<--size> or B<-s>

Minimum intron size accepted in nucleotide. All introns under this size will be reported. Default value = 10.

=item  B<--out>, B<--output> or B<-o>

Output gff3 file where the gene incriminated will be write.

=item B<--help> or B<-h>

Display this helpful text.

=back

=cut
