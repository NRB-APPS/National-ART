require 'fastercsv'

Source_db = YAML.load(File.open(File.join(RAILS_ROOT, "config/database.yml"), "r"))['production']["database"]
CDCDataExtraction = 1

def start
  facility_name = GlobalProperty.find_by_sql("select property_value from global_property where property = 'current_health_center_name'").map(&:property_value).first

  start_date = "2016-01-01".to_date
  end_date = "2016-03-31".to_date
  puts "CDC ART data extraction (Additional)................................................................................................"

  puts "Receving ART (Total registered) Additional 2014....................................................................................."
  end_date_first = '2014-09-30'.to_date
  total_receiving_art_14_years_old_first, total_receiving_art_less_1_year_first, total_receiving_art_between_1_and_9_years_first, total_receiving_art_10_14_years_first = receiving_art_cumulative(start_date, end_date_first)

  puts "Receving ART (Total registered) Additional 2015....................................................................................."
  end_date_second = '2015-09-30'.to_date
  total_receiving_art_14_years_old_second, total_receiving_art_less_1_year_second, total_receiving_art_between_1_and_9_years_second, total_receiving_art_10_14_years_second = receiving_art_cumulative(start_date, end_date_second)

  puts "Receving ART (Total registered) Additional 2016....................................................................................."
  end_date_third = '2016-09-30'.to_date
  total_receiving_art_14_years_old_third, total_receiving_art_less_1_year_third, total_receiving_art_between_1_and_9_years_third, total_receiving_art_10_14_years_third = receiving_art_cumulative(start_date, end_date_third)

  if CDCDataExtraction == 1
    file = "/home/deliwe/Desktop/cdc_data_extraction/cdc_art_additional_data_extraction_" + "#{facility_name}" + ".csv"

    FasterCSV.open( file, 'w' ) do |csv|
      csv << ["Facility_Name", "Category", "Total patients on ARVs 14yrs only", "Less_than_1_yr", "Between_1_and_9_yrs", "Between_10_14_yrs_female"]
      csv << ["#{facility_name}", "Receving ART (Total registered) Additional 2014","#{total_receiving_art_14_years_old_first}", "#{total_receiving_art_less_1_year_first}", "#{total_receiving_art_between_1_and_9_years_first}", "#{total_receiving_art_10_14_years_first}"]

      csv << ["#{facility_name}", "Receving ART (Total registered) Additional 2015","#{total_receiving_art_14_years_old_second}", "#{total_receiving_art_less_1_year_second}", "#{total_receiving_art_between_1_and_9_years_second}", "#{total_receiving_art_10_14_years_second}"]

      csv << ["#{facility_name}", "Receving ART (Total registered) Additional 2016","#{total_receiving_art_14_years_old_third}", "#{total_receiving_art_less_1_year_third}", "#{total_receiving_art_between_1_and_9_years_third}", "#{total_receiving_art_10_14_years_third}"]

    end
  end

  if CDCDataExtraction == 1
    #{}$resultsOutput.close()
  end
end

def self.receiving_art_cumulative(start_date, end_date)
  #pulling patients on ARVs cumulatively
  receiving_art_cumulative =  ActiveRecord::Base.connection.select_all <<EOF
        SELECT t.*, patient_outcome(patient_id, '#{end_date}') cum_outcome
      FROM temp_earliest_start_date t
      WHERE date_enrolled <= '#{end_date}'
      GROUP BY t.patient_id
      HAVING cum_outcome = 'On antiretrovirals';
EOF

  receiving_art_cumulative_less_1 = [], receiving_art_cumulative_between_1_and_9 = []
  receiving_art_cumulative_between_10_and_14 = [], receiving_art_cumulative_14yrs = []

  (receiving_art_cumulative || []).each do |patient|
    if patient['age_at_initiation'].to_i <= 1
      receiving_art_cumulative_less_1 << patient
    elsif patient['age_at_initiation'].to_i >= 2 && patient['age_at_initiation'].to_i <= 9
      receiving_art_cumulative_between_1_and_9 << patient
    elsif patient['age_at_initiation'].to_i >= 10 && patient['age_at_initiation'].to_i <= 14
      receiving_art_cumulative_between_10_and_14 << patient
    end

    if patient['age_at_initiation'].to_i == 14
      receiving_art_cumulative_14yrs << patient
    end
  end
  return [
    receiving_art_cumulative_less_1.count,
    receiving_art_cumulative_between_1_and_9.count,
    receiving_art_cumulative_between_10_and_14.count,
    receiving_art_cumulative_14yrs.count
  ]
end

start
