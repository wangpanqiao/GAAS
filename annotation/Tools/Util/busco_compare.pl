#!/usr/bin/env perl

###################################################
# Jacques Dainat 01/2018                          #  
# National Bioinformatics Infrastructure Sweden   #
# jacques.dainat@nbis.se                          #
###################################################

use Carp;
use strict;
use warnings;
use Clone 'clone';
use Pod::Usage;
use Getopt::Long;
use Data::Dumper;
use IO::File ;
use List::Util 'first';  
use Bio::Tools::GFF;
use BILS::Handler::GFF3handler qw(:Ok);
use BILS::Handler::GXFhandler qw(:Ok);

my $start_run = time();

my $folderIn1=undef;
my $folderIn2=undef;
my $outfolder=undef;
my $verbose=undef;
my $opt_help = 0;


Getopt::Long::Configure ('bundling');
if ( !GetOptions ('f1=s' => \$folderIn1,
                  "f2=s" => \$folderIn2,
                  'o|output=s' => \$outfolder,
                  'v|verbose!' => \$verbose,
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

if ( !defined($folderIn1) or  !defined($folderIn2) ){
   pod2usage( { -message => 'at least 2 parameters are mandatory: --f1 and --f2',
                 -verbose => 1,
                 -exitval => 1 } );
}

# Manage input folder1
my $fh1;
$folderIn1 = remove_slash_path_folder($folderIn1);
opendir(DIR, "$folderIn1")  or die "Unable to read Directory : $!";
my @files_table1 = grep(/^full_table_/,readdir(DIR));
my $path1=$folderIn1."/".$files_table1[0];
open($fh1, '<', $path1) or die "Could not open file '$path1' $!";

#Manage input folder2
my $fh2;
$folderIn2 = remove_slash_path_folder($folderIn2);
opendir(DIR, "$folderIn2") or die "Unable to read Directory $folderIn2 : $!";;
my @files_table2 = grep(/^full_table_/,readdir(DIR));
my $path2=$folderIn2."/".$files_table2[0];
open($fh2, '<', $path2) or die "Could not open file '$path2' $!";


#Manage output folder
if ($outfolder) {
  $outfolder = remove_slash_path_folder($outfolder);
  if(! -d $outfolder ){
    mkdir $outfolder;
  }
  else{
    print "$outfolder output folder already exists !\n"; exit;
  }
}

# Manage Output gff files
my $gffout_complete;
my $gffout_fragmented;
my $gffout_duplicated;
my %gff_out;
if ($outfolder) {
  my $outfile="f1_complete.gff";
  open(my $fh, '>', $outfolder."/".$outfile) or die "Could not open file '$outfile' $!";
  $gffout_complete= Bio::Tools::GFF->new(-fh => $fh, -gff_version => 3 );
  
  $outfile="f1_fragmented.gff";
  open(my $fh2, '>', $outfolder."/".$outfile) or die "Could not open file '$outfile' $!";
  $gffout_fragmented= Bio::Tools::GFF->new(-fh => $fh2, -gff_version => 3 );
  
  $outfile="f1_duplicated.gff";
  open(my $fh3, '>', $outfolder."/".$outfile) or die "Could not open file '$outfile' $!";
  $gffout_duplicated= Bio::Tools::GFF->new(-fh => $fh3, -gff_version => 3 );
}
else{
  $gffout_complete = Bio::Tools::GFF->new(-fh => \*STDOUT, -gff_version => 3 ); 
  $gffout_fragmented = Bio::Tools::GFF->new(-fh => \*STDOUT, -gff_version => 3 );
  $gffout_duplicated = Bio::Tools::GFF->new(-fh => \*STDOUT, -gff_version => 3 ); 
}
$gff_out{'complete'}=$gffout_complete;
$gff_out{'fragmented'}=$gffout_fragmented;
$gff_out{'duplicated'}=$gffout_duplicated;


#############################################################
#                         MAIN
#############################################################

#Read busco1 file 
my %busco1;
while( my $line = <$fh1>)  {   
   
  if( $line =~ m/^\w+\s{1}Complete/){   
    my @list = split(/\s/,$line);
    $busco1{'complete'}{$list[0]}=$line;
  }
  if( $line =~ m/^\w+\s{1}Missing/){
    my @list = split(/\s/,$line);
    $busco1{'missing'}{$list[0]}=$line;
  }
  if( $line =~ m/^\w+\s{1}Fragmented/){
    my @list = split(/\s/,$line);
    $busco1{'fragmented'}{$list[0]}=$line;
  }
  if( $line =~ m/^\w+\s{1}Duplicated/){
    my @list = split(/\s/,$line);
    $busco1{'duplicated'}{$list[0]}=$line;
  }
}

#Read busco2 file 
my %busco2;
while( my $line = <$fh2>)  {   
   
  if( $line =~ m/^\w+\s{1}Complete/){   
    my @list = split(/\s/,$line);
    $busco2{'complete'}{$list[0]}=$line;
  }
  if( $line =~ m/^\w+\s{1}Missing/){
    my @list = split(/\s/,$line);
    $busco2{'missing'}{$list[0]}=$line;
  }
  if( $line =~ m/^\w+\s{1}Fragmented/){
    my @list = split(/\s/,$line);
    $busco2{'fragmented'}{$list[0]}=$line;
  }
  if( $line =~ m/^\w+\s{1}Duplicated/){
    my @list = split(/\s/,$line);
    $busco2{'duplicated'}{$list[0]}=$line;
  }
}

my %hashCases;
my %streamOutputs;
#compare busco1 and busco2
foreach my $type1 (keys %busco1){
  foreach my $id1 (keys %{$busco1{$type1}} ){

    foreach my $type2 (keys %busco2){
      if($type1 ne $type2){
        if(exists_keys (\%busco2,($type2,$id1)  ) ){

          my $name=$type1."2".$type2;
          $hashCases{$id1}=$name;
          # create streamOutput
          if($outfolder){
            if (! exists_keys (\%streamOutputs,($name)) ){
              my $ostream = IO::File->new(); 
              $ostream->open( $outfolder."/$name.txt", 'w' ) or croak( sprintf( "Can not open '%s' for writing %s", $outfolder."/$name.txt", $! ) );
              $streamOutputs{$name}=$ostream;
            }
            my $streamOut=$streamOutputs{$name};
            print $streamOut  $busco1{$type1}{$id1};
          }
          else{
            print "$id1 was $type1 and it is now $type2\n";
          }
        }
      }
    }
    if(! exists_keys(\%hashCases,($id1) ) ){
      $hashCases{$id1}=$type1."2".$type1;
    }
  }
}

#extract gff from folder1
my %f_omniscient;
my $full_omniscient=\%f_omniscient;
my $loop = 0;
my $list_uID_new_omniscient=undef;
my $augustus_gff_folder=$folderIn1."/augustus_output/predicted_genes";

if (-d $augustus_gff_folder){
  opendir(DH, $augustus_gff_folder);
  my @files = readdir(DH);

  my %track_found;
  my @list_cases=("complete","fragmented","duplicated");
  foreach my $type (@list_cases){
    print "extract gff for $type cases\n" if $verbose;
    foreach my $id (keys %{$busco1{$type}}){
      my @list = split(/\s/,$busco1{$type}{$id});
      my $seqId = $list[2];
      my $start = $list[3];
      my $end = $list[4];

      my @matches = grep { /\Q$id/ } @files;
      if( @matches){
        foreach my $match (@matches){
          my $path = $augustus_gff_folder."/".$match;
          if (-f $path ){
            my  $found=undef;
            print $path."\n" if $verbose;
            my ($hash_omniscient, $hash_mRNAGeneLink) = slurp_gff3_file_JD({ input => $path
                                                                          });
            if (!keys %{$hash_omniscient}){
              print "No gene found for $path\n";exit;
            }
            
            my @listIDl1ToRemove;
            if( exists_keys ($hash_omniscient,('level1','gene'))){
              foreach my $id_l1 (keys %{$hash_omniscient->{'level1'}{'gene'}}){
                my $feature = $hash_omniscient->{'level1'}{'gene'}{$id_l1};
                if ($feature->seq_id() eq $seqId and  $feature->start == $start and $feature->end == $end){
                  $found=1;
                  $track_found{$type}{$id}++;

                  #Add the OG name to the feature, to be displayed in WA               
                  foreach my $tag_l2 (keys %{$hash_omniscient->{'level2'}}){
                    if( exists_keys($hash_omniscient,('level2', $tag_l2, $id_l1))){
                      foreach my $feature_l2 ( @{$hash_omniscient->{'level2'}{$tag_l2}{$id_l1}} ){
                        my $value=$id."-".$hashCases{$id};
                        $feature_l2->add_tag_value('description', $value);
                      }
                    }
                  }
                }
                else{push(@listIDl1ToRemove,$id_l1);}
              }
              
              if ($found){
                if(@listIDl1ToRemove){
                  print "lets remove those supernumary annotation: @listIDl1ToRemove \n" if $verbose;
                  remove_omniscient_elements_from_level1_id_list($hash_omniscient, \@listIDl1ToRemove);
                }
                
                if($loop == 0){
                  $full_omniscient = clone($hash_omniscient);
                  $loop++;
                }
                elsif($loop == 1){
                  $full_omniscient, $list_uID_new_omniscient = merge_omniscients($full_omniscient, $hash_omniscient);
                  $loop++;
                }
                else{
                  $full_omniscient, $list_uID_new_omniscient = merge_omniscients($full_omniscient, $hash_omniscient, $list_uID_new_omniscient);
                }
              }
              else{
                print "No annotation as described in the tsv file found in the gff file $path\n" if $verbose;
              }
            }
            else{
              print "No annotation in the file $path, lets look the next one.\n" if $verbose;
            }
          }
          else{
            print "A) file $id not found among augustus gff output\n" if $verbose;
          }
        }
      }
      else{
        print "file $id not found among augustus gff output\n" if $verbose;
      }
      if(! exists_keys(\%track_found,($type,$id))){
        print "WARNING After reading all the files related to id $id we didn't found any annotation matching its described in the tsv file.\n";
      }
    }
    my $out = $gff_out{$type};
    print_omniscient($full_omniscient, $out);
    %$full_omniscient = (); # empty hash
    $list_uID_new_omniscient=undef; #Empty Id used;
    my $nb = keys %{$track_found{$type}};
    $loop = 0;
    print "We found $nb annotations from $type busco\n";
  }

}
else{ print "$augustus_gff_folder folder doesn't exits\n"; exit;}




##Last round
my $end_run = time();
my $run_time = $end_run - $start_run;
print "Job done in $run_time seconds\n";
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

sub remove_slash_path_folder{
  my ($folder_path)=@_;
  if ( $folder_path =~ /\/$/){
    return  $folder_path = substr $folder_path, 0, -1;
  }
  else{
    return $folder_path;
  }
}

__END__


=head1 NAME

busco_compare.pl -
Will look at the results from two different runs of busco in order to look at the differentces.
The script look at the complete,fragmented and duplicated genes (not the missing ones) from the 1st run that will be classified differently in the second run.
the script also extracts the annotation of the complete,fragmented and duplicated genes from the 1st run in gff.
Loading the gff tracks on webapollo and looking for BUSCO group classified differently allows to catch easily the locus with potential problems.

=head1 SYNOPSIS

    busco_compare.pl --f1 <input busco folder1> --f2 <input busco folder2> [-o <output folder>]
    busco_compare.pl --help

=head1 OPTIONS

=over 8

=item B<--f1>

STRING: Input busco folder1

=item B<--f2>

STRING: Input busco folder2

=item B<-v> or B<--verbose> 

For displaying extra information

=item B<-o> or B<--output> 

STRING: Output folder.

=item B<--help> or B<-h>

Display this helpful text.

=back

=cut
