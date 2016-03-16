# -*- coding: utf-8 -*-
# load NGS_yyyymmdd.csv file
require 'csv'

module NGS

  HEADERS = %w(slide run_name application cluster_kit seq_kit hcs flowsell place place_id center_id library_id repli-g lane input density barcode disease note prep_kit prep_start seq_start seq_end 情報解析依頼 データ返却 担当 共有同意 snp_chip 解析状況 目的 施設)

  def self.readCSV(data)
    table = CSV.read(data, skip_blanks: true, headers: HEADERS)

    # 空の場合、前列の要素を引き継ぐ
    # slide またいだときの処理も別に考えた方がよいかも
    forwarding_headers = [0,1,2]
    last_headers = table.first.values_at(* forwarding_headers)
    table.each do |r|
      if HEADERS.size != r.size
        raise "NGS csv file format error: incorrect col size(#{r.size}) VS specified(#{Headers.size});" + "\n" + r.inspect()
      end
      for hi in forwarding_headers do 
        if r[hi].nil?
          r[hi] = last_headers[hi] 
        else 
          last_headers[hi] = r[hi]
        end
      end
    end
    #the first line is the header, not used since i manually specified
    table.delete(0)  
    return table
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

end
    
if __FILE__ == $0
  ngs = NGS.readCSV("./tmp/NGS_sample1")
  puts "header =", ngs.headers.inspect
  puts "inspect =" , ngs.inspect
end
  
