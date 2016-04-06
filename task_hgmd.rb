require 'sqlite3'

class TaskHgmd  
  def initialize(args)
    @args = args
  end

  def open_db()
    return SQLite3::Database.open("tmp/tmp_tasklog.sqlite3")
  end

  def before()

  end

  def command()
    return "sleep 10"
  end

  def after_spawn(pid)  
    begin
      db = open_db()      
      db.execute "create table if not exists tasks(pid int, status text)"
      db.transaction
      db.execute "insert into tasks values(#{pid}, \"not done\" )"
      @row_id = ( db.execute "select last_insert_rowid()" ).flatten()[0]
      db.commit
    ensure
      db.close()
    end
  end

  def end()
    begin      
      db = open_db()      
      db.execute "update tasks set status = \"done\" where rowid = #{@row_id}"
    ensure
      db.close()
    end

  end
end
