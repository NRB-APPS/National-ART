require 'yaml'
Connection = ActiveRecord::Base.connection

if ARGV[0].nil?
  raise "Please include the environment that you would like to choose. Either development or production"
else
  @environment = ARGV[0]
end


def initialize_variables
  @source_db = YAML.load(File.open(File.join(RAILS_ROOT, "config/database.yml"), "r"))["#{@environment}"]["database"]
  @started_at = Time.now.strftime("%Y-%m-%d-%H%M%S")
end


def get_all_patients
    puts "started at #{@started_at}"
    #open files for writing
    $temp_outfile_1 = File.open("./db/flat_tables_init_output/flat_cohort_table-" + @started_at + ".sql", "w")
    $temp_outfile_3 = File.open("./db/flat_tables_init_output/patients_initialized_in_flat_cohort_table-" + @started_at + ".sql", "w")
    $temp_outfile_4 = File.open("./db/flat_tables_init_output/guardians-" + @started_at + ".sql", "w")
    $temp_outfile_5 = File.open("./db/flat_tables_init_output/guardians_initialized_in_flat_cohort_table-" + @started_at + ".sql", "w")

    patient_list = Patient.find_by_sql("SELECT patient_id FROM #{@source_db}.flat_table1
                                        WHERE patient_id IN (SELECT patient_id FROM #{@source_db}.temp_earliest_start_date) GROUP BY patient_id").map(&:patient_id)

    $flat_table_1_patients_list = Encounter.find_by_sql("SELECT *
                                              FROM #{@source_db}.flat_table1
                                              WHERE patient_id IN (#{patient_list.join(',')})")

  $guardians = []
  $guardians = Patient.find_by_sql("SELECT patient_id, guardian_id FROM #{@source_db}.guardians")

  $guardians_not_on_art = []
  $guardians_not_on_art = Patient.find_by_sql("SELECT * FROM #{@source_db}.guardians
                                               WHERE guardian_id NOT IN (SELECT patient_id FROM #{@source_db}.temp_earliest_start_date ) GROUP BY guardian_id")
    patient_list.each do |p|
      $temp_outfile_3 << "#{p},"
      puts ">>working on patient>>>#{p}<<<<<<<"
      sql_statements = get_patients_data(p)
      $temp_outfile_1 << sql_statements[0]
      puts ">>finished working on patient>>>#{p}<<<<<<<"
    end

    $guardians_not_on_art.each do |guardian|
      $temp_outfile_5 << "#{guardian.guardian_id},"
      puts ">>working on guardian>>>#{guardian.guardian_id}<<<<<<<"
      sql_statements = process_all_guardians_not_on_arvs(guardian)
      $temp_outfile_4 << sql_statements[0]
      puts ">>finished working on guardian>>>#{guardian.guardian_id}<<<<<<<"
    end

    #close files
    $temp_outfile_1.close
    $temp_outfile_3.close
    $temp_outfile_4.close
    $temp_outfile_5.close
    puts "ended at #{Time.now.strftime("%Y-%m-%d-%H%M%S")}"
end

def process_all_guardians_not_on_arvs(guardian_data)
   initial_flat_table1_string = "INSERT INTO flat_table1 "
   guardian_details = []

   #get_guardians_data
   guardian_details = $guardians_not_on_art.select{|guardian| guardian.guardian_id == guardian_data.guardian_id}
#   raise guardian_details.to_yaml
   if guardian_details
     guardian_details = process_guardians(guardian_data.guardian_id)
   end

  #check if any of the strings are empty
  guardian_details = process_guardians(guardian_data.guardian_id) if guardian_details.empty?

  #write sql statement
  flat_table_1_sql_statement = initial_flat_table1_string + "(" + guardian_details[0] + ")" + \
  	 " VALUES (" + guardian_details[1] + ");"

   return [flat_table_1_sql_statement]
end

def process_guardians(guardian_id, type = 0)
  #initialize field and values variables
  fields = ""
  values = ""

  #create guardians field list hash template
  a_hash = {  :legacy_id2 => 'NULL'}

  this_guardian = $guardians_not_on_art.select{|guardian| guardian.guardian_id == guardian_id} rescue []
  the_identifiers = $patient_identifiers.select{|patient| patient.patient_id == guardian_id} rescue []
  the_attributes = $patient_attributes.select{|patient| patient.person_id == guardian_id} rescue []

  guardian_person_ids = $guardians.select{|person| person.patient_id == guardian_id}.map(&:guardian_id) rescue []
  guardian_to_which_patient_ids = $guardians.select{|person| person.guardian_id == guardian_id}.map(&:patient_id) rescue []

  a_hash[:patient_id] = this_guardian.first.guardian_id
  a_hash[:given_name] = this_guardian.first.given_name rescue nil
  a_hash[:middle_name] = this_guardian.first.middle_name rescue nil
  a_hash[:family_name] = this_guardian.first.family_name rescue nil
  a_hash[:gender] = this_guardian.first.gender  rescue nil #this_guardian.gender  rescue nil
  a_hash[:dob] = this_guardian.first.birthdate rescue nil
  a_hash[:dob_estimated] = this_guardian.first.birthdate_estimated rescue nil
  a_hash[:death_date] =  this_guardian.first.death_date rescue nil

  a_hash[:ta] = this_guardian.first.traditional_authority  rescue nil
  a_hash[:current_address] = this_guardian.first.current_residence  rescue nil
  a_hash[:home_district] = this_guardian.first.home_district  rescue nil
  a_hash[:landmark] = this_guardian.first.landmark  rescue nil

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

    return generate_sql_string(a_hash)
end

def get_patients_data(patient_id)
   #building flat_cohort_table

   initial_flat_table1_string = "INSERT INTO flat_cohort_table "

   flat_table_1_data = []; flat_table_2_data = []

   #get flat_table1 data
   flat_table_1_data = $flat_table_1_patients_list.select {|patient| patient.patient_id == patient_id}

   if flat_table_1_data
      flat_table1 = process_flat_table_1(flat_table_1_data)
   end

   #get flat_table2 data

    flat_table_2_data = Connection.select_all("SELECT  *
                            FROM #{@source_db}.flat_table2
                            WHERE patient_id = #{patient_id}
                            ORDER BY visit_date DESC
                            LIMIT 1")

   if flat_table_2_data
      flat_table2 = process_flat_table_2(flat_table_2_data)
   end
  #check if any of the strings are empty
  flat_table1 = process_flat_table_1(flat_table_1_data) if flat_table1.empty?
  flat_table2 = process_flat_table_2(flat_table_2_data) if flat_table2.empty?

  #write sql statement
  #raise hiv_staging[1].to_yaml
  flat_cohort_table_sql_statement = initial_flat_table1_string + "(" + flat_table1[0] + "," + flat_table2[0] + ")" + \
                " VALUES (" + flat_table1[1] + "," + flat_table2[1] + ");"


   return [flat_cohort_table_sql_statement]
end

def process_flat_table_1(flat_table_1_data, type = 0) #type 0 normal encounter, 1 generate_template only

    #initialize field and values variables
    fields = ""
    values = ""

    #create flat_table1 field list hash template
    a_hash = {  :ever_registered_at_art_clinic_v_date => 'NULL'}

    return generate_sql_string(a_hash) if type == 1

    (flat_table_1_data || []).each do |patient|
      unless patient.date_enrolled.blank?
        re_initiated = Connection.select_one("SELECT #{@source_db}.re_initiated_check(#{patient.patient_id}, '#{patient.date_enrolled}') AS re_initiated")
      end

      pat = Patient.find_by_patient_id(patient.patient_id)
      a_hash[:patient_id] = patient.patient_id
      a_hash[:gender] = patient.gender
      a_hash[:birthdate] = patient.dob
      a_hash[:death_date] = patient.death_date
      a_hash[:earliest_start_date] = patient.earliest_start_date
      a_hash[:date_enrolled] = patient.date_enrolled
      a_hash[:age_at_initiation] = patient.age_at_initiation
      a_hash[:age_in_days] = patient.age_in_days
      a_hash[:patient_re_initiated] = re_initiated['re_initiated'] rescue nil
      a_hash[:reason_for_starting] = patient.reason_for_eligibility
      a_hash[:who_stage] = patient.who_stage
      a_hash[:who_stages_criteria_present] = patient.who_stages_criteria_present
      a_hash[:ever_registered_at_art_clinic] = patient.ever_registered_at_art_clinic
      a_hash[:date_art_last_taken] = patient.date_art_last_taken
      a_hash[:taken_art_in_last_two_months] = patient.taken_art_in_last_two_months
      a_hash[:extrapulmonary_tuberculosis] = patient.extrapulmonary_tuberculosis
      a_hash[:pulmonary_tuberculosis] = patient.pulmonary_tuberculosis
      a_hash[:pulmonary_tuberculosis_last_2_years] = patient.pulmonary_tuberculosis_last_2_years
      a_hash[:kaposis_sarcoma] = patient.kaposis_sarcoma
      a_hash[:current_location] = patient.current_location
      a_hash[:extrapulmonary_tuberculosis_v_date] = patient.extrapulmonary_tuberculosis_v_date
      a_hash[:pulmonary_tuberculosis_v_date] = patient.pulmonary_tuberculosis_v_date
      a_hash[:pulmonary_tuberculosis_last_2_years_v_date] = patient.pulmonary_tuberculosis_last_2_years_v_date
      a_hash[:kaposis_sarcoma_v_date] = patient.kaposis_sarcoma_v_date
      a_hash[:reason_for_starting_v_date] = patient.reason_for_eligibility_v_date
      a_hash[:ever_registered_at_art_clinic_v_date] = patient.ever_registered_at_art_clinic_v_date
      a_hash[:date_art_last_taken_v_date] = patient.date_art_last_taken_v_date
      a_hash[:taken_art_in_last_two_months_v_date] = patient.taken_art_in_last_two_months_v_date
   end

    return generate_sql_string(a_hash)
end

def process_flat_table_2(flat_table_2_data, type = 0) #type 0 normal encounter, 1 generate_template only

    #initialize field and values variables
    fields = ""
    values = ""

    #create flat_table2 field list hash template
    a_hash = {  :drug_auto_expire_date5_v_date => 'NULL'}

    return generate_sql_string(a_hash) if type == 1

    (flat_table_2_data || []).each do |patient|
      a_hash[:hiv_program_state] = patient['current_hiv_program_state']
      a_hash[:hiv_program_start_date] = patient['current_hiv_program_start_date']
      a_hash[:patient_died_month] = patient['patient_died_month']
      a_hash[:patient_pregnant] = patient['patient_pregnant']
      a_hash[:drug_induced_abdominal_pain] = patient['drug_induced_abdominal_pain']
      a_hash[:drug_induced_anorexia] = patient['drug_induced_anorexia']
      a_hash[:drug_induced_diarrhea] = patient['drug_induced_diarrhea']
      a_hash[:drug_induced_jaundice] = patient['drug_induced_jaundice']
      a_hash[:drug_induced_leg_pain_numbness] = patient['drug_induced_leg_pain_numbness']
      a_hash[:drug_induced_vomiting] = patient['drug_induced_vomiting']
      a_hash[:drug_induced_peripheral_neuropathy] = patient['drug_induced_peripheral_neuropathy']
      a_hash[:drug_induced_hepatitis] = patient['drug_induced_hepatitis']
      a_hash[:drug_induced_anemia] = patient['drug_induced_anemia']
      a_hash[:drug_induced_lactic_acidosis] = patient['drug_induced_lactic_acidosis']
      a_hash[:drug_induced_lipodystrophy] = patient['drug_induced_lipodystrophy']
      a_hash[:drug_induced_skin_rash] = patient['drug_induced_skin_rash']
      a_hash[:drug_induced_other] = patient['drug_induced_other']
      a_hash[:drug_induced_fever] = patient['drug_induced_fever']
      a_hash[:drug_induced_cough] = patient['drug_induced_cough']
      a_hash[:drug_induced_kidney_failure] = patient['drug_induced_kidney_failure']
      a_hash[:drug_induced_nightmares] = patient['drug_induced_nightmares']
      a_hash[:drug_induced_diziness] = patient['drug_induced_diziness']
      a_hash[:drug_induced_psychosis] = patient['drug_induced_psychosis']
      a_hash[:drug_induced_blurry_vision] = patient['drug_induced_blurry_vision']

      a_hash[:side_effects_abdominal_pain] = patient['side_effects_peripheral_neuropathy']
      a_hash[:side_effects_anemia] = patient['side_effects_anemia']
      a_hash[:side_effects_anorexia] = patient['side_effects_anorexia']
      a_hash[:side_effects_blurry_vision] = patient['side_effects_blurry_vision']
      a_hash[:side_effects_cough] = patient['side_effects_cough']
      a_hash[:side_effects_diarrhea] = patient['side_effects_diarrhea']
      a_hash[:side_effects_diziness] = patient['side_effects_diziness']
      a_hash[:side_effects_fever] = patient['side_effects_fever']
      a_hash[:side_effects_hepatitis] = patient['side_effects_hepatitis']
      a_hash[:side_effects_jaundice] = patient['side_effects_jaundice']
      a_hash[:side_effects_kidney_failure] = patient['side_effects_kidney_failure']
      a_hash[:side_effects_lactic_acidosis] = patient['side_effects_lactic_acidosis']
      a_hash[:side_effects_leg_pain_numbness] = patient['side_effects_leg_pain_numbness']
      a_hash[:side_effects_lipodystrophy] = patient['side_effects_lipodystrophy']
      a_hash[:side_effects_no] = patient['side_effects_no']
      a_hash[:side_effects_other] = patient['side_effects_Other']
      a_hash[:side_effects_peripheral_neuropathy] = patient['side_effects_peripheral_neuropathy']
      a_hash[:side_effects_psychosis] = patient['side_effects_psychosis']
      a_hash[:side_effects_renal_failure] = patient['side_effects_renal_failure']
      a_hash[:side_effects_skin_rash] = patient['side_effects_skin_rash']
      a_hash[:side_effects_vomiting] = patient['side_effects_vomiting']
      a_hash[:side_effects_gynaecomastia] = patient['side_effects_gynaecomastia']
      a_hash[:side_effects_nightmares] = patient['side_effects_nightmares']

      a_hash[:tb_status] = patient['tb_status']
      a_hash[:tb_not_suspected] = patient['tb_status_tb_not_suspected']
      a_hash[:tb_suspected] = patient['tb_status_tb_suspected']
      a_hash[:confirmed_tb_not_on_treatment] = patient['tb_status_confirmed_tb_not_on_treatment']
      a_hash[:confirmed_tb_on_treatment] = patient['tb_status_confirmed_tb_on_treatment']
      a_hash[:unknown_tb_status] = patient['tb_status_unknown']
      a_hash[:regimen_category_treatment] = patient['regimen_category_treatment']
      a_hash[:regimen_category_dispensed] = patient['regimen_category_dispensed']
  
  #regimen category to be added in flat_cohort_table
      a_hash[:type_of_ARV_regimen_given] = patient['type_of_ARV_regimen_given']
      a_hash[:arv_regimens_received_construct] = patient['arv_regimens_received_construct']
      a_hash[:what_was_the_patient_adherence_for_this_drug1] = patient['what_was_the_patient_adherence_for_this_drug1']
      a_hash[:what_was_the_patient_adherence_for_this_drug2] = patient['what_was_the_patient_adherence_for_this_drug2']
      a_hash[:what_was_the_patient_adherence_for_this_drug3] = patient['what_was_the_patient_adherence_for_this_drug3']
      a_hash[:what_was_the_patient_adherence_for_this_drug4] = patient['what_was_the_patient_adherence_for_this_drug4']
      a_hash[:what_was_the_patient_adherence_for_this_drug5] = patient['what_was_the_patient_adherence_for_this_drug5']
      a_hash[:drug_name1] = patient['drug_name1']
      a_hash[:drug_name2] = patient['drug_name2']
      a_hash[:drug_name3] = patient['drug_name3']
      a_hash[:drug_name4] = patient['drug_name4']
      a_hash[:drug_name5] = patient['drug_name5']
      a_hash[:drug_inventory_id1] = patient['drug_inventory_id1']
      a_hash[:drug_inventory_id2] = patient['drug_inventory_id2']
      a_hash[:drug_inventory_id3] = patient['drug_inventory_id3']
      a_hash[:drug_inventory_id4] = patient['drug_inventory_id4']
      a_hash[:drug_inventory_id5] = patient['drug_inventory_id5']
      a_hash[:drug_auto_expire_date1] = patient['drug_auto_expire_date1']
      a_hash[:drug_auto_expire_date2] = patient['drug_auto_expire_date2']
      a_hash[:drug_auto_expire_date3] = patient['drug_auto_expire_date3']
      a_hash[:drug_auto_expire_date4] = patient['drug_auto_expire_date4']
      a_hash[:drug_auto_expire_date5] = patient['drug_equivalent_daily_dose5']

      a_hash[:hiv_program_state_v_date] = patient['visit_date']
      a_hash[:hiv_program_start_date_v_date] = patient['visit_date']
      a_hash[:current_tb_status_v_date] = patient['visit_date']
      a_hash[:patient_pregnant_v_date] = patient['visit_date']
      a_hash[:drug_induced_abdominal_pain_v_date] = patient['visit_date']
      a_hash[:drug_induced_anorexia_v_date] = patient['visit_date']
      a_hash[:drug_induced_diarrhea_v_date] = patient['visit_date']
      a_hash[:drug_induced_jaundice_v_date] = patient['visit_date']
      a_hash[:drug_induced_leg_pain_numbness_v_date] = patient['visit_date']
      a_hash[:drug_induced_vomiting_v_date] = patient['visit_date']
      a_hash[:drug_induced_peripheral_neuropathy_v_date] = patient['visit_date']
      a_hash[:drug_induced_hepatitis_v_date] = patient['visit_date']
      a_hash[:drug_induced_anemia_v_date] = patient['visit_date']
      a_hash[:drug_induced_lactic_acidosis_v_date] = patient['visit_date']
      a_hash[:drug_induced_lipodystrophy_v_date] = patient['visit_date']
      a_hash[:drug_induced_skin_rash_v_date] = patient['visit_date']
      a_hash[:drug_induced_other_v_date] = patient['visit_date']
      a_hash[:drug_induced_fever_v_date] = patient['visit_date']
      a_hash[:drug_induced_cough_v_date] = patient['visit_date']
      a_hash[:tb_not_suspected_v_date] = patient['visit_date']
      a_hash[:tb_suspected_v_date] = patient['visit_date']
      a_hash[:confirmed_tb_not_on_treatment_v_date] = patient['visit_date']
      a_hash[:confirmed_tb_on_treatment_v_date] = patient['visit_date']
      a_hash[:unknown_tb_status_v_date] = patient['visit_date']
      a_hash[:what_was_the_patient_adherence_for_this_drug1_v_date] = patient['visit_date']
      a_hash[:what_was_the_patient_adherence_for_this_drug2_v_date] = patient['visit_date']
      a_hash[:what_was_the_patient_adherence_for_this_drug3_v_date] = patient['visit_date']
      a_hash[:what_was_the_patient_adherence_for_this_drug4_v_date] = patient['visit_date']
      a_hash[:what_was_the_patient_adherence_for_this_drug5_v_date] = patient['visit_date']
      a_hash[:drug_name1_v_date] = patient['visit_date']
      a_hash[:drug_name2_v_date] = patient['visit_date']
      a_hash[:drug_name3_v_date] = patient['visit_date']
      a_hash[:drug_name4_v_date] = patient['visit_date']
      a_hash[:drug_name5_v_date] = patient['visit_date']
      a_hash[:drug_inventory_id1_v_date] = patient['visit_date']
      a_hash[:drug_inventory_id2_v_date] = patient['visit_date']
      a_hash[:drug_inventory_id3_v_date] = patient['visit_date']
      a_hash[:drug_inventory_id4_v_date] = patient['visit_date']
      a_hash[:drug_inventory_id5_v_date] = patient['visit_date']
      a_hash[:drug_auto_expire_date1_v_date] = patient['visit_date']
      a_hash[:drug_auto_expire_date2_v_date] = patient['visit_date']
      a_hash[:drug_auto_expire_date3_v_date] = patient['visit_date']
      a_hash[:drug_auto_expire_date4_v_date] = patient['visit_date']
      a_hash[:drug_auto_expire_date5_v_date] = patient['visit_date']


   end
    return generate_sql_string(a_hash)
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
 get_all_patients
end

start
