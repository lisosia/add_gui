# -*- coding: utf-8 -*-
require 'sinatra'
require 'sinatra/reloader'
require 'sinatra/config_file'
require 'haml'
require 'pp'
require 'pry'
require 'sqlite3'
require "./task_manager"
require 'logger'

require_relative "./ngs_csv.rb"

logger = Logger.new('./log/app.log')
config_file_path = './config.yml'
config_file config_file_path

tasks = TaskSpawn.new

configure do
  # logging is enabled by default in classic style applications,
  # so `enable :logging` is not needed
  file = File.new("#{settings.root}/log/#{settings.environment}.log", 'a+')
  file.sync = true
  use Rack::CommonLogger, file
end

before do
  unless File.exists? settings.storage_root
    raise "invalid storage_root path<#{settings.storage_root}> specified in configfile<#{config_file_path}>"
  end
  @table = NGS::readCSV( settings.ngs_file )
  @show_headers = ['slide', 'run_name', 'application', 'library_id']
end

get '/' do
  @show_headers = ['slide', 'run_name', 'application', 'library_id', 'prep_kit']
  haml :table, :locals => {:check_dir => @params[:check_dir]}
end

post '/' do
  logger.info 'post / called'
  slide = @params[:slide]
  redirect '/' if @params[:check].nil? 
  rows = @table.select{|r| r['slide'] == slide}
  library_ids_checked = params[:check].map{ |lib_id| @table.select{|r| r['library_id'] == lib_id}[0] }
  raise "not such slide<#{slide}>" if library_ids_checked.any?{ |r| r.nil? }
  logger.info 'just before call prepare(). from post /'
  prepare(slide, library_ids_checked )
  logger.info 'prepare call fin. from post /'
  redirect to('/')
end

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
  when /^N.A./ then return ''
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
    return '___NONE___'
  end  
end

# - checked - Array of CSV::Row
def prepare(slide, checked)
  logger.info "prepare called; #{slide},#{checked}"
  raise 'internal_error' unless ( checked.is_a? Array and checked[0].is_a? CSV::Row)

  checked.group_by{|r| r['prep_kit']}.each do |prep, row| 
    prepare_same_suffix(slide, row)
  end
  logger.info "prepare fin"
  return nil
end

def prepare_same_suffix(slide, checked)
  logger.info "prepare_same_suffix called; #{slide},#{checked}"
  # get run-name from NGS-file
  prep_kits = checked.map{|r| r['prep_kit'] }

  raise 'internal_error' unless prep_kits.uniq.size == 1
  suffix = get_suffix( prep_kits[0] )

  run_name = NGS::get_run_name(checked)
  ids = checked.map{|r| r['library_id']}.join(',')

  cmd = <<-EOS
  perl #{settings.root}/calc_dup/make_run_takearg.pl --run #{slide} --run-name #{run_name} --suffix #{suffix} --library-ids #{ids} \\ 
  >>  ./#{slide}.log \\
  2>> ./#{slide}.errlog
  EOS
  Dir.chdir(settings.storage_root){
    File.open("./#{slide}.tmplog___", 'w') {|f| f.write(cmd) }
    exec( cmd )
  }
end
