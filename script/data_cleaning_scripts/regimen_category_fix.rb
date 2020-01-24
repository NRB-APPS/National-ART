#adding/updating regimen categpry observation to the dispensing encounter

def start
	#get all patients that have dispensing encounter
	patient_arvs_dispensing_visits =  ActiveRecord::Base.connection.select_all <<EOF
		select patient_id, DATE(encounter_datetime) as visit_date, encounter_id, location_id, encounter_datetime from encounter where encounter_type IN (54) and voided = 0
		group by patient_id, date(encounter_datetime);
EOF

	(patient_arvs_dispensing_visits || []).each do |patient|

		regimen_category = ActiveRecord::Base.connection.select_one <<EOF
			select patient_current_regimen(#{patient["patient_id"].to_i}, '#{patient["visit_date"]}') as regimen_category;
EOF
		if regimen_category["regimen_category"]
      existing_regimen_cat = ActiveRecord::Base.connection.select_all <<EOF
      	select obs_id, person_id, encounter_id, location_id, value_text, obs_datetime from obs where encounter_id = #{patient["encounter_id"].to_i} and voided = 0 and concept_id = 8375;
EOF
		
			if existing_regimen_cat.blank?
				#insert
				puts "Insert regimen_category for patient_id: #{patient['patient_id'].to_i}"
				ActiveRecord::Base.connection.execute <<EOF
				UPDATE encounter set date_changed = NOW(), changed_by = 1
				WHERE voided = encounter_id = #{patient['encounter_id'].to_i}
				AND patient_id = #{patient['patient_id'].to_i};
EOF

				#create
				ActiveRecord::Base.connection.execute <<EOF
					INSERT INTO obs (person_id, encounter_id, location_id, concept_id, obs_datetime, date_created, creator, value_text, uuid)
					VALUES (#{patient['patient_id'].to_i}, #{patient['encounter_id'].to_i}, #{patient['location_id'].to_i} ,8375, '#{patient['obs_datetime']}', NOW(), 1, '#{regimen_category["regimen_category"]}', (SELECT UUID()));
EOF

			else
				(existing_regimen_cat || []).each do |category|
					if category["value_text"] == regimen_category["regimen_category"]
						puts "the same category for patient_id: #{patient['patient_id'].to_i} on visit_date: #{patient['visit_date']}"
					else
						#void
						puts "updating regimen_category for patient_id: #{patient['patient_id'].to_i} on visit_date: #{patient['visit_date']}"
						ActiveRecord::Base.connection.execute <<EOF
				      UPDATE obs set voided = 1, void_reason = "Patient with wrong regimen category", date_voided = NOW(), voided_by = 1
				      WHERE voided = 0
				      AND encounter_id = #{category['encounter_id'].to_i}
				      AND concept_id = 8375 and obs_id = #{category['obs_id'].to_i};
EOF

						#update encounters table
						ActiveRecord::Base.connection.execute <<EOF
				      UPDATE encounter set date_changed = NOW(), changed_by = 1
				      WHERE voided = encounter_id = #{category['encounter_id'].to_i}
				      AND patient_id = #{category['person_id'].to_i};						


						#create
						ActiveRecord::Base.connection.execute <<EOF
							INSERT INTO obs (person_id, encounter_id, location_id, concept_id, obs_datetime, date_created, creator, value_text, uuid)
							VALUES (#{category['person_id'].to_i}, #{category['encounter_id'].to_i}, #{category['location_id'].to_i} ,8375, '#{category['obs_datetime']}', NOW(), 1, '#{regimen_category["regimen_category"]}', (SELECT UUID()));
EOF
					end
				end
			end
		else
			raise 'am blank'
		end
	end
end

start