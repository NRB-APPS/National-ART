class PrescriptionsController < GenericPrescriptionsController
  def new_prescription
    @partial_name = 'drug_set'
    @partial_name = params[:screen] unless params[:screen].blank?
    @drugs = Drug.find(:all,:limit => 100)
    @drug_sets = {}
    drug_names = ['Quinine (600mg)','Azithromycin (250mg tablet)','Albendazole (400mg tablet)','Fefol (450 mg)','Doxycycline (200mg tablet)']
    drug_set_attr = [
      ['OD', 1, 7],
      ['OD', 1, 7],
      ['BD', 2, 2],
      ['OD', 1, 30],
      ['OD', 1, 7]
    ]

    Drug.find(:all,:limit => 5,:order => "name DESC",
      :conditions =>["name IN(?)",drug_names]).each_with_index do |d , i|
      @drug_sets[d.name] = { :duration => drug_set_attr[i][2],
        :frequency => drug_set_attr[i][0],:dose => drug_set_attr[i][1], :unit => 2,
        :display_name => "#{drug_names[i]} (#{drug_set_attr[i][0]}) #{drug_set_attr[i][2]} day(s)" }
    end
    render :layout => false
  end

  def search_for_drugs
    drugs = {}
    Drug.find(:all, :conditions => ["name LIKE (?)",
        "#{params[:search_str]}%"], :order => 'name', :limit => 20).map do |drug|
      drugs[drug.id] = {:name => drug.name, :dose_strength => drug.dose_strength || 1, :unit => drug.units}
    end
    render :text => drugs.to_json
  end

  def drug_set_prescription
    
    @patient = Patient.find(params[:patient_id])
    @partial_name = 'drug_set'
    @partial_name = params[:screen] unless params[:screen].blank?
    @drugs = Drug.find(:all, :limit => 20)
    @drug_sets = {}
    @set_names = {}
    @set_descriptions = {}

    GeneralSet.find_all_by_status("active").each do |set|

      @drug_sets[set.set_id] = {}
      @set_names[set.set_id] = set.name
      @set_descriptions[set.set_id] = set.description

      dsets = DrugSet.find_all_by_set_id_and_voided(set.set_id, 0)
      dsets.each do |d_set|

        @drug_sets[set.set_id][d_set.drug_inventory_id] = {}
        drug = Drug.find(d_set.drug_inventory_id)
        @drug_sets[set.set_id][d_set.drug_inventory_id]["drug_name"] = drug.name
        @drug_sets[set.set_id][d_set.drug_inventory_id]["units"] = drug.units
        @drug_sets[set.set_id][d_set.drug_inventory_id]["duration"] = d_set.duration
        @drug_sets[set.set_id][d_set.drug_inventory_id]["frequency"] = d_set.frequency
      end
    end

    render :layout => false
  end

  def prescribe
    @patient = Patient.find(params["patient_id"]) rescue nil

    session_date = (session[:datetime].to_date rescue Date.today)

    encounter = MedicationService.current_treatment_encounter(@patient, session_date)
    encounter.encounter_datetime = session_date
    encounter.save

    params[:drug_formulations] = (params[:drug_formulations] || []).collect { |df| eval(df) } || {}

    params[:drug_formulations].each do |prescription|

      prescription[:prn] = 0 if prescription[:prn].blank?
      auto_expire_date = session_date.to_date + (prescription[:duration].sub(/days/i, "").strip).to_i.days
      drug = Drug.find(prescription[:drug_id])

      DrugOrder.write_order(encounter, @patient, nil, drug, session_date, auto_expire_date, drug.dose_strength,
        prescription[:frequency], prescription[:prn].to_i)
    end

    if (@patient)
      print_and_redirect("/patients/print_visit_label/?patient_id=#{@patient.id}",
        next_task(@patient)) and return
    else
      redirect_to "/patients/treatment_dashboard/#{params[:patient_id]}" and return
    end
  end
  
end
