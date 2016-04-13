#!/bio/bin/perl -w

my $SAMPLE;
my $READS = 0;
my $UNQ = 0;
my $DUP = 0;

while(<STDIN>){
	chomp;
	my ($RUN, $unq, $dup, $reads) = split(/\s/, $_);
	($SAMPLE, my $tmp) = split(/\,/, $RUN);
	$UNQ += $unq;
	$DUP += $dup;
	$READS += $reads;
}

#print "Depth,Frequency,Percent\n";
print "$SAMPLE,$UNQ,$DUP,$READS," . $DUP/$READS*100 . "\n";
