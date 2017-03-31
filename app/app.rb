# -*- coding: utf-8 -*-

require_relative "prevent_dup.rb"
PreventDup::run( File.expand_path(__FILE__) + ".pid.hist" )

require 'haml'
require 'pp'
require 'pry'
require 'sqlite3'
require 'fileutils'

require 'sinatra'
require 'sinatra/reloader'
require 'sinatra/config_file'
require 'sinatra/streaming'
require 'json'

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

FileUtils.mkdir_p File.join(settings.root, "tmp")
FileUtils.mkdir_p File.join(settings.root, "log")
FileUtils.mkdir_p File.join(settings.root, "sim")

require_relative "./process_status.rb"
require_relative "./log.rb"
include MyLog
require_relative "./task_hgmd.rb"
TaskHgmd.init_db()
require_relative './ps_wrap.rb'
require_relative "../calc_dup/make_run.rb"
require_relative "../calc_dup/check_results.rb"


rack_logger = Logger.new('./log/app.log')

configure do
  use Rack::CommonLogger, rack_logger
end
mylog.info "start app"

before do
  @show_headers = ['slide', 'run_name', 'application', 'place' ,'library_id', 'prep_kit']
  @configs = $SET
  ProcessStatus.put 'debug', ProcessStatus::DONE, msg = 'this is for debug'
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
  `kill -KILL -#{pid}` # kill all process groups
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
  #tasks = TaskHgmd.tasks.where( Sequel.like( :args , "#{slide} %" ) )
  tasks = TaskHgmd.tasks_find_by_slide(slide) 
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

# assume retuened dataType; 'text' ; in /js/post.js
post '/get_post_status/:uuid' do
  uuid = @params[:uuid]
  state = nil
  state = ProcessStatus.get(uuid)

  # deletion of the record is optoinal
  # ProcessStatus.delete(uuid) if not state.nil? and state.end?
  
  if state    
    return { 'status' => state.status, 'msg' => state.msg, 'time' => state.created_at  }.to_json
  else
    return { 'status' => 'invalid request', 'msg' => 'requested post-result(uuid) not found' }.to_json
  end

end
get "/get_post_status/:uuid" do
  uuid = @params[:uuid]
  ProcessStatus.expire() # remove expired data
  haml :get_post_status, :locals => { :uuid => uuid }
end

$_post_allow = true
post '/' do
  mylog.info "post(/) called. slide=#{@params[:slide]}; checked_ids=#{params[:check]}; action=#{@params[:action]}"
  prepare_only = @params[:action] == 'preparation'

  uuid = SecureRandom.uuid
  unless $_post_allow
    status 500
    return 'error: double submit'
  end
  $_post_allow = false
  ProcessStatus.put( uuid, ProcessStatus::PROCESSING )

  slide = @params[:slide]

  raise "empty post; check some samples" if @params[:check].nil?
  checked_ids = @params[:check].map do |e|
    slide, libid = e.split('@')
    libid
  end

  rows = $SET.rows_group[slide]
  library_ids_checked = checked_ids.map do |lib_id| 
    sel = rows.find{|c| c.library_id == lib_id } 
    raise "Internal Error: sample(slie=#{slide},library_id=#{lib_id}) not found" if sel.nil?
    sel
  end
      
  # if not relunch, and sample-di exists, then error
  unless @params[:relaunch]
    raise "Error(post /); you checked sample(s) that already has sample dir " if library_ids_checked.any?{|c| dir_exists_col? c}
  end
  
  ok, prepkit = validate_prepkit( library_ids_checked )
  unless ok
    raise "unknown_prepkit=>[#{prepkit}]"
  end

  if prepare_only
    filename = prepare_and_spawn(slide, library_ids_checked, @params[:relaunch], prepare_only )    
    $_post_allow = true    
    return "Preparation finished. file to execute is #{filename} @ #{File.join($SET.storage_root,slide)}"
  else
    Thread.start do
      begin 
        prepare_and_spawn(slide, library_ids_checked, @params[:relaunch] )
        ProcessStatus.put( uuid, ProcessStatus::DONE )
        
      rescue => e
        STDERR.puts e.inspect
      ProcessStatus.put( uuid, ProcessStatus::ERROR, msg = "InternalError: #{e.inspect.to_s}" )
      ensure
        $_post_allow = true    
        puts 'post(/) ensured'
      end
    end
    
  end

  redirect to( "/get_post_status/#{uuid}" )
end

get '/form_cp_results/:slide' do
  slide = @params[:slide]
  raise if slide.nil?
  rows = $SET.rows_group[slide]
  raise 'internal error; #{slide} not found in ngs' if rows.nil?
  haml :form_cp_results, :locals => { :slide => slide, :rows =>rows, :header => @show_headers }
end

post '/form_cp_results' do
  slide = @params[:slide]
  raise if slide.nil?

  return "empty post; please return to previous page" if @params[:check].nil?
  checked_ids = @params[:check].map do |e|
    slide, libid = e.split('@')
    libid
  end
  rows = $SET.rows_group[slide]
  library_ids_checked = checked_ids.map{ |lib_id| rows.find{|c| c.library_id == lib_id} }
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
  FileUtils.mkdir_p copy_output_dir

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
  log = CheckResults.new(dir=File.join($SET.storage_root,slide)).to_s
  haml :form_remake_checkresults, :locals => { :slide => slide, :rows =>rows, :log => log }
end

post '/form_remake_checkresults' do
  slide = @params[:slide]
  raise if slide.nil?
  return "empty post; please return to previous page" if @params[:check].nil?
  checked_ids = @params[:check].map do |e|
    slide, libid = e.split('@')
    libid
  end

  rows = $SET.rows.select{|c| c.slide == slide}
  checked = checked_ids.map{ |lib_id| rows.find{|c| c.library_id == lib_id} }
  return "Error; you checked sample(s) that does not have sample dir " if checked.any?{|c| ! dir_exists_col? c}

  ret = remake_checkresults( slide, checked, async= false )
  # redirect to(/form_remake_checkresults/#{slide})
end

# rows: array of samples
def remake_checkresults( slide , rows, async = true, basename = 'check_results.json' )
  outfile = File.join( $SET.storage_root, slide, basename )
  FileUtils.rm_f outfile
  files = Dir[ File.join( $SET.storage_root, slide, '*' ) ]

  def write( outfile, libids )
    c = CheckResults.new( dir=File.dirname(outfile) )
    c.add_samples( libids )
    return c.to_s
  end

  if async # background
    Thread.new(outfile ,rows.map(&:library_id) ) do |outfile, libids|
      write(  outfile, libids )
    end
  else
    write( outfile, rows.map(&:library_id) )
  end
end


def make_checkresults_all(slide)
  dir = File.join( $SET.storage_root, slide )
  res = CheckResults.new( dir = dir, 'check_results.log.all' ,  )
  samples = Dir[ File.join( dir, "*/" ) ]
  res.add_samples( samples )
end

get '/all' do
  @show_headers = NGS::HEADERS
  haml :table
end

get '/showgraph/:slide' do
  slide = @params[:slide]
  if not File.exist? File.join($SET.root, "public/graph/#{slide}.png" ) and not /tmp/ === slide
    # mk_graph(slide)
  end
  haml :graph , :locals => {:slide => "#{slide}"}
end

post '/showgraph/:slide' do
  slide = @params[:slide]
  mk_graph(slide)
  redirect to("/showgraph/#{slide}")
end

def mk_graph(slide)
  if slide.include? '/'
    mylog.warn "invalud reqest slide=[#{slide}]"
    return
  end
  mylog.info "-> start making graph @ silde == #{slide}"
  FileUtils.mkdir_p 'public/graph'
  # input = CheckResults.json2oldformat( dir = File.join( $SET.storage_root, slide ) )
  res = CheckResults.new( dir = File.join( $SET.storage_root, slide ) )
  mylog.info "- checkresults loaded"
  if res.samples.size != $SET.rows_group[slide].size
    raise "sample size in check_results.json (=#{res.samples.size} ) does not match # of samples in NGS file (= $SET.rows_group(slide).size)"
  end
  input = res.to_s_old()
  
  mylog.info "- input data prepared : #{input[0..30]} ..."
  stdin,stdout,stderr, wait_thr = Open3.popen3( "python #{$SET.root}/etc/mk_graph/mk_graph.py #{$SET.root}/public/graph/#{slide}.png" )
  mylog.info '- open3 opened'
  stdin.puts input
  stdin.close
  mylog.info '- write inputs done'
  o,r = stdout.read, stderr.read
  mylog.info '- read stdout,stderr done'
  unless wait_thr.value.success?
    raise 'make graph script returns non-zero exit code'
  end   
  mylog.info "<--- end making graph @ silde == #{slide}"
 
#   `

# cd #{$SET.root}
# mkdir -p public/graph
# ruby calc_dup/check_results.rb --file #{$SET.storage_root}/#{slide}/check_results.json --convert-rev | python etc/mk_graph/mk_graph.py public/graph/#{slide}.png
# `
end

get '/graph-across-slides' do
  @table = $SET.rows_group
  haml :graph_across_slides, :locals =>{ :table => @table } , :layout => false
end
post '/graph-across-slides' do
  slides = @params[:slides]
  redirect to( "/graph-across-slides/#{slides.sort.join '-'}" )
  # haml :graph_across_slides, :locals =>{ :table => @table } , :layout => false
end

get '/graph-across-slides/:slides' do
  slides = @params[:slides].split('-')
  raise "invalid requesst #{@params[:slides]}" if slides.size==0
  haml :graph_across_slides_select_samples, :locals => { :table_group_by_slide => $SET.rows_group.select{ |k,v| slides.include? k.to_s } }
end

# example : return { :link => '/graph/5', :success => false }.to_json()#
post '/graph-across-slides/:slides' do
  begin
    slides = @params[:slides].split('-')
    raise 'no sample cheched' if @params[:check].nil?
    rows_by_slide = @params[:check].map do |i|
      slide, lib_id = i.split('@') 
      rows = $SET.rows.select{|c| c.slide == slide}
      row = rows.select{|c| c.library_id == lib_id}[0]
    end.group_by{| row | row[:slide] }
    
    # prepare inputs
    inputs = rows_by_slide.map do |slide ,rows|
      ret = CheckResults.new( dir = File.join($SET.storage_root,slide) ).to_s_old( rows.map(&:library_id) )
    end.join("")
    File.open( File.join( $SET.root, 'log/_scriptlog' ), 'w' ){|f| f.write inputs }
    
    # make graph
    outpng = "tmp_#{slides.join('-')}_#{ Time.now().strftime('%Y%m%d-%H%M%S') }.png"  
    graphdir = File.join( $SET.root, 'public/graph' )
    FileUtils.mkdir_p graphdir
    Dir.chdir(graphdir) do
      so,se,status = Open3.capture3( "echo -n '#{inputs}' | python #{$SET.root}/etc/mk_graph/mk_graph.py #{$SET.root}/public/graph/#{ outpng }" )
      raise 'internal error : make png failed for some reason. stderr=[#{se}]?' unless File.exists?( File.join( "#{$SET.root}/public/graph", outpng ) )
    end
    
    return { :link => "/graph/#{outpng}", :success => true }.to_json

  rescue => e
    return { :success => false ,:msg => e.inspect }.to_json()
  end

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
def prepare_and_spawn(slide, checked, relaunch, prepare_only = false )
  
  if relaunch # if relaunch , check duplication of task; 
    raise "launched task and running task conflict at slide==#{slide}. Wait until the tasks finishes or uncheck 'for-relaunch' button " if TaskHgmd.tasks_find_by_slide(slide).where( :status => 'NotDone' ).to_a.size > 0
  end
  
  FileUtils.mkdir_p File.join( $SET.storage_root, slide ), { :mode => 0755 }
  raise 'Internal error' unless ( checked.is_a? Array and checked[0].is_a? NGS::Col)

  # grouped by prepkit
  group = checked.group_by { |col|
    $PREP.data.map(&:regex).find{ |reg| reg =~ col.prep_kit }
  }
  path_check = File.join($SET.root,"calc_dup/check_results.rb")

  threads = []
  # make run.sh for samplesdirs if not exists
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
  TaskHgmd.spawn( slide, checked.map(&:library_id), bashfile ) unless prepare_only
  return bashfile
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
