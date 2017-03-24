#!/usr/bin/env ruby
require 'open3'

module CalcDup
 
  def self.run( sample )
    file = File.open( "#{sample}/stat/dup/dup.stat" )
    run_with_io( file )
  end
  
  def self.run_with_io( io )

    ret = nil
    
    perl_script = File.expand_path( File.join( File.dirname(__FILE__), 'calc_dup.pl'  ) )
    
    out, err, status = Open3.capture3( "perl #{perl_script}", :stdin_data => io.read )
    
    if status.success?
      ret = out
    else
      raise 'exit-code==#{status}'
    end
    
    return ret.chomp
  end

end

if __FILE__ == $0  

  if ARGV.size >= 1
    puts CalcDup.run_with_io( File.read( ARGV[0], 'r' ) )
  else
    puts CalcDup.run_with_io( STDIN )
  end

end
