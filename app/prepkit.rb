require 'yaml'
require_relative './config.rb'

class UnknownPrepkitError < StandardError
  attr_reader :prepkit
  def initialize(prepkit)
    @message = prepkit
  end
end

class Prepkit
  attr_accessor :suf_sure, :file, :data, :prep ,:data

  HEADS = %w{regex suffix surepos target}.map(&:to_sym)
  Col = Struct.new("PrepCol", * HEADS)

  def initialize( prep = load_config().prepfit_info ) # prep is a array of array
    raise unless prep.is_a? Array and prep[0].is_a? Array
    raise unless prep.size != HEADS.size
    @prep = prep
    @data = []
    for arr in @prep # arr == [regex, suffix, surepos_filepath, taget_bases]
      elm = Col.new( Regexp.new(arr[0]), arr[1], arr[2], arr[3] )
      raise 'empty regex in #{arr}' if elm.regex == ''
      raise "file not found #{elm.surepos}" if  elm.surepos != "" and !File.exists? elm.surepos
      raise "targetbase is not empty and not number #{elm.target}" unless elm.target.to_s == "" or /\A[0-9]+\z/ =~ elm.target.to_s
      @data << elm
    end
  end

  def get_suffix( prepkit )
    for e in @data
      return e.suffix if e.regex =~ prepkit
    end
    return nil
  end

  def suffix2targetbases(suffix)
    @suf_base ||= @data.reject{|e| e.suffix == ""}.map{ |e| [e.suffix,e.target] }
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
    @suf_sure ||= @data.reject{|e| e.suffix == ""}.map{|e| [e.suffix,e.surepos ] }
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

# old; depricated
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
