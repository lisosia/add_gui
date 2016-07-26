require 'yaml'

class MyConfig < Object

  instance_methods.each do |m|
    undef_method(m) unless (m.match(/^__/)) or m == :object_id
  end

  def initialize(yaml_file = File.expand_path("../../config.yml" , __FILE__) )
    @data = YAML.load_file(yaml_file)
    raise '"object_id" cannot be used as root variable' if @data.include?('object_id') or @data.include?(:object_id)
  end

  def method_missing(method, *args)
    # method is a Symbol
    s = method.to_s
    if @data.include? method
      return @data[method]
    elsif @data.include? s
      return @data[s]
    end
    raise NameError.new("undefined name in config: #{method}")
  end

end
