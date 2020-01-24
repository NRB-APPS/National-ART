class CohortDisaggregated

  def self.get_indicators(start_date, end_date)
  time_started = Time.now().strftime('%Y-%m-%d %H:%M:%S')
  #######################################################################################################


#=end
      #Get earliest date enrolled
      cum_start_date = CohortRevise.get_cum_start_date
      cohort = CohortService.new(cum_start_date)

      #Total registered
      cohort.total_registered = CohortRevise.total_registered(start_date, end_date)
      cohort.cum_total_registered = CohortRevise.total_registered(cum_start_date, end_date)

      #Patients initiated on ART first time
      cohort.initiated_on_art_first_time = CohortRevise.initiated_on_art_first_time(start_date, end_date)
      cohort.cum_initiated_on_art_first_time = CohortRevise.initiated_on_art_first_time(cum_start_date, end_date)

      #Patients re-initiated on ART
      cohort.re_initiated_on_art = CohortRevise.re_initiated_on_art(start_date, end_date)
      cohort.cum_re_initiated_on_art = CohortRevise.re_initiated_on_art(cum_start_date, end_date)

      #Patients transferred in on ART
      cohort.transfer_in = CohortRevise.transfer_in(start_date, end_date)
      cohort.cum_transfer_in = CohortRevise.transfer_in(cum_start_date, end_date)


      #All males
      cohort.all_males = CohortRevise.males(start_date, end_date)
      cohort.cum_all_males = CohortRevise.males(cum_start_date, end_date)

      #Unknown age
      cohort.unknown_age = CohortRevise.unknown_age(start_date, end_date)
      cohort.cum_unknown_age = CohortRevise.unknown_age(cum_start_date, end_date)

=begin
    No TB
    total_registered - (current_episode - tb_within_the_last_two_years)
=end
    cohort.no_tb = CohortRevise.no_tb(cohort.total_registered, cohort.tb_within_the_last_two_years, cohort.current_episode_of_tb)
    cohort.cum_no_tb = CohortRevise.cum_no_tb(cohort.cum_total_registered, cohort.cum_tb_within_the_last_two_years, cohort.cum_current_episode_of_tb)

=begin
    Total Alive and On ART
    Unique PatientProgram entries at the current location for those patients with at least one state
    ON ARVs and earliest start date of the 'ON ARVs' state less than or equal to end date of quarter
    and latest state is ON ARVs  (Excluding defaulters)
=end
    cohort.total_alive_and_on_art = CohortRevise.get_outcome('On antiretrovirals')


=begin
  Pregnant women

  Unique PatientProgram entries at the current location for those patients with at least one state ON ARVs
  and earliest start date of the 'ON ARVs' state within the quarter
  and having a REASON FOR ELIGIBILITY observation with an answer as PATIENT PREGNANT
=end
    cohort.total_pregnant_women = CohortRevise.total_pregnant_women(cohort.total_alive_and_on_art, start_date, end_date)

=begin
    Breastfeeding mothers

    Unique PatientProgram entries at the current location for those patients with at least one state
    ON ARVs and earliest start date of the 'ON ARVs' state within the quarter
    and having a REASON FOR ELIGIBILITY observation with an answer as BREASTFEEDING
=end
    cohort.total_breastfeeding_women = CohortRevise.total_breastfeeding_women(cohort.total_alive_and_on_art, start_date, end_date)

      #Non-pregnant females (all ages)
=begin
      Unique PatientProgram entries at the current location for those patients with at least one state ON ARVs
      and earliest start date of the 'ON ARVs' state within the quarter and having gender of
      related PERSON entry as F for female and no entries of 'IS PATIENT PREGNANT?' observation answered 'YES'
      in related HIV CLINIC CONSULTATION encounters not within 28 days from earliest registration date
=end
      pregnant_females = []
      (cohort.total_pregnant_women || []).each do |patient|
        pregnant_females << patient['person_id'].to_i
      end
      cohort.non_pregnant_females = CohortRevise.non_pregnant_females(start_date, end_date, pregnant_females)
      cohort.cum_non_pregnant_females = CohortRevise.non_pregnant_females(cum_start_date, end_date, pregnant_females)

    puts "Started at: #{time_started}. Finished at: #{Time.now().strftime('%Y-%m-%d %H:%M:%S')}"
    return cohort

  end

  def self.get_data(start_date, end_date, gender, age_group, cohort)

    @@cohort = cohort
    @@cohort_cum_start_date = CohortRevise.get_cum_start_date

    if gender == 'Male' || gender == 'Female'
      if age_group == '50+ years'
        yrs_months = 'year' ; age_to = 1000 ; age_from = 50
      elsif age_group.match(/years/i)
        age_from, age_to = age_group.sub(' years','').split('-')
        yrs_months = 'year'
      elsif age_group.match(/months/i)
        age_from, age_to = age_group.sub(' months','').split('-')
        yrs_months = 'month'
      end

      g = gender.first

      started_on_art = self.get_started_on_art(yrs_months, age_from, age_to, g, start_date, end_date)
      alive_on_art = self.get_alive_on_art(yrs_months, age_from, age_to, g, @@cohort_cum_start_date, end_date)
      started_on_ipt = self.get_started_on_ipt(yrs_months, age_from, age_to, g, @@cohort_cum_start_date, end_date)
      screened_for_tb = self.get_screened_for_tb(yrs_months, age_from, age_to, g, @@cohort_cum_start_date, end_date)

      return [(started_on_art.length rescue 0),
        (alive_on_art.length rescue 0),
        (started_on_ipt.length rescue 0),
        (screened_for_tb.length rescue 0)]
    end

    if gender == 'M'
      age_from = 0  ; age_to = 1000 ; yrs_months = 'year'
      started_on_art = self.get_started_on_art(yrs_months, age_from, age_to, gender, start_date, end_date)
      alive_on_art = self.get_alive_on_art(yrs_months, age_from, age_to, gender, @@cohort_cum_start_date, end_date)
      started_on_ipt = self.get_started_on_ipt(yrs_months, age_from, age_to, gender, @@cohort_cum_start_date, end_date)
      screened_for_tb = self.get_screened_for_tb(yrs_months, age_from, age_to, gender, @@cohort_cum_start_date, end_date)

      return [(started_on_art.length rescue 0),
        (alive_on_art.length rescue 0),
        (started_on_ipt.length rescue 0),
        (screened_for_tb.length rescue 0)]
    end

    if gender == 'FP'
      a, b, c, d = self.get_fp(start_date, end_date)
      return [a.length, b.length, c.length, d.length]
    end

    if gender == 'FNP'
      fnp_a, fnp_b, fnp_c, fnp_d = self.get_fnp(start_date, end_date)
      return [fnp_a.length, fnp_b.length, fnp_c.length, fnp_d.length]
    end


    if gender == 'FBf'
      a, b, c, d = self.get_fbf(start_date, end_date)
      return [a.length, b.length, c.length, d.length]
    end

    return [0, 0, 0, 0]
  end

  def self.get_fnp(start_date, end_date)
    age_from = 0  ; age_to = 1000 ; yrs_months = 'year' ; gender = 'F'

    females_pregnant = [] ; cum_females_pregnant = []
    breast_feeding_women = [] ; cum_breast_feeding_women = []

    started_on_art = [] ; alive_on_art = []
    started_on_ipt = [] ; screened_for_tb = []


    ###############################################################
    (@@cohort.total_breastfeeding_women || []).each do |p|
      date_enrolled_str = ActiveRecord::Base.connection.select_one <<EOF
      SELECT date_enrolled FROM temp_earliest_start_date e
      WHERE patient_id = #{p['person_id']};
EOF

      date_enrolled = date_enrolled_str['date_enrolled'].to_date
      if date_enrolled >= start_date.to_date and end_date.to_date <= end_date.to_date
        breast_feeding_women << p['person_id'].to_i
        breast_feeding_women = breast_feeding_women.uniq
      else
        cum_breast_feeding_women << p['person_id'].to_i
        cum_breast_feeding_women = cum_breast_feeding_women.uniq
      end
    end

    cum_pregnant_women = @@cohort.total_pregnant_women
    (cum_pregnant_women || []).each do |p|
      next if breast_feeding_women.include?(p['person_id'].to_i)

      date_enrolled_str = ActiveRecord::Base.connection.select_one <<EOF
        SELECT date_enrolled FROM temp_earliest_start_date e
        WHERE patient_id = #{p['person_id'].to_i};
EOF

      date_enrolled = date_enrolled_str['date_enrolled'].to_date
      if date_enrolled >= start_date.to_date and end_date.to_date <= end_date.to_date
        females_pregnant << p['person_id'].to_i
        females_pregnant = females_pregnant.uniq
      else
        cum_females_pregnant << p['person_id'].to_i
        cum_females_pregnant = cum_females_pregnant.uniq
      end
    end

    cum_females_pregnant = (cum_females_pregnant + females_pregnant).uniq rescue []
    cum_breast_feeding_women = (cum_breast_feeding_women + breast_feeding_women) rescue []
    #####################################################################

    (self.get_started_on_art(yrs_months, age_from, age_to, gender, start_date, end_date) || []).each do |fnp|
      next if females_pregnant.include?(fnp['patient_id'].to_i)
      next if breast_feeding_women.include?(fnp['patient_id'].to_i)
      started_on_art << {:patient_id => fnp['patient_id'].to_i, :date_enrolled => fnp['date_enrolled'].to_date}
    end

    (self.get_alive_on_art(yrs_months, age_from, age_to, gender, @@cohort_cum_start_date, end_date) || []).each do |fnp|
      next if cum_females_pregnant.include?(fnp['patient_id'].to_i)
      next if cum_breast_feeding_women.include?(fnp['patient_id'].to_i)
      alive_on_art << {:patient_id => fnp['patient_id'].to_i}
    end

    (self.get_started_on_ipt(yrs_months, age_from, age_to, gender, @@cohort_cum_start_date, end_date) || []).each do |fnp|
      next if cum_females_pregnant.include?(fnp['patient_id'].to_i)
      next if cum_breast_feeding_women.include?(fnp['patient_id'].to_i)
      started_on_ipt << {:patient_id => fnp['patient_id'].to_i}
    end

    (self.get_screened_for_tb(yrs_months, age_from, age_to, gender, @@cohort_cum_start_date, end_date) || []).each do |fnp|
      next if cum_females_pregnant.include?(fnp['patient_id'].to_i)
      next if cum_breast_feeding_women.include?(fnp['patient_id'].to_i)
      screened_for_tb << {:patient_id => fnp['patient_id'].to_i}
    end

    return [started_on_art, alive_on_art, started_on_ipt, screened_for_tb]
  end

  def self.get_screened_for_tb(yrs_months, age_from, age_to, gender, start_date, end_date)
    alive_on_art_patient_ids = []
    start_date = @@cohort_cum_start_date

    (@@cohort.total_alive_and_on_art || []).each do |data|
      alive_on_art_patient_ids << data['patient_id'].to_i
    end

    return [] if alive_on_art_patient_ids.blank?

    tb_treatment = ConceptName.find_by_name('TB treatment').concept_id
    tb_status_id = ConceptName.find_by_name('TB status').concept_id
    clinical_consultation = EncounterType.find_by_name('HIV CLINIC CONSULTATION').id

    data = ActiveRecord::Base.connection.select_all <<EOF
    SELECT t1.patient_id FROM obs t3
    INNER JOIN temp_earliest_start_date t1 ON t1.patient_id = t3.person_id
    WHERE t3.concept_id IN(#{tb_treatment},#{tb_status_id}) AND t3.voided = 0
    AND t3.obs_datetime BETWEEN '#{start_date.to_date.strftime('%Y-%m-%d 00:00:00')}'
    AND '#{end_date.to_date.strftime('%Y-%m-%d 23:59:59')}'
    AND gender = '#{gender.first}' AND t1.date_enrolled BETWEEN
    '#{start_date.to_date}' AND '#{end_date.to_date}'
    AND timestampdiff(#{yrs_months}, birthdate, DATE('#{end_date.to_date}'))
    BETWEEN #{age_from} AND #{age_to} AND t1.patient_id IN(#{alive_on_art_patient_ids.join(',')})
    AND t3.obs_datetime = (

      SELECT MAX(obs_datetime) FROM obs t4
      INNER JOIN encounter e ON e.encounter_id = t4.encounter_id
      AND e.encounter_type = #{clinical_consultation}
      WHERE t3.person_id = t4.person_id
      AND t4.voided = 0 AND t4.obs_datetime BETWEEN '#{start_date.to_date.strftime('%Y-%m-%d 00:00:00')}'
      AND '#{end_date.to_date.strftime('%Y-%m-%d 23:59:59')}'

    )
    GROUP BY t3.person_id;
EOF

    return data rescue 0

  end



  def self.get_started_on_ipt(yrs_months, age_from, age_to, gender, start_date, end_date)

    data = ActiveRecord::Base.connection.select_all <<EOF
    SELECT est.patient_id FROM temp_earliest_start_date est
    INNER JOIN temp_patient_outcomes tpo on tpo.patient_id = est.patient_id
    WHERE gender = '#{gender}' AND earliest_start_date <= '#{end_date.to_date}'
    AND timestampdiff(#{yrs_months}, birthdate, DATE('#{end_date.to_date}'))
    BETWEEN #{age_from} AND #{age_to}
    AND cum_outcome = "On antiretrovirals";
EOF

    return [] if data.blank?

    patient_ids = []

    (data).each do |d|
      patient_ids << d['patient_id'].to_i
    end

    amount_dispensed = ConceptName.find_by_name('Amount dispensed').concept_id
    ipt_drug_ids = Drug.find_all_by_concept_id(ConceptName.find_by_name('Isoniazid').concept_id).map(&:drug_id)

    data = ActiveRecord::Base.connection.select_all <<EOF
    SELECT obs.person_id patient_id FROM obs
    WHERE concept_id = #{amount_dispensed} AND obs.voided = 0
    AND obs.obs_datetime <= '#{end_date.to_date.strftime('%Y-%m-%d 23:59:59')}'
    AND value_drug IN(#{ipt_drug_ids.join(',')}) 
    AND obs.person_id IN (#{patient_ids.join(',')})
    GROUP BY obs.person_id;
EOF

    return data
  end

  def self.get_alive_on_art(yrs_months, age_from, age_to, gender, start_date, end_date)
    alive_on_art_patient_ids = []

    (@@cohort.total_alive_and_on_art || []).each do |data|
      alive_on_art_patient_ids << data['patient_id'].to_i
    end

    return [] if alive_on_art_patient_ids.blank?

    data = ActiveRecord::Base.connection.select_all <<EOF
    SELECT patient_id FROM temp_earliest_start_date
    WHERE gender = '#{gender}' AND date_enrolled <= '#{end_date.to_date}' AND
    patient_id IN(#{alive_on_art_patient_ids.join(',')})
    AND timestampdiff(#{yrs_months}, birthdate, DATE('#{end_date.to_date}'))
    BETWEEN #{age_from} AND #{age_to};
EOF

    return data

  end

  def self.get_started_on_art(yrs_months, age_from, age_to, gender, start_date, end_date)

    data = ActiveRecord::Base.connection.select_all <<EOF
    SELECT patient_id, date_enrolled FROM temp_earliest_start_date
    WHERE gender = '#{gender}' AND date_enrolled BETWEEN
    '#{start_date.to_date}' AND '#{end_date.to_date}' AND
    (DATE(date_enrolled) = DATE(earliest_start_date))
    AND timestampdiff(#{yrs_months}, birthdate, DATE(earliest_start_date))
    BETWEEN #{age_from} AND #{age_to}
EOF

    return data
  end

  def self.get_fp(start_date, end_date)
      age_from = 0  ; age_to = 1000 ; yrs_months = 'year' ; gender = 'F'
      cum_pregnant_women = @@cohort.total_pregnant_women

      return [[], [], [], []] if cum_pregnant_women.blank?
      pregnant_women_patient_ids = []

      (cum_pregnant_women).each do |p|
        date_enrolled_str = ActiveRecord::Base.connection.select_one <<EOF
        SELECT date_enrolled FROM temp_earliest_start_date e
        WHERE patient_id = #{p['person_id'].to_i};
EOF

        date_enrolled = date_enrolled_str['date_enrolled'].to_date
        if date_enrolled >= @@cohort_cum_start_date.to_date and end_date.to_date <= end_date.to_date
          pregnant_women_patient_ids << p['person_id'].to_i
        end
      end

      started_on_art = [] ; alive_on_art = []
      started_on_ipt = [] ; screened_for_tb = []

      (self.get_started_on_art(yrs_months, age_from, age_to, gender, start_date, end_date) || []).each do |p|
        next unless pregnant_women_patient_ids.include?(p['patient_id'].to_i)
        started_on_art << p
      end

      (self.get_alive_on_art(yrs_months, age_from, age_to, gender, @@cohort_cum_start_date, end_date) || []).each do |p|
        next unless pregnant_women_patient_ids.include?(p['patient_id'].to_i)
        alive_on_art << {:patient_id => p['patient_id'].to_i}
      end

      (self.get_started_on_ipt(yrs_months, age_from, age_to, gender, @@cohort_cum_start_date, end_date) || []).each do |p|
        next unless pregnant_women_patient_ids.include?(p['patient_id'].to_i)
        started_on_ipt << {:patient_id => p['patient_id'].to_i}
      end

      (self.get_screened_for_tb(yrs_months, age_from, age_to, gender, @@cohort_cum_start_date, end_date) || []).each do |p|
        next unless pregnant_women_patient_ids.include?(p['patient_id'].to_i)
        screened_for_tb << {:patient_id => p['patient_id'].to_i}
      end


      return [started_on_art, alive_on_art,
        started_on_ipt, screened_for_tb]
  end


  def self.get_fbf(start_date, end_date)
      age_from = 0  ; age_to = 1000 ; yrs_months = 'year' ; gender = 'F'
      cum_breastfeeding_mothers = @@cohort.total_breastfeeding_women

      return [[], [], [], []] if cum_breastfeeding_mothers.blank?
      fbf_women_patient_ids = []

      started_on_art = [] ; alive_on_art = []
      started_on_ipt = [] ; screened_for_tb = []


      #########################################################################
      cum_pregnant_women = @@cohort.total_pregnant_women
      pregnant_women_patient_ids = []

      (cum_pregnant_women).each do |p|
        date_enrolled_str = ActiveRecord::Base.connection.select_one <<EOF
        SELECT date_enrolled FROM temp_earliest_start_date e
        WHERE patient_id = #{p['person_id'].to_i};
EOF

        date_enrolled = date_enrolled_str['date_enrolled'].to_date
        if date_enrolled >= @@cohort_cum_start_date.to_date and end_date.to_date <= end_date.to_date
          pregnant_women_patient_ids << p['person_id'].to_i
        end
      end
      #########################################################################



      (cum_breastfeeding_mothers).each do |w|
        next if pregnant_women_patient_ids.include?(w['person_id'].to_i)
        date_enrolled_str = ActiveRecord::Base.connection.select_one <<EOF
        SELECT date_enrolled FROM temp_earliest_start_date e
        WHERE patient_id = #{w['person_id'].to_i};
EOF

        date_enrolled = date_enrolled_str['date_enrolled'].to_date
        if date_enrolled >= @@cohort_cum_start_date.to_date and end_date.to_date <= end_date.to_date
          fbf_women_patient_ids << w['person_id'].to_i
        end
      end

      (self.get_started_on_art(yrs_months, age_from, age_to, gender, start_date, end_date) || []).each do |fbf|
        next unless fbf_women_patient_ids.include?(fbf['patient_id'].to_i)
        started_on_art << {:patient_id => fbf['patient_id'].to_i, :date_enrolled => fbf['date_enrolled'].to_date}
      end

      (self.get_alive_on_art(yrs_months, age_from, age_to, gender, @@cohort_cum_start_date, end_date) || []).each do |fbf|
        next unless fbf_women_patient_ids.include?(fbf['patient_id'].to_i)
        alive_on_art << {:patient_id => fbf['patient_id'].to_i}
      end

      (self.get_started_on_ipt(yrs_months, age_from, age_to, gender, @@cohort_cum_start_date, end_date) || []).each do |fbf|
        next unless fbf_women_patient_ids.include?(fbf['patient_id'].to_i)
        started_on_ipt << {:patient_id => fbf['patient_id'].to_i}
      end

      (self.get_screened_for_tb(yrs_months, age_from, age_to, gender, @@cohort_cum_start_date, end_date) || []).each do |fbf|
        next unless fbf_women_patient_ids.include?(fbf['patient_id'].to_i)
        screened_for_tb << {:patient_id => fbf['patient_id'].to_i}
      end

      return [started_on_art, alive_on_art,
        started_on_ipt, screened_for_tb]
  end


end
