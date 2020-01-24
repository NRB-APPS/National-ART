require 'rubygems'
require 'fastercsv'
require 'mysql2'

FlattablesdDataAnalysis = 1

def dbconnect
  config = YAML::load_file("config/database.yml")["development"]
  config["host"] = config["hostname"]
  @cnn = Mysql2::Client.new(config)
end

def querydb(sql)
  @rs = @cnn.query("#{sql}")
end

def writetolog(log_str)
  log = File.open("log/flat_tables_analysis.log", "a")
  log.syswrite(Time.now.to_s + " " + log_str + "\n")
end

def start
  #get patients from temp_earliest_start_date
  eligible_patients = ActiveRecord::Base.connection.select_all <<EOF
    SELECT * FROM temp_earliest_start_date;
EOF

  patient_ids = []
  (eligible_patients || []).each do |person|
    patient_ids << person['patient_id'].to_i
  end

  #patient Demographics
  flat_table1_record_count_ids, flat_cohort_table_count_ids, earliest_start_date_record_count_ids, ids_not_in_source_ids, ids_not_in_flat1_ids, ids_not_in_flat_table_cohort_ids = compare_record_count(patient_ids)
  patient_ids_with_missing_mandetory_demo_fields = check_demographic_mandatory_fields(patient_ids)
  rs_demo_not_accurate_ids = check_demographics_accuracy(patient_ids)
  nonUniqueARV_Numbers_ids, nonUniquePatientRecords_ids, nonUniqueNational_records_ids = check_demographic_uniqueness(patient_ids)

  #patient HIV reception completeness
  visits_in_source_records, visits_in_flats_records, visits_not_in_flats_records, visits_not_in_source_records, incomplete_hiv_reception_visit_records = check_hiv_reception_completeness(patient_ids)
  guardian_present_not_accurate, patient_present_not_accurate = check_hiv_reception_data_accuracy(patient_ids)

  #patients Vitals records
  vitals_visits_in_source, vitals_visits_in_flats, vitals_visits_not_in_flats, vitals_visits_not_in_source, vitals_incomplete_vitals_visit = check_for_visits_with_missing_vitals_encounter(patient_ids)
  patients_without_vitals_obs, patients_without_mandatory_fields_1st_visit, patients_without_mandatory_fields_1st_visit, vitals_visits_without_a_match_in_flats = check_vitals_accuracy(patient_ids)

  #hiv consultation
  currently_using_family_planning_method_records, family_planning_method_oral_contraceptive_pills_records , family_planning_method_depo_provera_records, family_planning_method_tubal_ligation_records, family_planning_method_abstinence_records, family_planning_method_vasectomy_records, family_planning_method_intrauterine_contraception_records, family_planning_method_contraceptive_implant_records, family_planning_method_male_condoms_records, family_planning_method_female_condoms_records, family_planning_method_rythm_method_records, family_planning_method_withdrawal_records, family_planning_method_emergency_contraception_records, routine_tb_screening_fever_records, routine_tb_screening_night_sweats_records, routine_tb_screening_cough_of_any_duration_records, routine_tb_screening_weight_loss_failure_records, tb_status_tb_not_suspected_records, tb_status_tb_suspected_records, tb_status_unknown_records, tb_status_confirmed_tb_not_on_treatment_records, tb_status_confirmed_tb_on_treatment_records, drug_induced_abdominal_pain_records, drug_induced_anemia_records, drug_induced_anorexia_records, drug_induced_blurry_vision_records, drug_induced_cough_records, drug_induced_diarrhea_records, drug_induced_diziness_records, drug_induced_fever_records, drug_induced_gynaecomastia_records, drug_induced_hepatitis_records, drug_induced_jaundice_records, drug_induced_kidney_failure_records, drug_induced_lactic_acidosis_records, drug_induced_leg_pain_numbness_records, drug_induced_lipodystrophy_records, drug_induced_no_records, drug_induced_other_records, drug_induced_peripheral_neuropathy_records, drug_induced_psychosis_records, drug_induced_renal_failure_records, drug_induced_skin_rash_records, drug_induced_vomiting_records, drug_induced_nightmares_records, symptom_present_lipodystrophy_records, symptom_present_anemia_records, symptom_present_jaundice_records, symptom_present_lactic_acidosis_records, symptom_present_fever_records, symptom_present_skin_rash_records, symptom_present_abdominal_pain_records, symptom_present_anorexia_records, symptom_present_cough_records, symptom_present_diarrhea_records, symptom_present_hepatitis_records, symptom_present_leg_pain_numbness_records, symptom_present_peripheral_neuropathy_records, symptom_present_vomiting_records, symptom_present_other_symptom_records, symptom_present_kidney_failure_records, symptom_present_nightmares_records, symptom_present_diziness_records, symptom_present_psychosis_records, symptom_present_blurry_vision_records, symptom_present_gynaecomastia_records, symptom_present_no_records, sysmptom_present_renal_failure_records = check_hiv_clinic_consultation_accuracy(patient_ids)

  #patient orders completeness
  patient_orders_records_from_source_records, patient_orders_flat_tables_records, patient_orders_visits_not_in_records, patient_orders_visits_not_in_source_records =  patient_orders_records_completeness(patient_ids)
  #patient orders consistency and accuracy
  drug_order_ids, drug_encounter_ids, drug_start_date_ids, drug_auto_expire_date_ids, drug_inventory_ids, drug_name_ids, drug_equivalent_daily_dose_ids, drug_dose_ids, drug_frequency_ids, drug_quantity_ids = patient_orders_consistency_and_accuracy_check(patient_orders_records_from_source_records)

  #patient_outcomes completeness
  patient_outcome_records_from_source, patient_outcome_flat_tables_visits, patient_outcome_visits_not_in_flats, patient_outcome_visits_not_in_source = patient_outcome_records_completeness(patient_ids)
  #patient_outcomes consistency and accuracy
  current_hiv_program_state_ids, current_hiv_program_start_date_ids = patient_outcome_consistency_and_accuracy_check(patient_outcome_records_from_source)

  #treatment completeness
  treatment_records_from_source, treatment_flat_tables_visits, treatment_visits_not_in_flats, treatment_visits_not_in_source = treatment_records_completeness(patient_ids)
  #treatment consistency and accuracy
  ipt_given_ids, cpt_given_ids, condoms_given_ids, regimen_category_treatment_ids, type_of_ARV_regimen_given_ids, treatment_obs_not_in_any_category_details = treatment_consistency_and_accuracy_check(treatment_records_from_source)

  #dispensing completeness
  dispensing_records_from_source, dispensing_flat_tables_visits, dispensing_visits_not_in_flats, dispensing_visits_not_in_source = dispensing_records_completeness(patient_ids)
  #dispensing consistency and accuracy
  arv_regimens_received_construct_ids, regimen_category_dispensed_ids, dispensing_obs_not_in_any_category_ids = dispensing_consistency_and_accuracy_check(dispensing_records_from_source)

  #hiv_clinic_registration_completeness
  hiv_registration_records, transfer_ins, transfer_ins_with_all_fields, transfer_ins_without_all_fields, first_timers, unknown_ever_reg = hiv_registration_records_completeness(patient_ids)
  patients_not_in_flat_tables = patient_ids - hiv_registration_records

  #hiv_clinic_registration_consistency
  ever_received_art_ids, agrees_to_followup_ids, send_sms_ids, type_of_confirmatory_hiv_test_ids, confirmatory_hiv_test_location_ids, confirmatory_hiv_test_date_ids, date_started_art_ids, has_transfer_letter_ids, taken_art_in_last_two_weeks_ids, location_of_art_initialization_ids, date_art_last_taken_ids, taken_art_in_last_two_months_ids, last_art_drugs_taken_ids, ever_registered_at_art_clinic_ids, patients_without_hiv_clinic_reg_obs = hiv_registration_records_consistency(patient_ids)
  puts "\n\n"
  print "Category".ljust(50)
  print "Source DB".ljust(30)
  print "Flat_tables".ljust(30)
  print "Not in Source DB".ljust(30)
  print "Not in Flat_tables"
  puts ""
  print "Total Patients with Demographics".ljust(50)
  print earliest_start_date_record_count_ids.count.to_s.ljust(30)
  print flat_table1_record_count_ids.count.to_s.ljust(30)
  print ids_not_in_source_ids.count.to_s.ljust(30)
  print ids_not_in_flat1_ids.count.to_s
  puts ""
  print "Total Patients with HIV Reception".ljust(50)
  print visits_in_source_records.count.to_s.ljust(30)
  print visits_in_flats_records.count.to_s.ljust(30)
  print visits_not_in_source_records.count.to_s.ljust(30)
  print visits_not_in_flats_records.count.to_s
  puts ""
  print "Total Patients with Vitals".ljust(50)
  print vitals_visits_in_source.count.to_s.ljust(30)
  print vitals_visits_in_flats.count.to_s.ljust(30)
  print vitals_visits_not_in_source.count.to_s.ljust(30)
  print vitals_visits_not_in_flats.count.to_s
  puts ""
  print "Total Patients with HIV Clinic Registration".ljust(50)
  print patient_ids.count.to_s.ljust(30)
  print hiv_registration_records.count.to_s.ljust(30)
  print patients_not_in_flat_tables.count.to_s.ljust(30)
  print ""
  puts ""
  print "Total Patients with Treatment".ljust(50)
  print treatment_records_from_source.count.to_s.ljust(30)
  print treatment_flat_tables_visits.count.to_s.ljust(30)
  print treatment_visits_not_in_source.count.to_s.ljust(30)
  print treatment_visits_not_in_flats.count.to_s
  puts ""
  print "Total Patients with Dispensing".ljust(50)
  print dispensing_records_from_source.count.to_s.ljust(30)
  print dispensing_flat_tables_visits.count.to_s.ljust(30)
  print dispensing_visits_not_in_flats.count.to_s.ljust(30)
  print dispensing_visits_not_in_source.count.to_s
  puts ""
  print "Total Patients with outcomes".ljust(50)
  print patient_outcome_records_from_source.count.to_s.ljust(30)
  print patient_outcome_flat_tables_visits.count.to_s.ljust(30)
  print patient_outcome_visits_not_in_flats.count.to_s.ljust(30)
  print patient_outcome_visits_not_in_source.count.to_s
  puts ""
  print "Total Patients with drug orders".ljust(50)
  print patient_orders_records_from_source_records.count.to_s.ljust(30)
  print patient_orders_flat_tables_records.count.to_s.ljust(30)
  print patient_orders_visits_not_in_records.count.to_s.ljust(30)
  print patient_orders_visits_not_in_source_records.count.to_s
  puts ""
  puts "\nPatient Demographics summary\n"
  print "Category".ljust(50)
  print "Total Number of fields".ljust(30)
  puts ""
  print "Patients without all mandatory fields".ljust(50)
  print patient_ids_with_missing_mandetory_demo_fields.count.to_s.ljust(30)
  puts ""
  print "Patients with inaccurate fields".ljust(50)
  print rs_demo_not_accurate_ids.count.to_s.ljust(30)
  puts ""
  print "ARV Numbers assigned to more patients".ljust(50)
  print nonUniqueARV_Numbers_ids.count.to_s.ljust(30)
  puts ""
  print "Patients IDs assigned to more patients ".ljust(50)
  print nonUniquePatientRecords_ids.count.to_s.ljust(30)
  puts ""
  print "National IDs assigned to more patients".ljust(50)
  print nonUniqueNational_records_ids.count.to_s.ljust(30)
  puts ""
  puts "\nHIV Reception Encounters summary\n"
  print "Category".ljust(50)
  print "Total Number of fields".ljust(30)
  puts ""
  print "Incomplete HIV reception visits".ljust(50)
  print incomplete_hiv_reception_visit_records.count.to_s.ljust(30)
  puts ""
  print "Inaccurate Guardian present visits".ljust(50)
  print guardian_present_not_accurate.count.to_s.ljust(30)
  puts ""
  print "Inaccurate Patient present visits".ljust(50)
  print patient_present_not_accurate.count.to_s.ljust(30)
  puts ""
  puts "\nVitals Encounters summary\n"
  print "Category".ljust(50)
  print "Total Number of fields".ljust(30)
  puts ""
  print "Patients without Vitals".ljust(50)
  print patients_without_vitals_obs.count.to_s.ljust(30)
  puts ""
  print "Patients without mandatory fields during 1st visit".ljust(50)
  print patients_without_mandatory_fields_1st_visit.count.to_s.ljust(30)
  puts ""
  print "Vitals visit that did not match in flat_tables".ljust(50)
  print vitals_visits_without_a_match_in_flats.count.to_s.ljust(30)
  puts ""
  puts "\nHIV Clinic Registration Encounters summary\n"
  print "Category".ljust(50)
  print "Total Number of fields".ljust(30)
  puts ""
  print "Tranfer Ins".ljust(50)
  print transfer_ins.count.to_s.ljust(30)
  puts ""
  print "Transfer Ins with all fields".ljust(50)
  print transfer_ins_with_all_fields.count.to_s.ljust(30)
  puts ""
  print "Transfer Ins without all fields".ljust(50)
  print transfer_ins_without_all_fields.count.to_s.ljust(30)
  puts ""
  print "First time patients".ljust(50)
  print first_timers.count.to_s.ljust(30)
  puts ""
  print "Patients without HIV clinic registration encounter".ljust(50)
  print unknown_ever_reg.count.to_s.ljust(30)
  puts ""
  print "Ever received ART records not matching the source".ljust(50)
  print ever_received_art_ids.count.to_s.ljust(30)
  puts ""
  print "agrees_to_followup".ljust(50)
  print agrees_to_followup_ids.count.to_s.ljust(30)
  puts ""
  print "send_sms".ljust(50)
  print send_sms_ids.count.to_s.ljust(30)
  puts ""
  print "type_of_confirmatory_hiv_test".ljust(50)
  print type_of_confirmatory_hiv_test_ids.count.to_s.ljust(30)
  puts ""
  print "confirmatory_hiv_test_location".ljust(50)
  print confirmatory_hiv_test_location_ids.count.to_s.ljust(30)
  puts ""
  print "confirmatory_hiv_test_date".ljust(50)
  print confirmatory_hiv_test_date_ids.count.to_s.ljust(30)
  puts ""
  print "date_started_art".ljust(50)
  print date_started_art_ids.count.to_s.ljust(30)
  puts ""
  print "has_transfer_letter".ljust(50)
  print has_transfer_letter_ids.count.to_s.ljust(30)
  puts ""
  print "taken_art_in_last_two_weeks".ljust(50)
  print taken_art_in_last_two_weeks_ids.count.to_s.ljust(30)
  puts ""
  print "location_of_art_initialization".ljust(50)
  print location_of_art_initialization_ids.count.to_s.ljust(30)
  puts ""
  print "date_art_last_taken".ljust(50)
  print date_art_last_taken_ids.count.to_s.ljust(30)
  puts ""
  print "taken_art_in_last_two_months".ljust(50)
  print taken_art_in_last_two_months_ids.count.to_s.ljust(30)
  puts ""
  print "last_art_drugs_taken".ljust(50)
  print last_art_drugs_taken_ids.count.to_s.ljust(30)
  puts ""
  print "ever_registered_at_art_clinic".ljust(50)
  print ever_registered_at_art_clinic_ids.count.to_s.ljust(30)
  puts ""
  print "patients_without_hiv_clinic_reg".ljust(50)
  print patients_without_hiv_clinic_reg_obs.count.to_s.ljust(30)
  puts ""
  puts "\nHIV Clinic Consultation Encounters summary\n"
  print "Category".ljust(50)
  print "Total Number of fields".ljust(30)
  puts ""
  puts "TB status"
  print "TB suspected mismatched".ljust(50)
  print tb_status_tb_suspected_records.count.to_s.ljust(30)
  puts ""
  print "TB NOT suspected mismatched".ljust(50)
  print tb_status_tb_not_suspected_records.count.to_s.ljust(30)
  puts ""
  print "TB Confirmed and on treatment mismatched".ljust(50)
  print tb_status_confirmed_tb_on_treatment_records.count.to_s.ljust(30)
  puts ""
  print "TB Confirmed and not on treatment mismatched".ljust(50)
  print tb_status_confirmed_tb_not_on_treatment_records.count.to_s.ljust(30)
  puts ""
  print "Unknown TB status".ljust(50)
  print tb_status_unknown_records.count.to_s.ljust(30)
  puts ""
  puts "Routine TB screening"
  print "Fever mismatched".ljust(50)
  print routine_tb_screening_fever_records.count.to_s.ljust(30)
  puts ""
  print "Night sweats mismatched".ljust(50)
  print routine_tb_screening_night_sweats_records.count.to_s.ljust(30)
  puts ""
  print "Cough mismatched".ljust(50)
  print routine_tb_screening_cough_of_any_duration_records.count.to_s.ljust(30)
  puts ""
  print "Weigh loss mismatched".ljust(50)
  print routine_tb_screening_weight_loss_failure_records.count.to_s.ljust(30)
  puts ""
  puts "Family Planning"
  print "Currently using family planning mismatched".ljust(50)
  print currently_using_family_planning_method_records.count.to_s.ljust(30)
  puts ""
  print "Oral Contraceptive pills mismatched".ljust(50)
  print family_planning_method_oral_contraceptive_pills_records.count.to_s.ljust(30)
  puts ""
  print "Depo-provera mismatched".ljust(50)
  print family_planning_method_depo_provera_records.count.to_s.ljust(30)
  puts ""
  print "Tubal ligation mismatched".ljust(50)
  print family_planning_method_tubal_ligation_records.count.to_s.ljust(30)
  puts ""
  print "Abstinence mismatched".ljust(50)
  print family_planning_method_abstinence_records.count.to_s.ljust(30)
  puts ""
  print "Vasectomy mismatched".ljust(50)
  print family_planning_method_vasectomy_records.count.to_s.ljust(30)
  puts ""
  print "Intrauterine mismatched".ljust(50)
  print family_planning_method_intrauterine_contraception_records.count.to_s.ljust(30)
  puts ""
  print "Implant mismatched".ljust(50)
  print family_planning_method_contraceptive_implant_records.count.to_s.ljust(30)
  puts ""
  print "Male condoms mismatched".ljust(50)
  print family_planning_method_male_condoms_records.count.to_s.ljust(30)
  puts ""
  print "Female Condoms mismatched".ljust(50)
  print family_planning_method_female_condoms_records.count.to_s.ljust(30)
  puts ""
  print "Rythm mismatched".ljust(50)
  print family_planning_method_rythm_method_records.count.to_s.ljust(30)
  puts ""
  print "Withdrawal mismatched".ljust(50)
  print family_planning_method_withdrawal_records.count.to_s.ljust(30)
  puts ""
  print "Emergency Contraceptive pills mismatched".ljust(50)
  print family_planning_method_emergency_contraception_records.count.to_s.ljust(30)
  puts ""
  puts "Drug Induced Effects"
  print "Abdominal_pain mismatched".ljust(50)
  print drug_induced_abdominal_pain_records.count.to_s.ljust(30)
  puts ""
  print "Anemia mismatched".ljust(50)
  print drug_induced_anemia_records.count.to_s.ljust(30)
  puts ""
  print "Anorexia mismatched".ljust(50)
  print drug_induced_anorexia_records.count.to_s.ljust(30)
  puts ""
  print "Blurry_vision mismatched".ljust(50)
  print drug_induced_blurry_vision_records.count.to_s.ljust(30)
  puts ""
  print "Cough mismatched".ljust(50)
  print drug_induced_cough_records.count.to_s.ljust(30)
  puts ""
  print "Diarrhea mismatched".ljust(50)
  print drug_induced_diarrhea_records.count.to_s.ljust(30)
  puts ""
  print "Diziness mismatched".ljust(50)
  print drug_induced_diziness_records.count.to_s.ljust(30)
  puts ""
  print "Fever mismatched".ljust(50)
  print drug_induced_fever_records.count.to_s.ljust(30)
  puts ""
  print "Gynaecomastia mismatched".ljust(50)
  print drug_induced_gynaecomastia_records.count.to_s.ljust(30)
  puts ""
  print "Hepatitis mismatched".ljust(50)
  print drug_induced_hepatitis_records.count.to_s.ljust(30)
  puts ""
  print "Jaundice mismatched".ljust(50)
  print drug_induced_jaundice_records.count.to_s.ljust(30)
  puts ""
  print "Kidney_failure mismatched".ljust(50)
  print drug_induced_kidney_failure_records.count.to_s.ljust(30)
  puts ""
  print "Lactic_acidosis mismatched".ljust(50)
  print drug_induced_lactic_acidosis_records.count.to_s.ljust(30)
  puts ""
  print "Leg_pain_numbness mismatched".ljust(50)
  print drug_induced_leg_pain_numbness_records.count.to_s.ljust(30)
  puts ""
  print "Lipodystrophy mismatched".ljust(50)
  print drug_induced_lipodystrophy_records.count.to_s.ljust(30)
  puts ""
  print "No mismatched".ljust(50)
  print drug_induced_no_records.count.to_s.ljust(30)
  puts ""
  print "Other mismatched".ljust(50)
  print drug_induced_other_records.count.to_s.ljust(30)
  puts ""
  print "Peripheral_neuropathy mismatched".ljust(50)
  print drug_induced_peripheral_neuropathy_records.count.to_s.ljust(30)
  puts ""
  print "Psychosis mismatched".ljust(50)
  print drug_induced_psychosis_records.count.to_s.ljust(30)
  puts ""
  print "Renal_failure mismatched".ljust(50)
  print drug_induced_renal_failure_records.count.to_s.ljust(30)
  puts ""
  print "Vomiting mismatched".ljust(50)
  print drug_induced_vomiting_records.count.to_s.ljust(30)
  puts ""
  print "Nightmares mismatched".ljust(50)
  print drug_induced_nightmares_records.count.to_s.ljust(30)
  puts ""
  puts "Symptoms Present"
  print "Abdominal_pain mismatched".ljust(50)
  print symptom_present_abdominal_pain_records.count.to_s.ljust(30)
  puts ""
  print "Anemia mismatched".ljust(50)
  print symptom_present_anemia_records.count.to_s.ljust(30)
  puts ""
  print "Anorexia mismatched".ljust(50)
  print symptom_present_anorexia_records.count.to_s.ljust(30)
  puts ""
  print "Blurry_vision mismatched".ljust(50)
  print symptom_present_blurry_vision_records.count.to_s.ljust(30)
  puts ""
  print "Cough mismatched".ljust(50)
  print symptom_present_cough_records.count.to_s.ljust(30)
  puts ""
  print "Diarrhea mismatched".ljust(50)
  print symptom_present_diarrhea_records.count.to_s.ljust(30)
  puts ""
  print "Diziness mismatched".ljust(50)
  print symptom_present_diziness_records.count.to_s.ljust(30)
  puts ""
  print "Fever mismatched".ljust(50)
  print symptom_present_fever_records.count.to_s.ljust(30)
  puts ""
  print "Gynaecomastia mismatched".ljust(50)
  print symptom_present_gynaecomastia_records.count.to_s.ljust(30)
  puts ""
  print "Hepatitis mismatched".ljust(50)
  print symptom_present_hepatitis_records.count.to_s.ljust(30)
  puts ""
  print "Jaundice mismatched".ljust(50)
  print symptom_present_jaundice_records.count.to_s.ljust(30)
  puts ""
  print "Kidney_failure mismatched".ljust(50)
  print symptom_present_kidney_failure_records.count.to_s.ljust(30)
  puts ""
  print "Lactic_acidosis mismatched".ljust(50)
  print symptom_present_lactic_acidosis_records.count.to_s.ljust(30)
  puts ""
  print "Leg_pain_numbness mismatched".ljust(50)
  print symptom_present_leg_pain_numbness_records.count.to_s.ljust(30)
  puts ""
  print "Lipodystrophy mismatched".ljust(50)
  print symptom_present_lipodystrophy_records.count.to_s.ljust(30)
  puts ""
  print "No mismatched".ljust(50)
  print symptom_present_no_records.count.to_s.ljust(30)
  puts ""
  print "Other mismatched".ljust(50)
  print symptom_present_other_symptom_records.count.to_s.ljust(30)
  puts ""
  print "Peripheral_neuropathy mismatched".ljust(50)
  print symptom_present_peripheral_neuropathy_records.count.to_s.ljust(30)
  puts ""
  print "Psychosis mismatched".ljust(50)
  print symptom_present_psychosis_records.count.to_s.ljust(30)
  puts ""
  print "Renal_failure mismatched".ljust(50)
  print sysmptom_present_renal_failure_records.count.to_s.ljust(30)
  puts ""
  print "Vomiting mismatched".ljust(50)
  print symptom_present_vomiting_records.count.to_s.ljust(30)
  puts ""
  print "Nightmares mismatched".ljust(50)
  print symptom_present_nightmares_records.count.to_s.ljust(30)
  puts ""
  print "Skin Rash mismatched".ljust(50)
  print symptom_present_skin_rash_records.count.to_s.ljust(30)
  puts ""
  puts "\nTreatment Encounters summary\n"
  print "Category".ljust(50)
  print "Total Number of fields".ljust(30)
  puts ""
  print "IPT given not matched".ljust(50)
  print ipt_given_ids.count.to_s.ljust(30)
  puts ""
  print "CPT given not matched".ljust(50)
  print cpt_given_ids.count.to_s.ljust(30)
  puts ""
  print "Condoms given not matched".ljust(50)
  print condoms_given_ids.count.to_s.ljust(30)
  puts ""
  print "Regimen category not matched".ljust(50)
  print regimen_category_treatment_ids.count.to_s.ljust(30)
  puts ""
  print "Type of ARV regimen category not matched".ljust(50)
  print type_of_ARV_regimen_given_ids.count.to_s.ljust(30)
  puts ""
  print "Treatment obs not in flat_tables".ljust(50)
  print treatment_obs_not_in_any_category_details.count.to_s.ljust(30)
  puts ""
  puts "\nDispensing Encounters summary\n"
  print "Category".ljust(50)
  print "Total Number of fields".ljust(30)
  puts ""
  print "Regimen Category not matched".ljust(50)
  print regimen_category_dispensed_ids.count.to_s.ljust(30)
  puts ""
  print "ARV regimens received construct not matched".ljust(50)
  print arv_regimens_received_construct_ids.count.to_s.ljust(30)
  puts ""
  print "Dispensing obs not in flat tables".ljust(50)
  print dispensing_obs_not_in_any_category_ids.count.to_s.ljust(30)
  puts ""
  puts "\nPatient Outcomes Encounters summary\n"
  print "Category".ljust(50)
  print "Total Number of fields".ljust(30)
  puts ""
  print "Current HIV program states not matched".ljust(50)
  print current_hiv_program_state_ids.count.to_s.ljust(30)
  puts ""
  print "Curent HIV program state date not matched".ljust(50)
  print current_hiv_program_start_date_ids.count.to_s.ljust(30)
  puts ""
  puts "\nDrug Orders summary\n"
  print "Category".ljust(50)
  print "Total Number of fields".ljust(30)
  puts ""
  print "Drug orders not matched".ljust(50)
  print drug_order_ids.count.to_s.ljust(30)
  puts ""
  print "Drug encounters not matched".ljust(50)
  print drug_encounter_ids.count.to_s.ljust(30)
  puts ""
  print "Drug start_date not matched".ljust(50)
  print drug_start_date_ids.count.to_s.ljust(30)
  puts ""
  print "Drug auto_expire_date not matched".ljust(50)
  print drug_auto_expire_date_ids.count.to_s.ljust(30)
  puts ""
  print "Drug inventory_id not matched".ljust(50)
  print drug_inventory_ids.count.to_s.ljust(30)
  puts ""
  print "Drug name not matched".ljust(50)
  print drug_name_ids.count.to_s.ljust(30)
  puts ""
  print "Drug equivalent_daily_dose not matched".ljust(50)
  print drug_equivalent_daily_dose_ids.count.to_s.ljust(30)
  puts ""
  print "Drug dose not matched".ljust(50)
  print drug_dose_ids.count.to_s.ljust(30)
  puts ""
  print "Drug frequency not matched".ljust(50)
  print drug_frequency_ids.count.to_s.ljust(30)
  puts ""
  print "Drug quantity not matched".ljust(50)
  print drug_quantity_ids.count.to_s.ljust(30)
  puts ""
  #uniqueness
  #Accuracy

   if FlattablesdDataAnalysis == 1
    file = "flat_tables_data_analysis.csv"
    FasterCSV.open( file, 'w' ) do |csv|
      csv << ["Facility_Name", "Category", "Patient_ids"]
      csv << ["Facility_Name", "Demographics with not in source dbs", "#{ids_not_in_source_ids.join(',')}"] unless ids_not_in_source_ids.blank?
      csv << ["Facility_Name", "Demographics with not in flat_tables", "#{ids_not_in_flat1_ids.join(',')}"] unless ids_not_in_flat1_ids.blank?

      csv << ["Facility_Name", "Demographics with missing mandatory fields", "#{patient_ids_with_missing_mandetory_demo_fields.join(',')}"] unless patient_ids_with_missing_mandetory_demo_fields.blank?
      csv << ["Facility_Name", "Demographics with inaccurate fields", "#{rs_demo_not_accurate_ids.join(',')}"] unless rs_demo_not_accurate_ids.blank?
      csv << ["Facility_Name", "Duplicate ARV numbers", "#{nonUniqueARV_Numbers_ids.join(',')}"] unless nonUniqueARV_Numbers_ids.blank?
      csv << ["Facility_Name", "Duplicate patient Ids", "#{nonUniquePatientRecords_ids.join(',')}"] unless nonUniquePatientRecords_ids.blank?
      csv << ["Facility_Name", "Duplicate National IDs", "#{nonUniqueNational_records_ids.join(',')}"] unless nonUniqueNational_records_ids.blank?

      csv << ["Facility_Name", "HIV Reception visits not in source", "#{visits_not_in_source_records.join(',')}"] unless visits_not_in_source_records.blank?
      csv << ["Facility_Name", "HIV Reception visits not in flat_tables", "#{visits_not_in_flats_records.join(',')}"] unless visits_not_in_flats_records.blank?
      csv << ["Facility_Name", "Incomplete HIV Reception visits", "#{incomplete_hiv_reception_visit_records.join(',')}"] unless incomplete_hiv_reception_visit_records.blank?

      csv << ["Facility_Name", "Patients without Vitals", "#{patients_without_vitals_obs.join(',')}"] unless patients_without_vitals_obs.blank?
      csv << ["Facility_Name", "Patients without mandatory fields during 1st visit", "#{patients_without_mandatory_fields_1st_visit.join(',')}"] unless patients_without_mandatory_fields_1st_visit.blank?
      csv << ["Facility_Name", "Vitals visit that did not match in flat_tables", "#{}{vitals_visits_without_a_match_in_flats.join(',')}"] unless vitals_visits_without_a_match_in_flats.blank?

      csv << ["Facility_Name", "TB suspected mismatched","#{tb_status_tb_suspected_records.join(',')}"] unless tb_status_tb_suspected_records.blank?
      csv << ["Facility_Name", "TB NOT suspected mismatched","#{tb_status_tb_not_suspected_records.join(',')}"] unless tb_status_tb_not_suspected_records.blank?
      csv << ["Facility_Name", "TB Confirmed and on treatment mismatched","#{tb_status_confirmed_tb_on_treatment_records.join(',')}"] unless tb_status_confirmed_tb_on_treatment_records.blank?
      csv << ["Facility_Name", "TB Confirmed and not on treatment mismatched","#{tb_status_confirmed_tb_not_on_treatment_records.join(',')}"] unless tb_status_confirmed_tb_not_on_treatment_records.blank?
      csv << ["Facility_Name", "Unknown TB status","#{tb_status_unknown_records.join(',')}"] unless tb_status_unknown_records.blank?

      csv << ["Facility_Name", "Fever mismatched","#{routine_tb_screening_fever_records.join(',')}"] unless routine_tb_screening_fever_records.blank?
      csv << ["Facility_Name", "Night sweats mismatched","#{routine_tb_screening_night_sweats_records.join(',')}"] unless routine_tb_screening_night_sweats_records.blank?
      csv << ["Facility_Name", "Cough mismatched","#{routine_tb_screening_cough_of_any_duration_records.join(',')}"] unless routine_tb_screening_cough_of_any_duration_records.blank?
      csv << ["Facility_Name", "Weigh loss mismatched","#{routine_tb_screening_weight_loss_failure_records.join(',')}"] unless routine_tb_screening_weight_loss_failure_records.blank?

      csv << ["Facility_Name", "Currently using family planning mismatched", "#{currently_using_family_planning_method_records.join(',')}"] unless currently_using_family_planning_method_records.blank?
      csv << ["Facility_Name", "Oral Contraceptive pills mismatched","#{family_planning_method_oral_contraceptive_pills_records.join(',')}"] unless family_planning_method_oral_contraceptive_pills_records.blank?
      csv << ["Facility_Name", "Depo-provera mismatched","#{family_planning_method_depo_provera_records.join(',')}"] unless family_planning_method_depo_provera_records.blank?
      csv << ["Facility_Name", "Tubal ligation mismatched","#{family_planning_method_tubal_ligation_records.join(',')}"] unless family_planning_method_tubal_ligation_records.blank?
      csv << ["Facility_Name", "Abstinence mismatched","#{family_planning_method_abstinence_records.join(',')}"] unless family_planning_method_abstinence_records.blank?
      csv << ["Facility_Name", "Vasectomy mismatched","#{family_planning_method_vasectomy_records.join(',')}"] unless family_planning_method_vasectomy_records.blank?
      csv << ["Facility_Name", "Intrauterine mismatched","#{family_planning_method_intrauterine_contraception_records.join(',')}"] unless family_planning_method_intrauterine_contraception_records.blank?
      csv << ["Facility_Name", "Implant mismatched","#{family_planning_method_contraceptive_implant_records.join(',')}"] unless family_planning_method_contraceptive_implant_records.blank?
      csv << ["Facility_Name", "Male condoms mismatched","#{family_planning_method_male_condoms_records.join(',')}"] unless family_planning_method_male_condoms_records.blank?
      csv << ["Facility_Name", "Female Condoms mismatched","#{family_planning_method_female_condoms_records.join(',')}"] unless family_planning_method_female_condoms_records.blank?
      csv << ["Facility_Name", "Rythm mismatched","#{family_planning_method_rythm_method_records.join(',')}"] unless family_planning_method_rythm_method_records.blank?
      csv << ["Facility_Name", "Withdrawal mismatched","#{family_planning_method_withdrawal_records.join(',')}"] unless family_planning_method_withdrawal_records.blank?
      csv << ["Facility_Name", "Emergency Contraceptive pills mismatched","#{family_planning_method_emergency_contraception_records.join(',')}"] unless family_planning_method_emergency_contraception_records.blank?

      csv << ["Facility_Name", "Abdominal_pain mismatched","#{drug_induced_abdominal_pain_records.join(',')}"] unless drug_induced_abdominal_pain_records.blank?
      csv << ["Facility_Name", "Anemia mismatched","#{drug_induced_anemia_records.join(',')}"] unless drug_induced_anemia_records.blank?
      csv << ["Facility_Name", "Anorexia mismatched","#{drug_induced_anorexia_records.join(',')}"] unless drug_induced_anorexia_records.blank?
      csv << ["Facility_Name", "Blurry_vision mismatched","#{drug_induced_blurry_vision_records.join(',')}"] unless drug_induced_blurry_vision_records.blank?
      csv << ["Facility_Name", "Cough mismatched","#{drug_induced_cough_records.join(',')}"] unless drug_induced_cough_records.blank?
      csv << ["Facility_Name", "Diarrhea mismatched","#{drug_induced_diarrhea_records.join(',')}"] unless drug_induced_diarrhea_records.blank?
      csv << ["Facility_Name", "Diziness mismatched","#{drug_induced_diziness_records.join(',')}"] unless drug_induced_diziness_records.blank?
      csv << ["Facility_Name", "Fever mismatched","#{drug_induced_fever_records.join(',')}"] unless drug_induced_fever_records.blank?
      csv << ["Facility_Name", "Gynaecomastia mismatched","#{drug_induced_gynaecomastia_records.join(',')}"] unless drug_induced_gynaecomastia_records.blank?
      csv << ["Facility_Name", "Hepatitis mismatched","#{drug_induced_hepatitis_records.join(',')}"] unless drug_induced_hepatitis_records.blank?
      csv << ["Facility_Name", "Jaundice mismatched","#{drug_induced_jaundice_records.join(',')}"] unless drug_induced_jaundice_records.blank?
      csv << ["Facility_Name", "Kidney_failure mismatched","#{drug_induced_kidney_failure_records.join(',')}"] unless drug_induced_kidney_failure_records.blank?
      csv << ["Facility_Name", "Lactic_acidosis mismatched","#{drug_induced_lactic_acidosis_records.join(',')}"] unless drug_induced_lactic_acidosis_records.blank?
      csv << ["Facility_Name", "Leg_pain_numbness mismatched","#{drug_induced_leg_pain_numbness_records.join(',')}"] unless drug_induced_leg_pain_numbness_records.blank?
      csv << ["Facility_Name", "Lipodystrophy mismatched","#{drug_induced_lipodystrophy_records.join(',')}"] unless drug_induced_lipodystrophy_records.blank?
      csv << ["Facility_Name", "No mismatched","#{drug_induced_no_records.join(',')}"] unless drug_induced_no_records.blank?
      csv << ["Facility_Name", "Other mismatched","#{drug_induced_other_records.join(',')}"] unless drug_induced_other_records.blank?
      csv << ["Facility_Name", "Peripheral_neuropathy mismatched","#{drug_induced_peripheral_neuropathy_records.join(',')}"] unless drug_induced_peripheral_neuropathy_records.blank?
      csv << ["Facility_Name", "Psychosis mismatched","#{drug_induced_psychosis_records.join(',')}"] unless drug_induced_psychosis_records.blank?
      csv << ["Facility_Name", "Renal_failure mismatched","#{drug_induced_renal_failure_records.join(',')}"] unless drug_induced_renal_failure_records.blank?
      csv << ["Facility_Name", "Vomiting mismatched","#{drug_induced_vomiting_records.join(',')}"] unless drug_induced_vomiting_records.blank?
      csv << ["Facility_Name", "Nightmares mismatched","#{drug_induced_nightmares_records.join(',')}"] unless drug_induced_nightmares_records.blank?

      csv << ["Facility_Name", "Abdominal_pain mismatched","#{symptom_present_abdominal_pain_records.join(',')}"] unless symptom_present_abdominal_pain_records.blank?
      csv << ["Facility_Name", "Anemia mismatched","#{symptom_present_anemia_records.join(',')}"] unless symptom_present_anemia_records.blank?
      csv << ["Facility_Name", "Anorexia mismatched","#{symptom_present_anorexia_records.join(',')}"] unless symptom_present_anorexia_records.blank?
      csv << ["Facility_Name", "Blurry_vision mismatched","#{symptom_present_blurry_vision_records.join(',')}"] unless symptom_present_blurry_vision_records.blank?
      csv << ["Facility_Name", "Cough mismatched","#{symptom_present_cough_records.join(',')}"] unless symptom_present_cough_records.blank?
      csv << ["Facility_Name", "Diarrhea mismatched","#{symptom_present_diarrhea_records.join(',')}"] unless symptom_present_diarrhea_records.blank?
      csv << ["Facility_Name", "Diziness mismatched","#{symptom_present_diziness_records.join(',')}"] unless symptom_present_diziness_records.blank?
      csv << ["Facility_Name", "Fever mismatched","#{symptom_present_fever_records.join(',')}"] unless symptom_present_fever_records.blank?
      csv << ["Facility_Name", "Gynaecomastia mismatched","#{symptom_present_gynaecomastia_records.join(',')}"] unless symptom_present_gynaecomastia_records.blank?
      csv << ["Facility_Name", "Hepatitis mismatched","#{symptom_present_hepatitis_records.join(',')}"] unless symptom_present_hepatitis_records.blank?
      csv << ["Facility_Name", "Jaundice mismatched","#{symptom_present_jaundice_records.join(',')}"] unless symptom_present_jaundice_records.blank?
      csv << ["Facility_Name", "Kidney_failure mismatched","#{symptom_present_kidney_failure_records.join(',')}"] unless symptom_present_kidney_failure_records.blank?
      csv << ["Facility_Name", "Lactic_acidosis mismatched","#{symptom_present_lactic_acidosis_records.join(',')}"] unless symptom_present_lactic_acidosis_records.blank?
      csv << ["Facility_Name", "Leg_pain_numbness mismatched","#{symptom_present_leg_pain_numbness_records.join(',')}"] unless symptom_present_leg_pain_numbness_records.blank?
      csv << ["Facility_Name", "Lipodystrophy mismatched","#{symptom_present_lipodystrophy_records.join(',')}"] unless symptom_present_lipodystrophy_records.blank?
      csv << ["Facility_Name", "No mismatched","#{symptom_present_no_records.join(',')}"] unless symptom_present_no_records.blank?
      csv << ["Facility_Name", "Other mismatched","#{symptom_present_other_symptom_records.join(',')}"] unless symptom_present_other_symptom_records.blank?
      csv << ["Facility_Name", "Peripheral_neuropathy mismatched","#{symptom_present_peripheral_neuropathy_records.join(',')}"] unless symptom_present_peripheral_neuropathy_records.blank?
      csv << ["Facility_Name", "Psychosis mismatched","#{symptom_present_psychosis_records.join(',')}"] unless symptom_present_psychosis_records.blank?
      csv << ["Facility_Name", "Renal_failure mismatched", "#{sysmptom_present_renal_failure_records.join(',')}"] unless sysmptom_present_renal_failure_records.blank?
      csv << ["Facility_Name", "Vomiting mismatched","#{symptom_present_vomiting_records.join(',')}"] unless symptom_present_vomiting_records.blank?
      csv << ["Facility_Name", "Nightmares mismatched","#{symptom_present_nightmares_records.join(',')}"] unless symptom_present_nightmares_records.blank?
      csv << ["Facility_Name", "Skin Rash mismatched","#{symptom_present_skin_rash_records.join(',')}"] unless symptom_present_skin_rash_records.blank?

      csv << ["Facility_Name", "Patients with not in flat_tables", "#{patients_not_in_flat_tables.join(',')}"] unless patients_not_in_flat_tables.blank?
      csv << ["Facility_Name", "Patients with Unknown ever recieved ART", "#{unknown_ever_reg.join(',')}"] unless unknown_ever_reg.blank?
      csv << ["Facility_Name", "Transfer-ins patients without all mandatory fields", "#{transfer_ins_without_all_fields.join(',')}"] unless transfer_ins_without_all_fields.blank?
      csv << ["Facility_Name", "Agrres to followup not matching", "#{agrees_to_followup_ids.join(',')}"] unless agrees_to_followup_ids.blank?
      csv << ["Facility_Name", "Ever received ART not matching", "#{ever_received_art_ids.join(',')}"] unless ever_received_art_ids.blank?
      csv << ["Facility_Name", "Date ART last taken not matching", "#{date_art_last_taken_ids.join(',')}"] unless date_art_last_taken_ids.blank?
      csv << ["Facility_Name", "Taken ART in last two weeks not matching", "#{taken_art_in_last_two_months_ids.join(',')}"] unless taken_art_in_last_two_months_ids.blank?
      csv << ["Facility_Name", "Taken ART in last two weeks not matching", "#{taken_art_in_last_two_weeks_ids.join(',')}"] unless taken_art_in_last_two_weeks_ids.blank?
      csv << ["Facility_Name", "Last ART drugs taken ids not matching", "#{last_art_drugs_taken_ids.join(',')}"] unless last_art_drugs_taken_ids.blank?
      csv << ["Facility_Name", "Ever registered at ART clinic not matching", "#{ever_registered_at_art_clinic_ids.join(',')}"] unless ever_registered_at_art_clinic_ids.blank?
      csv << ["Facility_Name", "Has transfer letter ids not matching", "#{has_transfer_letter_ids.join(',')}"] unless has_transfer_letter_ids.blank?
      csv << ["Facility_Name", "Location of ART initialization not matching", "#{location_of_art_initialization_ids.join(',')}"] unless location_of_art_initialization_ids.blank?
      #csv << ["Facility_Name", "ART start date estimation not matching", "#{art_start_date_estimation_ids.join(',')}"] unless art_start_date_estimation_ids.blank?
      csv << ["Facility_Name", "Date started ART ids not matching", "#{taken_art_in_last_two_weeks_ids.join(',')}"] unless taken_art_in_last_two_weeks_ids.blank?
      csv << ["Facility_Name", "Send sms  taken ids not matching", "#{send_sms_ids.join(',')}"] unless send_sms_ids.blank?
      csv << ["Facility_Name", "Type of confirmatory HIV test not matching", "#{type_of_confirmatory_hiv_test_ids.join(',')}"] unless type_of_confirmatory_hiv_test_ids.blank?
      csv << ["Facility_Name", "Confirmatory HIV test location not matching", "#{confirmatory_hiv_test_location_ids.join(',')}"] unless confirmatory_hiv_test_location_ids.blank?
      csv << ["Facility_Name", "Confirmatory HIV test date not matching", "#{confirmatory_hiv_test_date_ids.join(',')}"] unless confirmatory_hiv_test_date_ids.blank?
      csv << ["Facility_Name", "Patients without HIV clinic reg obs not matching", "#{patients_without_hiv_clinic_reg_obs.join(',')}"] unless patients_without_hiv_clinic_reg_obs.blank?
      csv << ["","Treatement observations",""]
      csv << ["Facility_Name", "Total visits not in flat_tables", "#{treatment_visits_not_in_flats.join(',')}"] unless treatment_visits_not_in_flats.blank?
      csv << ["Facility_Name", "Total visits not in source", "#{treatment_visits_not_in_source.join(',')}"] unless treatment_visits_not_in_source.blank?
      csv << ["Facility_Name", "IPT given not matched", "#{ipt_given_ids.join(',')}"] unless ipt_given_ids.blank?
      csv << ["Facility_Name", "CPT given not matched", "#{cpt_given_ids.join(',')}"] unless cpt_given_ids.blank?
      csv << ["Facility_Name", "Condoms given not matched", "#{condoms_given_ids.join(',')}"] unless condoms_given_ids.blank?
      csv << ["Facility_Name", "Regimen category not matched", "#{regimen_category_treatment_ids.join(',')}"] unless regimen_category_treatment_ids.blank?
      csv << ["Facility_Name", "Type of ARV regimen category not matched", "#{type_of_ARV_regimen_given_ids.join(',')}"] unless type_of_ARV_regimen_given_ids.blank?
      csv << ["Facility_Name", "Treatment obs not in flat_tables", "#{treatment_obs_not_in_any_category_details.join(',')}"] unless treatment_obs_not_in_any_category_details.blank?
      csv << ["","Treatement observations",""]
      csv << ["Facility_Name", "Total visits not in flat_tables", "#{dispensing_visits_not_in_flats.join(',')}"] unless dispensing_visits_not_in_flats.blank?
      csv << ["Facility_Name", "Total visits not in source", "#{dispensing_visits_not_in_source.join(',')}"] unless dispensing_visits_not_in_source.blank?
      csv << ["Facility_Name", "Regimen Category not matched", "#{regimen_category_dispensed_ids.join(',')}"] unless regimen_category_dispensed_ids.blank?
      csv << ["Facility_Name", "ARV regimens received construct not matched", "#{arv_regimens_received_construct_ids.join(',')}"] unless arv_regimens_received_construct_ids.blank?
      csv << ["Facility_Name", "Dispensing obs not in flat tables", "#{dispensing_obs_not_in_any_category_ids.join(',')}"] unless dispensing_obs_not_in_any_category_ids.blank?
      csv << ["","Patient outcome details",""]
      csv << ["Facility_Name", "Total visits not in flat_tables", "#{patient_outcome_visits_not_in_flats.join(',')}"] unless patient_outcome_visits_not_in_flats.blank?
      csv << ["Facility_Name", "Total visits not in source", "#{patient_outcome_visits_not_in_source.join(',')}"] unless patient_outcome_visits_not_in_source.blank?
      csv << ["Facility_Name", "Current HIV program states not matched", "#{current_hiv_program_state_ids.join(',')}"] unless current_hiv_program_state_ids.blank?
      csv << ["Facility_Name", "Current HIV program start date not matched", "#{current_hiv_program_start_date_ids.join(',')}"] unless current_hiv_program_start_date_ids.blank?
      csv << ["","Patient Orders details",""]
      csv << ["Facility_Name", "Total visits not in flat_tables", "#{patient_orders_visits_not_in_records.join(',')}"] unless patient_orders_visits_not_in_records.blank?
      csv << ["Facility_Name", "Total visits not in source", "#{patient_orders_visits_not_in_source_records.join(',')}"] unless patient_orders_visits_not_in_source_records.blank?
      csv << ["Facility_Name", "Drug orders not matched", "#{drug_order_ids.join(',')}"] unless drug_order_ids.blank?
      csv << ["Facility_Name", "Drug encounters not matched", "#{drug_encounter_ids.join(',')}"] unless drug_encounter_ids.blank?
      csv << ["Facility_Name", "Drug start_date not matched", "#{drug_start_date_ids.join(',')}"] unless drug_start_date_ids.blank?
      csv << ["Facility_Name", "Drug auto_expire_date not matched", "#{drug_auto_expire_date_ids.join(',')}"] unless drug_auto_expire_date_ids.blank?
      csv << ["Facility_Name", "Drug inventory_id not matched", "#{drug_inventory_ids.join(',')}"] unless drug_inventory_ids.blank?
      csv << ["Facility_Name", "Drug name not matched", "#{drug_name_ids.join(',')}"] unless drug_name_ids.blank?
      csv << ["Facility_Name", "Drug equivalent_daily_dose not matched", "#{drug_equivalent_daily_dose_ids.join(',')}"] unless drug_equivalent_daily_dose_ids.blank?
      csv << ["Facility_Name", "Drug dose not matched", "#{drug_dose_ids.join(',')}"] unless drug_dose_ids.blank?
      csv << ["Facility_Name", "Drug frequency not matched", "#{drug_frequency_ids.join(',')}"] unless drug_frequency_ids.blank?
      csv << ["Facility_Name", "Drug quantity not matched", "#{drug_quantity_ids.join(',')}"] unless drug_quantity_ids.blank?
    end
  end
end

def check_hiv_clinic_consultation_accuracy(patient_ids)
  dbconnect
  #family planning
  currently_using_family_planning_method_records = []; family_planning_method_oral_contraceptive_pills_records = []
  family_planning_method_depo_provera_records = []; family_planning_method_tubal_ligation_records = []
  family_planning_method_abstinence_records = []; family_planning_method_vasectomy_records = []
  family_planning_method_intrauterine_contraception_records = []; family_planning_method_contraceptive_implant_records = []
  family_planning_method_male_condoms_records = []; family_planning_method_female_condoms_records = []
  family_planning_method_rythm_method_records = []; family_planning_method_withdrawal_records = []
  family_planning_method_emergency_contraception_records = []

  #routine_tb_screening
  routine_tb_screening_fever_records = []; routine_tb_screening_night_sweats_records = []
  routine_tb_screening_cough_of_any_duration_records = []; routine_tb_screening_weight_loss_failure_records = []

  #tb_status
  tb_status_tb_not_suspected_records = []; tb_status_tb_suspected_records = []; tb_status_unknown_records = []
  tb_status_confirmed_tb_not_on_treatment_records = []; tb_status_confirmed_tb_on_treatment_records = []

  #drug_induced
  drug_induced_abdominal_pain_records = []; drug_induced_anemia_records = []; drug_induced_anorexia_records = []
  drug_induced_blurry_vision_records = []; drug_induced_cough_records = []; drug_induced_diarrhea_records = []; drug_induced_diziness_records = []
  drug_induced_fever_records = []; drug_induced_gynaecomastia_records = []; drug_induced_hepatitis_records = [];drug_induced_jaundice_records = []
  drug_induced_kidney_failure_records = []; drug_induced_lactic_acidosis_records = []; drug_induced_leg_pain_numbness_records = []; drug_induced_lipodystrophy_records = []
  drug_induced_no_records = []; drug_induced_other_records = []; drug_induced_peripheral_neuropathy_records = [];drug_induced_psychosis_records = []
  drug_induced_renal_failure_records = []; drug_induced_skin_rash_records = []; drug_induced_vomiting_records = []; drug_induced_nightmares_records = []

  #symptom_present
  symptom_present_lipodystrophy_records = []; symptom_present_anemia_records = []
  symptom_present_jaundice_records = []; symptom_present_lactic_acidosis_records = []; symptom_present_fever_records = []
  symptom_present_skin_rash_records = []; symptom_present_abdominal_pain_records = []; symptom_present_anorexia_records = []
  symptom_present_cough_records = []; symptom_present_diarrhea_records = [];symptom_present_hepatitis_records = []
  symptom_present_leg_pain_numbness_records = []; symptom_present_peripheral_neuropathy_records = []; symptom_present_vomiting_records = []
  symptom_present_other_symptom_records = []; symptom_present_kidney_failure_records = [];symptom_present_nightmares_records = []
  symptom_present_diziness_records = []; symptom_present_psychosis_records = []; symptom_present_blurry_vision_records = []
  symptom_present_gynaecomastia_records = []; symptom_present_no_records = []; sysmptom_present_renal_failure_records = []


  #Get all flat table eligible patients
  (patient_ids || []).each do |row| #open 1
    puts "Checking HIV Consultation encounter for patient ID: #{row} "
    #Select patient encounters
    rs_enc = querydb("Select encounter_id,date(encounter_datetime) date, year(encounter_datetime) enc_yr from encounter where encounter_type = 53 and voided = 0 and patient_id = #{row} order by encounter_datetime asc")

    #For each Encounter check for observations
    rs_enc.each do |encounter| #open 2
      #Get observations for the encounter
      rs_obs = querydb("SELECT person_id,concept_id, value_coded, IFNULL(value_text,(select name from concept_name where concept_id = value_coded and concept_name_type = 'FULLY_SPECIFIED')) concept_ans from obs where encounter_id = #{encounter["encounter_id"]} and voided = 0")

      #For each observation check for a corresponding entry in flat_table2 on encounter and concept
      rs_obs.each do |obs| #open 3
        rs_ft2_HIV_consult_obs = querydb("Select
            patient_pregnant, patient_breastfeeding, currently_using_family_planning_method, family_planning_method_oral_contraceptive_pills, family_planning_method_depo_provera, family_planning_method_intrauterine_contraception, family_planning_method_contraceptive_implant, family_planning_method_male_condoms, family_planning_method_female_condoms, family_planning_method_rythm_method, family_planning_method_withdrawal, family_planning_method_abstinence, family_planning_method_tubal_ligation, family_planning_method_vasectomy, family_planning_method_emergency_contraception, symptom_present_lipodystrophy, symptom_present_anemia, symptom_present_jaundice, symptom_present_lactic_acidosis, symptom_present_fever, symptom_present_skin_rash, symptom_present_abdominal_pain, symptom_present_anorexia, symptom_present_cough, symptom_present_diarrhea, symptom_present_hepatitis, symptom_present_leg_pain_numbness, symptom_present_peripheral_neuropathy, symptom_present_vomiting, symptom_present_other_symptom, symptom_present_kidney_failure, symptom_present_nightmares, symptom_present_diziness, symptom_present_psychosis, symptom_present_blurry_vision, symptom_present_gynaecomastia, symptom_present_no, sysmptom_present_renal_failure, side_effects_abdominal_pain, side_effects_anemia, side_effects_anorexia, side_effects_blurry_vision, side_effects_cough, side_effects_diarrhea, side_effects_diziness, side_effects_fever, side_effects_gynaecomastia, side_effects_hepatitis, side_effects_jaundice, side_effects_kidney_failure, side_effects_lactic_acidosis, side_effects_leg_pain_numbness, side_effects_lipodystrophy, side_effects_no, side_effects_other, side_effects_peripheral_neuropathy, side_effects_psychosis, side_effects_renal_failure, side_effects_skin_rash, side_effects_vomiting, side_effects_nightmares, drug_induced_abdominal_pain, drug_induced_anemia, drug_induced_anorexia, drug_induced_blurry_vision, drug_induced_cough, drug_induced_diarrhea, drug_induced_diziness, drug_induced_fever, drug_induced_gynaecomastia, drug_induced_hepatitis, drug_induced_jaundice, drug_induced_kidney_failure, drug_induced_lactic_acidosis, drug_induced_leg_pain_numbness, drug_induced_lipodystrophy, drug_induced_no, drug_induced_other, drug_induced_peripheral_neuropathy, drug_induced_psychosis, drug_induced_renal_failure, drug_induced_skin_rash, drug_induced_vomiting, drug_induced_nightmares, routine_tb_screening_fever, routine_tb_screening_night_sweats, routine_tb_screening_cough_of_any_duration, routine_tb_screening_weight_loss_failure, tb_status_tb_not_suspected, tb_status_tb_suspected, tb_status_confirmed_tb_not_on_treatment, tb_status_confirmed_tb_on_treatment, tb_status_unknown, allergic_to_sulphur, patient_pregnant_enc_id, patient_breastfeeding_enc_id, currently_using_family_planning_method_enc_id, family_planning_method_oral_contraceptive_pills_enc_id, family_planning_method_depo_provera_enc_id, family_planning_method_intrauterine_contraception_enc_id, family_planning_method_contraceptive_implant_enc_id, family_planning_method_male_condoms_enc_id, family_planning_method_female_condoms_enc_id, family_planning_method_rythm_method_enc_id, family_planning_method_withdrawal_enc_id, family_planning_method_abstinence_enc_id, family_planning_method_tubal_ligation_enc_id, family_planning_method_vasectomy_enc_id, family_planning_method_emergency_contraception_enc_id, symptom_present_abdominal_pain_enc_id, symptom_present_anemia_enc_id, symptom_present_anorexia_enc_id, symptom_present_blurry_vision_enc_id, symptom_present_cough_enc_id, symptom_present_diarrhea_enc_id, symptom_present_diziness_enc_id, symptom_present_fever_enc_id, symptom_present_gynaecomastia_enc_id, symptom_present_hepatitis_enc_id, symptom_present_jaundice_enc_id, symptom_present_kidney_failure_enc_id, symptom_present_lactic_acidosis_enc_id, symptom_present_leg_pain_numbness_enc_id, symptom_present_lipodystrophy_enc_id, symptom_present_no_enc_id, symptom_present_other_enc_id, symptom_present_peripheral_neuropathy_enc_id, symptom_present_psychosis_enc_id, symptom_present_renal_failure_enc_id, symptom_present_skin_rash_enc_id, symptom_present_vomiting_enc_id, sysmptom_present_renal_failure_enc_id, side_effects_abdominal_pain_enc_id, side_effects_anemia_enc_id, side_effects_anorexia_enc_id, side_effects_blurry_vision_enc_id, side_effects_cough_enc_id, side_effects_diarrhea_enc_id, side_effects_diziness_enc_id, side_effects_fever_enc_id, side_effects_hepatitis_enc_id, side_effects_jaundice_enc_id, side_effects_kidney_failure_enc_id, side_effects_lactic_acidosis_enc_id, side_effects_leg_pain_numbness_enc_id, side_effects_lipodystrophy_enc_id, side_effects_no_enc_id, side_effects_other_enc_id, side_effects_peripheral_neuropathy_enc_id, side_effects_psychosis_enc_id, side_effects_renal_failure_enc_id, side_effects_skin_rash_enc_id, side_effects_vomiting_enc_id, side_effects_gynaecomastia_enc_id, side_effects_nightmares_enc_id, drug_induced_abdominal_pain_enc_id, drug_induced_anemia_enc_id, drug_induced_anorexia_enc_id, drug_induced_blurry_vision_enc_id, drug_induced_cough_enc_id, drug_induced_diarrhea_enc_id, drug_induced_diziness_enc_id, drug_induced_fever_enc_id, drug_induced_gynaecomastia_enc_id, drug_induced_hepatitis_enc_id, drug_induced_jaundice_enc_id, drug_induced_kidney_failure_enc_id, drug_induced_lactic_acidosis_enc_id, drug_induced_leg_pain_numbness_enc_id, drug_induced_lipodystrophy_enc_id, drug_induced_no_enc_id, drug_induced_other_enc_id, drug_induced_peripheral_neuropathy_enc_id, drug_induced_psychosis_enc_id, drug_induced_renal_failure_enc_id, drug_induced_skin_rash_enc_id, drug_induced_vomiting_enc_id, drug_induced_nightmares_enc_id, routine_tb_screening_fever_enc_id, routine_tb_screening_night_sweats_enc_id, routine_tb_screening_cough_of_any_duration_enc_id, routine_tb_screening_weight_loss_failure_enc_id, tb_status_tb_not_suspected_enc_id, tb_status_tb_suspected_enc_id, tb_status_confirmed_tb_not_on_treatment_enc_id, tb_status_confirmed_tb_on_treatment_enc_id, tb_status_unknown_enc_id, allergic_to_sulphur_Yes_enc_id, allergic_to_sulphur_no_enc_id
            from flat_table2 where patient_id = #{row} and visit_date = '#{encounter["date"]}'")

        rs_ft2_HIV_consult_obs.each do |value| #open 4
          case obs["concept_id"] #open 5
          when 1717 #Patient using family planning
            if obs["concept_ans"] != value["currently_using_family_planning_method"] then
              writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables ")
              currently_using_family_planning_method_records << [row, encounter["date"]]
            end
            if encounter["encounter_id"] != value["currently_using_family_planning_method_enc_id"] then
              writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables value in source #{encounter["encounter_id"]} value in flat table2 #{value["currently_using_family_planning_method"]} ")
            end
          when 374 #Method of family planning
            case obs['value_coded'].to_i #open 6
            when 780 #Oral contraception
              if "Yes" != value["family_planning_method_oral_contraceptive_pills"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables ")
                family_planning_method_oral_contraceptive_pills_records << [row, encounter["date"]]
              end
              if encounter["encounter_id"] != value["family_planning_method_oral_contraceptive_pills_enc_id"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables value in source #{encounter["encounter_id"]} value in flat table2 #{value["currently_using_family_planning_method"]} ")
              end
            when 907 #Depo-provera
              if "Yes" != value["family_planning_method_depo_provera"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables ")
                family_planning_method_depo_provera_records << [row, encounter["date"]]
              end
              if encounter["encounter_id"] != value["family_planning_method_depo_provera_enc_id"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables value in source #{encounter["encounter_id"]} value in flat table2 #{value["family_planning_method_depo_provera_enc_id"]} ")
              end
            when 1719 #Tubal ligation"
              if "Yes" != value["family_planning_method_tubal_ligation"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables ")
                family_planning_method_tubal_ligation_records << [row, encounter["date"]]
              end
              if encounter["encounter_id"] != value["family_planning_method_tubal_ligation_enc_id"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables value in source #{encounter["encounter_id"]} value in flat table2 #{value["family_planning_method_tubal_ligation_enc_id"]} ")
              end
            when 1720 #Abstinence
              if "Yes" != value["family_planning_method_abstinence"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables ")
                family_planning_method_abstinence_records << [row, encounter["date"]]
              end
              if encounter["encounter_id"] != value["family_planning_method_abstinence_enc_id"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables value in source #{encounter["encounter_id"]} value in flat table2 #{value["family_planning_method_abstinence_enc_id"]} ")
              end
            when 1721 #Vasectomy
              if "Yes" != value["family_planning_method_vasectomy"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables ")
                family_planning_method_vasectomy_records << [row, encounter["date"]]
              end
              if encounter["encounter_id"] != value["family_planning_method_vasectomy_enc_id"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables value in source #{encounter["encounter_id"]} value in flat table2 #{value["family_planning_method_vasectomy_enc_id"]} ")
              end
            when 5275 #Intrauterine device"
              if "Yes" != value["family_planning_method_intrauterine_contraception"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables ")
                family_planning_method_intrauterine_contraception_records << [row, encounter["date"]]
              end
              if encounter["encounter_id"] != value["family_planning_method_intrauterine_contraception_enc_id"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables value in source #{encounter["encounter_id"]} value in flat table2 #{value["family_planning_method_vasectomy_enc_id"]} ")
              end
            when 7857 #Contraceptive implant"
              if "Yes" != value["family_planning_method_contraceptive_implant"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables ")
                family_planning_method_contraceptive_implant_records << [row, encounter["date"]]
              end
              if encounter["encounter_id"] != value["family_planning_method_contraceptive_implant_enc_id"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables value in source #{encounter["encounter_id"]} value in flat table2 #{value["family_planning_method_contraceptive_implant_enc_id"]} ")
              end
            when 7858 #Male condoms"
              if "Yes" != value["family_planning_method_male_condoms"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables ")
                family_planning_method_male_condoms_records << [row, encounter["date"]]
              end
              if encounter["encounter_id"] != value["family_planning_method_male_condoms_enc_id"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables value in source #{encounter["encounter_id"]} value in flat table2 #{value["family_planning_method_male_condoms_enc_id"]} ")
              end
            when 7859 #Female condoms"
              if "Yes" != value["family_planning_method_female_condoms"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables ")
                family_planning_method_female_condoms_records << [row, encounter["date"]]
              end
              if encounter["encounter_id"] != value["family_planning_method_female_condoms_enc_id"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables value in source #{encounter["encounter_id"]} value in flat table2 #{value["family_planning_method_female_condoms_enc_id"]} ")
              end
            when 7860 #Rythm method"
              if "Yes" != value["family_planning_method_rythm_method"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables ")
                family_planning_method_rythm_method_records << [row, encounter["date"]]
              end
              if encounter["encounter_id"] != value["family_planning_method_rythm_method_enc_id"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables value in source #{encounter["encounter_id"]} value in flat table2 #{value["family_planning_method_rythm_method_enc_id"]} ")
              end
            when 7861 #Withdrawal method"
              if "Yes" != value["family_planning_method_withdrawal"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables ")
                family_planning_method_withdrawal_records << [row, encounter["date"]]
              end
              if encounter["encounter_id"] != value["family_planning_method_withdrawal_enc_id"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables value in source #{encounter["encounter_id"]} value in flat table2 #{value["family_planning_method_withdrawal"]} ")
              end
            when 7862 #Emergency contraception"
              if "Yes" != value["family_planning_method_emergency_contraception"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables ")
                family_planning_method_emergency_contraception_records  << [row, encounter["date"]]
              end
              if encounter["encounter_id"] != value["family_planning_method_emergency_contraception_enc_id"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables value in source #{encounter["encounter_id"]} value in flat table2 #{value["family_planning_method_emergency_contraception_enc_id"]} ")
              end
            end #close 6
#-----------------------------------------------------------------------------------------------------------------------------------------------end family planning
          when 8259 #Routine TB screening
            case obs['value_coded'].to_i #open 7
            when 5945 #Fever
              if "Yes" != value["routine_tb_screening_fever"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables ")
                routine_tb_screening_fever_records << [row, encounter["date"]]
              end
              if encounter["encounter_id"] != value["routine_tb_screening_fever_enc_id"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables value in source #{encounter["encounter_id"]} value in flat table2 #{value["family_planning_method_emergency_contraception_enc_id"]} ")
              end
            when 6029 #Night sweats
              if "Yes" != value["routine_tb_screening_night_sweats"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables ")
                routine_tb_screening_night_sweats_records << [row, encounter["date"]]
              end
              if encounter["encounter_id"] != value["routine_tb_screening_night_sweats_enc_id"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables value in source #{encounter["encounter_id"]} value in flat table2 #{value["family_planning_method_emergency_contraception_enc_id"]} ")
              end
            when 8260 #Weight loss / Failure to thrive / malnutrition
              if "Yes" != value["routine_tb_screening_weight_loss_failure"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables ")
                routine_tb_screening_weight_loss_failure_records << [row, encounter["date"]]
              end
              if encounter["encounter_id"] != value["routine_tb_screening_weight_loss_failure_enc_id"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables value in source #{encounter["encounter_id"]} value in flat table2 #{value["family_planning_method_emergency_contraception_enc_id"]} ")
              end
            when 8261 #Cough of any duration
              if "Yes" != value["routine_tb_screening_cough_of_any_duration"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables ")
                routine_tb_screening_cough_of_any_duration_records << [row, encounter["date"]]
              end
              if encounter["encounter_id"] != value["routine_tb_screening_cough_of_any_duration_enc_id"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables value in source #{encounter["encounter_id"]} value in flat table2 #{value["family_planning_method_emergency_contraception_enc_id"]} ")
              end
            end #end 7
#-------------------------------------------------------------------------------------------------------------------------------------------end routine tb screening
          when 7459 #TB status
            case obs['value_coded'].to_i #open 8
            when 1067 #Unknown
              if "Yes" != value["tb_status_unknown"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables ")
                tb_status_unknown_records << [row, encounter["date"]]
              end
              if encounter["encounter_id"] != value["tb_status_unknown_enc_id"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables value in source #{encounter["encounter_id"]} value in flat table2 #{value["family_planning_method_emergency_contraception_enc_id"]} ")
              end
            when 7454 #TB NOT suspected
              if "Yes" != value["tb_status_tb_not_suspected"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables ")
                tb_status_tb_not_suspected_records << [row, encounter["date"]]
              end
              if encounter["encounter_id"] != value["tb_status_tb_not_suspected_enc_id"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables value in source #{encounter["encounter_id"]} value in flat table2 #{value["family_planning_method_emergency_contraception_enc_id"]} ")
              end
            when 7455 #TB suspected
              if "Yes" != value["tb_status_tb_suspected"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables ")
                tb_status_tb_suspected_records << [row, encounter["date"]]
              end
              if encounter["encounter_id"] != value["tb_status_tb_suspected_enc_id"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables value in source #{encounter["encounter_id"]} value in flat table2 #{value["family_planning_method_emergency_contraception_enc_id"]} ")
              end
            when 7456 #Confirmed TB NOT on treatment
              if "Yes" != value["tb_status_confirmed_tb_not_on_treatment"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables ")
                tb_status_confirmed_tb_not_on_treatment_records << [row, encounter["date"]]
              end
              if encounter["encounter_id"] != value["tb_status_confirmed_tb_not_on_treatment_enc_id"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables value in source #{encounter["encounter_id"]} value in flat table2 #{value["family_planning_method_emergency_contraception_enc_id"]} ")
              end
            when 7458 #Confirmed TB on treatment
              if "Yes" != value["tb_status_confirmed_tb_on_treatment"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables ")
                tb_status_confirmed_tb_on_treatment_records << [row, encounter["date"]]
              end
              if encounter["encounter_id"] != value["tb_status_confirmed_tb_on_treatment_enc_id"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables value in source #{encounter["encounter_id"]} value in flat table2 #{value["family_planning_method_emergency_contraception_enc_id"]} ")
              end
            end #end 8
#------------------------------------------------------------------------------------------------------------------------------------------------------end tb status
          when 7567 #Drug Induced
            case obs['value_coded'].to_i #open 9
            when 3 #Anemia
              if "Yes" != value["drug_induced_anemia"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables ")
                drug_induced_anemia_records << [row, encounter["date"]]
              end
              if encounter["encounter_id"] != value["drug_induced_anemia_enc_id"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables value in source #{encounter["encounter_id"]} value in flat table2 #{value["family_planning_method_emergency_contraception_enc_id"]} ")
              end
            when 16 #Diarrhea
              if "Yes" != value["drug_induced_diarrhea"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables ")
                drug_induced_diarrhea_records << [row, encounter["date"]]
              end
              if encounter["encounter_id"] != value["drug_induced_diarrhea_enc_id"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables value in source #{encounter["encounter_id"]} value in flat table2 #{value["family_planning_method_emergency_contraception_enc_id"]} ")
              end
            when 29 #Hepatitis
              if "Yes" != value["drug_induced_hepatitis"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables ")
                drug_induced_hepatitis_records << [row, encounter["date"]]
              end
              if encounter["encounter_id"] != value["drug_induced_hepatitis_enc_id"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables value in source #{encounter["encounter_id"]} value in flat table2 #{value["family_planning_method_emergency_contraception_enc_id"]} ")
              end
            when 107 #Cough
              if "Yes" != value["drug_induced_cough"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables ")
                drug_induced_cough_records << [row, encounter["date"]]
              end
              if encounter["encounter_id"] != value["drug_induced_cough_enc_id"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables value in source #{encounter["encounter_id"]} value in flat table2 #{value["family_planning_method_emergency_contraception_enc_id"]} ")
              end
            when 151 #Abdominal pain
              if "Yes" != value["drug_induced_abdominal_pain"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables ")
                drug_induced_abdominal_pain_records << [row, encounter["date"]]
              end
              if encounter["encounter_id"] != value["drug_induced_abdominal_pain_enc_id"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables value in source #{encounter["encounter_id"]} value in flat table2 #{value["family_planning_method_emergency_contraception_enc_id"]} ")
              end
            when 215 #Jaundice
              if "Yes" != value["drug_induced_jaundice"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables ")
                drug_induced_jaundice_records << [row, encounter["date"]]
              end
              if encounter["encounter_id"] != value["drug_induced_jaundice_enc_id"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables value in source #{encounter["encounter_id"]} value in flat table2 #{value["family_planning_method_emergency_contraception_enc_id"]} ")
              end
            when 219 #Psychosis
              if "Yes" != value["drug_induced_psychosis"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables ")
                drug_induced_psychosisrecords << [row, encounter["date"]]
              end
              if encounter["encounter_id"] != value["drug_induced_psychosis_enc_id"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables value in source #{encounter["encounter_id"]} value in flat table2 #{value["family_planning_method_emergency_contraception_enc_id"]} ")
              end
            when 512 #Skin rash
              if "Yes" != value["drug_induced_skin_rash"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables ")
                drug_induced_skin_rash_records << [row, encounter["date"]]
              end
              if encounter["encounter_id"] != value["drug_induced_skin_rash_enc_id"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables value in source #{encounter["encounter_id"]} value in flat table2 #{value["family_planning_method_emergency_contraception_enc_id"]} ")
              end
            when 821 #Peripheral neuropathy
              if "Yes" != value["drug_induced_peripheral_neuropathy"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables ")
                drug_induced_peripheral_neuropathy_records << [row, encounter["date"]]
              end
              if encounter["encounter_id"] != value["drug_induced_peripheral_neuropathy_enc_id"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables value in source #{encounter["encounter_id"]} value in flat table2 #{value["family_planning_method_emergency_contraception_enc_id"]} ")
              end
            when 868 #Anorexia
              if "Yes" != value["drug_induced_anorexia"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables ")
                drug_induced_anorexia_records << [row, encounter["date"]]
              end
              if encounter["encounter_id"] != value["drug_induced_anorexia_enc_id"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables value in source #{encounter["encounter_id"]} value in flat table2 #{value["family_planning_method_emergency_contraception_enc_id"]} ")
              end
            when 877 #Dizziness
              if "Yes" != value["drug_induced_diziness"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables ")
                drug_induced_diziness_records << [row, encounter["date"]]
              end
              if encounter["encounter_id"] != value["drug_induced_diziness_enc_id"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables value in source #{encounter["encounter_id"]} value in flat table2 #{value["family_planning_method_emergency_contraception_enc_id"]} ")
              end
            when 1458 #Lactic acidosis
              if "Yes" != value["drug_induced_lactic_acidosis"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables ")
                drug_induced_lactic_acidosis_records << [row, encounter["date"]]
              end
              if encounter["encounter_id"] != value["drug_induced_lactic_acidosis_enc_id"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables value in source #{encounter["encounter_id"]} value in flat table2 #{value["family_planning_method_emergency_contraception_enc_id"]} ")
              end
            when 2148 #Lipodystrophy
              if "Yes" != value["drug_induced_lipodystrophy"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables ")
                drug_induced_lipodystrophy_records << [row, encounter["date"]]
              end
              if encounter["encounter_id"] != value["drug_induced_lipodystrophy_enc_id"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables value in source #{encounter["encounter_id"]} value in flat table2 #{value["family_planning_method_emergency_contraception_enc_id"]} ")
              end
            when 2150 #Nightmares
              if "Yes" != value["drug_induced_nightmares"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables ")
                drug_induced_nightmares_records << [row, encounter["date"]]
              end
              if encounter["encounter_id"] != value["drug_induced_nightmares_enc_id"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables value in source #{encounter["encounter_id"]} value in flat table2 #{value["family_planning_method_emergency_contraception_enc_id"]} ")
              end
            when 5945 #Fever
              if "Yes" != value["drug_induced_fever"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables ")
                drug_induced_fever_records << [row, encounter["date"]]
              end
              if encounter["encounter_id"] != value["drug_induced_fever_enc_id"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables value in source #{encounter["encounter_id"]} value in flat table2 #{value["family_planning_method_emergency_contraception_enc_id"]} ")
              end
            when 5953 #Blurry Vision
              if "Yes" != value["drug_induced_blurry_vision"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables ")
                drug_induced_blurry_vision_records << [row, encounter["date"]]
              end
              if encounter["encounter_id"] != value["drug_induced_blurry_vision_enc_id"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables value in source #{encounter["encounter_id"]} value in flat table2 #{value["family_planning_method_emergency_contraception_enc_id"]} ")
              end
            when 5980 #Vomiting
              if "Yes" != value["drug_induced_vomiting"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables ")
                drug_induced_vomiting_records << [row, encounter["date"]]
              end
              if encounter["encounter_id"] != value["drug_induced_vomiting_enc_id"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables value in source #{encounter["encounter_id"]} value in flat table2 #{value["family_planning_method_emergency_contraception_enc_id"]} ")
              end
            when 6779 #Other symptom
              if "Yes" != value["drug_induced_other"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables ")
                drug_induced_other_records << [row, encounter["date"]]
              end
              if encounter["encounter_id"] != value["drug_induced_other_enc_id"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables value in source #{encounter["encounter_id"]} value in flat table2 #{value["family_planning_method_emergency_contraception_enc_id"]} ")
              end
            when 7952 #Leg pain / numbness
              if "Yes" != value["drug_induced_leg_pain_numbness"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables ")
                drug_induced_leg_pain_numbness_records << [row, encounter["date"]]
              end
              if encounter["encounter_id"] != value["drug_induced_leg_pain_numbness_enc_id"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables value in source #{encounter["encounter_id"]} value in flat table2 #{value["family_planning_method_emergency_contraception_enc_id"]} ")
              end
            when 9242 #Kidney Failure
              if "Yes" != value["drug_induced_kidney_failure"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables ")
                drug_induced_kidney_failure_records << [row, encounter["date"]]
              end
              if encounter["encounter_id"] != value["drug_induced_kidney_failure_enc_id"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables value in source #{encounter["encounter_id"]} value in flat table2 #{value["family_planning_method_emergency_contraception_enc_id"]} ")
              end
            when 9440 #Gynaecomastia
              if "Yes" != value["drug_induced_gynaecomastia"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables ")
                drug_induced_gynaecomastia_records << [row, encounter["date"]]
              end
              if encounter["encounter_id"] != value["drug_induced_gynaecomastia_enc_id"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables value in source #{encounter["encounter_id"]} value in flat table2 #{value["family_planning_method_emergency_contraception_enc_id"]} ")
              end
            when 1066 #no
              if "Yes" != value["drug_induced_no"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables ")
                drug_induced_no_records << [row, encounter["date"]]
              end
              if encounter["encounter_id"] != value["drug_induced_no_enc_id"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables value in source #{encounter["encounter_id"]} value in flat table2 #{value["family_planning_method_emergency_contraception_enc_id"]} ")
              end
            when 3681 #renal_failure
              if "Yes" != value["drug_induced_renal_failure"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables ")
                drug_induced_renal_failure_records << [row, encounter["date"]]
              end
              if encounter["encounter_id"] != value["drug_induced_renal_failure_enc_id"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables value in source #{encounter["encounter_id"]} value in flat table2 #{value["family_planning_method_emergency_contraception_enc_id"]} ")
              end
            end #close 9
#---------------------------------------------------------------------------------------------------------------------------------------------------end drug induced
          when 1293 #Symtoms present
            case obs['value_coded'].to_i #open 10
            when 3   #Anemia
              if "Yes" != value["symptom_present_anemia"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables ")
                symptom_present_anemia_records << [row, encounter["date"]]
              end
              if encounter["encounter_id"] != value["symptom_present_anemia_enc_id"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables value in source #{encounter["encounter_id"]} value in flat table2 #{value["family_planning_method_emergency_contraception_enc_id"]} ")
              end
            when 16  #Diarrhea
              if "Yes" != value["symptom_present_diarrhea"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables ")
                symptom_present_diarrhea_records << [row, encounter["date"]]
              end
              if encounter["encounter_id"] != value["symptom_present_diarrhea_enc_id"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables value in source #{encounter["encounter_id"]} value in flat table2 #{value["family_planning_method_emergency_contraception_enc_id"]} ")
              end
            when 29  #Hepatitis
              if "Yes" != value["symptom_present_hepatitis"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables ")
                symptom_present_hepatitis_records << [row, encounter["date"]]
              end
              if encounter["encounter_id"] != value["symptom_present_hepatitis_enc_id"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables value in source #{encounter["encounter_id"]} value in flat table2 #{value["family_planning_method_emergency_contraception_enc_id"]} ")
              end
            when 107 #Cough
              if "Yes" != value["symptom_present_cough"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables ")
                symptom_present_cough_records << [row, encounter["date"]]
              end
              if encounter["encounter_id"] != value["symptom_present_cough_enc_id"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables value in source #{encounter["encounter_id"]} value in flat table2 #{value["family_planning_method_emergency_contraception_enc_id"]} ")
              end
            when 151 #Abdominal pain
              if "Yes" != value["symptom_present_abdominal_pain"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables ")
                symptom_present_abdominal_pain_records << [row, encounter["date"]]
              end
              if encounter["encounter_id"] != value["symptom_present_abdominal_pain_enc_id"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables value in source #{encounter["encounter_id"]} value in flat table2 #{value["family_planning_method_emergency_contraception_enc_id"]} ")
              end
            when 215 #Jaundice
              if "Yes" != value["symptom_present_jaundice"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables ")
                symptom_present_jaundice_records << [row, encounter["date"]]
              end
              if encounter["encounter_id"] != value["symptom_present_jaundice_enc_id"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables value in source #{encounter["encounter_id"]} value in flat table2 #{value["family_planning_method_emergency_contraception_enc_id"]} ")
              end
            when 219 #Psychosis
              if "Yes" != value["symptom_present_psychosis"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables ")
                symptom_present_psychosis_records << [row, encounter["date"]]
              end
              if encounter["encounter_id"] != value["symptom_present_psychosis_enc_id"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables value in source #{encounter["encounter_id"]} value in flat table2 #{value["family_planning_method_emergency_contraception_enc_id"]} ")
              end
            when 512 #Skin rash
              if "Yes" != value["symptom_present_skin_rash"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables ")
                symptom_present_skin_rash_records << [row, encounter["date"]]
              end
              if encounter["encounter_id"] != value["symptom_present_skin_rash_enc_id"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables value in source #{encounter["encounter_id"]} value in flat table2 #{value["family_planning_method_emergency_contraception_enc_id"]} ")
              end
            when 821 #Peripheral neuropathy
              if "Yes" != value["symptom_present_peripheral_neuropathy"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables ")
                symptom_present_peripheral_neuropathy_records << [row, encounter["date"]]
              end
              if encounter["encounter_id"] != value["symptom_present_peripheral_neuropathy_enc_id"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables value in source #{encounter["encounter_id"]} value in flat table2 #{value["family_planning_method_emergency_contraception_enc_id"]} ")
              end
            when 868 #Anorexia
              if "Yes" != value["symptom_present_anorexia"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables ")
                symptom_present_anorexia_records << [row, encounter["date"]]
              end
              if encounter["encounter_id"] != value["symptom_present_anorexia_enc_id"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables value in source #{encounter["encounter_id"]} value in flat table2 #{value["family_planning_method_emergency_contraception_enc_id"]} ")
              end
            when 877 #Dizziness
              if "Yes" != value["symptom_present_diziness"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables ")
                symptom_present_diziness_records << [row, encounter["date"]]
              end
              if encounter["encounter_id"] != value["symptom_present_diziness_enc_id"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables value in source #{encounter["encounter_id"]} value in flat table2 #{value["family_planning_method_emergency_contraception_enc_id"]} ")
              end
            when 1458 #Lactic acidosis
              if "Yes" != value["symptom_present_lactic_acidosis"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables ")
                symptom_present_lactic_acidosis_records << [row, encounter["date"]]
              end
              if encounter["encounter_id"] != value["symptom_present_lactic_acidosis_enc_id"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables value in source #{encounter["encounter_id"]} value in flat table2 #{value["family_planning_method_emergency_contraception_enc_id"]} ")
              end
            when 2148 #Lipodystrophy
              if "Yes" != value["symptom_present_lipodystrophy"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables ")
                symptom_present_lipodystrophy_records << [row, encounter["date"]]
              end
              if encounter["encounter_id"] != value["symptom_present_lipodystrophy_enc_id"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables value in source #{encounter["encounter_id"]} value in flat table2 #{value["family_planning_method_emergency_contraception_enc_id"]} ")
              end
            when 2150 #Nightmares
              if "Yes" != value["symptom_present_nightmares"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables ")
                symptom_present_nightmares_records << [row, encounter["date"]]
              end
              if encounter["encounter_id"] != value["ssymptom_present_nightmares_enc_id"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables value in source #{encounter["encounter_id"]} value in flat table2 #{value["family_planning_method_emergency_contraception_enc_id"]} ")
              end
            when 5945 #Fever
              if "Yes" != value["symptom_present_fever"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables ")
                symptom_present_fever_records << [row, encounter["date"]]
              end
              if encounter["encounter_id"] != value["symptom_present_fever_enc_id"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables value in source #{encounter["encounter_id"]} value in flat table2 #{value["family_planning_method_emergency_contraception_enc_id"]} ")
              end
            when 5953 #Blurry Vision
              if "Yes" != value["symptom_present_blurry_vision"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables ")
                symptom_present_blurry_vision_records << [row, encounter["date"]]
              end
              if encounter["encounter_id"] != value["symptom_present_blurry_vision_enc_id"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables value in source #{encounter["encounter_id"]} value in flat table2 #{value["family_planning_method_emergency_contraception_enc_id"]} ")
              end
            when 5980 #Vomiting
              if "Yes" != value["symptom_present_vomiting"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables ")
                symptom_present_vomiting_records << [row, encounter["date"]]
              end
              if encounter["encounter_id"] != value["symptom_present_vomiting_enc_id"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables value in source #{encounter["encounter_id"]} value in flat table2 #{value["family_planning_method_emergency_contraception_enc_id"]} ")
              end
            when 6779 #Other symptom
              if "Yes" != value["symptom_present_other_symptom"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables ")
                symptom_present_other_symptom_records << [row, encounter["date"]]
              end
              if encounter["encounter_id"] != value["symptom_present_other_symptom_enc_id"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables value in source #{encounter["encounter_id"]} value in flat table2 #{value["family_planning_method_emergency_contraception_enc_id"]} ")
              end
            when 7952 #Leg pain / numbness
              if "Yes" != value["symptom_present_leg_pain_numbness"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables ")
                symptom_present_leg_pain_numbness_records << [row, encounter["date"]]
              end
              if encounter["encounter_id"] != value["symptom_present_leg_pain_numbness_enc_id"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables value in source #{encounter["encounter_id"]} value in flat table2 #{value["family_planning_method_emergency_contraception_enc_id"]} ")
              end
            when 9242 #Kidney Failure
              if "Yes" != value["symptom_present_kidney_failure"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables ")
                symptom_present_kidney_failure_records << [row, encounter["date"]]
              end
              if encounter["encounter_id"] != value["symptom_present_kidney_failure_enc_id"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables value in source #{encounter["encounter_id"]} value in flat table2 #{value["family_planning_method_emergency_contraception_enc_id"]} ")
              end

            when 9440 #Gynaecomastia
              if "Yes" != value["symptom_present_gynaecomastia"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables ")
                symptom_present_gynaecomastia_records << [row, encounter["date"]]
              end
              if encounter["encounter_id"] != value["symptom_present_gynaecomastia_enc_id"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables value in source #{encounter["encounter_id"]} value in flat table2 #{value["family_planning_method_emergency_contraception_enc_id"]} ")
              end
            when 1066 #no
              if "Yes" != value["symptom_present_no"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables ")
                symptom_present_no_records << [row, encounter["date"]]
              end
              if encounter["encounter_id"] != value["symptom_present_no_enc_id"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables value in source #{encounter["encounter_id"]} value in flat table2 #{value["family_planning_method_emergency_contraception_enc_id"]} ")
              end
            when 3681 #renal_failure
              if "Yes" != value["sysmptom_present_renal_failure"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables ")
                sysmptom_present_renal_failure_records << [row, encounter["date"]]
              end
              if encounter["encounter_id"] != value["sysmptom_present_renal_failure_enc_id"] then
                writetolog("Value not matching for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables value in source #{encounter["encounter_id"]} value in flat table2 #{value["family_planning_method_emergency_contraception_enc_id"]} ")
              end
            end #close 10
#------------------------------------------------------------------------------------------------------------------------------------------------end symptom present
          end #close 5
        end #close 4
      end #close 3
    end #close 2
  end #close 1

  return [currently_using_family_planning_method_records, family_planning_method_oral_contraceptive_pills_records , family_planning_method_depo_provera_records, family_planning_method_tubal_ligation_records, family_planning_method_abstinence_records, family_planning_method_vasectomy_records, family_planning_method_intrauterine_contraception_records, family_planning_method_contraceptive_implant_records, family_planning_method_male_condoms_records, family_planning_method_female_condoms_records, family_planning_method_rythm_method_records, family_planning_method_withdrawal_records, family_planning_method_emergency_contraception_records, routine_tb_screening_fever_records, routine_tb_screening_night_sweats_records, routine_tb_screening_cough_of_any_duration_records, routine_tb_screening_weight_loss_failure_records, tb_status_tb_not_suspected_records, tb_status_tb_suspected_records, tb_status_unknown_records, tb_status_confirmed_tb_not_on_treatment_records, tb_status_confirmed_tb_on_treatment_records, drug_induced_abdominal_pain_records, drug_induced_anemia_records, drug_induced_anorexia_records, drug_induced_blurry_vision_records, drug_induced_cough_records, drug_induced_diarrhea_records, drug_induced_diziness_records, drug_induced_fever_records, drug_induced_gynaecomastia_records, drug_induced_hepatitis_records, drug_induced_jaundice_records, drug_induced_kidney_failure_records, drug_induced_lactic_acidosis_records, drug_induced_leg_pain_numbness_records, drug_induced_lipodystrophy_records, drug_induced_no_records, drug_induced_other_records, drug_induced_peripheral_neuropathy_records, drug_induced_psychosis_records, drug_induced_renal_failure_records, drug_induced_skin_rash_records, drug_induced_vomiting_records, drug_induced_nightmares_records, symptom_present_lipodystrophy_records, symptom_present_anemia_records, symptom_present_jaundice_records, symptom_present_lactic_acidosis_records, symptom_present_fever_records, symptom_present_skin_rash_records, symptom_present_abdominal_pain_records, symptom_present_anorexia_records, symptom_present_cough_records, symptom_present_diarrhea_records, symptom_present_hepatitis_records, symptom_present_leg_pain_numbness_records, symptom_present_peripheral_neuropathy_records, symptom_present_vomiting_records, symptom_present_other_symptom_records, symptom_present_kidney_failure_records, symptom_present_nightmares_records, symptom_present_diziness_records, symptom_present_psychosis_records, symptom_present_blurry_vision_records, symptom_present_gynaecomastia_records, symptom_present_no_records, sysmptom_present_renal_failure_records]
end

def check_for_visits_with_missing_vitals_encounter(patient_ids)
  dbconnect
  patient_visits_from_source = ActiveRecord::Base.connection.select_all <<EOF
    SELECT patient_id, DATE(encounter_datetime) AS encounter_datetime FROM encounter
    WHERE encounter_type IN (6, 7, 9, 25, 51, 52, 53, 54, 68, 119)
    AND voided = 0
    AND patient_id IN (#{patient_ids.join(',')})
    GROUP BY patient_id, DATE(encounter_datetime);
EOF

  patient_visits_from_flat_tables = ActiveRecord::Base.connection.select_all <<EOF
    SELECT * FROM flat_table2;
EOF
  vitals_visits_in_source = []
  vitals_visits_in_flats = []

 (patient_visits_from_source || []).each do |patient|
   vitals_visits_in_source << [patient['patient_id'], patient['encounter_datetime']]
 end

 (patient_visits_from_flat_tables || []).each do |patient|
   vitals_visits_in_flats << [patient['patient_id'], patient['visit_date']]
 end

  vitals_visits_not_in_flats  = vitals_visits_in_source - vitals_visits_in_flats
  vitals_visits_not_in_source = vitals_visits_in_flats - vitals_visits_in_source
  vitals_incomplete_vitals_visit = []

  rs_on_art = querydb("select patient_id,year(birthdate) yob from temp_earliest_start_date")
  rs_on_art.each do |row|
      #Retrieve encounters for all patients
    rs_enc = querydb("Select date(encounter_datetime) date,encounter_id, year(encounter_datetime) enc_yr from encounter where voided = 0 and patient_id = #{row["patient_id"]} group by date(encounter_datetime) order by encounter_datetime asc")
    puts "Checking Visits for Patient ID: #{row["patient_id"]}"

    #Check for Visit with missing Vitals encounter
    rs_enc.each do |encounter|
    rs_enc_compare = querydb("Select encounter_id, date(encounter_datetime) date from encounter where date(encounter_datetime) = '#{encounter["date"]}' and patient_id = #{row["patient_id"]} and encounter_type = 6 and voided = 0")
      if rs_enc.count < 1 then
        writetolog("Visit dated #{encounter["date"]} for patient ID: #{row["patient_id"]} has no Vitals encounter")
        vitals_incomplete_vitals_visit << [row["patient_id"], encounter["date"]]
      end
    end
  end

  return [vitals_visits_in_source,
          vitals_visits_in_flats,
          vitals_visits_not_in_flats,
          vitals_visits_not_in_source,
          vitals_incomplete_vitals_visit]
end

def check_vitals_accuracy(patient_ids)
  dbconnect
  patients_without_vitals_obs = []
  patients_without_mandatory_fields_1st_visit = []
  patients_without_mandatory_fields_1st_visit = []
  vitals_visits_without_a_match_in_flats = []

  rs_on_art = querydb("select patient_id,year(birthdate) yob from temp_earliest_start_date")
  rs_on_art.each do |row|
    #Retrieve Non voided Vitals encounters for each patients
    rs_enc = querydb("Select encounter_id,date(encounter_datetime) date, year(encounter_datetime) enc_yr from encounter where encounter_type = 6 and voided = 0 and patient_id = #{row["patient_id"]} order by encounter_datetime asc")
    rs_enc.each do |encounter|
      rs_obs = querydb("select group_concat(if(name = 'bmi',value_numeric,null)) bmi,group_concat(if(name = 'HT',value_numeric,null)) height,group_concat(if(name = 'WT',value_numeric,null)) weight,group_concat(if(name = 'SBP',value_numeric,null)) systolic_blood_pressure, group_concat(if(name = 'DBP',value_numeric,null)) diastolic_blood_pressure from obs left join concept_name cn on obs.concept_id = cn.concept_id where obs.encounter_id = #{encounter["encounter_id"]} and obs.voided = 0 and cn.voided = 0 and cn.name in ('WT','HT','BMI','DBP','SBP')") #Retrieve observations

      # Record Encounter without observations
      if rs_enc.count == 0 then
        writetolog("#{encounter["date"]} for Patient ID #{row["patient_id"]} has no Vitals observations" )
        patients_without_vitals_obs << [row["patient_id"].to_i, encounter["date"]]
      else #Check observations found for accuracy
        rs_obs.each do |obs|
          #Get comparison observations from flat_table2
          rs_flat_vitals = querydb("select bmi,height,weight,systolic_blood_pressure,diastolic_blood_pressure from flat_table2 where visit_date = '#{encounter["date"]}' and patient_id = #{row["patient_id"]}")
          rs_flat_vitals.each do |vitals|
            if encounter["enc_yr"] - row["yob"] >= 30 then #Check if patient is greater than 30 years of age
              #Process Patients who are above 30 years of age
              puts "you are in the 30ties because of Patient ID: #{row["patient_id"]} #{encounter["enc_yr"]} - #{row["yob"]} = #{encounter["enc_yr"] - row["yob"]}"
              #Check if it is first visit_date
              if encounter["date"] == rs_enc.first["date"] then
                puts "Checking first Visit Vitals for Patient ID: #{row["patient_id"]}"
                #Check if mandatory fields have Data on the fist visit
                obs.each do |key, value|
                  if value.nil? then
                    puts "#{key} for Patient ID: #{row["patient_id"]} is nil"
                    patients_without_mandatory_fields_1st_visit << [row["patient_id"].to_i, encounter["encounter_id"].to_i]
                  end
                end
              else
                #Check mandatory fields for subsequent visits
                obs.each do |key, value|
                  if value.nil? and key != "height" then
                    puts "#{key} for Patient ID: #{row["patient_id"]} is nil"
                  end
                end
              end
            elsif encounter["enc_yr"] - row["yob"] < 30 and encounter["enc_yr"] - row["yob"] >= 14 then
              #Process Patient who are between 14 to 30 years of age
              puts "you are between 14 and 30 because of #{encounter["enc_yr"]} - #{row["yob"]} = #{encounter["enc_yr"] - row["yob"]}"
              if encounter["date"] == rs_enc.first["date"] then
                puts "Checking first Visit Vitals for Patient ID: #{row["patient_id"]}"
                  #Check if mandatory fields have Data on the fist visit
                obs.each do |key,value|
                  if value.nil? and key != "systolic_blood_pressure" and key != "diastolic_blood_pressure" then
                    puts "#{key} for Patient ID: #{row["patient_id"]} is nil"
                    patients_without_mandatory_fields_1st_visit << [row["patient_id"].to_i, encounter["encounter_id"].to_i]
                  end
                end
              else
                #Check mandatory fields for subsequent visits
                obs.each do |key,value|
                  if value.nil? and key != "height" and key != "systolic_blood_pressure" and key != "diastolic_blood_pressure" then
                    puts "#{key} for Patient ID: #{row["patient_id"]} is nil"
                  end
                end
              end
            else
              #Process Patient who are less than 14 years of age
              puts "you are below the 14 because of #{encounter["enc_yr"]} - #{row["yob"]} = #{encounter["enc_yr"] - row["yob"]}"
              #All fields are mandatory for all visits
              obs.each do |key, value|
                if value.nil? and key != "systolic_blood_pressure" and key != "diastolic_blood_pressure" then
                  puts "#{key} for Patient ID: #{row["patient_id"]} is nil"
                end
              end
            end
            #Check if there is a corresponding value in flat_tables
            vitals.each do |key, value|
              if value != obs["#{key}"] then
                writetolog("There is no matching value in Flat table2 for encounter ID #{encounter["encounter_id"]}, #{key} for Patient ID: #{row["patient_id"]}")
                vitals_visits_without_a_match_in_flats << [row["patient_id"].to_i, encounter["encounter_id"].to_i]
              end
            end
          end
        end
      end
    end
  end
  return [patients_without_vitals_obs,
          patients_without_mandatory_fields_1st_visit,
          patients_without_mandatory_fields_1st_visit,
          vitals_visits_without_a_match_in_flats]
end

def check_hiv_reception_completeness(patient_ids)
  dbconnect
  #rs_on_art = querydb("select patient_id from temp_earliest_start_date")
  patient_visits_from_source = ActiveRecord::Base.connection.select_all <<EOF
    SELECT patient_id, DATE(encounter_datetime) AS encounter_datetime FROM encounter
    WHERE encounter_type IN (6, 7, 9, 25, 51, 52, 53, 54, 68, 119)
    AND voided = 0
    AND patient_id IN (#{patient_ids.join(',')})
    GROUP BY patient_id, DATE(encounter_datetime);
EOF

  patient_visits_from_flat_tables = ActiveRecord::Base.connection.select_all <<EOF
    SELECT * FROM flat_table2;
EOF
  visits_in_source = []
  visits_in_flats = []

 (patient_visits_from_source || []).each do |patient|
   visits_in_source << [patient['patient_id'], patient['encounter_datetime']]
 end

 (patient_visits_from_flat_tables || []).each do |patient|
   visits_in_flats << [patient['patient_id'], patient['visit_date']]
 end

  visits_not_in_flats  = visits_in_source - visits_in_flats
  visits_not_in_source = visits_in_flats - visits_in_source
  incomplete_hiv_visit = []

  (patient_ids || []).each do |row|
    puts "Checking completeness of hiv_reception_visit for Patient ID: #{row}"
    rs = querydb("select encounter_id,date(encounter_datetime) date from encounter where encounter_type = 51 and voided = 0 and patient_id = #{row}")
    rs.each do |encounter|
      rs_obs = querydb("select date(obs_datetime) date from obs where encounter_id = #{encounter["encounter_id"]} and voided = 0")
      rs_flat_table2 = querydb("select guardian_present,patient_present from flat_table2 where patient_id = #{row} and visit_date = '#{encounter["date"]}' and not isnull(guardian_present) and not isnull(patient_present)")
      if rs_obs.count != 2 and rs_flat_table2.count != 1 then
        writetolog("Incomplete hiv reception visit for Patient ID: #{row} for visit date: #{encounter["date"]}")
        incomplete_hiv_visit << [row, encounter['date']]
      end
    end
  end

  return [visits_in_source,
          visits_in_flats,
          visits_not_in_flats,
          visits_not_in_source,
          incomplete_hiv_visit]
end

def check_hiv_reception_data_accuracy(patient_ids)
  dbconnect
  guardian_present_not_accurate = []
  patient_present_not_accurate = []

  #rs_on_art = querydb("select patient_id from temp_earliest_start_date")
  (patient_ids || []).each do |row|
    puts "Checking accuracy of hiv reception observations for Patient ID: #{row} "

    #Get all encounters for patient
    rs_enc = querydb("Select date(encounter_datetime) date,encounter_id, year(encounter_datetime) enc_yr from encounter where voided = 0 and patient_id = #{row} and encounter_type = 51 group by date(encounter_datetime) order by encounter_datetime asc")
    (rs_enc || []).each do |encounter|

      rs_obs = querydb("select person_id,concept_id, ifnull(value_text,(select name from concept_name where concept_id = value_coded and concept_name_type = 'FULLY_SPECIFIED')) concept_ans from obs where encounter_id = #{encounter["encounter_id"]} and voided = 0")
      (rs_obs || []).each do |obs|
        #Check for answer
        rs_obs_flat = querydb("Select patient_present, guardian_present from flat_table2 where patient_id = #{row} and visit_date = '#{encounter["date"]}'")
          (rs_obs_flat || []).each do |value|
            #Check if value is matching from source db
            case obs["concept_id"]
            when 2122
              if obs["concept_ans"] != value["guardian_present"] then
                writetolog("Guardian Present for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables ")
                guardian_present_not_accurate << [row, encounter['date']]
              end
            when 1805
              if obs["concept_ans"] != value["patient_present"] then
                writetolog("Patient Present for patient_id = #{row} for visit on #{encounter["date"]} not matching value in flat tables")
                patient_present_not_accurate << [row, encounter['date']]
              end
            end
          end
      end
    end
  end
  return [guardian_present_not_accurate, patient_present_not_accurate]
end

def compare_record_count(patient_ids)
  #Compare record count for flat_table1,flat_cohort_table and earliest start_date View
  dbconnect
  puts "Counting records in flat_table1 ...."
  flat_table1_record_count = []; flat_cohort_table_count = []
  querydb("Select * from flat_table1").each{|p| flat_table1_record_count << p['patient_id'].to_i}
  puts "Counting records in flat_cohort_table ...."
  querydb("Select * from flat_cohort_table").each{|p| flat_cohort_table_count << p['patient_id'].to_i}
  puts "Counting records in temp_earliest_start_date_view ...."

  ids_not_in_source = []; ids_not_in_flat1 = []; ids_not_in_flat_table_cohort = []

  puts "Comparing flat_table1 and flat_cohort_table record count ...."
  #if flat_table1_record_count.count != flat_cohort_table_count.count then
    ids_not_in_flat_table_cohort = flat_table1_record_count - flat_cohort_table_count
    #puts "There is a mismatch in the record count for flat_table1 and flat_cohort_table"
  #else
    #puts "Record count test Passed!"
  #end

  puts "Comparing earliest start_date view and flat_cohort_table record count ...."
  #if flat_table1_record_count.count != patient_ids.count then
  ids_not_in_source = flat_table1_record_count - patient_ids
  #  puts "There is a count difference #{flat_table1_record_count.count} #{patient_ids.count}"
  #end

  ids_not_in_flat1 = patient_ids - flat_table1_record_count
    #puts "Record count test Passed!"
  #end

  return [flat_table1_record_count,
          flat_cohort_table_count,
          patient_ids,
          ids_not_in_source,
          ids_not_in_flat1,
          ids_not_in_flat_table_cohort]
end

def check_demographic_mandatory_fields(patient_ids)
  dbconnect
  rs = querydb("select patient_id,given_name,family_name,dob,gender,date_enrolled from flat_table1")
  rs_not_found = []
  puts "Checking data Accuracy"
  rs.each do |row|
    puts "checking patient_id #{row["patient_id"]}"
       row.each do |key,value|
         #puts value
         if value == nil then
           writetolog("#{key} for patient_id #{row["patient_id"]} is empty")
           rs_not_found << row["patient_id"].to_i
         end
       end
  end
  return [rs_not_found]
end

def check_demographics_accuracy(patient_ids)
  dbconnect
  rs_on_art = [] unless patient_ids.blank?
  rs_demo_not_accurate = []

  rs_on_art.each do |p_id|
    #puts "#{p_id["patient_id"]}"
    rs = querydb("Select pn.person_id ,given_name,family_name,p.birthdate dob,p.gender, earliest_start_date, date_enrolled,age_in_days,age_at_initiation,identifier arv_number FROM person_name pn left JOIN person p on pn.person_id = p.person_id left JOIN temp_earliest_start_date esd on pn.person_id = esd.patient_id LEFT JOIN (Select * from patient_identifier where identifier_type = 4) pi on pn.person_id = pi.patient_id where pn.person_id = #{p_id["patient_id"]}")

    #For each value in the database check if there is a corresponding value in the flat tables
      rs.each do |row|
        puts "Checking demographic data accuracy for Patient ID #{row["person_id"]}"
        rsflat_tables = querydb("Select patient_id person_id, given_name,family_name,dob,gender,earliest_start_date, date_enrolled, age_in_days,age_at_initiation,arv_number from flat_table1 where patient_id = #{p_id["patient_id"]}")
        rsflat_tables.each do |r|
          if rsflat_tables.count == 0 then #Check for presence
              writetolog("Record for Patient id #{r["patient_id"]} is not present in flat_table1")
          end
          #Check if all values are present
          col = rs.fields
          col.each do |column|
            if row["#{column}"].to_s != r["#{column}"].to_s then
              writetolog("#{column} for Patient ID #{row["person_id"]} does not match the one in flat tables")
              rs_demo_not_accurate << row["person_id"].to_i
            end
          end
        end
      end
  end
  return [rs_demo_not_accurate]
end

def check_demographic_uniqueness(patient_ids)
  #Check uniqueness of ARV number
  nonUniqueARV_Numbers = []
  nonUniquePatient_ids = []
  nonUniqueNational_ids = []
  dbconnect
  rs = querydb("select arv_number,count(arv_number) as count from flat_table1 where arv_number <> \"\" group by arv_number")
  rs.each do |row|
      puts "Checking uniquness of ARV number: #{row["arv_number"]}"
      if row["count"] > 1 then
          writetolog("Arv number #{row["arv_number"]} is duplicated #{row["count"]} time(s)")
          nonUniqueARV_Numbers << row["arv_number"]
      end
  end
  #Check uniquness of Patient ID
  rs = querydb("select patient_id,count(patient_id) as count from flat_table1 group by patient_id")
  rs.each do |row|
      puts "Checking uniquness of Patient ID: #{row["patient_id"]}"
      if row["count"] > 1 then
          writetolog("Patient ID: #{row["patient_id"]} is duplicated #{row["count"]} time(s)")
          nonUniquePatient_ids << row["patient_id"].to_i
      end
  end
  #Check uniquness of National ID
  rs = querydb("select nat_id,count(nat_id) as count from flat_table1 group by nat_id")
  rs.each do |row|
      puts "Checking uniquness of National ID: #{row["nat_id"]}"
      if row["count"] > 1 then
          writetolog("Patient ID: #{row["nat_id"]} is duplicated #{row["count"]} time(s)")
          nonUniqueNational_ids << row["nat_id"]
      end
  end
  return [nonUniqueARV_Numbers,
          nonUniquePatient_ids,
          nonUniqueNational_ids]
end

def patient_orders_records_completeness(patient_ids)
  #get all patient_orders records from the source
  patient_orders_records_from_source = ActiveRecord::Base.connection.select_all <<EOF
      SELECT o.patient_id, DATE(e.encounter_datetime) AS encounter_datetime, o.order_id, o.encounter_id, o.start_date, o.auto_expire_date, d.quantity,
      	   d.drug_inventory_id, d.dose, d.frequency, o.concept_id, d.equivalent_daily_dose
      FROM orders o
        INNER JOIN drug_order d ON d.order_id = o.order_id
        INNER JOIN encounter e on e.encounter_id = o.encounter_id
      WHERE o.voided = 0
      AND e.voided = 0 AND e.encounter_type = 25
      GROUP BY DATE(encounter_datetime), e.patient_id;
EOF

  #get all patient_orders records in the flat_tables
  patient_orders_records_from_flat_tables = ActiveRecord::Base.connection.select_all <<EOF
        SELECT patient_id, visit_date, drugs_dispensed, drug_order_id1, drug_encounter_id1, drug_start_date1, drug_auto_expire_date1, drug_inventory_id1, drug_name1, drug_equivalent_daily_dose1, drug_dose1, drug_frequency1, drug_quantity1, drug_order_id2, drug_encounter_id2, drug_start_date2, drug_auto_expire_date2, drug_inventory_id2, drug_name2, drug_equivalent_daily_dose2, drug_dose2, drug_frequency2, drug_quantity2, drug_order_id3, drug_encounter_id3, drug_start_date3, drug_auto_expire_date3, drug_inventory_id3, drug_name3, drug_equivalent_daily_dose3, drug_dose3, drug_frequency3, drug_quantity3, drug_order_id4, drug_encounter_id4, drug_start_date4, drug_auto_expire_date4, drug_inventory_id4, drug_name4, drug_equivalent_daily_dose4, drug_dose4, drug_frequency4, drug_quantity4, drug_order_id5, drug_encounter_id5, drug_start_date5, drug_auto_expire_date5, drug_inventory_id5, drug_name5, drug_equivalent_daily_dose5, drug_dose5, drug_frequency5, drug_quantity5, drug_order_id1_enc_id, drug_encounter_id1_enc_id, drug_start_date1_enc_id, drug_auto_expire_date1_enc_id, drug_inventory_id1_enc_id, drug_name1_enc_id, drug_equivalent_daily_dose1_enc_id, drug_dose1_enc_id, drug_frequency1_enc_id, drug_quantity1_enc_id, drug_order_id2_enc_id, drug_encounter_id2_enc_id, drug_start_date2_enc_id, drug_auto_expire_date2_enc_id, drug_inventory_id2_enc_id, drug_name2_enc_id, drug_equivalent_daily_dose2_enc_id, drug_dose2_enc_id, drug_frequency2_enc_id, drug_quantity2_enc_id, drug_order_id3_enc_id, drug_encounter_id3_enc_id, drug_start_date3_enc_id, drug_auto_expire_date3_enc_id, drug_inventory_id3_enc_id, drug_name3_enc_id, drug_equivalent_daily_dose3_enc_id, drug_dose3_enc_id, drug_frequency3_enc_id, drug_quantity3_enc_id, drug_order_id4_enc_id, drug_encounter_id4_enc_id, drug_start_date4_enc_id, drug_auto_expire_date4_enc_id, drug_inventory_id4_enc_id, drug_name4_enc_id, drug_equivalent_daily_dose4_enc_id, drug_dose4_enc_id, drug_frequency4_enc_id, drug_quantity4_enc_id, drug_order_id5_enc_id, drug_encounter_id5_enc_id, drug_start_date5_enc_id, drug_auto_expire_date5_enc_id, drug_inventory_id5_enc_id, drug_name5_enc_id, drug_equivalent_daily_dose5_enc_id, drug_dose5_enc_id, drug_frequency5_enc_id, drug_quantity5_enc_id
      FROM flat_table2;
EOF

  #get the difference
  patient_orders_source_visits = []
  (patient_orders_records_from_source || []).each do |patient|
    patient_orders_source_visits << [patient['patient_id'].to_i, patient['encounter_datetime']]
  end

  patient_orders_flat_tables_visits = []
  (patient_orders_records_from_flat_tables || []).each do |patient|
    patient_orders_flat_tables_visits << [patient['patient_id'].to_i, patient['visit_date']]
  end

  patient_orders_visits_not_in_source = []
  patient_orders_visits_not_in_flats = []
  patient_orders_visits_not_in_source = patient_orders_flat_tables_visits - patient_orders_source_visits
  patient_orders_visits_not_in_flats = patient_orders_source_visits - patient_orders_flat_tables_visits

  return [patient_orders_records_from_source, patient_orders_flat_tables_visits, patient_orders_visits_not_in_flats, patient_orders_visits_not_in_source]
end

def patient_orders_consistency_and_accuracy_check(patient_orders_source_records)
  patient_orders_obs_source_encounter_ids= []
  (patient_orders_source_records || []).each do |person|
    patient_orders_obs_source_encounter_ids << person['encounter_id'].to_i
  end

  #get the encounters
  patient_orders_obs_source_details_obs_records = ActiveRecord::Base.connection.select_all <<EOF
      SELECT * FROM orders
    WHERE encounter_id IN (#{patient_orders_obs_source_encounter_ids.join(',')});
EOF

  drug_order_id_records = []; drug_encounter_id_records = []; drug_start_date_records = []; drug_auto_expire_date_records = []
  drug_inventory_id_records = []; drug_name_records = []; drug_equivalent_daily_dose_records = []; drug_dose_records = []
  drug_frequency_records = []; drug_quantity_records = []; drug_order_id_records = []

  (patient_orders_obs_source_details_obs_records || []).each do |person|
    patient_orders_per_encounter =  ActiveRecord::Base.connection.select_all <<EOF
      SELECT o.patient_id, DATE(e.encounter_datetime) AS encounter_datetime, o.order_id, o.encounter_id, o.start_date, o.auto_expire_date, d.quantity,
           d.drug_inventory_id, dg.name, d.dose, d.frequency, o.concept_id, d.equivalent_daily_dose
      FROM orders o
        INNER JOIN drug_order d ON d.order_id = o.order_id
        INNER JOIN encounter e on e.encounter_id = o.encounter_id and e.voided = 0 AND e.encounter_type = 25
        INNER JOIN drug dg ON dg.drug_id = d.drug_inventory_id
      WHERE o.voided = 0
      AND e.patient_id = #{person['patient_id'].to_i}
      AND e.encounter_id = #{person['encounter_id'].to_i};
EOF
    #get all patient_orders records in the flat_tables

    (patient_orders_per_encounter || []).each do |order|
      patient_drug_order1 = ActiveRecord::Base.connection.select_all <<EOF
        SELECT patient_id, visit_date, drug_order_id1, drug_encounter_id1, drug_start_date1, drug_auto_expire_date1, drug_inventory_id1, drug_name1, drug_equivalent_daily_dose1, drug_dose1, drug_frequency1, drug_quantity1, drug_order_id1
        FROM flat_table2
        WHERE patient_id = #{order['patient_id'].to_i}
        AND visit_date = '#{order['encounter_datetime']}'
        AND drug_order_id1 = #{order['order_id'].to_i};
EOF

      patient_drug_order2 = ActiveRecord::Base.connection.select_all <<EOF
        SELECT patient_id, visit_date, drug_order_id2, drug_encounter_id2, drug_start_date2, drug_auto_expire_date2, drug_inventory_id2, drug_name2, drug_equivalent_daily_dose2, drug_dose2, drug_frequency2, drug_quantity2, drug_order_id2
        FROM flat_table2
        WHERE patient_id = #{order['patient_id'].to_i}
        AND visit_date = '#{order['encounter_datetime']}'
        AND drug_order_id2 = #{order['order_id'].to_i};
EOF

      patient_drug_order3  = ActiveRecord::Base.connection.select_all <<EOF
        SELECT patient_id, visit_date, drug_order_id3 , drug_encounter_id3 , drug_start_date3 , drug_auto_expire_date3 , drug_inventory_id3 , drug_name3 , drug_equivalent_daily_dose3 , drug_dose3 , drug_frequency3 , drug_quantity3 , drug_order_id3
        FROM flat_table2
        WHERE patient_id = #{order['patient_id'].to_i}
        AND visit_date = '#{order['encounter_datetime']}'
        AND drug_order_id3  = #{order['order_id'].to_i};
EOF

      patient_drug_order4  = ActiveRecord::Base.connection.select_all <<EOF
        SELECT patient_id, visit_date, drug_order_id4 , drug_encounter_id4 , drug_start_date4 , drug_auto_expire_date4 , drug_inventory_id4 , drug_name4 , drug_equivalent_daily_dose4 , drug_dose4 , drug_frequency4 , drug_quantity4 , drug_order_id4
        FROM flat_table2
        WHERE patient_id = #{order['patient_id'].to_i}
        AND visit_date = '#{order['encounter_datetime']}'
        AND drug_order_id4  = #{order['order_id'].to_i};
EOF

      patient_drug_order5  = ActiveRecord::Base.connection.select_all <<EOF
        SELECT patient_id, visit_date, drug_order_id5 , drug_encounter_id5 , drug_start_date5 , drug_auto_expire_date5 , drug_inventory_id5 , drug_name5 , drug_equivalent_daily_dose5 , drug_dose5 , drug_frequency5 , drug_quantity5 , drug_order_id5
        FROM flat_table2
        WHERE patient_id = #{order['patient_id'].to_i}
        AND visit_date = '#{order['encounter_datetime']}'
        AND drug_order_id5  = #{order['order_id'].to_i};
EOF

      unless patient_drug_order1.blank?
        (patient_drug_order1 || []).each do |patient_order|
          if patient_order['drug_order_id1'].to_i == order['order_id'].to_i
            puts "Drug order matched for patient_id: #{order['patient_id'].to_i}"
          else
            drug_order_id_records << order['order_id'].to_i
          end

          if patient_order['drug_encounter_id1'].to_i == order['encounter_id'].to_i
            puts "Drug order matched for patient_id: #{order['patient_id'].to_i}"
          else
            drug_order_id_records << order['order_id'].to_i
          end

          if patient_order['drug_start_date1'] == order['start_date']
            puts "Drug order matched for patient_id: #{order['patient_id'].to_i}"
          else
            drug_order_id_records << order['order_id'].to_i
          end

          if patient_order['drug_auto_expire_date1'] == order['auto_expire_date']
            puts "Drug order matched for patient_id: #{order['patient_id'].to_i}"
          else
            drug_order_id_records << order['order_id'].to_i
          end

          if patient_order['drug_inventory_id1'] == order['drug_inventory_id']
            puts "Drug inventory id matched for patient_id: #{order['patient_id'].to_i}"
          else
            drug_inventory_id_records << order['order_id'].to_i
          end

          if patient_order['drug_name1'] == order['name']
            puts "Drug name matched for patient_id: #{order['patient_id'].to_i}"
          else
            drug_name_records << order['order_id'].to_i
          end

          if patient_order['drug_equivalent_daily_dose1'] == order['equivalent_daily_dose']
            puts "Drug equivalent_daily_dose matched for patient_id: #{order['patient_id'].to_i}"
          else
            drug_equivalent_daily_dose_records << order['order_id'].to_i
          end

          if patient_order['drug_dose1'] == order['dose']
            puts "Drug dose matched for patient_id: #{order['patient_id'].to_i}"
          else
            drug_dose_records << order['order_id'].to_i
          end

          if patient_order['drug_frequency1'] == order['frequency']
            puts "Drug frequency matched for patient_id: #{order['patient_id'].to_i}"
          else
            drug_frequency_records << order['order_id'].to_i
          end

          if patient_order['drug_quantity1'] == order['quantity']
            puts "Drug quantity matched for patient_id: #{order['patient_id'].to_i}"
          else
            drug_quantity_records << order['order_id'].to_i
          end
        end
      end

      unless patient_drug_order2.blank?
        (patient_drug_order2 || []).each do |patient_order|
          if patient_order['drug_order_id2'].to_i == order['order_id'].to_i
            puts "Drug order matched for patient_id: #{order['patient_id'].to_i}"
          else
            drug_order_id_records << order['order_id'].to_i
          end

          if patient_order['drug_encounter_id2'].to_i == order['encounter_id'].to_i
            puts "Drug order matched for patient_id: #{order['patient_id'].to_i}"
          else
            drug_order_id_records << order['order_id'].to_i
          end

          if patient_order['drug_start_date2'] == order['start_date']
            puts "Drug order matched for patient_id: #{order['patient_id'].to_i}"
          else
            drug_order_id_records << order['order_id'].to_i
          end

          if patient_order['drug_auto_expire_date2'] == order['auto_expire_date']
            puts "Drug order matched for patient_id: #{order['patient_id'].to_i}"
          else
            drug_order_id_records << order['order_id'].to_i
          end

          if patient_order['drug_inventory_id2'] == order['drug_inventory_id']
            puts "Drug inventory id matched for patient_id: #{order['patient_id'].to_i}"
          else
            drug_inventory_id_records << order['order_id'].to_i
          end

          if patient_order['drug_name2'] == order['name']
            puts "Drug name matched for patient_id: #{order['patient_id'].to_i}"
          else
            drug_name_records << order['order_id'].to_i
          end

          if patient_order['drug_equivalent_daily_dose2'] == order['equivalent_daily_dose']
            puts "Drug equivalent_daily_dose matched for patient_id: #{order['patient_id'].to_i}"
          else
            drug_equivalent_daily_dose_records << order['order_id'].to_i
          end

          if patient_order['drug_dose2'] == order['dose']
            puts "Drug dose matched for patient_id: #{order['patient_id'].to_i}"
          else
            drug_dose_records << order['order_id'].to_i
          end

          if patient_order['drug_frequency2'] == order['frequency']
            puts "Drug frequency matched for patient_id: #{order['patient_id'].to_i}"
          else
            drug_frequency_records << order['order_id'].to_i
          end

          if patient_order['drug_quantity2'] == order['quantity']
            puts "Drug quantity matched for patient_id: #{order['patient_id'].to_i}"
          else
            drug_quantity_records << order['order_id'].to_i
          end
        end
      end

      unless patient_drug_order3.blank?
        (patient_drug_order3 || []).each do |patient_order|
          if patient_order['drug_order_id3'].to_i == order['order_id'].to_i
            puts "Drug order matched for patient_id: #{order['patient_id'].to_i}"
          else
            drug_order_id_records << order['order_id'].to_i
          end

          if patient_order['drug_encounter_id3'].to_i == order['encounter_id'].to_i
            puts "Drug order matched for patient_id: #{order['patient_id'].to_i}"
          else
            drug_order_id_records << order['order_id'].to_i
          end

          if patient_order['drug_start_date3'] == order['start_date']
            puts "Drug order matched for patient_id: #{order['patient_id'].to_i}"
          else
            drug_order_id_records << order['order_id'].to_i
          end

          if patient_order['drug_auto_expire_date3'] == order['auto_expire_date']
            puts "Drug order matched for patient_id: #{order['patient_id'].to_i}"
          else
            drug_order_id_records << order['order_id'].to_i
          end

          if patient_order['drug_inventory_id3'] == order['drug_inventory_id']
            puts "Drug inventory id matched for patient_id: #{order['patient_id'].to_i}"
          else
            drug_inventory_id_records << order['order_id'].to_i
          end

          if patient_order['drug_name3'] == order['name']
            puts "Drug name matched for patient_id: #{order['patient_id'].to_i}"
          else
            drug_name_records << order['order_id'].to_i
          end

          if patient_order['drug_equivalent_daily_dose3'] == order['equivalent_daily_dose']
            puts "Drug equivalent_daily_dose matched for patient_id: #{order['patient_id'].to_i}"
          else
            drug_equivalent_daily_dose_records << order['order_id'].to_i
          end

          if patient_order['drug_dose3'] == order['dose']
            puts "Drug dose matched for patient_id: #{order['patient_id'].to_i}"
          else
            drug_dose_records << order['order_id'].to_i
          end

          if patient_order['drug_frequency3'] == order['frequency']
            puts "Drug frequency matched for patient_id: #{order['patient_id'].to_i}"
          else
            drug_frequency_records << order['order_id'].to_i
          end

          if patient_order['drug_quantity3'] == order['quantity']
            puts "Drug quantity matched for patient_id: #{order['patient_id'].to_i}"
          else
            drug_quantity_records << order['order_id'].to_i
          end
        end
      end

      unless patient_drug_order4.blank?
        (patient_drug_order4 || []).each do |patient_order|
          if patient_order['drug_order_id4'].to_i == order['order_id'].to_i
            puts "Drug order matched for patient_id: #{order['patient_id'].to_i}"
          else
            drug_order_id_records << order['order_id'].to_i
          end

          if patient_order['drug_encounter_id4'].to_i == order['encounter_id'].to_i
            puts "Drug order matched for patient_id: #{order['patient_id'].to_i}"
          else
            drug_order_id_records << order['order_id'].to_i
          end

          if patient_order['drug_start_date4'] == order['start_date']
            puts "Drug order matched for patient_id: #{order['patient_id'].to_i}"
          else
            drug_order_id_records << order['order_id'].to_i
          end

          if patient_order['drug_auto_expire_date4'] == order['auto_expire_date']
            puts "Drug order matched for patient_id: #{order['patient_id'].to_i}"
          else
            drug_order_id_records << order['order_id'].to_i
          end

          if patient_order['drug_inventory_id4'] == order['drug_inventory_id']
            puts "Drug inventory id matched for patient_id: #{order['patient_id'].to_i}"
          else
            drug_inventory_id_records << order['order_id'].to_i
          end

          if patient_order['drug_name4'] == order['name']
            puts "Drug name matched for patient_id: #{order['patient_id'].to_i}"
          else
            drug_name_records << order['order_id'].to_i
          end

          if patient_order['drug_equivalent_daily_dose4'] == order['equivalent_daily_dose']
            puts "Drug equivalent_daily_dose matched for patient_id: #{order['patient_id'].to_i}"
          else
            drug_equivalent_daily_dose_records << order['order_id'].to_i
          end

          if patient_order['drug_dose4'] == order['dose']
            puts "Drug dose matched for patient_id: #{order['patient_id'].to_i}"
          else
            drug_dose_records << order['order_id'].to_i
          end

          if patient_order['drug_frequency4'] == order['frequency']
            puts "Drug frequency matched for patient_id: #{order['patient_id'].to_i}"
          else
            drug_frequency_records << order['order_id'].to_i
          end

          if patient_order['drug_quantity4'] == order['quantity']
            puts "Drug quantity matched for patient_id: #{order['patient_id'].to_i}"
          else
            drug_quantity_records << order['order_id'].to_i
          end
        end
      end

      unless patient_drug_order5.blank?
        (patient_drug_order5 || []).each do |patient_order|
          if patient_order['drug_order_id5'].to_i == order['order_id'].to_i
            puts "Drug order matched for patient_id: #{order['patient_id'].to_i}"
          else
            drug_order_id_records << order['order_id'].to_i
          end

          if patient_order['drug_encounter_id5'].to_i == order['encounter_id'].to_i
            puts "Drug order matched for patient_id: #{order['patient_id'].to_i}"
          else
            drug_order_id_records << order['order_id'].to_i
          end

          if patient_order['drug_start_date5'] == order['start_date']
            puts "Drug order matched for patient_id: #{order['patient_id'].to_i}"
          else
            drug_order_id_records << order['order_id'].to_i
          end

          if patient_order['drug_auto_expire_date5'] == order['auto_expire_date']
            puts "Drug order matched for patient_id: #{order['patient_id'].to_i}"
          else
            drug_order_id_records << order['order_id'].to_i
          end

          if patient_order['drug_inventory_id5'] == order['drug_inventory_id']
            puts "Drug inventory id matched for patient_id: #{order['patient_id'].to_i}"
          else
            drug_inventory_id_records << order['order_id'].to_i
          end

          if patient_order['drug_name5'] == order['name']
            puts "Drug name matched for patient_id: #{order['patient_id'].to_i}"
          else
            drug_name_records << order['order_id'].to_i
          end

          if patient_order['drug_equivalent_daily_dose5'] == order['equivalent_daily_dose']
            puts "Drug equivalent_daily_dose matched for patient_id: #{order['patient_id'].to_i}"
          else
            drug_equivalent_daily_dose_records << order['order_id'].to_i
          end

          if patient_order['drug_dose5'] == order['dose']
            puts "Drug dose matched for patient_id: #{order['patient_id'].to_i}"
          else
            drug_dose_records << order['order_id'].to_i
          end

          if patient_order['drug_frequency5'] == order['frequency']
            puts "Drug frequency matched for patient_id: #{order['patient_id'].to_i}"
          else
            drug_frequency_records << order['order_id'].to_i
          end

          if patient_order['drug_quantity5'] == order['quantity']
            puts "Drug quantity matched for patient_id: #{order['patient_id'].to_i}"
          else
            drug_quantity_records << order['order_id'].to_i
          end
        end
      end
    end
  end
  return [drug_order_id_records,
          drug_encounter_id_records,
          drug_start_date_records,
          drug_auto_expire_date_records,
          drug_inventory_id_records,
          drug_name_records,
          drug_equivalent_daily_dose_records,
          drug_dose_records,
          drug_frequency_records,
          drug_quantity_records,
          drug_order_id_records]
end

def patient_outcome_records_completeness(patient_ids)
  #get all patient_outcome records from the source
  patient_outcome_records_from_source = ActiveRecord::Base.connection.select_all <<EOF
    SELECT patient_id, DATE(encounter_datetime) AS encounter_datetime FROM encounter
    WHERE encounter_type IN (6, 7, 9, 25, 51, 52, 53, 54, 68, 119)
    AND voided = 0
    AND patient_id IN (#{patient_ids.join(',')})
    GROUP BY patient_id, DATE(encounter_datetime);
EOF

  #get all patient_outcome records in the flat_tables
  patient_outcome_records_from_flat_tables = ActiveRecord::Base.connection.select_all <<EOF
    SELECT patient_id, visit_date, current_hiv_program_state, current_hiv_program_start_date
    FROM flat_table2
    GROUP BY patient_id, visit_date
    ORDER BY patient_id, visit_date;
EOF

  #get the difference
  patient_outcome_source_visits = []
  (patient_outcome_records_from_source || []).each do |patient|
    patient_outcome_source_visits << [patient['patient_id'].to_i, patient['encounter_datetime']]
  end

  patient_outcome_flat_tables_visits = []
  (patient_outcome_records_from_flat_tables || []).each do |patient|
    patient_outcome_flat_tables_visits << [patient['patient_id'].to_i, patient['visit_date']]
  end

  patient_outcome_visits_not_in_source = []
  patient_outcome_visits_not_in_flats = []
  patient_outcome_visits_not_in_source = patient_outcome_flat_tables_visits - patient_outcome_source_visits
  patient_outcome_visits_not_in_flats = patient_outcome_source_visits - patient_outcome_flat_tables_visits

  return [patient_outcome_records_from_source, patient_outcome_flat_tables_visits, patient_outcome_visits_not_in_flats, patient_outcome_visits_not_in_source]
end

def patient_outcome_consistency_and_accuracy_check(patient_outcome_source_records)
  current_hiv_program_state_records = []; current_hiv_program_start_date_records = []
  patient_outcome_obs_not_in_any_category = []

  (patient_outcome_source_records || []).each do |person|
    #get all patient_outcome records in the flat_tables
    answer = ""
    person_id = person['patient_id'].to_i
    source_visit_date = person['encounter_datetime'].to_date.strftime("%Y-%m-%d")
    patient_state =  ActiveRecord::Base.connection.select_one <<EOF
      SELECT patient_outcome(#{person_id}, '#{source_visit_date}') AS outcome;
EOF
    patient_outcome = patient_state['outcome']

    patient_outcome_patient_record_from_flat_tables = ActiveRecord::Base.connection.select_all <<EOF
        SELECT patient_id, visit_date, current_hiv_program_state, current_hiv_program_start_date
        FROM flat_table2
        WHERE patient_id = #{person_id}
        AND visit_date = '#{source_visit_date}';
EOF
=begin
      2559 #"ARV regimens received abstracted construct"
      8375 #"Regimen Category"
=end

    (patient_outcome_patient_record_from_flat_tables || []).each do |field|
        if field['current_hiv_program_state'].to_s == patient_outcome.to_s
          puts "Patient Outcome matched for patient_id: #{person_id}"
        else
          current_hiv_program_state_records << [person_id, source_visit_date]
        end

        if field['current_hiv_program_start_date'] == source_visit_date
          puts "Current HIV program start date matched for patient_id: #{person_id}"
        else
          current_hiv_program_start_date_records << [person_id, source_visit_date]
        end
    end
  end
  return [current_hiv_program_state_records, current_hiv_program_start_date_records]
end

def treatment_records_completeness(patient_ids)
  #get all treatment records from the source
  treatment_records_from_source = ActiveRecord::Base.connection.select_all <<EOF
        SELECT e.patient_id, e.encounter_id, DATE(e.encounter_datetime) as encounter_datetime FROM encounter e
          INNER JOIN obs o ON o.encounter_id = e.encounter_id
          INNER JOIN orders ord on ord.encounter_id = e.encounter_id
        WHERE e.encounter_type = 25
        AND e.patient_id IN (#{patient_ids.join(',')})
        AND e.voided = 0  and o.voided = 0 AND ord.voided = 0
        GROUP BY e.encounter_id, DATE(e.encounter_datetime)
        ORDER BY e.patient_id, DATE(e.encounter_datetime);
EOF

  #get all treatment records in the flat_tables
  treatment_records_from_flat_tables = ActiveRecord::Base.connection.select_all <<EOF
      SELECT patient_id, visit_date, ipt_given, ipt_given_enc_id, cpt_given,
          cpt_given_enc_id, condoms_given, condoms_given_enc_id, regimen_category_treatment,
          regimen_category_treatment_enc_id, type_of_ARV_regimen_given, type_of_ARV_regimen_given_enc_id
      FROM flat_table2
      GROUP BY patient_id, visit_date;
EOF

  #get the difference
  treatment_source_visits = []
  (treatment_records_from_source || []).each do |patient|
    treatment_source_visits << [patient['patient_id'].to_i, patient['encounter_datetime']]
  end

  treatment_flat_tables_visits = []
  (treatment_records_from_flat_tables || []).each do |patient|
    treatment_flat_tables_visits << [patient['patient_id'].to_i, patient['visit_date']]
  end

  treatment_visits_not_in_source = []
  treatment_visits_not_in_flats = []
  treatment_visits_not_in_source = treatment_flat_tables_visits - treatment_source_visits
  treatment_visits_not_in_flats = treatment_source_visits - treatment_flat_tables_visits

  return [treatment_records_from_source, treatment_flat_tables_visits, treatment_visits_not_in_flats, treatment_visits_not_in_source]
end

def treatment_consistency_and_accuracy_check(treatment_source_records)
  treatment_obs_source_encounter_ids= []
  (treatment_source_records || []).each do |person|
    treatment_obs_source_encounter_ids << person['encounter_id'].to_i
  end

  #get the encounters
  treatment_obs_source_details_obs_records = ActiveRecord::Base.connection.select_all <<EOF
      SELECT * FROM obs
    WHERE encounter_id IN (#{treatment_obs_source_encounter_ids.join(',')});
EOF

  ipt_given_records = []; cpt_given_records = []; condoms_given_records = []
  regimen_category_treatment_records = []; type_of_ARV_regimen_given_records = []
  treatment_obs_not_in_any_category = []

  (treatment_obs_source_details_obs_records || []).each do |person|
    #get all treatment records in the flat_tables
    answer = ""
    person_id = person['person_id'].to_i
    source_visit_date = person['obs_datetime'].to_date.strftime('%Y-%m-%d')
    field_name = person['concept_id'].to_i

    answer = ""
    if !person['value_coded'].blank?
      answer = ConceptName.find_by_concept_id(person['value_coded'].to_i).name
    elsif !person['value_text'].blank?
      answer = person['value_text']
    elsif !person['value_datetime'].blank?
      answer = person['value_datetime'].to_date.strftime("%Y-%m-%d")
    elsif !person['value_numeric'].blank?
      answer = person['value_numeric'].to_i
    end

    treatment_patient_record_from_flat_tables = ActiveRecord::Base.connection.select_all <<EOF
        SELECT patient_id, visit_date, ipt_given, ipt_given_enc_id, cpt_given,
            cpt_given_enc_id, condoms_given, condoms_given_enc_id, regimen_category_treatment,
            regimen_category_treatment_enc_id, type_of_ARV_regimen_given, type_of_ARV_regimen_given_enc_id
        FROM flat_table2
        WHERE patient_id = #{person_id}
        AND visit_date = '#{source_visit_date}';
EOF
=begin
      190,Condoms
      656,Isoniazid
      6882,"What type of antiretroviral regimen
      7024,"Cotrimoxazole prophylaxis treatment started"
      8375,"Regimen Category"
=end

    (treatment_patient_record_from_flat_tables || []).each do |field|
      case field_name
      when 190 #Condoms
        if field['condoms_given'] == answer
          puts "Condoms given matched for patient_id: #{person_id}"
        else
          condoms_given_records << [person_id, source_visit_date]
        end
      when 656 #Isoniazid
        if field['condoms_given'] == answer
          puts "Condoms given matched for patient_id: #{person_id}"
        else
          condoms_given_records << [person_id, source_visit_date]
        end
      when 6882 #What type of antiretroviral regimen
        if field['type_of_ARV_regimen_given'] == answer
          puts "Type of regimen category given matched for patient_id: #{person_id}"
        else
          type_of_ARV_regimen_given_records << [person_id, source_visit_date]
        end
      when 7024 #Cotrimoxazole prophylaxis treatment started
        if field['cpt_given'] == answer
          puts "CPT given matched for patient_id: #{person_id}"
        else
          cpt_given_records << [person_id, source_visit_date]
        end
      when 8375 #Regimen Category"
        if field['regimen_category_treatment'] == answer
          puts "Regimen Category matched for patient_id: #{person_id}"
        else
          regimen_category_treatment_records << [person_id, source_visit_date]
        end
      else
        treatment_obs_not_in_any_category << [field_name]
      end
    end
  end
  treatment_obs_not_in_any_category.uniq! unless treatment_obs_not_in_any_category.blank?
  return [ipt_given_records, cpt_given_records, condoms_given_records, regimen_category_treatment_records, type_of_ARV_regimen_given_records,treatment_obs_not_in_any_category]
end

def dispensing_records_completeness(patient_ids)
  #get all dispensing records from the source
  dispensing_records_from_source = ActiveRecord::Base.connection.select_all <<EOF
      SELECT e.patient_id, e.encounter_id, DATE(e.encounter_datetime) as encounter_datetime FROM encounter e
        INNER JOIN obs o ON o.encounter_id = e.encounter_id
      WHERE e.encounter_type = 54
      AND e.patient_id IN (#{patient_ids.join(',')})
      AND e.voided = 0  and o.voided = 0
      GROUP BY e.encounter_id, DATE(e.encounter_datetime)
      ORDER BY e.patient_id, DATE(e.encounter_datetime);
EOF

  #get all di records in the flat_tables
  dispensing_records_from_flat_tables = ActiveRecord::Base.connection.select_all <<EOF
    SELECT patient_id, visit_date, regimen_category_dispensed, regimen_category_enc_id, arv_regimens_received_construct, arv_regimens_received_construct_enc_id
    FROM flat_table2
    GROUP BY patient_id, visit_date;
EOF

  #get the difference
  dispensing_source_visits = []
  (dispensing_records_from_source || []).each do |patient|
    dispensing_source_visits << [patient['patient_id'].to_i, patient['encounter_datetime']]
  end

  dispensing_flat_tables_visits = []
  (dispensing_records_from_flat_tables || []).each do |patient|
    dispensing_flat_tables_visits << [patient['patient_id'].to_i, patient['visit_date']]
  end

  dispensing_visits_not_in_source = []
  dispensing_visits_not_in_flats = []
  dispensing_visits_not_in_source = dispensing_flat_tables_visits - dispensing_source_visits
  dispensing_visits_not_in_flats = dispensing_source_visits - dispensing_flat_tables_visits

  return [dispensing_records_from_source, dispensing_flat_tables_visits, dispensing_visits_not_in_flats, dispensing_visits_not_in_source]
end

def dispensing_consistency_and_accuracy_check(dispensing_source_records)
  dispensing_obs_source_encounter_ids= []
  (dispensing_source_records || []).each do |person|
    dispensing_obs_source_encounter_ids << person['encounter_id'].to_i
  end

  #get the encounters
  dispensing_obs_source_details_obs_records = ActiveRecord::Base.connection.select_all <<EOF
      SELECT * FROM obs
    WHERE encounter_id IN (#{dispensing_obs_source_encounter_ids.join(',')});
EOF

  regimen_category_dispensed_records = []; arv_regimens_received_construct_records = []
  dispensing_obs_not_in_any_category = []

  (dispensing_obs_source_details_obs_records || []).each do |person|
    #get all dispensing records in the flat_tables
    answer = ""
    person_id = person['person_id'].to_i
    source_visit_date = person['obs_datetime'].to_date.strftime('%Y-%m-%d')
    field_name = person['concept_id'].to_i

    answer = ""
    if !person['value_coded'].blank?
      answer = ConceptName.find_by_concept_id(person['value_coded'].to_i).name
    elsif !person['value_text'].blank?
      answer = person['value_text']
    elsif !person['value_datetime'].blank?
      answer = person['value_datetime'].to_date.strftime("%Y-%m-%d")
    elsif !person['value_numeric'].blank?
      answer = person['value_numeric'].to_i
    end

    dispensing_patient_record_from_flat_tables = ActiveRecord::Base.connection.select_all <<EOF
        SELECT patient_id, visit_date, regimen_category_dispensed, regimen_category_enc_id, arv_regimens_received_construct, arv_regimens_received_construct_enc_id
        FROM flat_table2
        WHERE patient_id = #{person_id}
        AND visit_date = '#{source_visit_date}';
EOF
=begin
      2559 #"ARV regimens received abstracted construct"
      8375 #"Regimen Category"
=end

    (dispensing_patient_record_from_flat_tables || []).each do |field|
      case field_name
      when 2559 #ARV regimens received abstracted construct
        if field['arv_regimens_received_construct'] == answer
          puts "ARV regimens received abstracted construct given matched for patient_id: #{person_id}"
        else
          arv_regimens_received_construct_records << [person_id, source_visit_date]
        end
      when 8375 #Regimen Category
        if field['regimen_category_dispensed'] == answer
          puts "Regimen Category given matched for patient_id: #{person_id}"
        else
          regimen_category_dispensed_records << [person_id, source_visit_date]
        end
      else
        dispensing_obs_not_in_any_category << [field_name]
      end
    end
  end
  dispensing_obs_not_in_any_category.uniq! unless dispensing_obs_not_in_any_category.blank?
  return [arv_regimens_received_construct_records, regimen_category_dispensed_records, dispensing_obs_not_in_any_category]
end

def hiv_registration_records_completeness(eligible_patients_ids)
  #get all hiv_registration fields
  hiv_registration_records = []
  hiv_registration_records = ActiveRecord::Base.connection.select_all <<EOF
      SELECT
          patient_id, ever_received_art, date_art_last_taken, date_art_last_taken_v_date,
          taken_art_in_last_two_months, taken_art_in_last_two_months_v_date,
          taken_art_in_last_two_weeks, taken_art_in_last_two_months_v_date,
          last_art_drugs_taken, ever_registered_at_art_clinic,
          ever_registered_at_art_v_date, has_transfer_letter, location_of_art_initialization,
      	  art_start_date_estimation, date_started_art, send_sms, agrees_to_followup,
          type_of_confirmatory_hiv_test, confirmatory_hiv_test_location, confirmatory_hiv_test_date
      FROM
          flat_table1
      WHERE patient_id IN (#{eligible_patients_ids.join(',')});
EOF

  transfer_ins = []; transfer_ins_with_all_fields = []; transfer_ins_without_all_fields = []
  first_timers = []; hiv_clinic_reg_patient_ids = []; unknown_ever_reg = []

=begin
    mandatory fields for first_timers
    ----------------------------------------------------------------------------
    agrees_to_followup; confirmatory_hiv_test_location; type_of_confirmatory_hiv_test;
    confirmatory_hiv_test_date; ever_received_art; send_sms


    mandatory fields for transfer_ins
    ----------------------------------------------------------------------------
    date_art_last_taken; ever_registered_at_art_clinic; last_art_drugs_taken
    has_transfer_letter; date_started_art; type_of_confirmatory_hiv_test
    agrees_to_followup; confirmatory_hiv_test_location; location_of_art_initialization;
    confirmatory_hiv_test_date
=end

  #get all the mandatory fields
  (hiv_registration_records || []).each do |patient|
    hiv_clinic_reg_patient_ids << patient['patient_id'].to_i
    if patient['ever_received_art'] == 'Yes'
        transfer_ins << patient['patient_id'].to_i
      #check if all mandatory fields are filled
      unless patient['confirmatory_hiv_test_date'].blank? || patient['date_art_last_taken'].blank? || patient['location_of_art_initialization'].blank? || patient['ever_registered_at_art_clinic'].blank? || patient['last_art_drugs_taken'].blank? || patient['has_transfer_letter'].blank? || patient['date_started_art'].blank? || patient['type_of_confirmatory_hiv_test'].blank? || patient['agrees_to_followup'].blank? || patient['confirmatory_hiv_test_location'].blank?
        transfer_ins_with_all_fields << patient['patient_id'].to_i
      else
        transfer_ins_without_all_fields << patient['patient_id'].to_i
      end
    elsif patient['ever_received_art'] == 'No'
      first_timers << patient['patient_id'].to_i
    else
      unknown_ever_reg << patient['patient_id'].to_i
    end
  end
  return [hiv_clinic_reg_patient_ids, transfer_ins, transfer_ins_with_all_fields,
          transfer_ins_without_all_fields, first_timers, unknown_ever_reg]
end

def hiv_registration_records_consistency(patient_ids)
  puts "Working HIV clinic Registration consistency check"
  #get the encounters
  hiv_registration_obs_records = ActiveRecord::Base.connection.select_all <<EOF
      SELECT enc.* FROM encounter enc
    WHERE enc.encounter_type = 9
    AND enc.patient_id IN (#{patient_ids.join(',')})
    AND enc.encounter_id IN (SELECT max(e.encounter_id) FROM encounter e
     						 WHERE e.encounter_id = enc.encounter_id
    						 AND e.encounter_type = enc.encounter_type
                             AND e.patient_id = enc.patient_id
    						 AND e.voided = 0)
    AND enc.voided = 0
    GROUP BY enc.patient_id;
EOF

  ever_received_art_records = []; date_art_last_taken_records = []
  taken_art_in_last_two_months_records = []; taken_art_in_last_two_weeks_records = []
  last_art_drugs_taken_records = []; ever_registered_at_art_clinic_records = []
  has_transfer_letter_records = []; location_of_art_initialization_records = []
  art_start_date_estimation_records = []; date_started_art_records = []
  send_sms_records = []; agrees_to_followup_records = []; type_of_confirmatory_hiv_test_records = []
  confirmatory_hiv_test_location_records = []; confirmatory_hiv_test_date_records = []
  patients_without_hiv_clinic_reg_records = []

  (hiv_registration_obs_records || []).each do |obs|
    patient_hiv_registration_obs_records = ActiveRecord::Base.connection.select_all <<EOF
    SELECT * FROM obs WHERE person_id = #{obs['patient_id'].to_i}
    AND encounter_id = #{obs['encounter_id'].to_i};
EOF

    (patient_hiv_registration_obs_records || []).each do  |person|
      #call flat_table1_fields
      person_id = person['person_id'].to_i
      visit_date = person['obs_datetime']
      field_name = person['concept_id'].to_i

      answer = ""
      if !person['value_coded'].blank?
        answer = ConceptName.find_by_concept_id(person['value_coded'].to_i).name
      elsif !person['value_text'].blank?
        answer = person['value_text']
      elsif !person['value_datetime'].blank?
        answer = person['value_datetime'].to_date.strftime("%Y-%m-%d")
      elsif !person['value_numeric'].blank?
        answer = person['value_numeric'].to_i
      end

      flat_table_person_data = ActiveRecord::Base.connection.select_all <<EOF
        SELECT
            patient_id, ever_received_art, date_art_last_taken, date_art_last_taken_v_date,
            taken_art_in_last_two_months, taken_art_in_last_two_months_v_date,
            taken_art_in_last_two_weeks, taken_art_in_last_two_months_v_date,
            last_art_drugs_taken, ever_registered_at_art_clinic,
            ever_registered_at_art_v_date, has_transfer_letter, location_of_art_initialization,
            art_start_date_estimation, date_started_art, send_sms, agrees_to_followup,
            type_of_confirmatory_hiv_test, confirmatory_hiv_test_location, confirmatory_hiv_test_date
        FROM
            flat_table1
        WHERE patient_id = #{person_id};
EOF

      (flat_table_person_data || []).each do |field|
        case field_name
        when 7754 #"Ever received ART?"
          if field['ever_received_art'] == answer
            puts "Ever received ART matched for patient_id: #{person_id}"
          else
            ever_received_art_records << person_id
          end
        when 2552 #"Follow up agreement"
          if field['agrees_to_followup'] == answer
            puts "Agrees to followup records matched for patient_id: #{person_id}"
          else
            agrees_to_followup_records << person_id
          end
        when 8011 #"SEND SMS"
          if field['send_sms'] == answer
            puts "Send SMS matched for patient_id: #{person_id}"
          else
            send_sms_records << person_id
          end
        when 7880 #"Confirmatory HIV test type"
          if field['type_of_confirmatory_hiv_test']  == answer
            puts "Type of Confirmatory HIV test matched for patient_id: #{person_id}"
          else
            type_of_confirmatory_hiv_test_records << person_id
          end
        when 7881 #"Confirmatory HIV test location"
          if field['confirmatory_hiv_test_location'] == answer
            puts "Confirmatory HIT test location matched for patient_id: #{person_id}"
          else
            confirmatory_hiv_test_location_records << person_id
          end
        when 7882 #"Confirmatory HIV test date"
          if field['confirmatory_hiv_test_date'] == answer
            puts "Confirmatory HIV test date matched for patient_id: #{person_id}"
          else
            confirmatory_hiv_test_date_records << person_id
          end
        when 2516 #"Date antiretrovirals started"
          if field['date_started_art'] == answer
            puts "Date ART started matched for patient_id: #{person_id}"
          else
            date_started_art_records << person_id
          end
        when 6393 #"Has transfer letter"
          if field['has_transfer_letter'] == answer
            puts "Has transfer letter matched for patient_id: #{person_id}"
          else
            has_transfer_letter_records << person_id
          end
        when 6394 #"Has the patient taken ART in the last two weeks"
          if field['taken_art_in_last_two_weeks'] == answer
            puts "Taken ART in the last two weeks matched for patient_id: #{person_id}"
          else
            taken_art_in_last_two_weeks_records << person_id
          end
=begin
        when 6981 #"ART number at previous location"
          if field['taken_art_in_last_two_weeks'] == answer
            puts 'its_ok"
          else
            puts 'not ok'
          end
=end
        when 7750 #"Location of ART initiation"
          if field[ 'location_of_art_initialization'] == answer
            puts "Location of ART initialization matched for patient_id: #{person_id}"
          else
            location_of_art_initialization_records << person_id
          end
        when 7751 #"Date ART last taken"
          if field['date_art_last_taken'] == answer
            puts "Date ART last taken matched for patient_id: #{person_id}"
          else
            date_art_last_taken_records << person_id
          end
        when 7752 #"Has the patient taken ART in the last two months"
          if field['taken_art_in_last_two_months'] == answer
            puts "Taken ART in the last two months matched for patient_id: #{person_id}"
          else
            taken_art_in_last_two_months_records << person_id
          end
        when 7753 #"Last antiretroviral drugs taken"
          if field['last_art_drugs_taken'] == answer
            puts "Last ART drugs taken matched for patient_id: #{person_id}"
          else
            last_art_drugs_taken_records << person_id
          end
        when 7937 #"Ever registered at ART clinic"
          if field['ever_registered_at_art_clinic'] == answer
            puts "Ever registered at ART clinic matched for patient_id: #{person_id}"
          else
            ever_registered_at_art_clinic_records << person_id
          end
        else
          patients_without_hiv_clinic_reg_records << person_id
        end
      end
    end
  end
  patients_without_hiv_clinic_reg_records.uniq! unless patients_without_hiv_clinic_reg_records.blank?

  return [ever_received_art_records,
      agrees_to_followup_records,
      send_sms_records,
      type_of_confirmatory_hiv_test_records,
      confirmatory_hiv_test_location_records,
      confirmatory_hiv_test_date_records,
      date_started_art_records,
      has_transfer_letter_records,
      taken_art_in_last_two_weeks_records,
      location_of_art_initialization_records,
      date_art_last_taken_records,
      taken_art_in_last_two_months_records,
      last_art_drugs_taken_records,
      ever_registered_at_art_clinic_records,
      patients_without_hiv_clinic_reg_records]
end

start
