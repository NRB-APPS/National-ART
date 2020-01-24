class EncountersController < GenericEncountersController
	def new
		#raise params.to_yaml
		session_date = session[:datetime].to_date rescue Date.today
		@patient = Patient.find(params[:patient_id] || session[:patient_id] || params[:id])
		@patient_bean = PatientService.get_patient(@patient.person, session_date)
    
    if (params[:encounter_type].upcase rescue '') == 'APPOINTMENT'
			@todays_date = session_date
			logger.info('========================== Suggesting appointment date =================================== @ '  + Time.now.to_s)
      earliest_auto_expire_medication = MedicationService.earliest_auto_expire_dispensed_medication(@patient, session_date.to_date)
      @max_date = earliest_auto_expire_medication.to_date 
			@suggested_appointment_date = suggest_appointment_date(@max_date)
			logger.info('========================== Completed suggesting appointment date =================================== @ '  + Time.now.to_s)

      begin
        @appointment_limit = CoreService.get_global_property_value('clinic.appointment.limit').to_i 
        if @appointment_limit.blank? || @appointment_limit == 0
          @appointment_limit = 100
        end
      rescue 
        @appointment_limit = 100
      end

      clinic_holidays = CoreService.get_global_property_value('clinic.holidays')
      @set_clinic_holidays = []

      unless clinic_holidays.blank?
        (clinic_holidays.split(',') || []).map do |day|
          @set_clinic_holidays << day.to_date
        end
      end

      if @set_clinic_holidays.blank?
        @set_clinic_holidays = ["#{Date.today.year}-01-01", "#{Date.today.year}-12-25","#{Date.today.year}-03-03"]
      end
      render :action => params[:encounter_type] and return
		end

    @gender = @patient.person.gender.upcase
    @birth_date = @patient.person.birthdate.to_date
    @previous_weight = Patient.previous_weight(@patient, session_date)

    fast_track_concepts_names = ["Age > 18 years and on ART > 1 year", "Not On Second Line Treatment OR on IPT",
      "Last VL < 1000, no VL Result pending, no VL taken at next visit", "Not Pregnant? - no EID needed at next visit",
      "Adherence on last 2 visits was good", "Patient not suffering from major side effects, signs of TB or HIV associated disease",
      "Patient do not need hypertension or diabetes care on next visit"]

    fast_track_new_concept_names = ["Adult 18 years +", "on ART for 12 months +", "on 1st Line ART", "Last VL < 1000",
      "Good adherence last 2 visits", "Not Pregnant / Breastfeeding", "No Side Effects, OI / TB",
      "No BP / diabetes treatment", "No need for Depo at ART"
    ]

    @fast_track_assesment_concept_names = {}
    count = 1
    fast_track_concepts_names.each do |c_name|
      concept = Concept.find_by_name(c_name)
      @fast_track_assesment_concept_names[count] = {:concept_id => concept.concept_id, :concept_name => c_name}
      count = count + 1
    end
      
    art_start_date = PatientService.date_antiretrovirals_started(@patient)
    @new_guide_lines_start_date = GlobalProperty.find_by_property('new.art.start.date').property_value.to_date rescue session_date
    @session_date = session_date
    @art_duration_in_months = PatientService.period_on_treatment(art_start_date) rescue 0
    @fast_track_patient = fast_track_patient?(@patient, session_date)
    @last_appointment_date = patient_last_appointment_date(@patient,  session_date)
    @fast_track_patient_but_missed_appointment = fast_track_patient_but_missed_appointment?(@patient, session_date)
    @patient_has_stopped_fast_track_at_adherence = patient_has_stopped_fast_track_at_adherence?(@patient, session_date)
    @fast_track_message = ""
    if (session_date == @last_appointment_date.to_date)
      @fast_track_message = "Patient is on time"
    end rescue nil

    if (session_date < @last_appointment_date.to_date)
      days_diff = (@last_appointment_date.to_date - session_date).to_i
      @fast_track_message = "Patient is #{days_diff} day(s) early"
    end rescue nil

    if (session_date > @last_appointment_date.to_date)
      days_diff = (session_date - @last_appointment_date.to_date).to_i
      @fast_track_message = "Patient is #{days_diff} day(s) late"
    end rescue nil

    @patient_on_tb_treatment = patient_on_tb_treatment?(@patient, session_date)
    @patient_tb_suspected = tb_suspected_today?(@patient, session_date)
    @patient_tb_confirmed = tb_confirmed_today?(@patient, session_date)

    @confirmatory_hiv_test_type = Patient.type_of_hiv_confirmatory_test(@patient, session_date) rescue ""
    @hiv_clinic_registration_date = Patient.date_of_hiv_clinic_registration(@patient, session_date) rescue ""

    @ever_received_answer = Observation.find(:last, :conditions => ["person_id =? AND concept_id =? AND
      DATE(obs_datetime) =?", @patient.id, Concept.find_by_name('EVER RECEIVED ART').concept_id, session_date]
    ).answer_string.squish.upcase rescue ""

    #@fast_track_patient = false
    #@latest_fast_track_answer = @patient.person.observations.recent(1).question("FAST").first.answer_string.squish.upcase rescue nil
    #@fast_track_patient = true if @latest_fast_track_answer == 'YES'
    
    #if (patient_has_visited_on_scheduled_date(@patient,  session_date) == false)
    #@fast_track_patient = false
    # @latest_fast_track_answer = 'NO' #if this is No, then Fast Track popups will not be activated
    #end
=begin
    if (tb_suspected_or_confirmed?(@patient, session_date) == true)
      #Not interested in patients with tb suspect or confirmed tb
      @fast_track_patient = false
      @latest_fast_track_answer = 'NO' #if this is No, then Fast Track popups will not be activated
    end

    if (is_patient_on_htn_treatment?(@patient, session_date) == true)
      #Not interested in HTN patients
      @fast_track_patient = false
      @latest_fast_track_answer = 'NO'
    end
=end
    @fast_track_stop_reasons = ['', 'Poor Adherence', 'Sick', 'Side Effects', 'Other']
    @latest_vl_result = Lab.latest_viral_load_result(@patient)

    session[:return_uri] = params[:return_ip] if ! params[:return_ip].blank?
    
    @hiv_status = tb_art_patient(@patient,"hiv program") rescue ""
    @tb_status = tb_art_patient(@patient,"TB program") rescue ""
    @show_tb_types = false
    consultation_tb_status = Patient.find_by_sql("
											SELECT patient_id, current_state_for_program(patient_id, 2, '#{session_date}') AS state, c.name as status
											FROM patient p INNER JOIN program_workflow_state pw ON pw.program_workflow_state_id = current_state_for_program(patient_id, 2, '#{session_date}')
											INNER JOIN concept_name c ON c.concept_id = pw.concept_id where p.patient_id = '#{@patient.patient_id}'").first.status rescue ""
    if consultation_tb_status == "Currently in treatment"
      @consultation_tb_status = "Confirmed TB on treatment"
    elsif consultation_tb_status == "Symptomatic but NOT in treatment" or @hiv_status.to_s.upcase == "POSITIVE"
      @consultation_tb_status = "Confirmed TB NOT on treatment"
    else
      @show_tb_types = true
      @consultation_tb_status = "Unknown"
    end
		@current_hiv_program_status = Patient.find_by_sql("
											SELECT patient_id, current_state_for_program(patient_id, 1, '#{session_date}') AS state, c.name as status
											FROM patient p INNER JOIN program_workflow_state pw ON pw.program_workflow_state_id = current_state_for_program(patient_id, 1, '#{session_date}')
											INNER JOIN concept_name c ON c.concept_id = pw.concept_id where p.patient_id = '#{@patient.patient_id}'").first.status rescue "Unknown"
    @ask_staging = false
    @check_preart = false
    @normal_procedure = false
    if @current_hiv_program_status == "Pre-ART (Continue)"
      current_date = session[:datetime].to_date rescue Date.today
      if params[:repeat].blank?

        last_staging_date = Encounter.find_by_sql("
         SELECT * FROM encounter
          WHERE patient_id = #{@patient.id} AND encounter_type = #{EncounterType.find_by_name('HIV Staging').id}
          AND encounter_datetime < '#{current_date}' AND voided=0 ORDER BY encounter_datetime DESC LIMIT 1").first.encounter_datetime.to_date rescue ""
        
        if ! last_staging_date.blank? 
          month_gone = (current_date.year * 12 + current_date.month) - (last_staging_date.year * 12 + last_staging_date.month)
          @ask_staging = true if month_gone <= 3
          @normal_procedure =  true if month_gone > 3
        end
        #raise session["#{@patient.id}"]["#{current_date}"][:stage_patient].to_yaml
        #session["#{@patient.id}"]["#{current_date}"][:stage_patient] = []
      else
        session["#{@patient.id}"] = {}
        session["#{@patient.id}"]["#{current_date}"] = {}
          
        if params[:repeat] == "no"
          session["#{@patient.id}"]["#{current_date}"][:stage_patient] = "Yes"
        else
          session["#{@patient.id}"]["#{current_date}"][:stage_patient] = "No"
        end
         
        @check_preart = true
      end
    end
    
		if (params[:from_anc] == 'true')
      bart_activities = ['Manage Vitals','Manage HIV clinic consultations',
        'Manage ART adherence','Manage HIV staging visits','Manage HIV first visits',
        'Manage HIV reception visits','Manage drug dispensations','Manage prescription']

      current_user_activities = []
      current_user.activities.each{|a| current_user_activities << a.upcase }

      user_property = UserProperty.find(:first,
        :conditions =>["property = 'Activities' AND user_id = ?",current_user.id])

      (bart_activities).each do |activity|
        if not current_user_activities.include?(activity.upcase)
          user_property.property_value += ",#{activity}" rescue "" unless current_user.activities.blank?
          user_property.property_value = activity if current_user.activities.blank?
          user_property.save 
        end
      end
    end


		if session[:datetime]
			@retrospective = true 
		else
			@retrospective = false
		end
		@current_height = PatientService.get_patient_attribute_value(@patient, "current_height", session_date)
    
		@min_weight = PatientService.get_patient_attribute_value(@patient, "min_weight")
    @max_weight = PatientService.get_patient_attribute_value(@patient, "max_weight")
    @min_height = PatientService.get_patient_attribute_value(@patient, "min_height")
    @max_height = PatientService.get_patient_attribute_value(@patient, "max_height")
    @given_arvs_before = given_arvs_before(@patient)
    @current_encounters = @patient.encounters.find_by_date(session_date)
    @previous_tb_visit = previous_tb_visit(@patient.id)

    @is_patient_pregnant_value = nil
    @is_patient_breast_feeding_value = nil
    @currently_using_family_planning_methods = nil
    @guardian_visit = false
    @transfer_in_TB_registration_number = get_todays_observation_answer_for_encounter(@patient.id, "TB_INITIAL", "TB registration number")
    @referred_to_htc = nil
    @family_planning_methods = []
    @guardian_present = false
    @patient_present = false

    #guardian and patient present concepts
    guardian_present_concept_id = ConceptName.find_by_name("GUARDIAN PRESENT").concept_id 
    patient_present_concept_id = ConceptName.find_by_name("PATIENT PRESENT").concept_id 

    (@current_encounters || []).each do |encounter|
      if encounter.encounter_type == EncounterType.find_by_name("HIV RECEPTION").encounter_type_id
        (encounter.observations || []).each do |obs|
          if obs.concept_id == guardian_present_concept_id && obs.to_s.split(":")[1].squish == "Yes"
            @guardian_present =  true
          end

          if obs.concept_id == patient_present_concept_id && obs.to_s.split(":")[1].squish == "Yes"
            @patient_present = true
          end
        end
      end
    end

    if 'tb_reception'.upcase == (params[:encounter_type].upcase rescue '')
      @phone_numbers = PatientService.phone_numbers(Person.find(params[:patient_id]))
    end
       
    if 'HIV_CLINIC_CONSULTATION' == (params[:encounter_type].upcase rescue '') || 'ART_ADHERENCE' == (params[:encounter_type].upcase rescue '')
      session_date = session[:datetime].to_date rescue Date.today

      @allergic_to_sulphur = Observation.find(Observation.find(:first,
          :order => "obs_datetime DESC,date_created DESC",
          :conditions => ["person_id = ? AND concept_id = ?
                            AND DATE(obs_datetime) <= ?",@patient.id,
            ConceptName.find_by_name("Allergic to sulphur").concept_id,session_date])).answer_string.strip.squish rescue ''

      @use_extended_family_planning = CoreService.get_global_property_value('extended.family.planning') rescue false

      @obs_ans = Observation.find(Observation.find(:first,
          :order => "obs_datetime DESC,date_created DESC",
          :conditions => ["person_id = ? AND concept_id = ? AND DATE(obs_datetime) = ?",
            @patient.id,ConceptName.find_by_name("Prescribe drugs").concept_id,session_date])).to_s.strip.squish rescue ''

      @obs_ans = '' if @patient_has_stopped_fast_track_at_adherence #Just a hack. Do not remove this please.By mangochiman

      @current_weight = PatientService.get_patient_attribute_value(@patient, "current_weight", session_date) rescue []
    end
        
    if (params[:encounter_type].upcase rescue '') == 'UPDATE HIV STATUS'
      @referred_to_htc = get_todays_observation_answer_for_encounter(@patient.id, "UPDATE HIV STATUS", "Refer to HTC")
    end
    
		@given_lab_results = Encounter.find(:last,
			:order => "encounter_datetime DESC,date_created DESC",
			:conditions =>["encounter_type = ? and patient_id = ?",
				EncounterType.find_by_name("GIVE LAB RESULTS").id,@patient.id]).observations.map{|o|
      o.answer_string if o.to_s.include?("Laboratory results given to patient")} rescue nil
   
		@transfer_to = Encounter.find(:last,:conditions =>["encounter_type = ? and patient_id = ?",
        EncounterType.find_by_name("TB VISIT").id,@patient.id]).observations.map{|o|
      o.answer_string if o.to_s.include?("Transfer out to")} rescue nil
      
		@recent_sputum_results = PatientService.recent_sputum_results(@patient.id) rescue nil

    @recent_sputum_submissions = PatientService.recent_sputum_submissions(@patient.id)
    
		@continue_treatment_at_site = []
		Encounter.find(:last,:conditions =>["encounter_type = ? and patient_id = ? AND DATE(encounter_datetime) = ?",
        EncounterType.find_by_name("TB CLINIC VISIT").id,
        @patient.id,session_date.to_date]).observations.map{|o| @continue_treatment_at_site << o.answer_string if o.to_s.include?("Continue treatment")} rescue nil

		@patient_has_closed_TB_program_at_current_location = PatientProgram.find(:all,:conditions =>
        ["voided = 0 AND patient_id = ? AND location_id = ? AND (program_id = ? OR program_id = ?)", @patient.id, Location.current_health_center.id, Program.find_by_name('TB PROGRAM').id, Program.find_by_name('MDR-TB PROGRAM').id]).last.closed? rescue true

		if (params[:encounter_type].upcase rescue '') == 'IPT CONTACT PERSON'
			@contacts_ipt = []
						
			@ipt_contacts_ = @patient.tb_contacts.collect{|person| person unless PatientService.get_patient(person).age > 6}.compact rescue []
			@ipt_contacts.each do | person |
				@contacts_ipt << PatientService.get_patient(person)
			end
		end
		
		@select_options = select_options
		@months_since_last_hiv_test = PatientService.months_since_last_hiv_test(@patient.id)
		@current_user_role = self.current_user_role
		@tb_patient = is_tb_patient(@patient)
		@art_patient = PatientService.art_patient?(@patient)
		@recent_lab_results = patient_recent_lab_results(@patient.id)
    
    if @use_extended_family_planning && is_child_bearing_female(@patient)
      @select_options['why_no_family_planning_method'] = [
        ['Not sexually active', 'NOT SEXUALLY ACTIVE'],
        ['Patient wants to get pregnant','PATIENT WANTS TO GET PREGNANT'],
        ['Not needed for medical reasons', 'NOT NEEDED FOR MEDICAL REASONS'],
        ['At risk of unplanned pregnancy', 'AT RISK OF UNPLANNED PREGNANCY']
      ]

      @select_options['why_no_family_planning_method_specific'] = [
        ['Following wishes of spouse', 'FOLLOWING WISHES OF SPOUSE'],
        ['Religious reasons', 'RELIGIOUS REASONS'],
        ['Afraid of side effects','AFRAID OF SIDE EFFECTS'],
        ['Never thought about it','NEVER THOUGHT ABOUT IT'],
        ['Indifferent (Does not mind getting pregnant )', 'INDIFFERENT']
      ]

      @select_options['family_planning_methods_int'] = [
        ['Oral contraceptive pills', 'ORAL CONTRACEPTIVE PILLS'],
        ['Depo-Provera', 'DEPO-PROVERA'],
        ['IUD-Intrauterine device/loop', 'INTRAUTERINE CONTRACEPTION'],
        ['Contraceptive implant', 'CONTRACEPTIVE IMPLANT'],
        ['Female condoms', 'FEMALE CONDOMS'],
        ['Male condoms', 'MALE CONDOMS'],
        ['Tubal ligation', 'TUBAL LIGATION']
      ]

			if @retrospective
			
				@select_options['why_no_family_planning_method_specific'] << ['Other', 'OTHER'] << ['Unknown', 'UNKNOWN']
			
			end						
					
      @select_options['dual_options'] = [
        ['Oral contraceptive pills', 'ORAL CONTRACEPTIVE PILLS'],
        ['Depo-Provera', 'DEPO-PROVERA'],
        ['IUD-Intrauterine device/loop', 'INTRAUTERINE CONTRACEPTION'],
        ['Contraceptive implant', 'CONTRACEPTIVE IMPLANT']]
    end


		if (params[:encounter_type].upcase rescue '') == 'APPOINTMENT'
			@todays_date = session_date
			logger.info('========================== Suggesting appointment date =================================== @ '  + Time.now.to_s)
      earliest_auto_expire_medication = MedicationService.earliest_auto_expire_dispensed_medication(@patient, session_date.to_date)
      @max_date = earliest_auto_expire_medication.to_date
			@suggested_appointment_date = suggest_appointment_date(@max_date)
			logger.info('========================== Completed suggesting appointment date =================================== @ '  + Time.now.to_s)
		end

    @patient_ever_had_drugs = false
		@drug_given_before = MedicationService.drug_given_before(@patient, session[:datetime])
    @patient_ever_had_drugs = true unless @drug_given_before.blank?

    todays_seen_encounters = @patient.encounters.find(:all, :conditions => ["DATE(encounter_datetime) =?",
        session_date]).collect{|e|e.name.upcase}
    @hiv_reception_only_available = false
    if (todays_seen_encounters.count == 1 && todays_seen_encounters.include?('HIV RECEPTION'))
      @hiv_reception_only_available = true
    end

		@hiv_status = PatientService.patient_hiv_status(@patient)
		@hiv_test_date = PatientService.hiv_test_date(@patient.id)
    
		@lab_activities = lab_activities
		# @tb_classification = [["Pulmonary TB","PULMONARY TB"],["Extra Pulmonary TB","EXTRA PULMONARY TB"]]
		@tb_patient_category = [["New","NEW"], ["Relapse","RELAPSE"], ["Retreatment after default","RETREATMENT AFTER DEFAULT"], ["Fail","FAIL"], ["Other","OTHER"]]
		@sputum_visual_appearance = [['Muco-purulent','MUCO-PURULENT'],['Blood-stained','BLOOD-STAINED'],['Saliva','SALIVA']]

		@sputum_results = [['Negative', 'NEGATIVE'], ['Scanty', 'SCANTY'], ['1+', 'Weakly positive'], ['2+', 'Moderately positive'], ['3+', 'Strongly positive']]
    
		@sputum_orders = Hash.new()
		@sputum_submission_waiting_results = Hash.new()
		@sputum_results_not_given = Hash.new()
		@art_first_visit = is_first_hiv_clinic_consultation(@patient.id)
		@tb_first_registration = is_first_tb_registration(@patient.id)
		@tb_programs_state = uncompleted_tb_programs_status(@patient)
		@had_tb_treatment_before = ever_received_tb_treatment(@patient.id)
		@any_previous_tb_programs = any_previous_tb_programs(@patient.id)

		PatientService.sputum_orders_without_submission(@patient.id).each { | order | 
			@sputum_orders[order.accession_number] = Concept.find(order.value_coded).fullname rescue order.value_text
		}
		
		sputum_submissons_with_no_results(@patient.id).each{|order| @sputum_submission_waiting_results[order.accession_number] = Concept.find(order.value_coded).fullname rescue order.value_text}
		sputum_results_not_given(@patient.id).each{|order| @sputum_results_not_given[order.accession_number] = Concept.find(order.value_coded).fullname rescue order.value_text}

    if @art_first_visit
      @hiv_clinic_consultation_side_efects_label = "Potential Contra-indications (select all that apply)"
      @hiv_clinic_consultation_side_efects_label_short = "Potential Contra-indications"
    else
      @hiv_clinic_consultation_side_efects_label = "Potential Side effects (select all that apply)"
      @hiv_clinic_consultation_side_efects_label_short = "Potential Side effects"
    end
    
		@tb_status = recent_lab_results(@patient.id, session_date)
    # use @patient_tb_status  for the tb_status moved from the patient model
    @patient_tb_status = PatientService.patient_tb_status(@patient)
		@patient_is_transfer_in = is_transfer_in(@patient)
		@patient_transfer_in_date = get_transfer_in_date(@patient)
		@patient_is_child_bearing_female = is_child_bearing_female(@patient)
    @cell_number = @patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Cell Phone Number").id).value rescue ''

    @tb_symptoms = []
   
		if (params[:encounter_type].upcase rescue '') == 'TB_INITIAL'
			current_weight = PatientService.get_patient_attribute_value(@patient, "current_weight", session_date)
      tb_program = Program.find_by_name('TB Program')
			@tb_regimen_array = MedicationService.regimen_options(current_weight, tb_program)
			tb_program = Program.find_by_name('MDR-TB Program')
			@tb_regimen_array += MedicationService.regimen_options(current_weight, tb_program)
			@tb_regimen_array += [['Other', 'Other'], ['Unknown', 'Unknown']]
		end

		if (params[:encounter_type].upcase rescue '') == 'TB_VISIT'
		  @current_encounters.reverse.each do |enc|
        enc.observations.each do |o|
          @tb_symptoms << o.answer_string.strip if o.to_s.include?("TB symptoms") rescue nil
        end
      end
		end

		@location_transferred_to = []
		if (params[:encounter_type].upcase rescue '') == 'APPOINTMENT'
		  @old_appointment = nil
		  @report_url = nil
		  @report_url =  params[:report_url]  and @old_appointment = params[:old_appointment] if !params[:report_url].nil?
		  @current_encounters.reverse.each do |enc|
        enc.observations.each do |o|
          @location_transferred_to << o.to_s_location_name.strip if o.to_s.include?("Transfer out to") rescue nil
        end
      end
		end

		@tb_classification = nil
		@eptb_classification = nil
		@tb_type = nil

		@patients = nil
		
		if (params[:encounter_type].upcase rescue '') == "SOURCE_OF_REFERRAL"
			people = PatientService.person_search(params)
			@patients = []
			people.each do | person |
				patient = PatientService.get_patient(person)
				@patients << patient
			end
		end
    #raise @patient.person.observations.to_s.to_yaml
    if (params[:encounter_type].upcase rescue '') == 'TB_CLINIC_VISIT'
      @remote_results = false
      if @patient.person.observations.to_s.match(/Tuberculosis smear result:  Yes/i)
        if @patient.person.observations.to_s.match(/Moderately positive/i) or @patient.person.observations.to_s.match(/Strongly positive/i) or  @patient.person.observations.to_s.match(/Weakly positive/i)
          @suspected = true
        end
        
      end
    end

		if (params[:encounter_type].upcase rescue '') == 'TB_REGISTRATION'

			tb_clinic_visit_obs = Encounter.find(:first,:order => "encounter_datetime DESC",
				:conditions => ["DATE(encounter_datetime) = ? AND patient_id = ? AND encounter_type = ?",
          session_date, @patient.id, EncounterType.find_by_name('TB CLINIC VISIT').id]).observations rescue []

			(tb_clinic_visit_obs || []).each do | obs | 
				if obs.concept_id == Concept.find_by_name('EPTB classification').concept_id
					#@tb_classification = Concept.find(obs.value_coded).concept_names.typed("SHORT").first.name rescue Concept.find(obs.value_coded).fullname if Concept.find_by_name('TB classification').concept_id
					@eptb_classification = Concept.find(obs.value_coded).concept_names.typed("SHORT").first.name rescue Concept.find(obs.value_coded).fullname #if obs.concept_id == Concept.find_by_name('EPTB classification').concept_id
					#@tb_type = Concept.find(obs.value_coded).concept_names.typed("SHORT").first.name rescue Concept.find(obs.value_coded).fullname if obs.concept_id == Concept.find_by_name('TB type').concept_id
 				end
				if  obs.concept_id == Concept.find_by_name('TB classification').concept_id
          @tb_classification = Concept.find(obs.value_coded).concept_names.typed("SHORT").first.name
				end
				if obs.concept_id == Concept.find_by_name('TB type').concept_id
					@tb_type = Concept.find(obs.value_coded).concept_names.typed("SHORT").first.name rescue obs.value_text
				end
			end

		end

    if  ['HIV_CLINIC_CONSULTATION', 'TB_VISIT', 'HIV_STAGING'].include?((params[:encounter_type].upcase rescue ''))
      
      @current_weight = PatientService.get_patient_attribute_value(@patient, "current_weight", session_date)
      @current_height = PatientService.get_patient_attribute_value(@patient, "current_height", session_date)
      if @patient.person.age(session_date.to_date) >= 6 
        if @current_height > 0 and @current_weight > 0
          @current_patient_bmi =  (@current_weight/(@current_height*@current_height)*10000).round(1)
        end
      else
        median_weight_height = WeightHeightForAge.median_weight_height(@patient_bean.age_in_months, @patient.person.gender) rescue []
        if @current_weight > 0
          @current_weight_percentile = (@current_weight/(median_weight_height[0])*100) rescue 0
        end
      end

			@local_tb_dot_sites_tag = tb_dot_sites_tag 
			for encounter in @current_encounters.reverse do
				if encounter.name.humanize.include?('Hiv staging') || encounter.name.humanize.include?('Tb visit') || encounter.name.humanize.include?('Hiv clinic consultation') 
					encounter = Encounter.find(encounter.id, :include => [:observations])
					for obs in encounter.observations do
						if obs.concept_id == ConceptName.find_by_name("IS PATIENT PREGNANT?").concept_id
							@is_patient_pregnant_value = "#{obs.to_s(["short", "order"]).to_s.split(":")[1]}"
						end

						if obs.concept_id == ConceptName.find_by_name("IS PATIENT BREAST FEEDING?").concept_id
							@is_patient_breast_feeding_value = "#{obs.to_s(["short", "order"]).to_s.split(":")[1]}"
						end
					end

					if encounter.name.humanize.include?('Tb visit') || encounter.name.humanize.include?('Hiv clinic consultation')
						encounter = Encounter.find(encounter.id, :include => [:observations])
						for obs in encounter.observations do
							if obs.concept_id == ConceptName.find_by_name("CURRENTLY USING FAMILY PLANNING METHOD").concept_id
								#@currently_using_family_planning_methods = "#{obs.to_s(["short", "order"]).to_s.split(":")[1]}".squish
							end

							if obs.concept_id == ConceptName.find_by_name("FAMILY PLANNING METHOD").concept_id
								@family_planning_methods << "#{obs.to_s(["short", "order"]).to_s.split(":")[1]}".squish
							end
						end
					end
				end
			end

      @terminal_family_planning_method = false

      patient_family_planning_methods = @patient.person.observations.question("FAMILY PLANNING METHOD").collect{
        |o|o.answer_string.squish.upcase
      }
      @terminal_family_planning_method = true if patient_family_planning_methods.include?("TUBAL LIGATION")
  
      latest_visit_date = Encounter.find_by_sql("SELECT MAX(encounter_datetime) as encounter_datetime FROM encounter WHERE patient_id = #{@patient.id} AND
        voided = 0 AND DATE(encounter_datetime) < '#{session_date}'").last.encounter_datetime.to_date rescue nil

      latest_family_planning_method_question = @patient.person.observations.question("CURRENTLY USING FAMILY PLANNING METHOD").find(:last,
        :conditions => ["DATE(obs_datetime) = ?", latest_visit_date], :order => "obs_datetime ASC"
      ).answer_string.squish.upcase rescue nil
      @currently_using_family_planning_methods = latest_family_planning_method_question if latest_family_planning_method_question == 'YES'

    end

		if CoreService.get_global_property_value('use.normal.staging.questions').to_s == "true"
			@who_stage_peds_i = concept_set('WHO STAGE I PEDS')
			@who_stage_peds_ii = concept_set('WHO STAGE II PEDS')
			@who_stage_peds_iii = concept_set('WHO STAGE III PEDS')
			@who_stage_peds_iv = concept_set('WHO STAGE IV PEDS')

			@who_stage_adults_i = concept_set('WHO STAGE I ADULT')
			@who_stage_adults_ii = concept_set('WHO STAGE II ADULT')
			@who_stage_adults_iii = concept_set('WHO STAGE III ADULT')
			@who_stage_adults_iv = concept_set('WHO STAGE IV ADULT')
		end

    who_stage_iv_to_be_removed = ["HIV encephalopathy", "Disseminated non-tuberculosis mycobacterial infection",
      "Isosporiasis >1 month",
      "Disseminated mycosis (coccidiomycosis or histoplasmosis)", "Progressive multifocal leukoencephalopathy",
      "Cytomegalovirus infection (retinitis or infection or other organs)"]

		if (params[:encounter_type].upcase rescue '') == 'HIV_STAGING' or (params[:encounter_type].upcase rescue '') == 'HIV_CLINIC_REGISTRATION'
			if @patient_bean.age > 14 
				@who_stage_i = concept_set('WHO STAGE I ADULT AND PEDS') + concept_set('WHO STAGE I ADULT')
				@who_stage_ii = concept_set('WHO STAGE II ADULT AND PEDS') + concept_set('WHO STAGE II ADULT')
				@who_stage_iii = concept_set('WHO STAGE III ADULT AND PEDS') + concept_set('WHO STAGE III ADULT')
				@who_stage_iv = concept_set('WHO STAGE IV ADULT AND PEDS') + concept_set('WHO STAGE IV ADULT')

				if CoreService.get_global_property_value('use.extended.staging.questions').to_s == "true"
					@not_explicitly_asked = concept_set('WHO Stage defining conditions not explicitly asked adult')
				end
			else
				@who_stage_i = concept_set('WHO STAGE I ADULT AND PEDS') + concept_set('WHO STAGE I PEDS')
				@who_stage_ii = concept_set('WHO STAGE II ADULT AND PEDS') + concept_set('WHO STAGE II PEDS')
				@who_stage_iii = concept_set('WHO STAGE III ADULT AND PEDS') + concept_set('WHO STAGE III PEDS')
				@who_stage_iv = concept_set('WHO STAGE IV ADULT AND PEDS') + concept_set('WHO STAGE IV PEDS')
				if CoreService.get_global_property_value('use.extended.staging.questions').to_s == "true"
					@not_explicitly_asked = concept_set('WHO Stage defining conditions not explicitly asked peds')
				end
			end

			if ((params[:encounter_type].upcase rescue '') == 'HIV_STAGING') || (params[:encounter_type].upcase rescue '') == 'HIV_CLINIC_REGISTRATION'
				#added current weight to use on HIV staging for infants
				@current_weight = PatientService.get_patient_attribute_value(@patient,
          "current_weight")
				if !@retrospective
					@who_stage_i = @who_stage_i - concept_set('Unspecified Staging Conditions')
					@who_stage_ii = @who_stage_ii - concept_set('Unspecified Staging Conditions')
					@who_stage_iii = @who_stage_iii - concept_set('Unspecified Staging Conditions')
					@who_stage_iv = @who_stage_iv - concept_set('Unspecified Staging Conditions') - concept_set('Calculated WHO HIV staging conditions')
				end

				@moderate_wasting = []
				@severe_wasting = []
        @median_weight_height = []
        @current_bmi = 0
        
				if @patient_bean.age < 15
					median_weight_height = WeightHeightForAge.median_weight_height(@patient_bean.age_in_months, @patient.person.gender) rescue []
          @median_weight_height = median_weight_height
					current_weight_percentile = (@current_weight/(median_weight_height[0])*100) rescue 0
          
					if current_weight_percentile >= 70 && current_weight_percentile <= 79
						@moderate_wasting = ["Moderate unexplained wasting/malnutrition not responding to treatment (weight-for-height/ -age 70-79% or muac 11-12 cm)"]
						@who_stage_iii = @who_stage_iii.flatten.uniq if CoreService.get_global_property_value('use.extended.staging.questions').to_s != "true"       
						@severe_wasting = []
					elsif current_weight_percentile < 70
						@severe_wasting = ["Severe unexplained wasting or malnutrition not responding to treatment (weight-for-height/ -age <70% or MUAC less than 11cm or oedema)"]
						@who_stage_iv = @who_stage_iv.flatten.uniq if CoreService.get_global_property_value('use.extended.staging.questions').to_s != "true"
						@moderate_wasting = []
					end
        elsif @patient_bean.age >= 15
          current_weight = PatientService.get_patient_attribute_value(@patient, "current_weight")
          current_height = PatientService.get_patient_attribute_value(@patient, "current_height")
          currentBmi = (current_weight/(current_height * current_height)*10000).round(1) rescue 0
          @current_bmi = currentBmi

					if currentBmi >= 16.0 && currentBmi <= 18.5
						@moderate_wasting = ["Moderate weight loss less than or equal to 10 percent, unexplained"]
						@severe_wasting = []
					elsif currentBmi < 16
						@severe_wasting = ["Severe weight loss >10% and/or BMI <18.5kg/m^2, unexplained"]
						@moderate_wasting = []
					end
				end


        #raise "moderate_wasting: #{@moderate_wasting.inspect}   severe_wasting:#{@severe_wasting}"

        @who_stage_iv_paeds = [
          ["Pneumocystis pneumonia", "Pneumocystis pneumonia"],
          ["Candidiasis of oseophagus, trachea and bronchi or lungs", "Candidiasis of oseophagus, trachea and bronchi or lungs"],
          ["Extrapulmonary tuberculosis (EPTB)", "Extrapulmonary tuberculosis (EPTB)"],
          ["Kaposis sarcoma", "Kaposis sarcoma"],
          ["HIV encephalopathy", "HIV encephalopathy"],
          ["Cryptococcal meningitis or other extrapulmonary cryptococcosis", "Cryptococcal meningitis or other extrapulmonary cryptococcosis"],
          ["Disseminated non-tuberculosis mycobacterial infection", "Disseminated non-tuberculosis mycobacterial infection"],
          ["Cryptosporidiosis, chronic with diarroea", "Cryptosporidiosis, chronic with diarroea"],
          ["Isosporiasis >1 month", "Isosporiasis >1 month"],
          ["Disseminated mycosis (coccidiomycosis or histoplasmosis)", "Disseminated mycosis (coccidiomycosis or histoplasmosis)"],
          ["Symptomatic HIV-associated nephropathy or cardiomyopathy", "Symptomatic HIV-associated nephropathy or cardiomyopathy"],
          ["Progressive multifocal leukoencephalopathy", "Progressive multifocal leukoencephalopathy"],
          ["Cerebral or B-cell non Hodgkin lymphoma", "Cerebral or B-cell non Hodgkin lymphoma"],
          ["Severe unexplained wasting or malnutrition not responding to treatment (weight-for-height/ -age <70% or MUAC less than 11cm or oedema)", "Severe unexplained wasting or malnutrition not responding to treatment (weight-for-height/ -age <70% or MUAC less than 11cm or oedema)"],
          ["Bacterial infections, severe recurrent  (empyema, pyomyositis, meningitis, bone/joint infections but EXCLUDING pneumonia)", "Bacterial infections, severe recurrent  (empyema, pyomyositis, meningitis, bone/joint infections but EXCLUDING pneumonia)"],
          ["Chronic herpes simplex infection (orolabial or cutaneous >1 month or visceral at any site)", "Chronic herpes simplex infection (orolabial or cutaneous >1 month or visceral at any site)"],
          ["Cytomegalovirus infection: rentinitis or other organ (from age 1 month)", "Cytomegalovirus infection: rentinitis or other organ (from age 1 month)"],
          ["Toxoplasmosis of the brain (from age 1 month)", "Toxoplasmosis of the brain (from age 1 month)"],
          ["Recto-vaginal fistula, HIV-associated", "Recto-vaginal fistula, HIV-associated"]
        ]

        @who_stage_iii_paeds = [
          ["Fever, persistent unexplained, intermittent or constant, >1 month", "Fever, persistent unexplained, intermittent or constant, >1 month"],
          ["Oral hairy leukoplakia", "Oral hairy leukoplakia"],
          ["Pulmonary tuberculosis (current)", "Pulmonary tuberculosis (current)"],
          ["Tuberculosis (PTB or EPTB) within the last 2 years", "Tuberculosis (PTB or EPTB) within the last 2 years"],
          ["Anaemia, unexplained < 8 g/dl", "Anaemia, unexplained < 8 g/dl"],
          ["Neutropaenia, unexplained < 500 /mm(cubed)", "Neutropaenia, unexplained < 500 /mm(cubed)"],
          ["Thrombocytopaenia, chronic < 50,000 /mm(cubed)", "Thrombocytopaenia, chronic < 50,000 /mm(cubed)"],
          ["Moderate unexplained wasting/malnutrition not responding to treatment (weight-for-height/ -age 70-79% or muac 11-12 cm)", "Moderate unexplained wasting/malnutrition not responding to treatment (weight-for-height/ -age 70-79% or muac 11-12 cm)"], ["Diarrhoea, persistent unexplained (14 days or more)", "Diarrhoea, persistent unexplained (14 days or more)"], ["Oral candidiasis (from age 2 months)", "Oral candidiasis (from age 2 months)"], ["Acute necrotizing ulcerative gingivitis or periodontitis", "Acute necrotizing ulcerative gingivitis or periodontitis"], ["Lymph node tuberculosis", "Lymph node tuberculosis"], ["Bacterial pneumonia, severe recurrent", "Bacterial pneumonia, severe recurrent"], ["Symptomatic lymphoid interstitial pneumonia", "Symptomatic lymphoid interstitial pneumonia"], ["Chronic HIV-associated lung disease, including bronchiectasis", "Chronic HIV-associated lung disease, including bronchiectasis"]
        ]

        @who_stage_ii_paeds = [
          ["Respiratory tract infections, recurrent (sinusitis, tonsilitus, otitis media, pharyngitis)", "Respiratory tract infections, recurrent (sinusitis, tonsilitus, otitis media, pharyngitis)"],
          ["Herpes zoster", "Herpes zoster"],
          ["Angular cheilitis", "Angular cheilitis"],
          ["Oral ulcerations, recurrent", "Oral ulcerations, recurrent"],
          ["Papular pruritic eruptions / Fungal nail infections", "Papular pruritic eruptions / Fungal nail infections"],
          ["Hepatosplenomegaly, persistent unexplained", "Hepatosplenomegaly, persistent unexplained"],
          ["Lineal gingival erythema", "Lineal gingival erythema"],
          ["Wart virus infection, extensive", "Wart virus infection, extensive"],
          ["Molluscum contagiosum, extensive", "Molluscum contagiosum, extensive"],
          ["Parotid enlargement, persistent unexplained", "Parotid enlargement, persistent unexplained"]
        ]

        @who_stage_i_paeds = [
          ["Asymptomatic HIV infection", "Asymptomatic HIV infection"],
          ["Persistent generalized lymphadenopathy", "Persistent generalized lymphadenopathy"]
        ]

        @who_stage_i = [
          ["Asymptomatic HIV infection", "Asymptomatic HIV infection"],
          ["Persistent generalized lymphadenopathy", "Persistent generalized lymphadenopathy"]
        ]

        @who_stage_ii = [
          ["Moderate weight loss less than or equal to 10 percent, unexplained", "Moderate weight loss less than or equal to 10 percent, unexplained"],
          ["Respiratory tract infections, recurrent (sinusitis, tonsilitus, otitis media, pharyngitis)", "Respiratory tract infections, recurrent (sinusitis, tonsilitus, otitis media, pharyngitis)"],
          ["Seborrhoeic dermatitis", "Seborrhoeic dermatitis"],
          ["Papular pruritic eruptions / Fungal nail infections", "Papular pruritic eruptions / Fungal nail infections"],
          ["Herpes zoster", "Herpes zoster"],
          ["Angular cheilitis", "Angular cheilitis"],
          ["Oral ulcerations, recurrent", "Oral ulcerations, recurrent"],
          ["Unspecified stage 2 condition","Unspecified stage 2 condition"]
        ]
        

        @who_stage_iii = [
          ["Severe weight loss >10% and/or BMI <18.5kg/m^2, unexplained", "Severe weight loss >10% and/or BMI <18.5kg/m^2, unexplained"],
          ["Diarrhoea, chronic (>1 month) unexplained", "Diarrhoea, chronic (>1 month) unexplained"],
          ["Fever, persistent unexplained, intermittent or constant, >1 month", "Fever, persistent unexplained, intermittent or constant, >1 month"],
          ["Pulmonary tuberculosis (current)", "Pulmonary tuberculosis (current)"],
          ["Tuberculosis (PTB or EPTB) within the last 2 years", "Tuberculosis (PTB or EPTB) within the last 2 years"],
          ["Oral candidiasis", "Oral candidiasis"],
          ["Acute necrotizing ulcerative stomatitis, gingivitis or periodontitis", "Acute necrotizing ulcerative stomatitis, gingivitis or periodontitis"],
          ["Anaemia, unexplained < 8 g/dl", "Anaemia, unexplained < 8 g/dl"],
          ["Neutropaenia, unexplained < 500 /mm(cubed)", "Neutropaenia, unexplained < 500 /mm(cubed)"],
          ["Severe bacterial infections (pneumonia, empyema, pyomyositis, bone/joint, meningitis, bacteraemia)", "Severe bacterial infections (pneumonia, empyema, pyomyositis, bone/joint, meningitis, bacteraemia)"],
          ["Thrombocytopaenia, chronic < 50,000 /mm(cubed)", "Thrombocytopaenia, chronic < 50,000 /mm(cubed)"],
          ["Hepatitis B or C infection", "Hepatitis B or C infection"],
          ["Oral hairy leukoplakia", "Oral hairy leukoplakia"],
          ["Unspecified stage 3 condition", "Unspecified stage 3 condition"]
          
        ]

        @who_stage_iv = [
          ["Cryptococcal meningitis or other extrapulmonary cryptococcosis", "Cryptococcal meningitis or other extrapulmonary cryptococcosis"],
          ["Candidiasis of oseophagus, trachea and bronchi or lungs", "Candidiasis of oseophagus, trachea and bronchi or lungs"],
          ["Extrapulmonary tuberculosis (EPTB)", "Extrapulmonary tuberculosis (EPTB)"],
          ["Kaposis sarcoma", "Kaposis sarcoma"],
          ["Bacterial pneumonia, severe recurrent", "Bacterial pneumonia, severe recurrent"],
          ["Non-typhoidal Salmonella bacteraemia, recurrent", "Non-typhoidal Salmonella bacteraemia, recurrent"],
          ["Symptomatic HIV-associated nephropathy or cardiomyopathy", "Symptomatic HIV-associated nephropathy or cardiomyopathy"],
          ["Cerebral or B-cell non Hodgkin lymphoma", "Cerebral or B-cell non Hodgkin lymphoma"],
          ["Pneumocystis pneumonia", "Pneumocystis pneumonia"],
          ["Chronic herpes simplex infection (orolabial, gential / anorectal >1 month or visceral at any site)", "Chronic herpes simplex infection (orolabial, gential / anorectal >1 month or visceral at any site)"],
          ["Cytomegalovirus infection (retinitis or infection or other organs)", "Cytomegalovirus infection (retinitis or infection or other organs)"],
          ["Toxoplasmosis of the brain", "Toxoplasmosis of the brain"],
          ["Invasive cancer of cervix", "Invasive cancer of cervix"],
          ["Unspecified stage 4 condition", "Unspecified stage 4 condition"],
          ["Other", "Other"]
        ]
        #@who_stage_iv.delete_if{|stage_condition|who_stage_iv_to_be_removed.include?(stage_condition[0])} << ["Other", "Other"]
        
				reason_for_art = @patient.person.observations.recent(1).question("REASON FOR ART ELIGIBILITY").all rescue []
        @reason_for_art_eligibility = PatientService.reason_for_art_eligibility(@patient)
				if !@reason_for_art_eligibility.nil? && @reason_for_art_eligibility.upcase == 'NONE'
					@reason_for_art_eligibility = nil				
				end
			end
			
			if @tb_status == true && @hiv_status != 'Negative'
        tb_hiv_exclusions = [['Pulmonary tuberculosis (current)', 'Pulmonary tuberculosis (current)'],
					['Tuberculosis (PTB or EPTB) within the last 2 years', 'Tuberculosis (PTB or EPTB) within the last 2 years']]
				#@who_stage_iii = @who_stage_iii - tb_hiv_exclusions
			end

  			
			@confirmatory_hiv_test_type = @patient.person.observations.question("CONFIRMATORY HIV TEST TYPE").last.answer_concept_name.name rescue 'UNKNOWN'
		end

		@avilable_status = ''
		@avilable_status = PatientService.patient_tb_status(@patient).upcase if PatientService.patient_tb_status(@patient).upcase == ('CONFIRMED TB NOT ON TREATMENT' || 'CONFIRMED TB ON TREATMENT')

		@arv_drugs = nil

		if (params[:encounter_type].upcase rescue '') == 'HIV_CLINIC_REGISTRATION' || (params[:encounter_type].upcase rescue '') == 'HIV_CLINIC_CONSULTATION'
			other = []

=begin
			use_regimen_short_names = CoreService.get_global_property_value("use_regimen_short_names") rescue "false"
			show_other_regimen = ("show_other_regimen") rescue 'false'

			@answer_array = arv_regimen_answers(:patient => @patient,
				:use_short_names    => use_regimen_short_names == "true",
				:show_other_regimen => show_other_regimen      == "true")

			hiv_program = Program.find_by_name('HIV Program')
			current_weight = PatientService.get_patient_attribute_value(@patient, "current_weight")
			@answer_array = MedicationService.regimen_options(current_weight, hiv_program)
			@answer_array += [['Other', 'Other'], ['Unknown', 'Unknown']]
=end
			

			@arv_drugs = MedicationService.arv_drugs.collect { | drug | 
				if (CoreService.get_global_property_value('use_regimen_short_names').to_s == "true" rescue false)					
					other << [drug.concept.shortname, drug.concept.shortname] if (drug.concept.shortname.upcase.include?('OTHER') || drug.concept.shortname.upcase.include?('UNKNOWN'))
					[drug.concept.shortname, drug.concept.shortname] 
				else
					other << [drug.concept.fullname, drug.concept.fullname] if (drug.concept.fullname.upcase.include?('OTHER') || drug.concept.fullname.upcase.include?('UKNOWN'))
					[drug.concept.fullname, drug.concept.fullname]
				end
			}
			@arv_drugs = @arv_drugs - other
			@arv_drugs = @arv_drugs.sort {|a,b| a.to_s.downcase <=> b.to_s.downcase}
			@arv_drugs = @arv_drugs + other

      @arv_drugs = MedicationService.moh_arv_regimen_options(100) + [["Other", "Other"]]
      @regimen_formulations = MedicationService.regimen_formulations
      @other_medications = Drug.find(:all,:joins =>"INNER JOIN moh_regimen_ingredient i
      ON i.drug_inventory_id = drug.drug_id", :select => "drug.*, i.*",
        :group => 'drug.drug_id').collect{|d|[d.name, d.concept.fullname]}.sort_by{|k, v|k}
			@require_hiv_clinic_registration = require_hiv_clinic_registration
		end

    ######>>########## CERVICAL CANCER SCREENING##############################
    if cervical_cancer_screening_activated
      @via_referred = false
      @has_via_results = false
      @remaining_days = 0
      @terminal = false
      @lesion_size_too_big = false
      @cervical_cancer_first_visit_patient = true
      @no_cancer = false
      @patient_went_for_via = false
      @cryo_delayed = false
      ##### patient went for via logic START ################


      ##### patient went for via logic END###################
      terminal_referral_outcomes = ["PRE/CANCER TREATED", "CANCER UNTREATABLE"]
    
      cervical_cancer_screening_encounter_type_id = EncounterType.find_by_name("CERVICAL CANCER SCREENING").encounter_type_id

      via_referral_concept_id = Concept.find_by_name("VIA REFERRAL").concept_id
    
      via_results_concept_id  = Concept.find_by_name("VIA Results").concept_id

      cryo_done_date_concept_id = Concept.find_by_name("CRYO DONE DATE").concept_id

      via_referral_outcome_concept_id = Concept.find_by_name("VIA REFERRAL OUTCOME").concept_id

      positive_cryo_concept_id  = Concept.find_by_name("POSITIVE CRYO").concept_id

      patient_went_for_via_concept_id  = Concept.find_by_name("PATIENT WENT FOR VIA?").concept_id

      yes_concept_id = Concept.find_by_name('YES').concept_id

      latest_patient_went_for_via_obs = Observation.find(:last, :joins => [:encounter],
        :conditions => ["person_id =? AND encounter_type =? AND concept_id =?",
          @patient.id, cervical_cancer_screening_encounter_type_id, patient_went_for_via_concept_id]
      ).answer_string.squish.upcase rescue nil

      @patient_went_for_via = true if latest_patient_went_for_via_obs == 'YES'

      via_referral_answer_string = Observation.find(:last, :joins => [:encounter],
        :conditions => ["person_id =? AND encounter_type =? AND concept_id =?",
          @patient.id, cervical_cancer_screening_encounter_type_id, via_referral_concept_id]
      ).answer_string.squish.upcase rescue ""

      @todays_refferals_count = Observation.find(:all, :select => "DISTINCT(person_id)", 
        :conditions => ["DATE(obs_datetime) =? AND concept_id =? AND value_coded =?",
          session_date, via_referral_concept_id, yes_concept_id]).count

      daily_referral_limit_concept = "cervical.cancer.daily.referral.limit"
      @daily_referral_limit = GlobalProperty.find_by_property(daily_referral_limit_concept).property_value.to_i rescue 1000


      cervical_cancer_first_visit_question = @patient.person.observations.recent(1).question("EVER HAD VIA?")
      @cervical_cancer_first_visit_patient = false unless cervical_cancer_first_visit_question.blank?
      @via_referred = true if via_referral_answer_string == "YES"

      latest_via_results_obs_date = Observation.find(:last, :joins => [:encounter],
        :conditions => ["person_id =? AND encounter_type =? AND concept_id =?",
          @patient.id, cervical_cancer_screening_encounter_type_id, via_results_concept_id]
      ).obs_datetime.to_date rescue nil

      cervical_cancer_result_obs = Observation.find(:last, :joins => [:encounter],
        :conditions => ["person_id =? AND encounter_type =? AND concept_id =? AND DATE(obs_datetime) >= ?",
          @patient.id, cervical_cancer_screening_encounter_type_id, via_results_concept_id, latest_via_results_obs_date])

      via_referral_outcome_obs = Observation.find(:last, :joins => [:encounter],
        :conditions => ["person_id =? AND encounter_type =? AND concept_id =? AND DATE(obs_datetime) >= ?",
          @patient.id, cervical_cancer_screening_encounter_type_id, via_referral_outcome_concept_id, latest_via_results_obs_date])
      latest_via_referral_outcome = via_referral_outcome_obs.answer_string.squish.upcase rescue nil
      @latest_via_referral_outcome = latest_via_referral_outcome

      @has_via_results = true unless cervical_cancer_result_obs.blank?
    
      latest_cervical_cancer_result =  cervical_cancer_result_obs.answer_string.squish.upcase rescue nil
      @latest_cervical_cancer_result = latest_cervical_cancer_result

      three_years = 365 * 3
      one_year = 365

      ############################################################################
      latest_cryo_result = Observation.find(:last, :joins => [:encounter],
        :conditions => ["person_id =? AND encounter_type =? AND concept_id =? AND DATE(obs_datetime) >= ?",
          @patient.id, cervical_cancer_screening_encounter_type_id, positive_cryo_concept_id, latest_via_results_obs_date])

      unless latest_cryo_result.blank?
        cryo_result_answer = latest_cryo_result.answer_string.squish.upcase
        if cryo_result_answer == "CRYO DELAYED"
          @cryo_delayed = true
          @has_via_results = false
        end

        if cryo_result_answer == "LESION SIZE TOO BIG"
          @lesion_size_too_big = true
          obs_date = latest_cryo_result.obs_datetime.to_date
          date_gone_lesion_size_was_big = (Date.today - obs_date).to_i #Total days Between Two Dates

          if (date_gone_lesion_size_was_big >= three_years)
            @lesion_size_too_big = false
          end
        end
        
      end

      ############################################################################


      unless latest_cervical_cancer_result.blank?
        
        obs_date = cervical_cancer_result_obs.obs_datetime.to_date
        date_gone_in_days = (Date.today - obs_date).to_i #Total days Between Two Dates
        if latest_cervical_cancer_result == 'NEGATIVE'
          next_via_date = obs_date + three_years.days
          @remaining_days = three_years - date_gone_in_days
          if date_gone_in_days >= three_years
            @via_referred = false
            @has_via_results = false
            next_via_referral_obs = Observation.find(:last, :joins => [:encounter],
              :conditions => ["person_id =? AND encounter_type =? AND concept_id =? AND DATE(obs_datetime) >= ?",
                @patient.id, cervical_cancer_screening_encounter_type_id, via_referral_concept_id, next_via_date])
            unless next_via_referral_obs.blank?
              if (next_via_referral_obs.answer_string.squish.upcase == 'YES')
                @via_referred = true
              end
            end

            next_cervical_cancer_result_obs = Observation.find(:last, :joins => [:encounter],
              :conditions => ["person_id =? AND encounter_type =? AND concept_id =? AND DATE(obs_datetime) >= ?",
                @patient.id, cervical_cancer_screening_encounter_type_id, via_results_concept_id, next_via_date])
            @has_via_results = true unless next_cervical_cancer_result_obs.blank?
          end
        end
      
        cryo_done_cancer_result_obs = Observation.find(:last, :joins => [:encounter],
          :conditions => ["person_id =? AND encounter_type =? AND concept_id =? AND DATE(obs_datetime) >= ?",
            @patient.id, cervical_cancer_screening_encounter_type_id, cryo_done_date_concept_id,
            latest_via_results_obs_date])
    
        unless cryo_done_cancer_result_obs.blank?
          cryo_done_date = cryo_done_cancer_result_obs.answer_string.squish.to_date
          next_via_date = cryo_done_date + one_year.days
          date_gone_after_cryo_is_done = (Date.today - cryo_done_date).to_i #Total days Between Two Dates
          @remaining_days = one_year - date_gone_after_cryo_is_done
          if (date_gone_after_cryo_is_done >= one_year)
            @via_referred = false
            @has_via_results = false
            next_via_referral_obs = Observation.find(:last, :joins => [:encounter],
              :conditions => ["person_id =? AND encounter_type =? AND concept_id =? AND DATE(obs_datetime) >= ?",
                @patient.id, cervical_cancer_screening_encounter_type_id, via_referral_concept_id, next_via_date])
            unless next_via_referral_obs.blank?
              if (next_via_referral_obs.answer_string.squish.upcase == 'YES')
                @via_referred = true
              end
            end

            next_cervical_cancer_result_obs = Observation.find(:last, :joins => [:encounter],
              :conditions => ["person_id =? AND encounter_type =? AND concept_id =? AND DATE(obs_datetime) >= ?",
                @patient.id, cervical_cancer_screening_encounter_type_id, via_results_concept_id, next_via_date])
            @has_via_results = true unless next_cervical_cancer_result_obs.blank?
          end
        end

        unless latest_via_referral_outcome.blank?
          if latest_via_referral_outcome == 'NO CANCER'
            via_referral_outcome_obs_date = via_referral_outcome_obs.obs_datetime.to_date
            next_via_date = via_referral_outcome_obs_date + three_years.days
            date_gone_after_referral_outcome_is_done = (Date.today - via_referral_outcome_obs_date).to_i #Total days Between Two Dates
            @remaining_days = three_years - date_gone_after_referral_outcome_is_done
            @no_cancer = true
            @lesion_size_too_big = false
            
            if (date_gone_after_referral_outcome_is_done >= three_years)
              @via_referred = false
              @has_via_results = false
              @no_cancer = false

              next_via_referral_obs = Observation.find(:last, :joins => [:encounter],
                :conditions => ["person_id =? AND encounter_type =? AND concept_id =? AND DATE(obs_datetime) >= ?",
                  @patient.id, cervical_cancer_screening_encounter_type_id, via_referral_concept_id, next_via_date])
              unless next_via_referral_obs.blank?
                if (next_via_referral_obs.answer_string.squish.upcase == 'YES')
                  @via_referred = true
                end
              end

              next_cervical_cancer_result_obs = Observation.find(:last, :joins => [:encounter],
                :conditions => ["person_id =? AND encounter_type =? AND concept_id =? AND DATE(obs_datetime) >= ?",
                  @patient.id, cervical_cancer_screening_encounter_type_id, via_results_concept_id, next_via_date])
              unless next_cervical_cancer_result_obs.blank?
                @has_via_results = true
              end
            end
          end
        end



      end

      #>>>>>>>>>VIA DONE LOGIC>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
      @via_results_expired = true

      via_done_date_answer_string = @patient.person.observations.recent(1).question("VIA DONE DATE").last.answer_string.squish.to_date rescue nil
      unless via_done_date_answer_string.blank?
        #@cervical_cancer_first_visit_patient = false
        days_gone_after_via_done = (Date.today - via_done_date_answer_string).to_i #Total days Between Two Dates
        if (days_gone_after_via_done < three_years)
          @via_referred = true
          @via_results_expired = false
          @remaining_days = three_years - days_gone_after_via_done
        end
      end

      #>>>>>>>>VIA LOGIC END>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
      via_referral_outcome_answers = Observation.find(:all, :joins => [:encounter],
        :conditions => ["person_id =? AND encounter_type =? AND concept_id =?",
          @patient.id, cervical_cancer_screening_encounter_type_id, via_referral_outcome_concept_id]
      ).collect{|o|o.answer_string.squish.upcase}
    
      via_referral_outcome_answers.each do |outcome|
        if terminal_referral_outcomes.include?(outcome)
          @lesion_size_too_big = false
          @terminal = true
          break
        end
      end
    end

    ###########################################################################



    ################################# if vitals ##########################################
    if params[:encounter_type].upcase == "VITALS"
      birth_date = @patient.person.birthdate.to_date
      age_in_months = (session_date.year * 12 + session_date.month) - (birth_date.year * 12 + birth_date.month)
      sex = @patient_bean.sex == 'Male' ? 0 : 1
      #age_in_months = @patient_bean.age_in_months
      if @patient_bean.age < 5
        @weight_height_for_ages = {}
        age_in_months += 5 if age_in_months < 53
        weight_heights = WeightHeightForAge.find(:all, 
          :conditions => ["sex = ? AND age_in_months BETWEEN 0 AND ?", sex, age_in_months])
        (weight_heights || []).each do |data|

          m = data.median_weight.to_f
          l = data.standard_low_weight.to_f
          h = data.standard_high_weight.to_f
          
          @weight_height_for_ages[data.age_in_months] = {
            :median_weight => m.round(2) ,
            :standard_low_weight => (m - l).round(2),
            :standard_high_weight => (m + h).round(2)
          }
        end

      end

    end
    ######################################################################################


=begin
    ################################# if hiv clinic consultation ##########################################
    if params[:encounter_type].upcase == "HIV_CLINIC_CONSULTATION"
      session_date = (session[:datetime].to_date rescue Date.today).strftime('%Y-%m-%d 23:59:59')
      vitals = VitalsService.weight_trail(@patient, session_date)
      @weight_trail           = vitals['weight_trail']
      @weight_height_for_age  = vitals['weight_height_for_age']

      #raise @weight_height_for_age[1].keys.sort.inspect
    end
    ######################################################################################
=end


		if PatientIdentifier.site_prefix == "MPC"
      prefix = "LL-TB"
		else
      prefix = "#{PatientIdentifier.site_prefix}-TB"
		end
		@tb_auto_number = create_tb_number(PatientIdentifierType.find_by_name('District TB Number').id, prefix)

		if params["staging_conditions"] == "YES"
			@obs = params["observations"]
			render :template => 'encounters/normal_staging_summary', :layout => "normal_staging" and return
		end
		
		redirect_to "/" and return unless @patient

		redirect_to next_task(@patient) and return unless params[:encounter_type]

		redirect_to :action => :create, 'encounter[encounter_type_name]' => params[:encounter_type].upcase, 'encounter[patient_id]' => @patient.id and return if ['registration'].include?(params[:encounter_type])
		
		#if (params[:encounter_type].upcase rescue '') == 'VITALS'
      
    # render :action => params[:encounter_type], :layout => "weight_chart"

    if (params[:encounter_type].upcase rescue '') == 'HIV_STAGING' and  (CoreService.get_global_property_value('use.extended.staging.questions').to_s == "true" rescue false)
      if session[:datetime].blank?
			  render :template => 'encounters/extended_hiv_staging', :layout => "weight_chart"
      else
        render :action => params[:encounter_type], :layout => "weight_chart" if params[:encounter_type]
      end
      #elsif (params[:encounter_type].upcase rescue '') == 'HIV_STAGING' and  (CoreService.get_global_property_value('use.normal.staging.questions').to_s == "true" rescue false)
      #	render :template => 'encounters/normal_hiv_staging'
		else
			render :action => params[:encounter_type], :layout => "weight_chart" if params[:encounter_type]
		end
		
	end

	def check_tb_number
    value = params[:value]
    if PatientIdentifier.site_prefix == "MPC"
      tb_identifier = value.to_i
      value = "LL-TB  #{session[:datetime].to_date.strftime('%Y')} #{tb_identifier}" rescue  "LL-TB #{Date.today.strftime('%Y')} #{tb_identifier}"
    else
      tb_identifier = value.to_i
      value = "#{PatientIdentifier.site_prefix}-TB #{session[:datetime].to_date.strftime('%Y')} #{tb_identifier}" rescue  "#{PatientIdentifier.site_prefix}-TB #{Date.today.strftime('%Y')} #{tb_identifier}"
    end

    render :text => ("false".to_json) if ! PatientIdentifier.find_by_identifier(value).blank?

    render :text => ("true".to_json) if  PatientIdentifier.find_by_identifier(value).blank?
	end
	def tb_art_patient(patient,program)
    program_id = Program.find_by_name(program).id
    enrolled = PatientProgram.find(:first,:conditions =>["program_id = ? AND patient_id = ?",program_id,patient.id]).blank?
 

		return true if enrolled
    false
  end

  def select_options
    select_options = {
      'reason_for_tb_clinic_visit' => [
        ['',''],
        ['Clinical review (Children, Smear-, HIV+)','CLINICAL REVIEW'],
        ['Smear Positive (HIV-)','SMEAR POSITIVE'],
        ['X-ray result interpretation','X-RAY RESULT INTERPRETATION']
      ],
			'tb_investigation' =>[
				['',''],
				['Sputum Test','TB sputum test'],
				['X-Ray','X-Ray'],
        ['GeneXpert','GeneXpert'],
				['None','None']
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
        #['IUD-Intrauterine device/loop', 'INTRAUTERINE CONTRACEPTION'],
        ['Intrauterine device/loop', 'INTRAUTERINE CONTRACEPTION'],
        #['Contraceptive implant', 'CONTRACEPTIVE IMPLANT'],
        ['Implant', 'CONTRACEPTIVE IMPLANT'],
        ['Male condoms', 'MALE CONDOMS'],
        ['Female condoms', 'FEMALE CONDOMS'],
        ['Tubal ligation', 'TUBAL LIGATION'],
        ['None of the above', 'NONE'],
        #['Rhythm method', 'RYTHM METHOD'],
        #['Withdrawal method', 'WITHDRAWAL METHOD'],
        #['Abstinence', 'ABSTINENCE'],
        #['Vasectomy', 'VASECTOMY']
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
        "Sputum-AAFB" => ["AAFB(1st)", "AAFB(2nd)", "AAFB(3rd)"],
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
        # ["Meningitis", "Meningitis"],
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
        ['Pleural effusion', 'Pleural effusion'],
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
        # ['Multi-drug resistant (MDR)', 'Multi-drug resistant tuberculosis'],
        ['Extensive drug resistant (XDR)', 'Extensive drug resistant tuberculosis']
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

	def is_holiday(suggest_date, holidays)
		holiday = false;
		holidays.each do |h|
			if (h.to_date.strftime('%B %d') == suggest_date.strftime('%B %d'))
				holiday = true;
			end
		end
		return holiday
	end

	def return_original_suggested_date(suggested_date, booked_dates)
		suggest_original_date = nil
		#second_biggest_date_available = nil

		booked_dates.each do |booked_date|
			sdate = booked_date.to_s.split(":")[0].to_date

			if(sdate.to_date >= suggested_date.to_date)
				#second_biggest_date_available = suggested_date
				suggest_original_date = sdate
				suggested_date = sdate
			end
		end if booked_dates.to_s.size > 0

		@massage="All available days this calender week are fully booked"

		return suggest_original_date
	end

	def is_below_limit(recommended_date, bookings)
		clinic_appointment_limit = CoreService.get_global_property_value('clinic.appointment.limit').to_i rescue 0
		clinic_appointment_limit = 0 if clinic_appointment_limit.blank?
		within_limit = true
	
		if (bookings.blank? || clinic_appointment_limit <= 0)
			within_limit = true;
		else
			recommended_date_limit = bookings[recommended_date] rescue 0

			if (recommended_date_limit >= clinic_appointment_limit)
				within_limit = false
			end
		end

		return within_limit
	end

	def suggested_date(expiry_date, holidays, bookings, clinic_days)
    bookings.delete_if{|bd| holidays.collect{|h|h.to_date.to_s[5..-1]}.include?(bd.to_s[5..-1])}
    recommended_date = nil                                                      
    clinic_appointment_limit = CoreService.get_global_property_value('clinic.appointment.limit').to_i rescue 0

    @encounter_type = EncounterType.find_by_name('APPOINTMENT')                  
    @concept_id = ConceptName.find_by_name('APPOINTMENT DATE').concept_id        
          
    number_of_bookings = {}

    (bookings || []).sort.reverse.each do |date|
      next if not clinic_days.collect{|c|c.upcase}.include?(date.strftime('%A').upcase)
      limit = number_of_booked_patients(date.to_date).to_i rescue 0
      if clinic_appointment_limit == 0
        recommended_date = date
        break
      end
      if limit < clinic_appointment_limit
        recommended_date = date
        break
      else
        number_of_bookings[date] = limit
      end
    end
                                                                 
    
    (number_of_bookings || {}).sort_by { |dates,num| num }.each do |dates , num|   
      next if not clinic_days.collect{|c|c.upcase}.include?(dates.strftime('%A').upcase)
      recommended_date = dates
      break 
    end if recommended_date.blank?                                                                        

    recommended_date = expiry_date if recommended_date.blank?
    return recommended_date
	end

  def assign_close_to_expire_date(set_date,auto_expire_date)
    if (set_date < auto_expire_date)
      while (set_date < auto_expire_date)
        set_date = set_date + 1.day
      end
      #Give the patient a 2 day buffer*/
      set_date = set_date - 1.day
    end
    return set_date
  end

	def suggest_appointment_date(max_date)
		#for now we disable this because we are already checking for this
		#in the browser - the method is suggested_return_date
		#@number_of_days_to_add_to_next_appointment_date = number_of_days_to_add_to_next_appointment_date(@patient, session[:datetime] || Date.today)

=begin
		dispensed_date = session[:datetime].to_date rescue Date.today
		expiry_date = prescription_expiry_date(@patient, dispensed_date, max_date)
		return revised_suggested_date(expiry_date)
=end
		return revised_suggested_date(max_date)
	end

  def revised_suggested_date(expiry_date)
    clinic_appointment_limit = CoreService.get_global_property_value('clinic.appointment.limit').to_i 
    clinic_appointment_limit = 200 if clinic_appointment_limit < 1

    peads_clinic_days = CoreService.get_global_property_value('peads.clinic.days')
    if (@patient_bean.age <= 14 && !peads_clinic_days.blank?)
      clinic_days = peads_clinic_days
    else
      clinic_days = CoreService.get_global_property_value('clinic.days') || 'Monday,Tuesday,Wednesday,Thursday,Friday'
    end
    clinic_days = clinic_days.split(',')


    clinic_holidays = CoreService.get_global_property_value('clinic.holidays')
    clinic_holidays = clinic_holidays.split(',').map{|day|day.to_date.strftime('%d %B')}.join(',').split(',') rescue []

    recommended_date = expiry_date.to_date;

=begin
    amounts_dispensed = Observation.first(:conditions => ['concept_id = ? AND order_id = ? 
      AND encounter_id = ?', ConceptName.find_by_name("AMOUNT DISPENSED").concept_id, 
      order.order_id, EncounterType.find_by_name('TREATMENT').id]).value_numeric.to_f rescue nil 
=end

    expiry_date -= 2.day


    start_date = (expiry_date - 5.day).strftime('%Y-%m-%d 00:00:00')
    end_date = expiry_date.strftime('%Y-%m-%d 23:59:59')

    encounter_type = EncounterType.find_by_name('APPOINTMENT')
    concept_id = ConceptName.find_by_name('APPOINTMENT DATE').concept_id

    appointments = {} ; sdate = (end_date.to_date + 1.day)
    1.upto(4).each do |num|
      appointments[(sdate - num.day)] = 0
    end
    
    Observation.find_by_sql("SELECT value_datetime appointment_date, count(value_datetime) AS count FROM obs
      INNER JOIN encounter e USING(encounter_id) WHERE concept_id = #{concept_id}
      AND encounter_type = #{encounter_type.id} AND value_datetime BETWEEN '#{start_date}'
      AND '#{end_date}' AND obs.voided = 0 GROUP BY value_datetime").each do |appointment|
      appointments[appointment.appointment_date.to_date] = appointment.count.to_i
    end

    (appointments || {}).sort_by {|x, y| x.to_date }.reverse.each do |date, count|
      next unless clinic_days.include?(date.to_date.strftime('%A'))
      next unless clinic_holidays.include?(date.to_date.strftime('%d %B')).blank?

      if count < clinic_appointment_limit
        return date
      end
    end

=begin
    the following block of code will only run if the recommended date is full
    Its a hack, we need to find a better way of cleaning up the code but it works :)
=end
    (appointments || {}).sort_by {|x, y| y.to_i }.each do |date, count|
      next unless clinic_days.include?(date.to_date.strftime('%A'))
      next unless clinic_holidays.include?(date.to_date.strftime('%d %B')).blank?

      recommended_date = date
      break
    end

    return recommended_date
  end
	
	def prescription_expiry_date(patient, dispensed_date, max_date)
    session_date = dispensed_date.to_date
        
    #get all drug dispensed on set clinic day
    medication = MedicationService.drugs_given_on(patient, session_date)
    return session_date if medication.blank?

    #==========================================get the min auto_expire_date 
    medication_order_ids = []
    (medication || []).each do |order|
      next unless MedicationService.arv(order.drug_order.drug)
      medication_order_ids << order.id
    end


    ############################################# a hack if no ARV are dispensed #############################################
    if medication_order_ids.blank?
      (medication || []).each do |order|
        medication_order_ids << order.id
      end
      medication_order_ids = [0] if medication_order_ids.blank?
      smallest_expire_date_attr = ActiveRecord::Base.connection.select_one <<EOF
      SELECT MIN(auto_expire_date) AS auto_expire_date FROM orders 
      WHERE order_id IN(#{medication_order_ids.uniq.join(',')})
EOF

      return (smallest_expire_date_attr['auto_expire_date'].to_date - 2.day) rescue session_date
    end
    ############################################# a hack if no ARV are dispensed ends ########################################



    smallest_expire_date_attr = ActiveRecord::Base.connection.select_one <<EOF
    SELECT MIN(auto_expire_date) AS auto_expire_date FROM orders 
    WHERE order_id IN(#{medication_order_ids.join(',')})
EOF

    #We get the smallest_expire_date but we also give the patient a 2 day buffer
    smallest_expire_date = (smallest_expire_date_attr['auto_expire_date'].to_date - 2.day)
    #==========================================get the min auto_expire_date end

    #suggested return dates
    suggest_appointment_dates = []
    

    ######################################## If the user selected "Optimize appointment" #######################
=begin    
    appointment_type = PatientService.appointment_type(patient, session_date)
    if(appointment_type.value_text == 'Optimize - including hanging pills')    
      amounts_brought_to_clinic = MedicationService.amounts_brought_to_clinic(patient, session_date.to_date)

      (medication || []).each do |order|
        amounts_brought_to_clinic.each do |drug_id, amounts_brought|
          if drug_id == order.drug_order.drug_inventory_id
            pills_per_day = MedicationService.get_medication_pills_per_day(order)
            brought_to_clinic = amounts_brought
            days = (brought_to_clinic.to_i/pills_per_day) if pills_per_day > 0
            unless days.blank?
              suggest_appointment_dates << (smallest_expire_date + days.day).to_date 
            else
              suggest_appointment_dates << smallest_expire_date
            end
          end
        end
      end unless amounts_brought_to_clinic.blank?
    end unless appointment_type.blank?
=end
    ##############################################################################################################

    unless suggest_appointment_dates.blank?
      suggest_appointment = (suggest_appointment_dates.sort.first).to_date 
    else
      suggest_appointment = (smallest_expire_date).to_date
    end

    if suggest_appointment > max_date
      return max_date
    else
      return suggest_appointment
    end

	end

  def recalculation_auto_expire_date(orders, auto_expire_date)
=begin
  This block of code is making sure we add the exact number of days in months by 
  using the Rails way of adding months to a given dat.
  So if for example the given auto_expire_date date is first of January 2016
  and the dispensed date is the 1st of January 2016 then, a month from the 
  first the date will be 1st of Febuary 2016 not 28th of January 
=end
    smallest_expire_date = nil
    (orders || []).each do |order|
      if smallest_expire_date.blank?
        smallest_expire_date = [order.start_date.to_date, order.auto_expire_date.to_date]
      else
        if smallest_expire_date.last > order.auto_expire_date.to_date
          smallest_expire_date = [order.start_date.to_date, order.auto_expire_date.to_date]
        end
      end
    end

    return auto_expire_date if smallest_expire_date.blank?
    exp_date = smallest_expire_date.last
    dispensed_date = smallest_expire_date.first

    duration = (exp_date - dispensed_date).to_i

    case duration
    when 28
      return (dispensed_date + 1.month)
    when 58
      return (dispensed_date + 2.month)
    when 86
      return (dispensed_date + 3.month)
    when 114
      return (dispensed_date + 4.month)
    when 142
      return (dispensed_date + 5.month)
    when 170
      return (dispensed_date + 6.month)
    when 198
      return (dispensed_date + 7.month)
    when 226
      return (dispensed_date + 8.month)
    else
      return auto_expire_date
    end

  end
  	
  def bookings_within_range(end_date = nil)
    clinic_days = GlobalProperty.find_by_property("clinic.days")
    clinic_days = clinic_days.property_value.split(',') rescue 'Monday,Tuesday,Wednesday,Thursday,Friday'.split(',')

    start_date = (end_date - 4.days)
    booked_dates = [end_date]
  
    (1.upto(4)).each do |num|
      booked_dates << (end_date - num.day)                               
    end
    
    clinic_holidays = CoreService.get_global_property_value('clinic.holidays')  
    clinic_holidays = clinic_holidays.split(',').map{|day|day.to_date}.join(',').split(',') rescue []
    return_booked_dates = []
  
    unless clinic_holidays.blank?
      (booked_dates || []).each do |date|
        next if is_holiday(date,clinic_holidays)
        return_booked_dates << date
      end
    else
      return_booked_dates = booked_dates
    end

    return return_booked_dates
  end

  def create_remote
    location = Location.find(params["location"]) rescue nil
    user = User.first rescue nil

    if !location.nil? and !user.nil?
      self.current_location = location
      User.current = user

      Location.current_location = location

      target = {
        :observations=>[],
        :encounter=>params["encounter"]
      }

      params["obs"].each{|k,v|
        target[:observations] << v
      }

      params = target
      if params[:change_appointment_date] == "true"
        session_date = session[:datetime].to_date rescue Date.today
        type = EncounterType.find_by_name("APPOINTMENT")
        appointment_encounter = Observation.find(:first,
          :order => "encounter_datetime DESC,encounter.date_created DESC",
          :joins => "INNER JOIN encounter ON obs.encounter_id = encounter.encounter_id",
          :conditions => ["concept_id = ? AND encounter_type = ? AND patient_id = ?
      AND encounter_datetime >= ? AND encounter_datetime <= ?",
            ConceptName.find_by_name('Appointment date').concept_id,
            type.id, params[:encounter]["patient_id"],session_date.strftime("%Y-%m-%d 00:00:00"),
            session_date.strftime("%Y-%m-%d 23:59:59")]).encounter
        appointment_encounter.void("Given a new appointment date")
      end

      if params[:encounter]['encounter_type_name'] == 'TB_INITIAL'
        (params[:observations] || []).each do |observation|
          if observation['concept_name'].upcase == 'TRANSFER IN' and observation['value_coded_or_text'] == "YES"
            params[:observations] << {"concept_name" => "TB STATUS","value_coded_or_text" => "Confirmed TB on treatment"}
          end
        end
      end

      if params[:encounter]['encounter_type_name'] == 'HIV_CLINIC_REGISTRATION'

        has_tranfer_letter = false
        (params[:observations]).each do |ob|
          if ob["concept_name"] == "HAS TRANSFER LETTER"
            has_tranfer_letter = (ob["value_coded_or_text"].upcase == "YES")
            break
          end
        end
        if params[:observations][0]['concept_name'].upcase == 'EVER RECEIVED ART' and params[:observations][0]['value_coded_or_text'].upcase == 'NO'
          observations = []
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
        elsif params[:observations][4]['concept_name'].upcase == 'DATE ART LAST TAKEN' and params[:observations][4]['value_datetime'] != 'Unknown'
          observations = []
          (params[:observations] || []).each do |observation|
            next if observation['concept_name'].upcase == 'HAS THE PATIENT TAKEN ART IN THE LAST TWO WEEKS'
            next if observation['concept_name'].upcase == 'HAS THE PATIENT TAKEN ART IN THE LAST TWO MONTHS'
            observations << observation
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
            (params[:observations]).each do |ob|
              if ob["concept_name"] == "BODY MASS INDEX, MEASURED"
                bmi = ob["value_numeric"]
                break
              end
            end
            next if bmi.blank?
            vitals_observations << observation
          elsif observation['concept_name'].upcase == 'WEIGHT (KG)'
            weight = 0
            (params[:observations]).each do |ob|
              if ob["concept_name"] == "WEIGHT (KG)"
                weight = ob["value_numeric"].to_f rescue 0
                break
              end
            end
            next if weight.blank? or weight < 1
            vitals_observations << observation
          elsif observation['concept_name'].upcase == 'HEIGHT (CM)'
            height = 0
            (params[:observations]).each do |ob|
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
            end
          end
        end
        unless vitals_observations.blank?
          encounter = Encounter.new()
          encounter.encounter_type = EncounterType.find_by_name("VITALS").id
          encounter.patient_id = params[:encounter]['patient_id']
          encounter.encounter_datetime = date_started_art
          if encounter.encounter_datetime.blank?
            encounter.encounter_datetime = params[:encounter]['encounter_datetime']
          end
          if params[:filter] and !params[:filter][:provider].blank?
            user_person_id = User.find_by_username(params[:filter][:provider]).person_id
          else
            user_person_id = User.find_by_user_id(params[:encounter]['provider_id']).person_id
          end
          encounter.provider_id = user_person_id
          encounter.save
          params[:observations] = vitals_observations
          create_obs(encounter , params)
        end

        unless observations.blank?
          encounter = Encounter.new()
          encounter.encounter_type = EncounterType.find_by_name("HIV STAGING").id
          encounter.patient_id = params[:encounter]['patient_id']
          encounter.encounter_datetime = date_started_art
          if encounter.encounter_datetime.blank?
            encounter.encounter_datetime = params[:encounter]['encounter_datetime']
          end
          if params[:filter] and !params[:filter][:provider].blank?
            user_person_id = User.find_by_username(params[:filter][:provider]).person_id
          else
            user_person_id = User.find_by_user_id(params[:encounter]['provider_id']).person_id
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
      end

      if params[:encounter]['encounter_type_name'].upcase == 'HIV STAGING'
        
        @allergic_to_sulphur = Patient.allergic_to_sulpher(@patient, session_date) #chunked

        observations = []
        (params[:observations] || []).each do |observation|
          if observation['concept_name'].upcase == 'CD4 COUNT' or observation['concept_name'].upcase == "LYMPHOCYTE COUNT"
            observation['value_modifier'] = observation['value_numeric'].match(/=|>|</i)[0] rescue nil
            observation['value_numeric'] = observation['value_numeric'].match(/[0-9](.*)/i)[0] rescue nil
          end
          if observation['concept_name'].upcase == 'CD4 COUNT LOCATION' or observation['concept_name'].upcase == 'LYMPHOCYTE COUNT LOCATION'
            observation['value_numeric'] = observation['value_coded_or_text'] rescue nil
            observation['value_text'] = Location.find(observation['value_coded_or_text']).name.to_s rescue ""
            observation['value_coded_or_text'] = ""
          end
          if observation['concept_name'].upcase == 'CD4 PERCENT LOCATION'
            observation['value_numeric'] = observation['value_coded_or_text'] rescue nil
            observation['value_text'] = Location.find(observation['value_coded_or_text']).name.to_s rescue ""
            observation['value_coded_or_text'] = ""
          end

          observations << observation
        end

        params[:observations] = observations unless observations.blank?
      end

      if params[:encounter]['encounter_type_name'].upcase == 'ART ADHERENCE'
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

        unless previous_hiv_clinic_consultation_observations.blank?
          #if "REFER TO ART CLINICIAN","PRESCRIBE DRUGS" and "ALLERGIC TO SULPHUR" has
          #already been asked during HIV CLINIC CONSULTATION - we append the observations to the latest
          #HIV CLINIC CONSULTATION encounter done on that day

          session_date = session[:datetime].to_date rescue Date.today
          encounter_type = EncounterType.find_by_name("HIV CLINIC CONSULTATION")
          encounter = Encounter.find(:first,:order =>"encounter_datetime DESC,date_created DESC",
            :conditions =>["encounter_type=? AND patient_id=? AND encounter_datetime >= ?
          AND encounter_datetime <= ?",encounter_type.id,params[:encounter]['patient_id'],
              session_date.strftime("%Y-%m-%d 00:00:00"),session_date.strftime("%Y-%m-%d 23:59:59")])
          if encounter.blank?
            encounter = Encounter.new()
            encounter.encounter_type = encounter_type.id
            encounter.patient_id = params[:encounter]['patient_id']
            encounter.encounter_datetime = session_date.strftime("%Y-%m-%d 00:00:01")
            if params[:filter] and !params[:filter][:provider].blank?
              user_person_id = User.find_by_username(params[:filter][:provider]).person_id
            else
              user_person_id = User.find_by_user_id(params[:encounter]['provider_id']).person_id
            end
            encounter.provider_id = user_person_id
            encounter.save
          end
          params[:observations] = previous_hiv_clinic_consultation_observations
          create_obs(encounter , params)
        end
        params[:observations] = art_adherence_observations

        observations = []
        (params[:observations] || []).each do |observation|
          if observation['concept_name'].upcase == 'WHAT WAS THE PATIENTS ADHERENCE FOR THIS DRUG ORDER'
            observation['value_numeric'] = observation['value_text'] rescue nil
            observation['value_text'] =  ""
          end

          if observation['concept_name'].upcase == 'MISSED HIV DRUG CONSTRUCT'
            observation['value_numeric'] = observation['value_coded_or_text'] rescue nil
            observation['value_coded_or_text'] = ""
          end
          observations << observation
        end
        params[:observations] = observations unless observations.blank?
      end

      if params[:encounter]['encounter_type_name'].upcase == 'REFER PATIENT OUT?'
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
      end

      @patient = Patient.find(params[:encounter][:patient_id]) rescue nil
      if params[:location]
        if @patient.nil?
          @patient = Patient.find_with_voided(params[:encounter][:patient_id])
        end

        Person.migrated_datetime = params[:encounter]['date_created']
        Person.migrated_creator  = params[:encounter]['creator'] rescue nil

        # set current location via params if given
        Location.current_location = Location.find(params[:location])
      end

      if params[:encounter]['encounter_type_name'].to_s.upcase == "APPOINTMENT" && !params[:report_url].nil? && !params[:report_url].match(/report/).nil?
        concept_id = ConceptName.find_by_name("RETURN VISIT DATE").concept_id
        encounter_id_s = Observation.find_by_sql("SELECT encounter_id
                       FROM obs
                       WHERE concept_id = #{concept_id} AND person_id = #{@patient.id}
                            AND DATE(value_datetime) = DATE('#{params[:old_appointment]}') AND voided = 0
          ").map{|obs| obs.encounter_id}.each do |encounter_id|
          Encounter.find(encounter_id).void
        end
      end

      # Encounter handling
      encounter = Encounter.new(params[:encounter])
      unless params[:location]
        encounter.encounter_datetime = session[:datetime] unless session[:datetime].blank?
      else
        encounter.encounter_datetime = params[:encounter]['encounter_datetime']
      end

      if params[:filter] and !params[:filter][:provider].blank?
        user_person_id = User.find_by_username(params[:filter][:provider]).person_id
      elsif params[:location] # Migration
        user_person_id = encounter[:provider_id]
      else
        user_person_id = User.find_by_user_id(encounter[:provider_id]).person_id
      end
      encounter.provider_id = user_person_id

      encounter.save
      #create observations for the just created encounter
      create_obs(encounter , params)

      if !params[:recalculate_bmi].blank? && params[:recalculate_bmi] == "true"
        weight = 0
        height = 0

        weight_concept_id  = ConceptName.find_by_name("Weight (kg)").concept_id
        height_concept_id  = ConceptName.find_by_name("Height (cm)").concept_id
        bmi_concept_id = ConceptName.find_by_name("Body mass index, measured").concept_id
        work_station_concept_id = ConceptName.find_by_name("Workstation location").concept_id

        vitals_encounter_id = EncounterType.find_by_name("VITALS").encounter_type_id
        enc = Encounter.find(:all, 
          :conditions => ["encounter_type = ? AND patient_id = ? AND voided = 0", 
            vitals_encounter_id, @patient.id])

        encounter.observations.each do |o|
          height = o.answer_string.squish if o.concept_id == height_concept_id
        end

        enc.each do |e|
          obs_created = false
          weight = nil

          e.observations.each do |o|
            next if o.concept_id == work_station_concept_id

            if o.concept_id == weight_concept_id
              weight = o.answer_string.squish.to_i
            elsif o.concept_id == height_concept_id || o.concept_id == bmi_concept_id
              o.voided = 1
              o.date_voided = Time.now
              o.voided_by = encounter.creator
              o.void_reason = "Back data entry recalculation"
              o.save
            end
          end

          bmi = (weight.to_f/(height.to_f*height.to_f)*10000).round(1) rescue "Unknown"

          field = :value_numeric
          field = :value_text and height = 'Unknown' if height == 'Unknown' || height.to_i == 0

          height_obs = Observation.new(
            :concept_name => "Height (cm)",
            :person_id => @patient.id,
            :encounter_id => e.id,
            field => height,
            :obs_datetime => e.encounter_datetime)

          height_obs.save

          field = :value_numeric
          field = :value_text and bmi = 'Unknown' if bmi == 'Unknown' || bmi.to_i == 0

          bmi_obs = Observation.new(
            :concept_name => "Body mass index, measured",
            :person_id => @patient.id,
            :encounter_id => e.id,
            field => bmi,
            :obs_datetime => e.encounter_datetime)

          bmi_obs.save
        end
      end

      # Program handling
      date_enrolled = params[:programs][0]['date_enrolled'].to_time rescue nil
      date_enrolled = session[:datetime] || Time.now() if date_enrolled.blank?
      (params[:programs] || []).each do |program|
        # Look up the program if the program id is set
        @patient_program = PatientProgram.find(program[:patient_program_id]) unless program[:patient_program_id].blank?

        #>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
        #if params[:location] is not blank == migration params
        if params[:location]
          next if not @patient.patient_programs.in_programs("HIV PROGRAM").blank?
        end
        #>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
        # If it wasn't set, we need to create it
        unless (@patient_program)
          @patient_program = @patient.patient_programs.create(
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

      # Identifier handling
      arv_number_identifier_type = PatientIdentifierType.find_by_name('ARV Number').id
      (params[:identifiers] || []).each do |identifier|
        # Look up the identifier if the patient_identfier_id is set
        @patient_identifier = PatientIdentifier.find(identifier[:patient_identifier_id]) unless identifier[:patient_identifier_id].blank?
        # Create or update
        type = identifier[:identifier_type].to_i rescue nil
        unless (arv_number_identifier_type != type) and @patient_identifier
          arv_number = identifier[:identifier].strip
          if arv_number.match(/(.*)[A-Z]/i).blank?
            if params[:encounter]['encounter_type_name'] == 'TB REGISTRATION'
              identifier[:identifier] = "#{PatientIdentifier.site_prefix}-TB-#{arv_number}"
            else
              identifier[:identifier] = "#{PatientIdentifier.site_prefix}-ARV-#{arv_number}"
            end
          end
        end

        if @patient_identifier
          @patient_identifier.update_attributes(identifier)
        else
          @patient_identifier = @patient.patient_identifiers.create(identifier)
        end
      end

      # person attribute handling
      (params[:person] || []).each do | type , attribute |
        # Look up the attribute if the person_attribute_id is set
        @person_attribute = nil

        if not @person_attribute.blank?
          @patient_identifier.update_attributes(person_attribute)
        else
          case type
          when 'agrees_to_be_visited_for_TB_therapy'
            @person_attribute = @patient.person.person_attributes.create(
              :person_attribute_type_id => PersonAttributeType.find_by_name("Agrees to be visited at home for TB therapy").person_attribute_type_id,
              :value => attribute)
          when 'agrees_phone_text_for_TB_therapy'
            @person_attribute = @patient.person.person_attributes.create(
              :person_attribute_type_id => PersonAttributeType.find_by_name("Agrees to phone text for TB therapy").person_attribute_type_id,
              :value => attribute)
          end
        end
      end

      render :text => "OK"

    else
      render :text => "Location not found or not valid"
    end
  end

  def export_on_art_patients
    @ids = params["ids"].split(",")
    @id_string = "'" + @ids.join("','") + "'"
    @end_date = params["end_date"]
    @start_date = params["start_date"]
    anc_visit = Hash.new
    params["id_visit_map"].split(",").each do |map|
      anc_visit["#{map.split('|').first}"] = map.split('|').last
    end
    result = Hash.new
    @patient_ids = []
    b4_visit_one = []
    no_art = []
 
    nationa_id_identifier_type = PatientIdentifierType.find_by_name('National id').id 
    
    PatientProgram.find_by_sql("SELECT p.person_id patient_id, f.identifier, 
      earliest_start_date_at_clinic(p.person_id) earliest_start_date,
      current_state_for_program(p.person_id, 1, '#{@end_date}') AS state
			FROM person p 
      INNER JOIN patient_identifier f ON f.patient_id = p.person_id
      AND f.identifier_type = (#{nationa_id_identifier_type}) AND f.identifier IN (#{@id_string})
			WHERE (p.gender = 'F' OR gender = 'Female') 
      GROUP BY p.person_id").each do | patient |
      @patient_ids << patient.patient_id
      idf = patient.identifier
      result["#{idf}"] = patient.earliest_start_date
      if ((patient.earliest_start_date.to_date < anc_visit["#{idf}"].to_date) rescue false)
        b4_visit_one << idf
      end
    end
    no_art = @ids - result.keys

    dispensing_encounter_type = EncounterType.find_by_name('DISPENSING').id
    cpt_drug_id = Drug.find(:all, :conditions => ["name LIKE ?", "%Cotrimoxazole%"]).map(&:id)

    if @patient_ids.length > 0
=begin
      cpt_ids = Encounter.find_by_sql(["SELECT e.patient_id, o.value_drug, e.encounter_type FROM encounter e
			INNER JOIN obs o ON e.encounter_id = o.encounter_id AND e.voided = 0
			WHERE e.encounter_type = (#{dispensing_encounter_type})
			AND o.value_drug IN (#{cpt_drug_id.join(',')})
			AND e.patient_id IN (#{@patient_ids.join(',')}) AND 
      e.encounter_datetime <= ?", @end_date.to_date.strftime('%Y-%m-%d 23:59:59')]).collect{|e|
        PatientIdentifier.find(:last,
          :conditions => ["patient_id = ? AND identifier_type = ? AND identifier IN (?)",
            e.patient_id, PatientIdentifierType.find_by_name("National id").id,
            @ids]).identifier}.uniq rescue []
=end
      cpt_ids = Encounter.find_by_sql(["SELECT * FROM encounter e
			INNER JOIN obs o ON e.encounter_id = o.encounter_id AND e.voided = 0
			INNER JOIN patient_identifier i ON e.patient_id = i.patient_id AND i.voided = 0
      AND i.identifier_type = #{nationa_id_identifier_type} AND i.identifier IN(#{@id_string})
			WHERE e.encounter_type = (#{dispensing_encounter_type})
			AND o.value_drug IN (#{cpt_drug_id.join(',')})
			AND e.patient_id IN (#{@patient_ids.join(',')}) AND 
      e.encounter_datetime <= ?", @end_date.to_date.strftime('%Y-%m-%d 23:59:59')]).map(&:identifier)
    else
      cpt_ids = []
    end

    result["on_cpt"] = cpt_ids.join(",")
    result["arv_before_visit_one"] = b4_visit_one.join(",")
    result["no_art"] = no_art.join(",")
    render :text => result.to_json
  end

  def art_summary

    result = {}
    @patient = PatientIdentifier.find_by_identifier(params[:national_id]).patient rescue nil

    result["start_date"] = PatientService.earliest_start_date_patient_data(@patient.id)[:earliest_start_date] || ""

    result["arv_number"] = PatientService.get_patient_identifier(@patient, 'ARV Number') rescue ""

    result["last_date_seen"] =  @patient.encounters.find(:first, :order => ["encounter_datetime DESC"]).encounter_datetime.strftime("%d/%b/%Y") rescue ""

    hiv_test = {}

    @patient.encounters.find(:first, :order => ["encounter_datetime DESC"],
      :conditions => ["encounter_type = ?", EncounterType.find_by_name("UPDATE HIV STATUS")]).observations.collect{|obs|
      
      c_name = ConceptName.find_by_concept_id(obs.concept_id).name.strip.upcase
      next if c_name.match(/location/i)
      hiv_test[c_name] = obs.answer_string.strip
    } rescue {}

    result["latest_hiv_test"] = hiv_test    
   
    result.delete_if{|key, value| value.blank?}
    
    render :text => result.to_json

  end


	def lab_results_print
		label_commands = lab_results_label(params[:id])
		send_data(label_commands.to_s,:type=>"application/label; charset=utf-8", :stream=> false, :filename=>"#{params[:id]}#{rand(10000)}.lbs", :disposition => "inline")

	end

  def lab_results_label(patient_id)
		patient = Patient.find(patient_id)
		patient_bean = PatientService.get_patient(patient.person)

		begin
			observation = patient_recent_lab_results(patient_id)
			sputum_results = [['NEGATIVE','NEGATIVE'], ['SCANTY','SCANTY'], ['WEAKLY POSITIVE','1+'], ['MODERATELY POSITIVE','2+'], ['STRONGLY POSITIVE','3+']]
			concept_one = ConceptName.find_by_name("First sputum for AAFB results").concept_id
			concept_two = ConceptName.find_by_name("Second sputum for AAFB results").concept_id
			concept_three = ConceptName.find_by_name("Third sputum for AAFB results").concept_id
			concept_four = ConceptName.find_by_name("Culture(1st) Results").concept_id
			concept_five = ConceptName.find_by_name("Culture(2nd) Results").concept_id
			concept =[]
			culture =[]
			labels = []
			observation.each do |obs|
        next if obs.value_coded.blank?
        concept[0] = ConceptName.find_by_concept_id(obs.value_coded).name if obs.concept_id == concept_one
        concept[1] = ConceptName.find_by_concept_id(obs.value_coded).name if obs.concept_id == concept_two
        concept[2] = ConceptName.find_by_concept_id(obs.value_coded).name if obs.concept_id == concept_three
        culture[0] = ConceptName.find_by_concept_id(obs.value_coded).name if obs.concept_id == concept_four
        culture[1] = ConceptName.find_by_concept_id(obs.value_coded).name if obs.concept_id == concept_five
			end
			if concept.length < 2
        first = "Culture-1 Results: #{sputum_results.assoc("#{culture[0].upcase}")[1]}"
        second = "Culture-2 Results: #{sputum_results.assoc("#{culture[1].upcase}")[1]}"
			else
        lab_result = []
        h = 0
        (0..2).each do |x|
          if concept[x].to_s != ""
            lab_result[h] = sputum_results.assoc("#{concept[x].upcase}")
            h += 1
          end
        end
        first = "AAFB(1st) results: #{lab_result[0][1] rescue ""}"
        second = "AAFB(2nd) results: #{lab_result[1][1] rescue ""}"
      end
      i = 0
      labels = []

      label = 'label' + i.to_s
      label = ZebraPrinter::Label.new(500,165)
      label.font_size = 2
      label.font_horizontal_multiplier = 1
      label.font_vertical_multiplier = 1
      label.left_margin = 300
      label.draw_text("Name: #{patient_bean.name}",50,50,0,3,1,1,false)
      label.draw_text(first,50,90,0,2,1,1)
      label.draw_text(second,50,130,0,2,1,1)

      labels << label

      i = i + 1

      print_labels = []
      label = 0
      while label <= labels.size
        print_labels << labels[label].print(1) if labels[label] != nil
        label = label + 1
      end

      return print_labels
		rescue
			return
		end
  end

  def create_fast_track_assesment_observations
    session_date = session[:datetime].to_date rescue Time.now
    fast_track_status = params[:fast_track_status]
    patient = Patient.find(params[:patient_id])
    encounter_type = EncounterType.find_by_name("FAST TRACK ASSESMENT")
    concept_ids = params[:concept_ids].split(",")
    
    ActiveRecord::Base.transaction do
      encounter = patient.encounters.find(:last, :conditions => ["encounter_type =? AND DATE(encounter_datetime) =?",
          encounter_type, session_date.to_date])
      encounter.void unless encounter.blank?
      encounter = Encounter.new
      encounter.encounter_type = encounter_type.encounter_type_id
      encounter.patient_id = params[:patient_id]
      encounter.encounter_datetime = session_date
      encounter.save

      concept_ids.each do |concept_id|
        encounter.observations.create({
            :person_id => params[:patient_id],
            :concept_id => concept_id,
            :value_coded => Concept.find_by_name("YES").concept_id,
            :obs_datetime => encounter.encounter_datetime
          })
      end

      encounter.observations.create({
          :person_id => params[:patient_id],
          :concept_id => Concept.find_by_name("FAST").concept_id,
          :value_coded => Concept.find_by_name(fast_track_status).concept_id,
          :obs_datetime => encounter.encounter_datetime
        })
    end
    
    render :text => true and return
  end

  def create_encounter_ajax
    session_date = session[:datetime].to_date.strftime('%Y-%m-%d 00:00:01').to_time rescue Time.now
    encounter_type = EncounterType.find_by_name(params[:encounter_type])

    encounter = Encounter.create(:patient_id => params[:patient_id],
      :encounter_type => encounter_type.id,
      :encounter_datetime => session_date.strftime('%Y-%m-%d %H:%M:%S'))

    render :text => {:encounter_id => encounter.id, 
      :datetime => encounter.encounter_datetime}.to_json and return
  end

  def create_obs_ajax
    obs = JSON.parse(params[:obs][0])
    encounter = Encounter.find(params[:encounter_id])

    (obs || []).each do |ob|
      observation = Observation.create(:encounter_id => encounter.id,
        :obs_datetime => encounter.encounter_datetime,
        :person_id => encounter.patient_id,
        :concept_id =>  ConceptName.find_by_name(ob['concept_name']).concept_id)

      unless ob['value_coded_text'].blank?
        concept_id = ConceptName.find_by_name(ob['value_coded_text']).concept_id
        observation.update_attributes(:value_coded => concept_id)
      end

      unless ob['obs_group_text'].blank?
        obs_group = Observation.create(:encounter_id => encounter.id,
          :obs_datetime => encounter.encounter_datetime,
          :person_id => encounter.patient_id,
          :concept_id =>  ConceptName.find_by_name(ob['value_coded_text']).concept_id,
          :value_coded => ConceptName.find_by_name(ob['obs_group_text']).concept_id,
          :obs_group_id => observation.id)

      end

    end

    render :text => (encounter).to_json and return
  end

  def get_next_task
    render :text => next_task(Patient.find(params[:patient_id])).to_json and return
  end

  protected

  def number_of_booked_patients(date)
                                                                                
    start_date = date.strftime('%Y-%m-%d 00:00:00')
    end_date = date.strftime('%Y-%m-%d 23:59:59')
                                                                                
    appointments = Observation.find_by_sql("SELECT count(value_datetime) AS count FROM obs
      INNER JOIN encounter e USING(encounter_id) WHERE concept_id = #{@concept_id} 
      AND encounter_type = #{@encounter_type.id} AND value_datetime >= '#{start_date}' 
      AND value_datetime <= '#{end_date}' AND obs.voided = 0 GROUP BY value_datetime")     
    count = appointments.first.count unless appointments.blank?
    count = 0 if count.blank?
                                                                                
    return count
  end

  def suggested(program_id)
    session_date = session[:datetime].to_date rescue Date.today
    patient_program = PatientProgram.find(program_id)
    current_weight = PatientService.get_patient_attribute_value(patient_program.patient, "current_weight", session_date) rescue []
    return MedicationService.regimen_options(current_weight, patient_program.program) rescue []
  end

  def get_amounts_brought_if_transfer_in(person_id, drug_concept_id, date)
    amount = Observation.find(:first, :conditions =>["concept_id = ? AND (obs_datetime BETWEEN ? AND ?)
      AND person_id = ?", drug_concept_id , date.strftime('%Y-%m-%d 00:00:00'), 
        date.strftime('%Y-%m-%d 23:59:59'), person_id])
    return 0 if amount.blank?
    return amount.value_numeric
  end

end
