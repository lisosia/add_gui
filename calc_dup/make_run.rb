#!/bio/bin/ruby

require 'yaml'
require 'optparse'

require_relative '../app/prepkit.rb'
require_relative '../app/myconfig.rb'
PREP = Prepkit.new( MyConfig.new().prepkit_info )

############### get args, todo: prefer _ than - in log opt

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
RUN_DIR = [ "/data/HiSeq2000/#{run_name}/Unaligned/" ]
PREFIX = 'Project_'
sample_names = ''
RUN_NO=['PE001']
sure_pos = PREP.suffix2sure_pos( OPT[:suffix] )
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
  RUN_DIR.each_with_index do |dir, i|
    for direc in Dir.glob( File.join( dir, "#{PREFIX}#{sample}*#{suffix}", "Sample_#{sample}*" ) )
      direc.chomp!
      unless Dir.exists? direc
        puts "Error; #{direc} was not found"
        next
      end
      if RUN_NO[i].match /^PE/
        run_pe << RUN_NO[i]
        run_dir_pe << direc
      else
        run_se << RUN_NO[i]
        run_dir_se << direc
      end
    end
  end
  
  ### !!! ###
  sample += suffix

  FASTQ_DIR ||= File.join( run, sample, genome, 'fastq' )
  # `` system call -- exit if fail 
  # system() -- exit ruby proess if fail
  `mkdir -p #{FASTQ_DIR}`
  
  fastq_pe = []
  ############### run_pe loop to make fastq_pe
  for pe, pe_dir in run_pe.zip(run_dir_pe)
    for fst in Dir.glob( File.join( pe_dir, "*.fastq.gz" ) )
      temp = File.basename( fst ).split("_")
      temp[4].gsub! /R/, ''
      temp[5].gsub! /.fastq.gz/, ''
      file_base = "#{sample}.#{pe}.#{temp[3]}_#{temp[5]}_#{temp[4]}"

      cmd = "ln -s #{fst} #{FASTQ_DIR}/#{file_base}.fastq.gz"
      # print cmd
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
      
      cmd = "ln -s #{fst} #{FASTQ_DIR}/#{file_base}.fastq.gz"
      # print cmd
      `#{cmd}`

      if temp[4] == '1'
        fastq_se << "#{sample}.#{se}.#{temp[3]}_#{temp[5]}"
      end

    end
  end
  fastq_se = fastq_se.join(" ")

  ############### make run.sh
  if ! rna_flag
    thread = `gxpc e hostname | wc -l`.gsub(/\n/, '')
    run_file = File.join( run, sample, 'run.sh' )
    File.open(run_file, "w+") do |f|
      f.write "gxpc make -k -j #{thread} -f #{path_makefile} "
      f.write "SAMPLE=#{sample} PE_READS=\"#{fastq_pe}\" SE_READS=\"#{fastq_se}\" "
      f.write "SURE_POS=#{sure_pos}"
      f.write " TARGET=genome" if genome_flag;
      f.write "\n";
    end
    
  end
  

end ########## END OF MAIN LOOP ; for sample in libids



########## make run script <auto_run_SUFFIX.sh>

RUN_SCRIPT = File.join( run, "auto_run#{suffix}.sh" )
File.open( RUN_SCRIPT, 'w+' ) do |f|
  f.write <<EOS
#!/usr/bin/env bash

BASE_DIR=#{OPT[:storage]}
for DIR in #{ libid_list.map{|s| s + suffix}.join(" ") }
do
echo $DIR
EOS

  if ! rna_flag
    f.write <<EOS
\tcd $BASE_DIR/$DIR && date >> make.log && (time sh run.sh) >> make.log 2>> make.log
\tcd $BASE_DIR/ && #{OPT[:path_check]} $DIR >> check_results.log 2>> check_results.log
EOS
  else
    f.puts "\tqsub -N RNA-$DIR -o $DIR/make.log -j y /work/HiSeq2000/BaseCall/qsub_rna.sh $DIR"
  end

  f.puts 'done'
  f.puts 'exit 0'
end
