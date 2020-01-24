module MedicationService
  require 'csv'

	def self.arv(drug)
		arv_drugs.map(&:concept_id).include?(drug.concept_id) rescue false
	end

	def self.arv_drugs
		arv_concept       = ConceptName.find_by_name("ANTIRETROVIRAL DRUGS").concept_id
		arv_drug_concepts = ConceptSet.all(:conditions => ['concept_set = ?', arv_concept])
		arv_drug_concepts
	end

	def self.tb_medication(drug)
		tb_drugs.map(&:concept_id).include?(drug.concept_id)
	end

	def self.tb_drugs
		tb_medication_concept       = ConceptName.find_by_name("Tuberculosis treatment drugs").concept_id
		tb_medication_drug_concepts = ConceptSet.all(:conditions => ['concept_set = ?', tb_medication_concept])
		tb_medication_drug_concepts
	end
	
	def self.diabetes_medication(drug)
		diabetes_drugs.map(&:concept_id).include?(drug.concept_id)
	end	
	
	def self.diabetes_drugs
		diabetes_medication_concept       = ConceptName.find_by_name("DIABETES MEDICATION").concept_id
		diabetes_medication_drug_concepts = ConceptSet.all(:conditions => ['concept_set = ?', diabetes_medication_concept])
		diabetes_medication_drug_concepts
	end

  # Generate a given list of Regimen+s for the given +Patient+ <tt>weight</tt>
  # into select options. 
	def self.regimen_options(weight, program)
		regimens = Regimen.find(	:all,
      :order => 'regimen_index',
      :conditions => ['? >= min_weight AND ? < max_weight AND program_id = ?', weight, weight, program.program_id])

		options = regimens.map { |r|
			concept_name = (r.concept.concept_names.typed("SHORT").first ||	r.concept.concept_names.typed("FULLY_SPECIFIED").first).name
			if r.regimen_index.blank?
				["#{concept_name}", r.concept_id, r.regimen_index.to_i]
			else
				["#{r.regimen_index} - #{concept_name}", r.concept_id, r.regimen_index.to_i]
			end
		}.sort_by{| r | r[2]}.uniq

		return options
	end

  def self.all_regimen_options(program)
		regimens = Regimen.find(	:all,
      :order => 'regimen_index',
      :conditions => ['program_id = ?', program.program_id])

		options = regimens.map { |r|
			concept_name = (r.concept.concept_names.typed("SHORT").first ||	r.concept.concept_names.typed("FULLY_SPECIFIED").first).name
			if r.regimen_index.blank?
				["#{concept_name}", r.concept_id, r.regimen_index.to_i]
			else
				["#{r.regimen_index} - #{concept_name}", r.concept_id, r.regimen_index.to_i]
			end
		}.sort_by{| r | r[2]}.uniq

		return options
	end
	
  def self.current_orders(patient)
    encounter = current_treatment_encounter(patient)
    orders = encounter.orders.active
    orders
  end
  
  def self.current_treatment_encounter(patient)
    type = EncounterType.find_by_name("TREATMENT")
    encounter = patient.encounters.current.find_by_encounter_type(type.id)
    encounter ||= patient.encounters.create(:encounter_type => type.id)
  end

  def self.generic
    #tag_id = ConceptNameTag.find_by_tag("preferred_qech_aetc_opd").concept_name_tag_id
 
 		medication_tag = CoreService.get_global_property_value("application_generic_medication")
 			   
    all_drugs = Drug.all.collect {|drug|
      # [Concept.find(drug.concept_id).name.name, drug.concept_id] rescue nil

      [(drug.concept.fullname rescue drug.concept.shortname rescue ' '), drug.concept_id]
      #[ConceptName.find(:last, :conditions => ["concept_id = ? AND voided = 0 AND concept_name_id IN (?)", 
      #      drug.concept_id, ConceptNameTagMap.find(:all, :conditions => ["concept_name_tag_id = ?", tag_id]).collect{|c| 
      #        c.concept_name_id}]).name, drug.concept_id] rescue nil
    
    }.compact.uniq  rescue []
    
    if !medication_tag.blank?
    	application_drugs = concept_set(medication_tag)
    else
    	application_drugs = all_drugs
    end
    return_drugs = all_drugs - (all_drugs - application_drugs) 
  end

  def self.frequencies
    ConceptName.find_by_sql("SELECT name FROM concept_name WHERE concept_id IN \
                        (SELECT answer_concept FROM concept_answer c WHERE \
                        concept_id = (SELECT concept_id FROM concept_name \
                        WHERE name = 'DRUG FREQUENCY CODED')) AND concept_name_id \
                        IN (SELECT concept_name_id FROM concept_name_tag_map \
                        WHERE concept_name_tag_id = (SELECT concept_name_tag_id \
                        FROM concept_name_tag WHERE tag = 'preferred_dmht'))").collect {|freq|
      freq.name rescue nil
    }.compact rescue []
  end
  
	def self.fully_specified_frequencies
		concept_id = ConceptName.find_by_name('DRUG FREQUENCY CODED').concept_id
		set = ConceptSet.find_all_by_concept_set(concept_id, :order => 'sort_weight')
		frequencies = []
		options = set.each{ | item | 
			next if item.concept.blank?
			frequencies << [item.concept.shortname, item.concept.fullname + "(" + item.concept.shortname + ")"]
		}
		frequencies
	end
  
	def self.dosages(generic_drug_concept_id)    
		Drug.find(:all, :conditions => ["concept_id = ?", generic_drug_concept_id]).collect {|d|
			["#{d.name.upcase rescue ""}", "#{d.dose_strength.to_f rescue 1}", "#{d.units.upcase rescue ""}"]
		}.uniq.compact rescue []
	end
	
  def self.concept_set(concept_name)
    concept_id = ConceptName.find(:first, :conditions =>["name = ?", concept_name]).concept_id
    set = ConceptSet.find_all_by_concept_set(concept_id, :order => 'sort_weight')
    options = set.map{|item|next if item.concept.blank? ; [item.concept.fullname, item.concept.concept_id] }
    return options
  end

  def self.get_arv_regimen(patient_id, dispension_date)
    possible_combinations = {}
    csv_url =  RAILS_ROOT + "/doc/regimens_possible_combinations.csv"

    CSV.foreach("#{csv_url}") do |row|
      next if row[0].strip.match(/regimen/i)
      regimen = row[0].strip.upcase
      if possible_combinations[regimen].blank?
        possible_combinations[regimen] = []
      end
      possible_combinations[regimen] << row[1].strip
    end
   
    amount_dispensed_concept = ConceptName.find_by_name('Amount dispensed').concept
    dispensed_drugs = []
    dispensed_arvs_ids = Observation.find_by_sql("
      SELECT drug_inventory_id FROM obs
      INNER JOIN drug_order d ON d.order_id = obs.order_id
      AND obs.voided = 0 AND obs.concept_id = #{amount_dispensed_concept.id}
      WHERE obs.person_id = #{patient_id} AND obs.obs_datetime 
      BETWEEN '#{dispension_date.to_date.strftime('%Y-%m-%d 00:00:00')}' 
      AND '#{dispension_date.to_date.strftime('%Y-%m-%d 23:59:59')}' 
      AND d.drug_inventory_id IN(SELECT drug_id FROM arv_drug);")  
    
    return if dispensed_arvs_ids.blank?

    return self.regimen_interpreter(dispensed_arvs_ids.collect{|x| x.drug_inventory_id.to_i})
 
    dispensed_regimen = 'Unknown'
    dispensed_arvs_ids = dispensed_arvs_ids.map{|i|i.drug_inventory_id}.uniq

    (possible_combinations || {}).each do |regimen, drug_ids|
      (drug_ids).each do |ids|
        arv_ids = ids.split(';')
        if arv_ids.length == dispensed_arvs_ids.length
          if (arv_ids - dispensed_arvs_ids) == []
            dispensed_regimen = regimen
          end
        end
      end 
    end
    return dispensed_regimen
  end

  def self.latest_arv_dispensed_date(patient_id)
    amount_dispensed_concept = ConceptName.find_by_name('Amount dispensed').concept
    
    obs = Observation.find_by_sql("
      SELECT MAX(obs_datetime) obs_datetime FROM obs
      INNER JOIN drug_order d ON d.order_id = obs.order_id
      AND obs.voided = 0 AND obs.concept_id = #{amount_dispensed_concept.id}
      WHERE obs.person_id = #{patient_id} 
      AND d.drug_inventory_id IN(SELECT drug_id FROM arv_drug);")  
     
    return if obs.blank?
    return obs.first.obs_datetime
  end

  def self.moh_arv_regimen_options(current_weight)
    regimen_categories = {}
    #regimens = MohRegimen.find(:all, :joins => "INNER JOIN moh_regimen_lookup l 
    # ON l.regimen_id = moh_regimens.regimen_id", :select => "moh_regimens.*, l.*")

    regimen_ingrients = []
    ingrients = MohRegimenIngredient.all

    (ingrients || []).each do |r|
      if current_weight.to_f >= r.min_weight.to_f and current_weight.to_f <= r.max_weight.to_f
        regimen_ingrients << r.drug_inventory_id 
      end
    end

    moh_regimens = {}
    moh_regimen_lookup = MohRegimenLookup.find(:all, 
      :conditions => ["drug_inventory_id IN(?)", regimen_ingrients])

    (moh_regimen_lookup || []).each do |lookup|
      moh_regimens[lookup.regimen_name] = [] if moh_regimens[lookup.regimen_name].blank?
      moh_regimens[lookup.regimen_name] << lookup.drug_inventory_id
    end

    recommended_regimens = []

    (moh_regimens || {}).each do |regimen_name, drug_inventory_ids|
      regimen_index = regimen_name.to_i
      regimen_index_s = regimen_name.to_s

      num_of_drug_combination = MohRegimenLookup.find_by_regimen_name(regimen_name).num_of_drug_combination
      regimen_possible_drug_ids = MohRegimenLookup.find_by_sql("
        SELECT drug_inventory_id FROM moh_regimen_lookup 
        WHERE LEFT(regimen_name,#{regimen_index_s.length}) = #{regimen_index}").map(&:drug_inventory_id)
      found_in_combination = true

      valid_medication_ids = []
      (regimen_possible_drug_ids).each do |drug_id|
        medication = MohRegimenIngredient.find(:first, :conditions =>["drug_inventory_id = ? 
          AND #{current_weight.to_f} >= FORMAT(min_weight,2) 
          AND #{current_weight.to_f} <= FORMAT(max_weight,2)", drug_id])

        unless medication.blank?
          valid_medication_ids << drug_id
        end
      end  
       
      if (valid_medication_ids.count == num_of_drug_combination)
        recommended_regimens << "Regimen #{regimen_index} (#{self.get_regimen_formulation(regimen_index)})"
      end


    end

    
    return recommended_regimens.sort_by{|x| x.gsub('Regimen ','').to_i}.uniq
  end

  def self.get_regimen_formulation(index)
    regimen_formulations = {
      0 => "ABC / 3TC + NVP",
      2 => "AZT / 3TC / NVP",
      4 => "AZT / 3TC + EFV",
      5 => "TDF / 3TC / EFV",
      6 => "TDF / 3TC + NVP",
      7 => "TDF / 3TC + ATV/r",
      8 => "AZT / 3TC + ATV/r",
      9 => "ABC / 3TC + LPV/r",
      10 => "TDF / 3TC + LPV/r",
      11 => "AZT / 3TC + LPV/r",
      12 => "DRV + r + ETV + RAL"
    }
    return regimen_formulations[index]
  end

  def self.regimen_formulations
    regimen_formulations = {
      0 => "ABC/3TC + NVP",
      2 => "AZT/3TC/NVP",
      4 => "AZT/3TC + EFV",
      5 => "TDF/3TC/EFV",
      6 => "TDF/3TC + NVP",
      7 => "TDF/3TC + ATV/r",
      8 => "AZT/3TC + ATV/r",
      9 => "ABC/3TC + LPV/r",
      10 => "TDF/3TC + LPV/r",
      11 => "AZT/3TC + LPV/r",
      12 => "DRV + r + ETV + RAL"
    }
    
    return regimen_formulations
  end

  def self.regimen_medications(regimen_index, current_weight, patient_initiated = false, on_tb_treatment = false)
    regimen_index = regimen_index.to_s.gsub('Regimen ','').to_i 
    regimen_id = MohRegimen.find(:first, :conditions =>['regimen_index = ?', regimen_index]).regimen_id

    
    if patient_initiated == true and [0, 2, 6].include?(regimen_index.to_i)
      table_name = 'moh_regimen_ingredient_starter_packs'
    elsif on_tb_treatment == true and [7, 8].include?(regimen_index.to_i)
      table_name = 'moh_regimen_ingredient_tb_treatment'
    else
      table_name = 'moh_regimen_ingredient' 
    end

    regimen_medications = Drug.find(:all,:joins => "INNER JOIN #{table_name} i 
      ON i.drug_inventory_id = drug.drug_id AND i.regimen_id = #{regimen_id}
      INNER JOIN moh_regimen_doses d ON d.dose_id = i.dose_id",
      :conditions => "#{current_weight.to_f} >= FORMAT(min_weight,2) 
      AND #{current_weight.to_f} <= FORMAT(max_weight,2)", :select => "drug.*, i.*, d.*").map do |medication|
      {
        :drug_name => medication.name,
        :am => medication.am,
        :pm => medication.pm,
        :units => medication.units,
        :drug_id => medication.drug_id,
        :regimen_index => regimen_index,
        :category => MohRegimenLookup.find_by_drug_inventory_id(medication.drug_id).regimen_name.match(/A|P/i)[0]
      }
    end

    return regimen_medications    
  end

  def self.regimen_interpreter_old(medication_ids = [])
    return nil if medication_ids.blank?
    moh_regimen_ingredients = {}

    (MohRegimenLookup.all || []).each do |l|
      moh_regimen_ingredients[l.regimen_name] = [] if moh_regimen_ingredients[l.regimen_name].blank?
      moh_regimen_ingredients[l.regimen_name] << l.drug_inventory_id
    end

    regimen_name = 'Unknown'

    (moh_regimen_ingredients || {}).each do |regimen, drug_inventory_ids|
      if (drug_inventory_ids - medication_ids) == [] and (drug_inventory_ids.count == medication_ids.count)
        regimen_name = regimen
      end
    end

    return regimen_name
  end

  def self.regimen_interpreter(medication_ids = [])
    regimen_name = 'Unknown'
    regimen_codes = self.regimen_codes
    
    regimen_codes.each do |regimen_code, data|
      data.each do |row|
        drugs = [row].flatten
        drug_ids = Drug.find(:all, :conditions => ["drug_id IN (?)", drugs]).map(&:drug_id)
        if (drug_ids - medication_ids) == [] and (drug_ids.count == medication_ids.count)
          regimen_name = regimen_code
          break;
        end
      end
    end
    
    return regimen_name
  end

  def self.regimen_codes
    #ABC/3TC (Abacavir and Lamivudine 60/30mg tablet) = 733
    #NVP (Nevirapine 50 mg tablet) = 968
    #NVP (Nevirapine 200 mg tablet) = 22
    #ABC/3TC (Abacavir and Lamivudine 600/300mg tablet) = 969
    #AZT/3TC/NVP (60/30/50mg tablet) = 732
    #AZT/3TC/NVP (300/150/200mg tablet) = 731
    #AZT/3TC (Zidovudine and Lamivudine 60/30 tablet) = 736
    #EFV (Efavirenz 200mg tablet) = 30
    #EFV (Efavirenz 600mg tablet) = 11
    #AZT/3TC (Zidovudine and Lamivudine 300/150mg) = 39
    #TDF/3TC/EFV (300/300/600mg tablet) = 735
    #TDF/3TC (Tenofavir and Lamivudine 300/300mg tablet = 734
    #ATV/r (Atazanavir 300mg/Ritonavir 100mg) = 932
    #LPV/r (Lopinavir and Ritonavir 100/25mg tablet) = 74
    #LPV/r (Lopinavir and Ritonavir 200/50mg tablet) = 73
    #Darunavir 600mg = 976
    #Ritonavir 100mg = 977
    #Etravirine 100mg = 978
    #RAL (Raltegravir 400mg) = 954
    #NVP (Nevirapine 200 mg tablet) = 22
    #LPV/r pellets = 979

    regimens = {
      "0P" => [[733, 968], [733, 22]],
      
      "0A" =>[[969, 22],[969, 968]],
      
      "2P" => [[732],[732, 736], [732, 39]],
      
      "2A" => [[731],[731, 39], [731, 736]],
      
      "4P" => [[736, 30],[736, 11]],
      
      "4A" => [[39, 11],[39, 30]],
      
      "5A" => [[735]],
      
      "6A" => [[734, 22]],
      
      "7A" => [[734, 932]],

      "8A" => [[39, 932]],

      "9P" => [[733, 74],[733, 73],[733, 979]],

      "9A" => [[969, 73],[969, 74]],

      "10A" => [[734, 73]],

      "11P" => [[736, 74],[736, 73]],

      "11A" => [[39, 73],[39, 74]],

      "12A" => [[976, 977, 978, 954]]
      
    }

    return regimens
  end

  def self.other_medications(drug_name, current_weight)
    drug_ids = Drug.find(:all, :conditions =>['name LIKE ?', "%#{drug_name}%"]).map(&:drug_id)

    regimen_medications = (Drug.find(:all,:joins => "INNER JOIN moh_other_medications o 
      ON o.drug_inventory_id = drug.drug_id AND o.drug_inventory_id IN (#{drug_ids.join(',')})
      INNER JOIN moh_regimen_doses d ON d.dose_id = o.dose_id",
        :conditions => "#{current_weight.to_f} >= FORMAT(min_weight,2)
      AND #{current_weight.to_f} <= FORMAT(max_weight,2)",
        :select => "drug.*, o.*, d.*", :limit => 10, :order => "drug.name DESC") || []).map do |medication|
      {
        :drug_name => medication.name,
        :am => medication.am,
        :pm => medication.pm,
        :units => medication.units,
        :drug_id => medication.drug_id,
        :regimen_index => nil,
        :category => medication.category
      }
    end

    #Isoniazid section
    (regimen_medications || []).each do |medication|
      if medication[:drug_name].match(/Isoniazid/i) and medication[:drug_name].match(/300/i)
        return [medication]
      end
    end

    (regimen_medications || []).each do |medication|
      if medication[:drug_name].match(/Isoniazid/i) and medication[:drug_name].match(/100/i)
        return [medication]
      end
    end

    #Cotrimoxazole section
    if current_weight >= 25
      (regimen_medications || []).each do |medication|
        if medication[:drug_name].match(/Cotrimoxazole/i) and medication[:drug_name].match(/960/i)
          return [medication]
        end
      end
    end

    if current_weight >= 14
      (regimen_medications || []).each do |medication|
        if medication[:drug_name].match(/Cotrimoxazole/i) and medication[:drug_name].match(/480/i)
          return [medication]
        end
      end
    end

    (regimen_medications || []).each do |medication|
      if medication[:drug_name].match(/Cotrimoxazole/i) and medication[:drug_name].match(/120/i)
        return [medication]
      end
    end

    (regimen_medications || []).each do |medication|
      if medication[:drug_name].match(/Cotrimoxazole/i) and medication[:drug_name].match(/960/i)
        return [medication]
      end
    end

    (regimen_medications || []).each do |medication|
      if medication[:drug_name].match(/Cotrimoxazole/i) and medication[:drug_name].match(/480/i)
        return [medication]
      end
    end

    return regimen_medications
  end

  def self.calculate_days_base_on_pills(drug_id, current_weight, number_of_pills)
    doses = Drug.find(:all,:joins => "INNER JOIN moh_regimen_ingredient i 
      ON i.drug_inventory_id = drug.drug_id AND i.drug_inventory_id = #{drug_id}
      INNER JOIN moh_regimen_doses d ON d.dose_id = i.dose_id",
      :conditions => "#{current_weight.to_f} >= FORMAT(min_weight,2) 
      AND #{current_weight.to_f} <= FORMAT(max_weight,2)",
      :select => "drug.*, i.*, d.*").map do |medication|
      {
        :am => medication.am, :pm => medication.pm
      }
    end

    return 0 if doses.blank?
    total_pills_per_day = doses.first[:am].to_f + doses.first[:pm].to_f
    return ((number_of_pills)/total_pills_per_day).to_i
  end

  def self.get_medication_dose(order)
    instructions = order.instructions
    return 0 if instructions.blank?
    medication_name = order.drug_order.drug.name
    num_of_tabs = instructions.sub("#{medication_name}:-",'').gsub('tab(s)','').gsub('tabs','').\
      squish.gsub('Morning:','').sub('Evening:','').squish.split(',').collect {| n | n.to_f }

    dose = 0
    (num_of_tabs || []).each do |n|
      dose += 1 if n > 0
    end

    if dose == 0
      return 2 if instructions.match(/EVENING/i) and instructions.match(/MORNING/i)
      return 1 if instructions.match(/EVENING/i) and not instructions.match(/MORNING/i)
      return 1 if not instructions.match(/EVENING/i) and instructions.match(/MORNING/i)
      return 1 if not instructions.match(/ONCE/i) 
      return 2 if not instructions.match(/TWICE/i) 
    end

    return dose
  end

  def self.optimized_interval(order)
    start_date = order.start_date.to_date
    auto_expire_date = order.auto_expire_date.to_date
    discontinued_date = order.discontinued_date.to_date unless order.discontinued_date.blank?
    prescription_end = order.void_reason.to_date rescue nil

    if start_date == auto_expire_date and not prescription_end.blank?
      return (discontinued_date.to_date - start_date.to_date).to_i
    elsif not start_date < auto_expire_date
      return (auto_expire_date.to_date - start_date.to_date).to_i
    elsif not discontinued_date.blank?
      return (discontinued_date.to_date - start_date.to_date).to_i
    else
      return (auto_expire_date.to_date - start_date.to_date).to_i
    end
    
  end

  def self.prescription_interval(order)
    start_date = order.start_date.to_date
    end_date = order.auto_expire_date.to_date
    discontinued_date = order.discontinued_date.to_date unless order.discontinued_date.blank?
    prescription_end = order.void_reason.to_date rescue nil
    
    if start_date == end_date and not prescription_end.blank?
      end_date = prescription_end
    end

    return (end_date - start_date).to_i
  end

  def self.get_medication_pills_per_day(order)
    instructions = order.instructions
    return 0 if instructions.blank?
    medication_name = order.drug_order.drug.name
    num_of_tabs = instructions.sub("#{medication_name}:-",'').gsub('tab(s)','').gsub('tabs','').\
      squish.gsub('Morning:','').sub('Evening:','').squish.split(',').collect {| n | n.to_f }

    num_pills = 0
    (num_of_tabs || []).each do |n|
      num_pills += 1 if n > 0
    end

    return num_pills
  end

  def self.medication_category(medication_id)
    #ABC/3TC (Abacavir and Lamivudine 60/30mg tablet) = 733
    #NVP (Nevirapine 50 mg tablet) = 968
    #NVP (Nevirapine 200 mg tablet) = 22
    #ABC/3TC (Abacavir and Lamivudine 600/300mg tablet) = 969
    #AZT/3TC/NVP (60/30/50mg tablet) = 732
    #AZT/3TC/NVP (300/150/200mg tablet) = 731
    #AZT/3TC (Zidovudine and Lamivudine 60/30 tablet) = 736
    #EFV (Efavirenz 200mg tablet) = 30
    #EFV (Efavirenz 600mg tablet) = 11
    #AZT/3TC (Zidovudine and Lamivudine 300/150mg) = 39
    #TDF/3TC/EFV (300/300/600mg tablet) = 735
    #TDF/3TC (Tenofavir and Lamivudine 300/300mg tablet = 734
    #ATV/r (Atazanavir 300mg/Ritonavir 100mg) = 932
    #LPV/r (Lopinavir and Ritonavir 100/25mg tablet) = 74
    #LPV/r (Lopinavir and Ritonavir 200/50mg tablet) = 73
    #Darunavir 600mg = 976
    #Ritonavir 100mg = 977
    #Etravirine 100mg = 978
    #RAL (Raltegravir 400mg) = 954
    #NVP (Nevirapine 200 mg tablet) = 22
    #LPV/r pellets = 979

    #Non ARVs
    #Cotrimoxazole (960mg) = 576
    #Cotrimoxazole (480mg tablet) = 297
    #TMP/SMX (Cotrimoxazole 120mg tablet) = 963
    #INH or H (Isoniazid 300mg tablet) = 931
    #INH or H (Isoniazid 100mg tablet) = 24


    category = {} ; category['P'] = [733, 968, 732, 736, 30, 74, 979, 963, 24]
    category['A'] = [976, 977, 978, 954, 22,969, 731, 39, 11, 735, 734, 932, 73, 576, 297, 931]

    (category).each do |cat, medication_ids|
      return cat if medication_ids.include?(medication_id)
    end
  end

  def self.get_amounts_brought_if_transfer_in(person_id, drug_concept_id, date)
    amount = Observation.find(:first, :conditions =>["concept_id = ? AND (obs_datetime BETWEEN ? AND ?)
      AND person_id = ?", drug_concept_id , date.strftime('%Y-%m-%d 00:00:00'),
      date.strftime('%Y-%m-%d 23:59:59'), person_id])
    return 0 if amount.blank?
    return amount.value_numeric
  end

  def self.amounts_brought_to_clinic(patient, session_date)
     @amounts_brought_to_clinic = Hash.new(0)

    amounts_brought_to_clinic = ActiveRecord::Base.connection.select_all <<EOF
      SELECT obs.*, drug_order.* FROM obs INNER JOIN drug_order ON obs.order_id = drug_order.order_id
      INNER JOIN encounter e ON e.encounter_id = obs.encounter_id AND e.voided = 0
      AND e.encounter_type = #{EncounterType.find_by_name('ART ADHERENCE').id}
      WHERE obs.concept_id = #{ConceptName.find_by_name('AMOUNT OF DRUG BROUGHT TO CLINIC').concept_id}
      AND obs.obs_datetime >= '#{session_date.to_date.strftime('%Y-%m-%d 00:00:00')}'                         
      AND obs.obs_datetime <= '#{session_date.to_date.strftime('%Y-%m-%d 23:59:59')}'
      AND person_id = #{patient.id} AND obs.voided = 0 AND value_numeric IS NOT NULL;
EOF

    (amounts_brought_to_clinic || []).each do |amount|
      @amounts_brought_to_clinic[amount['drug_inventory_id'].to_i] += (amount['value_numeric'].to_f rescue 0)
    end

    amounts_brought_to_clinic = ActiveRecord::Base.connection.select_all <<EOF
      SELECT obs.*, d.* FROM obs INNER JOIN drug d ON d.concept_id = obs.concept_id AND obs.voided = 0
      WHERE obs.obs_datetime BETWEEN '#{session_date.to_date.strftime('%Y-%m-%d 00:00:00')}'                         
      AND '#{session_date.to_date.strftime('%Y-%m-%d 23:59:59')}' AND person_id = #{patient.id}
      AND value_numeric IS NOT NULL AND obs.voided = 0;
EOF

    (amounts_brought_to_clinic || []).each do |amount|
      @amounts_brought_to_clinic[amount['drug_id'].to_i] += (amount['value_numeric'].to_f rescue 0)
    end

    return @amounts_brought_to_clinic
  end  

  def self.recalculate_auto_expire_dates(orders)
    amounts_brought_to_clinic = self.amounts_brought_to_clinic(orders.first.patient, orders.first.encounter.encounter_datetime.to_date)
    return if amounts_brought_to_clinic.blank?
    
    reseted_auto_expire_date_order_ids = [] ; days_added = []
    
    (orders || []).each do |order|
      drug = order.drug_order.drug
      next unless MedicationService.arv(drug)
      pills_a_day = self.get_medication_pills_per_day(order)
      (amounts_brought_to_clinic || {}).each do |drug_id, amount|
        days = (amount / pills_a_day)
        if days > 0 and drug_id == drug.id
          next_auto_expire_date = (order.auto_expire_date.to_date + days.days).to_date
          if next_auto_expire_date >= order.auto_expire_date.to_date
            days_added << days
            reseted_auto_expire_date_order_ids << order.id

            ActiveRecord::Base.connection.execute <<EOF
          UPDATE orders SET discontinued_date = '#{next_auto_expire_date.to_date}'
          WHERE order_id = #{order.order_id};
EOF

          end
        end
      end
    end
    
   
    return if days_added.blank? or days_added.sort.first < 1 
    days_added = days_added.sort.first.to_i
     
    (orders || []).each do |order|
      drug = order.drug_order.drug
      next if MedicationService.arv(drug)
      if order.discontinued_date.blank?
        new_auto_expire_date = (order.auto_expire_date.to_date + days_added.day)
        discontinued_date = order.auto_expire_date
        ActiveRecord::Base.connection.execute <<EOF
        UPDATE orders SET discontinued_date = '#{new_auto_expire_date}'
        WHERE order_id = #{order.order_id};
EOF

      end
    end

  end

  def self.art_drug_given_before(patient, date = Date.today)
    clinic_encounters  =  ['DISPENSING']

    encounter_type_ids = EncounterType.find_all_by_name(clinic_encounters).collect{|e|e.id}

    latest_encounter_date = Encounter.find(:first,:conditions =>["patient_id=? AND encounter_datetime < ? AND
        encounter_type IN(?)",patient.id,date.strftime('%Y-%m-%d 00:00:00'),
        encounter_type_ids],:order =>"encounter_datetime DESC").encounter_datetime rescue nil

    return [] if latest_encounter_date.blank?

    start_date = latest_encounter_date.strftime('%Y-%m-%d 00:00:00')
    end_date = latest_encounter_date.strftime('%Y-%m-%d 23:59:59')

    concept_id = Concept.find_by_name('AMOUNT DISPENSED').id
    orders = Order.find(:all,:joins =>"INNER JOIN obs ON obs.order_id = orders.order_id",
        :conditions =>["obs.person_id = ? AND obs.concept_id = ?
        AND obs_datetime >=? AND obs_datetime <=?",
        patient.id,concept_id,start_date,end_date],
        :order =>"obs_datetime")

    (orders || []).reject do |order|
      drug = order.drug_order.drug
      !self.arv(drug)
    end
  end

  def self.drug_given_before(patient, date = Date.today)
    clinic_encounters = ['HIV CLINIC REGISTRATION','HIV STAGING','DISPENSING','TREATMENT',
                      'HIV CLINIC CONSULTATION','ART ADHERENCE','HIV RECEPTION','VITALS']

    encounter_type_ids = EncounterType.find_all_by_name(clinic_encounters).collect{|e|e.id}

    latest_encounter_date = Encounter.find(:first,:conditions =>["patient_id=? AND encounter_datetime < ? AND
        encounter_type IN(?)",patient.id,date.strftime('%Y-%m-%d 00:00:00'),
        encounter_type_ids],:order =>"encounter_datetime DESC").encounter_datetime rescue nil

    return [] if latest_encounter_date.blank?

    start_date = latest_encounter_date.strftime('%Y-%m-%d 00:00:00')
    end_date = latest_encounter_date.strftime('%Y-%m-%d 23:59:59')

    concept_id = Concept.find_by_name('AMOUNT DISPENSED').id
    Order.find(:all,:joins =>"INNER JOIN obs ON obs.order_id = orders.order_id",
        :conditions =>["obs.person_id = ? AND obs.concept_id = ?
        AND (obs_datetime BETWEEN ? AND ?)",
        patient.id,concept_id,start_date,end_date],
        :order =>"obs_datetime")
  end

  def self.drugs_given_on(patient, date = Date.today)
    clinic_encounters = ['HIV CLINIC REGISTRATION','HIV STAGING','DISPENSING','TREATMENT',
                      'HIV CLINIC CONSULTATION','ART ADHERENCE','HIV RECEPTION','VITALS']

    encounter_type_ids = EncounterType.find_all_by_name(clinic_encounters).collect{|e|e.id}
=begin
    latest_encounter_date = Encounter.find(:first,
        :conditions =>["patient_id = ? AND encounter_datetime >= ?
        AND encounter_datetime <=? AND encounter_type IN(?)",
        patient.id,date.strftime('%Y-%m-%d 00:00:00'),
        date.strftime('%Y-%m-%d 23:59:59'),encounter_type_ids],
        :order =>"encounter_datetime DESC").encounter_datetime rescue nil
=end
    latest_encounter_date = Encounter.find_by_sql("SELECT * FROM encounter
    WHERE patient_id = #{patient.id} AND encounter_datetime BETWEEN '#{date.strftime('%Y-%m-%d 00:00:00')}'
    AND '#{date.strftime('%Y-%m-%d 23:59:59')}' AND encounter_type IN(#{encounter_type_ids.join(',')}) 
    AND voided = 0 ORDER BY encounter_datetime DESC LIMIT 1").first.encounter_datetime rescue nil

    return [] if latest_encounter_date.blank?

    start_date = latest_encounter_date.strftime('%Y-%m-%d 00:00:00')
    end_date = latest_encounter_date.strftime('%Y-%m-%d 23:59:59')

    concept_id = Concept.find_by_name('AMOUNT DISPENSED').id
=begin
    Order.find(:all,:joins =>"INNER JOIN obs ON obs.order_id = orders.order_id",
        :conditions =>["obs.person_id = ? AND obs.concept_id = ?
        AND obs_datetime >=? AND obs_datetime <=?",
        patient.id,concept_id,start_date,end_date],
        :order =>"obs_datetime")
=end

    Order.find_by_sql("SELECT * FROM orders INNER JOIN obs ON obs.order_id = orders.order_id
      WHERE obs.person_id = #{patient.id} AND obs.concept_id = #{concept_id} AND obs.voided = 0
      AND obs_datetime BETWEEN '#{start_date}' AND '#{end_date}' ORDER BY obs_datetime")

  end

  def self.art_drug_prescribed_before(patient, date = Date.today)

    clinic_encounters  =  ['TREATMENT']

    encounter_type_ids = EncounterType.find_all_by_name(clinic_encounters).collect{|e|e.id}

    latest_encounter_date = Encounter.find(:first,:conditions =>["patient_id=? AND encounter_datetime < ? AND
        encounter_type IN(?)",patient.id,date.strftime('%Y-%m-%d 00:00:00'),
        encounter_type_ids],:order =>"encounter_datetime DESC").encounter_datetime rescue nil

    return [] if latest_encounter_date.blank?

    start_date = latest_encounter_date.strftime('%Y-%m-%d 00:00:00')
    end_date = latest_encounter_date.strftime('%Y-%m-%d 23:59:59')

    encounter_type = EncounterType.find_by_name('TREATMENT').id
    orders = Order.find(:all,:joins =>"INNER JOIN drug_order d ON d.order_id = orders.order_id
        INNER JOIN encounter e ON e.encounter_id = orders.encounter_id AND e.encounter_type = #{encounter_type}",
        :conditions =>["e.patient_id = ? AND (encounter_datetime BETWEEN ? AND ?)",
        patient.id, start_date, end_date], :order =>"encounter_datetime")

    (orders || []).reject do |order|
      drug = order.drug_order.drug
      !self.arv(drug)
    end

  end

  def self.adjust_order_end_dates(orders, optimized_hanging_pills)
    suggested_additional_dates = []
    start_date = orders.last.start_date.to_date
    auto_expire_date = orders.last.auto_expire_date.to_date

    (orders || []).each do |order|
      drug = order.drug_order.drug
      next unless self.arv(drug)
      next if optimized_hanging_pills[drug.id].blank?
      hanging_pills = optimized_hanging_pills[drug.id].to_f

      #additional_days = (hanging_pills / (order.drug_order.dose.to_f * order.drug_order.equivalent_daily_dose.to_f))
      additional_days = (hanging_pills / (order.drug_order.equivalent_daily_dose.to_f))
      additional_days = additional_days.to_i rescue 0
      next if additional_days < 1
      
      if ((start_date + additional_days.day).to_date >= auto_expire_date)
        ActiveRecord::Base.connection.execute <<EOF
          UPDATE orders SET auto_expire_date = '#{start_date.to_date}',
          void_reason = '#{auto_expire_date.to_date}'
          WHERE order_id = #{order.id};
EOF

        type = EncounterType.find_by_name("DISPENSING")
        obs_datetime = order.encounter.encounter_datetime.to_time.strftime('%Y-%m-%d %H:%M:%S')

        dispension_enc = order.patient.encounters.find(:first,
          :conditions =>["DATE(encounter_datetime) = ? AND encounter_type = ?",start_date.to_date,type.id])
        dispension_enc ||= order.patient.encounters.create(:encounter_type => type.id,
          :encounter_datetime => obs_datetime)
    
        obs = Observation.new()
        obs.concept_id = Concept.find_by_name("AMOUNT DISPENSED").concept_id
        obs.order_id = order.id
        obs.person_id = order.patient_id
        obs.encounter_id = dispension_enc.id
        obs.value_drug = drug.id
        obs.value_numeric = 0
        obs.value_text = "Pills remaining enough to last to next visit"
        obs.obs_datetime = obs_datetime
        obs.save

        ActiveRecord::Base.connection.execute <<EOF
          UPDATE drug_order SET quantity = #{hanging_pills.to_f} WHERE order_id = #{order.id};
EOF


        current_state = ActiveRecord::Base.connection.select_one <<EOF
          SELECT current_state_for_program(#{order.patient_id}, 1, '#{obs_datetime.to_date}') state;
EOF

        unless current_state['state'].to_i == 7
          patient = order.patient
          patient.patient_programs.find_last_by_program_id(Program.find_by_name("HIV PROGRAM")).transition(
             :state => "On antiretrovirals", :start_date => obs_datetime.to_time)
        end

      end

    end

    exact_discontinued_dates = []

    orders = Order.find(:all, :conditions => ["order_id IN(?)", orders.map(&:id)])

    (orders || []).each do |order|
      drug = order.drug_order.drug
      drug_order = order.drug_order
      next unless self.arv(drug)
      hanging_pills = optimized_hanging_pills[drug.id].to_f
      additional_days = (hanging_pills / (order.drug_order.equivalent_daily_dose.to_f))
      additional_days = additional_days.to_i rescue 0

      units = (drug_order.equivalent_daily_dose.to_f * (order.auto_expire_date.to_date - start_date.to_date).to_i)
      pack_size = DrugOrder.calculate_complete_pack(drug, units)       
      consumption_days = ((pack_size.to_f / drug_order.equivalent_daily_dose.to_f).to_i) - 1

      if additional_days > 1 and not (order.start_date.to_date == order.auto_expire_date.to_date)
        consumption_days += additional_days
      elsif additional_days > 1 and (order.start_date.to_date == order.auto_expire_date.to_date)
        #the assumption is;we subtruct 3 days from the additional_days because the patient is going
        #start taking the drugs on the visit day (1 day) plus the 2 day buffer 
        consumption_days = (additional_days - 3)     
      elsif additional_days < 1
        next
      end

      exact_discontinued_dates << (start_date + consumption_days.day).to_date
    end

    exact_discontinued_date = exact_discontinued_dates.sort.first unless exact_discontinued_dates.blank?

    unless exact_discontinued_date.blank?
      ActiveRecord::Base.connection.execute <<EOF
        UPDATE orders SET discontinued_date = '#{exact_discontinued_date.to_date}'
        WHERE order_id IN(#{orders.map(&:order_id).join(',')});
EOF

    end

    return nil 
  end

  def self.arv_earliest_auto_expire_medication(patient_id, date)
    encounter_type = EncounterType.find_by_name('TREATMENT').id
    start_date = date.strftime('%Y-%m-%d 00:00:00')
    end_date = date.strftime('%Y-%m-%d 23:59:59')
    concept_id = ConceptName.find_by_name('Amount dispensed').concept_id

    arv_drug_concepts = self.arv_drugs.map(&:concept_id)

    orders = Order.find(:all,:joins =>"INNER JOIN drug_order d ON d.order_id = orders.order_id
      INNER JOIN encounter e ON e.encounter_id = orders.encounter_id AND e.encounter_type = #{encounter_type}
      INNER JOIN drug ON drug.drug_id = d.drug_inventory_id",
      :conditions =>["e.patient_id = ? AND (encounter_datetime BETWEEN ? AND ?) AND drug.concept_id IN(?)",
      patient_id, start_date, end_date, arv_drug_concepts], :order =>"encounter_datetime")

    return [] if orders.blank?
    amount_dispensed = {}

    (orders || []).each do |order|
      auto_expire_date = order.discontinued_date.to_date rescue order.auto_expire_date.to_date
      original_auto_expire_date = order.void_reason.to_date rescue nil

      if order.start_date.to_date == order.auto_expire_date.to_date and not original_auto_expire_date.blank?
        auto_expire_date = original_auto_expire_date
      end
      amount_dispensed[order.drug_order.drug_inventory_id] = auto_expire_date 
    end

    return amount_dispensed.sort_by{|drug_id, auto_expire_date| auto_expire_date.to_date}.first
  end

  def self.earliest_auto_expire_medication(patient_id, date)
    encounter_type = EncounterType.find_by_name('TREATMENT').id
    start_date = date.strftime('%Y-%m-%d 00:00:00')
    end_date = date.strftime('%Y-%m-%d 23:59:59')
    concept_id = ConceptName.find_by_name('Amount dispensed').concept_id

    orders = Order.find(:all,:joins =>"INNER JOIN drug_order d ON d.order_id = orders.order_id
      INNER JOIN encounter e ON e.encounter_id = orders.encounter_id AND e.encounter_type = #{encounter_type}",
      :conditions =>["e.patient_id = ? AND (encounter_datetime BETWEEN ? AND ?)",
      patient_id, start_date, end_date], :order =>"encounter_datetime")

    return [] if orders.blank?
    amount_dispensed = {}

    (orders || []).each do |order|
      auto_expire_date = order.discontinued_date.to_date rescue order.auto_expire_date.to_date
      original_auto_expire_date = order.void_reason.to_date rescue nil

      if order.start_date.to_date == order.auto_expire_date.to_date and not original_auto_expire_date.blank?
        auto_expire_date = original_auto_expire_date
      end
      amount_dispensed[order.drug_order.drug_inventory_id] = auto_expire_date 
    end

    return amount_dispensed.sort_by{|drug_id, auto_expire_date| auto_expire_date.to_date}.first
  end

  def self.prescriped_earliest_auto_expire_medication(patient_id, date)
    encounter_type = EncounterType.find_by_name('TREATMENT').id
    start_date = date.strftime('%Y-%m-%d 00:00:00')
    end_date = date.strftime('%Y-%m-%d 23:59:59')
    patient = Patient.find(patient_id)

    orders = Order.find(:all,:joins =>"INNER JOIN encounter e ON e.encounter_id = orders.encounter_id 
        AND e.encounter_type = #{encounter_type}", :conditions =>["e.patient_id = ? 
        AND (encounter_datetime BETWEEN ? AND ?)", patient_id, start_date, end_date])

    amount_prescriped = {}
    return [] if orders.blank?

    (orders || []).each do |order|
      drug = order.drug_order.drug
      next unless self.arv(drug)  
      amount_prescriped[order.id] = order.auto_expire_date
      if not order.discontinued_date.blank? and (order.auto_expire_date.to_date == order.start_date.to_date)
        amount_prescriped[order.id] = order.discontinued_date
      end
    end

    return amount_prescriped.sort_by{|order_id, auto_expire_date| auto_expire_date.to_date}.first
  end

  def self.earliest_auto_expire_dispensed_medication(patient, session_date)
    encounter_type = EncounterType.find_by_name('TREATMENT').id
    start_date = session_date.strftime('%Y-%m-%d 00:00:00')
    end_date = session_date.strftime('%Y-%m-%d 23:59:59')
    drug_orders = {} ; auto_expire_dates = []
   
    orders = Order.find(:all, :joins =>"INNER JOIN encounter e ON e.encounter_id = orders.encounter_id", 
      :conditions =>["encounter_type = ? AND e.patient_id = ? AND encounter_datetime BETWEEN (?) AND (?)", 
      encounter_type, patient.patient_id, start_date, end_date])
    
    appointment_type = Observation.find(:first,:conditions =>["
      obs_datetime BETWEEN ? AND ? AND person_id = ?
      AND concept_id = ?", start_date, end_date, patient.id,
      ConceptName.find_by_name('Appointment type').concept_id]).value_text rescue ''

    if appointment_type == 'Optimize - including hanging pills'
     
      (orders || []).each do |order|
        drug_order = order.drug_order
        quantity = drug_order.quantity.to_f rescue 0.0
        next if quantity == 0.0

        equivalent_daily_dose = drug_order.equivalent_daily_dose.to_f
        begin
          auto_expire_dates << session_date.to_date + (((quantity / equivalent_daily_dose).day) - 1)
        rescue
          next
        end
      end 

    else

      ################################################## if not Optimize next appointment ###############
      amounts_brought = self.amounts_brought_to_clinic(patient, session_date)

      (orders || []).each do |order|
        drug_order = order.drug_order
        next unless self.arv(drug_order.drug)
        auto_expire_date = order.auto_expire_date.to_date
        auto_expire_date = order.discontinued_date.to_date unless order.discontinued_date.blank?
        auto_expire_dates << auto_expire_date
      end

      (orders || []).each do |order|
        drug_order = order.drug_order
        auto_expire_dates << order.auto_expire_date.to_date
      end if auto_expire_dates.blank?
      ########################################### end #############################################

    end

    return auto_expire_dates.sort[0] unless auto_expire_dates.blank?
    return session_date
  end

end
