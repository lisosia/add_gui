#!/bin/sh
START=${1%%_*}
if [ $# -ge 2 ];then
    END=${2%%_*}
else
    END=$START
fi

for NO in `seq -f %04g $START $END`;do
    SAMPLE=`ls |grep ^$NO|grep -v .old$|grep -v .bak$`

    if [ -d "$SAMPLE/exome" ];then
        DIR=$SAMPLE/exome
    else
        DIR=$SAMPLE/genome
    fi

    if [ -n "$SAMPLE" ];then
#echo "[check $NO]"
ls -l $DIR/fastq/|awk "NF>3 && \$11!~/$NO/{print}"
CHECK=`awk '{print $1}' $DIR/mpileup/ano/${SAMPLE}.sorted.ExAC |uniq|tr '\n' ','`
for chr in {1..22} X Y;do
    ls -l $DIR/mpileup/*.chr${chr}.raw.bcf|awk '$5<1000 {print "WARNING:check " $9}'
    ls -l $DIR/mpileup/*.chr${chr}.consensus.bz2|awk '$5<1000 {print "WARNING:check " $9}'
    if [ ! `echo "$CHECK" |grep "chr$chr,"` ];then
       echo "WARNING:check chr$chr in $DIR/mpileup/ano/${SAMPLE}.sorted.ExAC"
   fi
done

file_dir=$(dirname $(readlink -f f$0) )

cat $SAMPLE/stat/map/*.Nmap | perl $file_dir/calc_map_rate.pl
cat $SAMPLE/stat/dup/dup.stat | perl $file_dir/calc_dup.pl
cat $SAMPLE/stat/snv/*.stats | perl -pwe "s/\t/,/g"
else
    echo $NO is not found!!
fi
done

