# -*- coding: utf-8 -*-
# load NGS_yyyymmdd.csv file
require 'csv'

module NGS
  HEADERS = %w{slide run_name application cluster_kit seq_kit hcs flowsell place place_id center_id library_id repli-g lane input density barcode disease note prep_kit prep_start seq_start seq_end 情報解析依頼 データ返却 担当 共有同意 snp_chip 解析状況 目的 施設}.map(&:to_sym)
  Col = Struct.new("NgsCol", * HEADERS) do
    def to_s
      "NGS::Col<#{slide},#{run_name},#{library_id},#{prep_kit}>"
    end
  end

  def self.readCSV(data)
    ret = []
    table = CSV.read(data, skip_blanks: true) # array of array # , skip_lines: /\A#/ // skip_lines optoin available at ruby >= 2.0
    # slide またいだときの処理も別に考えた方がよいかも
    forwarding_headers = [0,1,2]
    last_headers = Array.new( forwarding_headers.size, nil )
    table.each do |r|
      unless r[0].nil? # now, new slide , then remove forwarding cache
        last_headers = Array.new( forwarding_headers.size, nil )
      end
      if HEADERS.size != r.size
        raise "NGS csv file format error: incorrect col size(#{r.size}) VS specified(#{Headers.size});" + "\n" + r.inspect()
      end
      # 空の場合、前列の要素を引き継ぐ
      for hi in forwarding_headers do
        if r[hi].nil?
          STDERR.puts "cannot forwardably resolve colum:#{HEADERS[hi]}; at line#{r}" if last_headers[hi].nil?
          r[hi] = last_headers[hi]
        else
          last_headers[hi] = r[hi]
        end
      end
      r[0] = r[0].gsub(/\s+/, "").chomp  # some slide colum values contain white space
      ret << Col.new( * r )
    end
    #the first line is the header, not used since i manually specified
    table.delete(0)
    return ret
  end

  # return int-slides
  def self.int_slides(arr)
    arr.map(&:slide).uniq.select{ |s| /\A[0-9]+\z/ === s }.map(&:to_i)
  end

  def self.col(headername)
    r = HEADERS.index headername
    raise "undefined header_name:#{headername}" if r.nil?
    return r
  end

  def self.cols(headernames)
    r = headernames.map{|s| HEADERS.index s}
    raise "undefined header_name:#{headernames[r.index nil]}" if r.include? nil
    return r
  end

  #table of CSV::Rowを受け取り、run_name を返す。同じslideでrun-name矛盾したときのエラー処理等
  def self.get_run_name(rows) 
    run_names = rows.map{|c| c.run_name }
    raise 'multi run_name in rows' unless run_names.uniq.size == 1
    raise 'some samples\'s run_name (in NGS file) is empty(nil)' if run_names.include? nil
    return run_names[0]
  end

end

if __FILE__ == $0
  ngs = NGS.readCSV("../sim/ngs.csv")
  require "pry"
  binding.pry
end
