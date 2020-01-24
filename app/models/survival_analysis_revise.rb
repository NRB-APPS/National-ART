class SurvivalAnalysisRevise

  def self.get_indicators(start_date, end_date, quarter_type)
  time_started = Time.now().strftime('%Y-%m-%d %H:%M:%S')
#=begin
  CohortRevise.create_temp_earliest_start_date_table(end_date)
  CohortRevise.update_cum_outcome(end_date)
#=end
    #Get earliest date enrolled
    cum_start_date = self.get_cum_start_date
    survival_start_date = start_date.to_date
    survival_end_date = end_date.to_date

    date_ranges = []
    cohort = CohortService.new(cum_start_date)

    if quarter_type == "Women"
			start_of_6_months = survival_start_date - 6.months
			end_of_6_months = survival_end_date.to_date - 6.months

			if end_of_6_months >= cum_start_date
		    date_ranges << {:start_date => start_of_6_months.to_date,
		                    :end_date   => end_of_6_months.to_date}
			end
		end

    while (survival_start_date -= 1.year) >= cum_start_date
      survival_end_date   -= 1.year
      date_ranges << {:start_date => survival_start_date,
                      :end_date   => survival_end_date
      }
    end
=begin
    The number of patients registered at ART within the 12 months
=end
    states = {}; women_outcomes = {}; children_outcomes = {}; pregnant_and_breast_feeding_women={};
    interval = ""

    date_ranges.sort_by {|x,i| x[:end_date] <=>  x[:start_date]}.each_with_index do |range, i|

      if quarter_type == "Women"
        if i == 0
      	   interval = "#{(i + 1)*6}"
      	else
      		 x = i - 1
      		 interval = "#{(x + 1)*12}"
      	end
      else
      	  interval = "#{(i + 1)*12}"
       end

      states[interval.to_i] = self.general_analysis(range[:start_date], range[:end_date])
      pregnant_and_breast_feeding_women[interval.to_i] = self.pregnant_and_breast_feeding_women(range[:start_date], range[:end_date])
      children_outcomes[interval.to_i] = self.children_analysis(range[:start_date], range[:end_date], 0, 14)
    end

    cohort.general_survival_analysis = states
    cohort.women_survival_analysis = pregnant_and_breast_feeding_women
    cohort.children_survival_analysis = children_outcomes

    puts "Started at: #{time_started}. Finished at: #{Time.now().strftime('%Y-%m-%d %H:%M:%S')}"

    return cohort
  end


  private
  def self.get_cum_start_date
    cum_start_date = ActiveRecord::Base.connection.select_value <<EOF
      SELECT MIN(date_enrolled) FROM temp_earliest_start_date;
EOF

    return cum_start_date.to_date rescue nil
  end

  def self.pregnant_and_breast_feeding_women(start_date, end_date)
    patient_details = []; registered = {} ; patient_id_plus_date_enrolled = []; outcomes = []

    number_of_new_patients_registered = []; number_alive_and_on_arvs = []
    number_dead = []; number_defaulted = []; number_stopped_treatment = []
    number_transferred_out = []; number_unknown =[]

    yes_concept_id = ConceptName.find_by_name('Yes').concept_id

    #breastfeeding_women
    breastfeeding_concept_ids = [ConceptName.find_by_name('Breastfeeding').concept_id,
                  ConceptName.find_by_name('Is patient breast feeding?').concept_id,
                  ConceptName.find_by_name('Breast feeding?').concept_id]

    breastfeeding_women = ActiveRecord::Base.connection.select_all <<EOF
      SELECT * FROM temp_earliest_start_date t
        INNER JOIN obs o ON o.person_id = t.patient_id AND o.voided = 0
      WHERE date_enrolled BETWEEN '#{start_date}' AND '#{end_date}'
      AND (o.concept_id IN (#{breastfeeding_concept_ids.join(', ')}) AND o.value_coded = #{yes_concept_id})
      AND (gender = 'F' OR gender = 'Female') GROUP BY patient_id;
EOF

    #pregnant women
    pregnant_concept_ids =[ConceptName.find_by_name('IS PATIENT PREGNANT?').concept_id,
                  ConceptName.find_by_name('PATIENT PREGNANT').concept_id,
                  ConceptName.find_by_name('PREGNANT AT INITIATION?').concept_id]

     pregnant_women = ActiveRecord::Base.connection.select_all <<EOF
              SELECT t.* , o.value_coded FROM temp_earliest_start_date t
                INNER JOIN obs o ON o.person_id = t.patient_id AND o.voided = 0
              WHERE date_enrolled BETWEEN '#{start_date}' AND '#{end_date}'
              AND (gender = 'F' OR gender = 'Female')
              AND o.concept_id IN (#{pregnant_concept_ids.join(', ')})
              AND (gender = 'F' OR gender = 'Female')
              AND DATE(o.obs_datetime) = DATE(t.earliest_start_date)
              GROUP BY patient_id
              HAVING value_coded = #{yes_concept_id};
EOF

    (pregnant_women || []).each do |patient|
      patient_id_plus_date_enrolled << [patient['patient_id'].to_i, patient['date_enrolled'].to_date]
    end

    patient_ids = []
    (patient_id_plus_date_enrolled || []).each do |patient_id, patient_date_enrolled|
      patient_ids << patient_id.to_i
    end

    (breastfeeding_women || []).each do |aRow|
      patient_ids << aRow['person_id'].to_i
    end

    outcomes = self.get_survival_analysis_outcome(patient_ids, start_date, end_date)
    quarter = Report.generate_quarter(end_date.to_date)

    (outcomes || []).each do |row|
      if row['cum_outcome'] == 'On antiretrovirals'
        number_alive_and_on_arvs << row
      elsif row['cum_outcome'] == 'Defaulted'
        number_defaulted << row
      elsif row['cum_outcome'] == 'Patient transferred out'
        number_transferred_out << row
      elsif row['cum_outcome'] == 'Patient died'
        number_dead << row
      elsif row['cum_outcome'] == 'Treatment stopped'
        number_stopped_treatment << row
      else
      end
    end

    registered = {
      'Quarter' => start_date.to_date.strftime("%Y"),
      "quarter_name" => quarter,
      "number_of_new_patients_registered" => patient_ids.uniq,
      "number_alive_and_on_arvs" => number_alive_and_on_arvs,
      "number_defaulted" => number_defaulted,
      "number_dead" => number_dead,
      "number_stopped_treatment" => number_stopped_treatment,
      "number_transferred_out" => number_transferred_out
    }
    return registered
  end

  def self.children_analysis(start_date, end_date, min_age, max_age)
    registered = {}; data = []
    number_of_new_patients_registered = []; number_alive_and_on_arvs = []
    number_dead = []; number_defaulted = []; number_stopped_treatment = []
    number_transferred_out = []; number_unknown =[]

    total_registered = ActiveRecord::Base.connection.select_all <<EOF
      SELECT e.*, o.cum_outcome cum_outcome FROM temp_earliest_start_date e
      RIGHT JOIN temp_patient_outcomes o 
      ON o.patient_id = e.patient_id
      WHERE e.date_enrolled BETWEEN '#{start_date}' AND '#{end_date}'
      AND e.age_at_initiation <= '#{max_age}' GROUP BY patient_id;
EOF

    (total_registered || []).each do |patient|
      data << patient['patient_id'].to_i
    end

    quarter = Report.generate_quarter(end_date.to_date)

    data = [] if data.blank?

    (total_registered || []).each do |row|
      #raise row['cum_outcome'].inspect
      if row['cum_outcome'] == 'On antiretrovirals'
        number_alive_and_on_arvs << row
      elsif row['cum_outcome'] == 'Defaulted'
        number_defaulted << row
      elsif row['cum_outcome'] == 'Patient transferred out'
        number_transferred_out << row
      elsif row['cum_outcome'] == 'Patient died'
        number_dead << row
      elsif row['cum_outcome'] == 'Treatment stopped'
        number_stopped_treatment << row
      else
      end
    end

    registered = {
      'Quarter' => start_date.to_date.strftime("%Y"),
      "quarter_name" => quarter,
      "number_of_new_patients_registered" => data,
      "number_alive_and_on_arvs" => number_alive_and_on_arvs,
      "number_defaulted" => number_defaulted,
      "number_dead" => number_dead,
      "number_stopped_treatment" => number_stopped_treatment,
      "number_transferred_out" => number_transferred_out
    }
    return registered
  end

  def self.general_analysis(start_date, end_date)
    registered = {}; data = []
    number_of_new_patients_registered = []; number_alive_and_on_arvs = []
    number_dead = []; number_defaulted = []; number_stopped_treatment = []
    number_transferred_out = []; number_unknown =[]

    total_registered = ActiveRecord::Base.connection.select_all <<EOF
      SELECT e.*, o.cum_outcome cum_outcome FROM temp_earliest_start_date e
      RIGHT JOIN temp_patient_outcomes o 
      ON o.patient_id = e.patient_id
      WHERE e.date_enrolled BETWEEN '#{start_date}' AND '#{end_date}'
      AND date_enrolled <= '#{end_date}' GROUP BY patient_id;
EOF

    (total_registered || []).each do |patient|
      data << patient['patient_id'].to_i
    end

    data = [] if data.blank?

    (total_registered || []).each do |row|
      if row['cum_outcome'] == 'On antiretrovirals'
        number_alive_and_on_arvs << row
      elsif row['cum_outcome'] == 'Defaulted'
        number_defaulted << row
      elsif row['cum_outcome'] == 'Patient transferred out'
        number_transferred_out << row
      elsif row['cum_outcome'] == 'Patient died'
        number_dead << row
      elsif row['cum_outcome'] == 'Treatment stopped'
        number_stopped_treatment << row
      else
      end
    end

    quarter = Report.generate_quarter(end_date.to_date)

    registered = {
      'Quarter' => start_date.to_date.strftime("%Y"),
      "quarter_name" => quarter,
      "number_of_new_patients_registered" => data,
      "number_alive_and_on_arvs" => number_alive_and_on_arvs,
      "number_defaulted" => number_defaulted,
      "number_dead" => number_dead,
      "number_stopped_treatment" => number_stopped_treatment,
      "number_transferred_out" => number_transferred_out
    }
    return registered
  end

  def self.get_survival_analysis_outcome(data, start_date, end_date)
    registered = []
    patient_ids = []

    data = [0] if data.blank?

    patient_ids = [0] if patient_ids.blank?

    total_alive_and_on_art = ActiveRecord::Base.connection.select_all <<EOF
      SELECT * FROM temp_patient_outcomes
      WHERE patient_id IN (#{data.join(', ')})
      GROUP BY patient_id;
EOF
    (total_alive_and_on_art || []).each do |patient|
      registered << patient
    end
    return registered
  end


end
