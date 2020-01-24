class FlatTablesCohort



  def self.get_indicators(start_date, end_date)
  time_started = Time.now().strftime('%Y-%m-%d %H:%M:%S')

    ActiveRecord::Base.connection.execute <<EOF
      DROP FUNCTION IF EXISTS `flat_drug_pill_count`;
EOF

    ActiveRecord::Base.connection.execute <<EOF
CREATE FUNCTION `flat_drug_pill_count`(my_patient_id INT, my_drug_id INT, my_date DATE) RETURNS decimal(10,0)
BEGIN
  DECLARE done INT DEFAULT FALSE;
  DECLARE my_pill_count, my_total_text, my_total_numeric DECIMAL;

  DECLARE cur1 CURSOR FOR SELECT SUM(ob.value_numeric), SUM(CAST(ob.value_text AS DECIMAL)) FROM obs ob
                        INNER JOIN drug_order do ON ob.order_id = do.order_id
                        INNER JOIN orders o ON do.order_id = o.order_id
                    WHERE ob.person_id = my_patient_id
                        AND ob.concept_id = 2540
                        AND ob.voided = 0
                        AND o.voided = 0
                        AND do.drug_inventory_id = my_drug_id
                        AND DATE(ob.obs_datetime) = my_date
                    GROUP BY ob.person_id;

  DECLARE cur2 CURSOR FOR SELECT SUM(ob.value_numeric) FROM obs ob
                    WHERE ob.person_id = my_patient_id
                        AND ob.concept_id = (SELECT concept_id FROM drug WHERE drug_id = my_drug_id)
                        AND ob.voided = 0
                        AND DATE(ob.obs_datetime) = my_date
                    GROUP BY ob.person_id;

  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

  OPEN cur1;

  SET my_pill_count = 0;

  read_loop: LOOP
    FETCH cur1 INTO my_total_numeric, my_total_text;

    IF done THEN
      CLOSE cur1;
      LEAVE read_loop;
    END IF;

        IF my_total_numeric IS NULL THEN
            SET my_total_numeric = 0;
        END IF;

        IF my_total_text IS NULL THEN
            SET my_total_text = 0;
        END IF;

        SET my_pill_count = my_total_numeric + my_total_text;
    END LOOP;

  OPEN cur2;
  SET done = false;

  read_loop: LOOP
    FETCH cur2 INTO my_total_numeric;

    IF done THEN
      CLOSE cur2;
      LEAVE read_loop;
    END IF;

        IF my_total_numeric IS NULL THEN
            SET my_total_numeric = 0;
        END IF;

        SET my_pill_count = my_total_numeric + my_pill_count;
    END LOOP;

  RETURN my_pill_count;
END;
EOF

    ActiveRecord::Base.connection.execute <<EOF
      DROP FUNCTION IF EXISTS `flat_current_defaulter`;
EOF

    ActiveRecord::Base.connection.execute <<EOF
CREATE FUNCTION `flat_current_defaulter`(my_patient_id INT, my_end_date DATETIME) RETURNS int(1)
BEGIN
  DECLARE done INT DEFAULT FALSE;
  DECLARE my_start_date, my_expiry_date, my_obs_datetime DATETIME;
  DECLARE my_daily_dose, my_quantity, my_pill_count, my_total_text, my_total_numeric DECIMAL;
  DECLARE my_drug_id, flag INT;

  DECLARE cur1 CURSOR FOR SELECT d.drug_inventory_id, o.start_date, d.equivalent_daily_dose daily_dose, d.quantity, o.start_date FROM drug_order d
    INNER JOIN arv_drug ad ON d.drug_inventory_id = ad.drug_id
    INNER JOIN orders o ON d.order_id = o.order_id
      AND d.quantity > 0
      AND o.voided = 0
      AND o.start_date <= my_end_date
      AND o.patient_id = my_patient_id;

  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

  SELECT MAX(o.start_date) INTO @obs_datetime FROM drug_order d
    INNER JOIN arv_drug ad ON d.drug_inventory_id = ad.drug_id
    INNER JOIN orders o ON d.order_id = o.order_id
      AND d.quantity > 0
      AND o.voided = 0
      AND o.start_date <= my_end_date
      AND o.patient_id = my_patient_id
    GROUP BY o.patient_id;

  OPEN cur1;

  SET flag = 0;

  read_loop: LOOP
    FETCH cur1 INTO my_drug_id, my_start_date, my_daily_dose, my_quantity, my_obs_datetime;

    IF done THEN
      CLOSE cur1;
      LEAVE read_loop;
    END IF;

    IF DATE(my_obs_datetime) = DATE(@obs_datetime) THEN

      IF my_daily_dose = 0 OR LENGTH(my_daily_dose) < 1 OR my_daily_dose IS NULL THEN
        SET my_daily_dose = 1;
      END IF;

            SET my_pill_count = flat_drug_pill_count(my_patient_id, my_drug_id, my_obs_datetime);

            SET @expiry_date = ADDDATE(DATE_SUB(my_start_date, INTERVAL 2 DAY), ((my_quantity + my_pill_count)/my_daily_dose));

      IF my_expiry_date IS NULL THEN
        SET my_expiry_date = @expiry_date;
      END IF;

      IF @expiry_date < my_expiry_date THEN
        SET my_expiry_date = @expiry_date;
            END IF;
        END IF;
    END LOOP;

    IF TIMESTAMPDIFF(day, my_expiry_date, my_end_date) > 60 THEN
        SET flag = 1;
    END IF;

  RETURN flag;
END;
EOF

    ActiveRecord::Base.connection.execute <<EOF
      DROP FUNCTION IF EXISTS `flat_patient_outcome`;
EOF

    ActiveRecord::Base.connection.execute <<EOF
CREATE FUNCTION flat_patient_outcome(patient_id INT, visit_date DATETIME) RETURNS varchar(25)
DETERMINISTIC
BEGIN
DECLARE set_program_id INT;
DECLARE set_patient_state INT;
DECLARE set_outcome varchar(25);
DECLARE set_date_started date;
DECLARE set_patient_state_died INT;
DECLARE set_died_concept_id INT;
DECLARE set_timestamp DATETIME;

SET set_timestamp = DATE_FORMAT(visit_date, '%Y-%m-%d 23:59:59');
SET set_program_id = (SELECT program_id FROM program WHERE name ="HIV PROGRAM" LIMIT 1);

SET set_patient_state = (SELECT state FROM `patient_state` INNER JOIN patient_program p ON p.patient_program_id = patient_state.patient_program_id AND p.program_id = set_program_id WHERE (patient_state.voided = 0 AND p.voided = 0 AND p.program_id = program_id AND DATE(start_date) <= visit_date AND p.patient_id = patient_id) AND (patient_state.voided = 0) ORDER BY start_date DESC, patient_state.patient_state_id DESC, patient_state.date_created DESC LIMIT 1);

IF set_patient_state = 1 THEN
  SET set_patient_state = flat_current_defaulter(patient_id, set_timestamp);

  IF set_patient_state = 1 THEN
    SET set_outcome = 'Defaulted';
  ELSE
    SET set_outcome = 'Pre-ART (Continue)';
  END IF;
END IF;

IF set_patient_state = 2   THEN
  SET set_outcome = 'Patient transferred out';
END IF;

IF set_patient_state = 3 OR set_patient_state = 127 THEN
  SET set_outcome = 'Patient died';
END IF;

/* ............... This block of code checks if the patient has any state that is "died" */
IF set_patient_state != 3 AND set_patient_state != 127 THEN
  SET set_patient_state_died = (SELECT state FROM `patient_state` INNER JOIN patient_program p ON p.patient_program_id = patient_state.patient_program_id AND p.program_id = set_program_id WHERE (patient_state.voided = 0 AND p.voided = 0 AND p.program_id = program_id AND DATE(start_date) <= visit_date AND p.patient_id = patient_id) AND (patient_state.voided = 0) AND state = 3 ORDER BY patient_state.patient_state_id DESC, patient_state.date_created DESC, start_date DESC LIMIT 1);

  SET set_died_concept_id = (SELECT concept_id FROM concept_name WHERE name = 'Patient died' LIMIT 1);

  IF set_patient_state_died IN(SELECT program_workflow_state_id FROM program_workflow_state WHERE concept_id = set_died_concept_id AND retired = 0) THEN
    SET set_outcome = 'Patient died';
    SET set_patient_state = 3;
  END IF;
END IF;
/* ....................  ends here .................... */


IF set_patient_state = 6 THEN
  SET set_outcome = 'Treatment stopped';
END IF;

IF set_patient_state = 7 THEN
  SET set_patient_state = flat_current_defaulter(patient_id, set_timestamp);

  IF set_patient_state = 1 THEN
    SET set_outcome = 'Defaulted';
  END IF;

  IF set_patient_state = 0 THEN
    SET set_outcome = 'On antiretrovirals';
  END IF;
END IF;

IF set_outcome IS NULL THEN
  SET set_patient_state = flat_current_defaulter(patient_id, set_timestamp);

  IF set_patient_state = 1 THEN
    SET set_outcome = 'Defaulted';
  END IF;

  IF set_outcome IS NULL THEN
    SET set_outcome = 'Unknown';
  END IF;

END IF;

RETURN set_outcome;
END;
EOF


    ActiveRecord::Base.connection.execute <<EOF
      DROP TABLE IF EXISTS `temp_flat_table1_patient_pregnant`;
EOF


    ActiveRecord::Base.connection.execute <<EOF
      CREATE TABLE temp_flat_table1_patient_pregnant
        SELECT `patient_id`, `gender`, `date_enrolled`, `earliest_start_date`, `patient_pregnant`, `patient_pregnant_v_date`, `pregnant_at_initiation`, `pregnant_at_initiation_v_date`
        FROM `flat_table1` 
        WHERE `patient_pregnant` IS NOT NULL or `pregnant_at_initiation` IS NOT NULL;
EOF

    ActiveRecord::Base.connection.execute <<EOF
      DROP TABLE IF EXISTS `temp_flat_table2_patient_pregnant`;
EOF

    ActiveRecord::Base.connection.execute <<EOF
      CREATE TABLE temp_flat_table2_patient_pregnant
        SELECT `ft2`.`patient_id`, `fct`.`gender`, `fct`.`date_enrolled`, `fct`.`earliest_start_date`, `ft2`.`patient_pregnant`, `ft2`.`visit_date`
        FROM `flat_table2` `ft2`
         INNER JOIN `flat_cohort_table` `fct` ON `fct`.`patient_id` = `ft2`.`patient_id`
        WHERE `ft2`.`patient_pregnant` IS NOT NULL
        ORDER BY `ft2`.`patient_id`, `ft2`.`visit_date`;
EOF

      ActiveRecord::Base.connection.execute <<EOF
        DROP TABLE IF EXISTS `temp_flat_tables_patient_outcomes`;
EOF

      ActiveRecord::Base.connection.execute <<EOF
        CREATE TABLE temp_flat_tables_patient_outcomes
          SELECT patient_id, flat_patient_outcome(patient_id, '#{end_date} 23:59:59') cum_outcome
        FROM flat_cohort_table
        WHERE date_enrolled <= '#{end_date}' AND date_enrolled <> '0000-00-00';
EOF

ActiveRecord::Base.connection.execute <<EOF
  DROP FUNCTION IF EXISTS `flat_last_text_for_obs`;
EOF

    ActiveRecord::Base.connection.execute <<EOF
CREATE FUNCTION flat_last_text_for_obs(my_patient_id INT, my_encounter_type_id INT, my_concept_id INT, my_regimem_given INT, unknown_regimen_value INT, my_end_date DATETIME) RETURNS varchar(255)

BEGIN
  SET @obs_value = NULL;
  SET @encounter_id = NULL;

  SELECT o.encounter_id INTO @encounter_id FROM encounter e
  	INNER JOIN obs o ON e.encounter_id = o.encounter_id AND o.concept_id IN (my_concept_id, @unknown_drug_concept_id) AND o.voided = 0
  WHERE e.encounter_type = my_encounter_type_id
  AND e.voided = 0
  AND e.patient_id = my_patient_id
  AND e.encounter_datetime <= my_end_date
  ORDER BY e.encounter_datetime DESC LIMIT 1;

  SELECT cn.name INTO @obs_value FROM obs o
  	LEFT JOIN concept_name cn ON o.value_coded = cn.concept_id AND cn.concept_name_type = 'FULLY_SPECIFIED'
  WHERE encounter_id = @encounter_id
  AND o.voided = 0
  AND o.concept_id = my_concept_id
  AND o.voided = 0 LIMIT 1;

  IF @obs_value IS NULL THEN
    SELECT 'unknown_drug_value' INTO @obs_value FROM obs
    WHERE encounter_id = @encounter_id
    AND voided = 0
    AND concept_id = my_regimem_given
    AND (value_coded = unknown_regimen_value OR value_text = 'Unknown')
    AND voided = 0 LIMIT 1;
  END IF;

  IF @obs_value IS NULL THEN
    SELECT value_text INTO @obs_value FROM obs
    WHERE encounter_id = @encounter_id
    AND voided = 0
    AND concept_id = my_concept_id
    AND voided = 0 LIMIT 1;
  END IF;

  IF @obs_value IS NULL THEN
    SELECT value_numeric INTO @obs_value FROM obs
    WHERE encounter_id = @encounter_id
    AND voided = 0
    AND concept_id = my_concept_id
    AND voided = 0 LIMIT 1;
  END IF;

  RETURN @obs_value;
END;
EOF

    ActiveRecord::Base.connection.execute <<EOF
      DROP FUNCTION IF EXISTS `flat_current_defaulter_date`;
EOF

    ActiveRecord::Base.connection.execute <<EOF
CREATE FUNCTION flat_current_defaulter_date(my_patient_id INT, my_end_date date) RETURNS varchar(25)
DETERMINISTIC
BEGIN
DECLARE done INT DEFAULT FALSE;
  DECLARE my_start_date, my_expiry_date, my_obs_datetime, my_defaulted_date DATETIME;
  DECLARE my_daily_dose, my_quantity, my_pill_count, my_total_text, my_total_numeric DECIMAL;
  DECLARE my_drug_id, flag INT;

  DECLARE cur1 CURSOR FOR SELECT d.drug_inventory_id, o.start_date, d.equivalent_daily_dose daily_dose, d.quantity, o.start_date FROM drug_order d
    INNER JOIN arv_drug ad ON d.drug_inventory_id = ad.drug_id
    INNER JOIN orders o ON d.order_id = o.order_id
      AND d.quantity > 0
      AND o.voided = 0
      AND o.start_date <= my_end_date
      AND o.patient_id = my_patient_id;

  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

  SELECT MAX(o.start_date) INTO @obs_datetime FROM drug_order d
    INNER JOIN arv_drug ad ON d.drug_inventory_id = ad.drug_id
    INNER JOIN orders o ON d.order_id = o.order_id
      AND d.quantity > 0
      AND o.voided = 0
      AND o.start_date <= my_end_date
      AND o.patient_id = my_patient_id
    GROUP BY o.patient_id;

  OPEN cur1;

  SET flag = 0;

  read_loop: LOOP
    FETCH cur1 INTO my_drug_id, my_start_date, my_daily_dose, my_quantity, my_obs_datetime;

    IF done THEN
      CLOSE cur1;
      LEAVE read_loop;
    END IF;

    IF DATE(my_obs_datetime) = DATE(@obs_datetime) THEN

      IF my_daily_dose = 0 OR my_daily_dose IS NULL OR LENGTH(my_daily_dose) < 1 THEN
        SET my_daily_dose = 1;
      END IF;

      SET my_pill_count = flat_drug_pill_count(my_patient_id, my_drug_id, my_obs_datetime);

      SET @expiry_date = ADDDATE(my_start_date, ((my_quantity + my_pill_count)/my_daily_dose));

      IF my_expiry_date IS NULL THEN
        SET my_expiry_date = @expiry_date;
      END IF;

      IF @expiry_date < my_expiry_date THEN
        SET my_expiry_date = @expiry_date;
        END IF;
      END IF;
    END LOOP;

    IF DATEDIFF(my_end_date, my_expiry_date) > 60 THEN
      SET my_defaulted_date = ADDDATE(my_expiry_date, 60);
    END IF;

  RETURN my_defaulted_date;
END;
EOF

    ActiveRecord::Base.connection.execute <<EOF
      DROP FUNCTION IF EXISTS `flat_re_initiated_check`;
EOF

    ActiveRecord::Base.connection.execute <<EOF
CREATE FUNCTION flat_re_initiated_check(set_patient_id INT, set_date_enrolled DATE) RETURNS VARCHAR(15)
DETERMINISTIC
BEGIN
DECLARE re_initiated VARCHAR(15) DEFAULT 'N/A';
DECLARE check_one INT DEFAULT 0;
DECLARE check_two INT DEFAULT 0;

DECLARE yes_concept INT;
DECLARE no_concept INT;
DECLARE date_art_last_taken_concept INT;
DECLARE taken_arvs_concept INT;

set yes_concept = (SELECT concept_id FROM concept_name WHERE name ='YES' LIMIT 1);
set no_concept = (SELECT concept_id FROM concept_name WHERE name ='NO' LIMIT 1);
set date_art_last_taken_concept = (SELECT concept_id FROM concept_name WHERE name ='DATE ART LAST TAKEN' LIMIT 1);
set taken_arvs_concept = (SELECT concept_id FROM concept_name WHERE name ='HAS THE PATIENT TAKEN ART IN THE LAST TWO MONTHS' LIMIT 1);

set check_one = (SELECT esd.patient_id FROM temp_earliest_start_date esd INNER JOIN clinic_registration_encounter e ON esd.patient_id = e.patient_id INNER JOIN ever_registered_obs AS ero ON e.encounter_id = ero.encounter_id INNER JOIN obs o ON o.encounter_id = e.encounter_id AND o.concept_id = date_art_last_taken_concept AND o.voided = 0 WHERE ((o.concept_id = date_art_last_taken_concept AND (DATEDIFF(o.obs_datetime,o.value_datetime)) > 14)) AND esd.date_enrolled = set_date_enrolled AND esd.patient_id = set_patient_id GROUP BY esd.patient_id);

set check_two = (SELECT esd.patient_id FROM temp_earliest_start_date esd INNER JOIN clinic_registration_encounter e ON esd.patient_id = e.patient_id INNER JOIN ever_registered_obs AS ero ON e.encounter_id = ero.encounter_id INNER JOIN obs o ON o.encounter_id = e.encounter_id AND o.concept_id = taken_arvs_concept AND o.voided = 0 WHERE  ((o.concept_id = taken_arvs_concept AND o.value_coded = no_concept)) AND esd.date_enrolled = set_date_enrolled AND esd.patient_id = set_patient_id GROUP BY esd.patient_id);

if check_one >= 1 then set re_initiated ="Re-initiated";
elseif check_two >= 1 then set re_initiated ="Re-initiated";
end if;


RETURN re_initiated;
END;
EOF

    ActiveRecord::Base.connection.execute <<EOF
      DROP FUNCTION IF EXISTS `flat_patient_died_in`;
EOF

    ActiveRecord::Base.connection.execute <<EOF
CREATE FUNCTION flat_patient_died_in(set_patient_id INT, set_status VARCHAR(25), date_enrolled DATE) RETURNS varchar(25)
DETERMINISTIC
BEGIN
DECLARE set_outcome varchar(25) default 'N/A';
DECLARE date_of_death DATE;
DECLARE num_of_days INT;

IF set_status = 'Patient died' THEN

  SET date_of_death = (SELECT death_date FROM flat_cohort_table WHERE patient_id = set_patient_id AND death_date <> '0000-00-00');

  IF date_of_death IS NULL THEN
    RETURN 'Unknown';
  END IF;


  set num_of_days = (TIMESTAMPDIFF(day, date(date_enrolled), date(date_of_death)));

  IF num_of_days <= 30 THEN set set_outcome ="1st month";
  ELSEIF num_of_days <= 60 THEN set set_outcome ="2nd month";
  ELSEIF num_of_days <= 91 THEN set set_outcome ="3rd month";
  ELSEIF num_of_days > 91 THEN set set_outcome ="4+ months";
  ELSEIF num_of_days IS NULL THEN set set_outcome = "Unknown";
  END IF;


END IF;

RETURN set_outcome;
END;
EOF
end



 def self.get_cumulative_data(start_date, end_date)
    results = []
    outcomes = []

    start_date = '1900-01-01'.to_date
    end_date = end_date.to_date

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
    return results
  end

  def self.get_patient_outcomes(start_date, end_date)
    outcomes = []
    cpt_names = []
    ipt_names = []

    start_date = '1900-01-01'.to_date
    end_date = end_date.to_date
   
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

    return outcomes
  end

  def self.get_patients_cpt_ipt_pfip_and_bp_screen(start_date, end_date)
    outcomes = []
    cpt_names = []
    ipt_names = []

    start_date = start_date.to_date
    end_date = end_date.to_date
   
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

    cpt_patients_ids_in_quarter.uniq! unless cpt_patients_ids_in_quarter.blank?

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
      :ipt_ids => ipt_patients_ids_in_quarter,
      :pfip_ids => family_planning_ids_in_quarter,
      :bp_screen_ids => bp_screen_patients_ids_in_quarter
    }
    
    return results
  end


  def self.get_total_pregnant_and_breastfeeding(start_date, end_date)
    patients_on_art   = []
    pregnant_females  = []
    female_patients   = []

    start_date = start_date.to_date
    end_date   = end_date.to_date

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

    return female_patients
  end

  def self.get_patients_alive_and_ART_details(start_date, end_date)
    patients_on_art = []
    patients_alive_and_ART_details = []

    end_date = end_date.to_date
   
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

    return patients_alive_and_ART_details

  end



end
