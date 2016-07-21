module PreventDup
  def self.run(hist_file)
    d = self.dup?(hist_file)
    raise "duplicate process; pgid = #{d}" if d
    File.open(hist_file, "a+") do |f|
      f.puts Process.pid.to_s
    end
  end

  private

  def self.get_last(hist_file)
    last = nil
    File.open(hist_file, "r+") do |f|
      f.readlines.each do |l|
        l.chomp!
        next if l.empty?
        raise "invalid hist_file<#{hist_file}> not int #{l.inspect}" unless /\A[1-9]\d*\z/ =~ l
        last = l.to_i
      end
    end
    return last # nil or num
  end

  def self.dup?(f)
    last = get_last(f)
    return false if last.nil?
    now = Process.pid
    return false if last == now # same pid
    procs = `ps axo "pgid=" | grep #{last}`.split("\n").size()
    return false if procs == 0
    return last
  end

end
