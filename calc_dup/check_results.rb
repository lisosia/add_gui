#!/usr/bin/env ruby

require 'open3'
require 'fileutils'
require 'json'

# premise: current dierctory is run-directory, each sample-directories exist under the current directory
# take 1 arg; comma separated sampe-directories; ex. 6758_1_SS5UTR,6759_1_SS5UTR

require_relative './calc_map_rate.rb'
require_relative './calc_dup.rb'

class CheckResults
  FILEPATH = File.expand_path( __FILE__ )

  def self.oldformat2json( file )
    r = File.readlines( file ).reject( &:empty? ).map(&:chomp)
    raise unless ( r.size % 3) == 0
    results = {}
    
    0.upto( r.size / 3 -1 ) do |i|
      index = i * 3
      lines = r[ index ... index  + 3 ]

      ss = lines.map{|l| l.split(',').first }.uniq
      raise unless ss.size == 1
      sample = ss.first
      results[ sample ] = lines.join( "\n" )

    end
    
    return JSON.pretty_generate( results )
  end

  def self.json2oldformat(file)
    ret = ''
    jj = JSON.parse( File.read(file) )
    for k,v in jj
      ret += v + "\n"      
    end
    return ret
  end

  def initialize( file, dir = '.' )
    @dir = dir
    Dir.chdir( dir ) do
      @file = file
      FileUtils.touch @file
      @read = File.read( file )
      raise unless  ( @read.split("\n").size % 3 ) == 0
    end

  end

  def to_s()
    print @read
  end
  
  def sample_exist?( sample )
    raise if sample.to_s == ''
    /^#{sample},/ === @read
  end

  def sample_dir_exist?( sample )
    Dir.exist? File.join( @dir, sample )
  end

  def add_samples( samples )

    samples = [samples] if samples.class == String

    ret = []
    for sample in samples
      if sample_exist? sample
        STDERR.puts "warning: skip because sample exists: #{sample}"
        next
      end
      ret << MakeCheckResults.sample_result( sample )
    end
    to_write = ret.join "\n"
    
    File.open( @file, 'a' ){ |f| f.puts to_write }
    @read = File.read( file )
  end
  
end

module MakeCheckResults

  # print ` cat #{s}/stat/snv/*.stats | perl -pwe \"s/\t/,/g\" `
  def self.snv_stats( sample )
    filename = files = "#{sample}/stat/snv/*.stats"
    files = Dir[ filename ]
    raise 'No such filename : #{ filename }' if files.size == 0
    return files.map{|f| File.read(f) }.join().gsub( "\t", ',' ).chomp
  end
  
  def self.iferr(msg)
    puts "WARNING:#{msg}"
  end
  
  def self.make_all_results( filename, samples )
    
    puts print( samples ) 
  end

  def self.print( samples )
    for sample in samples
      puts sample_result( sample )
    end
  end

  def self.sample_result( sample, slide  = nil )
    s = sample
    no = s.split('_')[0] # 7244, 7245, etc

    unless Dir.exist? s
      raise "WARNING not-exist directory given : [#{s}]"
    end

    dir = nil
    if Dir.exist? "#{s}/exome"
      dir = "#{s}/exome"
    else
      dir = "#{s}/genome"
    end

    ## system (do not pass through error) <-> exec.backquote (stop when error in bash)
    out,err,status = Open3.capture3( "ls -l #{dir}/fastq/ | awk 'NF>3 && $11!~/#{no}/{print}' " )
    iferr(err) if err.size != 0 or out.size != 0
    
    check = `awk '{print $1}' #{dir}/mpileup/ano/#{s}.sorted.ExAC |uniq|tr '\n' ','`

    for chr in (1..22).to_a.push('X', 'Y') do
      out,err,status = Open3.capture3( "ls -l #{dir}/mpileup/*.chr#{chr}.raw.bcf|awk '$5<1000 {print \"WARNING:check \" $9}'" )
      iferr(err) if err.size != 0 or out.size != 0
      out,err,status = Open3.capture3( "ls -l #{dir}/mpileup/*.chr#{chr}.consensus.bz2|awk '$5<1000 {print \"WARNING:check \" $9}'")
      iferr(err) if err.size != 0 or out.size != 0

      unless /chr#{chr},/.match check then
        iferr( "WARNING:check chr#{chr} in $DIR/mpileup/ano/#{s}.sorted.ExAC" )
      end
    end

    file_dir = File.expand_path File.dirname(__FILE__)
    # system "cat #{s}/stat/map/*.Nmap | perl #{file_dir}/calc_map_rate.pl"

    begin

      # print ` cat #{s}/stat/map/*.Nmap | ruby -W0 #{file_dir}/calc_map_rate.rb`
      # print ` cat #{s}/stat/dup/dup.stat | perl #{file_dir}/calc_dup.pl `
      # print ` cat #{s}/stat/snv/*.stats | perl -pwe \"s/\t/,/g\" `
      to_print = []
      to_print <<  CalcMapRate.run( s )
      to_print <<  CalcDup.run( s )
      to_print << snv_stats( s )
      # puts to_print.join("\n")
    rescue => ex
      raise ex
    end
  end

end

require 'optparse'

if __FILE__ == $0
  opt = {}
  OptionParser.new do |o|
    o.on( '--file file', 'checkresult.log : json file' ){|e| opt[:file] = e }
    o.on( '--add add' , 'comma separated file to be added' ){|e| opt[:add] = e }
    o.on( '--convert' , 'comma separated file to be added' ){|e| opt[:convert] = e }
    o.on( '--convert-rev' , 'comma separated file to be added' ){|e| opt[:convertrev] = e }
  end.parse!

  for req in [ :file ]
    raise "required arg:#{req}" unless opt[req]
  end
  
  if opt[:convert]
    print CheckResults.oldformat2json( opt[:file] )
    exit
  elsif opt[:convertrev]
    print CheckResults.json2oldformat( opt[:file] )
    exit
  end

  res = CheckResults.new( opt[:file] )
  if opt[:add]
    samples = top[:add].split(',')
    res.add_samples( samples )
    print res.to_s()
  else
    print res.to_s()
  end
  
  
  # if ARGV.size == 0
  #   raise 'usage: ruby <thisfile> comma-separated-samples'
  # end
  # samples = ARGV[0].split(",")
  # samples.map!{|s| ( s[-1] == '/')? s[0...-1] : s} # cut last '/' if exists
  # MakeCheckResults.print( samples )
end
