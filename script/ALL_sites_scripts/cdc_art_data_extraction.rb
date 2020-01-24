require 'fastercsv'

Source_db = YAML.load(File.open(File.join(RAILS_ROOT, "config/database.yml"), "r"))['production']["database"]
CDCDataExtraction = 1

def start
  facility_name = GlobalProperty.find_by_sql("select property_value from global_property where property = 'current_health_center_name'").map(&:property_value).first

  start_date = "2017-01-01".to_date
  end_date = "2017-03-31".to_date

  puts "CDC ART data extraction............................................................................................"

  puts "New on ART (Newly registered)......................................................................................"
  total_new_on_art, new_on_art_less_1, new_on_art_between_1_and_9, new_on_art_btwn_10_14_female, new_on_art_btwn_10_14_male, new_on_art_less_15_19_female, new_on_art_less_15_19_male, new_on_art_less_20_24_female, new_on_art_less_20_24_male, new_on_art_less_25_49_female, new_on_art_less_25_49_male, new_on_art_less_more_than_50_female, new_on_art_less_more_than_50_male, new_on_art_less_15_female, new_on_art_less_15_male, new_on_art_more_15_female,  new_on_art_more_15_male = new_on_art(start_date, end_date, nil, nil)

  puts "Receving ART (Total registered- Cumulative)........................................................................................."
  total_receiving_art_cumulative, receiving_art_cumulative_less_1, receiving_art_cumulative_between_1_and_9, receiving_art_cumulative_btwn_10_14_female, receiving_art_cumulative_btwn_10_14_male, receiving_art_cumulative_less_15_19_female, receiving_art_cumulative_less_15_19_male, receiving_art_cumulative_less_20_24_female, receiving_art_cumulative_less_20_24_male, receiving_art_cumulative_less_25_49_female, receiving_art_cumulative_less_25_49_male, receiving_art_cumulative_less_more_than_50_female, receiving_art_cumulative_less_more_than_50_male, receiving_art_cumulative_less_15_female, receiving_art_cumulative_less_15_male, receiving_art_cumulative_more_15_female,  receiving_art_cumulative_more_15_male = receiving_art_cumulative(start_date, end_date, nil, nil)

  puts "PLHIV with screened TB status positive............................................................................."
  total_plhiv_screened_tb_status, plhiv_screened_tb_status_less_15_female, plhiv_screened_tb_status_less_15_male, plhiv_screened_tb_status_more_15_female, plhiv_screened_tb_status_more_15_male = plhiv_screened_tb_status(start_date, end_date, nil, nil)

  puts "Total alive and on ARVS at 12 months after initiation.............................................."
  total_alive_and_on_ARVS_at_12_months_after_initiation, alive_and_on_ARVS_at_12_months_after_initiation_less_1, alive_and_on_ARVS_at_12_months_after_initiation_between_1_and_9, alive_and_on_ARVS_at_12_months_after_initiation_btwn_10_14_female, alive_and_on_ARVS_at_12_months_after_initiation_btwn_10_14_male, alive_and_on_ARVS_at_12_months_after_initiation_less_15_19_female, alive_and_on_ARVS_at_12_months_after_initiation_less_15_19_male, alive_and_on_ARVS_at_12_months_after_initiation_less_20_24_female, alive_and_on_ARVS_at_12_months_after_initiation_less_20_24_male, alive_and_on_ARVS_at_12_months_after_initiation_less_25_49_female, alive_and_on_ARVS_at_12_months_after_initiation_less_25_49_male, alive_and_on_ARVS_at_12_months_after_initiation_less_more_than_50_female, alive_and_on_ARVS_at_12_months_after_initiation_less_more_than_50_male, alive_and_on_ARVS_at_12_months_after_initiation_less_15_female, alive_and_on_ARVS_at_12_months_after_initiation_less_15_male, alive_and_on_ARVS_at_12_months_after_initiation_more_15_female, alive_and_on_ARVS_at_12_months_after_initiation_more_15_male = alive_and_on_ARVS_at_12_months_after_initiation(start_date, end_date, nil, nil)

  puts "Total initiated in 12 months........................................................................."
  total_total_initiated_in_12_months, total_initiated_in_12_months_less_1, total_initiated_in_12_months_between_1_and_9, total_initiated_in_12_months_btwn_10_14_female, total_initiated_in_12_months_btwn_10_14_male, total_initiated_in_12_months_less_15_19_female, total_initiated_in_12_months_less_15_19_male, total_initiated_in_12_months_less_20_24_female, total_initiated_in_12_months_less_20_24_male, total_initiated_in_12_months_less_25_49_female, total_initiated_in_12_months_less_25_49_male, total_initiated_in_12_months_less_more_than_50_female, total_initiated_in_12_months_less_more_than_50_male, total_initiated_in_12_months_less_15_female, total_initiated_in_12_months_less_15_male, total_initiated_in_12_months_more_15_female, total_initiated_in_12_months_more_15_male = total_initiated_in_12_months(start_date, end_date, nil, nil)

  puts "PEADs with outcomes........................................................................."
  cumulative_children_less_15_years = cumulative_children_less_15_years(start_date, end_date)
  patients_alive_and_on_arvs_all_ages, patients_alive_and_on_arvs_less_15_years, patients_alive_and_on_arvs_less_bwtn_10_14_years, patients_alive_and_on_arvs_only_14_years, patients_alive_and_on_arvs_between_15_and_19_years, patients_alive_and_on_arvs_more_than_20_years = peads_receiving_art_cumulative(start_date, end_date)
  treatment_outcome_for_children_less_15yrs_died = patients_by_age_and_outcomes(start_date, end_date, "Patient died", 0, 14)
  treatment_outcome_for_children_less_15yrs_defaulted = patients_by_age_and_outcomes(start_date, end_date, "Defaulted", 0, 14)
  treatment_outcome_for_children_less_15yrs_stopped = patients_by_age_and_outcomes(start_date, end_date, "Treatment stopped", 0, 14)
  treatment_outcome_for_children_less_15yrs_transferred_out = patients_by_age_and_outcomes(start_date, end_date, "Patient transferred out", 0, 14)

  if CDCDataExtraction == 1
    file = "/home/deliwe/Desktop/cdc_data_extraction/cdc_art_data_extraction_" + "#{facility_name}" + ".csv"

    FasterCSV.open( file, 'w' ) do |csv|
      csv << ["Facility_Name", "Category", "Total of Category", "Less_than_1_yr", "Between_1_and_9_yrs", "Between_10_14_yrs_female", "Between_10_14_yrs_male", "Between_15_19_yrs_female", "Between_15_19_yrs_male", "Between_20-24_yrs_female", "Between_20_24_yrs_male", "Between_25-49_yrs_female", "Between_25_49_yrs_male", "More_than_50yrs_female", "More_than_50yrs_male", "Less_than_15yrs_female", "Less_than_15yrs_male", "More_than_15yrs_female", "More_than_15yrs_male"]
      csv << ["#{facility_name}", "New on ART (Newly registered)","#{total_new_on_art}", "#{new_on_art_less_1}", "#{new_on_art_between_1_and_9}", "#{new_on_art_btwn_10_14_female}", "#{new_on_art_btwn_10_14_male}", "#{new_on_art_less_15_19_female}", "#{new_on_art_less_15_19_male}", "#{new_on_art_less_20_24_female}", "#{new_on_art_less_20_24_male}", "#{new_on_art_less_25_49_female}", "#{new_on_art_less_25_49_male}", "#{new_on_art_less_more_than_50_female}", "#{new_on_art_less_more_than_50_male}", "#{new_on_art_less_15_female}", "#{new_on_art_less_15_male}", "#{new_on_art_more_15_female}", "#{new_on_art_more_15_male}"]

      csv << ["#{facility_name}", "Recieving ART (Total registered- Cumulative)", "#{total_receiving_art_cumulative}", "#{receiving_art_cumulative_less_1}", "#{receiving_art_cumulative_between_1_and_9}", "#{receiving_art_cumulative_btwn_10_14_female}", "#{receiving_art_cumulative_btwn_10_14_male}", "#{receiving_art_cumulative_less_15_19_female}", "#{receiving_art_cumulative_less_15_19_male}", "#{receiving_art_cumulative_less_20_24_female}", "#{receiving_art_cumulative_less_20_24_male}", "#{receiving_art_cumulative_less_25_49_female}", "#{receiving_art_cumulative_less_25_49_male}", "#{receiving_art_cumulative_less_more_than_50_female}", "#{receiving_art_cumulative_less_more_than_50_male}", "#{receiving_art_cumulative_less_15_female}", "#{receiving_art_cumulative_less_15_male}", "#{receiving_art_cumulative_more_15_female}", "#{receiving_art_cumulative_more_15_male}"]

      csv << ["#{facility_name}",   "PLHIV with screened TB status positive",  "#{total_plhiv_screened_tb_status}",   "",   "",   "",   "",   "",   "",   "",   "",   "",   "",   "",   "",   "#{plhiv_screened_tb_status_less_15_female}", "#{plhiv_screened_tb_status_less_15_male}", "#{plhiv_screened_tb_status_more_15_female}", "#{plhiv_screened_tb_status_more_15_male}"]

      csv << ["#{facility_name}", "Total alive and on ARVS at 12 months after initiation","#{total_alive_and_on_ARVS_at_12_months_after_initiation}","#{alive_and_on_ARVS_at_12_months_after_initiation_less_1}","#{alive_and_on_ARVS_at_12_months_after_initiation_between_1_and_9}","#{alive_and_on_ARVS_at_12_months_after_initiation_btwn_10_14_female}","#{alive_and_on_ARVS_at_12_months_after_initiation_btwn_10_14_male}","#{alive_and_on_ARVS_at_12_months_after_initiation_less_15_19_female}","#{alive_and_on_ARVS_at_12_months_after_initiation_less_15_19_male}","#{alive_and_on_ARVS_at_12_months_after_initiation_less_20_24_female}","#{alive_and_on_ARVS_at_12_months_after_initiation_less_20_24_male}","#{alive_and_on_ARVS_at_12_months_after_initiation_less_25_49_female}","#{alive_and_on_ARVS_at_12_months_after_initiation_less_25_49_male}","#{alive_and_on_ARVS_at_12_months_after_initiation_less_more_than_50_female}","#{alive_and_on_ARVS_at_12_months_after_initiation_less_more_than_50_male}","#{alive_and_on_ARVS_at_12_months_after_initiation_less_15_female}","#{alive_and_on_ARVS_at_12_months_after_initiation_less_15_male}","#{alive_and_on_ARVS_at_12_months_after_initiation_more_15_female}","#{alive_and_on_ARVS_at_12_months_after_initiation_more_15_male}"]

      csv << ["#{facility_name}", "Total initiated in 12 months","#{total_total_initiated_in_12_months}", "#{total_initiated_in_12_months_less_1}", "#{total_initiated_in_12_months_between_1_and_9}", "#{total_initiated_in_12_months_btwn_10_14_female}", "#{total_initiated_in_12_months_btwn_10_14_male}", "#{total_initiated_in_12_months_less_15_19_female}", "#{total_initiated_in_12_months_less_15_19_male}", "#{total_initiated_in_12_months_less_20_24_female}", "#{total_initiated_in_12_months_less_20_24_male}", "#{total_initiated_in_12_months_less_25_49_female}", "#{total_initiated_in_12_months_less_25_49_male}", "#{total_initiated_in_12_months_less_more_than_50_female}", "#{total_initiated_in_12_months_less_more_than_50_male}", "#{total_initiated_in_12_months_less_15_female}", "#{total_initiated_in_12_months_less_15_male}", "#{total_initiated_in_12_months_more_15_female}", "#{total_initiated_in_12_months_more_15_male}"]

      csv << ["", "",  "", "",  "",  "",  "",  "",  "",  "",  "",  "",  "",  "",  "",  "",  "", "",  ""]
      csv << ["", "",  "", "",  "",  "",  "",  "",  "",  "",  "",  "",  "",  "",  "",  "",  "", "",  ""]

      csv << ["", "PEADs with outcomes", "Children_less_15yrs(Cumulative)", "Patients Alive and on ARVs(All ages)", "Children_less_15_years(Alive and on ARVs)", "Children_between_10_and_14yrs(Alive and on ARVS)", "Children_14yrs_only(Alive and on ARVS)", "Patients_between_15_and_19_yrs(Alive and on ARVS)", "Patients_more_than_20_yrs(Alive and on ARVS)", "Died_children_less_15yrs", "Defaulted_children_less_15yrs", "Treatment_stopped_children_less_15yrs", "Transfered_out_children_less_15yrs"]

      csv << ["#{facility_name}","PEADs with outcomes","#{cumulative_children_less_15_years}", "#{patients_alive_and_on_arvs_all_ages}", "#{patients_alive_and_on_arvs_less_15_years}", "#{patients_alive_and_on_arvs_less_bwtn_10_14_years}", "#{patients_alive_and_on_arvs_only_14_years}", "#{patients_alive_and_on_arvs_between_15_and_19_years}", "#{patients_alive_and_on_arvs_more_than_20_years}", "#{treatment_outcome_for_children_less_15yrs_died}", "#{treatment_outcome_for_children_less_15yrs_defaulted}", "#{treatment_outcome_for_children_less_15yrs_stopped}", "#{treatment_outcome_for_children_less_15yrs_transferred_out}"]
    end
  end

  if CDCDataExtraction == 1
    #{}$resultsOutput.close()
  end

end

def self.cumulative_children_less_15_years(start_date, end_date)
  #pulling children less than 15 years
  new_on_art = ActiveRecord::Base.connection.select_all <<EOF
    SELECT * FROM earliest_start_date
    WHERE date_enrolled <= '#{end_date}'
    AND age_at_initiation between 0 and 14;
EOF

  return new_on_art.count
end

def self.new_on_art(start_date, end_date, min_age = nil, max_age = nil, gender = [])
  #pulling patients initiated in ART for the first time in the quarter
  new_on_art =   ActiveRecord::Base.connection.select_all <<EOF
      SELECT * FROM temp_earliest_start_date
      WHERE date_enrolled BETWEEN '#{start_date}' AND '#{end_date}'
      AND DATE(date_enrolled) = DATE(earliest_start_date)
      GROUP BY patient_id;
EOF

  total_new_on_art = []; new_on_art_less_1  = []; new_on_art_between_1_and_9 = []
  new_on_art_btwn_10_14_female  = []; new_on_art_btwn_10_14_male = []; new_on_art_less_15_19_female = []
  new_on_art_less_15_19_male = []; new_on_art_less_20_24_female = []; new_on_art_less_20_24_male = []
  new_on_art_less_25_49_female = []; new_on_art_less_25_49_male = []; new_on_art_less_more_than_50_female = []
  new_on_art_less_more_than_50_male = []; new_on_art_less_15_female = []; new_on_art_less_15_male = []
  new_on_art_more_15_female = []; new_on_art_more_15_male = []

  (new_on_art || []).each do |patient|
    if patient['age_at_initiation'].to_i <= 1
      new_on_art_less_1 << patient['patient_id'].to_i
    elsif patient['age_at_initiation'].to_i  >= 2 && patient['age_at_initiation'].to_i  <= 9
      new_on_art_between_1_and_9 << patient['patient_id'].to_i
    end

    if (patient['age_at_initiation'].to_i  >= 10 && patient['age_at_initiation'].to_i  <= 14)
      if (patient['gender'] == "M")
        new_on_art_btwn_10_14_male << patient['patient_id'].to_i
      else
        new_on_art_btwn_10_14_female << patient['patient_id'].to_i
      end
    end

    if (patient['age_at_initiation'].to_i  >= 15 && patient['age_at_initiation'].to_i  <= 19)
      if (patient['gender'] == "F")
        new_on_art_less_15_19_female << patient['patient_id'].to_i
      else
        new_on_art_less_15_19_male << patient['patient_id'].to_i
      end
    end

    if (patient['age_at_initiation'].to_i  >= 20 && patient['age_at_initiation'].to_i  <= 24)
      if (patient['gender'] == "M")
        new_on_art_less_20_24_male << patient['patient_id'].to_i
      else
        new_on_art_less_20_24_female << patient['patient_id'].to_i
      end
    end

    if (patient['age_at_initiation'].to_i  >= 25 && patient['age_at_initiation'].to_i  <= 49)
      if (patient['gender'] == "M")
        new_on_art_less_25_49_male << patient['patient_id'].to_i
      else
        new_on_art_less_25_49_female << patient['patient_id'].to_i
      end
    end

    if (patient['age_at_initiation'].to_i  >= 50)
      if (patient['gender'] == "M")
        new_on_art_less_more_than_50_male << patient['patient_id'].to_i
      else
        new_on_art_less_more_than_50_female << patient['patient_id'].to_i
      end
    end

    if (patient['age_at_initiation'].to_i  <= 14)
      if (patient['gender'] == "M")
        new_on_art_less_15_male << patient['patient_id'].to_i
      else
        new_on_art_less_15_female << patient['patient_id'].to_i
      end
    end

    if (patient['age_at_initiation'].to_i  >= 15)
      if (patient['gender'] ==  "M")
        new_on_art_more_15_male << patient['patient_id'].to_i
      else
        new_on_art_more_15_female << patient['patient_id'].to_i
      end
    end
  end

  (new_on_art || []).each do |patient|
    total_new_on_art << patient['patient_id'].to_i
  end

  return [total_new_on_art.count, new_on_art_less_1.count,
  new_on_art_between_1_and_9.count, new_on_art_btwn_10_14_female.count,
  new_on_art_btwn_10_14_male.count, new_on_art_less_15_19_female.count,
  new_on_art_less_15_19_male.count, new_on_art_less_20_24_female.count,
  new_on_art_less_20_24_male.count, new_on_art_less_25_49_female.count,
  new_on_art_less_25_49_male.count, new_on_art_less_more_than_50_female.count,
  new_on_art_less_more_than_50_male.count, new_on_art_less_15_female.count,
  new_on_art_less_15_male.count, new_on_art_more_15_female.count, new_on_art_more_15_male.count]
end

def self.receiving_art_cumulative(start_date, end_date, min_age = nil, max_age = nil, gender = [])
  #pulling all patients that are alive and on ARVs cumulatively
  receiving_art_cumulative =  ActiveRecord::Base.connection.select_all <<EOF
        SELECT t.*, patient_outcome(patient_id, '#{end_date}') cum_outcome
      FROM temp_earliest_start_date t
      WHERE date_enrolled <= '#{end_date}'
      GROUP BY t.patient_id
      HAVING cum_outcome = 'On antiretrovirals';
EOF

  total_receiving_art_cumulative = []; receiving_art_cumulative_less_1  = []; receiving_art_cumulative_between_1_and_9 = []
  receiving_art_cumulative_btwn_10_14_female  = []; receiving_art_cumulative_btwn_10_14_male = []; receiving_art_cumulative_less_15_19_female = []
  receiving_art_cumulative_less_15_19_male = []; receiving_art_cumulative_less_20_24_female = []; receiving_art_cumulative_less_20_24_male = []
  receiving_art_cumulative_less_25_49_female = []; receiving_art_cumulative_less_25_49_male = []; receiving_art_cumulative_less_more_than_50_female = []
  receiving_art_cumulative_less_more_than_50_male = []; receiving_art_cumulative_less_15_female = []; receiving_art_cumulative_less_15_male = []
  receiving_art_cumulative_more_15_female = []; receiving_art_cumulative_more_15_male = []

  (receiving_art_cumulative || []).each do |patient|
    if patient['age_at_initiation'].to_i <= 1
      receiving_art_cumulative_less_1 << patient
    elsif patient['age_at_initiation'].to_i >= 2 && patient['age_at_initiation'].to_i <= 9
      receiving_art_cumulative_between_1_and_9 << patient
    end

    if (patient['age_at_initiation'].to_i >= 10 && patient['age_at_initiation'].to_i <= 14)
      if (patient['gender'] == "M")
        receiving_art_cumulative_btwn_10_14_male << patient
      else
        receiving_art_cumulative_btwn_10_14_female << patient
      end
    end

    if (patient['age_at_initiation'].to_i >= 15 && patient['age_at_initiation'].to_i <= 19)
      if (patient['gender'] == "M")
        receiving_art_cumulative_less_15_19_male << patient
      else
        receiving_art_cumulative_less_15_19_female << patient
      end
    end

    if (patient['age_at_initiation'].to_i >= 20 && patient['age_at_initiation'].to_i <= 24)
      if (patient['gender'] == "M")
        receiving_art_cumulative_less_20_24_male << patient
      else
        receiving_art_cumulative_less_20_24_female << patient
      end
    end

    if (patient['age_at_initiation'].to_i >= 25 && patient['age_at_initiation'].to_i <= 49)
      if (patient['gender'] == "M")
        receiving_art_cumulative_less_25_49_male << patient
      else
        receiving_art_cumulative_less_25_49_female << patient
      end
    end

    if (patient['age_at_initiation'].to_i >= 50)
      if (patient['gender'] == "M")
        receiving_art_cumulative_less_more_than_50_male << patient
      else
        receiving_art_cumulative_less_more_than_50_female << patient
      end
    end

    if (patient['age_at_initiation'].to_i < 15)
      if (patient['gender'] == "M")
        receiving_art_cumulative_less_15_male << patient
      else
        receiving_art_cumulative_less_15_female << patient
      end
    end

    if (patient['age_at_initiation'].to_i >= 15)
      if (patient['gender'] ==  "M")
        receiving_art_cumulative_more_15_male << patient
      else
        receiving_art_cumulative_more_15_female << patient
      end
    end
  end

  total_receiving_art_cumulative = receiving_art_cumulative

  return [total_receiving_art_cumulative.count, receiving_art_cumulative_less_1.count,
    receiving_art_cumulative_between_1_and_9.count, receiving_art_cumulative_btwn_10_14_female.count,
    receiving_art_cumulative_btwn_10_14_male.count, receiving_art_cumulative_less_15_19_female.count,
    receiving_art_cumulative_less_15_19_male.count, receiving_art_cumulative_less_20_24_female.count,
    receiving_art_cumulative_less_20_24_male.count, receiving_art_cumulative_less_25_49_female.count,
    receiving_art_cumulative_less_25_49_male.count, receiving_art_cumulative_less_more_than_50_female.count,
    receiving_art_cumulative_less_more_than_50_male.count, receiving_art_cumulative_less_15_female.count,
    receiving_art_cumulative_less_15_male.count, receiving_art_cumulative_more_15_female.count,
    receiving_art_cumulative_more_15_male.count]
end

def self.plhiv_screened_tb_status(start_date, end_date, min_age = nil, max_age = nil, gender = [])
  #pulling all patients that were screened their tb status
  #TB status = 7459 and 7456 = "Confirmed TB NOT on treatment" and 7458 = "Confirmed TB and on treatment"
  plhiv_screened_tb_status =  ActiveRecord::Base.connection.select_all <<EOF
        SELECT t.*, patient_outcome(patient_id, '#{end_date}') cum_outcome
      FROM temp_earliest_start_date t
        INNER JOIN obs o ON o.person_id = t.patient_id AND o.voided = 0
      WHERE date_enrolled <= '#{end_date}'
        AND o.concept_id = 7459
        AND value_coded IN (7456, 7458)
      AND DATE(o.obs_datetime) < '#{end_date}'
      GROUP BY t.patient_id
      HAVING cum_outcome = 'On antiretrovirals';
EOF

  total_plhiv_screened_tb_status = []; plhiv_screened_tb_status_less_1  = []; plhiv_screened_tb_status_between_1_and_9 = []
  plhiv_screened_tb_status_btwn_10_14_female  = []; plhiv_screened_tb_status_btwn_10_14_male = []; plhiv_screened_tb_status_less_15_19_female = []
  plhiv_screened_tb_status_less_15_19_male = []; plhiv_screened_tb_status_less_20_24_female = []; plhiv_screened_tb_status_less_20_24_male = []
  plhiv_screened_tb_status_less_25_49_female = []; plhiv_screened_tb_status_less_25_49_male = []; plhiv_screened_tb_status_less_more_than_50_female = []
  plhiv_screened_tb_status_less_more_than_50_male = []; plhiv_screened_tb_status_less_15_female = []; plhiv_screened_tb_status_less_15_male = []
  plhiv_screened_tb_status_more_15_female = []; plhiv_screened_tb_status_more_15_male = []

  (plhiv_screened_tb_status || []).each do |patient|
    if patient['age_at_initiation'].to_i <= 1
      plhiv_screened_tb_status_less_1 << patient
    elsif patient['age_at_initiation'].to_i >= 2 && patient['age_at_initiation'].to_i <= 9
      plhiv_screened_tb_status_between_1_and_9 << patient
    end

    if (patient['age_at_initiation'].to_i >= 10 && patient['age_at_initiation'].to_i <= 14)
      if (patient['gender'] == "M")
        plhiv_screened_tb_status_btwn_10_14_male << patient
      else
        plhiv_screened_tb_status_btwn_10_14_female << patient
      end
    end

    if (patient['age_at_initiation'].to_i >= 15 && patient['age_at_initiation'].to_i <= 19)
      if (patient['gender'] == "M")
        plhiv_screened_tb_status_less_15_19_male << patient
      else
        plhiv_screened_tb_status_less_15_19_female << patient
      end
    end

    if (patient['age_at_initiation'].to_i >= 20 && patient['age_at_initiation'].to_i <= 24)
      if (patient['gender'] == "M")
        plhiv_screened_tb_status_less_20_24_male << patient
      else
        plhiv_screened_tb_status_less_20_24_female << patient
      end
    end

    if (patient['age_at_initiation'].to_i >= 25 && patient['age_at_initiation'].to_i <= 49)
      if (patient['gender'] == "M")
        plhiv_screened_tb_status_less_25_49_male << patient
      else
        plhiv_screened_tb_status_less_25_49_female << patient
      end
    end

    if (patient['age_at_initiation'].to_i >= 50)
      if (patient['gender'] == "M")
        plhiv_screened_tb_status_less_more_than_50_male << patient
      else
        plhiv_screened_tb_status_less_more_than_50_female << patient
      end
    end

    if (patient['age_at_initiation'].to_i < 15)
      if (patient['gender'] == "M")
        plhiv_screened_tb_status_less_15_male << patient
      else
        plhiv_screened_tb_status_less_15_female << patient
      end
    end

    if (patient['age_at_initiation'].to_i >= 15)
      if (patient['gender'] ==  "M")
        plhiv_screened_tb_status_more_15_male << patient
      else
        plhiv_screened_tb_status_more_15_female << patient
      end
    end
  end

  total_plhiv_screened_tb_status = plhiv_screened_tb_status

  return [total_plhiv_screened_tb_status.count, plhiv_screened_tb_status_less_15_female.count,
  plhiv_screened_tb_status_less_15_male.count, plhiv_screened_tb_status_more_15_female.count,
  plhiv_screened_tb_status_more_15_male.count]
end

def self.alive_and_on_ARVS_at_12_months_after_initiation(start_date, end_date, min_age = nil, max_age = nil, gender = [])
  #Pulling patients that are alive and on ARvs at 12 months after their initiation
  alive_and_on_ARVS_at_12_months_after_initiation =  ActiveRecord::Base.connection.select_all <<EOF
        SELECT t.*, patient_outcome(patient_id, '#{end_date}') cum_outcome
      FROM temp_earliest_start_date t
      WHERE date_enrolled BETWEEN '2016-01-01' AND '#{end_date}'
       GROUP BY t.patient_id
      HAVING cum_outcome = 'On antiretrovirals';
EOF

    total_alive_and_on_ARVS_at_12_months_after_initiation = []; alive_and_on_ARVS_at_12_months_after_initiation_less_1  = []; alive_and_on_ARVS_at_12_months_after_initiation_between_1_and_9 = []
    alive_and_on_ARVS_at_12_months_after_initiation_btwn_10_14_female  = []; alive_and_on_ARVS_at_12_months_after_initiation_btwn_10_14_male = []; alive_and_on_ARVS_at_12_months_after_initiation_less_15_19_female = []
    alive_and_on_ARVS_at_12_months_after_initiation_less_15_19_male = []; alive_and_on_ARVS_at_12_months_after_initiation_less_20_24_female = []; alive_and_on_ARVS_at_12_months_after_initiation_less_20_24_male = []
    alive_and_on_ARVS_at_12_months_after_initiation_less_25_49_female = []; alive_and_on_ARVS_at_12_months_after_initiation_less_25_49_male = []; alive_and_on_ARVS_at_12_months_after_initiation_less_more_than_50_female = []
    alive_and_on_ARVS_at_12_months_after_initiation_less_more_than_50_male = []; alive_and_on_ARVS_at_12_months_after_initiation_less_15_female = []; alive_and_on_ARVS_at_12_months_after_initiation_less_15_male = []
    alive_and_on_ARVS_at_12_months_after_initiation_more_15_female = []; alive_and_on_ARVS_at_12_months_after_initiation_more_15_male = []

    (alive_and_on_ARVS_at_12_months_after_initiation || []).each do |patient|
      if patient['age_at_initiation'].to_i <= 1
        alive_and_on_ARVS_at_12_months_after_initiation_less_1 << patient
      elsif patient['age_at_initiation'].to_i >= 2 && patient['age_at_initiation'].to_i <= 9
        alive_and_on_ARVS_at_12_months_after_initiation_between_1_and_9 << patient
      end

      if (patient['age_at_initiation'].to_i >= 10 && patient['age_at_initiation'].to_i <= 14)
        if (patient['gender'] == "M")
          alive_and_on_ARVS_at_12_months_after_initiation_btwn_10_14_male << patient
        else
          alive_and_on_ARVS_at_12_months_after_initiation_btwn_10_14_female << patient
        end
      end

      if (patient['age_at_initiation'].to_i >= 15 && patient['age_at_initiation'].to_i <= 19)
        if (patient['gender'] == "M")
          alive_and_on_ARVS_at_12_months_after_initiation_less_15_19_male << patient
        else
          alive_and_on_ARVS_at_12_months_after_initiation_less_15_19_female << patient
        end
      end

      if (patient['age_at_initiation'].to_i >= 20 && patient['age_at_initiation'].to_i <= 24)
        if (patient['gender'] == "M")
          alive_and_on_ARVS_at_12_months_after_initiation_less_20_24_male << patient
        else
          alive_and_on_ARVS_at_12_months_after_initiation_less_20_24_female << patient
        end
      end

      if (patient['age_at_initiation'].to_i >= 25 && patient['age_at_initiation'].to_i <= 49)
        if (patient['gender'] == "M")
          alive_and_on_ARVS_at_12_months_after_initiation_less_25_49_male << patient
        else
          alive_and_on_ARVS_at_12_months_after_initiation_less_25_49_female << patient
        end
      end

      if (patient['age_at_initiation'].to_i >= 50)
        if (patient['gender'] == "M")
          alive_and_on_ARVS_at_12_months_after_initiation_less_more_than_50_male << patient
        else
          alive_and_on_ARVS_at_12_months_after_initiation_less_more_than_50_female << patient
        end
      end

      if (patient['age_at_initiation'].to_i < 15)
        if (patient['gender'] == "M")
          alive_and_on_ARVS_at_12_months_after_initiation_less_15_male << patient
        else
          alive_and_on_ARVS_at_12_months_after_initiation_less_15_female << patient
        end
      end

      if (patient['age_at_initiation'].to_i >= 15)
        if (patient['gender'] ==  "M")
          alive_and_on_ARVS_at_12_months_after_initiation_more_15_male << patient
        else
          alive_and_on_ARVS_at_12_months_after_initiation_more_15_female << patient
        end
      end
    end

    total_alive_and_on_ARVS_at_12_months_after_initiation = alive_and_on_ARVS_at_12_months_after_initiation

    return [total_alive_and_on_ARVS_at_12_months_after_initiation.count, alive_and_on_ARVS_at_12_months_after_initiation_less_1.count,
    alive_and_on_ARVS_at_12_months_after_initiation_between_1_and_9.count,
    alive_and_on_ARVS_at_12_months_after_initiation_btwn_10_14_female.count,
    alive_and_on_ARVS_at_12_months_after_initiation_btwn_10_14_male.count,
    alive_and_on_ARVS_at_12_months_after_initiation_less_15_19_female.count,
    alive_and_on_ARVS_at_12_months_after_initiation_less_15_19_male.count,
    alive_and_on_ARVS_at_12_months_after_initiation_less_20_24_female.count,
    alive_and_on_ARVS_at_12_months_after_initiation_less_20_24_male.count,
    alive_and_on_ARVS_at_12_months_after_initiation_less_25_49_female.count,
    alive_and_on_ARVS_at_12_months_after_initiation_less_25_49_male.count,
    alive_and_on_ARVS_at_12_months_after_initiation_less_more_than_50_female.count,
    alive_and_on_ARVS_at_12_months_after_initiation_less_more_than_50_male.count,
    alive_and_on_ARVS_at_12_months_after_initiation_less_15_female.count,
    alive_and_on_ARVS_at_12_months_after_initiation_less_15_male.count,
    alive_and_on_ARVS_at_12_months_after_initiation_more_15_female.count,
    alive_and_on_ARVS_at_12_months_after_initiation_more_15_male.count]
end

def self.total_initiated_in_12_months(start_date, end_date, min_age = nil, max_age = nil, gender = [])
  #pulling patients that have been registered in 12 months (a year)
  total_initiated_in_12_months = ActiveRecord::Base.connection.select_all <<EOF
      SELECT *
      FROM temp_earliest_start_date
      WHERE date_enrolled BETWEEN '2016-01-01' AND '#{end_date}';
EOF

  total_tota_initiated_in_12_months = []; total_initiated_in_12_months_less_1  = []; total_initiated_in_12_months_between_1_and_9 = []
  total_initiated_in_12_months_btwn_10_14_female  = []; total_initiated_in_12_months_btwn_10_14_male = []; total_initiated_in_12_months_less_15_19_female = []
  total_initiated_in_12_months_less_15_19_male = []; total_initiated_in_12_months_less_20_24_female = []; total_initiated_in_12_months_less_20_24_male = []
  total_initiated_in_12_months_less_25_49_female = []; total_initiated_in_12_months_less_25_49_male = []; total_initiated_in_12_months_less_more_than_50_female = []
  total_initiated_in_12_months_less_more_than_50_male = []; total_initiated_in_12_months_less_15_female = []; total_initiated_in_12_months_less_15_male = []
  total_initiated_in_12_months_more_15_female = []; total_initiated_in_12_months_more_15_male = []

  (total_initiated_in_12_months || []).each do |patient|
    if patient['age_at_initiation'].to_i <= 1
      total_initiated_in_12_months_less_1 << patient
    elsif patient['age_at_initiation'].to_i >= 2 && patient['age_at_initiation'].to_i <= 9
      total_initiated_in_12_months_between_1_and_9 << patient
    end

    if (patient['age_at_initiation'].to_i >= 10 && patient['age_at_initiation'].to_i <= 14)
      if (patient['gender'] == "M")
        total_initiated_in_12_months_btwn_10_14_male << patient
      else
        total_initiated_in_12_months_btwn_10_14_female << patient
      end
    end

    if (patient['age_at_initiation'].to_i >= 15 && patient['age_at_initiation'].to_i <= 19)
      if (patient['gender'] == "M")
        total_initiated_in_12_months_less_15_19_male << patient
      else
        total_initiated_in_12_months_less_15_19_female << patient
      end
    end

    if (patient['age_at_initiation'].to_i >= 20 && patient['age_at_initiation'].to_i <= 24)
      if (patient['gender'] == "M")
        total_initiated_in_12_months_less_20_24_male << patient
      else
        total_initiated_in_12_months_less_20_24_female << patient
      end
    end

    if (patient['age_at_initiation'].to_i >= 25 && patient['age_at_initiation'].to_i <= 49)
      if (patient['gender'] == "M")
        total_initiated_in_12_months_less_25_49_male << patient
      else
        total_initiated_in_12_months_less_25_49_female << patient
      end
    end

    if (patient['age_at_initiation'].to_i >= 50)
      if (patient['gender'] == "M")
        total_initiated_in_12_months_less_more_than_50_male << patient
      else
        total_initiated_in_12_months_less_more_than_50_female << patient
      end
    end

    if (patient['age_at_initiation'].to_i < 15)
      if (patient['gender'] == "M")
        total_initiated_in_12_months_less_15_male << patient
      else
        total_initiated_in_12_months_less_15_female << patient
      end
    end

    if (patient['age_at_initiation'].to_i >= 15)
      if (patient['gender'] ==  "M")
        total_initiated_in_12_months_more_15_male << patient
      else
        total_initiated_in_12_months_more_15_female << patient
      end
    end
  end

  total_total_initiated_in_12_months = total_initiated_in_12_months

  return [total_total_initiated_in_12_months.count, total_initiated_in_12_months_less_1.count,
    total_initiated_in_12_months_between_1_and_9.count,
    total_initiated_in_12_months_btwn_10_14_female.count,
    total_initiated_in_12_months_btwn_10_14_male.count,
    total_initiated_in_12_months_less_15_19_female.count,
    total_initiated_in_12_months_less_15_19_male.count,
    total_initiated_in_12_months_less_20_24_female.count,
    total_initiated_in_12_months_less_20_24_male.count,
    total_initiated_in_12_months_less_25_49_female.count,
    total_initiated_in_12_months_less_25_49_male.count,
    total_initiated_in_12_months_less_more_than_50_female.count,
    total_initiated_in_12_months_less_more_than_50_male.count,
    total_initiated_in_12_months_less_15_female.count,
    total_initiated_in_12_months_less_15_male.count,
    total_initiated_in_12_months_more_15_female.count,
    total_initiated_in_12_months_more_15_male.count]
end

def self.peads_receiving_art_cumulative(start_date, end_date, min_age = nil, max_age = nil, gender = [])
  #pulling peads who are alive and on ARVs
  receiving_art_cumulative =  ActiveRecord::Base.connection.select_all <<EOF
          SELECT t.*, patient_outcome(patient_id, '#{end_date}') cum_outcome
        FROM temp_earliest_start_date t
        WHERE date_enrolled <= '#{end_date}'
         GROUP BY t.patient_id
        HAVING cum_outcome = 'On antiretrovirals';
EOF

  patients_alive_and_on_arvs_all_ages = []
  patients_alive_and_on_arvs_less_15_years = []
  patients_alive_and_on_arvs_less_bwtn_10_14_years = []
  patients_alive_and_on_arvs_only_14_years = []
  patients_alive_and_on_arvs_between_15_and_19_years = []
  patients_alive_and_on_arvs_more_than_20_years = []

  (receiving_art_cumulative || []).each do |patient|
    if (patient['age_at_initiation'].to_i < 15)
      patients_alive_and_on_arvs_less_15_years << patient
    end

    if (patient['age_at_initiation'].to_i >= 10 && patient['age_at_initiation'].to_i <= 14)
      patients_alive_and_on_arvs_less_bwtn_10_14_years << patient
    end

    if (patient['age_at_initiation'].to_i == 14)
      patients_alive_and_on_arvs_only_14_years << patient
    end

    if (patient['age_at_initiation'].to_i >= 15 && patient['age_at_initiation'].to_i <= 19)
      patients_alive_and_on_arvs_between_15_and_19_years << patient
    end

    if (patient['age_at_initiation'].to_i >= 20 )
      patients_alive_and_on_arvs_more_than_20_years << patient
    end
  end

  patients_alive_and_on_arvs_all_ages = receiving_art_cumulative

  return [patients_alive_and_on_arvs_all_ages.count,patients_alive_and_on_arvs_less_15_years.count,
    patients_alive_and_on_arvs_less_bwtn_10_14_years.count, patients_alive_and_on_arvs_only_14_years.count,
    patients_alive_and_on_arvs_between_15_and_19_years.count, patients_alive_and_on_arvs_more_than_20_years.count]
end

def self.patients_by_age_and_outcomes(start_date, end_date, patient_outcome, min_age = nil, max_age = nil, gender = [])
  if (max_age.blank? && min_age.blank?)
    condition = ""
  elsif (max_age.blank?)
    condition = "AND age_at_initiation >= #{min_age}"
  else
    condition = "AND age_at_initiation  BETWEEN #{min_age} and #{max_age}"
  end

  unless gender.blank?
    patients_outcome = ActiveRecord::Base.connection.select_all <<EOF
        SELECT t.*, patient_outcome(patient_id, '#{end_date}') cum_outcome
      FROM temp_earliest_start_date t
      WHERE date_enrolled <= '#{end_date}'
      AND gender = '#{gender}'   #{condition}
      GROUP BY t.patient_id
      HAVING cum_outcome = '#{patient_outcome}';
EOF
  else
    patients_outcome = ActiveRecord::Base.connection.select_all <<EOF
      SELECT t.*, patient_outcome(patient_id, '#{end_date}') cum_outcome
      FROM temp_earliest_start_date t
      WHERE date_enrolled <= '#{end_date}'
      AND gender IN ('M', 'F')   #{condition}
      GROUP BY t.patient_id
      HAVING cum_outcome = '#{patient_outcome}';
EOF
  end
  if patients_outcome.blank?
    result = 0
  else
    result = patients_outcome.count
  end
  return  result
end

start
