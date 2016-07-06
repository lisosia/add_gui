class TaskSpawn

  def initialize()
    @pids = {}
  end

  #def spawn(command, options = {})
  #  #opt = {:pgroup => true}
  #  @pids << Kernel.spawn(command, options)
  #end

  def spawn_task(task, spawn_opts ={})    
    task.before() if task.respond_to?(:before)
    pid = Kernel.spawn(task.command() , spawn_opts)
    raise "pid crash" if @pids[pid]
    @pids[ pid ] = task
    task.after_spawn(pid) if task.respond_to?(:after_spawn)
    # task.after()  if task.respond_to?(:after)
  end

  def pids()
    return @pids.clone
  end

  def waitany_nohang()
    delete_key, task = nil,nil
    ret = nil
    @pids.each do |p, t|
      pid,status = Process.waitpid2(p, Process::WNOHANG)
      unless pid.nil?
        delete_key = p
        task = t
        ret = [pid,status]
        break
      end
    end

    if delete_key
      @pids[delete_key].end() if task.respond_to?(:end)
      @pids.delete delete_key      
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
