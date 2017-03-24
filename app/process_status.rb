require_relative 'concurrent_hash.rb'

module ProcessStatus
  
  PROCESSING = 'processing'
  DONE = 'done'
  ERROR = 'error'

  @@d = ConcurrentHash.new()
  def self.all_status()
    self.constants.map{|name| self.const_get(name) }
  end
  
  def self.put( uuid, status, msg = '', expire = nil )
    @@d[ uuid ] ||= []
    @@d[ uuid ] << Status.new( status, msg, expire )
  end

  def self.get( uuid )
    r = @@d[ uuid ]
    r.nil? ? nil : r[-1] #return last
  end

  def self.delete( uuid)
    @@d.delete(uuid)
  end

  def self.expire()
    time = Time.now()
    to_del = []
    for k,v in @@d
      last_mod = v[-1]
      to_del << k if time > ( last_mod.expire_time() )
    end
    for k in to_del
      @@d.delete( k )
    end
    return to_del
  end

  def self.all_data
    return @@d
  end

  def self.delete( uuid )
    @@d.delete( uuid )
  end
  
  
  class Status
    DEFAULT_EXPIRE_SEC = 60 * 60

    attr_reader :status, :msg, :created_at, :expire
    
    def initialize( status, msg, ttl )
      raise unless ProcessStatus.all_status().include? status
      @status = status
      @msg = msg
      @created_at = Time.now
      @ttl = ttl
      @ttl ||= DEFAULT_EXPIRE_SEC
    end

    def expire_time
      @created_at + @ttl
    end

    def end?
      @status == DONE or @status == ERROR
    end

  end
  
end

# test
if __FILE__ == $0
  ProcessStatus.put 'a',  ProcessStatus::PROCESSING, msg='a1'
  sleep 1.5
  ProcessStatus.put 'a',  ProcessStatus::DONE, msg='a2', expire = 30
  ProcessStatus.put 'b',  ProcessStatus::PROCESSING, msg='b1'
  sleep 1
  ProcessStatus.put 'b',  ProcessStatus::ERROR, msg='b2', expire = 10

  for i in 1..20
    p ''
    p Time.now
    p ProcessStatus.all_data()
    p ProcessStatus.expire()
    sleep 3
  end  
  
end
