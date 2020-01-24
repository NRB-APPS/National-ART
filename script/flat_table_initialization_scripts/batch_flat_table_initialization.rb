require 'yaml'

if ARGV[0].nil?
  raise "Please include the environment that you would like to choose. Either development or production"
else
  @environment = ARGV[0]
end

def initialize_variables
  # initializes the different variables required for the
  # flat table initalization process
  @source_db = YAML.load(File.open(File.join(RAILS_ROOT, "config/database.yml"), "r"))["#{@environment}"]["database"]
  @started_at = Time.now.strftime("%Y-%m-%d-%H%M%S")
  @drug_list = get_drug_list
  @max_dispensing_enc_date = Encounter.find_by_sql("SELECT DATE(max(encounter_datetime)) AS adate
                                                    FROM #{@source_db}.encounter
                                                    WHERE encounter_type = 54
                                                    AND voided = 0").map(&:adate)

  $guardians = []
  $guardians = Patient.find_by_sql("SELECT patient_id, guardian_id FROM guardians")

  $patient_demographics = []
  $patient_demographics = Patient.find_by_sql("SELECT * FROM #{@source_db}.patients_demographics").each{|pat| pat}

  $patient_identifiers = []
  $patient_identifiers =  Patient.find_by_sql("SELECT * FROM #{@source_db}.all_patient_identifiers").each{|patient| patient}

  $patient_attributes = []
  $patient_attributes = Patient.find_by_sql("SELECT * FROM #{@source_db}.all_patients_attributes").each{|patient| patient}
end

def pre_export_check
  #to contain checks before starting the process of initialization
end

def initiate_special_script
    puts "started at #{@started_at}"

    threads = []
    patients = Patient.find_by_sql("SELECT max(patient_id) as max_patient_id, count(*) record_count FROM #{@source_db}.patients_demographics")

    record_count = patients.first.record_count
    max_patient_id = patients.first.max_patient_id
    thresholds = generate_thresholds(record_count, max_patient_id)

    count = 0
      thresholds.each do |threshold|
        threads << Thread.new(count) do |i|
          count += 1
          get_all_patients(threshold[0], threshold[1], count)
        end
      end

    threads.each {|t| t.join}

    puts "ended at #{Time.now.strftime("%Y-%m-%d-%H%M%S")}"
end

def initiate_special_script(patients_list)
    puts "started at #{@started_at}"

    threads = []
    record_count = patients_list.length
    if record_count < 250
        thread_number = 1
    else
	thread_number = 10
    end

    start_element = 0
    end_element = record_count / thread_number
    block = record_count / thread_number
    count = 0
    thread_number.times do
        threads << Thread.new(count) do |i|
	  count += 1
          get_specific_patients(patients_list[start_element..end_element], count)
        end

	start_element = end_element + 1

	if count == 9
		end_element = (record_count - 1)
	else
		end_element = end_element + block
	end
      end

    threads.each {|t| t.join}

    puts "ended at #{Time.now.strftime("%Y-%m-%d-%H%M%S")}"
end

def initiate_script
    puts "started at #{@started_at}"

    threads = []
    patients = Patient.find_by_sql("SELECT max(patient_id) as max_patient_id, count(*) record_count FROM #{@source_db}.patients_demographics")
    record_count = patients.first.record_count
    max_patient_id = patients.first.max_patient_id
    thresholds = generate_thresholds(record_count, max_patient_id)

    count = 0
      (thresholds || []).each do |threshold|
        threads << Thread.new(count) do |i|
          count += 1
          get_all_patients(threshold[0], threshold[1], count)
        end
      end

    threads.each {|t| t.join}

    puts "ended at #{Time.now.strftime("%Y-%m-%d-%H%M%S")}"
end

def generate_thresholds(records, patient_id)
   number_iterations = patient_id.to_i / records.to_i

   if number_iterations > 10
       number_iterations = 10
   elsif number_iterations < 5
       number_iterations = 5
   end

   threshold = (patient_id.to_i + (number_iterations * 2)) / number_iterations.to_i
   threshold_array = []

   count = 0
   number_iterations.times do
	if count == 0
	   item = ["1", "#{threshold}"]
	else
	   last_item_index = threshold_array.length - 1
	   if (count + 1) == number_iterations
		   item = ["#{(threshold_array[last_item_index][1].to_i + 1)}","#{patient_id}"]
	   else
        	   item = ["#{(threshold_array[last_item_index][1].to_i + 1)}","#{(threshold_array[last_item_index][1].to_i + threshold.to_i)}"]
	   end
	end
	threshold_array << item
	count += 1
   end

   return threshold_array
end

def get_all_patients(min, max, thread)
    puts "thread #{thread} started at #{Time.now.strftime("%Y-%m-%d-%H%M%S")} for ids #{min} to #{max}"
    min_patient_id = min
    max_patient_id = max
    #open output files for writing
    if thread == 1
      $temp_outfile_1_1 = File.open("./db/flat_tables_init_output/flat_table_1-" + @started_at + "thread_#{thread}" + ".sql", "w")
      $temp_outfile_1_2 = File.open("./db/flat_tables_init_output/flat_table_2-" + @started_at + "thread_#{thread}" + ".sql", "w")
      $temp_outfile_1_3 = File.open("./db/flat_tables_init_output/patients_initialized-" + @started_at + "thread_#{thread}" + ".sql", "w")
    elsif thread == 2
      $temp_outfile_2_1 = File.open("./db/flat_tables_init_output/flat_table_1-" + @started_at + "thread_#{thread}" + ".sql", "w")
      $temp_outfile_2_2 = File.open("./db/flat_tables_init_output/flat_table_2-" + @started_at + "thread_#{thread}" + ".sql", "w")
      $temp_outfile_2_3 = File.open("./db/flat_tables_init_output/patients_initialized-" + @started_at + "thread_#{thread}" + ".sql", "w")
    elsif thread == 3
      $temp_outfile_3_1 = File.open("./db/flat_tables_init_output/flat_table_1-" + @started_at + "thread_#{thread}" + ".sql", "w")
      $temp_outfile_3_2 = File.open("./db/flat_tables_init_output/flat_table_2-" + @started_at + "thread_#{thread}" + ".sql", "w")
      $temp_outfile_3_3 = File.open("./db/flat_tables_init_output/patients_initialized-" + @started_at + "thread_#{thread}" + ".sql", "w")
    elsif thread == 4
      $temp_outfile_4_1 = File.open("./db/flat_tables_init_output/flat_table_1-" + @started_at + "thread_#{thread}" + ".sql", "w")
      $temp_outfile_4_2 = File.open("./db/flat_tables_init_output/flat_table_2-" + @started_at + "thread_#{thread}" + ".sql", "w")
      $temp_outfile_4_3 = File.open("./db/flat_tables_init_output/patients_initialized-" + @started_at + "thread_#{thread}" + ".sql", "w")
    elsif thread == 5
      $temp_outfile_5_1 = File.open("./db/flat_tables_init_output/flat_table_1-" + @started_at + "thread_#{thread}" + ".sql", "w")
      $temp_outfile_5_2 = File.open("./db/flat_tables_init_output/flat_table_2-" + @started_at + "thread_#{thread}" + ".sql", "w")
      $temp_outfile_5_3 = File.open("./db/flat_tables_init_output/patients_initialized-" + @started_at + "thread_#{thread}" + ".sql", "w")
    elsif thread == 6
      $temp_outfile_6_1 = File.open("./db/flat_tables_init_output/flat_table_1-" + @started_at + "thread_#{thread}" + ".sql", "w")
      $temp_outfile_6_2 = File.open("./db/flat_tables_init_output/flat_table_2-" + @started_at + "thread_#{thread}" + ".sql", "w")
      $temp_outfile_6_3 = File.open("./db/flat_tables_init_output/patients_initialized-" + @started_at + "thread_#{thread}" + ".sql", "w")
    elsif thread == 7
      $temp_outfile_7_1 = File.open("./db/flat_tables_init_output/flat_table_1-" + @started_at + "thread_#{thread}" + ".sql", "w")
      $temp_outfile_7_2 = File.open("./db/flat_tables_init_output/flat_table_2-" + @started_at + "thread_#{thread}" + ".sql", "w")
      $temp_outfile_7_3 = File.open("./db/flat_tables_init_output/patients_initialized-" + @started_at + "thread_#{thread}" + ".sql", "w")
    elsif thread == 8
      $temp_outfile_8_1 = File.open("./db/flat_tables_init_output/flat_table_1-" + @started_at + "thread_#{thread}" + ".sql", "w")
      $temp_outfile_8_2 = File.open("./db/flat_tables_init_output/flat_table_2-" + @started_at + "thread_#{thread}" + ".sql", "w")
      $temp_outfile_8_3 = File.open("./db/flat_tables_init_output/patients_initialized-" + @started_at + "thread_#{thread}" + ".sql", "w")
    elsif thread == 9
      $temp_outfile_9_1 = File.open("./db/flat_tables_init_output/flat_table_1-" + @started_at + "thread_#{thread}" + ".sql", "w")
      $temp_outfile_9_2 = File.open("./db/flat_tables_init_output/flat_table_2-" + @started_at + "thread_#{thread}" + ".sql", "w")
      $temp_outfile_9_3 = File.open("./db/flat_tables_init_output/patients_initialized-" + @started_at + "thread_#{thread}" + ".sql", "w")
    elsif thread == 10
      $temp_outfile_10_1 = File.open("./db/flat_tables_init_output/flat_table_1-" + @started_at + "thread_#{thread}" + ".sql", "w")
      $temp_outfile_10_2 = File.open("./db/flat_tables_init_output/flat_table_2-" + @started_at + "thread_#{thread}" + ".sql", "w")
      $temp_outfile_10_3 = File.open("./db/flat_tables_init_output/patients_initialized-" + @started_at + "thread_#{thread}" + ".sql", "w")
    end

    patient_list = Patient.find_by_sql("SELECT patient_id
                                        FROM #{@source_db}.patients_demographics
                                        WHERE patient_id >= #{min_patient_id}
                                        AND patient_id <= #{max_patient_id}").map(&:patient_id)

    (patient_list || []).each do |p|
	puts ">>working on patient>>>#{p}<<<<<<<"
	    sql_statements = get_patients_data(p)

      if thread == 1
  	$temp_outfile_1_3 << "#{p},"
      	$temp_outfile_1_1 << sql_statements[0]
      	$temp_outfile_1_2 << sql_statements[1]
      elsif thread == 2
        $temp_outfile_2_3 << "#{p},"
        $temp_outfile_2_1 << sql_statements[0]
        $temp_outfile_2_2 << sql_statements[1]
      elsif thread == 3
        $temp_outfile_3_3 << "#{p},"
        $temp_outfile_3_1 << sql_statements[0]
        $temp_outfile_3_2 << sql_statements[1]
      elsif thread == 4
        $temp_outfile_4_3 << "#{p},"
        $temp_outfile_4_1 << sql_statements[0]
        $temp_outfile_4_2 << sql_statements[1]
      elsif thread == 5
        $temp_outfile_5_3 << "#{p},"
        $temp_outfile_5_1 << sql_statements[0]
        $temp_outfile_5_2 << sql_statements[1]
      elsif thread == 6
        $temp_outfile_6_3 << "#{p},"
        $temp_outfile_6_1 << sql_statements[0]
        $temp_outfile_6_2 << sql_statements[1]
      elsif thread == 7
        $temp_outfile_7_3 << "#{p},"
        $temp_outfile_7_1 << sql_statements[0]
        $temp_outfile_7_2 << sql_statements[1]
      elsif thread == 8
        $temp_outfile_8_3 << "#{p},"
        $temp_outfile_8_1 << sql_statements[0]
        $temp_outfile_8_2 << sql_statements[1]
      elsif thread == 9
        $temp_outfile_9_3 << "#{p},"
        $temp_outfile_9_1 << sql_statements[0]
        $temp_outfile_9_2 << sql_statements[1]
      elsif thread == 10
        $temp_outfile_10_3 << "#{p},"
        $temp_outfile_10_1 << sql_statements[0]
        $temp_outfile_10_2 << sql_statements[1]
      end
    puts ">>Finished working on patient>>>#{p}<<<<<<<"
    end

    #close output files
    if thread == 1
      $temp_outfile_1_3.close
      $temp_outfile_1_1.close
      $temp_outfile_1_2.close
    elsif thread == 2
      $temp_outfile_2_3.close
      $temp_outfile_2_1.close
      $temp_outfile_2_2.close
    elsif thread == 3
      $temp_outfile_3_3.close
      $temp_outfile_3_1.close
      $temp_outfile_3_2.close
    elsif thread == 4
      $temp_outfile_4_3.close
      $temp_outfile_4_1.close
      $temp_outfile_4_2.close
    elsif thread == 5
      $temp_outfile_5_3.close
      $temp_outfile_5_1.close
      $temp_outfile_5_2.close
    elsif thread == 6
      $temp_outfile_6_3.close
      $temp_outfile_6_1.close
      $temp_outfile_6_2.close
    elsif thread == 7
      $temp_outfile_7_3.close
      $temp_outfile_7_1.close
      $temp_outfile_7_2.close
    elsif thread == 8
      $temp_outfile_8_3.close
      $temp_outfile_8_1.close
      $temp_outfile_8_2.close
    elsif thread == 9
      $temp_outfile_9_3.close
      $temp_outfile_9_1.close
      $temp_outfile_9_2.close
    elsif thread == 10
      $temp_outfile_10_3.close
      $temp_outfile_10_1.close
      $temp_outfile_10_2.close
    end

    puts "thread #{thread} ended at #{Time.now.strftime("%Y-%m-%d-%H%M%S")} for ids #{min} to #{max}"

end

def get_specific_patients(patients_list, thread)
    last_element = (patients_list.length - 1)
    puts "thread #{thread} started at #{Time.now.strftime("%Y-%m-%d-%H%M%S")} Patients from >>#{patients_list[0]}<< to >>#{patients_list[last_element]}<< "

    #open output files for writing
    if thread == 1
      $temp_outfile_1_1 = File.open("./db/flat_tables_init_output/flat_table_1-" + @started_at + "thread_#{thread}" + ".sql", "w")
      $temp_outfile_1_2 = File.open("./db/flat_tables_init_output/flat_table_2-" + @started_at + "thread_#{thread}" + ".sql", "w")
      $temp_outfile_1_3 = File.open("./db/flat_tables_init_output/patients_initialized-" + @started_at + "thread_#{thread}" + ".sql", "w")
    elsif thread == 2
      $temp_outfile_2_1 = File.open("./db/flat_tables_init_output/flat_table_1-" + @started_at + "thread_#{thread}" + ".sql", "w")
      $temp_outfile_2_2 = File.open("./db/flat_tables_init_output/flat_table_2-" + @started_at + "thread_#{thread}" + ".sql", "w")
      $temp_outfile_2_3 = File.open("./db/flat_tables_init_output/patients_initialized-" + @started_at + "thread_#{thread}" + ".sql", "w")
    elsif thread == 3
      $temp_outfile_3_1 = File.open("./db/flat_tables_init_output/flat_table_1-" + @started_at + "thread_#{thread}" + ".sql", "w")
      $temp_outfile_3_2 = File.open("./db/flat_tables_init_output/flat_table_2-" + @started_at + "thread_#{thread}" + ".sql", "w")
      $temp_outfile_3_3 = File.open("./db/flat_tables_init_output/patients_initialized-" + @started_at + "thread_#{thread}" + ".sql", "w")
    elsif thread == 4
      $temp_outfile_4_1 = File.open("./db/flat_tables_init_output/flat_table_1-" + @started_at + "thread_#{thread}" + ".sql", "w")
      $temp_outfile_4_2 = File.open("./db/flat_tables_init_output/flat_table_2-" + @started_at + "thread_#{thread}" + ".sql", "w")
      $temp_outfile_4_3 = File.open("./db/flat_tables_init_output/patients_initialized-" + @started_at + "thread_#{thread}" + ".sql", "w")
    elsif thread == 5
      $temp_outfile_5_1 = File.open("./db/flat_tables_init_output/flat_table_1-" + @started_at + "thread_#{thread}" + ".sql", "w")
      $temp_outfile_5_2 = File.open("./db/flat_tables_init_output/flat_table_2-" + @started_at + "thread_#{thread}" + ".sql", "w")
      $temp_outfile_5_3 = File.open("./db/flat_tables_init_output/patients_initialized-" + @started_at + "thread_#{thread}" + ".sql", "w")
    elsif thread == 6
      $temp_outfile_6_1 = File.open("./db/flat_tables_init_output/flat_table_1-" + @started_at + "thread_#{thread}" + ".sql", "w")
      $temp_outfile_6_2 = File.open("./db/flat_tables_init_output/flat_table_2-" + @started_at + "thread_#{thread}" + ".sql", "w")
      $temp_outfile_6_3 = File.open("./db/flat_tables_init_output/patients_initialized-" + @started_at + "thread_#{thread}" + ".sql", "w")
    elsif thread == 7
      $temp_outfile_7_1 = File.open("./db/flat_tables_init_output/flat_table_1-" + @started_at + "thread_#{thread}" + ".sql", "w")
      $temp_outfile_7_2 = File.open("./db/flat_tables_init_output/flat_table_2-" + @started_at + "thread_#{thread}" + ".sql", "w")
      $temp_outfile_7_3 = File.open("./db/flat_tables_init_output/patients_initialized-" + @started_at + "thread_#{thread}" + ".sql", "w")
    elsif thread == 8
      $temp_outfile_8_1 = File.open("./db/flat_tables_init_output/flat_table_1-" + @started_at + "thread_#{thread}" + ".sql", "w")
      $temp_outfile_8_2 = File.open("./db/flat_tables_init_output/flat_table_2-" + @started_at + "thread_#{thread}" + ".sql", "w")
      $temp_outfile_8_3 = File.open("./db/flat_tables_init_output/patients_initialized-" + @started_at + "thread_#{thread}" + ".sql", "w")
    elsif thread == 9
      $temp_outfile_9_1 = File.open("./db/flat_tables_init_output/flat_table_1-" + @started_at + "thread_#{thread}" + ".sql", "w")
      $temp_outfile_9_2 = File.open("./db/flat_tables_init_output/flat_table_2-" + @started_at + "thread_#{thread}" + ".sql", "w")
      $temp_outfile_9_3 = File.open("./db/flat_tables_init_output/patients_initialized-" + @started_at + "thread_#{thread}" + ".sql", "w")
    elsif thread == 10
      $temp_outfile_10_1 = File.open("./db/flat_tables_init_output/flat_table_1-" + @started_at + "thread_#{thread}" + ".sql", "w")
      $temp_outfile_10_2 = File.open("./db/flat_tables_init_output/flat_table_2-" + @started_at + "thread_#{thread}" + ".sql", "w")
      $temp_outfile_10_3 = File.open("./db/flat_tables_init_output/patients_initialized-" + @started_at + "thread_#{thread}" + ".sql", "w")
    end

    patient_list = patients_list

    (patient_list || []).each do |p|
       puts ">>working on patient>>>#{p}<<<<<<<"
	    sql_statements = get_patients_data(p)
     if thread == 1
  	    $temp_outfile_1_3 << "#{p},"
      	$temp_outfile_1_1 << sql_statements[0]
      	$temp_outfile_1_2 << sql_statements[1]
      elsif thread == 2
        $temp_outfile_2_3 << "#{p},"
        $temp_outfile_2_1 << sql_statements[0]
        $temp_outfile_2_2 << sql_statements[1]
      elsif thread == 3
        $temp_outfile_3_3 << "#{p},"
        $temp_outfile_3_1 << sql_statements[0]
        $temp_outfile_3_2 << sql_statements[1]
      elsif thread == 4
        $temp_outfile_4_3 << "#{p},"
        $temp_outfile_4_1 << sql_statements[0]
        $temp_outfile_4_2 << sql_statements[1]
      elsif thread == 5
        $temp_outfile_5_3 << "#{p},"
        $temp_outfile_5_1 << sql_statements[0]
        $temp_outfile_5_2 << sql_statements[1]
      elsif thread == 6
        $temp_outfile_6_3 << "#{p},"
        $temp_outfile_6_1 << sql_statements[0]
        $temp_outfile_6_2 << sql_statements[1]
      elsif thread == 7
        $temp_outfile_7_3 << "#{p},"
        $temp_outfile_7_1 << sql_statements[0]
        $temp_outfile_7_2 << sql_statements[1]
      elsif thread == 8
        $temp_outfile_8_3 << "#{p},"
        $temp_outfile_8_1 << sql_statements[0]
        $temp_outfile_8_2 << sql_statements[1]
      elsif thread == 9
        $temp_outfile_9_3 << "#{p},"
        $temp_outfile_9_1 << sql_statements[0]
        $temp_outfile_9_2 << sql_statements[1]
      elsif thread == 10
        $temp_outfile_10_3 << "#{p},"
        $temp_outfile_10_1 << sql_statements[0]
        $temp_outfile_10_2 << sql_statements[1]
      end
      puts ">>finished on patient>>>#{p}<<<<<<<"
    end

    #close output files
    if thread == 1
      $temp_outfile_1_3.close
      $temp_outfile_1_1.close
      $temp_outfile_1_2.close
    elsif thread == 2
      $temp_outfile_2_3.close
      $temp_outfile_2_1.close
      $temp_outfile_2_2.close
    elsif thread == 3
      $temp_outfile_3_3.close
      $temp_outfile_3_1.close
      $temp_outfile_3_2.close
    elsif thread == 4
      $temp_outfile_4_3.close
      $temp_outfile_4_1.close
      $temp_outfile_4_2.close
    elsif thread == 5
      $temp_outfile_5_3.close
      $temp_outfile_5_1.close
      $temp_outfile_5_2.close
    elsif thread == 6
      $temp_outfile_6_3.close
      $temp_outfile_6_1.close
      $temp_outfile_6_2.close
    elsif thread == 7
      $temp_outfile_7_3.close
      $temp_outfile_7_1.close
      $temp_outfile_7_2.close
    elsif thread == 8
      $temp_outfile_8_3.close
      $temp_outfile_8_1.close
      $temp_outfile_8_2.close
    elsif thread == 9
      $temp_outfile_9_3.close
      $temp_outfile_9_1.close
      $temp_outfile_9_2.close
    elsif thread == 10
      $temp_outfile_10_3.close
      $temp_outfile_10_1.close
      $temp_outfile_10_2.close
    end

    puts "thread #{thread} ended at #{Time.now.strftime("%Y-%m-%d-%H%M%S")} Patients from >>#{patients_list[0]}<< to >>#{patients_list[last_element]}<< "

end

def get_patients_data(patient_id)
 #flat_table1 will contain hiv_staging, hiv clinic regitsrtaion observations
 #and patient demographics
 hiv_clinic_registration = []; hiv_staging = []; demographics = []
 initial_flat_table1_string = "INSERT INTO flat_table1 "

 #get patient demographics
 demographics = get_patient_demographics(patient_id)

  hiv_staging_obs_concept_ids = [2743, 7565, 7563,823,7961,5048,7551,5344, 7957,2858,5034,42,831,1549, 8206, 2585,882,6763,2894,1362,507,2587,1547,7553,7550,5046,1359,2583,7546,7546,5334,16,7955,7954,6759,2889, 3,5024,1215,5333,7539,8206,5027,7540,5337,7537,2577,2575,6758,5012,836,2891,1210,2576,6775,1212,6757,5328,5006,6831,730,9098,5497,9099,7965,1755,6131]

  hiv_staging_and_reg_enc = Encounter.find(:all,
      			:include => [:observations],
      			:order => "encounter_datetime DESC",
      			:conditions => ['voided = 0 AND patient_id = ? AND encounter_type IN (9, 52)', patient_id])
  hiv_staging_obs = []
  hiv_staging_and_reg_enc.each do |enc|
    if enc.encounter_type == 9
      obs_concepts_ids = enc.observations.map(&:concept_id)
      intersect = obs_concepts_ids & hiv_staging_obs_concept_ids
      if intersect.length != 0
        hiv_staging_obs = enc.observations
        hiv_staging = process_hiv_staging_encounter(hiv_staging_obs)
        #break
      end
    end

    if enc.encounter_type == 52

      hiv_staging_obs = enc.observations
      hiv_staging = process_hiv_staging_encounter(hiv_staging_obs)
      #break
    end
  end

  hiv_clinic_reg_obs = []

  hiv_staging_and_reg_enc.each do |enc|
    hiv_clinic_reg_obs << enc if enc.encounter_type == 9
  end

  if !hiv_clinic_reg_obs.blank?
    hiv_clinic_registration = process_hiv_clinic_registration_encounter(hiv_clinic_reg_obs.first.observations)
  end

  #check if any of the strings are empty
  demographics = get_patient_demographics(patient_id, 1) if demographics.empty?
  hiv_staging = process_hiv_staging_encounter(hiv_staging_obs, 1) if hiv_staging.empty?
  hiv_clinic_registration = process_hiv_clinic_registration_encounter(hiv_clinic_reg_obs, 1) if hiv_clinic_registration.empty?

  #write sql statement
  table_1_sql_statement = initial_flat_table1_string + "(" + demographics[0] + "," + hiv_clinic_registration[0] + "," + hiv_staging[0] + ")" + \
  	 " VALUES (" + demographics[1] + "," + hiv_clinic_registration[1] + "," + hiv_staging[1] + ");"

  visits = []

  patient_obj = Patient.find_by_patient_id(patient_id)

  visits = Encounter.find_by_sql("SELECT date(encounter_datetime) AS visit_date FROM #{@source_db}.encounter
			WHERE patient_id = #{patient_id}
			AND encounter_type IN (6, 7, 9, 25, 51, 52, 53, 54, 68, 119)
			AND voided = 0
			group by date(encounter_datetime)").map(&:visit_date)

  session_date = @max_dispensing_enc_date #date for calculating defaulters

  states_dates  = PatientProgram.find_by_sql("SELECT
                                                  ps.start_date
                                              FROM
                                                  #{@source_db}.patient_program pp
                                                      INNER JOIN
                                                  #{@source_db}.patient_state ps
                                                        ON ps.patient_program_id = pp.patient_program_id AND pp.program_id = 1
                                              WHERE
                                                  patient_id = #{patient_id}
                                              AND ps.voided = 0
                                              GROUP BY ps.start_date").map(&:start_date)

  if !states_dates.blank?
    states_dates.each do |date|
      if !date.blank?
        visits << date
      end
    end
  end

  #list of encounters for bart2
  #vitals => 6, appointment => 7, treatment => 25,
  #hiv clinic consultation => 53, hiv_reception => 51

  initial_string = "INSERT INTO flat_table2 "
  table2_sql_batch = ""

  visits.uniq.sort.each do |visit|
     	# arrays of [fields, values]
      patient_details = ["patient_id, visit_date","#{patient_id},'#{visit}'"]
      vitals = []
      appointment = []
      hcc = []
      hiv_reception = []
      patient_orders = []
      patient_state = []
      patient_adh = []
      patient_reg_category = []
      treatment_obs = []
      dispensing_obs = []
      exit_from_care_obs = []

      # we will exclude the orders having drug_inventory_id null
      orders = Order.find_by_sql("SELECT o.patient_id, IFNULL(o.order_id, 0) AS order_id, IFNULL(o.encounter_id, 0) AS encounter_id,
                                               o.start_date, o.auto_expire_date, IFNULL(d.quantity, 0) AS quantity,
                                               d.drug_inventory_id, IFNULL(d.dose, 2) As dose, IFNULL(d.frequency, 'Unknown') AS frequency,
                                               o.concept_id, IFNULL(d.equivalent_daily_dose, 2) AS equivalent_daily_dose
                                    FROM #{@source_db}.orders o
                                      INNER JOIN #{@source_db}.drug_order d ON d.order_id = o.order_id
                                    WHERE DATE(o.start_date) = '#{visit}'
                                    AND o.patient_id = #{patient_id}
                                    AND d.drug_inventory_id IS NOT NULL ")

        	if orders
          		patient_orders = process_patient_orders(orders, visit, 1) if patient_orders.empty?
        	end

          reg_category = Encounter.find_by_sql("SELECT e.patient_id AS patient_id, patient_current_regimen(e.patient_id, '#{visit}') AS regimen_category, o.encounter_id AS encounter_id, e.encounter_datetime
                                              FROM #{@source_db}.encounter e
                                              WHERE e.encounter_type in (25, 54)
                                              AND DATE(e.encounter_datetime) = '#{visit}'
                                              AND e.patient_id = #{patient_id}")

          if reg_category
            patient_reg_category = process_pat_regimen_category(reg_category, visit, 1) if patient_reg_category.empty?
          end

      	encounters = Encounter.find(:all,
      			:include => [:observations],
      			:order => "encounter_datetime ASC",
      			:conditions => ['voided = 0 AND patient_id = ? AND date(encounter_datetime) = ?', patient_id, visit])

      	encounters.each do |enc|
      		if enc.encounter_type == 6 #vitals
      			vitals = process_vitals_encounter(enc)
      		elsif enc.encounter_type == 51#HIV Reception
      			hiv_reception = process_hiv_reception_encounter(enc)
      		elsif enc.encounter_type == 53 #HIV Clinic Consultation
      			hcc = process_hiv_clinic_consultation_encounter(enc)
      		elsif enc.encounter_type == 68 #ART adherence
      		  patient_adh = process_adherence_encounter(enc, visit)
      		elsif enc.encounter_type == 25 #treatment
      		  treatment_obs = process_treatment_obs(enc)
          elsif enc.encounter_type == 7 #appointment
            appointment = process_appointment_encounter(enc)
          elsif enc.encounter_type == 54 #dispensing
            dispensing_obs = process_dispensing_obs(enc)
          elsif enc.encounter_type == 119 #exit_from_care
            exit_from_care_obs = process_exit_from_care_obs(enc)
      		end
      	end

      	patient_state = process_patient_state(patient_id, visit)

      	#if some encounters are missing, create a skeleton with defaults
      	 vitals = process_vitals_encounter(1, 1) if vitals.empty?
         hcc = process_hiv_clinic_consultation_encounter(1, 1) if hcc.empty?
         hiv_reception = process_hiv_reception_encounter(1, 1) if hiv_reception.empty?
         patient_adh = process_adherence_encounter(1, visit,1) if patient_adh.empty?
         treatment_obs = process_treatment_obs(1, 1) if treatment_obs.empty?
         appointment = process_appointment_encounter(1, 1) if appointment.empty?
         dispensing_obs = process_dispensing_obs(1, 1) if dispensing_obs.empty?
         exit_from_care_obs = process_exit_from_care_obs(1, 1) if exit_from_care_obs.empty?

         table_2_sql_statement = initial_string + "(" + patient_details[0] + "," + exit_from_care_obs[0] + "," + patient_state[0] + "," + appointment[0] + "," + vitals[0] + "," + hcc[0] + "," + hiv_reception[0] + "," + patient_orders[0] + "," + patient_adh[0] + "," + patient_reg_category[0] + "," + dispensing_obs[0] + "," + treatment_obs[0] + ")" + \
           " VALUES (" + patient_details[1] + "," + exit_from_care_obs[1] + "," + patient_state[1]  + "," + appointment[1] + "," + vitals[1] + "," + hcc[1] + "," + hiv_reception[1] + "," + patient_orders[1] + "," + patient_adh[1] + "," + patient_reg_category[1] + "," + dispensing_obs[1] + "," + treatment_obs[1] + ");"

      table2_sql_batch += table_2_sql_statement

   end
   return [table_1_sql_statement, table2_sql_batch]
end

def get_patient_demographics(patient_id)
  puts "patient_id: #{patient_id}"
  pat = Patient.find(patient_id)
  @initialized_patients = []

  current_location = Location.find(GlobalProperty.find_by_property("current_health_center_id").property_value).name

  this_patient = []
  this_identifiers = []
  this_attributes = []

  if @initialized_patients.include?(patient_id)
     puts"patient already initialized>>>>>>#{patient_id}"
  else
     this_patient =  $patient_demographics.select{|patient| patient.patient_id.to_i == patient_id}
     the_identifiers = $patient_identifiers.select{|patient| patient.patient_id.to_i == patient_id} rescue []
     the_attributes = $patient_attributes.select{|patient| patient.person_id.to_i == patient_id} rescue []

     guardian_person_ids = $guardians.select{|person| person.patient_id == patient_id}.map(&:guardian_id) rescue []
     guardian_to_which_patient_ids = $guardians.select{|person| person.guardian_id == patient_id}.map(&:patient_id) rescue []

     a_hash = {:legacy_id2 => 'NULL'}

     gender = pat.person.gender
=begin
     if gender == 'M'
        gender = 'Male'
     elsif gender == 'F'
        gender = 'Female'
     end
=end
     a_hash[:patient_id] = patient_id
     a_hash[:given_name] = this_patient.first.given_name rescue nil
     a_hash[:middle_name] = this_patient.first.middle_name rescue nil
     a_hash[:family_name] = this_patient.first.family_name rescue nil
     a_hash[:gender] = gender rescue nil
     a_hash[:dob] = this_patient.first.birthdate rescue nil
     a_hash[:dob_estimated] = this_patient.first.birthdate_estimated rescue nil
     unless this_patient.first.death_date.blank?
       a_hash[:death_date] = this_patient.first.death_date
     end
     a_hash[:ta] = this_patient.first.traditional_authority  rescue nil
     a_hash[:current_address] = this_patient.first.current_residence  rescue nil
     a_hash[:home_district] = this_patient.first.home_district  rescue nil
     a_hash[:landmark] = this_patient.first.landmark  rescue nil

     a_hash[:cellphone_number] = the_attributes.first.cell_phone  rescue nil
     a_hash[:home_phone_number] = the_attributes.first.home_phone  rescue nil
     a_hash[:office_phone_number] = the_attributes.first.office_phone  rescue nil
     a_hash[:occupation] = the_attributes.first.occupation  rescue nil
     a_hash[:nat_id] = the_identifiers.first.national_id  rescue nil
     a_hash[:arv_number]  = the_identifiers.first.arv_number  rescue nil
     a_hash[:pre_art_number] = the_identifiers.first.pre_art_number  rescue nil
     a_hash[:tb_number]  = the_identifiers.first.tb_number  rescue nil
     a_hash[:legacy_id]  = the_identifiers.first.legacy_id  rescue nil
     a_hash[:prev_art_number]  = the_identifiers.first.prev_art_number rescue nil
     a_hash[:filing_number]  = the_identifiers.first.filing_number  rescue nil
     a_hash[:archived_filing_number]  = the_identifiers.first.archived_filing_number rescue nil

     a_hash[:earliest_start_date]  = this_patient.first.earliest_start_date  rescue nil
     unless this_patient.first.date_enrolled.blank?
       a_hash[:date_enrolled] = this_patient.first.date_enrolled
     end
     a_hash[:age_at_initiation] = this_patient.first.age_at_initiation rescue nil
     a_hash[:age_in_days] = this_patient.first.age_in_days rescue nil
     a_hash[:current_location] = current_location rescue nil

     if guardian_person_ids
       a_hash[:guardian_person_id1] = guardian_person_ids[0]
       a_hash[:guardian_person_id2] = guardian_person_ids[1]
       a_hash[:guardian_person_id3] = guardian_person_ids[2]
       a_hash[:guardian_person_id4] = guardian_person_ids[3]
       a_hash[:guardian_person_id5] = guardian_person_ids[4]
    end

     if guardian_to_which_patient_ids
      a_hash[:guardian_to_which_patient1] = guardian_to_which_patient_ids[0]
      a_hash[:guardian_to_which_patient2] = guardian_to_which_patient_ids[1]
      a_hash[:guardian_to_which_patient3] = guardian_to_which_patient_ids[2]
      a_hash[:guardian_to_which_patient4] = guardian_to_which_patient_ids[3]
      a_hash[:guardian_to_which_patient5] = guardian_to_which_patient_ids[4]
     end

     @initialized_patients << patient_id
  end

  return generate_sql_string(a_hash)
end

def process_appointment_encounter(encounter, type = 0) #type 0 normal encounter, 1 generate_template only

    #initialize field and values variables
    fields = ""
    values = ""

    #create vitals field list hash template
    a_hash = {  :appointment_date_enc_id => 'NULL'}

    return generate_sql_string(a_hash) if type == 1

    encounter.observations.each do |obs|
      if obs.concept_id.to_i == 5096 #appointment_date
        a_hash[:appointment_date] = obs.value_datetime.to_date rescue nil
		    a_hash[:appointment_date_enc_id] = encounter.encounter_id
      end
    end

    return generate_sql_string(a_hash)
end


def process_vitals_encounter(encounter, type = 0) #type 0 normal encounter, 1 generate_template only

    #initialize field and values variables
    fields = ""
    values = ""

    #create vitals field list hash template
    a_hash = {  :weight_enc_id => 'NULL'}

    return generate_sql_string(a_hash) if type == 1

    encounter.observations.each do |obs|
      if obs.concept_id.to_i == 5089 #weight
        a_hash[:weight] = obs.to_s.split(':')[1].strip rescue nil
		    a_hash[:weight_enc_id] = encounter.encounter_id
      elsif obs.concept_id.to_i == 5090 #height
        a_hash[:height] = obs.to_s.split(':')[1].strip rescue nil
		    a_hash[:height_enc_id] = encounter.encounter_id
      elsif obs.concept_id.to_i == 5088 #temperature
        a_hash[:temperature] = obs.to_s.split(':')[1].strip rescue nil
		    a_hash[:temperature_enc_id] = encounter.encounter_id
      elsif obs.concept_id.to_i == 2137 #bmi
        a_hash[:bmi] = obs.to_s.split(':')[1].strip rescue nil
		    a_hash[:bmi_enc_id] = encounter.encounter_id
      elsif obs.concept_id.to_i == 5085 #systolic blood pressure
        a_hash[:systolic_blood_pressure] = obs.to_s.split(':')[1].strip rescue nil
		    a_hash[:systolic_blood_pressure_enc_id] = encounter.encounter_id
      elsif obs.concept_id.to_i == 5086 #diastolic blood pressure
        a_hash[:diastolic_blood_pressure] = obs.to_s.split(':')[1].strip rescue nil
		    a_hash[:diastolic_blood_pressure_enc_id] = encounter.encounter_id
      elsif obs.concept_id.to_i == 1822 #weight for height
        a_hash[:weight_for_height]  = obs.to_s.split(':')[1].strip rescue nil
		    a_hash[:weight_for_height_enc_id] = encounter.encounter_id
      elsif obs.concept_id.to_i == 6396 #weight for age
        a_hash[:weight_for_age] = obs.to_s.split(':')[1].strip rescue nil
		    a_hash[:weight_for_age_enc_id] = encounter.encounter_id
      elsif obs.concept_id.to_i == 6397 #height_for_age
        a_hash[:height_for_age] = obs.to_s.split(':')[1].strip rescue nil
		    a_hash[:height_for_age_enc_id] = encounter.encounter_id
      end
    end

    return generate_sql_string(a_hash)
end

def process_hiv_reception_encounter(encounter, type = 0) #type 0 normal encounter, 1 generate_template only

    #initialize field and values variables
    fields = ""
    values = ""

    #create vitals field list hash template
    a_hash =	  {:guardian_present_enc_id => 'NULL'}

    return generate_sql_string(a_hash) if type == 1

    encounter.observations.each do |obs|

      if obs.concept_id.to_i == 2122 #Guardian Present
    		if obs.value_coded.to_i == 1065 && obs.value_coded_name_id == 1102
    			a_hash[:guardian_present] = 'Yes'
    			a_hash[:guardian_present_enc_id] = encounter.encounter_id
    		elsif obs.value_coded.to_i == 1066 && obs.value_coded_name_id == 1103
    			a_hash[:guardian_present] = 'No'
    			a_hash[:guardian_present_enc_id] = encounter.encounter_id
    	  elsif obs.value_coded.to_i == 1067 && obs.value_coded_name_id == 1104
    			a_hash[:guardian_present] = 'Unknown'
    			a_hash[:guardian_present_enc_id] = encounter.encounter_id
    	  elsif obs.value_text == 'Yes'
    	    a_hash[:guardian_present] = 'Yes'
    			a_hash[:guardian_present_enc_id] = encounter.encounter_id
    		elsif obs.value_text == 'No'
    		  a_hash[:guardian_present] = 'No'
    			a_hash[:guardian_present_enc_id] = encounter.encounter_id
    		elsif obs.value_text == 'Unknown'
    		  a_hash[:guardian_present] = 'Unknown'
    			a_hash[:guardian_present_enc_id] = encounter.encounter_id
    		end
      elsif obs.concept_id.to_i == 1805 #Patient Present
        if obs.value_coded.to_i == 1065 && obs.value_coded_name_id == 1102
          a_hash[:patient_present] = 'Yes'
          a_hash[:patient_present_enc_id] = encounter.encounter_id
        elsif obs.value_coded.to_i == 1066 && obs.value_coded_name_id == 1103
          a_hash[:patient_present] = 'No'
          a_hash[:patient_present_enc_id] = encounter.encounter_id
        elsif obs.value_coded.to_i == 1067 && obs.value_coded_name_id == 1104
          a_hash[:patient_present] = 'Unknown'
          a_hash[:patient_present_enc_id] = encounter.encounter_id
        end
      end
    end

    return generate_sql_string(a_hash)
end

def process_dispensing_obs(encounter, type = 0) #type 0 normal encounter, 1 generate_template only

    #initialize field and values variables
    fields = ""
    values = ""

    #create vitals field list hash template
    a_hash =	  {:arv_regimen_type_AZT_3TC_LPV_r_enc_id => 'NULL'}

    return generate_sql_string(a_hash) if type == 1

    encounter.observations.each do |obs|
      if obs.concept_id.to_i == 8375 #regimen_category_treatment

        a_hash[:regimen_category_dispensed] = obs.value_text
        a_hash[:regimen_category_dispensed_enc_id] = encounter.encounter_id
      elsif obs.concept_id.to_i == 2559 #arv_regimens_received_construct_record
        a_hash[:arv_regimens_received_construct] = obs.to_s.split(':')[1].strip rescue nil
        a_hash[:arv_regimens_received_construct_enc_id] = encounter.encounter_id
      end
    end
    return generate_sql_string(a_hash)
end

def process_exit_from_care_obs(encounter, type = 0) #type 0 normal encounter, 1 generate_template only

    #initialize field and values variables
    fields = ""
    values = ""

    #create vitals field list hash template
    a_hash =	  {:arv_regimen_type_triomune => 'NULL'}

    return generate_sql_string(a_hash) if type == 1

    encounter.observations.each do |obs|
      if obs.concept_id.to_i == 1811 #reason_for_exiting_from_care
        a_hash[:reason_for_exiting_from_care] = obs.to_s.split(':')[1].strip rescue nil
        a_hash[:reason_for_exiting_from_care_enc_id] = encounter.encounter_id

      elsif obs.concept_id.to_i == 3003 #transfer_out_location
        value_record = Location.find_by_sql("SELECT name FROM location WHERE location_id = #{obs.value_numeric.to_i}").first.name rescue nil
        value_record = obs.value_text if value_record.blank?

        a_hash[:transfer_out_location] = value_record rescue nil
        a_hash[:transfer_out_location_enc_id] = encounter.encounter_id
      elsif obs.concept_id.to_i == 8519 #date_of_exiting_care
        a_hash[:date_exiting_from_care] = obs.value_datetime.to_date rescue nil
        a_hash[:date_exiting_from_care_enc_id] = encounter.encounter_id
      end
    end
    return generate_sql_string(a_hash)
end

def process_treatment_obs(encounter, type = 0) #type 0 normal encounter, 1 generate_template only

    #initialize field and values variables
    fields = ""
    values = ""

    #create vitals field list hash template
    a_hash =	  {:arv_regimen_type_d4T_3TC_NVP_enc_id => 'NULL'}

    return generate_sql_string(a_hash) if type == 1

    encounter.observations.each do |obs|
      if obs.concept_id.to_i == 656 #IPT given
    		if obs.value_coded.to_i == 1065 #&& obs.value_coded_name_id == 1102
    			a_hash[:ipt_given] = 'Yes'
    			a_hash[:ipt_given_enc_id] = encounter.encounter_id
    		elsif obs.value_coded.to_i == 1066 #&& obs.value_coded_name_id == 1103
    			a_hash[:ipt_given] = 'No'
    			a_hash[:ipt_given_enc_id] = encounter.encounter_id

    		end
      elsif obs.concept_id.to_i == 7024 #CPT given
        if obs.value_coded.to_i == 1065 #&& obs.value_coded_name_id == 1102
          a_hash[:cpt_given] = 'Yes'
          a_hash[:cpt_given_enc_id] = encounter.encounter_id
        elsif obs.value_coded.to_i == 1066 #&& obs.value_coded_name_id == 1103
          a_hash[:cpt_given] = 'No'
          a_hash[:cpt_given_enc_id] = encounter.encounter_id
        end
      elsif obs.concept_id.to_i == 190 #condoms_given
        a_hash[:condoms_given] = obs.value_numeric
        a_hash[:condoms_given_enc_id] = encounter.encounter_id
      elsif obs.concept_id.to_i == 8375 #regimen_category_treatment
        a_hash[:regimen_category_treatment] = obs.value_text
        a_hash[:regimen_category_treatment_enc_id] = encounter.encounter_id
      elsif obs.concept_id.to_i == 6882 #what_type_of_ARV_regimen
        a_hash[:type_of_ARV_regimen_given] = obs.to_s.split(':')[1].strip rescue nil
        a_hash[:type_of_ARV_regimen_given_enc_id] = encounter.encounter_id
      end
    end

    return generate_sql_string(a_hash)
end

def process_hiv_clinic_consultation_encounter(encounter, type = 0) #type 0 normal encounter, 1 generate_template only

    #initialize field and values variables
    fields = ""
    values = ""

    #create vitals field list hash template
    a_hash =   {
                :routine_tb_screening_weight_loss_failure_enc_id => 'NULL'
                }

    return generate_sql_string(a_hash) if type == 1
    encounter.observations.each do |obs|
      #determining if the patient have side effects that visit
      new_malawi_side_effects_saved =  Encounter.find_by_sql("SELECT person_id, concept_id, value_coded from obs
                                          WHERE encounter_id = #{obs.encounter_id}
                                          AND obs_group_id IS NOT NULL
                                          AND concept_id IN (215, 3, 1458, 151, 868, 107, 16, 7952, 5980, 29, 219, 512, 821, 877, 2148, 2150, 3681, 5953, 6408, 9242, 9440)")

      if new_malawi_side_effects_saved.blank?
        old_malawi_side_effects_saved = Encounter.find_by_sql("SELECT person_id, concept_id, value_coded from obs
                                            WHERE encounter_id = #{obs.encounter_id}
                                            AND concept_id = 7755 AND value_coded NOT IN (1066, 1107)")

        unless old_malawi_side_effects_saved.blank?
          a_hash[:side_effects_present] = 'Yes'
          a_hash[:side_effects_present_enc_id] = encounter.encounter_id
        else
          a_hash[:side_effects_present] = 'No'
          a_hash[:side_effects_present_enc_id] = encounter.encounter_id
        end

      else
        new_malawi_side_effects_saved =  Encounter.find_by_sql("SELECT person_id, concept_id, value_coded from obs
                                            WHERE encounter_id = #{obs.encounter_id}
                                            AND concept_id IN (215, 3, 1458, 151, 868, 107, 16, 7952, 5980, 29, 219, 512, 821, 877, 2148, 2150, 3681, 5953, 6408, 9242, 9440)
                                            AND obs_group_id IS NOT NULL
                                            AND value_coded NOT IN (1066, 1107)")
        unless new_malawi_side_effects_saved.blank?
          a_hash[:side_effects_present] = 'Yes'
          a_hash[:side_effects_present_enc_id] = encounter.encounter_id
        else
          a_hash[:side_effects_present] = 'No'
          a_hash[:side_effects_present_enc_id] = encounter.encounter_id
        end
      end

      if obs.concept_id.to_i == 6131 #Patient Pregnant
        if obs.value_coded.to_i == 1065 && obs.value_coded_name_id == 1102
          a_hash[:patient_pregnant] = 'Yes'
          a_hash[:patient_pregnant_enc_id] = encounter.encounter_id
          a_hash[:patient_pregnant_v_date] = obs.obs_datetime.to_date
        elsif obs.value_coded.to_i == 1066 && obs.value_coded_name_id == 1103
          a_hash[:patient_pregnant] = 'No'
          a_hash[:patient_pregnant_enc_id] = encounter.encounter_id
          a_hash[:patient_pregnant_v_date] = obs.obs_datetime.to_date
        elsif obs.value_coded.to_i == 1067 && obs.value_coded_name_id == 1104
          a_hash[:patient_pregnant] = 'Unknown'
          a_hash[:patient_pregnant_enc_id] = encounter.encounter_id
          a_hash[:patient_pregnant_v_date] = obs.obs_datetime.to_date
        end
      elsif obs.concept_id.to_i == 1755 #Patient Pregnant
        if obs.value_coded.to_i == 1065 && obs.value_coded_name_id == 1102
          a_hash[:patient_pregnant] = 'Yes'
          a_hash[:patient_pregnant_enc_id] = encounter.encounter_id
          a_hash[:patient_pregnant_v_date] = obs.obs_datetime.to_date
        elsif obs.value_coded.to_i == 1066 && obs.value_coded_name_id == 1103
          a_hash[:patient_pregnant] = 'No'
          a_hash[:patient_pregnant_enc_id] = encounter.encounter_id
          a_hash[:patient_pregnant_v_date] = obs.obs_datetime.to_date
        elsif obs.value_coded.to_i == 1067 && obs.value_coded_name_id == 1104
          a_hash[:patient_pregnant] = 'Unknown'
          a_hash[:patient_pregnant_enc_id] = encounter.encounter_id
          a_hash[:patient_pregnant_v_date] = obs.obs_datetime.to_date
        end
      elsif obs.concept_id.to_i == 7965 #breastfeeding
        if obs.value_coded.to_i == 1065 && obs.value_coded_name_id == 1102
          a_hash[:patient_breastfeeding] = 'Yes'
          a_hash[:patient_breastfeeding_enc_id] = encounter.encounter_id
          a_hash[:patient_breastfeeding_v_date] = obs.obs_datetime.to_date
        elsif obs.value_coded.to_i == 1066 && obs.value_coded_name_id == 1103
          a_hash[:patient_breastfeeding] = 'No'
          a_hash[:patient_breastfeeding_enc_id] = encounter.encounter_id
          a_hash[:patient_breastfeeding_v_date] = obs.obs_datetime.to_date
        elsif obs.value_coded.to_i == 1067 && obs.value_coded_name_id == 1104
          a_hash[:patient_breastfeeding] = 'Unknown'
          a_hash[:patient_breastfeeding_enc_id] = encounter.encounter_id
          a_hash[:patient_breastfeeding_v_date] = obs.obs_datetime.to_date
        end
    	elsif obs.concept_id.to_i == 7459 #tb status
    		if obs.value_coded.to_i == 7454 && obs.value_coded_name_id == 10270
          a_hash[:tb_status] = 'TB NOT Suspected'
          a_hash[:tb_status_enc_id] = encounter.encounter_id
    			a_hash[:tb_status_tb_not_suspected] = 'Yes'
    			a_hash[:tb_status_tb_not_suspected_enc_id] = encounter.encounter_id
    		elsif obs.value_coded.to_i == 7455 && obs.value_coded_name_id == 10273
          a_hash[:tb_status] = 'TB Suspected'
          a_hash[:tb_status_enc_id] = encounter.encounter_id
    			a_hash[:tb_status_tb_suspected] = 'Yes'
          a_hash[:tb_status_tb_suspected_enc_id] = encounter.encounter_id
    		elsif obs.value_coded.to_i == 7456 && obs.value_coded_name_id == 10274
          a_hash[:tb_status] = 'Confirmed TB NOT on treatment'
          a_hash[:tb_status_enc_id] = encounter.encounter_id
    			a_hash[:tb_status_confirmed_tb_not_on_treatment] = 'Yes'
          a_hash[:tb_status_confirmed_tb_not_on_treatment_enc_id] = encounter.encounter_id
    		elsif obs.value_coded.to_i == 7458 && obs.value_coded_name_id == 10279
          a_hash[:tb_status] = 'Confirmed TB on treatment'
          a_hash[:tb_status_enc_id] = encounter.encounter_id
    			a_hash[:tb_status_confirmed_tb_on_treatment] = 'Yes'
          a_hash[:tb_status_confirmed_tb_on_treatment_enc_id] = encounter.encounter_id
    		elsif obs.value_coded.to_i == 1067 && obs.value_coded_name_id == 1104
          a_hash[:tb_status] = 'Unknown'
          a_hash[:tb_status_enc_id] = encounter.encounter_id
    			a_hash[:tb_status_unknown] = 'Yes'
          a_hash[:tb_status_unknown_enc_id] = encounter.encounter_id
    		end
      elsif obs.concept_id.to_i == 1717 #using family planning methods
        if obs.value_coded.to_i == 1065 && obs.value_coded_name_id == 1102
          a_hash[:currently_using_family_planning_method] = 'Yes'
          a_hash[:currently_using_family_planning_method_enc_id] = encounter.encounter_id
        elsif obs.value_coded.to_i == 1066 && obs.value_coded_name_id == 1103
          a_hash[:currently_using_family_planning_method] = 'No'
          a_hash[:currently_using_family_planning_method_enc_id] = encounter.encounter_id
        elsif obs.value_coded.to_i == 1067 && obs.value_coded_name_id == 1104
          a_hash[:currently_using_family_planning_method] = 'Unknown'
          a_hash[:currently_using_family_planning_method_enc_id] = encounter.encounter_id
        end
      elsif obs.concept_id.to_i == 374 #family planning method
        if obs.value_coded.to_i == 780 && obs.value_coded_name_id == 10736
          a_hash[:family_planning_method_oral_contraceptive_pills] = 'Yes'
          a_hash[:family_planning_method_oral_contraceptive_pills_enc_id] = encounter.encounter_id
        elsif obs.value_coded.to_i == 907 && obs.value_coded_name_id == 931
          a_hash[:family_planning_method_depo_provera] = 'Yes'
          a_hash[:family_planning_method_depo_provera_enc_id] = encounter.encounter_id
        elsif obs.value_coded.to_i == 5275 && obs.value_coded_name_id == 10737
          a_hash[:family_planning_method_intrauterine_contraception] = 'Yes'
          a_hash[:family_planning_method_intrauterine_contraception_enc_id] = encounter.encounter_id
        elsif obs.value_coded.to_i == 7857 && obs.value_coded_name_id == 10738
          a_hash[:family_planning_method_contraceptive_implant] = 'Yes'
          a_hash[:family_planning_method_contraceptive_implant_enc_id] = encounter.encounter_id
        elsif obs.value_coded.to_i == 7858 && obs.value_coded_name_id == 10739
          a_hash[:family_planning_method_male_condoms] = 'Yes'
          a_hash[:family_planning_method_male_condoms_enc_id] = encounter.encounter_id
        elsif obs.value_coded.to_i == 7859 && obs.value_coded_name_id == 10740
          a_hash[:family_planning_method_female_condoms] = 'Yes'
          a_hash[:family_planning_method_female_condoms_enc_id] = encounter.encounter_id
        elsif obs.value_coded.to_i == 7860 && obs.value_coded_name_id == 10741
          a_hash[:family_planning_method_rythm_method] = 'Yes'
          a_hash[:family_planning_method_rythm_method_enc_id] = encounter.encounter_id
        elsif obs.value_coded.to_i == 7861 && obs.value_coded_name_id == 10743
          a_hash[:family_planning_method_withdrawal] = 'Yes'
          a_hash[:family_planning_method_withdrawal_enc_id] = encounter.encounter_id
        elsif obs.value_coded.to_i == 1720 && obs.value_coded_name_id == 1876
          a_hash[:family_planning_method_abstinence] = 'Yes'
          a_hash[:family_planning_method_abstinence_enc_id] = encounter.encounter_id
        elsif obs.value_coded.to_i == 1719 && obs.value_coded_name_id == 1874
          a_hash[:family_planning_method_tubal_ligation] = 'Yes'
          a_hash[:family_planning_method_tubal_ligation_enc_id] = encounter.encounter_id
        elsif obs.value_coded.to_i == 1721 && obs.value_coded_name_id == 1877
          a_hash[:family_planning_method_vasectomy] = 'Yes'
          a_hash[:family_planning_method_vasectomy_enc_id] = encounter.encounter_id
        elsif obs.value_coded.to_i == 7862 && obs.value_coded_name_id == 10744
          a_hash[:family_planning_method_emergency_contraception] = 'Yes'
          a_hash[:family_planning_method_emergency_contraception_enc_id] = encounter.encounter_id
        end
      elsif obs.concept_id.to_i == 1618 #family planning method
        if obs.value_coded.to_i == 1107
          a_hash[:family_planning_method] = 'None'
        elsif obs.value_coded.to_i == 1066
          a_hash[:family_planning_method] = 'No'
        elsif obs.value_coded.to_i == 1067
          a_hash[:family_planning_method] = 'Unknown'
        else
          a_hash[:family_planning_method] = 'Yes'
        end

        if obs.value_coded.to_i == 780 && obs.value_coded_name_id == 10736
          a_hash[:family_planning_method_oral_contraceptive_pills] = 'Yes'
          a_hash[:family_planning_method_oral_contraceptive_pills_enc_id] = encounter.encounter_id
        elsif obs.value_coded.to_i == 907 && obs.value_coded_name_id == 931
          a_hash[:family_planning_method_depo_provera] = 'Yes'
          a_hash[:family_planning_method_depo_provera_enc_id] = encounter.encounter_id
        elsif obs.value_coded.to_i == 5275 && obs.value_coded_name_id == 10737
          a_hash[:family_planning_method_intrauterine_contraception] = 'Yes'
          a_hash[:family_planning_method_intrauterine_contraception_enc_id] = encounter.encounter_id
        elsif obs.value_coded.to_i == 7857 && obs.value_coded_name_id == 10738
          a_hash[:family_planning_method_contraceptive_implant] = 'Yes'
          a_hash[:family_planning_method_contraceptive_implant_enc_id] = encounter.encounter_id
        elsif obs.value_coded.to_i == 7858 && obs.value_coded_name_id == 10739
          a_hash[:family_planning_method_male_condoms] = 'Yes'
          a_hash[:family_planning_method_male_condoms_enc_id] = encounter.encounter_id
        elsif obs.value_coded.to_i == 7859 && obs.value_coded_name_id == 10740
          a_hash[:family_planning_method_female_condoms] = 'Yes'
          a_hash[:family_planning_method_female_condoms_enc_id] = encounter.encounter_id
        elsif obs.value_coded.to_i == 7860 && obs.value_coded_name_id == 10741
          a_hash[:family_planning_method_rythm_method] = 'Yes'
          a_hash[:family_planning_method_rythm_method_enc_id] = encounter.encounter_id
        elsif obs.value_coded.to_i == 7861 && obs.value_coded_name_id == 10743
          a_hash[:family_planning_method_withdrawal] = 'Yes'
          a_hash[:family_planning_method_withdrawal_enc_id] = encounter.encounter_id
        elsif obs.value_coded.to_i == 1720 && obs.value_coded_name_id == 1876
          a_hash[:family_planning_method_abstinence] = 'Yes'
          a_hash[:family_planning_method_abstinence_enc_id] = encounter.encounter_id
        elsif obs.value_coded.to_i == 1719 && obs.value_coded_name_id == 1874
          a_hash[:family_planning_method_tubal_ligation] = 'Yes'
          a_hash[:family_planning_method_tubal_ligation_enc_id] = encounter.encounter_id
        elsif obs.value_coded.to_i == 1721 && obs.value_coded_name_id == 1877
          a_hash[:family_planning_method_vasectomy] = 'Yes'
          a_hash[:family_planning_method_vasectomy_enc_id] = encounter.encounter_id
        elsif obs.value_coded.to_i == 7862 && obs.value_coded_name_id == 10744
          a_hash[:family_planning_method_emergency_contraception] = 'Yes'
          a_hash[:family_planning_method_emergency_contraception_enc_id] = encounter.encounter_id
        end
     elsif obs.concept_id.to_i == 1293 #symptoms present
        if obs.value_coded.to_i == 2148 && obs.value_coded_name_id == 2325
          a_hash[:symptom_present_lipodystrophy] = 'Yes'
          a_hash[:symptom_present_lipodystrophy_enc_id] = encounter.encounter_id
        elsif obs.value_coded.to_i == 3 && obs.value_coded_name_id == 3
          a_hash[:symptom_present_anemia] = 'Yes'
          a_hash[:symptom_present_anemia_enc_id] = encounter.encounter_id
        elsif obs.value_coded.to_i == 215 && obs.value_coded_name_id == 226
          a_hash[:symptom_present_jaundice] = 'Yes'
          a_hash[:symptom_present_jaundice_enc_id] = encounter.encounter_id
        elsif obs.value_coded.to_i == 1458 && obs.value_coded_name_id == 1576
          a_hash[:symptom_present_lactic_acidosis] = 'Yes'
          a_hash[:symptom_present_lactic_acidosis_enc_id] = encounter.encounter_id
        elsif obs.value_coded.to_i == 5945 && obs.value_coded_name_id == 4315
          a_hash[:symptom_present_fever] = 'Yes'
          a_hash[:symptom_present_fever_enc_id] = encounter.encounter_id
        elsif obs.value_coded.to_i == 512 && obs.value_coded_name_id == 524
          a_hash[:symptom_present_skin_rash] = 'Yes'
          a_hash[:symptom_present_skin_rash_enc_id] = encounter.encounter_id
        elsif obs.value_coded.to_i == 151 && obs.value_coded_name_id == 156
          a_hash[:symptom_present_abdominal_pain] = 'Yes'
          a_hash[:symptom_present_abdominal_pain_enc_id] = encounter.encounter_id
        elsif obs.value_coded.to_i == 868 && obs.value_coded_name_id == 888
          a_hash[:symptom_present_anorexia] = 'Yes'
          a_hash[:symptom_present_anorexia_enc_id] = encounter.encounter_id
        elsif obs.value_coded.to_i == 107 && obs.value_coded_name_id == 110
          a_hash[:symptom_present_cough] = 'Yes'
          a_hash[:symptom_present_cough_enc_id] = encounter.encounter_id
        elsif obs.value_coded.to_i == 16 && obs.value_coded_name_id == 17
          a_hash[:symptom_present_diarrhea] = 'Yes'
          a_hash[:symptom_present_diarrhea_enc_id] = encounter.encounter_id
        elsif obs.value_coded.to_i == 7952 && obs.value_coded_name_id == 10894
          a_hash[:symptom_present_leg_pain_numbness] = 'Yes'
          a_hash[:symptom_present_leg_pain_numbness_enc_id] = encounter.encounter_id
        elsif obs.value_coded.to_i == 821 && obs.value_coded_name_id == 838
          a_hash[:symptom_present_peripheral_neuropathy] = 'Yes'
          a_hash[:symptom_present_peripheral_neuropathy_enc_id] = encounter.encounter_id
        elsif obs.value_coded.to_i == 5980 && obs.value_coded_name_id == 4355
          a_hash[:symptom_present_vomiting] = 'Yes'
          a_hash[:symptom_present_vomiting_enc_id] = encounter.encounter_id
        elsif obs.value_coded.to_i == 6779 && obs.value_coded_name_id == 4355
          a_hash[:symptom_present_other_symptom] = 'Yes'
          a_hash[:symptom_present_other_symptom_enc_id] = encounter.encounter_id
        elsif obs.value_coded.to_i == 29 && obs.value_coded_name_id == 30
          a_hash[:symptom_present_hepatitis] = 'Yes'
          a_hash[:symptom_present_hepatitis_enc_id] = encounter.encounter_id
        elsif obs.value_coded.to_i == 9242 && obs.value_coded_name_id == 12434
          a_hash[:symptom_present_kidney_failure] = 'Yes'
          a_hash[:symptom_present_kidney_failure_enc_id] = encounter.encounter_id
        elsif obs.value_coded.to_i == 2150 && obs.value_coded_name_id == 2328
          a_hash[:symptom_present_nightmares] = 'Yes'
          a_hash[:symptom_present_nightmares_enc_id] = encounter.encounter_id
        elsif obs.value_coded.to_i == 877 && obs.value_coded_name_id == 897
          a_hash[:symptom_present_diziness] = 'Yes'
          a_hash[:symptom_present_diziness_enc_id] = encounter.encounter_id
        elsif obs.value_coded.to_i == 219 && obs.value_coded_name_id == 231
          a_hash[:symptom_present_psychosis] = 'Yes'
          a_hash[:symptom_present_psychosis_enc_id] = encounter.encounter_id
        elsif obs.value_coded.to_i == 5953 && obs.value_coded_name_id == 4325
          a_hash[:symptom_present_blurry_vision] = 'Yes'
          a_hash[:symptom_present_blurry_vision_enc_id] = encounter.encounter_id
        end
      elsif obs.concept_id.to_i == 7755 #malawi_art_side_effects
        if obs.value_coded.to_i == 215 && obs.value_coded_name_id == 226
          obs_value = get_hiv_clinic_consultation_answer(obs.person_id.to_i, obs.encounter_id.to_i, obs.concept_id.to_i, obs.value_coded.to_i, obs.obs_datetime)
          a_hash[:side_effects_jaundice] = obs_value
          a_hash[:side_effects_jaundice_enc_id] = encounter.encounter_id
        elsif obs.value_coded.to_i == 3 && obs.value_coded_name_id == 3
          obs_value = get_hiv_clinic_consultation_answer(obs.person_id.to_i, obs.encounter_id.to_i, obs.concept_id.to_i, obs.value_coded.to_i, obs.obs_datetime)
          a_hash[:side_effects_anemia] = obs_value
          a_hash[:side_effects_anemia_enc_id] = encounter.encounter_id

        elsif obs.value_coded.to_i == 1458 && obs.value_coded_name_id == 1576
          obs_value = get_hiv_clinic_consultation_answer(obs.person_id.to_i, obs.encounter_id.to_i, obs.concept_id.to_i, obs.value_coded.to_i, obs.obs_datetime)
          a_hash[:side_effects_lactic_acidosis] = obs_value
          a_hash[:side_effects_lactic_acidosis_enc_id] = encounter.encounter_id

        elsif obs.value_coded.to_i == 5945 && obs.value_coded_name_id == 4315
          obs_value = get_hiv_clinic_consultation_answer(obs.person_id.to_i, obs.encounter_id.to_i, obs.concept_id.to_i, obs.value_coded.to_i, obs.obs_datetime)
          a_hash[:side_effects_fever] = obs_value
          a_hash[:side_effects_fever_enc_id] = encounter.encounter_id

        elsif obs.value_coded.to_i == 151 && obs.value_coded_name_id == 156
          obs_value = get_hiv_clinic_consultation_answer(obs.person_id.to_i, obs.encounter_id.to_i, obs.concept_id.to_i, obs.value_coded.to_i, obs.obs_datetime)
          a_hash[:side_effects_abdominal_pain] = obs_value
          a_hash[:side_effects_abdominal_pain_enc_id] = encounter.encounter_id

        elsif obs.value_coded.to_i == 868 && obs.value_coded_name_id == 888
          obs_value = get_hiv_clinic_consultation_answer(obs.person_id.to_i, obs.encounter_id.to_i, obs.concept_id.to_i, obs.value_coded.to_i, obs.obs_datetime)
          a_hash[:side_effects_anorexia] = obs_value
          a_hash[:side_effects_anorexia_enc_id] = encounter.encounter_id

        elsif obs.value_coded.to_i == 107 && obs.value_coded_name_id == 110
          obs_value = get_hiv_clinic_consultation_answer(obs.person_id.to_i, obs.encounter_id.to_i, obs.concept_id.to_i, obs.value_coded.to_i, obs.obs_datetime)
          a_hash[:side_effects_cough] = obs_value
          a_hash[:side_effects_cough_enc_id] = encounter.encounter_id

        elsif obs.value_coded.to_i == 16 && obs.value_coded_name_id == 17
          obs_value = get_hiv_clinic_consultation_answer(obs.person_id.to_i, obs.encounter_id.to_i, obs.concept_id.to_i, obs.value_coded.to_i, obs.obs_datetime)
          a_hash[:side_effects_diarrhea] = obs_value
          a_hash[:side_effects_diarrhea_enc_id] = encounter.encounter_id

        elsif obs.value_coded.to_i == 7952 && obs.value_coded_name_id == 10894
          obs_value = get_hiv_clinic_consultation_answer(obs.person_id.to_i, obs.encounter_id.to_i, obs.concept_id.to_i, obs.value_coded.to_i, obs.obs_datetime)
          a_hash[:side_effects_leg_pain_numbness] = obs_value
          a_hash[:side_effects_leg_pain_numbness_enc_id] = encounter.encounter_id

        elsif obs.value_coded.to_i == 5980 && obs.value_coded_name_id == 4355
          obs_value = get_hiv_clinic_consultation_answer(obs.person_id.to_i, obs.encounter_id.to_i, obs.concept_id.to_i, obs.value_coded.to_i, obs.obs_datetime)
          a_hash[:side_effects_vomiting] = obs_value
          a_hash[:side_effects_vomiting_enc_id] = encounter.encounter_id
        elsif obs.value_coded.to_i == 29 && obs.value_coded_name_id == 30
            obs_value = get_hiv_clinic_consultation_answer(obs.person_id.to_i, obs.encounter_id.to_i, obs.concept_id.to_i, obs.value_coded.to_i, obs.obs_datetime)
            a_hash[:side_effects_hepatitis] = obs_value
            a_hash[:side_effects_hepatitis_enc_id] = encounter.encounter_id
        elsif obs.value_coded.to_i == 219 && obs.value_coded_name_id == 231
          obs_value = get_hiv_clinic_consultation_answer(obs.person_id.to_i, obs.encounter_id.to_i, obs.concept_id.to_i, obs.value_coded.to_i, obs.obs_datetime)
          a_hash[:side_effects_psychosis] = obs_value
          a_hash[:side_effects_psychosis_enc_id] = encounter.encounter_id
        elsif obs.value_coded.to_i == 512 && obs.value_coded_name_id == 524
          obs_value = get_hiv_clinic_consultation_answer(obs.person_id.to_i, obs.encounter_id.to_i, obs.concept_id.to_i, obs.value_coded.to_i, obs.obs_datetime)
          a_hash[:side_effects_skin_rash] = obs_value
          a_hash[:side_effects_skin_rash_enc_id] = encounter.encounter_id
        elsif obs.value_coded.to_i == 821 && obs.value_coded_name_id == 838
          obs_value = get_hiv_clinic_consultation_answer(obs.person_id.to_i, obs.encounter_id.to_i, obs.concept_id.to_i, obs.value_coded.to_i, obs.obs_datetime)
          a_hash[:side_effects_peripheral_neuropathy] = obs_value
          a_hash[:side_effects_peripheral_neuropathy_enc_id] = encounter.encounter_id
        elsif obs.value_coded.to_i == 877 && obs.value_coded_name_id == 897
          obs_value = get_hiv_clinic_consultation_answer(obs.person_id.to_i, obs.encounter_id.to_i, obs.concept_id.to_i, obs.value_coded.to_i, obs.obs_datetime)
          a_hash[:side_effects_diziness] = obs_value
          a_hash[:side_effects_diziness_enc_id] = encounter.encounter_id
        elsif obs.value_coded.to_i == 1066 && obs.value_coded_name_id == 1103
          obs_value = get_hiv_clinic_consultation_answer(obs.person_id.to_i, obs.encounter_id.to_i, obs.concept_id.to_i, obs.value_coded.to_i, obs.obs_datetime)
          a_hash[:side_effects_no] = obs_value
          a_hash[:side_effects_no_enc_id] = encounter.encounter_id
        elsif obs.value_coded.to_i == 2148 && obs.value_coded_name_id == 2325
          obs_value = get_hiv_clinic_consultation_answer(obs.person_id.to_i, obs.encounter_id.to_i, obs.concept_id.to_i, obs.value_coded.to_i, obs.obs_datetime)
          a_hash[:side_effects_lipodystrophy] = obs_value
          a_hash[:side_effects_lipodystrophy_enc_id] = encounter.encounter_id
        elsif obs.value_coded.to_i == 2150 && obs.value_coded_name_id == 2328
          obs_value = get_hiv_clinic_consultation_answer(obs.person_id.to_i, obs.encounter_id.to_i, obs.concept_id.to_i, obs.value_coded.to_i, obs.obs_datetime)
          a_hash[:side_effects_nightmares] = obs_value
          a_hash[:side_effects_nightmares_enc_id] = encounter.encounter_id
        elsif obs.value_coded.to_i == 3681 && obs.value_coded_name_id == 5037
          obs_value = get_hiv_clinic_consultation_answer(obs.person_id.to_i, obs.encounter_id.to_i, obs.concept_id.to_i, obs.value_coded.to_i, obs.obs_datetime)
          a_hash[:side_effects_renal_failure] = obs_value
          a_hash[:side_effects_renal_failure_enc_id] = encounter.encounter_id
        elsif obs.value_coded.to_i == 5953 && obs.value_coded_name_id == 4325
          obs_value = get_hiv_clinic_consultation_answer(obs.person_id.to_i, obs.encounter_id.to_i, obs.concept_id.to_i, obs.value_coded.to_i, obs.obs_datetime)
          a_hash[:side_effects_blurry_vision] = obs_value
          a_hash[:side_effects_blurry_vision_enc_id] = encounter.encounter_id
        elsif obs.value_coded.to_i == 6408 && obs.value_coded_name_id == 8873
          obs_value = get_hiv_clinic_consultation_answer(obs.person_id.to_i, obs.encounter_id.to_i, obs.concept_id.to_i, obs.value_coded.to_i, obs.obs_datetime)
          a_hash[:side_effects_Other] = obs_value
          a_hash[:side_effects_Other_enc_id] = encounter.encounter_id
        elsif obs.value_coded.to_i == 9242 && obs.value_coded_name_id == 12434
          obs_value = get_hiv_clinic_consultation_answer(obs.person_id.to_i, obs.encounter_id.to_i, obs.concept_id.to_i, obs.value_coded.to_i, obs.obs_datetime)
          a_hash[:side_effects_kidney_failure] = obs_value
          a_hash[:side_effects_kidney_failure_enc_id] = encounter.encounter_id
        elsif obs.value_coded.to_i == 9440 && obs.value_coded_name_id == 12659
          obs_value = get_hiv_clinic_consultation_answer(obs.person_id.to_i, obs.encounter_id.to_i, obs.concept_id.to_i, obs.value_coded.to_i, obs.obs_datetime)
          a_hash[:side_effects_gynaecomastia] = obs_value
          a_hash[:side_effects_gynaecomastia_enc_id] = encounter.encounter_id
        end
      elsif obs.concept_id.to_i == 8012 #allergic to sulpher
        if obs.value_coded.to_i == 1065 && obs.value_coded_name_id == 1102
          a_hash[:allergic_to_sulphur] = 'Yes'
          a_hash[:allergic_to_sulphur_enc_id] = encounter.encounter_id
        elsif obs.value_coded.to_i == 1066 && obs.value_coded_name_id == 1103
          a_hash[:allergic_to_sulphur] = 'No'
          a_hash[:allergic_to_sulphur_enc_id] = encounter.encounter_id
        elsif obs.value_text
          if obs.value_text == 1065
            a_hash[:allergic_to_sulphur] = 'Yes'
            a_hash[:allergic_to_sulphur_enc_id] = encounter.encounter_id
          elsif obs.value_text == 1066
            a_hash[:allergic_to_sulphur] = 'No'
            a_hash[:allergic_to_sulphur_enc_id] = encounter.encounter_id
          end
        end
      elsif obs.concept_id.to_i == 7874 #prescribe arvs
        if obs.value_coded.to_i == 1065 && obs.value_coded_name_id == 1102
          a_hash[:prescribe_arvs] = 'Yes'
          a_hash[:prescribe_arvs_enc_id] = encounter.encounter_id
        elsif obs.value_coded.to_i == 1066 && obs.value_coded_name_id == 1103
          a_hash[:prescribe_arvs] = 'No'
          a_hash[:prescribe_arvs_enc_id] = encounter.encounter_id
        elsif obs.value_text
          if obs.value_text == 1065
            a_hash[:prescribe_arvs] = 'Yes'
            a_hash[:prescribe_arvs_enc_id] = encounter.encounter_id
          elsif obs.value_text == 1066
            a_hash[:prescribe_arvs] = 'No'
            a_hash[:prescribe_arvs_enc_id] = encounter.encounter_id
          end
        end
      elsif obs.concept_id.to_i == 656 #prescribe ipt
        if obs.value_coded.to_i == 1065 && obs.value_coded_name_id == 1102
          a_hash[:prescribe_ipt] = 'Yes'
          a_hash[:prescribe_ipt_enc_id] = encounter.encounter_id
        elsif obs.value_coded.to_i == 1066 && obs.value_coded_name_id == 1103
          a_hash[:prescribe_ipt] = 'No'
          a_hash[:prescribe_ipt_enc_id] = encounter.encounter_id
       elsif obs.value_text
          if obs.value_text == 1065
            a_hash[:prescribe_ipt] = 'Yes'
            a_hash[:prescribe_ipt_enc_id] = encounter.encounter_id
          elsif obs.value_text == 1066
            a_hash[:prescribe_ipt] = 'No'
            a_hash[:prescribe_ipt_enc_id] = encounter.encounter_id
          end
        end
      elsif obs.concept_id.to_i == 8259 #routine tb screening
	      if obs.value_coded.to_i == 5945 && obs.value_coded_name_id == 4315
          obs_value = get_hiv_clinic_consultation_answer(obs.person_id.to_i, obs.encounter_id.to_i, obs.concept_id.to_i, obs.value_coded.to_i, obs.obs_datetime)
		      a_hash[:routine_tb_screening_fever] = obs_value
		      a_hash[:routine_tb_screening_fever_enc_id] = encounter.encounter_id
	      elsif obs.value_coded.to_i == 6029 && obs.value_coded_name_id == 4407
          obs_value = get_hiv_clinic_consultation_answer(obs.person_id.to_i, obs.encounter_id.to_i, obs.concept_id.to_i, obs.value_coded.to_i, obs.obs_datetime)
		      a_hash[:routine_tb_screening_night_sweats] = obs_value
          a_hash[:routine_tb_screening_night_sweats_enc_id] = encounter.encounter_id
	      elsif obs.value_coded.to_i == 8261 && obs.value_coded_name_id == 11335
          obs_value = get_hiv_clinic_consultation_answer(obs.person_id.to_i, obs.encounter_id.to_i, obs.concept_id.to_i, obs.value_coded.to_i, obs.obs_datetime)
		      a_hash[:routine_tb_screening_cough_of_any_duration] = obs_value
          a_hash[:routine_tb_screening_cough_of_any_duration_enc_id] = encounter.encounter_id
	      elsif obs.value_coded.to_i == 8260 && obs.value_coded_name_id == 11333
          obs_value = get_hiv_clinic_consultation_answer(obs.person_id.to_i, obs.encounter_id.to_i, obs.concept_id.to_i, obs.value_coded.to_i, obs.obs_datetime)
		      a_hash[:routine_tb_screening_weight_loss_failure] = obs_value
          a_hash[:routine_tb_screening_weight_loss_failure_enc_id] = encounter.encounter_id
	      end

      elsif obs.concept_id.to_i == 7567 #drug induced symptoms
        a_hash[:side_effects_present] = 'Yes'
        a_hash[:side_effects_present_enc_id] = encounter.encounter_id
        if obs.value_coded.to_i == 2148 && obs.value_coded_name_id == 2325
          a_hash[:drug_induced_lipodystrophy] = 'Yes'
          a_hash[:drug_induced_lipodystrophy_enc_id] = encounter.encounter_id
        elsif obs.value_coded.to_i == 3 && obs.value_coded_name_id == 3
          a_hash[:drug_induced_anemia] = 'Yes'
          a_hash[:drug_induced_anemia_enc_id] = encounter.encounter_id
        elsif obs.value_coded.to_i == 215 && obs.value_coded_name_id == 226
          a_hash[:drug_induced_jaundice] = 'Yes'
          a_hash[:drug_induced_jaundice_enc_id] = encounter.encounter_id
        elsif obs.value_coded.to_i == 1458 && obs.value_coded_name_id == 1576
          a_hash[:drug_induced_lactic_acidosis] = 'Yes'
          a_hash[:drug_induced_lactic_acidosis_enc_id] = encounter.encounter_id
        elsif obs.value_coded.to_i == 5945 && obs.value_coded_name_id == 4315
          a_hash[:drug_induced_fever] = 'Yes'
          a_hash[:drug_induced_fever_enc_id] = encounter.encounter_id
        elsif obs.value_coded.to_i == 512 && obs.value_coded_name_id == 524
          a_hash[:drug_induced_skin_rash] = 'Yes'
          a_hash[:drug_induced_skin_rash_enc_id] = encounter.encounter_id
        elsif obs.value_coded.to_i == 151 && obs.value_coded_name_id == 156
          a_hash[:drug_induced_abdominal_pain] = 'Yes'
          a_hash[:drug_induced_abdominal_pain_enc_id] = encounter.encounter_id
        elsif obs.value_coded.to_i == 868 && obs.value_coded_name_id == 888
          a_hash[:drug_induced_anorexia] = 'Yes'
          a_hash[:drug_induced_anorexia_enc_id] = encounter.encounter_id
        elsif obs.value_coded.to_i == 107 && obs.value_coded_name_id == 110
          a_hash[:drug_induced_cough] = 'Yes'
          a_hash[:drug_induced_cough_enc_id] = encounter.encounter_id
        elsif obs.value_coded.to_i == 16 && obs.value_coded_name_id == 17
		      a_hash[:drug_induced_diarrhea] = 'Yes'
          a_hash[:drug_induced_diarrhea_enc_id] = encounter.encounter_id
        elsif obs.value_coded.to_i == 7952 && obs.value_coded_name_id == 10894
          a_hash[:drug_induced_leg_pain_numbness] = 'Yes'
          a_hash[:drug_induced_leg_pain_numbness_enc_id] = encounter.encounter_id
        elsif obs.value_coded.to_i == 821 && obs.value_coded_name_id == 838
          a_hash[:drug_induced_peripheral_neuropathy] = 'Yes'
          a_hash[:drug_induced_peripheral_neuropathy_enc_id] = encounter.encounter_id
        elsif obs.value_coded.to_i == 5980 && obs.value_coded_name_id == 4355
          a_hash[:drug_induced_vomiting] = 'Yes'
          a_hash[:drug_induced_vomiting_enc_id] = encounter.encounter_id
        elsif obs.value_coded.to_i == 6779 && obs.value_coded_name_id == 4355
          a_hash[:drug_induced_other] = 'Yes'
          a_hash[:drug_induced_other_enc_id] = encounter.encounter_id
        elsif obs.value_coded.to_i == 29 && obs.value_coded_name_id == 30
          a_hash[:drug_induced_hepatitis] = 'Yes'
          a_hash[:drug_induced_hepatitis_enc_id] = encounter.encounter_id
        elsif obs.value_coded.to_i == 9242 && obs.value_coded_name_id == 12434
          a_hash[:drug_induced_kidney_failure] = 'Yes'
          a_hash[:drug_induced_kidney_failure_enc_id] = encounter.encounter_id
        elsif obs.value_coded.to_i == 2150 && obs.value_coded_name_id == 2328
          a_hash[:drug_induced_nightmares] = 'Yes'
          a_hash[:drug_induced_nightmares_enc_id] = encounter.encounter_id
        elsif obs.value_coded.to_i == 877 && obs.value_coded_name_id == 897
          a_hash[:drug_induced_diziness] = 'Yes'
          a_hash[:drug_induced_diziness_enc_id] = encounter.encounter_id
        elsif obs.value_coded.to_i == 219 && obs.value_coded_name_id == 231
          a_hash[:drug_induced_psychosis] = 'Yes'
          a_hash[:drug_induced_psychosis_enc_id] = encounter.encounter_id
        elsif obs.value_coded.to_i == 5953 && obs.value_coded_name_id == 4325
          a_hash[:drug_induced_blurry_vision] = 'Yes'
          a_hash[:drug_induced_blurry_vision_enc_id] = encounter.encounter_id
        end
     	end
    end

    return generate_sql_string(a_hash)
end

def get_hiv_clinic_consultation_answer(obs_person_id, obs_encounter_id, obs_concept_id, obs_value_coded, obs_obs_datetime)
  #check if value_coded is saved as concept_id
  patient_value = []

  Encounter.find_by_sql("
          SELECT o.obs_id, o.person_id, o.encounter_id, o.obs_datetime, o.value_coded, o.voided
          FROM #{@source_db}.obs o
          WHERE encounter_id = #{obs_encounter_id} AND o.concept_id = #{obs_value_coded}
          AND DATE(obs_datetime) = '#{obs_obs_datetime.to_date.strftime'%Y-%m-%d'}' AND person_id = #{obs_person_id}
          lIMIT 1").each{|obs| patient_value << obs.value_coded}

  unless patient_value.blank?
    answer = ConceptName.find_by_concept_id(patient_value.first).name
  else
    answer = 'Yes'
  end

  return answer
end

def process_hiv_clinic_registration_encounter(encounter, type = 0) #type 0 normal encounter, 1 generate_template only

  #initialize field and values variables
  fields = ""
  values = ""

  #create hiv_clinic_registration field list hash template

  a_hash = {:date_created => 'NULL'}

  return generate_sql_string(a_hash) if type == 1

  (encounter || []).each do | obs |
    if obs.concept_id.to_i == 8011 #send_sms
      ans_registration = ""
      if obs.value_coded
        ans_registration = obs.to_s.split(':')[1].strip rescue nil
      else
        if obs.value_text == '1065'
          ans_registration = 'Yes'
        elsif obs.value_text == '1066'
          ans_registration = 'No'
        elsif obs.value_text == '1067'
          ans_registration = 'Unknown'
        end
      end
      a_hash[:send_sms] = ans_registration rescue nil
      a_hash[:send_sms_enc_id] = obs.encounter_id
      a_hash[:send_sms_v_date] = obs.obs_datetime.to_date rescue nil

    elsif obs.concept_id.to_i == 2552 #FOLLOW UP AGREEMENT
      ans_registration = ""
      if obs.value_coded
        ans_registration = obs.to_s.split(':')[1].strip rescue nil
      else
        if obs.value_text == '1065'
          ans_registration = 'Yes'
        elsif obs.value_text == '1066'
          ans_registration = 'No'
        elsif obs.value_text == '1067'
          ans_registration = 'Unknown'
        end
      end
      a_hash[:agrees_to_followup] = ans_registration rescue nil
      a_hash[:agrees_to_followup_enc_id] = obs.encounter_id
      a_hash[:agrees_to_followup_v_date] = obs.obs_datetime.to_date rescue nil

    elsif obs.concept_id.to_i == 7882 #CONFIRMATORY HIV TEST DATE
      a_hash[:confirmatory_hiv_test_date] = obs.value_datetime.to_date rescue nil
      a_hash[:confirmatory_hiv_test_date_enc_id] = obs.encounter_id
      a_hash[:confirmatory_hiv_test_date_v_date] = obs.obs_datetime.to_date rescue nil
    elsif obs.concept_id.to_i == 7881 #CONFIRMATORY HIV TEST LOCATION
     if obs.value_text
       conf_loc_name = Location.find_by_location_id(obs.value_text.to_i).name rescue nil
       if conf_loc_name
         a_hash[:confirmatory_hiv_test_location] = conf_loc_name rescue nil
         a_hash[:confirmatory_hiv_test_location_enc_id] = obs.encounter_id
         a_hash[:confirmatory_hiv_test_location_v_date] = obs.obs_datetime.to_date rescue nil
       else
         a_hash[:confirmatory_hiv_test_location] = obs.value_text.to_s rescue nil
         a_hash[:confirmatory_hiv_test_location_enc_id] = obs.encounter_id
         a_hash[:confirmatory_hiv_test_location_v_date] = obs.obs_datetime.to_date rescue nil
       end
     else
      hiv_location = Location.find_by_location_id(obs.value_numeric).name rescue nil
      a_hash[:confirmatory_hiv_test_location] = hiv_location rescue nil
      a_hash[:confirmatory_hiv_test_location_enc_id] = obs.encounter_id
      a_hash[:confirmatory_hiv_test_location_v_date] = obs.obs_datetime.to_date rescue nil
     end
    elsif obs.concept_id.to_i == 7750 #LOCATION OF ART INITIATION
      if obs.value_text
        loc_of_art = Location.find_by_location_id(obs.value_text.to_i).name rescue nil
        if loc_of_art
         a_hash[:location_of_art_initialization] = loc_of_art rescue nil
         a_hash[:location_of_art_initialization_enc_id] = obs.encounter_id
         a_hash[:location_of_art_initialization_v_date] = obs.obs_datetime.to_date rescue nil
        else
         a_hash[:location_of_art_initialization] = obs.value_text.to_s rescue nil
         a_hash[:location_of_art_initialization_enc_id] = obs.encounter_id
         a_hash[:location_of_art_initialization_v_date] = obs.obs_datetime.to_date rescue nil
        end
       else
        art_location = Location.find_by_location_id(obs.value_numeric).name rescue nil
        a_hash[:location_of_art_initialization] = art_location rescue nil
        a_hash[:location_of_art_initialization_enc_id] = obs.encounter_id
        a_hash[:location_of_art_initialization_v_date] = obs.obs_datetime.to_date rescue nil
      end

    elsif obs.concept_id.to_i == 7752 #HAS THE PATIENT TAKEN ART IN THE LAST TWO MONTHS
      ans_registration = ""
      if obs.value_coded
        ans_registration = obs.to_s.split(':')[1].strip rescue nil
      else
        if obs.value_text == '1065'
          ans_registration = 'Yes'
        elsif obs.value_text == '1066'
          ans_registration = 'No'
        elsif obs.value_text == '1067'
          ans_registration = 'Unknown'
        end
      end
      a_hash[:taken_art_in_last_two_months] = ans_registration rescue nil
      a_hash[:taken_art_in_last_two_months_enc_id] = obs.encounter_id
      a_hash[:taken_art_in_last_two_months_v_date] = obs.obs_datetime.to_date rescue nil

    elsif obs.concept_id.to_i == 7880 #Confirmatory HIV Test Type
      a_hash[:type_of_confirmatory_hiv_test] = obs.to_s.split(':')[1].squish rescue nil
      a_hash[:type_of_confirmatory_hiv_test_enc_id] = obs.encounter_id
      a_hash[:type_of_confirmatory_hiv_test_v_date] = obs.obs_datetime.to_date rescue nil

    elsif obs.concept_id.to_i == 6394 #HAS THE PATIENT TAKEN ART IN THE LAST TWO WEEKS
      ans_registration = ""
      if obs.value_coded
        ans_registration = obs.to_s.split(':')[1].strip rescue nil
      else
        if obs.value_text == '1065'
          ans_registration = 'Yes'
        elsif obs.value_text == '1066'
          ans_registration = 'No'
        elsif obs.value_text == '1067'
          ans_registration = 'Unknown'
        end
      end
      a_hash[:taken_art_in_last_two_weeks] = ans_registration rescue nil
      a_hash[:taken_art_in_last_two_weeks_enc_id] = obs.encounter_id
      a_hash[:taken_art_in_last_two_weeks_v_date] = obs.obs_datetime.to_date rescue nil

    elsif obs.concept_id.to_i == 6393 #HAS TRANSFER LETTER
      ans_registration = ""
      if obs.value_coded
        ans_registration = obs.to_s.split(':')[1].strip rescue nil
      else
        if obs.value_text == '1065'
          ans_registration = 'Yes'
        elsif obs.value_text == '1066'
          ans_registration = 'No'
        elsif obs.value_text == '1067'
          ans_registration = 'Unknown'
        end
      end
      a_hash[:has_transfer_letter] = ans_registration rescue nil
      a_hash[:has_transfer_letter_enc_id] = obs.encounter_id
      a_hash[:has_transfer_letter_v_date] = obs.obs_datetime.to_date rescue nil

    elsif obs.concept_id.to_i == 2516 #DATE ANTIRETROVIRALS STARTED
      a_hash[:date_started_art] = obs.value_datetime.to_date rescue nil
      a_hash[:date_started_art_enc_id] = obs.encounter_id
      a_hash[:date_started_art_v_date] = obs.obs_datetime.to_date rescue nil

    elsif obs.concept_id.to_i == 7937 #EVER REGISTERED AT ART CLINIC
      ans_registration = ""
      if obs.value_coded
        ans_registration = obs.to_s.split(':')[1].strip rescue nil
      else
        if obs.value_text == '1065'
          ans_registration = 'Yes'
        elsif obs.value_text == '1066'
          ans_registration = 'No'
        elsif obs.value_text == '1067'
          ans_registration = 'Unknown'
        end
      end
      a_hash[:ever_registered_at_art_clinic] = ans_registration rescue nil
      a_hash[:ever_registered_at_art_clinic_enc_id] = obs.encounter_id
      a_hash[:ever_registered_at_art_clinic_v_date] = obs.obs_datetime.to_date rescue nil

    elsif obs.concept_id.to_i == 7754 #EVER RECEIVED ART?
      ans_registration = ""
      if obs.value_coded
        ans_registration = obs.to_s.split(':')[1].strip rescue nil
      else
        if obs.value_text == '1065'
          ans_registration = 'Yes'
        elsif obs.value_text == '1066'
          ans_registration = 'No'
        elsif obs.value_text == '1067'
          ans_registration = 'Unknown'
        end
      end
      a_hash[:ever_received_art] = ans_registration rescue nil
      a_hash[:ever_received_art_enc_id] = obs.encounter_id
      a_hash[:ever_received_art_v_date] = obs.obs_datetime.to_date rescue nil

    elsif obs.concept_id.to_i == 7753 #LAST ART DRUGS TAKEN
      last_drug = ""
      if obs.value_coded
        last_drug = obs.to_s.split(':')[1].strip rescue nil
      elsif obs.value_text
        last_drug = Drug.find_by_concept_id(obs.value_text).name rescue nil
      end
      a_hash[:last_art_drugs_taken] = last_drug rescue nil
      a_hash[:last_art_drugs_taken_enc_id] = obs.encounter_id
      a_hash[:last_art_drugs_taken_v_date] = obs.obs_datetime.to_date rescue nil

    elsif obs.concept_id.to_i == 7751 #DATE ART LAST TAKEN
      a_hash[:date_art_last_taken] = obs.value_datetime.to_date rescue nil
      a_hash[:date_art_last_taken_enc_id] = obs.encounter_id
      a_hash[:date_art_last_taken_v_date] = obs.obs_datetime.to_date rescue nil
    else
      process_hiv_staging_encounter(encounter, type = 0)
    end
  end

  return generate_sql_string(a_hash)
end

def process_hiv_staging_encounter(encounter, type = 0) #type 0 normal encounter, 1 generate_template only
  #initialize field and values variables
  fields = ""
  values = ""
  #create hiv_staging field list hash template
  a_hash = {
            :creator => 'NULL'
          }

  return generate_sql_string(a_hash) if type == 1

  (encounter || []).each do | obs |
    reason_for_starting = ""

    reason_for_starting_concept_id = Encounter.find_by_sql("SELECT patient_reason_for_starting_art(#{obs.person_id.to_i}) AS reason_for_starting_art").map(&:reason_for_starting_art).first
    unless reason_for_starting_concept_id.blank?
      reason_for_starting = ConceptName.find_by_concept_id(reason_for_starting_concept_id.to_i).name
    end

    a_hash[:reason_for_eligibility] = reason_for_starting rescue nil
    a_hash[:reason_for_eligibility_v_date] = obs.obs_datetime.to_date rescue nil
    a_hash[:reason_for_eligibility_enc_id] = obs.encounter_id rescue nil

    if obs.concept_id.to_i == 6131 #Patient Pregnant
      if !obs.value_coded.blank?
        if obs.value_coded.to_i == 1065 && obs.value_coded_name_id == 1102
          a_hash[:patient_pregnant] = 'Yes'
          a_hash[:patient_pregnant_enc_id] = obs.encounter_id
          a_hash[:patient_pregnant_v_date] = obs.obs_datetime.to_date
        elsif obs.value_coded.to_i == 1066 && obs.value_coded_name_id == 1103
          a_hash[:patient_pregnant] = 'No'
          a_hash[:patient_pregnant_enc_id] = obs.encounter_id
          a_hash[:patient_pregnant_v_date] = obs.obs_datetime.to_date
        elsif obs.value_coded.to_i == 1067 && obs.value_coded_name_id == 1104
          a_hash[:patient_pregnant] = 'Unknown'
          a_hash[:patient_pregnant_enc_id] = obs.encounter_id
          a_hash[:patient_pregnant_v_date] = obs.obs_datetime.to_date
        end
      else
        if obs.value_text == '1065'
          a_hash[:patient_pregnant] = 'Yes'
          a_hash[:patient_pregnant_enc_id] = obs.encounter_id
          a_hash[:patient_pregnant_v_date] = obs.obs_datetime.to_date
        elsif obs.value_text == '1066'
          a_hash[:patient_pregnant] = 'No'
          a_hash[:patient_pregnant_enc_id] = obs.encounter_id
          a_hash[:patient_pregnant_v_date] = obs.obs_datetime.to_date
        elsif obs.value_text == '1067'
          a_hash[:patient_pregnant] = 'Unknown'
          a_hash[:patient_pregnant_enc_id] = obs.encounter_id
          a_hash[:patient_pregnant_v_date] = obs.obs_datetime.to_date
        end
      end
    elsif obs.concept_id.to_i == 7972 #Patient Pregnant at initiation
      if !obs.value_coded.blank?
        if obs.value_coded.to_i == 1065 && obs.value_coded_name_id == 1102
          a_hash[:pregnant_at_initiation] = 'Yes'
          a_hash[:pregnant_at_initiation_enc_id] = obs.encounter_id
          a_hash[:pregnant_at_initiation_v_date] = obs.obs_datetime.to_date
        elsif obs.value_coded.to_i == 1066 && obs.value_coded_name_id == 1103
          a_hash[:pregnant_at_initiation] = 'No'
          a_hash[:pregnant_at_initiation_enc_id] = obs.encounter_id
          a_hash[:pregnant_at_initiation_v_date] = obs.obs_datetime.to_date
        elsif obs.value_coded.to_i == 1067 && obs.value_coded_name_id == 1104
          a_hash[:pregnant_at_initiation] = 'Unknown'
          a_hash[:pregnant_at_initiation_enc_id] = obs.encounter_id
          a_hash[:pregnant_at_initiation_v_date] = obs.obs_datetime.to_date
        end
      else
        if obs.value_text == '1065'
          a_hash[:pregnant_at_initiation] = 'Yes'
          a_hash[:pregnant_at_initiation_enc_id] = obs.encounter_id
          a_hash[:pregnant_at_initiation_v_date] = obs.obs_datetime.to_date
        elsif obs.value_text == '1066'
          a_hash[:pregnant_at_initiation] = 'No'
          a_hash[:pregnant_at_initiation_enc_id] = obs.encounter_id
          a_hash[:pregnant_at_initiation_v_date] = obs.obs_datetime.to_date
        elsif obs.value_text == '1067'
          a_hash[:pregnant_at_initiation] = 'Unknown'
          a_hash[:pregnant_at_initiation_enc_id] = obs.encounter_id
          a_hash[:pregnant_at_initiation_v_date] = obs.obs_datetime.to_date
        end
      end
    elsif obs.concept_id.to_i == 1755 #Patient Pregnant
      if !obs.value_coded.blank?
        if obs.value_coded.to_i == 1065 && obs.value_coded_name_id == 1102
          a_hash[:patient_pregnant] = 'Yes'
          a_hash[:patient_pregnant_enc_id] = obs.encounter_id
          a_hash[:patient_pregnant_v_date] = obs.obs_datetime.to_date
        elsif obs.value_coded.to_i == 1066 && obs.value_coded_name_id == 1103
          a_hash[:patient_pregnant] = 'No'
          a_hash[:patient_pregnant_enc_id] = obs.encounter_id
          a_hash[:patient_pregnant_v_date] = obs.obs_datetime.to_date
        elsif obs.value_coded.to_i == 1067 && obs.value_coded_name_id == 1104
          a_hash[:patient_pregnant] = 'Unknown'
          a_hash[:patient_pregnant_enc_id] = obs.encounter_id
          a_hash[:patient_pregnant_v_date] = obs.obs_datetime.to_date
        end
      else
        if obs.value_text == '1065'
          a_hash[:patient_pregnant] = 'Yes'
          a_hash[:patient_pregnant_enc_id] = obs.encounter_id
          a_hash[:patient_pregnant_v_date] = obs.obs_datetime.to_date
        elsif obs.value_text == '1066'
          a_hash[:patient_pregnant] = 'No'
          a_hash[:patient_pregnant_enc_id] = obs.encounter_id
          a_hash[:patient_pregnant_v_date] = obs.obs_datetime.to_date
        elsif obs.value_text == '1067'
          a_hash[:patient_pregnant] = 'Unknown'
          a_hash[:patient_pregnant_enc_id] = obs.encounter_id
          a_hash[:patient_pregnant_v_date] = obs.obs_datetime.to_date
        end
      end
    elsif obs.concept_id.to_i == 7965 #breastfeeding
      if !obs.value_coded.blank?
        if obs.value_coded.to_i == 1065 && obs.value_coded_name_id == 1102
          a_hash[:patient_breastfeeding] = 'Yes'
          a_hash[:patient_breastfeeding_enc_id] = obs.encounter_id
          a_hash[:patient_breastfeeding_v_date] = obs.obs_datetime.to_date
        elsif obs.value_coded.to_i == 1066 && obs.value_coded_name_id == 1103
          a_hash[:patient_breastfeeding] = 'No'
          a_hash[:patient_breastfeeding_enc_id] = obs.encounter_id
          a_hash[:patient_breastfeeding_v_date] = obs.obs_datetime.to_date
        elsif obs.value_coded.to_i == 1067 && obs.value_coded_name_id == 1104
          a_hash[:patient_breastfeeding] = 'Unknown'
          a_hash[:patient_breastfeeding_enc_id] = obs.encounter_id
          a_hash[:patient_breastfeeding_v_date] = obs.obs_datetime.to_date
        end
      else
        if obs.value_text == '1065'
          a_hash[:patient_breastfeeding] = 'Yes'
          a_hash[:patient_breastfeeding_enc_id] = obs.encounter_id
          a_hash[:patient_breastfeeding_v_date] = obs.obs_datetime.to_date
        elsif obs.value_text == '1066'
          a_hash[:patient_breastfeeding] = 'No'
          a_hash[:patient_breastfeeding_enc_id] = obs.encounter_id
          a_hash[:patient_breastfeeding_v_date] = obs.obs_datetime.to_date
        elsif obs.value_text == '1067'
          a_hash[:patient_breastfeeding] = 'Unknown'
          a_hash[:patient_breastfeeding_enc_id] = obs.encounter_id
          a_hash[:patient_breastfeeding_v_date] = obs.obs_datetime.to_date
        end
      end
    elsif obs.concept_id.to_i == 9099 #cd4 count location
      if obs.value_text
        cd4_count_loc = Location.find_by_location_id(obs.value_text.to_i).name rescue nil
       if cd4_count_loc
         a_hash[:cd4_count_location] = cd4_count_loc rescue nil
         a_hash[:cd4_count_location_enc_id] = obs.encounter_id
         a_hash[:cd4_count_location_v_date] = obs.obs_datetime.to_date
       else
         a_hash[:cd4_count_location] = obs.value_text.to_s rescue nil
         a_hash[:cd4_count_location_enc_id] = obs.encounter_id
         a_hash[:cd4_count_location_v_date] = obs.obs_datetime.to_date
       end
      else
        cd4_location = Location.find_by_location_id(obs.value_numeric).name rescue nil
        a_hash[:cd4_count_location] = cd4_location rescue nil
        a_hash[:cd4_count_location_enc_id] = obs.encounter_id
        a_hash[:cd4_count_location_v_date] = obs.obs_datetime.to_date
      end

    elsif obs.concept_id.to_i == 5497 #cd4_count
      a_hash[:cd4_count] = obs.value_numeric.to_i rescue nil
      a_hash[:cd4_count_enc_id] = obs.encounter_id
      a_hash[:cd4_count_v_date] = obs.obs_datetime.to_date
    elsif obs.concept_id.to_i == 9098 #cd4_count_modifier
      a_hash[:cd4_count_modifier] = obs.to_s.split(':')[1].strip rescue nil
      a_hash[:cd4_count_modifier_enc_id] = obs.encounter_id
      a_hash[:cd4_count_modifier_v_date] = obs.obs_datetime.to_date
    elsif obs.concept_id.to_i == 730 #cd4_count_percent
      a_hash[:cd4_count_percent] = obs.to_s.split(':')[1].strip rescue nil
      a_hash[:cd4_count_percent_enc_id] = obs.encounter_id
      a_hash[:cd4_count_percent_v_date] = obs.obs_datetime.to_date
    elsif obs.concept_id.to_i == 6831 #cd4_count_datetime
      a_hash[:cd4_count_datetime] = obs.value_datetime.to_date rescue nil
      a_hash[:cd4_count_datetime_enc_id] = obs.encounter_id
      a_hash[:cd4_count_datetime_v_date] = obs.obs_datetime.to_date

    elsif (obs.value_coded == 5006) #asymptomatic
      if (obs.value_text == '1065' || obs.value_coded == 1065)
        a_hash[:asymptomatic] = 'Yes'
        a_hash[:asymptomatic_enc_id] = obs.encounter_id
        a_hash[:asymptomatic_v_date] = obs.obs_datetime.to_date
      elsif (obs.value_text == '1065' || obs.value_coded == 1066)
        a_hash[:asymptomatic] = 'No'
        a_hash[:asymptomatic_enc_id] = obs.encounter_id
        a_hash[:asymptomatic_v_date] = obs.obs_datetime.to_date
      elsif (obs.value_text == '1067' || obs.value_coded == 1067)
        a_hash[:asymptomatic] = 'Unknown'
        a_hash[:asymptomatic_enc_id] = obs.encounter_id
        a_hash[:asymptomatic_v_date] = obs.obs_datetime.to_date
      end
=begin
    elsif obs.concept_id.to_i == 7563 #reason_for_starting_art
      reason_for_starting = ""

      reason_for_starting_concept_id = Encounter.find_by_sql("SELECT patient_reason_for_starting_art(#{obs.person_id.to_i}) AS reason_for_starting_art").map(&:reason_for_starting_art).first
      puts "am the reason #{reason_for_starting_concept_id}"
      unless reason_for_starting_concept_id.blank?
        reason_for_starting = ConceptName.find_by_concept_id(reason_for_starting_concept_id.to_i).name
      end


      if obs.value_coded
        reason_for_starting = obs.to_s.split(':')[1].strip rescue nil
        if reason_for_starting.blank?
          reason_for_starting = ConceptName.find_by_concept_id(obs.value_coded_name_id.to_i).name rescue nil
        else
          reason_for_starting = ConceptName.find_by_concept_id(obs.value_coded.to_i).name rescue nil
        end
      elsif obs.value_text
        reason_for_starting = ConceptName.find_by_concept_id(obs.value_text) rescue nil
      end

      a_hash[:reason_for_eligibility] = reason_for_starting rescue nil
      a_hash[:reason_for_eligibility_v_date] = obs.obs_datetime.to_date rescue nil
      a_hash[:reason_for_eligibility_enc_id] = obs.encounter_id rescue nil
=end
    elsif obs.concept_id.to_i == 7562 #who_stage
      a_hash[:who_stage] = obs.to_s.split(':')[1].strip rescue nil
      a_hash[:who_stage_enc_id] = obs.encounter_id
      a_hash[:who_stage_v_date] = obs.obs_datetime.to_date

    elsif (obs.concept_id.to_i == 5328) #persistent_generalized_lymphadenopathy
      ans_staging = ""
        if (obs.value_text == '1065' || obs.value_coded == 1065)
          a_hash[:persistent_generalized_lymphadenopathy] = 'Yes'
          a_hash[:persistent_generalized_lymphadenopathy_enc_id] = obs.encounter_id
          a_hash[:persistent_generalized_lymphadenopathy_v_date] = obs.obs_datetime.to_date
        elsif (obs.value_text == '1065' || obs.value_coded == 1066)
          a_hash[:persistent_generalized_lymphadenopathy] = 'No'
          a_hash[:persistent_generalized_lymphadenopathy_enc_id] = obs.encounter_id
          a_hash[:persistent_generalized_lymphadenopathy_v_date] = obs.obs_datetime.to_date
        elsif (obs.value_text == '1067' || obs.value_coded == 1067)
          a_hash[:persistent_generalized_lymphadenopathy] = 'Unknown'
          a_hash[:persistent_generalized_lymphadenopathy_enc_id] = obs.encounter_id
          a_hash[:persistent_generalized_lymphadenopathy_v_date] = obs.obs_datetime.to_date
        end

    elsif  (obs.concept_id.to_i == 6757) #unspecified_stage_1_cond
        if (obs.value_text == '1065' || obs.value_coded == 1065)
          a_hash[:unspecified_stage_1_cond] = 'Yes'
          a_hash[:unspecified_stage_1_cond_enc_id] = obs.encounter_id
          a_hash[:unspecified_stage_1_cond_v_date] = obs.obs_datetime.to_date
        elsif (obs.value_text == '1065' || obs.value_coded == 1066)
          a_hash[:unspecified_stage_1_cond] = 'No'
          a_hash[:unspecified_stage_1_cond_enc_id] = obs.encounter_id
          a_hash[:unspecified_stage_1_cond_v_date] = obs.obs_datetime.to_date
        elsif (obs.value_text == '1067' || obs.value_coded == 1067)
          a_hash[:unspecified_stage_1_cond] = 'Unknown'
          a_hash[:unspecified_stage_1_cond_enc_id] = obs.encounter_id
          a_hash[:unspecified_stage_1_cond_v_date] = obs.obs_datetime.to_date
        end

    elsif (obs.concept_id.to_i == 1212) #molluscumm_contagiosum
        if (obs.value_text == '1065' || obs.value_coded == 1065)
          a_hash[:molluscumm_contagiosum] = 'Yes'
          a_hash[:molluscumm_contagiosum_enc_id] = obs.encounter_id
          a_hash[:molluscumm_contagiosum_v_date] = obs.obs_datetime.to_date
        elsif (obs.value_text == '1065' || obs.value_coded == 1066)
          a_hash[:molluscumm_contagiosum] = 'No'
          a_hash[:molluscumm_contagiosum_enc_id] = obs.encounter_id
          a_hash[:molluscumm_contagiosum_v_date] = obs.obs_datetime.to_date
        elsif (obs.value_text == '1067' || obs.value_coded == 1067)
          a_hash[:molluscumm_contagiosum] = 'Unknown'
          a_hash[:molluscumm_contagiosum_enc_id] = obs.encounter_id
          a_hash[:molluscumm_contagiosum_v_date] = obs.obs_datetime.to_date
        end

    elsif (obs.concept_id.to_i == 6775) #wart_virus_infection_extensive
        if (obs.value_text == '1065' || obs.value_coded == 1065)
          a_hash[:wart_virus_infection_extensive] = 'Yes'
          a_hash[:wart_virus_infection_extensive_enc_id] = obs.encounter_id
          a_hash[:wart_virus_infection_extensive_v_date] = obs.obs_datetime.to_date
        elsif (obs.value_text == '1065' || obs.value_coded == 1066)
          a_hash[:wart_virus_infection_extensive] = 'No'
          a_hash[:wart_virus_infection_extensive_enc_id] = obs.encounter_id
          a_hash[:wart_virus_infection_extensive_v_date] = obs.obs_datetime.to_date
        elsif (obs.value_text == '1067' || obs.value_coded == 1067)
          a_hash[:wart_virus_infection_extensive] = 'Unknown'
          a_hash[:wart_virus_infection_extensive_enc_id] = obs.encounter_id
          a_hash[:wart_virus_infection_extensive_v_date] = obs.obs_datetime.to_date
        end

    elsif (obs.concept_id.to_i == 2576) #oral_ulcerations_recurrent
        if (obs.value_text == '1065' || obs.value_coded == 1065)
          a_hash[:oral_ulcerations_recurrent] = 'Yes'
          a_hash[:oral_ulcerations_recurrent_enc_id] = obs.encounter_id
          a_hash[:oral_ulcerations_recurrent_v_date] = obs.obs_datetime.to_date
        elsif (obs.value_text == '1065' || obs.value_coded == 1066)
          a_hash[:oral_ulcerations_recurrent] = 'No'
          a_hash[:oral_ulcerations_recurrent_enc_id] = obs.encounter_id
          a_hash[:oral_ulcerations_recurrent_v_date] = obs.obs_datetime.to_date
        elsif (obs.value_text == '1067' || obs.value_coded == 1067)
          a_hash[:oral_ulcerations_recurrent] = 'Unknown'
          a_hash[:oral_ulcerations_recurrent_enc_id] = obs.encounter_id
          a_hash[:oral_ulcerations_recurrent_v_date] = obs.obs_datetime.to_date
        end

    elsif (obs.concept_id.to_i == 1210) #parotid_enlargement_persistent_unexplained
        if (obs.value_text == '1065' || obs.value_coded == 1065)
          a_hash[:parotid_enlargement_persistent_unexplained] = 'Yes'
          a_hash[:parotid_enlargement_persistent_unexplained_enc_id] = obs.encounter_id
          a_hash[:parotid_enlargement_persistent_unexplained_v_date] = obs.obs_datetime.to_date
        elsif (obs.value_text == '1065' || obs.value_coded == 1066)
          a_hash[:parotid_enlargement_persistent_unexplained] = 'No'
          a_hash[:parotid_enlargement_persistent_unexplained_enc_id] = obs.encounter_id
          a_hash[:parotid_enlargement_persistent_unexplained_v_date] = obs.obs_datetime.to_date
        elsif (obs.value_text == '1067' || obs.value_coded == 1067)
          a_hash[:parotid_enlargement_persistent_unexplained] = 'Unknown'
          a_hash[:parotid_enlargement_persistent_unexplained_enc_id] = obs.encounter_id
          a_hash[:parotid_enlargement_persistent_unexplained_v_date] = obs.obs_datetime.to_date
        end

    elsif (obs.concept_id.to_i == 2891) #lineal_gingival_erythema
         if (obs.value_text == '1065' || obs.value_coded == 1065)
          a_hash[:lineal_gingival_erythema] = 'Yes'
          a_hash[:lineal_gingival_erythema_enc_id] = obs.encounter_id
          a_hash[:lineal_gingival_erythema_v_date] = obs.obs_datetime.to_date
        elsif (obs.value_text == '1065' || obs.value_coded == 1066)
          a_hash[:lineal_gingival_erythema] = 'No'
          a_hash[:lineal_gingival_erythema_enc_id] = obs.encounter_id
          a_hash[:lineal_gingival_erythema_v_date] = obs.obs_datetime.to_date
        elsif (obs.value_text == '1067' || obs.value_coded == 1067)
          a_hash[:lineal_gingival_erythema] = 'Unknown'
          a_hash[:lineal_gingival_erythema_enc_id] = obs.encounter_id
          a_hash[:lineal_gingival_erythema_v_date] = obs.obs_datetime.to_date
        end

    elsif (obs.concept_id.to_i == 836)  #herpes_zoster
        if (obs.value_text == '1065' || obs.value_coded == 1065)
          a_hash[:herpes_zoster] = 'Yes'
          a_hash[:herpes_zoster_enc_id] = obs.encounter_id
          a_hash[:herpes_zoster_v_date] = obs.obs_datetime.to_date
        elsif (obs.value_text == '1065' || obs.value_coded == 1066)
          a_hash[:herpes_zoster] = 'No'
          a_hash[:herpes_zoster_enc_id] = obs.encounter_id
          a_hash[:herpes_zoster_v_date] = obs.obs_datetime.to_date
        elsif (obs.value_text == '1067' || obs.value_coded == 1067)
          a_hash[:herpes_zoster] = 'Unknown'
          a_hash[:herpes_zoster_enc_id] = obs.encounter_id
          a_hash[:herpes_zoster_v_date] = obs.obs_datetime.to_date
        end

    elsif (obs.concept_id.to_i == 5012) #respiratory_tract_infections_recurrent
        if (obs.value_text == '1065' || obs.value_coded == 1065)
          a_hash[:respiratory_tract_infections_recurrent] = 'Yes'
          a_hash[:respiratory_tract_infections_recurrent_enc_id] = obs.encounter_id
          a_hash[:respiratory_tract_infections_recurrent_v_date] = obs.obs_datetime.to_date
        elsif (obs.value_text == '1065' || obs.value_coded == 1066)
          a_hash[:respiratory_tract_infections_recurrent] = 'No'
          a_hash[:respiratory_tract_infections_recurrent_enc_id] = obs.encounter_id
          a_hash[:respiratory_tract_infections_recurrent_v_date] = obs.obs_datetime.to_date
        elsif (obs.value_text == '1067' || obs.value_coded == 1067)
          a_hash[:respiratory_tract_infections_recurrent] = 'Unknown'
          a_hash[:respiratory_tract_infections_recurrent_enc_id] = obs.encounter_id
          a_hash[:respiratory_tract_infections_recurrent_v_date] = obs.obs_datetime.to_date
        end

    elsif  (obs.concept_id.to_i == 6758) #unspecified_stage2_condition
        if (obs.value_text == '1065' || obs.value_coded == 1065)
          a_hash[:unspecified_stage2_condition] = 'Yes'
          a_hash[:unspecified_stage2_condition_enc_id] = obs.encounter_id
          a_hash[:unspecified_stage2_condition_v_date] = obs.obs_datetime.to_date
        elsif (obs.value_text == '1065' || obs.value_coded == 1066)
          a_hash[:unspecified_stage2_condition] = 'No'
          a_hash[:unspecified_stage2_condition_enc_id] = obs.encounter_id
          a_hash[:unspecified_stage2_condition_v_date] = obs.obs_datetime.to_date
        elsif (obs.value_text == '1067' || obs.value_coded == 1067)
          a_hash[:unspecified_stage2_condition] = 'Unknown'
          a_hash[:unspecified_stage2_condition_enc_id] = obs.encounter_id
          a_hash[:unspecified_stage2_condition_v_date] = obs.obs_datetime.to_date
        end

    elsif (obs.concept_id.to_i == 2575) #angular_chelitis
        if (obs.value_text == '1065' || obs.value_coded == 1065)
          a_hash[:angular_chelitis] = 'Yes'
          a_hash[:angular_chelitis_enc_id] = obs.encounter_id
          a_hash[:angular_chelitis_v_date] = obs.obs_datetime.to_date
        elsif (obs.value_text == '1065' || obs.value_coded == 1066)
          a_hash[:angular_chelitis] = 'No'
          a_hash[:angular_chelitis_enc_id] = obs.encounter_id
          a_hash[:angular_chelitis_v_date] = obs.obs_datetime.to_date
        elsif (obs.value_text == '1067' || obs.value_coded == 1067)
          a_hash[:angular_chelitis] = 'Unknown'
          a_hash[:angular_chelitis_enc_id] = obs.encounter_id
          a_hash[:angular_chelitis_v_date] = obs.obs_datetime.to_date
        end

    elsif (obs.concept_id.to_i == 2577) #papular_pruritic_eruptions
        if (obs.value_text == '1065' || obs.value_coded == 1065)
          a_hash[:papular_pruritic_eruptions] = 'Yes'
          a_hash[:papular_pruritic_eruptions_enc_id] = obs.encounter_id
          a_hash[:papular_pruritic_eruptions_v_date] = obs.obs_datetime.to_date
        elsif (obs.value_text == '1065' || obs.value_coded == 1066)
          a_hash[:papular_pruritic_eruptions] = 'No'
          a_hash[:papular_pruritic_eruptions_enc_id] = obs.encounter_id
          a_hash[:papular_pruritic_eruptions_v_date] = obs.obs_datetime.to_date
        elsif (obs.value_text == '1067' || obs.value_coded == 1067)
          a_hash[:papular_pruritic_eruptions] = 'Unknown'
          a_hash[:papular_pruritic_eruptions_enc_id] = obs.encounter_id
          a_hash[:papular_pruritic_eruptions_v_date] = obs.obs_datetime.to_date
        end

    elsif (obs.concept_id.to_i == 7537) #hepatosplenomegaly_unexplained
        if (obs.value_text == '1065' || obs.value_coded == 1065)
          a_hash[:hepatosplenomegaly_unexplained] = 'Yes'
          a_hash[:hepatosplenomegaly_unexplained_enc_id] = obs.encounter_id
          a_hash[:hepatosplenomegaly_unexplained_v_date] = obs.obs_datetime.to_date
        elsif (obs.value_text == '1065' || obs.value_coded == 1066)
          a_hash[:hepatosplenomegaly_unexplained] = 'No'
          a_hash[:hepatosplenomegaly_unexplained_enc_id] = obs.encounter_id
          a_hash[:hepatosplenomegaly_unexplained_v_date] = obs.obs_datetime.to_date
        elsif (obs.value_text == '1067' || obs.value_coded == 1067)
          a_hash[:hepatosplenomegaly_unexplained] = 'Unknown'
          a_hash[:hepatosplenomegaly_unexplained_enc_id] = obs.encounter_id
          a_hash[:hepatosplenomegaly_unexplained_v_date] = obs.obs_datetime.to_date
        end

    elsif (obs.concept_id.to_i == 5337) #oral_hairy_leukoplakia
        if (obs.value_text == '1065' || obs.value_coded == 1065)
          a_hash[:oral_hairy_leukoplakia] = 'Yes'
          a_hash[:oral_hairy_leukoplakia_enc_id] = obs.encounter_id
          a_hash[:oral_hairy_leukoplakia_v_date] = obs.obs_datetime.to_date
        elsif (obs.value_text == '1065' || obs.value_coded == 1066)
          a_hash[:oral_hairy_leukoplakia] = 'No'
          a_hash[:oral_hairy_leukoplakia_enc_id] = obs.encounter_id
          a_hash[:oral_hairy_leukoplakia_v_date] = obs.obs_datetime.to_date
        elsif (obs.value_text == '1067' || obs.value_coded == 1067)
          a_hash[:oral_hairy_leukoplakia] = 'Unknown'
          a_hash[:oral_hairy_leukoplakia_enc_id] = obs.encounter_id
          a_hash[:oral_hairy_leukoplakia_v_date] = obs.obs_datetime.to_date
        end

    elsif (obs.concept_id.to_i == 7540) #severe_weight_loss
        if (obs.value_text == '1065' || obs.value_coded == 1065)
          a_hash[:severe_weight_loss] = 'Yes'
          a_hash[:severe_weight_loss_enc_id] = obs.encounter_id
          a_hash[:severe_weight_loss_v_date] = obs.obs_datetime.to_date
        elsif (obs.value_text == '1065' || obs.value_coded == 1066)
          a_hash[:severe_weight_loss] = 'No'
          a_hash[:severe_weight_loss_enc_id] = obs.encounter_id
          a_hash[:severe_weight_loss_v_date] = obs.obs_datetime.to_date
        elsif (obs.value_text == '1067' || obs.value_coded == 1067)
          a_hash[:severe_weight_loss] = 'Unknown'
          a_hash[:severe_weight_loss_enc_id] = obs.encounter_id
          a_hash[:severe_weight_loss_v_date] = obs.obs_datetime.to_date
        end

    elsif (obs.concept_id.to_i == 5027) #fever_persistent_unexplained
        if (obs.value_text == '1065' || obs.value_coded == 1065)
          a_hash[:fever_persistent_unexplained] = 'Yes'
          a_hash[:fever_persistent_unexplained_enc_id] = obs.encounter_id
          a_hash[:fever_persistent_unexplained_v_date] = obs.obs_datetime.to_date
        elsif (obs.value_text == '1065' || obs.value_coded == 1066)
          a_hash[:fever_persistent_unexplained] = 'No'
          a_hash[:fever_persistent_unexplained_enc_id] = obs.encounter_id
          a_hash[:fever_persistent_unexplained_v_date] = obs.obs_datetime.to_date
        elsif (obs.value_text == '1067' || obs.value_coded == 1067)
          a_hash[:fever_persistent_unexplained] = 'Unknown'
          a_hash[:fever_persistent_unexplained_enc_id] = obs.encounter_id
          a_hash[:fever_persistent_unexplained_v_date] = obs.obs_datetime.to_date
        end

    elsif  (obs.concept_id.to_i == 2891) #pulmonary_tuberculosis
        if (obs.value_text == '1065' || obs.value_coded == 1065)
          a_hash[:pulmonary_tuberculosis] = 'Yes'
          a_hash[:pulmonary_tuberculosis_enc_id] = obs.encounter_id
          a_hash[:pulmonary_tuberculosis_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_text == '1065' || obs.value_coded == 1066)
          a_hash[:pulmonary_tuberculosis] = 'No'
          a_hash[:pulmonary_tuberculosis_enc_id] = obs.encounter_id
          a_hash[:pulmonary_tuberculosis_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_text == '1067' || obs.value_coded == 1067)
          a_hash[:pulmonary_tuberculosis] = 'Unknown'
          a_hash[:pulmonary_tuberculosis_enc_id] = obs.encounter_id
          a_hash[:pulmonary_tuberculosis_v_date] = obs.obs_datetime.to_date rescue nil
        end

    elsif  (obs.concept_id.to_i == 8206) #pulmonary_tuberculosis
        if (obs.value_text == '1065' || obs.value_coded == 1065)
          a_hash[:pulmonary_tuberculosis] = 'Yes'
          a_hash[:pulmonary_tuberculosis_enc_id] = obs.encounter_id
          a_hash[:pulmonary_tuberculosis_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_text == '1065' || obs.value_coded == 1066)
          a_hash[:pulmonary_tuberculosis] = 'No'
          a_hash[:pulmonary_tuberculosis_enc_id] = obs.encounter_id
          a_hash[:pulmonary_tuberculosis_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_text == '1067' || obs.value_coded == 1067)
          a_hash[:pulmonary_tuberculosis] = 'Unknown'
          a_hash[:pulmonary_tuberculosis_enc_id] = obs.encounter_id
          a_hash[:pulmonary_tuberculosis_v_date] = obs.obs_datetime.to_date rescue nil
        end

    elsif  (obs.concept_id.to_i == 1549) #pulmonary_tuberculosis
        if (obs.value_text == '1065' || obs.value_coded == 1065)
          a_hash[:pulmonary_tuberculosis] = 'Yes'
          a_hash[:pulmonary_tuberculosis_enc_id] = obs.encounter_id
          a_hash[:pulmonary_tuberculosis_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_text == '1065' || obs.value_coded == 1066)
          a_hash[:pulmonary_tuberculosis] = 'No'
          a_hash[:pulmonary_tuberculosis_enc_id] = obs.encounter_id
          a_hash[:pulmonary_tuberculosis_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_text == '1067' || obs.value_coded == 1067)
          a_hash[:pulmonary_tuberculosis] = 'Unknown'
          a_hash[:pulmonary_tuberculosis_enc_id] = obs.encounter_id
          a_hash[:pulmonary_tuberculosis_v_date] = obs.obs_datetime.to_date rescue nil
        end

    elsif  (obs.concept_id.to_i == 831) #pulmonary_tuberculosis
        if (obs.value_text == '1065' || obs.value_coded == 1065)
          a_hash[:pulmonary_tuberculosis] = 'Yes'
          a_hash[:pulmonary_tuberculosis_enc_id] = obs.encounter_id
          a_hash[:pulmonary_tuberculosis_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_text == '1065' || obs.value_coded == 1066)
          a_hash[:pulmonary_tuberculosis] = 'No'
          a_hash[:pulmonary_tuberculosis_enc_id] = obs.encounter_id
          a_hash[:pulmonary_tuberculosis_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_text == '1067' || obs.value_coded == 1067)
          a_hash[:pulmonary_tuberculosis] = 'Unknown'
          a_hash[:pulmonary_tuberculosis_enc_id] = obs.encounter_id
          a_hash[:pulmonary_tuberculosis_v_date] = obs.obs_datetime.to_date rescue nil
        end

    elsif  (obs.concept_id.to_i == 42) #pulmonary_tuberculosis
        if (obs.value_text == '1065' || obs.value_coded == 1065)
          a_hash[:pulmonary_tuberculosis] = 'Yes'
          a_hash[:pulmonary_tuberculosis_enc_id] = obs.encounter_id
          a_hash[:pulmonary_tuberculosis_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_text == '1065' || obs.value_coded == 1066)
          a_hash[:pulmonary_tuberculosis] = 'No'
          a_hash[:pulmonary_tuberculosis_enc_id] = obs.encounter_id
          a_hash[:pulmonary_tuberculosis_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_text == '1067' || obs.value_coded == 1067)
          a_hash[:pulmonary_tuberculosis] = 'Unknown'
          a_hash[:pulmonary_tuberculosis_enc_id] = obs.encounter_id
          a_hash[:pulmonary_tuberculosis_v_date] = obs.obs_datetime.to_date rescue nil
        end

    elsif (obs.concept_id.to_i == 7539) #pulmonary_tuberculosis_last_2_years
        if (obs.value_text == '1065' || obs.value_coded == 1065)
          a_hash[:pulmonary_tuberculosis_last_2_years] = 'Yes'
          a_hash[:pulmonary_tuberculosis_last_2_years_enc_id] = obs.encounter_id
          a_hash[:pulmonary_tuberculosis_last_2_years_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_text == '1065' || obs.value_coded == 1066)
          a_hash[:pulmonary_tuberculosis_last_2_years] = 'No'
          a_hash[:pulmonary_tuberculosis_last_2_years_enc_id] = obs.encounter_id
          a_hash[:pulmonary_tuberculosis_last_2_years_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_text == '1067' || obs.value_coded == 1067)
          a_hash[:pulmonary_tuberculosis_last_2_years] = 'Unknown'
          a_hash[:pulmonary_tuberculosis_last_2_years_enc_id] = obs.encounter_id
          a_hash[:pulmonary_tuberculosis_last_2_years_v_date] = obs.obs_datetime.to_date rescue nil
        end

    elsif (obs.concept_id.to_i == 2624) #pulmonary_tuberculosis_last_2_years
        if (obs.value_text == '1065' || obs.value_coded == 1065)
          a_hash[:pulmonary_tuberculosis_last_2_years] = 'Yes'
          a_hash[:pulmonary_tuberculosis_last_2_years_enc_id] = obs.encounter_id
          a_hash[:pulmonary_tuberculosis_last_2_years_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_text == '1065' || obs.value_coded == 1066)
          a_hash[:pulmonary_tuberculosis_last_2_years] = 'No'
          a_hash[:pulmonary_tuberculosis_last_2_years_enc_id] = obs.encounter_id
          a_hash[:pulmonary_tuberculosis_last_2_years_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_text == '1067' || obs.value_coded == 1067)
          a_hash[:pulmonary_tuberculosis_last_2_years] = 'Unknown'
          a_hash[:pulmonary_tuberculosis_last_2_years_enc_id] = obs.encounter_id
          a_hash[:pulmonary_tuberculosis_last_2_years_v_date] = obs.obs_datetime.to_date rescue nil
        end

    elsif (obs.concept_id.to_i == 5333) #severe_bacterial_infection
        if (obs.value_text == '1065' || obs.value_coded == 1065)
          a_hash[:severe_bacterial_infection] = 'Yes'
          a_hash[:severe_bacterial_infection_enc_id] = obs.encounter_id
          a_hash[:severe_bacterial_infection_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_text == '1065' || obs.value_coded == 1066)
          a_hash[:severe_bacterial_infection] = 'No'
          a_hash[:severe_bacterial_infection_enc_id] = obs.encounter_id
          a_hash[:severe_bacterial_infection_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_text == '1067' || obs.value_coded == 1067)
          a_hash[:severe_bacterial_infection] = 'Unknown'
          a_hash[:severe_bacterial_infection_enc_id] = obs.encounter_id
          a_hash[:severe_bacterial_infection_v_date] = obs.obs_datetime.to_date rescue nil
        end

    elsif (obs.concept_id.to_i == 1215) #bacterial_pnuemonia
        if (obs.value_text == '1065' || obs.value_coded == 1065)
          a_hash[:bacterial_pnuemonia] = 'Yes'
          a_hash[:bacterial_pnuemonia_enc_id] = obs.encounter_id
          a_hash[:bacterial_pnuemonia_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_text == '1065' || obs.value_coded == 1066)
          a_hash[:bacterial_pnuemonia] = 'No'
          a_hash[:bacterial_pnuemonia_enc_id] = obs.encounter_id
          a_hash[:bacterial_pnuemonia_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_text == '1067' || obs.value_coded == 1067)
          a_hash[:bacterial_pnuemonia] = 'Unknown'
          a_hash[:bacterial_pnuemonia_enc_id] = obs.encounter_id
          a_hash[:bacterial_pnuemonia_v_date] = obs.obs_datetime.to_date rescue nil
        end

    elsif (obs.concept_id.to_i == 5024) #symptomatic_lymphoid_interstitial_pnuemonitis
        if (obs.value_text == '1065' || obs.value_coded == 1065)
          a_hash[:symptomatic_lymphoid_interstitial_pnuemonitis] = 'Yes'
          a_hash[:symptomatic_lymphoid_interstitial_pnuemonitis_enc_id] = obs.encounter_id
          a_hash[:symptomatic_lymphoid_interstitial_pnuemonitis_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_text == '1065' || obs.value_coded == 1066)
          a_hash[:symptomatic_lymphoid_interstitial_pnuemonitis] = 'No'
          a_hash[:symptomatic_lymphoid_interstitial_pnuemonitis_enc_id] = obs.encounter_id
          a_hash[:symptomatic_lymphoid_interstitial_pnuemonitis_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_text == '1067' || obs.value_coded == 1067)
          a_hash[:symptomatic_lymphoid_interstitial_pnuemonitis] = 'Unknown'
          a_hash[:symptomatic_lymphoid_interstitial_pnuemonitis_enc_id] = obs.encounter_id
          a_hash[:symptomatic_lymphoid_interstitial_pnuemonitis_v_date] = obs.obs_datetime.to_date rescue nil
        end

    elsif (obs.concept_id.to_i == 2889) #chronic_hiv_assoc_lung_disease
        if (obs.value_text == '1065' || obs.value_coded == 1065)
          a_hash[:chronic_hiv_assoc_lung_disease] = 'Yes'
          a_hash[:chronic_hiv_assoc_lung_disease_enc_id] = obs.encounter_id
          a_hash[:chronic_hiv_assoc_lung_disease_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_text == '1065' || obs.value_coded == 1066)
          a_hash[:chronic_hiv_assoc_lung_disease] = 'No'
          a_hash[:chronic_hiv_assoc_lung_disease_enc_id] = obs.encounter_id
          a_hash[:chronic_hiv_assoc_lung_disease_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_text == '1067' || obs.value_coded == 1067)
          a_hash[:chronic_hiv_assoc_lung_disease] = 'Unknown'
          a_hash[:chronic_hiv_assoc_lung_disease_enc_id] = obs.encounter_id
          a_hash[:chronic_hiv_assoc_lung_disease_v_date] = obs.obs_datetime.to_date rescue nil
        end

    elsif (obs.concept_id.to_i == 6759) #unspecified_stage3_condition
        if (obs.value_text == '1065' || obs.value_coded == 1065)
          a_hash[:unspecified_stage3_condition] = 'Yes'
          a_hash[:unspecified_stage3_condition_enc_id] = obs.encounter_id
          a_hash[:unspecified_stage3_condition_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_text == '1065' || obs.value_coded == 1066)
          a_hash[:unspecified_stage3_condition] = 'No'
          a_hash[:unspecified_stage3_condition_enc_id] = obs.encounter_id
          a_hash[:unspecified_stage3_condition_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_text == '1067' || obs.value_coded == 1067)
          a_hash[:unspecified_stage3_condition] = 'Unknown'
          a_hash[:unspecified_stage3_condition_enc_id] = obs.encounter_id
          a_hash[:unspecified_stage3_condition_v_date] = obs.obs_datetime.to_date rescue nil
        end

    elsif (obs.concept_id.to_i == 3) #aneamia
        if (obs.value_text == '1065' || obs.value_coded == 1065)
          a_hash[:aneamia] = 'Yes'
          a_hash[:aneamia_enc_id] = obs.encounter_id
          a_hash[:aneamia_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_text == '1065' || obs.value_coded == 1066)
          a_hash[:aneamia] = 'No'
          a_hash[:aneamia_enc_id] = obs.encounter_id
          a_hash[:aneamia_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_text == '1067' || obs.value_coded == 1067)
          a_hash[:aneamia] = 'Unknown'
          a_hash[:aneamia_enc_id] = obs.encounter_id
          a_hash[:aneamia_v_date] = obs.obs_datetime.to_date rescue nil
        end

    elsif (obs.concept_id.to_i == 7954) #neutropaenia
        if (obs.value_text == '1065' || obs.value_coded == 1065)
          a_hash[:neutropaenia] = 'Yes'
          a_hash[:neutropaenia_enc_id] = obs.encounter_id
          a_hash[:neutropaenia_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_text == '1065' || obs.value_coded == 1066)
          a_hash[:neutropaenia] = 'No'
          a_hash[:neutropaenia_enc_id] = obs.encounter_id
          a_hash[:neutropaenia_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_text == '1067' || obs.value_coded == 1067)
          a_hash[:neutropaenia] = 'Unknown'
          a_hash[:neutropaenia_enc_id] = obs.encounter_id
          a_hash[:neutropaenia_v_date] = obs.obs_datetime.to_date rescue nil
        end

    elsif (obs.concept_id.to_i == 7955) #thrombocytopaenia_chronic
        if (obs.value_text == '1065' || obs.value_coded == 1065)
          a_hash[:thrombocytopaenia_chronic]  = 'Yes'
          a_hash[:thrombocytopaenia_chronic_enc_id] = obs.encounter_id
          a_hash[:thrombocytopaenia_chronic_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_text == '1065' || obs.value_coded == 1066)
          a_hash[:thrombocytopaenia_chronic]  = 'No'
          a_hash[:thrombocytopaenia_chronic_enc_id] = obs.encounter_id
          a_hash[:thrombocytopaenia_chronic_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_text == '1067' || obs.value_coded == 1067)
          a_hash[:thrombocytopaenia_chronic]  = 'Unknown'
          a_hash[:thrombocytopaenia_chronic_enc_id] = obs.encounter_id
          a_hash[:thrombocytopaenia_chronic_v_date] = obs.obs_datetime.to_date rescue nil
        end

    elsif (obs.concept_id.to_i == 16) #diarhoea
        if (obs.value_text == '1065' || obs.value_coded == 1065)
          a_hash[:diarhoea] = 'Yes'
          a_hash[:diarhoea_enc_id] = obs.encounter_id
          a_hash[:diarhoea_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_text == '1065' || obs.value_coded == 1066)
          a_hash[:diarhoea] = 'No'
          a_hash[:diarhoea_enc_id] = obs.encounter_id
          a_hash[:diarhoea_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_text == '1067' || obs.value_coded == 1067)
          a_hash[:diarhoea] = 'Unknown'
          a_hash[:diarhoea_enc_id] = obs.encounter_id
          a_hash[:diarhoea_v_date] = obs.obs_datetime.to_date rescue nil
        end

    elsif (obs.concept_id.to_i == 5334) #oral_candidiasis
        if (obs.value_text == '1065' || obs.value_coded == 1065)
          a_hash[:oral_candidiasis] = 'Yes'
          a_hash[:oral_candidiasis_enc_id] = obs.encounter_id
          a_hash[:oral_candidiasis_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_text == '1065' || obs.value_coded == 1066)
          a_hash[:oral_candidiasis] = 'No'
          a_hash[:oral_candidiasis_enc_id] = obs.encounter_id
          a_hash[:oral_candidiasis_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_text == '1067' || obs.value_coded == 1067)
          a_hash[:oral_candidiasis] = 'Unknown'
          a_hash[:oral_candidiasis_enc_id] = obs.encounter_id
          a_hash[:oral_candidiasis_v_date] = obs.obs_datetime.to_date rescue nil
        end

    elsif (obs.concept_id.to_i == 7546) #acute_necrotizing_ulcerative_gingivitis
        if (obs.value_text == '1065' || obs.value_coded == 1065)
          a_hash[:acute_necrotizing_ulcerative_gingivitis] = 'Yes'
          a_hash[:acute_necrotizing_ulcerative_gingivitis_enc_id] = obs.encounter_id
          a_hash[:acute_necrotizing_ulcerative_gingivitis_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_text == '1065' || obs.value_coded == 1066)
          a_hash[:acute_necrotizing_ulcerative_gingivitis] = 'No'
          a_hash[:acute_necrotizing_ulcerative_gingivitis_enc_id] = obs.encounter_id
          a_hash[:acute_necrotizing_ulcerative_gingivitis_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_text == '1067' || obs.value_coded == 1067)
          a_hash[:acute_necrotizing_ulcerative_gingivitis] = 'Unknown'
          a_hash[:acute_necrotizing_ulcerative_gingivitis_enc_id] = obs.encounter_id
          a_hash[:acute_necrotizing_ulcerative_gingivitis_v_date] = obs.obs_datetime.to_date rescue nil
        end

    elsif (obs.concept_id.to_i == 7547) #lymph_node_tuberculosis
        if (obs.value_text == '1065' || obs.value_coded == 1065)
          a_hash[:lymph_node_tuberculosis] = 'Yes'
          a_hash[:lymph_node_tuberculosis_enc_id] = obs.encounter_id
          a_hash[:lymph_node_tuberculosis_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_text == '1065' || obs.value_coded == 1066)
          a_hash[:lymph_node_tuberculosis] = 'No'
          a_hash[:lymph_node_tuberculosis_enc_id] = obs.encounter_id
          a_hash[:lymph_node_tuberculosis_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_text == '1067' || obs.value_coded == 1067)
          a_hash[:lymph_node_tuberculosis] = 'Unknown'
          a_hash[:lymph_node_tuberculosis_enc_id] = obs.encounter_id
          a_hash[:lymph_node_tuberculosis_v_date] = obs.obs_datetime.to_date rescue nil
        end

    elsif (obs.concept_id.to_i == 2583) #toxoplasmosis_of_the_brain
        if (obs.value_text == '1065' || obs.value_coded == 1065)
          a_hash[:toxoplasmosis_of_the_brain] = 'Yes'
          a_hash[:toxoplasmosis_of_the_brain_enc_id] = obs.encounter_id
          a_hash[:toxoplasmosis_of_the_brain_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_text == '1065' || obs.value_coded == 1066)
          a_hash[:toxoplasmosis_of_the_brain] = 'No'
          a_hash[:toxoplasmosis_of_the_brain_enc_id] = obs.encounter_id
          a_hash[:toxoplasmosis_of_the_brain_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_text == '1067' || obs.value_coded == 1067)
          a_hash[:toxoplasmosis_of_the_brain] = 'Unknown'
          a_hash[:toxoplasmosis_of_the_brain_enc_id] = obs.encounter_id
          a_hash[:toxoplasmosis_of_the_brain_v_date] = obs.obs_datetime.to_date rescue nil
        end

    elsif (obs.concept_id.to_i == 1359) #cryptococcal_meningitis
        if (obs.value_text == '1065' || obs.value_coded == 1065)
          a_hash[:cryptococcal_meningitis] = 'Yes'
          a_hash[:cryptococcal_meningitis_enc_id] = obs.encounter_id
          a_hash[:cryptococcal_meningitis_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_text == '1065' || obs.value_coded == 1066)
          a_hash[:cryptococcal_meningitis] = 'No'
          a_hash[:cryptococcal_meningitis_enc_id] = obs.encounter_id
          a_hash[:cryptococcal_meningitis_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_text == '1067' || obs.value_coded == 1067)
          a_hash[:cryptococcal_meningitis] = 'Unknown'
          a_hash[:cryptococcal_meningitis_enc_id] = obs.encounter_id
          a_hash[:cryptococcal_meningitis_v_date] = obs.obs_datetime.to_date rescue nil
        end

    elsif (obs.concept_id.to_i == 5046) #progressive_multifocal_leukoencephalopathy
        if (obs.value_text == '1065' || obs.value_coded == 1065)
          a_hash[:progressive_multifocal_leukoencephalopathy] = 'Yes'
          a_hash[:progressive_multifocal_leukoencephalopathy_enc_id] = obs.encounter_id
          a_hash[:progressive_multifocal_leukoencephalopathy_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_text == '1065' || obs.value_coded == 1066)
          a_hash[:progressive_multifocal_leukoencephalopathy] = 'No'
          a_hash[:progressive_multifocal_leukoencephalopathy_enc_id] = obs.encounter_id
          a_hash[:progressive_multifocal_leukoencephalopathy_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_text == '1067' || obs.value_coded == 1067)
          a_hash[:progressive_multifocal_leukoencephalopathy] = 'Unknown'
          a_hash[:progressive_multifocal_leukoencephalopathy_enc_id] = obs.encounter_id
          a_hash[:progressive_multifocal_leukoencephalopathy_v_date] = obs.obs_datetime.to_date rescue nil
        end

    elsif (obs.concept_id.to_i == 7550) #disseminated_mycosis
        if (obs.value_text == '1065' || obs.value_coded == 1065)
          a_hash[:disseminated_mycosis] = 'Yes'
          a_hash[:disseminated_mycosis_enc_id] = obs.encounter_id
          a_hash[:disseminated_mycosis_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_text == '1065' || obs.value_coded == 1066)
          a_hash[:disseminated_mycosis] = 'No'
          a_hash[:disseminated_mycosis_enc_id] = obs.encounter_id
          a_hash[:disseminated_mycosis_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_text == '1067' || obs.value_coded == 1067)
          a_hash[:disseminated_mycosis] = 'Unknown'
          a_hash[:disseminated_mycosis_enc_id] = obs.encounter_id
          a_hash[:disseminated_mycosis_v_date] = obs.obs_datetime.to_date rescue nil
        end

    elsif (obs.concept_id.to_i == 7553) #candidiasis_of_oesophagus
        if (obs.value_text == '1065' || obs.value_coded == 1065)
          a_hash[:candidiasis_of_oesophagus] = 'Yes'
          a_hash[:candidiasis_of_oesophagus_enc_id] = obs.encounter_id
          a_hash[:candidiasis_of_oesophagus_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_text == '1065' || obs.value_coded == 1066)
          a_hash[:candidiasis_of_oesophagus] = 'No'
          a_hash[:candidiasis_of_oesophagus_enc_id] = obs.encounter_id
          a_hash[:candidiasis_of_oesophagus_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_text == '1067' || obs.value_coded == 1067)
          a_hash[:candidiasis_of_oesophagus] = 'Unknown'
          a_hash[:candidiasis_of_oesophagus_enc_id] = obs.encounter_id
          a_hash[:candidiasis_of_oesophagus_v_date] = obs.obs_datetime.to_date rescue nil
        end

    elsif  (obs.concept_id.to_i == 1547) #extrapulmonary_tuberculosis
        if (obs.value_text == '1065' || obs.value_coded == 1065)
          a_hash[:extrapulmonary_tuberculosis] = 'Yes'
          a_hash[:extrapulmonary_tuberculosis_enc_id] = obs.encounter_id
          a_hash[:extrapulmonary_tuberculosis_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_text == '1065' || obs.value_coded == 1066)
          a_hash[:extrapulmonary_tuberculosis] = 'No'
          a_hash[:extrapulmonary_tuberculosis_enc_id] = obs.encounter_id
          a_hash[:extrapulmonary_tuberculosis_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_text == '1067' || obs.value_coded == 1067)
          a_hash[:extrapulmonary_tuberculosis] = 'Unknown'
          a_hash[:extrapulmonary_tuberculosis_enc_id] = obs.encounter_id
          a_hash[:extrapulmonary_tuberculosis_v_date] = obs.obs_datetime.to_date rescue nil
        end

    elsif  (obs.concept_id.to_i == 2587) #cerebral_non_hodgkin_lymphoma
        if (obs.value_text == '1065' || obs.value_coded == 1065)
          a_hash[:cerebral_non_hodgkin_lymphoma] = 'Yes'
          a_hash[:cerebral_non_hodgkin_lymphoma_enc_id] = obs.encounter_id
          a_hash[:cerebral_non_hodgkin_lymphoma_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_text == '1065' || obs.value_coded == 1066)
          a_hash[:cerebral_non_hodgkin_lymphoma] = 'No'
          a_hash[:cerebral_non_hodgkin_lymphoma_enc_id] = obs.encounter_id
          a_hash[:cerebral_non_hodgkin_lymphoma_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_text == '1067' || obs.value_coded == 1067)
          a_hash[:cerebral_non_hodgkin_lymphoma] = 'Unknown'
          a_hash[:cerebral_non_hodgkin_lymphoma_enc_id] = obs.encounter_id
          a_hash[:cerebral_non_hodgkin_lymphoma_v_date] = obs.obs_datetime.to_date rescue nil
        end

    elsif (obs.concept_id.to_i == 507) #kaposis
        if (obs.value_text == '1065' || obs.value_coded == 1065)
          a_hash[:kaposis_sarcoma] = 'Yes'
          a_hash[:kaposis_sarcoma_enc_id] = obs.encounter_id
          a_hash[:kaposis_sarcoma_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_text == '1065' || obs.value_coded == 1066)
          a_hash[:kaposis_sarcoma] = 'No'
          a_hash[:kaposis_sarcoma_enc_id] = obs.encounter_id
          a_hash[:kaposis_sarcoma_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_text == '1067' || obs.value_coded == 1067)
          a_hash[:kaposis_sarcoma] = 'Unknown'
          a_hash[:kaposis_sarcoma_enc_id] = obs.encounter_id
          a_hash[:kaposis_sarcoma_v_date] = obs.obs_datetime.to_date rescue nil
        end

    elsif  (obs.concept_id.to_i == 1362) #hiv_encephalopathy
        if (obs.value_text == '1065' || obs.value_coded == 1065)
          a_hash[:hiv_encephalopathy] = 'Yes'
          a_hash[:hiv_encephalopathy_enc_id] = obs.encounter_id
          a_hash[:hiv_encephalopathy_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_text == '1065' || obs.value_coded == 1066)
          a_hash[:hiv_encephalopathy] = 'No'
          a_hash[:hiv_encephalopathy_enc_id] = obs.encounter_id
          a_hash[:hiv_encephalopathy_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_text == '1067' || obs.value_coded == 1067)
          a_hash[:hiv_encephalopathy] = 'Unknown'
          a_hash[:hiv_encephalopathy_enc_id] = obs.encounter_id
          a_hash[:hiv_encephalopathy_v_date] = obs.obs_datetime.to_date rescue nil
        end

    elsif  (obs.concept_id.to_i == 2894) #bacterial_infections_severe_recurrent
        if (obs.value_text == '1065' || obs.value_coded == 1065)
          a_hash[:bacterial_infections_severe_recurrent] = 'Yes'
          a_hash[:bacterial_infections_severe_recurrent_enc_id] = obs.encounter_id
          a_hash[:bacterial_infections_severe_recurrent_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_text == '1065' || obs.value_coded == 1066)
          a_hash[:bacterial_infections_severe_recurrent] = 'No'
          a_hash[:bacterial_infections_severe_recurrent_enc_id] = obs.encounter_id
          a_hash[:bacterial_infections_severe_recurrent_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_text == '1067' || obs.value_coded == 1067)
          a_hash[:bacterial_infections_severe_recurrent] = 'Unknown'
          a_hash[:bacterial_infections_severe_recurrent_enc_id] = obs.encounter_id
          a_hash[:bacterial_infections_severe_recurrent_v_date] = obs.obs_datetime.to_date rescue nil
        end

    elsif obs.concept_id.to_i == 6763 #unspecified_stage_4_condition
        if (obs.value_text == '1065' || obs.value_coded == 1065)
          a_hash[:unspecified_stage_4_condition] = 'Yes'
          a_hash[:unspecified_stage_4_condition_enc_id] = obs.encounter_id
          a_hash[:unspecified_stage_4_condition_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_text == '1065' || obs.value_coded == 1066)
          a_hash[:unspecified_stage_4_condition] = 'No'
          a_hash[:unspecified_stage_4_condition_enc_id] = obs.encounter_id
          a_hash[:unspecified_stage_4_condition_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_text == '1067' || obs.value_coded == 1067)
          a_hash[:unspecified_stage_4_condition] = 'Unknown'
          a_hash[:unspecified_stage_4_condition_enc_id] = obs.encounter_id
          a_hash[:unspecified_stage_4_condition_v_date] = obs.obs_datetime.to_date rescue nil
        end

    elsif (obs.concept_id.to_i == 882) #pnuemocystis_pnuemonia
        if (obs.value_text == '1065' || obs.value_coded == 1065)
          a_hash[:pnuemocystis_pnuemonia] = 'Yes'
          a_hash[:pnuemocystis_pnuemonia_enc_id] = obs.encounter_id
          a_hash[:pnuemocystis_pnuemonia_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_text == '1065' || obs.value_coded == 1066)
          a_hash[:pnuemocystis_pnuemonia] = 'No'
          a_hash[:pnuemocystis_pnuemonia_enc_id] = obs.encounter_id
          a_hash[:pnuemocystis_pnuemonia_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_text == '1067' || obs.value_coded == 1067)
          a_hash[:pnuemocystis_pnuemonia] = 'Unknown'
          a_hash[:pnuemocystis_pnuemonia_enc_id] = obs.encounter_id
          a_hash[:pnuemocystis_pnuemonia_v_date] = obs.obs_datetime.to_date rescue nil
        end

    elsif (obs.concept_id.to_i == 2585) #disseminated_non_tuberculosis_mycobacterial_infection
        if (obs.value_text == '1065' || obs.value_coded == 1065)
          a_hash[:disseminated_non_tuberculosis_mycobacterial_infection] = 'Yes'
          a_hash[:disseminated_non_tuberculosis_mycobacterial_infection_enc_id] = obs.encounter_id
          a_hash[:disseminated_non_tuberculosis_mycobacterial_infection_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_text == '1065' || obs.value_coded == 1066)
          a_hash[:disseminated_non_tuberculosis_mycobacterial_infection] = 'No'
          a_hash[:disseminated_non_tuberculosis_mycobacterial_infection_enc_id] = obs.encounter_id
          a_hash[:disseminated_non_tuberculosis_mycobacterial_infection_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_text == '1067' || obs.value_coded == 1067)
          a_hash[:disseminated_non_tuberculosis_mycobacterial_infection] = 'Unknown'
          a_hash[:disseminated_non_tuberculosis_mycobacterial_infection_enc_id] = obs.encounter_id
          a_hash[:disseminated_non_tuberculosis_mycobacterial_infection_v_date] = obs.obs_datetime.to_date rescue nil
        end

    elsif (obs.concept_id.to_i == 5034) #cryptosporidiosis
        if (obs.value_text == '1065' || obs.value_coded == 1065)
          a_hash[:cryptosporidiosis] = 'Yes'
          a_hash[:cryptosporidiosis_enc_id] = obs.encounter_id
          a_hash[:cryptosporidiosis_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_text == '1065' || obs.value_coded == 1066)
          a_hash[:cryptosporidiosis] = 'No'
          a_hash[:cryptosporidiosis_enc_id] = obs.encounter_id
          a_hash[:cryptosporidiosis_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_text == '1067' || obs.value_coded == 1067)
          a_hash[:cryptosporidiosis] = 'Unknown'
          a_hash[:cryptosporidiosis_enc_id] = obs.encounter_id
          a_hash[:cryptosporidiosis_v_date] = obs.obs_datetime.to_date rescue nil
        end

    elsif (obs.concept_id.to_i == 2858) #isosporiasis
        if (obs.value_text == '1065' || obs.value_coded == 1065)
          a_hash[:isosporiasis] = 'Yes'
          a_hash[:isosporiasis_enc_id] = obs.encounter_id
          a_hash[:isosporiasis_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_text == '1065' || obs.value_coded == 1066)
          a_hash[:isosporiasis] = 'No'
          a_hash[:isosporiasis_enc_id] = obs.encounter_id
          a_hash[:isosporiasis_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_text == '1067' || obs.value_coded == 1067)
          a_hash[:isosporiasis] = 'Unknown'
          a_hash[:isosporiasis_enc_id] = obs.encounter_id
          a_hash[:isosporiasis_v_date] = obs.obs_datetime.to_date rescue nil
        end

    elsif (obs.concept_id.to_i == 7957) #symptomatic_hiv_associated_nephropathy
        if (obs.value_text == '1065' || obs.value_coded == 1065)
          a_hash[:symptomatic_hiv_associated_nephropathy] = 'Yes'
          a_hash[:symptomatic_hiv_associated_nephropathy_enc_id] = obs.encounter_id
          a_hash[:symptomatic_hiv_associated_nephropathy_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_text == '1065' || obs.value_coded == 1066)
          a_hash[:symptomatic_hiv_associated_nephropathy] = 'No'
          a_hash[:symptomatic_hiv_associated_nephropathy_enc_id] = obs.encounter_id
          a_hash[:symptomatic_hiv_associated_nephropathy_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_text == '1067' || obs.value_coded == 1067)
          a_hash[:symptomatic_hiv_associated_nephropathy] = 'Unknown'
          a_hash[:symptomatic_hiv_associated_nephropathy_enc_id] = obs.encounter_id
          a_hash[:symptomatic_hiv_associated_nephropathy_v_date] = obs.obs_datetime.to_date rescue nil
        end

    elsif (obs.concept_id.to_i == 5344) #chronic_herpes_simplex_infection
        if (obs.value_text == '1065' || obs.value_coded == 1065)
          a_hash[:chronic_herpes_simplex_infection] = 'Yes'
          a_hash[:chronic_herpes_simplex_infection_enc_id] = obs.encounter_id
          a_hash[:chronic_herpes_simplex_infection_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_text == '1065' || obs.value_coded == 1066)
          a_hash[:chronic_herpes_simplex_infection] = 'No'
          a_hash[:chronic_herpes_simplex_infection_enc_id] = obs.encounter_id
          a_hash[:chronic_herpes_simplex_infection_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_text == '1067' || obs.value_coded == 1067)
          a_hash[:chronic_herpes_simplex_infection] = 'Unknown'
          a_hash[:chronic_herpes_simplex_infection_enc_id] = obs.encounter_id
          a_hash[:chronic_herpes_simplex_infection_v_date] = obs.obs_datetime.to_date rescue nil
        end

    elsif (obs.concept_id.to_i == 7551) #cytomegalovirus_infection
        if (obs.value_text == '1065' || obs.value_coded == 1065)
          a_hash[:cytomegalovirus_infection] = 'Yes'
          a_hash[:cytomegalovirus_infection_enc_id] = obs.encounter_id
          a_hash[:cytomegalovirus_infection_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_text == '1065' || obs.value_coded == 1066)
          a_hash[:cytomegalovirus_infection] = 'No'
          a_hash[:cytomegalovirus_infection_enc_id] = obs.encounter_id
          a_hash[:cytomegalovirus_infection_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_text == '1067' || obs.value_coded == 1067)
          a_hash[:cytomegalovirus_infection] = 'Unknown'
          a_hash[:cytomegalovirus_infection_enc_id] = obs.encounter_id
          a_hash[:cytomegalovirus_infection_v_date] = obs.obs_datetime.to_date rescue nil
        end

    elsif (obs.concept_id.to_i == 5048) #toxoplasomis_of_the_brain_1month
        if (obs.value_text == '1065' || obs.value_coded == 1065)
          a_hash[:toxoplasomis_of_the_brain_1month] = 'Yes'
        elsif (obs.value_text == '1065' || obs.value_coded == 1066)
          a_hash[:toxoplasomis_of_the_brain_1month] = 'No'
        elsif (obs.value_text == '1067' || obs.value_coded == 1067)
          a_hash[:toxoplasomis_of_the_brain_1month] = 'Unknown'
        end

    elsif (obs.concept_id.to_i == 7961) #recto_vaginal_fitsula
        if (obs.value_text == '1065' || obs.value_coded == 1065)
          a_hash[:recto_vaginal_fitsula] = 'Yes'
          a_hash[:recto_vaginal_fitsula_enc_id] = obs.encounter_id
          a_hash[:recto_vaginal_fitsula_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_text == '1065' || obs.value_coded == 1066)
          a_hash[:recto_vaginal_fitsula] = 'No'
          a_hash[:recto_vaginal_fitsula_enc_id] = obs.encounter_id
          a_hash[:recto_vaginal_fitsula_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_text == '1067' || obs.value_coded == 1067)
          a_hash[:recto_vaginal_fitsula] = 'Unknown'
          a_hash[:recto_vaginal_fitsula_enc_id] = obs.encounter_id
          a_hash[:recto_vaginal_fitsula_v_date] = obs.obs_datetime.to_date rescue nil
        end

    elsif (obs.concept_id.to_i == 823) #moderate_weight_loss_less_than_or_equal_to_10_percent_unexpl
        if (obs.value_text == '1065' || obs.value_coded == 1065)
          a_hash[:moderate_weight_loss_less_than_or_equal_to_10_percent_unexpl] = 'Yes'
          a_hash[:moderate_weight_loss_less_than_or_equal_to_10_unexpl_enc_id] = obs.encounter_id
          a_hash[:moderate_weight_loss_less_than_or_equal_to_10_unexpl_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_text == '1065' || obs.value_coded == 1066)
          a_hash[:moderate_weight_loss_less_than_or_equal_to_10_percent_unexpl] = 'No'
          a_hash[:moderate_weight_loss_less_than_or_equal_to_10_unexpl_enc_id] = obs.encounter_id
          a_hash[:moderate_weight_loss_less_than_or_equal_to_10_unexpl_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_text == '1067' || obs.value_coded == 1067)
          a_hash[:moderate_weight_loss_less_than_or_equal_to_10_percent_unexpl] = 'Unknown'
          a_hash[:moderate_weight_loss_less_than_or_equal_to_10_unexpl_enc_id] = obs.encounter_id
          a_hash[:moderate_weight_loss_less_than_or_equal_to_10_unexpl_v_date] = obs.obs_datetime.to_date rescue nil
        end
    elsif obs.concept_id.to_i == 2743 #who_stages_criteria_present
      a_hash[:who_stages_criteria_present] = obs.to_s.split(':')[1].strip rescue nil
      a_hash[:who_stages_criteria_present_enc_id] = obs.encounter_id rescue nil
      a_hash[:who_stages_criteria_present_v_date] = obs.obs_datetime.to_date rescue nil

        if (obs.value_coded == 5328) #persistent_generalized_lymphadenopathy
    	    a_hash[:persistent_generalized_lymphadenopathy] = 'Yes'
        elsif (obs.value_coded == 5006) #asymptomatic
          a_hash[:asymptomatic] = 'Yes'
          a_hash[:asymptomatic_enc_id] = obs.encounter_id
          a_hash[:asymptomatic_v_date] = obs.obs_datetime.to_date
        elsif  (obs.value_coded== 6757) #unspecified_stage_1_cond
          a_hash[:unspecified_stage_1_cond] = 'Yes'
          a_hash[:unspecified_stage_1_cond_enc_id] = obs.encounter_id
          a_hash[:unspecified_stage_1_cond_v_date] = obs.obs_datetime.to_date
        elsif (obs.value_coded== 1212) #molluscumm_contagiosum
          a_hash[:molluscumm_contagiosum] = 'Yes'
          a_hash[:molluscumm_contagiosum_enc_id] = obs.encounter_id
          a_hash[:molluscumm_contagiosum_v_date] = obs.obs_datetime.to_date
        elsif (obs.value_coded== 6775) #wart_virus_infection_extensive
          a_hash[:wart_virus_infection_extensive] = 'Yes'
          a_hash[:wart_virus_infection_extensive_enc_id] = obs.encounter_id
          a_hash[:wart_virus_infection_extensive_v_date] = obs.obs_datetime.to_date
        elsif (obs.value_coded== 2576) #oral_ulcerations_recurrent
          a_hash[:oral_ulcerations_recurrent] = 'Yes'
          a_hash[:oral_ulcerations_recurrent_enc_id] = obs.encounter_id
          a_hash[:oral_ulcerations_recurrent_v_date] = obs.obs_datetime.to_date
        elsif (obs.value_coded== 1210) #parotid_enlargement_persistent_unexplained
          a_hash[:parotid_enlargement_persistent_unexplained] = 'Yes'
          a_hash[:parotid_enlargement_persistent_unexplained_enc_id] = obs.encounter_id
          a_hash[:parotid_enlargement_persistent_unexplained_v_date] = obs.obs_datetime.to_date
        elsif (obs.value_coded== 2891) #lineal_gingival_erythema
          a_hash[:lineal_gingival_erythema] = 'Yes'
          a_hash[:lineal_gingival_erythema_enc_id] = obs.encounter_id
          a_hash[:lineal_gingival_erythema_v_date] = obs.obs_datetime.to_date
        elsif (obs.value_coded== 836)  #herpes_zoster
          a_hash[:herpes_zoster] = 'Yes'
          a_hash[:herpes_zoster_enc_id] = obs.encounter_id
          a_hash[:herpes_zoster_v_date] = obs.obs_datetime.to_date
        elsif (obs.value_coded== 5012) #respiratory_tract_infections_recurrent
          a_hash[:respiratory_tract_infections_recurrent] = 'Yes'
          a_hash[:respiratory_tract_infections_recurrent_enc_id] = obs.encounter_id
          a_hash[:respiratory_tract_infections_recurrent_v_date] = obs.obs_datetime.to_date
        elsif  (obs.value_coded== 6758) #unspecified_stage2_condition
          a_hash[:unspecified_stage2_condition] = 'Yes'
          a_hash[:unspecified_stage2_condition_enc_id] = obs.encounter_id
          a_hash[:unspecified_stage2_condition_v_date] = obs.obs_datetime.to_date
        elsif (obs.value_coded== 2575) #angular_chelitis
          a_hash[:angular_chelitis] = 'Yes'
          a_hash[:angular_chelitis_enc_id] = obs.encounter_id
          a_hash[:angular_chelitis_v_date] = obs.obs_datetime.to_date
        elsif (obs.value_coded== 2577) #papular_pruritic_eruptions
          a_hash[:papular_pruritic_eruptions] = 'Yes'
          a_hash[:papular_pruritic_eruptions_enc_id] = obs.encounter_id
          a_hash[:papular_pruritic_eruptions_v_date] = obs.obs_datetime.to_date
        elsif (obs.value_coded== 7537) #hepatosplenomegaly_unexplained
          a_hash[:hepatosplenomegaly_unexplained] = 'Yes'
          a_hash[:hepatosplenomegaly_unexplained_enc_id] = obs.encounter_id
          a_hash[:hepatosplenomegaly_unexplained_v_date] = obs.obs_datetime.to_date
        elsif (obs.value_coded== 5337) #oral_hairy_leukoplakia
          a_hash[:oral_hairy_leukoplakia] = 'Yes'
          a_hash[:oral_hairy_leukoplakia_enc_id] = obs.encounter_id
          a_hash[:oral_hairy_leukoplakia_v_date] = obs.obs_datetime.to_date
        elsif (obs.value_coded== 7540) #severe_weight_loss
          a_hash[:severe_weight_loss] = 'Yes'
          a_hash[:severe_weight_loss_enc_id] = obs.encounter_id
          a_hash[:severe_weight_loss_v_date] = obs.obs_datetime.to_date
        elsif (obs.value_coded== 5027) #fever_persistent_unexplained
          a_hash[:fever_persistent_unexplained] = 'Yes'
          a_hash[:fever_persistent_unexplained_enc_id] = obs.encounter_id
          a_hash[:fever_persistent_unexplained_v_date] = obs.obs_datetime.to_date
        elsif  (obs.value_coded== 2891) #pulmonary_tuberculosis
          a_hash[:pulmonary_tuberculosis] = 'Yes'
          a_hash[:pulmonary_tuberculosis_enc_id] = obs.encounter_id
          a_hash[:pulmonary_tuberculosis_v_date] = obs.obs_datetime.to_date rescue nil
         elsif  (obs.value_coded== 42) #pulmonary_tuberculosis
          a_hash[:pulmonary_tuberculosis] = 'Yes'
          a_hash[:pulmonary_tuberculosis_enc_id] = obs.encounter_id
          a_hash[:pulmonary_tuberculosis_v_date] = obs.obs_datetime.to_date rescue nil
        elsif  (obs.value_coded== 831) #pulmonary_tuberculosis
          a_hash[:pulmonary_tuberculosis] = 'Yes'
          a_hash[:pulmonary_tuberculosis_enc_id] = obs.encounter_id
          a_hash[:pulmonary_tuberculosis_v_date] = obs.obs_datetime.to_date rescue nil
        elsif  (obs.value_coded== 1549) #pulmonary_tuberculosis
          a_hash[:pulmonary_tuberculosis] = 'Yes'
          a_hash[:pulmonary_tuberculosis_enc_id] = obs.encounter_id
          a_hash[:pulmonary_tuberculosis_v_date] = obs.obs_datetime.to_date rescue nil
        elsif  (obs.value_coded== 8206) #pulmonary_tuberculosis
          a_hash[:pulmonary_tuberculosis] = 'Yes'
          a_hash[:pulmonary_tuberculosis_enc_id] = obs.encounter_id
          a_hash[:pulmonary_tuberculosis_v_date] = obs.obs_datetime.to_date rescue nil                        
        elsif (obs.value_coded== 7539) #pulmonary_tuberculosis_last_2_years
          a_hash[:pulmonary_tuberculosis_last_2_years] = 'Yes'
          a_hash[:pulmonary_tuberculosis_last_2_years_enc_id] = obs.encounter_id
          a_hash[:pulmonary_tuberculosis_last_2_years_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_coded== 2624) #pulmonary_tuberculosis_last_2_years
          a_hash[:pulmonary_tuberculosis_last_2_years] = 'Yes'
          a_hash[:pulmonary_tuberculosis_last_2_years_enc_id] = obs.encounter_id
          a_hash[:pulmonary_tuberculosis_last_2_years_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_coded== 5333) #severe_bacterial_infection
          a_hash[:severe_bacterial_infection] = 'Yes'
          a_hash[:severe_bacterial_infection_enc_id] = obs.encounter_id
          a_hash[:severe_bacterial_infection_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_coded== 1215) #bacterial_pnuemonia
          a_hash[:bacterial_pnuemonia] = 'Yes'
          a_hash[:bacterial_pnuemonia_enc_id] = obs.encounter_id
          a_hash[:bacterial_pnuemonia_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_coded== 5024) #symptomatic_lymphoid_interstitial_pnuemonitis
          a_hash[:symptomatic_lymphoid_interstitial_pnuemonitis] = 'Yes'
          a_hash[:symptomatic_lymphoid_interstitial_pnuemonitis_enc_id] = obs.encounter_id
          a_hash[:symptomatic_lymphoid_interstitial_pnuemonitis_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_coded== 2889) #chronic_hiv_assoc_lung_disease
          a_hash[:chronic_hiv_assoc_lung_disease] = 'Yes'
          a_hash[:chronic_hiv_assoc_lung_disease_enc_id] = obs.encounter_id
          a_hash[:chronic_hiv_assoc_lung_disease_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_coded== 6759) #unspecified_stage3_condition
          a_hash[:unspecified_stage3_condition] = 'Yes'
          a_hash[:unspecified_stage3_condition_enc_id] = obs.encounter_id
          a_hash[:unspecified_stage3_condition_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_coded== 3) #aneamia
          a_hash[:aneamia] = 'Yes'
          a_hash[:aneamia_enc_id] = obs.encounter_id
          a_hash[:aneamia_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_coded== 7954) #neutropaenia
          a_hash[:neutropaenia] = 'Yes'
          a_hash[:neutropaenia_enc_id] = obs.encounter_id
          a_hash[:neutropaenia_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_coded== 7955) #thrombocytopaenia_chronic
          a_hash[:thrombocytopaenia_chronic]  = 'Yes'
          a_hash[:thrombocytopaenia_chronic_enc_id] = obs.encounter_id
          a_hash[:thrombocytopaenia_chronic_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_coded== 16) #diarhoea
          a_hash[:diarhoea] = 'Yes'
          a_hash[:diarhoea_enc_id] = obs.encounter_id
          a_hash[:diarhoea_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_coded== 5334) #oral_candidiasis
          a_hash[:oral_candidiasis] = 'Yes'
          a_hash[:oral_candidiasis_enc_id] = obs.encounter_id
          a_hash[:oral_candidiasis_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_coded== 7546) #acute_necrotizing_ulcerative_gingivitis
          a_hash[:acute_necrotizing_ulcerative_gingivitis] = 'Yes'
          a_hash[:acute_necrotizing_ulcerative_gingivitis_enc_id] = obs.encounter_id
          a_hash[:acute_necrotizing_ulcerative_gingivitis_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_coded== 7547) #lymph_node_tuberculosis
          a_hash[:lymph_node_tuberculosis] = 'Yes'
          a_hash[:lymph_node_tuberculosis_enc_id] = obs.encounter_id
          a_hash[:lymph_node_tuberculosis_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_coded== 2583) #toxoplasmosis_of_the_brain
          a_hash[:toxoplasmosis_of_the_brain] = 'Yes'
          a_hash[:toxoplasmosis_of_the_brain_enc_id] = obs.encounter_id
          a_hash[:toxoplasmosis_of_the_brain_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_coded== 1359) #cryptococcal_meningitis
          a_hash[:cryptococcal_meningitis] = 'Yes'
          a_hash[:cryptococcal_meningitis_enc_id] = obs.encounter_id
          a_hash[:cryptococcal_meningitis_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_coded== 5046) #progressive_multifocal_leukoencephalopathy
          a_hash[:progressive_multifocal_leukoencephalopathy] = 'Yes'
          a_hash[:progressive_multifocal_leukoencephalopathy_enc_id] = obs.encounter_id
          a_hash[:progressive_multifocal_leukoencephalopathy_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_coded== 7550) #disseminated_mycosis
          a_hash[:disseminated_mycosis] = 'Yes'
          a_hash[:disseminated_mycosis_enc_id] = obs.encounter_id
          a_hash[:disseminated_mycosis_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_coded== 7553) #candidiasis_of_oesophagus
          a_hash[:candidiasis_of_oesophagus] = 'Yes'
          a_hash[:candidiasis_of_oesophagus_enc_id] = obs.encounter_id
          a_hash[:candidiasis_of_oesophagus_v_date] = obs.obs_datetime.to_date rescue nil
        elsif  (obs.value_coded== 1547) #extrapulmonary_tuberculosis
          a_hash[:extrapulmonary_tuberculosis] = 'Yes'
          a_hash[:extrapulmonary_tuberculosis_enc_id] = obs.encounter_id
          a_hash[:extrapulmonary_tuberculosis_v_date] = obs.obs_datetime.to_date rescue nil
        elsif  (obs.value_coded== 2587) #cerebral_non_hodgkin_lymphoma
          a_hash[:cerebral_non_hodgkin_lymphoma] = 'Yes'
          a_hash[:cerebral_non_hodgkin_lymphoma_enc_id] = obs.encounter_id
          a_hash[:cerebral_non_hodgkin_lymphoma_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_coded== 507) #kaposis
          a_hash[:kaposis_sarcoma] = 'Yes'
          a_hash[:kaposis_sarcoma_enc_id] = obs.encounter_id
          a_hash[:kaposis_sarcoma_v_date] = obs.obs_datetime.to_date rescue nil
        elsif  (obs.value_coded== 1362) #hiv_encephalopathy
          a_hash[:hiv_encephalopathy] = 'Yes'
          a_hash[:hiv_encephalopathy_enc_id] = obs.encounter_id
          a_hash[:hiv_encephalopathy_v_date] = obs.obs_datetime.to_date rescue nil
        elsif  (obs.value_coded== 2894) #bacterial_infections_severe_recurrent
          a_hash[:bacterial_infections_severe_recurrent] = 'Yes'
          a_hash[:bacterial_infections_severe_recurrent_enc_id] = obs.encounter_id
          a_hash[:bacterial_infections_severe_recurrent_v_date] = obs.obs_datetime.to_date rescue nil
        elsif obs.value_coded== 6763 #unspecified_stage_4_condition
          a_hash[:unspecified_stage_4_condition] = 'Yes'
          a_hash[:unspecified_stage_4_condition_enc_id] = obs.encounter_id
          a_hash[:unspecified_stage_4_condition_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_coded== 882) #pnuemocystis_pnuemonia
          a_hash[:pnuemocystis_pnuemonia] = 'Yes'
          a_hash[:pnuemocystis_pnuemonia_enc_id] = obs.encounter_id
          a_hash[:pnuemocystis_pnuemonia_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_coded== 2585) #disseminated_non_tuberculosis_mycobacterial_infection
          a_hash[:disseminated_non_tuberculosis_mycobacterial_infection] = 'Yes'
          a_hash[:disseminated_non_tuberculosis_mycobacterial_infection_enc_id] = obs.encounter_id
          a_hash[:disseminated_non_tuberculosis_mycobacterial_infection_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_coded== 5034) #cryptosporidiosis
          a_hash[:cryptosporidiosis] = 'Yes'
          a_hash[:cryptosporidiosis_enc_id] = obs.encounter_id
          a_hash[:cryptosporidiosis_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_coded== 2858) #isosporiasis
          a_hash[:isosporiasis] = 'Yes'
          a_hash[:isosporiasis_enc_id] = obs.encounter_id
          a_hash[:isosporiasis_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_coded== 7957) #symptomatic_hiv_associated_nephropathy
          a_hash[:symptomatic_hiv_associated_nephropathy] = 'Yes'
          a_hash[:symptomatic_hiv_associated_nephropathy_enc_id] = obs.encounter_id
          a_hash[:symptomatic_hiv_associated_nephropathy_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_coded== 5344) #chronic_herpes_simplex_infection
          a_hash[:chronic_herpes_simplex_infection] = 'Yes'
          a_hash[:chronic_herpes_simplex_infection_enc_id] = obs.encounter_id
          a_hash[:chronic_herpes_simplex_infection_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_coded== 7551) #cytomegalovirus_infection
          a_hash[:cytomegalovirus_infection] = 'Yes'
          a_hash[:cytomegalovirus_infection_enc_id] = obs.encounter_id
          a_hash[:cytomegalovirus_infection_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_coded== 5048) #toxoplasomis_of_the_brain_1month
          a_hash[:toxoplasomis_of_the_brain_1month] = 'Yes'
        elsif (obs.value_coded== 7961) #recto_vaginal_fitsula
          a_hash[:recto_vaginal_fitsula] = 'Yes'
          a_hash[:recto_vaginal_fitsula_enc_id] = obs.encounter_id
          a_hash[:recto_vaginal_fitsula_v_date] = obs.obs_datetime.to_date rescue nil
        elsif (obs.value_coded== 823) #moderate_weight_loss_less_than_or_equal_to_10_percent_unexpl
          a_hash[:moderate_weight_loss_less_than_or_equal_to_10_percent_unexpl] = 'Yes'
          a_hash[:moderate_weight_loss_less_than_or_equal_to_10_unexpl_enc_id] = obs.encounter_id
          a_hash[:moderate_weight_loss_less_than_or_equal_to_10_unexpl_v_date] = obs.obs_datetime.to_date rescue nil
        else
        end
    else
    end
  end

  return generate_sql_string(a_hash)
end

def process_pat_regimen_category(reg_category, visit, type = 0)
  a_hash = {:transfer_within_responsibility => 'NULL'}

  if reg_category
    (reg_category || []).each do |patient|

      a_hash[:regimen_category] = patient.regimen_category
      a_hash[:regimen_category_enc_id] = patient.encounter_id
    end

    return generate_sql_string(a_hash)
  end
end

def process_patient_orders(orders, visit, type = 0)
  patient_orders = {}
  drug_dose_hash = {}; drug_frequency_hash = {};
  drug_equivalent_daily_dose_hash = {}; drug_inventory_ids_hash = {}
  patient_orders = {}; drug_order_ids_hash = {}; drug_enc_ids_hash = {}
  drug_start_date_hash = {}; drug_auto_expire_date_hash = {}; drug_quantity_hash = {}

  a_hash = {:drug_quantity5_enc_id => 'NULL'}

  if !orders.blank?
    patient_id = orders.map(&:patient_id).first
  end

  (orders || []).each do |ord|
    if ord.drug_inventory_id == '2833'
      drug_name = @drug_list[:"738"]
    elsif ord.drug_inventory_id == '1610'
      drug_name = @drug_list[:"731"]
    elsif ord.drug_inventory_id == '1613'
      drug_name = @drug_list[:"955"]
    elsif ord.drug_inventory_id == '2985'
      drug_name = @drug_list[:"735"]
    elsif ord.drug_inventory_id == '7927'
      drug_name = @drug_list[:"969"]
    elsif ord.drug_inventory_id == '7928'
      drug_name = @drug_list[:"734"]
    elsif ord.drug_inventory_id == '9175'
      drug_name = @drug_list[:"932"]
    else
      drug_name = @drug_list[:"#{ord.drug_inventory_id}"]
    end

    if patient_orders[drug_name].blank?
      patient_orders[drug_name] = drug_name
      drug_order_ids_hash[drug_name] = ord.order_id
      drug_enc_ids_hash[drug_name] = ord.encounter_id
      drug_start_date_hash[drug_name] = ord.start_date.strftime("%Y-%m-%d")  rescue nil
      drug_auto_expire_date_hash[drug_name] = ord.auto_expire_date.strftime("%Y-%m-%d")  rescue nil
      drug_quantity_hash[drug_name] = ord.quantity rescue nil
      drug_dose_hash[drug_name] = ord.dose
      drug_frequency_hash[drug_name] = ord.frequency
      drug_equivalent_daily_dose_hash[drug_name] = ord.equivalent_daily_dose
      drug_inventory_ids_hash[drug_name] = ord.drug_inventory_id
    else
      patient_orders[drug_name] = drug_name
      drug_order_ids_hash[drug_name] = ord.order_id
      drug_enc_ids_hash[drug_name] = ord.encounter_id
      drug_start_date_hash[drug_name] = ord.start_date.strftime("%Y-%m-%d")  rescue nil
      drug_auto_expire_date_hash[drug_name] = ord.auto_expire_date.strftime("%Y-%m-%d")  rescue nil
      drug_quantity_hash[drug_name] = ord.quantity rescue nil
      drug_dose_hash[drug_name] = ord.dose
      drug_frequency_hash[drug_name] = ord.frequency
      drug_equivalent_daily_dose_hash[drug_name] = ord.equivalent_daily_dose
      drug_inventory_ids_hash[drug_name] = ord.drug_inventory_id
    end
  end

  count = 1
  (patient_orders).each do |drug_name, name|
    case count
      when 1
       a_hash[:drug_name1] = drug_name
       a_hash[:drug_order_id1] = drug_order_ids_hash[drug_name]
       a_hash[:drug_start_date1] = drug_start_date_hash[drug_name]
       a_hash[:drug_auto_expire_date1] = drug_auto_expire_date_hash[drug_name]
       a_hash[:drug_quantity1] = drug_quantity_hash[drug_name]
       a_hash[:drug_frequency1] = drug_frequency_hash[drug_name]
       a_hash[:drug_dose1] = drug_dose_hash[drug_name]
       a_hash[:drug_equivalent_daily_dose1] = drug_equivalent_daily_dose_hash[drug_name]
       a_hash[:drug_encounter_id1] = drug_enc_ids_hash[drug_name]
       a_hash[:drug_inventory_id1] = drug_inventory_ids_hash[drug_name]
       count += 1
      when 2
       a_hash[:drug_name2] = drug_name
       a_hash[:drug_order_id2] = drug_order_ids_hash[drug_name]
       a_hash[:drug_start_date2] = drug_start_date_hash[drug_name]
       a_hash[:drug_auto_expire_date2] = drug_auto_expire_date_hash[drug_name]
       a_hash[:drug_quantity2] = drug_quantity_hash[drug_name]
       a_hash[:drug_frequency2] = drug_frequency_hash[drug_name]
       a_hash[:drug_dose2] = drug_dose_hash[drug_name]
       a_hash[:drug_equivalent_daily_dose2] = drug_equivalent_daily_dose_hash[drug_name]
       a_hash[:drug_encounter_id2] = drug_enc_ids_hash[drug_name]
       a_hash[:drug_inventory_id2] = drug_inventory_ids_hash[drug_name]
       count += 1
      when 3
       a_hash[:drug_name3] = drug_name
       a_hash[:drug_order_id3] = drug_order_ids_hash[drug_name]
       a_hash[:drug_start_date3] = drug_start_date_hash[drug_name]
       a_hash[:drug_auto_expire_date3] = drug_auto_expire_date_hash[drug_name]
       a_hash[:drug_quantity3] = drug_quantity_hash[drug_name]
       a_hash[:drug_frequency3] = drug_frequency_hash[drug_name]
       a_hash[:drug_dose3] = drug_dose_hash[drug_name]
       a_hash[:drug_equivalent_daily_dose3] = drug_equivalent_daily_dose_hash[drug_name]
       a_hash[:drug_encounter_id3] = drug_enc_ids_hash[drug_name]
       a_hash[:drug_inventory_id3] = drug_inventory_ids_hash[drug_name]
       count += 1
      when 4
       a_hash[:drug_name4] = drug_name
       a_hash[:drug_order_id4] = drug_order_ids_hash[drug_name]
       a_hash[:drug_start_date4] = drug_start_date_hash[drug_name]
       a_hash[:drug_auto_expire_date4] = drug_auto_expire_date_hash[drug_name]
       a_hash[:drug_quantity4] = drug_quantity_hash[drug_name]
       a_hash[:drug_frequency4] = drug_frequency_hash[drug_name]
       a_hash[:drug_dose4] = drug_dose_hash[drug_name]
       a_hash[:drug_equivalent_daily_dose4] = drug_equivalent_daily_dose_hash[drug_name]
       a_hash[:drug_encounter_id4] = drug_enc_ids_hash[drug_name]
       a_hash[:drug_inventory_id4] = drug_inventory_ids_hash[drug_name]
       count += 1
      when 5
       a_hash[:drug_name5] = drug_name
       a_hash[:drug_order_id5] = drug_order_ids_hash[drug_name]
       a_hash[:drug_start_date5] = drug_start_date_hash[drug_name]
       a_hash[:drug_auto_expire_date5] = drug_auto_expire_date_hash[drug_name]
       a_hash[:drug_quantity5] = drug_quantity_hash[drug_name]
       a_hash[:drug_frequency5] = drug_frequency_hash[drug_name]
       a_hash[:drug_dose5] = drug_dose_hash[drug_name]
       a_hash[:drug_equivalent_daily_dose5] = drug_equivalent_daily_dose_hash[drug_name]
       a_hash[:drug_encounter_id5] = drug_enc_ids_hash[drug_name]
       a_hash[:drug_inventory_id5] = drug_inventory_ids_hash[drug_name]
       count += 1
      end
  end

  return generate_sql_string(a_hash)
end

def process_patient_state(patient_id, visit)
  #initialize field and values variables
  fields = ""
  values = ""

  a_hash = {:current_hiv_program_start_date => 'NULL'}
  a_hash = {:current_hiv_program_end_date => 'NULL'}

  patient_state =  PatientProgram.find_by_sql("SELECT patient_outcome(#{patient_id}, '#{visit} 23:59:59') AS state").first.state
  end_date = PatientProgram.find_by_sql("SELECT p.date_completed from patient_state s inner join patient_program p on s.patient_program_id = p.patient_program_id where p.patient_id = #{patient_id} and p.program_id = 1").first.date_completed
  current_hiv_program_end_date = end_date.to_date.strftime('%Y-%m-%d') rescue nil

  if patient_state.blank?
    patient_outcome = "Unknown"
  else
    patient_outcome = patient_state
  end
  if patient_outcome == 'Patient died'
    patient_date_enrolled = Person.find_by_sql("SELECT #{@source_db}.patient_date_enrolled(#{patient_id}) as date_enrolled").first.date_enrolled
    died_in_month = Person.find_by_sql("SELECT #{@source_db}.died_in(#{patient_id}, '#{patient_outcome}', '#{patient_date_enrolled}') AS died_month").first.died_month
    a_hash[:patient_died_month] = died_in_month
  end

  a_hash[:current_hiv_program_state] = "#{patient_outcome}"
  a_hash[:current_hiv_program_start_date] = visit
  a_hash[:current_hiv_program_end_date] = current_hiv_program_end_date

  return generate_sql_string(a_hash)
end

def process_adherence_encounter(encounter, visit, type = 0) #type 0 normal encounter, 1 generate_template only
    patient_adh = {}
    amount_of_drug_brought_to_clinic_hash  = {}
    missed_hiv_drug_const_hash  = {}
    patient_adherence_hash  = {}
    patient_adherence_enc_ids = {}
    amount_of_drug_remaining_at_home_hash  = {}
    amount_of_remaining_drug_order_id_hash = {}

    #initialize field and values variables
    fields = ""
    values = ""
    #create patient adherence field list hash template
    a_hash = {:missed_hiv_drug_construct1 => 'NULL'}

    return generate_sql_string(a_hash) if type == 1
    if encounter != 1
      #find patient's lowest (minimum) adherence if the regimen they were on has multiple drugs
      #6987 = what was the patient adherence for this drug
      patient_adherence =  Encounter.find_by_sql("
                                        select replace(ifnull(value_text, value_numeric), '%', '') as adherence 
                                        from #{@source_db}.obs where concept_id = 6987
                                        and person_id = #{encounter.patient_id}
                                        and DATE(obs_datetime) = DATE('#{visit}')")

      if patient_adherence.blank?
        puts 'Adherence is blank'
      else
        patient_adh = []
        (patient_adherence || []).each do |p|
          patient_adh << p['adherence'].to_i
        end
        
        patient_art_adherence = patient_adh.sort.first

        if patient_art_adherence.to_f >= 95
          adherence = 'Adherent'
        elsif patient_art_adherence.to_f < 95
           adherence = 'Not adherent'
        elsif patient_art_adherence.match(/unknown/i)
           adherence = 'Unknown'
        end
        
        a_hash[:patient_art_adherence] = adherence
      end
      
      (encounter.observations || []).each do |adh|
        if adh.order_id.to_i > 0
        if patient_adh[adh.order_id.to_i].blank?
          if adh.value_text
            answer_value = adh.value_text
          elsif adh.value_numeric
            answer_value = adh.value_numeric
          elsif adh.value_coded
            answer_value = ConceptName.find_by_sql("Select name FROM #{@source_db}.concept_name
                                                    WHERE concept_id = #{adh.value_coded.to_i}
                                                    AND concept_name_type = 'FULLY_SPECIFIED'").first.name
          end
          patient_adh[adh.order_id.to_i] = visit rescue nil
          amount_of_remaining_drug_order_id_hash[adh.order_id.to_i] = adh.order_id rescue nil
          if adh.concept_id == 2540 #amount brought
            amount_of_drug_brought_to_clinic_hash[adh.order_id.to_i] = adh.to_s.split(':')[1].strip rescue nil
          elsif adh.concept_id == 2667 #missed hiv drug
            missed_hiv_drug_const_hash[adh.order_id.to_i] = adh.to_s.split(':')[1].strip rescue nil
          elsif adh.concept_id == 6987 #patient adherence
            patient_adherence_hash[adh.order_id.to_i] = adh.to_s.split(':')[1].strip rescue nil
            patient_adherence_enc_ids[adh.order_id.to_i] = adh.encounter_id rescue nil
          elsif adh.concept_id == 6781 #amount remaining
            amount_of_drug_remaining_at_home_hash[adh.order_id.to_i] = adh.to_s.split(':')[1].strip rescue nil
          end
        else
          patient_adh[adh.order_id.to_i] += visit rescue nil
          amount_of_remaining_drug_order_id_hash[adh.order_id.to_i] += adh.order_id rescue nil
          if adh.concept_id == 2540 #amount brought
            amount_of_drug_brought_to_clinic_hash[adh.order_id.to_i] += adh.to_s.split(':')[1].strip rescue nil
          elsif adh.concept_id == 2667 #missed hiv drug
            missed_hiv_drug_const_hash[adh.order_id.to_i] += adh.to_s.split(':')[1].strip rescue nil
          elsif adh.concept_id == 6987 #patient adherence
            patient_adherence_hash[adh.order_id.to_i] = adh.to_s.split(':')[1].strip rescue nil
            patient_adherence_enc_ids[adh.order_id.to_i] += adh.encounter_id rescue nil
          elsif adh.concept_id == 6781 #amount remaining
            amount_of_drug_remaining_at_home_hash[adh.order_id.to_i] += adh.to_s.split(':')[1].strip rescue nil
          end
        end
      end
    end
end
    count = 1
    (patient_adh || []).each do |order_id, data|
      case count
        when 1
         a_hash[:amount_of_drug1_brought_to_clinic] = amount_of_drug_brought_to_clinic_hash[order_id] rescue nil
         a_hash[:amount_of_drug1_remaining_at_home] = amount_of_drug_remaining_at_home_hash[order_id] rescue nil
         a_hash[:what_was_the_patient_adherence_for_this_drug1] = patient_adherence_hash[order_id] rescue nil
         a_hash[:what_was_the_patient_adherence_for_this_drug1_enc_id] = patient_adherence_enc_ids[order_id] rescue nil
         a_hash[:missed_hiv_drug_construct1] = missed_hiv_drug_const_hash[order_id] rescue nil
         a_hash[:amount_of_remaining_drug1_order_id] = amount_of_remaining_drug_order_id_hash[order_id] rescue nil
         count += 1
        when 2
         a_hash[:amount_of_drug2_brought_to_clinic] = amount_of_drug_brought_to_clinic_hash[order_id] rescue nil
         a_hash[:amount_of_drug2_remaining_at_home] = amount_of_drug_remaining_at_home_hash[order_id] rescue nil
         a_hash[:what_was_the_patient_adherence_for_this_drug2] = patient_adherence_hash[order_id] rescue nil
         a_hash[:what_was_the_patient_adherence_for_this_drug2_enc_id] = patient_adherence_enc_ids[order_id] rescue nil
         a_hash[:missed_hiv_drug_construct2] = missed_hiv_drug_const_hash[order_id] rescue nil
         a_hash[:amount_of_remaining_drug2_order_id] = amount_of_remaining_drug_order_id_hash[order_id] rescue nil
         count += 1
        when 3
         a_hash[:amount_of_drug3_brought_to_clinic] = amount_of_drug_brought_to_clinic_hash[order_id] rescue nil
         a_hash[:amount_of_drug3_remaining_at_home] = amount_of_drug_remaining_at_home_hash[order_id] rescue nil
         a_hash[:what_was_the_patient_adherence_for_this_drug3] = patient_adherence_hash[order_id] rescue nil
         a_hash[:what_was_the_patient_adherence_for_this_drug3_enc_id] = patient_adherence_enc_ids[order_id] rescue nil
         a_hash[:missed_hiv_drug_construct3] = missed_hiv_drug_const_hash[order_id] rescue nil
         a_hash[:amount_of_remaining_drug3_order_id] = amount_of_remaining_drug_order_id_hash[order_id] rescue nil
         count += 1
        when 4
         a_hash[:amount_of_drug4_brought_to_clinic] = amount_of_drug_brought_to_clinic_hash[order_id] rescue nil
         a_hash[:amount_of_drug4_remaining_at_home] = amount_of_drug_remaining_at_home_hash[order_id] rescue nil
         a_hash[:what_was_the_patient_adherence_for_this_drug4] = patient_adherence_hash[order_id] rescue nil
         a_hash[:what_was_the_patient_adherence_for_this_drug4_enc_id] = patient_adherence_enc_ids[order_id] rescue nil
         a_hash[:missed_hiv_drug_construct4] = missed_hiv_drug_const_hash[order_id] rescue nil
         a_hash[:amount_of_remaining_drug4_order_id] = amount_of_remaining_drug_order_id_hash[order_id] rescue nil
         count += 1
        when 5
         a_hash[:amount_of_drug5_brought_to_clinic] = amount_of_drug_brought_to_clinic_hash[order_id] rescue nil
         a_hash[:amount_of_drug5_remaining_at_home] = amount_of_drug_remaining_at_home_hash[order_id] rescue nil
         a_hash[:what_was_the_patient_adherence_for_this_drug5] = patient_adherence_hash[order_id] rescue nil
         a_hash[:what_was_the_patient_adherence_for_this_drug5_enc_id] = patient_adherence_enc_ids[order_id] rescue nil
         a_hash[:missed_hiv_drug_construct5] = missed_hiv_drug_const_hash[order_id] rescue nil
         a_hash[:amount_of_remaining_drug5_order_id] = amount_of_remaining_drug_order_id_hash[order_id] rescue nil
         count += 1
     end
    end
  return generate_sql_string(a_hash)
end

def process_all_guardians_not_on_arvs
    a_hash = {:legacy_id2 => 'NULL'}

    guardian_list = Patient.find_by_sql("SELECT
                                            guardian_id,
                                            gender,
                                            given_name,
                                            family_name,
                                            middle_name,
                                            birthdate_estimated,
                                            birthdate,
                                            home_district,
                                            current_district,
                                            landmark,
                                            current_residence,
                                            traditional_authority,
                                            date_enrolled,
                                            earliest_start_date,
                                            death_date,
                                            age_at_initiation,
                                            age_in_days
                                        FROM
                                            guardians
                                        WHERE
                                            guardian_id NOT IN (SELECT
                                                                  patient_id
                                                                FROM
                                                                 earliest_start_date)
                                        GROUP BY guardian_id").each{|guardian| guardian}
     guardian_list.each do |guardian|
       a_hash[:patient_id] = patient_id
       a_hash[:given_name] = this_patient.first.given_name rescue nil
       a_hash[:middle_name] = this_patient.first.middle_name rescue nil
       a_hash[:family_name] = this_patient.first.family_name rescue nil
       a_hash[:gender] = gender  rescue nil
       a_hash[:dob] = this_patient.first.birthdate rescue nil
       a_hash[:dob_estimated] = this_patient.first.birthdate_estimated rescue nil
       a_hash[:death_date] =  this_patient.first.death_date rescue nil

       a_hash[:ta] = this_patient.first.traditional_authority  rescue nil
       a_hash[:current_address] = this_patient.first.current_residence  rescue nil
       a_hash[:home_district] = this_patient.first.home_district  rescue nil
       a_hash[:landmark] = this_patient.first.landmark  rescue nil

       a_hash[:cellphone_number] = the_attributes.first.cell_phone  rescue nil
       a_hash[:home_phone_number] = the_attributes.first.home_phone  rescue nil
       a_hash[:office_phone_number] = the_attributes.first.office_phone  rescue nil
       a_hash[:occupation] = the_attributes.first.occupation  rescue nil

       a_hash[:nat_id] = the_identifiers.first.national_id  rescue nil
       a_hash[:arv_number]  = the_identifiers.first.arv_number  rescue nil
       a_hash[:pre_art_number] = the_identifiers.first.pre_art_number  rescue nil
       a_hash[:tb_number]  = the_identifiers.first.tb_number  rescue nil
       a_hash[:legacy_id]  = the_identifiers.first.legacy_id  rescue nil
       a_hash[:prev_art_number]  = the_identifiers.first.prev_art_number rescue nil
       a_hash[:filing_number]  = the_identifiers.first.filing_number  rescue nil
       a_hash[:archived_filing_number]  = the_identifiers.first.archived_filing_number rescue nil

       a_hash[:earliest_start_date]  = this_patient.first.earliest_start_date  rescue nil
       a_hash[:date_enrolled] = this_patient.first.date_enrolled rescue nil
       a_hash[:age_at_initiation] = this_patient.first.age_at_initiation rescue nil
       a_hash[:age_in_days] = this_patient.first.age_in_days rescue nil
       a_hash[:current_location] = current_location rescue nil

       puts"<<<<<<<<<<<<<<Working on #{guardian.guardian_id}>>>>>>>>>>>>>>>>>>>"
      return generate_sql_string(a_hash)
    end
end

def generate_sql_string(a_hash)
   fields = ""
   values = ""

    a_hash.each do |key,value|
        fields += fields.empty? ? "`#{key}`" : ", `#{key}`"
      	str = '"' + value.to_s + '"'
        values += values.empty? ? "#{str}" : ", #{str}"
    end

    return [fields, values]
end

def start
 initialize_variables
 #get_all_patients
 #specify patients_list, if you want to debug a list of patients
 specify_patients_list = []
 specify_patients_list = specify_patients_list.join(',') rescue specify_patients_list

 patients_list = []

 if !specify_patients_list.blank?
   patients_list = specify_patients_list
 else
   patients_list = $patient_demographics.collect{|p| p.patient_id}
 end

 #patients_list = []
 if (!specify_patients_list.blank?) && (patients_list.blank?)
  puts"<<<<<<<<<<<<<<These patients are voided: #{specify_patients_list}>>>>>>>>>>>>>>>>>>>"
 else
    if patients_list.length != 0
      initiate_special_script(patients_list)
    else
      initiate_script
    end
  end
end

def get_drug_list
  drug_hash = {}
  drug_list = Drug.find_by_sql("SELECT drug_id, name FROM #{@source_db}.drug")
  drug_list.each do |drug|
    drug_hash[:"#{drug.drug_id}"] = drug.name
  end
  return drug_hash
end

start
