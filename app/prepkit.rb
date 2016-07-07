require 'yaml'

class UnknownPrepkitError < StandardError
  attr_reader :prepkit
  def initialize(prepkit)
    @message = prepkit
  end  
end

class Prepkit
  attr_accessor :suf_sure, :file, :data, :prep ,:data
  def initialize(file = File.join( File.dirname(__FILE__), '../config.yml') )
    @file = file
    @prep = YAML.load_file( file )['prepkit_info']
    @data = []
    for arr in @prep # arr == [regex, suffix, surepos_filepath, taget_bases]
      raise 'empty regex in a#{arr}' if arr[0] == ''
      @data << [ Regexp.new(arr[0]), arr[1], arr[2], arr[3] ]
    end
  end

  def get_suffix( prepkit )
    for arr in @data
      return arr[1] if arr[0] === prepkit
    end
    return  nil
  end

  def suffix2targetbases(suffix)
    @suf_base ||= @prep.map{ |a| [a[1],a[3]] }.reject{|suf,_| suf == '' }
    for suf, base in @suf_base
      raise "invalid target base: #{base}" unless base=='' or  base.is_a?(Integer) or /\A[0-9]+\z/.match(base)
      if suffix.match /#{suf}/
        return nil if base == ''
        return base 
      end
    end

    STDERR.puts 'unknown suffix #{suffix}'
    return nil
  end

  def suffix2sure_pos(suffix)
    @suf_sure ||= @prep.map{  |a| [a[1],a[2]] }.reject{|suf,_| suf == '' }
    for suf, sure in @suf_sure
      raise "file not found: #{sure}" unless sure=='' or File.exists?( sure )
      if suffix.match /#{suf}/
        return nil if sure == ''
        return sure 
      end
    end
    STDERR.puts 'unknown suffix #{suffix}'
    return nil
  end

end

# old
def get_suffix_old(prep_kit)
  case prep_kit
  # when /^N.A./ then return ''
  when /^Illumina TruSeq/ then return '_TruSeq'
  when /^Agilent SureSelect custom 0.5Mb/ then return '_SSc0_5Mb'
  when /^Agilent SureSelect custom 50Mb/ then return '_SS50Mb'
  when /^Agilent SureSelect v4\+UTR/ then return '_SS4UTR'
  when /^Agilent SureSelect v5\+UTR/ then return '_SS5UTR'
  when /^Agilent SureSelect v6\+UTR/ then return '_SS6UTR'
  when /^Agilent SureSelect v5/ then return '_SS5'
  when /^Amplicon/ then return '_Amplicon'
  when "RNA" then return '_RNA'
  when /^TruSeq DNA PCR-Free Sample Prep Kit/ then return '_WG'
  else
    STDERR.puts "WARNING Uninitilalized value; #{prep_kit}"
    return [nil,  prep_kit ]
  end  
end

if __FILE__ == $0

  p get_suffix_old( 'Agilent SureSelect v5 adsa' )
  p get_suffix_old( 'Agilent SureSelect v6+UTR 21adsa' )
  p '---'

  c = Prepkit.new()
  p c.get_suffix( 'Agilent SureSelect v5 adsa' )
  p c.get_suffix( 'Agilent SureSelect v6+UTR 21adsa' )
  
  p '---'
  p c.suffix2surepos '_WG'
  p c.suffix2targetbases '_WG'

  p c.suffix2surepos '_SS5'
  p c.suffix2targetbases '_SS5'

  p c.suffix2surepos '_Custom'
  p c.suffix2targetbases '_Custom'

end
