#!/bio/bin/ruby

require 'yaml'
require 'optparse'

require_relative '../app/prepkit.rb'
require_relative '../app/config.rb'
PREP = Prepkit.new( load_config().prepkit_info )

############### get args, todo: prefer _ than - in log opt

if __FILE__ == $0 

OPT = {}
opt = OptionParser.new
opt.on( '--library-ids V' , desc = "',' separeted id list" ){|v| OPT[:libids_raw] = v } # ex. 7381,7309_2
opt.on( '--run V', String ){|v| OPT[:run] = v } # slide ex. 256
opt.on( '--run-name V', String ){|v| OPT[:run_name] = v } # ex. 372813_sb38310_dsa23131sda
opt.on( '--suffix V' ){|v| OPT[:suffix] = v } # ex. SS5UTR
opt.on( '--storage V' ){|v| OPT[:storage] = v } # path
opt.on( '--path-check-result V' ){|v| OPT[:path_check] = v } # needed?
opt.on( '--path-makefile V' ){|v| OPT[:path_makefile] = v } # path

opt.parse!(ARGV)
for req in [:libids_raw, :run, :run_name, :suffix, :storage, :path_check, :path_makefile]
  unless OPT[req]
    raise "missing option; #{req}"
  end
end

run = OPT[:run]
run_name = OPT[:run_name]
suffix = OPT[:suffix]
libid_list = OPT[:libids_raw].split(/,/)
path_makefile = OPT[:path_makefile]
storage = OPT[:storage]
path_check = OPT[:path_check]

make_run_sh(run, run_name, suffix, libid_list, storage, path_makefile, path_check)
end

def make_run_sh(run, run_name, suffix, libid_list, storage, path_makefile, path_check)

run_dir = [ "/data/HiSeq2000/#{run_name}/Unaligned/" ]
prefix = 'Project_'
sample_names = ''
run_no=['PE001']
sure_pos = PREP.suffix2sure_pos( suffix )
rna_flag = (suffix == '_RNA')? true : false


###############

for sample in libid_list
  
  puts "SAMPLE: #{run}/#{sample}#{suffix}"
  sample_names += " #{sample}#{suffix}"
  
  genome_flag , genome = false, 'exome'
  genome_flag , genome = true, 'genome' if suffix == '_WG'
  genome = 'rna' if rna_flag

  run_pe , run_dir_pe = [] , []
  run_se , run_dir_se = [] , []
  
  ############### loop to push elements to RUN[_DIR]_[PS]E
  run_dir.each_with_index do |dir, i|
    for direc in Dir.glob( File.join( dir, "#{prefix}#{sample}*#{suffix}", "Sample_#{sample}*" ) )
      direc.chomp!
      unless Dir.exists? direc
        puts "Error; #{direc} was not found"
        next
      end
      if run_no[i].match /^PE/
        run_pe << run_no[i]
        run_dir_pe << direc
      else
        run_se << run_no[i]
        run_dir_se << direc
      end
    end
  end
  
  ### !!! ###
  sample += suffix

  fastq_dir = File.join( storage, run, sample, genome, 'fastq' )
  # `` system call -- exit if fail 
  # system() -- exit ruby proess if fail
  `mkdir -p #{fastq_dir}`
  
  fastq_pe = []
  ############### run_pe loop to make fastq_pe
  for pe, pe_dir in run_pe.zip(run_dir_pe)
    for fst in Dir.glob( File.join( pe_dir, "*.fastq.gz" ) )
      temp = File.basename( fst ).split("_")
      temp[4].gsub! /R/, ''
      temp[5].gsub! /.fastq.gz/, ''
      file_base = "#{sample}.#{pe}.#{temp[3]}_#{temp[5]}_#{temp[4]}"

      cmd = "ln -s #{fst} #{fastq_dir}/#{file_base}.fastq.gz"
      # STDERR.puts cmd
      `#{cmd}`

      if temp[4] == '1'
        fastq_pe << "#{sample}.#{pe}.#{temp[3]}_#{temp[5]}"
      end

    end
  end
  puts " --- #{fastq_pe}"
  fastq_pe = fastq_pe.join(" ")

  fastq_se = []
  ############### run_se loop to make fastq_se
  for se, se_dir in run_se.zip(run_dir_se)
    for fst in Dir.glob( File.join( se_dir, "*_R1_*.fastq.gz" ) )
      temp = File.basename( fst ).split("_")
      temp[4].gsub! /R/, ''
      temp[5].gsub! /.fastq.gz/, ''
      file_base = "#{sample}.#{se}.#{temp[3]}_#{temp[5]}_#{temp[4]}"

      cmd = "ln -s #{fst} #{fastq_dir}/#{file_base}.fastq.gz"
      # print cmd
      `#{cmd}`

      if temp[4] == '1'
        fastq_se << "#{sample}.#{se}.#{temp[3]}_#{temp[5]}"
      end

    end
  end
  fastq_se = fastq_se.join(" ")

  ############### make run.sh in each sample dir
  if ! rna_flag
    thread = `gxpc e hostname | wc -l`.gsub(/\n/, '')
    `mkdir -p #{File.join( storage, run, sample)}`
    run_file = File.join( storage, run, sample, 'run.sh' )
    File.open(run_file, "w") do |f|
      f.write "gxpc make -k -j #{thread} -f #{path_makefile} "
      f.write "SAMPLE=#{sample} PE_READS=\"#{fastq_pe}\" SE_READS=\"#{fastq_se}\" "
      f.write "SURE_POS=#{sure_pos}"
      f.write " TARGET=genome" if genome_flag;
      f.write "\n";
    end

  end

end ########## END OF MAIN LOOP ; for sample in libids
end # end of function



########## make run script <auto_run_SUFFIX.sh>
def make_auto_run_sh_core( path_check, rna_flag)
  if ! rna_flag
    return <<EOS
\tcd $BASE_DIR/$DIR && date >> make.log && (time sh run.sh) >> make.log 2>> make.log
\tcd $BASE_DIR/ && ruby -W0 #{path_check} $DIR >> check_results.log 2>> check_results.log
EOS
  else <<EOS
\tqsub -sync y -N RNA-$DIR -o $DIR/make.log -j y /work/HiSeq2000/BaseCall/qsub_rna.sh $DIR
EOS
  end
end

def make_auto_run_sh(storage, slide,  group_by_prep,  path_check)

  run_script = File.join( storage, slide, "auto_run.#{Time.now().strftime("%Y%m%d-%H%M%S")}.sh" )
  File.open( run_script, 'w' ) do |f|
    f.write <<EOS
#!/usr/bin/env bash
BASE_DIR=#{File.join(storage,slide)}
EOS
    for regex, rows in group_by_prep
      suffix = $PREP.get_suffix( rows[0].prep_kit )
      rna_flag = (  /RNA/ =~ regex.to_s )? true : false
      # STDERR.puts '---rna_flag---', rna_flag
      f.write <<EOS
for DIR in #{ rows.map{|e| e.library_id + suffix }.join(" ") }
do
echo $DIR
EOS
      f.puts make_auto_run_sh_core( path_check, rna_flag )
      f.puts 'done'
    end
  end
  return run_script
end

