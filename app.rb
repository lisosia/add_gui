# -*- coding: utf-8 -*-
require 'sinatra'
require 'sinatra/reloader'
require 'sinatra/config_file'
require 'haml'
require 'pp'
require 'pry'
require 'sqlite3'
require "./task_manager"

require_relative "./ngs_csv.rb"

config_file_path = './config.yml'
config_file config_file_path

tasks = TaskSpawn.new

before do
  unless File.exists? settings.storage_root
    raise "invalid storage_root path<#{settings.storage_root}> specified in configfile<#{config_file_path}>"
  end
  @table = NGS::readCSV( settings.ngs_file )
  @show_headers = ['slide', 'run_name', 'application', 'library_id']

end

get '/' do
  @show_headers = ['slide', 'run_name', 'application', 'library_id']
  haml :table
end

#post '/' do
#  slide = @params[:slide]
#  library_ids = @table.select{|row| row['slide'] == slide}.map{|row| row['library_id'] }
#  library_ids_checked = params[:check]
#  raise "not such slide<#{slide}>" if library_ids.include? nil
#  process(slide, library_ids,library_ids_checked )
#end

get '/all' do
  @show_headers = NGS::HEADERS
  haml :table
end


get '/process' do
  @last_tasks = nil
  begin
    db = SQLite3::Database.open("tmp/tmp_tasklog.sqlite3")
    @last_tasks = db.execute("select rowid,* from tasks order by rowid desc limit 6;")
  ensure
    db.close if db
  end
  f = tasks.waitany_nohang()
  haml :process
end

get '/enqueue' do
  require "./task_hgmd"
  tasks.spawn_task(TaskHgmd.new(nil) )
end


def dir_exists?(slide, library_id, prep_kit)
  raise "args include nil" if slide.nil? or library_id.nil?
  p = settings.storage_root + '/' + slide.to_s + '/' + library_id.to_s + get_suffix(prep_kit)
  #return p
  File.exists? (p)
end

def get_suffix(prep_kit)
  case prep_kit
  when /^N.A./ return ''
  when /^Illumina TruSeq/ return '_TruSeq'
  when /^Agilent SureSelect custom 0.5Mb/ return '_SSc0_5Mb'
  when /^Agilent SureSelect custom 50Mb/ return '_SS50Mb'
  when /^Agilent SureSelect v4\+UTR/ return '_SS4UTR'
  when /^Agilent SureSelect v5\+UTR/ return '_SS5UTR'
  when /^Agilent SureSelect v6\+UTR/ return '_SS6UTR'
  when /^Agilent SureSelect v5/ return '_SS5'
  when /^Amplicon/ return '_Amplicon'
  when "RNA" return '_RNA'
  when /^TruSeq DNA PCR-Free Sample Prep Kit/ return '_WG'
  else
    STDERR.puts "WARNING Uninitilalized value; #{prep_kit}"
  end
  return ''
end

def process(slide, library_ids, checked)
  "process<br>-- slide : #{slide}<br>-- library_ids : #{library_ids}<br>-- checked : #{checked}"
end
