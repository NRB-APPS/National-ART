#Adding regimen category observation to all dispensing encounter

  User.current = User.find(1)
  
  ART_ADHERENCE_ENC = EncounterType.find_by_name('ART ADHERENCE')
  Drug_order_adherence = ConceptName.find_by_name('Drug order adherence')
  Amount_of_drug_brought_to_clinic = ConceptName.find_by_name('Amount of drug brought to clinic')
  Amount_dispensed = ConceptName.find_by_name('Amount dispensed')
  ARV_drug_ids = MohRegimenIngredient.all.map(&:drug_inventory_id)
  DISPENSING_ENC = EncounterType.find_by_name('DISPENSING')

  def delete_all
    ActiveRecord::Base.connection.execute <<EOF
    UPDATE obs SET voided = 1, void_reason = 'Recalculate adherence' 
    WHERE voided = 0 AND concept_id = #{Drug_order_adherence.concept_id};
EOF

  end

  def start
    start_time = Time.now()
    puts "Started at: #{start_time.strftime('%A, %d %b %Y  %H:%M:%S')}"
    amount_of_drug_brought_to_clinic = {}
    observations = Observation.find(:all, 
      :joins =>"INNER JOIN drug_order d ON d.order_id = obs.order_id",
      :conditions =>["concept_id = ? AND d.drug_inventory_id in(?)", 
      Amount_of_drug_brought_to_clinic.concept_id, ARV_drug_ids])

    (observations || []).each_with_index do |ob, i|
      if amount_of_drug_brought_to_clinic[ob.person_id].blank?
        amount_of_drug_brought_to_clinic[ob.person_id] = {} 
      end

      if amount_of_drug_brought_to_clinic[ob.person_id][ob.obs_datetime.to_date].blank?
        amount_of_drug_brought_to_clinic[ob.person_id][ob.obs_datetime.to_date] = []
      end
       
      value_drug = (DrugOrder.find_by_order_id(ob.order_id).drug_inventory_id) 
      days_gone , amount_dispensed  = pills_given_last_time(ob.person_id, value_drug, ob.obs_datetime.to_date)

      amount_of_drug_brought_to_clinic[ob.person_id][ob.obs_datetime.to_date] << {
        :value_drug => value_drug, :pills_counted => ob.value_numeric, :order_id => ob.order_id,
        :concept_id => ob.concept_id, :obs_datetime => ob.obs_datetime,
        :dose => nil, :pills_given_last_time => amount_dispensed, :duration_gone => days_gone,
        :adherence => nil
      }
      puts "Observations ..................................... #{(i+1)} of #{observations.count}"
    end

   (amount_of_drug_brought_to_clinic || {}).each do |person_id, obs_date|
     (obs_date || {}).each do |date, data|
       curr_weight_then = get_curr_weight_then(person_id, date)
       (data || []).each do |d|
         d[:dose] = get_dose(curr_weight_then, d[:value_drug]) 
         d[:adherence] = cal_adherence_rate(d[:dose], d[:pills_given_last_time], d[:duration_gone], d[:pills_counted])
       end
     end
   end
  
  
    delete_all
  
   (amount_of_drug_brought_to_clinic || {}).each do |person_id, obs_date|
     (obs_date || {}).each do |date, data|
       (data || []).each do |d|
         next if d[:adherence].blank?
         e = Encounter.find(:first, :conditions =>["(encounter_datetime BETWEEN  ? AND ?) 
          AND encounter_type = ? AND encounter.patient_id = ?", date.to_date.strftime('%Y-%m-%d 00:00:00'), 
          date.to_date.strftime('%Y-%m-%d 23:59:59'), ART_ADHERENCE_ENC.id, person_id])

         e = Encounter.create(:patient_id => person_id, :encounter_datetime => date, :encounter_type => ART_ADHERENCE_ENC.id) if e.blank? 

         Observation.create(:concept_id => Drug_order_adherence.concept_id, :person_id => person_id, 
          :value_drug => d[:value_drug], :value_numeric => d[:adherence], :obs_datetime => d[:obs_datetime], 
          :encounter_id => e.encounter_id, :order_id => d[:order_id]) 
         puts "................................... Patient:#{person_id}, date:#{date}, adherence:#{d[:adherence]}%"
       end
     end
   end

    end_time = Time.now()
    puts "Time duration: #{start_time.strftime('%A, %d %b %Y  %H:%M:%S')}  => #{end_time.strftime('%A, %d %b %Y  %H:%M:%S')}"
  end

  def cal_adherence_rate(dose, pills_given_last_time, duration_gone, amount_remaining)
    return nil if dose.blank? || pills_given_last_time.blank? || duration_gone.blank? || amount_remaining.blank?

    expected_amount_remaining = (pills_given_last_time - (duration_gone * dose))
    adherence = (100*(pills_given_last_time - amount_remaining) / (pills_given_last_time - expected_amount_remaining)).round
    return adherence if adherence >= 0
    return 0 if adherence < 0
  end

  def get_dose(weight, drug_inventory_id)
    dose = MohRegimenIngredient.find(:first,:joins => "INNER JOIN moh_regimen_doses d ON d.dose_id = moh_regimen_ingredient.dose_id",
      :conditions =>["? >= min_weight and ? <= max_weight AND drug_inventory_id = ?",
      weight, weight, drug_inventory_id],:select => "d.*")
    
   return nil if dose.blank?
   return (dose.am.to_i + dose.pm.to_i)  
  end

  def get_curr_weight_then(person_id, session_date)
    obs = Patient.find(person_id).person.observations.before((session_date + 1.days).to_date).question("WEIGHT (KG)").all
    return obs.first.answer_string.to_f rescue 0
  end

  def pills_given_last_time(person_id, value_drug, obs_date)
    amount_dispensed_last_visit_date = Observation.find(:all,:conditions =>["concept_id = ?
      AND obs_datetime < ? AND value_drug = ? AND person_id = ?", Amount_dispensed.concept_id, 
      obs_date.strftime('%Y-%m-%d 00:00:00'), value_drug, person_id], 
      :select => "MAX(obs_datetime) ob_date").first.ob_date.to_date rescue nil

    return nil if amount_dispensed_last_visit_date.blank? rescue nil

    amount_dispensed = Observation.find(:first,:conditions =>["concept_id = ?
      AND (obs_datetime BETWEEN ? AND ?) AND value_drug = ? AND person_id = ?", Amount_dispensed.concept_id, 
      amount_dispensed_last_visit_date.strftime('%Y-%m-%d 00:00:00'), 
      amount_dispensed_last_visit_date.strftime('%Y-%m-%d 23:59:59'),
      value_drug, person_id], :select => "value_numeric amount_dispensed").amount_dispensed.to_f rescue nil

    days_gone = ActiveRecord::Base.connection.select_value <<EOF
    SELECT  timestampdiff(day, date('#{amount_dispensed_last_visit_date}'), date('#{obs_date.to_date}')) AS days
EOF


    return [days_gone.to_i, amount_dispensed]
  end

  start


