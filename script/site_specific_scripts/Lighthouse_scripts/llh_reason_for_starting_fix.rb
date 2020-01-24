# Script written to assign reason for starting for all those patients on ART
# but without reason for starting

def start
  #getting patients with reason for eligibility obs
  #reason_for_art_eligibility concept_id = 7563
  patients_with_reason_for_start = ActiveRecord::Base.connection.select_all <<EOF
    SELECT * FROM obs WHERE concept_id = 7563 AND voided = 0 GROUP BY person_id;
EOF

  patient_ids_with_start_reason = []
  (patients_with_reason_for_start || []).each do |patient|
    patient_ids_with_start_reason << patient['person_id'].to_i
  end

  #getting patients who started ART but do not have reason_for_art_eligibility obs
  patients_without_start_reason = ActiveRecord::Base.connection.select_all <<EOF
    SELECT * FROM earliest_start_date
    WHERE patient_id NOT IN (#{patient_ids_with_start_reason.join(',')});
EOF

  patient_ids_without_start_reason = []
  (patients_without_start_reason || []).each do |patient|
    patient_ids_without_start_reason << patient['patient_id'].to_i
  end

  #getting the hiv_staging encounters for all those that do not have reason_for_art_eligibility obs
  hiv_staging_encounters = ActiveRecord::Base.connection.select_all <<EOF
    SELECT * FROM encounter
    WHERE patient_id IN (#{patient_ids_without_start_reason.join(',')})
    AND voided = 0 AND encounter_type = 52;
EOF

  #unknown = 1067
  (hiv_staging_encounters || []).each do |patient|
    puts "working on encounter_id=#{patient['encounter_id'].to_i} belonging to patient_id=#{patient['patient_id'].to_i}"
    #insert reason_for_art_eligibility obs for each encounter
    ActiveRecord::Base.connection.execute <<EOF
      INSERT INTO obs (person_id, concept_id, encounter_id, obs_datetime, date_created, location_id, value_coded, value_coded_name_id, creator, uuid)
      VALUES(#{patient['patient_id'].to_i}, 7563, #{patient['encounter_id'].to_i}, '#{patient['encounter_datetime']}', NOW(), #{patient['location_id'].to_i}, 1067, 1104,1, (SELECT UUID()));
EOF
    puts "finished working on encounter_id=#{patient['encounter_id'].to_i} belonging to patient_id=#{patient['patient_id'].to_i}"
  end
end

start
