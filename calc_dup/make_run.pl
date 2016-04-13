#!/bio/bin/perl -w
use File::Basename;

my $RUN=378; #
my $j=1;
my $NO="_1";
my @SAMPLE_LIST=(7308..7339); #
my $PREFIX="Project_";
my $SAMPLE_NAME="";
my @RUN_NO=("PE001");
my @RUN_DIR=(
"/data/HiSeq2000/160216_D00734_0060_BC8NAEACXX/Unaligned/"
);

##my $SURE_POS="/grid2/personal-genome/BED/SureSelect_All_Exon_50mb_with_annotation_hg19_bed";
#my $SUFFIX="_TruSeq";
#my $SURE_POS="/grid2/personal-genome/BED/TruSeq-Exome-Targeted-Regions-BED-file";
#my $SUFFIX="_SS4UTR";
#my $SURE_POS="/grid2/personal-genome/BED/SureSelect_All_Exon_V4+UTRs_hg19.bed";
#my $SUFFIX="_SS5UTR";
#my $SURE_POS="/grid2/personal-genome/BED/S04380219_V5_Core+UTR_Fragments.bed";
my $SUFFIX="_SS6UTR";
my $SURE_POS="/grid2/personal-genome/BED/S07604624_V6+UTR_Covered.bed";
#my $SUFFIX="_Amplicon";
#my $SURE_POS="";
#my $SUFFIX="_WG";
#my $SURE_POS="";
#my $SUFFIX="_Custom";
#my $SURE_POS="0494601_Covered-205_custom.bed";
#my $SUFFIX="_RNA";
#my $SURE_POS="";
#my $SUFFIX="_Cancer";
#my $SURE_POS="/grid2/personal-genome/BED/120522_HG19_Onco_R_EZ.bed";

my $RNA_FLAG = 0;
if($SUFFIX eq "_RNA"){
    $RNA_FLAG = 1;
}

foreach my $SAMPLE (@SAMPLE_LIST){ # START of each sample loop
    
    print "SAMPLE: $RUN/$SAMPLE$NO$SUFFIXn";
    $SAMPLE_NAME .= " $SAMPLE$NO$SUFFIX";
    
    my $GENOME_FLAG = 0;
    my $GENOME = "exome";
    if($SUFFIX eq "_WG"){
        $GENOME_FLAG = 1;
        $GENOME = "genome";
    }
    if($RNA_FLAG){
        $GENOME = "rna";
    }
    
    my @RUN_PE=();
    my @RUN_DIR_PE=();
    my @RUN_SE=();
    my @RUN_DIR_SE=();
    
    for(my $i=0;$i<=$#RUN_DIR;$i++){
        my $DIR = $RUN_DIR[$i];
        my @READ_DIR = glob($DIR . "/" . $PREFIX . $SAMPLE . "*" . $SUFFIX . "/Sample_" . $SAMPLE . "*");
        
        foreach(@READ_DIR){
            chomp;
            if(!-d $_){
                print "Error: $_ was not found!n";
                next;
            }
            if($RUN_NO[$i] =~ /^PE/){
                push(@RUN_PE, $RUN_NO[$i]);
                push(@RUN_DIR_PE, $_);
            }
            else{
                push(@RUN_SE, $RUN_NO[$i]);
                push(@RUN_DIR_SE, $_);
            }
        }
    }
    
    $SAMPLE .= $NO . $SUFFIX;
    
    my $FASTQ_DIR="$RUN/$SAMPLE/$GENOME/fastq";
    !system("mkdir -p $FASTQ_DIR") || die "Error mkdirn";
    
    my $FASTQ_PE="";
    my $FASTQ_SE="";
    #&check();
    
    for(my $i=0; $i<=$#RUN_PE; $i++){
        while(glob("$RUN_DIR_PE[$i]/*.fastq.gz")){
            my @temp=split("_", basename($_));
            
            $temp[4]=~s/R//g;
            $temp[5]=~s/.fastq.gz//g;
            
            $FILE_BASE="$SAMPLE.$RUN_PE[$i].$temp[3]_$temp[5]_$temp[4]";
            $cmd="ln -s $_ $FASTQ_DIR/$FILE_BASE.fastq.gz";
            #    print "$cmdn";
            !system("$cmd") || die "Errorn";
            
            if($temp[4] eq "1"){
                $FILE_BASE="$SAMPLE.$RUN_PE[$i].$temp[3]_$temp[5]";
                
                if($FASTQ_PE eq ""){
                    $FASTQ_PE="$FILE_BASE";
                    }else{
                    $FASTQ_PE="$FASTQ_PE $FILE_BASE";
                }
            }
        }
    }
    
    for(my $i=0; $i<=$#RUN_SE; $i++){
        while(glob("$RUN_DIR_SE[$i]/*_R1_*.fastq.gz")){
            my @temp=split("_", basename($_));
            
            $temp[4]=~s/R//g;
            $temp[5]=~s/.fastq.gz//g;
            
            $FILE_BASE="$SAMPLE.$RUN_SE[$i].$temp[3]_$temp[5]_$temp[4]";
            $cmd="ln -s $_ $FASTQ_DIR/$FILE_BASE.fastq.gz";
            print "$cmdn";
            !system("$cmd") || die "Errorn";
            
            if($temp[4] eq "1"){
                $FILE_BASE="$SAMPLE.$RUN_SE[$i].$temp[3]_$temp[5]";
                
                if($FASTQ_SE eq ""){
                    $FASTQ_SE="$FILE_BASE";
                    }else{
                    $FASTQ_SE="$FASTQ_SE $FILE_BASE";
                }
            }
        }
    }
    
    ### make run.sh
    if(!$RNA_FLAG){
        my $thread=`gxpc e hostname | wc -l`;
        $thread=~s/n//g;
        
        my $RUN_FILE="$RUN/$SAMPLE/run.sh";
        open(OUT,">$RUN_FILE") || die "Errorn";
        
        print OUT "gxpc make -k -j $thread -f /nfs/6/personal-genome/makefiles/makefile_md5.nfs ";
        print OUT "SAMPLE=$SAMPLE PE_READS="$FASTQ_PE" SE_READS="$FASTQ_SE" ";
        print OUT "SURE_POS=$SURE_POS";
        print OUT " TARGET=genome" if($GENOME_FLAG);
        print OUT "n";
        close(OUT);
    }
    
} # END of each sample loop

###  make run script
my $RUN_SCRIPT="$RUN/auto_run$SUFFIX.sh";
open(OUT,">$RUN_SCRIPT") || die "Cannot create $RUN_SCRIPT";
print OUT "BASE_DIR=/work/HiSeq2000/$RUN
for DIR in $SAMPLE_NAME
do
echo $DIRn";

if(!$RNA_FLAG){
    print OUT "tcd $BASE_DIR/$DIR && date >> make.log && (time sh run.sh) >> make.log 2>> make.logn";
    print OUT "tcd $BASE_DIR/ && sh /work/yoshimura/tools/check_results.sh $DIR >> check_results.log 2>> check_results.logn";
}
else{
    print OUT "tqsub -N RNA-$DIR -o $DIR/make.log -j y /work/HiSeq2000/BaseCall/qsub_rna.sh $DIRn";
}

print OUT "done";
close(OUT);
#sub check{
    #        die("Check SAMPLE!n") if($SAMPLE eq "0242_1_SS4UTR");
    #        for(my $i=0; $i<=$#RUN_PE; $i++){
        #                die("$RUN_DIR_PE[$i] does not exist!n") if(! -d $RUN_DIR_PE[$i]);
        #                die("check RUN_DIR_PE[$i]!n") if($RUN_DIR_PE[$i] !~ /$SAMPLE/);
    #        }
    #        for(my $i=0; $i<=$#RUN_SE; $i++){
        #               die("$RUN_DIR_SE[$i] does not exist!n") if(! -d $RUN_DIR_SE[$i]);
        #               die("check RUN_DIR_SE[$i]!n") if($RUN_DIR_SE[$i] !~ /$SAMPLE/);
    #       }
#}