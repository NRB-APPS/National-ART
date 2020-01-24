module VitalsService

  def self.weight_trail(patient, session_date)
    person = patient.person

    concept_id = ConceptName.find_by_name("Weight (Kg)").concept_id
    session_date = (session[:datetime].to_date rescue Date.today).strftime('%Y-%m-%d 23:59:59')
    obs = []

    weight_trail = {} ; current_date = (session_date.to_date - 2.year).to_date

    weights = ActiveRecord::Base.connection.select_all <<EOF
    SELECT * FROM obs WHERE person_id = #{patient.id}
    AND concept_id = #{concept_id} AND voided = 0 AND 
    obs_datetime BETWEEN '#{(session_date.to_date - 2.year).strftime('%Y-%m-%d 00:00:00')}' 
    AND '#{session_date}' ORDER BY obs_datetime LIMIT 100;
EOF

    vitals = {}
    vitals['weight_trail']      = self.get_weight_trail(weights)
    vitals['weight_height_for_age'] = self.get_weight_height_for_age(person, session_date, weights) 
    vitals['weight_for_age']    = self.get_weight_for_age(weights) rescue {}
  
    return vitals
  end


  def self.get_weight_trail(weights)
    weight_trail = {}

    (weights || []).each do |weight|
      current_date = weight['obs_datetime'].to_date

      begin
        weight_trail[current_date] =  weight['value_numeric'].squish.to_f
      rescue
        next
      end

    end

    return weight_trail
  end

  def self.get_weight_height_for_age(person, session_date, weights)
    birthdate = person.birthdate.to_date rescue nil

    months = ActiveRecord::Base.connection.select_one <<EOF
    SELECT timestampdiff(month, DATE('#{birthdate.to_date}'), DATE('#{session_date.to_date}')) AS `month`;
EOF

    age_in_months = (session_date.to_date.year * 12 + session_date.to_date.month) - (birthdate.year * 12 + birthdate.month)
    sex = (person.gender == 'Male' || person.gender == 'M') ? 0 : 1
    weight_height_for_ages = {}

    age_in_months += 5 if age_in_months < 53
    weight_heights = WeightHeightForAge.find(:all,
      :conditions => ["sex = ? AND age_in_months BETWEEN 0 AND ?", sex, age_in_months])

    (weight_heights || []).each do |data|

      m = data.median_weight.to_f
      l = data.standard_low_weight.to_f
      h = data.standard_high_weight.to_f

      weight_height_for_ages[data.age_in_months] = {
        :median_weight => m.round(2) ,
        :standard_low_weight => (m - l).round(2),
        :standard_high_weight => (m + h).round(2)
      }
    end

    ###################################################################
    weight_trail = {}

    (weights || []).each do |weight|
      current_date = weight['obs_datetime'].to_date
      year = current_date.year

      months = ActiveRecord::Base.connection.select_one <<EOF
        SELECT timestampdiff(month, DATE('#{birthdate.to_date}'), DATE('#{current_date.to_date}')) AS `month`;
EOF

      month = months['month'].to_i
      next if month > 58
      begin
        weight_trail[month] =  weight['value_numeric'].squish.to_f
        #whfa = weight_height_for_ages[month]
        #w =  weight['value_numeric'].squish.to_f
        #m = whfa[:median_weight] ; l = whfa[:standard_low_weight]
        #s = whfa[:standard_high_weight]

        #weight_trail[month] = ((w/m)**l - 1) / (l * s)
      rescue
        next
      end

    end
    
    sorted_weight_trail = []
    (weight_trail || {}).sort_by{|x, y | x}.each do |m, weight|
      sorted_weight_trail << [m, weight.to_f]
    end

    ###################################################################

    return [sorted_weight_trail, weight_height_for_ages]
  end

end
