#update records of patients with incomplete breastfeeding data

Connection = ActiveRecord::Base.connection

def start
	#get all patients_ids
	pregnant_obs =  Connection.select_all <<EOF
		select * from obs where concept_id IN (1755, 6131, 7972) and voided = 0
		and (value_coded is not null and value_coded_name_id is null);
EOF

	(pregnant_obs || []).each do |patient|
		puts "Working on patient_id: #{patient["patient_id"].to_i}"

		update_encounter(patient['patient_id'].to_i, patient['encounter_id'].to_i, patient['value_coded'], patient['obs_id'].to_i)
		
		puts "Finished working on patient_id: #{patient["patient_id"].to_i}"
	end
end

def update_encounter(patient_id, encounter_id, value, obs_id)
		#update the date_changed in encounters_table
          Connection.execute <<EOF
UPDATE encounter set date_changed = NOW(), changed_by = 1
	WHERE encounter_id = #{encounter_id}
	AND patient_id = #{person_id};
EOF

		value_coded_name = ""
		if value == 1102
			value_coded_name = 1102
		elsif value == 1066
			value_coded_name = 1103 
		elsif value == 1067
			value_coded_name = 1104
		end

          Connection.execute <<EOF
UPDATE obs set value_coded_name_id = #{value_coded_name}
	WHERE encounter_id = #{encounter_id}
	AND person_id = #{person_id}
	AND obs_id = #{obs_id};
EOF

end

start