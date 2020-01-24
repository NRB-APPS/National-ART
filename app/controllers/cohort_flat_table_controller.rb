class CohortFlatTableController < ApplicationController


  def get_cumulative_data
    results = []
    outcomes = []

    start_date = '1900-01-01'.to_date
    end_date = params[:end_date].to_date

    cohort = FlatTablesCohort.get_indicators(start_date, end_date)

    cummulative = ActiveRecord::Base.connection.select_all <<EOF
    SELECT * FROM flat_cohort_table WHERE date_enrolled 
    BETWEEN '#{start_date}' AND '#{end_date}';
EOF

    all_female_patients = []
    (cummulative || []).each do |patient|
      if patient['gender'] == 'F' || patient['Female']
        all_female_patients << patient['patient_id'].to_i
      end
    end

    registered = [] ; transfer_ins_preg_women = []; pregnant_females1 = []; pregnant_females2 = []
    all_pregnant_females = []

    flat_table1_patient_pregnant = ActiveRecord::Base.connection.select_all <<EOF
      select * from temp_flat_table1_patient_pregnant
      where (patient_pregnant = 'Yes' or pregnant_at_initiation = 'Yes')
      and date_enrolled BETWEEN '#{start_date}' AND '#{end_date}'
      and gender = 'F'
      and (( date(patient_pregnant_v_date) = date(earliest_start_date)) or ( date(pregnant_at_initiation_v_date) = date(earliest_start_date))) ;
EOF

    flat_table2_patient_pregnant = ActiveRecord::Base.connection.select_all <<EOF
      select * from temp_flat_table2_patient_pregnant
      where date(visit_date) = date(earliest_start_date)
      and date_enrolled BETWEEN '#{start_date}' AND '#{end_date}'
      and patient_pregnant = 'Yes' and gender = 'F'
      group by patient_id;
EOF

    pregnant_at_initiation = ActiveRecord::Base.connection.select_all <<EOF
      SELECT patient_id, date_enrolled, earliest_start_date, reason_for_starting
      FROM flat_cohort_table
      WHERE reason_for_starting = 'Patient pregnant' AND gender = 'F'
      AND (date_enrolled BETWEEN '#{start_date}' AND '#{end_date}');
EOF
    pregnant_at_initiation_ids = []
    (pregnant_at_initiation || []).each do |patient|
      pregnant_at_initiation_ids << patient['patient_id'].to_i
    end

    if pregnant_at_initiation_ids.blank?
      pregnant_at_initiation_ids = [0]
    end    

    transfer_ins_women = ActiveRecord::Base.connection.select_all <<EOF
      SELECT patient_id, date_enrolled, patient_re_initiated FROM flat_cohort_table
      WHERE date_enrolled  BETWEEN '#{start_date}' AND '#{end_date}'
      AND (gender = 'F' OR gender = 'Female') AND DATE(date_enrolled) != DATE(earliest_start_date)
      AND date_enrolled <> '0000-00-00' AND patient_id IN (#{pregnant_at_initiation_ids.join(',')})
      AND patient_re_initiated != 'Re-initiated'
      GROUP BY patient_id
EOF

    (transfer_ins_women || []).each do |patient|
      if patient['patient_id'].to_i != 0
        transfer_ins_preg_women << patient['patient_id'].to_i
      end
    end

    (transfer_ins_women || []).each do |patient|
      if patient['patient_id'].to_i != 0
        transfer_ins_preg_women << patient['patient_id'].to_i
      end
    end

    (flat_table1_patient_pregnant || []).each do |patient|
      if patient['patient_id'].to_i != 0
        pregnant_females1 << patient['patient_id'].to_i
      end
    end
 
    (flat_table2_patient_pregnant || []).each do |patient|
      if patient['patient_id'].to_i != 0
        pregnant_females2 << patient['patient_id'].to_i
      end
    end

    all_pregnant_females = (pregnant_females1 + pregnant_females2 + transfer_ins_preg_women).uniq

    #non pregnant female
    non_pregnant_females = []
    non_pregnant_females = all_female_patients - all_pregnant_females


    (cummulative || []).each do |c|
      this_pregnant_patient       = ""
      all_pregnant_females.select do |preg|
        if preg == c['patient_id'].to_i
          this_pregnant_patient = "Yes"
        end
      end

      this_non_pregnant_pregnant  = ""
      non_pregnant_females.select do |not_preg|
        if not_preg == c['patient_id'].to_i
          non_pregnant_females = "Yes"
        end
      end

      results << {
        :patient_id                                     =>  c['patient_id'].to_i,
        :date_enrolled                                  =>  c['date_enrolled'].to_date,
        :earliest_start_date                            =>  (c['earliest_start_date'].to_date rescue nil),
        :gender                                         =>  c['gender'],
        :birthdate                                      =>  (c['birthdate'].to_date rescue nil),
        :age_at_initiation                              =>  c['age_at_initiation'],
        :age_in_days                                    =>  c['age_in_days'],
        :patient_pregnant                               =>  this_pregnant_patient,
        :patient_not_pregnant                           =>  non_pregnant_females,
        :reason_for_starting                            =>  c['reason_for_starting'],
        :who_stages_criteria_present                    =>  c['who_stages_criteria_present'],
        :re_initiated                                   =>  c['patient_re_initiated'],
        :kaposis_sarcoma                                =>  c['kaposis_sarcoma'],
        :extrapulmonary_tuberculosis                    =>  c['extrapulmonary_tuberculosis'],
        :pulmonary_tuberculosis                         =>  c['pulmonary_tuberculosis'],
        :pulmonary_tuberculosis_last_2_years            =>  c['pulmonary_tuberculosis_last_2_years'],
        :who_stages_criteria_present_v_date             =>  (c['who_stages_criteria_present_v_date'].to_date rescue nil),
        :kaposis_sarcoma_v_date                         =>  (c['kaposis_sarcoma_v_date'].to_date rescue nil),
        :extrapulmonary_tuberculosis_v_date             =>  (c['extrapulmonary_tuberculosis_v_date'].to_date rescue nil),
        :pulmonary_tuberculosis_v_date                  =>  (c['pulmonary_tuberculosis_v_date'].to_date rescue nil),
        :pulmonary_tuberculosis_last_2_years_v_date     =>  (c['pulmonary_tuberculosis_last_2_years_v_date'].to_date rescue nil)
      }
    end
    
    render :text => results.to_json
  end

  def get_patient_outcomes
    outcomes = []

    start_date = '1900-01-01'.to_date
    end_date = params[:end_date].to_date
   
    patient_outcomes = ActiveRecord::Base.connection.select_all <<EOF
      SELECT fct.patient_id, fct.date_enrolled, fct.earliest_start_date, fct.death_date, fct.age_at_initiation, fct.age_in_days, po.*, flat_patient_died_in(fct.patient_id, po.cum_outcome, fct.date_enrolled) died_in
      FROM temp_flat_tables_patient_outcomes po
        LEFT JOIN flat_cohort_table fct on fct.patient_id = po.patient_id;
EOF

    (patient_outcomes || []).each do |outcome|
      outcomes << {
        :patient_id               => outcome['patient_id'].to_i,
        :cum_outcome              => outcome['cum_outcome'],
        :date_enrolled            => (outcome['date_enrolled'].to_date rescue nil),
        :earliest_start_date      => (outcome['earliest_start_date'].to_date rescue nil),
        :death_date               => (outcome['death_date'].to_date rescue nil),
        :age_at_initiation        => outcome['age_at_initiation'],
        :age_in_days              => outcome['age_in_days'],
        :died_in                  => outcome['died_in']

      }
    end

    render :text => outcomes.to_json
  end


  def get_patients_cpt_ipt_pfip_and_bp_screen
    outcomes = []
    cpt_names = []
    ipt_names = []

    start_date = params[:start_date].to_date
    end_date = params[:end_date].to_date
   
    alive_on_art = ActiveRecord::Base.connection.select_all <<EOF
      SELECT po.patient_id, po.cum_outcome, fct.date_enrolled, fct.earliest_start_date, fct.age_at_initiation, fct.age_in_days, fct.gender
      FROM temp_flat_tables_patient_outcomes po
       INNER JOIN flat_cohort_table fct on fct.patient_id = po.patient_id
      WHERE cum_outcome = 'On antiretrovirals';
EOF
    patients_on_art = []
    (alive_on_art || []).each do |patient|
      patients_on_art << patient['patient_id'].to_i
    end

    cpt = ActiveRecord::Base.connection.select_all <<EOF
      SELECT name as cpt_name FROM openmrs_matiki.drug where name like '%Cotrimoxazole%';
EOF

    (cpt || []).each do |cpt|
      cpt_names << cpt["cpt_name"]
    end
  

    ipt = ActiveRecord::Base.connection.select_all <<EOF
      SELECT name AS ipt_name FROM drug where name like '%Isoniazid%' or name like '%Pyridoxine%';
EOF

    (ipt || []).each do |ipt_name|
      ipt_names << ipt_name["ipt_name"]
    end

  #CPT
  cpt_patients_ids_in_quarter = []
  cpt_patients_in_quarter = ActiveRecord::Base.connection.select_all <<EOF
      SELECT  fct.patient_id, ft2.visit_date, fct.date_enrolled, ft2.drug_name1, ft2.drug_name2, ft2.drug_name3, ft2.drug_name4, ft2.drug_name5, ft2.drug_quantity1, ft2.drug_quantity2, ft2.drug_quantity3, ft2.drug_quantity4, ft2.drug_quantity5
      FROM flat_cohort_table fct
        INNER JOIN flat_table2 ft2 ON ft2.patient_id = fct.patient_id
      WHERE (ft2.drug_name1 like '%Cotrimoxazole%' OR ft2.drug_name2 like '%Cotrimoxazole%' OR ft2.drug_name3 like '%Cotrimoxazole%' OR ft2.drug_name4 like '%Cotrimoxazole%' OR ft2.drug_name5 like '%Cotrimoxazole%')
      AND (ft2.visit_date BETWEEN '#{start_date}' AND '#{end_date}')
      AND fct.patient_id IN (#{patients_on_art.join(',')})
      AND visit_date = (SELECT max(visit_date) FROM flat_table2 f2
      WHERE f2.patient_id = ft2.patient_id
      AND f2.visit_date BETWEEN '#{start_date}' AND '#{end_date}'
      AND (f2.drug_name1 LIKE '%Cotrimoxazole%' OR f2.drug_name2 LIKE '%Cotrimoxazole%' OR f2.drug_name3 LIKE '%Cotrimoxazole%' OR f2.drug_name4 LIKE '%Cotrimoxazole%' OR f2.drug_name5 LIKE '%Cotrimoxazole%')
      AND (f2.drug_quantity1 IS NOT NULL OR f2.drug_quantity2 IS NOT NULL OR f2.drug_quantity3 IS NOT NULL OR f2.drug_quantity4 IS NOT NULL OR f2.drug_quantity5 IS NOT NULL))
      GROUP BY fct.patient_id;
EOF
    (cpt_patients_in_quarter || []).each do |patient|
      if cpt_names.include?(patient["drug_name1"]) && patient["drug_quantity1"].to_i != 0
        cpt_patients_ids_in_quarter << patient["patient_id"].to_i
      end

      if cpt_names.include?(patient["drug_name2"]) && patient["drug_quantity2"].to_i != 0
        cpt_patients_ids_in_quarter << patient["patient_id"].to_i
      end

      if cpt_names.include?(patient["drug_name3"]) && patient["drug_quantity3"].to_i != 0
        cpt_patients_ids_in_quarter << patient["patient_id"].to_i
      end

      if cpt_names.include?(patient["drug_name4"]) && patient["drug_quantity4"].to_i != 0
        cpt_patients_ids_in_quarter << patient["patient_id"].to_i
      end

      if cpt_names.include?(patient["drug_name5"]) && patient["drug_quantity5"].to_i != 0
        cpt_patients_ids_in_quarter << patient["patient_id"].to_i
      end
    end

    cpt_patient_in_q_percent = (((cpt_patients_ids_in_quarter.count).to_f / (patients_on_art.count).to_f) *100).to_i rescue 0

    #IPT
    ipt_patients_ids_in_quarter = []
    ipt_patients_in_quarter = ActiveRecord::Base.connection.select_all <<EOF
      SELECT fct.patient_id, ft2.visit_date, fct.date_enrolled, ft2.drug_name1, ft2.drug_name2, ft2.drug_name3, ft2.drug_name4, ft2.drug_name5, ft2.drug_quantity1, ft2.drug_quantity2, ft2.drug_quantity3, ft2.drug_quantity4, ft2.drug_quantity5
      FROM flat_cohort_table fct INNER JOIN flat_table2 ft2 ON ft2.patient_id = fct.patient_id
      WHERE ((ft2.drug_name1 like '%Isoniazid%' OR ft2.drug_name1 like '%Pyridoxine%') OR (ft2.drug_name2 like '%Isoniazid%' OR ft2.drug_name2 like '%Pyridoxine%')
      OR (ft2.drug_name3 like '%Isoniazid%' OR ft2.drug_name3 like '%Pyridoxine%') OR (ft2.drug_name4 like '%Isoniazid%' OR ft2.drug_name4 like '%Pyridoxine%')
      OR (ft2.drug_name5 like '%Isoniazid%' OR ft2.drug_name5 like '%Pyridoxine%')) 
      AND (ft2.visit_date BETWEEN '#{start_date}' AND '#{end_date}')
      AND fct.patient_id IN (#{patients_on_art.join(',')})
      AND ft2.visit_date = (SELECT max(f2.visit_date) FROM flat_table2 f2
      WHERE f2.patient_id = ft2.patient_id
      AND f2.visit_date BETWEEN '#{start_date}' AND '#{end_date}'
      AND ((f2.drug_name1 like '%Isoniazid%' OR f2.drug_name1 like '%Pyridoxine%') OR (f2.drug_name2 like '%Isoniazid%' OR f2.drug_name2 like '%Pyridoxine%')
      OR (f2.drug_name3 like '%Isoniazid%' OR f2.drug_name3 like '%Pyridoxine%') OR (f2.drug_name4 like '%Isoniazid%' OR f2.drug_name4 like '%Pyridoxine%')
      OR (f2.drug_name5 like '%Isoniazid%' OR f2.drug_name5 like '%Pyridoxine%'))
      AND (f2.drug_quantity1 IS NOT NULL OR f2.drug_quantity2 IS NOT NULL OR f2.drug_quantity3 IS NOT NULL OR f2.drug_quantity4 IS NOT NULL OR f2.drug_quantity5 IS NOT NULL))
      GROUP BY fct.patient_id;
EOF

    (ipt_patients_in_quarter || []).each do |patient|
      if ipt_names.include?(patient["drug_name1"]) && patient["drug_quantity1"].to_i != 0
        ipt_patients_ids_in_quarter << patient["patient_id"].to_i
      end

      if ipt_names.include?(patient["drug_name2"]) && patient["drug_quantity2"].to_i != 0
        ipt_patients_ids_in_quarter << patient["patient_id"].to_i
      end

      if ipt_names.include?(patient["drug_name3"]) && patient["drug_quantity3"].to_i != 0
        ipt_patients_ids_in_quarter << patient["patient_id"].to_i
      end

      if ipt_names.include?(patient["drug_name4"]) && patient["drug_quantity4"].to_i != 0
        ipt_patients_ids_in_quarter << patient["patient_id"].to_i
      end

      if ipt_names.include?(patient["drug_name5"]) && patient["drug_quantity5"].to_i != 0
        ipt_patients_ids_in_quarter << patient["patient_id"].to_i
      end
    end

    ipt_patients_ids_in_quarter.uniq! unless ipt_patients_ids_in_quarter.blank?
      
    ipt_patient_in_q_percent = (((ipt_patients_ids_in_quarter.count).to_f / (patients_on_art.count).to_f) *100).to_i rescue 0

    #PIFP
    female_patients = []
    (alive_on_art || []).each do |patient|
      if patient['gender'] == 'F'
        if patient['date_enrolled'].to_date >= start_date && patient['date_enrolled'].to_date <= end_date
          female_patients << patient['patient_id'].to_i
        end
      end
    end

    family_planning_ids_in_quarter = []
    family_planning_ids = ActiveRecord::Base.connection.select_all <<EOF
      SELECT ft2.patient_id, ft2.visit_date, ft2.family_planning_method, ft2.currently_using_family_planning_method
      FROM flat_table2 ft2 
      WHERE (ft2.family_planning_method NOT IN ('None', 'No', 'Unknown')
      OR ft2.currently_using_family_planning_method NOT IN ('None', 'No', 'Unknown'))
      AND (ft2.visit_date BETWEEN '#{start_date}' AND '#{end_date}')
      AND ft2.patient_id IN (#{female_patients.join(',')})
      AND visit_date = (SELECT max(f2.visit_date) FROM flat_table2 f2
      WHERE f2.patient_id = ft2.patient_id
      AND f2.visit_date BETWEEN '#{start_date}' AND '#{end_date}'
      AND (f2.family_planning_method IS NOT NULL
      OR ft2.currently_using_family_planning_method IS NOT NULL))
      GROUP BY ft2.patient_id;
EOF
    
    (family_planning_ids || []).each do |patient|
      family_planning_ids_in_quarter << patient["patient_id"].to_i
    end

    family_palnning_quarter = (((family_planning_ids_in_quarter.count).to_f / (female_patients.count).to_f) *100).to_i rescue 0

    #BP screen
    bp_screen_patients_ids_in_quarter = []
    bp_screen_patients  = ActiveRecord::Base.connection.select_all <<EOF
      SELECT fct.patient_id, ft2.visit_date, fct.date_enrolled
      FROM flat_cohort_table fct
      INNER JOIN flat_table2 ft2 ON ft2.patient_id = fct.patient_id
      WHERE ft2.systolic_blood_pressure IS NOT NULL and ft2.systolic_blood_pressure IS NOT NULL
      AND (ft2.visit_date <= '#{end_date}')
      AND fct.patient_id IN (#{patients_on_art.join(',')})
      AND ft2.visit_date = (SELECT max(f2.visit_date) FROM flat_table2 f2
      WHERE f2.systolic_blood_pressure IS NOT NULL and f2.systolic_blood_pressure IS NOT NULL
      AND f2.patient_id = ft2.patient_id
      AND f2.visit_date <= '#{end_date}')
      GROUP BY fct.patient_id;
EOF
    
    (bp_screen_patients || []).each do |patient|
      bp_screen_patients_ids_in_quarter << patient["patient_id"].to_i
    end
    bp_screen_patients_percent = (((bp_screen_patients_ids_in_quarter.count).to_f / (patients_on_art.count).to_f) *100).to_i rescue 0

    results = []

    results << {
      :cpt_usage_percent =>  "#{cpt_patient_in_q_percent} %",
      :ipt_usage_percent =>  "#{ipt_patient_in_q_percent} %",
      :family_planning   =>  "#{family_palnning_quarter} %",
      :bp_screening      =>  "#{bp_screen_patients_percent} %",
      :cpt_ids => cpt_patients_ids_in_quarter,
      :ipt_ids => ipt_patients_in_quarter,
      :pfip_ids => family_planning_ids_in_quarter,
      :bp_screen_ids => bp_screen_patients_ids_in_quarter
    }
    
    render :text => results.to_json
  end

  def get_total_pregnant_and_breastfeeding
    patients_on_art   = []
    pregnant_females  = []
    female_patients   = []

    start_date = params[:start_date].to_date
    end_date   = params[:end_date].to_date

    alive_on_art = ActiveRecord::Base.connection.select_all <<EOF
      SELECT po.patient_id, po.cum_outcome FROM temp_flat_tables_patient_outcomes po WHERE cum_outcome = 'On antiretrovirals';
EOF

    (alive_on_art || []).each do |patient|
      patients_on_art << patient['patient_id'].to_i
    end

    pregnant_women = ActiveRecord::Base.connection.select_all <<EOF
      SELECT fct.patient_id, ft2.visit_date, ft2.patient_pregnant
      FROM flat_cohort_table fct
      INNER JOIN flat_table2 ft2 ON ft2.patient_id = fct.patient_id
      WHERE ft2.patient_pregnant = 'Yes' AND ft2.patient_pregnant IS NOT NULL
      AND (ft2.visit_date <= '#{end_date}')
      AND fct.patient_id IN (#{patients_on_art.join(',')})
      AND ft2.visit_date = (SELECT max(visit_date) from flat_table2 f2
      WHERE f2.patient_id = ft2.patient_id
      AND f2.visit_date <= '#{end_date}'
      AND f2.patient_pregnant IS NOT NULL)
      GROUP BY fct.patient_id;
EOF

    (pregnant_women || []).each do |patient|
      pregnant_females << patient['patient_id'].to_i
    end

    breastfeeding_women = ActiveRecord::Base.connection.select_all <<EOF
      SELECT fct.patient_id, ft2.visit_date, ft2.patient_breastfeeding
      FROM flat_cohort_table fct
      INNER JOIN flat_table2 ft2  ON ft2.patient_id = fct.patient_id
      WHERE ft2.patient_breastfeeding = 'Yes' AND ft2.patient_breastfeeding IS NOT NULL
      AND (ft2.visit_date <= '#{end_date}')
      AND fct.patient_id IN (#{patients_on_art.join(',')})
      AND fct.patient_id NOT IN (#{pregnant_females.join(',')})
      AND ft2.visit_date = (SELECT max(visit_date) from flat_table2 f2
      WHERE f2.patient_id = fct.patient_id
      AND f2.visit_date <= '#{end_date}'
      AND f2.patient_breastfeeding IS NOT NULL)
      GROUP BY fct.patient_id;
EOF
    
    breastfeeding_females = []
    (breastfeeding_women || []).each do |patient|
      breastfeeding_females << patient['patient_id'].to_i
    end

    #total_other_patients
    total_other_patients = []
    total_other_patients = (patients_on_art - (pregnant_females + breastfeeding_females))

    (patients_on_art || []).each do |patient|

      #pregnant
      this_patient_pregnant = ""
      pregnant_women.select do |r|
        if(r['patient_id'].to_i == patient)
          this_patient_pregnant = r['patient_pregnant']
        end
      end

      #breastfeeding_women
      this_patient_breastfeeding = ""
      breastfeeding_women.select do |r| 
        if(r['patient_id'].to_i == patient)
          this_patient_breastfeeding = r['patient_breastfeeding']
        end
      end

      #total_other_patients
      this_other_patient = ""
      total_other_patients.select do |patient_id|
        if (patient_id == patient)
          this_other_patient = "Other Patient"
        end
      end

      female_patients << {
        :patient_id                 =>  patient,
        :patient_pregnant           =>  this_patient_pregnant,
        :patient_breastfeeding      =>  this_patient_breastfeeding,
        :other_patient              =>  this_other_patient}
    end

    render :text => female_patients.to_json
  end

  def get_patients_alive_and_ART_details
    patients_on_art = []
    patients_alive_and_ART_details = []

    end_date = params[:end_date].to_date
   
    alive_on_art = ActiveRecord::Base.connection.select_all <<EOF
      SELECT po.patient_id, po.cum_outcome FROM temp_flat_tables_patient_outcomes po WHERE cum_outcome = 'On antiretrovirals';
EOF
    
    (alive_on_art || []).each do |patient|
      patients_on_art << patient['patient_id'].to_i
    end

    #Regimen category
    regimens = ActiveRecord::Base.connection.select_all <<EOF
        SELECT f2.patient_id, f2.visit_date, f2.regimen_category_dispensed, f2.regimen_category, f2.regimen_category_treatment
        FROM flat_table2 f2
        WHERE f2.patient_id IN (#{patients_on_art.join(',')})
        AND f2.visit_date <= '#{end_date}' 
        AND visit_date = (SELECT max(ft2.visit_date) FROM flat_table2 ft2 WHERE ft2.patient_id = f2.patient_id AND ft2.visit_date <= '#{end_date}' AND ft2.regimen_category is not null)
        GROUP BY f2.patient_id;
EOF

    #Patient Adherence
    adherence = ActiveRecord::Base.connection.select_all <<EOF
        SELECT f2.patient_id, f2.visit_date, f2.patient_art_adherence
        FROM flat_table2 f2
        WHERE f2.patient_id IN (#{patients_on_art.join(',')})
        AND f2.visit_date <= '#{end_date}' 
        AND visit_date = (SELECT max(ft2.visit_date) FROM flat_table2 ft2 WHERE ft2.patient_id = f2.patient_id AND ft2.visit_date <= '#{end_date}' AND ft2.patient_art_adherence is not null)
        GROUP BY f2.patient_id;
EOF

    #TB status
    tb_status = ActiveRecord::Base.connection.select_all <<EOF
        SELECT f2.patient_id, f2.visit_date, f2.tb_status, f2.tb_status_enc_id
        FROM flat_table2 f2
        WHERE f2.patient_id IN (#{patients_on_art.join(',')})
        AND f2.visit_date <= '#{end_date}'
        AND visit_date = (SELECT max(ft2.visit_date) FROM flat_table2 ft2 WHERE ft2.patient_id = f2.patient_id AND ft2.visit_date <= '#{end_date}' AND ft2.tb_status is not null)
        GROUP BY f2.patient_id;
EOF

    #Side Effects
    side_effects = ActiveRecord::Base.connection.select_all <<EOF
        SELECT f2.patient_id, f2.visit_date, fct.earliest_start_date, fct.date_enrolled, f2.side_effects_present, f2.side_effects_present_enc_id

        FROM flat_table2 f2
          INNER JOIN flat_cohort_table fct ON fct.patient_id = f2.patient_id
        WHERE (f2.patient_id IN (#{patients_on_art.join(',')}))
        AND f2.visit_date <= '#{end_date}'
        AND f2.visit_date = (SELECT max(ft2.visit_date) FROM flat_table2 ft2 
                             WHERE ft2.patient_id = f2.patient_id AND ft2.visit_date <= '#{end_date}' 
                             AND ft2.side_effects_present is not null)
        GROUP BY f2.patient_id;
EOF

    (alive_on_art || []).each do |patient|
      #regimen
      this_patient_regimen = ""
      regimens.select do |r| 
        if(r['patient_id'].to_i == patient['patient_id'].to_i)
          this_patient_regimen = r['regimen_category']
        end
      end

      #tb_status
      this_patient_tb_status = ""
      tb_status.select do |t| 
        if(t['patient_id'].to_i == patient['patient_id'].to_i)
          this_patient_tb_status = t['tb_status']
        end
      end

      #side_effects
      this_patient_side_effects        = ""
      this_patient_date_enrolled       = ""
      this_patient_earliest_start_date = ""
      this_patient_visit_date          = ""

      side_effects.select do |s|
        if(s['patient_id'].to_i == patient['patient_id'].to_i)
          this_patient_side_effects         = s['side_effects_present']
          this_patient_date_enrolled        = s['date_enrolled']
          this_patient_earliest_start_date  = s['earliest_start_date']
          this_patient_visit_date           = s['earliest_start_date']
        end
      end

      #patient Adherence
      this_patient_adherence           = ""

      adherence.select do |a|
        if(a['patient_id'].to_i == patient['patient_id'].to_i)
          this_patient_adherence = a['patient_art_adherence']
        end
      end

      patients_alive_and_ART_details << {
        :patient_id             =>  patient['patient_id'].to_i,
        :regimen_category       =>  this_patient_regimen,
        :tb_status              =>  this_patient_tb_status,
        :date_enrolled          =>  (this_patient_date_enrolled.to_date rescue nil),
        :earliest_start_date    =>  (this_patient_earliest_start_date.to_date rescue nil),
        :visit_date             =>  (this_patient_visit_date.to_date rescue nil),
        :patient_side_effect    =>  this_patient_side_effects,
        :patient_art_adherence  =>  this_patient_adherence
      }
    end

    render :text => patients_alive_and_ART_details.to_json

  end

end
