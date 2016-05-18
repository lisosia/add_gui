#!/bio/bin/ruby

samples = ARGV[0].split(",")

for s in samples do
  no = s.split('_')[0] # 7244, 7245, etc

  unless Dir.exist? s
    puts WARNING "not-exist directory given : [#{s}]"
    next
  end

  dir = nil
  if Dir.exist? "#{s}/exome"
    dir = "#{s}/exome"
  else
    dir = "#{s}/genome"
  end

  ## system (do not pass through error) <-> exec.backquote (stop when error in bash)
  system "ls -l #{dir}/fastq/|awk 'NF>3 && $11!~/#{no}/{print}' " 
  check = `awk '{print $1}' #{dir}/mpileup/ano/#{s}.sorted.ExAC |uniq|tr '\n' ','`

  for chr in (1..22).to_a.push('X', 'Y') do
    system "ls -l #{dir}/mpileup/*.chr#{chr}.raw.bcf|awk '$5<1000 {print \"WARNING:check \" $9}'"
    system "ls -l #{dir}/mpileup/*.chr#{chr}.consensus.bz2|awk '$5<1000 {print \"WARNING:check \" $9}'"

    unless /chr#{chr},/.match check then
      puts "WARNING:check chr#{chr} in $DIR/mpileup/ano/#{s}.sorted.ExAC"
    end
  end

  file_dir = File.expand_path File.dirname(__FILE__)
  system "cat #{s}/stat/map/*.Nmap | perl #{file_dir}/calc_map_rate.pl"
  system "cat #{s}/stat/dup/dup.stat | perl #{file_dir}/calc_dup.pl"
  system "cat #{s}/stat/snv/*.stats | perl -pwe \"s/\t/,/g\""

end
