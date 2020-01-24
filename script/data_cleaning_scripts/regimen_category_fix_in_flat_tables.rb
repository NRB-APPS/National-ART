#adding/updating regimen categpry observation to the dispensing encounter

def start
	#get all patients that have dispensing encounter
	patient_arvs_dispensing_visits =  ActiveRecord::Base.connection.select_all <<EOF
		select patient_id, visit_date, regimen_category, regimen_category_dispensed, regimen_category_treatment
		from flat_table2
		where regimen_category is null
		group by patient_id, visit_date;
EOF

	(patient_arvs_dispensing_visits || []).each do |patient|
		patients_per_visit = ActiveRecord::Base.connection.select_all <<EOF
			SELECT e.patient_id, DATE(e.encounter_datetime) as visit_date, patient_current_regimen(e.patient_id, DATE(e.encounter_datetime)) AS regimen_category  
			FROM encounter e 
			 inner join orders o on o.patient_id = e.patient_id 
			 inner join drug_order d on d.order_id = o.order_id 
			WHERE e.encounter_type IN (54, 25)
			AND e.voided = 0 AND e.patient_id = #{patient['patient_id'].to_i} AND DATE(e.encounter_datetime) = '#{patient['visit_date']}'
			AND drug_inventory_id IN (select * from arv_drug)
			GROUP BY e.patient_id, DATE(e.encounter_datetime);
EOF
		
		if patients_per_visit
			(patients_per_visit || []).each do |visit_date|
				puts "working on patient_id: #{visit_date['patient_id'].to_i} on visit_date: #{visit_date['visit_date']}"
				
				update_regimen_category(visit_date['patient_id'].to_i, visit_date['visit_date'], visit_date['regimen_category'])
				
				puts "Finished working on patient_id: #{visit_date['patient_id'].to_i} on visit_date: #{visit_date['visit_date']}"

			end
	  end
			
	end
end

def update_regimen_category(patient_id, visit_date, regimen_category)
	#update flat_table2
	ActiveRecord::Base.connection.execute <<EOF
		UPDATE flat_table2 set regimen_category = '#{regimen_category}'
		WHERE patient_id = #{patient_id}
		AND visit_date = '#{visit_date}';
EOF
end

start