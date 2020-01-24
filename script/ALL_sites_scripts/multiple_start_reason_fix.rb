# Script to void multiple start reason

def start
  #getting patients with multiple reason for eligibility obs
  #reason_for_art_eligibility concept_id = 7563
  patients_with_multiple_start_reasons = ActiveRecord::Base.connection.select_all <<EOF
    SELECT person_id, count(*) c
    FROM obs
    WHERE concept_id = 7563
    AND voided = 0
    GROUP BY person_id
    HAVING c > 1 ;
EOF
  #voiding the duplicate start reasons
  (patients_with_multiple_start_reasons || []).each do |patient|
    puts "updating patient_id: #{patient['person_id']}"

    patient_obs_id =  ActiveRecord::Base.connection.select_one <<EOF
      SELECT obs_id FROM obs
      WHERE person_id = #{patient['person_id'].to_i}
      AND concept_id = 7563
      AND voided = 0
      ORDER BY obs_datetime ASC, date_created ASC LIMIT 1;
EOF

    ActiveRecord::Base.connection.execute <<EOF
      UPDATE obs set voided = 1, void_reason = "Patient with multiple start reason", date_voided = NOW(), voided_by = 1
      WHERE voided = 0
      AND person_id = #{patient['person_id'].to_i}
      AND concept_id = 7563 and obs_id != #{patient_obs_id['obs_id'].to_i};
EOF
  puts "Finished updating patient_id: #{patient['person_id']}"
  end
end

start
