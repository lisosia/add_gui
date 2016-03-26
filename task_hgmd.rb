require 'sqlite3'

class TaskHgmd  
  def initialize(args)
    @args = args
  end

  def before()
    begin      
      db = SQLite3::Database.open("tmp_tasklog.sqlite3")
      db.execute "create table if not exists tasks(num int, status text)"
      db.transaction
      db.execute "insert into tasks values(#{Random.rand 1000}, \"not done\" )"
      @row_id = ( db.execute "select last_insert_rowid()" ).flatten()[0]
      db.commit
    ensure
      db.close()
    end

  end
  def command()
    return "sleep 10"
  end
  def after()
    begin      
      db = SQLite3::Database.open("tmp_tasklog.sqlite3")
      db.execute "update tasks set status = \"done\" where rowid = #{@row_id}"
    ensure
      db.close()
    end

  end
end
