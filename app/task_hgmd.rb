require 'sqlite3'
require 'securerandom'
require 'yaml'
require 'sequel'

module TaskHgmd
  extend MyLog

  @@db_file = $SET.db_file
  raise "db_dile entry not exists in config file" if @@db_file.nil?
  @@db = Sequel.sqlite( @@db_file )
  # @@db.run '.timeout 3000;'

  @@tasks = @@db[:tasks]
  @@tasks.where(:status => 'NotDone' ).update(:status => 'Error' )

  def self.init_db()
    @@db.run <<-EOS
create table if not exists tasks(
pid int not null,
ppid int not null,
createat string not null,
status text not null,
uuid string not null,
args string
    )
    EOS
  end
  def self.tasks()
    @@tasks
  end

  def self.run_sql(str)
    return @@db[str]
  end

  def self.add_task(uuid, create, args )
    @@tasks.insert( {:pid => -1, :ppid => -1, :status => "NotDone", :createat => create, :uuid => uuid, :args => args.to_s} )
  end

  def self.set_pid(uuid, pid, ppid)
    @@tasks.where( :uuid => uuid ).update( {:pid => pid, :ppid => ppid } )
  end

  def self.done_task(uuid)
    @@tasks.where( :uuid => uuid ).update( :status => 'Done' )
  end
  def self.done_task_bash(uuid)
    cmd = <<-EOS
    sqlite3 #{@@db_file} 'UPDATE tasks SET status = \"Done\" WHERE uuid = \"#{uuid}\" '
    EOS
    `cmd`
  end

  def self.get_uuid(time)
    return ( time.strftime("%Y%m%d-%H%M%S") + "--" + SecureRandom.uuid )
  end
  # bashfile must be fullpath
  def self.spawn( slide, ids , bashfile, dir = File.join($SET.storage_root,slide) )
    time_now = Time.now
    time_str = time_now.strftime("%Y%m%d-%H_%M_%S%Z")
    uuid = get_uuid(time_now)

    init_db()
    args_str = [slide ,ids.join(',')].join(" ")
    add_task(uuid,time_str, args_str)
    File.open( File.join($SET.root, 'log/tasklog'), "a+" ){|f| f.puts "#{args_str}"}

    # http://dba.stackexchange.com/questions/47919/how-do-i-specify-a-timeout-in-sqlite3-from-the-command-line
    `mkdir -p #{dir}`
    File.open( bashfile , 'a') do |f|
      f.write <<EOS
### added by task_hgmd.rb
sqlite3 -init #{File.join($SET.root,"etc/set_timeout.sql")} #{@@db_file} 'UPDATE tasks SET status = \"Done\" WHERE uuid = \"#{uuid}\" '
exit 0
EOS

    end
    pid = Process.spawn( "bash #{bashfile} __uuid__=#{uuid}" , :chdir => dir, :pgroup=>nil,
                         [:out,:err]=>[ bashfile + '.log' , "w"] )
    set_pid(uuid, pid, Process.pid)
    Process.detach pid
    return pid
  end

end
