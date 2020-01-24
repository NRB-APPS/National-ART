class DrugController < GenericDrugController
  def art_summary_dispensation
    drug_name = params[:drug_name] rescue ''
    dispensation_date = params[:date] rescue "2014-01-06".to_date
    connection = ActiveRecord::Base.connection

    drug_order = connection.select_one("SELECT * FROM order_type WHERE 
      name='Drug Order' LIMIT 1")
    drug_order_type_id = drug_order["order_type_id"]
    dispensing_encounter_type = connection.select_one("SELECT * FROM encounter_type WHERE
      name='DISPENSING' LIMIT 1")
    dispensing_encounter_type_id = dispensing_encounter_type["encounter_type_id"]
    treatment_encounter_type = connection.select_one("SELECT * FROM encounter_type WHERE
      name='TREATMENT' LIMIT 1")
    treatment_encounter_type_id = treatment_encounter_type["encounter_type_id"]
    amount_dispensed_concept = Concept.find_by_name('Amount dispensed').id

    dispensation_data = connection.select_all("SELECT SUM(obs.value_numeric) as Bottles, COUNT(e.patient_id) as total_patients, d.name as DrugName FROM encounter e INNER JOIN encounter_type et
        ON e.encounter_type = et.encounter_type_id INNER JOIN obs ON e.encounter_id=obs.encounter_id
        INNER JOIN orders o
        ON obs.order_id = o.order_id INNER JOIN drug_order do ON o.order_id = do.order_id
        INNER JOIN drug d ON do.drug_inventory_id = d.drug_id
        WHERE e.encounter_type = #{dispensing_encounter_type_id} AND
        o.order_type_id = #{drug_order_type_id} AND e.encounter_datetime >= \"#{dispensation_date} 00:00:00\"
        AND e.encounter_datetime <= \"#{dispensation_date} 23:59:59\"
        AND obs.concept_id = #{amount_dispensed_concept}
        AND e.voided=0 GROUP BY d.name")

=begin
    prescription_data = connection.select_all("SELECT SUM(do.quantity)/60 as Bottles, d.name as DrugName FROM encounter e INNER JOIN encounter_type et
        ON e.encounter_type = et.encounter_type_id INNER JOIN orders o
        ON e.encounter_id = o.encounter_id INNER JOIN drug_order do ON o.order_id = do.order_id
        INNER JOIN drug d ON do.drug_inventory_id = d.drug_id
        WHERE e.encounter_type = #{treatment_encounter_type_id} AND
        o.order_type_id = #{drug_order_type_id} AND e.encounter_datetime >= \"#{dispensation_date} 00:00:00\"
        AND e.encounter_datetime <= \"#{dispensation_date} 23:59:59\"
        AND e.voided=0 GROUP BY d.name ORDER BY e.encounter_datetime DESC LIMIT 100")
=end

    prescription_data = connection.select_all("SELECT (ABS(DATEDIFF(o.auto_expire_date, o.start_date)) * do.equivalent_daily_dose) as Bottles,
        d.name as DrugName, e.patient_id as patient_id FROM encounter e INNER JOIN encounter_type et
        ON e.encounter_type = et.encounter_type_id INNER JOIN orders o
        ON e.encounter_id = o.encounter_id INNER JOIN drug_order do ON o.order_id = do.order_id
        INNER JOIN drug d ON do.drug_inventory_id = d.drug_id
        WHERE e.encounter_type = #{treatment_encounter_type_id} AND
        o.order_type_id = #{drug_order_type_id} AND e.encounter_datetime >= \"#{dispensation_date} 00:00:00\"
        AND e.encounter_datetime <= \"#{dispensation_date} 23:59:59\"
        AND e.voided=0" )

    dispensations = {}
    dispensation_data.each do |data|
      drug_name = data["DrugName"]
      bottles = data["Bottles"]
      dispensations[drug_name] = {}
      dispensations[drug_name]["bottles"] = bottles
      dispensations[drug_name]["total_patients"] = data["total_patients"]
    end

    prescribed_drugs = {}
    prescription_data.each do |prescription|
      prescribed_drug = prescription["DrugName"]
      bottles = prescription["Bottles"].to_i
      patient_id = prescription["patient_id"]
      #prescribed_drugs[prescribed_drug] = 0 if prescribed_drugs[prescribed_drug].blank?
      #prescribed_drugs[prescribed_drug]+=bottles
      #******************************************
      prescribed_drugs[prescribed_drug] = {} if prescribed_drugs[prescribed_drug].blank?
      prescribed_drugs[prescribed_drug]["bottles"] = 0 if prescribed_drugs[prescribed_drug]["bottles"].blank?
      prescribed_drugs[prescribed_drug]["bottles"] += bottles
      prescribed_drugs[prescribed_drug]["patient_ids"] = [] if prescribed_drugs[prescribed_drug]["patient_ids"].blank?
      prescribed_drugs[prescribed_drug]["patient_ids"] << patient_id
      #******************************************

    end
    
    prescriptions = {}
    prescribed_drugs.each do |data|
      drug_name = data[0]
      bottles = data[1]["bottles"]
      patient_ids = data[1]["patient_ids"]
      prescriptions[drug_name] = {}
      prescriptions[drug_name]["bottles"] = bottles
      prescriptions[drug_name]["total_patients"] = patient_ids.count
    end
    stocks = {}

    arv_concepts = MedicationService.arv_drugs.map(&:concept_id)
    arv_drugs = Drug.find(:all, :conditions => ["concept_id IN (?)", arv_concepts])
    cotrim_drugs = ["Cotrimoxazole (480mg tablet)", "Cotrimoxazole (960mg)"]
    arv_drugs += Drug.find(:all, :conditions => ["name IN (?)", cotrim_drugs])
    end_date = params[:date]
    relocations = {}
    
    arv_drugs.each do |drug|
      
      p_start_date = Pharmacy.first_delivery_date(drug.drug_id)
      start_date = p_start_date.blank? ? 50.years.ago : p_start_date

      total_prescribed = Pharmacy.total_drug_prescription(drug.drug_id, start_date, end_date)
      total_delivered = Pharmacy.total_delivered(drug.drug_id, start_date, end_date)
      total_dispensed = Pharmacy.dispensed_drugs_since(drug.drug_id, start_date, end_date)
      total_removed = Pharmacy.total_removed(drug.drug_id, start_date, end_date)
      clinic_verified = Pharmacy.verify_closing_stock_count(drug.drug_id,start_date,end_date, type="clinic", true)
      supervision_verified = Pharmacy.verify_closing_stock_count(drug.drug_id,start_date,end_date, type="supervision", true)
      drug_relocation = Pharmacy.relocated(drug.drug_id,start_date,end_date)
      new_deliveries =  Pharmacy.delivered(drug.drug_id,start_date,end_date)

      stocks[drug.name] = {}
      relocations[drug.name] = {}
      
      stocks[drug.name]["Total prescribed"] = total_prescribed
      stocks[drug.name]["Total delivered"] = total_delivered
      stocks[drug.name]["Total dispensed"] = total_dispensed
      stocks[drug.name]["Total removed"] = total_removed
      stocks[drug.name]["Clinic verification"] = clinic_verified
      stocks[drug.name]["Supervision verification"] = supervision_verified
      relocations[drug.name]["relocated"] = drug_relocation
      stocks[drug.name]["New delivery"] = new_deliveries

    end

    drug_summary = {}
    drug_summary["dispensations"] =  dispensations
    drug_summary["prescriptions"] = prescriptions
    drug_summary["stock_level"] = stocks
    drug_summary["relocations"] = relocations

    render :text => drug_summary.to_json and return    
  end

  def art_stock_info
    date = Date.today
    moh_products = DrugCms.find(:all)
    drug_order_type = OrderType.find_by_name('Drug Order') 
    dispensing_encounter_type = EncounterType.find_by_name("DISPENSING")
    treatment_encounter_type = EncounterType.find_by_name("TREATMENT")
    amount_dispensed_concept = Concept.find_by_name('Amount dispensed')
    location_name = Location.current_health_center.name rescue ''

    drug_summary = {}
    drug_summary["dispensations"] =  get_dispensations(date, dispensing_encounter_type, amount_dispensed_concept)
    drug_summary["prescriptions"] = get_prescriptions(date, treatment_encounter_type)
    drug_summary["stock_level"] = get_stock_level(date, moh_products)
    drug_summary["consumption_rate"] = get_drug_consumption_rate(moh_products)
    drug_summary["relocations"] = get_relocations(date, moh_products)
    drug_summary["receipts"] = get_receipts(date, moh_products)
    drug_summary["supervision_verification"] = get_supervision_verification(date, moh_products)
    drug_summary["clinic_verification"] = get_clinic_verification(date, moh_products)
    supervision_verification_in_details = get_supervision_verification_in_details(date, moh_products)
    unless supervision_verification_in_details.blank?
      drug_summary["supervision_verification_in_details"] = supervision_verification_in_details
    end
    site_code = PatientIdentifier.site_prefix
    data = {
      :site_code => site_code,
      :date => date,
      :dispensations => drug_summary["dispensations"],
      :prescriptions => drug_summary["prescriptions"],
      :stock_level => drug_summary["stock_level"],
      :consumption_rate => drug_summary["consumption_rate"],
      :relocations => drug_summary["relocations"],
      :receipts => drug_summary["receipts"],
      :supervision_verification => drug_summary["supervision_verification"],
      :supervision_verification_in_details => supervision_verification_in_details,
      :location => location_name
    }
    
    SendResultsToCouchdb.add_record(data) rescue ''
    #render :text => drug_summary.to_json and return we are no longer using this method for posting.
  end

  def new_drug_sets
    @sets = GeneralSet.all(:order => ["date_updated DESC"],
      :conditions => ["status = 'active'"]) +
      GeneralSet.all(:order => ["date_updated DESC"],
      :conditions => ["status = 'inactive'"])

    #raise @sets.to_yaml
    @set_name_ids_map = {}
    @set_desc_ids_map = {}
    @status = {}
    @drug_sets = {}
    @keys = []

    @sets.each{|set|

      @set_name_ids_map[set.set_id] = set.name
      @set_desc_ids_map[set.set_id] = set.description
      @status[set.set_id] = set.status
      @drug_sets[set.set_id] = set.drug_sets
      @keys << set.set_id
    }
  end

  def void_new_set
    if params[:drug_set_id]
      drug_set = DrugSet.find(params[:drug_set_id])
      drug_set.void
    end
  end

  def add_new_drug_set

    already_selected = DrugSet.find_all_by_set_id(params[:set_id]).collect{|d| d.drug_inventory_id} rescue []
    already_selected = [-1] if already_selected.blank?
    @drugs = [["", ""]] + Drug.all(:conditions => ["drug_id NOT IN (?)",
        already_selected]).collect{|drug| [drug.name, drug.id]}

    @frequencies = ["", "Once a day (OD)", "Twice a day (BD)", "Three a day (TDS)",
      "Four times a day (QID)", "Five times a day (5X/D)", "Six times a day (Q4HRS)",
      "In the morning (QAM)", "Once a day at noon (QNOON)", "In the evening (QPM)",
      "Once a day at night (QHS)", "Every other day (QOD)",
      "Once a week (QWK)", "Once a month", "Twice a month"]
  end

  def create_new_drug_set

    d = (session[:datetime].to_date rescue Date.today)
    t = Time.now
    session_date = DateTime.new(d.year, d.month, d.day, t.hour, t.min, t.sec)

    set_id = params[:set_id]

    if params[:name]

      set = GeneralSet.new(:name => params[:name],
        :description => params[:description],
        :status => "active",
        :date_created => session_date,
        :date_updated => session_date,
        :creator => params[:user_id]
      )
      set.save!
      set_id = set.set_id
    end

    drug_set = DrugSet.new(:drug_inventory_id => params[:drug].to_i,
      :set_id => set_id.to_i,
      :frequency => params[:frequency],
      :duration => params[:duration].to_i,
      :date_created => session_date,
      :date_updated => session_date,
      :creator => params[:user_id]
    )
    drug_set.save!
    GeneralSet.find(set_id).update_attributes(:date_updated => session_date)

    redirect_to "/drug/new_drug_sets/#{params[:user_id]}"
  end

  def deactivate_drug_set

    d = (session[:datetime].to_date rescue Date.today)
    t = Time.now
    session_date = DateTime.new(d.year, d.month, d.day, t.hour, t.min, t.sec)

    s = GeneralSet.find(params[:set_id])
    s.deactivate(session_date) if !s.blank?
  end

  def activate_drug_set

    d = (session[:datetime].to_date rescue Date.today)
    t = Time.now
    session_date = DateTime.new(d.year, d.month, d.day, t.hour, t.min, t.sec)

    s = GeneralSet.find(params[:set_id])
    s.activate(session_date) if !s.blank?
  end

  def block_drug_set

    d = (session[:datetime].to_date rescue Date.today)
    t = Time.now
    session_date = DateTime.new(d.year, d.month, d.day, t.hour, t.min, t.sec)

    s = GeneralSet.find(params[:set_id])
    s.block(session_date) if !s.blank?
    render :text => 'ok'.to_json
  end

  private

  def get_dispensations(date, encounter_type, concept)
    start_date = date.strftime('%Y-%m-%d 00:00:00')
    end_date = date.strftime('%Y-%m-%d 23:59:59')

    return ActiveRecord::Base.connection.select_all("SELECT count(e.patient_id) total_patients,
c.drug_inventory_id,sum(value_numeric) total FROM encounter e 
INNER JOIN obs ON obs.encounter_id = e.encounter_id
INNER JOIN drug_order d ON d.order_id = obs.order_id
INNER JOIN drug_cms c ON c.drug_inventory_id = obs.value_drug 
WHERE encounter_type = #{encounter_type.id} AND encounter_datetime 
BETWEEN '#{start_date}' AND '#{end_date}' AND e.voided = 0
AND obs.voided = 0 AND obs.concept_id = #{concept.id} 
GROUP BY value_drug;") 
    
  end

  def get_prescriptions(date, encounter_type)
    start_date = date.strftime('%Y-%m-%d 00:00:00')
    end_date = date.strftime('%Y-%m-%d 23:59:59')

    return ActiveRecord::Base.connection.select_all("SELECT count(e.patient_id) total_patients,do.drug_inventory_id,
SUM((ABS(DATEDIFF(o.auto_expire_date, o.start_date)) * do.equivalent_daily_dose)) as total
FROM encounter e INNER JOIN orders o
ON e.encounter_id = o.encounter_id 
INNER JOIN drug_order do ON o.order_id = do.order_id
INNER JOIN drug_cms d ON do.drug_inventory_id = d.drug_inventory_id
WHERE e.encounter_type = #{encounter_type.id}
AND e.encounter_datetime BETWEEN '#{start_date}'
AND '#{end_date}' AND e.voided = 0 GROUP BY do.drug_inventory_id")

  end

  def get_stock_level(date, drugs)
    stock_levels = {}
    (drugs || []).each do |drug|
      stock_levels[drug.drug_inventory_id] = Pharmacy.drug_stock_on(drug.drug_inventory_id, date)
    end
    
    return stock_levels
  end

  def get_drug_consumption_rate(drugs)
    consumption_rate = {}
    (drugs || []).each do |drug|
      consumption_rate[drug.drug_inventory_id] = Pharmacy.latest_drug_rate(drug.drug_inventory_id)
    end
    
    return consumption_rate
  end

  def get_relocations(date, drugs)
    drug_relocations = {}
    (drugs || []).each do |drug|
      drug_relocations[drug.drug_inventory_id] = Pharmacy.relocated(drug.drug_inventory_id, date, date)
    end
    
    return drug_relocations
  end

  def get_receipts(date, drugs)
    drug_receipts = {}
    (drugs || []).each do |drug|
      drug_receipts[drug.drug_inventory_id] = Pharmacy.receipts(drug.drug_inventory_id, date, date)
    end
    
    return drug_receipts
  end

  def get_supervision_verification(date, drugs)
    drug_supervision_verification = {}
    (drugs || []).each do |drug|
      drug_supervision_verification[drug.drug_inventory_id] = Pharmacy.verify_closing_stock_count(drug.drug_inventory_id,(date - 1.day ),date,"supervision", false)
    end

    return drug_supervision_verification
  end

  def get_clinic_verification(date, drugs)
    drug_clinic_verification = {}
    (drugs || []).each do |drug|
      drug_clinic_verification[drug.drug_inventory_id] = Pharmacy.verify_closing_stock_count(drug.drug_inventory_id,(date - 1.day),date, "clinic", false)
    end

    return drug_clinic_verification
  end

  def get_supervision_verification_in_details(date, drugs)
    drug_supervision_verification = {}
    (drugs || []).each do |drug|
      drug_supervision_verification[drug.drug_inventory_id] = Pharmacy.physical_verified_stock(drug.drug_inventory_id,date)
    end

    return drug_supervision_verification
  end

end
