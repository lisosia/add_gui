require "yaml"

REQ = %w{root storage_root ngs_file db_file makefile_path prepkit_info}.map(&:to_sym)
FILES_INDEX = [0,1,2,3,4]

MyConfig = Struct.new("MyConfig", * REQ)

def load_config( file = File.expand_path("../../config.yml", __FILE__) )
  data = YAML.load_file(file)
  ret = MyConfig.new()
  REQ.map(&:to_s).each_with_index do |e, i|
    arg = data[e]
    raise "missing config element:#{e}" if arg.nil?
    if FILES_INDEX.include? i
      arg = File.expand_path(File.join("../", arg), file ) if /\A\.\// =~ arg
      raise "file not found #{arg}" unless File.exists? arg
    end
    ret.send( e + "=", arg )

  end

  return ret
end
