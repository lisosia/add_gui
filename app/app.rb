# -*- coding: utf-8 -*-

require 'sinatra'
require 'sinatra/reloader'
require 'sinatra/config_file'

set :root, File.expand_path( '../../.', __FILE__)

$LOAD_PATH.push( File.dirname(__FILE__) )

require_relative './verify_config.rb'
config_path = File.join( File.dirname(__FILE__), '../config.yml' )
verify_config( config_path )

require_relative './prepkit.rb'
PREP = Prepkit.new()

require_relative 'myconfig.rb'
$SETTINGS = MyConfig.new( config_path )
require_relative "./init.rb"
include MyLog

rack_logger = Logger.new('./log/app.log')

configure do
  use Rack::CommonLogger, rack_logger
end

before do
  unless File.exists? $SETTINGS.storage_root
    raise "invalid storage_root path<#{settings.storage_root}> specified in configfile<#{config_path}>"
  end
  @table = NGS::readCSV( $SETTINGS.ngs_file )
  @show_headers = ['slide', 'run_name', 'application', 'library_id']
end

get '/' do
  if @params[:range] and /\A[0-9]+-[0-9]+/ === @params[:range]
    min , max = @params[:range].split('-').map{|v| v.chomp.to_i}
    @filtered_table = slide_filtered_table(@table, min, max)
  elsif @params[:range] == 'others'
    @filtered_table = @table.group_by{|r| r.values_at('slide').first}.reject{|slide,arr| /\A[-+]?[0-9]+\z/ === slide }
  else
    @filtered_table = @table.group_by{|r| r.values_at('slide').first}
  end
  @show_headers = ['slide', 'run_name', 'application', 'library_id', 'prep_kit']

  haml :table, :locals => {:check_dir => @params[:check_dir]}
end

def slide_filtered_table(table, min, max, include_not_num = false)
  table.group_by{|r| r.values_at('slide').first}.select{|k,v| (include_not_num and !( /\A[-+]?[0-9]+\z/ === k) ) or (k.to_i <= max and k.to_i >= min ) }
end

post '/' do
  slide = @params[:slide]
  
  return "empty post; please return to previous page" if @params[:check].nil? 
  rows = @table.select{|r| r['slide'] == slide}
  library_ids_checked = params[:check].map{ |lib_id| @table.select{|r| r['library_id'] == lib_id}[0] }
  mylog.info 'post / called. slide=#{slide}; checked_ids=#{library_ids_checked}'
  raise "internal eoor; not such slide<#{slide}>" if library_ids_checked.any?{ |r| r.nil? }
  
  ok, prepkit = validate_prepkit( library_ids_checked )
  unless ok
    return haml( :error, :locals => { :unknown_prepkit => prepkit } )
  end

  prepare(slide, library_ids_checked )

  redirect to('/process')
end

get '/all' do
  @show_headers = NGS::HEADERS
  haml :table
end

get '/graph/:slide' do
  slide = @params[:slide]
  unless File.exist? File.join($SETTINGS.root, 'public/graph/#{slide}.png' )
    mk_graph(slide)
  end
  haml :graph , :locals => {:slide => "#{slide}"}
end

post '/graph/:slide' do
  slide = @params[:slide]
  mk_graph(slide)
  redirect to("/graph/#{slide}")
end

def mk_graph(slide)
  if slide.include? '/'
    mylog.warn "invalud reqest slide=[#{slide}]"
    return
  end
  system <<EOS
mkdir -p #{$SETTINGS.root}/public/graph
cd #{$SETTINGS.root}/public/graph && cat #{$SETTINGS.storage_root}/#{slide}/check_results.log | python #{$SETTINGS.root}/etc/mk_graph/mk_graph.py
mv tmp.png #{$SETTINGS.root}/public/graph/#{slide}.png
EOS
end

get '/process' do
  STEP = 10
  offset = @params[:offset].nil? ? 0 : @params[:offset].to_i

  headers =   %w(pid ppid status createat args uuid)
  head_show =   [0,  1,   2,     3,       4]
  tasks = TaskHgmd.run_sql("select #{headers.join(',')} from tasks order by uuid desc limit #{STEP} OFFSET #{offset}")
  count = TaskHgmd.run_sql("select COUNT(pid) from tasks").flatten[0]
  # tasks.map{|e| e.inspect}.join("<br>")

  haml :process ,:locals=>{:tasks => tasks, :step => STEP, :count => count, :headers => headers, :head_show => head_show}
end

get '/progress/:slide' do
  d = Dir.glob( File.join($SETTINGS.storage_root, params['slide'], "*" ) ).select{|f| File.directory? f}
  missings = []
  def cont(dr, arr)
    file = File.join dr,"make.log.progress"
    if File.exist? file 
      `cat #{file}`
    else
      arr << file
      "! file-not-exist" 
    end	
  end

  show = d.map{ |e|  [ e, cont(e, missings) ] }
  progresses = show.map{|f| f[0] + "; " + f[1].gsub("\tend", ' -> ').gsub("\t", ' ' ).gsub('  ', ' ').gsub("\n", " ") }.join("|\n") << "|"
  
  def check_results(slide)
    file = File.join $SETTINGS.storage_root, slide, "check_results.log"
    if File.exist? file
      `cat #{file} | grep "WARNING"`
    else
      "! file-not-exists"
    end

  end

missings_str = missings.size > 0 ? "<font color='red'>missing check_results.log (work not done, or error occured)<br/> #{missings.join("\n")} </font>" : ""
<<EOS
<h2> > check_results 's WARNING(s)</h2>
<textarea cols="120" wrap="off" readonly>
#{check_results( @params[:slide] )}
</textarea>
<BR/><BR/>
<h2> > progress of each sample dirs // make.progress.log</h2>
#{missings_str}
#{missings_str.empty? ? "" : "<br/><br/>"}

<small>progress sequence : [bam-index -> mpileup -> compress -> rars]</small><br/>
<textarea cols="120" wrap="off" readonly>
#{progresses}
</textarea>
EOS
end

def dir_slide_exist?(slide)
  slide = slide.to_s
  raise 'invalid arg' if slide == ''
  return File.directory? File.join($SETTINGS.storage_root, slide)
end

def dir_exists?(slide, library_id, prep_kit)
  raise "args include nil" if slide.nil? or library_id.nil?
  p = File.join( $SETTINGS.storage_root, slide, library_id, PREP.get_suffix(prep_kit) )
  File.exists? p
end

# to avoid uncaught throw <- cannot catch error over threads
def validate_prepkit(checked)
  checked.group_by{|r| r['prep_kit']}.each do |prep, row| 
    ok = PREP.get_suffix( prep )
    return [false, prep ] unless ok
  end
  return true
end

# - checked - Array of CSV::Row
def prepare(slide, checked)
  raise 'internal_error' unless ( checked.is_a? Array and checked[0].is_a? CSV::Row)

  checked.group_by{|r| r['prep_kit']}.each do |prep, row| 
    prepare_same_suffix(slide, row)
  end
  return nil
end

def prepare_same_suffix(slide, checked)
  mylog.info "prepare_same_suffix called; #{slide}, #{checked}"
  # get run-name from NGS-file
  prep_kits = checked.map{|r| r['prep_kit'] }

  raise 'internal_error' unless prep_kits.uniq.size == 1
  suffix = PREP.get_suffix( prep_kits[0] )
  raise 'err' unless suffix

  run_name = NGS::get_run_name(checked)
  ids = checked.map{|r| r['library_id']}
  storage = File.join( $SETTINGS.storage_root, slide)

  cmd = <<-EOS
  ruby #{$SETTINGS.root}/calc_dup/make_run.rb --run #{slide} --run-name #{run_name} --suffix #{suffix} --library-ids #{ids.join(',')} --storage #{storage} --path-check-result #{$SETTINGS.root}/calc_dup/check_results.rb --path-makefile #{$SETTINGS.makefile_path}
        EOS
  
  Dir.chdir($SETTINGS.storage_root){
    File.open("./#{slide}.make_run.rb.log", 'w') {|f| f.write(cmd) }
    `#{cmd}`
  }

  # TaskHgmd.spawn("./etc/dummy.sh" , slide ,ids, $SETTINGS.root )
  TaskHgmd.spawn("./auto_run#{suffix}.sh" , slide, ids, storage)

end
