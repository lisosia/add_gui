require 'sinatra'
require 'sinatra/reloader'
require 'sinatra/config_file'
require 'haml'
require 'pp'
require 'pry'
require "./task_manager"

require_relative "./ngs_csv.rb"

config_file_path = './config.yml'
config_file config_file_path

@table = NGS::readCSV( settings.root + "/sim/ngs.csv")
@tasks = TaskSpawn.new

before do
  unless File.exists? settings.storage_root
    raise "invalid storage_root path<#{settings.storage_root}> specified in configfile<#{config_file_path}>"
  end
  @table = NGS::readCSV( settings.root + "/sim/ngs.csv")
  @show_headers = ['slide', 'run_name', 'application', 'library_id']

end

get '/processes' do
  " #{@tasks.pids.inspect} "
end

get '/' do
  @display_cols = NGS::cols ['slide', 'run_name', 'application']
  haml :table
end

post '/' do
  @tasks.spawn("sleep 10")
  redirect "/processes"
end 


#post '/' do
#  slide = @params[:slide]
#  library_ids = @table.select{|row| row['slide'] == slide}.map{|row| row['library_id'] }
#  library_ids_checked = params[:check]
#  raise "not such slide<#{slide}>" if library_ids.include? nil
#  process(slide, library_ids,library_ids_checked )
#end


get '/all' do
  haml :table
end

def dir_exists?(slide, library_id)
  raise "args include nil" if slide.nil? or library_id.nil?
  p = settings.storage_root + '/' + slide.to_s + '/' + library_id.to_s
  #return p
  File.exists? (p)
end

def process(slide, library_ids, checked)
  "process<br>-- slide : #{slide}<br>-- library_ids : #{library_ids}<br>-- checked : #{checked}"
end