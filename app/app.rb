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
require_relative "./ngs_csv.rb"
$SET.rows = NGS::readCSV( $SET.ngs_file)
$SET.rows_group = $SET.rows.group_by(&:slide)
raise if $SET.rows.nil?
unless File.exists? $SET.storage_root
  raise "invalid storage_root path<#{$SET.storage_root}> specified in configfile<#{config_path}>"
end

require_relative "./init.rb"
require_relative "./log.rb"
include MyLog
require_relative "./task_hgmd.rb"
TaskHgmd.init_db()
require_relative './ps_wrap.rb'

rack_logger = Logger.new('./log/app.log')

configure do
  use Rack::CommonLogger, rack_logger
end
mylog.info "start app"

before do
  @show_headers = ['slide', 'run_name', 'application', 'place' ,'library_id', 'prep_kit']
  @configs = $SET
end

post '/reload_ngs' do
  set_tmp = load_config()
  $SET.ngs_file = set_tmp.ngs_file
  $SET.rows = NGS::readCSV( $SET.ngs_file )
  $SET.rows_group = $SET.rows.group_by(&:slide)  
  redirect to('/')
end

post '/reload' do
  
  $SET = load_config() # laod config.yml
  $PREP = Prepkit.new( $SET.prepkit_info )
  $SET.rows = NGS::readCSV( $SET.ngs_file)
  $SET.rows_group = $SET.rows.group_by(&:slide)

  load "task_hgmd.rb"
  TaskHgmd.init_db()
  redirect back
end

get '/' do
  @table = $SET.rows_group
  haml :index
end

get '/running' do
  
  auto_runs = PsWrap.command /auto_run/
  # fetch notDone tasks in db
  notdone = TaskHgmd.tasks.where( :status => "NotDone")
  # get corresponing unix-process
  data = notdone.map do |col|
    corresp = auto_runs.find do |proc| 
      col[:pid] == proc.pid.to_i and /#{col[:uuid]}/ =~ proc.command
    end
    [col, corresp]
  end
  haml :running, :locals => {:data => data }
end

post '/kill/:pid' do
  pid = @params[:pid]
  raise 'internal error' unless /[1-9][0-9]*/ =~ pid
  raise 'not positive pid' unless pid.to_i > 0
  `kill -TERM -#{pid}` # kill all process groups
  sleep 1
  redirect to('/running')
end

get '/table' do
  if @params[:range] and /\A[0-9]+-[0-9]+/ === @params[:range]
    min , max = @params[:range].split('-').map{|v| v.chomp.to_i}
    @filtered_table = slide_filtered_table($SET.rows, min, max)
  elsif @params[:range] == 'others'
    @filtered_table = $SET.rows.group_by(&:slide).reject{|slide,arr| /\A[-+]?[0-9]+\z/ === slide }
  else
    @filtered_table = $SET.rows.group_by(&:slide)
  end
  @show_headers = ['slide', 'run_name', 'application', 'library_id', 'prep_kit']
  @table = $SET.rows
  haml :table, :locals => {:check_dir => @params[:check_dir]}


end

def slide_filtered_table(table, min, max, include_not_num = false)
  table.group_by(&:slide).select{|k,v| (include_not_num and !( /\A[-+]?[0-9]+\z/ === k) ) or (k.to_i <= max and k.to_i >= min ) }
end

get '/menu/:slide' do
  slide = @params[:slide]
  rows = $SET.rows_group[slide]
  #tasks = TaskHgmd.run_sql("select #{headers.join(',')} from tasks order by uuid desc where args like '#{slide} %' ")
  tasks = TaskHgmd.tasks.where( Sequel.like( :args , "#{slide} %" ) )
  heads = tasks.columns
  haml :menu, :locals => { :slide => slide, :rows =>rows, :tasks => tasks, :heads => heads }
end

get '/form/:slide' do
  
  slide = @params[:slide]
  raise if slide.nil?
  rows = $SET.rows_group[slide]
  raise 'internal error; #{slide} not found in ngs' if rows.nil?
  haml :form, :locals => { :slide => slide, :rows =>rows }
end

post '/' do

  begin 

    slide = @params[:slide]

    return "empty post; check some samples" if @params[:check].nil?
    rows = $SET.rows.select{|c| c.slide == slide}
    library_ids_checked = params[:check].map{ |lib_id| rows.select{|c| c.library_id == lib_id}[0] }
    return "Error(post /); you checked sample(s) that already has sample dir " if library_ids_checked.any?{|c| dir_exists_col? c}
    mylog.info "post / called. slide=#{slide}; checked_ids=#{params[:check]}"
    raise "internal error; not such slide<#{slide}>" if library_ids_checked.any?{ |r| r.nil? }

    ok, prepkit = validate_prepkit( library_ids_checked )
    unless ok
      # return haml( :error, :locals => { :unknown_prepkit => prepkit } )
      raise "unknown_prepkit=>[#{prepkit}]"
    end

    prepare(slide, library_ids_checked )
  rescue => e
    STDERR.puts e.inspect
    # return "<textarea cols='80'> #{e.inspect.to_s} </textarea> <br> check NGS file #{$SET.ngs_file} "
    return "InternalError: #{e.inspect.to_s}"
  end

  "Success: task launched #{}"
end

get '/form_cp_results/:slide' do
  slide = @params[:slide]
  raise if slide.nil?
  rows = $SET.rows_group[slide]
  raise 'internal error; #{slide} not found in ngs' if rows.nil?
  haml :form_cp_results, :locals => { :slide => slide, :rows =>rows }
end

post '/form_cp_results' do
  slide = @params[:slide]
  raise if slide.nil?

  return "empty post; please return to previous page" if @params[:check].nil?
  rows = $SET.rows.select{|c| c.slide == slide}
  library_ids_checked = params[:check].map{ |lib_id| rows.select{|c| c.library_id == lib_id}[0] }
  return "Error; you checked sample(s) that does not have sample dir " if library_ids_checked.any?{|c| ! dir_exists_col? c}
  mylog.info 'post form_cp_results / called. slide=#{slide}; checked_ids=#{library_ids_checked}'
  raise "internal error; not such slide<#{slide}>" if library_ids_checked.any?{ |r| r.nil? }

  places = library_ids_checked.map(&:place).uniq
  return "duplication of places: #{ places }" unless places.size == 1
  place = places[0]

  subdir = $SET.place2dirname[ place.to_s ]
  if subdir.nil?
    input = @params[ :output_subdir ]
    if input.nil? or input.empty?
      return "place not registered and textarea is empty"
    else
      subdir = input
    end
  end

  raise unless Dir.exists? $SET.copy_output_dir
  copy_output_dir = File.join( $SET.copy_output_dir , subdir)
  `mkdir -p #{copy_output_dir}` unless Dir.exists? copy_output_dir

  storage = File.join( $SET.storage_root, slide )
  raise unless Dir.exists? storage

cmd = <<EOS
cd #{storage} ;
bash #{File.join( $SET.root, "etc" , "cp_results.sh" ) } #{copy_output_dir} #{ library_ids_checked.map(&:library_id).join(" ") }
EOS

  ` #{cmd} `
  "#files copyed to #{copy_output_dir}; bash command are below<br>#{cmd}"
end

get '/form_remake_checkresults/:slide' do
  slide = @params[:slide]
  raise if slide.nil?
  rows = $SET.rows_group[slide]
  raise 'internal error; #{slide} not found in ngs' if rows.nil?
  haml :form_remake_checkresults, :locals => { :slide => slide, :rows =>rows }
end

post '/form_remake_checkresults' do
  slide = @params[:slide]
  raise if slide.nil?
  return "empty post; please return to previous page" if @params[:check].nil?
  rows = $SET.rows.select{|c| c.slide == slide}
  checked = params[:check].map{ |lib_id| rows.select{|c| c.library_id == lib_id}[0] }
  return "Error; you checked sample(s) that does not have sample dir " if checked.any?{|c| ! dir_exists_col? c}

  files = Dir[ File.join( $SET.storage_root,slide, '*' ) ]
  fn = checked.map{ |r| files.find{|f| f =~ /#{r.library_id}/ } }
  return 'internal err; some of sample-dirs you requested are missing' if fn.any?(&:nil?)
  fn = fn.map{ |n| n.split('/')[-1] }

  cmd = <<EOS
cd #{ File.join( $SET.storage_root, slide ) }
ruby -W0 #{ File.join( $SET.root, 'calc_dup', 'check_results.rb' ) } #{fn.join(',')} > check_results.log 2> check_results.log
EOS

  p = Process.spawn( cmd )
  Process.detach( p )
  
  "background-job spawned;wait a minutes to complete; commands are<br>#{cmd}"
  
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
      # `cat #{file} | grep -v -E "^[0-9]{4}"`
      `cat #{file} `
    else
      "! file-not-exists"
    end

  end

missings_str = missings.size > 0 ? "<font color='red'>missing check_results.log (work not done, or error occured)<br/> #{missings.join("\n")} </font>" : ""
<<EOS
<h2> > check_results </h2>
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
  `mkdir -m 775 #{ File.join( $SET.storage_root, slide ) }`
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


### VIEW HELPERS

helpers do
  def table(arg)
    <<EOS
<table border="1">
<thread><tr><th>
ok
</th></tr></thread>

<tbody>
<tr><td>conl</td></tr>
<tr><td> #{arg} </td></tr>
</tbody>

</table>
EOS
  end

  def t2(arg)
    <<EOS
<table border="1">
<thread><tr><th>
ok
</th></tr></thread>

<tbody>
<tr><td>conl</td></tr>
<tr><td> #{arg} </td></tr>
</tbody>

</table>
EOS
  end

end
