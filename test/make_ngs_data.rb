require "csv"
require_relative "../ngs_csv.rb"

slides = 1..3

CSV.open("ngs.csv", "w") do |csv|
  csv << NGS::Headers
  n = 0
  for slide in slides do
    for line_num in 0...(Random.rand(3) + 5) do
      line = []
      line << (line_num == 0 ? slide : nil )
      for col in NGS::Headers[1..-1] do
        line << col + "_" + slide.to_s + "_" + Random.rand(100).to_s
      end
      csv << line
    end
  end

end
