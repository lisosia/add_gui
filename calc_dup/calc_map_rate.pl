#!/bio/bin/perl -w

# #Target Bases
# TruSeq : 62085295
# Sure Select 50Mb : 51860012
# Sure Select 4 + UTR : 107839035
# Sure Select 5 + UTR : 116898557
# Genome : 3095677412

my $target_bases = 3095677412;

my $name;
my $n_reads = 0;
my $map_reads = 0;
my $unq_reads = 0;
my $map_bases = 0;
my $unq_bases = 0;

while(<STDIN>){
	chomp;
	my @column = split(/\s/, $_);
	$name = $column[0];
	$n_reads += $column[1];
	$map_reads += $column[2];
	$unq_reads += $column[3];
	$map_bases += $column[4];
	$unq_bases += $column[5];
}

@path = split(/\//, $name);
@sample = split(/\./, $path[2]);

if($sample[0] =~ /SS50Mb/){
	$target_bases = 51860012;
}
elsif($sample[0] =~ /SS4UTR/){
	$target_bases = 107839035;
}
elsif($sample[0] =~ /SS5UTR/){
	$target_bases = 116898557;
}
elsif($sample[0] =~ /SS6UTR/){
	$target_bases = 90697072;
}
elsif($sample[0] =~ /TruSeq/){
	$target_bases = 62085295;
}
elsif($sample[0] =~ /WG/){
	$target_bases = 3095677412;
}
elsif($sample[0] =~ /Cancer/){
	$target_bases = 8643867;
}

#Sample,#Reads,#Mapped Reads,#Mappe Reads (Unique),Mapping Rate (%),Mapping Rate (Unique) (%),Coverage (x),Coverage (Unique) (x)
print "$sample[0],$n_reads,$map_reads,$unq_reads," . $map_reads / $n_reads * 100 . "," . $unq_reads / $n_reads * 100 . "," . $map_bases / $target_bases . "," . $unq_bases / $target_bases . "\n";
