require 'sqlite3'
require 'securerandom'
require 'yaml'

module TaskHgmd
  extend MyLog

  @@db_file = $SET.db_file
  raise "db_dile entry not exists in config file" if @@db_file.nil?

  def self.open_db()
    db = SQLite3::Database.open(@@db_file)
    db.busy_timeout 3000
    return db
  end

  def self.run_sql(sql)
    db = open_db
    ret = db.execute(sql)
    db.close
    return ret
  end

  def self.init_db()
    sql = <<-EOS
create table if not exists tasks(
pid int not null,
ppid int not null,
createat string not null,
status text not null,
uuid string not null,
args string
    )
    EOS
    db = open_db()
    db.execute sql
    db.close()
  end

  def self.add_task(uuid, create, args )
    db = open_db
    db.execute <<-EOS
insert into tasks(pid,ppid, status, createat, uuid, args)
values( -1, -1, \"NotDone\", '#{create}', '#{uuid}', '#{args.to_s}' )
    EOS
    db.close
  end

  def self.set_pid(uuid, pid, ppid)
    db = open_db
    db.execute "update tasks set pid = \"#{pid}\", ppid = \"#{ppid}\" where uuid = \"#{uuid}\" "
    db.close
  end

  def self.done_task(uuid)
    db = open_db
    db.execute "UPDATE tasks SET status = \"Done\" WHERE uuid = \"#{uuid}\" "
    db.close
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
