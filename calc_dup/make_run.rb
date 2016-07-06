#!/bio/bin/ruby

require 'yaml'

# $conf = [ [suffix1, target_bases1], [suffix2, target_bases2], ...  ]
$conf = YAML.load_file( File.join( File.dirname(__FILE__) , '../config.yml' ) )['prepkit_info']
  .map{|arr| [ arr[1], arr[2] ] }
  .select{|suf, sure_pos_file| sure_pos_file != ''  }

def get_sure_pos(suffix)
  ret = $conf.select{|suf, sure| suffix.match /#{suf}/ }
  if ret.length != 0
    return ret.first[1]
  else
    return nil
  end
end

