#this script will void the current HIV program for all those patients with
#multiple programs. Then it will update all the outcomes from the second
#HIV program to the first HIV program taking into consideration the
#dates sequence.

#Written by: Deliwe Nkhoma on 19th July, 2017

def start
  #get all patients that have multiple HIV programs
  #HIV_program_id = 1
  multiple_programs_patients = ActiveRecord::Base.connection.select_all <<EOF
    SELECT patient_id, COUNT(patient_id)
    FROM patient_program WHERE voided = 0 AND program_id = 1
    GROUP BY patient_id HAVING COUNT(patient_id)>1;
EOF

  (multiple_programs_patients || []).each do |patient|
    puts "Working on patient: #{patient['patient_id'].to_i}"
    #get all the HIV programs the patient has
    current_patient_hiv_program = ActiveRecord::Base.connection.select_all <<EOF
      SELECT p.* FROM patient_program p
      WHERE p.voided = 0 AND p.program_id = 1
      AND p.patient_id = #{patient['patient_id'].to_i}
      AND p.date_enrolled = (SELECT max(pp.date_enrolled) FROM patient_program pp
                             WHERE pp.patient_id = p.patient_id
                             AND pp.program_id = p.program_id
                             AND pp.voided = 0);
EOF

  first_patient_hiv_program = ActiveRecord::Base.connection.select_one <<EOF
    SELECT p.patient_program_id FROM patient_program p
    WHERE p.voided = 0 AND p.program_id = 1
    AND p.patient_id = #{patient['patient_id'].to_i}
    AND p.date_enrolled = (SELECT min(pp.date_enrolled) FROM patient_program pp
                           WHERE pp.patient_id = p.patient_id
                           AND pp.program_id = p.program_id
                           AND pp.voided = 0);
EOF
    patient_program_id = first_patient_hiv_program['patient_program_id'].to_i
    ActiveRecord::Base.connection.execute <<EOF
UPDATE patient_program SET date_completed = NULL WHERE patient_program_id = #{patient_program_id};
EOF

  all_program_ids = ActiveRecord::Base.connection.select_all <<EOF
    SELECT patient_program_id FROM patient_program WHERE patient_id = #{patient['patient_id'].to_i} AND voided = 0
    AND program_id = 1 AND patient_program_id != #{patient_program_id.to_i};
EOF

    (all_program_ids || []).each do |program|
      ActiveRecord::Base.connection.execute <<EOF
        UPDATE patient_program
        SET voided = 1, voided_by = 1, date_voided = NOW(), void_reason = 'Patient with multiple HIV programs'
        WHERE patient_program_id  = #{program['patient_program_id'].to_i};
EOF

      ActiveRecord::Base.connection.execute <<EOF
        UPDATE patient_state
        SET patient_program_id = #{patient_program_id}, date_changed = NOW(), changed_by = 1
        WHERE patient_program_id = #{program['patient_program_id'].to_i};
EOF
    end

    #get all patient_states for the patient
    patient_program_id
    patients_states = ActiveRecord::Base.connection.select_all <<EOF
      SELECT * FROM patient_state WHERE patient_program_id = #{patient_program_id}
      AND voided = 0 ORDER BY start_date;
EOF
    patient_states = []
    (patients_states || []).each do |patient|
      patient_states << [patient['patient_program_id'], patient['patient_state_id'], patient['start_date']]
    end

    state = 0
    while state < (patient_states.length - 1)
        previous_details = patient_states[state]
        patient_details = patient_states[state + 1]

        ActiveRecord::Base.connection.execute <<EOF
          UPDATE patient_state
          SET end_date = '#{patient_details[2]}' , date_changed = NOW(), changed_by = 1
          WHERE patient_program_id = #{patient_details[0].to_i} AND patient_state_id = #{previous_details[1].to_i};
EOF
        state += 1
    end
  end
end
start
