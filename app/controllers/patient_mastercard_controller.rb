class PatientMastercardController < ApplicationController

  def get_visit_dates
    patient_id = params[:patient_id]

    art_encounters = [
      'HIV CLINIC REGISTRATION','HIV RECEPTION',
      'VITALS','HIV STAGING',
      'HIV CLINIC CONSULTATION','ART ADHERENCE',
      'TREATMENT','DISPENSING'
    ]
    encounter_types = EncounterType.find(:all,:conditions =>["name IN(?)", art_encounters]).map(&:id)

    encounter_datetimes = []
    Encounter.find(:all,:conditions =>["patient_id = ? AND encounter_type IN(?)",
      patient_id, encounter_types], :group =>"DATE(encounter_datetime)").map do |e|
        encounter_datetimes << e.encounter_datetime.to_date
    end

    defaulted_dates = get_defaulted_dates(patient_id, Date.today)
    (defaulted_dates || []).each do |date|
      encounter_datetimes << date.to_date
    end 
  
    encounter_datetimes = encounter_datetimes.uniq rescue []
    render :text => (encounter_datetimes.map{|d| d.to_date.strftime('%Y-%m-%d')}.sort).to_json 
  end

  def get_visit
    visit_date = params[:visit_date].to_date
    patient_id = params[:patient_id].to_i

    height          = nil
    weight          = nil
    bmi             = nil
    regimen         = nil
    adherence       = nil
    side_effects    = nil
    pills_brought   = nil
    gave            = nil
    cpt             = nil
    outcome         = nil

    start_date  = visit_date.to_date.strftime('%Y-%m-%d 00:00:00')
    end_date    = visit_date.to_date.strftime('%Y-%m-%d 23:59;59')

    height_concept_id = ConceptName.find_by_name('Height (cm)').concept_id
    weight_concept_id = ConceptName.find_by_name('Weight (Kg)').concept_id
    

    height = Observation.find(:last, 
      :conditions =>["person_id = ? AND concept_id = ?
      AND obs_datetime BETWEEN ? AND ?", 
      patient_id, height_concept_id,
      start_date, end_date]).value_numeric rescue nil

    weight = Observation.find(:last, 
      :conditions =>["person_id = ? AND concept_id = ?
      AND obs_datetime BETWEEN ? AND ?", 
      patient_id, weight_concept_id,
      start_date, end_date]).value_numeric rescue nil
    
    if not weight.blank? and not height.blank?
      bmi = (weight.to_f/(height.to_f*height.to_f)*10000).round(1)
    end

    regimen         = get_regimen(patient_id, visit_date)
    gave            = get_pills_gave(patient_id, visit_date)
    adherence       = get_adherence(patient_id, visit_date)
    side_effects    = get_side_effects(patient_id, visit_date)
    pills_brought   = get_pills_brought(patient_id, visit_date)

    if bmi.blank? 
      age = Person.find(patient_id).age(visit_date.to_date)
      if age >= 18
        height_obs = Observation.find(:last, 
          :conditions =>["concept_id = ? AND person_id = ? AND obs_datetime <= ?",
          ConceptName.find_by_name('Height (cm)').concept_id, patient_id, end_date])

        if not height_obs.blank? and not weight.blank?
          begin
            previous_height = height_obs.value_numeric.blank? ? height_obs.value_text : height_obs.value_numeric
            bmi = (weight.to_f/(previous_height.to_f*previous_height.to_f)*10000).round(1)
          rescue
            bmi = nil
          end
        end
      end
    end

    render :text => {
      :height          => height,
      :weight          => weight,
      :bmi             => bmi,
      :regimen         => regimen,
      :art_adherences  => adherence,
      :side_effects    => side_effects,
      :pills_brought   => pills_brought,
      :pills_gave      => gave,
      :cpt             => cpt,
      :outcome         => get_outcome(patient_id, visit_date),
      :visit_date      => visit_date.to_date.strftime('%Y-%m-%d')
    }.to_json 
  end


  private
 
 
 
  def get_pills_brought(patient_id, visit_date)
    concpet = ConceptName.find_by_name('AMOUNT OF DRUG BROUGHT TO CLINIC')
    start_date  = visit_date.to_date.strftime('%Y-%m-%d 00:00:00')
    end_date    = visit_date.to_date.strftime('%Y-%m-%d 23:59;59')

    data = Observation.find(:all, 
      :conditions =>["person_id = ? AND concept_id = ?
      AND obs_datetime BETWEEN ? AND ?", 
      patient_id, concpet.concept_id, start_date, end_date])

    pills_brought = []
    (data || []).each do |i|
      drug_order = Order.find(i.order_id).drug_order rescue []
      next if drug_order.blank?
      name = drug_order.drug.name rescue ''
      pills_brought << {
        :name       =>  (drug_order.drug.name rescue nil),
        :short_name =>  (drug_order.drug.concept.shortname rescue nil),
        :quantity   => i.value_numeric
      }
    end

    return pills_brought
  end
  
  def get_adherence(patient_id, visit_date)
    adherence_concpet = ConceptName.find_by_name('What was the patients adherence for this drug order')
    start_date  = visit_date.to_date.strftime('%Y-%m-%d 00:00:00')
    end_date    = visit_date.to_date.strftime('%Y-%m-%d 23:59;59')

    adherences = Observation.find(:all, 
      :conditions =>["person_id = ? AND concept_id = ?
      AND obs_datetime BETWEEN ? AND ?", 
      patient_id, adherence_concpet.concept_id, start_date, end_date])

    art_adherences = []
    unless adherences.blank?
      (adherences || []).each do |adherence|
        drug_order = Order.find(adherence.order_id).drug_order rescue []
        next if drug_order.blank?
        
        adherence_rate = adherence.value_text
        if not adherence_rate.blank? and not adherence_rate.match(/\%/)
          adherence_rate = "#{adherence.value_text}%"
        end
          
        name = drug_order.drug.name rescue ''
        art_adherences << {
          :name       =>  (drug_order.drug.name rescue nil),
          :short_name =>  (drug_order.drug.concept.shortname rescue nil),
          :adherence   =>  adherence_rate
        }
      end
    end

    return art_adherences
  end

  def get_regimen(patient_id, visit_date)
    amount_dispensed = ConceptName.find_by_name('AMOUNT DISPENSED').concept_id
    start_date  = visit_date.to_date.strftime('%Y-%m-%d 00:00:00')
    end_date    = visit_date.to_date.strftime('%Y-%m-%d 23:59;59')

    dispensed = Observation.find(:last, 
      :conditions =>["person_id = ? AND concept_id = ?
      AND obs_datetime BETWEEN ? AND ?", 
      patient_id, amount_dispensed, start_date, end_date])

    unless dispensed.blank?
    reg = ActiveRecord::Base.connection.select_one <<EOF
            SELECT patient_current_regimen(#{patient_id}, DATE('#{visit_date.to_date}')) AS regimen_category;
EOF

      return reg['regimen_category']
    end

    return nil
  end

  def get_pills_gave(patient_id, visit_date)
    order_type = OrderType.find_by_name('Drug Order').id
    start_date  = visit_date.to_date.strftime('%Y-%m-%d 00:00:00')
    end_date    = visit_date.to_date.strftime('%Y-%m-%d 23:59;59')

    orders = Order.find(:all, :conditions =>["patient_id = ? AND order_type_id = ?
      AND start_date BETWEEN ? AND ?", patient_id, order_type, start_date, end_date])

    gave = []
    (orders || []).each do |order|
      drug_order = order.drug_order rescue []
      next if drug_order.blank?
      name = drug_order.drug.name rescue ''
      gave << {
        :name       =>  (drug_order.drug.name rescue nil),
        :short_name =>  (drug_order.drug.concept.shortname rescue nil),
        :quantity   =>  drug_order.quantity
      }
    end

    return gave
  end

  def get_side_effects(patient_id, visit_date)
  	drug_induced_concept_id = ConceptName.find_by_name('Drug induced').concept_id
    malawi_art_side_effects_concept_id = ConceptName.find_by_name('Malawi ART side effects').concept_id
    no_side_effects_concept_id = ConceptName.find_by_name('No').concept_id
    yes_side_effects_concept_id = ConceptName.find_by_name('Yes').concept_id

    malawi_side_effects_ids =  ActiveRecord::Base.connection.select_all <<EOF
SELECT t1.person_id patient_id, t1.obs_id, value_coded, t1.obs_datetime 
FROM obs t1 
where t1.person_id = #{patient_id}
AND t1.voided = 0 AND concept_id IN(#{malawi_art_side_effects_concept_id}, #{drug_induced_concept_id})
AND t1.obs_datetime = (SELECT max(obs_datetime) FROM obs t2
WHERE t2.voided = 0 AND t2.person_id = t1.person_id
AND t2.concept_id IN(#{malawi_art_side_effects_concept_id}, #{drug_induced_concept_id}) 
AND t2.obs_datetime BETWEEN '#{visit_date.to_date.strftime('%Y-%m-%d 00:00:00')}'
AND '#{visit_date.to_date.strftime('%Y-%m-%d 23:59:59')}'
) GROUP BY t1.person_id, t1.value_coded
#HAVING DATE(obs_datetime) != DATE(earliest_start_date);
EOF

    results = []
    (malawi_side_effects_ids || []).each do |row|
      obs_group = Observation.find(:first, 
        :conditions =>["concept_id = ? AND obs_group_id = ?",
          row['value_coded'].to_i, row['obs_id'].to_i]) rescue nil 

      if obs_group.blank?
          next if no_side_effects_concept_id == row['value_coded'].to_i
          results << ConceptName.find_by_concept_id(row['value_coded']).name
      elsif obs_group.value_coded == yes_side_effects_concept_id
          results << ConceptName.find_by_concept_id(obs_group.concept_id).name
      end
    end

    return results
  end

  def get_outcome(patient_id, visit_date)
    patient_outcome = ActiveRecord::Base.connection.select_one <<EOF
            SELECT patient_outcome(#{patient_id}, DATE('#{visit_date.to_date}')) AS outcome;
EOF

    outcome = patient_outcome['outcome']
    outcome = 'On ART' if outcome.match(/On ant/i)
    return outcome
  end



  
  def get_defaulted_dates(patient_id, current_date)
    #raise session_date.to_yaml
    #getting all patient's dispensations encounters
    all_dispensations = Observation.find_by_sql("SELECT obs.person_id, obs.obs_datetime AS obs_datetime, d.order_id
      FROM drug_order d
        LEFT JOIN orders o ON d.order_id = o.order_id
        LEFT JOIN obs ON d.order_id = obs.order_id
      WHERE d.drug_inventory_id IN (SELECT drug_id FROM drug WHERE concept_id IN (SELECT concept_id FROM concept_set WHERE concept_set = 1085))
      AND quantity > 0 AND obs.voided = 0 AND o.voided = 0 AND obs.person_id = #{patient_id}
      GROUP BY DATE(obs_datetime) ORDER BY obs_datetime")

    outcome_dates = []
    dates = 0
    total_dispensations = all_dispensations.length
    defaulted_dates = all_dispensations.map(&:obs_datetime)

    all_dispensations.each do |disp_date|
      d = ((dates - total_dispensations) + 1)

      prev_dispenation_date = all_dispensations[d].obs_datetime.to_date

      if d == 0
        previous_date = current_date
        defaulted_state = ActiveRecord::Base.connection.select_value "
        SELECT current_defaulter(#{disp_date.person_id},'#{previous_date}')"

        if defaulted_state.to_i == 1
          defaulted_date = ActiveRecord::Base.connection.select_value "
            SELECT current_defaulter_date(#{disp_date.person_id}, '#{previous_date}')"

          #Assumption that the patient started taking the dose the first day of receiving
          outcome_dates << (defaulted_date.to_date - 1.day) if !defaulted_dates.include?(defaulted_date.to_date)
        end
      else
        previous_date = prev_dispenation_date.to_date

        defaulted_state = ActiveRecord::Base.connection.select_value "
        SELECT current_defaulter(#{disp_date.person_id},'#{previous_date}')"

        if defaulted_state.to_i == 1
          defaulted_date = ActiveRecord::Base.connection.select_value "
            SELECT current_defaulter_date(#{disp_date.person_id}, '#{previous_date}')"


	  next if defaulted_date.blank?
          #Assumption that the patient started taking the dose the first day of receiving
          outcome_dates << (defaulted_date.to_date - 1.day) if !defaulted_dates.include?(defaulted_date.to_date)
        end
      end

      dates += 1
    end
    #raise outcome_dates.to_yaml
    return outcome_dates
  end


end
