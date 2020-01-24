require 'fastercsv'

Source_db = YAML.load(File.open(File.join(RAILS_ROOT, "config/database.yml"), "r"))['production']["database"]

def start
 sample

end

def sample
  facility_name = GlobalProperty.find_by_sql("select property_value from global_property where property = 'current_health_center_name'").map(&:property_value).first
  end_date = '2016-12-31 23:59:59'
  file = "/home/user/dha_patient_level_data_" + "#{facility_name}" + ".csv"

  patient_details = ActiveRecord::Base.connection.select_all <<EOF
      SELECT esd.patient_id,
        esd.gender,
        esd.birthdate,
        DATE(esd.date_enrolled) AS date_of_registration,
        esd.earliest_start_date AS date_of_initiation,
        DATE(en.encounter_datetime) AS visit_date
      FROM earliest_start_date esd
        INNER JOIN encounter en ON en.patient_id = esd.patient_id AND en.voided = 0
      WHERE DATE(en.encounter_datetime) <= '#{end_date}'
      GROUP BY esd.patient_id, DATE(en.encounter_datetime);
EOF

  appointment_and_outcome_details = []
  (patient_details || []).each do |patient|
    appointment = ActiveRecord::Base.connection.select_one <<EOF
      SELECT person_id, concept_id, obs_datetime,  DATE(value_datetime) AS next_appointment_date FROM obs
        WHERE person_id = #{patient['patient_id']}
        AND DATE(obs_datetime) = '#{patient['visit_date']}'
        AND concept_id = 5096 AND voided = 0 LIMIT 1;
EOF

  outcome = ActiveRecord::Base.connection.select_one <<EOF
    SELECT patient_id, patient_outcome(#{patient['patient_id']}, '#{patient['visit_date']}') AS outcome
    FROM patient WHERE patient_id = #{patient['patient_id']} AND voided = 0;
EOF

    unless appointment.blank?
      appointment_date = appointment['next_appointment_date']
    else
      appointment_date = "N/A"
    end

    puts "#{patient['patient_id']}, #{appointment_date}, #{outcome['outcome']}"
    appointment_and_outcome_details << [patient['patient_id'], patient['gender'], patient['birthdate'], patient['date_of_registration'], patient['date_of_initiation'], patient['visit_date'], appointment_date, outcome['outcome']]
  end

  FasterCSV.open( file, 'w' ) do |csv|
    csv << ["facility_name","patient_id", "gender", "birthdate", "date_of_registration", "date_of_initiation", "visit_date", "next_appointment_date", "outcome"]
    appointment_and_outcome_details.each do |s|
      csv << ["#{facility_name}", s[0], s[1], s[2], s[3], s[4], s[5], s[6], s[7]]
    end
  end
  puts "please check your home folder for this site's csv file............"
end
start
