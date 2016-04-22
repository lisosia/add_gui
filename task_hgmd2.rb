require 'sqlite3'
require 'securerandom'
require 'yaml'

module TaskHgmd

  @@db_file = YAML.load_file("config.yml")["db_file"]
  
  def self.open_db()
    puts @@db_file
    `mkdir -p tmp`
    return SQLite3::Database.open(@@db_file)
  end

  def run_sql(sql)
    db = open_db
    db.execute(sql)
    db.close
  end

  def self.init_db()
    sql = <<-EOS
    create table if not exists tasks(
    pid int, 
    status text,
    uuid string
    )
    EOS
    db = open_db()
    db.execute sql      
    db.close()
  end 

  def self.add_task(uuid)
    db = open_db
    db.execute <<-EOS
insert into tasks(pid, status, uuid)
values( -1, \"NotDone\", \"#{uuid}\" )
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

  def self.spawn(bashfile, dir, uuid = Time.now.strftime("%Y%m%d-%H_%M_%S%Z") + "--" + SecureRandom.uuid )
    init_db()
    add_task(uuid)
    # http://dba.stackexchange.com/questions/47919/how-do-i-specify-a-timeout-in-sqlite3-from-the-command-line
    bash_cmd = <<-EOS
bash #{bashfile} || exit 1
sqlite3 -init ./etc/set_timeout.sql #{@@db_file} 'UPDATE tasks SET status = \"Done\" WHERE uuid = \"#{uuid}\" '
exit 0
    EOS
    pid = Process.spawn( bash_cmd , :chdir => dir, :pgroup=>nil,
      [:out,:err]=>[ File.join("./log", uuid ), "w"] )
    set_pid(uuid, pid)
    Process.detach pid
  end

end
