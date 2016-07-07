#!/usr/bin/env ruby

require 'open3'
# premise: current dierctory is run-directory, each sample-directories exist under the current directory
# take 1 arg; comma separated sampe-directories; ex. 6758_1_SS5UTR,6759_1_SS5UTR

samples = ARGV[0].split(",")
samples.map!{|s| ( s[-1] == '/')? s[0...-1] : s} # cut last '/' if exists

for s in samples do
  no = s.split('_')[0] # 7244, 7245, etc

  unless Dir.exist? s
    puts "WARNING not-exist directory given : [#{s}]"
    next
  end

  dir = nil
  if Dir.exist? "#{s}/exome"
    dir = "#{s}/exome"
  else
    dir = "#{s}/genome"
  end

  ## system (do not pass through error) <-> exec.backquote (stop when error in bash)
  out,err,status = Open3.capture3( "ls -l #{dir}/fastq/ | awk 'NF>3 && $11!~/#{no}/{print}' " )
  puts "WARNING:#{err}" if err.size != 0 or out.size != 0
  
  check = `awk '{print $1}' #{dir}/mpileup/ano/#{s}.sorted.ExAC |uniq|tr '\n' ','`

  for chr in (1..22).to_a.push('X', 'Y') do
    out,err,status = Open3.capture3( "ls -l #{dir}/mpileup/*.chr#{chr}.raw.bcf|awk '$5<1000 {print \"WARNING:check \" $9}'" )
    puts "WARNING:#{err}" if err.size != 0 or out.size != 0
    out,err,status = Open3.capture3( "ls -l #{dir}/mpileup/*.chr#{chr}.consensus.bz2|awk '$5<1000 {print \"WARNING:check \" $9}'")
    puts "WARNING:#{err}" if err.size != 0 or out.size != 0

    unless /chr#{chr},/.match check then
      puts "WARNING:check chr#{chr} in $DIR/mpileup/ano/#{s}.sorted.ExAC"
    end
  end

  file_dir = File.expand_path File.dirname(__FILE__)
  # system "cat #{s}/stat/map/*.Nmap | perl #{file_dir}/calc_map_rate.pl"
  system "cat #{s}/stat/map/*.Nmap | ruby #{file_dir}/calc_map_rate.rb"
  system "cat #{s}/stat/dup/dup.stat | perl #{file_dir}/calc_dup.pl"
  system "cat #{s}/stat/snv/*.stats | perl -pwe \"s/\t/,/g\""

end
