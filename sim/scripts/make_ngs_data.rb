require "csv"
require_relative "../../ngs_csv.rb"

slides = 1..3

CSV.open("ngs.csv", "w") do |csv|
  csv << NGS::HEADERS
  n = 0
  for slide in slides do
    for line_num in 0...(Random.rand(3) + 5) do
      line = []
      line << (line_num == 0 ? slide : nil )
      for col in NGS::HEADERS[1..-1] do
        line << "#{slide}_runname" and next if col == "run_name"
        line << col + "_" + slide.to_s + "_" + Random.rand(2).to_s
      end
      csv << line
    end
  end

end
