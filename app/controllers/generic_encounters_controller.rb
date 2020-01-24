class GenericEncountersController < ApplicationController
  def create(params=params, session=session)
    
    if params[:encounter]["encounter_type_name"].squish.upcase == "HIV RECEPTION"
      url = create_reception_encounter(params, session)
      redirect_to url and return
    end

    if params[:encounter]["encounter_type_name"].squish.upcase == 'HIV CLINIC REGISTRATION'
      url = create_hiv_registration_encounter(params, session)
      redirect_to url and return
    end

    if params[:encounter]["encounter_type_name"].squish.upcase == 'VITALS'
      url = create_vitals_encounter(params, session)
      redirect_to url and return
    end

    if params[:encounter]["encounter_type_name"].squish.upcase == 'HIV CLINIC CONSULTATION'
      url = create_hiv_clinic_consultation_encounter(params, session)
      redirect_to url and return
    end

    if params[:encounter]["encounter_type_name"].squish.upcase == 'APPOINTMENT'
      url = create_appointment_date_encounter(params, session)
      patient_id = params[:encounter]["patient_id"]
      print_and_redirect("/patients/dashboard_print_visit/#{patient_id}","/patients/show/#{patient_id}")
      #redirect_to url and return
      return
    end

    if params[:encounter]["encounter_type_name"].squish.upcase == 'HIV STAGING'
      url = create_hiv_staging_encounter(params, session)
      redirect_to url and return
    end

    if params[:encounter]["encounter_type_name"].squish.upcase == 'ART ADHERENCE'
      url = create_art_adherence_encounter(params, session)
      redirect_to url and return
    end

    if params[:encounter]["encounter_type_name"].squish.upcase == 'CERVICAL CANCER SCREENING'
      url = create_cervical_cancer_screening_encounter(params, session)
      redirect_to url and return
    end

    #TB encounters ................................................................

    if params[:encounter]["encounter_type_name"].squish.upcase == "TB RECEPTION"
      url = create_tb_reception_encounter(params, session)
      redirect_to url and return
    end

    if params['encounter']['encounter_type_name'] == 'TB_INITIAL'
      (params[:observations] || []).each do |observation|
        if observation['concept_name'].upcase == 'TRANSFER IN' and observation['value_coded_or_text'] == "YES"
          params[:observations] << {"concept_name" => "TB STATUS","value_coded_or_text" => "Confirmed TB on treatment"}
        end
      end
      create_tb_encounter(params, session)
    end


    if params['encounter']['encounter_type_name'].upcase == 'TB CLINIC VISIT'
      (params[:observations] || []).each do |observation|
        if observation['concept_name'].upcase == 'FURTHER EXAMINATION FOR TB REQUIRED' and observation['value_coded_or_text'] == "GeneXpert"
          xpertassay = true
        end
      end
      create_tb_encounter(params, session)
    end

    if params['encounter']['encounter_type_name'].upcase == 'REFER PATIENT OUT?'
      observations = []
      (params[:observations] || []).each do |observation|
        if observation['concept_name'].upcase == 'REFERRAL CLINIC IF REFERRED'
          observation['value_numeric'] = observation['value_coded_or_text'] rescue nil
          observation['value_text'] = Location.find(observation['value_coded_or_text']).name.to_s rescue ""
          observation['value_coded_or_text'] = ""
        end
        observations << observation
      end
      params[:observations] = observations unless observations.blank?
      create_tb_encounter(params, session)
    end

    if params['encounter']['encounter_type_name'] == 'SOURCE OF REFERRAL'
      create_tb_encounter(params, session)
    end

    if params['encounter']['encounter_type_name'] == 'UPDATE HIV STATUS'
      create_tb_encounter(params, session)
    end

    if params[:encounter]["encounter_type_name"].squish.upcase == "LAB ORDERS"
      create_tb_encounter(params, session)
    end

    if params[:encounter]["encounter_type_name"].squish.upcase == "TB REGISTRATION"
      create_tb_encounter(params, session)
    end

    if params[:encounter]["encounter_type_name"].squish.upcase == "TB VISIT"
      create_tb_encounter(params, session)
    end

    if params[:encounter]["encounter_type_name"].squish.upcase == "TB ADHERENCE"
      create_tb_encounter(params, session)
    end

    if params[:encounter]["encounter_type_name"].squish.upcase == "TB CLINIC VISIT"
      create_tb_encounter(params, session)
    end

    if params[:encounter]["encounter_type_name"].squish.upcase == "SPUTUM SUBMISSION"
      create_tb_encounter(params, session)
    end

    if params[:encounter]["encounter_type_name"].squish.upcase == "LAB RESULTS"
      create_tb_encounter(params, session)
    end

    if params[:encounter]["encounter_type_name"].squish.upcase == "GIVE LAB RESULTS"
      create_tb_encounter(params, session)
    end

    patient = Patient.find(params[:encounter]['patient_id'])
    url = next_task(patient) 

    if params['encounter']['encounter_type_name'].upcase == 'GIVE LAB RESULTS'
      if patient.person.observations.to_s.match(/results given to patient:  Yes/i)
        print_and_redirect("/encounters/lab_results_print/?id=#{patient.id}", next_task(patient))
        return
      else
        redirect_to url
        return
      end
    elsif params['encounter']['encounter_type_name'] == "LAB ORDERS"
      redirect_to "/patients/print_lab_orders/?patient_id=#{patient.id}"
      return
    elsif params['encounter']['encounter_type_name'].upcase == "TB suspect source of referral" && !params[:gender].empty? && !params[:family_name].empty? && !params[:given_name].empty?
      redirect_to "/encounters/new/tb_suspect_source_of_referral/?patient_id=#{patient.id}&gender=#{params[:gender]}&family_name=#{params[:family_name]}&given_name=#{params[:given_name]}" 
      return
    else
      redirect_to url
      return
    end


    #raise
  end
  ###################################################################################################

	def new	
		@patient = Patient.find(params[:patient_id] || session[:patient_id])
		@patient_bean = PatientService.get_patient(@patient.person)
		session_date = session[:datetime].to_date rescue Date.today

		if session[:datetime]
			@retrospective = true 
		else
			@retrospective = false
		end
		session[:patient] = @patient
		redirect_to "/" and return unless @patient

		redirect_to next_task(@patient) and return unless params[:encounter_type]

		redirect_to :action => :create, 'encounter[encounter_type_name]' => params[:encounter_type].upcase, 'encounter[patient_id]' => @patient.id and return if ['registration'].include?(params[:encounter_type])
		
		if (params[:encounter_type].upcase rescue '') == 'HIV_STAGING' and  (CoreService.get_global_property_value('use.extended.staging.questions').to_s == "true" rescue false)
      render :template => 'encounters/extended_hiv_staging'
		else
			render :action => params[:encounter_type] if params[:encounter_type]
		end
		
	end

	def current_user_role
		@role = current_user.user_roles.map{|r|r.role}
		return @role
	end


	def extract_regions
		
		ta = Region.all.collect { | element |
			[element.region_id.to_s  + ',' + element.name]
		}
		render :text => "'" + ta.join("' ; '") + "'"
	end

	def extract_districts
		
		ta = District.all.collect { | element |
			[element.district_id.to_s  + ',' + element.name + ',' + element.region_id.to_s + ',' + element.region.name]
		}
		render :text => "'" + ta.join("' ; '") + "'"
	end

	def extract_tas
		
		ta = TraditionalAuthority.all.collect { | element |
			[element.traditional_authority_id.to_s  + "," + element.name + "," + element.district_id.to_s + "," + element.district.name]
		}
		my_text = ta.join(" <br> ")
		render :text => my_text.to_s
	end

	def extract_villages
		
		ta = Village.all.collect { | element |
			[element.village_id.to_s  + ',' + element.name + ',' + element.traditional_authority_id.to_s + ',' + element.traditional_authority.name + ',' + element.traditional_authority.district_id.to_s + ',' + element.traditional_authority.district.name]
		}

		my_text = ta.join(" <br> ")
		render :text => my_text.to_s
	end

	def diagnoses
		search_string = (params[:search_string] || '').upcase
		filter_list = params[:filter_list].split(/, */) rescue []
		outpatient_diagnosis = ConceptName.find_by_name("DIAGNOSIS").concept
		#diagnosis_concepts = ConceptClass.find_by_name("Diagnosis", :include => {:concepts => :name}).concepts rescue []
		# TODO Need to check a global property for which concept set to limit things to

		#diagnosis_concept_set = ConceptName.find_by_name('MALAWI NATIONAL DIAGNOSIS').concept This should be used when the concept becames available
		diagnosis_set = CoreService.get_global_property_value("application_diagnosis_concept")
		diagnosis_set = "Qech outpatient diagnosis list" if diagnosis_set.blank?
		diagnosis_concept_set = ConceptName.find_by_name(diagnosis_set).concept
		diagnosis_concepts = Concept.find(:all, :joins => :concept_sets, :conditions => ['concept_set = ?', diagnosis_concept_set.id])

		valid_answers = diagnosis_concepts.map{|concept|
			name = concept.fullname rescue nil
			name.upcase.include?(search_string) ? name : nil rescue nil
		}.compact

		previous_answers = []
		# TODO Need to check global property to find out if we want previous answers or not (right now we)
		previous_answers = Observation.find_most_common(outpatient_diagnosis, search_string)
		@suggested_answers = (previous_answers + valid_answers.sort!).reject{ | answer | filter_list.include?(answer) }.uniq[0..10]
		@suggested_answers = @suggested_answers - params[:search_filter].split(',') rescue @suggested_answers
		render :text => "<li></li>" + "<li>" + @suggested_answers.join("</li><li>") + "</li>"
	end


	def treatment
		search_string = (params[:search_string] || '').upcase
		filter_list = params[:filter_list].split(/, */) rescue []
		valid_answers = []
		unless search_string.blank?
			drugs = Drug.find(:all, :conditions => ["name LIKE ?", '%' + search_string + '%'])
			valid_answers = drugs.map {|drug| drug.name.upcase }
		end
		treatment = ConceptName.find_by_name("TREATMENT").concept
		previous_answers = Observation.find_most_common(treatment, search_string)
		suggested_answers = (previous_answers + valid_answers).reject{|answer| filter_list.include?(answer) }.uniq[0..10] 
		render :text => "<li>" + suggested_answers.join("</li><li>") + "</li>"
	end

	def locations
		search_string = (params[:search_string] || 'neno').upcase
		filter_list = params[:filter_list].split(/, */) rescue []    
		locations =  Location.find(:all, :select =>'name', :conditions => ["name LIKE ?", '%' + search_string + '%'])
		render :text => "<li>" + locations.map{|location| location.name }.join("</li><li>") + "</li>"
	end

	def observations
		# We could eventually include more here, maybe using a scope with includes
		encounter = Encounter.find(params[:id], :include => [:observations]) rescue []

		@child_obs = {}
		@observations = []
		(encounter.observations || []).map do |obs|
			next if !obs.obs_group_id.blank?
      next if ConceptName.find_by_concept_id(obs.concept_id).name.match(/patient tracking state/i)
			if ConceptName.find_by_concept_id(obs.concept_id).name.match(/location/)
				obs.value_numeric = ""
				@observations << obs
			else
				@observations << obs
			end
			child_obs = Observation.find(:all, :conditions => ["obs_group_id = ?", obs.obs_id])
			if child_obs
				@child_obs[obs.obs_id] = child_obs
			end
		end unless encounter.blank?

		render :layout => false
	end

	def void
		@encounter = Encounter.find(params[:id])
    encounter = @encounter
    tb_reg = EncounterType.find_by_name("TB registration").id.to_i
    patient_identifier_type_id = PatientIdentifierType.find_by_name("District TB Number").patient_identifier_type_id
    tb_prog = Program.find_by_name("TB PROGRAM").id

    dispensing_enc_type =  EncounterType.find_by_name('DISPENSING').id
    patient_id = @encounter.patient_id
    current_day = session[:datetime].to_date rescue Date.today
    patient = encounter.patient
    
    if encounter.name == 'DISPENSING'
      if !(Patient.ever_had_dispensations(patient, current_day))
        hiv_program_id = Program.find_by_name("HIV Program").program_id
        patient_hiv_program = patient.patient_programs.find_last_by_program_id(hiv_program_id)
        current_state = patient_hiv_program.patient_states.current.last
        
        previous_state = patient_hiv_program.patient_states.find(:last,
          :conditions => ["patient_state_id < ?", current_state.patient_state_id])
        
        program_workflow_state = patient_hiv_program.patient_states.current.last.program_workflow_state

        if (program_workflow_state.concept.shortname.upcase == "ON ARVS")
          begin
            ActiveRecord::Base.transaction do
              current_state.void
              previous_state.end_date = nil
              previous_state.save
            end
          rescue
            nil
          end
        end
        
      end
    end

    if tb_reg == @encounter.encounter_type.to_i
      void_prog = PatientProgram.find(:last, :conditions => ['DATE(date_enrolled) = ? AND patient_id = ? AND program_id = ?',
          @encounter.encounter_datetime.to_date, @encounter.patient_id, tb_prog])
          
      if ! void_prog.blank?
        void_prog.void
      end
    
      current_identifier = PatientIdentifier.find(:first, :conditions => ['patient_id = ? AND identifier_type = ?',
          @encounter.patient_id, patient_identifier_type_id], :order => "date_created DESC")
      
      if ! current_identifier.blank?
        current_identifier.void
      end

    end
    
    state = Encounter.find_by_sql("
        SELECT * FROM obs WHERE concept_id = (SELECT concept_id FROM concept_name WHERE name = 'PATIENT TRACKING STATE')
        AND encounter_id = #{params[:id]}").first rescue []
    
    if not state.blank?
      voided_state  = PatientState.find_by_sql(
        "SELECT * FROM patient_state WHERE patient_state_id = #{state.value_numeric}").first
      voided_state.void
    end
    
    if @encounter.name.upcase == 'ART ADHERENCE'
      (@encounter.observations || []).each do |o|
        o.void('Voided from app')
      end
    end

    if (encounter.type.name.match(/TREATMENT/i))
      #We don't want to have a dispensation encounter without treatment encounter
      #Void dispensation encounter soon after voiding treatment
      (@encounter.orders || []).each do |o|
        o.void('Voided from app')
      end

      (@encounter.observations || []).each do |o|
        o.void('Voided from app')
      end
    end

		@encounter.void
		head :ok
	end

	# List ARV Regimens as options for a select HTML element
	# <tt>options</tt> is a hash which should have the following keys and values
	#
	# <tt>patient</tt>: a Patient whose regimens will be listed
	# <tt>use_short_names</tt>: true, false (whether to use concept short names or
	#  names)
	#
	def arv_regimen_answers(options = {})
		answer_array = Array.new
		regimen_types = ['FIRST LINE ANTIRETROVIRAL REGIMEN', 
			'ALTERNATIVE FIRST LINE ANTIRETROVIRAL REGIMEN',
			'SECOND LINE ANTIRETROVIRAL REGIMEN'
		]

		regimen_types.collect{|regimen_type|
			Concept.find_by_name(regimen_type).concept_members.flatten.collect{|member|
				next if member.concept.fullname.include?("Triomune Baby") and !PatientService.patient_is_child?(options[:patient])
				next if member.concept.fullname.include?("Triomune Junior") and !PatientService.patient_is_child?(options[:patient])
				if options[:use_short_names]
					include_fixed = member.concept.fullname.match("(fixed)")
					answer_array << [member.concept.shortname, member.concept_id] unless include_fixed
					answer_array << ["#{member.concept.shortname} (fixed)", member.concept_id] if include_fixed
					member.concept.shortname
				else
					answer_array << [member.concept.fullname.titleize, member.concept_id] unless member.concept.fullname.include?("+")
					answer_array << [member.concept.fullname, member.concept_id] if member.concept.fullname.include?("+")
				end
			}
		}

		if options[:show_other_regimen]
		  answer_array << "Other" if !answer_array.blank?
		end
		answer_array

		# raise answer_array.inspect
	end

	def lab
		@patient = Patient.find(params[:encounter][:patient_id])
		encounter_type = params[:observations][0][:value_coded_or_text] 
		redirect_to "/encounters/new/#{encounter_type}?patient_id=#{@patient.id}"
	end

	def lab_orders
		@lab_orders = select_options['lab_orders'][params['sample']].collect{|order| order}
		render :text => '<li></li><li>' + @lab_orders.join('</li><li>') + '</li>'
	end

	def give_drugs
		@patient = Patient.find(params[:patient_id] || session[:patient_id])
		#@prescriptions = @patient.orders.current.prescriptions.all
		type = EncounterType.find_by_name('TREATMENT')
		session_date = session[:datetime].to_date rescue Date.today
		@prescriptions = Order.find(:all,
			:joins => "INNER JOIN encounter e USING (encounter_id)",
			:conditions => ["encounter_type = ? AND e.patient_id = ? AND DATE(encounter_datetime) = ?",
				type.id,@patient.id,session_date])
		@historical = @patient.orders.historical.prescriptions.all
		@restricted = ProgramLocationRestriction.all(:conditions => {:location_id => Location.current_health_center.id })
		@restricted.each do |restriction|
			@prescriptions = restriction.filter_orders(@prescriptions)
			@historical = restriction.filter_orders(@historical)
		end
		#render :layout => "menu" 
		render :template => 'dashboards/treatment_dashboard', :layout => false
	end

	def is_first_hiv_clinic_consultation(patient_id)
		session_date = session[:datetime].to_date rescue Date.today
		art_encounter = Encounter.find(:first,:conditions =>["voided = 0 AND patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) < ?",
				patient_id, EncounterType.find_by_name('HIV CLINIC REGISTRATION').id, session_date ]) rescue nil
		return true if art_encounter.nil?
		return false
	end

	def is_first_tb_registration(patient_id)
		session_date = session[:datetime].to_date rescue Date.today
		tb_registration = Encounter.find(:first,
			:conditions =>["patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) < ?",
				patient_id,EncounterType.find_by_name('TB REGISTRATION').id, session_date]) rescue nil

		return true if tb_registration.nil?
		return false
	end

	def uncompleted_tb_programs_status(patient)

		tb_program_state = nil

		tb_programs = patient.patient_programs.not_completed.in_programs('MDR-TB program') 
		tb_programs = patient.patient_programs.not_completed.in_programs('XDR-TB program') if tb_programs.blank?
		tb_programs = patient.patient_programs.not_completed.in_programs('TB PROGRAM') if tb_programs.blank?

		unless tb_programs.blank?
			tb_programs.each{|program|
				tb_status_state = program.patient_states.last.program_workflow_state.concept.fullname
			}
		end

		return tb_program_state
	end

	def recent_lab_results(patient_id, session_date = Date.today)
		sputum_concept_names = ["AAFB(1st) results", "AAFB(2nd) results", "AAFB(3rd) results", "Culture(1st) Results", "Culture-2 Results"]
		sputum_concept_ids = ConceptName.find(:all, :conditions => ["name IN (?)", sputum_concept_names]).map(&:concept_id)

		lab_results = Encounter.find(:last,:conditions =>["encounter_type = ? AND patient_id = ? AND DATE(encounter_datetime) >= ?",
				EncounterType.find_by_name("LAB RESULTS").id, patient_id, (session_date.to_date - 3.month).strftime('%Y-%m-%d 00:00:00')])
				            
		positive_result = false                  

		results = lab_results.observations.map{|o| o if sputum_concept_ids.include?(o.concept_id)} rescue []

		results.each do |result|
			concept_name = Concept.find(result.value_coded).fullname.upcase rescue 'NEGATIVE'
			if not ((concept_name).include? 'NEGATIVE')
				positive_result = true
			end
		end

		return positive_result
	end

  def select_options
    select_options = {
			'reason_for_tb_clinic_visit' => [
        ['',''],
        ['Clinical review (Children, Smear-, HIV+)','CLINICAL REVIEW'],
        ['Smear Positive (HIV-)','SMEAR POSITIVE'],
        ['X-ray result interpretation','X-RAY RESULT INTERPRETATION']
      ],
			'tb_clinic_visit_type' => [
        ['',''],
        ['Lab analysis','Lab follow-up'],
        ['Follow-up','Follow-up'],
        ['Clinical review (Clinician visit)','Clinical review']
      ],
			'family_planning_methods' => [
				['',''],
				['Oral contraceptive pills', 'ORAL CONTRACEPTIVE PILLS'],
				['Depo-Provera', 'DEPO-PROVERA'],
				['IUD-Intrauterine device/loop', 'INTRAUTERINE CONTRACEPTION'],
				['Contraceptive implant', 'CONTRACEPTIVE IMPLANT'],
				['Male condoms', 'MALE CONDOMS'],
				['Female condoms', 'FEMALE CONDOMS'],
				['Rhythm method', 'RYTHM METHOD'],
				['Withdrawal method', 'WITHDRAWAL METHOD'],
				['Abstinence', 'ABSTINENCE'],
				['Tubal ligation', 'TUBAL LIGATION'],
				['Vasectomy', 'VASECTOMY']
      ],
			'male_family_planning_methods' => [
				['',''],
				['Male condoms', 'MALE CONDOMS'],
				['Withdrawal method', 'WITHDRAWAL METHOD'],
				['Rhythm method', 'RYTHM METHOD'],
				['Abstinence', 'ABSTINENCE'],
				['Vasectomy', 'VASECTOMY'],
				['Other','OTHER']
      ],
			'female_family_planning_methods' => [
				['',''],
				['Oral contraceptive pills', 'ORAL CONTRACEPTIVE PILLS'],
				['Depo-Provera', 'DEPO-PROVERA'],
				['IUD-Intrauterine device/loop', 'INTRAUTERINE CONTRACEPTION'],
				['Contraceptive implant', 'CONTRACEPTIVE IMPLANT'],
				['Female condoms', 'FEMALE CONDOMS'],
				['Withdrawal method', 'WITHDRAWAL METHOD'],
				['Rhythm method', 'RYTHM METHOD'],
				['Abstinence', 'ABSTINENCE'],
				['Tubal ligation', 'TUBAL LIGATION'],
				['Emergency contraception', 'EMERGENCY CONTRACEPTION'],
				['Other','OTHER']
      ],
			'drug_list' => [
				['',''],
				["Rifampicin Isoniazid Pyrazinamide and Ethambutol", "RHEZ (RIF, INH, Ethambutol and Pyrazinamide tab)"],
				["Rifampicin Isoniazid and Ethambutol", "RHE (Rifampicin Isoniazid and Ethambutol -1-1-mg t"],
				["Rifampicin and Isoniazid", "RH (Rifampin and Isoniazid tablet)"],
				["Stavudine Lamivudine and Nevirapine", "D4T+3TC+NVP"],
				["Stavudine Lamivudine + Stavudine Lamivudine and Nevirapine", "D4T+3TC/D4T+3TC+NVP"],
				["Zidovudine Lamivudine and Nevirapine", "AZT+3TC+NVP"]
      ],
			'presc_time_period' => [
				["",""],
				["1 month", "30"],
				["2 months", "60"],
				["3 months", "90"],
				["4 months", "120"],
				["5 months", "150"],
				["6 months", "180"],
				["7 months", "210"],
				["8 months", "240"]
      ],
			'continue_treatment' => [
				["",""],
				["Yes", "YES"],
				["DHO DOT site","DHO DOT SITE"],
				["Transfer Out", "TRANSFER OUT"]
      ],
			'hiv_status' => [
				['',''],
				['Negative','NEGATIVE'],
				['Positive','POSITIVE'],
				['Unknown','UNKNOWN']
      ],
      'who_stage1' => [
        ['',''],
        ['Asymptomatic','ASYMPTOMATIC'],
        ['Persistent generalised lymphadenopathy','PERSISTENT GENERALISED LYMPHADENOPATHY'],
        ['Unspecified stage 1 condition','UNSPECIFIED STAGE 1 CONDITION']
      ],
      'who_stage2' => [
        ['',''],
        ['Unspecified stage 2 condition','UNSPECIFIED STAGE 2 CONDITION'],
        ['Angular cheilitis','ANGULAR CHEILITIS'],
        ['Popular pruritic eruptions / Fungal nail infections','POPULAR PRURITIC ERUPTIONS / FUNGAL NAIL INFECTIONS']
      ],
      'who_stage3' => [
        ['',''],
        ['Oral candidiasis','ORAL CANDIDIASIS'],
        ['Oral hairly leukoplakia','ORAL HAIRLY LEUKOPLAKIA'],
        ['Pulmonary tuberculosis','PULMONARY TUBERCULOSIS'],
        ['Unspecified stage 3 condition','UNSPECIFIED STAGE 3 CONDITION']
      ],
      'who_stage4' => [
        ['',''],
        ['Toxaplasmosis of the brain','TOXAPLASMOSIS OF THE BRAIN'],
        ["Kaposi's Sarcoma","KAPOSI'S SARCOMA"],
        ['Unspecified stage 4 condition','UNSPECIFIED STAGE 4 CONDITION'],
        ['HIV encephalopathy','HIV ENCEPHALOPATHY']
      ],
      'tb_xray_interpretation' => [
        ['',''],
        ['Consistent of TB','Consistent of TB'],
        ['Not Consistent of TB','Not Consistent of TB']
      ],
      'lab_orders' =>{
        "Blood" => ["Full blood count", "Malaria parasite", "Group & cross match", "Urea & Electrolytes", "CD4 count", "Resistance",
					"Viral Load", "Cryptococcal Antigen", "Lactate", "Fasting blood sugar", "Random blood sugar", "Sugar profile",
					"Liver function test", "Hepatitis test", "Sickling test", "ESR", "Culture & sensitivity", "Widal test", "ELISA",
					"ASO titre", "Rheumatoid factor", "Cholesterol", "Triglycerides", "Calcium", "Creatinine", "VDRL", "Direct Coombs",
					"Indirect Coombs", "Blood Test NOS"],
        "CSF" => ["Full CSF analysis", "Indian ink", "Protein & sugar", "White cell count", "Culture & sensitivity"],
        "Urine" => ["Urine microscopy", "Urinanalysis", "Culture & sensitivity"],
        "Aspirate" => ["Full aspirate analysis"],
        "Stool" => ["Full stool analysis", "Culture & sensitivity"],
        "Sputum-AAFB" => ["AAFB(1st)", "AAFB(2nd)"],
        "Sputum-Culture" => ["Culture(1st)", "Culture(2nd)"],
        "Swab" => ["Microscopy", "Culture & sensitivity"]
      },
      'tb_symptoms_short' => [
        ['',''],
        ["Bloody cough", "Hemoptysis"],
        ["Chest pain", "Chest pain"],
        ["Cough", "Cough lasting more than three weeks"],
        ["Fatigue", "Fatigue"],
        ["Fever", "Relapsing fever"],
        ["Loss of appetite", "Loss of appetite"],
        ["Night sweats","Night sweats"],
        ["Shortness of breath", "Shortness of breath"],
        ["Weight loss", "Weight loss"],
        ["Other", "Other"]
      ],
      'tb_symptoms_all' => [
        ['',''],
        ["Bloody cough", "Hemoptysis"],
        ["Bronchial breathing", "Bronchial breathing"],
        ["Crackles", "Crackles"],
        ["Cough", "Cough lasting more than three weeks"],
        ["Failure to thrive", "Failure to thrive"],
        ["Fatigue", "Fatigue"],
        ["Fever", "Relapsing fever"],
        ["Loss of appetite", "Loss of appetite"],
        ["Meningitis", "Meningitis"],
        ["Night sweats","Night sweats"],
        ["Peripheral neuropathy", "Peripheral neuropathy"],
        ["Shortness of breath", "Shortness of breath"],
        ["Weight loss", "Weight loss"],
        ["Other", "Other"]
      ],
      'drug_related_side_effects' => [
        ['',''],
        ["Confusion", "Confusion"],
        ["Deafness", "Deafness"],
        ["Dizziness", "Dizziness"],
        ["Peripheral neuropathy","Peripheral neuropathy"],
        ["Skin itching/purpura", "Skin itching"],
        ["Visual impairment", "Visual impairment"],
        ["Vomiting", "Vomiting"],
        ["Yellow eyes", "Jaundice"],
        ["Other", "Other"]
      ],
      'tb_patient_categories' => [
        ['',''],
        ["New", "New patient"],
        ["Failure", "Failed - TB"],
        ["Relapse", "Relapse MDR-TB patient"],
        ["Treatment after default", "Treatment after default MDR-TB patient"],
        ["Other", "Other"]
      ],
      'duration_of_current_cough' => [
        ['',''],
        ["Less than 1 week", "Less than one week"],
        ["1 Week", "1 week"],
        ["2 Weeks", "2 weeks"],
        ["3 Weeks", "3 weeks"],
        ["4 Weeks", "4 weeks"],
        ["More than 4 Weeks", "More than 4 weeks"],
        ["Unknown", "Unknown"]
      ],
      'eptb_classification'=> [
        ['',''],
        ['Pulmonary effusion', 'Pulmonary effusion'],
        ['Lymphadenopathy', 'Lymphadenopathy'],
        ['Pericardial effusion', 'Pericardial effusion'],
        ['Ascites', 'Ascites'],
        ['Spinal disease', 'Spinal disease'],
        ['Meningitis','Meningitis'],
        ['Other', 'Other']
      ],
      'tb_types' => [
        ['',''],
        ['Susceptible', 'Susceptible to tuberculosis drug'],
        ['Multi-drug resistant (MDR)', 'Multi-drug resistant tuberculosis'],
        ['Extreme drug resistant (XDR)', 'Extreme drug resistant tuberculosis']
      ],
      'tb_classification' => [
        ['',''],
        ['Pulmonary tuberculosis (PTB)', 'Pulmonary tuberculosis'],
        ['Extrapulmonary tuberculosis (EPTB)', 'Extrapulmonary tuberculosis (EPTB)']
      ],
      'source_of_referral' => [
        ['',''],
        ['Walk in', 'Walk in'],
        ['Index Patient', 'Index Patient'],
        ['HTC', 'HTC clinic'],
        ['ART/PMTCT', 'ART Clinic/PMTCT'],
        ['OPD', 'OPD'],
        ['Private practitioner', 'Private practitioner'],
        ['Sputum collection point', 'Sputum collection point'],
        ['Other','Other']
      ]
    }
  end

  def ever_received_tb_treatment(patient_id)
		encounters = Encounter.find(:all,:conditions =>["patient_id = ? AND encounter_type = ?",
				patient_id, EncounterType.find_by_name('TB_INITIAL').id],
			:include => [:observations],:order =>'encounter_datetime ASC') rescue nil

    tb_treatment_value = ''
    unless encounters.nil?
      encounters.each { |encounter|
        encounter.observations.each { |observation|
					if observation.concept_id == ConceptName.find_by_name("Ever received TB treatment").concept_id
						tb_treatment_value = ConceptName.find_by_concept_id(observation.value_coded).name
					end
        }
      }
    end
		return true if tb_treatment_value == "Yes"
		return false
	end

	def any_previous_tb_programs(patient_id)
		@tb_programs = ''
		patient_programs = PatientProgram.find_all_by_patient_id(patient_id)

		unless patient_programs.blank?
			patient_programs.each{ |patient_program|
				if patient_program.program_id == Program.find_by_name("MDR-TB program").program_id ||
						patient_program.program_id == Program.find_by_name("TB PROGRAM").program_id
					@tb_programs = true
					break
				end
			}
		end
	    
		return false if @tb_programs.blank?
		return true
	end
	
	def previous_tb_visit(patient_id)
		session_date = session[:datetime].to_date rescue Date.today
		encounter = Encounter.find(:all, :conditions=>["patient_id = ? \
                    AND encounter_type = ? AND DATE(encounter_datetime) < ? ", patient_id, \
					EncounterType.find_by_name("TB VISIT").id, session_date]).last rescue nil
		@date = encounter.encounter_datetime.to_date rescue nil
		previous_visit_obs = []

		if !encounter.nil?
			for obs in encounter.observations do
				previous_visit_obs << "#{(obs.to_s(["short", "order"])).gsub('hiv','HIV').gsub('Hiv','HIV')}".squish
			end
		end
		previous_visit_obs
	end
	
	def get_todays_observation_answer_for_encounter(patient_id, encountertype_name, observation_name)
		session_date = session[:datetime].to_date rescue Date.today
		encounter = Encounter.find(:all, :conditions=>["patient_id = ? \
                    AND encounter_type = ? AND DATE(encounter_datetime) = ? ", patient_id, \
					EncounterType.find_by_name("#{encountertype_name}").id, session_date]).last rescue nil
		@date = encounter.encounter_datetime.to_date rescue nil
		observation = nil
		if !encounter.nil?
			for obs in encounter.observations do
				if obs.concept_id == ConceptName.find_by_name("#{observation_name}").concept_id
					observation = "#{obs.to_s(["short", "order"]).to_s.split(":")[1]}".squish
				end
			end
		end
		observation
	end

  def lab_activities
    lab_activities = [
      ['Lab Orders', 'lab_orders'],
      ['Sputum Submission', 'sputum_submission'],
      ['Lab Results', 'lab_results'],
    ]
  end

  #originally recent_lab_results. Changed to portray the usage
  def patient_recent_lab_results(patient_id)
		Encounter.find(:last,:conditions =>["encounter_type = ? and patient_id = ?",
        EncounterType.find_by_name("LAB RESULTS").id,patient_id]).observations.map{|o| o } rescue nil
  end

  def sputum_submissons_with_no_results(patient_id)
    # sputum_concept_names = ["AAFB(1st)", "AAFB(2nd)", "AAFB(3rd)", "Culture(1st)", "Culture(2nd)"]
	  sputum_concept_names = ["AAFB(1st)", "AAFB(2nd)",  "Culture(1st)", "Culture(2nd)"]
    sputum_concept_ids = ConceptName.find(:all, :conditions => ["name IN (?)", sputum_concept_names]).map(&:concept_id)
    sputums_array = Observation.find(:all, :conditions => ["person_id = ? AND concept_id = ? AND (value_coded in (?) OR value_text in (?))", patient_id, ConceptName.find_by_name('Tests ordered').concept_id, sputum_concept_ids, sputum_concept_names], :order => "obs_datetime desc", :limit => 3)

    #results_concept_name = ["AAFB(1st) results", "AAFB(2nd) results", "AAFB(3rd) results", "Culture(1st) Results", "Culture-2 Results"]
		results_concept_name = ["AAFB(1st) results", "AAFB(2nd) results", "Culture(1st) Results", "Culture-2 Results"]
    sputum_results_id = ConceptName.find(:all, :conditions => ["name IN (?)", results_concept_name ]).map(&:concept_id)

    sputums_array = sputums_array.select { |order|
			accessor_history = Observation.find(:all, :conditions => ["person_id = ? AND accession_number  = (?) AND voided = 0 AND concept_id IN (?)",  patient_id, order.accession_number, sputum_results_id]);
			accessor_history.size == 0
		}
    sputums_array
  end

  def sputum_results_not_given(patient_id)
    PatientService.recent_sputum_results(patient_id).collect{|order| order unless Observation.find(:all, :conditions => ["person_id = ? AND concept_id = ?", patient_id, Concept.find_by_name("Lab test result").concept_id]).map{|o| o.accession_number}.include?(order.accession_number)}.compact
  end

  def is_tb_patient(patient)
		#raise "here"
    return given_tb_medication_before(patient)
  end

  def given_tb_medication_before(patient)
    patient.orders.each{|order|
      drug_order = order.drug_order
      drug_order_quantity = drug_order.quantity
      if drug_order_quantity == nil
        drug_order_quantity = 0
      end
      next if drug_order == nil
      next unless drug_order_quantity > 0
      return true if MedicationService.tb_medication(drug_order.drug)
    } rescue false
    false
  end

  def get_transfer_in_date(patient)
    patient_transfer_in = patient.person.observations.recent(1).question("HAS TRANSFER LETTER").all rescue nil
    return patient_transfer_in.each{|datetime| return datetime.obs_datetime  if datetime.obs_datetime}
  end

  def is_transfer_in(patient)
    patient_transfer_in = patient.person.observations.recent(1).question("HAS TRANSFER LETTER").all rescue nil
    return false if patient_transfer_in.blank?
    return true
  end

  def is_child_bearing_female(patient)
  	patient_bean = PatientService.get_patient(patient.person)
    (patient_bean.sex == 'Female' && patient_bean.age >= 9 && patient_bean.age <= 45) ? true : false
  end

  def given_arvs_before(patient)
    patient.orders.each{|order|
      drug_order = order.drug_order
      next if drug_order == nil
      next if drug_order.quantity == nil
      next unless drug_order.quantity > 0
      return true if MedicationService.arv(drug_order.drug) rescue false
    }
    false
  end

	def number_of_days_to_add_to_next_appointment_date(patient, date = Date.today)
    #because a dispension/pill count can have several drugs,we pick the drug with the lowest pill count
    #and we also make sure the drugs in the pill count/Adherence encounter are
    #the same as the one in Dispension encounter

    concept_id = ConceptName.find_by_name('AMOUNT OF DRUG BROUGHT TO CLINIC').concept_id
    encounter_type = EncounterType.find_by_name('ART ADHERENCE')
    adherence = Observation.find(:all,
      :joins => 'INNER JOIN encounter USING(encounter_id)',
      :conditions =>["encounter_type = ? AND patient_id = ? AND concept_id = ? AND DATE(encounter_datetime)=?",
        encounter_type.id,patient.id,concept_id,date.to_date],:order => 'encounter_datetime DESC')
    return 0 if adherence.blank?
    concept_id = ConceptName.find_by_name('AMOUNT DISPENSED').concept_id
    encounter_type = EncounterType.find_by_name('DISPENSING')
    drug_dispensed = Observation.find(:all,
      :joins => 'INNER JOIN encounter USING(encounter_id)',
      :conditions =>["encounter_type = ? AND patient_id = ? AND concept_id = ? AND DATE(encounter_datetime)=?",
        encounter_type.id,patient.id,concept_id,date.to_date],:order => 'encounter_datetime DESC')

    #check if what was dispensed is what was counted as remaing pills
    return 0 unless (drug_dispensed.map{| d | d.value_drug } - adherence.map{|a|a.order.drug_order.drug_inventory_id}) == []

    #the folliwing block of code picks the drug with the lowest pill count
    count_drug_count = []
    (adherence).each do | adh |
      unless count_drug_count.blank?
        if adh.value_numeric < count_drug_count[1]
          count_drug_count = [adh.order.drug_order.drug_inventory_id,adh.value_numeric]
        end
      end
      count_drug_count = [adh.order.drug_order.drug_inventory_id,adh.value_numeric] if count_drug_count.blank?
    end

    #from the drug dispensed on that day,we pick the drug "plus it's daily dose"
    #that match the drug with the lowest pill count
    equivalent_daily_dose = 1
    (drug_dispensed).each do | dispensed_drug |
      drug_order = dispensed_drug.order.drug_order
      if count_drug_count[0] == drug_order.drug_inventory_id
        equivalent_daily_dose = drug_order.equivalent_daily_dose
      end
    end
    (count_drug_count[1] / equivalent_daily_dose).to_i
  end

  def new_appointment                                                   
    #render :layout => "menu"                                                    
  end
  
	def update

		@encounter = Encounter.find(params[:encounter_id])
		ActiveRecord::Base.transaction do
			@encounter.void
		end

		encounter = Encounter.new(params[:encounter])
		encounter.encounter_datetime = session[:datetime] unless session[:datetime].blank? or encounter.name == 'DIABETES TEST'
		encounter.save

		# saving  of encounter states
		if(params[:complete])
			encounter_state = EncounterState.find(encounter.encounter_id) rescue nil

			if(encounter_state) # update an existing encounter_state
				state =  params[:complete] == "true"? 1 : 0
				EncounterState.update_attributes(:encounter_id => encounter.encounter_id, :state => state)
			else # a new encounter_state
				state =  params[:complete] == "true"? 1 : 0
				EncounterState.create(:encounter_id => encounter.encounter_id, :state => state)
			end
		end

		(params[:observations] || []).each{ | observation |
			# Check to see if any values are part of this observation
			# This keeps us from saving empty observations
			values = "coded_or_text group_id boolean coded drug datetime numeric modifier text".split(" ").map{ | value_name |
				observation["value_#{value_name}"] unless observation["value_#{value_name}"].blank? rescue nil
			}.compact

			next if values.length == 0
			observation.delete(:value_text) unless observation[:value_coded_or_text].blank?
			observation[:encounter_id] = encounter.id
			observation[:obs_datetime] = encounter.encounter_datetime ||= Time.now()
			observation[:person_id] ||= encounter.patient_id
			observation[:concept_name] ||= "OUTPATIENT DIAGNOSIS" if encounter.type.name == "OUTPATIENT DIAGNOSIS"

			# convert values from 'mmol/litre' to 'mg/declitre'
			if(observation[:measurement_unit])
				observation[:value_numeric] = observation[:value_numeric].to_f * 18 if ( observation[:measurement_unit] == "mmol/l")
				observation.delete(:measurement_unit)
			end

			if(observation[:parent_concept_name])
				concept_id = Concept.find_by_name(observation[:parent_concept_name]).id rescue nil
				observation[:obs_group_id] = Observation.find(:last, :conditions=> ['concept_id = ? AND encounter_id = ?', concept_id, encounter.id], :order => "obs_id ASC, date_created ASC").id rescue ""
				observation.delete(:parent_concept_name)
			end

			concept_id = Concept.find_by_name(observation[:concept_name]).id rescue nil
			obs_id = Observation.find(:first, :conditions=> ['concept_id = ? AND encounter_id = ?',concept_id, encounter.id]).id rescue nil

			extracted_value_numerics = observation[:value_numeric]
			if (extracted_value_numerics.class == Array)
				extracted_value_numerics.each do |	value_numeric |
					observation[:value_numeric] = value_numeric
					Observation.create(observation)
				end
			else
				Observation.create(observation)
			end
			  
		}

		@patient = Patient.find(params[:encounter][:patient_id])

		redirect_to "/patients/show/#{@patient.patient_id}" and return
	end

  private

	def create_obs(encounter , params)
		# Observation handling
		# raise params.to_yaml
		(params[:observations] || []).each do |observation|
			# Check to see if any values are part of this observation
			# This keeps us from saving empty observations
			values = ['coded_or_text', 'coded_or_text_multiple', 'group_id', 'boolean', 'coded', 'drug', 'datetime', 'numeric', 'modifier', 'text'].map { |value_name|
				observation["value_#{value_name}"] unless observation["value_#{value_name}"].blank? rescue nil
			}.compact
			
			next if values.length == 0

			observation[:value_text] = observation[:value_text].join(", ") if observation[:value_text].present? && observation[:value_text].is_a?(Array)
			observation.delete(:value_text) unless observation[:value_coded_or_text].blank?
			observation[:encounter_id] = encounter.id
			observation[:obs_datetime] = encounter.encounter_datetime || Time.now()
			observation[:person_id] ||= encounter.patient_id
			observation[:concept_name].upcase ||= "DIAGNOSIS" if encounter.type.name.upcase == "OUTPATIENT DIAGNOSIS"

			# Handle multiple select

			if observation[:value_coded_or_text_multiple] && observation[:value_coded_or_text_multiple].is_a?(String)
				observation[:value_coded_or_text_multiple] = observation[:value_coded_or_text_multiple].split(';')
			end
      
			if observation[:value_coded_or_text_multiple] && observation[:value_coded_or_text_multiple].is_a?(Array)
				observation[:value_coded_or_text_multiple].compact!
				observation[:value_coded_or_text_multiple].reject!{|value| value.blank?}
			end  
      
			# convert values from 'mmol/litre' to 'mg/declitre'
			if(observation[:measurement_unit])
				observation[:value_numeric] = observation[:value_numeric].to_f * 18 if ( observation[:measurement_unit] == "mmol/l")
				observation.delete(:measurement_unit)
			end

			if(!observation[:parent_concept_name].blank?)
				concept_id = Concept.find_by_name(observation[:parent_concept_name]).id rescue nil
				observation[:obs_group_id] = Observation.find(:last, :conditions=> ['concept_id = ? AND encounter_id = ?', concept_id, encounter.id], :order => "obs_id ASC, date_created ASC").id rescue ""
				observation.delete(:parent_concept_name)
			else
				observation.delete(:parent_concept_name)
				observation.delete(:obs_group_id)
			end

			extracted_value_numerics = observation[:value_numeric]
			extracted_value_coded_or_text = observation[:value_coded_or_text]
      
			#TODO : Added this block with Yam, but it needs some testing.
			if ! params[:location].blank?
				if encounter.encounter_type == EncounterType.find_by_name("ART ADHERENCE").id
					passed_concept_id = Concept.find_by_name(observation[:concept_name]).concept_id rescue -1
					obs_concept_id = Concept.find_by_name("AMOUNT OF DRUG BROUGHT TO CLINIC").concept_id rescue -1
					if observation[:order_id].blank? && passed_concept_id == obs_concept_id
						order_id = Order.find(:first,
							:select => "orders.order_id",
							:joins => "INNER JOIN drug_order USING (order_id)",
							:conditions => ["orders.patient_id = ? AND drug_order.drug_inventory_id = ? 
										  AND orders.start_date < ?", encounter.patient_id, 
								observation[:value_drug], encounter.encounter_datetime.to_date],
							:order => "orders.start_date DESC").order_id rescue nil
						if !order_id.blank?
							observation[:order_id] = order_id
						end
					end
				end
			end
      
			if observation[:value_coded_or_text_multiple] && observation[:value_coded_or_text_multiple].is_a?(Array) && !observation[:value_coded_or_text_multiple].blank?
				values = observation.delete(:value_coded_or_text_multiple)
				values.each do |value| 
					observation[:value_coded_or_text] = value
					if observation[:concept_name].humanize == "Tests ordered"
						observation[:accession_number] = Observation.new_accession_number 
					end

					observation = update_observation_value(observation)

					Observation.create(observation) 
				end
			elsif extracted_value_numerics.class == Array
				extracted_value_numerics.each do |value_numeric|
					observation[:value_numeric] = value_numeric
					
				  if !observation[:value_numeric].blank? && !(Float(observation[:value_numeric]) rescue false)
						observation[:value_text] = observation[:value_numeric]
						observation.delete(:value_numeric)
					end
									
					Observation.create(observation)
				end
			else      
				observation.delete(:value_coded_or_text_multiple)
				observation = update_observation_value(observation) if !observation[:value_coded_or_text].blank?
				
				if !observation[:value_numeric].blank? && !(Float(observation[:value_numeric]) rescue false)
					observation[:value_text] = observation[:value_numeric]
					observation.delete(:value_numeric)
				end
				
				Observation.create(observation)
			end
		end
	end

	def update_observation_value(observation)
		value = observation[:value_coded_or_text]
		value_coded_name = ConceptName.find_by_name(value)

		if value_coded_name.blank?
			observation[:value_text] = value
		else
			observation[:value_coded_name_id] = value_coded_name.concept_name_id
			observation[:value_coded] = value_coded_name.concept_id
		end
		observation.delete(:value_coded_or_text)
		return observation
	end

	#added this to ensure that we are able to get the detailed concept set
	def concept_options
		concept_name = params[:search_string]
		options = concept_set(concept_name).flatten.uniq

		render :text => "<li></li><li>" + options.join("</li><li>") + "</li>"
	end
	
	def create_tb_number(type_id, prefix)
		session_date = "#{prefix} #{Date.today.year.to_s}%"
		current_date = Date.today.to_s
		current_date = session[:datetime] if !session[:datetime].blank?
    session_date = "#{prefix} #{session[:datetime].to_date.year.to_s}%" if !session[:datetime].blank?
    patient_exists = PatientIdentifier.find(:all, :conditions => ['identifier_type = ? AND identifier like ? AND patient_id = ?', type_id, session_date, @patient.id]).first
    type = patient_exists
    state = ""
    @patient.patient_programs.each do |prog|
      state = prog.patient_states.last.to_s if prog.program.name.humanize == "Tb program"
    end
		if ! patient_exists.blank? and state.downcase.match(/treatment complete/i)
			patient_exists.voided = 1
			patient_exists.save
		end
		#if patient_exists.blank?
    type = PatientIdentifier.find_by_sql("SELECT * FROM patient_identifier
																						WHERE identifier_type = #{type_id} and identifier LIKE '%#{session_date}%'
																						AND voided = 0 ORDER BY patient_identifier_id DESC")
    #type = PatientIdentifier.find(:all, :conditions => ['identifier_type = ? AND identifier like ?', type_id, session_date],:order => 'patient_identifier_id DESC')
		#end
    type = type.first.identifier.split(" ") rescue ""
    if type.include?(current_date.to_date.year.to_s)
			return (type.last.to_i + 1) 
    else
			return 1
    end
	end


  ################################### create encounter/obs section ####################################

  def create_reception_encounter(params, session)
    encounter_type = EncounterType.find_by_name('HIV RECEPTION')
    patient_id = params[:encounter]["patient_id"].to_i
    begin
      encounter_datetime = session[:datetime].to_date.strftime('%Y-%m-%d 00:00:01') 
      params[:encounter]['encounter_datetime'] = encounter_datetime
    rescue
      encounter_datetime = params[:encounter]['encounter_datetime'].to_time.strftime('%Y-%m-%d %H:%M:%S') rescue nil
      if encounter_datetime.blank?
        encounter_datetime = Time.now().strftime('%Y-%m-%d %H:%M:%S')
        params[:encounter]['encounter_datetime'] = encounter_datetime
      end
    end

    encounter = Encounter.create(:patient_id => patient_id,
      :encounter_datetime => encounter_datetime, 
      :encounter_type => encounter_type.id)

    create_obs(encounter, params)

    #when the patient has been assigned ARV number
    unless params[:identifiers].blank?
      hcc_identifier_type = PatientIdentifierType.find_by_name('HCC Number')
      arv_identifier_type = PatientIdentifierType.find_by_name('ARV Number')

      (params[:identifiers] || []).each do |i|
        identifier_type = i["identifier_type"].to_i
        number = i["identifier"]
        if identifier_type == arv_identifier_type.id
          identifier = "#{PatientIdentifier.site_prefix}-ARV-#{number}"
        elsif identifier_type == hcc_identifier_type.id
          identifier = "#{PatientIdentifier.site_prefix}-HCC-#{number}"
        end

        PatientIdentifier.create(:patient_id => patient_id,
          :identifier_type => identifier_type, :identifier => identifier) 
      end
    end

    return next_task(encounter.patient)
  end

  def create_cervical_cancer_screening_encounter(params, session)
    encounter_type = EncounterType.find_by_name('CERVICAL CANCER SCREENING')
    patient_id = params[:encounter]["patient_id"].to_i
    begin
      encounter_datetime = session[:datetime].to_date.strftime('%Y-%m-%d 00:00:01')
      params[:encounter]['encounter_datetime'] = encounter_datetime
    rescue
      encounter_datetime = params[:encounter]['encounter_datetime'].to_time.strftime('%Y-%m-%d %H:%M:%S') rescue nil
      if encounter_datetime.blank?
        encounter_datetime = Time.now().strftime('%Y-%m-%d %H:%M:%S')
        params[:encounter]['encounter_datetime'] = encounter_datetime
      end
    end

    encounter = Encounter.create(:patient_id => patient_id,
      :encounter_datetime => encounter_datetime,
      :encounter_type => encounter_type.id)

    create_obs(encounter, params)

    return next_task(encounter.patient)
  end

  def create_hiv_registration_encounter(params, session)
    begin
      encounter_datetime = session[:datetime].to_date.strftime('%Y-%m-%d 00:00:01') 
      params[:encounter]['encounter_datetime'] = encounter_datetime
    rescue
      encounter_datetime = params[:encounter]['encounter_datetime'].to_time.strftime('%Y-%m-%d %H:%M:%S') rescue nil
      if encounter_datetime.blank?
        encounter_datetime = Time.now().strftime('%Y-%m-%d %H:%M:%S')
        params[:encounter]['encounter_datetime'] = encounter_datetime
      end
    end
    session_date = encounter_datetime.to_date

    has_tranfer_letter = false
    (params["observations"]).each do |ob|
      if ob["concept_name"] == "HAS TRANSFER LETTER" 
        has_tranfer_letter = (ob["value_coded_or_text"].upcase == "YES")
        break
      end
    end
        
    observations = []
    
    (params[:observations] || []).each do |obs|
      if obs['concept_name'].upcase == 'EVER RECEIVED ART' and obs['value_coded_or_text'].upcase == 'NO'
        (params[:observations] || []).each do |observation|
          next if observation['concept_name'].upcase == 'HAS TRANSFER LETTER'
          next if observation['concept_name'].upcase == 'HAS THE PATIENT TAKEN ART IN THE LAST TWO WEEKS'
          next if observation['concept_name'].upcase == 'HAS THE PATIENT TAKEN ART IN THE LAST TWO MONTHS'
          next if observation['concept_name'].upcase == 'ART NUMBER AT PREVIOUS LOCATION'
          next if observation['concept_name'].upcase == 'DATE ART LAST TAKEN'
          next if observation['concept_name'].upcase == 'LAST ART DRUGS TAKEN'
          next if observation['concept_name'].upcase == 'TRANSFER IN'
          next if observation['concept_name'].upcase == 'HAS THE PATIENT TAKEN ART IN THE LAST TWO WEEKS'
          next if observation['concept_name'].upcase == 'HAS THE PATIENT TAKEN ART IN THE LAST TWO MONTHS'
          observations << observation
        end
      elsif obs['concept_name'].upcase == 'Date antiretrovirals started'.upcase || obs['concept_name'].upcase == 'ART START DATE'
        date_art_started = obs['value_datetime'].to_date rescue nil
        art_start_date_estimation = params[:art_start_date_estimation]
        if date_art_started.blank? and not art_start_date_estimation.blank?
          case art_start_date_estimation
          when '6 months ago'
            obs[:value_datetime] = session_date - 6.months
            obs[:value_modifier] = '='
          when '12 months ago'
            obs[:value_datetime] = session_date - 12.months
            obs[:value_modifier] = '='
          when '18 months ago'
            obs[:value_datetime] = session_date - 18.months
            obs[:value_modifier] = '='
          when '24 months'
            obs[:value_datetime] = session_date - 24.months
            obs[:value_modifier] = '='
          when 'Over 2 years'
            obs[:value_datetime] = session_date - 24.months
            obs[:value_modifier] = '>'
          end
          obs[:value_text] = art_start_date_estimation
        end
      elsif obs['concept_name'].upcase == 'DATE ART LAST TAKEN' 
        new_patient = false
        (params[:observations] || []).each do |observation|
          if observation['concept_name'].upcase == 'EVER RECEIVED ART' && observation['value_coded_or_text'].upcase == 'NO'
            new_patient = true
            break
          end
        end
        next if new_patient == true

        date_art_last_taken = obs['value_datetime'].to_date rescue nil
        observations = []
        (params[:observations] || []).each do |observation|
          next if observation['concept_name'].upcase == 'HAS THE PATIENT TAKEN ART IN THE LAST TWO WEEKS'
          next if observation['concept_name'].upcase == 'HAS THE PATIENT TAKEN ART IN THE LAST TWO MONTHS'
          observations << observation
        end unless date_art_last_taken.blank?
        
        if date_art_last_taken.blank?
          last_month = false ; last_week = false
          (params[:observations] || []).each do |observation|
            if observation['concept_name'].upcase == 'HAS THE PATIENT TAKEN ART IN THE LAST TWO WEEKS' && observation['value_coded_or_text'].upcase == 'YES'
              last_week = true
            elsif observation['concept_name'].upcase == 'HAS THE PATIENT TAKEN ART IN THE LAST TWO MONTHS' && observation['value_coded_or_text'].upcase == 'YES'
              last_month = true
            end
          end 
         
          if last_week == true
            obs[:value_datetime] = (session_date - 2.weeks)
          elsif last_month == true
            obs[:value_datetime] = (session_date.to_date - 2.months)
          else
            year_art_last_taken = params['year_art_last_taken'].to_i
            month_art_last_taken = params['month_art_last_taken']
            day_art_last_taken = params['day_art_last_taken'].to_i
            if year_art_last_taken > 1 and month_art_last_taken == 'Unknown'
              obs[:value_datetime] = "#{year_art_last_taken}/July/01".to_date
            elsif year_art_last_taken > 1 and month_art_last_taken != 'Unknown' && day_art_last_taken < 1
              obs[:value_datetime] = "#{year_art_last_taken}/#{month_art_last_taken}/15".to_date
            elsif last_month == false and last_week == false
              obs[:value_datetime] = (session_date.to_date - 3.months)
            end
          end
          obs[:value_text] ='Estimated'
        end
      end
    end

    params[:observations] = observations unless observations.blank?

    observations = []
    (params[:observations] || []).each do |observation|
      if observation['concept_name'].upcase == 'LOCATION OF ART INITIATION' or observation['concept_name'].upcase == 'CONFIRMATORY HIV TEST LOCATION'
        observation['value_numeric'] = observation['value_coded_or_text'] rescue nil
        observation['value_text'] = Location.find(observation['value_coded_or_text']).name.to_s rescue ""
        observation['value_coded_or_text'] = ""
      end
      observations << observation
    end

    params[:observations] = observations unless observations.blank?

    observations = []
    vitals_observations = []
    initial_observations = []
    (params[:observations] || []).each do |observation|
      if observation['concept_name'].upcase == 'WHO STAGES CRITERIA PRESENT'
        observations << observation
      elsif observation['concept_name'].upcase == 'WHO STAGES CRITERIA PRESENT'
        observations << observation
      elsif observation['concept_name'].upcase == 'CD4 COUNT LOCATION'
        observations << observation
      elsif observation['concept_name'].upcase == 'CD4 COUNT DATETIME'
        observations << observation
      elsif observation['concept_name'].upcase == 'CD4 COUNT'
        observations << observation
      elsif observation['concept_name'].upcase == 'CD4 COUNT LESS THAN OR EQUAL TO 250'
        observations << observation
      elsif observation['concept_name'].upcase == 'CD4 COUNT LESS THAN OR EQUAL TO 350'
        observations << observation
      elsif observation['concept_name'].upcase == 'CD4 PERCENT'
        observations << observation
      elsif observation['concept_name'].upcase == 'CD4 PERCENT LESS THAN 25'
        observations << observation
      elsif observation['concept_name'].upcase == 'REASON FOR ART ELIGIBILITY'
        observations << observation
      elsif observation['concept_name'].upcase == 'WHO STAGE'
        observations << observation
      elsif observation['concept_name'].upcase == 'BODY MASS INDEX, MEASURED'
        bmi = nil
        (params["observations"]).each do |ob|
          if ob["concept_name"] == "BODY MASS INDEX, MEASURED" 
            bmi = ob["value_numeric"]
            break
          end
        end
        next if bmi.blank? 
        vitals_observations << observation
      elsif observation['concept_name'].upcase == 'WEIGHT (KG)'
        weight = 0
        (params["observations"]).each do |ob|
          if ob["concept_name"] == "WEIGHT (KG)" 
            weight = ob["value_numeric"].to_f rescue 0
            break
          end
        end
        next if weight.blank? or weight < 1
        vitals_observations << observation
      elsif observation['concept_name'].upcase == 'HEIGHT (CM)'
        height = 0
        (params["observations"]).each do |ob|
          if ob["concept_name"] == "HEIGHT (CM)" 
            height = ob["value_numeric"].to_i rescue 0
            break
          end
        end
        next if height.blank? or height < 1
        vitals_observations << observation
      else
        initial_observations << observation
      end
    end if has_tranfer_letter

    date_started_art = nil
    (initial_observations || []).each do |ob|
      if ob['concept_name'].upcase == 'DATE ANTIRETROVIRALS STARTED'
        date_started_art = ob["value_datetime"].to_date rescue nil
        if date_started_art.blank?
          date_started_art = ob["value_coded_or_text"].to_date rescue nil
          if date_started_art.blank?
            year_started_art = params[:year_started_art].to_i 
            month_started_art = params[:month_started_art]
            day_started_art = params[:day_started_art].to_i 
            if year_started_art > 1 and month_started_art == 'Unknown'
              ob[:value_datetime] = "#{year_started_art}/July/01".to_date 
              ob[:value_text] = 'Estimated'
            elsif year_started_art > 1 and month_started_art != 'Unknown' and day_started_art < 1
              ob[:value_datetime] = "#{year_started_art}/#{month_started_art}/15".to_date 
              ob[:value_text] = 'Estimated'
            end
          end
        end
      end
    end
    
        
    unless vitals_observations.blank?
      encounter = Encounter.new()
      encounter.encounter_type = EncounterType.find_by_name("VITALS").id
      encounter.patient_id = params['encounter']['patient_id']
      encounter.encounter_datetime = date_started_art

      unless params['encounter']['creator'].blank?
        #Hack for API for simulating patients visit. By mangochiman
        encounter.creator = params['encounter']['creator']
        User.current = User.find(params['encounter']['creator'])
      end

      if encounter.encounter_datetime.blank?                                                                        
        encounter.encounter_datetime = params['encounter']['encounter_datetime']  
      end 
      if params[:filter] and !params[:filter][:provider].blank?
        user_person_id = User.find_by_username(params[:filter][:provider]).person_id
      else
        user_person_id = User.find_by_user_id(params['encounter']['provider_id']).person_id
      end
      encounter.provider_id = user_person_id
      encounter.save   
      params[:observations] = vitals_observations
      create_obs(encounter , params)
    end

    unless observations.blank? 
      encounter = Encounter.new()
      encounter.encounter_type = EncounterType.find_by_name("HIV STAGING").id
      encounter.patient_id = params['encounter']['patient_id']
      encounter.encounter_datetime = date_started_art 
      if encounter.encounter_datetime.blank?                                                                        
        encounter.encounter_datetime = params['encounter']['encounter_datetime']  
      end 
      if params[:filter] and !params[:filter][:provider].blank?
        user_person_id = User.find_by_username(params[:filter][:provider]).person_id
      else
        user_person_id = User.find_by_user_id(params['encounter']['provider_id']).person_id
      end
      encounter.provider_id = user_person_id
      encounter.save 
        
      params[:observations] = observations 

      (params[:observations] || []).each do |observation|
        if observation['concept_name'].upcase == 'CD4 COUNT' or observation['concept_name'].upcase == "LYMPHOCYTE COUNT"
          observation['value_modifier'] = observation['value_numeric'].match(/=|>|</i)[0] rescue nil
          observation['value_numeric'] = observation['value_numeric'].match(/[0-9](.*)/i)[0] rescue nil
        end
      end
      create_obs(encounter , params)
    end
    params[:observations] = initial_observations if has_tranfer_letter  
    encounter_type = EncounterType.find_by_name('HIV CLINIC REGISTRATION')
    patient_id = params[:encounter]["patient_id"].to_i
    encounter_datetime = params[:encounter]['encounter_datetime'].to_time.strftime('%Y-%m-%d %H:%M:%S')

    encounter = Encounter.create(
      :encounter_type => encounter_type.id,
      :patient_id => patient_id,
      :encounter_datetime => encounter_datetime
    )
    



    # Program handling ################################################################
    date_enrolled = encounter.encounter_datetime
    patient = encounter.patient

    (params[:programs] || []).each do |program|
      if params['encounter']['encounter_type_name'] == 'HIV CLINIC REGISTRATION'
        next if not patient.patient_programs.in_programs("HIV PROGRAM").blank?
      end
      # Look up the program if the program id is set      
      patient_program = PatientProgram.find(program[:patient_program_id]) unless program[:patient_program_id].blank?

      if ! params[:location].blank?
        next if not patient.patient_programs.in_programs("HIV PROGRAM").blank?
      end

      # If it wasn't set, we need to create it
      unless (@patient_program)
        @patient_program = patient.patient_programs.create(
          :program_id => program[:program_id],
          :date_enrolled => date_enrolled)          
      end
      # Lots of states bub
      unless program[:states].blank?
        #adding program_state start date
        program[:states][0]['start_date'] = date_enrolled
      end
      (program[:states] || []).each {|state| @patient_program.transition(state) }
    end
    ####################################################################################





    create_obs(encounter ,  params)
    return next_task(encounter.patient)

  end

  def create_vitals_encounter(params, session)
    #raise params.inspect
    encounter_type = EncounterType.find_by_name('VITALS')
    patient_id = params[:encounter]["patient_id"].to_i
    begin
      encounter_datetime = session[:datetime].to_date.strftime('%Y-%m-%d 00:00:01') 
      params[:encounter]['encounter_datetime'] = encounter_datetime
    rescue
      encounter_datetime = params[:encounter]['encounter_datetime'].to_time.strftime('%Y-%m-%d %H:%M:%S') rescue nil
      if encounter_datetime.blank?
        encounter_datetime = Time.now().strftime('%Y-%m-%d %H:%M:%S')
        params[:encounter]['encounter_datetime'] = encounter_datetime
      end
    end


    encounter = Encounter.create(:patient_id => patient_id,
      :encounter_datetime => encounter_datetime, 
      :encounter_type => encounter_type.id)
    
    create_obs(encounter, params) 
    return next_task(encounter.patient)
  end

  def create_hiv_clinic_consultation_encounter(params, session)
    #A hack to set concept: Prescribe drugs to No/Yes if Medication orders include any of: ARVs/CPT/IPT
    set_prescribe_drugs_yes = true
    (params[:observations] || []).each do |ob|
      if ob[:concept_name] == 'Medication orders'
        ipt_index = ob['value_coded_or_text_multiple'].find_index('IPT') rescue nil
        ob['value_coded_or_text_multiple'][ipt_index] = 'Isoniazid' unless ipt_index.blank?
        options_selected = ob['value_coded_or_text_multiple'].join(',') unless ob['value_coded_or_text_multiple'].blank?
        if options_selected.blank?
          params[:observations] -= [ob]
          next
        end

        if options_selected.match(/None/i)
          set_prescribe_drugs_yes = false
          break
        end
      end
    end

    (params[:observations] || []).each do |ob|
      if ob[:concept_name] == 'Prescribe drugs'
        if (set_prescribe_drugs_yes == true)
          ob['value_coded_or_text'] = 'Yes'
        else
          ob['value_coded_or_text'] = 'NO'
        end
        
        break
      end
    end

    ##########3 hack ends here ######
    encounter_type = EncounterType.find_by_name('HIV CLINIC CONSULTATION')
    patient_id = params[:encounter]["patient_id"].to_i
    begin
      encounter_datetime = session[:datetime].to_date.strftime('%Y-%m-%d 00:00:01') 
      params[:encounter]['encounter_datetime'] = encounter_datetime
    rescue
      encounter_datetime = params[:encounter]['encounter_datetime'].to_time.strftime('%Y-%m-%d %H:%M:%S') rescue nil
      if encounter_datetime.blank?
        encounter_datetime = Time.now().strftime('%Y-%m-%d %H:%M:%S')
        params[:encounter]['encounter_datetime'] = encounter_datetime
      end
    end

    encounter = Encounter.create(:patient_id => patient_id,
      :encounter_datetime => encounter_datetime, 
      :encounter_type => encounter_type.id)

    create_obs(encounter ,  params)
    return next_task(encounter.patient)
  end

  def create_appointment_date_encounter(params, session)
    #raise session.inspect
    encounter_type = EncounterType.find_by_name('APPOINTMENT')
    patient_id = params[:encounter]["patient_id"].to_i
    begin
      encounter_datetime = session[:datetime].to_date.strftime('%Y-%m-%d 00:00:01') 
      params[:encounter]['encounter_datetime'] = encounter_datetime
    rescue
      encounter_datetime = params[:encounter]['encounter_datetime'].to_time.strftime('%Y-%m-%d %H:%M:%S') rescue nil
      if encounter_datetime.blank?
        encounter_datetime = Time.now().strftime('%Y-%m-%d %H:%M:%S')
        params[:encounter]['encounter_datetime'] = encounter_datetime
      end
    end

    encounter = Encounter.find(:last, :conditions => ["patient_id = ? AND encounter_type = ?
      AND encounter_datetime BETWEEN ? AND ?", patient_id, encounter_type.id,
        encounter_datetime.to_time.strftime('%Y-%m-%d 00:00:00'),
        encounter_datetime.to_time.strftime('%Y-%m-%d 23:59:59')])

    (encounter.observations || []).each do |o|
      o.void("Setting a new appointment date")
    end unless encounter.blank?

    encounter = Encounter.create(:patient_id => patient_id,
      :encounter_datetime => encounter_datetime, 
      :encounter_type => encounter_type.id) if encounter.blank?

    (params[:observations] || []).each do |ob|
      next unless ob['concept_name'].squish.match(/Appointment date/i)
      
      obs_datetime = encounter.encounter_datetime
      time = Time.now.strftime('%H:%M:%S')
      Observation.create(
        :person_id => patient_id, :encounter_id => encounter.id,
        :obs_datetime => obs_datetime, 
        :concept_id => ConceptName.find_by_name('Appointment date').concept_id,
        :value_datetime => ob['value_datetime'].to_date.strftime("%Y-%m-%d #{time}")
      )
    end

    return next_task(encounter.patient)
  end

  def create_hiv_staging_encounter(params, session)
    begin
      encounter_datetime = session[:datetime].to_date.strftime('%Y-%m-%d 00:00:01') 
      params[:encounter]['encounter_datetime'] = encounter_datetime
    rescue
      encounter_datetime = params[:encounter]['encounter_datetime'].to_time.strftime('%Y-%m-%d %H:%M:%S') rescue nil
      if encounter_datetime.blank?
        encounter_datetime = Time.now().strftime('%Y-%m-%d %H:%M:%S')
        params[:encounter]['encounter_datetime'] = encounter_datetime
      end
    end

    observations = []
    (params[:observations] || []).each do |observation|
      if observation['concept_name'].upcase == 'CD4 COUNT' or observation['concept_name'].upcase == "LYMPHOCYTE COUNT"
        observation['value_modifier'] = observation['value_numeric'].match(/=|>|</i)[0] rescue nil
        observation['value_numeric'] = observation['value_numeric'].match(/[0-9](.*)/i)[0] rescue nil
      end

      if observation['concept_name'].upcase == 'CD4 COUNT LOCATION' or observation['concept_name'].upcase == 'LYMPHOCYTE COUNT LOCATION'
        location = Location.find(observation['value_coded_or_text']) rescue nil

        unless location.blank?
          observation['value_numeric'] = location.id
          observation['value_text'] = location.name
        else
          observation['value_text'] =  observation['value_coded_or_text']
        end
        observation['value_coded_or_text'] = ""
      end

      if observation['concept_name'].upcase == 'CD4 PERCENT LOCATION'
        location = Location.find(observation['value_coded_or_text']) rescue nil

        unless location.blank?
          observation['value_numeric'] = location.id
          observation['value_text'] = location.name
        else
          observation['value_text'] =  observation['value_coded_or_text']
        end
        observation['value_coded_or_text'] = ""
      end

      observations << observation
    end
    
    params[:observations] = observations
    encounter_type = EncounterType.find_by_name('HIV STAGING')
    patient_id = params[:encounter]["patient_id"].to_i
    encounter_datetime = params[:encounter]['encounter_datetime'].to_time.strftime('%Y-%m-%d %H:%M:%S')

    encounter = Encounter.create(
      :encounter_type => encounter_type.id,
      :patient_id => patient_id,
      :encounter_datetime => encounter_datetime
    )
    create_obs(encounter ,  params)
    return next_task(encounter.patient)
  end

  def create_art_adherence_encounter(params, session)

    #A hack to set concept: Prescribe drugs to No/Yes if Medication orders include any of: ARVs/CPT/IPT
    set_prescribe_drugs_yes = true
    (params[:observations] || []).each do |ob|
      if ob[:concept_name] == 'Medication orders'
        ipt_index = ob['value_coded_or_text_multiple'].find_index('IPT') rescue nil
        ob['value_coded_or_text_multiple'][ipt_index] = 'Isoniazid' unless ipt_index.blank?
        options_selected = ob['value_coded_or_text_multiple'].join(',') unless ob['value_coded_or_text_multiple'].blank?
        if options_selected.blank?
          params[:observations] -= [ob]
          next
        end

        if options_selected.match(/None/i)
          set_prescribe_drugs_yes = false
          break
        end
      end
    end

    (params[:observations] || []).each do |ob|
      if ob[:concept_name] == 'Prescribe drugs'
        if (set_prescribe_drugs_yes == true)
          ob['value_coded_or_text'] = 'Yes'
        else
          ob['value_coded_or_text'] = 'NO'
        end
        
        break
      end
    end
    ##########3 hack ends here ######


    previous_hiv_clinic_consultation_observations = []
    art_adherence_observations = []
    (params[:observations] || []).each do |observation|
      if observation['concept_name'].upcase == 'REFER TO ART CLINICIAN'
        previous_hiv_clinic_consultation_observations << observation
      elsif observation['concept_name'].upcase == 'PRESCRIBE DRUGS'
        previous_hiv_clinic_consultation_observations << observation
      elsif observation['concept_name'].upcase == 'ALLERGIC TO SULPHUR'
        previous_hiv_clinic_consultation_observations << observation
      else
        art_adherence_observations << observation
      end
    end

    params[:observations] = art_adherence_observations

    encounter_type = EncounterType.find_by_name('ART ADHERENCE')
    patient_id = params[:encounter]["patient_id"].to_i
    begin
      encounter_datetime = session[:datetime].to_date.strftime('%Y-%m-%d 00:00:01') 
      params[:encounter]['encounter_datetime'] = encounter_datetime
    rescue
      encounter_datetime = params[:encounter]['encounter_datetime'].to_time.strftime('%Y-%m-%d %H:%M:%S') rescue nil
      if encounter_datetime.blank?
        encounter_datetime = Time.now().strftime('%Y-%m-%d %H:%M:%S')
        params[:encounter]['encounter_datetime'] = encounter_datetime
      end
    end

    encounter = Encounter.create(
      :encounter_type => encounter_type.id,
      :patient_id => patient_id,
      :encounter_datetime => encounter_datetime
    )


    observations = []
    (params[:observations] || []).each do |observation|
      if observation['concept_name'].upcase == 'WHAT WAS THE PATIENTS ADHERENCE FOR THIS DRUG ORDER'
        #observation['value_numeric'] = observation['value_text'] rescue nil
        observation['value_coded_or_text'] =  observation['value_coded_or_text'] + "%"
        observation['value_text'] =  observation['value_coded_or_text'] 
      end

      if observation['concept_name'].upcase == 'MISSED HIV DRUG CONSTRUCT'
        observation['value_numeric'] = observation['value_coded_or_text'] rescue nil
      end
      observations << observation
    end
    
    params[:observations] = observations

    create_obs(encounter ,  params)

    unless previous_hiv_clinic_consultation_observations.blank?
      session_date = session[:datetime].to_date rescue Date.today
      encounter_type = EncounterType.find_by_name("HIV CLINIC CONSULTATION")
      encounter = Encounter.find(:first,:order =>"encounter_datetime DESC,date_created DESC",
        :conditions =>["encounter_type = ? AND patient_id = ? AND encounter_datetime >= ?
          AND encounter_datetime <= ?",encounter_type.id, patient_id,
          session_date.strftime("%Y-%m-%d 00:00:00"),session_date.strftime("%Y-%m-%d 23:59:59")])

      unless encounter.blank?
        params[:observations] = previous_hiv_clinic_consultation_observations
        create_obs(encounter , params)
      end

      if encounter.blank?
        encounter = Encounter.new()
        encounter.encounter_type = encounter_type.id
        encounter.patient_id = params['encounter']['patient_id']
        encounter.encounter_datetime = session_date.strftime("%Y-%m-%d 00:00:01")
        if params[:filter] and !params[:filter][:provider].blank?
          user_person_id = User.find_by_username(params[:filter][:provider]).person_id
        else
          user_person_id = User.find_by_user_id(params['encounter']['provider_id']).person_id
        end
        encounter.provider_id = user_person_id
        encounter.save

        params[:observations] = previous_hiv_clinic_consultation_observations
        create_obs(encounter , params)
      end
    end

    patient = Patient.find(patient_id)
    url = next_task(patient)
    return url
  end

  def create_tb_reception_encounter(params, session)
    encounter_type = EncounterType.find_by_name('TB RECEPTION')
    patient_id = params[:encounter]["patient_id"].to_i
    begin
      encounter_datetime = session[:datetime].to_date.strftime('%Y-%m-%d 00:00:01') 
      params[:encounter]['encounter_datetime'] = encounter_datetime
    rescue
      encounter_datetime = params[:encounter]['encounter_datetime'].to_time.strftime('%Y-%m-%d %H:%M:%S') rescue nil
      if encounter_datetime.blank?
        encounter_datetime = Time.now().strftime('%Y-%m-%d %H:%M:%S')
        params[:encounter]['encounter_datetime'] = encounter_datetime
      end
    end

    encounter = Encounter.create(:patient_id => patient_id,
      :encounter_datetime => encounter_datetime, 
      :encounter_type => encounter_type.id)

    create_obs(encounter, params)
 
    #when the patient has been assigned ARV number
    unless params[:identifiers].blank?
      hcc_identifier_type = PatientIdentifierType.find_by_name('HCC Number')
      arv_identifier_type = PatientIdentifierType.find_by_name('ARV Number')

      (params[:identifiers] || []).each do |i|
        identifier_type = i["identifier_type"].to_i
        number = i["identifier"]
        if identifier_type == arv_identifier_type.id
          identifier = "#{PatientIdentifier.site_prefix}-ARV-#{number}"
        elsif identifier_type == hcc_identifier_type.id
          identifier = "#{PatientIdentifier.site_prefix}-HCC-#{number}"
        end

        PatientIdentifier.create(:patient_id => patient_id,
          :identifier_type => identifier_type, :identifier => identifier) 
      end
    end

    return next_task(encounter.patient)
  end

  def create_tb_encounter(params, session)
    encounter_type = EncounterType.find_by_name(params[:encounter]['encounter_type_name'])
    patient_id = params[:encounter]["patient_id"].to_i
    begin
      encounter_datetime = session[:datetime].to_date.strftime('%Y-%m-%d 00:00:01') rescue nil
    rescue
      encounter_datetime = params[:encounter]['encounter_datetime'].to_time.strftime('%Y-%m-%d %H:%M:%S')
    end

    encounter = Encounter.create(:patient_id => patient_id,
      :encounter_datetime => encounter_datetime, 
      :encounter_type => encounter_type.id)


    create_obs(encounter, params)
  end

end
