class TaskSpawn

  def initialize()
    @pids = []
  end

  def spawn(command, options = {})
    #opt = {:pgroup => true}
    @pids << Kernel.spawn(command, options)
  end

  def pids()
    return @pids.clone
  end

  def waitany_nohang()
    delete_idx = nil
    ret = nil
    @pids.each_with_index do |p, idx|
      pid,status = Process.waitpid2(p, Process::WNOHANG)
      unless pid.nil?
        delete_idx = idx
        ret = [pid,status]
        break
      end
    end

    if delete_idx
      @pids.delete_at(delete_idx)
      return ret
    else
      # no task fininshed
      return nil
    end

  end 

end

if __FILE__ == $0
  manager = TaskSpawn.new
  manager.spawn("sleep 6")
  manager.spawn("sleep 3")
  exit
  sleep 20
  #exit 
  while manager.pids.size != 0
    sleep 1
    print "^"
    r = manager.waitany_nohang
    p r unless r.nil?
  end

end 