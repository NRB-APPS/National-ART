#who_stages_criteria_present fix in flat_tables

Connection = ActiveRecord::Base.connection

def start
	#get all patients_ids
	who_stages_criteria_present_patients=  Connection.select_all <<EOF
		select ft1.patient_id, fct.who_stages_criteria_present as ftc_value, ft1.who_stages_criteria_present as ft1_value from flat_table1 ft1
		 inner join flat_cohort_table fct on fct.patient_id = ft1.patient_id
		where ft1.who_stages_criteria_present <> fct.who_stages_criteria_present;
EOF

	(who_stages_criteria_present_patients || []).each do |patient|
		puts "Working on patient_id: #{patient["patient_id"].to_i}"

		update_flat_cohort_table(patient['patient_id'].to_i, patient['ftc_value'], patient['ft1_value'])
		
		puts "Finished working on patient_id: #{patient["patient_id"].to_i}"
	end
end

def update_flat_cohort_table(patient_id, ftc_value, ft1_value)
		#update the date_changed in encounters_table
          Connection.execute <<EOF
UPDATE flat_cohort_table set who_stages_criteria_present = '#{ft1_value}'
	WHERE patient_id = #{patient_id};
EOF

end

start