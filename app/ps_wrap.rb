module PsWrap
  FORMAT = %w[user pid ppid pgid command]
  UnixProcess = Struct.new("UnixProcess", * FORMAT.map(&:to_sym))

  def self.all()
    `ps axo #{FORMAT.join(',')}`.split("\n").map do |line|
      UnixProcess.new( * line.split( pattern = nil ,limit = FORMAT.size) )
    end
  end

  def self.command( reg )
    raise 'not regex #{regex}' unless reg.is_a? Regexp

    `ps axo #{FORMAT.join(',')}`.split("\n").map do |line|
      UnixProcess.new( * line.split( pattern = nil ,limit = FORMAT.size) )
    end.select do |e|
      reg =~ e.command
    end
  end

end

