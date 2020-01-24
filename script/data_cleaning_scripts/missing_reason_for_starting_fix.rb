#update records of patients without reason for starting

Connection = ActiveRecord::Base.connection

def start
	#patients with tb within the last 2 years = 2624
	patient_with_tb_within_the_last_2_yrs = Connection.select_all <<EOF
		SELECT o.person_id as patient_id, o.concept_id, DATE(o.obs_datetime) as obs_datetime, 
		      ifnull((select name from concept_name where concept_id = o.value_coded and concept_name_type = 'FULLY_SPECIFIED'), o.value_text) AS name
		FROM obs o
			INNER JOIN encounter e ON e.encounter_id = o.encounter_id
		WHERE ((o.concept_id = 2743 AND o.value_coded = 2624) OR (o.concept_id = 2624 AND o.value_coded IS NOT NULL))
		AND o.voided = 0 and e.voided = 0
		GROUP BY o.person_id;
EOF
	
	#update flat_tables with these recrds
	(patient_with_tb_within_the_last_2_yrs || []).each do |patient|
		puts "Updating TB within the last 2 years for patient_id: #{patient['patient_id'].to_i}"

		update_tb_with_the_last_2_yrs(patient['patient_id'].to_i, patient['encounter_id'].to_i, patient['obs_datetime'], patient['concept_id'].to_i, patient['name'])

		puts "Finished updating TB within the last 2 years for patient_id: #{patient['patient_id'].to_i}"
	end

	#patients with voided reason for starting obs but with active associated encounter
	encounter_ids_list_with_voided_reason = []
	patient_list = Connection.select_all <<EOF
		select e.patient_id, e.encounter_id from encounter e
			inner join obs o on o.encounter_id = e.encounter_id
		where o.concept_id = 7563 and o.voided = 1 and o.void_reason = 'Voided multiple start reasons'
		and e.voided = 0 GROUP BY o.person_id;
EOF
raise patient_list.inspect
	(patient_list).each do |patient|
		start_reason = Connection.select_one  <<EOF
			select o.person_id, DATE(o.obs_datetime) AS obs_datetime, o.encounter_id, c.name as reason from obs o 
			 inner join concept_name c on c.concept_id = o.value_coded and c.concept_name_type = 'FULLY_SPECIFIED'
			where o.person_id = #{patient["patient_id"].to_i} and o.concept_id = 7563 and o.voided = 0
			and o.obs_datetime = (select max(obs.obs_datetime) from obs obs where obs.person_id = o.person_id and obs.voided = 0 and obs.concept_id = 7563);
EOF

		if start_reason
			puts "Updating flat_table1 and flat_cohort_table with reason_for_starting for patient_id: #{patient['patient_id'].to_i}"
			update_flat_tables(start_reason['person_id'].to_i, start_reason['encounter_id'].to_i, start_reason['obs_datetime'], start_reason['reason'])
			puts "Finished updating patient_id: #{patient['patient_id']}"
		end
	end

	#get all patients_ids
	patients_without_reason_for_starting_arvs =  Connection.select_all <<EOF
		select patient_id from flat_table1 where reason_for_eligibility like '0%' or reason_for_eligibility like '1%' or reason_for_eligibility like '2%' or reason_for_eligibility like '3%'
		or reason_for_eligibility like '4%' or reason_for_eligibility like '5%' or reason_for_eligibility like '6%' or reason_for_eligibility like '7%' or reason_for_eligibility like '8%' or reason_for_eligibility like '9%'
		or reason_for_eligibility is null;
EOF

	patient_ids = []
	(patients_without_reason_for_starting_arvs).each do |patient|
		patient_ids << patient['patient_id'].to_i
	end

	max_hiv_staging_encounter = Connection.select_all <<EOF
		select * from encounter e where e.encounter_type = 52 and e.patient_id IN (#{patient_ids.join(',')})
		and e.voided = 0 and e.encounter_datetime = (select max(enc.encounter_datetime) 
			                          from encounter enc where enc.encounter_type IN (52) 
			                          and enc.voided = 0 and e.patient_id = enc.patient_id);
EOF


	(max_hiv_staging_encounter || []).each do |patient|
		puts "Working on patient_id: #{patient["patient_id"].to_i}"

		update_encounter(patient['patient_id'].to_i, patient['encounter_id'].to_i)
		
		puts "Finished working on patient_id: #{patient["patient_id"].to_i}"
	end

end

def update_flat_tables(patient_id, encounter_id, obs_datetime, reason_for_starting)
	#update flat_table1
	          Connection.execute <<EOF
UPDATE flat_table1 set reason_for_eligibility = '#{reason_for_starting}', reason_for_eligibility_enc_id = #{encounter_id}, reason_for_eligibility_v_date = '#{obs_datetime}' 
	WHERE patient_id = #{patient_id};
EOF

	#update_flat_cohort_table
          Connection.execute <<EOF
UPDATE flat_cohort_table set reason_for_starting = '#{reason_for_starting}', reason_for_starting_v_date = '#{obs_datetime}' 
	WHERE patient_id = #{patient_id};
EOF
end

def update_encounter(patient_id, encounter_id)
		#update the date_changed in encounters_table
          Connection.execute <<EOF
UPDATE encounter set date_changed = NOW(), changed_by = 1
	WHERE encounter_id = #{encounter_id}
	AND patient_id = #{patient_id};
EOF
end

def update_tb_with_the_last_2_yrs(patient_id, encounter_id, obs_datetime, concept_id, name)
		#update flat_table1
		if concept_id == 2743
	          Connection.execute <<EOF
UPDATE flat_table1 set pulmonary_tuberculosis_last_2_years = 'Yes', pulmonary_tuberculosis_last_2_years_enc_id = #{encounter_id}, pulmonary_tuberculosis_last_2_years_v_date = '#{obs_datetime}' 
	WHERE patient_id = #{patient_id};
EOF
		else
				    Connection.execute <<EOF
UPDATE flat_table1 set pulmonary_tuberculosis_last_2_years = '#{name}', pulmonary_tuberculosis_last_2_years_enc_id = #{encounter_id}, pulmonary_tuberculosis_last_2_years_v_date = '#{obs_datetime}' 
	WHERE patient_id = #{patient_id};
EOF
		end

	#update_flat_cohort_table
		if concept_id == 2743
	          Connection.execute <<EOF
UPDATE flat_cohort_table set pulmonary_tuberculosis_last_2_years = 'Yes', pulmonary_tuberculosis_last_2_years_v_date = '#{obs_datetime}'
	WHERE patient_id = #{patient_id};
EOF
		else
				    Connection.execute <<EOF
UPDATE flat_cohort_table set pulmonary_tuberculosis_last_2_years = '#{name}', pulmonary_tuberculosis_last_2_years_v_date = '#{obs_datetime}'
	WHERE patient_id = #{patient_id};
EOF
		end
end

start