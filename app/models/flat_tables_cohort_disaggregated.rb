class FlatTablesCohortDisaggregated

  def self.get_indicators(start_date, end_date)
    time_started = Time.now().strftime('%Y-%m-%d %H:%M:%S')
    #######################################################################################################

    #Get earliest date enrolled
    cum_start_date = FlatTablesCohort.get_cum_start_date
    cohort = CohortService.new(cum_start_date)  

    puts "Started at: #{time_started}. Finished at: #{Time.now().strftime('%Y-%m-%d %H:%M:%S')}"
    return cohort

  end

  def self.get_total_alive_and_on_arvs
    @@total_alive_and_on_art = ActiveRecord::Base.connection.select_all <<EOF
      SELECT * FROM temp_flat_tables_patient_outcomes WHERE cum_outcome = 'On antiretrovirals';
EOF
    return @@total_alive_and_on_art
  end

  def self.get_data(start_date, end_date, gender, age_group, cohort)

    @@cohort = cohort
    @@cohort_cum_start_date = FlatTablesCohort.get_cum_start_date

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
    (get_total_breastfeeding_women(start_date, end_date, get_total_alive_and_on_arvs) || []).each do |p|
      date_enrolled_str = ActiveRecord::Base.connection.select_one <<EOF
      SELECT date_enrolled FROM flat_cohort_table e
      WHERE patient_id = #{p['patient_id']};
EOF

      date_enrolled = date_enrolled_str['date_enrolled'].to_date
      if date_enrolled >= start_date.to_date and end_date.to_date <= end_date.to_date
        breast_feeding_women << p['patient_id'].to_i
        breast_feeding_women = breast_feeding_women.uniq
      else
        cum_breast_feeding_women << p['patient_id'].to_i
        cum_breast_feeding_women = cum_breast_feeding_women.uniq
      end
    end

    cum_pregnant_women = get_total_pregnant_women(start_date, end_date, get_total_alive_and_on_arvs)
    (cum_pregnant_women || []).each do |p|
      next if breast_feeding_women.include?(p['patient_id'].to_i)

      date_enrolled_str = ActiveRecord::Base.connection.select_one <<EOF
        SELECT date_enrolled FROM flat_cohort_table e
        WHERE patient_id = #{p['patient_id'].to_i};
EOF

      date_enrolled = date_enrolled_str['date_enrolled'].to_date
      if date_enrolled >= start_date.to_date and end_date.to_date <= end_date.to_date
        females_pregnant << p['patient_id'].to_i
        females_pregnant = females_pregnant.uniq
      else
        cum_females_pregnant << p['patient_id'].to_i
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

    (get_total_alive_and_on_arvs || []).each do |data|
      alive_on_art_patient_ids << data['patient_id'].to_i
    end

    return [] if alive_on_art_patient_ids.blank?

    data = ActiveRecord::Base.connection.select_all <<EOF
      SELECT fct.patient_id FROM flat_cohort_table fct
        INNER JOIN flat_table2 ft2 on ft2.patient_id = fct.patient_id
      WHERE ft2.tb_status IS NOT NULL AND ft2.visit_date BETWEEN '#{start_date.to_date.strftime('%Y-%m-%d 00:00:00')}' AND '#{end_date.to_date.strftime('%Y-%m-%d 23:59:59')}'
    AND fct.gender = '#{gender.first}' AND fct.date_enrolled BETWEEN '#{start_date.to_date}' AND '#{end_date.to_date}' 
    AND timestampdiff(#{yrs_months}, birthdate, DATE('#{end_date.to_date}')) BETWEEN #{age_from} AND #{age_to} 
    AND fct.patient_id IN(#{alive_on_art_patient_ids.join(',')})
    AND ft2.visit_date = ( 
      SELECT max(t3.visit_date) FROM flat_table2 t3
      WHERE t3.visit_date BETWEEN '#{start_date.to_date.strftime('%Y-%m-%d 00:00:00')}' AND '#{end_date.to_date.strftime('%Y-%m-%d 23:59:59')}'
      AND t3.tb_status IS NOT NULL AND t3.patient_id = ft2.patient_id
    )
    GROUP BY ft2.patient_id;


EOF
    return data rescue 0

  end


  def self.get_started_on_ipt(yrs_months, age_from, age_to, gender, start_date, end_date)

    data = ActiveRecord::Base.connection.select_all <<EOF
    SELECT patient_id FROM flat_cohort_table
    WHERE gender = '#{gender}' AND earliest_start_date <= '#{end_date.to_date}'
    AND timestampdiff(#{yrs_months}, birthdate, DATE('#{end_date.to_date}'))
    BETWEEN #{age_from} AND #{age_to};
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
    AND value_drug IN(#{ipt_drug_ids.join(',')}) AND obs.person_id IN(#{patient_ids.join(',')});
EOF

    return data
  end

  def self.get_alive_on_art(yrs_months, age_from, age_to, gender, start_date, end_date)
    alive_on_art_patient_ids = []

    (get_total_alive_and_on_arvs || []).each do |data|
      alive_on_art_patient_ids << data['patient_id'].to_i
    end

    return [] if alive_on_art_patient_ids.blank?

    data = ActiveRecord::Base.connection.select_all <<EOF
    SELECT patient_id FROM flat_cohort_table
    WHERE gender = '#{gender}' AND date_enrolled <= '#{end_date.to_date}' AND
    patient_id IN(#{alive_on_art_patient_ids.join(',')})
    AND timestampdiff(#{yrs_months}, birthdate, DATE('#{end_date.to_date}'))
    BETWEEN #{age_from} AND #{age_to};
EOF

    return data

  end

  def self.get_started_on_art(yrs_months, age_from, age_to, gender, start_date, end_date)

    data = ActiveRecord::Base.connection.select_all <<EOF
    SELECT patient_id, date_enrolled FROM flat_cohort_table
    WHERE gender = '#{gender}' AND date_enrolled BETWEEN
    '#{start_date.to_date}' AND '#{end_date.to_date}' AND
    (DATE(date_enrolled) = DATE(earliest_start_date))
    AND timestampdiff(#{yrs_months}, birthdate, DATE(earliest_start_date))
    BETWEEN #{age_from} AND #{age_to}
EOF

    return data
  end

  def self.get_total_pregnant_women(start_date, end_date, patient_ids)
    alive_patient_ids = []

    (patient_ids || []).each do |patient|
      alive_patient_ids << patient['patient_id'].to_i
    end

   data = ActiveRecord::Base.connection.select_all <<EOF
      SELECT fct.patient_id, ft2.visit_date, ft2.patient_pregnant
      FROM flat_cohort_table fct
      INNER JOIN flat_table2 ft2 ON ft2.patient_id = fct.patient_id
      WHERE ft2.patient_pregnant = 'Yes' AND ft2.patient_pregnant IS NOT NULL
      AND (ft2.visit_date <= '#{end_date}')
      AND fct.patient_id IN (#{alive_patient_ids.join(',')})
      AND ft2.visit_date = (SELECT max(visit_date) from flat_table2 f2
      WHERE f2.patient_id = ft2.patient_id
      AND f2.visit_date <= '#{end_date}'
      AND f2.patient_pregnant IS NOT NULL)
      GROUP BY fct.patient_id;
EOF
  
    return data
  end

  def self.get_fp(start_date, end_date)
      age_from = 0  ; age_to = 1000 ; yrs_months = 'year' ; gender = 'F'
      cum_pregnant_women = get_total_pregnant_women(start_date, end_date, get_total_alive_and_on_arvs)

      return [[], [], [], []] if cum_pregnant_women.blank?
      pregnant_women_patient_ids = []

      (cum_pregnant_women).each do |p|
        date_enrolled_str = ActiveRecord::Base.connection.select_one <<EOF
        SELECT date_enrolled FROM flat_cohort_table e
        WHERE patient_id = #{p['patient_id'].to_i};
EOF

        date_enrolled = date_enrolled_str['date_enrolled'].to_date
        if date_enrolled >= @@cohort_cum_start_date.to_date and end_date.to_date <= end_date.to_date
          pregnant_women_patient_ids << p['patient_id'].to_i
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

  def self.get_total_breastfeeding_women(start_date, end_date, patient_ids) 
    alive_patient_ids = []

    (patient_ids || []).each do |patient|
      alive_patient_ids << patient['patient_id'].to_i
    end

   data = ActiveRecord::Base.connection.select_all <<EOF
      SELECT fct.patient_id, ft2.visit_date, ft2.patient_breastfeeding
      FROM flat_cohort_table fct
      INNER JOIN flat_table2 ft2  ON ft2.patient_id = fct.patient_id
      WHERE ft2.patient_breastfeeding = 'Yes' AND ft2.patient_breastfeeding IS NOT NULL
      AND (ft2.visit_date <= '#{end_date}')
      AND fct.patient_id IN (#{alive_patient_ids.join(',')})
      AND ft2.visit_date = (SELECT max(visit_date) from flat_table2 f2
      WHERE f2.patient_id = fct.patient_id
      AND f2.visit_date <= '#{end_date}'
      AND f2.patient_breastfeeding IS NOT NULL)
      GROUP BY fct.patient_id;
EOF
  
    return data  
  end

  def self.get_fbf(start_date, end_date)
      age_from = 0  ; age_to = 1000 ; yrs_months = 'year' ; gender = 'F'
      cum_breastfeeding_mothers = get_total_breastfeeding_women(start_date, end_date, get_total_alive_and_on_arvs)

      return [[], [], [], []] if cum_breastfeeding_mothers.blank?
      fbf_women_patient_ids = []

      started_on_art = [] ; alive_on_art = []
      started_on_ipt = [] ; screened_for_tb = []


      #########################################################################
      cum_pregnant_women = get_total_pregnant_women(start_date, end_date, get_total_alive_and_on_arvs)
      pregnant_women_patient_ids = []

      (cum_pregnant_women).each do |p|
        date_enrolled_str = ActiveRecord::Base.connection.select_one <<EOF
        SELECT date_enrolled FROM flat_cohort_table e
        WHERE patient_id = #{p['patient_id'].to_i};
EOF

        date_enrolled = date_enrolled_str['date_enrolled'].to_date
        if date_enrolled >= @@cohort_cum_start_date.to_date and end_date.to_date <= end_date.to_date
          pregnant_women_patient_ids << p['patient_id'].to_i
        end
      end
      #########################################################################



      (cum_breastfeeding_mothers).each do |w|
        next if pregnant_women_patient_ids.include?(w['patient_id'].to_i)
        date_enrolled_str = ActiveRecord::Base.connection.select_one <<EOF
        SELECT date_enrolled FROM flat_cohort_table e
        WHERE patient_id = #{w['patient_id'].to_i};
EOF

        date_enrolled = date_enrolled_str['date_enrolled'].to_date
        if date_enrolled >= @@cohort_cum_start_date.to_date and end_date.to_date <= end_date.to_date
          fbf_women_patient_ids << w['patient_id'].to_i
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
