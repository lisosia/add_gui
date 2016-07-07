#!/bio/bin/ruby

require 'yaml'
require_relative '../app/prepkit.rb'
PREP = Prepkit.new()

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

target_bases = PREP.suffix2targetbases( sample[0] ) || 3095677412

# Sample,#Reads,#Mapped Reads,#Mappe Reads (Unique),Mapping Rate (%),Mapping Rate (Unique) (%),Coverage (x),Coverage (Unique) (x)
puts "#{sample[0]},#{n_reads},#{map_reads},#{unq_reads},#{ map_reads.to_f / n_reads * 100 },#{ unq_reads.to_f / n_reads * 100 },#{ map_bases.to_f / target_bases },#{ unq_bases.to_f / target_bases }"
