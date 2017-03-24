#!/bio/bin/ruby

require 'yaml'
require_relative '../app/config.rb'
require_relative '../app/prepkit.rb'

module CalcMapRate

  PREP = Prepkit.new( load_config().prepkit_info )
  def self.run( sample )
    input = Dir["#{sample}/stat/map/*.Nmap"].map{ |f| File.read(f) }.join()
    return run_with_input( input )
  end
  
  def self.run_with_input( input = STDIN.read )

    name = nil
    n_reads = map_reads = unq_reads = map_bases = unq_bases = 0
    
    for l in input.split( "\n" )
      c = l.chomp.split(/\s/)
      name = c[0]
      n_reads += c[1].to_i
      map_reads += c[2].to_i
      unq_reads += c[3].to_i
      map_bases += c[4].to_i
      unq_bases += c[5].to_i

    end

    path = name.split(/\//)
    sample = path[2].split(/\./)

    target_bases = PREP.suffix2targetbases( sample[0] ) || 3095677412

    # Sample,#Reads,#Mapped Reads,#Mappe Reads (Unique),Mapping Rate (%),Mapping Rate (Unique) (%),Coverage (x),Coverage (Unique) (x)
    return "#{sample[0]},#{n_reads},#{map_reads},#{unq_reads},#{ map_reads.to_f / n_reads * 100 },#{ unq_reads.to_f / n_reads * 100 },#{ map_bases.to_f / target_bases },#{ unq_bases.to_f / target_bases }"

  end
end

if __FILE__ == $0
  if ARGV.size >= 1
    sample = ARGV[0]
    puts CalcMapRate( sample ) 
  else
    input = STDIN.read
    puts CalcMapRate.run_with_input( input ) 
  end
end
