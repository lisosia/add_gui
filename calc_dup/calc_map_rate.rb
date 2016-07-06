#!/bio/bin/ruby

require 'yaml'

# $conf = [ [suffix1, target_bases1], [suffix2, target_bases2], ...  ]
$conf = YAML.load_file( File.join( File.dirname(__FILE__) , '../config.yml' ) )['prepkit_info']
  .map{|arr| [ arr[1], arr[3] ] }
  .select{|suf, target| target != ''  }
  .map{|sux, target| [ sux, target.to_i ] }

def suffix2targetbases(suffix)
  ret = $conf.select{|suf, target| suffix.match /#{suf}/ }
  if ret.length != 0
    return ret.first[1]
  else
    return nil
  end
end


name = nil
n_reads = map_reads = unq_reads = map_bases = unq_bases = 0

while l = gets
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

target_bases = suffix2targetbases( sample[0] ) || 3095677412

# Sample,#Reads,#Mapped Reads,#Mappe Reads (Unique),Mapping Rate (%),Mapping Rate (Unique) (%),Coverage (x),Coverage (Unique) (x)
puts "#{sample[0]},#{n_reads},#{map_reads},#{unq_reads},#{ map_reads.to_f / n_reads * 100 },#{ unq_reads.to_f / n_reads * 100 },#{ map_bases.to_f / target_bases },#{ unq_bases.to_f / target_bases }"
