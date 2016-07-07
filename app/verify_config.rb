def verify_config(file)
  require 'yaml'
  c = YAML.load_file(file)

  for req in %w(root storage_root ngs_file db_file makefile_path prepkit_info)
    raise "missing elements #{req}" unless c[req]
  end

  prep = c['prepkit_info']
  raise 'err' unless prep.class == Array
  prep.each do |arr|
    #arr format == [ruby-regex, suffix, file-path(.bed file), target_base_number]
    #empty string permitted : suffix, file-path, target_base_number
    raise 'arr in arr format is not satisfied' unless arr.class == Array
    raise 'arr size is not 4' unless arr.size == 4

    reg, suffix, file, target_base = arr
    raise "empty regex: line = #{arr} " if reg == ''
    if file != ''
      raise "file not found #{file}" unless File.exists?(file)
    end
    if target_base.to_s != ''
      raise "not empty and not number <#{target_base}> in #{arr} " unless /\A[0-9]+\z/.match target_base.to_s
    end
  end

  STDERR.puts 'verify config ok'
  return true
end

if __FILE__ == $0
  f = (ARGV.size >= 1)? ARGV[0] : File.join( File.dirname(__FILE__), '../config.yml' )
  verify_config f
end
