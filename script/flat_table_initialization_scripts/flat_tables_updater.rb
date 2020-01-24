
User.current = User.find(1)
=begin
ART tables in OpenMRS
1.  encounter
2.  obs
3.  orders
4.  drug_orders
6.  patient
7.  person
8.  person_name
9.  person_address
10. person_attribute
11. patient_identifier
12. patient_program
13. patient_state
14. program_workflow
15. program_workflow_state
16. relationship
=end

UniqPatientIds = []
Connection = ActiveRecord::Base.connection

Current_date = Date.today

def start
  start_time = DateTime.now
=begin
  Getting all changed rows in encounter table
=end
  
  #getting the the max date the flat tables were updated
  max_flat_table2_max = nil
  max_updater_table_date = nil

  Connection.select_one("SELECT max(visit_date) as visit_date FROM flat_table2").map do |vDate|
    max_flat_table2_max = vDate[1]
  end

  Connection.select_one("SELECT max(DATE(updated_date)) FROM flat_tables_updater_log_details").map do |vDate|
    max_updater_table_date = vDate[1]
  end

  if max_updater_table_date.blank?
    start_date = max_flat_table2_max
  else
    start_date = max_updater_table_date
  end

  start_date = Current_date if start_date.blank?

  patient_ids_in_earliest_start_date = get_earliest_start_date_patients(start_date)


  if patient_ids_in_earliest_start_date.blank?
    puts "No changes found on #{Current_date.strftime('%A, %d %B %Y')}"
    return
  end

  puts "Getting all changed rows in encounter table"

  enc_patient_ids = Connection.select_all("
    SELECT patient_id FROM encounter e
    WHERE (date(date_created) >= DATE('#{start_date}') OR
    DATE(date_changed) >= DATE('#{start_date}') OR
    DATE(date_voided) >= DATE('#{start_date}'))
    AND patient_id IN(#{patient_ids_in_earliest_start_date.join(',')})
    GROUP BY patient_id
  ").collect{|p|p["patient_id"].to_i}
=begin
  Getting all changed rows in obs table
=end

  puts "Getting all changed rows in obs table"

  obs_patient_ids = Connection.select_all("
    SELECT person_id FROM obs
    WHERE (date(date_created) >= DATE('#{start_date}') OR
    DATE(date_voided) >= DATE('#{start_date}'))
    AND person_id IN(#{patient_ids_in_earliest_start_date.join(',')})
    GROUP BY person_id
  ").collect{|p|p["person_id"].to_i}

=begin
  Getting all changed rows in orders table
=end

  orders_patient_ids = Connection.select_all("
    SELECT patient_id FROM orders
    WHERE (date(date_created) >= DATE('#{start_date}') OR
    DATE(date_voided) >= DATE('#{start_date}'))
    AND patient_id IN(#{patient_ids_in_earliest_start_date.join(',')})
    GROUP BY patient_id
  ").collect{|p|p["patient_id"].to_i}

=begin
  Getting all changed rows in patient table
=end

  patient_patient_ids = Connection.select_all("
    SELECT patient_id FROM patient
    WHERE (date(date_created) >= DATE('#{start_date}') OR
    DATE(date_voided) >= DATE('#{start_date}'))
    AND patient_id IN(#{patient_ids_in_earliest_start_date.join(',')})
    GROUP BY patient_id
  ").collect{|p|p["patient_id"].to_i}

=begin
  Getting all changed rows in person table
=end

  person_patient_ids = Connection.select_all("
    SELECT person_id FROM person
    WHERE (date(date_created) >= DATE('#{start_date}') OR
    DATE(date_changed) >= DATE('#{start_date}') OR
    DATE(date_voided) >= DATE('#{start_date}'))
    AND person_id IN(#{patient_ids_in_earliest_start_date.join(',')})
    GROUP BY person_id
  ").collect{|p|p["person_id"].to_i}

=begin
  Getting all changed rows in person_name table
=end

  person_name_patient_ids = Connection.select_all("
    SELECT person_id FROM person_name
    WHERE (date(date_created) >= DATE('#{start_date}') OR
    DATE(date_changed) >= DATE('#{start_date}') OR
    DATE(date_voided) >= DATE('#{start_date}'))
    AND person_id IN(#{patient_ids_in_earliest_start_date.join(',')})
    GROUP BY person_id
  ").collect{|p|p["person_id"].to_i}

=begin
  Getting all changed rows in person_address table
=end

  person_address_patient_ids = Connection.select_all("
    SELECT person_id FROM person_address
    WHERE (date(date_created) >= DATE('#{start_date}') OR
    DATE(date_voided) >= DATE('#{start_date}'))
    AND person_id IN(#{patient_ids_in_earliest_start_date.join(',')})
    GROUP BY person_id
  ").collect{|p|p["person_id"].to_i}

=begin
  Getting all changed rows in person_attribute table
=end
   person_attribute_patient_ids = Connection.select_all("
    SELECT person_id FROM person_attribute
    WHERE (date(date_created) >= DATE('#{start_date}') OR
    DATE(date_changed) >= DATE('#{start_date}') OR
    DATE(date_voided) >= DATE('#{start_date}'))
    AND person_id IN(#{patient_ids_in_earliest_start_date.join(',')})
    GROUP BY person_id
  ").collect{|p|p["person_id"].to_i}

=begin
  Getting all changed rows in patient_identifier table
=end

  patient_identifier_patient_ids = Connection.select_all("
    SELECT patient_id FROM patient_identifier
    WHERE (date(date_created) >= DATE('#{start_date}') OR
    DATE(date_voided) >= DATE('#{start_date}'))
    AND patient_id IN(#{patient_ids_in_earliest_start_date.join(',')})
    GROUP BY patient_id
  ").collect{|p|p["patient_id"].to_i}

=begin
  Getting all changed rows in patient_program table
=end

  patient_program_patient_ids = Connection.select_all("
    SELECT patient_id FROM patient_program
    WHERE (date(date_created) >= DATE('#{start_date}') OR
    DATE(date_changed) >= DATE('#{start_date}') OR
    DATE(date_voided) >= DATE('#{start_date}'))
    AND patient_id IN(#{patient_ids_in_earliest_start_date.join(',')})
    GROUP BY patient_id
  ").collect{|p|p["patient_id"].to_i}

=begin
  Getting all changed rows in patient_state table
=end

  patient_state_patient_ids = Connection.select_all("
    SELECT p.patient_id FROM patient_program p
    inner join patient_state s ON s.patient_program_id = p.patient_program_id
    WHERE (date(s.date_created) >= DATE('#{start_date}') OR date(s.date_changed) >= DATE('#{start_date}'))
    AND p.patient_id IN(#{patient_ids_in_earliest_start_date.join(',')})
    group by p.patient_id
  ").collect{|p|p["p.patient_id"].to_i}

  puts "Getting all changed rows in orders table"

=begin
  Getting all changed rows in patient table
=end

  puts "Getting all changed rows in patient table"

  patient_patient_ids = Connection.select_all("
    SELECT patient_id FROM patient
    WHERE (date(date_created) >= DATE('#{start_date}') OR
    DATE(date_voided) >= DATE('#{start_date}'))
    AND patient_id IN(#{patient_ids_in_earliest_start_date.join(',')})
    GROUP BY patient_id
  ").collect{|p|p["patient_id"].to_i}

=begin
  Getting all changed rows in person table
=end

  puts "Getting all changed rows in person table"

  person_patient_ids = Connection.select_all("
    SELECT person_id FROM person
    WHERE (date(date_created) >= DATE('#{start_date}') OR
    DATE(date_changed) >= DATE('#{start_date}') OR
    DATE(date_voided) >= DATE('#{start_date}'))
    AND person_id IN(#{patient_ids_in_earliest_start_date.join(',')})
    GROUP BY person_id
  ").collect{|p|p["person_id"].to_i}

=begin
  Getting all changed rows in person_name table
=end

  puts "Getting all changed rows in person_name table"

  person_name_patient_ids = Connection.select_all("
    SELECT person_id FROM person_name
    WHERE (date(date_created) >= DATE('#{start_date}') OR
    DATE(date_changed) >= DATE('#{start_date}') OR
    DATE(date_voided) >= DATE('#{start_date}'))
    AND person_id IN(#{patient_ids_in_earliest_start_date.join(',')})
    GROUP BY person_id
  ").collect{|p|p["person_id"].to_i}

=begin
  Getting all changed rows in person_address table
=end

  puts "Getting all changed rows in person_address table"

  person_address_patient_ids = Connection.select_all("
    SELECT person_id FROM person_address
    WHERE (date(date_created) >= DATE('#{start_date}') OR
    DATE(date_voided) >= DATE('#{start_date}'))
    AND person_id IN(#{patient_ids_in_earliest_start_date.join(',')})
    GROUP BY person_id
  ").collect{|p|p["person_id"].to_i}

=begin
  Getting all changed rows in person_attribute table
=end

   puts "Getting all changed rows in person_attribute table"

   person_attribute_patient_ids = Connection.select_all("
    SELECT person_id FROM person_attribute
    WHERE (date(date_created) >= DATE('#{start_date}') OR
    DATE(date_changed) >= DATE('#{start_date}') OR
    DATE(date_voided) >= DATE('#{start_date}'))
    AND person_id IN(#{patient_ids_in_earliest_start_date.join(',')})
    GROUP BY person_id
  ").collect{|p|p["person_id"].to_i}

=begin
  Getting all changed rows in patient_identifier table
=end

  puts "Getting all changed rows in patient_identifier table"

  patient_identifier_patient_ids = Connection.select_all("
    SELECT patient_id FROM patient_identifier
    WHERE (date(date_created) >= DATE('#{start_date}') OR
    DATE(date_voided) >= DATE('#{start_date}'))
    AND patient_id IN(#{patient_ids_in_earliest_start_date.join(',')})
    GROUP BY patient_id
  ").collect{|p|p["patient_id"].to_i}

=begin
  Getting all changed rows in patient_program table
=end

  puts "Getting all changed rows in patient_program table"

  patient_program_patient_ids = Connection.select_all("
    SELECT patient_id FROM patient_program
    WHERE (date(date_created) >= DATE('#{start_date}') OR
    DATE(date_changed) >= DATE('#{start_date}') OR
    DATE(date_voided) >= DATE('#{start_date}'))
    AND patient_id IN(#{patient_ids_in_earliest_start_date.join(',')})
    GROUP BY patient_id
  ").collect{|p|p["patient_id"].to_i}

=begin
  Getting all changed rows in patient_state table
=end

  puts "Getting all changed rows in patient_state table"

  patient_state_patient_ids = Connection.select_all("
    SELECT p.patient_id FROM patient_program p
    inner join patient_state s ON s.patient_program_id >= p.patient_program_id
    WHERE (date(s.date_created) >= DATE('#{start_date}') OR date(s.date_changed) >= DATE('#{start_date}'))
    AND p.patient_id IN(#{patient_ids_in_earliest_start_date.join(',')})
    group by p.patient_id
  ").collect{|p|p["p.patient_id"].to_i}


=begin
  Getting all changed rows in program_workflow table
=end

  puts "Getting all changed rows in program_workflow table"

  program_workflow_patient_ids = Connection.select_all("
    SELECT p.patient_id FROM patient_program p
    inner join program_workflow w ON p.program_id = w.program_id
    WHERE  (date(w.date_created) >= DATE('#{start_date}') OR date(w.date_changed) >= DATE('#{start_date}'))
    AND p.patient_id IN(#{patient_ids_in_earliest_start_date.join(',')})
    group by p.patient_id
  ").collect{|p|p["p.patient_id"].to_i}


=begin
  Getting all changed rows in program_workflow_state table
=end

  puts "Getting all changed rows in program_workflow_state table"

  program_workflow_state_patient_ids = Connection.select_all("
    SELECT p.patient_id from patient_program p
    inner join program_workflow w ON p.program_id = w.program_id
    inner join program_workflow_state s ON w.program_workflow_id = s.program_workflow_id
    WHERE (date(s.date_created) >= DATE('#{start_date}') OR date(s.date_changed) >= DATE('#{start_date}'))
    AND p.patient_id IN(#{patient_ids_in_earliest_start_date.join(',')})
    group by p.patient_id
  ").collect{|p|p["p.patient_id"].to_i}

=begin
  Getting all changed rows in relationship table
=end

  puts "Getting all changed rows in relationship table"

   relationship_patient_ids = Connection.select_all("
    SELECT person_a FROM relationship
    WHERE (date(date_created) >= DATE('#{start_date}') OR
    DATE(date_voided) >= DATE('#{start_date}'))
    AND person_a IN(#{patient_ids_in_earliest_start_date.join(',')})
    group by person_a;
  ").collect{|p|p["patient_id"].to_i}


  patient_ids = (enc_patient_ids + obs_patient_ids + orders_patient_ids + patient_patient_ids + person_patient_ids + person_name_patient_ids + person_address_patient_ids + person_attribute_patient_ids + patient_identifier_patient_ids + patient_program_patient_ids + patient_state_patient_ids + program_workflow_patient_ids + program_workflow_state_patient_ids + relationship_patient_ids).uniq

  #1. Demographics lookup
  updating_person_table(person_patient_ids, start_date)

  #2. Demographics lookup (names)
  updating_person_name_table(person_name_patient_ids, start_date)

  #3. Demographics lookup (address)
  updating_person_address_table(person_address_patient_ids, start_date)

  #4. Demographics lookup (patient_identifier)
  updating_patient_identifier_table(patient_identifier_patient_ids, start_date)

  #5. Person attributes (person_attributes)
  updating_person_attributes_table(person_attribute_patient_ids, start_date)

  #6. Patient_program lookup (patient_program)
  updating_patient_program_table(patient_program_patient_ids, start_date)

  #7 Demographics lookup (relationship)
  upating_relationship_table(relationship_patient_ids, start_date)

  #9 updating_orders_tables()
  #updating_orders_tables(orders_patient_ids)

  #10 updating_drug_orders_table()
  updating_drug_orders_table(patient_ids, start_date)

  #11 Demographics lookup (obs)
  updating_obs_table(patient_ids, start_date)

  #updating flat_cohort_table:
  updating_flat_cohort_table(patient_ids, start_date)
  end_time = DateTime.now

  patient_ids.delete_if{|n| n==0}

  #update flat_tables_updater_log_details
    Connection.execute <<EOF
      INSERT INTO flat_tables_updater_log_details (updated_date, number_of_records_updated) VALUES ('#{DateTime.now}', #{patient_ids.length});
EOF

  puts "\n...........PROCESSED #{patient_ids.length} patients from #{start_time.strftime('%Y-%m-%d %H:%M:%S')} to #{end_time.strftime('%Y-%m-%d %H:%M:%S')}"
end

def updating_flat_cohort_table(patient_ids, start_date)
  data = get_earliest_start_date_patients_data(patient_ids, start_date)
  (data || []).each do |row|

    #get flat_table1 data
    flat_table1_record = Connection.select_one("SELECT * FROM flat_table1 WHERE patient_id = #{row[:patient_id]}")

    next if flat_table1_record.blank?

    #get flat_cohort_table data
    flat_table_2_data = Connection.select_one("SELECT * FROM flat_table2
                                                WHERE patient_id = #{row[:patient_id]}
                                                ORDER BY visit_date DESC ")

    hiv_program_state                     = flat_table_2_data['current_hiv_program_state']
    hiv_program_start_date                = flat_table_2_data['current_hiv_program_start_date']
    patient_died_month                    = flat_table_2_data['patient_died_month']
    patient_pregnant                      = flat_table_2_data['patient_pregnant']
    patient_breastfeeding                 = flat_table_2_data['patient_breastfeeding']
    drug_induced_abdominal_pain           = flat_table_2_data['drug_induced_abdominal_pain']
    drug_induced_anorexia                 = flat_table_2_data['drug_induced_anorexia']
    drug_induced_diarrhea                 = flat_table_2_data['drug_induced_diarrhea']
    drug_induced_jaundice                 = flat_table_2_data['drug_induced_jaundice']
    drug_induced_leg_pain_numbness        = flat_table_2_data['drug_induced_leg_pain_numbness']
    drug_induced_vomiting                 = flat_table_2_data['drug_induced_vomiting']
    drug_induced_peripheral_neuropathy    = flat_table_2_data['drug_induced_peripheral_neuropathy']
    drug_induced_hepatitis                = flat_table_2_data['drug_induced_hepatitis']
    drug_induced_anemia                   = flat_table_2_data['drug_induced_anemia']
    drug_induced_lactic_acidosis          = flat_table_2_data['drug_induced_lactic_acidosis']
    drug_induced_lipodystrophy            = flat_table_2_data['drug_induced_lipodystrophy']
    drug_induced_skin_rash                = flat_table_2_data['drug_induced_skin_rash']
    drug_induced_other                    = flat_table_2_data['drug_induced_other']
    drug_induced_fever                    = flat_table_2_data['drug_induced_fever']
    drug_induced_cough                    = flat_table_2_data['drug_induced_cough']
    tb_not_suspected                      = flat_table_2_data['tb_status_tb_not_suspected']
    tb_suspected                          = flat_table_2_data['tb_status_tb_suspected']
    confirmed_tb_not_on_treatment         = flat_table_2_data['tb_status_confirmed_tb_not_on_treatment']
    confirmed_tb_on_treatment             = flat_table_2_data['tb_status_confirmed_tb_on_treatment']
    unknown_tb_status                     = flat_table_2_data['tb_status_unknown']
    regimen_category_treatment            = flat_table_2_data['regimen_category_treatment']
    regimen_category_dispensed            = flat_table_2_data['regimen_category_dispensed']
    what_was_the_patient_adherence_for_this_drug1 = flat_table_2_data['what_was_the_patient_adherence_for_this_drug1']
    what_was_the_patient_adherence_for_this_drug2 = flat_table_2_data['what_was_the_patient_adherence_for_this_drug2']
    what_was_the_patient_adherence_for_this_drug3 = flat_table_2_data['what_was_the_patient_adherence_for_this_drug3']
    what_was_the_patient_adherence_for_this_drug4 = flat_table_2_data['what_was_the_patient_adherence_for_this_drug4']
    what_was_the_patient_adherence_for_this_drug5 = flat_table_2_data['what_was_the_patient_adherence_for_this_drug5']
    drug_name1                            = flat_table_2_data['drug_name1']
    drug_name2                            = flat_table_2_data['drug_name2']
    drug_name3                            = flat_table_2_data['drug_name3']
    drug_name4                            = flat_table_2_data['drug_name4']
    drug_name5                            = flat_table_2_data['drug_name5']
    drug_inventory_id1                    = flat_table_2_data['drug_inventory_id1']
    drug_inventory_id2                    = flat_table_2_data['drug_inventory_id2']
    drug_inventory_id3                    = flat_table_2_data['drug_inventory_id3']
    drug_inventory_id4                    = flat_table_2_data['drug_inventory_id4']
    drug_inventory_id5                    = flat_table_2_data['drug_inventory_id5']
    drug_auto_expire_date1                = flat_table_2_data['drug_auto_expire_date1']
    drug_auto_expire_date2                = flat_table_2_data['drug_auto_expire_date2']
    drug_auto_expire_date3                = flat_table_2_data['drug_auto_expire_date3']
    drug_auto_expire_date4                = flat_table_2_data['drug_auto_expire_date4']
    drug_auto_expire_date5                = flat_table_2_data['drug_equivalent_daily_dose5']
    hiv_program_state_v_date              = flat_table_2_data['visit_date']
    hiv_program_start_date_v_date         = flat_table_2_data['visit_date']
    current_tb_status_v_date              = flat_table_2_data['visit_date']
    patient_pregnant_v_date               = flat_table_2_data['visit_date']
    drug_induced_abdominal_pain_v_date    = flat_table_2_data['visit_date']
    drug_induced_anorexia_v_date          = flat_table_2_data['visit_date']
    drug_induced_diarrhea_v_date          = flat_table_2_data['visit_date']
    drug_induced_jaundice_v_date          = flat_table_2_data['visit_date']
    drug_induced_leg_pain_numbness_v_date = flat_table_2_data['visit_date']
    drug_induced_vomiting_v_date          = flat_table_2_data['visit_date']
    drug_induced_peripheral_neuropathy_v_date = flat_table_2_data['visit_date']
    drug_induced_hepatitis_v_date         = flat_table_2_data['visit_date']
    drug_induced_anemia_v_date            = flat_table_2_data['visit_date']
    drug_induced_lactic_acidosis_v_date   = flat_table_2_data['visit_date']
    drug_induced_lipodystrophy_v_date     = flat_table_2_data['visit_date']
    drug_induced_skin_rash_v_date         = flat_table_2_data['visit_date']
    drug_induced_other_v_date             = flat_table_2_data['visit_date']
    drug_induced_fever_v_date             = flat_table_2_data['visit_date']
    drug_induced_cough_v_date             = flat_table_2_data['visit_date']
    tb_not_suspected_v_date               = flat_table_2_data['visit_date']
    tb_suspected_v_date                   = flat_table_2_data['visit_date']
    confirmed_tb_not_on_treatment_v_date  = flat_table_2_data['visit_date']
    confirmed_tb_on_treatment_v_date      = flat_table_2_data['visit_date']
    unknown_tb_status_v_date              = flat_table_2_data['visit_date']
    what_was_the_patient_adherence_for_this_drug1_v_date = flat_table_2_data['visit_date']
    what_was_the_patient_adherence_for_this_drug2_v_date = flat_table_2_data['visit_date']
    what_was_the_patient_adherence_for_this_drug3_v_date = flat_table_2_data['visit_date']
    what_was_the_patient_adherence_for_this_drug4_v_date = flat_table_2_data['visit_date']
    what_was_the_patient_adherence_for_this_drug5_v_date = flat_table_2_data['visit_date']
    drug_name1_v_date                     = flat_table_2_data['visit_date']
    drug_name2_v_date                     = flat_table_2_data['visit_date']
    drug_name3_v_date                     = flat_table_2_data['visit_date']
    drug_name4_v_date                     = flat_table_2_data['visit_date']
    drug_name5_v_date                     = flat_table_2_data['visit_date']
    drug_inventory_id1_v_date             = flat_table_2_data['visit_date']
    drug_inventory_id2_v_date             = flat_table_2_data['visit_date']
    drug_inventory_id3_v_date             = flat_table_2_data['visit_date']
    drug_inventory_id4_v_date             = flat_table_2_data['visit_date']
    drug_inventory_id5_v_date             = flat_table_2_data['visit_date']
    drug_auto_expire_date1_v_date         = flat_table_2_data['visit_date']
    drug_auto_expire_date2_v_date         = flat_table_2_data['visit_date']
    drug_auto_expire_date3_v_date         = flat_table_2_data['visit_date']
    drug_auto_expire_date4_v_date         = flat_table_2_data['visit_date']
    drug_auto_expire_date5_v_date         = flat_table_2_data['visit_date']
    side_effects_abdominal_pain           = flat_table_2_data['side_effects_peripheral_neuropathy']
    side_effects_anemia                   = flat_table_2_data['side_effects_anemia']
    side_effects_anorexia                 = flat_table_2_data['side_effects_anorexia']
    side_effects_blurry_vision            = flat_table_2_data['side_effects_blurry_vision']
    side_effects_cough                    = flat_table_2_data['side_effects_cough']
    side_effects_diarrhea                 = flat_table_2_data['side_effects_diarrhea']
    side_effects_diziness                 = flat_table_2_data['side_effects_diziness']
    side_effects_fever                    = flat_table_2_data['side_effects_fever']
    side_effects_hepatitis                = flat_table_2_data['side_effects_hepatitis']
    side_effects_jaundice                 = flat_table_2_data['side_effects_jaundice']
    side_effects_kidney_failure           = flat_table_2_data['side_effects_kidney_failure']
    side_effects_lactic_acidosis          = flat_table_2_data['side_effects_lactic_acidosis']
    side_effects_leg_pain_numbness        = flat_table_2_data['side_effects_leg_pain_numbness']
    side_effects_lipodystrophy            = flat_table_2_data['side_effects_lipodystrophy']
    side_effects_no                       = flat_table_2_data['side_effects_no']
    side_effects_other                    = flat_table_2_data['side_effects_Other']
    side_effects_peripheral_neuropathy    = flat_table_2_data['side_effects_peripheral_neuropathy']
    side_effects_psychosis                = flat_table_2_data['side_effects_psychosis']
    side_effects_renal_failure            = flat_table_2_data['side_effects_renal_failure']
    side_effects_skin_rash                = flat_table_2_data['side_effects_skin_rash']
    side_effects_vomiting                 = flat_table_2_data['side_effects_vomiting']
    side_effects_gynaecomastia            = flat_table_2_data['side_effects_gynaecomastia']
    side_effects_nightmares               = flat_table_2_data['side_effects_nightmares']
    drug_induced_kidney_failure           = flat_table_2_data['drug_induced_kidney_failure']
    drug_induced_nightmares               = flat_table_2_data['drug_induced_nightmares']
    drug_induced_diziness                 = flat_table_2_data['drug_induced_diziness']
    drug_induced_psychosis                = flat_table_2_data['drug_induced_psychosis']
    drug_induced_blurry_vision            = flat_table_2_data['drug_induced_blurry_vision']


    eligible    = flat_table1_record['earliest_start_date'] rescue nil


    gender                                      = flat_table1_record['gender']
    dob                                         = flat_table1_record['dob']
    age_in_days                                 = flat_table1_record['age_in_days']
    death_date                                  = flat_table1_record['death_date']
    pregnant_at_initiation                      = flat_table1_record['pregnant_at_initiation']
    reason_for_eligibility                      = flat_table1_record['reason_for_eligibility']
    who_stage                                   = flat_table1_record['who_stage']
    who_stages_criteria_present                 = flat_table1_record['who_stages_criteria_present']
    ever_registered_at_art_clinic               = flat_table1_record['ever_registered_at_art_clinic']
    current_location                            = flat_table1_record['current_location']
    date_art_last_taken                         = flat_table1_record['date_art_last_taken']
    pulmonary_tuberculosis_last_2_years         = flat_table1_record['pulmonary_tuberculosis_last_2_years']
    kaposis_sarcoma                             = flat_table1_record['kaposis_sarcoma']
    extrapulmonary_tuberculosis                 = flat_table1_record['extrapulmonary_tuberculosis']
    extrapulmonary_tuberculosis_v_date          = flat_table1_record['extrapulmonary_tuberculosis_v_date']#.to_date rescue nil
    pulmonary_tuberculosis                      = flat_table1_record['pulmonary_tuberculosis']
    pulmonary_tuberculosis_v_date               = flat_table1_record['pulmonary_tuberculosis_v_date']#.to_date
    pulmonary_tuberculosis_last_2_years_v_date  = flat_table1_record['pulmonary_tuberculosis_last_2_years_v_date']#.to_date rescue nil
    kaposis_sarcoma_v_date                      = flat_table1_record['kaposis_sarcoma_v_date']#.to_date rescue nil
    reason_for_eligibility_v_date               = flat_table1_record['reason_for_eligibility_v_date']#.to_date rescue nil
    pregnant_at_initiation_v_date               = flat_table1_record['pregnant_at_initiation_v_date']
    who_stages_criteria_present_v_date          = flat_table1_record['who_stages_criteria_present_v_date']#.to_date rescue nil
    ever_registered_at_art_clinic_v_date        = flat_table1_record['ever_registered_at_art_clinic_v_date']
    date_art_last_taken_v_date                  = flat_table1_record['date_art_last_taken_v_date']
    taken_art_in_last_two_months_v_date         = flat_table1_record['taken_art_in_last_two_months_v_date']
    taken_art_in_last_two_months                = flat_table1_record['taken_art_in_last_two_months']
    date_enrolled                               = flat_table1_record['date_enrolled']
    patient_breastfeeding_v_date                = flat_table1_record['patient_breastfeeding_v_date']

    unless date_enrolled.blank?
      re_initiated = Connection.select_one("SELECT re_initiated_check(#{row[:patient_id]}, '#{date_enrolled}') AS re_initiated")
    end
      patient_re_initiated = re_initiated['re_initiated']  rescue nil
    unless eligible.blank?
      record = Connection.select_one("SELECT id FROM flat_cohort_table WHERE patient_id = #{row[:patient_id]}") rescue nil
      age_at_initiation = flat_table1_record['age_at_initiation']  rescue nil
      record_exists = record['id'] rescue nil

      if record_exists.blank?
        puts "............ Inserting new record into flat_cohort_table (patient_id: #{row[:patient_id]})"
        Connection.execute <<EOF
INSERT INTO flat_cohort_table
 (patient_id, gender, birthdate, earliest_start_date, date_enrolled, age_at_initiation, age_in_days, death_date, patient_died_month, pregnant_at_initiation, patient_re_initiated, reason_for_starting, ever_registered_at_art_clinic, date_art_last_taken, taken_art_in_last_two_months, extrapulmonary_tuberculosis, pulmonary_tuberculosis, pulmonary_tuberculosis_last_2_years, kaposis_sarcoma,extrapulmonary_tuberculosis_v_date, pulmonary_tuberculosis_v_date, pulmonary_tuberculosis_last_2_years_v_date, kaposis_sarcoma_v_date, reason_for_starting_v_date, pregnant_at_initiation_v_date, ever_registered_at_art_clinic_v_date, date_art_last_taken_v_date, taken_art_in_last_two_months_v_date, hiv_program_state, hiv_program_start_date, patient_pregnant, drug_induced_abdominal_pain, drug_induced_anorexia, drug_induced_diarrhea, drug_induced_jaundice, drug_induced_leg_pain_numbness, drug_induced_vomiting, drug_induced_peripheral_neuropathy, drug_induced_hepatitis, drug_induced_anemia, drug_induced_lactic_acidosis, drug_induced_lipodystrophy, drug_induced_skin_rash, drug_induced_other, drug_induced_fever, drug_induced_cough, tb_not_suspected, tb_suspected, confirmed_tb_not_on_treatment, confirmed_tb_on_treatment, unknown_tb_status, regimen_category_treatment, regimen_category_dispensed, what_was_the_patient_adherence_for_this_drug1, what_was_the_patient_adherence_for_this_drug2,  what_was_the_patient_adherence_for_this_drug3, what_was_the_patient_adherence_for_this_drug4, what_was_the_patient_adherence_for_this_drug5, drug_name1, drug_name2, drug_name3, drug_name4, drug_name5, drug_inventory_id1, drug_inventory_id2, drug_inventory_id3, drug_inventory_id4, drug_inventory_id5, drug_auto_expire_date1, drug_auto_expire_date2, drug_auto_expire_date3, drug_auto_expire_date4, drug_auto_expire_date5, hiv_program_state_v_date, hiv_program_start_date_v_date, current_tb_status_v_date, patient_pregnant_v_date, drug_induced_abdominal_pain_v_date, drug_induced_anorexia_v_date, drug_induced_diarrhea_v_date, drug_induced_jaundice_v_date, drug_induced_leg_pain_numbness_v_date, drug_induced_vomiting_v_date, drug_induced_peripheral_neuropathy_v_date, drug_induced_hepatitis_v_date, drug_induced_anemia_v_date, drug_induced_lactic_acidosis_v_date, drug_induced_lipodystrophy_v_date, drug_induced_skin_rash_v_date, drug_induced_other_v_date, drug_induced_fever_v_date, drug_induced_cough_v_date, tb_not_suspected_v_date, tb_suspected_v_date, confirmed_tb_not_on_treatment_v_date, confirmed_tb_on_treatment_v_date, unknown_tb_status_v_date, what_was_the_patient_adherence_for_this_drug1_v_date, what_was_the_patient_adherence_for_this_drug2_v_date, what_was_the_patient_adherence_for_this_drug3_v_date, what_was_the_patient_adherence_for_this_drug4_v_date, what_was_the_patient_adherence_for_this_drug5_v_date, drug_name1_v_date, drug_name2_v_date, drug_name3_v_date, drug_name4_v_date, drug_name5_v_date, drug_inventory_id1_v_date, drug_inventory_id2_v_date, drug_inventory_id3_v_date, drug_inventory_id4_v_date, drug_inventory_id5_v_date, drug_auto_expire_date1_v_date, drug_auto_expire_date2_v_date, drug_auto_expire_date3_v_date, drug_auto_expire_date4_v_date, drug_auto_expire_date5_v_date, side_effects_abdominal_pain, side_effects_anemia, side_effects_anorexia, side_effects_blurry_vision, side_effects_cough, side_effects_diarrhea, side_effects_diziness, side_effects_fever, side_effects_hepatitis, side_effects_jaundice, side_effects_kidney_failure, side_effects_lactic_acidosis, side_effects_leg_pain_numbness, side_effects_lipodystrophy, side_effects_no, side_effects_other, side_effects_peripheral_neuropathy, side_effects_psychosis, side_effects_renal_failure, side_effects_skin_rash, side_effects_vomiting, side_effects_gynaecomastia, side_effects_nightmares, drug_induced_kidney_failure, drug_induced_nightmares, drug_induced_diziness, drug_induced_psychosis, drug_induced_blurry_vision)
  VALUES (#{row[:patient_id]}, '#{gender}', '#{dob}', '#{eligible}', '#{date_enrolled}', #{age_at_initiation}, #{age_in_days}, '#{death_date}', '#{patient_died_month}','#{pregnant_at_initiation}', '#{patient_re_initiated}','#{reason_for_eligibility}', '#{ever_registered_at_art_clinic}', '#{date_art_last_taken}', '#{taken_art_in_last_two_months}', '#{extrapulmonary_tuberculosis}', '#{pulmonary_tuberculosis}', '#{pulmonary_tuberculosis_last_2_years}', '#{kaposis_sarcoma}', '#{extrapulmonary_tuberculosis_v_date}', '#{pulmonary_tuberculosis_v_date}', '#{pulmonary_tuberculosis_last_2_years_v_date}', '#{kaposis_sarcoma_v_date}', '#{reason_for_eligibility_v_date}', '#{pregnant_at_initiation_v_date}', '#{ever_registered_at_art_clinic_v_date}', '#{date_art_last_taken_v_date}', '#{taken_art_in_last_two_months_v_date}',"#{hiv_program_state}", "#{hiv_program_start_date}", "#{patient_pregnant}", "#{drug_induced_abdominal_pain}", "#{drug_induced_anorexia}", "#{drug_induced_diarrhea}", "#{drug_induced_jaundice}", "#{drug_induced_leg_pain_numbness}", "#{drug_induced_vomiting}", "#{drug_induced_peripheral_neuropathy}", "#{drug_induced_hepatitis}", "#{drug_induced_anemia}", "#{drug_induced_lactic_acidosis}", "#{drug_induced_lipodystrophy}", "#{drug_induced_skin_rash}", "#{drug_induced_other}", "#{drug_induced_fever}", "#{drug_induced_cough}", "#{tb_not_suspected}", "#{tb_suspected}", "#{confirmed_tb_not_on_treatment}", "#{confirmed_tb_on_treatment}", "#{unknown_tb_status}", "#{regimen_category_treatment}", "#{regimen_category_dispensed}", "#{what_was_the_patient_adherence_for_this_drug1}", "#{what_was_the_patient_adherence_for_this_drug2}",  "#{what_was_the_patient_adherence_for_this_drug3}", "#{what_was_the_patient_adherence_for_this_drug4}", "#{what_was_the_patient_adherence_for_this_drug5}", "#{drug_name1}", "#{drug_name2}", "#{drug_name3}", "#{drug_name4}", "#{drug_name5}", "#{drug_inventory_id1}", "#{drug_inventory_id2}", "#{drug_inventory_id3}", "#{drug_inventory_id4}", "#{drug_inventory_id5}", '#{drug_auto_expire_date1}', '#{drug_auto_expire_date2}', '#{drug_auto_expire_date3}', '#{drug_auto_expire_date4}', '#{drug_auto_expire_date5}', '#{hiv_program_state_v_date}', '#{hiv_program_start_date_v_date}', '#{current_tb_status_v_date}', "#{patient_pregnant_v_date}", "#{drug_induced_abdominal_pain_v_date}", "#{drug_induced_anorexia_v_date}", "#{drug_induced_diarrhea_v_date}", "#{drug_induced_jaundice_v_date}", "#{drug_induced_leg_pain_numbness_v_date}", "#{drug_induced_vomiting_v_date}", "#{drug_induced_peripheral_neuropathy_v_date}", "#{drug_induced_hepatitis_v_date}", "#{drug_induced_anemia_v_date}", "#{drug_induced_lactic_acidosis_v_date}", "#{drug_induced_lipodystrophy_v_date}", "#{drug_induced_skin_rash_v_date}", "#{drug_induced_other_v_date}", "#{drug_induced_fever_v_date}", "#{drug_induced_cough_v_date}", "#{tb_not_suspected_v_date}", "#{tb_suspected_v_date}", "#{confirmed_tb_not_on_treatment_v_date}", "#{confirmed_tb_on_treatment_v_date}", "#{unknown_tb_status_v_date}", "#{what_was_the_patient_adherence_for_this_drug1_v_date}", "#{what_was_the_patient_adherence_for_this_drug2_v_date}", "#{what_was_the_patient_adherence_for_this_drug3_v_date}", "#{what_was_the_patient_adherence_for_this_drug4_v_date}", "#{what_was_the_patient_adherence_for_this_drug5_v_date}", "#{drug_name1_v_date}", "#{drug_name2_v_date}", "#{drug_name3_v_date}", "#{drug_name4_v_date}", "#{drug_name5_v_date}", "#{drug_inventory_id1_v_date}", "#{drug_inventory_id2_v_date}", "#{drug_inventory_id3_v_date}", "#{drug_inventory_id4_v_date}", "#{drug_inventory_id5_v_date}", "#{drug_auto_expire_date1_v_date}", "#{drug_auto_expire_date2_v_date}", "#{drug_auto_expire_date3_v_date}", "#{drug_auto_expire_date4_v_date}", "#{drug_auto_expire_date5_v_date}","#{side_effects_abdominal_pain}",  "#{side_effects_anemia}",  "#{side_effects_anorexia}",  "#{side_effects_blurry_vision}",  "#{side_effects_cough}",  "#{side_effects_diarrhea}",  "#{side_effects_diziness}",  "#{side_effects_fever}",  "#{side_effects_hepatitis}",  "#{side_effects_jaundice}",  "#{side_effects_kidney_failure}",  "#{side_effects_lactic_acidosis}",  "#{side_effects_leg_pain_numbness}",  "#{side_effects_lipodystrophy}",  "#{side_effects_no}",  "#{side_effects_other}",  "#{side_effects_peripheral_neuropathy}",  "#{side_effects_psychosis}",  "#{side_effects_renal_failure}",  "#{side_effects_skin_rash}",  "#{side_effects_vomiting}",  "#{side_effects_gynaecomastia}",  "#{side_effects_nightmares}", "#{drug_induced_kidney_failure}", "#{drug_induced_nightmares}", "#{drug_induced_diziness}", "#{drug_induced_psychosis}", "#{drug_induced_blurry_vision}");
EOF

      else
        Connection.execute <<EOF
UPDATE flat_cohort_table
 SET earliest_start_date = '#{eligible}', date_enrolled = '#{date_enrolled}', gender = '#{gender}', birthdate = '#{dob}',
  age_at_initiation = #{age_at_initiation}, age_in_days = #{age_in_days},
  hiv_program_state = "#{hiv_program_state}",
  hiv_program_start_date = '#{hiv_program_start_date}',
  patient_died_month = "#{patient_died_month}",
  patient_re_initiated = "#{patient_re_initiated}",
  pregnant_at_initiation = "#{pregnant_at_initiation}",
  reason_for_starting = "#{reason_for_eligibility}",
  ever_registered_at_art_clinic = "#{ever_registered_at_art_clinic}",
  patient_pregnant = "#{patient_pregnant}",
  patient_breastfeeding = "#{patient_breastfeeding}",
  drug_induced_abdominal_pain = "#{drug_induced_abdominal_pain}",
  drug_induced_anorexia = "#{drug_induced_anorexia}",
  drug_induced_diarrhea = "#{drug_induced_diarrhea}",
  drug_induced_jaundice = "#{drug_induced_jaundice}",
  drug_induced_leg_pain_numbness = "#{drug_induced_leg_pain_numbness}",
  drug_induced_vomiting = "#{drug_induced_vomiting}",
  drug_induced_peripheral_neuropathy = "#{drug_induced_peripheral_neuropathy}",
  drug_induced_hepatitis = "#{drug_induced_hepatitis}",
  drug_induced_anemia = "#{drug_induced_anemia}",
  drug_induced_lactic_acidosis = "#{drug_induced_lactic_acidosis}",
  drug_induced_lipodystrophy = "#{drug_induced_lipodystrophy}",
  drug_induced_skin_rash = "#{drug_induced_skin_rash}",
  drug_induced_other = "#{drug_induced_other}",
  drug_induced_fever = "#{drug_induced_fever}",
  drug_induced_cough = "#{drug_induced_cough}",
  drug_induced_kidney_failure = "#{drug_induced_kidney_failure}",
  drug_induced_nightmares = "#{drug_induced_nightmares}",
  drug_induced_diziness = "#{drug_induced_diziness}",
  drug_induced_psychosis = "#{drug_induced_psychosis}",
  drug_induced_blurry_vision = "#{drug_induced_blurry_vision}",

  side_effects_abdominal_pain = "#{side_effects_abdominal_pain}",
  side_effects_anemia = "#{side_effects_anemia}",
  side_effects_anorexia = "#{side_effects_anorexia}",
  side_effects_blurry_vision = "#{side_effects_blurry_vision}",
  side_effects_cough = "#{side_effects_cough}",
  side_effects_diarrhea = "#{side_effects_diarrhea}",
  side_effects_diziness = "#{side_effects_diziness}",
  side_effects_fever = "#{side_effects_fever}",
  side_effects_hepatitis = "#{side_effects_hepatitis}",
  side_effects_jaundice = "#{side_effects_jaundice}",
  side_effects_kidney_failure = "#{side_effects_kidney_failure}",
  side_effects_lactic_acidosis = "#{side_effects_lactic_acidosis}",
  side_effects_leg_pain_numbness = "#{side_effects_leg_pain_numbness}",
  side_effects_lipodystrophy = "#{side_effects_lipodystrophy}",
  side_effects_no = "#{side_effects_no}",
  side_effects_other = "#{side_effects_other}",
  side_effects_peripheral_neuropathy = "#{side_effects_peripheral_neuropathy}",
  side_effects_psychosis = "#{side_effects_psychosis}",
  side_effects_renal_failure = "#{side_effects_renal_failure}",
  side_effects_skin_rash = "#{side_effects_skin_rash}",
  side_effects_vomiting = "#{side_effects_vomiting}",
  side_effects_gynaecomastia = "#{side_effects_gynaecomastia}",
  side_effects_nightmares = "#{side_effects_nightmares}",

  tb_not_suspected_v_date = "#{tb_not_suspected_v_date}",
  tb_not_suspected = "#{tb_not_suspected}",
  confirmed_tb_not_on_treatment = "#{confirmed_tb_not_on_treatment}",
  confirmed_tb_on_treatment = "#{confirmed_tb_on_treatment}",
  unknown_tb_status = "#{unknown_tb_status}",
  extrapulmonary_tuberculosis = "#{extrapulmonary_tuberculosis}",
  pulmonary_tuberculosis = "#{pulmonary_tuberculosis}",
  pulmonary_tuberculosis_last_2_years = "#{pulmonary_tuberculosis_last_2_years}",
  kaposis_sarcoma = "#{kaposis_sarcoma}",
  what_was_the_patient_adherence_for_this_drug1 = "#{what_was_the_patient_adherence_for_this_drug1}",
  what_was_the_patient_adherence_for_this_drug2 = "#{what_was_the_patient_adherence_for_this_drug2}",
  what_was_the_patient_adherence_for_this_drug3 = "#{what_was_the_patient_adherence_for_this_drug3}",
  what_was_the_patient_adherence_for_this_drug4 = "#{what_was_the_patient_adherence_for_this_drug4}",
  what_was_the_patient_adherence_for_this_drug5 = "#{what_was_the_patient_adherence_for_this_drug5}",
  regimen_category_treatment = "#{regimen_category_treatment}",
  regimen_category_dispensed = "#{regimen_category_dispensed}",
  drug_name1 = "#{drug_name1}",
  drug_name2 = "#{drug_name2}",
  drug_name3 = "#{drug_name3}",
  drug_name4 = "#{drug_name4}",
  drug_name5 = "#{drug_name5}",
  drug_inventory_id1 = "#{drug_inventory_id1}",
  drug_inventory_id2 = "#{drug_inventory_id2}",
  drug_inventory_id3 = "#{drug_inventory_id3}",
  drug_inventory_id4 = "#{drug_inventory_id4}",
  drug_inventory_id5 = "#{drug_inventory_id5}",
  drug_auto_expire_date1 = '#{drug_auto_expire_date1}',
  drug_auto_expire_date2 = '#{drug_auto_expire_date2}',
  drug_auto_expire_date3 = '#{drug_auto_expire_date3}',
  drug_auto_expire_date4 = '#{drug_auto_expire_date4}',
  drug_auto_expire_date5 = '#{drug_auto_expire_date5}',
  current_location = "#{current_location}",
  hiv_program_state_v_date = '#{hiv_program_state_v_date}',
  hiv_program_start_date_v_date = '#{hiv_program_start_date_v_date}',
  current_tb_status_v_date = '#{current_tb_status_v_date}',
  reason_for_starting_v_date = '#{reason_for_eligibility_v_date}',
  pregnant_at_initiation_v_date = '#{pregnant_at_initiation_v_date}',
  drug_induced_abdominal_pain_v_date = '#{drug_induced_abdominal_pain_v_date}',
  drug_induced_anorexia_v_date = '#{drug_induced_anorexia_v_date}',
  drug_induced_diarrhea_v_date = '#{drug_induced_diarrhea_v_date}',
  drug_induced_jaundice_v_date = '#{drug_induced_jaundice_v_date}',
  drug_induced_leg_pain_numbness_v_date = '#{drug_induced_leg_pain_numbness_v_date}',
  drug_induced_vomiting_v_date = '#{drug_induced_vomiting_v_date}',
  drug_induced_peripheral_neuropathy_v_date = '#{drug_induced_peripheral_neuropathy_v_date}',
  drug_induced_hepatitis_v_date = '#{drug_induced_hepatitis_v_date}',
  drug_induced_anemia_v_date = '#{drug_induced_anemia_v_date}',
  drug_induced_lactic_acidosis_v_date = '#{drug_induced_lactic_acidosis_v_date}',
  drug_induced_lipodystrophy_v_date = '#{drug_induced_lipodystrophy_v_date}',
  drug_induced_skin_rash_v_date = '#{drug_induced_skin_rash_v_date}',
  drug_induced_other_v_date = '#{drug_induced_other_v_date}',
  drug_induced_fever_v_date = '#{drug_induced_fever_v_date}',
  drug_induced_cough_v_date = '#{drug_induced_cough_v_date}',
  tb_not_suspected_v_date = '#{tb_not_suspected_v_date}',
  tb_suspected_v_date = '#{tb_suspected_v_date}',
  confirmed_tb_not_on_treatment_v_date = '#{confirmed_tb_not_on_treatment_v_date}',
  confirmed_tb_on_treatment_v_date = '#{confirmed_tb_on_treatment_v_date}',
  unknown_tb_status_v_date = '#{unknown_tb_status_v_date}',
  what_was_the_patient_adherence_for_this_drug1_v_date = '#{what_was_the_patient_adherence_for_this_drug1_v_date}',
  what_was_the_patient_adherence_for_this_drug2_v_date = '#{what_was_the_patient_adherence_for_this_drug2_v_date}',
  what_was_the_patient_adherence_for_this_drug3_v_date = '#{what_was_the_patient_adherence_for_this_drug3_v_date}',
  what_was_the_patient_adherence_for_this_drug4_v_date = '#{what_was_the_patient_adherence_for_this_drug4_v_date}',
  what_was_the_patient_adherence_for_this_drug5_v_date = '#{what_was_the_patient_adherence_for_this_drug5_v_date}',
  drug_name1_v_date = '#{drug_name1_v_date}',
  drug_name2_v_date = '#{drug_name2_v_date}',
  drug_name3_v_date = '#{drug_name3_v_date}',
  drug_name4_v_date = '#{drug_name4_v_date}',
  drug_name5_v_date = '#{drug_name5_v_date}',
  drug_inventory_id1_v_date = '#{drug_inventory_id1_v_date.to_date}',
  drug_inventory_id2_v_date = '#{drug_inventory_id2_v_date}',
  drug_inventory_id3_v_date = '#{drug_inventory_id3_v_date}',
  drug_inventory_id4_v_date = '#{drug_inventory_id4_v_date}',
  drug_inventory_id5_v_date = '#{drug_inventory_id5_v_date}',
  drug_auto_expire_date1_v_date = '#{drug_auto_expire_date1_v_date}',
  drug_auto_expire_date2_v_date = '#{drug_auto_expire_date2_v_date}',
  drug_auto_expire_date3_v_date = '#{drug_auto_expire_date3_v_date}',
  drug_auto_expire_date4_v_date = '#{drug_auto_expire_date4_v_date}',
  drug_auto_expire_date1_v_date = '#{drug_auto_expire_date5_v_date}',
  patient_pregnant_v_date = '#{patient_pregnant_v_date}',
  patient_breastfeeding_v_date = '#{patient_breastfeeding_v_date}'

 WHERE patient_id = #{row[:patient_id]};
EOF
  puts "........... Updating flat_cohort_table (patient_id: #{row[:patient_id]})"

  flat_cohort_record = Connection.select_one(" SELECT * FROM flat_cohort_table WHERE patient_id = #{row[:patient_id]} ")
  old_extrapulmonary_tuberculosis_v_date  = flat_cohort_record['extrapulmonary_tuberculosis_v_date'].to_date rescue nil
  old_pulmonary_tuberculosis_v_date       = flat_cohort_record['pulmonary_tuberculosis_v_date'].to_date rescue nil
  old_pulmonary_tuberculosis_last_2_years_v_date  = flat_cohort_record['pulmonary_tuberculosis_last_2_years_v_date'].to_date rescue nil
  old_kaposis_sarcoma_v_date                      = flat_cohort_record['kaposis_sarcoma_v_date'].to_date rescue nil
  old_reason_for_eligibility_v_date                  = flat_cohort_record['reason_for_eligibility_v_date'].to_date rescue nil
  old_pregnant_at_initiation_v_date               = flat_cohort_record['pregnant_at_initiation_v_date'].to_date rescue nil
  old_who_stages_criteria_present_v_date          = flat_cohort_record['who_stages_criteria_present_v_date'].to_date rescue nil
  old_ever_registered_at_art_clinic_v_date               = flat_cohort_record['ever_registered_at_art_clinic_v_date'].to_date rescue nil
  old_date_art_last_taken_v_date                  = flat_cohort_record['date_art_last_taken_v_date'].to_date rescue nil
  old_taken_art_in_last_two_months_v_date         = flat_cohort_record['taken_art_in_last_two_months_v_date'].to_date rescue nil

        #puts "....... old_extrapulmonary_tuberculosis_v_date   #{old_extrapulmonary_tuberculosis_v_date}"

        unless extrapulmonary_tuberculosis_v_date.blank?
          #if extrapulmonary_tuberculosis_v_date.to_date > old_extrapulmonary_tuberculosis_v_date.to_date
          Connection.execute <<EOF
UPDATE flat_cohort_table
  SET extrapulmonary_tuberculosis = "#{extrapulmonary_tuberculosis}",
    extrapulmonary_tuberculosis_v_date = '#{extrapulmonary_tuberculosis_v_date}'
  WHERE patient_id = #{row[:patient_id]};
EOF
          #end
        end

        unless pulmonary_tuberculosis_v_date.blank?
          #if pulmonary_tuberculosis_v_date.to_date > old_pulmonary_tuberculosis_v_date.to_date
          Connection.execute <<EOF
UPDATE flat_cohort_table
  SET pulmonary_tuberculosis = "#{pulmonary_tuberculosis}",
    pulmonary_tuberculosis_v_date = '#{pulmonary_tuberculosis_v_date}'
  WHERE patient_id = #{row[:patient_id]};
EOF
          #end
        end

        unless pulmonary_tuberculosis_last_2_years_v_date.blank?
          #if pulmonary_tuberculosis_last_2_years_v_date.to_date > old_pulmonary_tuberculosis_last_2_years_v_date.to_date
          Connection.execute <<EOF
UPDATE flat_cohort_table
  SET pulmonary_tuberculosis_last_2_years = "#{pulmonary_tuberculosis_last_2_years}",
    pulmonary_tuberculosis_last_2_years_v_date = '#{pulmonary_tuberculosis_last_2_years_v_date}'
  WHERE patient_id = #{row[:patient_id]};
EOF
          #end
        end

        unless kaposis_sarcoma_v_date.blank?
          #if kaposis_sarcoma_v_date.to_date > old_kaposis_sarcoma_v_date.to_date
          Connection.execute <<EOF
UPDATE flat_cohort_table
  SET kaposis_sarcoma = "#{kaposis_sarcoma}",
    kaposis_sarcoma_v_date = '#{kaposis_sarcoma_v_date}'
  WHERE patient_id = #{row[:patient_id]};
EOF
          #end
        end

        unless reason_for_eligibility_v_date.blank?
          #if reason_for_eligibility_v_date.to_date > old_reason_for_eligibility_v_date.to_date
          Connection.execute <<EOF
UPDATE flat_cohort_table
  SET reason_for_starting = "#{reason_for_eligibility}",
    reason_for_starting_v_date = '#{reason_for_eligibility_v_date}'
  WHERE patient_id = #{row[:patient_id]};
EOF
          #end
        end

        unless pregnant_at_initiation_v_date.blank?
          #if pregnant_at_initiation_v_date.to_date > old_pregnant_at_initiation_v_date.to_date
          Connection.execute <<EOF
UPDATE flat_cohort_table
  SET pregnant_at_initiation = "#{pregnant_at_initiation}",
    pregnant_at_initiation_v_date = '#{pregnant_at_initiation_v_date}'
  WHERE patient_id = #{row[:patient_id]};
EOF
          #end
        end

        unless who_stages_criteria_present_v_date.blank?
          #if who_stages_criteria_present_v_date.to_date > old_who_stages_criteria_present_v_date.to_date
          Connection.execute <<EOF
UPDATE flat_cohort_table
  SET who_stages_criteria_present = "#{who_stages_criteria_present}",
    who_stages_criteria_present_v_date = '#{who_stages_criteria_present_v_date}'
  WHERE patient_id = #{row[:patient_id]};
EOF
          #end
        end

        unless ever_registered_at_art_clinic_v_date.blank?
          #if ever_registered_at_art_clinic_v_date.to_date > old_ever_registered_at_art_clinic_v_date.to_date
          Connection.execute <<EOF
UPDATE flat_cohort_table
  SET ever_registered_at_art_clinic = "#{ever_registered_at_art_clinic}",
    ever_registered_at_art_clinic_v_date = '#{ever_registered_at_art_clinic_v_date}'
  WHERE patient_id = #{row[:patient_id]};
EOF
          #end
        end

        unless date_art_last_taken_v_date.blank?
          #if date_art_last_taken_v_date.to_date > old_date_art_last_taken_v_date.to_date
          Connection.execute <<EOF
UPDATE flat_cohort_table
  SET date_art_last_taken = '#{date_art_last_taken_v_date}',
    date_art_last_taken_v_date = '#{date_art_last_taken_v_date}'
  WHERE patient_id = #{row[:patient_id]};
EOF
          #end
        end

        unless taken_art_in_last_two_months_v_date.blank?
          #if taken_art_in_last_two_months_v_date.to_date > old_taken_art_in_last_two_months_v_date.to_date
          Connection.execute <<EOF
UPDATE flat_cohort_table
  SET taken_art_in_last_two_months = "#{taken_art_in_last_two_months}",
    taken_art_in_last_two_months_v_date = '#{taken_art_in_last_two_months_v_date}'
  WHERE patient_id = #{row[:patient_id]};
EOF
          #end
        end

      end #record_exists.blank

    end #unless eligible

  end #loop
end

def updating_obs_table(patient_ids, start_date)
  (patient_ids || []).each do |patient_id|
    art_encounter_types = ["VITALS", "APPOINTMENT", "HIV CLINIC REGISTRATION", "TREATMENT", "HIV RECEPTION", "HIV STAGING", "HIV CLINIC CONSULTATION", "DISPENSING", "ART ADHERENCE", "EXIT FROM HIV CARE"]
    art_encounter_type_ids = EncounterType.find(:all, :conditions => ["name IN (?)", art_encounter_types]).map(&:encounter_type_id)

    encounter_records = Connection.select_all("SELECT * FROM encounter WHERE patient_id = #{patient_id}
      AND ((DATE(encounter_datetime) >= DATE('#{start_date}'))
      OR (DATE(date_created) >= DATE('#{start_date}'))
      OR (DATE(date_voided) >= DATE('#{start_date}'))
      OR (DATE(date_changed) >= DATE('#{start_date}')))
      AND encounter_type IN (#{art_encounter_type_ids.join(',')})")

      
    (encounter_records || []).each do |encounter|
      flat_table2_record = Connection.select_one("SELECT * FROM flat_table2 WHERE patient_id = '#{patient_id}'
        AND (DATE(visit_date) = DATE('#{encounter['encounter_datetime']}'))")

      visit = flat_table2_record

      #go to process patient program
      process_patient_state(patient_id, "#{encounter['encounter_datetime'].to_date.strftime'%Y-%m-%d'}", visit)

      if encounter['encounter_type'].to_i  == EncounterType.find_by_name("HIV RECEPTION").encounter_type_id #HIV Reception
        #go to process HIV reception obs
        process_hiv_reception_obs(encounter, visit)

      elsif encounter['encounter_type'].to_i  == EncounterType.find_by_name("VITALS").encounter_type_id #Vitals
        #go to process Vitals obs
        process_vitals_obs(encounter, visit)

      elsif encounter['encounter_type'].to_i  == EncounterType.find_by_name("HIV CLINIC REGISTRATION").encounter_type_id #HIV Clinin Registration
        #go to process HIV Clinic Registration obs
        process_hiv_clinic_registration_obs(encounter, visit)

      elsif encounter['encounter_type'].to_i  == EncounterType.find_by_name("HIV STAGING").encounter_type_id #HIV Staging
        #go to process HIV Stating obs
        process_hiv_staging_obs(encounter, visit)

      elsif encounter['encounter_type'].to_i  == EncounterType.find_by_name("HIV CLINIC CONSULTATION").encounter_type_id #HIV Clinic Consultation
        #go to process HIV Clinic Consultation obs
        process_hiv_clinic_consultation_obs(encounter, visit)

      elsif encounter['encounter_type'].to_i  == EncounterType.find_by_name("TREATMENT").encounter_type_id #Treatment
        #go to process Treatment obs
        process_treatment_obs(encounter, visit)

      elsif encounter['encounter_type'].to_i  == EncounterType.find_by_name("DISPENSING").encounter_type_id #Dispensing
        #go to process Dispensing obs
        process_dispensing_obs(encounter, visit)

      elsif encounter['encounter_type'].to_i  == EncounterType.find_by_name("APPOINTMENT").encounter_type_id #Appointment
        #go to process Appointment obs
        process_appointment_obs(encounter, visit)

      elsif encounter['encounter_type'].to_i  == EncounterType.find_by_name("ART ADHERENCE").encounter_type_id #ART Adherence
        #go to process ART Adherence obs
        process_art_adherence_obs(encounter, visit)

      elsif encounter['encounter_type'].to_i == EncounterType.find_by_name("EXIT FROM HIV CARE").encounter_type_id #Exit from Care
        #go to process Exit from care obs
        process_exit_from_care_obs(encounter, visit)

      else
        puts "#{encounter['encounter_type']} encounter not ART"
      end #ending if encounter_type
    end #encing encounter_records

  end #ending patient_ids
end

def process_patient_state(patient, visit_date, visit)
  patient_state =  Connection.select_one("SELECT patient_outcome(#{patient}, '#{visit_date}') AS state")

  if patient_state.blank?
    patient_outcome = "Unknown"
  else
    patient_outcome = patient_state['state']
  end

  if patient_outcome == 'Patient died'
    patient_date_enrolled = Connection.select_one("SELECT patient_date_enrolled(#{patient}) as date_enrolled")
    died_in_month = Connection.select_one("SELECT died_in(#{patient}, '#{patient_outcome}', '#{patient_date_enrolled['date_enrolled']}') AS died_month")

    patient_died_in_month = died_in_month['died_month']
  end

  terminal_states = ["Patient transferred out", "Patient died", "Treatment stopped"]

  if terminal_states.include?("#{patient_outcome}")
    current_program_date_completed = Connection.select_one("SELECT date_completed AS date_completed FROM patient_program WHERE patient_id = #{patient} AND program_id = 1 AND voided = 0 LIMIT 1")
    if current_program_date_completed.blank?
      program_date_completed = "NULL"
    else
      program_date_completed = current_program_date_completed['date_completed']
    end
  else
    program_date_completed = "NULL"
  end

  patient_record = Connection.select_one("SELECT ID from flat_table2 WHERE patient_id = #{patient} AND DATE(visit_date) = '#{visit_date}'")

  unless patient_record.blank?
      Connection.execute <<EOF
UPDATE flat_table2
SET  current_hiv_program_state = "#{patient_outcome}", current_hiv_program_start_date = '#{visit_date}', current_hiv_program_end_date = '#{program_date_completed}', patient_died_month = "#{patient_died_in_month}"
WHERE flat_table2.id = '#{patient_record['ID']}';
EOF
 else #else update current_state_for_program---update
        #update current_hiv_program_start_date
        Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, current_hiv_program_state, current_hiv_program_start_date, current_hiv_program_end_date, patient_died_month)
VALUES ("#{patient}", '#{visit_date}', "#{patient_outcome}", '#{visit_date}', '#{program_date_completed}', "#{patient_died_in_month}");
EOF
  end #end if visit blank?
end

def process_hiv_reception_obs(encounter, visit)
  #insert, update and void hiv reception obs
  patient_present_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
                LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                WHERE  name = 'Patient Present' AND voided = 0 AND retired = 0 LIMIT 1")
  patient_present = patient_present_record['concept_id']

  guardian_present_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
                LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                WHERE  name = 'Guardian Present' AND voided = 0 AND retired = 0 LIMIT 1")
  guardian_present = guardian_present_record['concept_id']

  yes_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
      LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
      WHERE  name = 'Yes' AND voided = 0 AND retired = 0 LIMIT 1")
  yes = yes_record['concept_id']

  no_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
        LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
        WHERE  name = 'No' AND voided = 0 AND retired = 0 LIMIT 1")
  no = no_record['concept_id']

  unknown_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
        LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
        WHERE  name = 'Unknown' AND voided = 0 AND retired = 0 LIMIT 1")
  unknown = unknown_record['concept_id']

  patient_obs = Connection.select_all("SELECT * FROM obs
                            WHERE  encounter_id = #{encounter['encounter_id'].to_i}")


  (patient_obs || []).each do |patient|
    patient_visit_date =  patient['obs_datetime'].to_date.strftime("%Y-%m-%d")

    flat_table_2_data = []
    flat_table_2_data = Connection.select_one("SELECT * FROM flat_table2
                                        WHERE patient_id = #{encounter['patient_id']}
                                        AND visit_date = '#{patient_visit_date}'")
    case patient['concept_id']
    when guardian_present
      if flat_table_2_data.blank?
        if (patient['value_coded'] == "#{yes_record['concept_id']}"  || patient['value_text'] == "Yes")
          #insert guardian_present_yes
          Connection.execute <<EOF
INSERT INTO flat_table2
(patient_id, visit_date, guardian_present, guardian_present_enc_id)
VALUES (#{patient['person_id']}, '#{patient_visit_date}', 'Yes', #{patient['encounter_id']});
EOF
        elsif (patient['value_coded'] == "#{no_record['concept_id']}"  || patient['value_text'] == "No")
          #insert guardian_present_no
          Connection.execute <<EOF
INSERT INTO flat_table2
(patient_id, visit_date, guardian_present, guardian_present_enc_id)
VALUES (#{patient['person_id']}, '#{patient_visit_date}', 'No', #{patient['encounter_id']});
EOF
        elsif (patient['value_coded'] == "#{unknown_record['concept_id']}"  || patient['value_text'] == "Unknown")
          #insert guardian_present_unknown
          Connection.execute <<EOF
INSERT INTO flat_table2
(patient_id, visit_date, guardian_present, guardian_present_enc_id)
VALUES (#{patient['person_id']}, '#{patient_visit_date}', 'Unknown', #{patient['encounter_id']});
EOF
        end
      else #else if visit is blank---update
        if (patient['value_coded'] == "#{yes_record['concept_id']}" || patient['value_text'] == "Yes") #check the value_coded
          if patient['voided'] == "0"
            #update guardian_present_yes
            Connection.execute <<EOF
UPDATE flat_table2
SET  guardian_present = 'Yes', guardian_present_enc_id = #{patient['encounter_id']}
WHERE flat_table2.id = '#{flat_table_2_data['ID']}';
EOF
          else #voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  guardian_present = NULL, guardian_present_enc_id = NULL
WHERE flat_table2.id = '#{flat_table_2_data['ID']}';
EOF
          end #end voided
        elsif (patient['value_coded'] == "#{no_record['concept_id']}"  || patient['value_text'] == "No")#check the value_coded
          if patient['voided'] == "0"
            #update guardian_present_no
            Connection.execute <<EOF
UPDATE flat_table2
SET  guardian_present = 'No', guardian_present_enc_id = #{patient['encounter_id']}
WHERE flat_table2.id = '#{flat_table_2_data['ID']}';
EOF
          else #voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  guardian_present = NULL, guardian_present_enc_id = NULL
WHERE flat_table2.id = '#{flat_table_2_data['ID']}';
EOF
          end #end voided
        elsif (patient['value_coded'] == "#{unknown_record['concept_id']}"  || patient['value_text'] == "Unknown") #check the value_coded
          if patient['voided'] == "0"
            #update guardian_present_unknown
            Connection.execute <<EOF
UPDATE flat_table2
SET  guardian_present = 'Unknown', guardian_present_enc_id = #{patient['encounter_id']}
WHERE flat_table2.id = '#{flat_table_2_data['ID']}';
EOF
          else #voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  guardian_present = NULL, guardian_present_enc_id = NULL
WHERE flat_table2.id = '#{flat_table_2_data['ID']}';
EOF
          end #end voided
        end #end check the value_coded
      end #end if visit blank?

    when patient_present
            patient_check = []
            patient_check = Connection.select_one("SELECT ID FROM flat_table2
                                    WHERE patient_id = #{patient['person_id']}
                                    and visit_date = '#{patient_visit_date}'")
      if patient_check.blank?
        if (patient['value_coded'] == "#{yes_record['concept_id']}"  || patient['value_text'] == "Yes")
          #insert patient_present
          Connection.execute <<EOF
INSERT INTO flat_table2
(patient_id, visit_date, patient_present, patient_present_enc_id)
VALUES (#{patient['person_id']}, '#{patient_visit_date}', 'Yes', #{patient['encounter_id']});
EOF
        elsif (patient['value_coded'] == "#{no_record['concept_id']}"  || patient['value_text'] == "No")
          #insert patient_present_no
          Connection.execute <<EOF
INSERT INTO flat_table2
(patient_id, visit_date, patient_present, patient_present_enc_id, patient_present)
VALUES (#{patient['person_id']}, '#{patient_visit_date}', 'No', #{patient['encounter_id']});
EOF
        elsif (patient['value_coded'] == "#{unknown_record['concept_id']}"  || patient['value_text'] == "Unknown")
          #insert patient_present_unknown
          Connection.execute <<EOF
INSERT INTO flat_table2
(patient_id, visit_date, patient_present, patient_present_enc_id)
VALUES (#{patient['person_id']}, '#{patient_visit_date}', 'Unknown', #{patient['encounter_id']});
EOF
        end
      else #else if visit is blank---update
        if (patient['value_coded'] == "#{yes_record['concept_id']}" || patient['value_text'] == "Yes") #check the value_coded
          if patient['voided'] == "0"
            #update patient_present_yes
            Connection.execute <<EOF
UPDATE flat_table2
SET  patient_present = 'Yes', patient_present_enc_id = #{patient['encounter_id']}
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          else #voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  patient_present = NULL, patient_present_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end voided
        elsif (patient['value_coded'] == "#{no_record['concept_id']}"  || patient['value_text'] == "No")#check the value_coded
          if patient['voided'] == "0"
            #update patient_present_no
            Connection.execute <<EOF
UPDATE flat_table2
SET  patient_present = 'No', patient_present_enc_id = #{patient['encounter_id']}
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          else #voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  patient_present = NULL, patient_present_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end voided
        elsif (patient['value_coded'] == "#{unknown_record['concept_id']}"  || patient['value_text'] == "Unknown") #check the value_coded
          if patient['voided'] == "0"
            #update patient_present_unknown
            Connection.execute <<EOF
UPDATE flat_table2
SET  patient_present = 'Unknown', patient_present_enc_id = #{patient['encounter_id']}
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          else #voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  patient_present = NULL, patient_present_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end voided
        end #end check the value_coded
      end #end if visit blank?
    end #end case statement
    puts "Finished working on HIV reception obs for patient_id: #{patient['person_id']}"
  end #end patient_obs
end

def process_vitals_obs(encounter, visit)
  weight_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
WHERE  name = 'Weight' AND voided = 0 AND retired = 0 LIMIT 1")
  weight = weight_record['concept_id']

  height_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
WHERE  name = 'Height (cm)' AND voided = 0 AND retired = 0 LIMIT 1")
  height = height_record['concept_id']

  temperature_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
WHERE  name = 'Temperature' AND voided = 0 AND retired = 0 LIMIT 1")
  temperature = temperature_record['concept_id']

  bmi_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
WHERE  name = 'BMI' AND voided = 0 AND retired = 0 LIMIT 1")
  bmi = bmi_record['concept_id']

  systolic_blood_pressure_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
WHERE  name = 'Systolic blood pressure' AND voided = 0 AND retired = 0 LIMIT 1")
  systolic_blood_pressure = systolic_blood_pressure_record['concept_id']

  diastolic_blood_pressure_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
WHERE  name = 'Diastolic blood pressure' AND voided = 0 AND retired = 0 LIMIT 1")
  diastolic_blood_pressure = diastolic_blood_pressure_record['concept_id']

  weight_for_height_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
WHERE  name = 'Weight for height percent of median' AND voided = 0 AND retired = 0 LIMIT 1")
  weight_for_height = weight_for_height_record['concept_id']

  weight_for_age_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
WHERE  name = 'Weight for age percent of median' AND voided = 0 AND retired = 0 LIMIT 1")
  weight_for_age = weight_for_age_record['concept_id']

  height_for_age_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
WHERE  name = 'Height for age percent of median' AND voided = 0 AND retired = 0 LIMIT 1")
  height_for_age = height_for_age_record['concept_id']

  patient_vitals_obs = Connection.select_all("SELECT person_id, encounter_id, concept_id, obs_datetime,
                            ifnull(value_numeric, value_text) as value, value_datetime, value_coded,
                            value_coded_name_id, voided
                          FROM obs
        WHERE  encounter_id = #{encounter['encounter_id'].to_i}")

  (patient_vitals_obs || []).each do |patient|
    patient_visit_date =  patient['obs_datetime'].to_date.strftime("%Y-%m-%d")
    flat_table_2_data = []
    flat_table_2_data = Connection.select_one("SELECT * FROM flat_table2
                                        WHERE patient_id = #{encounter['patient_id']}
                                        AND visit_date = '#{patient_visit_date}'")
    case patient['concept_id']
      when weight
        if flat_table_2_data.blank?
          #insert weight
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, weight, weight_enc_id)
VALUES ("#{patient['person_id']}", DATE('#{patient_visit_date}'), "#{patient['value']}", "#{patient['encounter_id']}");
EOF
        else #else visit blank
          if patient['voided'] == "1"
            Connection.execute <<EOF
UPDATE flat_table2 SET  weight = NULL, weight_enc_id = NULL WHERE flat_table2.id = "#{flat_table_2_data['ID']}";
EOF
          else #else voided
            Connection.execute <<EOF
UPDATE flat_table2 SET  weight = "#{patient['value']}", weight_enc_id = "#{patient['encounter_id']}" WHERE flat_table2.id = "#{flat_table_2_data['ID']}";
EOF
          end #end if voided
        end #end if visit blank
#---------------------------------------------------------------------end weight
      when height
        patient_check = []
        patient_check = Connection.select_one("SELECT * FROM flat_table2
                                            WHERE patient_id = #{encounter['patient_id']}
                                            AND visit_date = '#{patient_visit_date}'")
        if patient_check.blank?
          #insert height
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, height, height_enc_id)
VALUES ("#{patient['person_id']}", DATE('#{patient_visit_date}'), "#{patient['value']}", "#{patient['encounter_id']}");
EOF
        else #else visit blank
          if patient['voided'] == "1"
            Connection.execute <<EOF
UPDATE flat_table2 SET  height = NULL, height_enc_id = NULL WHERE flat_table2.id = "#{patient_check['ID']}";
EOF
          else #else voided
            Connection.execute <<EOF
UPDATE flat_table2 SET  height = "#{patient['value']}", height_enc_id = "#{patient['encounter_id']}" WHERE flat_table2.id = "#{patient_check['ID']}";
EOF
          end #end if voided
        end #end if visit blank
#---------------------------------------------------------------------end height
      when temperature
        patient_check = []
        patient_check = Connection.select_one("SELECT * FROM flat_table2
                                            WHERE patient_id = #{encounter['patient_id']}
                                            AND visit_date = '#{patient_visit_date}'")
        if patient_check.blank?
          #insert temperature
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, temperature, temperature_enc_id)
VALUES ("#{patient['person_id']}", DATE('#{patient_visit_date}'), "#{patient['value']}", "#{patient['encounter_id']}");
EOF
        else #else visit blank
          if patient['voided'] == "1"
            Connection.execute <<EOF
UPDATE flat_table2 SET  temperature = NULL, temperature_enc_id = NULL WHERE flat_table2.id = "#{patient_check['ID']}";
          else #else voided
EOF
            Connection.execute <<EOF
UPDATE flat_table2 SET  temperature = "#{patient['value']}", temperature_enc_id = "#{patient['encounter_id']}" WHERE flat_table2.id = "#{patient_check['ID']}";
EOF
          end #end if voided
        end #end if visit blank
#---------------------------------------------------------------------end temperature
      when bmi
          patient_check = []
          patient_check = Connection.select_one("SELECT * FROM flat_table2
                                            WHERE patient_id = #{encounter['patient_id']}
                                            AND visit_date = '#{patient_visit_date}'")
        if patient_check.blank?
        #insert bmi
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, bmi, bmi_enc_id)
VALUES ("#{patient['person_id']}", DATE('#{patient_visit_date}'), "#{patient['value']}", "#{patient['encounter_id']}");
EOF
        else #else visit blank
          if patient['voided'] == "1"
            Connection.execute <<EOF
UPDATE flat_table2 SET  bmi = NULL, bmi_enc_id = NULL WHERE flat_table2.id = "#{patient_check['ID']}";
EOF
          else #else voided
            Connection.execute <<EOF
UPDATE flat_table2 SET  bmi = "#{patient['value']}", bmi_enc_id = "#{patient['encounter_id']}" WHERE flat_table2.id = "#{patient_check['ID']}";
EOF
          end #end if voided
        end #end if visit blank
#---------------------------------------------------------------------end bmi
      when systolic_blood_pressure
        patient_check = []
        patient_check = Connection.select_one("SELECT * FROM flat_table2
                                            WHERE patient_id = #{encounter['patient_id']}
                                            AND visit_date = '#{patient_visit_date}'")
        if patient_check.blank?
          #insert systolic_blood_pressure
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, systolic_blood_pressure, systolic_blood_pressure_enc_id)
VALUES ("#{patient['person_id']}", DATE('#{patient_visit_date}'), "#{patient['value']}", "#{patient['encounter_id']}");
EOF
        else #else visit blank
          if patient['voided'] == "1"
            Connection.execute <<EOF
UPDATE flat_table2 SET  systolic_blood_pressure = NULL, systolic_blood_pressure_enc_id = NULL WHERE flat_table2.id = "#{patient_check['ID']}";
EOF
          else #else voided
            Connection.execute <<EOF
UPDATE flat_table2 SET  systolic_blood_pressure = "#{patient['value']}", systolic_blood_pressure_enc_id = "#{patient['encounter_id']}" WHERE flat_table2.id = "#{patient_check['ID']}";
EOF
          end #end if voided
        end #end if visit blank
#---------------------------------------------------------------------end systolic_blood_pressure
      when diastolic_blood_pressure
        patient_check = []
        patient_check = Connection.select_one("SELECT * FROM flat_table2
                                            WHERE patient_id = #{encounter['patient_id']}
                                            AND visit_date = '#{patient_visit_date}'")
        if patient_check.blank?
          #insert diastolic_blood_pressure
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, diastolic_blood_pressure, diastolic_blood_pressure_enc_id)
VALUES ("#{patient['person_id']}", DATE('#{patient_visit_date}'), "#{patient['value']}", "#{patient['encounter_id']}");
EOF
        else #else visit blank
          if patient['voided'] == "1"
            Connection.execute <<EOF
UPDATE flat_table2 SET  diastolic_blood_pressure = NULL, diastolic_blood_pressure_enc_id = NULL WHERE flat_table2.id = "#{patient_check['ID']}";
EOF
          else #else voided
            Connection.execute <<EOF
UPDATE flat_table2 SET  diastolic_blood_pressure = "#{patient['value']}", diastolic_blood_pressure_enc_id = "#{patient['encounter_id']}" WHERE flat_table2.id = "#{patient_check['ID']}";
EOF
          end #end if voided
        end #end if visit blank
#---------------------------------------------------------------------end diastolic_blood_pressure
      when weight_for_height
        patient_check = []
        patient_check = Connection.select_one("SELECT * FROM flat_table2
                                            WHERE patient_id = #{encounter['patient_id']}
                                            AND visit_date = '#{patient_visit_date}'")
        if patient_check.blank?
          #insert weight_for_height
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, weight_for_height, weight_for_height_enc_id)
VALUES ("#{patient['person_id']}", DATE('#{patient_visit_date}'), "#{patient['value']}", "#{patient['encounter_id']}");
EOF
        else #else visit blank
          if patient['voided'] == "1"
            Connection.execute <<EOF
UPDATE flat_table2 SET  weight_for_height = NULL, weight_for_height_enc_id = NULL WHERE flat_table2.id = "#{patient_check['ID']}";
EOF
          else #else voided
            Connection.execute <<EOF
UPDATE flat_table2 SET  weight_for_height = "#{patient['value']}", weight_for_height_enc_id = "#{patient['encounter_id']}" WHERE flat_table2.id = "#{patient_check['ID']}";
EOF
          end #end if voided
        end #end if visit blank
#---------------------------------------------------------------------end weight_for_height
      when weight_for_age
        patient_check = []
        patient_check = Connection.select_one("SELECT * FROM flat_table2
                                            WHERE patient_id = #{encounter['patient_id']}
                                            AND visit_date = '#{patient_visit_date}'")
        if patient_check.blank?
          #insert weight_for_age
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, weight_for_age, weight_for_age_enc_id)
VALUES ("#{patient['person_id']}", DATE('#{patient_visit_date}'), "#{patient['value']}", "#{patient['encounter_id']}");
EOF
        else #else visit blank
          if patient['voided'] == "1"
            Connection.execute <<EOF
UPDATE flat_table2 SET  weight_for_age = NULL, weight_for_age_enc_id = NULL WHERE flat_table2.id = "#{patient_check['ID']}";
EOF
          else #else voided
            Connection.execute <<EOF
UPDATE flat_table2 SET  weight_for_age = "#{patient['value']}", weight_for_age_enc_id = "#{patient['encounter_id']}" WHERE flat_table2.id = "#{patient_check['ID']}";
EOF
          end #end if voided
        end #end if visit blank
#---------------------------------------------------------------------end weight_for_age
      when height_for_age
          patient_check = []
          patient_check = Connection.select_one("SELECT * FROM flat_table2
                                            WHERE patient_id = #{encounter['patient_id']}
                                            AND visit_date = '#{patient_visit_date}'")
        if patient_check.blank?
          #insert height_for_age
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, height_for_age, height_for_age_enc_id)
VALUES ("#{patient['person_id']}", DATE('#{patient_visit_date}'), "#{patient['value']}", "#{patient['encounter_id']}");
EOF
        else #else visit blank
          if patient['voided'] == "1"
            Connection.execute <<EOF
UPDATE flat_table2 SET  height_for_age = NULL, height_for_age_enc_id = NULL WHERE flat_table2.id = "#{patient_check['ID']}";
EOF
          else #else voided
            Connection.execute <<EOF
UPDATE flat_table2 SET  height_for_age = "#{patient['value']}", height_for_age_enc_id = "#{patient['encounter_id']}" WHERE flat_table2.id = "#{patient_check['ID']}";
EOF
          end #end if voided
        end #end if visit blank
#---------------------------------------------------------------------end height_for_age
    end #end case statement
    puts "Finished working on Vitals obs for patient_id: #{patient['person_id']}"
  end #end patient_vitals_obs
end

def process_hiv_clinic_registration_obs(encounter, visit)

  send_sms_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
                      LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                  WHERE name = 'send sms' AND voided = 0 AND retired = 0 LIMIT 1")
  send_sms = send_sms_record['concept_id'].to_i

  location_of_art_initialization_record  = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
                      LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                  WHERE name = 'Location of ART initiation' AND voided = 0 AND retired = 0 LIMIT 1")
  location_of_art_initialization = location_of_art_initialization_record['concept_id'].to_i


  agrees_to_followup_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
                      LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                  WHERE name = 'Agrees to followup' AND voided = 0 AND retired = 0 LIMIT 1")
  agrees_to_followup = agrees_to_followup_record['concept_id'].to_i

  confirmatory_hiv_test_date_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
                      LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                  WHERE name = 'Confirmatory HIV test date' AND voided = 0 AND retired = 0 LIMIT 1")
  confirmatory_hiv_test_date = confirmatory_hiv_test_date_record['concept_id'].to_i

  confirmatory_hiv_test_location_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
                      LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                  WHERE name = 'confirmatory hiv test location' AND voided = 0 AND retired = 0 LIMIT 1")
  confirmatory_hiv_test_location = confirmatory_hiv_test_location_record['concept_id'].to_i

  type_of_confirmatory_hiv_test_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
                      LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                  WHERE name = 'Confirmatory HIV test type' AND voided = 0 AND retired = 0 LIMIT 1")
  type_of_confirmatory_hiv_test = type_of_confirmatory_hiv_test_record['concept_id'].to_i

  date_started_art_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                WHERE name = 'ART start date' AND voided = 0 AND retired = 0 LIMIT 1")
  date_started_art = date_started_art_record['concept_id'].to_i

  has_transfer_letter_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                WHERE name = 'Has transfer letter' AND voided = 0 AND retired = 0 LIMIT 1")
  has_transfer_letter = has_transfer_letter_record['concept_id'].to_i

  ever_received_art_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                WHERE name = 'ever received art' AND voided = 0 AND retired = 0 LIMIT 1")
  ever_received_art = ever_received_art_record['concept_id'].to_i


  ever_reg_4_art_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                WHERE name = 'Ever registered at ART clinic' AND voided = 0 AND retired = 0 LIMIT 1")
  ever_reg_4_art = ever_reg_4_art_record['concept_id'].to_i

  last_arv_reg_record =  Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                WHERE name = 'Last ART drugs taken' AND voided = 0 AND retired = 0 LIMIT 1")
  last_arv_reg = last_arv_reg_record['concept_id'].to_i

  art_in_2_weeks_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                WHERE name = 'Has the patient taken ART in the last two weeks' AND voided = 0 AND retired = 0 LIMIT 1")
  art_in_2_weeks = art_in_2_weeks_record['concept_id'].to_i

  art_in_2_months_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                WHERE name = 'Has the patient taken ART in the last two months' AND voided = 0 AND retired = 0 LIMIT 1")
  art_in_2_months = art_in_2_months_record['concept_id'].to_i

  date_last_taken_arv_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                WHERE name = 'Date ART last taken' AND voided = 0 AND retired = 0 LIMIT 1")
  date_last_taken_arv = date_last_taken_arv_record['concept_id'].to_i

  patient_obs = Connection.select_all("SELECT * FROM obs
    WHERE encounter_id = #{encounter['encounter_id'].to_i}")

  (patient_obs || []).each do |patient|
    patient_visit_date = patient['obs_datetime'].to_date.strftime("%Y-%m-%d")

    case patient['concept_id'].to_i
      when ever_received_art
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded'].to_i
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id WHERE concept.concept_id = #{value_coded} AND voided = 0 AND retired = 0")
        answer = answer_record['name']

        puts ".......... Updating record into flat_table1 (ever_received_art == #{answer}): #{patient['person_id']}"

        Connection.execute <<EOF
UPDATE flat_table1
 SET  ever_received_art = "#{answer}", ever_received_art_enc_id = "#{patient['encounter_id']}",
      ever_received_art_v_date = "#{patient_visit_date}"
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
      puts ".......... Updating record into flat_table1 (ever_received_art) NULL: #{patient['person_id']}"
      Connection.execute <<EOF
UPDATE flat_table1
 SET  ever_received_art = NULL, ever_received_art_enc_id = NULL, ever_received_art_v_date = NULL
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided4
#---------------------------------------------------------------------end ever_received_art

    when send_sms
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded'].to_i
        answer_record = Connection.select_one("SELECT concept_name.name FROM concept_name
                          LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                      WHERE concept.concept_id = #{value_coded}")
        answer = answer_record['name'] rescue nil

        puts "........... Updating record into flat_table1 (send_sms == #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  send_sms = "#{answer}", send_sms_v_date = DATE('#{patient_visit_date}'), send_sms_enc_id = #{patient['encounter_id'].to_i}
 WHERE flat_table1.patient_id = #{patient['person_id']} ;
EOF
      else
        puts "........... Updating record into flat_table1 (send_sms) NULL: #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  send_sms = NULL, send_sms_v_date = NULL, send_sms_enc_id = NULL  WHERE flat_table1.patient_id = #{patient['person_id']} ;
EOF
      end #if voided
#---------------------------------------------------------------------end sms

    when agrees_to_followup
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded'].to_i
        answer_record = Connection.select_one("SELECT concept_name.name FROM concept_name
                          LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                      WHERE concept.concept_id = #{value_coded}")
        answer = answer_record['name'] rescue nil

        puts "........... Updating record into flat_table1 (agrees_to_followup == #{answer}): #{patient['person_id']}"

        Connection.execute <<EOF
UPDATE flat_table1
 SET  agrees_to_followup = "#{answer}", agrees_to_followup_enc_id = "#{patient['encounter_id']}",
      agrees_to_followup_v_date = "#{patient_visit_date}"
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts "........... Updating record into flat_table1 (agrees_to_followup == NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  agrees_to_followup = NULL, agrees_to_followup_enc_id = NULL, agrees_to_followup_v_date = NULL
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided
#---------------------------------------------------------------------end agrees_to_followup

    when confirmatory_hiv_test_date
      if patient['voided'].to_i
        value_datetime = patient['value_datetime']
        puts "........... Updating record into flat_table1 (confirmatory_hiv_test_date == #{value_datetime}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  confirmatory_hiv_test_date = '#{value_datetime}', confirmatory_hiv_test_date_enc_id = "#{patient['encounter_id']}",
      confirmatory_hiv_test_date_v_date = "#{patient_visit_date}"
 WHERE flat_table1.patient_id = #{patient['person_id']} ;
EOF
      else
        puts "........... Updating record into flat_table1 (confirmatory_hiv_test_date == NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  confirmatory_hiv_test_date = NULL, confirmatory_hiv_test_date_enc_id = NULL, confirmatory_hiv_test_date_v_date = NULL
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided
#---------------------------------------------------------------------end confirmatory_hiv_test_date

    when confirmatory_hiv_test_location
      if patient['voided'].to_i == 0
        value_text = patient['value_text']
        unless value_text.blank?
          puts "........... Updating record into flat_table1 (confirmatory_hiv_test_location == #{value_text}): #{patient['person_id']}"
          Connection.execute <<EOF
UPDATE flat_table1
 SET  confirmatory_hiv_test_location = "#{value_text}", confirmatory_hiv_test_location_enc_id = "#{patient['encounter_id']}",
      confirmatory_hiv_test_location_v_date = "#{patient_visit_date}"
 WHERE flat_table1.patient_id = #{patient['person_id']} ;
EOF
        else
          puts "........... Updating record into flat_table1 (confirmatory_hiv_test_location == Unknown): #{patient['person_id']}"
          Connection.execute <<EOF
UPDATE flat_table1
 SET  confirmatory_hiv_test_location = "Unknown", confirmatory_hiv_test_location_enc_id = "#{patient['encounter_id']}",
      confirmatory_hiv_test_location_v_date = "#{patient_visit_date}"
 WHERE flat_table1.patient_id = #{patient['person_id']} ;
EOF
        end #unless
      else
        puts "........... Updating record into flat_table1 (confirmatory_hiv_test_location == NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  confirmatory_hiv_test_location = NULL, confirmatory_hiv_test_location_enc_id = NULL, confirmatory_hiv_test_location_v_date = NULL
 WHERE flat_table1.patient_id = #{patient['person_id']} ;
EOF
      end #voided
#---------------------------------------------------------------------end confirmatory_hiv_test_location

    when location_of_art_initialization
      if patient['voided'].to_i == 0
        value_text = patient['value_text']
        unless value_text.blank?
          puts "........... Updating record into flat_table1 (location_of_art_initialization == #{value_text}): #{patient['person_id']}"
          Connection.execute <<EOF
UPDATE flat_table1
 SET  location_of_art_initialization = "#{patient['value_text']}", location_of_art_initialization_enc_id = "#{patient['encounter_id']}",
      location_of_art_initialization_v_date = "#{patient_visit_date}"
 WHERE flat_table1.patient_id = #{patient['person_id']} ;
EOF
        else
          puts "........... Updating record into flat_table1 (location_of_art_initialization == Unknown): #{patient['person_id']}"
          Connection.execute <<EOF
UPDATE flat_table1
 SET  location_of_art_initialization = "Unknown", location_of_art_initialization_enc_id = "#{patient['encounter_id']}",
      location_of_art_initialization_v_date = "#{patient_visit_date}"
 WHERE flat_table1.patient_id = #{patient['person_id']} ;
EOF
        end #unless
      else
        puts "........... Updating record into flat_table1 (location_of_art_initialization == NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  location_of_art_initialization = NULL, location_of_art_initialization_enc_id = NULL, location_of_art_initialization_v_date = NULL
 WHERE flat_table1.patient_id = #{patient['person_id']} ;
EOF
      end #voided
#---------------------------------------------------------------------end confirmatory_hiv_test_location

    when type_of_confirmatory_hiv_test
      if patient['voided'].to_i == 0
        answer_record = Connection.select_one("SELECT concept_name.name FROM concept_name
                          LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                      WHERE concept.concept_id = #{patient['value_coded']} AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts "........... Updating record into flat_table1 (type_of_confirmatory_hiv_test): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  type_of_confirmatory_hiv_test = "#{answer}", type_of_confirmatory_hiv_test_enc_id = "#{patient['encounter_id']}",
      type_of_confirmatory_hiv_test_v_date = "#{patient_visit_date}"
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts "........... Updating record into flat_table1 (type_of_confirmatory_hiv_test): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  type_of_confirmatory_hiv_test = NULL, type_of_confirmatory_hiv_test_enc_id = NULL, type_of_confirmatory_hiv_test_v_date = NULL
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided
#---------------------------------------------------------------------end type_of_confirmatory_hiv_test

    when date_started_art
      if patient['value_text'].blank?
        value_datetime = patient['value_datetime']
      else
        value_datetime = patient['value_text']
      end
      if patient['voided'].to_i == 0
        puts ".......... Updating record into flat_table1 (date_started_art): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  date_started_art = '#{value_datetime}', date_started_art_enc_id = "#{patient['encounter_id']}",
      date_started_art_v_date =  "#{patient_visit_date}"
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (date_started_art): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  date_started_art = NULL, date_started_art_enc_id = NULL, date_started_art_v_date = NULL
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided
#---------------------------------------------------------------------end date_started_art

    when has_transfer_letter
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (has_transfer_letter): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  has_transfer_letter = "#{answer}", has_transfer_letter_enc_id = "#{patient['encounter_id']}",
      has_transfer_letter_v_date =  "#{patient_visit_date}"
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (has_transfer_letter): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  has_transfer_letter = NULL, has_transfer_letter_enc_id = NULL, has_transfer_letter_v_date = NULL
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided
#---------------------------------------------------------------------end has_transfer_letter

    when ever_reg_4_art
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded'].to_i
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']

        puts ".......... Updating record into flat_table1 (ever_reg_4_art): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  ever_registered_at_art_clinic = "#{answer}", ever_registered_at_art_clinic_enc_id = "#{patient['encounter_id']}", ever_registered_at_art_clinic_v_date = DATE('#{patient_visit_date}')
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (ever_reg_4_art) NULL: #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  ever_registered_at_art_clinic = NULL, ever_registered_at_art_clinic_enc_id = NULL, ever_registered_at_art_clinic_v_date = NULL
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided
#---------------------------------------------------------------------end ever_reg_4_art

    when last_arv_reg
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name'] rescue nil

        puts ".......... Updating record into flat_table1 (last_art_drugs_taken = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  last_art_drugs_taken = "#{answer}", last_art_drugs_taken_enc_id = "#{patient['encounter_id']}", last_art_drugs_taken_v_date = DATE('#{patient_visit_date}')
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (last_art_drugs_taken) NULL: #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  last_art_drugs_taken = NULL, last_art_drugs_taken_enc_id = NULL, last_art_drugs_taken_v_date = NULL
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided
#---------------------------------------------------------------------end last_arv_reg

    when art_in_2_months
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (art_in_2_months): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  taken_art_in_last_two_months = "#{answer}", taken_art_in_last_two_months_enc_id = "#{patient['encounter_id']}", taken_art_in_last_two_months_v_date = DATE('#{patient_visit_date}')
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (art_in_2_months) NULL: #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  taken_art_in_last_two_months = NULL, taken_art_in_last_two_months_enc_id = NULL, taken_art_in_last_two_months_v_date = NULL
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided
#---------------------------------------------------------------------end art_in_2_months

    when date_last_taken_arv
      if patient['voided'].to_i == 0
        value_datetime = patient['value_datetime']
        puts ".......... Updating record into flat_table1 (date_last_taken_arv): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  date_art_last_taken = '#{value_datetime}', date_art_last_taken_enc_id = "#{patient['encounter_id']}", date_art_last_taken_v_date = DATE('#{patient_visit_date}')
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (date_last_taken_arv): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  date_art_last_taken = NULL, date_art_last_taken_enc_id = NULL, date_art_last_taken_v_date = NULL
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided
#---------------------------------------------------------------------end date_last_taken_arv

    when art_in_2_weeks
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (art_in_2_weeks == #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  taken_art_in_last_two_weeks = "#{answer}", taken_art_in_last_two_weeks_enc_id = "#{patient['encounter_id']}", taken_art_in_last_two_weeks_v_date = DATE('#{patient_visit_date}')
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (art_in_2_weeks == NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  taken_art_in_last_two_weeks = NULL,
 taken_art_in_last_two_weeks_enc_id = NULL,
taken_art_in_last_two_weeks_v_date = NULL
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided
#---------------------------------------------------------------------end art_in_2_weeks

    else
      # call process_hiv_staging_obs
      process_hiv_staging_obs(encounter, visit)
    end #case patient['concept_id']
  end #patient_obs

end #method

def process_hiv_staging_obs(encounter, visit)
  pregnant_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
          LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
      WHERE name = 'Is patient pregnant?' AND voided = 0 AND retired = 0")
  pregnant = pregnant_record['concept_id'].to_i

  pregnant2_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
                        LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                    WHERE name = 'patient pregnant' AND voided = 0 AND retired = 0")
  pregnant2 = pregnant2_record['concept_id'].to_i

  pregnant_at_initiation_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
                        LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                    WHERE name = 'Is patient pregnant at initiation?' AND voided = 0 AND retired = 0")
  pregnant_at_initiation = pregnant_at_initiation_record['concept_id'].to_i

  breastfeeding_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
                        LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                    WHERE name = 'Breastfeeding' AND voided = 0 AND retired = 0 LIMIT 1")
  breastfeeding = breastfeeding_record['concept_id'].to_i

  breast_feeding_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
                        LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                    WHERE name = 'Breast feeding' AND voided = 0 AND retired = 0")
  breast_feeding = breast_feeding_record['concept_id'].to_i

  breast_feeding2_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
                        LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                    WHERE name = 'Is patient breast feeding?' AND voided = 0 AND retired = 0 LIMIT 1")
  breast_feeding2 = breast_feeding2_record['concept_id'].to_i

  cd4_count_loc_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                WHERE name = 'Cd4 count location' AND voided = 0 AND retired = 0 LIMIT 1")
  cd4_count_loc = cd4_count_loc_record['concept_id'].to_i

  cd4_count_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                WHERE name = 'Cd4 count' AND voided = 0 AND retired = 0 LIMIT 1")
  cd4_count = cd4_count_record['concept_id'].to_i

  cd4_count_percent_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                WHERE name = 'Cd4 percent' AND voided = 0 AND retired = 0 LIMIT 1")
  cd4_count_percent = cd4_count_percent_record['concept_id'].to_i

  cd4_count_date_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                WHERE name = 'Cd4 count datetime' AND voided = 0 AND retired = 0 LIMIT 1")
  cd4_count_date = cd4_count_date_record['concept_id'].to_i

  cd4_percent_less_than_25_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                WHERE name = 'CD4 percent less than 25' AND voided = 0 AND retired = 0 LIMIT 1")
  cd4_percent_less_than_25 = cd4_percent_less_than_25_record['concept_id'].to_i

  cd4_percent_loc_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                    WHERE name = 'CD4 percent location' AND voided = 0 AND retired = 0 LIMIT 1")
  cd4_percent_loc = cd4_percent_loc_record['concept_id'].to_i

  cd4_count_less_than_250_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                WHERE name = 'CD4 count less than 250' AND voided = 0 AND retired = 0 LIMIT 1")
  cd4_count_less_than_250 = cd4_count_less_than_250_record['concept_id'].to_i

  cd4_count_less_than_or_equal_to_250_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                WHERE name = 'CD4 count less than or equal to 250' AND voided = 0 AND retired = 0 LIMIT 1")
  cd4_count_less_than_or_equal_to_250 = cd4_count_less_than_or_equal_to_250_record['concept_id'].to_i

  cd4_count_less_than_350_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                WHERE name = 'CD4 count less than or equal to 350' AND voided = 0 AND retired = 0 LIMIT 1")
  cd4_count_less_than_350 = cd4_count_less_than_350_record['concept_id'].to_i

  cd4_count_less_than_or_equal_to_350_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                WHERE name = 'CD4 count <= 350' AND voided = 0 AND retired = 0 LIMIT 1")
  cd4_count_less_than_or_equal_to_350 = cd4_count_less_than_or_equal_to_350_record['concept_id'].to_i

  cd4_count_less_than_or_equal_to_500_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                WHERE name = 'CD4 count less than or equal to 500' AND voided = 0 AND retired = 0 LIMIT 1")
  cd4_count_less_than_or_equal_to_500 = cd4_count_less_than_or_equal_to_500_record['concept_id'].to_i

  lymphocyte_count_date_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                WHERE name = 'Lymphocyte count datetime' AND voided = 0 AND retired = 0 LIMIT 1")
  lymphocyte_count_date = lymphocyte_count_date_record['concept_id'].to_i

  lymphocyte_count_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                WHERE name = 'Lymphocyte count' AND voided = 0 AND retired = 0 LIMIT 1")
  lymphocyte_count = lymphocyte_count_record['concept_id'].to_i

  asymptomatic_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                WHERE name = 'Asymptomatic HIV infection' AND voided = 0 AND retired = 0 LIMIT 1")
  asymptomatic = asymptomatic_record['concept_id'].to_i

  pers_gnrl_lymphadenopathy_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                WHERE name = 'Persistent generalized lymphadenopathy' AND voided = 0 AND retired = 0 LIMIT 1")
  pers_gnrl_lymphadenopathy = pers_gnrl_lymphadenopathy_record['concept_id'].to_i

  unspecified_stage_1_cond_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                WHERE name = 'Unspecified stage I condition' AND voided = 0 AND retired = 0 LIMIT 1")
  unspecified_stage_1_cond = unspecified_stage_1_cond_record['concept_id'].to_i

  molluscumm_contagiosum_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                WHERE name = 'Molluscum contagiosum' AND voided = 0 AND retired = 0 LIMIT 1")
  molluscumm_contagiosum = molluscumm_contagiosum_record['concept_id'].to_i

  wart_virus_infection_extensive_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                WHERE name = 'Wart virus infection, extensive' AND voided = 0 AND retired = 0 LIMIT 1")
  wart_virus_infection_extensive = wart_virus_infection_extensive_record['concept_id'].to_i

  oral_ulcerations_recurrent_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                WHERE name = 'Oral ulcerations, recurrent' AND voided = 0 AND retired = 0 LIMIT 1")
  oral_ulcerations_recurrent = oral_ulcerations_recurrent_record['concept_id'].to_i

  parotid_enlargement_pers_unexp_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                WHERE name = 'Parotid enlargement' AND voided = 0 AND retired = 0 LIMIT 1")
  parotid_enlargement_pers_unexp = parotid_enlargement_pers_unexp_record['concept_id'].to_i

  lineal_gingival_erythema_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                WHERE name = 'Lineal gingival erythema' AND voided = 0 AND retired = 0 LIMIT 1")
  lineal_gingival_erythema = lineal_gingival_erythema_record['concept_id'].to_i

  herpes_zoster_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                WHERE name = 'Herpes zoster' AND voided = 0 AND retired = 0 LIMIT 1")
  herpes_zoster = herpes_zoster_record['concept_id'].to_i

  resp_tract_infections_rec_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                WHERE name = 'Respiratory tract infections, recurrent (sinusitis, tonsilitus, otitis media, pharyngitis)' AND voided = 0 AND retired = 0 LIMIT 1")
  resp_tract_infections_rec = resp_tract_infections_rec_record['concept_id'].to_i

  unspecified_stage2_condition_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                WHERE name = 'Unspecified stage II condition' AND voided = 0 AND retired = 0 LIMIT 1")
  unspecified_stage2_condition = unspecified_stage2_condition_record['concept_id'].to_i

  angular_chelitis_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                WHERE name = 'Angular cheilitis' AND voided = 0 AND retired = 0 LIMIT 1")
  angular_chelitis = angular_chelitis_record['concept_id'].to_i

  papular_prurtic_eruptions_record = Connection.select_one("SELECT concept_name.concept_id FROM  concept_name
                    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                WHERE name = 'Papular pruritic eruptions / Fungal nail infections' AND voided = 0 AND retired = 0 LIMIT 1")
  papular_prurtic_eruptions = papular_prurtic_eruptions_record['concept_id'].to_i

  hepatosplenomegaly_unexplained_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                WHERE name = 'Hepatosplenomegaly persistent unexplained' AND voided = 0 AND retired = 0 LIMIT 1")
  hepatosplenomegaly_unexplained = hepatosplenomegaly_unexplained_record['concept_id'].to_i

  oral_hairy_leukoplakia_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                WHERE name = 'Oral hairy leukoplakia' AND voided = 0 AND retired = 0 LIMIT 1")
  oral_hairy_leukoplakia = oral_hairy_leukoplakia_record['concept_id'].to_i

  severe_weight_loss_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                WHERE name = 'Severe weight loss >10% and/or BMI <18.5kg/m^2, unexplained' AND voided = 0 AND retired = 0 LIMIT 1")
  severe_weight_loss = severe_weight_loss_record['concept_id'].to_i

  fever_persistent_unexplained_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                WHERE name = 'Fever, persistent unexplained, intermittent or constant, >1 month' AND voided = 0 AND retired = 0 LIMIT 1")
  fever_persistent_unexplained = fever_persistent_unexplained_record['concept_id'].to_i

  pulmonary_tuberculosis_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                WHERE name = 'Pulmonary tuberculosis (current)' AND voided = 0 AND retired = 0 LIMIT 1")
  pulmonary_tuberculosis = pulmonary_tuberculosis_record['concept_id'].to_i

  pulmonary_tuberculosis_last_2_years_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                WHERE name = 'Tuberculosis (PTB or EPTB) within the last 2 years' AND voided = 0 AND retired = 0 LIMIT 1")
  pulmonary_tuberculosis_last_2_years = pulmonary_tuberculosis_last_2_years_record['concept_id'].to_i

  ptb_last_2_years_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                WHERE name = 'Ptb within the past two years' AND voided = 0 AND retired = 0 LIMIT 1")
  ptb_last_2_years = ptb_last_2_years_record['concept_id'].to_i


  severe_bacterial_infection_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                WHERE name = 'Severe bacterial infections (pneumonia, empyema, pyomyositis, bone/joint, meningitis, bacteraemia)' AND voided = 0 AND retired = 0 LIMIT 1")
  severe_bacterial_infection = severe_bacterial_infection_record['concept_id'].to_i

  bacterial_pnuemonia_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                WHERE name = 'Bacterial pneumonia, severe recurrent' AND voided = 0 AND retired = 0 LIMIT 1")
  bacterial_pnuemonia = bacterial_pnuemonia_record['concept_id'].to_i

  symptomatic_lymphoid_interstitial_pnuemonitis_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                WHERE name = 'Symptomatic lymphoid interstitial pneumonia' AND voided = 0 AND retired = 0 LIMIT 1")
  symptomatic_lymphoid_interstitial_pnuemonitis = symptomatic_lymphoid_interstitial_pnuemonitis_record['concept_id'].to_i

  chronic_hiv_assoc_lung_disease_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                WHERE name = 'Chronic HIV lung disease' AND voided = 0 AND retired = 0 LIMIT 1")
  chronic_hiv_assoc_lung_disease = chronic_hiv_assoc_lung_disease_record['concept_id'].to_i

  unspecified_stage3_condition_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                WHERE name = 'Unspecified stage III condition' AND voided = 0 AND retired = 0 LIMIT 1")
  unspecified_stage3_condition = unspecified_stage3_condition_record['concept_id'].to_i

  aneamia_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                WHERE name = 'Anaemia, unexplained < 8 g/dl' AND voided = 0 AND retired = 0 LIMIT 1")
  aneamia = aneamia_record['concept_id'].to_i

  neutropaenia_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                WHERE name = 'Neutropaenia, unexplained < 500 /mm(cubed)' AND voided = 0 AND retired = 0 LIMIT 1")
  neutropaenia = neutropaenia_record['concept_id'].to_i

  thrombocytopaenia_chronic_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                WHERE name = 'Thrombocytopaenia, chronic < 50,000 /mm(cubed)' AND voided = 0 AND retired = 0 LIMIT 1")
  thrombocytopaenia_chronic = thrombocytopaenia_chronic_record['concept_id'].to_i

  diarhoea_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                WHERE name = 'Diarrhoea, chronic (>1 month) unexplained' AND voided = 0 AND retired = 0 LIMIT 1")
  diarhoea = diarhoea_record['concept_id'].to_i

  oral_candidiasis_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                WHERE name = 'Oral candidiasis' AND voided = 0 AND retired = 0 LIMIT 1")
  oral_candidiasis = oral_candidiasis_record['concept_id'].to_i

  acute_necrotizing_ulcerative_gingivitis_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                WHERE name LIKE '%Acute necrotizing ulcerative stomatitis, gingivitis or periodontitis%' AND voided = 0 AND retired = 0 LIMIT 1")
  acute_necrotizing_ulcerative_gingivitis = acute_necrotizing_ulcerative_gingivitis_record['concept_id'].to_i

  lymph_node_tuberculosis_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                WHERE name = 'Lymph node tuberculosis' AND voided = 0 AND retired = 0 LIMIT 1")
  lymph_node_tuberculosis = lymph_node_tuberculosis_record['concept_id'].to_i

  toxoplasmosis_of_brain_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                WHERE name = 'Toxoplasmosis of the brain' AND voided = 0 AND retired = 0 LIMIT 1")
  toxoplasmosis_of_brain = toxoplasmosis_of_brain_record['concept_id'].to_i

  cryptococcal_meningitis_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                WHERE name = 'Cryptococcal meningitis or other extrapulmonary cryptococcosis' AND voided = 0 AND retired = 0 LIMIT 1")
  cryptococcal_meningitis = cryptococcal_meningitis_record['concept_id'].to_i

  progressive_multifocal_leukoencephalopathy_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                WHERE name = 'Progressive multifocal leukoencephalopathy' AND voided = 0 AND retired = 0 LIMIT 1")
  progressive_multifocal_leukoencephalopathy = progressive_multifocal_leukoencephalopathy_record['concept_id'].to_i

  disseminated_mycosis_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                WHERE name = 'Disseminated mycosis (coccidiomycosis or histoplasmosis)' AND voided = 0 AND retired = 0 LIMIT 1")
  disseminated_mycosis = disseminated_mycosis_record['concept_id'].to_i

  candidiasis_of_oesophagus_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                WHERE name = 'Candidiasis of oseophagus, trachea and bronchi or lungs' AND voided = 0 AND retired = 0 LIMIT 1")
  candidiasis_of_oesophagus = candidiasis_of_oesophagus_record['concept_id'].to_i

  extrapulmonary_tuberculosis_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                WHERE name = 'Extrapulmonary tuberculosis (EPTB)' AND voided = 0 AND retired = 0 LIMIT 1")
  extrapulmonary_tuberculosis = extrapulmonary_tuberculosis_record['concept_id'].to_i

  cerebral_non_hodgkin_lymphoma_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                WHERE name = 'Cerebral or B-cell non Hodgkin lymphoma' AND voided = 0 AND retired = 0 LIMIT 1")
  cerebral_non_hodgkin_lymphoma = cerebral_non_hodgkin_lymphoma_record['concept_id'].to_i


  hiv_encephalopathy_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                WHERE name = 'HIV encephalopathy' AND voided = 0 AND retired = 0 LIMIT 1")
  hiv_encephalopathy = hiv_encephalopathy_record['concept_id'].to_i

  bacterial_infections_severe_recurrent_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                WHERE name = 'Bacterial infections, severe recurrent  (empyema, pyomyositis, meningitis, bone/joint infections but EXCLUDING pneumonia)' AND voided = 0 AND retired = 0 LIMIT 1")
  bacterial_infections_severe_recurrent = bacterial_infections_severe_recurrent_record['concept_id'].to_i

  unspecified_stage_4_condition_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                WHERE name = 'Unspecified stage IV condition' AND voided = 0 AND retired = 0 LIMIT 1")
  unspecified_stage_4_condition = unspecified_stage_4_condition_record['concept_id'].to_i

  pnuemocystis_pnuemonia_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                    WHERE name = 'Pneumocystis pneumonia' AND voided = 0 AND retired = 0")
  pnuemocystis_pnuemonia = pnuemocystis_pnuemonia_record['concept_id'].to_i

  disseminated_non_tuberculosis_mycobactierial_infection_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                WHERE name = 'Disseminated non-tuberculosis mycobacterial infection' AND voided = 0 AND retired = 0 LIMIT 1")
  disseminated_non_tuberculosis_mycobactierial_infection = disseminated_non_tuberculosis_mycobactierial_infection_record['concept_id'].to_i

  cryptosporidiosis_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                WHERE name = 'Cryptosporidiosis, chronic with diarroea' AND voided = 0 AND retired = 0 LIMIT 1")
  cryptosporidiosis = cryptosporidiosis_record['concept_id'].to_i

  isosporiasis_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                WHERE name = 'Isosporiasis >1 month' AND voided = 0 AND retired = 0 LIMIT 1")
  isosporiasis = isosporiasis_record['concept_id'].to_i

  symptomatic_hiv_asscoiated_nephropathy_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                WHERE name = 'Symptomatic HIV associated nephropathy or cardiomyopathy' AND voided = 0 AND retired = 0 LIMIT 1")
  symptomatic_hiv_asscoiated_nephropathy = symptomatic_hiv_asscoiated_nephropathy_record['concept_id'].to_i

  chronic_herpes_simplex_infection_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                WHERE name = 'Chronic herpes simplex infection (orolabial, gential / anorectal >1 month or visceral at any site)' AND voided = 0 AND retired = 0 LIMIT 1")
  chronic_herpes_simplex_infection = chronic_herpes_simplex_infection_record['concept_id'].to_i

  cytomegalovirus_infection_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                WHERE name = 'Cytomegalovirus infection' AND voided = 0 AND retired = 0 LIMIT 1")
  cytomegalovirus_infection = cytomegalovirus_infection_record['concept_id'].to_i

  toxoplasomis_of_the_brain_1month_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                WHERE name = 'Toxoplasmosis, brain > 1 month' AND voided = 0 AND retired = 0 LIMIT 1")
  toxoplasomis_of_the_brain_1month = toxoplasomis_of_the_brain_1month_record['concept_id'].to_i

  recto_vaginal_fitsula_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                WHERE name = 'Rectovaginal fistula' AND voided = 0 AND retired = 0 LIMIT 1")
  recto_vaginal_fitsula = recto_vaginal_fitsula_record['concept_id'].to_i

  mod_wght_loss_less_thanequal_to_10_perc_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                WHERE name = 'Moderate weight loss less than or equal to 10 percent, unexplained' AND voided = 0 AND retired = 0 LIMIT 1")
  mod_wght_loss_less_thanequal_to_10_perc = mod_wght_loss_less_thanequal_to_10_perc_record['concept_id'].to_i

  seborrhoeic_dermatitis_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                WHERE name = 'Seborrhoeic dermatitis' AND voided = 0 AND retired = 0 LIMIT 1")
  seborrhoeic_dermatitis = seborrhoeic_dermatitis_record['concept_id'].to_i

  hepatitis_b_or_c_infection_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                WHERE name = 'Hepatitis B or C infection' AND voided = 0 AND retired = 0 LIMIT 1")
  hepatitis_b_or_c_infection = hepatitis_b_or_c_infection_record['concept_id'].to_i

  kaposis_sarcoma_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                WHERE name = 'Kaposis sarcoma' AND voided = 0 AND retired = 0 LIMIT 1")
  kaposis_sarcoma = kaposis_sarcoma_record['concept_id'].to_i

  non_typhoidal_salmonella_bacteraemia_recurrent_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                WHERE name = 'Non-typhoidal salmonella bacteraemia, recurrent' AND voided = 0 AND retired = 0 LIMIT 1")
  non_typhoidal_salmonella_bacteraemia_recurrent = non_typhoidal_salmonella_bacteraemia_recurrent_record['concept_id'].to_i

  leishmaniasis_atypical_disseminated_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                WHERE name = 'Atypical disseminated leishmaniasis' AND voided = 0 AND retired = 0 LIMIT 1")
  leishmaniasis_atypical_disseminated = leishmaniasis_atypical_disseminated_record['concept_id'].to_i

  cerebral_or_b_cell_non_hodgkin_lymphoma_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                WHERE name = 'Cerebral or B-cell non Hodgkin lymphoma' AND voided = 0 AND retired = 0 LIMIT 1")
  cerebral_or_b_cell_non_hodgkin_lymphoma = cerebral_or_b_cell_non_hodgkin_lymphoma_record['concept_id'].to_i

  invasive_cancer_of_cervix_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                WHERE name = 'invasive cancer of cervix' AND voided = 0 AND retired = 0 LIMIT 1")
  invasive_cancer_of_cervix = invasive_cancer_of_cervix_record['concept_id'].to_i

  cryptococcal_meningitis_or_other_eptb_cryptococcosis_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                        LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                    WHERE name = 'Cryptococcal meningitis or other extrapulmonary cryptococcosis' AND voided = 0 AND retired = 0 LIMIT 1")
  cryptococcal_meningitis_or_other_eptb_cryptococcosis = cryptococcal_meningitis_or_other_eptb_cryptococcosis_record['concept_id'].to_i

  severe_unexplained_wasting_malnutrition_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                        LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                    WHERE name = 'Severe unexplained wasting or malnutrition not responding to treatment (weight-for-height/ -age <70% or MUAC less than 11cm or oedema)' AND voided = 0 AND retired = 0 LIMIT 1")
  severe_unexplained_wasting_malnutrition = severe_unexplained_wasting_malnutrition_record['concept_id'].to_i

  diarrhoea_chronic_less_1_month_unexplained_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                        LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                    WHERE name = 'Diarrhoea, chronic (>1 month) unexplained' AND voided = 0 AND retired = 0 LIMIT 1")
  diarrhoea_chronic_less_1_month_unexplained = diarrhoea_chronic_less_1_month_unexplained_record['concept_id'].to_i

  moderate_weight_loss_10_unexplained_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                        LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                    WHERE name = 'Moderate weight loss less than or equal to 10 percent, unexplained' AND voided = 0 AND retired = 0 LIMIT 1")
  moderate_weight_loss_10_unexplained = moderate_weight_loss_10_unexplained_record['concept_id'].to_i

  cd4_percentage_available_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                        LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                    WHERE name = 'CD4 percent available' AND voided = 0 AND retired = 0 LIMIT 1")
  cd4_percentage_available = cd4_percentage_available_record['concept_id'].to_i rescue nil

  acute_necrotizing_ulcerative_stomatitis_gingivitis_or_period_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                        LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                    WHERE name = 'Acute necrotizing ulcerative stomatitis, gingivitis or periodontitis' AND voided = 0 AND retired = 0 LIMIT 1")
  acute_necrotizing_ulcerative_stomatitis_gingivitis_or_period = acute_necrotizing_ulcerative_stomatitis_gingivitis_or_period_record['concept_id'].to_i rescue nil

  moderate_unexplained_wasting_malnutrition_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                        LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                    WHERE name = 'Moderate unexplained wasting/malnutrition not responding to treatment (weight-for-height/ -age 70-79% or muac 11-12 cm)' AND voided = 0 AND retired = 0 LIMIT 1")
  moderate_unexplained_wasting_malnutrition = moderate_unexplained_wasting_malnutrition_record['concept_id'].to_i

  diarrhoea_persistent_unexplained_14_days_or_more_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                        LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                    WHERE name = 'Diarrhoea, persistent unexplained (14 days or more)' AND voided = 0 AND retired = 0 LIMIT 1")
  diarrhoea_persistent_unexplained_14_days_or_more = diarrhoea_persistent_unexplained_14_days_or_more_record['concept_id'].to_i

  acute_ulcerative_mouth_infections_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                        LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                    WHERE name = 'Acute ulcerative mouth infections' AND voided = 0 AND retired = 0 LIMIT 1")
  acute_ulcerative_mouth_infections = acute_ulcerative_mouth_infections_record['concept_id'].to_i

  anaemia_unexplained_8_g_dl_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                        LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                    WHERE name = 'Anaemia, unexplained < 8 g/dl' AND voided = 0 AND retired = 0 LIMIT 1")
  anaemia_unexplained_8_g_dl = anaemia_unexplained_8_g_dl_record['concept_id'].to_i

  atypical_mycobacteriosis_disseminated_or_lung_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                        LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                    WHERE name = 'Atypical mycobacteriosis, disseminated or lung' AND voided = 0 AND retired = 0 LIMIT 1")
  atypical_mycobacteriosis_disseminated_or_lung = atypical_mycobacteriosis_disseminated_or_lung_record['concept_id'].to_i

  bacterial_infections_sev_recurrent_excluding_pneumonia_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                        LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                    WHERE name = 'Bacterial infections, severe recurrent  (empyema, pyomyositis, meningitis, bone/joint infections but EXCLUDING pneumonia)' AND voided = 0 AND retired = 0 LIMIT 1")
  bacterial_infections_sev_recurrent_excluding_pneumonia = bacterial_infections_sev_recurrent_excluding_pneumonia_record['concept_id'].to_i

  cancer_cervix_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                        LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                    WHERE name = 'Cancer cervix' AND voided = 0 AND retired = 0 LIMIT 1")
  cancer_cervix = cancer_cervix_record['concept_id'].to_i

  chronic_herpes_simplex_infection_genital_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                        LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                    WHERE name = 'Chronic herpes simplex infection(orolabial, genital / anorectal >1 month or visceral at any site)' AND voided = 0 AND retired = 0 LIMIT 1")
  chronic_herpes_simplex_infection_genital = chronic_herpes_simplex_infection_genital_record['concept_id'].to_i

  cryptosporidiosis_chronic_with_diarrhoea_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                        LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                    WHERE name = 'Cryptosporidiosis, chronic with diarroea' AND voided = 0 AND retired = 0 LIMIT 1")
  cryptosporidiosis_chronic_with_diarrhoea = cryptosporidiosis_chronic_with_diarrhoea_record['concept_id'].to_i

  cytomegalovirus_infection_retinitis_or_other_organ_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                        LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                    WHERE name = 'Cytomegalovirus infection: rentinitis or other organ (from age 1 month)' AND voided = 0 AND retired = 0 LIMIT 1")
  cytomegalovirus_infection_retinitis_or_other_organ = cytomegalovirus_infection_retinitis_or_other_organ_record['concept_id'].to_i

  cytomegalovirus_of_an_organ_other_than_liver_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                        LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                    WHERE name = 'Cytomegalovirus of an organ other than liver, spleen or lymph node' AND voided = 0 AND retired = 0 LIMIT 1")
  cytomegalovirus_of_an_organ_other_than_liver = cytomegalovirus_of_an_organ_other_than_liver_record['concept_id'].to_i

  fungal_nail_infections_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                        LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                    WHERE name = 'Fungal nail infection' AND voided = 0 AND retired = 0 LIMIT 1")
  fungal_nail_infections = fungal_nail_infections_record['concept_id'].to_i

  herpes_simplex_infection_mucocutaneous_visceral_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                        LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                    WHERE name = 'Herpes simplex infection, mucocutaneous for longer than 1 month or visceral' AND voided = 0 AND retired = 0 LIMIT 1")
  herpes_simplex_infection_mucocutaneous_visceral = herpes_simplex_infection_mucocutaneous_visceral_record['concept_id'].to_i

  hiv_associated_cardiomyopathy_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                        LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                    WHERE name = 'HIV associated cardiomyopathy' AND voided = 0 AND retired = 0 LIMIT 1")
  hiv_associated_cardiomyopathy = hiv_associated_cardiomyopathy_record['concept_id'].to_i

  hiv_associated_nephropathy_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                        LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                    WHERE name = 'HIV associated nephropathy' AND voided = 0 AND retired = 0 LIMIT 1")
  hiv_associated_nephropathy = hiv_associated_nephropathy_record['concept_id'].to_i

  invasive_cancer_cervix_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                        LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                    WHERE name = 'Invasive cancer of cervix' AND voided = 0 AND retired = 0 LIMIT 1")
  invasive_cancer_cervix = invasive_cancer_cervix_record['concept_id'].to_i

  isosporiasis_1_month_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                        LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                    WHERE name = 'Isosporiasis >1 month' AND voided = 0 AND retired = 0 LIMIT 1")
  isosporiasis_1_month = isosporiasis_1_month_record['concept_id'].to_i

  minor_mucocutaneous_manifestations_seborrheic_dermatitis_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                        LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                    WHERE name = 'Minor mucocutaneous manifestations (seborrheic dermatitis, prurigo, fungal nail infections, recurrent oral ulcerations, angular chelitis)' AND voided = 0 AND retired = 0 LIMIT 1")
  minor_mucocutaneous_manifestations_seborrheic_dermatitis = minor_mucocutaneous_manifestations_seborrheic_dermatitis_record['concept_id'].to_i

  moderate_unexplained_malnutrition_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                        LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                    WHERE name = 'Moderate unexplained wasting/malnutrition not responding to treatment (weight-for-height/ -age 70-79% or muac 11-12 cm)' AND voided = 0 AND retired = 0 LIMIT 1")
  moderate_unexplained_malnutrition = moderate_unexplained_malnutrition_record['concept_id'].to_i

  molluscum_contagiosum_extensive_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                        LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                    WHERE name = 'Molluscum contagiosum, extensive' AND voided = 0 AND retired = 0 LIMIT 1")
  molluscum_contagiosum_extensive = molluscum_contagiosum_extensive_record['concept_id'].to_i

  oral_candidiasis_from_age_2_months_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                        LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                    WHERE name = 'Oral candidiasis (from age 2 months)' AND voided = 0 AND retired = 0 LIMIT 1")
  oral_candidiasis_from_age_2_months = oral_candidiasis_from_age_2_months_record['concept_id'].to_i

  oral_thrush_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                        LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                    WHERE name = 'Oral thrush' AND voided = 0 AND retired = 0 LIMIT 1")
  oral_thrush = oral_thrush_record['concept_id'].to_i

  perform_extended_staging_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                        LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                    WHERE name = 'Perform extended staging' AND voided = 0 AND retired = 0 LIMIT 1")
  perform_extended_staging = perform_extended_staging_record['concept_id'].to_i

  pneumocystis_carinii_pneumonia_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                        LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                    WHERE name = 'Pneumocystis carinii pneumonia' AND voided = 0 AND retired = 0 LIMIT 1")
  pneumocystis_carinii_pneumonia = pneumocystis_carinii_pneumonia_record['concept_id'].to_i

  pneumonia_severe_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                        LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                    WHERE name = 'Pneumonia, severe' AND voided = 0 AND retired = 0 LIMIT 1")
  pneumonia_severe = pneumonia_severe_record['concept_id'].to_i

  recurrent_bacteraemia_or_sepsis_with_nts_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                        LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                    WHERE name = 'Recurrent bacteraemia or sepsis with NTS' AND voided = 0 AND retired = 0 LIMIT 1")
  recurrent_bacteraemia_or_sepsis_with_nts = recurrent_bacteraemia_or_sepsis_with_nts_record['concept_id'].to_i

  recurrent_severe_presumed_pneumonia_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                        LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                    WHERE name = 'Recurrent severe presumed pneumonia' AND voided = 0 AND retired = 0 LIMIT 1")
  recurrent_severe_presumed_pneumonia = recurrent_severe_presumed_pneumonia_record['concept_id'].to_i

  recurrent_upper_respiratory_tract_bac_sinusitis_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                        LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                    WHERE name = 'Recurrent upper respiratory infection (ie, bacterial sinusitis)' AND voided = 0 AND retired = 0 LIMIT 1")
  recurrent_upper_respiratory_tract_bac_sinusitis = recurrent_upper_respiratory_tract_bac_sinusitis_record['concept_id'].to_i

  sepsis_severe_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                        LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                    WHERE name = 'Sepsis, severe' AND voided = 0 AND retired = 0 LIMIT 1")
  sepsis_severe = sepsis_severe_record['concept_id'].to_i

  tb_lymphadenopathy_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                        LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                    WHERE name = 'TB lymphadenopathy' AND voided = 0 AND retired = 0 LIMIT 1")
  tb_lymphadenopathy = tb_lymphadenopathy_record['concept_id'].to_i

  unexplained_anaemia_neutropenia_or_thrombocytopenia_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                        LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                    WHERE name = 'Unexplained anaemia, neutropaenia, or throbocytopaenia' AND voided = 0 AND retired = 0 LIMIT 1")
  unexplained_anaemia_neutropenia_or_thrombocytopenia = unexplained_anaemia_neutropenia_or_thrombocytopenia_record['concept_id'].to_i

  visceral_leishmaniasis_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name concept_name
                        LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                    WHERE name = 'Visceral leishmaniasis' AND voided = 0 AND retired = 0 LIMIT 1")
  visceral_leishmaniasis = visceral_leishmaniasis_record['concept_id'].to_i

  reason_for_eligibility_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
                      LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                  WHERE name = 'Reason for ART eligibility' AND voided = 0 AND retired = 0 LIMIT 1")
  reason_for_eligibility = reason_for_eligibility_record['concept_id'].to_i rescue nil

  who_stage_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
                      LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                  WHERE name = 'WHO stage' AND voided = 0 AND retired = 0 LIMIT 1")
  who_stage = who_stage_record['concept_id'].to_i

  who_stages_criteria_present_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
                      LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                  WHERE name = 'Who stages criteria present' AND voided = 0 AND retired = 0 LIMIT 1")
  who_stages_criteria_present = who_stages_criteria_present_record['concept_id'].to_i

  patient_obs = Connection.select_all("SELECT * FROM obs
    WHERE encounter_id = #{encounter['encounter_id'].to_i}")

  (patient_obs || []).each do |patient|
    #puts "concept_id = #{patient['concept_id'].to_i}"
    patient_visit_date =  patient['obs_datetime'].to_date.strftime("%Y-%m-%d")

    flat_table_1_data = []
    flat_table1_record = Connection.select_one("SELECT * FROM flat_table1 WHERE flat_table1.patient_id = #{patient['person_id']}") rescue nil

    case patient['concept_id'].to_i
    when pregnant
      yes_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id WHERE name = 'Yes' AND voided = 0 AND retired = 0 LIMIT 1")
      yes = yes_record['concept_id'].to_i

      no_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id WHERE name = 'No' AND voided = 0 AND retired = 0 LIMIT 1")
      no = no_record['concept_id'].to_i

      unknown_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id WHERE name = 'Unknown' AND voided = 0 AND retired = 0 LIMIT 1")
      unknown = unknown_record['concept_id'].to_i
      value_coded_name_id = patient['value_coded_name_id']
      value_record = Connection.select_one("SELECT * FROM concept_name WHERE concept_name_id = #{value_coded_name_id}")
      value = value_record['name']

      encounter_type_record = Connection.select_one("SELECT en.* FROM encounter_type en INNER JOIN encounter e ON e.encounter_type = en.encounter_type_id WHERE e.encounter_id = #{patient['encounter_id']} LIMIT 1")
      encounter_type_name = encounter_type_record['name']

      if flat_table1_record.blank?
        if (encounter_type_name == 'HIV STAGING')
          Connection.execute <<EOF
INSERT INTO flat_table1 (patient_id, patient_pregnant, patient_pregnant_enc_id, patient_pregnant_v_date)
VALUES (#{patient['person_id']}, "#{value}", #{patient['encounter_id']}, DATE('#{patient_visit_date}'));
EOF
        elsif (encounter_type_name == 'HIV CLINIC CONSULTATION')
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, patient_pregnant, patient_pregnant_enc_id, patient_pregnant_v_date)
VALUES (#{patient['person_id']}, DATE('#{patient_visit_date}'), "#{value}", #{patient['encounter_id']}, DATE('#{patient_visit_date}');
EOF
        end #encounter_type
      else
        if (encounter_type_name == 'HIV STAGING')
          if patient['voided'].to_i == 0
            Connection.execute <<EOF
UPDATE flat_table1
SET  patient_pregnant = "#{value}", patient_pregnant_enc_id = #{patient['encounter_id']},
  patient_pregnant_v_date = DATE('#{patient_visit_date}')
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
          else
            Connection.execute <<EOF
UPDATE flat_table1
SET  patient_pregnant = NULL, patient_pregnant_enc_id = NULL,
  patient_pregnant_v_date = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
          end #voided
        elsif (encounter_type_name == 'HIV CLINIC CONSULTATION')
          if patient['voided'].to_i == 0
            Connection.execute <<EOF
UPDATE flat_table2
SET  patient_pregnant = "#{value}", patient_pregnant_enc_id = '#{patient['encounter_id']}', patient_pregnant_v_date = DATE('#{patient_visit_date}')
WHERE flat_table2.id = #{visit};
EOF
          else
            Connection.execute <<EOF
UPDATE flat_table2
SET  patient_pregnant = NULL, patient_pregnant_enc_id = NULL, patient_pregnant_v_date = NULL
WHERE flat_table2.id = #{visit};
EOF
          end #voided
        end #encounter_type
      end #visit

    when pregnant2
      yes_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id WHERE name = 'Yes' AND voided = 0 AND retired = 0 LIMIT 1")
      yes = yes_record['concept_id'].to_i

      no_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id WHERE name = 'No' AND voided = 0 AND retired = 0 LIMIT 1")
      no = no_record['concept_id'].to_i

      unknown_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id WHERE name = 'Unknown' AND voided = 0 AND retired = 0 LIMIT 1")
      unknown = unknown_record['concept_id'].to_i

      value_coded_name_id = patient['value_coded_name_id']
      value_record = Connection.select_one("SELECT * FROM concept_name WHERE concept_name_id = #{value_coded_name_id}")
      value = value_record['name']

      encounter_type_record = Connection.select_one("SELECT * FROM encounter e WHERE e.encounter_id = #{patient['encounter_id']} AND voided = #{patient['voided']}")
      encounter_type = encounter_type_record['encounter_type'].to_i

      if flat_table1_record.blank?
        if (encounter_type_name == 'HIV STAGING')
          Connection.execute <<EOF
INSERT INTO flat_table1
(patient_id, patient_pregnant, patient_pregnant_enc_id, patient_pregnant_v_date)
VALUES (#{patient['person_id']}, "#{value}", #{patient['encounter_id']}, DATE('#{patient_visit_date}');
EOF
        elsif (encounter_type_name == 'HIV CLINIC CONSULTATION')
          Connection.execute <<EOF
INSERT INTO flat_table2
(patient_id, visit_date, patient_pregnant, patient_pregnant_enc_id, patient_pregnant_v_date )
VALUES (#{patient['person_id']}, DATE('#{patient_visit_date}'), "#{value}", #{patient['encounter_id']}, #DATE('#{patient_visit_date}');
EOF
        end #encounter_type
      else
        if (encounter_type_name == 'HIV STAGING')
          if patient['voided'].to_i == 0
            Connection.execute <<EOF
UPDATE flat_table1
SET  patient_pregnant = "#{value}", patient_pregnant_enc_id = #{patient['encounter_id']},
  patient_pregnant_v_date = DATE('#{patient_visit_date}')
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
          else
            Connection.execute <<EOF
UPDATE flat_table1
SET  patient_pregnant = NULL, patient_pregnant_enc_id = NULL,
  patient_pregnant_v_date = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
          end #voided
        elsif (encounter_type_name == 'HIV CLINIC CONSULTATION')
          if patient['voided'].to_i == 0
            Connection.execute <<EOF
UPDATE flat_table2
SET  patient_pregnant = "#{value}", patient_pregnant_enc_id = '#{patient['encounter_id']}', patient_pregnant_v_date = DATE('#{patient_visit_date}')
WHERE flat_table2.id = #{visit};
EOF
          else
            Connection.execute <<EOF
UPDATE flat_table2
SET  patient_pregnant = NULL, patient_pregnant_enc_id = NULL, patient_pregnant_v_date = NULL
WHERE flat_table2.id = #{visit};
EOF
          end #voided
        end #encounter_type
      end #visit

    when breastfeeding

      yes_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
                LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
            WHERE name = 'Yes' AND voided = 0 AND retired = 0 LIMIT 1")
      yes = yes_record['concept_id']

      no_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
                LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
            WHERE name = 'No' AND voided = 0 AND retired = 0 LIMIT 1")
      no = no_record['concept_id']

      unknown_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
                LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
            WHERE name = 'Unknown' AND voided = 0 AND retired = 0 LIMIT 1")
      unknown = unknown_record['concept_id']

      value_coded_name_id = patient['value_coded_name_id']
      value_record = Connection.select_one("SELECT * FROM concept_name WHERE concept_name_id = #{value_coded_name_id}")
      value = value_record['name']

      encounter_type_record = Connection.select_one("SELECT * FROM encounter e WHERE e.encounter_id = #{patient['encounter_id']} AND voided = #{patient['voided']}")
      encounter_type = encounter_type_record['encounter_type'].to_i

      if flat_table1_record.blank?
        if (encounter_type_name == 'HIV STAGING')
          Connection.execute <<EOF
INSERT INTO flat_table1
(patient_id, patient_breastfeeding, patient_breastfeeding_enc_id, patient_breastfeeding_v_date)
VALUES (#{patient['person_id']}, "#{value}", #{patient['encounter_id']}, DATE('#{patient_visit_date}');
EOF
        elsif (encounter_type_name == 'HIV CLINIC CONSULTATION')
          Connection.execute <<EOF
INSERT INTO flat_table2
(patient_id, visit_date, patient_breastfeeding, patient_breastfeeding_enc_id, patient_breastfeeding_v_date)
VALUES (#{patient['person_id']}, DATE('#{patient_visit_date}'), "#{value}", #{patient['encounter_id']}, #DATE('#{patient_visit_date}');
EOF
        end #encounter_type
      else
        if (encounter_type_name == 'HIV STAGING')
          if patient['voided'].to_i == 0
            Connection.execute <<EOF
UPDATE flat_table1
SET  patient_breastfeeding = "#{value}", patient_breastfeeding_enc_id = #{patient['encounter_id']},
  patient_breastfeeding_v_date = DATE('#{patient_visit_date}')
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
          else
            Connection.execute <<EOF
UPDATE flat_table1
SET  patient_breastfeeding = NULL, patient_breastfeeding_enc_id = NULL,
  patient_breastfeeding_v_date = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
          end #voided
        elsif (encounter_type_name == 'HIV CLINIC CONSULTATION')
          if patient['voided'].to_i == 0
            Connection.execute <<EOF
UPDATE flat_table2
SET  patient_breastfeeding = "#{value}", patient_breastfeeding_enc_id = '#{patient['encounter_id']}', patient_breastfeeding_v_date = DATE('#{patient_visit_date}')
WHERE flat_table2.id = #{visit};
EOF
          else
            Connection.execute <<EOF
UPDATE flat_table2
SET  patient_breastfeeding = NULL, patient_breastfeeding_enc_id = NULL, patient_breastfeeding_v_date =NULL
WHERE flat_table2.id = #{visit};
EOF
          end #voided
        end #encounter_type
      end #visit
    when breast_feeding

      yes_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
                LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
            WHERE name = 'Yes' AND voided = 0 AND retired = 0 LIMIT 1")
      yes = yes_record['concept_id']

      no_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
                LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
            WHERE name = 'No' AND voided = 0 AND retired = 0 LIMIT 1")
      no = no_record['concept_id']

      unknown_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
                LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
            WHERE name = 'Unknown' AND voided = 0 AND retired = 0 LIMIT 1")
      unknown = unknown_record['concept_id']

      value_coded_name_id = patient['value_coded_name_id']
      value_record = Connection.select_one("SELECT * FROM concept_name WHERE concept_name_id = #{value_coded_name_id}")
      value = value_record['name']

      encounter_type_record = Connection.select_one("SELECT * FROM encounter e WHERE e.encounter_id = #{patient['encounter_id']} AND voided = #{patient['voided']}")
      encounter_type = encounter_type_record['encounter_type'].to_i

      if flat_table1_record.blank?
        if (encounter_type_name == 'HIV STAGING')
          Connection.execute <<EOF
INSERT INTO flat_table1 (patient_id, patient_breastfeeding, patient_breastfeeding_enc_id, patient_breastfeeding_v_date)
VALUES (#{patient['person_id']}, "#{value}", #{patient['encounter_id']}, DATE('#{patient_visit_date}');
EOF
        elsif (encounter_type_name == 'HIV CLINIC CONSULTATION')
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, patient_breastfeeding, patient_breastfeeding_enc_id, patient_breastfeeding_v_date)
VALUES (#{patient['person_id']}, DATE('#{patient_visit_date}'), "#{value}", #{patient['encounter_id']}, #DATE('#{patient_visit_date}');
EOF
        end #encounter_type
      else
        if (encounter_type_name == 'HIV STAGING')
          if patient['voided'].to_i == 0
            Connection.execute <<EOF
UPDATE flat_table1
SET  patient_breastfeeding = "#{value}", patient_breastfeeding_enc_id = #{patient['encounter_id']},
  patient_breastfeeding_v_date = DATE('#{patient_visit_date}')
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
          else
            Connection.execute <<EOF
UPDATE flat_table1
SET  patient_breastfeeding = NULL, patient_breastfeeding_enc_id = NULL,
  patient_breastfeeding_v_date = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
          end #voided
        elsif (encounter_type_name == 'HIV CLINIC CONSULTATION')
          if patient['voided'].to_i == 0
            Connection.execute <<EOF
UPDATE flat_table2
SET  patient_breastfeeding = "#{value}", patient_breastfeeding_enc_id = '#{patient['encounter_id']}', patient_breastfeeding_v_date = DATE('#{patient_visit_date}')
WHERE flat_table2.id = #{visit};
EOF
          else
            Connection.execute <<EOF
UPDATE flat_table2
SET  patient_breastfeeding = NULL, patient_breastfeeding_enc_id = NULL, patient_breastfeeding_v_date = NULL
WHERE flat_table2.id = #{visit};
EOF
          end #voided
        end #encounter_type
      end #visit

    when breast_feeding2

      yes_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
                LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
            WHERE name = 'Yes' AND voided = 0 AND retired = 0 LIMIT 1")
      yes = yes_record['concept_id']

      no_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
                LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
            WHERE name = 'No' AND voided = 0 AND retired = 0 LIMIT 1")
      no = no_record['concept_id']

      unknown_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
                LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
            WHERE name = 'Unknown' AND voided = 0 AND retired = 0 LIMIT 1")
      unknown = unknown_record['concept_id']

      value_coded_name_id = patient['value_coded_name_id']
      value_record = Connection.select_one("SELECT * FROM concept_name WHERE concept_name_id = #{value_coded_name_id}")
      value = value_record['name']

      encounter_type_record = Connection.select_one("SELECT * FROM encounter e WHERE e.encounter_id = #{patient['encounter_id']} AND voided = #{patient['voided']}")
      encounter_type = encounter_type_record['encounter_type'].to_i

      if flat_table1_record.blank?
        if (encounter_type_name == 'HIV STAGING')
          Connection.execute <<EOF
INSERT INTO flat_table1 (patient_id, patient_breastfeeding, patient_breastfeeding_enc_id, patient_breastfeeding_v_date)
VALUES (#{patient['person_id']}, "#{value}", #{patient['encounter_id']}, DATE('#{patient_visit_date}');
EOF
        elsif (encounter_type_name == 'HIV CLINIC CONSULTATION')
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, patient_breastfeeding, patient_breastfeeding_enc_id, patient_breastfeeding_v_date)
VALUES (#{patient['person_id']}, DATE('#{patient_visit_date}'), "#{value}", #{patient['encounter_id']}, #DATE('#{patient_visit_date}');
EOF
        end #encounter_type
      else
        if (encounter_type_name == 'HIV STAGING')
          if patient['voided'].to_i == 0
            Connection.execute <<EOF
UPDATE flat_table1
SET  patient_breastfeeding = "#{value}", patient_breastfeeding_enc_id = #{patient['encounter_id']},
  patient_breastfeeding_v_date = DATE('#{patient_visit_date}')
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
          else
            Connection.execute <<EOF
UPDATE flat_table1
SET  patient_breastfeeding = NULL, patient_breastfeeding_enc_id = NULL,
  patient_breastfeeding_v_date = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
          end #voided
        elsif (encounter_type_name == 'HIV CLINIC CONSULTATION')
          if patient['voided'].to_i == 0
            Connection.execute <<EOF
UPDATE flat_table2
SET  patient_breastfeeding = "#{value}", patient_breastfeeding_enc_id = '#{patient['encounter_id']}', patient_breastfeeding_v_date = DATE('#{patient_visit_date}')
WHERE flat_table2.id = #{visit};
EOF
          else
            Connection.execute <<EOF
UPDATE flat_table2
SET  patient_breastfeeding = NULL, patient_breastfeeding_enc_id = NULL, patient_breastfeeding_v_date = NULL
WHERE flat_table2.id = #{visit};
EOF
          end #voided
        end #encounter_type
      end #visit

    when pregnant_at_initiation
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded'].to_i
        answer_record = Connection.select_one("SELECT name FROM location WHERE location_id = '#{value_coded}' ")

		answer_value = Connection.select_one("SELECT concept_name.name FROM concept_name
				LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
			WHERE concept_name.concept_id = #{value_coded} AND voided = 0 AND retired = 0 LIMIT 1")

        answer = answer_value['name'] rescue nil

        if answer.blank?
          puts ".......... Updating record into flat_table1 (pregnant_at_initiation = Unknown): #{patient['person_id']}"
          Connection.execute <<EOF
UPDATE flat_table1
 SET  pregnant_at_initiation = "Unknown", pregnant_at_initiation_enc_id = '#{patient['encounter_id']}', pregnant_at_initiation_v_date  = DATE('#{patient_visit_date}')
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
        else
          puts ".......... Updating record into flat_table1 (pregnant_at_initiation = #{answer}): #{patient['person_id']}"
          Connection.execute <<EOF
UPDATE flat_table1
 SET  pregnant_at_initiation = "#{answer}", pregnant_at_initiation_enc_id = '#{patient['encounter_id']}', pregnant_at_initiation_v_date  = DATE('#{patient_visit_date}')
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
        end #answer

      else
        puts ".......... Updating record into flat_table1 (pregnant_at_initiation = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  pregnant_at_initiation = NULL, pregnant_at_initiation_enc_id = NULL, pregnant_at_initiation_v_date = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when cd4_count_loc
      if patient['voided'].to_i == 0
        value_text = patient['value_text']
        answer_record = Connection.select_one("SELECT name FROM location WHERE location_id = '#{value_text}' ")
        answer = answer_record['name'] rescue nil

        if answer.blank?
          puts ".......... Updating record into flat_table1 (cd4_count_location = Unknown): #{patient['person_id']}"
          Connection.execute <<EOF
UPDATE flat_table1
 SET  cd4_count_location = "Unknown", cd4_count_location_enc_id = '#{patient['encounter_id']}', cd4_count_location_v_date  = DATE('#{patient_visit_date}')
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
        else
          puts ".......... Updating record into flat_table1 (cd4_count_location = #{answer}): #{patient['person_id']}"
          Connection.execute <<EOF
UPDATE flat_table1
 SET  cd4_count_location = "#{answer}", cd4_count_location_enc_id = '#{patient['encounter_id']}', cd4_count_location_v_date  = DATE('#{patient_visit_date}')
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
        end #answer

      else
        puts ".......... Updating record into flat_table1 (cd4_count_location = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  cd4_count_location = NULL, cd4_count_location_enc_id = NULL, cd4_count_location_v_date = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when cd4_count
      if patient['voided'].to_i == 0
        value_numeric = patient['value_numeric']
        value_modifier = patient['value_modifier']
        puts "........... Updating record into flat_table1 (cd4_count = #{value_numeric}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  cd4_count = "#{value_numeric}", cd4_count_enc_id = '#{patient['encounter_id']}', cd4_count_v_date = DATE('#{patient_visit_date}')
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
        puts "........... Updating record into flat_table1 (cd4_count_modifier = #{value_modifier}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  cd4_count_modifier = "#{value_modifier}", cd4_count_modifier_enc_id = '#{patient['encounter_id']}', cd4_count_modifier_v_date = DATE('#{patient_visit_date}')
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts "........... Updating record into flat_table1 (cd4_count = NULL): #{patient['person_id']}}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  cd4_count = NULL, cd4_count_enc_id = NULL, cd4_count_v_date =  NULL
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
        puts "........... Updating record into flat_table1 (cd4_count_modifier = NULL): #{patient['person_id']}}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  cd4_count_modifier = NULL, cd4_count_modifier_enc_id = NULL, cd4_count_modifier_v_date =  NULL
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF

      end #voided
    when cd4_count_percent
      value_numeric = patient['value_numeric']
      puts ".......... Updating record into flat_table1 (cd4_count_percent = #{value_numeric}): #{patient['person_id']}"
      Connection.execute <<EOF
UPDATE flat_table1
 SET  cd4_count_percent = "#{value_numeric}",  cd4_count_percent_enc_id = '#{patient['encounter_id']}', cd4_count_percent_v_date = DATE('#{patient_visit_date}')
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF

    when cd4_count_date
      if patient['voided'].to_i == 0
        value_datetime = patient['value_datetime']
        puts ".......... Updating record into flat_table1 (cd4_count_datetime = #{value_datetime}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  cd4_count_datetime = '#{value_datetime}',  cd4_count_datetime_enc_id = '#{patient['encounter_id']}', cd4_count_datetime_v_date = DATE('#{patient_visit_date}')
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (cd4_count_datetime = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  cd4_count_datetime = NULL, cd4_count_datetime_enc_id = NULL, cd4_count_datetime_v_date = NULL
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when cd4_percent_less_than_25
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']

        puts ".......... Updating record into flat_table1 (cd4_percent_less_than_25 = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  cd4_percent_less_than_25 = "#{answer}", cd4_percent_less_than_25_enc_id = '#{patient['encounter_id']}', cd4_percent_less_than_25_v_date = DATE('#{patient_visit_date}')
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (cd4_percent_less_than_25 = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  cd4_percent_less_than_25 = NULL, cd4_percent_less_than_25_enc_id = NULL, cd4_percent_less_than_25_v_date = NULL
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when cd4_percent_loc
      if patient['voided'].to_i == 0
        value_text = patient['value_text']
        puts ".......... Updating record into flat_table1 (cd4_count_location = #{value_text}): patient_id: #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
  SET cd4_count_location = "#{value_text}", cd4_count_location_enc_id = '#{patient['encounter_id']}', cd4_count_location_v_date = DATE('#{patient_visit_date}')
  WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (cd4_count_location = NULL): patient_id: #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
  SET cd4_count_location = NULL, cd4_count_location_enc_id  = NULL, cd4_count_location_v_date = NULL
  WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when cd4_count_less_than_250
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']

        puts ".......... Updating record into flat_table1 (cd4_count_less_than_250 = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  cd4_count_less_than_250 = "#{answer}", cd4_count_less_than_250_enc_id = '#{patient['encounter_id']}', cd4_count_less_than_250_v_date = DATE('#{patient_visit_date}')
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (cd4_count_less_than_250 = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  cd4_count_less_than_250 = NULL, cd4_count_less_than_250_enc_id = NULL, cd4_count_less_than_250_v_date = NULL
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when cd4_count_less_than_350
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (cd4_count_less_than_350 = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  cd4_count_less_than_350 = "#{answer}", cd4_count_less_than_350_enc_id = '#{patient['encounter_id']}', cd4_count_less_than_350_v_date = DATE('#{patient_visit_date}')
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (cd4_count_less_than_350 = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  cd4_count_less_than_350 = NULL, cd4_count_less_than_350_enc_id = NULL, cd4_count_less_than_350_v_date = NULL
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when lymphocyte_count_date
      if patient['voided'].to_i == 0
        value_datetime = patient['value_datetime']
        puts ".......... Updating record into flat_table1 (lymphocyte_count_date = #{value_datetime}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  lymphocyte_count_date = '#{value_datetime}', lymphocyte_count_date_enc_id = '#{patient['encounter_id']}', lymphocyte_count_date_v_date = DATE('#{patient_visit_date}')
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (lymphocyte_count_date = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  lymphocyte_count_date = NULL, lymphocyte_count_date_enc_id = NULL, lymphocyte_count_date_v_date = NULL
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when lymphocyte_count
      if patient['voided'].to_i == 0
        value_numeric = patient['value_numeric']
        puts ".......... Updating record into flat_table1 (lymphocyte_count = #{value_numeric}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  lymphocyte_count = "#{value_numeric}", lymphocyte_count_enc_id = '#{patient['encounter_id']}', lymphocyte_count_v_date = DATE('#{patient_visit_date}')
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (lymphocyte_count = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  lymphocyte_count = NULL, lymphocyte_count_enc_id = NULL, lymphocyte_count_v_date = NULL
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when asymptomatic
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (asymptomatic = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  asymptomatic = "#{answer}", asymptomatic_enc_id = '#{patient['encounter_id']}', asymptomatic_v_date = DATE('#{patient_visit_date}')
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (asymptomatic = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  asymptomatic = NULL, asymptomatic_enc_id = NULL, asymptomatic_v_date = NULL
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when pers_gnrl_lymphadenopathy
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (persistent_generalized_lymphadenopathy = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  persistent_generalized_lymphadenopathy= "#{answer}", persistent_generalized_lymphadenopathy_enc_id = '#{patient['encounter_id']}',
     persistent_generalized_lymphadenopathy_v_date = DATE('#{patient_visit_date}')
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (persistent_generalized_lymphadenopathy = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  persistent_generalized_lymphadenopathy = NULL, persistent_generalized_lymphadenopathy_enc_id = NULL,
persistent_generalized_lymphadenopathy_v_date = NULL
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when unspecified_stage_1_cond
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (unspecified_stage_1_cond = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  unspecified_stage_1_cond = "#{answer}", unspecified_stage_1_cond_enc_id = '#{patient['encounter_id']}',
     unspecified_stage_1_cond_v_date = DATE('#{patient_visit_date}')
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (unspecified_stage_1_cond): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  unspecified_stage_1_cond = NULL, unspecified_stage_1_cond_enc_id = NULL, unspecified_stage_1_cond_v_date = NULL
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when molluscumm_contagiosum
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (molluscumm_contagiosum = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  molluscumm_contagiosum = "#{answer}", molluscumm_contagiosum_enc_id = '#{patient['encounter_id']}',
     molluscumm_contagiosum_v_date = DATE('#{patient_visit_date}')
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (molluscumm_contagiosum = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  molluscumm_contagiosum = NULL, molluscumm_contagiosum_enc_id = NULL,
molluscumm_contagiosum_v_date = NULL
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when wart_virus_infection_extensive
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (wart_virus_infection_extensive = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  wart_virus_infection_extensive = "#{answer}", wart_virus_infection_extensive_enc_id = '#{patient['encounter_id']}',
     wart_virus_infection_extensive_v_date = DATE('#{patient_visit_date}')
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (wart_virus_infection_extensive = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  wart_virus_infection_extensive = NULL, wart_virus_infection_extensive_enc_id = NULL,
wart_virus_infection_extensive_v_date = NULL
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when oral_ulcerations_recurrent
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (oral_ulcerations_recurrent = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  oral_ulcerations_recurrent = "#{answer}", oral_ulcerations_recurrent_enc_id = '#{patient['encounter_id']}',
     oral_ulcerations_recurrent_v_date = DATE('#{patient_visit_date}')
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (oral_ulcerations_recurrent = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  oral_ulcerations_recurrent = NULL, oral_ulcerations_recurrent_enc_id = NULL,
oral_ulcerations_recurrent_v_date = NULL
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when parotid_enlargement_pers_unexp
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (parotid_enlargement_persistent_unexplained = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  parotid_enlargement_persistent_unexplained = "#{answer}", parotid_enlargement_persistent_unexplained_enc_id = '#{patient['encounter_id']}',
     parotid_enlargement_persistent_unexplained_v_date = DATE('#{patient_visit_date}')
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (parotid_enlargement_persistent_unexplained = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  parotid_enlargement_persistent_unexplained = NULL, parotid_enlargement_persistent_unexplained_enc_id = NULL,
parotid_enlargement_persistent_unexplained_v_date = NULL
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when lineal_gingival_erythema
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']

        puts ".......... Updating record into flat_table1 (lineal_gingival_erythema = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  lineal_gingival_erythema = "#{answer}", lineal_gingival_erythema_enc_id = '#{patient['encounter_id']}',
     lineal_gingival_erythema_v_date = DATE('#{patient_visit_date}')
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (lineal_gingival_erythema = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  lineal_gingival_erythema = NULL, lineal_gingival_erythema_enc_id = NULL,
lineal_gingival_erythema_v_date = NULL
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when herpes_zoster
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
                puts ".......... Updating record into flat_table1 (herpes_zoster = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  herpes_zoster = "#{answer}", herpes_zoster_enc_id = '#{patient['encounter_id']}',
     herpes_zoster_v_date = DATE('#{patient_visit_date}')
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (herpes_zoster): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  herpes_zoster = NULL, herpes_zoster_enc_id = NULL,
herpes_zoster_v_date = NULL
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when resp_tract_infections_rec
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (respiratory_tract_infections_recurrent = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  respiratory_tract_infections_recurrent = "#{answer}", respiratory_tract_infections_recurrent_enc_id = '#{patient['encounter_id']}',
     respiratory_tract_infections_recurrent_v_date = DATE('#{patient_visit_date}')
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (respiratory_tract_infections_recurrent = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  respiratory_tract_infections_recurrent = NULL, respiratory_tract_infections_recurrent_enc_id = NULL,
respiratory_tract_infections_recurrent_v_date = NULL
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when unspecified_stage2_condition
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (unspecified_stage2_condition = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  unspecified_stage2_condition = "#{answer}", unspecified_stage2_condition_enc_id = '#{patient['encounter_id']}',
     unspecified_stage2_condition_v_date = DATE('#{patient_visit_date}')
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (unspecified_stage2_condition = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  unspecified_stage2_condition = NULL, unspecified_stage2_condition_enc_id = NULL,
unspecified_stage2_condition_v_date = NULL
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when angular_chelitis
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (angular_chelitis = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  angular_chelitis = "#{answer}", angular_chelitis_enc_id = '#{patient['encounter_id']}',
     angular_chelitis_v_date = DATE('#{patient_visit_date}')
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (angular_chelitis = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  angular_chelitis = NULL, angular_chelitis_enc_id = NULL,
angular_chelitis_v_date = NULL
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when papular_prurtic_eruptions
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (papular_pruritic_eruptions = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  papular_pruritic_eruptions = "#{answer}", papular_pruritic_eruptions_enc_id = '#{patient['encounter_id']}',
     papular_pruritic_eruptions_v_date = DATE('#{patient_visit_date}')
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (papular_pruritic_eruptions = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  papular_pruritic_eruptions = NULL, papular_pruritic_eruptions_enc_id = NULL,
papular_pruritic_eruptions_v_date = NULL
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when hepatosplenomegaly_unexplained
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']

        puts ".......... Updating record into flat_table1 (hepatosplenomegaly_unexplained = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  hepatosplenomegaly_unexplained = "#{answer}", hepatosplenomegaly_unexplained_enc_id = '#{patient['encounter_id']}',
     hepatosplenomegaly_unexplained_v_date = DATE('#{patient_visit_date}')
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (hepatosplenomegaly_unexplained = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  hepatosplenomegaly_unexplained = NULL, hepatosplenomegaly_unexplained_enc_id = NULL,
hepatosplenomegaly_unexplained_v_date = NULL
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when oral_hairy_leukoplakia
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (oral_hairy_leukoplakia = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  oral_hairy_leukoplakia = "#{answer}", oral_hairy_leukoplakia_enc_id = '#{patient['encounter_id']}',
     oral_hairy_leukoplakia_v_date = DATE('#{patient_visit_date}')
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (oral_hairy_leukoplakia = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  oral_hairy_leukoplakia = NULL, oral_hairy_leukoplakia_enc_id = NULL, oral_hairy_leukoplakia_v_date = NULL
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when severe_weight_loss
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (severe_weight_loss = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  severe_weight_loss = "#{answer}", severe_weight_loss_enc_id = '#{patient['encounter_id']}',
     severe_weight_loss_v_date = DATE('#{patient_visit_date}')
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (severe_weight_loss = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  severe_weight_loss = NULL, severe_weight_loss_enc_id = NULL,
severe_weight_loss_v_date = NULL
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when fever_persistent_unexplained
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (fever_persistent_unexplained = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  fever_persistent_unexplained = "#{answer}", fever_persistent_unexplained_enc_id = '#{patient['encounter_id']}',
     fever_persistent_unexplained_v_date = DATE('#{patient_visit_date}')
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (fever_persistent_unexplained = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  fever_persistent_unexplained = NULL, fever_persistent_unexplained_enc_id = NULL,
fever_persistent_unexplained_v_date = NULL
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when pulmonary_tuberculosis
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (pulmonary_tuberculosis = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  pulmonary_tuberculosis = "#{answer}", pulmonary_tuberculosis_enc_id = '#{patient['encounter_id']}',
     pulmonary_tuberculosis_v_date = DATE('#{patient_visit_date}')
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (pulmonary_tuberculosis = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  pulmonary_tuberculosis = NULL, pulmonary_tuberculosis_enc_id = NULL,
pulmonary_tuberculosis_v_date = NULL
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when pulmonary_tuberculosis_last_2_years
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (pulmonary_tuberculosis_last_2_years = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  pulmonary_tuberculosis_last_2_years = "#{answer}", pulmonary_tuberculosis_last_2_years_enc_id = '#{patient['encounter_id']}', pulmonary_tuberculosis_last_2_years_v_date = DATE('#{patient_visit_date}')
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (pulmonary_tuberculosis_last_2_years = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  pulmonary_tuberculosis_last_2_years = NULL, pulmonary_tuberculosis_last_2_years_enc_id = NULL, pulmonary_tuberculosis_last_2_years_v_date = NULL
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when ptb_last_2_years
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (pulmonary_tuberculosis_last_2_years = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  pulmonary_tuberculosis_last_2_years = "#{answer}", pulmonary_tuberculosis_last_2_years_enc_id = '#{patient['encounter_id']}', pulmonary_tuberculosis_last_2_years_v_date = DATE('#{patient_visit_date}')
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (pulmonary_tuberculosis_last_2_years = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  pulmonary_tuberculosis_last_2_years = NULL, pulmonary_tuberculosis_last_2_years_enc_id = NULL, pulmonary_tuberculosis_last_2_years_v_date = NULL
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when severe_bacterial_infection
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (severe_bacterial_infection = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  severe_bacterial_infection = "#{answer}", severe_bacterial_infection_enc_id = '#{patient['encounter_id']}',
      severe_bacterial_infection_v_date = DATE('#{patient_visit_date}')
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (severe_bacterial_infection = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  severe_bacterial_infection = NULL, severe_bacterial_infection_enc_id = NULL,
severe_bacterial_infection_v_date = NULL
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when bacterial_pnuemonia
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (bacterial_pnuemonia = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  bacterial_pnuemonia = "#{answer}", bacterial_pnuemonia_enc_id = '#{patient['encounter_id']}',
      bacterial_pnuemonia_v_date = DATE('#{patient_visit_date}')
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (bacterial_pnuemonia = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  bacterial_pnuemonia = NULL, bacterial_pnuemonia_enc_id = NULL,
bacterial_pnuemonia_v_date = NULL
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when symptomatic_lymphoid_interstitial_pnuemonitis
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (symptomatic_lymphoid_interstitial_pnuemonitis = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  symptomatic_lymphoid_interstitial_pnuemonitis = "#{answer}", symptomatic_lymphoid_interstitial_pnuemonitis_enc_id = '#{patient['encounter_id']}',
      symptomatic_lymphoid_interstitial_pnuemonitis_v_date = DATE('#{patient_visit_date}')
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (symptomatic_lymphoid_interstitial_pnuemonitis = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  symptomatic_lymphoid_interstitial_pnuemonitis = NULL, symptomatic_lymphoid_interstitial_pnuemonitis_enc_id = NULL,
symptomatic_lymphoid_interstitial_pnuemonitis_v_date = NULL
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when chronic_hiv_assoc_lung_disease
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (chronic_hiv_assoc_lung_disease = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  chronic_hiv_assoc_lung_disease = "#{answer}", chronic_hiv_assoc_lung_disease_enc_id = '#{patient['encounter_id']}',
      chronic_hiv_assoc_lung_disease_v_date = DATE('#{patient_visit_date}')
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (chronic_hiv_assoc_lung_disease = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  chronic_hiv_assoc_lung_disease = NULL, chronic_hiv_assoc_lung_disease_enc_id = NULL,
chronic_hiv_assoc_lung_disease_v_date = NULL
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when unspecified_stage3_condition
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']

        puts ".......... Updating record into flat_table1 (unspecified_stage3_condition = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  unspecified_stage3_condition = "#{answer}", unspecified_stage3_condition_enc_id = '#{patient['encounter_id']}',
      unspecified_stage3_condition_v_date = DATE('#{patient_visit_date}')
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
        else
          puts ".......... Updating record into flat_table1 (unspecified_stage3_condition = NULL): #{patient['person_id']}"
          Connection.execute <<EOF
UPDATE flat_table1
 SET  unspecified_stage3_condition = NULL, unspecified_stage3_condition_enc_id = NULL,
unspecified_stage3_condition_v_date = NULL
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
        end #voided

    when aneamia
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (aneamia = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  aneamia = "#{answer}", aneamia_enc_id = '#{patient['encounter_id']}',
      aneamia_v_date = DATE('#{patient_visit_date}')
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (aneamia = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  aneamia = NULL, aneamia_enc_id = NULL, aneamia_v_date = NULL
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when neutropaenia
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (neutropaenia = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  neutropaenia = "#{answer}", neutropaenia_enc_id = '#{patient['encounter_id']}',
      neutropaenia_v_date = DATE('#{patient_visit_date}')
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (neutropaenia = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  neutropaenia = NULL, neutropaenia_enc_id = NULL
neutropaenia_v_date = NULL
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when thrombocytopaenia_chronic
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (thrombocytopaenia_chronic = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  thrombocytopaenia_chronic = "#{answer}", thrombocytopaenia_chronic_enc_id = '#{patient['encounter_id']}',
      thrombocytopaenia_chronic_v_date = DATE('#{patient_visit_date}')
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (thrombocytopaenia_chronic = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  thrombocytopaenia_chronic = NULL, thrombocytopaenia_chronic_enc_id = NULL,
thrombocytopaenia_chronic_v_date = NULL
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when diarhoea
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (diarhoea = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  diarhoea = "#{answer}", diarhoea_enc_id = '#{patient['encounter_id']}',
      diarhoea_v_date = DATE('#{patient_visit_date}')
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (diarhoea = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  diarhoea = NULL, diarhoea_enc_id = NULL, diarhoea_v_date = NULL
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when oral_candidiasis
      if patient['voided'] == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (oral_candidiasis = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  oral_candidiasis = "#{answer}", oral_candidiasis_enc_id = '#{patient['encounter_id']}',
      oral_candidiasis_v_date = DATE('#{patient_visit_date}')
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (oral_candidiasis = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  oral_candidiasis = NULL, oral_candidiasis_enc_id = NULL, oral_candidiasis_v_date = NULL
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

  when acute_necrotizing_ulcerative_gingivitis
    if patient['voided'].to_i == 0
      value_coded = patient['value_coded']
      answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
      answer = answer_record['name']
      puts ".......... Updating record into flat_table1 (acute_necrotizing_ulcerative_gingivitis = #{answer}): #{patient['person_id']}"
      Connection.execute <<EOF
UPDATE flat_table1
 SET  acute_necrotizing_ulcerative_gingivitis = "#{answer}", acute_necrotizing_ulcerative_gingivitis_enc_id = '#{patient['encounter_id']}',
      acute_necrotizing_ulcerative_gingivitis_v_date = DATE('#{patient_visit_date}')
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
    else
      puts ".......... Updating record into flat_table1 (acute_necrotizing_ulcerative_gingivitis = NULL): #{patient['person_id']}"
      Connection.execute <<EOF
UPDATE flat_table1
 SET  acute_necrotizing_ulcerative_gingivitis = NULL, acute_necrotizing_ulcerative_gingivitis_enc_id = NULL, acute_necrotizing_ulcerative_gingivitis_v_date = NULL
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
    end #voided

  when lymph_node_tuberculosis
    if patient['voided'].to_i == 0
      value_coded = patient['value_coded']
      answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
      answer = answer_record['name']
      puts ".......... Updating record into flat_table1 (lymph_node_tuberculosis = #{answer}): #{patient['person_id']}"
      Connection.execute <<EOF
UPDATE flat_table1
 SET  lymph_node_tuberculosis = "#{answer}", lymph_node_tuberculosis_enc_id = '#{patient['encounter_id']}',
      lymph_node_tuberculosis_v_date = DATE('#{patient_visit_date}')
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
    else
      puts ".......... Updating record into flat_table1 (lymph_node_tuberculosis = NULL): #{patient['person_id']}"
      Connection.execute <<EOF
UPDATE flat_table1
 SET  lymph_node_tuberculosis = NULL, lymph_node_tuberculosis_enc_id = NULL, lymph_node_tuberculosis_v_date = NULL
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
    end #voided

  when toxoplasmosis_of_brain
    if patient['voided'].to_i == 0
      value_coded = patient['value_coded']
      answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
      answer = answer_record['name']
      puts ".......... Updating record into flat_table1 (toxoplasmosis_of_brain = #{answer}): #{patient['person_id']}"
      Connection.execute <<EOF
UPDATE flat_table1
 SET  toxoplasmosis_of_the_brain = "#{answer}", toxoplasmosis_of_the_brain_enc_id = '#{patient['encounter_id']}',
      toxoplasmosis_of_the_brain_v_date = DATE('#{patient_visit_date}')
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
    else
      puts ".......... Updating record into flat_table1 (toxoplasmosis_of_brain = NULL): #{patient['person_id']}"
      Connection.execute <<EOF
UPDATE flat_table1
 SET  toxoplasmosis_of_the_brain = NULL, toxoplasmosis_of_the_brain_enc_id = NULL,
toxoplasmosis_of_the_brain_v_date = NULL
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
    end #voided

  when cryptococcal_meningitis
    if patient['voided'].to_i == 0
      value_coded = patient['value_coded']
      answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
      answer = answer_record['name']
      puts ".......... Updating record into flat_table1 (cryptococcal_meningitis = #{answer}): #{patient['person_id']}"
      Connection.execute <<EOF
UPDATE flat_table1
 SET  cryptococcal_meningitis = "#{answer}", cryptococcal_meningitis_enc_id = '#{patient['encounter_id']}',
      cryptococcal_meningitis_v_date = DATE('#{patient_visit_date}')
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
    else
      puts ".......... Updating record into flat_table1 (cryptococcal_meningitis = NULL): #{patient['person_id']}"
      Connection.execute <<EOF
UPDATE flat_table1
 SET  cryptococcal_meningitis = NULL, cryptococcal_meningitis_enc_id = NULL, cryptococcal_meningitis_v_date =  NULL
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
    end #voided

  when progressive_multifocal_leukoencephalopathy
    if patient['voided'].to_i == 0
      value_coded = patient['value_coded']
      answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
      answer = answer_record['name']
      puts ".......... Updating record into flat_table1 (progressive_multifocal_leukoencephalopathy = #{answer}): #{patient['person_id']}"
      Connection.execute <<EOF
UPDATE flat_table1
 SET  progressive_multifocal_leukoencephalopathy = "#{answer}", progressive_multifocal_leukoencephalopathy_enc_id = '#{patient['encounter_id']}',
      progressive_multifocal_leukoencephalopathy_v_date = DATE('#{patient_visit_date}')
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
    else
      puts ".......... Updating record into flat_table1 (progressive_multifocal_leukoencephalopathy = NULL): #{patient['person_id']}"
      Connection.execute <<EOF
UPDATE flat_table1
 SET  progressive_multifocal_leukoencephalopathy = NULL, progressive_multifocal_leukoencephalopathy_enc_id = NULL,
progressive_multifocal_leukoencephalopathy_v_date = NULL
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
    end #voided

  when disseminated_mycosis
    if patient['voided'].to_i == 0
      value_coded = patient['value_coded']
      answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
      answer = answer_record['name']
      puts ".......... Updating record into flat_table1 (disseminated_mycosis = #{answer}): #{patient['person_id']}"
      Connection.execute <<EOF
UPDATE flat_table1
 SET  disseminated_mycosis = "#{answer}", disseminated_mycosis_enc_id = '#{patient['encounter_id']}',
      disseminated_mycosis_v_date = DATE('#{patient_visit_date}')
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
    else
      puts ".......... Updating record into flat_table1 (disseminated_mycosis = NULL): #{patient['person_id']}"
      Connection.execute <<EOF
UPDATE flat_table1
 SET  disseminated_mycosis = NULL, disseminated_mycosis_enc_id = NULL,
disseminated_mycosis_v_date = NULL
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
    end #voided

  when candidiasis_of_oesophagus
    if patient['voided'].to_i == 0
      value_coded = patient['value_coded']
      answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
      answer = answer_record['name']
      puts ".......... Updating record into flat_table1 (candidiasis_of_oesophagus = #{answer}): #{patient['person_id']}"
      Connection.execute <<EOF
UPDATE flat_table1
 SET  candidiasis_of_oesophagus = "#{answer}", candidiasis_of_oesophagus_enc_id = '#{patient['encounter_id']}', candidiasis_of_oesophagus_v_date = '#{start_date}',
    candidiasis_of_oesophagus_enc_id = #{patient['encounter_id']}
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
    else
      puts ".......... Updating record into flat_table1 (candidiasis_of_oesophagus = NULL): #{patient['person_id']}"
      Connection.execute <<EOF
UPDATE flat_table1
 SET  candidiasis_of_oesophagus = NULL, candidiasis_of_oesophagus_enc_id = NULL, candidiasis_of_oesophagus_v_date = NULL, candidiasis_of_oesophagus_enc_id = NULL
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
    end #voided

  when extrapulmonary_tuberculosis
    if patient['voided'].inspect == 0
      value_coded = patient['value_coded']
      answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
      answer = answer_record['name']
      puts ".......... Updating record into flat_table1 (extrapulmonary_tuberculosis = #{answer}): #{patient['person_id']}"
      Connection.execute <<EOF
UPDATE flat_table1
 SET  extrapulmonary_tuberculosis = "#{answer}", extrapulmonary_tuberculosis_enc_id = '#{patient['encounter_id']}',
      extrapulmonary_tuberculosis_v_date = DATE('#{patient_visit_date}')
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
    else
      puts ".......... Updating record into flat_table1 (extrapulmonary_tuberculosis = NULL): #{patient['person_id']}"
      Connection.execute <<EOF
UPDATE flat_table1
 SET  extrapulmonary_tuberculosis = NULL, extrapulmonary_tuberculosis_enc_id= NULL, extrapulmonary_tuberculosis_v_date = NULL
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
    end #voided

    when cerebral_non_hodgkin_lymphoma
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (cerebral_non_hodgkin_lymphoma = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  cerebral_non_hodgkin_lymphoma = "#{answer}", cerebral_non_hodgkin_lymphoma_enc_id = '#{patient['encounter_id']}',
      cerebral_non_hodgkin_lymphoma_v_date = DATE('#{patient_visit_date}')
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (cerebral_non_hodgkin_lymphoma = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1 SET  cerebral_non_hodgkin_lymphoma = NULL, cerebral_non_hodgkin_lymphoma_enc_id = NULL, cerebral_non_hodgkin_lymphoma_v_date = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when hiv_encephalopathy
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (hiv_encephalopathy = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  hiv_encephalopathy = "#{answer}", hiv_encephalopathy_enc_id = '#{patient['encounter_id']}',
      hiv_encephalopathy_v_date = DATE('#{patient_visit_date}')
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (hiv_encephalopathy = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  hiv_encephalopathy = NULL, hiv_encephalopathy_enc_id = NULL,
hiv_encephalopathy_v_date = NULL
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when bacterial_infections_severe_recurrent
      if patient['voided'].to_i == 0
        value_coded = patient['coded_value']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (bacterial_infections_severe_recurrent = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  bacterial_infections_severe_recurrent = "#{answer}", bacterial_infections_severe_recurrent_enc_id = '#{patient['encounter_id']}',
      bacterial_infections_severe_recurrent_v_date = DATE('#{patient_visit_date}')
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (bacterial_infections_severe_recurrent = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  bacterial_infections_severe_recurrent = NULL, bacterial_infections_severe_recurrent_enc_id = NULL,
bacterial_infections_severe_recurrent_v_date = NULL
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when unspecified_stage_4_condition
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (unspecified_stage_4_condition = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  unspecified_stage_4_condition = "#{answer}", unspecified_stage_4_condition_enc_id = '#{patient['encounter_id']}',
      unspecified_stage_4_condition_v_date = DATE('#{patient_visit_date}')
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (unspecified_stage_4_condition = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  unspecified_stage_4_condition = NULL, unspecified_stage_4_condition_enc_id = NULL, unspecified_stage_4_condition_v_date = NULL
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when pnuemocystis_pnuemonia
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                  WHERE  concept.concept_id = #{value_coded} AND voided = 0 AND retired = 0")
        answer = answer_record['name']

        Connection.execute <<EOF
UPDATE flat_table1
  SET pnuemocystis_pnuemonia = "#{answer}", pnuemocystis_pnuemonia_enc_id = '#{patient['encounter_id']}',
       pnuemocystis_pnuemonia_v_date = DATE('#{patient_visit_date}')
  WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        Connection.execute <<EOF
UPDATE flat_table1
  SET pnuemocystis_pnuemonia = NULL, pnuemocystis_pnuemonia_enc_id = NULL,
pnuemocystis_pnuemonia_v_date = NULL
  WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when disseminated_non_tuberculosis_mycobactierial_infection
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (disseminated_non_tuberculosis_mycobactierial_infection = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  disseminated_non_tuberculosis_mycobacterial_infection = "#{answer}", disseminated_non_tuberculosis_mycobacterial_infection_enc_id = '#{patient['encounter_id']}',
      disseminated_non_tuberculosis_mycobacterial_infection_v_date = DATE('#{patient_visit_date}')
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (disseminated_non_tuberculosis_mycobactierial_infection = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  disseminated_non_tuberculosis_mycobacterial_infection = NULL, disseminated_non_tuberculosis_mycobacterial_infection_enc_id = NULL,
disseminated_non_tuberculosis_mycobacterial_infection_v_date= NULL
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when cryptosporidiosis
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (cryptosporidiosis = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  cryptosporidiosis = "#{answer}", cryptosporidiosis_enc_id = '#{patient['encounter_id']}',
      cryptosporidiosis_v_date = DATE('#{patient_visit_date}')
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (cryptosporidiosis = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  cryptosporidiosis = NULL, cryptosporidiosis_enc_id = NULL,
cryptosporidiosis_v_date = NULL
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when isosporiasis
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (isosporiasis = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  isosporiasis = "#{answer}", isosporiasis_enc_id = '#{patient['encounter_id']}',
      isosporiasis_enc_id = DATE('#{patient_visit_date}')
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (isosporiasis = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
 SET  isosporiasis = NULL, isosporiasis_enc_id = NULL,
isosporiasis_enc_id = NULL
 WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when symptomatic_hiv_asscoiated_nephropathy
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (symptomatic_hiv_associated_nephropathy = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET symptomatic_hiv_associated_nephropathy = "#{answer}", symptomatic_hiv_associated_nephropathy_enc_id = '#{patient['encounter_id']}',
     symptomatic_hiv_associated_nephropathy_v_date = DATE('#{patient_visit_date}')
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (symptomatic_hiv_asscoiated_nephropathy = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET symptomatic_hiv_associated_nephropathy = NULL, symptomatic_hiv_associated_nephropathy_enc_id = NULL,
symptomatic_hiv_associated_nephropathy_v_date = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when chronic_herpes_simplex_infection
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (chronic_herpes_simplex_infection = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET chronic_herpes_simplex_infection = "#{answer}", chronic_herpes_simplex_infection_enc_id = '#{patient['encounter_id']}',
     chronic_herpes_simplex_infection_v_date = DATE('#{patient_visit_date}')
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (chronic_herpes_simplex_infection = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET chronic_herpes_simplex_infection = NULL, chronic_herpes_simplex_infection_enc_id =
chronic_herpes_simplex_infection_v_date = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when cytomegalovirus_infection
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (cytomegalovirus_infection = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET cytomegalovirus_infection = "#{answer}", cytomegalovirus_infection_enc_id = '#{patient['encounter_id']}',
     cytomegalovirus_infection_v_date = DATE('#{patient_visit_date}')
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (cytomegalovirus_infection = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET cytomegalovirus_infection = NULL, cytomegalovirus_infection_enc_id = NULL,
cytomegalovirus_infection_v_date = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when toxoplasomis_of_the_brain_1month
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (toxoplasomis_of_the_brain_1month = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET toxoplasomis_of_the_brain_1month = "#{answer}", toxoplasomis_of_the_brain_1month_enc_id = '#{patient['encounter_id']}',
     toxoplasomis_of_the_brain_1month_v_date = DATE('#{patient_visit_date}')
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (toxoplasomis_of_the_brain_1month = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET toxoplasomis_of_the_brain_1month = NULL, toxoplasomis_of_the_brain_1month_enc_id = NULL,
toxoplasomis_of_the_brain_1month_v_date = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when recto_vaginal_fitsula
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (recto_vaginal_fitsula = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET recto_vaginal_fitsula = "#{answer}", recto_vaginal_fitsula_enc_id = '#{patient['encounter_id']}',
     recto_vaginal_fitsula_v_date = DATE('#{patient_visit_date}')
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (recto_vaginal_fitsula = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET recto_vaginal_fitsula = NULL, recto_vaginal_fitsula_enc_id = NULL,
recto_vaginal_fitsula_v_date = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when mod_wght_loss_less_thanequal_to_10_perc
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (moderate_weight_loss_less_than_or_equal_to_10_percent_unexpl = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET moderate_weight_loss_less_than_or_equal_to_10_percent_unexpl = "#{answer}", moderate_weight_loss_less_than_or_equal_to_10_unexpl_enc_id = '#{patient['encounter_id']}',
     moderate_weight_loss_less_than_or_equal_to_10_unexpl_v_date = DATE('#{patient_visit_date}')
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (moderate_weight_loss_less_than_or_equal_to_10_percent_unexpl = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET moderate_weight_loss_less_than_or_equal_to_10_percent_unexpl = NULL, moderate_weight_loss_less_than_or_equal_to_10_unexpl_enc_id = NULL,
moderate_weight_loss_less_than_or_equal_to_10_unexpl_v_date = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when seborrhoeic_dermatitis
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (seborrhoeic_dermatitis = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET seborrhoeic_dermatitis = "#{answer}", seborrhoeic_dermatitis_enc_id = '#{patient['encounter_id']}',
     seborrhoeic_dermatitis_v_date = DATE('#{patient_visit_date}')
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (seborrhoeic_dermatitis = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET seborrhoeic_dermatitis = NULL, seborrhoeic_dermatitis_enc_id = NULL,
seborrhoeic_dermatitis_v_date = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when hepatitis_b_or_c_infection
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (hepatitis_b_or_c_infection = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET hepatitis_b_or_c_infection = "#{answer}", hepatitis_b_or_c_infection_enc_id = '#{patient['encounter_id']}',
     hepatitis_b_or_c_infection_v_date = DATE('#{patient_visit_date}')
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (hepatitis_b_or_c_infection = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET hepatitis_b_or_c_infection = NULL, hepatitis_b_or_c_infection_enc_id = NULL,
hepatitis_b_or_c_infection_v_date = NUL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when kaposis_sarcoma
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (kaposis_sarcoma = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET kaposis_sarcoma = "#{answer}", kaposis_sarcoma_enc_id = '#{patient['encounter_id']}', kaposis_sarcoma_v_date = DATE('#{patient_visit_date}')
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (kaposis_sarcoma = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET kaposis_sarcoma = NULL, kaposis_sarcoma_enc_id = NULL, kaposis_sarcoma_v_date = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when non_typhoidal_salmonella_bacteraemia_recurrent
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (non_typhoidal_salmonella_bacteraemia_recurrent = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET non_typhoidal_salmonella_bacteraemia_recurrent = "#{answer}", non_typhoidal_salmonella_bacteraemia_recurrent_enc_id = '#{patient['encounter_id']}',
    non_typhoidal_salmonella_bacteraemia_recurrent_v_date = DATE('#{patient_visit_date}')
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (non_typhoidal_salmonella_bacteraemia_recurrent = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET non_typhoidal_salmonella_bacteraemia_recurrent = NULL, non_typhoidal_salmonella_bacteraemia_recurrent_enc_id = NULL,
non_typhoidal_salmonella_bacteraemia_recurrent_v_date = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when leishmaniasis_atypical_disseminated
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (leishmaniasis_atypical_disseminated = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET leishmaniasis_atypical_disseminated = "#{answer}", leishmaniasis_atypical_disseminated_enc_id = '#{patient['encounter_id']}',
    leishmaniasis_atypical_disseminated_v_date = DATE('#{patient_visit_date}')
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (leishmaniasis_atypical_disseminated = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET leishmaniasis_atypical_disseminated = NULL, leishmaniasis_atypical_disseminated_enc_id = NULL,
leishmaniasis_atypical_disseminated_v_date = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when cerebral_or_b_cell_non_hodgkin_lymphoma
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (cerebral_or_b_cell_non_hodgkin_lymphoma = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET cerebral_or_b_cell_non_hodgkin_lymphoma = "#{answer}", cerebral_or_b_cell_non_hodgkin_lymphoma_enc_id = '#{patient['encounter_id']}',
    cerebral_or_b_cell_non_hodgkin_lymphoma_v_date = DATE('#{patient_visit_date}')
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (cerebral_or_b_cell_non_hodgkin_lymphoma = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET cerebral_or_b_cell_non_hodgkin_lymphoma = NULL, cerebral_or_b_cell_non_hodgkin_lymphoma_enc_id = NULL,
cerebral_or_b_cell_non_hodgkin_lymphoma_enc_id = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when invasive_cancer_of_cervix
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (invasive_cancer_of_cervix = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET invasive_cancer_of_cervix = "#{answer}", invasive_cancer_of_cervix_enc_id = '#{patient['encounter_id']}',
    invasive_cancer_of_cervix_v_date = DATE('#{patient_visit_date}')
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (invasive_cancer_of_cervix = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET invasive_cancer_of_cervix = NULL, invasive_cancer_of_cervix_enc_id = NULL, invasive_cancer_of_cervix_v_date = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when cryptococcal_meningitis_or_other_eptb_cryptococcosis
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (cryptococcal_meningitis_or_other_eptb_cryptococcosis = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET cryptococcal_meningitis_or_other_eptb_cryptococcosis = "#{answer}",
    cryptococcal_meningitis_or_other_eptb_cryptococcosis_v_date = DATE('#{patient_visit_date}'),
    cryptococcal_meningitis_or_other_eptb_cryptococcosis_enc_id = #{patient['encounter_id']}
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (cryptococcal_meningitis_or_other_eptb_cryptococcosis = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET cryptococcal_meningitis_or_other_eptb_cryptococcosis = NULL,
    cryptococcal_meningitis_or_other_eptb_cryptococcosis_v_date = NULL,
    cryptococcal_meningitis_or_other_eptb_cryptococcosis_enc_id = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when severe_unexplained_wasting_malnutrition
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (severe_unexplained_wasting_malnutrition = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET severe_unexplained_wasting_malnutrition = "#{answer}", severe_unexplained_wasting_malnutrition_v_date = DATE('#{patient_visit_date}'),
   severe_unexplained_wasting_malnutrition_enc_id = #{patient['encounter_id']}
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (severe_unexplained_wasting_malnutrition = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET severe_unexplained_wasting_malnutrition = NULL, severe_unexplained_wasting_malnutrition_v_date = NULL,
    severe_unexplained_wasting_malnutrition_enc_id = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when diarrhoea_chronic_less_1_month_unexplained
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (diarrhoea_chronic_less_1_month_unexplained = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET diarrhoea_chronic_less_1_month_unexplained = "#{answer}", diarrhoea_chronic_less_1_month_unexplained_v_date = DATE('#{patient_visit_date}'),
    diarrhoea_chronic_less_1_month_unexplained_enc_id = "#{patient['encounter_id']}"
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (diarrhoea_chronic_less_1_month_unexplained = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET diarrhoea_chronic_less_1_month_unexplained = NULL, diarrhoea_chronic_less_1_month_unexplained_v_date = NULL,
    diarrhoea_chronic_less_1_month_unexplained_enc_id = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when moderate_weight_loss_10_unexplained
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (moderate_weight_loss_10_unexplained = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET moderate_weight_loss_10_unexplained = "#{answer}", moderate_weight_loss_10_unexplained_v_date = DATE('#{patient_visit_date}'),
    moderate_weight_loss_10_unexplained_enc_id = "#{encounter_id}"
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (moderate_weight_loss_10_unexplained = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET moderate_weight_loss_10_unexplained = NULL, moderate_weight_loss_10_unexplained_v_date = NULL,
    moderate_weight_loss_10_unexplained_enc_id = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when cd4_percentage_available
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (cd4_percentage_available = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET cd4_percentage_available = "#{answer}", cd4_percentage_available_v_date = DATE('#{patient_visit_date}'),
    cd4_percentage_available_enc_id = "#{patient['encounter_id']}"
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (cd4_percentage_available = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET cd4_percentage_available = NULL, cd4_percentage_available_v_date = NULL,
    cd4_percentage_available_enc_id = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when acute_necrotizing_ulcerative_stomatitis_gingivitis_or_period
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (acute_necrotizing_ulcerative_stomatitis_gingivitis_or_period = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET acute_necrotizing_ulcerative_stomatitis_gingivitis_or_period = "#{answer}",
    acute_necrotizing_ulcerative_stomatitis_gingivitis_or_period_v_date = DATE('#{patient_visit_date}'),
    acute_necrotizing_ulcerative_stomatitis_gingivitis_or_period_enc_id = #{patient['encounter_id']}
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (acute_necrotizing_ulcerative_stomatitis_gingivitis_or_period = NULL): #{patient_id}"
        Connection.execute <<EOF
UPDATE flat_table1
SET acute_necrotizing_ulcerative_stomatitis_gingivitis_or_period = NULL,
    acute_necrotizing_ulcerative_stomatitis_gingivitis_or_period_v_date = NULL,
    acute_necrotizing_ulcerative_stomatitis_gingivitis_or_period_enc_id = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

  when moderate_unexplained_wasting_malnutrition
    if patient['voided'].to_i == 0
      value_coded = patient['value_coded']
      answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
      answer = answer_record['name']
      puts ".......... Updating record into flat_table1 (moderate_unexplained_wasting_malnutrition = #{answer}): #{patient['person_id']}"
      Connection.execute <<EOF
UPDATE flat_table1
SET moderate_unexplained_wasting_malnutrition = "#{answer}", moderate_unexplained_wasting_malnutrition_v_date = DATE('#{patient_visit_date}'),
    moderate_unexplained_wasting_malnutrition_enc_id = #{patient['encounter_id']}
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (moderate_unexplained_wasting_malnutrition = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET moderate_unexplained_wasting_malnutrition = NULL, moderate_unexplained_wasting_malnutrition_v_date = NULL,
    moderate_unexplained_wasting_malnutrition_enc_id = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when diarrhoea_persistent_unexplained_14_days_or_more
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (diarrhoea_persistent_unexplained_14_days_or_more = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET diarrhoea_persistent_unexplained_14_days_or_more = "#{answer}", diarrhoea_persistent_unexplained_14_days_or_more_v_date = DATE('#{patient_visit_date}'),
    diarrhoea_persistent_unexplained_14_days_or_more_enc_id = #{patient['encounter_id']}
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (diarrhoea_persistent_unexplained_14_days_or_more = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET diarrhoea_persistent_unexplained_14_days_or_more = NULL, diarrhoea_persistent_unexplained_14_days_or_more_v_date = NULL,
    diarrhoea_persistent_unexplained_14_days_or_more_enc_id = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when acute_ulcerative_mouth_infections
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (acute_ulcerative_mouth_infections = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET acute_ulcerative_mouth_infections = "#{answer}", acute_ulcerative_mouth_infections_v_date = DATE('#{patient_visit_date}'),
    acute_ulcerative_mouth_infections_enc_id = "#{patient['encounter_id']}"
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (acute_ulcerative_mouth_infections = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET acute_ulcerative_mouth_infections = NULL, acute_ulcerative_mouth_infections_v_date = NULL, acute_ulcerative_mouth_infections_enc_id = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when anaemia_unexplained_8_g_dl
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (anaemia_unexplained_8_g_dl = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET anaemia_unexplained_8_g_dl = "#{answer}", anaemia_unexplained_8_g_dl_v_date = DATE('#{patient_visit_date}'), anaemia_unexplained_8_g_dl_enc_id = #{patient['encounter_id']}
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (anaemia_unexplained_8_g_dl = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET anaemia_unexplained_8_g_dl = NULL, anaemia_unexplained_8_g_dl_v_date = NULL, anaemia_unexplained_8_g_dl_enc_id = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when atypical_mycobacteriosis_disseminated_or_lung
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (atypical_mycobacteriosis_disseminated_or_lung = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET atypical_mycobacteriosis_disseminated_or_lung = "#{answer}", atypical_mycobacteriosis_disseminated_or_lung_v_date = DATE('#{patient_visit_date}'),
    atypical_mycobacteriosis_disseminated_or_lung_enc_id = #{patient['encounter_id']}
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (atypical_mycobacteriosis_disseminated_or_lung = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET atypical_mycobacteriosis_disseminated_or_lung = NULL, atypical_mycobacteriosis_disseminated_or_lung_v_date = NULL,
    atypical_mycobacteriosis_disseminated_or_lung_enc_id = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when bacterial_infections_sev_recurrent_excluding_pneumonia
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (bacterial_infections_sev_recurrent_excluding_pneumonia = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET bacterial_infections_sev_recurrent_excluding_pneumonia = "#{answer}", bacterial_infections_sev_recurrent_excluding_pneumonia_v_date = DATE('#{patient_visit_date}'),
    bacterial_infections_sev_recurrent_excluding_pneumonia_enc_id = #{patient['encounter_id']}
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (bacterial_infections_sev_recurrent_excluding_pneumonia = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET bacterial_infections_sev_recurrent_excluding_pneumonia = NULL, bacterial_infections_sev_recurrent_excluding_pneumonia_v_date = NULL,
    bacterial_infections_sev_recurrent_excluding_pneumonia_enc_id = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when cancer_cervix
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (cancer_cervix = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET cancer_cervix = "#{answer}", cancer_cervix_v_date = DATE('#{patient_visit_date}'), cancer_cervix_enc_id = #{patient['encounter_id']}
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (cancer_cervix = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET cancer_cervix = NULL, cancer_cervix_v_date = NULL, cancer_cervix_enc_id = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when chronic_herpes_simplex_infection_genital
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (chronic_herpes_simplex_infection_genital = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET chronic_herpes_simplex_infection_genital = "#{answer}", chronic_herpes_simplex_infection_genital_v_date = DATE('#{patient_visit_date}'),
    chronic_herpes_simplex_infection_genital_enc_id = #{patient['encounter_id']}"
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when cryptosporidiosis_chronic_with_diarrhoea
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (cryptosporidiosis_chronic_with_diarrhoea = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET cryptosporidiosis_chronic_with_diarrhoea = "#{answer}", cryptosporidiosis_chronic_with_diarrhoea_v_date = DATE('#{patient_visit_date}'),
    cryptosporidiosis_chronic_with_diarrhoea_enc_id = #{patient['encounter_id']}
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (cryptosporidiosis_chronic_with_diarrhoea = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET cryptosporidiosis_chronic_with_diarrhoea = NULL, cryptosporidiosis_chronic_with_diarrhoea_v_date = NULL, cryptosporidiosis_chronic_with_diarrhoea_enc_id = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when cytomegalovirus_infection_retinitis_or_other_organ
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (cytomegalovirus_infection_retinitis_or_other_organ = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET cytomegalovirus_infection_retinitis_or_other_organ = "#{answer}",
    cytomegalovirus_infection_retinitis_or_other_organ_v_date = DATE('#{patient_visit_date}'),
    cytomegalovirus_infection_retinitis_or_other_organ_enc_id = #{patient['encounter_id']}
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (cytomegalovirus_infection_retinitis_or_other_organ = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET cytomegalovirus_infection_retinitis_or_other_organ = NULL, cytomegalovirus_infection_retinitis_or_other_organ_v_date = NULL,
    cytomegalovirus_infection_retinitis_or_other_organ_enc_id = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when cytomegalovirus_of_an_organ_other_than_liver
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (cytomegalovirus_of_an_organ_other_than_liver = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET cytomegalovirus_of_an_organ_other_than_liver = "#{answer}", cytomegalovirus_of_an_organ_other_than_liver_v_date = DATE('#{patient_visit_date}'),
    cytomegalovirus_of_an_organ_other_than_liver_enc_id = #{patient['encounter_id']}
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (cytomegalovirus_of_an_organ_other_than_liver = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET cytomegalovirus_of_an_organ_other_than_liver = NULL, cytomegalovirus_of_an_organ_other_than_liver_v_date = NULL,
    cytomegalovirus_of_an_organ_other_than_liver_enc_id = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when fungal_nail_infections
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (fungal_nail_infections #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET fungal_nail_infections = "#{answer}", fungal_nail_infections_v_date = DATE('#{patient_visit_date}'), fungal_nail_infections_enc_id = #{patient['encounter_id']}
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (fungal_nail_infections = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET fungal_nail_infections = NULL, fungal_nail_infections_v_date = NULL, fungal_nail_infections_enc_id = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when herpes_simplex_infection_mucocutaneous_visceral
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (herpes_simplex_infection_mucocutaneous_visceral = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET herpes_simplex_infection_mucocutaneous_visceral = "#{answer}",
    herpes_simplex_infection_mucocutaneous_visceral_v_date = DATE('#{patient_visit_date}'),
    herpes_simplex_infection_mucocutaneous_visceral_enc_id = #{patient['encounter_id']}
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (herpes_simplex_infection_mucocutaneous_visceral = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET herpes_simplex_infection_mucocutaneous_visceral = NULL, herpes_simplex_infection_mucocutaneous_visceral_v_date = NULL,
    herpes_simplex_infection_mucocutaneous_visceral_enc_id = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when hiv_associated_cardiomyopathy
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (hiv_associated_cardiomyopathy = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET hiv_associated_cardiomyopathy = "#{answer}", hiv_associated_cardiomyopathy_v_date = DATE('#{patient_visit_date}'),
    hiv_associated_cardiomyopathy_enc_id = #{patient['encounter_id']}
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (hiv_associated_cardiomyopathy = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET hiv_associated_cardiomyopathy = NULL, hiv_associated_cardiomyopathy_v_date = NULL, hiv_associated_cardiomyopathy_enc_id = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when hiv_associated_nephropathy
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (hiv_associated_nephropathy = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET hiv_associated_nephropathy = "#{answer}", hiv_associated_nephropathy_v_date = DATE('#{patient_visit_date}'), hiv_associated_nephropathy_enc_id = "#{patient['encounter_id']}"
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (hiv_associated_nephropathy = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET hiv_associated_nephropathy = NULL, hiv_associated_nephropathy_v_date = NULL, hiv_associated_nephropathy_enc_id = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when invasive_cancer_cervix
      if patient['voided'] == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (invasive_cancer_cervix = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET invasive_cancer_cervix = "#{answer}", invasive_cancer_cervix_v_date = DATE('#{patient_visit_date}'), invasive_cancer_cervix_enc_id = "#{patient['encounter_id']}"
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (invasive_cancer_cervix = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET invasive_cancer_cervix = NULL, invasive_cancer_cervix_v_date = NULL, invasive_cancer_cervix_enc_id = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when isosporiasis_1_month
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (isosporiasis_1_month = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET isosporiasis_1_month = "#{answer}", isosporiasis_1_month_v_date = DATE('#{patient_visit_date}'), isosporiasis_1_month_enc_id = "#{patient['encounter_id']}"
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (isosporiasis_1_month = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET isosporiasis_1_month = NULL, isosporiasis_1_month_v_date = NULL, isosporiasis_1_month_enc_id = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when minor_mucocutaneous_manifestations_seborrheic_dermatitis
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (minor_mucocutaneous_manifestations_seborrheic_dermatitis = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET minor_mucocutaneous_manifestations_seborrheic_dermatitis = "#{answer}",
    minor_mucocutaneous_manifestations_seborrheic_dermatitis_v_date = DATE('#{patient_visit_date}'),
    minor_mucocutaneous_manifestations_seborrheic_dermatitis_enc_id = "#{patient['encounter_id']}"
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (minor_mucocutaneous_manifestations_seborrheic_dermatitis = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET minor_mucocutaneous_manifestations_seborrheic_dermatitis = NULL,
    minor_mucocutaneous_manifestations_seborrheic_dermatitis_v_date = NULL,
    minor_mucocutaneous_manifestations_seborrheic_dermatitis_enc_id = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when moderate_unexplained_malnutrition
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (moderate_unexplained_malnutrition = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET moderate_unexplained_malnutrition = "#{answer}", moderate_unexplained_malnutrition_v_date = DATE('#{patient_visit_date}'),
    moderate_unexplained_malnutrition_enc_id = "#{patient['encounter_id']}"
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (moderate_unexplained_malnutrition = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET moderate_unexplained_malnutrition = NULL, moderate_unexplained_malnutrition_v_date = NULL, moderate_unexplained_malnutrition_enc_id = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when molluscum_contagiosum_extensive
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (molluscum_contagiosum_extensive = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET molluscum_contagiosum_extensive = "#{answer}", molluscum_contagiosum_extensive_v_date = DATE('#{patient_visit_date}'), molluscum_contagiosum_extensive_enc_id = #{patient['encounter_id']}
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (molluscum_contagiosum_extensive = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET molluscum_contagiosum_extensive = NULL, molluscum_contagiosum_extensive_v_date = NULL, molluscum_contagiosum_extensive_enc_id = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when oral_thrush
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (oral_thrush = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET oral_thrush = "#{answer}", oral_thrush_v_date = DATE('#{patient_visit_date}'), oral_thrush_enc_id = "#{patient['encounter_id']}"
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (oral_thrush = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET oral_thrush = NULL, oral_thrush_v_date = NULL, oral_thrush_enc_id = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when perform_extended_staging
      if patient['voided'] == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (perform_extended_staging = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET perform_extended_staging = "#{answer}", perform_extended_staging_v_date = DATE('#{patient_visit_date}'), perform_extended_staging_enc_id = "#{patient['encounter_id']}"
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (perform_extended_staging = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET perform_extended_staging = NULL, perform_extended_staging_v_date = NULL, perform_extended_staging_enc_id = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when pneumocystis_carinii_pneumonia
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (pneumocystis_carinii_pneumonia = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET pneumocystis_carinii_pneumonia = "#{answer}", pneumocystis_carinii_pneumonia_v_date = DATE('#{patient_visit_date}'), pneumocystis_carinii_pneumonia_enc_id = #{patient['encounter_id']}
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (pneumocystis_carinii_pneumonia = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET pneumocystis_carinii_pneumonia = NULL, pneumocystis_carinii_pneumonia_v_date = NULL, pneumocystis_carinii_pneumonia_enc_id = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when pneumonia_severe
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (pneumonia_severe = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET pneumonia_severe = "#{answer}", pneumonia_severe_v_date = DATE('#{patient_visit_date}'), pneumonia_severe_enc_id = #{patient['encounter_id']}
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (pneumonia_severe = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET pneumonia_severe = NULL, pneumonia_severe_v_date = NULL, pneumonia_severe_enc_id = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when recurrent_bacteraemia_or_sepsis_with_nts
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (recurrent_bacteraemia_or_sepsis_with_nts = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET recurrent_bacteraemia_or_sepsis_with_nts = "#{answer}",
    recurrent_bacteraemia_or_sepsis_with_nts_v_date = DATE('#{patient_visit_date}'),
    recurrent_bacteraemia_or_sepsis_with_nts_enc_id = "#{patient['encounter_id']}"
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (recurrent_bacteraemia_or_sepsis_with_nts = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET recurrent_bacteraemia_or_sepsis_with_nts = NULL, recurrent_bacteraemia_or_sepsis_with_nts_v_date = NULL, recurrent_bacteraemia_or_sepsis_with_nts_enc_id = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when recurrent_severe_presumed_pneumonia
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (recurrent_severe_presumed_pneumonia = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET recurrent_severe_presumed_pneumonia = "#{answer}",
    recurrent_severe_presumed_pneumonia_v_date = DATE('#{patient_visit_date}'),
    recurrent_severe_presumed_pneumonia_enc_id = "#{patient['encounter_id']}"
WHERE flat_table1.patient_id = "#{patient['person_id']}";
EOF
      else
        puts ".......... Updating record into flat_table1 (recurrent_severe_presumed_pneumonia = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET recurrent_severe_presumed_pneumonia = NULL,
    recurrent_severe_presumed_pneumonia_v_date = NULL,
    recurrent_severe_presumed_pneumonia_enc_id = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when recurrent_upper_respiratory_tract_bac_sinusitis
    if patient['voided'].to_i == 0
      value_coded = patient['value_coded']
      answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
      answer = answer_record['name']
      puts ".......... Updating record into flat_table1 (recurrent_upper_respiratory_tract_bac_sinusitis = #{answer}): #{patient['person_id']}"
      Connection.execute <<EOF
UPDATE flat_table1
SET recurrent_upper_respiratory_tract_bac_sinusitis = "#{answer}",
    recurrent_upper_respiratory_tract_bac_sinusitis_v_date = DATE('#{patient_visit_date}'),
    recurrent_upper_respiratory_tract_bac_sinusitis_enc_id = #{patient['encounter_id']}
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (recurrent_upper_respiratory_tract_bac_sinusitis = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET recurrent_upper_respiratory_tract_bac_sinusitis = NULL,
    recurrent_upper_respiratory_tract_bac_sinusitis_v_date = NULL,
    recurrent_upper_respiratory_tract_bac_sinusitis_enc_id = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when sepsis_severe
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (sepsis_severe = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET sepsis_severe = "#{answer}", sepsis_severe_v_date = DATE('#{patient_visit_date}'), sepsis_severe_enc_id = #{patient['encounter_id']}
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
        else
          puts ".......... Updating record into flat_table1 (sepsis_severe = NULL): #{patient['person_id']}"
          Connection.execute <<EOF
UPDATE flat_table1
SET sepsis_severe = NULL, sepsis_severe_v_date = NULL, sepsis_severe_enc_id = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
        end #voided

      when unexplained_anaemia_neutropenia_or_thrombocytopenia
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (unexplained_anaemia_neutropenia_or_thrombocytopenia = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET unexplained_anaemia_neutropenia_or_thrombocytopenia = "#{answer}",
    unexplained_anaemia_neutropenia_or_thrombocytopenia_v_date = DATE('#{patient_visit_date}'),
    unexplained_anaemia_neutropenia_or_thrombocytopenia_enc_id = "#{patient['encounter_id']}"
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (unexplained_anaemia_neutropenia_or_thrombocytopenia = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET unexplained_anaemia_neutropenia_or_thrombocytopenia = NULL,
    unexplained_anaemia_neutropenia_or_thrombocytopenia_v_date = NULL,
    unexplained_anaemia_neutropenia_or_thrombocytopenia_enc_id = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when visceral_leishmaniasis
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (visceral_leishmaniasis = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET visceral_leishmaniasis = "#{answer}", visceral_leishmaniasis_v_date = DATE('#{patient_visit_date}'), visceral_leishmaniasis_enc_id = "#{patient['encounter_id']}"
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (visceral_leishmaniasis = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET visceral_leishmaniasis = NULL, visceral_leishmaniasis_v_date = NULL, visceral_leishmaniasis_enc_id = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when reason_for_eligibility
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("select name as reason from concept_name where concept_id = patient_reason_for_starting_art(#{patient['person_id']}) and concept_name_type = 'FULLY_SPECIFIED'")

        answer = answer_record['reason'] if patient['value_text'].blank?
        puts "........... Updating record into flat_table1 reason_for_eligibility = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET reason_for_eligibility = "#{answer}", reason_for_eligibility_v_date = DATE('#{patient_visit_date}'), reason_for_eligibility_enc_id = "#{patient['encounter_id']}"
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts "........... Updating record into flat_table1 reason_for_eligibility: #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  reason_for_eligibility = NULL, reason_for_eligibility_v_date = NULL, reason_for_eligibility_enc_id = NULL
WHERE flat_table1.patient_id = #{patient['person_id']} ;
EOF
      end #voided

    when who_stage
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        stage_record = Connection.select_one("SELECT concept_name.name FROM concept_name
                          LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                      WHERE concept.concept_id = '#{value_coded}' AND name <> ' ' AND voided = 0 AND retired = 0 LIMIT 1")
        stage = stage_record['name']
        puts "........... Updating record into flat_table1 (who_stage  = #{stage}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  who_stage = "#{stage}", who_stage_v_date = DATE('#{patient_visit_date}'), who_stage_enc_id = "#{patient['encounter_id']}"
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts "........... Updating record into flat_table1 (who_stage = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  who_stage = NULL, who_stage_v_date = NULL,
who_stage_enc_id = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

    when oral_candidiasis_from_age_2_months
      if patient['voided'].to_i == 0
        value_coded = patient['value_coded']
        answer_record = Connection.select_one("SELECT name from concept_name LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
              WHERE  concept.concept_id = '#{value_coded}' AND voided = 0 AND retired = 0 LIMIT 1")
        answer = answer_record['name']
        puts ".......... Updating record into flat_table1 (oral_candidiasis_from_age_2_months = #{answer}): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  oral_candidiasis_from_age_2_months = "#{answer}", oral_candidiasis_from_age_2_months_v_date = DATE('#{patient_visit_date}'),
    oral_candidiasis_from_age_2_months_enc_id = #{patient['encounter_id']}
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (oral_candidiasis_from_age_2_months = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET oral_candidiasis_from_age_2_months = NULL, oral_candidiasis_from_age_2_months_v_date = NULL, oral_candidiasis_from_age_2_months_enc_id = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #voided

when who_stages_criteria_present
  case patient['value_coded'].to_i
    when asymptomatic
      if patient['voided'].to_i == 0
        puts ".......... Updating record into flat_table1 (asymptomatic): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  asymptomatic = "Yes", asymptomatic_enc_id = '#{patient['encounter_id']}', asymptomatic_v_date = DATE('#{patient_visit_date}')
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (asymptomatic = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  asymptomatic = NULL, asymptomatic_enc_id = NULL, asymptomatic_v_date = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #end if

    when pers_gnrl_lymphadenopathy
      if patient['voided'].to_i == 0
        puts ".......... Updating record into flat_table1 (persistent_generalized_lymphadenopathy): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  persistent_generalized_lymphadenopathy = "Yes", persistent_generalized_lymphadenopathy_enc_id = '#{patient['encounter_id']}',
     persistent_generalized_lymphadenopathy_v_date = DATE('#{patient_visit_date}')
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (persistent_generalized_lymphadenopathy = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  persistent_generalized_lymphadenopathy = NULL, persistent_generalized_lymphadenopathy_enc_id = NULL,
persistent_generalized_lymphadenopathy_v_date = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #end if

    when unspecified_stage_1_cond
      if patient['voided'].to_i == 0
        puts ".......... Updating record into flat_table1 (unspecified_stage_1_cond): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  unspecified_stage_1_cond = "Yes", unspecified_stage_1_cond_enc_id = '#{patient['encounter_id']}',
     unspecified_stage_1_cond_v_date = DATE('#{patient_visit_date}')
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (unspecified_stage_1_cond = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  unspecified_stage_1_cond = NULL, unspecified_stage_1_cond_enc_id = NULL, unspecified_stage_1_cond_v_date = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #end if

    when molluscumm_contagiosum
      if patient['voided'].to_i == 0
        puts ".......... Updating record into flat_table1 (molluscumm_contagiosum): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  molluscumm_contagiosum = "Yes", molluscumm_contagiosum_enc_id = '#{patient['encounter_id']}',
     molluscumm_contagiosum_v_date = DATE('#{patient_visit_date}')
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (molluscumm_contagiosum = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  molluscumm_contagiosum = NULL,, molluscumm_contagiosum_enc_id = NULL,
molluscumm_contagiosum_v_date = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #end if

    when wart_virus_infection_extensive
      if patient['voided'].to_i == 0
        puts ".......... Updating record into flat_table1 (wart_virus_infection_extensive): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  wart_virus_infection_extensive = "Yes", wart_virus_infection_extensive_enc_id = '#{patient['encounter_id']}',
     wart_virus_infection_extensive_v_date = DATE('#{patient_visit_date}')
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (wart_virus_infection_extensive = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  wart_virus_infection_extensive = NULL, wart_virus_infection_extensive_enc_id = NULL,
wart_virus_infection_extensive_v_date = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #end if

    when oral_ulcerations_recurrent
      if patient['voided'].to_i == 0
        puts ".......... Updating record into flat_table1 (oral_ulcerations_recurrent): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  oral_ulcerations_recurrent = "Yes", oral_ulcerations_recurrent_enc_id = '#{patient['encounter_id']}',
     oral_ulcerations_recurrent_v_date = DATE('#{patient_visit_date}')
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (oral_ulcerations_recurrent = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  oral_ulcerations_recurrent = NULL, oral_ulcerations_recurrent_enc_id = NULL,
oral_ulcerations_recurrent_v_date = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #end if

    when parotid_enlargement_pers_unexp
      if patient['voided'].to_i == 0
        puts ".......... Updating record into flat_table1 (parotid_enlargement_persistent_unexplained): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  parotid_enlargement_persistent_unexplained = "Yes", parotid_enlargement_persistent_unexplained_enc_id = '#{patient['encounter_id']}',
     parotid_enlargement_persistent_unexplained_v_date = DATE('#{patient_visit_date}')
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (parotid_enlargement_persistent_unexplained = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  parotid_enlargement_persistent_unexplained = NULL, parotid_enlargement_persistent_unexplained_enc_id = NULL,
parotid_enlargement_persistent_unexplained_v_date = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #end if

    when lineal_gingival_erythema
      if patient['voided'].to_i == 0
        puts ".......... Updating record into flat_table1 (lineal_gingival_erythema): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  lineal_gingival_erythema = "Yes", lineal_gingival_erythema_enc_id = '#{patient['encounter_id']}',
     lineal_gingival_erythema_v_date = DATE('#{patient_visit_date}')
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (lineal_gingival_erythema = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  lineal_gingival_erythema = NULL, lineal_gingival_erythema_enc_id = NULL,
lineal_gingival_erythema_v_date = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #end if

    when herpes_zoster
      if patient['voided'].to_i == 0
        puts ".......... Updating record into flat_table1 (herpes_zoster): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  herpes_zoster = "Yes", herpes_zoster_enc_id = '#{patient['encounter_id']}',
     herpes_zoster_v_date = DATE('#{patient_visit_date}')
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (herpes_zoster = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  herpes_zoster = NULL, herpes_zoster_enc_id = NULL,
herpes_zoster_v_date = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #end if

    when resp_tract_infections_rec
      if patient['voided'].to_i == 0
        puts ".......... Updating record into flat_table1 (respiratory_tract_infections_recurrent): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  respiratory_tract_infections_recurrent = "Yes", respiratory_tract_infections_recurrent_enc_id = '#{patient['encounter_id']}',
     respiratory_tract_infections_recurrent_v_date = DATE('#{patient_visit_date}')
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (respiratory_tract_infections_recurrent = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  respiratory_tract_infections_recurrent = NULL, respiratory_tract_infections_recurrent_enc_id = NULL,
respiratory_tract_infections_recurrent_v_date = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #end if

    when unspecified_stage2_condition
      if patient['voided'].to_i == 0
        puts ".......... Updating record into flat_table1 (unspecified_stage2_condition): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  unspecified_stage2_condition = "Yes", unspecified_stage2_condition_enc_id = '#{patient['encounter_id']}',
     unspecified_stage2_condition_v_date = DATE('#{patient_visit_date}')
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (unspecified_stage2_condition = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  unspecified_stage2_condition = NULL, unspecified_stage2_condition_enc_id = NULL,
unspecified_stage2_condition_v_date = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #end if

    when angular_chelitis
      if patient['voided'].to_i == 0
        puts ".......... Updating record into flat_table1 (angular_chelitis): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  angular_chelitis = "Yes", angular_chelitis_enc_id = '#{patient['encounter_id']}',
     angular_chelitis_v_date = DATE('#{patient_visit_date}')
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (angular_chelitis = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  angular_chelitis = NULL, angular_chelitis_enc_id = NULL,
angular_chelitis_v_date = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #end if

    when papular_prurtic_eruptions
      if patient['voided'].to_i == 0
        puts ".......... Updating record into flat_table1 (papular_pruritic_eruptions): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  papular_pruritic_eruptions = "Yes", papular_pruritic_eruptions_enc_id = '#{patient['encounter_id']}',
     papular_pruritic_eruptions_v_date = DATE('#{patient_visit_date}')
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (papular_pruritic_eruptions = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  papular_pruritic_eruptions = NULL, papular_pruritic_eruptions_enc_id = NULL,
papular_pruritic_eruptions_v_date = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #end if


    when hepatosplenomegaly_unexplained
      if patient['voided'].to_i == 0
        puts ".......... Updating record into flat_table1 (hepatosplenomegaly_unexplained): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  hepatosplenomegaly_unexplained = "Yes", hepatosplenomegaly_unexplained_enc_id = '#{patient['encounter_id']}',
     hepatosplenomegaly_unexplained_v_date = DATE('#{patient_visit_date}')
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (hepatosplenomegaly_unexplained = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  hepatosplenomegaly_unexplained = NULL, hepatosplenomegaly_unexplained_enc_id = NULL,
hepatosplenomegaly_unexplained_v_date = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #end if

    when oral_hairy_leukoplakia
      if patient['voided'].to_i == 0
        puts ".......... Updating record into flat_table1 (oral_hairy_leukoplakia): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  oral_hairy_leukoplakia = "Yes", oral_hairy_leukoplakia_enc_id = '#{patient['encounter_id']}',
     oral_hairy_leukoplakia_v_date= DATE('#{patient_visit_date}')
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (oral_hairy_leukoplakia = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  oral_hairy_leukoplakia = NULL, oral_hairy_leukoplakia_enc_id = NULL, oral_hairy_leukoplakia_v_date = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #end if

    when severe_weight_loss
      if patient['voided'].to_i == 0
        puts ".......... Updating record into flat_table1 (severe_weight_loss): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  severe_weight_loss = "Yes"
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (severe_weight_loss = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  severe_weight_loss = NULL, severe_weight_loss_enc_id = '#{patient['encounter_id']}',
     severe_weight_loss_v_date = DATE('#{patient_visit_date}'), severe_weight_loss_enc_id = NULL,
severe_weight_loss_v_date = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #end if

    when fever_persistent_unexplained
      if patient['voided'].to_i == 0
        puts ".......... Updating record into flat_table1 (fever_persistent_unexplained): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  fever_persistent_unexplained = "Yes", fever_persistent_unexplained_enc_id = '#{patient['encounter_id']}',
     fever_persistent_unexplained_v_date= DATE('#{patient_visit_date}')
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (fever_persistent_unexplained = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  fever_persistent_unexplained = NULL, fever_persistent_unexplained_enc_id = NULL,
fever_persistent_unexplained_v_date = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #end if

    when pulmonary_tuberculosis
      if patient['voided'].to_i == 0
        puts ".......... Updating record into flat_table1 (pulmonary_tuberculosis): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  pulmonary_tuberculosis = "Yes", pulmonary_tuberculosis_enc_id = '#{patient['encounter_id']}',
     pulmonary_tuberculosis_v_date = DATE('#{patient_visit_date}')
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (pulmonary_tuberculosis = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  pulmonary_tuberculosis = NULL, pulmonary_tuberculosis_enc_id = NULL,
pulmonary_tuberculosis_v_date = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #end if

    when pulmonary_tuberculosis_last_2_years
      if patient['voided'].to_i == 0
        puts ".......... Updating record into flat_table1 (pulmonary_tuberculosis_last_2_years): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  pulmonary_tuberculosis_last_2_years = "Yes", pulmonary_tuberculosis_last_2_years_enc_id = '#{patient['encounter_id']}', pulmonary_tuberculosis_last_2_years_v_date= DATE('#{patient_visit_date}')
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (pulmonary_tuberculosis_last_2_years = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  pulmonary_tuberculosis_last_2_years = NULL, pulmonary_tuberculosis_last_2_years_enc_id = NULL, pulmonary_tuberculosis_last_2_years_v_date = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #end if

    when ptb_last_2_years
      if patient['voided'].to_i == 0
        puts ".......... Updating record into flat_table1 (pulmonary_tuberculosis_last_2_years): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  pulmonary_tuberculosis_last_2_years = "Yes", pulmonary_tuberculosis_last_2_years_enc_id = '#{patient['encounter_id']}', pulmonary_tuberculosis_last_2_years_v_date= DATE('#{patient_visit_date}')
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (pulmonary_tuberculosis_last_2_years = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  pulmonary_tuberculosis_last_2_years = NULL, pulmonary_tuberculosis_last_2_years_enc_id = NULL, pulmonary_tuberculosis_last_2_years_v_date = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #end if  

    when severe_bacterial_infection
      if patient['voided'].to_i == 0
        puts ".......... Updating record into flat_table1 (severe_bacterial_infection): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  severe_bacterial_infection = "Yes", severe_bacterial_infection_enc_id = '#{patient['encounter_id']}',
      severe_bacterial_infection_v_date = DATE('#{patient_visit_date}')
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (severe_bacterial_infection = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  severe_bacterial_infection = NULL, severe_bacterial_infection_enc_id = NULL,
severe_bacterial_infection_v_date = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #end if

    when bacterial_pnuemonia
      if patient['voided'].to_i == 0
        puts ".......... Updating record into flat_table1 (bacterial_pnuemonia): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  bacterial_pnuemonia = "Yes", bacterial_pnuemonia_enc_id = '#{patient['encounter_id']}',
      bacterial_pnuemonia_v_date = DATE('#{patient_visit_date}')
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (bacterial_pnuemonia = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  bacterial_pnuemonia = NULL, bacterial_pnuemonia_enc_id = NULL,
bacterial_pnuemonia_v_date = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #end if

    when symptomatic_lymphoid_interstitial_pnuemonitis
      if patient['voided'].to_i == 0
        puts ".......... Updating record into flat_table1 (symptomatic_lymphoid_interstitial_pnuemonitis): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  symptomatic_lymphoid_interstitial_pnuemonitis = "Yes", symptomatic_lymphoid_interstitial_pnuemonitis_enc_id = '#{patient['encounter_id']}',
      symptomatic_lymphoid_interstitial_pnuemonitis_v_date = DATE('#{patient_visit_date}')
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (symptomatic_lymphoid_interstitial_pnuemonitis = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  symptomatic_lymphoid_interstitial_pnuemonitis = NULL, symptomatic_lymphoid_interstitial_pnuemonitis_enc_id = NULL,
symptomatic_lymphoid_interstitial_pnuemonitis_v_date = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #end if

    when chronic_hiv_assoc_lung_disease
      if patient['voided'].to_i == 0
        puts ".......... Updating record into flat_table1 (chronic_hiv_assoc_lung_disease): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  chronic_hiv_assoc_lung_disease = "Yes", chronic_hiv_assoc_lung_disease_enc_id = '#{patient['encounter_id']}',
      chronic_hiv_assoc_lung_disease_v_date = DATE('#{patient_visit_date}')
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (chronic_hiv_assoc_lung_disease = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  chronic_hiv_assoc_lung_disease = NULL, chronic_hiv_assoc_lung_disease_enc_id = NULL,
chronic_hiv_assoc_lung_disease_v_date = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #end if

    when unspecified_stage3_condition
      if patient['voided'].to_i == 0
        puts ".......... Updating record into flat_table1 (unspecified_stage3_condition): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  unspecified_stage3_condition = "Yes", unspecified_stage3_condition_enc_id = '#{patient['encounter_id']}',
      unspecified_stage3_condition_v_date = DATE('#{patient_visit_date}')
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (unspecified_stage3_condition = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  unspecified_stage3_condition = NULL, unspecified_stage3_condition_enc_id = NULL,
unspecified_stage3_condition_v_date = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #end if

    when aneamia
      if patient['voided'].to_i == 0
        puts ".......... Updating record into flat_table1 (aneamia): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  aneamia = "Yes", aneamia_enc_id = '#{patient['encounter_id']}',
      aneamia_v_date = DATE('#{patient_visit_date}')
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (aneamia = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  aneamia = NULL, aneamia_enc_id = NULL, aneamia_v_date = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #end if

    when neutropaenia
      if patient['voided'].to_i == 0
        puts ".......... Updating record into flat_table1 (neutropaenia): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  neutropaenia = "Yes", neutropaenia_enc_id = '#{patient['encounter_id']}',
      neutropaenia_v_date = DATE('#{patient_visit_date}')
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (neutropaenia = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  neutropaenia = NULL, neutropaenia_enc_id = NULL
neutropaenia_v_date = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #end if

    when thrombocytopaenia_chronic
      if patient['voided'].to_i == 0
        puts ".......... Updating record into flat_table1 (thrombocytopaenia_chronic): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  thrombocytopaenia_chronic = "Yes",thrombocytopaenia_chronic_enc_id = '#{patient['encounter_id']}',
      thrombocytopaenia_chronic_v_date = DATE('#{patient_visit_date}')
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (thrombocytopaenia_chronic = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  thrombocytopaenia_chronic = NULL, , thrombocytopaenia_chronic_enc_id = NULL,
thrombocytopaenia_chronic_v_date = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #end if

    when diarhoea
      if patient['voided'].to_i == 0
        puts ".......... Updating record into flat_table1 (diarhoea): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  diarhoea = "Yes", diarhoea_enc_id = '#{patient['encounter_id']}',
      diarhoea_v_date = DATE('#{patient_visit_date}')
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (diarhoea = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  diarhoea = NULL, diarhoea_enc_id = NULL, diarhoea_v_date = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #end if

    when oral_candidiasis
      if patient['voided'].to_i == 0
        puts ".......... Updating record into flat_table1 (oral_candidiasis): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  oral_candidiasis = "Yes", oral_candidiasis_enc_id = '#{patient['encounter_id']}',
      oral_candidiasis_v_date = DATE('#{patient_visit_date}')
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (oral_candidiasis = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  oral_candidiasis = NULL, oral_candidiasis_enc_id = NULL, oral_candidiasis_v_date = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #end if

    when acute_necrotizing_ulcerative_gingivitis
      if patient['voided'].to_i == 0
        puts ".......... Updating record into flat_table1 (acute_necrotizing_ulcerative_gingivitis): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  acute_necrotizing_ulcerative_gingivitis = "Yes", acute_necrotizing_ulcerative_gingivitis_enc_id = '#{patient['encounter_id']}',
      acute_necrotizing_ulcerative_gingivitis_v_date = DATE('#{patient_visit_date}')
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (acute_necrotizing_ulcerative_gingivitis = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  acute_necrotizing_ulcerative_gingivitis = NULL, acute_necrotizing_ulcerative_gingivitis_enc_id = NULL, acute_necrotizing_ulcerative_gingivitis_v_date = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #end if

    when lymph_node_tuberculosis
      if patient['voided'].to_i == 0
        puts ".......... Updating record into flat_table1 (lymph_node_tuberculosis): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  lymph_node_tuberculosis = "Yes", lymph_node_tuberculosis_enc_id = '#{patient['encounter_id']}',
      lymph_node_tuberculosis_v_date = DATE('#{patient_visit_date}')
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (lymph_node_tuberculosis = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  lymph_node_tuberculosis = NULL, lymph_node_tuberculosis_enc_id = NULL, lymph_node_tuberculosis_v_date = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #end if

    when toxoplasmosis_of_brain
      if patient['voided'].to_i == 0
        puts ".......... Updating record into flat_table1 (toxoplasmosis_of_the_brain): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  toxoplasmosis_of_the_brain = "Yes", toxoplasmosis_of_the_brain_enc_id = '#{patient['encounter_id']}',
      toxoplasmosis_of_the_brain_v_date = DATE('#{patient_visit_date}')
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (toxoplasmosis_of_the_brain = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  toxoplasmosis_of_the_brain = NULL, toxoplasmosis_of_the_brain_enc_id = NULL,
toxoplasmosis_of_the_brain_v_date = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #end if

    when cryptococcal_meningitis
      if patient['voided'].to_i == 0
        puts ".......... Updating record into flat_table1 (cryptococcal_meningitis): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  cryptococcal_meningitis = "Yes", cryptococcal_meningitis_enc_id = '#{patient['encounter_id']}',
      cryptococcal_meningitis_v_date = DATE('#{patient_visit_date}')
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (cryptococcal_meningitis = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  cryptococcal_meningitis = NULL, cryptococcal_meningitis_enc_id = NULL, cryptococcal_meningitis_v_date =  NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #end if

    when progressive_multifocal_leukoencephalopathy
      if patient['voided'].to_i == 0
        puts ".......... Updating record into flat_table1 (progressive_multifocal_leukoencephalopathy): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  progressive_multifocal_leukoencephalopathy = "Yes", progressive_multifocal_leukoencephalopathy_enc_id = '#{patient['encounter_id']}',
      progressive_multifocal_leukoencephalopathy_v_date = DATE('#{patient_visit_date}')
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (progressive_multifocal_leukoencephalopathy = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  progressive_multifocal_leukoencephalopathy = NULL, progressive_multifocal_leukoencephalopathy_enc_id = NULL,
progressive_multifocal_leukoencephalopathy_v_date = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #end if

    when disseminated_mycosis
      if patient['voided'].to_i == 0
        puts ".......... Updating record into flat_table1 (disseminated_mycosis): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  disseminated_mycosis = "Yes", disseminated_mycosis_enc_id = '#{patient['encounter_id']}',
      disseminated_mycosis_v_date = DATE('#{patient_visit_date}')
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (disseminated_mycosis = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  disseminated_mycosis = NULL, disseminated_mycosis_enc_id = NULL,
disseminated_mycosis_v_date = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #end if

    when candidiasis_of_oesophagus
      if patient['voided'].to_i == 0
        puts ".......... Updating record into flat_table1 (candidiasis_of_oesophagus): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  candidiasis_of_oesophagus = "Yes",candidiasis_of_oesophagus_enc_id = '#{patient['encounter_id']}', candidiasis_of_oesophagus_v_date = '#{start_date}',
    candidiasis_of_oesophagus_enc_id = #{patient['encounter_id']}
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (candidiasis_of_oesophagus = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  candidiasis_of_oesophagus = NULL, , candidiasis_of_oesophagus_enc_id = NULL, candidiasis_of_oesophagus_v_date = NULL, candidiasis_of_oesophagus_enc_id = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #end if

    when extrapulmonary_tuberculosis
      if patient['voided'].to_i == 0
        puts ".......... Updating record into flat_table1 (extrapulmonary_tuberculosis): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  extrapulmonary_tuberculosis = "Yes", extrapulmonary_tuberculosis_enc_id = '#{patient['encounter_id']}',
      extrapulmonary_tuberculosis_v_date = DATE('#{patient_visit_date}')
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (extrapulmonary_tuberculosis = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  extrapulmonary_tuberculosis = NULL, extrapulmonary_tuberculosis_enc_id= NULL, extrapulmonary_tuberculosis_v_date = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #end if

    when cerebral_non_hodgkin_lymphoma
      if patient['voided'].to_i == 0
        puts ".......... Updating record into flat_table1 (cerebral_non_hodgkin_lymphoma): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  cerebral_non_hodgkin_lymphoma = "Yes", cerebral_non_hodgkin_lymphoma_enc_id = '#{patient['encounter_id']}',
      cerebral_non_hodgkin_lymphoma_v_date = DATE('#{patient_visit_date}')
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (cerebral_non_hodgkin_lymphoma = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  cerebral_non_hodgkin_lymphoma = NULL,  cerebral_non_hodgkin_lymphoma_enc_id = NULL, cerebral_non_hodgkin_lymphoma_v_date = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #end if

    when hiv_encephalopathy
      if patient['voided'].to_i == 0
        puts ".......... Updating record into flat_table1 (hiv_encephalopathy): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  hiv_encephalopathy = "Yes", hiv_encephalopathy_enc_id = '#{patient['encounter_id']}',
      hiv_encephalopathy_v_date = DATE('#{patient_visit_date}')
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (hiv_encephalopathy = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  hiv_encephalopathy = NULL, hiv_encephalopathy_enc_id = NULL,
hiv_encephalopathy_v_date = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #end if

    when bacterial_infections_severe_recurrent
      if patient['voided'].to_i == 0
        puts ".......... Updating record into flat_table1 (bacterial_infections_severe_recurrent): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  bacterial_infections_severe_recurrent = "Yes", bacterial_infections_severe_recurrent_enc_id = '#{patient['encounter_id']}',
      bacterial_infections_severe_recurrent_v_date = DATE('#{patient_visit_date}')
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (bacterial_infections_severe_recurrent = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  bacterial_infections_severe_recurrent = NULL, bacterial_infections_severe_recurrent_enc_id = NULL,
bacterial_infections_severe_recurrent_v_date = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #end if

    when unspecified_stage_4_condition
      if patient['voided'].to_i == 0
        puts ".......... Updating record into flat_table1 (unspecified_stage_4_condition): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  unspecified_stage_4_condition = "Yes", unspecified_stage_4_condition_enc_id = '#{patient['encounter_id']}',
      unspecified_stage_4_condition_v_date = DATE('#{patient_visit_date}')
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (unspecified_stage_4_condition = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  unspecified_stage_4_condition = NULL, unspecified_stage_4_condition_enc_id = NULL, unspecified_stage_4_condition_v_date = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #end if

    when pnuemocystis_pnuemonia
      if patient['voided'].to_i == 0
        puts ".......... Updating record into flat_table1 (pnuemocystis_pnuemonia): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  pnuemocystis_pnuemonia = "Yes", pnuemocystis_pnuemonia_enc_id = '#{patient['encounter_id']}',
       pnuemocystis_pnuemonia_v_date = DATE('#{patient_visit_date}')
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (pnuemocystis_pnuemonia = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  pnuemocystis_pnuemonia = NULL, pnuemocystis_pnuemonia_enc_id = NULL,
pnuemocystis_pnuemonia_v_date = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #end if

    when disseminated_non_tuberculosis_mycobactierial_infection
      if patient['voided'].to_i == 0
        puts ".......... Updating record into flat_table1 (disseminated_non_tuberculosis_mycobacterial_infection): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  disseminated_non_tuberculosis_mycobacterial_infection = "Yes", disseminated_non_tuberculosis_mycobacterial_infection_enc_id = '#{patient['encounter_id']}',
      disseminated_non_tuberculosis_mycobacterial_infection_v_date = DATE('#{patient_visit_date}')
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (disseminated_non_tuberculosis_mycobacterial_infection = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  disseminated_non_tuberculosis_mycobacterial_infection = NULL, disseminated_non_tuberculosis_mycobacterial_infection_enc_id = NULL,
disseminated_non_tuberculosis_mycobacterial_infection_v_date= NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #end if

    when cryptosporidiosis
      if patient['voided'].to_i == 0
        puts ".......... Updating record into flat_table1 (cryptosporidiosis): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  cryptosporidiosis = "Yes", cryptosporidiosis_enc_id = '#{patient['encounter_id']}',
      cryptosporidiosis_v_date = DATE('#{patient_visit_date}')
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (cryptosporidiosis = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  cryptosporidiosis = NULL, cryptosporidiosis_enc_id = NULL,
cryptosporidiosis_v_date = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #end if

    when isosporiasis
      if patient['voided'].to_i == 0
        puts ".......... Updating record into flat_table1 (isosporiasis): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  isosporiasis = "Yes", isosporiasis_enc_id = '#{patient['encounter_id']}',
      isosporiasis_enc_id = DATE('#{patient_visit_date}')
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (isosporiasis = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  isosporiasis = NULL, isosporiasis_enc_id = NULL,
isosporiasis_enc_id = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #end if

    when symptomatic_hiv_asscoiated_nephropathy
      if patient['voided'].to_i == 0
        puts ".......... Updating record into flat_table1 (symptomatic_hiv_associated_nephropathy): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  symptomatic_hiv_associated_nephropathy = "Yes", symptomatic_hiv_associated_nephropathy_enc_id = '#{patient['encounter_id']}',
     symptomatic_hiv_associated_nephropathy_v_date = DATE('#{patient_visit_date}')
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (symptomatic_hiv_associated_nephropathy = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  symptomatic_hiv_associated_nephropathy = NULL, symptomatic_hiv_associated_nephropathy_enc_id = NULL,
symptomatic_hiv_associated_nephropathy_v_date = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #end if

    when chronic_herpes_simplex_infection
      if patient['voided'].to_i == 0
        puts ".......... Updating record into flat_table1 (chronic_herpes_simplex_infection): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  chronic_herpes_simplex_infection = "Yes", chronic_herpes_simplex_infection_enc_id = '#{patient['encounter_id']}',
     chronic_herpes_simplex_infection_v_date = DATE('#{patient_visit_date}')
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (chronic_herpes_simplex_infection = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  chronic_herpes_simplex_infection = NULL, chronic_herpes_simplex_infection_enc_id =
chronic_herpes_simplex_infection_v_date = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #end if

    when cytomegalovirus_infection
      if patient['voided'].to_i == 0
        puts ".......... Updating record into flat_table1 (cytomegalovirus_infection): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  cytomegalovirus_infection = "Yes", cytomegalovirus_infection_enc_id = '#{patient['encounter_id']}',
     cytomegalovirus_infection_v_date = DATE('#{patient_visit_date}')
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (cytomegalovirus_infection = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  cytomegalovirus_infection = NULL, cytomegalovirus_infection_enc_id = NULL,
cytomegalovirus_infection_v_date = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #end if

    when toxoplasomis_of_the_brain_1month
      if patient['voided'].to_i == 0
        puts ".......... Updating record into flat_table1 (toxoplasomis_of_the_brain_1month): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  toxoplasomis_of_the_brain_1month = "Yes", toxoplasomis_of_the_brain_1month_enc_id = '#{patient['encounter_id']}',
     toxoplasomis_of_the_brain_1month_v_date = DATE('#{patient_visit_date}')
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (toxoplasomis_of_the_brain_1month = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  toxoplasomis_of_the_brain_1month = NULL, toxoplasomis_of_the_brain_1month_enc_id = NULL,
toxoplasomis_of_the_brain_1month_v_date = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #end if

    when recto_vaginal_fitsula
      if patient['voided'].to_i == 0
        puts ".......... Updating record into flat_table1 (recto_vaginal_fitsula): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  recto_vaginal_fitsula = "Yes", recto_vaginal_fitsula_enc_id = '#{patient['encounter_id']}',
     recto_vaginal_fitsula_v_date = DATE('#{patient_visit_date}')
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (recto_vaginal_fitsula = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  recto_vaginal_fitsula = NULL, recto_vaginal_fitsula_enc_id = NULL,
recto_vaginal_fitsula_v_date = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #end if

    when mod_wght_loss_less_thanequal_to_10_perc
      if patient['voided'].to_i == 0
        puts ".......... Updating record into flat_table1 (moderate_weight_loss_less_than_or_equal_to_10_percent_unexpl): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  moderate_weight_loss_less_than_or_equal_to_10_percent_unexpl = "Yes", moderate_weight_loss_less_than_or_equal_to_10_unexpl_enc_id = '#{patient['encounter_id']}',
     moderate_weight_loss_less_than_or_equal_to_10_unexpl_v_date = DATE('#{patient_visit_date}')
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (moderate_weight_loss_less_than_or_equal_to_10_percent_unexpl = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  moderate_weight_loss_less_than_or_equal_to_10_percent_unexpl = NULL, moderate_weight_loss_less_than_or_equal_to_10_unexpl_enc_id = NULL,
moderate_weight_loss_less_than_or_equal_to_10_unexpl_v_date = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #end if

    when seborrhoeic_dermatitis
      if patient['voided'].to_i == 0
        puts ".......... Updating record into flat_table1 (seborrhoeic_dermatitis): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  seborrhoeic_dermatitis = "Yes", seborrhoeic_dermatitis_enc_id = '#{patient['encounter_id']}',
     seborrhoeic_dermatitis_v_date = DATE('#{patient_visit_date}')
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (seborrhoeic_dermatitis = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  seborrhoeic_dermatitis = NULL, seborrhoeic_dermatitis_enc_id = NULL,
seborrhoeic_dermatitis_v_date = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #end if

    when hepatitis_b_or_c_infection
      if patient['voided'].to_i == 0
        puts ".......... Updating record into flat_table1 (hepatitis_b_or_c_infection): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  hepatitis_b_or_c_infection = "Yes", hepatitis_b_or_c_infection_enc_id = '#{patient['encounter_id']}',
     hepatitis_b_or_c_infection_v_date = DATE('#{patient_visit_date}')
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (hepatitis_b_or_c_infection = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  hepatitis_b_or_c_infection = NULL, hepatitis_b_or_c_infection_enc_id = NULL,
hepatitis_b_or_c_infection_v_date = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #end if

    when kaposis_sarcoma
      if patient['voided'].to_i == 0
        puts ".......... Updating record into flat_table1 (kaposis_sarcoma): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  kaposis_sarcoma = "Yes", kaposis_sarcoma_enc_id = '#{patient['encounter_id']}', kaposis_sarcoma_v_date = DATE('#{patient_visit_date}')
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (kaposis_sarcoma = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  kaposis_sarcoma = NULL, kaposis_sarcoma_enc_id = NULL, kaposis_sarcoma_v_date = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #end if

    when non_typhoidal_salmonella_bacteraemia_recurrent
      if patient['voided'].to_i == 0
        puts ".......... Updating record into flat_table1 (non_typhoidal_salmonella_bacteraemia_recurrent): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  non_typhoidal_salmonella_bacteraemia_recurrent = "Yes", non_typhoidal_salmonella_bacteraemia_recurrent_enc_id = '#{patient['encounter_id']}',
    non_typhoidal_salmonella_bacteraemia_recurrent_v_date = DATE('#{patient_visit_date}')
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (non_typhoidal_salmonella_bacteraemia_recurrent = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  non_typhoidal_salmonella_bacteraemia_recurrent = NULL, non_typhoidal_salmonella_bacteraemia_recurrent_enc_id = NULL,
non_typhoidal_salmonella_bacteraemia_recurrent_v_date = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #end if

    when leishmaniasis_atypical_disseminated
      if patient['voided'].to_i == 0
        puts ".......... Updating record into flat_table1 (leishmaniasis_atypical_disseminated): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  leishmaniasis_atypical_disseminated = "Yes", leishmaniasis_atypical_disseminated_enc_id = '#{patient['encounter_id']}',
    leishmaniasis_atypical_disseminated_v_date = DATE('#{patient_visit_date}')
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (leishmaniasis_atypical_disseminated = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  leishmaniasis_atypical_disseminated = NULL, leishmaniasis_atypical_disseminated_enc_id = NULL,
leishmaniasis_atypical_disseminated_v_date = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #end if

    when cerebral_or_b_cell_non_hodgkin_lymphoma
      if patient['voided'].to_i == 0
        puts ".......... Updating record into flat_table1 (cerebral_or_b_cell_non_hodgkin_lymphoma): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  cerebral_or_b_cell_non_hodgkin_lymphoma = "Yes", cerebral_or_b_cell_non_hodgkin_lymphoma_enc_id = '#{patient['encounter_id']}',
    cerebral_or_b_cell_non_hodgkin_lymphoma_v_date = DATE('#{patient_visit_date}')
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (cerebral_or_b_cell_non_hodgkin_lymphoma = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  cerebral_or_b_cell_non_hodgkin_lymphoma = NULL, cerebral_or_b_cell_non_hodgkin_lymphoma_enc_id = NULL,
cerebral_or_b_cell_non_hodgkin_lymphoma_enc_id = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #end if

    when invasive_cancer_of_cervix
      if patient['voided'].to_i == 0
        puts ".......... Updating record into flat_table1 (invasive_cancer_of_cervix): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  invasive_cancer_of_cervix = "Yes", invasive_cancer_of_cervix_enc_id = '#{patient['encounter_id']}',
    invasive_cancer_of_cervix_v_date = DATE('#{patient_visit_date}')
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (invasive_cancer_of_cervix = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  invasive_cancer_of_cervix = NULL, invasive_cancer_of_cervix_enc_id = NULL, invasive_cancer_of_cervix_v_date = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #end if

    when cryptococcal_meningitis_or_other_eptb_cryptococcosis
      if patient['voided'].to_i == 0
        puts ".......... Updating record into flat_table1 (cryptococcal_meningitis_or_other_eptb_cryptococcosis): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  cryptococcal_meningitis_or_other_eptb_cryptococcosis = "Yes",
    cryptococcal_meningitis_or_other_eptb_cryptococcosis_v_date = DATE('#{patient_visit_date}'),
    cryptococcal_meningitis_or_other_eptb_cryptococcosis_enc_id = #{patient['encounter_id']}
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (cryptococcal_meningitis_or_other_eptb_cryptococcosis = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  cryptococcal_meningitis_or_other_eptb_cryptococcosis = NULL,
    cryptococcal_meningitis_or_other_eptb_cryptococcosis_v_date = NULL,
    cryptococcal_meningitis_or_other_eptb_cryptococcosis_enc_id = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #end if

    when severe_unexplained_wasting_malnutrition
      if patient['voided'].to_i == 0
        puts ".......... Updating record into flat_table1 (severe_unexplained_wasting_malnutrition): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  severe_unexplained_wasting_malnutrition = "Yes", severe_unexplained_wasting_malnutrition_v_date = DATE('#{patient_visit_date}'),
   severe_unexplained_wasting_malnutrition_enc_id = #{patient['encounter_id']}
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (severe_unexplained_wasting_malnutrition = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  severe_unexplained_wasting_malnutrition = NULL, severe_unexplained_wasting_malnutrition_v_date = NULL,
    severe_unexplained_wasting_malnutrition_enc_id = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #end if

    when diarrhoea_chronic_less_1_month_unexplained
      if patient['voided'].to_i == 0
        puts ".......... Updating record into flat_table1 (diarrhoea_chronic_less_1_month_unexplained): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  diarrhoea_chronic_less_1_month_unexplained = "Yes", diarrhoea_chronic_less_1_month_unexplained_v_date = DATE('#{patient_visit_date}'),
    diarrhoea_chronic_less_1_month_unexplained_enc_id = "#{patient['encounter_id']}"
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (diarrhoea_chronic_less_1_month_unexplained = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  diarrhoea_chronic_less_1_month_unexplained = NULL, diarrhoea_chronic_less_1_month_unexplained_v_date = NULL,
    diarrhoea_chronic_less_1_month_unexplained_enc_id = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #end if

    when moderate_weight_loss_10_unexplained
      if patient['voided'].to_i == 0
        puts ".......... Updating record into flat_table1 (moderate_weight_loss_10_unexplained): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  moderate_weight_loss_10_unexplained = "Yes", moderate_weight_loss_10_unexplained_v_date = DATE('#{patient_visit_date}'),
    moderate_weight_loss_10_unexplained_enc_id = "#{encounter_id}"
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (moderate_weight_loss_10_unexplained = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  moderate_weight_loss_10_unexplained = NULL, moderate_weight_loss_10_unexplained_v_date = NULL,
    moderate_weight_loss_10_unexplained_enc_id = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #end if

    when acute_necrotizing_ulcerative_stomatitis_gingivitis_or_period
      if patient['voided'].to_i == 0
        puts ".......... Updating record into flat_table1 (acute_necrotizing_ulcerative_stomatitis_gingivitis_or_period): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  acute_necrotizing_ulcerative_stomatitis_gingivitis_or_period = "Yes",
    acute_necrotizing_ulcerative_stomatitis_gingivitis_or_period_v_date = DATE('#{patient_visit_date}'),
    acute_necrotizing_ulcerative_stomatitis_gingivitis_or_period_enc_id = #{patient['encounter_id']}
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (acute_necrotizing_ulcerative_stomatitis_gingivitis_or_period = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  acute_necrotizing_ulcerative_stomatitis_gingivitis_or_period = NULL,
    acute_necrotizing_ulcerative_stomatitis_gingivitis_or_period_v_date = NULL,
    acute_necrotizing_ulcerative_stomatitis_gingivitis_or_period_enc_id = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #end if

    when moderate_unexplained_wasting_malnutrition
      if patient['voided'].to_i == 0
        puts ".......... Updating record into flat_table1 (moderate_unexplained_wasting_malnutrition): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  moderate_unexplained_wasting_malnutrition = "Yes", moderate_unexplained_wasting_malnutrition_v_date = DATE('#{patient_visit_date}'),
    moderate_unexplained_wasting_malnutrition_enc_id = #{patient['encounter_id']}
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (moderate_unexplained_wasting_malnutrition = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  moderate_unexplained_wasting_malnutrition = NULL, moderate_unexplained_wasting_malnutrition_v_date = NULL,
    moderate_unexplained_wasting_malnutrition_enc_id = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #end if

    when diarrhoea_persistent_unexplained_14_days_or_more
      if patient['voided'].to_i == 0
        puts ".......... Updating record into flat_table1 (diarrhoea_persistent_unexplained_14_days_or_more): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  diarrhoea_persistent_unexplained_14_days_or_more = "Yes", diarrhoea_persistent_unexplained_14_days_or_more_v_date = DATE('#{patient_visit_date}'),
    diarrhoea_persistent_unexplained_14_days_or_more_enc_id = #{patient['encounter_id']}
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (diarrhoea_persistent_unexplained_14_days_or_more = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  diarrhoea_persistent_unexplained_14_days_or_more = NULL, diarrhoea_persistent_unexplained_14_days_or_more_v_date = NULL,
    diarrhoea_persistent_unexplained_14_days_or_more_enc_id = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #end if

    when acute_ulcerative_mouth_infections
      if patient['voided'].to_i == 0
        puts ".......... Updating record into flat_table1 (acute_ulcerative_mouth_infections): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  acute_ulcerative_mouth_infections = "Yes", acute_ulcerative_mouth_infections_v_date = DATE('#{patient_visit_date}'),
    acute_ulcerative_mouth_infections_enc_id = "#{patient['encounter_id']}"
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (acute_ulcerative_mouth_infections = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  acute_ulcerative_mouth_infections = NULL, acute_ulcerative_mouth_infections_v_date = NULL, acute_ulcerative_mouth_infections_enc_id = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #end if

    when anaemia_unexplained_8_g_dl
      if patient['voided'].to_i == 0
        puts ".......... Updating record into flat_table1 (anaemia_unexplained_8_g_dl): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  anaemia_unexplained_8_g_dl = "Yes", anaemia_unexplained_8_g_dl_v_date = DATE('#{patient_visit_date}'), anaemia_unexplained_8_g_dl_enc_id = #{patient['encounter_id']}
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (anaemia_unexplained_8_g_dl = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  anaemia_unexplained_8_g_dl = NULL, anaemia_unexplained_8_g_dl_v_date = NULL, anaemia_unexplained_8_g_dl_enc_id = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #end if

    when atypical_mycobacteriosis_disseminated_or_lung
      if patient['voided'].to_i == 0
        puts ".......... Updating record into flat_table1 (atypical_mycobacteriosis_disseminated_or_lung): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  atypical_mycobacteriosis_disseminated_or_lung = "Yes", atypical_mycobacteriosis_disseminated_or_lung_v_date = DATE('#{patient_visit_date}'),
    atypical_mycobacteriosis_disseminated_or_lung_enc_id = #{patient['encounter_id']}
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (atypical_mycobacteriosis_disseminated_or_lung = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  atypical_mycobacteriosis_disseminated_or_lung = NULL, atypical_mycobacteriosis_disseminated_or_lung_v_date = NULL,
    atypical_mycobacteriosis_disseminated_or_lung_enc_id = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #end if

    when bacterial_infections_sev_recurrent_excluding_pneumonia
      if patient['voided'].to_i == 0
        puts ".......... Updating record into flat_table1 (bacterial_infections_sev_recurrent_excluding_pneumonia): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  bacterial_infections_sev_recurrent_excluding_pneumonia = "Yes", bacterial_infections_sev_recurrent_excluding_pneumonia_v_date = DATE('#{patient_visit_date}'),
    bacterial_infections_sev_recurrent_excluding_pneumonia_enc_id = #{patient['encounter_id']}
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      else
        puts ".......... Updating record into flat_table1 (bacterial_infections_sev_recurrent_excluding_pneumonia = NULL): #{patient['person_id']}"
        Connection.execute <<EOF
UPDATE flat_table1
SET  bacterial_infections_sev_recurrent_excluding_pneumonia = NULL, bacterial_infections_sev_recurrent_excluding_pneumonia_v_date = NULL,
    bacterial_infections_sev_recurrent_excluding_pneumonia_enc_id = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
      end #end if

    when cancer_cervix
    if patient['voided'].to_i == 0
      puts ".......... Updating record into flat_table1 (cancer_cervix): #{patient['person_id']}"
      Connection.execute <<EOF
UPDATE flat_table1
SET  cancer_cervix = "Yes", cancer_cervix_v_date = DATE('#{patient_visit_date}'), cancer_cervix_enc_id = #{patient['encounter_id']}
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
    else
      puts ".......... Updating record into flat_table1 (cancer_cervix = NULL): #{patient['person_id']}"
      Connection.execute <<EOF
UPDATE flat_table1
SET  cancer_cervix = NULL, cancer_cervix_v_date = NULL, cancer_cervix_enc_id = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
    end #end if

  when chronic_herpes_simplex_infection_genital
    if patient['voided'].to_i == 0
      puts ".......... Updating record into flat_table1 (chronic_herpes_simplex_infection_genital): #{patient['person_id']}"
      Connection.execute <<EOF
UPDATE flat_table1
SET  chronic_herpes_simplex_infection_genital = "Yes", chronic_herpes_simplex_infection_genital_v_date = DATE('#{patient_visit_date}'),
    chronic_herpes_simplex_infection_genital_enc_id = #{patient['encounter_id']}"
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
    else
      puts ".......... Updating record into flat_table1 (chronic_herpes_simplex_infection_genital = NULL): #{patient['person_id']}"
      Connection.execute <<EOF
UPDATE flat_table1
SET  chronic_herpes_simplex_infection_genital = NULL, chronic_herpes_simplex_infection_genital_v_date = NULL,
chronic_herpes_simplex_infection_genital_enc_id = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
    end #end if

  when cryptosporidiosis_chronic_with_diarrhoea
    if patient['voided'].to_i == 0
      puts ".......... Updating record into flat_table1 (cryptosporidiosis_chronic_with_diarrhoea): #{patient['person_id']}"
      Connection.execute <<EOF
UPDATE flat_table1
SET  cryptosporidiosis_chronic_with_diarrhoea = "Yes", cryptosporidiosis_chronic_with_diarrhoea_v_date = DATE('#{patient_visit_date}'),
    cryptosporidiosis_chronic_with_diarrhoea_enc_id = #{patient['encounter_id']}
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
    else
      puts ".......... Updating record into flat_table1 (cryptosporidiosis_chronic_with_diarrhoea = NULL): #{patient['person_id']}"
      Connection.execute <<EOF
UPDATE flat_table1
SET  cryptosporidiosis_chronic_with_diarrhoea = NULL, cryptosporidiosis_chronic_with_diarrhoea_v_date = NULL, cryptosporidiosis_chronic_with_diarrhoea_enc_id = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
    end #end if

  when cytomegalovirus_infection_retinitis_or_other_organ
    if patient['voided'].to_i == 0
      puts ".......... Updating record into flat_table1 (cytomegalovirus_infection_retinitis_or_other_organ): #{patient['person_id']}"
      Connection.execute <<EOF
UPDATE flat_table1
SET  cytomegalovirus_infection_retinitis_or_other_organ = "Yes",
    cytomegalovirus_infection_retinitis_or_other_organ_v_date = DATE('#{patient_visit_date}'),
    cytomegalovirus_infection_retinitis_or_other_organ_enc_id = #{patient['encounter_id']}
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
    else
      puts ".......... Updating record into flat_table1 (cytomegalovirus_infection_retinitis_or_other_organ = NULL): #{patient['person_id']}"
      Connection.execute <<EOF
UPDATE flat_table1
SET  cytomegalovirus_infection_retinitis_or_other_organ = NULL, cytomegalovirus_infection_retinitis_or_other_organ_v_date = NULL,
    cytomegalovirus_infection_retinitis_or_other_organ_enc_id = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
    end #end if

  when cytomegalovirus_of_an_organ_other_than_liver
    if patient['voided'].to_i == 0
      puts ".......... Updating record into flat_table1 (cytomegalovirus_of_an_organ_other_than_liver): #{patient['person_id']}"
      Connection.execute <<EOF
UPDATE flat_table1
SET  cytomegalovirus_of_an_organ_other_than_liver = "Yes", cytomegalovirus_of_an_organ_other_than_liver_v_date = DATE('#{patient_visit_date}'),
    cytomegalovirus_of_an_organ_other_than_liver_enc_id = #{patient['encounter_id']}
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
    else
      puts ".......... Updating record into flat_table1 (cytomegalovirus_of_an_organ_other_than_liver = NULL): #{patient['person_id']}"
      Connection.execute <<EOF
UPDATE flat_table1
SET  cytomegalovirus_of_an_organ_other_than_liver = NULL, cytomegalovirus_of_an_organ_other_than_liver_v_date = NULL,
    cytomegalovirus_of_an_organ_other_than_liver_enc_id = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
    end #end if

  when fungal_nail_infections
    if patient['voided'].to_i == 0
      puts ".......... Updating record into flat_table1 (fungal_nail_infections): #{patient['person_id']}"
      Connection.execute <<EOF
UPDATE flat_table1
SET  fungal_nail_infections = "Yes", fungal_nail_infections_v_date = DATE('#{patient_visit_date}'), fungal_nail_infections_enc_id = #{patient['encounter_id']}
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
    else
      puts ".......... Updating record into flat_table1 (fungal_nail_infections = NULL): #{patient['person_id']}"
      Connection.execute <<EOF
UPDATE flat_table1
SET  fungal_nail_infections = NULL, fungal_nail_infections_v_date = NULL, fungal_nail_infections_enc_id = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
    end #end if

  when herpes_simplex_infection_mucocutaneous_visceral
    if patient['voided'].to_i == 0
      puts ".......... Updating record into flat_table1 (herpes_simplex_infection_mucocutaneous_visceral): #{patient['person_id']}"
      Connection.execute <<EOF
UPDATE flat_table1
SET  herpes_simplex_infection_mucocutaneous_visceral = "Yes",
    herpes_simplex_infection_mucocutaneous_visceral_v_date = DATE('#{patient_visit_date}'),
    herpes_simplex_infection_mucocutaneous_visceral_enc_id = #{patient['encounter_id']}
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
    else
      puts ".......... Updating record into flat_table1 (herpes_simplex_infection_mucocutaneous_visceral = NULL): #{patient['person_id']}"
      Connection.execute <<EOF
UPDATE flat_table1
SET  herpes_simplex_infection_mucocutaneous_visceral = NULL, herpes_simplex_infection_mucocutaneous_visceral_v_date = NULL,
    herpes_simplex_infection_mucocutaneous_visceral_enc_id = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
    end #end if

  when hiv_associated_cardiomyopathy
    if patient['voided'].to_i == 0
      puts ".......... Updating record into flat_table1 (hiv_associated_cardiomyopathy): #{patient['person_id']}"
      Connection.execute <<EOF
UPDATE flat_table1
SET  hiv_associated_cardiomyopathy = "Yes", hiv_associated_cardiomyopathy_v_date = DATE('#{patient_visit_date}'),
    hiv_associated_cardiomyopathy_enc_id = #{patient['encounter_id']}
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
    else
      puts ".......... Updating record into flat_table1 (hiv_associated_cardiomyopathy = NULL): #{patient['person_id']}"
      Connection.execute <<EOF
UPDATE flat_table1
SET  hiv_associated_cardiomyopathy = NULL, hiv_associated_cardiomyopathy_v_date = NULL, hiv_associated_cardiomyopathy_enc_id = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
    end #end if

  when hiv_associated_nephropathy
    if patient['voided'].to_i == 0
      puts ".......... Updating record into flat_table1 (hiv_associated_nephropathy): #{patient['person_id']}"
      Connection.execute <<EOF
UPDATE flat_table1
SET symptomatic_hiv_associated_nephropathy = "#{answer}", symptomatic_hiv_associated_nephropathy_enc_id = '#{patient['encounter_id']}',
     symptomatic_hiv_associated_nephropathy_v_date = DATE('#{patient_visit_date}')
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
    else
      puts ".......... Updating record into flat_table1 (hiv_associated_nephropathy = NULL): #{patient['person_id']}"
      Connection.execute <<EOF
UPDATE flat_table1
SET symptomatic_hiv_associated_nephropathy = NULL, symptomatic_hiv_associated_nephropathy_enc_id = NULL,
symptomatic_hiv_associated_nephropathy_v_date = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
    end #end if

  when invasive_cancer_cervix
    if patient['voided'].to_i == 0
      puts ".......... Updating record into flat_table1 (invasive_cancer_cervix): #{patient['person_id']}"
      Connection.execute <<EOF
UPDATE flat_table1
SET  invasive_cancer_cervix = "Yes", invasive_cancer_cervix_v_date = DATE('#{patient_visit_date}'), invasive_cancer_cervix_enc_id = "#{patient['encounter_id']}"
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
    else
      puts ".......... Updating record into flat_table1 (invasive_cancer_cervix = NULL): #{patient['person_id']}"
      Connection.execute <<EOF
UPDATE flat_table1
SET  invasive_cancer_cervix = NULL, invasive_cancer_cervix_v_date = NULL, invasive_cancer_cervix_enc_id = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
    end #end if

  when isosporiasis_1_month
    if patient['voided'].to_i == 0
      puts ".......... Updating record into flat_table1 (isosporiasis_1_month): #{patient['person_id']}"
      Connection.execute <<EOF
UPDATE flat_table1
SET  isosporiasis_1_month = "Yes", isosporiasis_1_month_v_date = DATE('#{patient_visit_date}'), isosporiasis_1_month_enc_id = "#{patient['encounter_id']}"
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
    else
      puts ".......... Updating record into flat_table1 (isosporiasis_1_month = NULL): #{patient['person_id']}"
      Connection.execute <<EOF
UPDATE flat_table1
SET  isosporiasis_1_month = NULL, isosporiasis_1_month_v_date = NULL, isosporiasis_1_month_enc_id = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
    end #end if

  when minor_mucocutaneous_manifestations_seborrheic_dermatitis
    if patient['voided'].to_i == 0
      puts ".......... Updating record into flat_table1 (minor_mucocutaneous_manifestations_seborrheic_dermatitis): #{patient['person_id']}"
      Connection.execute <<EOF
UPDATE flat_table1
SET  minor_mucocutaneous_manifestations_seborrheic_dermatitis = "Yes",
    minor_mucocutaneous_manifestations_seborrheic_dermatitis_v_date = DATE('#{patient_visit_date}'),
    minor_mucocutaneous_manifestations_seborrheic_dermatitis_enc_id = "#{patient['encounter_id']}"
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
    else
      puts ".......... Updating record into flat_table1 (minor_mucocutaneous_manifestations_seborrheic_dermatitis = NULL): #{patient['person_id']}"
      Connection.execute <<EOF
UPDATE flat_table1
SET  minor_mucocutaneous_manifestations_seborrheic_dermatitis = NULL,
    minor_mucocutaneous_manifestations_seborrheic_dermatitis_v_date = NULL,
    minor_mucocutaneous_manifestations_seborrheic_dermatitis_enc_id = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
    end #end if

  when moderate_unexplained_malnutrition
    if patient['voided'].to_i == 0
      puts ".......... Updating record into flat_table1 (moderate_unexplained_malnutrition): #{patient['person_id']}"
      Connection.execute <<EOF
UPDATE flat_table1
SET  moderate_unexplained_malnutrition = "Yes", moderate_unexplained_malnutrition_v_date = DATE('#{patient_visit_date}'),
    moderate_unexplained_malnutrition_enc_id = "#{patient['encounter_id']}"
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
    else
      puts ".......... Updating record into flat_table1 (moderate_unexplained_malnutrition = NULL): #{patient['person_id']}"
      Connection.execute <<EOF
UPDATE flat_table1
SET  moderate_unexplained_malnutrition = NULL, moderate_unexplained_malnutrition_v_date = NULL, moderate_unexplained_malnutrition_enc_id = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
    end #end if

  when molluscum_contagiosum_extensive
    if patient['voided'].to_i == 0
      puts ".......... Updating record into flat_table1 (molluscum_contagiosum_extensive): #{patient['person_id']}"
      Connection.execute <<EOF
UPDATE flat_table1
SET  molluscum_contagiosum_extensive = "Yes", molluscum_contagiosum_extensive_v_date = DATE('#{patient_visit_date}'),
     molluscum_contagiosum_extensive_enc_id = #{patient['encounter_id']}
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
    else
      puts ".......... Updating record into flat_table1 (molluscum_contagiosum_extensive = NULL): #{patient['person_id']}"
      Connection.execute <<EOF
UPDATE flat_table1
SET  molluscum_contagiosum_extensive = NULL, molluscum_contagiosum_extensive_v_date = NULL, molluscum_contagiosum_extensive_enc_id = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
    end #end if

  when oral_candidiasis_from_age_2_months
    if patient['voided'].to_i == 0
      puts ".......... Updating record into flat_table1 (oral_candidiasis_from_age_2_months): #{patient['person_id']}"
      Connection.execute <<EOF
UPDATE flat_table1
SET  oral_candidiasis_from_age_2_months = "Yes", oral_candidiasis_from_age_2_months_v_date = DATE('#{patient_visit_date}'),
    oral_candidiasis_from_age_2_months_enc_id = #{patient['encounter_id']}
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
    else
      puts ".......... Updating record into flat_table1 (oral_candidiasis_from_age_2_months = NULL): #{patient['person_id']}"
      Connection.execute <<EOF
UPDATE flat_table1
SET  oral_candidiasis_from_age_2_months = NULL, oral_candidiasis_from_age_2_months_v_date = NULL, oral_candidiasis_from_age_2_months_enc_id = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
    end #end if

  when oral_thrush
    if patient['voided'].to_i == 0
      puts ".......... Updating record into flat_table1 (oral_thrush): #{patient['person_id']}"
      Connection.execute <<EOF
UPDATE flat_table1
SET  oral_thrush = "Yes", oral_thrush_v_date = DATE('#{patient_visit_date}'), oral_thrush_enc_id = "#{patient['encounter_id']}"
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
    else
      puts ".......... Updating record into flat_table1 (oral_thrush = NULL): #{patient['person_id']}"
      Connection.execute <<EOF
UPDATE flat_table1
SET  oral_thrush = NULL, oral_thrush_v_date = NULL, oral_thrush_enc_id = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
    end #end if

  when pneumocystis_carinii_pneumonia
    if patient['voided'].to_i == 0
      puts ".......... Updating record into flat_table1 (pneumocystis_carinii_pneumonia): #{patient['person_id']}"
      Connection.execute <<EOF
UPDATE flat_table1
SET  pneumocystis_carinii_pneumonia = "Yes", , pneumocystis_carinii_pneumonia_v_date = DATE('#{patient_visit_date}'),
     pneumocystis_carinii_pneumonia_enc_id = #{patient['encounter_id']}
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
    else
      puts ".......... Updating record into flat_table1 (pneumocystis_carinii_pneumonia = NULL): #{patient['person_id']}"
      Connection.execute <<EOF
UPDATE flat_table1
SET  pneumocystis_carinii_pneumonia = NULL, pneumocystis_carinii_pneumonia_v_date = NULL, pneumocystis_carinii_pneumonia_enc_id = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
    end #end if

  when pneumonia_severe
    if patient['voided'].to_i == 0
      puts ".......... Updating record into flat_table1 (pneumonia_severe): #{patient['person_id']}"
      Connection.execute <<EOF
UPDATE flat_table1
SET  pneumonia_severe = "Yes", pneumonia_severe_v_date = DATE('#{patient_visit_date}'), pneumonia_severe_enc_id = #{patient['encounter_id']}
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
    else
      puts ".......... Updating record into flat_table1 (pneumonia_severe = NULL): #{patient['person_id']}"
      Connection.execute <<EOF
UPDATE flat_table1
SET  pneumonia_severe = NULL, pneumonia_severe_v_date = NULL, pneumonia_severe_enc_id = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
    end #end if

  when recurrent_bacteraemia_or_sepsis_with_nts
    if patient['voided'].to_i == 0
      puts ".......... Updating record into flat_table1 (recurrent_bacteraemia_or_sepsis_with_nts): #{patient['person_id']}"
      Connection.execute <<EOF
UPDATE flat_table1
SET  recurrent_bacteraemia_or_sepsis_with_nts = "Yes",
    recurrent_bacteraemia_or_sepsis_with_nts_v_date = DATE('#{patient_visit_date}'),
    recurrent_bacteraemia_or_sepsis_with_nts_enc_id = "#{patient['encounter_id']}"
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
    else
      puts ".......... Updating record into flat_table1 (recurrent_bacteraemia_or_sepsis_with_nts = NULL): #{patient['person_id']}"
      Connection.execute <<EOF
UPDATE flat_table1
SET  recurrent_bacteraemia_or_sepsis_with_nts = NULL, recurrent_bacteraemia_or_sepsis_with_nts_v_date = NULL, recurrent_bacteraemia_or_sepsis_with_nts_enc_id = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
    end #end if

  when recurrent_severe_presumed_pneumonia
    if patient['voided'].to_i == 0
      puts ".......... Updating record into flat_table1 (recurrent_severe_presumed_pneumonia): #{patient['person_id']}"
      Connection.execute <<EOF
UPDATE flat_table1
SET  recurrent_severe_presumed_pneumonia = "Yes",
    recurrent_severe_presumed_pneumonia_v_date = DATE('#{patient_visit_date}'),
    recurrent_severe_presumed_pneumonia_enc_id = "#{patient['encounter_id']}"
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
    else
      puts ".......... Updating record into flat_table1 (recurrent_severe_presumed_pneumonia = NULL): #{patient['person_id']}"
      Connection.execute <<EOF
UPDATE flat_table1
SET  recurrent_severe_presumed_pneumonia = NULL,
    recurrent_severe_presumed_pneumonia_v_date = NULL,
    recurrent_severe_presumed_pneumonia_enc_id = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
    end #end if

  when recurrent_upper_respiratory_tract_bac_sinusitis
    if patient['voided'].to_i == 0
      puts ".......... Updating record into flat_table1 (recurrent_upper_respiratory_tract_bac_sinusitis): #{patient['person_id']}"
      Connection.execute <<EOF
UPDATE flat_table1
SET  recurrent_upper_respiratory_tract_bac_sinusitis = "Yes",
    recurrent_upper_respiratory_tract_bac_sinusitis_v_date = DATE('#{patient_visit_date}'),
    recurrent_upper_respiratory_tract_bac_sinusitis_enc_id = #{patient['encounter_id']}
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
    else
      puts ".......... Updating record into flat_table1 (recurrent_upper_respiratory_tract_bac_sinusitis = NULL): #{patient['person_id']}"
      Connection.execute <<EOF
UPDATE flat_table1
SET  recurrent_upper_respiratory_tract_bac_sinusitis = NULL,
    recurrent_upper_respiratory_tract_bac_sinusitis_v_date = NULL,
    recurrent_upper_respiratory_tract_bac_sinusitis_enc_id = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
    end #end if

  when sepsis_severe
    if patient['voided'].to_i == 0
      puts ".......... Updating record into flat_table1 (sepsis_severe): #{patient['person_id']}"
      Connection.execute <<EOF
UPDATE flat_table1
SET  sepsis_severe = "Yes", sepsis_severe_v_date = DATE('#{patient_visit_date}'), sepsis_severe_enc_id = #{patient['encounter_id']}
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
    else
      puts ".......... Updating record into flat_table1 (sepsis_severe = NULL): #{patient['person_id']}"
      Connection.execute <<EOF
UPDATE flat_table1
SET  sepsis_severe = NULL, sepsis_severe_v_date = NULL, sepsis_severe_enc_id = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
    end #end if

  when unexplained_anaemia_neutropenia_or_thrombocytopenia
    if patient['voided'].to_i == 0
      puts ".......... Updating record into flat_table1 (unexplained_anaemia_neutropenia_or_thrombocytopenia): #{patient['person_id']}"
      Connection.execute <<EOF
UPDATE flat_table1
SET  unexplained_anaemia_neutropenia_or_thrombocytopenia = "Yes",
    unexplained_anaemia_neutropenia_or_thrombocytopenia_v_date = DATE('#{patient_visit_date}'),
    unexplained_anaemia_neutropenia_or_thrombocytopenia_enc_id = "#{patient['encounter_id']}"
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
    else
      puts ".......... Updating record into flat_table1 (unexplained_anaemia_neutropenia_or_thrombocytopenia = NULL): #{patient['person_id']}"
      Connection.execute <<EOF
UPDATE flat_table1
SET  unexplained_anaemia_neutropenia_or_thrombocytopenia = NULL,
    unexplained_anaemia_neutropenia_or_thrombocytopenia_v_date = NULL,
    unexplained_anaemia_neutropenia_or_thrombocytopenia_enc_id = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
    end #end if

  when visceral_leishmaniasis
  if patient['voided'].to_i == 0
    puts ".......... Updating record into flat_table1 (visceral_leishmaniasis): #{patient['person_id']}"
    Connection.execute <<EOF
UPDATE flat_table1
SET  visceral_leishmaniasis = "Yes", visceral_leishmaniasis_v_date = DATE('#{patient_visit_date}'), visceral_leishmaniasis_enc_id = "#{patient['encounter_id']}"
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
  else
    puts ".......... Updating record into flat_table1 (visceral_leishmaniasis = NULL): #{patient['person_id']}"
    Connection.execute <<EOF
UPDATE flat_table1
SET  visceral_leishmaniasis = NULL, visceral_leishmaniasis_v_date = NULL, visceral_leishmaniasis_enc_id = NULL
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
  end #end if

else
    if patient['voided'].to_i == 0
          value_coded = patient['value_coded']
          answer_record = Connection.select_one("SELECT concept_name.name FROM concept_name
                            LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                        WHERE concept.concept_id = '#{value_coded}' AND name <> ' ' AND voided = 0 AND retired = 0 LIMIT 1")

          answer = answer_record['name']

          puts "........... Updating record into flat_table1 who_stages_criteria_present = #{answer}): #{patient['person_id']}"
          Connection.execute <<EOF
UPDATE flat_table1
SET who_stages_criteria_present = "#{answer}", who_stages_criteria_present_v_date = DATE('#{patient_visit_date}'), who_stages_criteria_present_enc_id = "#{patient['encounter_id']}"
WHERE flat_table1.patient_id = #{patient['person_id']};
EOF
        else
          puts "........... Updating record into flat_table1 who_stages_criteria_present: #{patient['person_id']}"
          Connection.execute <<EOF
UPDATE flat_table1
SET  who_stages_criteria_present = NULL, who_stages_criteria_present_v_date = NULL, who_stages_criteria_present_enc_id = NULL
WHERE flat_table1.patient_id = #{patient['person_id']} ;
EOF
        end #voided
end #end case

  end #patient['concept_id']

  end #patient_obs

end #process_hiv_staging_obs

def process_hiv_clinic_consultation_obs(encounter, visit)
  #answer concepts yes..no..unknown
  yes_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
        LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
WHERE  name = 'Yes' AND voided = 0 AND retired = 0  ")
  yes_answer = yes_record['concept_id']

  no_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
        LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
WHERE  name = 'No' AND voided = 0 AND retired = 0 LIMIT 1")
  no_answer = no_record['concept_id']

  unknown_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
        LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
WHERE  name = 'Unknown' AND voided = 0 AND retired = 0 LIMIT 1")
  unknown_answer = unknown_record['concept_id']

  #patient pregnant concepts
  patient_pregnant_record1 = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
WHERE  name = 'Is patient pregnant?' AND voided = 0 AND retired = 0 LIMIT 1")
  patient_pregnant1 = patient_pregnant_record1['concept_id']

  patient_pregnant_record2 = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
WHERE  name = 'Patient pregnant' AND voided = 0 AND retired = 0 LIMIT 1")
  patient_pregnant2 = patient_pregnant_record2['concept_id']

  #breastfeeding concept
  breastfeeding_record1 = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
        LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
    WHERE  name = 'Breastfeeding' AND voided = 0 AND retired = 0")
  patient_breastfeeding1 = breastfeeding_record1['concept_id']

  breastfeeding_record2 = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
        LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
    WHERE  name = 'Is patient breast feeding?' AND voided = 0 AND retired = 0")
  patient_breastfeeding2 = breastfeeding_record2['concept_id']

  #family planning concepts
  family_planning_method_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
      LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
WHERE  name = 'Family planning, action to take' AND voided = 0 AND retired = 0 LIMIT 1")
  family_planning_method = family_planning_method_record['concept_id']

  currently_using_family_planning_method_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
      LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
WHERE  name = 'Currently using family planning method' AND voided = 0 AND retired = 0 LIMIT 1")
  currently_using_family_planning_method = currently_using_family_planning_method_record['concept_id']

  method_of_family_planning_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
      LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
WHERE  name = 'Method of family planning' AND voided = 0 AND retired = 0 LIMIT 1")
  method_of_family_planning = method_of_family_planning_record['concept_id']

  family_planning_method_oral_contraceptive_pills_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
      LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
WHERE  name = 'Oral contraception' AND voided = 0 AND retired = 0 LIMIT 1")
  family_planning_method_oral_contraceptive_pills = family_planning_method_oral_contraceptive_pills_record['concept_id']

  family_planning_method_depo_provera_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
      LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
WHERE  name = 'Depo-provera' AND voided = 0 AND retired = 0 LIMIT 1")
  family_planning_method_depo_provera = family_planning_method_depo_provera_record['concept_id']

  family_planning_method_intrauterine_contraception_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
      LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
WHERE  name = 'Intrauterine device' AND voided = 0 AND retired = 0 LIMIT 1")
  family_planning_method_intrauterine_contraception = family_planning_method_intrauterine_contraception_record['concept_id']

  family_planning_method_contraceptive_implant_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
      LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
WHERE  name = 'Contraceptive implant' AND voided = 0 AND retired = 0 LIMIT 1")
  family_planning_method_contraceptive_implant = family_planning_method_contraceptive_implant_record['concept_id']

  family_planning_method_male_condoms_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
      LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
WHERE  name = 'Male condoms' AND voided = 0 AND retired = 0 LIMIT 1")
  family_planning_method_male_condoms = family_planning_method_male_condoms_record['concept_id']

  family_planning_method_female_condoms_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
      LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
WHERE  name = 'Female condoms' AND voided = 0 AND retired = 0 LIMIT 1")
  family_planning_method_female_condoms = family_planning_method_female_condoms_record['concept_id']

  family_planning_method_rythm_method_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
      LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
WHERE  name = 'Rythm method' AND voided = 0 AND retired = 0 LIMIT 1")
  family_planning_method_rythm_method = family_planning_method_rythm_method_record['concept_id']

  family_planning_method_withdrawal_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
      LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
WHERE  name = 'Withdrawal method' AND voided = 0 AND retired = 0 LIMIT 1")
  family_planning_method_withdrawal = family_planning_method_withdrawal_record['concept_id']

  family_planning_method_abstinence_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
      LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
WHERE  name = 'Abstinence' AND voided = 0 AND retired = 0 LIMIT 1")
  family_planning_method_abstinence = family_planning_method_abstinence_record['concept_id']

  family_planning_method_tubal_ligation_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
      LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
WHERE  name = 'Tubal ligation' AND voided = 0 AND retired = 0 LIMIT 1")
  family_planning_method_tubal_ligation = family_planning_method_tubal_ligation_record['concept_id']

  family_planning_method_vasectomy_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
      LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
WHERE  name = 'Vasectomy' AND voided = 0 AND retired = 0 LIMIT 1")
  family_planning_method_vasectomy = family_planning_method_vasectomy_record['concept_id']

  family_planning_method_emergency_contraception_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
      LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
WHERE  name = 'Emergency contraception' AND voided = 0 AND retired = 0 LIMIT 1")
  family_planning_method_emergency_contraception = family_planning_method_emergency_contraception_record['concept_id']

  #symptom present/ drug_induced and malawi_art_side_effects or side_effects
  symptom_present_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
      LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
WHERE  name = 'Symptom present' AND voided = 0 AND retired = 0 LIMIT 1")
  symptom_present = symptom_present_record['concept_id']

  drug_induced_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
      LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
WHERE  name = 'Drug induced' AND voided = 0 AND retired = 0 LIMIT 1")
  drug_induced = drug_induced_record['concept_id']

  malawi_art_side_effects_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
      LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
WHERE  name = 'Malawi ART side effects' AND voided = 0 AND retired = 0 LIMIT 1")
  malawi_art_side_effects = malawi_art_side_effects_record['concept_id']

  abdominal_pain_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
      LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
WHERE  name = 'Abdominal pain' AND voided = 0 AND retired = 0 LIMIT 1")
  abdominal_pain = abdominal_pain_record['concept_id'].to_i

  anemia_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
      LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
WHERE  name = 'Anemia' AND voided = 0 AND retired = 0 LIMIT 1")
  anemia = anemia_record['concept_id'].to_i

  anorexia_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
WHERE  name = 'Anorexia' AND voided = 0 AND retired = 0 LIMIT 1")
  anorexia = anorexia_record['concept_id'].to_i

  blurry_vision_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
WHERE  name = 'Blurry vision' AND voided = 0 AND retired = 0 LIMIT 1")
  blurry_vision = blurry_vision_record['concept_id'].to_i

  cough_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
WHERE  name = 'Cough' AND voided = 0 AND retired = 0 LIMIT 1")
  cough = cough_record['concept_id'].to_i

  diarrhea_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
      LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
WHERE  name = 'Diarrhea' AND voided = 0 AND retired = 0 LIMIT 1")
  diarrhea = diarrhea_record['concept_id'].to_i

  diziness_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
WHERE  name = 'Dizziness' AND voided = 0 AND retired = 0 LIMIT 1")
  diziness = diziness_record['concept_id'].to_i

  fever_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
      LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
WHERE  name = 'fever' AND voided = 0 AND retired = 0 LIMIT 1")
  fever = fever_record['concept_id'].to_i

  gynaecomastia_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
      LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
WHERE  name = 'Gynaecomastia' AND voided = 0 AND retired = 0 LIMIT 1")
  gynaecomastia = gynaecomastia_record['concept_id'].to_i

  hepatitis_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
WHERE  name = 'Hepatitis' AND voided = 0 AND retired = 0 LIMIT 1")
  hepatitis = hepatitis_record['concept_id'].to_i

  jaundice_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
      LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
WHERE  name = 'Jaundice' AND voided = 0 AND retired = 0 LIMIT 1")
  jaundice = jaundice_record['concept_id'].to_i

  kidney_failure_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
      LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
WHERE  name = 'Kidney failure' AND voided = 0 AND retired = 0 LIMIT 1")
  kidney_failure = kidney_failure_record['concept_id'].to_i

  lactic_acidosis_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
WHERE  name = 'Lactic acidosis' AND voided = 0 AND retired = 0 LIMIT 1")
  lactic_acidosis = lactic_acidosis_record['concept_id'].to_i

  leg_pain_numbness_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
      LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
WHERE  name = 'Leg pain / numbness' AND voided = 0 AND retired = 0 LIMIT 1")
  leg_pain_numbness = leg_pain_numbness_record['concept_id'].to_i

  lipodystrophy_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
      LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
WHERE  name = 'Lipodystrophy' AND voided = 0 AND retired = 0 LIMIT 1")
  lipodystrophy = lipodystrophy_record['concept_id'].to_i

  nightmares_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
       LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
WHERE name = 'Nightmares' AND voided = 0 AND retired = 0 ORDER BY concept_name.concept_id DESC ")
  nightmares = nightmares_record['concept_id'].to_i

  symptom_no_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
WHERE  name = 'No' AND voided = 0 AND retired = 0 LIMIT 1")
  symptom_no = symptom_no_record['concept_id'].to_i

  other_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
      LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
WHERE  name = 'Other' AND voided = 0 AND retired = 0 LIMIT 1")
  other = other_record['concept_id'].to_i

  peripheral_neuropathy_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
      LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
WHERE  name = 'Peripheral neuropathy' AND voided = 0 AND retired = 0 LIMIT 1")
  peripheral_neuropathy = peripheral_neuropathy_record['concept_id'].to_i

  psychosis_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
WHERE  name = 'Psychosis' AND voided = 0 AND retired = 0 LIMIT 1")
  psychosis = psychosis_record['concept_id'].to_i

  renal_failure_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
      LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
WHERE  name = 'Renal failure' AND voided = 0 AND retired = 0 LIMIT 1")
  renal_failure = renal_failure_record['concept_id'].to_i

  skin_rash_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
WHERE  name = 'Skin rash' AND voided = 0 AND retired = 0 LIMIT 1")
  skin_rash = skin_rash_record['concept_id'].to_i

  vomiting_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
WHERE  name = 'Vomiting' AND voided = 0 AND retired = 0 LIMIT 1")
  vomiting = vomiting_record['concept_id'].to_i

  #tb screening
  routine_tb_screening_screening_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
WHERE  name = 'Routine Tuberculosis Screening' AND voided = 0 AND retired = 0 LIMIT 1")
  routine_tb_screening_screening = routine_tb_screening_screening_record['concept_id']

  routine_tb_screening_fever_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
WHERE  name = 'Fever' AND voided = 0 AND retired = 0 LIMIT 1")
  routine_tb_screening_fever = routine_tb_screening_fever_record['concept_id'].to_i

  routine_tb_screening_night_sweats_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
WHERE  name = 'Night sweats' AND voided = 0 AND retired = 0 LIMIT 1")
  routine_tb_screening_night_sweats = routine_tb_screening_night_sweats_record['concept_id'].to_i

  routine_tb_screening_cough_of_any_duration_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
WHERE  name = 'Cough any duration' AND voided = 0 AND retired = 0 LIMIT 1")
  routine_tb_screening_cough_of_any_duration = routine_tb_screening_cough_of_any_duration_record['concept_id'].to_i

  routine_tb_screening_weight_loss_failure_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
WHERE  name = 'Weight loss / Failure to thrive / malnutrition' AND voided = 0 AND retired = 0 LIMIT 1")
  routine_tb_screening_weight_loss_failure = routine_tb_screening_weight_loss_failure_record['concept_id'].to_i
  #tb status
  tb_status_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
WHERE  name = 'TB status' AND voided = 0 AND retired = 0 LIMIT 1")
  tb_status = tb_status_record['concept_id']

  tb_status_tb_not_suspected_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
WHERE  name = 'TB NOT suspected' AND voided = 0 AND retired = 0 LIMIT 1")
  tb_status_tb_not_suspected = tb_status_tb_not_suspected_record['concept_id']

  tb_status_tb_suspected_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
WHERE  name = 'TB suspected' AND voided = 0 AND retired = 0 LIMIT 1")
  tb_status_tb_suspected = tb_status_tb_suspected_record['concept_id']

  tb_status_confirmed_tb_not_on_treatment_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
WHERE  name = 'Confirmed TB NOT on treatment' AND voided = 0 AND retired = 0 LIMIT 1")
  tb_status_confirmed_tb_not_on_treatment = tb_status_confirmed_tb_not_on_treatment_record['concept_id']

  tb_status_confirmed_tb_on_treatment_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
WHERE  name = 'Confirmed TB on treatment' AND voided = 0 AND retired = 0 LIMIT 1")
  tb_status_confirmed_tb_on_treatment = tb_status_confirmed_tb_on_treatment_record['concept_id']

  tb_status_unknown_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
WHERE  name = 'Unknown' AND voided = 0 AND retired = 0 LIMIT 1")
  tb_status_unknown = tb_status_unknown_record['concept_id']

  #cpt, sulpher and ipt
  allergic_to_sulphur_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
WHERE  name = 'Allergic to sulphur' AND voided = 0 AND retired = 0 LIMIT 1")
  allergic_to_sulphur = allergic_to_sulphur_record['concept_id']

  prescribe_arvs_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
WHERE  name = 'Prescribe drugs' AND voided = 0 AND retired = 0 LIMIT 1")
  prescribe_arvs = prescribe_arvs_record['concept_id']

  prescribe_ipt_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
WHERE  name = 'Isoniazid' AND voided = 0 AND retired = 0 LIMIT 1")
  prescribe_ipt = prescribe_ipt_record['concept_id']

  patient_hiv_consultation_obs = Connection.select_all("SELECT * FROM obs WHERE encounter_id = #{encounter['encounter_id']}")
  encounter_visit_date =  encounter['encounter_datetime'].to_date.strftime("%Y-%m-%d")


  flat_table_2_data = []
  flat_table_2_data = Connection.select_one("SELECT * FROM flat_table2
                                    WHERE patient_id = #{encounter['patient_id']}
                                    AND visit_date = '#{encounter_visit_date}'")

  malawi_art_side_effects_concept_ids =  []
  new_malawi_side_effects_saved =  Connection.select_all("SELECT person_id, concept_id, value_coded from obs
                                      WHERE encounter_id = #{encounter['encounter_id']}
                                      AND obs_group_id IS NOT NULL
                                      AND concept_id IN (215, 3, 1458, 5945, 151, 868, 107, 16, 7952, 5980, 29, 219, 512, 821, 877, 1066, 2148, 2150, 3681, 5953, 6408, 9242, 9440)")

  unless flat_table_2_data.blank?
    #update
    if encounter['voided'].to_i == 0

      if new_malawi_side_effects_saved.blank?
        old_malawi_side_effects_saved = Connection.select_all("SELECT person_id, concept_id, value_coded from obs
                                            WHERE encounter_id = #{encounter['encounter_id']}
                                            AND concept_id = 7755 AND value_coded NOT IN (1066, 1107)")

        unless old_malawi_side_effects_saved.blank?
            Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_present = 'Yes', side_effects_present_enc_id = #{encounter['encounter_id']}
WHERE flat_table2.id = '#{flat_table_2_data['ID']}';
EOF
        else
          Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_present = 'No', side_effects_present_enc_id = #{encounter['encounter_id']}
WHERE flat_table2.id = '#{flat_table_2_data['ID']}';
EOF
        end
      else
        new_malawi_side_effects_saved =  Connection.select_all("SELECT person_id, concept_id, value_coded from obs
                                          WHERE encounter_id = #{encounter['encounter_id']}
                                          AND concept_id IN (215, 3, 1458, 5945, 151, 868, 107, 16, 7952, 5980, 29, 219, 512, 821, 877, 2148, 2150, 3681, 5953, 6408, 9242, 9440)
                                          AND obs_group_id IS NOT NULL
                                          AND value_coded NOT IN (1066, 1107)")

        unless new_malawi_side_effects_saved.blank?
          Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_present = 'Yes', side_effects_present_enc_id = #{encounter['encounter_id']}
WHERE flat_table2.id = '#{flat_table_2_data['ID']}';
EOF
        else
        Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_present = 'No', side_effects_present_enc_id = #{encounter['encounter_id']}
WHERE flat_table2.id = '#{flat_table_2_data['ID']}';
EOF
        end
     end
    else
      Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_present = NULL, side_effects_present_enc_id = NULL
WHERE flat_table2.id = '#{flat_table_2_data['ID']}';
EOF
    end
  else #else unless
    if new_malawi_side_effects_saved.blank?
      old_malawi_side_effects_saved = Connection.select_all("SELECT person_id, concept_id, value_coded from obs
                                          WHERE encounter_id = #{encounter['encounter_id']}
                                          AND concept_id = 7755 AND value_coded NOT IN (1066, 1107)")

      unless old_malawi_side_effects_saved.blank?
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, side_effects_present, side_effects_present_enc_id)
VALUES('#{encounter['patient_id']}', DATE('#{encounter_visit_date}'), 'Yes', '#{encounter['encounter_id']}') ;
EOF
      else
        Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, side_effects_present, side_effects_present_enc_id)
VALUES('#{encounter['patient_id']}', DATE('#{encounter_visit_date}'), 'Yes', '#{encounter['encounter_id']}') ;
EOF
      end
    else
      new_malawi_side_effects_saved =  Connection.select_all("SELECT person_id, concept_id, value_coded from obs
                                        WHERE encounter_id = #{encounter['encounter_id']}
                                        AND concept_id IN (215, 3, 1458, 5945, 151, 868, 107, 16, 7952, 5980, 29, 219, 512, 821, 877, 2148, 2150, 3681, 5953, 6408, 9242, 9440)
                                        AND obs_group_id IS NOT NULL
                                        AND value_coded NOT IN (1066, 1107)")

      unless new_malawi_side_effects_saved.blank?
        Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, side_effects_present, side_effects_present_enc_id)
VALUES('#{encounter['patient_id']}', DATE('#{encounter_visit_date}'), 'Yes', '#{encounter['encounter_id']}') ;
EOF
      else
        Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, side_effects_present, side_effects_present_enc_id)
VALUES('#{encounter['patient_id']}', DATE('#{encounter_visit_date}'), 'Yes', '#{encounter['encounter_id']}') ;
EOF
      end
    end
  end



  (patient_hiv_consultation_obs || []).each do |patient|
    patient_visit_date =  patient['obs_datetime'].to_date.strftime("%Y-%m-%d")


    case patient['concept_id']
      when patient_pregnant1
        if flat_table_2_data.blank?
          #insert
          answer_value = ""
          if (patient['value_coded'] == "#{yes_record['concept_id']}" || patient['value_text'] == "Yes")
            answer_value = 'Yes'
          elsif (patient['value_coded'] == "#{no_record['concept_id']}" || patient['value_text'] == "No")
            answer_value = 'No'
          elsif (patient['value_coded'] == "#{unknown_record['concept_id']}" || patient['value_text'] == "Unknown")
            answer_value = 'Unknown'
          end #end answer_value

          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, patient_pregnant, patient_pregnant_enc_id, patient_pregnant_v_date)
VALUES('#{patient['person_id']}', DATE('#{patient_visit_date}'), '#{answer_value}', '#{patient['encounter_id']}', DATE('#{patient_visit_date}') ;
EOF
        else #else visit blank?
            #update to null
            if patient['voided'] == "0"
              #update to value
              answer_value = ""
              if (patient['value_coded'] == "#{yes_record['concept_id']}" || patient['value_text'] == "Yes")
                answer_value = 'Yes'
              elsif (patient['value_coded'] == "#{no_record['concept_id']}" || patient['value_text'] == "No")
                answer_value = 'No'
              elsif (patient['value_coded'] == "#{unknown_record['concept_id']}" || patient['value_text'] == "Unknown")
                answer_value = 'Unknown'
              end #end answer_value

              Connection.execute <<EOF
UPDATE flat_table2
SET  patient_pregnant = '#{answer_value}', patient_pregnant_enc_id = #{patient['encounter_id']}, patient_pregnant_v_date = DATE('#{patient_visit_date}')
WHERE flat_table2.id = '#{flat_table_2_data['ID']}';
EOF
          else #else voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  patient_pregnant = NULL, patient_pregnant_enc_id = NULL, patient_pregnant_v_date = NULL
WHERE flat_table2.id = '#{flat_table_2_data['ID']}';
EOF
          end #end if voided
        end# end if visit blank
#---------------------------------------------------------------------------------------------------------------------end patient_pregnant1
      when patient_pregnant2
        patient_check = []
        patient_check = Connection.select_one("SELECT ID FROM flat_table2
                                      WHERE patient_id = #{patient['person_id']}
                                      and visit_date = '#{patient_visit_date}'")
        if patient_check.blank?
          #insert
          answer_value = ""
          if (patient['value_coded'] == "#{yes_record['concept_id']}" || patient['value_text'] == "Yes")
            answer_value = 'Yes'
          elsif (patient['value_coded'] == "#{no_record['concept_id']}" || patient['value_text'] == "No")
            answer_value = 'No'
          elsif (patient['value_coded'] == "#{unknown_record['concept_id']}" || patient['value_text'] == "Unknown")
            answer_value = 'Unknown'
          end #end answer_value

          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, patient_pregnant, patient_pregnant_enc_id, patient_pregnant_v_date)
VALUES('#{patient['person_id']}', DATE('#{patient_visit_date}'), '#{answer_value}', '#{patient['encounter_id']}', DATE('#{patient_visit_date}') ;
EOF
        else #else visit blank?
          if patient['voided'] =="0"
            #update to value
            answer_value = ""
            if (patient['value_coded'] == "#{yes_record['concept_id']}" || patient['value_text'] == "Yes")
              answer_value = 'Yes'
            elsif (patient['value_coded'] == "#{no_record['concept_id']}" || patient['value_text'] == "No")
              answer_value = 'No'
            elsif (patient['value_coded'] == "#{unknown_record['concept_id']}" || patient['value_text'] == "Unknown")
              answer_value = 'Unknown'
            end #end answer_value

            Connection.execute <<EOF
UPDATE flat_table2
SET  patient_pregnant = '#{answer_value}', patient_pregnant_enc_id = #{patient['encounter_id']},
patient_pregnant_v_date = DATE('#{patient_visit_date}')
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          else #else voided
            #update to null
            Connection.execute <<EOF
UPDATE flat_table2
SET  patient_pregnant = NULL, patient_pregnant_enc_id = NULL, patient_pregnant_v_date = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end if voided
        end# end if visit blank
#---------------------------------------------------------------------------------------------------------------------end patient_pregnant2
      when patient_breastfeeding1
        patient_check = []
        patient_check = Connection.select_one("SELECT ID FROM flat_table2
                                      WHERE patient_id = #{patient['person_id']}
                                      and visit_date = '#{patient_visit_date}'")
        if patient_check.blank?
          #insert
          answer_value = ""
          if (patient['value_coded'] == "#{yes_record['concept_id']}" || patient['value_text'] == "Yes")
            answer_value = 'Yes'
          elsif (patient['value_coded'] == "#{no_record['concept_id']}" || patient['value_text'] == "No")
            answer_value = 'No'
          elsif (patient['value_coded'] == "#{unknown_record['concept_id']}" || patient['value_text'] == "Unknown")
            answer_value = 'Unknown'
          end #end answer_value

          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, patient_breastfeeding, patient_breastfeeding_enc_id, patient_breastfeeding_v_date)
VALUES('#{patient['person_id']}', DATE('#{patient_visit_date}'), '#{answer_value}', '#{patient['encounter_id']}', DATE('#{patient_visit_date}') ;
EOF
        else #else visit blank?
          if patient['voided'] == "0"
            #update to value
            answer_value = ""
            if (patient['value_coded'] == "#{yes_record['concept_id']}" || patient['value_text'] == "Yes")
              answer_value = 'Yes'
            elsif (patient['value_coded'] == "#{no_record['concept_id']}" || patient['value_text'] == "No")
              answer_value = 'No'
            elsif (patient['value_coded'] == "#{unknown_record['concept_id']}" || patient['value_text'] == "Unknown")
              answer_value = 'Unknown'
            end #end answer_value

            Connection.execute <<EOF
UPDATE flat_table2
SET  patient_breastfeeding = '#{answer_value}', patient_breastfeeding_enc_id = #{patient['encounter_id']},
patient_breastfeeding_v_date = DATE('#{patient_visit_date}')
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF

          else #else voided
            #update to null
            Connection.execute <<EOF
UPDATE flat_table2
SET  patient_breastfeeding = NULL, patient_breastfeeding_enc_id = NULL, patient_breastfeeding_v_date = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end if voided
        end# end if visit blank
#---------------------------------------------------------------------------------------------------------------------end patient_breastfeeding1
      when patient_breastfeeding2
        patient_check = []
        patient_check = Connection.select_one("SELECT ID FROM flat_table2
                                      WHERE patient_id = #{patient['person_id']}
                                      and visit_date = '#{patient_visit_date}'")
        if patient_check.blank?
          #insert
          answer_value = ""
          if (patient['value_coded'] == "#{yes_record['concept_id']}" || patient['value_text'] == "Yes")
            answer_value = 'Yes'
          elsif (patient['value_coded'] == "#{no_record['concept_id']}" || patient['value_text'] == "No")
            answer_value = 'No'
          elsif (patient['value_coded'] == "#{unknown_record['concept_id']}" || patient['value_text'] == "Unknown")
            answer_value = 'Unknown'
          end #end answer_value

          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, patient_breastfeeding, patient_breastfeeding_enc_id, patient_breastfeeding_v_date)
VALUES('#{patient['person_id']}', DATE('#{patient_visit_date}'), '#{answer_value}', '#{patient['encounter_id']}', DATE('#{patient_visit_date}') ;
EOF
        else #else visit blank?
          if patient['voided'] == "0"
            #update to value
            answer_value = ""
            if (patient['value_coded'] == "#{yes_record['concept_id']}" || patient['value_text'] == "Yes")
              answer_value = 'Yes'
            elsif (patient['value_coded'] == "#{no_record['concept_id']}" || patient['value_text'] == "No")
              answer_value = 'No'
            elsif (patient['value_coded'] == "#{unknown_record['concept_id']}" || patient['value_text'] == "Unknown")
              answer_value = 'Unknown'
            end #end answer_value

            Connection.execute <<EOF
UPDATE flat_table2
SET  patient_breastfeeding = '#{answer_value}', patient_breastfeeding_enc_id = #{patient['encounter_id']},
patient_breastfeeding_v_date = DATE('#{patient_visit_date}')
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          else #else voided
            #update to null
            Connection.execute <<EOF
UPDATE flat_table2
SET  patient_breastfeeding = NULL, patient_breastfeeding_enc_id = NULL, patient_breastfeeding_v_date = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end if voided
        end# end if visit blank
#---------------------------------------------------------------------------------------------------------------------end patient_breastfeeding2
    when family_planning_method
      patient_check = []
      patient_check = Connection.select_one("SELECT ID FROM flat_table2
                                    WHERE patient_id = #{patient['person_id']}
                                    and visit_date = '#{patient_visit_date}'")
      if patient_check.blank?
        #insert
        answer_value = ""
        if (patient['value_coded'] == "#{yes_record['concept_id']}" || patient['value_text'] == "Yes")
          answer_value = 'Yes'
        elsif (patient['value_coded'] == "#{no_record['concept_id']}" || patient['value_text'] == "No")
          answer_value = 'No'
        elsif (patient['value_coded'] == "#{unknown_record['concept_id']}" || patient['value_text'] == "Unknown")
          answer_value = 'Unknown'
        else
          answer_value = 'Yes'
        end #end answer_value

        Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, family_planning_method, family_planning_method_enc_id)
VALUES('#{patient['person_id']}', DATE('#{patient_visit_date}'), '#{answer_value}', '#{patient['encounter_id']}') ;
EOF
      else #else visit blank?
        if patient['voided'] == "0"
          #update to value
          answer_value = ""
          if (patient['value_coded'] == "#{yes_record['concept_id']}" || patient['value_text'] == "Yes")
            answer_value = 'Yes'
          elsif (patient['value_coded'] == "#{no_record['concept_id']}" || patient['value_text'] == "No")
            answer_value = 'No'
          elsif (patient['value_coded'] == "#{unknown_record['concept_id']}" || patient['value_text'] == "Unknown")
            answer_value = 'Unknown'
          else
            answer_value = 'Yes'
          end #end answer_value
    Connection.execute <<EOF
UPDATE flat_table2
SET  family_planning_method = '#{answer_value}', family_planning_method_enc_id = #{patient['encounter_id']}
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
        else #else voided
          #update to null
          Connection.execute <<EOF
UPDATE flat_table2
SET  family_planning_method = NULL, family_planning_method_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
        end #end if voided
      end# end if visit blank
#---------------------------------------------------------------------------------------------------------------------end family planning

      when currently_using_family_planning_method
        patient_check = []
        patient_check = Connection.select_one("SELECT ID FROM flat_table2
                                      WHERE patient_id = #{patient['person_id']}
                                      and visit_date = '#{patient_visit_date}'")
        if patient_check.blank?
          #insert
          answer_value = ""
          if (patient['value_coded'] == "#{yes_record['concept_id']}" || patient['value_text'] == "Yes")
            answer_value = 'Yes'
          elsif (patient['value_coded'] == "#{no_record['concept_id']}" || patient['value_text'] == "No")
            answer_value = 'No'
          elsif (patient['value_coded'] == "#{unknown_record['concept_id']}" || patient['value_text'] == "Unknown")
            answer_value = 'Unknown'
          end #end answer_value

          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, currently_using_family_planning_method, currently_using_family_planning_method_enc_id)
VALUES('#{patient['person_id']}', DATE('#{patient_visit_date}'), '#{answer_value}', '#{patient['encounter_id']}') ;
EOF
        else #else visit blank?
          if patient['voided'] == "0"
            #update to value
            answer_value = ""
            if (patient['value_coded'] == "#{yes_record['concept_id']}" || patient['value_text'] == "Yes")
              answer_value = 'Yes'
            elsif (patient['value_coded'] == "#{no_record['concept_id']}" || patient['value_text'] == "No")
              answer_value = 'No'
            elsif (patient['value_coded'] == "#{unknown_record['concept_id']}" || patient['value_text'] == "Unknown")
              answer_value = 'Unknown'
            end #end answer_value
      Connection.execute <<EOF
UPDATE flat_table2
SET  currently_using_family_planning_method = '#{answer_value}', currently_using_family_planning_method_enc_id = #{patient['encounter_id']}
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          else #else voided
            #update to null
            Connection.execute <<EOF
UPDATE flat_table2
SET  currently_using_family_planning_method = NULL, currently_using_family_planning_method_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end if voided
        end# end if visit blank
#---------------------------------------------------------------------------------------------------------------------end currently_using_family_planning_method
      when method_of_family_planning
        case patient['value_coded']
          when family_planning_method_oral_contraceptive_pills
            patient_check = []
            patient_check = Connection.select_one("SELECT ID FROM flat_table2
                                          WHERE patient_id = #{patient['person_id']}
                                          and visit_date = '#{patient_visit_date}'")
            if patient_check.blank?
              #insert
              Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, family_planning_method_oral_contraceptive_pills, family_planning_method_oral_contraceptive_pills_enc_id)
VALUES('#{patient['person_id']}', DATE('#{patient_visit_date}'), 'Yes', '#{patient['encounter_id']}') ;
EOF
            else #else visit blank
              #update
              if patient['voided'] == "0"
                Connection.execute <<EOF
UPDATE flat_table2
SET  family_planning_method_oral_contraceptive_pills = 'Yes', family_planning_method_oral_contraceptive_pills_enc_id = '#{patient['encounter_id']}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
              else #else voided
                Connection.execute <<EOF
UPDATE flat_table2
SET  family_planning_method_oral_contraceptive_pills = NULL, family_planning_method_oral_contraceptive_pills_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
              end #end voided
            end #end visit blank

          when family_planning_method_depo_provera
            patient_check = []
            patient_check = Connection.select_one("SELECT ID FROM flat_table2
                                          WHERE patient_id = #{patient['person_id']}
                                          and visit_date = '#{patient_visit_date}'")
            if patient_check.blank?
              #insert
              Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, family_planning_method_depo_provera, family_planning_method_depo_provera_enc_id)
VALUES('#{patient['person_id']}', DATE('#{patient_visit_date}'), 'Yes', '#{patient['encounter_id']}') ;
EOF
            else #else visit blank
              #update
              if patient['voided'] == "0"
                Connection.execute <<EOF
UPDATE flat_table2
SET  family_planning_method_depo_provera = 'Yes', family_planning_method_depo_provera_enc_id = '#{patient['encounter_id']}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
              else #else voided
                Connection.execute <<EOF
UPDATE flat_table2
SET  family_planning_method_depo_provera = NULL, family_planning_method_depo_provera_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
              end #end voided
            end #end visit blank

          when family_planning_method_intrauterine_contraception
            patient_check = []
            patient_check = Connection.select_one("SELECT ID FROM flat_table2
                                          WHERE patient_id = #{patient['person_id']}
                                          and visit_date = '#{patient_visit_date}'")
            if patient_check.blank?
              #insert
              Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, family_planning_method_intrauterine_contraception, family_planning_method_intrauterine_contraception_enc_id)
VALUES('#{patient['person_id']}', DATE('#{patient_visit_date}'), 'Yes', '#{patient['encounter_id']}') ;
EOF
            else #else visit blank
              #update
              if patient['voided'] == "0"
                Connection.execute <<EOF
UPDATE flat_table2
SET  family_planning_method_intrauterine_contraception = 'Yes', family_planning_method_intrauterine_contraception_enc_id = '#{patient['encounter_id']}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
              else #else voided
                Connection.execute <<EOF
UPDATE flat_table2
SET  family_planning_method_intrauterine_contraception = NULL, family_planning_method_intrauterine_contraception_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
              end #end voided
            end #end visit blank

          when family_planning_method_contraceptive_implant
            patient_check = []
            patient_check = Connection.select_one("SELECT ID FROM flat_table2
                                          WHERE patient_id = #{patient['person_id']}
                                          and visit_date = '#{patient_visit_date}'")
            if patient_check.blank?
              #insert
              Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, family_planning_method_contraceptive_implant, family_planning_method_contraceptive_implant_enc_id)
VALUES('#{patient['person_id']}', DATE('#{patient_visit_date}'), 'Yes', '#{patient['encounter_id']}') ;
EOF
            else #else visit blank
              #update
              if patient['voided'] == "0"
                Connection.execute <<EOF
UPDATE flat_table2
SET  family_planning_method_contraceptive_implant = 'Yes', family_planning_method_contraceptive_implant_enc_id = '#{patient['encounter_id']}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
              else #else voided
                Connection.execute <<EOF
UPDATE flat_table2
SET  family_planning_method_contraceptive_implant = NULL, family_planning_method_contraceptive_implant_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
              end #end voided
            end #end visit blank

          when family_planning_method_male_condoms
            patient_check = []
            patient_check = Connection.select_one("SELECT ID FROM flat_table2
                                          WHERE patient_id = #{patient['person_id']}
                                          and visit_date = '#{patient_visit_date}'")
            if patient_check.blank?
              #insert
  Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, family_planning_method_male_condoms, family_planning_method_male_condoms_enc_id)
VALUES('#{patient['person_id']}', DATE('#{patient_visit_date}'), 'Yes', '#{patient['encounter_id']}') ;
EOF
            else #else visit blank
              #update
              if patient['voided'] == "0"
                Connection.execute <<EOF
UPDATE flat_table2
SET  family_planning_method_male_condoms = 'Yes', family_planning_method_male_condoms_enc_id = '#{patient['encounter_id']}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
              else #else voided
                Connection.execute <<EOF
UPDATE flat_table2
SET  family_planning_method_male_condoms = NULL, family_planning_method_male_condoms_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
              end #end voided
            end #end visit blank

          when family_planning_method_female_condoms
            patient_check = []
            patient_check = Connection.select_one("SELECT ID FROM flat_table2
                                          WHERE patient_id = #{patient['person_id']}
                                          and visit_date = '#{patient_visit_date}'")
            if patient_check.blank?
              #insert
              Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, family_planning_method_female_condoms, family_planning_method_female_condoms_enc_id)
VALUES('#{patient['person_id']}', DATE('#{patient_visit_date}'), 'Yes', '#{patient['encounter_id']}') ;
EOF
            else #else visit blank
              #update
              if patient['voided'] == "0"
                Connection.execute <<EOF
UPDATE flat_table2
SET  family_planning_method_female_condoms = 'Yes', family_planning_method_female_condoms_enc_id = '#{patient['encounter_id']}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
              else #else voided
                Connection.execute <<EOF
UPDATE flat_table2
SET  family_planning_method_female_condoms = NULL, family_planning_method_female_condoms_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
              end #end voided
            end #end visit blank

          when family_planning_method_rythm_method
            patient_check = []
            patient_check = Connection.select_one("SELECT ID FROM flat_table2
                                          WHERE patient_id = #{patient['person_id']}
                                          and visit_date = '#{patient_visit_date}'")
            if patient_check.blank?
              #insert
              Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, family_planning_method_rythm_method, family_planning_method_rythm_method_enc_id)
VALUES('#{patient['person_id']}', DATE('#{patient_visit_date}'), 'Yes', '#{patient['encounter_id']}') ;
EOF
            else #else visit blank
              #update
              if patient['voided'] == "0"
                Connection.execute <<EOF
UPDATE flat_table2
SET  family_planning_method_rythm_method = 'Yes', family_planning_method_rythm_method_enc_id = '#{patient['encounter_id']}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
              else #else voided
                Connection.execute <<EOF
UPDATE flat_table2
SET  family_planning_method_rythm_method = NULL, family_planning_method_rythm_method_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
              end #end voided
            end #end visit blank

          when family_planning_method_withdrawal
            patient_check = []
            patient_check = Connection.select_one("SELECT ID FROM flat_table2
                                          WHERE patient_id = #{patient['person_id']}
                                          and visit_date = '#{patient_visit_date}'")
            if patient_check.blank?
              #insert
              Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, family_planning_method_withdrawal, family_planning_method_withdrawal_enc_id)
VALUES('#{patient['person_id']}', DATE('#{patient_visit_date}'), 'Yes', '#{patient['encounter_id']}') ;
EOF
            else #else visit blank
              #update
              if patient['voided'] == "0"
                Connection.execute <<EOF
UPDATE flat_table2
SET  family_planning_method_withdrawal = 'Yes', family_planning_method_withdrawal_enc_id = '#{patient['encounter_id']}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
              else #else voided
                Connection.execute <<EOF
UPDATE flat_table2
SET  family_planning_method_withdrawal = NULL, family_planning_method_withdrawal_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
              end #end voided
            end #end visit blank

          when family_planning_method_abstinence
            patient_check = []
            patient_check = Connection.select_one("SELECT ID FROM flat_table2
                                          WHERE patient_id = #{patient['person_id']}
                                          and visit_date = '#{patient_visit_date}'")
            if patient_check.blank?
              #insert
              Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, family_planning_method_abstinence, family_planning_method_abstinence_enc_id)
VALUES('#{patient['person_id']}', DATE('#{patient_visit_date}'), 'Yes', '#{patient['encounter_id']}') ;
EOF
            else #else visit blank
              #update
              if patient['voided'] == "0"
                Connection.execute <<EOF
UPDATE flat_table2
SET  family_planning_method_abstinence = 'Yes', family_planning_method_abstinence_enc_id = '#{patient['encounter_id']}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
              else #else voided
                Connection.execute <<EOF
UPDATE flat_table2
SET  family_planning_method_abstinence = NULL, family_planning_method_abstinence_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
              end #end voided
            end #end visit blank

          when family_planning_method_tubal_ligation
            patient_check = []
            patient_check = Connection.select_one("SELECT ID FROM flat_table2
                                          WHERE patient_id = #{patient['person_id']}
                                          and visit_date = '#{patient_visit_date}'")
            if patient_check.blank?
              #insert
              Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, family_planning_method_tubal_ligation, family_planning_method_tubal_ligation_enc_id)
VALUES('#{patient['person_id']}', DATE('#{patient_visit_date}'), 'Yes', '#{patient['encounter_id']}') ;
EOF
            else #else visit blank
              #update
              if patient['voided'] == "0"
                Connection.execute <<EOF
UPDATE flat_table2
SET  family_planning_method_tubal_ligation = 'Yes', family_planning_method_tubal_ligation_enc_id = '#{patient['encounter_id']}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
              else #else voided
                Connection.execute <<EOF
UPDATE flat_table2
SET  family_planning_method_tubal_ligation = NULL, family_planning_method_tubal_ligation_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
              end #end voided
            end #end visit blank

          when family_planning_method_vasectomy
            patient_check = []
            patient_check = Connection.select_one("SELECT ID FROM flat_table2
                                          WHERE patient_id = #{patient['person_id']}
                                          and visit_date = '#{patient_visit_date}'")
            if patient_check.blank?
              #insert
              Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, family_planning_method_vasectomy, family_planning_method_vasectomy_enc_id)
VALUES('#{patient['person_id']}', DATE('#{patient_visit_date}'), 'Yes', '#{patient['encounter_id']}') ;
EOF
            else #else visit blank
              #update
              if patient['voided'] == "0"
                Connection.execute <<EOF
UPDATE flat_table2
SET  family_planning_method_vasectomy = 'Yes', family_planning_method_vasectomy_enc_id = '#{patient['encounter_id']}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
              else #else voided
                Connection.execute <<EOF
UPDATE flat_table2
SET  family_planning_method_vasectomy = NULL, family_planning_method_vasectomy_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
              end #end voided
            end #end visit blank

          when family_planning_method_emergency_contraception
            patient_check = []
            patient_check = Connection.select_one("SELECT ID FROM flat_table2
                                          WHERE patient_id = #{patient['person_id']}
                                          and visit_date = '#{patient_visit_date}'")
            if patient_check.blank?
              #insert
              Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, family_planning_method_emergency_contraception, family_planning_method_emergency_contraception_enc_id)
VALUES('#{patient['person_id']}', DATE('#{patient_visit_date}'), 'Yes', '#{patient['encounter_id']}') ;
EOF
            else #else visit blank
              #update
              if patient['voided'] == "0"
                Connection.execute <<EOF
UPDATE flat_table2
SET  family_planning_method_emergency_contraception = 'Yes', family_planning_method_emergency_contraception_enc_id = '#{patient['encounter_id']}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
              else #else voided
                Connection.execute <<EOF
UPDATE flat_table2
SET  family_planning_method_emergency_contraception = NULL, family_planning_method_emergency_contraception_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
              end #end voided
            end #end visit blank
        end #end family planning value_coded
#---------------------------------------------------------------------------------------------------------------------end family planning method

    when routine_tb_screening_screening
      updating_routine_tb_screening(patient['person_id'].to_i, patient['encounter_id'].to_i, patient['value_coded'].to_i, patient['obs_datetime'], patient['voided'].to_i)
#------------------------------------------------------------------------------------------------------------------------close TB routine screening
    when tb_status
#--------------------------------------------------------------------------------------------------------------
      tb_status_record = Connection.select_one("SELECT concept_name.name FROM concept_name
        LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
      WHERE  concept_name.concept_id = '#{patient['value_coded']}' AND voided = 0 AND retired = 0 LIMIT 1")
      puts "........... tb_status: #{tb_status_record}"

      tb_status_value = tb_status_record['name']

      patient_check = []
      patient_check = Connection.select_one("SELECT ID FROM flat_table2
                                    WHERE patient_id = #{patient['person_id']}
                                    and visit_date = '#{patient_visit_date}'")
      if patient_check.blank?
        #insert
        Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, tb_status, tb_status_enc_id)
VALUES('#{patient['person_id']}', DATE('#{patient_visit_date}'), '#{tb_status_value}', '#{patient['encounter_id']}') ;
EOF
       else #else visit blank
         #update
         if patient['voided'] == "0"
           Connection.execute <<EOF
UPDATE flat_table2
SET  tb_status = '#{tb_status_value}', tb_status_enc_id = '#{patient['encounter_id']}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
         else #else voided
           Connection.execute <<EOF
UPDATE flat_table2
SET  tb_status = NULL, tb_status_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
        end #end voided
      end #end visit blank
#-------------------------------------------------------------------------------------------------------------
      case patient['value_coded']
      when tb_status_tb_not_suspected
        patient_check = []
        patient_check = Connection.select_one("SELECT ID FROM flat_table2
                                      WHERE patient_id = #{patient['person_id']}
                                      and visit_date = '#{patient_visit_date}'")
        if patient_check.blank?
          #insert
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, tb_status_tb_not_suspected, tb_status_tb_not_suspected_enc_id)
VALUES('#{patient['person_id']}', DATE('#{patient_visit_date}'), 'Yes', '#{patient['encounter_id']}') ;
EOF
         else #else visit blank
           #update
           if patient['voided'] == "0"
             Connection.execute <<EOF
UPDATE flat_table2
SET  tb_status_tb_not_suspected = 'Yes', tb_status_tb_not_suspected_enc_id = '#{patient['encounter_id']}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
           else #else voided
             Connection.execute <<EOF
UPDATE flat_table2
SET  tb_status_tb_not_suspected = NULL, tb_status_tb_not_suspected_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end voided
        end #end visit blank

      when tb_status_tb_suspected
        patient_check = []
        patient_check = Connection.select_one("SELECT ID FROM flat_table2
                                      WHERE patient_id = #{patient['person_id']}
                                      and visit_date = '#{patient_visit_date}'")
        if patient_check.blank?
          #insert
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, tb_status_tb_suspected, tb_status_tb_suspected_enc_id)
VALUES('#{patient['person_id']}', DATE('#{patient_visit_date}'), 'Yes', '#{patient['encounter_id']}') ;
EOF
         else #else visit blank
           #update
           if patient['voided'] == "0"
             Connection.execute <<EOF
UPDATE flat_table2
SET  tb_status_tb_suspected = 'Yes', tb_status_tb_suspected_enc_id = '#{patient['encounter_id']}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
           else #else voided
             Connection.execute <<EOF
UPDATE flat_table2
SET  tb_status_tb_suspected = NULL, tb_status_tb_suspected_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end voided
        end #end visit blank

      when tb_status_confirmed_tb_not_on_treatment
        patient_check = []
        patient_check = Connection.select_one("SELECT ID FROM flat_table2
                                      WHERE patient_id = #{patient['person_id']}
                                      and visit_date = '#{patient_visit_date}'")
        if patient_check.blank?
          #insert
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, tb_status_confirmed_tb_not_on_treatment, tb_status_confirmed_tb_not_on_treatment_enc_id)
VALUES('#{patient['person_id']}', DATE('#{patient_visit_date}'), 'Yes', '#{patient['encounter_id']}') ;
EOF
         else #else visit blank
           #update
           if patient['voided'] == "0"
             Connection.execute <<EOF
UPDATE flat_table2
SET  tb_status_confirmed_tb_not_on_treatment = 'Yes', tb_status_confirmed_tb_not_on_treatment_enc_id = '#{patient['encounter_id']}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
           else #else voided
             Connection.execute <<EOF
UPDATE flat_table2
SET  tb_status_confirmed_tb_not_on_treatment = NULL, tb_status_confirmed_tb_not_on_treatment_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end voided
        end #end visit blank

      when tb_status_confirmed_tb_on_treatment
        patient_check = []
        patient_check = Connection.select_one("SELECT ID FROM flat_table2
                                      WHERE patient_id = #{patient['person_id']}
                                      and visit_date = '#{patient_visit_date}'")
        if patient_check.blank?
          #insert
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, tb_status_confirmed_tb_on_treatment, tb_status_confirmed_tb_on_treatment_enc_id)
VALUES('#{patient['person_id']}', DATE('#{patient_visit_date}'), 'Yes', '#{patient['encounter_id']}') ;
EOF
         else #else visit blank
           #update
           if patient['voided'] == "0"
             Connection.execute <<EOF
UPDATE flat_table2
SET  tb_status_confirmed_tb_on_treatment = 'Yes', tb_status_confirmed_tb_on_treatment_enc_id = '#{patient['encounter_id']}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
           else #else voided
             Connection.execute <<EOF
UPDATE flat_table2
SET  tb_status_confirmed_tb_on_treatment = NULL, tb_status_confirmed_tb_on_treatment_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end voided
        end #end visit blank

      when tb_status_unknown
        patient_check = []
        patient_check = Connection.select_one("SELECT ID FROM flat_table2
                                      WHERE patient_id = #{patient['person_id']}
                                      and visit_date = '#{patient_visit_date}'")
        if patient_check.blank?
          #insert
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, tb_status_unknown, tb_status_unknown_enc_id)
VALUES('#{patient['person_id']}', DATE('#{patient_visit_date}'), 'Yes', '#{patient['encounter_id']}') ;
EOF
         else #else visit blank
           #update
           if patient['voided'] == "0"
             Connection.execute <<EOF
UPDATE flat_table2
SET  tb_status_unknown = 'Yes', tb_status_unknown_enc_id = '#{patient['encounter_id']}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
           else #else voided
             Connection.execute <<EOF
UPDATE flat_table2
SET  tb_status_unknown = NULL, tb_status_unknown_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end voided
        end #end visit blank
      end #tb_status value_coded
#------------------------------------------------------------------------------------------------------------------------close TB status
    when allergic_to_sulphur
                    patient_check = []
                    patient_check = Connection.select_one("SELECT ID FROM flat_table2
                                    WHERE patient_id = #{patient['person_id']}
                                    and visit_date = '#{patient_visit_date}'")
      if patient_check.blank?
        #insert
        answer_value = ""
        if (patient['value_coded'] == "#{yes_record['concept_id']}" || patient['value_text'] == "Yes")
          answer_value = 'Yes'
        elsif (patient['value_coded'] == "#{no_record['concept_id']}" || patient['value_text'] == "No")
          answer_value = 'No'
        elsif (patient['value_coded'] == "#{unknown_record['concept_id']}" || patient['value_text'] == "Unknown")
          answer_value = 'Unknown'
        end #end answer_value

        Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, allergic_to_sulphur, allergic_to_sulphur_enc_id)
VALUES('#{patient['person_id']}', DATE('#{patient_visit_date}'), '#{answer_value}', '#{patient['encounter_id']}') ;
EOF
      else #else visit blank?
        if patient['voided'] == "0"
          #update to value
          answer_value = ""
          if (patient['value_coded'] == "#{yes_record['concept_id']}" || patient['value_text'] == "Yes")
            answer_value = 'Yes'
          elsif (patient['value_coded'] == "#{no_record['concept_id']}" || patient['value_text'] == "No")
            answer_value = 'No'
          elsif (patient['value_coded'] == "#{unknown_record['concept_id']}" || patient['value_text'] == "Unknown")
            answer_value = 'Unknown'
          end #end answer_value

          Connection.execute <<EOF
UPDATE flat_table2
SET  allergic_to_sulphur = '#{answer_value}', allergic_to_sulphur_enc_id = #{patient['encounter_id']},
      visit_date = DATE('#{patient_visit_date}')
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF

        else #else voided
          #update to null
          Connection.execute <<EOF
UPDATE flat_table2
SET  allergic_to_sulphur = NULL, allergic_to_sulphur_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
        end #end if voided
      end# end if visit blank
#-------------------------------------------------------------------------------------------------------------------------end allergic_to_sulphur
    when prescribe_arvs
                    patient_check = []
                    patient_check = Connection.select_one("SELECT ID FROM flat_table2
                                    WHERE patient_id = #{patient['person_id']}
                                    and visit_date = '#{patient_visit_date}'")
      if patient_check.blank?
        #insert
        answer_value = ""
        if (patient['value_coded'] == "#{yes_record['concept_id']}" || patient['value_text'] == "Yes")
          answer_value = 'Yes'
        elsif (patient['value_coded'] == "#{no_record['concept_id']}" || patient['value_text'] == "No")
          answer_value = 'No'
        elsif (patient['value_coded'] == "#{unknown_record['concept_id']}" || patient['value_text'] == "Unknown")
          answer_value = 'Unknown'
        end #end answer_value

        Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, prescribe_arvs, prescribe_arvs_enc_id)
VALUES('#{patient['person_id']}', DATE('#{patient_visit_date}'), '#{answer_value}', '#{patient['encounter_id']}' ;
EOF
      else #else visit blank?
        if patient['voided'] == "0"
          #update to value
          answer_value = ""
          if (patient['value_coded'] == "#{yes_record['concept_id']}" || patient['value_text'] == "Yes")
            answer_value = 'Yes'
          elsif (patient['value_coded'] == "#{no_record['concept_id']}" || patient['value_text'] == "No")
            answer_value = 'No'
          elsif (patient['value_coded'] == "#{unknown_record['concept_id']}" || patient['value_text'] == "Unknown")
            answer_value = 'Unknown'
          end #end answer_value

          Connection.execute <<EOF
UPDATE flat_table2
SET  prescribe_arvs = '#{answer_value}', prescribe_arvs_enc_id = #{patient['encounter_id']},
visit_date = DATE('#{patient_visit_date}')
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF

        else #else voided
          #update to null
          Connection.execute <<EOF
UPDATE flat_table2
SET  prescribe_arvs = NULL, prescribe_arvs_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
        end #end if voided
      end# end if visit blank
#-----------------------------------------------------------------------------------------------end prescribe_arvs
    when prescribe_ipt
                    patient_check = []
                    patient_check = Connection.select_one("SELECT ID FROM flat_table2
                                    WHERE patient_id = #{patient['person_id']}
                                    and visit_date = '#{patient_visit_date}'")
      if patient_check.blank?
        #insert
        answer_value = ""
        if (patient['value_coded'] == "#{yes_record['concept_id']}" || patient['value_text'] == "Yes")
          answer_value = 'Yes'
        elsif (patient['value_coded'] == "#{no_record['concept_id']}" || patient['value_text'] == "No")
          answer_value = 'No'
        elsif (patient['value_coded'] == "#{unknown_record['concept_id']}" || patient['value_text'] == "Unknown")
          answer_value = 'Unknown'
        end #end answer_value

        Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, prescribe_ipt, prescribe_ipt_enc_id, prescribe_ipt_v_date)
VALUES('#{patient['person_id']}', DATE('#{patient_visit_date}'), '#{answer_value}', '#{patient['encounter_id']}', DATE('#{patient_visit_date}') ;
EOF
      else #else visit blank?
        if patient['voided'] == "0"
          #update to value
          answer_value = ""
          if (patient['value_coded'] == "#{yes_record['concept_id']}" || patient['value_text'] == "Yes")
            answer_value = 'Yes'
          elsif (patient['value_coded'] == "#{no_record['concept_id']}" || patient['value_text'] == "No")
            answer_value = 'No'
          elsif (patient['value_coded'] == "#{unknown_record['concept_id']}" || patient['value_text'] == "Unknown")
            answer_value = 'Unknown'
          end #end answer_value

          Connection.execute <<EOF
UPDATE flat_table2
SET  prescribe_ipt = '#{answer_value}', prescribe_ipt_enc_id = #{patient['encounter_id']},
prescribe_ipt_v_date = DATE('#{patient_visit_date}')
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF

        else #else voided
          #update to null
          Connection.execute <<EOF
UPDATE flat_table2
SET  prescribe_ipt = NULL, prescribe_ipt_enc_id = NULL, prescribe_ipt_v_date = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
        end #end if voided
      end# end if visit blank
#---------------------------------------------------------------------------------------------------------------end prescribe ipt
    when symptom_present
      case patient['value_coded']
      when abdominal_pain
        patient_check = []
        patient_check = Connection.select_one("SELECT ID FROM flat_table2
                                      WHERE patient_id = #{patient['person_id']}
                                      and visit_date = '#{patient_visit_date}'")
        if patient_check.blank?
          #insert
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, symptom_present_abdominal_pain, symptom_present_abdominal_pain_enc_id)
VALUES('#{patient['person_id']}', DATE('#{patient_visit_date}'), 'Yes', '#{patient['encounter_id']}') ;
EOF
         else #else visit blank
           #update
           if patient['voided'] == "0"
             Connection.execute <<EOF
UPDATE flat_table2
SET  symptom_present_abdominal_pain = 'Yes', symptom_present_abdominal_pain_enc_id = '#{patient['encounter_id']}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
           else #else voided
             Connection.execute <<EOF
UPDATE flat_table2
SET  symptom_present_abdominal_pain = NULL, symptom_present_abdominal_pain_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end voided
        end #end visit blank

      when anemia
        patient_check = []
        patient_check = Connection.select_one("SELECT ID FROM flat_table2
                                      WHERE patient_id = #{patient['person_id']}
                                      and visit_date = '#{patient_visit_date}'")
        if patient_check.blank?
          #insert
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, symptom_present_anemia, symptom_present_anemia_enc_id)
VALUES('#{patient['person_id']}', DATE('#{patient_visit_date}'), 'Yes', '#{patient['encounter_id']}') ;
EOF
         else #else visit blank
           #update
           if patient['voided'] == "0"
             Connection.execute <<EOF
UPDATE flat_table2
SET  symptom_present_anemia = 'Yes', symptom_present_anemia_enc_id = '#{patient['encounter_id']}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
           else #else voided
             Connection.execute <<EOF
UPDATE flat_table2
SET  symptom_present_anemia = NULL, symptom_present_anemia_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end voided
        end #end visit blank

      when anorexia
              patient_check = []
              patient_check = Connection.select_one("SELECT ID FROM flat_table2
                              WHERE patient_id = #{patient['person_id']}
                              and visit_date = '#{patient_visit_date}'")
        if patient_check.blank?
          #insert
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, symptom_present_anorexia, symptom_present_anorexia_enc_id)
VALUES('#{patient['person_id']}', DATE('#{patient_visit_date}'), 'Yes', '#{patient['encounter_id']}') ;
EOF
         else #else visit blank
           #update
           if patient['voided'] == "0"
             Connection.execute <<EOF
UPDATE flat_table2
SET  symptom_present_anorexia = 'Yes', symptom_present_anorexia_enc_id = '#{patient['encounter_id']}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
           else #else voided
             Connection.execute <<EOF
UPDATE flat_table2
SET  symptom_present_anorexia = NULL, symptom_present_anorexia_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end voided
        end #end visit blank

      when blurry_vision
              patient_check = []
              patient_check = Connection.select_one("SELECT ID FROM flat_table2
                              WHERE patient_id = #{patient['person_id']}
                              and visit_date = '#{patient_visit_date}'")
        if patient_check.blank?
          #insert
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, symptom_present_blurry_vision, symptom_present_blurry_vision_enc_id)
VALUES('#{patient['person_id']}', DATE('#{patient_visit_date}'), 'Yes', '#{patient['encounter_id']}') ;
EOF
         else #else visit blank
           #update
           if patient['voided'] == "0"
             Connection.execute <<EOF
UPDATE flat_table2
SET  symptom_present_blurry_vision = 'Yes', symptom_present_blurry_vision_enc_id = '#{patient['encounter_id']}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
           else #else voided
             Connection.execute <<EOF
UPDATE flat_table2
SET  symptom_present_blurry_vision = NULL, symptom_present_blurry_vision_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end voided
        end #end visit blank

      when cough
              patient_check = []
              patient_check = Connection.select_one("SELECT ID FROM flat_table2
                              WHERE patient_id = #{patient['person_id']}
                              and visit_date = '#{patient_visit_date}'")
        if patient_check.blank?
          #insert
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, symptom_present_cough, symptom_present_cough_enc_id)
VALUES('#{patient['person_id']}', DATE('#{patient_visit_date}'), 'Yes', '#{patient['encounter_id']}') ;
EOF
         else #else visit blank
           #update
           if patient['voided'] == "0"
             Connection.execute <<EOF
UPDATE flat_table2
SET  symptom_present_cough = 'Yes', symptom_present_cough_enc_id = '#{patient['encounter_id']}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
           else #else voided
             Connection.execute <<EOF
UPDATE flat_table2
SET  symptom_present_cough = NULL, symptom_present_cough_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end voided
        end #end visit blank

      when diarrhea
              patient_check = []
              patient_check = Connection.select_one("SELECT ID FROM flat_table2
                              WHERE patient_id = #{patient['person_id']}
                              and visit_date = '#{patient_visit_date}'")
        if patient_check.blank?
          #insert
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, symptom_present_diarrhea, symptom_present_diarrhea_enc_id)
VALUES('#{patient['person_id']}', DATE('#{patient_visit_date}'), 'Yes', '#{patient['encounter_id']}') ;
EOF
         else #else visit blank
           #update
           if patient['voided'] == "0"
             Connection.execute <<EOF
UPDATE flat_table2
SET  symptom_present_diarrhea = 'Yes', symptom_present_diarrhea_enc_id = '#{patient['encounter_id']}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
           else #else voided
             Connection.execute <<EOF
UPDATE flat_table2
SET  symptom_present_diarrhea = NULL, symptom_present_diarrhea_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end voided
        end #end visit blank

      when diziness
              patient_check = []
              patient_check = Connection.select_one("SELECT ID FROM flat_table2
                              WHERE patient_id = #{patient['person_id']}
                              and visit_date = '#{patient_visit_date}'")
        if patient_check.blank?
          #insert
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, symptom_present_diziness, symptom_present_diziness_enc_id)
VALUES('#{patient['person_id']}', DATE('#{patient_visit_date}'), 'Yes', '#{patient['encounter_id']}') ;
EOF
         else #else visit blank
           #update
           if patient['voided'] == "0"
             Connection.execute <<EOF
UPDATE flat_table2
SET  symptom_present_diziness = 'Yes', symptom_present_diziness_enc_id = '#{patient['encounter_id']}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
           else #else voided
             Connection.execute <<EOF
UPDATE flat_table2
SET  symptom_present_diziness = NULL, symptom_present_diziness_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end voided
        end #end visit blank

      when fever
              patient_check = []
              patient_check = Connection.select_one("SELECT ID FROM flat_table2
                              WHERE patient_id = #{patient['person_id']}
                              and visit_date = '#{patient_visit_date}'")
        if patient_check.blank?
          #insert
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, symptom_present_fever, symptom_present_fever_enc_id)
VALUES('#{patient['person_id']}', DATE('#{patient_visit_date}'), 'Yes', '#{patient['encounter_id']}') ;
EOF
         else #else visit blank
           #update
           if patient['voided'] == "0"
             Connection.execute <<EOF
UPDATE flat_table2
SET  symptom_present_fever = 'Yes', symptom_present_fever_enc_id = '#{patient['encounter_id']}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
           else #else voided
             Connection.execute <<EOF
UPDATE flat_table2
SET  symptom_present_fever = NULL, symptom_present_fever_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end voided
        end #end visit blank

      when hepatitis
              patient_check = []
              patient_check = Connection.select_one("SELECT ID FROM flat_table2
                              WHERE patient_id = #{patient['person_id']}
                              and visit_date = '#{patient_visit_date}'")
        if patient_check.blank?
         #insert
         Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, symptom_present_hepatitis, symptom_present_hepatitis_enc_id)
VALUES('#{patient['person_id']}', DATE('#{patient_visit_date}'), 'Yes', '#{patient['encounter_id']}') ;
EOF
        else #else visit blank
          #update
          if patient['voided'] == "0"
            Connection.execute <<EOF
UPDATE flat_table2
SET  symptom_present_hepatitis = 'Yes', symptom_present_hepatitis_enc_id = '#{patient['encounter_id']}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          else #else voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  symptom_present_hepatitis = NULL, symptom_present_hepatitis_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
         end #end voided
       end #end visit blank

      when jaundice
              patient_check = []
              patient_check = Connection.select_one("SELECT ID FROM flat_table2
                              WHERE patient_id = #{patient['person_id']}
                              and visit_date = '#{patient_visit_date}'")
        if patient_check.blank?
          #insert
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, symptom_present_jaundice, symptom_present_jaundice_enc_id)
VALUES('#{patient['person_id']}', DATE('#{patient_visit_date}'), 'Yes', '#{patient['encounter_id']}') ;
EOF
        else #else visit blank
           #update
          if patient['voided'] == "0"
            Connection.execute <<EOF
UPDATE flat_table2
SET  symptom_present_jaundice = 'Yes', symptom_present_jaundice_enc_id = '#{patient['encounter_id']}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          else #else voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  symptom_present_jaundice = NULL, symptom_present_jaundice_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end voided
        end #end visit blank

      when kidney_failure
              patient_check = []
              patient_check = Connection.select_one("SELECT ID FROM flat_table2
                              WHERE patient_id = #{patient['person_id']}
                              and visit_date = '#{patient_visit_date}'")
        if patient_check.blank?
          #insert
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, symptom_present_kidney_failure, symptom_present_kidney_failure_enc_id)
VALUES('#{patient['person_id']}', DATE('#{patient_visit_date}'), 'Yes', '#{patient['encounter_id']}') ;
EOF
        else #else visit blank
          #update
          if patient['voided'] == "0"
            Connection.execute <<EOF
UPDATE flat_table2
SET  symptom_present_kidney_failure = 'Yes', symptom_present_kidney_failure_enc_id = '#{patient['encounter_id']}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          else #else voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  symptom_present_kidney_failure = NULL, symptom_present_kidney_failure_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end voided
        end #end visit blank

      when lactic_acidosis
              patient_check = []
              patient_check = Connection.select_one("SELECT ID FROM flat_table2
                              WHERE patient_id = #{patient['person_id']}
                              and visit_date = '#{patient_visit_date}'")
        if patient_check.blank?
          #insert
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, symptom_present_lactic_acidosis, symptom_present_lactic_acidosis_enc_id)
VALUES('#{patient['person_id']}', DATE('#{patient_visit_date}'), 'Yes', '#{patient['encounter_id']}') ;
EOF
        else #else visit blank
          #update
          if patient['voided'] == "0"
            Connection.execute <<EOF
UPDATE flat_table2
SET  symptom_present_lactic_acidosis = 'Yes', symptom_present_lactic_acidosis_enc_id = '#{patient['encounter_id']}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          else #else voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  symptom_present_lactic_acidosis = NULL, symptom_present_lactic_acidosis_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end voided
        end #end visit blank

      when leg_pain_numbness
              patient_check = []
              patient_check = Connection.select_one("SELECT ID FROM flat_table2
                              WHERE patient_id = #{patient['person_id']}
                              and visit_date = '#{patient_visit_date}'")
        if patient_check.blank?
          #insert
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, symptom_present_leg_pain_numbness, symptom_present_leg_pain_numbness_enc_id)
VALUES('#{patient['person_id']}', DATE('#{patient_visit_date}'), 'Yes', '#{patient['encounter_id']}') ;
EOF
        else #else visit blank
          #update
          if patient['voided'] == "0"
            Connection.execute <<EOF
UPDATE flat_table2
SET  symptom_present_leg_pain_numbness = 'Yes', symptom_present_leg_pain_numbness_enc_id = '#{patient['encounter_id']}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          else #else voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  symptom_present_leg_pain_numbness = NULL, symptom_present_leg_pain_numbness_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end voided
        end #end visit blank

      when lipodystrophy
              patient_check = []
              patient_check = Connection.select_one("SELECT ID FROM flat_table2
                              WHERE patient_id = #{patient['person_id']}
                              and visit_date = '#{patient_visit_date}'")
        if patient_check.blank?
          #insert
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, symptom_present_lipodystrophy, symptom_present_lipodystrophy_enc_id)
VALUES('#{patient['person_id']}', DATE('#{patient_visit_date}'), 'Yes', '#{patient['encounter_id']}') ;
EOF
        else #else visit blank
          #update
          if patient['voided'] == "0"
            Connection.execute <<EOF
UPDATE flat_table2
SET  symptom_present_lipodystrophy = 'Yes', symptom_present_lipodystrophy_enc_id = '#{patient['encounter_id']}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          else #else voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  symptom_present_lipodystrophy = NULL, symptom_present_lipodystrophy_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end voided
        end #end visit blank

      when symptom_no
              patient_check = []
              patient_check = Connection.select_one("SELECT ID FROM flat_table2
                              WHERE patient_id = #{patient['person_id']}
                              and visit_date = '#{patient_visit_date}'")
        if patient_check.blank?
          #insert
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, symptom_present_no, symptom_present_no_enc_id)
VALUES('#{patient['person_id']}', DATE('#{patient_visit_date}'), 'Yes', '#{patient['encounter_id']}') ;
EOF
        else #else visit blank
          #update
          if patient['voided'] == "0"
            Connection.execute <<EOF
UPDATE flat_table2
SET  symptom_present_no = 'Yes', symptom_present_no_enc_id = '#{patient['encounter_id']}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          else #else voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  symptom_present_no = NULL, symptom_present_no_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end voided
        end #end visit blank

      when other
              patient_check = []
              patient_check = Connection.select_one("SELECT ID FROM flat_table2
                              WHERE patient_id = #{patient['person_id']}
                              and visit_date = '#{patient_visit_date}'")
        if patient_check.blank?
          #insert
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, symptom_present_other_symptom, symptom_present_other_symptom_enc_id)
VALUES('#{patient['person_id']}', DATE('#{patient_visit_date}'), 'Yes', '#{patient['encounter_id']}') ;
EOF
        else #else visit blank
          #update
          if patient['voided'] == "0"
            Connection.execute <<EOF
UPDATE flat_table2
SET  symptom_present_other_symptom = 'Yes', symptom_present_other_symptom_enc_id = '#{patient['encounter_id']}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          else #else voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  symptom_present_other_symptom = NULL, symptom_present_other_symptom_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end voided
        end #end visit blank

      when peripheral_neuropathy
              patient_check = []
              patient_check = Connection.select_one("SELECT ID FROM flat_table2
                              WHERE patient_id = #{patient['person_id']}
                              and visit_date = '#{patient_visit_date}'")
        if patient_check.blank?
          #insert
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, symptom_present_peripheral_neuropathy, symptom_present_peripheral_neuropathy_enc_id)
VALUES('#{patient['person_id']}', DATE('#{patient_visit_date}'), 'Yes', '#{patient['encounter_id']}') ;
EOF
        else #else visit blank
          #update
          if patient['voided'] == "0"
            Connection.execute <<EOF
UPDATE flat_table2
SET  symptom_present_peripheral_neuropathy = 'Yes', symptom_present_peripheral_neuropathy_enc_id = '#{patient['encounter_id']}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          else #else voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  symptom_present_peripheral_neuropathy = NULL, symptom_present_peripheral_neuropathy_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end voided
        end #end visit blank

      when psychosis
              patient_check = []
              patient_check = Connection.select_one("SELECT ID FROM flat_table2
                              WHERE patient_id = #{patient['person_id']}
                              and visit_date = '#{patient_visit_date}'")
        if patient_check.blank?
          #insert
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, symptom_present_psychosis, symptom_present_psychosis_enc_id)
VALUES('#{patient['person_id']}', DATE('#{patient_visit_date}'), 'Yes', '#{patient['encounter_id']}') ;
EOF
        else #else visit blank
          #update
          if patient['voided'] == "0"
            Connection.execute <<EOF
UPDATE flat_table2
SET  symptom_present_psychosis = 'Yes', symptom_present_psychosis_enc_id = '#{patient['encounter_id']}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          else #else voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  symptom_present_psychosis = NULL, symptom_present_psychosis_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end voided
        end #end visit blank

      when renal_failure
              patient_check = []
              patient_check = Connection.select_one("SELECT ID FROM flat_table2
                              WHERE patient_id = #{patient['person_id']}
                              and visit_date = '#{patient_visit_date}'")
        if patient_check.blank?
          #insert
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, sysmptom_present_renal_failure, sysmptom_present_renal_failure_enc_id)
VALUES('#{patient['person_id']}', DATE('#{patient_visit_date}'), 'Yes', '#{patient['encounter_id']}') ;
EOF
        else #else visit blank
          #update
          if patient['voided'] == "0"
            Connection.execute <<EOF
UPDATE flat_table2
SET  sysmptom_present_renal_failure = 'Yes', sysmptom_present_renal_failure_enc_id = '#{patient['encounter_id']}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          else #else voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  sysmptom_present_renal_failure = NULL, sysmptom_present_renal_failure_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end voided
        end #end visit blank

      when skin_rash
              patient_check = []
              patient_check = Connection.select_one("SELECT ID FROM flat_table2
                              WHERE patient_id = #{patient['person_id']}
                              and visit_date = '#{patient_visit_date}'")
        if patient_check.blank?
          #insert
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, symptom_present_skin_rash, symptom_present_skin_rash_enc_id)
VALUES('#{patient['person_id']}', DATE('#{patient_visit_date}'), 'Yes', '#{patient['encounter_id']}') ;
EOF
        else #else visit blank
          #update
          if patient['voided'] == "0"
            Connection.execute <<EOF
UPDATE flat_table2
SET  symptom_present_skin_rash = 'Yes', symptom_present_skin_rash_enc_id = '#{patient['encounter_id']}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          else #else voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  symptom_present_skin_rash = NULL, symptom_present_skin_rash_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end voided
        end #end visit blank

      when vomiting
              patient_check = []
              patient_check = Connection.select_one("SELECT ID FROM flat_table2
                              WHERE patient_id = #{patient['person_id']}
                              and visit_date = '#{patient_visit_date}'")
        if patient_check.blank?
          #insert
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, symptom_present_vomiting, symptom_present_vomiting_enc_id)
VALUES('#{patient['person_id']}', DATE('#{patient_visit_date}'), 'Yes', '#{patient['encounter_id']}') ;
EOF
        else #else visit blank
          #update
          if patient['voided'] == "0"
            Connection.execute <<EOF
UPDATE flat_table2
SET  symptom_present_vomiting = 'Yes', symptom_present_vomiting_enc_id = '#{patient['encounter_id']}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          else #else voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  symptom_present_vomiting = NULL, symptom_present_vomiting_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end voided
        end #end visit blank

      when nightmares
              patient_check = []
              patient_check = Connection.select_one("SELECT ID FROM flat_table2
                              WHERE patient_id = #{patient['person_id']}
                              and visit_date = '#{patient_visit_date}'")
        if patient_check.blank?
          #insert
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, symptom_present_nightmares, symptom_present_nightmares_enc_id)
VALUES('#{patient['person_id']}', DATE('#{patient_visit_date}'), 'Yes', '#{patient['encounter_id']}') ;
EOF
        else #else visit blank
          #update
          if patient['voided'] == "0"
            Connection.execute <<EOF
UPDATE flat_table2
SET  symptom_present_nightmares = 'Yes', symptom_present_nightmares_enc_id = '#{patient['encounter_id']}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          else #else voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  symptom_present_nightmares = NULL, symptom_present_nightmares_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end voided
        end #end visit blank

      when gynaecomastia
              patient_check = []
              patient_check = Connection.select_one("SELECT ID FROM flat_table2
                              WHERE patient_id = #{patient['person_id']}
                              and visit_date = '#{patient_visit_date}'")
        if patient_check.blank?
          #insert
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, symptom_present_gynaecomastia, symptom_present_gynaecomastia_enc_id)
VALUES('#{patient['person_id']}', DATE('#{patient_visit_date}'), 'Yes', '#{patient['encounter_id']}') ;
EOF
        else #else visit blank
          #update
          if patient['voided'] == "0"
            Connection.execute <<EOF
UPDATE flat_table2
SET  symptom_present_gynaecomastia = 'Yes', symptom_present_gynaecomastia_enc_id = '#{patient['encounter_id']}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          else #else voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  symptom_present_gynaecomastia = NULL, symptom_present_gynaecomastia_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end voided
        end #end visit blank
      end #end symptom_present case statement
#end ------------------------------------------------------------------------------------------------------------------------------------------symptom preSET
    when drug_induced
      case patient['value_coded']
      when abdominal_pain
              patient_check = []
              patient_check = Connection.select_one("SELECT ID FROM flat_table2
                              WHERE patient_id = #{patient['person_id']}
                              and visit_date = '#{patient_visit_date}'")
        if patient_check.blank?
          #insert
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, drug_induced_abdominal_pain, drug_induced_abdominal_pain_enc_id)
VALUES('#{patient['person_id']}', DATE('#{patient_visit_date}'), 'Yes', '#{patient['encounter_id']}') ;
EOF
         else #else visit blank
           #update
           if patient['voided'] == "0"
             Connection.execute <<EOF
UPDATE flat_table2
SET  drug_induced_abdominal_pain = 'Yes', drug_induced_abdominal_pain_enc_id = '#{patient['encounter_id']}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
           else #else voided
             Connection.execute <<EOF
UPDATE flat_table2
SET  drug_induced_abdominal_pain = NULL, drug_induced_abdominal_pain_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end voided
        end #end visit blank

      when anemia
              patient_check = []
              patient_check = Connection.select_one("SELECT ID FROM flat_table2
                              WHERE patient_id = #{patient['person_id']}
                              and visit_date = '#{patient_visit_date}'")
        if patient_check.blank?
          #insert
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, drug_induced_anemia, drug_induced_anemia_enc_id)
VALUES('#{patient['person_id']}', DATE('#{patient_visit_date}'), 'Yes', '#{patient['encounter_id']}') ;
EOF
         else #else visit blank
           #update
           if patient['voided'] == "0"
             Connection.execute <<EOF
UPDATE flat_table2
SET  drug_induced_anemia = 'Yes', drug_induced_anemia_enc_id = '#{patient['encounter_id']}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
           else #else voided
             Connection.execute <<EOF
UPDATE flat_table2
SET  drug_induced_anemia = NULL, drug_induced_anemia_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end voided
        end #end visit blank

      when anorexia
              patient_check = []
              patient_check = Connection.select_one("SELECT ID FROM flat_table2
                              WHERE patient_id = #{patient['person_id']}
                              and visit_date = '#{patient_visit_date}'")
        if patient_check.blank?
          #insert
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, drug_induced_anorexia, drug_induced_anorexia_enc_id)
VALUES('#{patient['person_id']}', DATE('#{patient_visit_date}'), 'Yes', '#{patient['encounter_id']}') ;
EOF
         else #else visit blank
           #update
           if patient['voided'] == "0"
             Connection.execute <<EOF
UPDATE flat_table2
SET  drug_induced_anorexia = 'Yes', drug_induced_anorexia_enc_id = '#{patient['encounter_id']}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
           else #else voided
             Connection.execute <<EOF
UPDATE flat_table2
SET  drug_induced_anorexia = NULL, drug_induced_anorexia_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end voided
        end #end visit blank

      when blurry_vision
              patient_check = []
              patient_check = Connection.select_one("SELECT ID FROM flat_table2
                              WHERE patient_id = #{patient['person_id']}
                              and visit_date = '#{patient_visit_date}'")
        if patient_check.blank?
          #insert
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, drug_induced_blurry_vision, drug_induced_blurry_vision_enc_id)
VALUES('#{patient['person_id']}', DATE('#{patient_visit_date}'), 'Yes', '#{patient['encounter_id']}') ;
EOF
         else #else visit blank
           #update
           if patient['voided'] == "0"
             Connection.execute <<EOF
UPDATE flat_table2
SET  drug_induced_blurry_vision = 'Yes', drug_induced_blurry_vision_enc_id = '#{patient['encounter_id']}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
           else #else voided
             Connection.execute <<EOF
UPDATE flat_table2
SET  drug_induced_blurry_vision = NULL, drug_induced_blurry_vision_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end voided
        end #end visit blank

      when cough
              patient_check = []
              patient_check = Connection.select_one("SELECT ID FROM flat_table2
                              WHERE patient_id = #{patient['person_id']}
                              and visit_date = '#{patient_visit_date}'")
        if patient_check.blank?
          #insert
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, drug_induced_cough, drug_induced_cough_enc_id)
VALUES('#{patient['person_id']}', DATE('#{patient_visit_date}'), 'Yes', '#{patient['encounter_id']}') ;
EOF
         else #else visit blank
           #update
           if patient['voided'] == "0"
             Connection.execute <<EOF
UPDATE flat_table2
SET  drug_induced_cough = 'Yes', drug_induced_cough_enc_id = '#{patient['encounter_id']}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
           else #else voided
             Connection.execute <<EOF
UPDATE flat_table2
SET  drug_induced_cough = NULL, drug_induced_cough_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end voided
        end #end visit blank

      when diarrhea
              patient_check = []
              patient_check = Connection.select_one("SELECT ID FROM flat_table2
                              WHERE patient_id = #{patient['person_id']}
                              and visit_date = '#{patient_visit_date}'")
        if patient_check.blank?
          #insert
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, drug_induced_diarrhea, drug_induced_diarrhea_enc_id)
VALUES('#{patient['person_id']}', DATE('#{patient_visit_date}'), 'Yes', '#{patient['encounter_id']}') ;
EOF
         else #else visit blank
           #update
           if patient['voided'] == "0"
             Connection.execute <<EOF
UPDATE flat_table2
SET  drug_induced_diarrhea = 'Yes', drug_induced_diarrhea_enc_id = '#{patient['encounter_id']}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
           else #else voided
             Connection.execute <<EOF
UPDATE flat_table2
SET  drug_induced_diarrhea = NULL, drug_induced_diarrhea_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end voided
        end #end visit blank

      when diziness
              patient_check = []
              patient_check = Connection.select_one("SELECT ID FROM flat_table2
                              WHERE patient_id = #{patient['person_id']}
                              and visit_date = '#{patient_visit_date}'")
        if patient_check.blank?
          #insert
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, drug_induced_diziness, drug_induced_diziness_enc_id)
VALUES('#{patient['person_id']}', DATE('#{patient_visit_date}'), 'Yes', '#{patient['encounter_id']}') ;
EOF
         else #else visit blank
           #update
           if patient['voided'] == "0"
             Connection.execute <<EOF
UPDATE flat_table2
SET  drug_induced_diziness = 'Yes', drug_induced_diziness_enc_id = '#{patient['encounter_id']}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
           else #else voided
             Connection.execute <<EOF
UPDATE flat_table2
SET  drug_induced_diziness = NULL, drug_induced_diziness_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end voided
        end #end visit blank

      when fever
              patient_check = []
              patient_check = Connection.select_one("SELECT ID FROM flat_table2
                              WHERE patient_id = #{patient['person_id']}
                              and visit_date = '#{patient_visit_date}'")
        if patient_check.blank?
          #insert
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, drug_induced_fever, drug_induced_fever_enc_id)
VALUES('#{patient['person_id']}', DATE('#{patient_visit_date}'), 'Yes', '#{patient['encounter_id']}') ;
EOF
         else #else visit blank
           #update
           if patient['voided'] == "0"
             Connection.execute <<EOF
UPDATE flat_table2
SET  drug_induced_fever = 'Yes', drug_induced_fever_enc_id = '#{patient['encounter_id']}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
           else #else voided
             Connection.execute <<EOF
UPDATE flat_table2
SET  drug_induced_fever = NULL, drug_induced_fever_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end voided
        end #end visit blank

      when hepatitis
              patient_check = []
              patient_check = Connection.select_one("SELECT ID FROM flat_table2
                              WHERE patient_id = #{patient['person_id']}
                              and visit_date = '#{patient_visit_date}'")
        if patient_check.blank?
         #insert
         Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, drug_induced_hepatitis, drug_induced_hepatitis_enc_id)
VALUES('#{patient['person_id']}', DATE('#{patient_visit_date}'), 'Yes', '#{patient['encounter_id']}') ;
EOF
        else #else visit blank
          #update
          if patient['voided'] == "0"
            Connection.execute <<EOF
UPDATE flat_table2
SET  drug_induced_hepatitis = 'Yes', drug_induced_hepatitis_enc_id = '#{patient['encounter_id']}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          else #else voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  drug_induced_hepatitis = NULL, drug_induced_hepatitis_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
         end #end voided
       end #end visit blank

      when jaundice
              patient_check = []
              patient_check = Connection.select_one("SELECT ID FROM flat_table2
                              WHERE patient_id = #{patient['person_id']}
                              and visit_date = '#{patient_visit_date}'")
        if patient_check.blank?
          #insert
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, drug_induced_jaundice, drug_induced_jaundice_enc_id)
VALUES('#{patient['person_id']}', DATE('#{patient_visit_date}'), 'Yes', '#{patient['encounter_id']}') ;
EOF
        else #else visit blank
           #update
          if patient['voided'] == "0"
            Connection.execute <<EOF
UPDATE flat_table2
SET  drug_induced_jaundice = 'Yes', drug_induced_jaundice_enc_id = '#{patient['encounter_id']}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          else #else voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  drug_induced_jaundice = NULL, drug_induced_jaundice_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end voided
        end #end visit blank

      when kidney_failure
              patient_check = []
              patient_check = Connection.select_one("SELECT ID FROM flat_table2
                              WHERE patient_id = #{patient['person_id']}
                              and visit_date = '#{patient_visit_date}'")
        if patient_check.blank?
          #insert
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, drug_induced_kidney_failure, drug_induced_kidney_failure_enc_id)
VALUES('#{patient['person_id']}', DATE('#{patient_visit_date}'), 'Yes', '#{patient['encounter_id']}') ;
EOF
        else #else visit blank
          #update
          if patient['voided'] == "0"
            Connection.execute <<EOF
UPDATE flat_table2
SET  drug_induced_kidney_failure = 'Yes', drug_induced_kidney_failure_enc_id = '#{patient['encounter_id']}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          else #else voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  drug_induced_kidney_failure = NULL, drug_induced_kidney_failure_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end voided
        end #end visit blank

      when lactic_acidosis
              patient_check = []
              patient_check = Connection.select_one("SELECT ID FROM flat_table2
                              WHERE patient_id = #{patient['person_id']}
                              and visit_date = '#{patient_visit_date}'")
        if patient_check.blank?
          #insert
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, drug_induced_lactic_acidosis, drug_induced_lactic_acidosis_enc_id)
VALUES('#{patient['person_id']}', DATE('#{patient_visit_date}'), 'Yes', '#{patient['encounter_id']}') ;
EOF
        else #else visit blank
          #update
          if patient['voided'] == "0"
            Connection.execute <<EOF
UPDATE flat_table2
SET  drug_induced_lactic_acidosis = 'Yes', drug_induced_lactic_acidosis_enc_id = '#{patient['encounter_id']}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          else #else voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  drug_induced_lactic_acidosis = NULL, drug_induced_lactic_acidosis_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end voided
        end #end visit blank

      when leg_pain_numbness
              patient_check = []
              patient_check = Connection.select_one("SELECT ID FROM flat_table2
                              WHERE patient_id = #{patient['person_id']}
                              and visit_date = '#{patient_visit_date}'")
        if patient_check.blank?
          #insert
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, drug_induced_leg_pain_numbness, drug_induced_leg_pain_numbness_enc_id)
VALUES('#{patient['person_id']}', DATE('#{patient_visit_date}'), 'Yes', '#{patient['encounter_id']}') ;
EOF
        else #else visit blank
          #update
          if patient['voided'] == "0"
            Connection.execute <<EOF
UPDATE flat_table2
SET  drug_induced_leg_pain_numbness = 'Yes', drug_induced_leg_pain_numbness_enc_id = '#{patient['encounter_id']}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          else #else voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  drug_induced_leg_pain_numbness = NULL, drug_induced_leg_pain_numbness_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end voided
        end #end visit blank

      when lipodystrophy
              patient_check = []
              patient_check = Connection.select_one("SELECT ID FROM flat_table2
                              WHERE patient_id = #{patient['person_id']}
                              and visit_date = '#{patient_visit_date}'")
        if patient_check.blank?
          #insert
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, drug_induced_lipodystrophy, drug_induced_lipodystrophy_enc_id)
VALUES('#{patient['person_id']}', DATE('#{patient_visit_date}'), 'Yes', '#{patient['encounter_id']}') ;
EOF
        else #else visit blank
          #update
          if patient['voided'] == "0"
            Connection.execute <<EOF
UPDATE flat_table2
SET  drug_induced_lipodystrophy = 'Yes', drug_induced_lipodystrophy_enc_id = '#{patient['encounter_id']}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          else #else voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  drug_induced_lipodystrophy = NULL, drug_induced_lipodystrophy_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end voided
        end #end visit blank

      when symptom_no
              patient_check = []
              patient_check = Connection.select_one("SELECT ID FROM flat_table2
                              WHERE patient_id = #{patient['person_id']}
                              and visit_date = '#{patient_visit_date}'")
        if patient_check.blank?
          #insert
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, drug_induced_no, drug_induced_no_enc_id)
VALUES('#{patient['person_id']}', DATE('#{patient_visit_date}'), 'Yes', '#{patient['encounter_id']}') ;
EOF
        else #else visit blank
          #update
          if patient['voided'] == "0"
            Connection.execute <<EOF
UPDATE flat_table2
SET  drug_induced_no = 'Yes', drug_induced_no_enc_id = '#{patient['encounter_id']}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          else #else voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  drug_induced_no = NULL, drug_induced_no_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end voided
        end #end visit blank

      when other
              patient_check = []
              patient_check = Connection.select_one("SELECT ID FROM flat_table2
                              WHERE patient_id = #{patient['person_id']}
                              and visit_date = '#{patient_visit_date}'")
        if patient_check.blank?
          #insert
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, drug_induced_other, drug_induced_other_enc_id)
VALUES('#{patient['person_id']}', DATE('#{patient_visit_date}'), 'Yes', '#{patient['encounter_id']}') ;
EOF
        else #else visit blank
          #update
          if patient['voided'] == "0"
            Connection.execute <<EOF
UPDATE flat_table2
SET  drug_induced_other = 'Yes', drug_induced_other_enc_id = '#{patient['encounter_id']}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          else #else voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  drug_induced_other = NULL, drug_induced_other_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end voided
        end #end visit blank

      when peripheral_neuropathy
              patient_check = []
              patient_check = Connection.select_one("SELECT ID FROM flat_table2
                              WHERE patient_id = #{patient['person_id']}
                              and visit_date = '#{patient_visit_date}'")
        if patient_check.blank?
          #insert
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, drug_induced_peripheral_neuropathy, drug_induced_peripheral_neuropathy_enc_id)
VALUES('#{patient['person_id']}', DATE('#{patient_visit_date}'), 'Yes', '#{patient['encounter_id']}') ;
EOF
        else #else visit blank
          #update
          if patient['voided'] == "0"
            Connection.execute <<EOF
UPDATE flat_table2
SET  drug_induced_peripheral_neuropathy = 'Yes', drug_induced_peripheral_neuropathy_enc_id = '#{patient['encounter_id']}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          else #else voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  drug_induced_peripheral_neuropathy = NULL, drug_induced_peripheral_neuropathy_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end voided
        end #end visit blank

      when psychosis
              patient_check = []
              patient_check = Connection.select_one("SELECT ID FROM flat_table2
                              WHERE patient_id = #{patient['person_id']}
                              and visit_date = '#{patient_visit_date}'")
        if patient_check.blank?
          #insert
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, drug_induced_psychosis, drug_induced_psychosis_enc_id)
VALUES('#{patient['person_id']}', DATE('#{patient_visit_date}'), 'Yes', '#{patient['encounter_id']}') ;
EOF
        else #else visit blank
          #update
          if patient['voided'] == "0"
            Connection.execute <<EOF
UPDATE flat_table2
SET  drug_induced_psychosis = 'Yes', drug_induced_psychosis_enc_id = '#{patient['encounter_id']}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          else #else voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  drug_induced_psychosis = NULL, drug_induced_psychosis_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end voided
        end #end visit blank

      when renal_failure
              patient_check = []
              patient_check = Connection.select_one("SELECT ID FROM flat_table2
                              WHERE patient_id = #{patient['person_id']}
                              and visit_date = '#{patient_visit_date}'")
        if patient_check.blank?
          #insert
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, sysmptom_present_renal_failure, sysmptom_present_renal_failure_enc_id)
VALUES('#{patient['person_id']}', DATE('#{patient_visit_date}'), 'Yes', '#{patient['encounter_id']}') ;
EOF
        else #else visit blank
          #update
          if patient['voided'] == "0"
            Connection.execute <<EOF
UPDATE flat_table2
SET  sysmptom_present_renal_failure = 'Yes', sysmptom_present_renal_failure_enc_id = '#{patient['encounter_id']}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          else #else voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  sysmptom_present_renal_failure = NULL, sysmptom_present_renal_failure_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end voided
        end #end visit blank

      when skin_rash
              patient_check = []
              patient_check = Connection.select_one("SELECT ID FROM flat_table2
                              WHERE patient_id = #{patient['person_id']}
                              and visit_date = '#{patient_visit_date}'")
        if patient_check.blank?
          #insert
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, drug_induced_skin_rash, drug_induced_skin_rash_enc_id)
VALUES('#{patient['person_id']}', DATE('#{patient_visit_date}'), 'Yes', '#{patient['encounter_id']}') ;
EOF
        else #else visit blank
          #update
          if patient['voided'] == "0"
            Connection.execute <<EOF
UPDATE flat_table2
SET  drug_induced_skin_rash = 'Yes', drug_induced_skin_rash_enc_id = '#{patient['encounter_id']}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          else #else voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  drug_induced_skin_rash = NULL, drug_induced_skin_rash_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end voided
        end #end visit blank

      when vomiting
              patient_check = []
              patient_check = Connection.select_one("SELECT ID FROM flat_table2
                              WHERE patient_id = #{patient['person_id']}
                              and visit_date = '#{patient_visit_date}'")
        if patient_check.blank?
          #insert
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, drug_induced_vomiting, drug_induced_vomiting_enc_id)
VALUES('#{patient['person_id']}', DATE('#{patient_visit_date}'), 'Yes', '#{patient['encounter_id']}') ;
EOF
        else #else visit blank
          #update
          if patient['voided'] == "0"
            Connection.execute <<EOF
UPDATE flat_table2
SET  drug_induced_vomiting = 'Yes', drug_induced_vomiting_enc_id = '#{patient['encounter_id']}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          else #else voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  drug_induced_vomiting = NULL, drug_induced_vomiting_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end voided
        end #end visit blank

      when nightmares
              patient_check = []
              patient_check = Connection.select_one("SELECT ID FROM flat_table2
                              WHERE patient_id = #{patient['person_id']}
                              and visit_date = '#{patient_visit_date}'")
        if patient_check.blank?
          #insert
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, drug_induced_nightmares, drug_induced_nightmares_enc_id)
VALUES('#{patient['person_id']}', DATE('#{patient_visit_date}'), 'Yes', '#{patient['encounter_id']}') ;
EOF
        else #else visit blank
          #update
          if patient['voided'] == "0"
            Connection.execute <<EOF
UPDATE flat_table2
SET  drug_induced_nightmares = 'Yes', drug_induced_nightmares_enc_id = '#{patient['encounter_id']}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          else #else voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  drug_induced_nightmares = NULL, drug_induced_nightmares_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end voided
        end #end visit blank

      when gynaecomastia
              patient_check = []
              patient_check = Connection.select_one("SELECT ID FROM flat_table2
                              WHERE patient_id = #{patient['person_id']}
                              and visit_date = '#{patient_visit_date}'")
        if patient_check.blank?
          #insert
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, drug_induced_gynaecomastia, drug_induced_gynaecomastia_enc_id)
VALUES('#{patient['person_id']}', DATE('#{patient_visit_date}'), 'Yes', '#{patient['encounter_id']}') ;
EOF
        else #else visit blank
          #update
          if patient['voided'] == "0"
            Connection.execute <<EOF
UPDATE flat_table2
SET  drug_induced_gynaecomastia = 'Yes', drug_induced_gynaecomastia_enc_id = '#{patient['encounter_id']}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          else #else voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  drug_induced_gynaecomastia = NULL, drug_induced_gynaecomastia_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end voided
        end #end visit blank
      end #end drug_induced case statement
#---------------------------------------------------------------------------------------------------------------end drug_induced
    when malawi_art_side_effects
      updating_side_effects(patient['person_id'].to_i, patient['encounter_id'].to_i, patient['value_coded'].to_i, patient['obs_datetime'])
#--------------------------------------------------------------------------------------------------------------end malawi_art_side_effects
    end #closing case statement
  end #closing patient_hiv_consultation_obs
end

def process_treatment_obs(encounter, visit)
  yes_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
        LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
    WHERE  name = 'Yes' AND voided = 0 AND retired = 0 LIMIT 1")
  yes_answer = yes_record['concept_id']

  no_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
        LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
    WHERE  name = 'No' AND voided = 0 AND retired = 0 LIMIT 1")
  no_answer = no_record['concept_id']

  unknown_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
        LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
    WHERE  name = 'Unknown' AND voided = 0 AND retired = 0 LIMIT 1")
  unknown_answer = unknown_record['concept_id']

  regimen_category_treatment_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
        LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
    WHERE  name = 'Regimen category' AND voided = 0 AND retired = 0 LIMIT 1")
  regimen_category_treatment = regimen_category_treatment_record['concept_id']

  what_type_of_ARV_regimen_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
        LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
    WHERE  name = 'What type of antiretroviral regimen' AND voided = 0 AND retired = 0 LIMIT 1")
  what_type_of_ARV_regimen = what_type_of_ARV_regimen_record['concept_id']

  condoms_given_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
        LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
    WHERE  name = 'Condoms' AND voided = 0 AND retired = 0 LIMIT 1")
  condoms_given = condoms_given_record['concept_id']

  cpt_given_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
        LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
    WHERE  name = 'CPT Started' AND voided = 0 AND retired = 0 LIMIT 1")
  cpt_given = cpt_given_record['concept_id']

  isoniazid_given_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
        LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
    WHERE  name = 'isoniazid' AND voided = 0 AND retired = 0 LIMIT 1")
  isoniazid_given = isoniazid_given_record['concept_id']

  patient_treatment_obs = Connection.select_all("SELECT * FROM obs WHERE encounter_id = #{encounter['encounter_id']}")

  (patient_treatment_obs || []).each do |patient|
    patient_visit_date =  patient['obs_datetime'].to_date.strftime("%Y-%m-%d")
   flat_table_2_data = []
     flat_table_2_data = Connection.select_one("SELECT * FROM flat_table2
                                        WHERE patient_id = #{encounter['patient_id']}
                                        AND visit_date = '#{patient_visit_date}'")
    case patient['concept_id']
    when cpt_given
      if flat_table_2_data.blank?
        #insert
        answer_value = ""
        if (patient['value_coded'] == "#{yes_record['concept_id']}" || patient['value_text'] == "Yes")
          answer_value = 'Yes'
        elsif (patient['value_coded'] == "#{no_record['concept_id']}" || patient['value_text'] == "No")
          answer_value = 'No'
        elsif (patient['value_coded'] == "#{unknown_record['concept_id']}" || patient['value_text'] == "Unknown")
          answer_value = 'Unknown'
        end #end answer_value

        Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, cpt_given, cpt_given_enc_id)
VALUES('#{patient['person_id']}', DATE('#{patient_visit_date}'), '#{answer_value}', '#{patient['encounter_id']}') ;
EOF
      else #else visit blank?
          #update to null
          if patient['voided'] == "0"
            #update to value
            answer_value = ""
            if (patient['value_coded'] == "#{yes_record['concept_id']}" || patient['value_text'] == "Yes")
              answer_value = 'Yes'
            elsif (patient['value_coded'] == "#{no_record['concept_id']}" || patient['value_text'] == "No")
              answer_value = 'No'
            elsif (patient['value_coded'] == "#{unknown_record['concept_id']}" || patient['value_text'] == "Unknown")
              answer_value = 'Unknown'
            end #end answer_value

Connection.execute <<EOF
UPDATE flat_table2
SET  cpt_given = '#{answer_value}', cpt_given_enc_id = #{patient['encounter_id']}
WHERE flat_table2.id = '#{flat_table_2_data['ID']}';
EOF
        else #else voided
          Connection.execute <<EOF
UPDATE flat_table2
SET  cpt_given = NULL, cpt_given_enc_id = NULL
WHERE flat_table2.id = '#{flat_table_2_data['ID']}';
EOF
        end #end if voided
      end# end if visit blank
#---------------------------------------------------------------------------------------------------------------------end cpt_given1
    when isoniazid_given
            patient_check = []
            patient_check = Connection.select_one("SELECT ID FROM flat_table2
                              WHERE patient_id = #{patient['person_id']}
                              and visit_date = '#{patient_visit_date}'")
     if patient_check.blank?
        #insert
        answer_value = ""
        if (patient['value_coded'] == "#{yes_record['concept_id']}" || patient['value_text'] == "Yes")
          answer_value = 'Yes'
        elsif (patient['value_coded'] == "#{no_record['concept_id']}" || patient['value_text'] == "No")
          answer_value = 'No'
        elsif (patient['value_coded'] == "#{unknown_record['concept_id']}" || patient['value_text'] == "Unknown")
          answer_value = 'Unknown'
        end #end answer_value

        Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, ipt_given, ipt_given_enc_id)
VALUES('#{patient['person_id']}', DATE('#{patient_visit_date}'), '#{answer_value}', '#{patient['encounter_id']}') ;
EOF
      else #else visit blank?
          #update to null
          if patient['voided'] == "0"
            #update to value
            answer_value = ""
            if (patient['value_coded'] == "#{yes_record['concept_id']}" || patient['value_text'] == "Yes")
              answer_value = 'Yes'
            elsif (patient['value_coded'] == "#{no_record['concept_id']}" || patient['value_text'] == "No")
              answer_value = 'No'
            elsif (patient['value_coded'] == "#{unknown_record['concept_id']}" || patient['value_text'] == "Unknown")
              answer_value = 'Unknown'
            end #end answer_value

          Connection.execute <<EOF
UPDATE flat_table2
SET  ipt_given = '#{answer_value}', ipt_given_enc_id = #{patient['encounter_id']}
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
        else #else voided
          Connection.execute <<EOF
UPDATE flat_table2
SET  ipt_given = NULL, ipt_given_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
        end #end if voided
      end# end if visit blank
#---------------------------------------------------------------------------------------------------------------------end ipt_given1
    when regimen_category_treatment
      #including the regimen_category based on the function
      patient_check = []
      patient_check = Connection.select_one("SELECT ID FROM flat_table2
                              WHERE patient_id = #{patient['person_id']}
                              and visit_date = '#{patient_visit_date}'")

     patient_regimen_category = Connection.select_one("SELECT patient_current_regimen(#{patient['person_id']}, '#{patient_visit_date}') AS regimen")

     if patient_regimen_category.blank?
        regimen_category = "Unknown"
     else
        regimen_category = patient_regimen_category['regimen']
     end

     if patient_check.blank?
        #insert
        Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, regimen_category_treatment, regimen_category_treatment_enc_id, regimen_category)
VALUES('#{patient['person_id']}', DATE('#{patient_visit_date}'), '#{patient['value_text']}', '#{patient['encounter_id']}', #{regimen_category}) ;
EOF
      else #else visit blank
        #update
        if patient['voided'] == "0"
          Connection.execute <<EOF
UPDATE flat_table2
SET  regimen_category_treatment = '#{patient['value_text']}', regimen_category_treatment_enc_id = '#{patient['encounter_id']}', regimen_category = '#{regimen_category}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
        else #else voided
          Connection.execute <<EOF
UPDATE flat_table2
SET  regimen_category_treatment = NULL, regimen_category_treatment_enc_id = NULL, regimen_category = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
        end #end voided
      end #end visit blank
#---------------------------------------------------------------------------------------------------------------------end regimen_category_treatment
    when what_type_of_ARV_regimen
      answer_record = Connection.select_one("SELECT concept_name.name FROM concept_name
            LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
            WHERE  concept_name.concept_id = '#{patient['value_coded']}' AND voided = 0 AND retired = 0
            AND concept_name.concept_name_type = 'SHORT'")

                  patient_check = []
                  patient_check = Connection.select_one("SELECT ID FROM flat_table2
                              WHERE patient_id = #{patient['person_id']}
                              and visit_date = '#{patient_visit_date}'")
     arv_type = ""
     if answer_record.blank?
       arv_type = patient['value_text']
     else
       arv_type = answer_record['name']
     end

     if patient_check.blank?
        #insert
        Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, type_of_ARV_regimen_given, type_of_ARV_regimen_given_enc_id)
VALUES('#{patient['person_id']}', DATE('#{patient_visit_date}'), '#{arv_type}', '#{patient['encounter_id']}') ;
EOF
      else #else visit blank
        #update
        if patient['voided'] == "0"
          Connection.execute <<EOF
UPDATE flat_table2
SET  type_of_ARV_regimen_given = '#{arv_type}', type_of_ARV_regimen_given_enc_id = '#{patient['encounter_id']}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
        else #else voided
          Connection.execute <<EOF
UPDATE flat_table2
SET  type_of_ARV_regimen_given = NULL,type_of_ARV_regimen_given_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
        end #end voided
      end #end visit blank
  #---------------------------------------------------------------------------------------------------------------------end what_type_of_ARV_regimen
when condoms_given
          patient_check = []
      patient_check = Connection.select_one("SELECT ID FROM flat_table2
                              WHERE patient_id = #{patient['person_id']}
                              and visit_date = '#{patient_visit_date}'")
     if patient_check.blank?
        #insert
        Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, condoms_given, condoms_given_enc_id
VALUES('#{patient['person_id']}', DATE('#{patient_visit_date}'), '#{patient['value_numeric']}', '#{patient['encounter_id']}') ;
EOF
      else #else visit blank
        #update
        if patient['voided'] == "0"
          Connection.execute <<EOF
UPDATE flat_table2
SET  condoms_given = '#{patient['value_numeric']}', condoms_given_enc_id = '#{patient['encounter_id']}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
        else #else voided
          Connection.execute <<EOF
UPDATE flat_table2
SET  condoms_given = NULL, condoms_given_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
        end #end voided
      end #end visit blank
#---------------------------------------------------------------------------------------------------------------------end isoniazid_given
    end #close case statement
  end #end patient_treatment_obs
end

def process_dispensing_obs(encounter, visit)

  regimen_category_dispensed_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
        LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
    WHERE  name = 'Regimen category' AND voided = 0 AND retired = 0 LIMIT 1")
  regimen_category_dispensed = regimen_category_dispensed_record['concept_id']

  arv_regimens_received_construct_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
        LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
    WHERE  name = 'ARV regimens received abstracted construct' AND voided = 0 AND retired = 0 LIMIT 1")
  arv_regimens_received_construct = arv_regimens_received_construct_record['concept_id']

  drugs_dispensed_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
        LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
    WHERE  name = 'Condoms' AND voided = 0 AND retired = 0 LIMIT 1")
  drugs_dispensed = drugs_dispensed_record['concept_id']

  patient_dispensing_obs = Connection.select_all("SELECT * FROM obs WHERE encounter_id = #{encounter['encounter_id']}")

  (patient_dispensing_obs || []).each do |patient|
    patient_visit_date =  patient['obs_datetime'].to_date.strftime("%Y-%m-%d")
   flat_table_2_data = []
    flat_table_2_data = Connection.select_one("SELECT * FROM flat_table2
                                        WHERE patient_id = #{encounter['patient_id']}
                                        AND visit_date = '#{patient_visit_date}'")
    case patient['concept_id']
    when arv_regimens_received_construct
      answer_record = Connection.select_one("SELECT concept_name.name FROM concept_name
            LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
        WHERE  concept_name.concept_id = '#{patient['value_coded']}' AND voided = 0 AND retired = 0
            AND concept_name.concept_name_type = 'SHORT'")

     if flat_table_2_data.blank?
        #insert
        Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, arv_regimens_received_construct, arv_regimens_received_construct_enc_id)
VALUES('#{patient['person_id']}', DATE('#{patient_visit_date}'), '#{answer_record['name']}', '#{patient['encounter_id']}') ;
EOF
      else #else visit blank
        #update
        if patient['voided'] == "0"
          Connection.execute <<EOF
UPDATE flat_table2
SET  arv_regimens_received_construct = '#{answer_record['name']}', arv_regimens_received_construct_enc_id = '#{patient['encounter_id']}'
WHERE flat_table2.id = '#{flat_table_2_data['ID']}';
EOF
        else #else voided
          Connection.execute <<EOF
UPDATE flat_table2
SET  arv_regimens_received_construct = NULL,arv_regimens_received_construct_enc_id = NULL
WHERE flat_table2.id = '#{flat_table_2_data['ID']}';
EOF
        end #end voided
      end #end visit blank
#-----------------------------------------------------------------------------------end arv_regimens_received_construct

    when regimen_category_dispensed

      patient_check = []
      patient_check = Connection.select_one("SELECT ID FROM flat_table2
                              WHERE patient_id = #{patient['person_id']}
                              and visit_date = '#{patient_visit_date}'")
     patient_regimen_category = Connection.select_one("SELECT patient_current_regimen(#{patient['person_id']}, '#{patient_visit_date}') AS regimen")

     if patient_regimen_category.blank?
        regimen_category = "Unknown"
     else
        regimen_category = patient_regimen_category['regimen']
     end

     if patient_check.blank?
        
        #insert
        Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, regimen_category_dispensed, regimen_category_dispensed_enc_id, regimen_category)
VALUES('#{patient['person_id']}', DATE('#{patient_visit_date}'), '#{patient['value_text']}', '#{patient['encounter_id']}', '#{regimen_category}') ;
EOF
      else #else visit blank
        #update
        if patient['voided'] == "0"
          Connection.execute <<EOF
UPDATE flat_table2
SET  regimen_category_dispensed = '#{patient['value_text']}', regimen_category_dispensed_enc_id = '#{patient['encounter_id']}', regimen_category = '#{regimen_category}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
        else #else voided
          Connection.execute <<EOF
UPDATE flat_table2
SET  regimen_category_dispensed = NULL, regimen_category_dispensed_enc_id = NULL, regimen_category = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
        end #end voided
      end #end visit blank
#---------------------------------------------------------------------------------------------------------------------end regimen_category_dispensed
    end #end of case statement
  end #end of patient_dispensing_obs
end

def process_appointment_obs(encounter, visit)
  appointment_date_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
                LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
WHERE  name = 'Appointment date' AND voided = 0 AND retired = 0 LIMIT 1")
  appointment_date = appointment_date_record['concept_id']

  appointment_date_obs = Connection.select_all("SELECT * FROM obs WHERE encounter_id = #{encounter['encounter_id']}")

  (appointment_date_obs || []).each do |patient|
    case patient['concept_id']
    when appointment_date
      patient_visit_date =  patient['obs_datetime'].to_date.strftime("%Y-%m-%d")
   flat_table_2_data = []
      flat_table_2_data = Connection.select_one("SELECT * FROM flat_table2
                                          WHERE patient_id = #{encounter['patient_id']}
                                          AND visit_date = '#{patient_visit_date}'")

     if flat_table_2_data.blank?
        #insert
        Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, appointment_date, appointment_date_enc_id)
VALUES('#{patient['person_id']}', DATE('#{patient_visit_date}'), DATE('#{patient['value_datetime']}'), '#{patient['encounter_id']}') ;
EOF
      else #else visit blank
        #update
        if patient['voided'] == "0"
          Connection.execute <<EOF
UPDATE flat_table2
SET  appointment_date = DATE('#{patient['value_datetime']}'), appointment_date_enc_id = '#{patient['encounter_id']}'
WHERE flat_table2.id = '#{flat_table_2_data['ID']}';
EOF
        else #else voided
          Connection.execute <<EOF
UPDATE flat_table2
SET  appointment_date = NULL, appointment_date_enc_id = NULL
WHERE flat_table2.id = '#{flat_table_2_data['ID']}';
EOF
        end #end voided
      end #end visit blank
#----------------------------------------------------------------------------------------------------------------------end appointment_date
    end #end appointment_date case statement
  end #end appointment_date obs
end

def process_exit_from_care_obs(encounter, visit)
  reason_for_exiting_from_care_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
                LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                WHERE  name = 'Reason for exiting care' AND voided = 0 AND retired = 0 LIMIT 1")
  reason_for_exiting_from_care = reason_for_exiting_from_care_record['concept_id']

  transfer_out_to_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
                LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                WHERE  name = 'Transfer out to' AND voided = 0 AND retired = 0 LIMIT 1")
  transfer_out_to = transfer_out_to_record['concept_id']

  date_of_exiting_care_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
                LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                WHERE  name = 'Date of exiting care' AND voided = 0 AND retired = 0 LIMIT 1")
  date_of_exiting_care = date_of_exiting_care_record['concept_id']

  exit_from_care_obs = Connection.select_all("SELECT * FROM obs WHERE encounter_id = #{encounter['encounter_id']}")

  (exit_from_care_obs || []).each do |patient|
    case patient['concept_id']
    when reason_for_exiting_from_care
      patient_visit_date =  patient['obs_datetime'].to_date.strftime("%Y-%m-%d")

      value_record = Connection.select_one("SELECT concept_name.name AS name FROM concept_name
                    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
                    WHERE concept_name.concept_id = #{patient['value_coded'].to_i} AND voided = 0 AND retired = 0 LIMIT 1")

      flat_table_2_data = []
      flat_table_2_data = Connection.select_one("SELECT * FROM flat_table2
                                          WHERE patient_id = #{encounter['patient_id']}
                                          AND visit_date = '#{patient_visit_date}'")

     if flat_table_2_data.blank?
        #insert
        Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, reason_for_exiting_from_care, reason_for_exiting_from_care_enc_id)
VALUES('#{patient['person_id']}', '#{value_record['name']}', #{patient['encounter_id']}') ;
EOF
      else #else visit blank
        #update
        if patient['voided'] == "0"
          Connection.execute <<EOF
UPDATE flat_table2
SET  reason_for_exiting_from_care =  '#{value_record['name']}', reason_for_exiting_from_care_enc_id = '#{patient['encounter_id']}'
WHERE flat_table2.id = '#{flat_table_2_data['ID']}';
EOF
        else #else voided
          Connection.execute <<EOF
UPDATE flat_table2
SET  reason_for_exiting_from_care = NULL, reason_for_exiting_from_care_enc_id = NULL
WHERE flat_table2.id = '#{flat_table_2_data['ID']}';
EOF
        end #end voided
      end #end visit blank
#-----------------------------------------------------------------------------------------------------------------end reason exit_from_care_obs
when transfer_out_to
  patient_visit_date =  patient['obs_datetime'].to_date.strftime("%Y-%m-%d")

  value_record = Connection.select_one("SELECT name FROM location WHERE location_id = #{patient['value_numeric'].to_i}")
  value_record = patient['value_text'] if value_record.blank?

  flat_table_2_data = []
  flat_table_2_data = Connection.select_one("SELECT * FROM flat_table2
                                      WHERE patient_id = #{encounter['patient_id']}
                                      AND visit_date = '#{patient_visit_date}'")

  if flat_table_2_data.blank?
    #insert
    Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, transfer_out_location, transfer_out_location_enc_id)
VALUES('#{patient['person_id']}', '#{value_record['name']}', #{patient['encounter_id']}') ;
EOF
  else #else visit blank
    #update
    if patient['voided'] == "0"
      Connection.execute <<EOF
UPDATE flat_table2
SET  transfer_out_location =  '#{value_record['name']}', transfer_out_location_enc_id = '#{patient['encounter_id']}'
WHERE flat_table2.id = '#{flat_table_2_data['ID']}';
EOF
    else #else voided
      Connection.execute <<EOF
UPDATE flat_table2
SET  transfer_out_location = NULL, transfer_out_location_enc_id = NULL
WHERE flat_table2.id = '#{flat_table_2_data['ID']}';
EOF
    end #end voided
  end #end visit blank
#-----------------------------------------------------------------------------------------------------------------end transfer out
  when date_of_exiting_care
    patient_visit_date =  patient['obs_datetime'].to_date.strftime("%Y-%m-%d")

    flat_table_2_data = []
    flat_table_2_data = Connection.select_one("SELECT * FROM flat_table2
                                        WHERE patient_id = #{encounter['patient_id']}
                                        AND visit_date = '#{patient_visit_date}'")

   if flat_table_2_data.blank?
      #insert
    Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, date_exiting_from_care, date_of_exiting_care_enc_id)
VALUES('#{patient['person_id']}', '#{patient['value_datetime']}', #{patient['encounter_id']}') ;
EOF
    else #else visit blank
      #update
      if patient['voided'] == "0"
        Connection.execute <<EOF
UPDATE flat_table2
SET  date_exiting_from_care =  '#{patient['value_datetime']}', date_exiting_from_care_enc_id = '#{patient['encounter_id']}'
WHERE flat_table2.id = '#{flat_table_2_data['ID']}';
EOF
      else #else voided
        Connection.execute <<EOF
UPDATE flat_table2
SET  date_exiting_from_care = NULL, date_exiting_from_care_enc_id = NULL
WHERE flat_table2.id = '#{flat_table_2_data['ID']}';
EOF
      end #end voided
    end #end visit blank
#-----------------------------------------------------------------------------------------------------------------end date exit from care
    end #end appointment_date case statement
  end #end appointment_date obs
end

def process_art_adherence_obs(encounter, visit)
  amount_of_drug_brought_to_clinic_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
          LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
          WHERE name = 'Amount of drug brought to clinic' AND voided = 0 AND retired = 0 LIMIT 1")
  amount_of_drug_brought_to_clinic = amount_of_drug_brought_to_clinic_record['concept_id'].to_i

  amount_of_drug_remaining_at_home_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
            LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
            WHERE name = 'Amount of drug remaining at home' AND voided = 0 AND retired = 0 LIMIT 1")
  amount_of_drug_remaining_at_home = amount_of_drug_remaining_at_home_record['concept_id'].to_i

  what_was_the_patient_adherence_for_this_drug_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
            LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
            WHERE name = 'What was the patients adherence for this drug order' AND voided = 0 AND retired = 0 LIMIT 1")
  what_was_the_patient_adherence_for_this_drug = what_was_the_patient_adherence_for_this_drug_record['concept_id'].to_i

  missed_hiv_drug_construct_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
            LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
            WHERE name = 'Missed HIV drug construct' AND voided = 0 AND retired = 0 LIMIT 1")
  missed_hiv_drug_construct = missed_hiv_drug_construct_record['concept_id'].to_i

  patient_adh = {}; amount_of_drug_brought_to_clinic_hash  = {}
  missed_hiv_drug_const_hash  = {}; patient_adherence_hash  = {}
  patient_adherence_enc_ids = {}; amount_of_drug_remaining_at_home_hash  = {}
  amount_of_remaining_drug_order_id_hash = {}; amount_voided = {}

  #Find the patient's minimum adherence if the regimen contain several drugs
  patient_minimum_adherence = Connection.select_one("select MIN(ifnull(value_text, value_numeric)) as adherence 
                                        from obs where concept_id = #{what_was_the_patient_adherence_for_this_drug}
                                        and person_id = #{encounter['patient_id'].to_i}
                                        and DATE('#{encounter['encounter_datetime'].to_date.strftime('%Y-%m-%d')}')")

  patient_obs = Connection.select_all("select person_id, order_id, concept_id, value_coded, ifnull(value_numeric, value_text) as value, obs_datetime, encounter_id, voided
                                       from obs where encounter_id = #{encounter['encounter_id'].to_i}")
    (patient_obs || []).each do |adh|
    unless adh['order_id'].to_i <= 0
      if patient_adh.blank?
        patient_adh[adh['order_id'].to_i] = adh['order_id'].to_i
        amount_voided[adh['order_id'].to_i] = adh['voided'].to_i
        amount_of_remaining_drug_order_id_hash[adh['order_id'].to_i] = adh['order_id'].to_i rescue nil

        if adh['concept_id'].to_i == 2540 #amount brought
          if adh['value'].blank?
            amount_of_drug_brought_to_clinic_hash[adh['order_id'].to_i] = "NULL"
          else
            amount_of_drug_brought_to_clinic_hash[adh['order_id'].to_i] = adh['value']
          end
        #else
         # amount_of_drug_brought_to_clinic_hash[adh['order_id'].to_i] = "NULL"
        end

        if adh['concept_id'].to_i == 2667 #missed hiv drug
          missed_hiv_drug_const_hash[adh['order_id'].to_i] = adh['value'] rescue nil
        #else
         # missed_hiv_drug_const_hash[adh['order_id'].to_i] = "NULL"
        end

        if adh['concept_id'].to_i == 6987 #patient adherence
          patient_adherence_hash[adh['order_id'].to_i] = adh['value'] rescue nil
          patient_adherence_enc_ids[adh['order_id'].to_i] = adh['encounter_id'] rescue nil
        #else
         # patient_adherence_hash[adh['order_id'].to_i] = "NULL"
         # patient_adherence_enc_ids[adh['order_id'].to_i] = "NULL"
        end

        if adh['concept_id'].to_i == 6781 #amount remaining
          amount_of_drug_remaining_at_home_hash[adh['order_id'].to_i] = adh['value'] rescue nil
        #else
        #  amount_of_drug_remaining_at_home_hash[adh['order_id'].to_i] = "NULL"
        end
      else
        patient_adh.store(adh['order_id'].to_i, adh['order_id'].to_i)
        amount_voided.store(adh['order_id'].to_i, adh['voided'].to_i)
        amount_of_remaining_drug_order_id_hash.store(adh['order_id'].to_i, adh['order_id'])
        if adh['concept_id'].to_i == 2540 #amount brought
          amount_of_drug_brought_to_clinic_hash.store(adh['order_id'].to_i, adh['value'])
        #else
        #  amount_of_drug_brought_to_clinic_hash.store(adh['order_id'].to_i, "NULL")
        end

        if adh['concept_id'].to_i == 2667 #missed hiv drug
          missed_hiv_drug_const_hash.store(adh['order_id'].to_i, adh['value'])
        #else
        #  missed_hiv_drug_const_hash.store(adh['order_id'].to_i, "NULL")
        end

        if adh['concept_id'].to_i == 6987 #patient adherence
          patient_adherence_hash.store(adh['order_id'].to_i, adh['value'])
          patient_adherence_enc_ids.store(adh['order_id'].to_i, adh['encounter_id'])
        #else
         # patient_adherence_hash.store(adh['order_id'].to_i, "NULL")
         # patient_adherence_enc_ids.store(adh['order_id'].to_i, "NULL")
        end

        if adh['concept_id'].to_i == 6781 #amount remaining
          amount_of_drug_remaining_at_home_hash.store(adh['order_id'].to_i, adh['value'])
        #else
        #  amount_of_drug_remaining_at_home_hash.store(adh['order_id'].to_i, "NULL")
        end
      end
    end
    end

  count = 1
  (patient_adh || []).each do |order_id, data|
    case count
      when 1
        if amount_of_drug_brought_to_clinic_hash[order_id].blank?
          @amount_of_drug1_brought_to_clinic = "NULL"
          @amount_of_remaining_drug1_order_id = "NULL"
          @amount_voided1 = "NULL"
        else
          @amount_of_drug1_brought_to_clinic = amount_of_drug_brought_to_clinic_hash[order_id]
          @amount_of_remaining_drug1_order_id = amount_of_remaining_drug_order_id_hash[order_id]
          @amount_voided1 = amount_voided[order_id]
        end

        if amount_of_drug_remaining_at_home_hash[order_id].blank?
          @amount_of_drug1_remaining_at_home = "NULL"
        else
          @amount_of_drug1_remaining_at_home = amount_of_drug_remaining_at_home_hash[order_id]
        end

        if patient_adherence_hash[order_id].blank?
          @what_was_the_patient_adherence_for_this_drug1 = "NULL"
          @what_was_the_patient_adherence_for_this_drug1_enc_id = "NULL"
        else
          @what_was_the_patient_adherence_for_this_drug1 = patient_adherence_hash[order_id]
          @what_was_the_patient_adherence_for_this_drug1_enc_id = patient_adherence_enc_ids[order_id]
        end

        if missed_hiv_drug_const_hash[order_id].blank?
          @missed_hiv_drug_construct1 = "NULL"
        else
          @missed_hiv_drug_construct1 = missed_hiv_drug_const_hash[order_id]
        end

      count << 1
    when 2
      if amount_of_drug_brought_to_clinic_hash[order_id].blank?
        @amount_of_drug2_brought_to_clinic = "NULL"
        @amount_of_remaining_drug2_order_id = "NULL"
        @amount_voided2 = "NULL"
      else
        @amount_of_drug2_brought_to_clinic = amount_of_drug_brought_to_clinic_hash[order_id]
        @amount_of_remaining_drug2_order_id = amount_of_remaining_drug_order_id_hash[order_id]
        @amount_voided2 = amount_voided[order_id]
      end

      if amount_of_drug_remaining_at_home_hash[order_id].blank?
        @amount_of_drug2_remaining_at_home = "NULL"
      else
        @amount_of_drug2_remaining_at_home = amount_of_drug_remaining_at_home_hash[order_id]
      end

      if patient_adherence_hash[order_id].blank?
        @what_was_the_patient_adherence_for_this_drug2 = "NULL"
        @what_was_the_patient_adherence_for_this_drug2_enc_id = "NULL"
      else
        @what_was_the_patient_adherence_for_this_drug2 = patient_adherence_hash[order_id]
        @what_was_the_patient_adherence_for_this_drug2_enc_id = patient_adherence_enc_ids[order_id]
      end

      if missed_hiv_drug_const_hash[order_id].blank?
        @missed_hiv_drug_construct2 = "NULL"
      else
        @missed_hiv_drug_construct2 = missed_hiv_drug_const_hash[order_id]
      end

      count << 1
    when 3
      if amount_of_drug_brought_to_clinic_hash[order_id].blank?
        @amount_of_drug3_brought_to_clinic = "NULL"
        @amount_of_remaining_drug3_order_id = "NULL"
        @amount_voided3 = "NULL"
      else
        @amount_of_drug3_brought_to_clinic = amount_of_drug_brought_to_clinic_hash[order_id]
        @amount_of_remaining_drug3_order_id = amount_of_remaining_drug_order_id_hash[order_id]
        @amount_voided3 = amount_voided[order_id]
      end

      if amount_of_drug_remaining_at_home_hash[order_id].blank?
        @amount_of_drug3_remaining_at_home = "NULL"
      else
        @amount_of_drug3_remaining_at_home = amount_of_drug_remaining_at_home_hash[order_id]
      end

      if patient_adherence_hash[order_id].blank?
        @what_was_the_patient_adherence_for_this_drug3 = "NULL"
        @what_was_the_patient_adherence_for_this_drug3_enc_id = "NULL"
      else
        @what_was_the_patient_adherence_for_this_drug3 = patient_adherence_hash[order_id]
        @what_was_the_patient_adherence_for_this_drug3_enc_id = patient_adherence_enc_ids[order_id]
      end

      if missed_hiv_drug_const_hash[order_id].blank?
        @missed_hiv_drug_construct3 = "NULL"
      else
        @missed_hiv_drug_construct3 = missed_hiv_drug_const_hash[order_id]
      end

      count << 1
    when 4
      if amount_of_drug_brought_to_clinic_hash[order_id].blank?
        @amount_of_drug4_brought_to_clinic = "NULL"
        @amount_of_remaining_drug4_order_id = "NULL"
        @amount_voided4 = "NULL"
      else
        @amount_of_drug4_brought_to_clinic = amount_of_drug_brought_to_clinic_hash[order_id]
        @amount_of_remaining_drug4_order_id = amount_of_remaining_drug_order_id_hash[order_id]
        @amount_voided4 = amount_voided[order_id]
      end

      if amount_of_drug_remaining_at_home_hash[order_id].blank?
        @amount_of_drug4_remaining_at_home = "NULL"
      else
        @amount_of_drug4_remaining_at_home = amount_of_drug_remaining_at_home_hash[order_id]
      end

      if patient_adherence_hash[order_id].blank?
        @what_was_the_patient_adherence_for_this_drug4 = "NULL"
        @what_was_the_patient_adherence_for_this_drug4_enc_id = "NULL"
      else
        @what_was_the_patient_adherence_for_this_drug4 = patient_adherence_hash[order_id]
        @what_was_the_patient_adherence_for_this_drug4_enc_id = patient_adherence_enc_ids[order_id]
      end

      if missed_hiv_drug_const_hash[order_id].blank?
        @missed_hiv_drug_construct4 = "NULL"
      else
        @missed_hiv_drug_construct4 = missed_hiv_drug_const_hash[order_id]
      end

      count << 1
    when 5
      if amount_of_drug_brought_to_clinic_hash[order_id].blank?
        @amount_of_drug5_brought_to_clinic = "NULL"
        @amount_of_remaining_drug5_order_id = "NULL"
        @amount_voided5 = "NULL"
      else
        @amount_of_drug5_brought_to_clinic = amount_of_drug_brought_to_clinic_hash[order_id]
        @amount_of_remaining_drug5_order_id = amount_of_remaining_drug_order_id_hash[order_id]
        @amount_voided5 = amount_voided[order_id]
      end

      if amount_of_drug_remaining_at_home_hash[order_id].blank?
        @amount_of_drug5_remaining_at_home = "NULL"
      else
        @amount_of_drug5_remaining_at_home = amount_of_drug_remaining_at_home_hash[order_id]
      end

      if patient_adherence_hash[order_id].blank?
        @what_was_the_patient_adherence_for_this_drug5 = "NULL"
        @what_was_the_patient_adherence_for_this_drug5_enc_id = "NULL"
      else
        @what_was_the_patient_adherence_for_this_drug5 = patient_adherence_hash[order_id]
        @what_was_the_patient_adherence_for_this_drug5_enc_id = patient_adherence_enc_ids[order_id]
      end

      if missed_hiv_drug_const_hash[order_id].blank?
        @missed_hiv_drug_construct5 = "NULL"
      else
        @missed_hiv_drug_construct5 = missed_hiv_drug_const_hash[order_id]
      end

      count << 1
    end #end case statement
  end #end patient_orders

  unless patient_minimum_adherence.blank?
    if patient_minimum_adherence['adherence'].to_f >= 95
      adherence = 'Adherent'
    elsif patient_minimum_adherence['adherence'].to_f < 95
      adherence = 'Not adherent'
    elsif patient_minimum_adherence['adherence'].match(/unknown/i)
      adherence = 'Unknown'
    end

    if @amount_voided1 == 0
      Connection.execute <<EOF
        UPDATE flat_table2
        SET
          patient_art_adherence = '#{adherence}'
        WHERE flat_table2.patient_id = #{encounter['patient_id']} and flat_table2.visit_date = DATE('#{encounter['encounter_datetime']}');
EOF
    else #else voided
    Connection.execute <<EOF
      UPDATE flat_table2
      SET
        patient_art_adherence = NULL
      WHERE flat_table2.patient_id = #{encounter['patient_id']} and flat_table2.visit_date = DATE('#{encounter['encounter_datetime']}');
EOF
    end #end voided
  end

  unless @amount_of_drug1_brought_to_clinic.blank?
    if @amount_voided1 == 0
      Connection.execute <<EOF
UPDATE flat_table2
SET
  amount_of_drug1_brought_to_clinic = '#{@amount_of_drug1_brought_to_clinic}',
  amount_of_drug1_remaining_at_home = '#{@amount_of_drug1_remaining_at_home}',
  what_was_the_patient_adherence_for_this_drug1 = '#{@what_was_the_patient_adherence_for_this_drug1}',
  what_was_the_patient_adherence_for_this_drug1_enc_id = '#{@what_was_the_patient_adherence_for_this_drug1_enc_id}',
  missed_hiv_drug_construct1 = '#{@missed_hiv_drug_construct1}',
  amount_of_remaining_drug1_order_id = '#{@amount_of_remaining_drug1_order_id}'

WHERE flat_table2.patient_id = #{encounter['patient_id']} and flat_table2.visit_date = DATE('#{encounter['encounter_datetime']}');
EOF
    else #else voided
      Connection.execute <<EOF
UPDATE flat_table2
SET
amount_of_drug1_brought_to_clinic = NULL,
amount_of_drug1_remaining_at_home = NULL,
what_was_the_patient_adherence_for_this_drug1 = NULL,
what_was_the_patient_adherence_for_this_drug1_enc_id = NULL,
missed_hiv_drug_construct1 = NULL,
amount_of_remaining_drug1_order_id = NULL
WHERE flat_table2.patient_id = #{encounter['patient_id']} and flat_table2.visit_date = DATE('#{encounter['encounter_datetime']}');
EOF
    end #end voided
  end #end unless amount_of_remaining_drug1_order_id

  unless @amount_of_drug2_brought_to_clinic.blank?
    if @amount_voided2 == 0
      Connection.execute <<EOF
UPDATE flat_table2
SET
  amount_of_drug2_brought_to_clinic = #{@amount_of_drug2_brought_to_clinic},
  amount_of_drug2_remaining_at_home = #{@amount_of_drug2_remaining_at_home},
  what_was_the_patient_adherence_for_this_drug2 = #{@what_was_the_patient_adherence_for_this_drug2},
  what_was_the_patient_adherence_for_this_drug2_enc_id = #{@what_was_the_patient_adherence_for_this_drug2_enc_id},
  missed_hiv_drug_construct2 = #{@missed_hiv_drug_construct2},
  amount_of_remaining_drug2_order_id = #{@amount_of_remaining_drug2_order_id}
WHERE flat_table2.patient_id = #{encounter['patient_id']} and flat_table2.visit_date = DATE('#{encounter['encounter_datetime']}');
EOF
    else #else voided
      Connection.execute <<EOF
UPDATE flat_table2
SET
amount_of_drug2_brought_to_clinic = NULL,
amount_of_drug2_remaining_at_home = NULL,
what_was_the_patient_adherence_for_this_drug2 = NULL,
what_was_the_patient_adherence_for_this_drug2_enc_id = NULL,
missed_hiv_drug_construct2 = NULL,
amount_of_remaining_drug2_order_id = NULL
WHERE flat_table2.patient_id = #{encounter['patient_id']} and flat_table2.visit_date = DATE('#{encounter['encounter_datetime']}');
EOF
    end #end voided
  end #end unless amount_of_remaining_drug2_order_id

  unless @amount_of_drug3_brought_to_clinic.blank?
    if @amount_voided3 == 0
      Connection.execute <<EOF
UPDATE flat_table2
SET
  amount_of_drug3_brought_to_clinic = #{@amount_of_drug3_brought_to_clinic},
  amount_of_drug3_remaining_at_home = #{@amount_of_drug3_remaining_at_home},
  what_was_the_patient_adherence_for_this_drug3 = #{@what_was_the_patient_adherence_for_this_drug3},
  what_was_the_patient_adherence_for_this_drug3_enc_id = #{@what_was_the_patient_adherence_for_this_drug3_enc_id},
  missed_hiv_drug_construct3 = #{@missed_hiv_drug_construct3},
  amount_of_remaining_drug3_order_id = #{@amount_of_remaining_drug3_order_id}
WHERE flat_table2.patient_id = #{encounter['patient_id']} and flat_table2.visit_date = DATE('#{encounter['encounter_datetime']}');
EOF
    else #else voided
      Connection.execute <<EOF
UPDATE flat_table2
SET
amount_of_drug3_brought_to_clinic = NULL,
amount_of_drug3_remaining_at_home = NULL,
what_was_the_patient_adherence_for_this_drug3 = NULL,
what_was_the_patient_adherence_for_this_drug3_enc_id = NULL,
missed_hiv_drug_construct3 = NULL,
amount_of_remaining_drug3_order_id = NULL
WHERE flat_table2.patient_id = #{encounter['patient_id']} and flat_table2.visit_date = DATE('#{encounter['encounter_datetime']}');
EOF
    end #end voided
  end #end unless amount_of_remaining_drug3_order_id

  unless @amount_of_drug4_brought_to_clinic.blank?
    if @amount_voided4 == 0
      Connection.execute <<EOF
UPDATE flat_table2
SET
  amount_of_drug4_brought_to_clinic = #{@amount_of_drug4_brought_to_clinic},
  amount_of_drug4_remaining_at_home = #{@amount_of_drug4_remaining_at_home},
  what_was_the_patient_adherence_for_this_drug4 = #{@what_was_the_patient_adherence_for_this_drug4},
  what_was_the_patient_adherence_for_this_drug4_enc_id = #{@what_was_the_patient_adherence_for_this_drug4_enc_id},
  missed_hiv_drug_construct4 = #{@missed_hiv_drug_construct4},
  amount_of_remaining_drug4_order_id = #{@amount_of_remaining_drug4_order_id}
WHERE flat_table2.patient_id = #{encounter['patient_id']} and flat_table2.visit_date = DATE('#{encounter['encounter_datetime']}');
EOF
    else #else voided
      Connection.execute <<EOF
UPDATE flat_table2
SET
amount_of_drug4_brought_to_clinic = NULL,
amount_of_drug4_remaining_at_home = NULL,
what_was_the_patient_adherence_for_this_drug4 = NULL,
what_was_the_patient_adherence_for_this_drug4_enc_id = NULL,
missed_hiv_drug_construct4 = NULL,
amount_of_remaining_drug4_order_id = NULL
WHERE flat_table2.patient_id = #{encounter['patient_id']} and flat_table2.visit_date = DATE('#{encounter['encounter_datetime']}');
EOF
    end #end voided
  end #end unless amount_of_remaining_drug4_order_id

  unless @amount_of_drug5_brought_to_clinic.blank?
    if @amount_voided5 == 0
      Connection.execute <<EOF
UPDATE flat_table2
SET
amount_of_drug5_brought_to_clinic = #{@amount_of_drug5_brought_to_clinic},
amount_of_drug5_remaining_at_home = #{@amount_of_drug5_remaining_at_home},
what_was_the_patient_adherence_for_this_drug5 = #{@what_was_the_patient_adherence_for_this_drug5},
what_was_the_patient_adherence_for_this_drug5_enc_id = #{@what_was_the_patient_adherence_for_this_drug5_enc_id},
missed_hiv_drug_construct5 = #{@missed_hiv_drug_construct5},
amount_of_remaining_drug5_order_id = #{@amount_of_remaining_drug5_order_id}
WHERE flat_table2.patient_id = #{encounter['patient_id']} and flat_table2.visit_date = DATE('#{encounter['encounter_datetime']}');
EOF
    else #else voided
    Connection.execute <<EOF
UPDATE flat_table5
SET
amount_of_drug5_brought_to_clinic = NULL,
amount_of_drug5_remaining_at_home = NULL,
what_was_the_patient_adherence_for_this_drug5 = NULL,
what_was_the_patient_adherence_for_this_drug5_enc_id = NULL,
missed_hiv_drug_construct5 = NULL,
amount_of_remaining_drug5_order_id = NULL
WHERE flat_table2.patient_id = #{encounter['patient_id']} and flat_table2.visit_date = DATE('#{encounter['encounter_datetime']}');
EOF
    end #end voided
  end #end unless amount_of_remaining_drug5_order_id
end

def updating_drug_orders_table(patient_ids, start_date)
  @drug_list = get_drug_list

  # we will exclude the orders having drug_inventory_id null
  (patient_ids || []).each do |patient_id|
    drug_order_rec = Connection.select_all("SELECT o.patient_id, IFNULL(o.order_id, 0) AS order_id, IFNULL(o.encounter_id, 0) AS encounter_id,
                                             o.start_date, o.auto_expire_date, IFNULL(d.quantity, 0) AS quantity,
                                             d.drug_inventory_id, IFNULL(d.dose, 2) As dose, IFNULL(d.frequency, 'Unknown') AS frequency,
                                             o.concept_id, IFNULL(d.equivalent_daily_dose, 2) AS equivalent_daily_dose, o.voided AS voided
                                  FROM  orders o
                                    INNER JOIN drug_order d ON d.order_id = o.order_id
                              WHERE (DATE(o.date_created) = DATE('#{start_date}')
                                    OR DATE(o.date_voided) = DATE('#{start_date}'))
                                  AND o.patient_id = #{patient_id}
                                  AND d.drug_inventory_id IS NOT NULL ")

    patient_orders = {}
    drug_dose_hash = {}; drug_frequency_hash = {}; record_voided = {}
    drug_equivalent_daily_dose_hash = {}; drug_inventory_ids_hash = {}
    patient_orders = {}; drug_order_ids_hash = {}; drug_enc_ids_hash = {}
    drug_start_date_hash = {}; drug_auto_expire_date_hash = {}; drug_quantity_hash = {}

    (drug_order_rec || []).each do |drug_order|
      if drug_order['drug_inventory_id'] == '2833'
        drug_name = @drug_list[:"738"]
      elsif drug_order['drug_inventory_id'] == '1610'
        drug_name = @drug_list[:"731"]
      elsif drug_order['drug_inventory_id'] == '1613'
        drug_name = @drug_list[:"955"]
      elsif drug_order['drug_inventory_id'] == '2985'
        drug_name = @drug_list[:"735"]
      elsif drug_order['drug_inventory_id'] == '7927'
        drug_name = @drug_list[:"969"]
      elsif drug_order['drug_inventory_id'] == '7928'
        drug_name = @drug_list[:"734"]
      elsif drug_order['drug_inventory_id'] == '9175'
        drug_name = @drug_list[:"932"]
      else
        drug_name = @drug_list[:"#{drug_order['drug_inventory_id']}"]
      end

      if patient_orders[drug_name].blank?
        patient_orders[drug_name] = drug_name
        drug_order_ids_hash[drug_name] = drug_order['order_id']
        drug_enc_ids_hash[drug_name] = drug_order['encounter_id']
        drug_start_date_hash[drug_name] = drug_order['start_date']
        drug_auto_expire_date_hash[drug_name] = drug_order['auto_expire_date']
        drug_quantity_hash[drug_name] = drug_order['quantity']
        drug_dose_hash[drug_name] = drug_order['dose']
        drug_frequency_hash[drug_name] = drug_order['frequency']
        drug_equivalent_daily_dose_hash[drug_name] = drug_order['equivalent_daily_dose']
        drug_inventory_ids_hash[drug_name] = drug_order['drug_inventory_id']
        record_voided[drug_name] = drug_order['voided']
      else
        patient_orders[drug_name] = drug_name
        drug_order_ids_hash[drug_name] = drug_order['order_id']
        drug_enc_ids_hash[drug_name] = drug_order['encounter_id']
        drug_start_date_hash[drug_name] = drug_order['start_date']
        drug_auto_expire_date_hash[drug_name] = drug_order['auto_expire_date']
        drug_quantity_hash[drug_name] = drug_order['quantity']
        drug_dose_hash[drug_name] = drug_order['dose']
        drug_frequency_hash[drug_name] = drug_order['frequency']
        drug_equivalent_daily_dose_hash[drug_name] = drug_order['equivalent_daily_dose']
        drug_inventory_ids_hash[drug_name] = drug_order['drug_inventory_id']
        record_voided[drug_name] = drug_order['voided']
      end #end if patient_orders blank
    end #end drug_order_rec

    count = 1
    (patient_orders || []).each do |drug_name, name|
      case count
      when 1
        @drug_name1 = drug_name
        @drug_order_id1 = drug_order_ids_hash[drug_name]
        @drug_start_date1 = drug_start_date_hash[drug_name]
        @drug_auto_expire_date1 = drug_auto_expire_date_hash[drug_name]
        @drug_quantity1 = drug_quantity_hash[drug_name]
        @drug_frequency1 = drug_frequency_hash[drug_name]
        @drug_dose1 = drug_dose_hash[drug_name]
        @drug_equivalent_daily_dose1 = drug_equivalent_daily_dose_hash[drug_name]
        @drug_encounter_id1 = drug_enc_ids_hash[drug_name]
        @drug_inventory_id1 = drug_inventory_ids_hash[drug_name]
        @voided1 = record_voided[drug_name]
        count << 1
      when 2
        @drug_name2 = drug_name
        @drug_order_id2 = drug_order_ids_hash[drug_name]
        @drug_start_date2 = drug_start_date_hash[drug_name]
        @drug_auto_expire_date2 = drug_auto_expire_date_hash[drug_name]
        @drug_quantity2 = drug_quantity_hash[drug_name]
        @drug_frequency2 = drug_frequency_hash[drug_name]
        @drug_dose2 = drug_dose_hash[drug_name]
        @drug_equivalent_daily_dose2 = drug_equivalent_daily_dose_hash[drug_name]
        @drug_encounter_id2 = drug_enc_ids_hash[drug_name]
        @drug_inventory_id2 = drug_inventory_ids_hash[drug_name]
        @voided2 = record_voided[drug_name]
        count << 1
      when 3
        @drug_name3 = drug_name
        @drug_order_id3 = drug_order_ids_hash[drug_name]
        @drug_start_date3 = drug_start_date_hash[drug_name]
        @drug_auto_expire_date3 = drug_auto_expire_date_hash[drug_name]
        @drug_quantity3 = drug_quantity_hash[drug_name]
        @drug_frequency3 = drug_frequency_hash[drug_name]
        @drug_dose3 = drug_dose_hash[drug_name]
        @drug_equivalent_daily_dose3 = drug_equivalent_daily_dose_hash[drug_name]
        @drug_encounter_id3 = drug_enc_ids_hash[drug_name]
        @drug_inventory_id3 = drug_inventory_ids_hash[drug_name]
        @voided3 = record_voided[drug_name]
        count << 1
      when 4
        @drug_name4 = drug_name
        @drug_order_id4 = drug_order_ids_hash[drug_name]
        @drug_start_date4 = drug_start_date_hash[drug_name]
        @drug_auto_expire_date4 = drug_auto_expire_date_hash[drug_name]
        @drug_quantity4 = drug_quantity_hash[drug_name]
        @drug_frequency4 = drug_frequency_hash[drug_name]
        @drug_dose4 = drug_dose_hash[drug_name]
        @drug_equivalent_daily_dose4 = drug_equivalent_daily_dose_hash[drug_name]
        @drug_encounter_id4 = drug_enc_ids_hash[drug_name]
        @drug_inventory_id4 = drug_inventory_ids_hash[drug_name]
        @voided4 = record_voided[drug_name]
        count << 1
      when 5
        @drug_name5 = drug_name
        @drug_order_id5 = drug_order_ids_hash[drug_name]
        @drug_start_date5 = drug_start_date_hash[drug_name]
        @drug_auto_expire_date5 = drug_auto_expire_date_hash[drug_name]
        @drug_quantity5 = drug_quantity_hash[drug_name]
        @drug_frequency5 = drug_frequency_hash[drug_name]
        @drug_dose5 = drug_dose_hash[drug_name]
        @drug_equivalent_daily_dose5 = drug_equivalent_daily_dose_hash[drug_name]
        @drug_encounter_id5 = drug_enc_ids_hash[drug_name]
        @drug_inventory_id5 = drug_inventory_ids_hash[drug_name]
        @voided5 = record_voided[drug_name]
        count << 1
      end #end case statement
    end #end patient_orders

    unless @drug_name1.blank?
      if @voided1 == "0"
        Connection.execute <<EOF
UPDATE flat_table2
SET  drug_name1 = "#{@drug_name1}", drug_order_id1 = "#{@drug_order_id1}",
  drug_start_date1 = "#{@drug_start_date1}", drug_auto_expire_date1 = "#{@drug_auto_expire_date1}",
  drug_quantity1 = "#{@drug_quantity1}", drug_frequency1 =  "#{@drug_frequency1}",
  drug_dose1 = "#{@drug_dose1}", drug_equivalent_daily_dose1 = "#{@drug_equivalent_daily_dose1}",
  drug_encounter_id1 = "#{@drug_encounter_id1}", drug_inventory_id1 = "#{@drug_inventory_id1}"
WHERE flat_table2.patient_id = '#{patient_id}' and flat_table2.visit_date = DATE('#{start_date}');
EOF
      else #else voided
        Connection.execute <<EOF
UPDATE flat_table2
SET  drug_name1 = NULL, drug_order_id1 = NULL,
  drug_start_date1 = NULL, drug_auto_expire_date1 = NULL,
  drug_quantity1 = NULL, drug_frequency1 = NULL,
  drug_dose1 = NULL, drug_equivalent_daily_dose1 = NULL,
  drug_encounter_id1 = NULL, drug_inventory_id1 = NULL
WHERE flat_table2.patient_id = '#{patient_id}' and flat_table2.visit_date = DATE('#{start_date}');
EOF
      end #end voided
    end #end unless drug_name1

    unless @drug_name2.blank?
      if @voided2 == "0"
        Connection.execute <<EOF
UPDATE flat_table2
SET  drug_name2 = "#{@drug_name2}", drug_order_id2 = "#{@drug_order_id2}",
  drug_start_date2 = "#{@drug_start_date2}", drug_auto_expire_date2 = "#{@drug_auto_expire_date2}",
  drug_quantity2 = "#{@drug_quantity2}", drug_frequency2 =  "#{@drug_frequency2}",
  drug_dose2 = "#{@drug_dose2}", drug_equivalent_daily_dose2 = "#{@drug_equivalent_daily_dose2}",
  drug_encounter_id2 = "#{@drug_encounter_id2}", drug_inventory_id2 = "#{@drug_inventory_id2}"
WHERE flat_table2.patient_id = '#{patient_id}' and flat_table2.visit_date = DATE('#{start_date}');
EOF
      else #else voided
        Connection.execute <<EOF
UPDATE flat_table2
SET  drug_name2 = NULL, drug_order_id2 = NULL,
  drug_start_date2 = NULL, drug_auto_expire_date2 = NULL,
  drug_quantity2 = NULL, drug_frequency2 = NULL,
  drug_dose2 = NULL, drug_equivalent_daily_dose2 = NULL,
  drug_encounter_id2 = NULL, drug_inventory_id2 = NULL
WHERE flat_table2.patient_id = '#{patient_id}' and flat_table2.visit_date = DATE('#{start_date}');
EOF
      end #end voided
    end #end unless drug_name2

    unless @drug_name3.blank?
      if @voided3 == "0"
        Connection.execute <<EOF
UPDATE flat_table2
SET  drug_name3 = "#{@drug_name3}", drug_order_id3 = "#{@drug_order_id3}",
  drug_start_date3 = "#{@drug_start_date3}", drug_auto_expire_date3 = "#{@drug_auto_expire_date3}",
  drug_quantity3 = "#{@drug_quantity3}", drug_frequency3 =  "#{@drug_frequency3}",
  drug_dose3 = "#{@drug_dose3}", drug_equivalent_daily_dose3 = "#{@drug_equivalent_daily_dose3}",
  drug_encounter_id3 = "#{@drug_encounter_id3}", drug_inventory_id3 = "#{@drug_inventory_id3}"
WHERE flat_table2.patient_id = '#{patient_id}' and flat_table2.visit_date = DATE('#{start_date}');
EOF
      else #else voided
        Connection.execute <<EOF
UPDATE flat_table2
SET  drug_name3 = NULL, drug_order_id3 = NULL,
  drug_start_date3 = NULL, drug_auto_expire_date3 = NULL,
  drug_quantity3 = NULL, drug_frequency3 = NULL,
  drug_dose3 = NULL, drug_equivalent_daily_dose3 = NULL,
  drug_encounter_id3 = NULL, drug_inventory_id3 = NULL
WHERE flat_table2.patient_id = '#{patient_id}' and flat_table2.visit_date = DATE('#{start_date}');
EOF
      end #end voided
    end #end unless drug_name3

    unless @drug_name4.blank?
      if @voided4 == "0"
        Connection.execute <<EOF
UPDATE flat_table2
SET  drug_name4 = "#{@drug_name4}", drug_order_id4 = "#{@drug_order_id4}",
  drug_start_date4 = "#{@drug_start_date4}", drug_auto_expire_date4 = "#{@drug_auto_expire_date4}",
  drug_quantity4 = "#{@drug_quantity4}", drug_frequency4 =  "#{@drug_frequency4}",
  drug_dose4 = "#{@drug_dose4}", drug_equivalent_daily_dose4 = "#{@drug_equivalent_daily_dose4}",
  drug_encounter_id4 = "#{@drug_encounter_id4}", drug_inventory_id4 = "#{@drug_inventory_id4}"
WHERE flat_table2.patient_id = '#{patient_id}' and flat_table2.visit_date = DATE('#{start_date}');
EOF
      else #else voided
        Connection.execute <<EOF
UPDATE flat_table2
SET  drug_name4 = NULL, drug_order_id4 = NULL,
  drug_start_date4 = NULL, drug_auto_expire_date4 = NULL,
  drug_quantity4 = NULL, drug_frequency4 = NULL,
  drug_dose4 = NULL, drug_equivalent_daily_dose4 = NULL,
  drug_encounter_id4 = NULL, drug_inventory_id4 = NULL
WHERE flat_table2.patient_id = '#{patient_id}' and flat_table2.visit_date = DATE('#{start_date}');
EOF
      end #end voided
    end #end unless drug_name4

    unless @drug_name5.blank?
      if @voided5 == "0"
        Connection.execute <<EOF
UPDATE flat_table2
SET  drug_name5 = "#{@drug_name5}", drug_order_id5 = "#{@drug_order_id5}",
  drug_start_date5 = "#{@drug_start_date5}", drug_auto_expire_date5 = "#{@drug_auto_expire_date5}",
  drug_quantity5 = "#{@drug_quantity5}", drug_frequency5 =  "#{@drug_frequency5}",
  drug_dose5 = "#{@drug_dose5}", drug_equivalent_daily_dose5 = "#{@drug_equivalent_daily_dose5}",
  drug_encounter_id5 = "#{@drug_encounter_id5}", drug_inventory_id5 = "#{@drug_inventory_id5}"
WHERE flat_table2.patient_id = '#{patient_id}' and flat_table2.visit_date = DATE('#{start_date}');
EOF
      else #else voided
        Connection.execute <<EOF
UPDATE flat_table2
SET  drug_name5 = NULL, drug_order_id5 = NULL,
  drug_start_date5 = NULL, drug_auto_expire_date5 = NULL,
  drug_quantity5 = NULL, drug_frequency5 = NULL,
  drug_dose5 = NULL, drug_equivalent_daily_dose5 = NULL,
  drug_encounter_id5 = NULL, drug_inventory_id5 = NULL
WHERE flat_table2.patient_id = '#{patient_id}' and flat_table2.visit_date = DATE('#{start_date}');
EOF
      end #end voided
    end #end unless drug_name5
  end #end patient_ids
end

def get_drug_list
  drug_hash = {}
  drug_list = Drug.find_by_sql("SELECT drug_id, name FROM drug")
  drug_list.each do |drug|
    drug_hash[:"#{drug.drug_id}"] = drug.name
  end
  return drug_hash
end

def upating_relationship_table(patient_ids, start_date)

  (patient_ids || []).each do |person_id|
    relationship_rec = Connection.select_all("
      SELECT * FROM relationship
WHERE  person_a = '#{person_id}' AND
      (DATE(date_created) = DATE('#{start_date}') OR
      DATE(date_voided) = DATE('#{start_date}'))
    ")


    (relationship_rec).each do |relationship|
      #--Get the guardian's person_id
      guardian_id = relationship['person_b']

      #--Check if guardian exist in flat_table1
      flat_table1_record = Connection.select_one("SELECT * FROM flat_table1 WHERE patient_id = #{guardian_id}")

      guardian_id_in_flat_table = flat_table1_record['patient_id']

      #--Get patient_id
      guardian_to_which_patient = relationship['person_a']

      unless guardian_to_which_patient.blank?
        #--check if the giardian_person_id fields have values
        flat_table1_record2 = Connection.select_one("SELECT * FROM flat_table1 WHERE patient_id = #{guardian_to_which_patient}")

        guardian_person_id1 = flat_table1_record2['guardian_person_id1'] rescue nil
        guardian_person_id2 = flat_table1_record2['guardian_person_id2'] rescue nil
        guardian_person_id3 = flat_table1_record2['guardian_person_id3'] rescue nil
        guardian_person_id4 = flat_table1_record2['guardian_person_id4'] rescue nil
        guardian_person_id5 = flat_table1_record2['guardian_person_id5'] rescue nil

        if (guardian_person_id1 == guardian_id)
          guardian_exist = guardian_id

        elsif (guardian_person_id2 == guardian_id)
          guardian_exist = guardian_id

        elsif (guardian_person_id3 == guardian_id)
          guardian_exist = guardian_id

        elsif (guardian_person_id4 == guardian_id)
          guardian_exist = guardian_id

        elsif (guardian_person_id5 == guardian_id)
          guardian_exist = guardian_id
        else
          guardian_exist = 0
        end

      end

      unless guardian_id.blank?
        #--check if the guardian_to_which_patient fields have values
        guardian_to_which_patient1 = flat_table1_record['guardian_to_which_patient1'] rescue nil
        guardian_to_which_patient2 = flat_table1_record['guardian_to_which_patient2'] rescue nil
        guardian_to_which_patient3 = flat_table1_record['guardian_to_which_patient3'] rescue nil
        guardian_to_which_patient4 = flat_table1_record['guardian_to_which_patient4'] rescue nil
        guardian_to_which_patient5 = flat_table1_record['guardian_to_which_patient5'] rescue nil

        if (guardian_to_which_patient1 == guardian_to_which_patient)
          patient_exist = guardian_to_which_patient

        elsif (guardian_to_which_patient2 == guardian_to_which_patient)
          patient_exist = guardian_to_which_patient

        elsif (guardian_to_which_patient3 == guardian_to_which_patient)
          patient_exist = guardian_to_which_patient

        elsif (guardian_to_which_patient4 == guardian_to_which_patient)
          patient_exist = guardian_to_which_patient

        elsif (guardian_to_which_patient5 == guardian_to_which_patient)
          patient_exist = guardian_to_which_patient

        else
          patient_exist = 0
        end

      end

      #--update the guardian_person_id fields

      if guardian_exist.blank?
        if guardian_person_id1.blank?
          Connection.execute <<EOF
UPDATE flat_table1
 SET  guardian_to_which_patient1 = '#{guardian_to_which_patient}'
 WHERE patient_id = #{guardian_id};
EOF
        elsif guardian_person_id2.blank?
          Connection.execute <<EOF
UPDATE flat_table1
 SET  guardian_person_id2 = #{guardian_id}
WHERE patient_id = #{guardian_to_which_patient};
EOF
        elsif guardian_person_id3.blank?
          Connection.execute <<EOF
UPDATE flat_table1
 SET  guardian_person_id3 = #{guardian_id}
 WHERE patient_id = #{guardian_to_which_patient};
EOF
        elsif guardian_person_id4.blank?
          Connection.execute <<EOF
UPDATE flat_table1
 SET  guardian_person_id4 = #{guardian_id}
 WHERE patient_id = #{guardian_to_which_patient};
EOF
        elsif guardian_person_id5.blank?
          Connection.execute <<EOF
UPDATE flat_table1
 SET  guardian_person_id5 = #{guardian_id}
 WHERE patient_id = #{guardian_to_which_patient};
EOF
        else
          guardian_person = guardian_id
        end
      end

      #--update the guardian_to_which_patient fields
      if patient_exist.blank?
        if guardian_to_which_patient1.blank?
          Connection.execute <<EOF
UPDATE flat_table1
 SET  guardian_to_which_patient1 = #{guardian_to_which_patient}
 WHERE patient_id = #{guardian_id};
EOF
        elsif guardian_to_which_patient2.blank?
          Connection.execute <<EOF
UPDATE flat_table1
 SET  guardian_to_which_patient2 = #{guardian_to_which_patient}
 WHERE patient_id = #{guardian_id};
EOF
        elsif guardian_to_which_patient3.blank?
          Connection.execute <<EOF
UPDATE flat_table1
 SET  guardian_to_which_patient3 = #{guardian_to_which_patient}
 WHERE patient_id = #{guardian_id};
EOF
        elsif guardian_to_which_patient4.blank?
          Connection.execute <<EOF
UPDATE flat_table1
 SET  guardian_to_which_patient4 = #{guardian_to_which_patient}
 WHERE patient_id = #{guardian_id};
EOF
        elsif guardian_to_which_patient5.blank?
          Connection.execute <<EOF
UPDATE flat_table1
 SET  guardian_to_which_patient5 = #{guardian_to_which_patient}
 WHERE patient_id = #{guardian_id};
EOF
        else
          guardian_to_which_patient_id = guardian_to_which_patient
        end
      end
  end

  end
end

def updating_patient_program_table(patient_ids, start_date)

  data = get_earliest_start_date_patients_data(patient_ids, start_date)

  (data || []).each do |row|
      #raise row[:earliest_start_date].inspect
      flat_table1_record = Connection.select_one("SELECT * FROM flat_table1 WHERE patient_id = #{row[:patient_id]}")

      earliest_start_date = flat_table1_record['earliest_start_date'].to_date rescue nil
      date_enrolled       = flat_table1_record['date_enrolled'].to_date rescue nil
      age_at_initiation   = flat_table1_record['age_at_initiation'] rescue nil
      age_in_days         = flat_table1_record['age_in_days'] rescue nil

      earliest_start_date_2 = row[:earliest_start_date].to_date rescue nil
      date_enrolled_2       = row[:date_enrolled].to_date rescue nil

      unless earliest_start_date_2.to_date == earliest_start_date
        earliest_start_date = earliest_start_date_2
      end unless earliest_start_date_2.blank? rescue nil

      unless date_enrolled_2 == date_enrolled
        date_enrolled = date_enrolled_2
      end unless date_enrolled_2.blank? rescue nil

      unless row[:age_at_initiation] == age_at_initiation
        age_at_initiation = row[:age_at_initiation]
      end

      unless row[:age_in_days] == age_in_days
        age_in_days = row[:age_in_days]
      end

      if not flat_table1_record.blank?
        Connection.execute <<EOF
UPDATE flat_table1
SET   earliest_start_date = '#{row[:earliest_start_date]}', date_enrolled = '#{row[:date_enrolled]}', age_at_initiation = #{row[:age_at_initiation]}, age_in_days = #{row[:age_in_days]}
WHERE patient_id = #{row[:patient_id]};
EOF

      else
        Connection.execute <<EOF
UPDATE flat_table1
SET   earliest_start_date = '#{row[:earliest_start_date]}', date_enrolled = '#{row[:date_enrolled]}', age_at_initiation = #{row[:age_at_initiation]}, age_in_days = #{row[:age_in_days]}
WHERE patient_id = #{row[:patient_id]};
EOF

      end
  puts "........... Updating record into flat_table1 (Patient_program): #{row[:patient_id]}"

  end
end

def updating_person_attributes_table(patient_ids, start_date)
  occupation_id = PersonAttributeType.find_by_name('Occupation').id
  cell_phone_number_id = PersonAttributeType.find_by_name('Cell Phone Number').id
  home_phone_number_id = PersonAttributeType.find_by_name('Home Phone Number').id
  office_phone_number_id = PersonAttributeType.find_by_name('Office Phone Number').id

  #puts "occupation id: #{occupation_id}"

  (patient_ids || []).each do |person_id|
    person_attributes_records = Connection.select_all("
      SELECT * FROM person_attribute WHERE person_id = #{person_id}
      AND (DATE(date_created) = DATE('#{start_date}')
      OR DATE(date_voided) = DATE('#{start_date}'))")

    flat_table1_record = Connection.select_one("SELECT * FROM flat_table1 WHERE patient_id = #{person_id}")

    occupation = flat_table1_record['occupation']
    cell_phone_number = flat_table1_record['cellphone_number']
    home_phone_number = flat_table1_record['home_phone_number']
    office_phone_number = flat_table1_record['office_phone_number']

    #puts "occupation: #{occupation}"

    #1. updating occupation (New)
    occupation_rec = Connection.select_one("
      SELECT * FROM person_attribute WHERE person_id = #{person_id}
      AND person_attribute_type_id = #{occupation_id}
      AND (DATE(date_created) = DATE('#{start_date}')
      OR DATE(date_voided) = DATE('#{start_date}'))
      ORDER BY date_created DESC LIMIT 1")

    unless occupation_rec.blank? # == occupation
      if occupation_rec['voided'] == '1'
        Connection.execute <<EOF
UPDATE flat_table1
SET  occupation = NULL WHERE patient_id = #{person_id};
EOF
      else
        Connection.execute <<EOF
UPDATE flat_table1
SET  occupation = "#{occupation_rec['value']}" WHERE patient_id = #{person_id};
EOF
      end #end if occupation voided
    end #unless occupation_rec.blank?

   #............................................................................................. occupation end

    #2. Updating cell phone number
     cell_phone_number_rec = Connection.select_one("
      SELECT * FROM person_attribute WHERE person_id = #{person_id}
      AND person_attribute_type_id = #{cell_phone_number_id}
      AND (DATE(date_created) = DATE('#{start_date}')
      OR DATE(date_voided) = DATE('#{start_date}'))
      ORDER BY date_created DESC LIMIT 1")

    unless cell_phone_number_rec.blank? #== cell_phone_number
      #cell_phone_number = cell_phone_number_rec['value']
      if cell_phone_number_rec['voided'] == '1'
        Connection.execute <<EOF
UPDATE flat_table1
SET  cellphone_number = NULL WHERE patient_id = #{person_id};
EOF
      else
        Connection.execute <<EOF
UPDATE flat_table1
SET  cellphone_number = "#{cell_phone_number_rec['value']}" WHERE patient_id = #{person_id};
EOF
      end #end if cell_phone_number voided
    end #unless cell_phone_number_rec.blank?
    #............................................................................ Cell_phone number end

    #3. Updating home phone number
     home_phone_number_rec = Connection.select_one("
      SELECT * FROM person_attribute WHERE person_id = #{person_id}
      AND person_attribute_type_id = #{home_phone_number_id}
      AND (DATE(date_created) = DATE('#{start_date}')
      OR DATE(date_voided) = DATE('#{start_date}'))
      ORDER BY date_created DESC LIMIT 1")

    unless home_phone_number_rec.blank? #== home_phone_number
      #home_phone_number = home_phone_number_rec['value']
      if home_phone_number_rec['voided'] == '1'
        Connection.execute <<EOF
UPDATE flat_table1
SET  home_phone_number = NULL WHERE patient_id = #{person_id};
EOF
      else
        Connection.execute <<EOF
UPDATE flat_table1
SET  home_phone_number = "#{home_phone_number_rec['value']}" WHERE patient_id = #{person_id};
EOF
      end #end cell_phone_number_rec voided
    end #unless home_phone_number_rec.blank?

    #............................................................................. home_phone_number

    #4. Updating office_phone_number
     office_phone_number_rec = Connection.select_one("
      SELECT * FROM person_attribute WHERE person_id = #{person_id}
      AND person_attribute_type_id = #{office_phone_number_id}
      AND (DATE(date_created) = DATE('#{start_date}')
      OR DATE(date_voided) = DATE('#{start_date}'))
      ORDER BY date_created DESC LIMIT 1")

    unless office_phone_number_rec.blank? #== office_phone_number
      #office_phone_number = office_phone_number_rec['value']
      if office_phone_number_rec['voided'] == '1'
        Connection.execute <<EOF
UPDATE flat_table1
SET  office_phone_number = NULL WHERE patient_id = #{person_id};
EOF
      else
      Connection.execute <<EOF
UPDATE flat_table1
SET  office_phone_number = "#{office_phone_number_rec['value']}" WHERE patient_id = #{person_id};
EOF
      end #end office_phone_number_rec voided
    end #unless office_phone_number_rec.blank?

    #............................................................................ office number end

  end

end

def updating_patient_identifier_table(patient_ids, start_date)
  nat_id_type_id = PatientIdentifierType.find_by_name('National id').id
  arv_number_type_id = PatientIdentifierType.find_by_name('ARV number').id
  pre_arv_number_type_id = PatientIdentifierType.find_by_name('Pre-art number').id
  filing_number_id = PatientIdentifierType.find_by_name('Filing number').id
  archived_filing_number_id = PatientIdentifierType.find_by_name('Archived filing number').id

  #puts "archived_filing_number_id: #{archived_filing_number_id}"
  (patient_ids || []).each do |patient_identifier_patient_id|
    patient_identifier_records = Connection.select_all("
      SELECT * FROM patient_identifier WHERE patient_id = #{patient_identifier_patient_id}
      AND (DATE(date_created) = DATE('#{start_date}')
      OR DATE(date_voided) = DATE('#{start_date}'))")

    patient_id = patient_identifier_patient_id.to_i

    flat_table1_record = Connection.select_one("SELECT * FROM flat_table1 WHERE patient_id = #{patient_id}")

    (patient_identifier_records || []).each do |row|
      old_nat_id = flat_table1_record['nat_id'] rescue nil
      arv_number = flat_table1_record['arv_number'] rescue nil
      pre_art_number = flat_table1_record['pre_art_number'] rescue nil
      new_nat_id = flat_table1_record['new_nat_id'] rescue nil
      filing_number = flat_table1_record['filing_number'] rescue nil
      archived_filing_number = flat_table1_record['archived_filing_number'] rescue nil

      # updating filing number -------------------------------------------------

      openmrs_filing_number = Connection.select_one("
        SELECT * FROM patient_identifier WHERE patient_id = #{patient_id}
        AND identifier_type = #{filing_number_id}
        AND (DATE(date_created) = DATE('#{start_date}')
        OR DATE(date_voided) = DATE('#{start_date}'))
        ORDER BY date_created DESC LIMIT 1")

      unless openmrs_filing_number.blank? #== filing_number
        if openmrs_filing_number['voided'] == '1'
          Connection.execute <<EOF
UPDATE flat_table1
SET  filing_number = NULL WHERE patient_id = #{patient_id};
EOF
        else
          #filing_number = openmrs_filing_number['identifier']
          Connection.execute <<EOF
UPDATE flat_table1
SET  filing_number = "#{openmrs_filing_number['identifier']}" WHERE patient_id = #{patient_id};
EOF
        end #close openmrs_filing_number voided
      end #unless openmrs_filing_number.blank?
     #....................................................................................... Filing number end

     # Updating archived_filing_number ............................................................... begin

     openmrs_archived_filing_number = Connection.select_one("
        SELECT * FROM patient_identifier WHERE patient_id = #{patient_id}
        AND identifier_type = #{archived_filing_number_id}
        AND (DATE(date_created) = DATE('#{start_date}')
        OR DATE(date_voided) = DATE('#{start_date}'))
        ORDER BY date_created DESC LIMIT 1")

      unless openmrs_archived_filing_number.blank? #['identifier'] == archived_filing_number
        #archived_filing_number = openmrs_archived_filing_number['identifier']
        if openmrs_archived_filing_number['voided'] == '1'
          Connection.execute <<EOF
UPDATE flat_table1
SET  archived_filing_number = NULL WHERE patient_id = #{patient_id};
EOF
        else
          Connection.execute <<EOF
UPDATE flat_table1
SET  archived_filing_number = "#{openmrs_archived_filing_number['identifier']}" WHERE patient_id = #{patient_id};
EOF
        end #end archived_filing_number voided
      end #unless openmrs_archived_filing_number.blank?

     # archived_filing_number...........................................................................................end

      #1. updating national Id (New: with 6 char)
      openmrs_new_nat_id = Connection.select_one("
        SELECT * FROM patient_identifier WHERE patient_id = #{patient_id}
        AND identifier_type = #{nat_id_type_id} AND LENGTH(identifier) = 6
        AND (DATE(date_created) = DATE('#{start_date}')
        OR DATE(date_voided) = DATE('#{start_date}'))
        ORDER BY date_created DESC LIMIT 1")

      unless openmrs_new_nat_id.blank? #== new_nat_id
        #new_nat_id = openmrs_new_nat_id['identifier']
        if openmrs_new_nat_id['voided'] == '1'
          Connection.execute <<EOF
UPDATE flat_table1
SET  new_nat_id = NULL WHERE patient_id = #{patient_id};
EOF
        else
          Connection.execute <<EOF
UPDATE flat_table1
SET  new_nat_id = "#{openmrs_new_nat_id['identifier']}" WHERE patient_id = #{patient_id};
EOF
        end #end new_nat_id voided
      end #unless openmrs_new_nat_id.blank?

     #............................................................................................. New national ids end

      #2. updating national Id (old: with 13 char)
      openmrs_old_nat_id = Connection.select_one("
        SELECT * FROM patient_identifier WHERE patient_id = #{patient_id}
        AND identifier_type = #{nat_id_type_id} AND LENGTH(identifier) != 6
        AND (DATE(date_created) = DATE('#{start_date}')
        OR DATE(date_voided) = DATE('#{start_date}'))
        ORDER BY date_created DESC LIMIT 1")

      unless openmrs_old_nat_id.blank?
        #old_nat_id = openmrs_old_nat_id['identifier']
        if openmrs_old_nat_id['voided'] == '1'
          Connection.execute <<EOF
UPDATE flat_table1
SET  nat_id = NULL WHERE patient_id = #{patient_id};
EOF
        else
          Connection.execute <<EOF
UPDATE flat_table1
SET  nat_id = "#{openmrs_old_nat_id['identifier']}" WHERE patient_id = #{patient_id};
EOF
        end #end openmrs_old_nat_id voided
      end #unless openmrs_old_nat_id.blank?

     #............................................................................................. Old national ids end

      #3. updating ARV number (adding ARV number)
      openmrs_arv_number = Connection.select_one("
        SELECT * FROM patient_identifier WHERE patient_id = #{patient_id}
        AND identifier_type = #{arv_number_type_id}
        AND (DATE(date_created) = DATE('#{start_date}')
        OR DATE(date_voided) = DATE('#{start_date}'))
        ORDER BY date_created DESC LIMIT 1")

      unless openmrs_arv_number.blank? # == arv_number
        #arv_number = openmrs_arv_number['identifier']
        if openmrs_arv_number['voided'] == '1'
          Connection.execute <<EOF
UPDATE flat_table1
SET  arv_number = NULL WHERE patient_id = #{patient_id};
EOF
        else
          Connection.execute <<EOF
UPDATE flat_table1
SET  arv_number = "#{openmrs_arv_number['identifier']}" WHERE patient_id = #{patient_id};
EOF
        end #end openmrs_arv_number voided
      end #unless openmrs_arv_number.blank?


     #............................................................................................. ARV numbers end

      puts "........... Updating record into flat_table1 (patient_identifier): #{patient_id}"
    end
  end

end

def updating_routine_tb_screening(obs_person_id, obs_encounter_id, routine_screening_id, obs_visit_date, obs_voided)
  #tb screening
  routine_tb_screening_screening_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
    WHERE name = 'Routine Tuberculosis Screening' AND voided = 0 AND retired = 0 LIMIT 1")
  routine_tb_screening_screening = routine_tb_screening_screening_record['concept_id']

  routine_tb_screening_fever_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
    WHERE name = 'Fever' AND voided = 0 AND retired = 0 LIMIT 1")
  routine_tb_screening_fever = routine_tb_screening_fever_record['concept_id'].to_i

  routine_tb_screening_night_sweats_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
    WHERE name = 'Night sweats' AND voided = 0 AND retired = 0 LIMIT 1")
  routine_tb_screening_night_sweats = routine_tb_screening_night_sweats_record['concept_id'].to_i

  routine_tb_screening_cough_of_any_duration_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
    WHERE name = 'Cough any duration' AND voided = 0 AND retired = 0 LIMIT 1")
  routine_tb_screening_cough_of_any_duration = routine_tb_screening_cough_of_any_duration_record['concept_id'].to_i

  routine_tb_screening_weight_loss_failure_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
    LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
    WHERE name = 'Weight loss / Failure to thrive / malnutrition' AND voided = 0 AND retired = 0 LIMIT 1")
  routine_tb_screening_weight_loss_failure = routine_tb_screening_weight_loss_failure_record['concept_id'].to_i

  #get the
  tb_screening_routine_ans = []
  Connection.select_all("
          SELECT o.obs_id, o.person_id, o.encounter_id, o.obs_datetime, c.name, o.voided
          FROM obs o
            INNER JOIN concept_name c on c.concept_id = o.value_coded
          WHERE encounter_id = #{obs_encounter_id} AND o.concept_id = #{routine_screening_id}
          AND obs_datetime = '#{obs_visit_date}' AND person_id = #{obs_person_id} AND concept_name_type = 'FULLY_SPECIFIED'
          AND c.voided  = 0").each do |patient|
            tb_screening_routine_ans << patient
          end

  patient_check = []
  patient_check = Connection.select_one("SELECT ID FROM flat_table2
                        WHERE patient_id = #{obs_person_id}
                        and visit_date = DATE('#{obs_visit_date}')")


  unless tb_screening_routine_ans.blank? #unless tb_screening_routine_ans is blank
    (tb_screening_routine_ans || []).each do |patient_obs|
      case routine_screening_id #routine_screening case
        when routine_tb_screening_fever #routine_screening case
          if patient_check.blank? #check patient_not_in_flat_table2
            #insert
            Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, routine_tb_screening_fever, routine_tb_screening_fever_enc_id)
VALUES('#{obs_person_id}', DATE('#{obs_visit_date}'), '#{patient_obs['name']}', '#{obs_encounter_id}') ;
EOF
          else #check patient_not_in_flat_table2
            if patient_obs['voided'].to_i == 0 #if voided
              Connection.execute <<EOF
UPDATE flat_table2
SET  routine_tb_screening_fever = '#{patient_obs['name']}', routine_tb_screening_fever_enc_id = '#{obs_encounter_id}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
            else #else voided
              Connection.execute <<EOF
UPDATE flat_table2
SET  routine_tb_screening_fever = NULL, routine_tb_screening_fever_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
            end #end voided
          end #check patient_not_in_flat_table2
#------------------------------------------------------------------------------------------------------------end routine_tb_screening_fever
        when routine_tb_screening_night_sweats
          if patient_check.blank? #check patient_not_in_flat_table2
  #insert
  Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, routine_tb_screening_night_sweats, routine_tb_screening_night_sweats_enc_id)
VALUES('#{obs_person_id}', DATE('#{obs_visit_date}'), '#{patient_obs['name']}', '#{obs_encounter_id}') ;
EOF
          else #check patient_not_in_flat_table2
            if patient_obs['voided'].to_i == 0 #if voided
    Connection.execute <<EOF
UPDATE flat_table2
SET  routine_tb_screening_night_sweats = '#{patient_obs['name']}', routine_tb_screening_night_sweats_enc_id = '#{obs_encounter_id}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
            else #else voided
    Connection.execute <<EOF
UPDATE flat_table2
SET  routine_tb_screening_night_sweats = NULL, routine_tb_screening_night_sweats_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
            end #end voided
          end #check patient_not_in_flat_table2
#------------------------------------------------------------------------------------------------------------end routine_tb_screening_night_sweats
        when routine_tb_screening_cough_of_any_duration
          if patient_check.blank? #check patient_not_in_flat_table2
            #insert
            Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, routine_tb_screening_cough_of_any_duration, routine_tb_screening_cough_of_any_duration_enc_id)
VALUES('#{obs_person_id}', DATE('#{obs_visit_date}'), '#{patient_obs['name']}', '#{obs_encounter_id}') ;
EOF
          else #check patient_not_in_flat_table2
            if patient_obs['voided'].to_i == 0 #if voided
              Connection.execute <<EOF
UPDATE flat_table2
SET  routine_tb_screening_cough_of_any_duration = '#{patient_obs['name']}', routine_tb_screening_cough_of_any_duration_enc_id = '#{obs_encounter_id}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
            else #else voided
              Connection.execute <<EOF
UPDATE flat_table2
SET  routine_tb_screening_cough_of_any_duration = NULL, routine_tb_screening_cough_of_any_duration_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
            end #end voided
          end #check patient_not_in_flat_table2
#------------------------------------------------------------------------------------------------------------end routine_tb_screening_cough_of_any_duration
        when routine_tb_screening_weight_loss_failure
          if patient_check.blank? #check patient_not_in_flat_table2
            #insert
            Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, routine_tb_screening_weight_loss_failure, routine_tb_screening_weight_loss_failure_enc_id)
VALUES('#{obs_person_id}', DATE('#{obs_visit_date}'), '#{patient_obs['name']}', '#{obs_encounter_id}') ;
EOF
          else #check patient_not_in_flat_table2
            if patient_obs['voided'].to_i == 0 #if voided
              Connection.execute <<EOF
UPDATE flat_table2
SET  routine_tb_screening_weight_loss_failure = '#{patient_obs['name']}', routine_tb_screening_weight_loss_failure_enc_id = '#{obs_encounter_id}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
            else #else voided
              Connection.execute <<EOF
UPDATE flat_table2
SET  routine_tb_screening_weight_loss_failure = NULL, routine_tb_screening_weight_loss_failure_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
            end #end voided
          end #check patient_not_in_flat_table2
#------------------------------------------------------------------------------------------------------------end routine_tb_screening_weight_loss_failure
      end  #end routine_screening case
    end #end tb_screening_routine_ans
  else #else unless tb_screening_routine_ans is blank
    case routine_screening_id #second routine case
      when routine_tb_screening_fever #when second routine case
        if patient_check.blank? #check patient_not_in_flat_table2
          #insert
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, routine_tb_screening_fever, routine_tb_screening_fever_enc_id)
VALUES('#{obs_person_id}', DATE('#{obs_visit_date}'), 'Yes', '#{obs_encounter_id}') ;
EOF
        else #check patient_not_in_flat_table2
          if obs_voided == 0 #if voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  routine_tb_screening_fever = 'Yes', routine_tb_screening_fever_enc_id = '#{obs_encounter_id}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          else #else voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  routine_tb_screening_fever = NULL, routine_tb_screening_fever_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end voided
        end #check patient_not_in_flat_table2

      when  routine_tb_screening_cough_of_any_duration
        if patient_check.blank? #check patient_not_in_flat_table2
          #insert
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, routine_tb_screening_cough_of_any_duration, routine_tb_screening_cough_of_any_duration_enc_id)
VALUES('#{obs_person_id}', DATE('#{obs_visit_date}'), 'Yes', '#{obs_encounter_id}') ;
EOF
        else #check patient_not_in_flat_table2
          if obs_voided == 0 #if voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  routine_tb_screening_cough_of_any_duration = 'Yes', routine_tb_screening_cough_of_any_duration_enc_id = '#{obs_encounter_id}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          else #else voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  routine_tb_screening_cough_of_any_duration = NULL, routine_tb_screening_cough_of_any_duration_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end voided
        end #check patient_not_in_flat_table2

      when  routine_tb_screening_weight_loss_failure
        if patient_check.blank? #check patient_not_in_flat_table2
          #insert
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, routine_tb_screening_weight_loss_failure, routine_tb_screening_weight_loss_failure_enc_id)
VALUES('#{obs_person_id}', DATE('#{obs_visit_date}'), 'Yes', '#{obs_encounter_id}') ;
EOF
        else #check patient_not_in_flat_table2
          if obs_voided == 0 #if voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  routine_tb_screening_weight_loss_failure = 'Yes', routine_tb_screening_weight_loss_failure_enc_id = '#{obs_encounter_id}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          else #else voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  routine_tb_screening_weight_loss_failure = NULL, routine_tb_screening_weight_loss_failure_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end voided
        end #check patient_not_in_flat_table2

      when  routine_tb_screening_night_sweats
        if patient_check.blank? #check patient_not_in_flat_table2
  #insert
  Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, routine_tb_screening_night_sweats, routine_tb_screening_night_sweats_enc_id)
VALUES('#{obs_person_id}', DATE('#{obs_visit_date}'), 'Yes', '#{obs_encounter_id}') ;
EOF
        else #check patient_not_in_flat_table2
          if obs_voided == 0 #if voided
    Connection.execute <<EOF
UPDATE flat_table2
SET  routine_tb_screening_night_sweats = 'Yes', routine_tb_screening_night_sweats_enc_id = '#{obs_encounter_id}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
        else #else voided
    Connection.execute <<EOF
UPDATE flat_table2
SET  routine_tb_screening_night_sweats = NULL, routine_tb_screening_night_sweats_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
        end #end voided
      end #check patient_not_in_flat_table2
    else #else second routine case
      puts 'No tb routine_screening'
    end #end second routine case
  end #end unless tb_screening_routine_ans is blank
end

def updating_side_effects(obs_person_id, obs_encounter_id, side_effect_id, obs_visit_date)
  abdominal_pain_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
        LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
      WHERE  name = 'Abdominal pain' AND voided = 0 AND retired = 0 LIMIT 1")
  abdominal_pain = abdominal_pain_record['concept_id'].to_i

  anemia_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
        LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
      WHERE  name = 'Anemia' AND voided = 0 AND retired = 0 LIMIT 1")
  anemia = anemia_record['concept_id'].to_i

  anorexia_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
      LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
    WHERE  name = 'Anorexia' AND voided = 0 AND retired = 0 LIMIT 1")
  anorexia = anorexia_record['concept_id'].to_i

  blurry_vision_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
      LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
    WHERE  name = 'Blurry vision' AND voided = 0 AND retired = 0 LIMIT 1")
  blurry_vision = blurry_vision_record['concept_id'].to_i

  cough_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
      LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
    WHERE  name = 'Cough' AND voided = 0 AND retired = 0 LIMIT 1")
  cough = cough_record['concept_id'].to_i

  diarrhea_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
        LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
      WHERE  name = 'Diarrhea' AND voided = 0 AND retired = 0 LIMIT 1")
  diarrhea = diarrhea_record['concept_id'].to_i

  diziness_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
      LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
    WHERE  name = 'Dizziness' AND voided = 0 AND retired = 0 LIMIT 1")
  diziness = diziness_record['concept_id'].to_i

  fever_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
        LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
      WHERE  name = 'fever' AND voided = 0 AND retired = 0 LIMIT 1")
  fever = fever_record['concept_id'].to_i

  gynaecomastia_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
        LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
      WHERE  name = 'Gynaecomastia' AND voided = 0 AND retired = 0 LIMIT 1")
  gynaecomastia = gynaecomastia_record['concept_id'].to_i

  hepatitis_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
      LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
    WHERE  name = 'Hepatitis' AND voided = 0 AND retired = 0 LIMIT 1")
  hepatitis = hepatitis_record['concept_id'].to_i

  jaundice_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
        LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
      WHERE  name = 'Jaundice' AND voided = 0 AND retired = 0 LIMIT 1")
  jaundice = jaundice_record['concept_id'].to_i

  kidney_failure_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
        LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
      WHERE  name = 'Kidney failure' AND voided = 0 AND retired = 0 LIMIT 1")
  kidney_failure = kidney_failure_record['concept_id'].to_i

  lactic_acidosis_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
      LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
    WHERE  name = 'Lactic acidosis' AND voided = 0 AND retired = 0 LIMIT 1")
  lactic_acidosis = lactic_acidosis_record['concept_id'].to_i

  leg_pain_numbness_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
        LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
      WHERE  name = 'Leg pain / numbness' AND voided = 0 AND retired = 0 LIMIT 1")
  leg_pain_numbness = leg_pain_numbness_record['concept_id'].to_i

  lipodystrophy_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
        LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
      WHERE  name = 'Lipodystrophy' AND voided = 0 AND retired = 0 LIMIT 1")
  lipodystrophy = lipodystrophy_record['concept_id'].to_i

  nightmares_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
        LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
       WHERE name = 'Nightmares' AND voided = 0 AND retired = 0 ORDER BY concept_name.concept_id DESC ")
  nightmares = nightmares_record['concept_id'].to_i

  symptom_no_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
      LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
    WHERE  name = 'No' AND voided = 0 AND retired = 0 LIMIT 1")
  symptom_no = symptom_no_record['concept_id'].to_i

  other_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
        LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
      WHERE  name = 'Other' AND voided = 0 AND retired = 0 LIMIT 1")
  other = other_record['concept_id'].to_i

  peripheral_neuropathy_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
        LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
      WHERE  name = 'Peripheral neuropathy' AND voided = 0 AND retired = 0 LIMIT 1")
  peripheral_neuropathy = peripheral_neuropathy_record['concept_id'].to_i

  psychosis_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
      LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
    WHERE  name = 'Psychosis' AND voided = 0 AND retired = 0 LIMIT 1")
  psychosis = psychosis_record['concept_id'].to_i

  renal_failure_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
        LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
      WHERE  name = 'Renal failure' AND voided = 0 AND retired = 0 LIMIT 1")
  renal_failure = renal_failure_record['concept_id'].to_i

  skin_rash_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
      LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
    WHERE  name = 'Skin rash' AND voided = 0 AND retired = 0 LIMIT 1")
  skin_rash = skin_rash_record['concept_id'].to_i

  vomiting_record = Connection.select_one("SELECT concept_name.concept_id FROM concept_name
      LEFT OUTER JOIN concept ON concept.concept_id = concept_name.concept_id
    WHERE  name = 'Vomiting' AND voided = 0 AND retired = 0 LIMIT 1")
  vomiting = vomiting_record['concept_id'].to_i

  #check side_effect_id value
  side_effect_answer =[]
  Connection.select_all("
          SELECT o.obs_id, o.person_id, o.encounter_id, o.obs_datetime, c.name, o.voided
          FROM obs o
          	INNER JOIN concept_name c on c.concept_id = o.value_coded
          WHERE encounter_id = #{obs_encounter_id} AND o.concept_id = #{side_effect_id}
          AND obs_datetime = '#{obs_visit_date}' AND person_id = #{obs_person_id} AND concept_name_type = 'FULLY_SPECIFIED'
          AND c.voided  = 0").each do |patient|
            side_effect_answer << patient
          end
  patient_check = []
  patient_check = Connection.select_one("SELECT ID FROM flat_table2
                        WHERE patient_id = #{obs_person_id}
                        and visit_date = DATE('#{obs_visit_date}')")

  unless side_effect_answer.blank?
    #update the side_effect value
    (side_effect_answer || []).each do |patient_obs|
    case side_effect_id
    when abdominal_pain
      if patient_check.blank? #check patient_not_in_flat_table2
        #insert
        Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, side_effects_abdominal_pain, side_effects_abdominal_pain_enc_id)
VALUES('#{obs_person_id}', DATE('#{obs_visit_date}'), '#{patient_obs['name']}', '#{obs_encounter_id}') ;
EOF
      else #check patient_not_in_flat_table2
        if patient_obs['voided'].to_i == 0 #if voided
          Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_abdominal_pain = '#{patient_obs['name']}', side_effects_abdominal_pain_enc_id = '#{obs_encounter_id}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
        else #else voided
          Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_abdominal_pain = NULL, side_effects_abdominal_pain_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
        end #end voided
      end #check patient_not_in_flat_table2
#---------------------------------------------------------------------------------------------------end abdominal_pain
    when anemia
      if patient_check.blank? #check patient_not_in_flat_table2
        #insert
        Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, side_effects_anemia, side_effects_anemia_enc_id)
VALUES('#{obs_person_id}', DATE('#{obs_visit_date}'), '#{patient_obs['name']}', '#{obs_encounter_id}') ;
EOF
      else #check patient_not_in_flat_table2
        if patient_obs['voided'].to_i == 0 #if voided
          Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_anemia = '#{patient_obs['name']}', side_effects_anemia_enc_id = '#{obs_encounter_id}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
        else #else voided
          Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_anemia = NULL, side_effects_anemia_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
        end #end voided
      end #check patient_not_in_flat_table2
#-------------------------------------------------------------------------------------------------------------end anemia
    when anorexia
      if patient_check.blank? #check patient_not_in_flat_table2
        #insert
        Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, side_effects_anorexia, side_effects_anorexia_enc_id)
VALUES('#{obs_person_id}', DATE('#{obs_visit_date}'), '#{patient_obs['name']}', '#{obs_encounter_id}') ;
EOF
      else #check patient_not_in_flat_table2
        if patient_obs['voided'].to_i == 0 #if voided
          Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_anorexia = '#{patient_obs['name']}', side_effects_anorexia_enc_id = '#{obs_encounter_id}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
        else #else voided
          Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_anorexia = NULL, side_effects_anorexia_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
        end #end voided
      end #check patient_not_in_flat_table2
#------------------------------------------------------------------------------------------------------------------end anorexia
    when blurry_vision
      if patient_check.blank? #check patient_not_in_flat_table2
        #insert
        Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, side_effects_blurry_vision, side_effects_blurry_vision_enc_id)
VALUES('#{obs_person_id}', DATE('#{obs_visit_date}'), '#{patient_obs['name']}', '#{obs_encounter_id}') ;
EOF
      else #check patient_not_in_flat_table2
        if patient_obs['voided'].to_i == 0 #if voided
          Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_blurry_vision = '#{patient_obs['name']}', side_effects_blurry_vision_enc_id = '#{obs_encounter_id}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
        else #else voided
          Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_blurry_vision = NULL, side_effects_blurry_vision_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
        end #end voided
      end #check patient_not_in_flat_table2
#-----------------------------------------------------------------------------------------------------------------end blurry_vision
    when cough
      if patient_check.blank? #check patient_not_in_flat_table2
        #insert
        Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, side_effects_cough, side_effects_cough_enc_id)
VALUES('#{obs_person_id}', DATE('#{obs_visit_date}'), '#{patient_obs['name']}', '#{obs_encounter_id}') ;
EOF
      else #check patient_not_in_flat_table2
        if patient_obs['voided'].to_i == 0 #if voided
          Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_cough = '#{patient_obs['name']}', side_effects_cough_enc_id = '#{obs_encounter_id}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
        else #else voided
          Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_cough = NULL, side_effects_cough_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
        end #end voided
      end #check patient_not_in_flat_table2
#---------------------------------------------------------------------------------------------------------------end cough
    when diarrhea
      if patient_check.blank? #check patient_not_in_flat_table2
        #insert
        Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, side_effects_diarrhea, side_effects_diarrhea_enc_id)
VALUES('#{obs_person_id}', DATE('#{obs_visit_date}'), '#{patient_obs['name']}', '#{obs_encounter_id}') ;
EOF
      else #check patient_not_in_flat_table2
        if patient_obs['voided'].to_i == 0 #if voided
          Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_diarrhea = '#{patient_obs['name']}', side_effects_diarrhea_enc_id = '#{obs_encounter_id}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
        else #else voided
          Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_diarrhea = NULL, side_effects_diarrhea_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
        end #end voided
      end #check patient_not_in_flat_table2
#------------------------------------------------------------------------------------------------------------------end diarrhea
    when diziness
      if patient_check.blank? #check patient_not_in_flat_table2
        #insert
        Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, side_effects_diziness, side_effects_diziness_enc_id)
VALUES('#{obs_person_id}', DATE('#{obs_visit_date}'), '#{patient_obs['name']}', '#{obs_encounter_id}') ;
EOF
      else #check patient_not_in_flat_table2
        if patient_obs['voided'].to_i == 0 #if voided
          Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_diziness = '#{patient_obs['name']}', side_effects_diziness_enc_id = '#{obs_encounter_id}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
        else #else voided
          Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_diziness = NULL, side_effects_diziness_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
        end #end voided
      end #check patient_not_in_flat_table2
#----------------------------------------------------------------------------------------------------------------end diziness
    when fever
      if patient_check.blank? #check patient_not_in_flat_table2
        #insert
        Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, side_effects_fever, side_effects_fever_enc_id)
VALUES('#{obs_person_id}', DATE('#{obs_visit_date}'), '#{patient_obs['name']}', '#{obs_encounter_id}') ;
EOF
      else #check patient_not_in_flat_table2
        if patient_obs['voided'].to_i == 0 #if voided
          Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_fever = '#{patient_obs['name']}', side_effects_fever_enc_id = '#{obs_encounter_id}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
        else #else voided
          Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_fever = NULL, side_effects_fever_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
        end #end voided
      end #check patient_not_in_flat_table2
#-----------------------------------------------------------------------------------------------------------------end fever
    when gynaecomastia
      if patient_check.blank? #check patient_not_in_flat_table2
        #insert
        Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, side_effects_gynaecomastia, side_effects_gynaecomastia_enc_id)
VALUES('#{obs_person_id}', DATE('#{obs_visit_date}'), '#{patient_obs['name']}', '#{obs_encounter_id}') ;
EOF
      else #check patient_not_in_flat_table2
        if patient_obs['voided'].to_i == 0 #if voided
          Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_gynaecomastia = '#{patient_obs['name']}', side_effects_gynaecomastia_enc_id = '#{obs_encounter_id}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
        else #else voided
          Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_gynaecomastia = NULL, side_effects_gynaecomastia_enc_id = NULL WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
        end #end voided
      end #check patient_not_in_flat_table2
#-----------------------------------------------------------------------------------------------------------end gynaecomastia
    when hepatitis
      if patient_check.blank? #check patient_not_in_flat_table2
        #insert
        Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, side_effects_hepatitis, side_effects_hepatitis_enc_id)
VALUES('#{obs_person_id}', DATE('#{obs_visit_date}'), '#{patient_obs['name']}', '#{obs_encounter_id}') ;
EOF
      else #check patient_not_in_flat_table2
        if patient_obs['voided'].to_i == 0 #if voided
          Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_hepatitis = '#{patient_obs['name']}', side_effects_hepatitis_enc_id = '#{obs_encounter_id}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
        else #else voided
          Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_hepatitis = NULL, side_effects_hepatitis_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
        end #end voided
      end #check patient_not_in_flat_table2
#-----------------------------------------------------------------------------------------------------------end jaundice
    when jaundice
      if patient_check.blank? #check patient_not_in_flat_table2
        #insert
        Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, side_effects_jaundice, side_effects_jaundice_enc_id)
VALUES('#{obs_person_id}', DATE('#{obs_visit_date}'), '#{patient_obs['name']}', '#{obs_encounter_id}') ;
EOF
      else #check patient_not_in_flat_table2
        if patient_obs['voided'].to_i == 0 #if voided
          Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_jaundice = '#{patient_obs['name']}', side_effects_jaundice_enc_id = '#{obs_encounter_id}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
        else #else voided
          Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_jaundice = NULL, side_effects_jaundice_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
        end #end voided
      end #check patient_not_in_flat_table2
#-----------------------------------------------------------------------------------------------------------end jaundice
    when kidney_failure
      if patient_check.blank? #check patient_not_in_flat_table2
        #insert
        Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, side_effects_kidney_failure, side_effects_kidney_failure_enc_id)
VALUES('#{obs_person_id}', DATE('#{obs_visit_date}'), '#{patient_obs['name']}', '#{obs_encounter_id}') ;
EOF
      else #check patient_not_in_flat_table2
        if patient_obs['voided'].to_i == 0 #if voided
          Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_kidney_failure = '#{patient_obs['name']}', side_effects_kidney_failure_enc_id = '#{obs_encounter_id}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
        else #else voided
          Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_kidney_failure = NULL, side_effects_kidney_failure_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
        end #end voided
      end #check patient_not_in_flat_table2
#-----------------------------------------------------------------------------------------------------------end kidney_failure
    when lactic_acidosis
      if patient_check.blank? #check patient_not_in_flat_table2
        #insert
        Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, side_effects_lactic_acidosis, side_effects_lactic_acidosis_enc_id)
VALUES('#{obs_person_id}', DATE('#{obs_visit_date}'), '#{patient_obs['name']}', '#{obs_encounter_id}') ;
EOF
      else #check patient_not_in_flat_table2
        if patient_obs['voided'].to_i == 0 #if voided
          Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_lactic_acidosis = '#{patient_obs['name']}', side_effects_lactic_acidosis_enc_id = '#{obs_encounter_id}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
        else #else voided
          Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_lactic_acidosis = NULL, side_effects_lactic_acidosis_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
        end #end voided
      end #check patient_not_in_flat_table2
#-----------------------------------------------------------------------------------------------------------end lactic_acidosis
    when leg_pain_numbness
      if patient_check.blank? #check patient_not_in_flat_table2
        #insert
        Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, side_effects_leg_pain_numbness, side_effects_leg_pain_numbness_enc_id)
VALUES('#{obs_person_id}', DATE('#{obs_visit_date}'), '#{patient_obs['name']}', '#{obs_encounter_id}') ;
EOF
      else #check patient_not_in_flat_table2
        if patient_obs['voided'].to_i == 0 #if voided
          Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_leg_pain_numbness = '#{patient_obs['name']}', side_effects_leg_pain_numbness_enc_id = '#{obs_encounter_id}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
        else #else voided
          Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_leg_pain_numbness = NULL, side_effects_leg_pain_numbness_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
        end #end voided
      end #check patient_not_in_flat_table2
#-----------------------------------------------------------------------------------------------------------end leg_pain_numbness
    when lipodystrophy
      if patient_check.blank? #check patient_not_in_flat_table2
        #insert
        Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, side_effects_lipodystrophy, side_effects_lipodystrophy_enc_id)
VALUES('#{obs_person_id}', DATE('#{obs_visit_date}'), '#{patient_obs['name']}', '#{obs_encounter_id}') ;
EOF
      else #check patient_not_in_flat_table2
        if patient_obs['voided'].to_i == 0 #if voided
          Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_lipodystrophy = '#{patient_obs['name']}', side_effects_lipodystrophy_enc_id = '#{obs_encounter_id}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
        else #else voided
          Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_lipodystrophy = NULL, side_effects_lipodystrophy_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
        end #end voided
      end #check patient_not_in_flat_table2
#-----------------------------------------------------------------------------------------------------------end lipodystrophy
    when nightmares
      if patient_check.blank? #check patient_not_in_flat_table2
        #insert
        Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, side_effects_nightmares, side_effects_nightmares_enc_id)
VALUES('#{obs_person_id}', DATE('#{obs_visit_date}'), '#{patient_obs['name']}', '#{obs_encounter_id}') ;
EOF
      else #check patient_not_in_flat_table2
        if patient_obs['voided'].to_i == 0 #if voided
          Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_nightmares = '#{patient_obs['name']}', side_effects_nightmares_enc_id = '#{obs_encounter_id}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
        else #else voided
          Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_nightmares = NULL, side_effects_nightmares_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
        end #end voided
      end #check patient_not_in_flat_table2
#-----------------------------------------------------------------------------------------------------------end nightmares
    when symptom_no
      if patient_check.blank? #check patient_not_in_flat_table2
        #insert
        Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, side_effects_no, side_effects_no_enc_id)
VALUES('#{obs_person_id}', DATE('#{obs_visit_date}'), '#{patient_obs['name']}', '#{obs_encounter_id}') ;
EOF
      else #check patient_not_in_flat_table2
        if patient_obs['voided'].to_i == 0 #if voided
          Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_no = '#{patient_obs['name']}', side_effects_no_enc_id = '#{obs_encounter_id}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
        else #else voided
          Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_no = NULL, side_effects_no_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
        end #end voided
      end #check patient_not_in_flat_table2
#-----------------------------------------------------------------------------------------------------------end side effects no
    when other
      if patient_check.blank? #check patient_not_in_flat_table2
        #insert
        Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, side_effects_other, side_effects_other_enc_id)
VALUES('#{obs_person_id}', DATE('#{obs_visit_date}'), '#{patient_obs['name']}', '#{obs_encounter_id}') ;
EOF
      else #check patient_not_in_flat_table2
        if patient_obs['voided'].to_i == 0 #if voided
          Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_other = '#{patient_obs['name']}', side_effects_other_enc_id = '#{obs_encounter_id}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
        else #else voided
          Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_other = NULL, side_effects_other_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
        end #end voided
      end #check patient_not_in_flat_table2
#-----------------------------------------------------------------------------------------------------------end other
    when peripheral_neuropathy
      if patient_check.blank? #check patient_not_in_flat_table2
        #insert
        Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, side_effects_peripheral_neuropathy, side_effects_peripheral_neuropathy_enc_id)
VALUES('#{obs_person_id}', DATE('#{obs_visit_date}'), '#{patient_obs['name']}', '#{obs_encounter_id}') ;
EOF
      else #check patient_not_in_flat_table2
        if patient_obs['voided'].to_i == 0 #if voided
          Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_peripheral_neuropathy = '#{patient_obs['name']}', side_effects_peripheral_neuropathy_enc_id = '#{obs_encounter_id}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
        else #else voided
          Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_peripheral_neuropathy = NULL, side_effects_peripheral_neuropathy_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
        end #end voided
      end #check patient_not_in_flat_table2
#----------------------------------------------------------------------------------------------------------end peripheral_neuropathy
    when psychosis
      if patient_check.blank? #check patient_not_in_flat_table2
        #insert
        Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, side_effects_psychosis, side_effects_psychosis_enc_id)
VALUES('#{obs_person_id}', DATE('#{obs_visit_date}'), '#{patient_obs['name']}', '#{obs_encounter_id}') ;
EOF
      else #check patient_not_in_flat_table2
        if patient_obs['voided'].to_i == 0 #if voided
          Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_psychosis = '#{patient_obs['name']}', side_effects_psychosis_enc_id = '#{obs_encounter_id}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
        else #else voided
          Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_psychosis = NULL, side_effects_psychosis_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
        end #end voided
      end #check patient_not_in_flat_table2
#-------------------------------------------------------------------------------------------------------------------------end psychosis
    when renal_failure
      if patient_check.blank? #check patient_not_in_flat_table2
        #insert
        Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, side_effects_renal_failure, side_effects_renal_failure_enc_id)
VALUES('#{obs_person_id}', DATE('#{obs_visit_date}'), '#{patient_obs['name']}', '#{obs_encounter_id}') ;
EOF
      else #check patient_not_in_flat_table2
        if patient_obs['voided'].to_i == 0 #if voided
          Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_renal_failure = '#{patient_obs['name']}', side_effects_renal_failure_enc_id = '#{obs_encounter_id}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
        else #else voided
          Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_renal_failure = NULL, side_effects_renal_failure_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
        end #end voided
      end #check patient_not_in_flat_table2
#-------------------------------------------------------------------------------------------------------------------------end renal_failure
    when skin_rash
      if patient_check.blank? #check patient_not_in_flat_table2
        #insert
        Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, side_effects_skin_rash, side_effects_skin_rash_enc_id)
VALUES('#{obs_person_id}', DATE('#{obs_visit_date}'), '#{patient_obs['name']}', '#{obs_encounter_id}') ;
EOF
      else #check patient_not_in_flat_table2
        if patient_obs['voided'].to_i == 0 #if voided
          Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_skin_rash = '#{patient_obs['name']}', side_effects_skin_rash_enc_id = '#{obs_encounter_id}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
        else #else voided
          Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_skin_rash = NULL, side_effects_skin_rash_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
        end #end voided
      end #check patient_not_in_flat_table2
#-------------------------------------------------------------------------------------------------------------------------end skin_rash
    when vomiting
      if patient_check.blank? #check patient_not_in_flat_table2
        #insert
        Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, side_effects_vomiting, side_effects_vomiting_enc_id)
VALUES('#{obs_person_id}', DATE('#{obs_visit_date}'), '#{patient_obs['name']}', '#{obs_encounter_id}') ;
EOF
      else #check patient_not_in_flat_table2
        if patient_obs['voided'].to_i == 0 #if voided
          Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_vomiting = '#{patient_obs['name']}', side_effects_vomiting_enc_id = '#{obs_encounter_id}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
        else #else voided
          Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_vomiting = NULL, side_effects_vomiting_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
        end #end voided
      end #check patient_not_in_flat_table2
    else #else case
    end #end case
  end #new one
  else #else unless
    #then check save the ordinary way
  end #end unless

end

def updating_person_address_table(person_ids, start_date)
  (person_ids || []).each do |person_address_person_id|
    person_address_records = Connection.select_all("
      SELECT * FROM person_address WHERE person_id = #{person_address_person_id}
      AND (DATE(date_created) = '#{start_date.to_date.strftime('%Y-%m-%d 00:00:00')}'
      OR DATE(date_voided) = '#{start_date.to_date.strftime('%Y-%m-%d 00:00:00')}')")

    #puts "person address records: #{person_address_person_id}"

    (person_address_records || []).each do |row|
      #person_id = row['person_id'].to_i
      flat_table1_record = Connection.select_one("SELECT * FROM flat_table1 WHERE patient_id = #{row['person_id']}")

    if row['voided'] == '1'
      Connection.execute <<EOF
UPDATE flat_table1
SET  current_address = NULL, home_district = NULL, ta = NULL, landmark = NULL WHERE patient_id = #{row['person_id']};
EOF
    else
      Connection.execute <<EOF
UPDATE flat_table1
SET  current_address = "#{row['city_village']}", home_district = "#{row['address2']}", ta = "#{row['county_district']}", landmark = "#{row['address1']}"
WHERE patient_id = #{row['person_id']};
EOF
    end

      puts "........... Updating record into flat_table1 (address): #{row['person_id']}"
    end
  end
end

def updating_person_name_table(person_ids, start_date)
  (person_ids || []).each do |person_name_person_id|
    person_name_records = Connection.select_all("
      SELECT * FROM person_name WHERE person_id = #{person_name_person_id}
      AND (DATE(date_created) = '#{start_date.to_date.strftime('%Y-%m-%d 00:00:00')}'
      OR DATE(date_changed) = '#{start_date.to_date.strftime('%Y-%m-%d 00:00:00')}'
      OR DATE(date_voided) = '#{start_date.to_date.strftime('%Y-%m-%d 00:00:00')}')")

    (person_name_records || []).each do |row|
      #person_id = row['person_id'].to_i
      flat_table1_rocord = Connection.select_one("SELECT * FROM flat_table1 WHERE patient_id = #{row['person_id']}")

      puts "........... Updating record into flat_table1 (names): #{row['person_id']}"
      if row['voided'] == '1'
        Connection.execute <<EOF
UPDATE flat_table1
SET  given_name = NULL, family_name = NULL, middle_name = NULL WHERE patient_id = #{row['person_id']};
EOF
      else
        Connection.execute <<EOF
UPDATE flat_table1
SET  given_name = "#{row['given_name']}", family_name = "#{row['family_name']}", middle_name = "#{row['middle_name']}" WHERE patient_id = #{row['person_id']};
EOF
      end #end person_names voided
     end #
   end #
end

def updating_person_table(person_ids, start_date)
  (person_ids || []).each do |person_id|
    person_records = Connection.select_all("
      SELECT * FROM person WHERE person_id = #{person_id}
      AND (DATE(date_created) = '#{start_date.to_date.strftime('%Y-%m-%d 00:00:00')}'
      OR DATE(date_changed) = '#{start_date.to_date.strftime('%Y-%m-%d 00:00:00')}'
      OR DATE(date_voided) = '#{start_date.to_date.strftime('%Y-%m-%d 00:00:00')}')
      AND '#{start_date.to_date.strftime('%Y-%m-%d 23:59:59')}'
    ")

    unless person_records.blank?
      (person_records || []).each do |row|
        flat_table1_rocord = Connection.select_one("SELECT * FROM flat_table1 WHERE patient_id = #{person_id}")
        if flat_table1_rocord.blank?
          puts "........... Inserting new record into flat_table1: #{person_id}"
          Connection.execute <<EOF
INSERT INTO flat_table1
(patient_id, gender, dob, dob_estimated)
VALUES(#{person_id}, '#{row['gender']}', '#{row['birthdate']}', #{row['birthdate_estimated']})
EOF

          puts "........... Inserting new record into flat_table2: #{person_id}"
          Connection.execute <<EOF
INSERT INTO flat_table2
(patient_id, visit_date)
VALUES(#{person_id}, DATE('#{start_date}'))
EOF

        else
          if row['voided'] == 1
            puts "........... Deleting record into flat_table1: #{person_id}"
            Connection.execute <<EOF
DELETE flat_table1 WHERE patient_id = #{person_id}
EOF

         else
           puts "........... Updating record into flat_table1: #{person_id}"
           Connection.execute <<EOF
UPDATE flat_table1
SET  dob = '#{row['birthdate'].to_date}', dob_estimated = #{row['birthdate_estimated'].to_i}, gender = '#{row['gender']}'
WHERE patient_id = #{person_id};
EOF

           unless row['death_date'].blank?
             Connection.execute <<EOF
UPDATE flat_table1
SET  death_date = '#{row['death_date'].to_date}' WHERE patient_id = #{person_id};
EOF

           end
         end

        end
      end
    end

  end
end

def updating_encounter_table(patient_ids)
  art_encounters =  [
    'SOURCE OF REFERRAL','UPDATE HIV STATUS',
    'HIV CLINIC REGISTRATION','VITALS','HIV STAGING',
    'HIV CLINIC CONSULTATION','ART ADHERENCE','TREATMENT','DISPENSING'
  ]
  art_encounters_ids = EncounterType.find(:all, :conditions =>["name IN(?)",art_encounters]).map(&:id)

  (patient_ids || []).each do |patient_id|
    puts "encounter table: patient_id: #{patient_id}"
    encounters = Connection.select_all("
      SELECT * FROM encounter WHERE patient_id = #{patient_id}
      AND encounter_datetime BETWEEN '#{Current_date.to_date.strftime('%Y-%m-%d 00:00:00')}'
      AND '#{Current_date.to_date.strftime('%Y-%m-%d 23:59:59')}'
      AND encounter_type IN(#{art_encounters_ids.join(',')})
    ")

    if encounters.length > 0
      (encounters || []).each do |e|
      end
    end
  end
end

def get_earliest_start_date_patients(start_date)
  art_patient_ids = Connection.select_all("
  SELECT
    `p`.`patient_id` AS `patient_id`, `pe`.`gender` AS `gender`, `pe`.`birthdate`,
    date_antiretrovirals_started(`p`.`patient_id`, min(`s`.`start_date`)) AS `earliest_start_date`,
    cast(patient_date_enrolled(`p`.`patient_id`) as date) AS `date_enrolled`,
    `pe`.`death_date` AS `death_date`, DATE(`encounter`.`encounter_datetime`) AS visit_date,
    (select timestampdiff(year, `pe`.`birthdate`, min(`s`.`start_date`))) AS `age_at_initiation`,
    (select timestampdiff(day, `pe`.`birthdate`, min(`s`.`start_date`))) AS `age_in_days`
  FROM
    ((`patient_program` `p`
    left join `person` `pe` ON ((`pe`.`person_id` = `p`.`patient_id`))
    left join `patient_state` `s` ON ((`p`.`patient_program_id` = `s`.`patient_program_id`)))
    left join `encounter` ON ((`encounter`.`patient_id` = `p`.`patient_id`)))
  WHERE
      ((`p`.`voided` = 0) AND (`s`.`voided` = 0) AND (`p`.`program_id` = 1) AND (`s`.`state` = 7)
        AND (DATE(`p`.`date_created`) >= DATE('#{start_date}') OR DATE(`p`.`date_changed`) >= DATE('#{start_date}'))
        OR ( DATE(`encounter`.`date_created`) >= DATE('#{start_date}') OR DATE(`encounter`.`date_changed`) >= DATE('#{start_date}') OR DATE(`encounter`.`date_voided`) >= DATE('#{start_date}')))
  GROUP BY `p`.`patient_id`
  ").collect{|p|p["patient_id"].to_i}

  return art_patient_ids
end

def get_earliest_start_date_patients_data(patient_ids, start_date)
  patient_ids = [0] if patient_ids.blank?
  records = Connection.select_all("
    SELECT
      `p`.`patient_id` AS `patient_id`,
      `pe`.`gender` AS `gender`,
      `pe`.`birthdate`,
      date_antiretrovirals_started(`p`.`patient_id`, min(`s`.`start_date`)) AS `earliest_start_date`,
      cast(patient_date_enrolled(`p`.`patient_id`) as date) AS `date_enrolled`,
      `pe`.`death_date` AS `death_date`, DATE(`encounter`.`encounter_datetime`) AS visit_date,
      (select timestampdiff(year,`pe`.`birthdate`, min(`s`.`start_date`))) AS `age_at_initiation`,
      (select timestampdiff(day, `pe`.`birthdate`, min(`s`.`start_date`))) AS `age_in_days`
    FROM
      ((`patient_program` `p`
      LEFT JOIN `person` `pe` ON ((`pe`.`person_id` = `p`.`patient_id`))
      LEFT JOIN `patient_state` `s` ON ((`p`.`patient_program_id` = `s`.`patient_program_id`)))
      LEFT JOIN `encounter` ON ((`encounter`.`patient_id` = `p`.`patient_id`)))
    WHERE ((`p`.`voided` = 0) AND (`s`.`voided` = 0) AND (`p`.`program_id` = 1) AND (`s`.`state` = 7)
    AND (DATE(`p`.`date_created`) >= DATE('#{start_date}') OR DATE(`p`.`date_changed`) >= DATE('#{start_date}'))
          OR (DATE(`encounter`.`date_created`) >= DATE('#{start_date}') OR DATE(`encounter`.`date_changed`) >= DATE('#{start_date}')
          OR DATE(`encounter`.`date_voided`) >= DATE('#{start_date}'))
    AND `p`.`patient_id` IN (#{patient_ids.join(',')}))
    GROUP BY  `p`.`patient_id`
  ").collect do |p|
    {
      :patient_id => p["patient_id"].to_i, :date_enrolled => p['date_enrolled'],
      :earliest_start_date => p['earliest_start_date'], :death_date => (p['death_date'].to_date rescue nil), :age_at_initiation => p['age_at_initiation'], :age_in_days => p['age_in_days']
    }
  end
  return records
end

start
