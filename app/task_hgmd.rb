require 'sqlite3'
require 'securerandom'
require 'yaml'

module TaskHgmd
  extend MyLog

  @@db_file = $SETTINGS.db_file
  raise "db_dile entry not exists in config file" if @@db_file.nil?

  def self.open_db()
    puts @@db_file
    `mkdir -p tmp`
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
pid int, 
status text,
uuid string,
args string
    )
    EOS
    db = open_db()
    db.execute sql      
    db.close()
  end 

  def self.add_task(uuid, args = nil)
    db = open_db
    db.execute <<-EOS
insert into tasks(pid, status, uuid, args)
values( -1, \"NotDone\", '#{uuid}', '#{args.to_s}' )
    EOS
    db.close
  end

  def self.set_pid(uuid, pid)
    db = open_db
    db.execute "update tasks set pid = \"#{pid}\" where uuid = \"#{uuid}\" "
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

  def self.spawn(bashfile, slide, ids , dir, uuid = Time.now.strftime("%Y%m%d-%H_%M_%S%Z") + "--" + SecureRandom.uuid )

    init_db()
    args_str = [slide ,ids.join(',')].join(" ")
    add_task(uuid, args_str)
    # http://dba.stackexchange.com/questions/47919/how-do-i-specify-a-timeout-in-sqlite3-from-the-command-line
    bash_cmd = <<-EOS
set -xv
bash #{bashfile} #{ args_str } #{bashfile}.out 2> #{bashfile}.err || exit 1
sqlite3 -init ./etc/set_timeout.sql #{@@db_file} 'UPDATE tasks SET status = \"Done\" WHERE uuid = \"#{uuid}\" '
# ruby #{$SETTINGS.root}/calc_dup/check_results.rb #{ids.join(',')}
exit 0
    EOS

    `mkdir -p ./log/tasks`
    
    File.open( File.join($SETTINGS.root, 'log/tasks/', "#{slide}__#{uuid}.bash") , 'w') do |f|
      f.write bash_cmd
    end

    `mkdir #{dir}`
    pid = Process.spawn( bash_cmd , :chdir => dir, :pgroup=>nil,
                         [:out,:err]=>[ File.join($SETTINGS.root,"log/tasks/", "#{slide}__#{uuid}" ), "w"] )
    set_pid(uuid, pid)
    Process.detach pid
    return pid
  end

end
