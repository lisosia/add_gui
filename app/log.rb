require 'logger'

module MyLog
  def self.mylog()
    # @@logger ||= Logger.new("./log/app.log")  	
    @@logger ||= Logger.new File.join( $SETTINGS.root, "./log/app.log" )
  end
  def mylog()
  	MyLog.mylog()
  end  
end
