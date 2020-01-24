class EncounterTypesController < GenericEncounterTypesController

  def index
    patient = Patient.find(params[:patient_id])
    role_privileges = RolePrivilege.find(:all,:conditions => ["role IN (?)", current_user_roles])
    privileges = role_privileges.each.map{ |role_privilege_pair| role_privilege_pair["privilege"].humanize }
 
    @encounter_privilege_map = CoreService.get_global_property_value("encounter_privilege_map").to_s rescue ''
    @encounter_privilege_map = @encounter_privilege_map.split(",")
    @encounter_privilege_hash = {}

    @encounter_privilege_map.each do |encounter_privilege|
      @encounter_privilege_hash[encounter_privilege.split(":").last.squish.humanize] = encounter_privilege.split(":").first.squish.humanize
    end

    roles_for_the_user = []

    privileges.each do |privilege|
      roles_for_the_user  << @encounter_privilege_hash[privilege] if !@encounter_privilege_hash[privilege].nil?
    end
    roles_for_the_user = roles_for_the_user.uniq

    # TODO add clever sorting
    @encounter_types = EncounterType.find(:all).map{|enc|enc.name.gsub(/.*\//,"").gsub(/\..*/,"").humanize}
    @available_encounter_types = Dir.glob(RAILS_ROOT+"/app/views/encounters/*.rhtml").map{|file|file.gsub(/.*\//,"").gsub(/\..*/,"").humanize}

    @available_encounter_types -= @available_encounter_types - @encounter_types

    @available_encounter_types = ((@available_encounter_types) - ((@available_encounter_types - roles_for_the_user) + (roles_for_the_user - @available_encounter_types)))
    if CoreService.get_global_property_value("activate.htn.enhancement").to_s == "true" && patient_present(Patient.find(params[:patient_id]), (session[:datetime].to_date rescue Date.today)) && htn_client?(Patient.find(params[:patient_id]))
      @available_encounter_types << "BP Management"
    end

    if (cervical_cancer_activated and (patient.person.gender.first.upcase == 'F'))
      @available_encounter_types << "Cervical cancer screening"
    end

    app_name = (what_app? rescue 'ART')
    if app_name == 'ART'
      @available_encounter_types.delete_if{|e|e.match(/TB|lab|Sputum|Update hiv status|referral/i)}
    end

    @available_encounter_types = @available_encounter_types.sort

  end

  def show
		if params["encounter_type"].downcase == "lab orders"

			redirect_to "/lims?id=#{params[:patient_id]}&location_id=#{session[:location_id]}&user_id=#{User.current.id rescue nil}" and return

		end

    patient = Patient.find(params[:patient_id])
    if CoreService.get_global_property_value("activate.htn.enhancement").to_s == "true"
      if params[:encounter_type].downcase == "vitals"
        session_date = session[:datetime].to_date rescue Date.today
        task = main_next_task(Location.current_location, patient, session_date)
        htn_workflow = check_htn_workflow(patient, task)
        redirect_to htn_workflow.url and return
      end
    end

    if params["encounter_type"].downcase == "bp management"
      redirect_to "/htn_encounter/bp_management?#{params.to_param}" and return
    else
      redirect_to "/encounters/new/#{params["encounter_type"].downcase.gsub(/ /,"_")}?#{params.to_param}" and return
    end

  end

end
