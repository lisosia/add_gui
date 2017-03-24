require 'thread'

class ConcurrentHash < Hash
  def initialize
    super
    @mutex = Mutex.new()
  end
  def [](*args)
    @mutex.synchronize{ super }
  end
  def []=(*args)
    @mutex.synchronize{ super }
  end
end
