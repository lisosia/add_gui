# -*- coding: utf-8 -*-

require_relative "prevent_dup.rb"
PreventDup::run( File.expand_path(__FILE__) + ".pid.hist" )

require 'sinatra'
require 'sinatra/reloader'
require 'sinatra/config_file'

set :root, File.expand_path( '../../.', __FILE__)

$LOAD_PATH.push( File.dirname(__FILE__) )

config_path = File.join( File.dirname(__FILE__), '../config.yml' )

require_relative './prepkit.rb'
require_relative './config.rb'
$SET = load_config() # laod config.yml
$PREP = Prepkit.new( $SET.prepkit_info )

require_relative "./init.rb"

rack_logger = Logger.new('./log/app.log')

configure do
  set :rows, NGS::readCSV( $SET.ngs_file)
  raise if settings.rows.nil?
  set :rows_group, settings.rows.group_by(&:slide)
  use Rack::CommonLogger, rack_logger
end
mylog.info "start app"

before do
  unless File.exists? $SET.storage_root
    raise "invalid storage_root path<#{$SET.storage_root}> specified in configfile<#{config_path}>"
  end
  settings.rows = NGS::readCSV( $SET.ngs_file )
  @show_headers = ['slide', 'run_name', 'application', 'library_id', 'prep_kit']
end

get '/' do
  @table = settings.rows_group
  haml :index
end

get '/running' do
  `#{$SET.root}/etc/psppid #{Process.pid}`.split("\n").select{|e| /auto_run/ =~ e}.join('<br/>')
end

get '/table' do
  if @params[:range] and /\A[0-9]+-[0-9]+/ === @params[:range]
    min , max = @params[:range].split('-').map{|v| v.chomp.to_i}
    @filtered_table = slide_filtered_table(settings.rows, min, max)
  elsif @params[:range] == 'others'
    @filtered_table = settings.rows.group_by(&:slide).reject{|slide,arr| /\A[-+]?[0-9]+\z/ === slide }
  else
    @filtered_table = settings.rows.group_by(&:slide)
  end
  @show_headers = ['slide', 'run_name', 'application', 'library_id', 'prep_kit']
  @table = settings.rows
  haml :table, :locals => {:check_dir => @params[:check_dir]}
end

def slide_filtered_table(table, min, max, include_not_num = false)
  table.group_by(&:slide).select{|k,v| (include_not_num and !( /\A[-+]?[0-9]+\z/ === k) ) or (k.to_i <= max and k.to_i >= min ) }
end

get '/form/:slide' do
  slide = @params[:slide]
  raise if slide.nil?
  rows = settings.rows_group[slide]
  raise 'internal error; #{slide} not found in ngs' if rows.nil?
  haml :form, :locals => { :slide => slide, :rows =>rows }
end

post '/' do
  slide = @params[:slide]

  return "empty post; please return to previous page" if @params[:check].nil?
  rows = settings.rows.select{|c| c.slide == slide}
  library_ids_checked = params[:check].map{ |lib_id| settings.rows.select{|c| c.library_id == lib_id}[0] }
  return "Error; you checked sample(s) that already has sample dir " if library_ids_checked.any?{|c| dir_exists_col? c}
  mylog.info 'post / called. slide=#{slide}; checked_ids=#{library_ids_checked}'
  raise "internal eoor; not such slide<#{slide}>" if library_ids_checked.any?{ |r| r.nil? }

  ok, prepkit = validate_prepkit( library_ids_checked )
  unless ok
    return haml( :error, :locals => { :unknown_prepkit => prepkit } )
  end

  begin 
    prepare(slide, library_ids_checked )
  rescue => e
    STDERR.puts e.inspect
    return "<textarea cols='80'> #{e.inspect.to_s} </textarea> <br> check NGS file #{$SET.ngs_file} "
  end

  redirect to('/process')
end

get '/all' do
  @show_headers = NGS::HEADERS
  haml :table
end

get '/graph/:slide' do
  slide = @params[:slide]
  unless File.exist? File.join($SET.root, 'public/graph/#{slide}.png' )
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
mkdir -p #{$SET.root}/public/graph
cd #{$SET.root}/public/graph && cat #{$SET.storage_root}/#{slide}/check_results.log | python #{$SET.root}/etc/mk_graph/mk_graph.py
mv tmp.png #{$SET.root}/public/graph/#{slide}.png
EOS
end

get '/process' do
  step = 10
  offset = @params[:offset].nil? ? 0 : @params[:offset].to_i

  headers =   %w(pid ppid status createat args uuid)
  head_show =   [0,  1,   2,     3,       4]
  tasks = TaskHgmd.run_sql("select #{headers.join(',')} from tasks order by uuid desc limit #{step} OFFSET #{offset}")
  count = TaskHgmd.tasks.count
  # tasks.map{|e| e.inspect}.join("<br>")

  haml :process ,:locals=>{:tasks => tasks, :step => step, :count => count, :headers => headers, :head_show => head_show}
end

get '/progress/:slide' do
  d = Dir.glob( File.join($SET.storage_root, params['slide'], "*" ) ).select{|f| File.directory? f}
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
    file = File.join $SET.storage_root, slide, "check_results.log"
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
  return File.directory? File.join($SET.storage_root, slide)
end

def dir_exists?(slide, library_id, prep_kit)
  raise "args include nil" if slide.nil? or library_id.nil?
  suffix = $PREP.get_suffix(prep_kit).to_s
  p = File.join( $SET.storage_root, slide, library_id + suffix )
  File.exists? p
end
def dir_exists_col?(c)
  raise unless c.is_a? NGS::Col
  suffix = $PREP.get_suffix( c.prep_kit ).to_s
  f = File.join( $SET.storage_root, c.slide, c.library_id + suffix )
  File.exists? f
end

# to avoid uncaught throw <- cannot catch error over threads
def validate_prepkit(checked)
  checked.group_by(&:prep_kit).each do |prep, row|
    ok = $PREP.get_suffix( prep )
    return [false, prep ] unless ok
  end
  return true
end

# - checked - Array of Ngs::Col
def prepare(slide, checked)
  raise 'internal_error' unless ( checked.is_a? Array and checked[0].is_a? NGS::Col)

  group = checked.group_by { |col|
    $PREP.data.map(&:regex).find{ |reg| reg =~ col.prep_kit }
  }
  require_relative "../calc_dup/make_run.rb"
  path_check = File.join($SET.root,"calc_dup/check_results.rb")
  # make run.sh
  group.each do |regex, rows|
    raise "internal error; unknown_prepkit" if regex.nil?
    prep_kits = rows.map(&:prep_kit)
    mylog.warn "same regex, but slightly different prep_kits: #{prep_kits}" unless prep_kits.uniq.size == 1
    run_name = NGS::get_run_name(rows)
    ids = rows.map(&:library_id) # must be one
    suffix = $PREP.get_suffix( rows.first.prep_kit )

    make_run_sh(slide, run_name, suffix, ids, $SET.storage_root, $SET.makefile_path, path_check )
  end

  # make auto_run.sh
  bashfile = make_auto_run_sh($SET.storage_root, slide,  group , path_check )

  # launch task
  TaskHgmd.spawn( slide, checked.map(&:library_id), bashfile )

  return nil
end
