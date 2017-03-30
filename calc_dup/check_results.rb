#!/usr/bin/env ruby

require 'open3'
require 'fileutils'
require 'json'
require 'pathname'

# premise: current dierctory is run-directory, each sample-directories exist under the current directory

require_relative './calc_map_rate.rb'
require_relative './calc_dup.rb'

# require_relative '../app/prepkit.rb'
# PREP = Prepkit.new()

class CheckResults
  FILEPATH = File.expand_path( __FILE__ )

  def self.library_id2sampledir( libid, dir='.' ) # libid, ex): 8456, 8457,
    libid = File.basename libid
    f = File.join( dir, "#{libid}*/")
    dd = Dir[ f ]
    raise ArgumentError,  "ambiguous library_id(#{libid}). There exist multi sample-dirs whose name matches #{f}" if dd.size > 2
    raise ArgumentError,  "sample dir not found: library_id(#{libid})" if dd.size == 0          
    return File.basename( dd[0] )    
  end

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

  # if samples == nil, return all
  def self.json2oldformat(file, samples = nil)
    print_all = samples.nil?
    ret = ''
    jj = JSON.parse( File.read(file) )
    for k,v in jj
      next if not print_all and not samples.any?{|libid| /#{libid}/ === k }
      ret += v['result'] + "\n"
    end
    return ret
  end
  
  def initialize( dir, file = 'check_results.json' )
    @dir = dir
    @file = File.join( dir, file )
    if File.exists? @file
      @results = JSON.parse( File.read( @file ) )
    else
      @results = {}
    end
  end

  def to_s()
    JSON.pretty_generate(@results)
  end

  # samples : array of library_id
  def to_s_old( samples = nil )
    self.class.json2oldformat( @file, samples )
  end
  
  def samples()
    @results.keys
  end

  # samples : array of string(library_id)
  def add_samples( samples )
    samples = [samples] unless samples.class == Array
    samples.map! do |s|
      raise "not String object <#{s.class}? given : #{s}" unless s.class == String
      self.class.library_id2sampledir( s, dir=@dir )
    end

    for sample in samples
      if sample_exist? sample
        STDERR.puts "warning: skip because sample exists: #{sample}"
        next
      end
      Dir.chdir @dir do
        @results[sample] = MakeCheckResults.sample_result( sample )
      end
    end
    File.open( @file, 'w' ){ |f| f.puts self.to_s }
    @read = File.read( @file )
  end
  
  private

  def sample_exist?( sample )
    raise 'empty input' if sample.to_s == ''
    @results.keys.include? sample
  end

  def sample_dir_exist?( sample )
    Dir.exist? File.join( @dir, sample )
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

  def self.sample_result( sample )
    s = CheckResults.library_id2sampledir( sample )
    no = s.split('_')[0] # 7244, 7245, etc

    unless Dir.exist? s
      raise "WARNING not-exist directory given : [#{s}]"
    end

    dir = nil
    if Dir.exist? "#{s}/exome"
      dir = "#{s}/exome"
    elsif Dir.exist? "#{s}/genome"
      dir = "#{s}/genome"
    else
      raise ArgumentError , "neither #{s}/exome or #{s}/genome directory exists."
    end

    warning = []

    # warn if another sample's fastq file exists in fastq directory
    # out,err,status = Open3.capture3( "ls -l #{dir}/fastq/ | awk 'NF>3 && $11!~/#{no}/{print}' " )
    Dir["#{dir}/fastq/*"].each do |f|
      warning << "another sample's fastq file exists in fastq directory : #{f}" unless /#{no}/ === f
    end
    
    chr_list = (1..22).to_a.push('X', 'Y')

    # warn if missing chr{*} exists
    # check = `awk '{print $1}' #{dir}/mpileup/ano/#{s}.sorted.ExAC |uniq|tr '\n' ','`
    # unless /chr#{chr},/.match check then
    #  iferr( "WARNING:check chr#{chr} in $DIR/mpileup/ano/#{s}.sorted.ExAC" )
    # end
    ano_sort = File.join( dir,"/mpileup/ano/#{s}.sorted.ExAC" )
    chr_sort = File.readlines( ano_sort ).map{|l| l.split()[0] }.uniq.join("\n")
    for chr in chr_list do
      waring << "check chr#{chr} in ano_sort" unless /chr#{chr}/.match chr_sort
    end

    for chr in chr_list do

      # out,err,status = Open3.capture3( "ls -l #{dir}/mpileup/*.chr#{chr}.raw.bcf|awk '$5<1000 {print \"WARNING:check \" $9}'" )
      Dir["#{dir}/fastq/*"].each do |f|
        size = File.open( f ).size
        waring << "too small filesize (#{size}), check #{f}" if size < 1000        
      end

      # out,err,status = Open3.capture3( "ls -l #{dir}/mpileup/*.chr#{chr}.consensus.bz2|awk '$5<1000 {print \"WARNING:check \" $9}'")
      Dir["#{dir}/mpileup/*.chr#{chr}.consensus.bz2"].each do |f|
        size = File.open( f ).size
        waring << "too small filesize (#{size}), check #{f}" if size < 1000        
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
      return { 'result' => to_print.join("\n") ,'warn' =>  warning.join("\n") }
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
    o.on( '--convert' , 'old format(3 line per sample) to json' ){|e| opt[:convert] = e }
    o.on( '--convert-rev' , 'json to old format' ){|e| opt[:convertrev] = e }
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
    samples = opt[:add].split(',').map{ |e| e.gsub /\/*$/, '' }
    res.add_samples( samples )
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
