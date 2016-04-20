require 'sqlite3'

module TaskHgmd

  def self.open_db()
    return SQLite3::Database.open("tmp/tmp_tasklog.sqlite3")
  end

  def self.before(uuid)
    # make entry
  end   

  def self.spawn(bashfile, dir, uuid)
    before(uuid)

    bash_cmd = <<-EOS
    bash #{bashfile}
    ruby #{__FILE__} #{uuid}
    EOS

    pid = Process.spawn( cmd , :chdir => dir )
    Process.detach pid
  end

  def end(uuid)
    begin      
      db = open_db()   
      #todo error if entry does not exist   
      db.execute "update tasks set status = \"done\" where rowid = #{@row_id}"
    ensure
      db.close()
    end

  end
end

if __FILE__ == $0
    TaskHgmd.end(ARGV[0])
end