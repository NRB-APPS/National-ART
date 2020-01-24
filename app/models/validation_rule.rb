class ValidationRule < ActiveRecord::Base
  has_many :validation_results
  @dispensed_id = ConceptName.find_by_name('PILLS DISPENSED').concept_id

  def self.rules_xy
    rules = []

    self.find_by_sql("SELECT * FROM validation_rules").each do |rule|
      rules << rule.expr.scan(/\{\w+\}/).collect{|xpr| xpr.gsub(/\{|\}/, "")}
    end
    rules.flatten.uniq
  end

  def self.data_consistency_checks(date = Date.today)
    date = date.to_date
    time = Time.now
    # require 'colorize'
    data_consistency_checks = {}
    #All methods for now should be here:
    data_consistency_checks['Patients without outcomes'] = "self.patients_without_outcomes(date)"
    data_consistency_checks['Patients with pills remaining greater than dispensed'] = "self.pills_remaining_over_dispensed(date)"
    data_consistency_checks['Patients without reason for starting'] = "self.validate_presence_of_start_reason(date)"
    data_consistency_checks['Patients with missing dispensations'] = "self.prescrition_without_dispensation(date)"
    data_consistency_checks['Patients with missing prescriptions'] = "self.dispensation_without_prescription(date)"
    data_consistency_checks['Patients with dispensation without appointment'] = "self.dispensation_without_appointment(date)"
    data_consistency_checks['Patients with vitals without weight'] = "self.validate_presence_of_vitals_without_weight(date)"
    data_consistency_checks['Patients with encounters before birth or after death'] = "self.death_date_less_than_last_encounter_date_and_less_than_date_of_birth(date)"
    data_consistency_checks['Patients with encounters without obs or orders'] = "self.encounters_without_obs_or_orders(date)"
    data_consistency_checks['Patients with ART start date before birth'] = "self.start_date_before_birth(date)"
    data_consistency_checks['Dead patients with follow up visits'] = "self.visit_after_death(date)"
    data_consistency_checks['Male patients with pregnant observations'] = "self.male_patients_with_pregnant_observation(date)"
    data_consistency_checks['Male patients with breastfeeding observations'] = "self.male_patients_with_breastfeeding_obs(date)"
    data_consistency_checks['Male patients with family planning methods obs'] = "self.male_patients_with_family_planning_methods_obs(date)"
    data_consistency_checks['ART patients without HIV clinic registration encounter'] = "self.check_every_ART_patient_has_HIV_Clinical_Registration(date)"
    data_consistency_checks['Under 18 patients without height and weight in visit'] = "self.every_visit_of_patients_who_are_under_18_should_have_height_and_weight(date)"
    data_consistency_checks['Patients with outcomes without date'] = "self.every_outcome_needs_a_date(date)"
    data_consistency_checks['Patients without gender'] = "self.patients_without_gender(date)"
    data_consistency_checks['Pre-ART patients with ARV drugs'] = "self.pre_art_patients_with_arv_drugs(date)"
    data_consistency_checks['Patients with treatment encounters without orders'] = "self.patients_with_treatment_encounter_without_orders(date)"
    data_consistency_checks['Patients with encounters without observations'] = "self.patients_with_encounters_without_observations(date)"
    data_consistency_checks['Patients without birthdate'] = "self.patients_without_birthdate(date)"
    data_consistency_checks['Patients with first visit greater than birthdate'] = "self.first_visit_date_greater_than_birthdate(date)"
    data_consistency_checks['Patients with death_date less than last visit date'] = "self.death_date_less_than_last_visit_date(date)"
		
    data_consistency_checks = data_consistency_checks.keys.inject({}){|hash, key| 
      time = Time.now
      puts "Running query for #{key}"
      hash[key] = eval(data_consistency_checks[key])
      period = (Time.now - time).to_i
     
      color = hash[key].length > 0 ? "red" : "green"
      eval("puts 'Time taken  :  #{(period/60).to_i} min  and #{(period % 60)} sec  --> #{hash[key].length} patient(s) found'.#{color}")
      puts ""	
      hash
    }
		
      set_rules = self.find(:all,:conditions =>['type_id = 2'])     

      (set_rules || []).each do |rule|                                            
         unless data_consistency_checks[rule.desc].blank?                          
           create_update_validation_result(rule, time, data_consistency_checks[rule.desc])
        end                                                                       
      end                                                                         
                                                                                
    return data_consistency_checks
  end

  def self.create_update_validation_result(rule, date, patient_ids)

    #We substitute mysql with couch DB for storing results
    file = "#{Rails.root}/config/couchdb_config.yml"
    couchdb_details = YAML.load(File.read(file))
    data = {
      "date_checked" => date.strftime("%Y%m%d%H%M%S"),
      "rule" => rule.desc,
      "site_code" => couchdb_details["site_code"],
      "site_name" => couchdb_details["site_name"],
      "failures" => patient_ids.length
    }
    #raise data['site_name']

    ValidationResult.add_record(data)
  end

  def self.patients_without_outcomes(visit_date)
    visit_date = visit_date.to_date
    connection = ActiveRecord::Base.connection
    art_patient_ids = connection.select_all("SELECT patient_id FROM flat_cohort_table
      WHERE DATE(earliest_start_date) <= '#{visit_date}'").collect{|p|p["patient_id"]}

    art_patient_ids = [-999] if art_patient_ids.blank?

    patient_ids = connection.select_all("SELECT patient_id FROM flat_table2 WHERE
      DATE(visit_date) <= '#{visit_date}' AND patient_id in (#{art_patient_ids.join(',')})
      AND current_hiv_program_state IS NULL OR current_hiv_program_state = ''").collect{|p|p["patient_id"]}
    
   return patient_ids

  end

  def self.pills_remaining_over_dispensed(visit_date=Date.today)


    visit_date = visit_date.to_date rescue Date.today
    patient_ids = []
    #art_adherence_enc = EncounterType.find_by_name('ART ADHERENCE').id
    dispensing_enc = EncounterType.find_by_name('DISPENSING').id
    #amount_dispensed_concept = Concept.find_by_name('AMOUNT DISPENSED').id
    amount_brought_to_clinic_concept = Concept.find_by_name('AMOUNT OF DRUG BROUGHT TO CLINIC').id
    
    patients = Patient.find_by_sql("
      SELECT ord.order_id as orderID, enc.patient_id as patient_ID,
      do.quantity as amought_dispensed from encounter enc INNER JOIN obs ON
      enc.encounter_id=obs.encounter_id INNER JOIN orders ord ON ord.order_id=obs.order_id
      AND enc.encounter_type = #{dispensing_enc} INNER JOIN drug_order do ON ord.order_id = do.order_id
      AND enc.voided=0 WHERE do.quantity > 0 AND DATE(enc.encounter_datetime) <= \'#{visit_date}\'
      HAVING  amought_dispensed < (SELECT o.value_numeric  FROM obs o
      WHERE order_id = orderID AND o.concept_id=#{amount_brought_to_clinic_concept} LIMIT 1)
      ")
    patient_ids = patients.collect{|patient|patient["patient_ID"]}

    return patient_ids
  end
  
  def self.validate_presence_of_start_reason(end_date = Date.today)
    #This function checks for patients who do not have a reason for starting ART in flat tables

    patients = Patient.find_by_sql("SELECT patient_id FROM flat_cohort_table WHERE earliest_start_date <= '#{end_date}'
                                    AND COALESCE(TRIM(reason_for_starting), '') = ''").collect{|x| x.patient_id}

  end

  def self.dispensation_without_prescription(end_date = Date.today)

    visit_date = end_date.to_date
    connection = ActiveRecord::Base.connection
    art_patient_ids = connection.select_all("SELECT patient_id FROM flat_cohort_table
      WHERE DATE(earliest_start_date) <= '#{visit_date}'").collect{|p|p["patient_id"]}
    art_patient_ids = [-999] if art_patient_ids.blank?

    patient_ids = connection.select_all("SELECT patient_id FROM flat_table2 WHERE
      DATE(visit_date) <= '#{visit_date}' AND patient_id in (#{art_patient_ids.join(',')})
      AND (
            ((COALESCE(drug_quantity1,0) > 0) AND drug_encounter_id1 IS NULL) OR
            ((COALESCE(drug_quantity2,0) > 0) AND drug_encounter_id2 IS NULL) OR
            ((COALESCE(drug_quantity3,0) > 0) AND drug_encounter_id3 IS NULL) OR
            ((COALESCE(drug_quantity4,0) > 0) AND drug_encounter_id4 IS NULL) OR
            ((COALESCE(drug_quantity5,0) > 0) AND drug_encounter_id5 IS NULL)
          )"
    ).collect{|p|p["patient_id"]}

    return patient_ids

  end

  def self.prescrition_without_dispensation(end_date = Date.today)
    visit_date = end_date.to_date
    connection = ActiveRecord::Base.connection
    art_patient_ids = connection.select_all("SELECT patient_id FROM flat_cohort_table
      WHERE DATE(earliest_start_date) <= '#{visit_date}'").collect{|p|p["patient_id"]}
    art_patient_ids = [-999] if art_patient_ids.blank?

    patient_ids = connection.select_all("SELECT patient_id FROM flat_table2 WHERE
      DATE(visit_date) <= '#{visit_date}' AND patient_id in (#{art_patient_ids.join(',')})
      AND (
            (drug_encounter_id1 IS NOT NULL AND (COALESCE(drug_quantity1,0) = 0)) OR
            (drug_encounter_id2 IS NOT NULL AND (COALESCE(drug_quantity2,0) = 0)) OR
            (drug_encounter_id3 IS NOT NULL AND (COALESCE(drug_quantity3,0) = 0)) OR
            (drug_encounter_id4 IS NOT NULL AND (COALESCE(drug_quantity4,0) = 0)) OR
            (drug_encounter_id5 IS NOT NULL AND (COALESCE(drug_quantity5,0) = 0))
          )"
    ).collect{|p|p["patient_id"]}

    return patient_ids

  end

  def self.dispensation_without_appointment(end_date = Date.today)

    visit_date = end_date.to_date
    connection = ActiveRecord::Base.connection
    art_patient_ids = connection.select_all("SELECT patient_id FROM flat_cohort_table
      WHERE DATE(earliest_start_date) <= '#{visit_date}'").collect{|p|p["patient_id"]}
    art_patient_ids = [-999] if art_patient_ids.blank?

    patient_ids = connection.select_all("SELECT patient_id FROM flat_table2 WHERE
      DATE(visit_date) <= '#{visit_date}' AND patient_id in (#{art_patient_ids.join(',')})
      AND (
            (drug_encounter_id1 IS NOT NULL AND (COALESCE(drug_quantity1,0) > 0) AND appointment_date IS NULL) OR
            (drug_encounter_id2 IS NOT NULL AND (COALESCE(drug_quantity2,0) > 0) AND appointment_date IS NULL) OR
            (drug_encounter_id3 IS NOT NULL AND (COALESCE(drug_quantity3,0) > 0) AND appointment_date IS NULL) OR
            (drug_encounter_id4 IS NOT NULL AND (COALESCE(drug_quantity4,0) > 0) AND appointment_date IS NULL) OR
            (drug_encounter_id5 IS NOT NULL AND (COALESCE(drug_quantity5,0) > 0) AND appointment_date IS NULL)
          )"
    ).collect{|p|p["patient_id"]}

  return patient_ids

  end

  def self.validate_presence_of_vitals_without_weight(date = Date.today)
    # Developer   : Kenneth Kapundi
    # Date        : 3/09/2014 
    # Purpose     : Return Patient IDs for patients having Vitals encounters without weight 
    # Amendments  :

    enc_ids = ["Height_enc_id", "height_for_age_enc_id", "Height",
               "weight_for_height_enc_id", "weight_for_age_enc_id",
               "Temperature_enc_id", "BMI_enc_id",
               "systolic_blood_pressure", "diastolic_blood_pressure"
               ]
    patients_with_vitals_without_weight = ActiveRecord::Base.connection.select_all("SELECT DISTINCT(ft2.patient_id)
                                          FROM flat_table2 ft2
                                          JOIN flat_cohort_table fct ON ft2.patient_id = fct.patient_id
                                          WHERE COALESCE(#{enc_ids.join(',')}) IS NOT NULL
                                          AND (Weight IS NULL OR Weight = '')
                                          AND DATE(ft2.visit_date) = #{date.to_date}").map(&:patient_id)

    return patients_with_vitals_without_weight

  end

  def self.death_date_less_than_last_visit_date(end_date = Date.today)
    # patients with visits after death

    art_patient_ids = connection.select_all("SELECT patient_id FROM flat_cohort_table
      WHERE DATE(earliest_start_date) <= '#{end_date}'").collect{|p|p["patient_id"]}
    art_patient_ids = [-999] if art_patient_ids.blank?

    return ValidationRule.find_by_sql("SELECT 
				    ft2.patient_id,
				    fct.earliest_start_date,
				    fct.birthdate,
				    fct.death_date,
				    ft2.visit_date,
				    DATEDIFF(ft2.visit_date, fct.death_date)
				  FROM
    				    flat_table2 ft2
				        INNER JOIN
				    flat_cohort_table fct ON ft2.patient_id = fct.patient_id
				  WHERE DATEDIFF(ft2.visit_date, fct.death_date) > 0
				  AND DATE(ft2.visit_date) <= '#{end_date.to_date}'
				  GROUP BY ft2.patient_id").map(&:patient_id)
  end

  def self.first_visit_date_greater_than_birthdate(end_date = Date.today)

    #patients with visit_date before birth_date    

    return ValidationRule.find_by_sql("SELECT 
                                    ft2.patient_id,
                                    fct.earliest_start_date,
                                    fct.birthdate,
                                    fct.death_date,
                                    ft2.visit_date,
                                    DATEDIFF(fct.birthdate, ft2.visit_date)
                                  FROM
                                    flat_table2 ft2
                                        INNER JOIN
                                    flat_cohort_table fct ON ft2.patient_id = fct.patient_id
                                  WHERE DATEDIFF(fct.birthdate, ft2.visit_date) > 0
                                  AND DATE(ft2.visit_date) <= '#{end_date.to_date}'
                                  GROUP BY ft2.patient_id").map(&:patient_id)
  end

  def self.death_date_less_than_last_encounter_date_and_less_than_date_of_birth(date = Date.today)

    death_date_less_than_last_enc = ActiveRecord::Base.connection.select_all("
                                    SELECT DISTINCT (ft2.patient_id)
                                    FROM flat_table2 ft2
                                    INNER JOIN flat_cohort_table fct ON ft2.patient_id = fct.patient_id
			                              WHERE DATEDIFF(ft2.visit_date, fct.death_date) > 0
			                              AND DATE(ft2.visit_date) <= #{date.to_date}").map(&:patient_id)

    death_date_less_than_date_of_birth = ActiveRecord::Base.connection.select_all("
                                    SELECT DISTINCT (ft2.patient_id)
                                    FROM flat_table2 ft2
                                    INNER JOIN flat_cohort_table fct ON ft2.patient_id = fct.patient_id
			                              WHERE DATEDIFF(fct.birthdate, ft2.visit_date) > 0
			                              AND DATE(ft2.visit_date) <= #{date.to_date}").map(&:patient_id)

    results = (death_date_less_than_last_enc + death_date_less_than_date_of_birth).uniq

    return results

    #  FlatTable2.find_by_sql(["
			# (SELECT DISTINCT (ft2.patient_id) FROM flat_table2 ft2
    #     INNER JOIN flat_cohort_table fct ON ft2.patient_id = fct.patient_id
			# WHERE DATEDIFF(ft2.visit_date, fct.death_date) > 0
			#   AND DATE(ft2.visit_date) <= ?)
    #
    #    UNION
    #   (SELECT DISTINCT (ft2.patient_id) FROM flat_table2 ft2
    #     INNER JOIN flat_cohort_table fct ON ft2.patient_id = fct.patient_id
			# WHERE DATEDIFF(fct.birthdate, ft2.visit_date) > 0
			#   AND DATE(ft2.visit_date) <= ?)
    # ", date.to_date, date.to_date]).map(&:patient_id).uniq

  end

  def self.patients_with_treatment_encounter_without_orders(end_date = Date.today)
    # Query pulling all treatment encounters without orders
    ValidationRule.find_by_sql("SELECT e.patient_id, e.encounter_id, e.encounter_type, e.encounter_datetime
				FROM earliest_start_date esd
			          INNER JOIN encounter e ON e.patient_id = esd.patient_id AND e.voided = 0
				WHERE e.encounter_type IN (25)
				AND e.encounter_id NOT IN (SELECT encounter_id FROM orders WHERE voided = 0 AND DATE(start_date) <= '#{end_date.to_date}')
                                AND DATE(encounter_datetime) <= '#{end_date.to_date}'
				GROUP BY e.patient_id").map(&:patient_id)
  end 

  def self.patients_with_encounters_without_observations(end_date = Date.today)
   #Query pulling all encounters without observations 
   ValidationRule.find_by_sql("SELECT e.patient_id, e.encounter_id, e.encounter_type, e.encounter_datetime
			       FROM earliest_start_date esd
			         INNER JOIN encounter e ON e.patient_id = esd.patient_id AND e.voided = 0
			       WHERE e.encounter_id NOT IN (SELECT encounter_id FROM obs 
                                                            WHERE voided = 0 
                                                            AND DATE(obs_datetime) <= '#{end_date.to_date}')
                               AND DATE(encounter_datetime) <= '#{end_date.to_date}'
		               GROUP BY e.patient_id").map(&:patient_id)
  end

  def self.encounters_without_obs_or_orders(end_date = Date.today)
    #Query for encounters without obs or orders ~ Kenneth
    ValidationRule.find_by_sql(["
         			 SELECT DISTINCT (enc.patient_id) FROM encounter enc
    			           LEFT JOIN obs o ON o.encounter_id = enc.encounter_id
    			           LEFT JOIN orders od ON od.encounter_id = enc.encounter_id
			         WHERE enc.voided = 0 AND (o.encounter_id IS NULL OR o.voided = 1) AND (od.encounter_id IS NULL OR od.voided = 1)
			         AND DATE(enc.encounter_datetime) <= ?", end_date.to_date
			       ]).map(&:patient_id)		

  end
	
  def self.start_date_before_birth(date = Date.today)

    #begin Query for patients whose earliest start date is less that date of birth ~ Kenneth
    return FlatTable2.find_by_sql(["
			SELECT DISTINCT (ft2.patient_id) FROM flat_table2 ft2
        INNER JOIN flat_cohort_table fct ON ft2.patient_id = fct.patient_id
			WHERE DATEDIFF(fct.earliest_start_date, fct.birthdate) <= 0
			  AND DATE(ft2.visit_date) <= ?", date.to_date]).map(&:patient_id)

  end
	
  def self.visit_after_death(date = Date.today)

   # Query for patients with followup visit after death ~ Kenneth
   return FlatTable2.find_by_sql(["
			SELECT DISTINCT (ft2.patient_id) FROM flat_table2 ft2
        INNER JOIN flat_cohort_table fct ON ft2.patient_id = fct.patient_id
			WHERE DATEDIFF(ft2.visit_date, fct.death_date) > 0
			  AND DATE(ft2.visit_date) <= ?", date.to_date]).map(&:patient_id)

  end	

  def self.male_patients_with_pregnant_observation(date = Date.today)

    pregnant_fields = ActiveRecord::Base.connection.select_all("SHOW COLUMNS
                           FROM flat_table2 LIKE '%pregnant%'").collect{|p|p['Field']}
    pregnant_fields = pregnant_fields.map{|field| "ft2.#{field}"}

    # pregnant_fields = [
    #                     "ft2.pregnant_yes", "ft2.pregnant_no", "ft2.pregnant_unknown",
    #                     "ft2.pregnant_yes_enc_id", "ft2.pregnant_no_enc_id", "ft2.pregnant_unknown_enc_id",
    #                     "ft2.pregnant_yes_v_date", "ft2.pregnant_no_v_date", "ft2.pregnant_unknown_v_date"
    #                   ]

    #Query pulling all male patients with pregnant observations

    male_pats_with_preg_obs = FlatTable2.find_by_sql(["SELECT ft2.patient_id FROM flat_table2 ft2
                                  INNER JOIN flat_cohort_table fct ON fct.patient_id = ft2.patient_id
                                  WHERE fct.gender IN ('Male', 'M')
                                  AND COALESCE(#{pregnant_fields.join(',')}) IS NOT NULL
                                  AND DATE(ft2.visit_date) <= ?", date.to_date]).map(&:patient_id)

    return male_pats_with_preg_obs

  end

  def self.male_patients_with_breastfeeding_obs(date = Date.today)

    breastfeeding_fields = ActiveRecord::Base.connection.select_all("SHOW COLUMNS
                           FROM flat_table2 LIKE '%breastfeeding%'").collect{|p|p['Field']}
    breastfeeding_fields = breastfeeding_fields.map{|field| "ft2.#{field}"}

    # breastfeeding_fields = [
    #     "ft2.breastfeeding_yes", "ft2.breastfeeding_no", "ft2.breastfeeding_unknown",
    #     "ft2.breastfeeding_yes_enc_id", "ft2.breastfeeding_no_enc_id", "ft2.breastfeeding_unknown_enc_id",
    #     "ft2.breastfeeding_yes_v_date", "ft2.breastfeeding_no_v_date", "ft2.breastfeeding_unknown_v_date"
    # ]

    #Query pulling all male patients with breastfeeding observations
    male_pats_with_breastfeed_obs = ActiveRecord::Base.connection.select_all("SELECT ft2.patient_id
                                    FROM flat_table2 ft2
                                    INNER JOIN flat_cohort_table fct ON fct.patient_id = ft2.patient_id
                                    WHERE gender IN ('Male', 'M')
                                    AND COALESCE(#{breastfeeding_fields.join(',')}) IS NOT NULL
                                    AND DATE(ft2.visit_date) <= #{date.to_date}").map(&:patient_id)

    return male_pats_with_breastfeed_obs

  end

  def self.male_patients_with_family_planning_methods_obs(date = Date.today)

    family_planning_fields = ActiveRecord::Base.connection.select_all("SHOW COLUMNS
                           FROM flat_table2 LIKE '%family_planning%'").collect{|p|p['Field']}
    family_planning_fields = family_planning_fields.map{|field| "ft2.#{field}"}

    # family_planning_fields = FlatTable2.find_by_sql("SHOW COLUMNS FROM flat_table2 LIKE '%family_planning%'").map(&:Field)

    # Query pulling all male patients with family planning methods observations

    male_pats_with_family_planning_obs = FlatTable2.find_by_sql(["SELECT ft2.patient_id
                                         FROM flat_table2 ft2
                                         INNER JOIN flat_cohort_table fct ON fct.patient_id = ft2.patient_id
                                         WHERE fct.gender IN ('Male', 'M')
                                         AND COALESCE(#{family_planning_fields.join(',')}) IS NOT NULL
                                         AND DATE(ft2.visit_date) <= ?", date.to_date]).map(&:patient_id)

    return male_pats_with_family_planning_obs

  end

  def self.check_every_ART_patient_has_HIV_Clinical_Registration(date = Date.today)
			#Task 32
			#SQL to check for every ART patient should have a HIV Clinical Registration
			date = date.to_date.strftime('%Y-%m-%d 23:59:59')

      eligible_patients = Patient.find_by_sql("SELECT patient_id FROM flat_cohort_table").collect { |x| x.patient_id }
      
      return FlatCohortTable.find_by_sql("SELECT 
                                              fct.patient_id,
                                              fct.earliest_start_date,
                                              ft1.ever_received_art,
                                              ft1.type_of_confirmatory_hiv_test,
                                              ft1.confirmatory_hiv_test_location,
                                              ft1.ever_registered_at_art_clinic,
                                              ft1.agrees_to_followup
                                          FROM
                                              flat_cohort_table fct
                                                  INNER JOIN
                                              flat_table1 ft1 ON ft1.patient_id = fct.patient_id
                                          WHERE
                                              fct.earliest_start_date <= DATE('#{date}')
                                                  AND ft1.type_of_confirmatory_hiv_test IS NULL
                                                  AND ft1.confirmatory_hiv_test_location IS NULL
                                                  AND ft1.agrees_to_followup IS NULL
                                                  AND ft1.ever_received_art IS NULL
                                          GROUP BY fct.patient_id").map(&:patient_id)                                          

  end

  def self.deliver_validation_results(rules_date = Date.today)
     sent_to_mail = {}
    ValidationResult.find_by_sql("
      SELECT * FROM validation_results vs
      INNER JOIN validation_rules vr ON vr.id = vs.rule_id
      ").each {|validated|
        sent_to_mail["#{validated.desc}"] = {}
        sent_to_mail["#{validated.desc}"]["failed"] = validated.failures
        sent_to_mail["#{validated.desc}"]["validated_on"] = validated.date_checked
      }
    return sent_to_mail
  end

  def self.every_visit_of_patients_who_are_under_18_should_have_height_and_weight(date = Date.today)
    #Task 31
    #SQL for every visit of patients who are under 18 should have height and weight

    date = date.to_date.strftime('%Y-%m-%d 23:59:59')

    eligible_patients = Patient.find_by_sql("SELECT patient_id, FLOOR(DATEDIFF(DATE('#{date}'), birthdate)/365) AS age
 FROM flat_cohort_table HAVING age < 18").collect { |x| x.patient_id }

    eligible_patients = [-10] if eligible_patients.blank? #to avoid mysql crash

    return Patient.find_by_sql("SELECT 
                                  ft2.visit_date,
                                  ftc.patient_id,
                                  ftc.birthdate,
                                  FLOOR(DATEDIFF(DATE(NOW()), ftc.birthdate) / 365.25) AS patient_age,
                                  ft2.guardian_present,
                                  ft2.patient_present,
                                  ft2.weight,
                                  ft2.height
                              FROM
                                  flat_cohort_table ftc
                                      INNER JOIN
                                  flat_table2 ft2 ON ft2.patient_id = ftc.patient_id
                              WHERE
                                  (ft2.weight IS NULL
                                      OR ft2.height IS NULL) 
                              HAVING patient_age <= 18 AND ft2.patient_present = 'Yes'
                               AND (ft2.guardian_present = 'Yes' Or ft2.guardian_present = 'No')").map(&:patient_id)

  end

	def self.every_outcome_needs_a_date(date = Date.today)
          #Task 40
	  #Every outcome needs a date

          date = date.to_date.strftime('%Y-%m-%d 23:59:59')

          FlatTable2.find_by_sql("SELECT patient_id FROM flat_table2 WHERE COALESCE(TRIM(current_hiv_program_state),'') != ''
                                  AND DATE(current_hiv_program_start_date) IS NULL AND DATE(visit_date) <= DATE('#{date}')
                                  AND patient_id in (SELECT patient_id FROM flat_cohort_table)").map(&:patient_id)
  end
 
  def self.patients_without_gender(end_date = Date.today)
   #pulling out without gender
   ValidationRule.find_by_sql("SELECT fct.patient_id, fct.gender, fct.earliest_start_date
                               FROM flat_cohort_table fct
                               WHERE (fct.gender IS NULL OR fct.gender = '')
                               AND fct.earliest_start_date <= '#{end_date.to_date}'").map(&:patient_id)
  end
  
  def self.pre_art_patients_with_arv_drugs(end_date = Date.today)
   # pulling all pre-art patients with ARV drugs
   ValidationRule.find_by_sql("SELECT 
                                 fct.patient_id,
                                 fct.gender,
                                 fct.earliest_start_date,
                                 fct.hiv_program_state,
                                 fct.hiv_program_start_date
                               FROM
                                   flat_cohort_table fct
                                 INNER JOIN
                                   arv_drugs_orders ado ON ado.patient_id = fct.patient_id
                               WHERE
                                 fct.hiv_program_state = 'Pre-ART (Continue)'
                                 AND fct.earliest_start_date <= '#{end_date.to_date}'
                                 AND DATE(ado.start_date) <= '#{end_date.to_date}'
                               GROUP BY fct.patient_id").map(&:patient_id)
  end

  def self.patients_without_birthdate(end_date = Date.today)
    #pulling all patients without birthdate
    ValidationRule.find_by_sql("SELECT fct.patient_id, fct.birthdate, fct.earliest_start_date
                               FROM flat_cohort_table fct
                               WHERE (fct.birthdate IS NULL OR fct.birthdate = '' OR fct.birthdate = '0000-00-00')
                               AND fct.earliest_start_date <= '#{end_date.to_date}'").map(&:patient_id)

  end
 
  def self.patients_with_birthdate_less_than_death_date(end_date = Date.today)
    #pulling all patients with bithdate less than death_date
    ValidationRule.find_by_sql("SELECT fct.patient_id, fct.birthdate, fct.death_date, fct.earliest_start_date
                               FROM flat_cohort_table fct
                               WHERE Date(fct.birthdate) < DATE(fct.death_date)
                               AND fct.earliest_start_date <= '#{end_date.to_date}'").map(&:patient_id)

  end

  def self.patients_with_earliest_start_date_greater_than_first_received_drug_date(end_date = Date.today)
   #pulling all patients with earliest_start_date greater than first received drug date
   ValidationRule.find_by_sql("SELECT fct.patient_id, fct.earliest_start_date
			       FROM flat_cohort_table fct
			       WHERE fct.earliest_start_date < (SELECT min(DATE(start_date)) FROM amount_dispensed_obs
                               				         WHERE person_id = fct.patient_id
				                                 AND DATE(start_date) < '#{end_date.to_date}')
			       AND fct.earliest_start_date < '#{end_date.to_date}'
			       GROUP BY fct.patient_id").map(&:patient_id) 
  end
end
