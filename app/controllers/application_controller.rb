class ApplicationController < GenericApplicationController
  def national_lims_activated
    if !File.exists?("#{Rails.root}/config/lims.yml")
      return false
    end
    settings = YAML.load_file("#{Rails.root}/config/lims.yml")[Rails.env]
    enabled = settings['enable_lims']

    begin
      return true if (enabled.to_s == 'true')
      return false 
    rescue
      return false 
    end
  end

  def latest_lims_vl(patient)
    settings = YAML.load_file("#{Rails.root}/config/lims.yml")[Rails.env]
    national_id_type = PatientIdentifierType.find_by_name("National id").id
    npid = patient.patient_identifiers.find_by_identifier_type(national_id_type).identifier
    url = settings['lims_national_dashboard_ip'] + "/api/vl_result_by_npid?npid=#{npid}&test_status=verified__reviewed"
    trail_url = settings['lims_national_dashboard_ip'] + "/api/patient_lab_trail?npid=#{npid}"
    data = JSON.parse(RestClient.get(url)) rescue []
    latest_date = data.last[0].to_date rescue nil
    latest_result = data.last[1]["Viral Load"] rescue nil
    modifier = ''
    [modifier, latest_result, latest_date] rescue []
  end

  def todays_consultation_encounters(patient, session_date = Date.today)
    hiv_clinic_consultation_encounter_type = EncounterType.find_by_name("HIV CLINIC CONSULTATION")
    hiv_clinic_consultations = Encounter.find(:all, :conditions =>["patient_id=? AND encounter_type=?
      AND DATE(encounter_datetime) = ?", patient.id, hiv_clinic_consultation_encounter_type.id,
        session_date.to_date])
    return hiv_clinic_consultations.count
  end

  def patient_has_stopped_fast_track_at_adherence?(patient, session_date = Date.today)
    stop_reason_concept_id = Concept.find_by_name('STOP REASON').concept_id
    fast_track_stop_reason_obs = patient.person.observations.find(:last, :conditions => ["DATE(obs_datetime) = ? AND
        concept_id =?", session_date, stop_reason_concept_id]
    )
    return false if fast_track_stop_reason_obs.blank?
    encounter_type = fast_track_stop_reason_obs.encounter.type.name rescue nil
    return false if encounter_type.blank?
    return true if encounter_type.match(/ADHERENCE/i)
    return false
  end

  def tb_suspected_today?(patient, session_date = Date.today)
    tb_status_concept_id = Concept.find_by_name('TB STATUS').concept_id

    latest_tb_status = patient.person.observations.find(:last, :conditions => ["DATE(obs_datetime) = ? AND concept_id =?",
        session_date, tb_status_concept_id]
    ).answer_string.squish.upcase rescue nil

    return false if latest_tb_status.blank?
    return true if (latest_tb_status == 'SUP')
    return false

  end

  def tb_confirmed_today?(patient, session_date = Date.today)
    tb_status_concept_id = Concept.find_by_name('TB STATUS').concept_id

    latest_tb_status = patient.person.observations.find(:last, :conditions => ["DATE(obs_datetime) = ? AND concept_id =?",
        session_date, tb_status_concept_id]
    ).answer_string.squish.upcase rescue nil
    #CONFIRMED TB NOT ON TREATMENT = RX
    return false if latest_tb_status.blank?
    return true if (latest_tb_status.match(/CONFIRMED|RX/i))
    return false
  end

  def patient_on_tb_treatment?(patient, session_date = Date.today)
    tb_treatment_concept_id = Concept.find_by_name('TB TREATMENT').concept_id

    latest_tb_treatment_status = patient.person.observations.find(:last, :conditions => ["DATE(obs_datetime) = ? AND concept_id =?",
        session_date, tb_treatment_concept_id]
    ).answer_string.squish.upcase rescue nil

    return false if latest_tb_treatment_status.blank?
    return true if (latest_tb_treatment_status.match(/YES/i))
    return false

  end

  def patient_last_appointment_date(patient,  session_date = Date.today)
    appointment_date_concept_id = Concept.find_by_name("APPOINTMENT DATE").concept_id
    latest_appointment_date = patient.person.observations.find(:last, :conditions => ["DATE(obs_datetime) < ? AND concept_id =?",
        session_date, appointment_date_concept_id]
    ).answer_string.squish.to_date rescue nil
    return latest_appointment_date
  end

  def fast_track_patient_but_missed_appointment?(patient, session_date = Date.today)
    fast_track_patient = false
    latest_fast_track_answer = patient.person.observations.recent(1).question("FAST").first.answer_string.squish.upcase rescue nil
    fast_track_patient = true if latest_fast_track_answer == 'YES'

    if fast_track_patient
      if (patient_has_visited_on_scheduled_date(patient,  session_date) == false)
        return true
      end
    end

    return false #If not fast track OR fast track but missed their appointment dates
  end

  def fast_track_obs_date(patient, session_date = Date.today)
    fast_track_concept_id = Concept.find_by_name("FAST").concept_id
    fast_track_assesment_encounter_type_id = EncounterType.find_by_name("FAST TRACK ASSESMENT").encounter_type_id
    fast_track_obs = patient.person.observations.find(:last, :joins => [:encounter],
        :conditions => ["encounter_type =? AND DATE(obs_datetime) <= ? AND
        concept_id =?", fast_track_assesment_encounter_type_id, session_date, fast_track_concept_id]
    )
    fast_track_obs_date = fast_track_obs.obs_datetime.to_date unless fast_track_obs.blank?
    return fast_track_obs_date
  end

  def fast_track_done_today(patient, session_date = Date.today)
    fast_track_done_obs = patient.person.observations.find(:last, :joins => [:encounter],
      :conditions => ["DATE(obs_datetime) = ? AND comments =?", session_date, 'fast track done'])
    return false if fast_track_done_obs.blank?
    return true
  end

  def fast_track_patient?(patient, session_date = Date.today)
    fast_track_patient = false
    latest_fast_track_answer = patient.person.observations.recent(1).question("FAST").first.answer_string.squish.upcase rescue nil
    fast_track_patient = true if latest_fast_track_answer == 'YES'

    if (patient_has_visited_on_scheduled_date(patient,  session_date) == false)
      fast_track_patient = false
    end

    return fast_track_patient
  end

  def tb_suspected_or_confirmed?(patient, session_date = Date.today)
    tb_status_concept_id = Concept.find_by_name('TB STATUS').concept_id

    latest_tb_status = patient.person.observations.find(:last, :conditions => ["DATE(obs_datetime) < ? AND concept_id =?",
        session_date, tb_status_concept_id]
    ).answer_string.squish.upcase rescue nil

    return false if latest_tb_status.blank?
    return true if (latest_tb_status.match(/TB SUSPECTED|CONFIRMED/i))
    return false

  end

  def patient_has_psychosis?(patient, session_date = Date.today)
    mw_art_side_effects_concept_id = Concept.find_by_name('MALAWI ART SIDE EFFECTS').concept_id
    psychosis_concept_id = Concept.find_by_name('PSYCHOSIS').concept_id
    latest_psychosis_side_effect = patient.person.observations.find(:last, :conditions => ["DATE(obs_datetime) <= ? AND
      concept_id =? AND value_coded =?",
        session_date, mw_art_side_effects_concept_id, psychosis_concept_id]
    )
    return true unless latest_psychosis_side_effect.blank?
    return false
  end

  def patient_has_visited_on_scheduled_date(patient,  session_date = Date.today)
    appointment_date_concept_id = Concept.find_by_name("APPOINTMENT DATE").concept_id
    latest_appointment_date = patient.person.observations.find(:last, :conditions => ["DATE(obs_datetime) < ? AND concept_id =?",
        session_date, appointment_date_concept_id]
    ).answer_string.squish.to_date rescue nil

    if (latest_appointment_date.class == Date) #check if it is a valid date object
      min_valid_date = latest_appointment_date - 7.days #One week earlier
      max_valid_date = latest_appointment_date + 7.days #One week later
      if (session_date < min_valid_date || session_date > max_valid_date)
        #The patient came one or more weeks earlier than the appointment date
        #The patient came one or more weeks later than the appointment date
        return false
      end
      return true
    end

    return false
  end

  def htn_client?(patient)
    #    link_to_htn = CoreService.get_global_property_value("activate.htn.enhancement")
    htn_min_age = CoreService.get_global_property_value("htn.screening.age.threshold")
    age = patient.person.age((session[:datetime].to_date rescue Date.today)) rescue 0
    htn_patient = false
=begin
    refer_to_clinician = (Observation.last(:conditions => ["person_id = ? AND voided = 0 AND concept_id = ?
                                                          AND DATE(obs_datetime) = ?",
                                                          patient.person.id,
                                                          ConceptName.find_by_name("REFER TO ART CLINICIAN").concept_id,
                                                          (session[:datetime].to_date rescue Date.today)
    ]).answer_string.downcase.strip rescue nil) == "yes"

    if ((!refer_to_clinician && link_to_htn.to_s == "true" && htn_min_age.to_i <= age) rescue false)
      htn_patient = true
    end
=end

    if ((htn_min_age.to_i <= age.to_i) rescue false) || patient.programs.map{|x| x.name}.include?("HYPERTENSION PROGRAM")
      htn_patient = true
    end
    return htn_patient
  end

  def next_task(patient)

    session_date = session[:datetime].to_date rescue Date.today
    task = main_next_task(Location.current_location, patient,session_date)
    sbp_threshold = CoreService.get_global_property_value("htn.systolic.threshold").to_i
    dbp_threshold = CoreService.get_global_property_value("htn.diastolic.threshold").to_i

    if vl_routine_check_activated
      if (@template.improved_viral_load_check(patient) == true)
        #WORKFLOW FOR HIV VIRAL LOAD GOES HERE
        #This is the path "/patients/hiv_viral_load?patient_id=patient_id"
        concept_id = ConceptName.find_by_name("Prescribe drugs").concept_id
        prescribe_drugs_obs = Observation.find(:first,:conditions =>["person_id=? AND concept_id =? AND
              DATE(obs_datetime) =?", patient.id, concept_id, session_date])

        unless prescribe_drugs_obs.blank?
          if (prescribe_drugs_obs.answer_string.squish.upcase == 'YES')
            if task.encounter_type.match(/TREATMENT/i)
              #Do viral load just before treatment
              if !(session[:hiv_viral_load_today_patient].to_i == patient.id)
                task.url = "/patients/hiv_viral_load?patient_id=#{patient.id}"
              end
            end
          end

          if (prescribe_drugs_obs.answer_string.squish.upcase == 'NO')
            #Still do viral load if treatment is not required
            if !(session[:hiv_viral_load_today_patient].to_i == patient.id)
              task.url = "/patients/hiv_viral_load?patient_id=#{patient.id}"
            end
          end
        end
      end
    end

    if cervical_cancer_screening_activated
      patient_bean = PatientService.get_patient(patient.person)
      age = patient_bean.age
      sex = patient_bean.sex.upcase

      cervical_cancer_min_age_property = "cervical.cancer.min.age"
      cervical_cancer_max_age_property = "cervical.cancer.max.age"
      daily_referral_limit_concept = "cervical.cancer.daily.referral.limit"
      current_daily_referral_limit = GlobalProperty.find_by_property(daily_referral_limit_concept).property_value.to_i rescue 1000

      current_cervical_min_age  = GlobalProperty.find_by_property(cervical_cancer_min_age_property).property_value.to_i rescue 0
      current_cervical_max_age  = GlobalProperty.find_by_property(cervical_cancer_max_age_property).property_value.to_i rescue 1000

      cervical_cancer_encounters_count = Encounter.find(:all, :select => "COUNT(DISTINCT(patient_id)) as count", :conditions =>["DATE(encounter_datetime) = ? AND
          encounter_type = ?", session_date.to_date, EncounterType.find_by_name('CERVICAL CANCER SCREENING').id]
      ).last["count"].to_i rescue 0

      if sex == 'FEMALE' && (age >= current_cervical_min_age && age <= current_cervical_max_age)
        cervical_cancer_screening_encounter_type_id = EncounterType.find_by_name("CERVICAL CANCER SCREENING").encounter_type_id
        via_referral_outcome_concept_id = Concept.find_by_name("VIA REFERRAL OUTCOME").concept_id
        via_referral_concept_id = Concept.find_by_name("VIA REFERRAL").concept_id

        todays_cervical_cancer_encounter = Encounter.find(:last, :conditions => ["patient_id =? AND
          encounter_type =? AND DATE(encounter_datetime) =?", patient.id,
            cervical_cancer_screening_encounter_type_id, Date.today]
        )

        terminal_referral_outcomes = ["PRE/CANCER TREATED", "CANCER UNTREATABLE"]

        via_referral_outcome_answers = Observation.find(:all, :joins => [:encounter],
          :conditions => ["person_id =? AND encounter_type =? AND concept_id =?",
            patient.id, cervical_cancer_screening_encounter_type_id, via_referral_outcome_concept_id]
        ).collect{|o|o.answer_string.squish.upcase}
        terminal = false

        via_referral_outcome_answers.each do |outcome|
          if terminal_referral_outcomes.include?(outcome)
            terminal = true
            break
          end
        end

        if terminal == true
          #Don't go to cervical screening cancer
        else
          if !(session[:cervical_cancer_patient].to_i == patient.id)
            if todays_cervical_cancer_encounter.blank?
              if ((cervical_cancer_encounters_count <= current_daily_referral_limit) || (positive_cryo_patient_on_last_cervical_cancer_screening_visit(patient) == true))
                if task.encounter_type.match(/TREATMENT/i)
                  task.encounter_type = "Cervical Cancer Screening"
                  task.url = "/encounters/new/cervical_cancer_screening?patient_id=#{patient.id}"
                end
              end
            end
          end
        end
      end
    end

    if CoreService.get_global_property_value("activate.htn.enhancement").to_s == "true"

      patient_is_htn_client = htn_client?(patient)
      if patient_is_htn_client
        task = check_htn_workflow(patient, task)
      elsif (session['captureBP'] == "true")
        task = Task.new(:url => "/htn_encounter/vitals_confirmation?patient_id=#{patient.id}", :encounter_type => "BP Vitals")
        session['captureBP'] = nil
      else
        bp = patient.current_bp(session_date)
        if ((!bp[0].blank? && bp[0] > sbp_threshold) || (!bp[1].blank?  && bp[1] > dbp_threshold))
          task = Task.new(:url => "/htn_encounter/bp_management?patient_id=#{patient.id}",
            :encounter_type => "HYPERTENSION MANAGEMENT")
        end
      end

    end

    begin
      return task.url if task.present? && task.url.present?
      return "/patients/show/#{patient.id}"
    rescue
      return "/patients/show/#{patient.id}"
    end
  end

  # TB next form

  def positive_cryo_patient_on_last_cervical_cancer_screening_visit(patient)
    cervical_cancer_encounter_type = EncounterType.find_by_name('CERVICAL CANCER SCREENING').id
    patient_cervical_cancer_encounter = Encounter.find(:last, :conditions => ["patient_id =? AND encounter_type =?",
        patient.patient_id, cervical_cancer_encounter_type])
    return false if patient_cervical_cancer_encounter.blank?

    patient_cervical_cancer_encounter.observations.each do |observation|
      next unless observation.concept.fullname.match(/POSITIVE CRYO/i)
      if observation.answer_string.squish.match(/Cryo Done/i)
        return true
        break
      end
      return false
    end

  end

  def continue_tb_treatment(patient,session_date)
    tb_visit = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
      :conditions =>["patient_id = ? AND encounter_type = ?
                    AND DATE(encounter_datetime) = ?",patient.id,
        EncounterType.find_by_name("TB VISIT").id,session_date.to_date])

    tb_visit.observations.map{|o|
      o.to_s.upcase.strip.squish
    }.include?("CONTINUE TREATMENT: YES") rescue false

  end

  def tb_next_form(location , patient , session_date = Date.today)
    task = (Task.first.nil?)? Task.new() : Task.first
    pp = PatientProgram.find(:first, :joins => :location, :conditions => ["program_id = ? AND patient_id = ?", Program.find_by_concept_id(Concept.find_by_name('HIV PROGRAM').id).id,patient.id]).patient_states.last.program_workflow_state.concept.fullname	rescue ""

    if patient.patient_programs.in_uncompleted_programs(['TB PROGRAM', 'MDR-TB PROGRAM']).blank?
      #Patient has no active TB program ...'
      ids = Program.find(:all,:conditions =>["name IN(?)",['TB PROGRAM', 'MDR-TB PROGRAM']]).map{|p|p.id}
      last_active = PatientProgram.find(:first,:order => "date_completed DESC,date_created DESC",
        :conditions => ["patient_id = ? AND program_id IN(?)",patient.id,ids])

      if not last_active.blank?
        state = last_active.patient_states.last.program_workflow_state.concept.fullname rescue 'NONE'
        task.encounter_type = state
        task.url = "/patients/show/#{patient.id}"
        return task
      end
    end

    #we get the sequence of clinic questions(encounters) form the GlobalProperty table
    #property: list.of.clinical.encounters.sequentially
    #property_value: ?

    #valid privileges for ART visit ....
    #1. Manage TB Reception Visits - TB RECEPTION
    #2. Manage TB initial visits - TB_INITIAL
    #3. Manage Lab orders - LAB ORDERS
    #4. Manage sputum submission - SPUTUM SUBMISSION
    #5. Manage Lab results - LAB RESULTS
    #6. Manage TB registration - TB REGISTRATION
    #7. Manage TB followup - TB VISIT
    #8. Manage HIV status updates - UPDATE HIV STATUS
    #8. Manage prescriptions - TREATMENT
    #8. Manage dispensations - DISPENSING
		if patient.person.observations.to_s.match(/smear result:  Yes/i)
			tb_encounters =  [
        'SOURCE OF REFERRAL','UPDATE HIV STATUS',
        'SPUTUM SUBMISSION','LAB RESULTS','TB_INITIAL',
        'TB RECEPTION','TB REGISTRATION','TB VISIT','TB ADHERENCE',
        'TB CLINIC VISIT','HIV CLINIC REGISTRATION','VITALS','HIV STAGING',
        'HIV CLINIC CONSULTATION','ART ADHERENCE','TREATMENT','DISPENSING'
      ]
		else
			tb_encounters =  [
        'SOURCE OF REFERRAL','UPDATE HIV STATUS','LAB ORDERS',
        'SPUTUM SUBMISSION','LAB RESULTS','TB_INITIAL',
        'TB RECEPTION','TB REGISTRATION','TB VISIT','TB ADHERENCE',
        'TB CLINIC VISIT','HIV CLINIC REGISTRATION','VITALS','HIV STAGING',
        'HIV CLINIC CONSULTATION','ART ADHERENCE','TREATMENT','DISPENSING'
      ]
		end
    user_selected_activities = current_user.activities.collect{|a| a.upcase }.join(',') rescue []
    if user_selected_activities.blank? or tb_encounters.blank?
      task.url = "/patients/show/#{patient.id}"
      return task
    end
    art_reason = patient.person.observations.recent(1).question("REASON FOR ART ELIGIBILITY").all rescue nil
    reason_for_art = art_reason.map{|c|ConceptName.find(c.value_coded_name_id).name}.join(',') rescue ''

    tb_reception_attributes = []
    tb_obs = Encounter.find(:first,:order => "encounter_datetime DESC",
      :conditions => ["DATE(encounter_datetime) = ? AND patient_id = ? AND encounter_type = ?",
        session_date,patient.id,EncounterType.find_by_name('TB RECEPTION').id]).observations rescue []
    (tb_obs || []).each do | obs |
      tb_reception_attributes << obs.to_s.squish.strip
    end

    tb_encounters.each do | type |
			next if pp.match(/patient\sdied/i)
			task.encounter_type = type

      case type
      when 'SOURCE OF REFERRAL'
        next if PatientService.patient_tb_status(patient).match(/treatment/i)

        if ['Lighthouse','Martin Preuss Centre'].include?(Location.current_health_center.name)
          if not (location.current_location.name.match(/Chronic Cough/) or
                location.current_location.name.match(/TB Sputum Submission Station/i))
            next
          end
        end

        source_of_referral = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
          :conditions =>["encounter_datetime <= ?
                                      AND patient_id = ? AND encounter_type = ?",
            (session_date.to_date).strftime('%Y-%m-%d 23:59:59'),
            patient.id,EncounterType.find_by_name(type).id])

        if source_of_referral.blank? and user_selected_activities.match(/Manage Source of Referral/i)
          task.url = "/encounters/new/source_of_referral?patient_id=#{patient.id}"
          return task
        elsif source_of_referral.blank? and not user_selected_activities.match(/Manage Source of Referral/i)
          task.url = "/patients/show/#{patient.id}"
          return task
        end
      when 'UPDATE HIV STATUS'
        next_task = PatientService.checks_if_labs_results_are_avalable_to_be_shown(patient , session_date , task)
        return next_task unless next_task.blank?

        next if PatientService.patient_hiv_status(patient).match(/Positive/i)
        if not patient.patient_programs.blank?
          next if patient.patient_programs.collect{|p|p.program.name}.include?('HIV PROGRAM')
        end

        hiv_status = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
          :conditions =>["encounter_datetime >= ? AND encounter_datetime <= ?
                                      AND patient_id = ? AND encounter_type = ?",(session_date.to_date - 3.month).strftime('%Y-%m-%d 00:00:00'),
            (session_date.to_date).strftime('%Y-%m-%d 23:59:59'),patient.id,EncounterType.find_by_name(type).id])

        if hiv_status.observations.map{|s|s.to_s.split(':').last.strip}.include?('Positive')
          next
        end if not hiv_status.blank?

        if hiv_status.blank? and user_selected_activities.match(/Manage HIV Status Visits/i)
          task.url = "/encounters/new/hiv_status?show&patient_id=#{patient.id}"
          return task
        elsif hiv_status.blank? and not user_selected_activities.match(/Manage HIV Status Visits/i)
          task.url = "/patients/show/#{patient.id}"
          return task
        end

        tb_clinic_encounter = Encounter.find(:first,
          :conditions => ["encounter_type = ? AND patient_id = ?
            AND DATE(encounter_datetime) <= ?",
            EncounterType.find_by_name("TB clinic visit").id,patient.id,
            session_date.to_date],:order => "encounter_datetime DESC,
            encounter.date_created DESC")

        xray = tb_clinic_encounter.observations.find_all_by_concept_id(ConceptName.find_by_name("Further examination for TB required").concept_id).first.to_s.strip.squish.upcase rescue ''

        if xray.match(/: X-Ray/i)
          task.encounter_type = "Xray scan"
          task.url = "/patients/show/#{patient.id}"
          return task
        elsif xray.match(/: TB sputum test/i)
          if user_selected_activities.match(/Manage Lab Orders/i)
            task.encounter_type = "Lab orders"
            task.url = "/encounters/new/lab_orders?show&patient_id=#{patient.id}"
            return task
          elsif not user_selected_activities.match(/Manage Lab Orders/i)
            task.encounter_type = "Lab orders"
            task.url = "/patients/show/#{patient.id}"
            return task
          end
        end

        refered_to_htc_concept_id = ConceptName.find_by_name("Refer to HTC").concept_id
        observation = Observation.find(:all,
          :conditions => ["encounter_id = ?", Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
              :conditions =>["DATE(encounter_datetime) <= ? AND patient_id = ? AND encounter_type = ?",
                session_date.to_date, patient.id,EncounterType.find_by_name("update hiv status").id]).encounter_id]).to_s


        #if hiv_status.blank? and user_selected_activities.match(/Manage HIV Status Visits/i)
        if observation.match(/Refer to HTC:  Yes/i) and user_selected_activities.match(/Manage HIV Status Visits/i)
          task.encounter_type = 'Refered to HTC'
          task.url = "/patients/show/#{patient.id}"
          return task
        end

        if observation.match(/Refer to HTC:  Yes/i) and location.name.upcase == "TB HTC"
          refered_to_htc = Encounter.find(:first,
            :joins => "INNER JOIN obs ON obs.encounter_id = encounter.encounter_id",
            :order => "encounter_datetime DESC,date_created DESC",
            :conditions => ["patient_id = ? and concept_id = ? AND value_coded = ?",
              patient.id,refered_to_htc_concept_id,ConceptName.find_by_name('YES').concept_id])

          loc_name = refered_to_htc.observations.map do | obs |
            next unless obs.to_s.match(/Workstation location/i)
            obs.to_s.gsub('Workstation location:','').squish
          end

          task.encounter_type = "#{loc_name}"
          task.url = "/patients/show/#{patient.id}"
          return task
        end
      when 'VITALS'

        if not PatientService.patient_hiv_status(patient).match(/Positive/i) and not PatientService.patient_tb_status(patient).match(/treatment/i)
          next
        end

        first_vitals = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
          :conditions =>["patient_id = ? AND encounter_type = ?",
            patient.id,EncounterType.find_by_name(type).id])

        if not PatientService.patient_tb_status(patient).match(/treatment/i) and not tb_reception_attributes.include?('Any need to see a clinician: Yes')
          next
        end if not PatientService.patient_hiv_status(patient).match(/Positive/i)

        if PatientService.patient_tb_status(patient).match(/treatment/i) and not PatientService.patient_hiv_status(patient).match(/Positive/i)
          next
        end if not first_vitals.blank?

        vitals = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
          :conditions =>["DATE(encounter_datetime) = ? AND patient_id = ? AND encounter_type = ?",
            session_date.to_date,patient.id,EncounterType.find_by_name(type).id])

				patient_present = Observation.find(:all, :limit => 1, :conditions => ["DATE(obs_datetime) = ? AND concept_id = ? AND person_id = ?",
            session_date.to_date, ConceptName.find_by_name("Patient present for consultation").concept_id, patient.id])
				#raise patient_present.to_s.to_yaml
        next if patient_present.to_s.match(/patient present for consultation:  no/i)
        if vitals.blank? and user_selected_activities.match(/Manage Vitals/i)
          task.encounter_type = 'VITALS'
          task.url = "/encounters/new/vitals?patient_id=#{patient.id}"
          return task
        elsif vitals.blank? and not user_selected_activities.match(/Manage Vitals/i)
          task.encounter_type = 'VITALS'
          task.url = "/patients/show/#{patient.id}"
          return task
        end
      when 'TB RECEPTION'
        reception = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
          :conditions =>["DATE(encounter_datetime) = ? AND patient_id = ? AND encounter_type = ?",
            session_date.to_date,patient.id,EncounterType.find_by_name(type).id])

        if reception.blank? and user_selected_activities.match(/Manage TB Reception Visits/i)
          task.url = "/encounters/new/tb_reception?show&patient_id=#{patient.id}"
          return task
        elsif reception.blank? and not user_selected_activities.match(/Manage TB Reception Visits/i)
          task.url = "/patients/show/#{patient.id}"
          return task
        end
      when 'LAB ORDERS'
        next if PatientService.patient_tb_status(patient).match(/treatment/i)

        if ['Lighthouse','Martin Preuss Centre'].include?(Location.current_health_center.name)
          if not (location.current_location.name.match(/Chronic Cough/) or
                location.current_location.name.match(/TB Sputum Submission Station/i))
            next
          end
        end

        lab_order = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
          :conditions =>["DATE(encounter_datetime) <= ? AND patient_id = ? AND encounter_type = ?",
            session_date.to_date ,patient.id,EncounterType.find_by_name(type).id])

        next_lab_encounter =  PatientService.next_lab_encounter(patient , lab_order , session_date)

        if (lab_order.encounter_datetime.to_date == session_date.to_date)
          task.encounter_type = 'NONE'
          task.url = "/patients/show/#{patient.id}"
          return task
        end if not lab_order.blank?

        if user_selected_activities.match(/Manage Lab Orders/i)
          task.url = "/encounters/new/lab_orders?show&patient_id=#{patient.id}"
          return task
        elsif not user_selected_activities.match(/Manage Lab Orders/i)
          task.url = "/patients/show/#{patient.id}"
          return task
        end if (next_lab_encounter.blank? or next_lab_encounter == 'NO LAB ORDERS')
      when 'SPUTUM SUBMISSION'
        previous_sputum_sub = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
          :conditions =>["DATE(encounter_datetime) <= ? AND patient_id = ? AND encounter_type = ?",
            session_date.to_date ,patient.id,EncounterType.find_by_name(type).id])

        next_lab_encounter =  PatientService.next_lab_encounter(patient , previous_sputum_sub , session_date)

        if (previous_sputum_sub.encounter_datetime.to_date == session_date.to_date)
          task.encounter_type = 'NONE'
          task.url = "/patients/show/#{patient.id}"
          return task
        end if not previous_sputum_sub.blank?

        if not next_lab_encounter.blank?
          next
        end if not (next_lab_encounter == "NO LAB ORDERS")

        if next_lab_encounter.blank? and previous_sputum_sub.encounter_datetime.to_date == session_date.to_date
          task.encounter_type = 'NONE'
          task.url = "/patients/show/#{patient.id}"
          return task
        end if not previous_sputum_sub.blank?

        if user_selected_activities.match(/Manage Sputum Submissions/i)
          task.url = "/encounters/new/sputum_submission?show&patient_id=#{patient.id}"
          return task
        elsif not user_selected_activities.match(/Manage Sputum Submissions/i)
          task.url = "/patients/show/#{patient.id}"
          return task
        end if (next_lab_encounter.blank?)
      when 'LAB RESULTS'
        lab_result = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
          :conditions =>["DATE(encounter_datetime) <= ? AND patient_id = ? AND encounter_type = ?",
            session_date.to_date ,patient.id,EncounterType.find_by_name(type).id])

        next_lab_encounter =  PatientService.next_lab_encounter(patient , lab_result , session_date)

        if not next_lab_encounter.blank?
          next
        end if not (next_lab_encounter == "NO LAB ORDERS")

        if user_selected_activities.match(/Manage Lab Results/i)
          task.url = "/encounters/new/lab_results?show&patient_id=#{patient.id}"
          return task
        elsif not user_selected_activities.match(/Manage Lab Results/i)
          task.url = "/patients/show/#{patient.id}"
          return task
        end if (next_lab_encounter.blank?)
      when 'TB CLINIC VISIT'

        next if PatientService.patient_tb_status(patient).match(/treatment/i)

        obs_ans = Observation.find(Observation.find(:first,
            :order => "obs_datetime DESC,date_created DESC",
            :conditions => ["person_id = ? AND concept_id = ? AND DATE(obs_datetime) = ?",patient.id,
              ConceptName.find_by_name("ANY NEED TO SEE A CLINICIAN").concept_id,session_date])).to_s.strip.squish rescue nil

        if not obs_ans.blank?
          next if obs_ans.match(/ANY NEED TO SEE A CLINICIAN: NO/i)
          if obs_ans.match(/ANY NEED TO SEE A CLINICIAN: YES/i)
            tb_visits = Encounter.find(:all,:order => "encounter_datetime DESC,date_created DESC",
              :conditions =>["DATE(encounter_datetime) = ? AND patient_id = ? AND encounter_type = ?",
                session_date.to_date,patient.id,EncounterType.find_by_name('TB VISIT').id])
            if (tb_visits.length == 1)
              roles = current_user_roles.join(',') rescue ''
              if not (roles.match(/Clinician/i) or roles.match(/Doctor/i))
                task.encounter_type = 'TB VISIT'
                task.url = "/patients/show/#{patient.id}"
                return task
              elsif user_selected_activities.match(/Manage TB Treatment Visits/i)
                task.encounter_type = 'TB VISIT'
                task.url = "/encounters/new/tb_visit?show&patient_id=#{patient.id}"
                return task
              elsif not user_selected_activities.match(/Manage TB Treatment Visits/i)
                task.encounter_type = 'TB VISIT'
                task.url = "/patients/show/#{patient.id}"
                return task
              end
            end
          end
        end

        visit_type = Observation.find(Observation.find(:last, :conditions => ["person_id = ? AND concept_id = ? AND DATE(obs_datetime) = ?",
              patient.id, ConceptName.find_by_name("TYPE OF VISIT").concept_id,session_date])).to_s.strip.squish rescue nil

        if not visit_type.blank?  #and obs_ans.match(/ANY NEED TO SEE A CLINICIAN: NO/i)
          next if visit_type.match(/Reason for visit: Follow-up/i)
        end if obs_ans.blank?

        clinic_visit = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
          :conditions =>["DATE(encounter_datetime) = ? AND patient_id = ? AND encounter_type = ?",
            session_date.to_date ,patient.id,EncounterType.find_by_name(type).id])

        clinic_visit = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
          :conditions =>["patient_id = ? AND encounter_type = ?",
            patient.id,EncounterType.find_by_name(type).id])

        if clinic_visit.blank? and user_selected_activities.match(/Manage TB clinic visits/i)
          task.url = "/encounters/new/tb_clinic_visit?show&patient_id=#{patient.id}"
          return task
        elsif clinic_visit.blank? and not user_selected_activities.match(/Manage TB clinic visits/i)
          task.url = "/patients/show/#{patient.id}"
          return task
        end

        clinic_visit = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
          :conditions =>["patient_id = ? AND encounter_type = ?",
            patient.id,EncounterType.find_by_name(type).id])

        #clinic_visit_obs = !clinic_visit.observations.map{|o|
        #o.to_s.downcase.strip.squish
        # }.include?("further examination for tb required: none") rescue false
        clinic_visit_obs = false
        clinic_visit_obs = true if clinic_visit.observations.to_s.match(/further examination for tb required: none/i)
				#raise clinic_visit_obs.to_yaml
        if clinic_visit_obs
          if user_selected_activities.match(/Manage TB clinic visits/i)
            task.url = "/encounters/new/tb_clinic_visit?show&patient_id=#{patient.id}"
            return task
          elsif not user_selected_activities.match(/Manage TB clinic visits/i)
            task.url = "/patients/show/#{patient.id}"
            return task
          end
        end if clinic_visit_obs

      when 'TB_INITIAL'
        #next if not patient.tb_status.match(/treatment/i)
        tb_initial = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
          :conditions =>["patient_id = ? AND encounter_type = ?",
            patient.id,EncounterType.find_by_name(type).id])

        next if not tb_initial.blank?

        #enrolled_in_tb_program = patient.patient_programs.collect{|p|p.program.name}.include?('TB PROGRAM') rescue false

        if user_selected_activities.match(/Manage TB initial visits/i)
          task.url = "/encounters/new/tb_initial?show&patient_id=#{patient.id}"
          return task
        elsif not user_selected_activities.match(/Manage TB initial visits/i)
          task.url = "/patients/show/#{patient.id}"
          return task
        end
      when 'HIV CLINIC REGISTRATION'
        next unless PatientService.patient_hiv_status(patient).match(/Positive/i)

        next unless continue_tb_treatment(patient,session_date)

        enrolled_in_hiv_program = Concept.find(Observation.find(:last,
            :conditions => ["person_id = ? AND concept_id = ?",patient.id,
              ConceptName.find_by_name("Patient enrolled in HIV program").concept_id]).value_coded).concept_names.map{|c|
          c.name}[0].upcase rescue nil

        next unless enrolled_in_hiv_program == 'YES'

        enrolled_in_hiv_program = patient.patient_programs.collect{|p|p.program.name}.include?('HIV PROGRAM') rescue false
        next if enrolled_in_hiv_program

        hiv_clinic_registration = Encounter.find(:first,:conditions =>["patient_id = ? AND encounter_type = ?",
            patient.id,EncounterType.find_by_name(type).id],
          :order =>'encounter_datetime DESC,date_created DESC',:limit => 1)

				#raise user_selected_activities.to_yaml
        if hiv_clinic_registration.blank? and user_selected_activities.match(/Manage HIV first visits/i)
          task.url = "/encounters/new/hiv_clinic_registration?show&patient_id=#{patient.id}"
          return task
        elsif hiv_clinic_registration.blank? and not user_selected_activities.match(/Manage HIV first visits/i)
          task.url = "/patients/show/#{patient.id}"
          return task
        end
      when 'HIV STAGING'
        staging = session["#{patient.id}"]["#{session_date.to_date}"][:stage_patient] rescue []
        if ! staging.blank?
          next if staging == "No"
        end
        next unless continue_tb_treatment(patient,session_date)
        #checks if vitals have been taken already
        vitals = PatientService.checks_if_vitals_are_need(patient,session_date,task,user_selected_activities)
        return vitals unless vitals.blank?

        enrolled_in_hiv_program = Concept.find(Observation.find(:last, :conditions => ["person_id = ? AND concept_id = ?",patient.id,
              ConceptName.find_by_name("Patient enrolled in IMB HIV program").concept_id]).value_coded).concept_names.map{|c|c.name}[0].upcase rescue nil

        next if enrolled_in_hiv_program == 'NO'
        next if patient.patient_programs.blank?
        next unless PatientService.patient_hiv_status(patient).match(/Positive/i)
        next if not patient.patient_programs.collect{|p|p.program.name}.include?('HIV PROGRAM')

        next unless PatientService.patient_hiv_status(patient).match(/Positive/i)
        hiv_staging = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
          :conditions =>["patient_id = ? AND encounter_type = ?",
            patient.id,EncounterType.find_by_name(type).id])

        if hiv_staging.blank? and user_selected_activities.match(/Manage HIV staging visits/i)
          task.url = "/encounters/new/hiv_staging?show&patient_id=#{patient.id}"
          return task
        elsif hiv_staging.blank? and not user_selected_activities.match(/Manage HIV staging visits/i)
          task.url = "/patients/show/#{patient.id}"
          return task
        end if (reason_for_art.upcase ==  'UNKNOWN' or reason_for_art.blank?)
      when 'TB REGISTRATION'
        #checks if patient needs to be stage before continuing
        next_task = PatientService.need_art_enrollment(task,patient,location,session_date,user_selected_activities,reason_for_art)
        return next_task if not next_task.blank? and user_selected_activities.match(/Manage HIV staging visits/i)

        next unless PatientService.patient_tb_status(patient).match(/treatment/i)
        tb_registration = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
          :conditions =>["patient_id = ? AND encounter_type = ?",
            patient.id,EncounterType.find_by_name(type).id])

        next if not tb_registration.blank?
        #enrolled_in_tb_program = patient.patient_programs.collect{|p|p.program.name}.include?('TB PROGRAM') rescue false

        #checks if vitals have been taken already
        vitals = PatientService.checks_if_vitals_are_need(patient,session_date,task,user_selected_activities)
        return vitals unless vitals.blank?


        if user_selected_activities.match(/Manage TB Registration visits/i)
          task.url = "/encounters/new/tb_registration?show&patient_id=#{patient.id}"
          return task
        elsif not user_selected_activities.match(/Manage TB Registration visits/i)
          task.url = "/patients/show/#{patient.id}"
          return task
        end
      when 'TB VISIT'
        if PatientService.patient_is_child?(patient) or PatientService.patient_hiv_status(patient).match(/Positive/i)
          clinic_visit = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
            :conditions =>["patient_id = ? AND encounter_type = ?",
              patient.id,EncounterType.find_by_name('TB CLINIC VISIT').id])
          #checks if vitals have been taken already
          vitals = PatientService.checks_if_vitals_are_need(patient,session_date,task,user_selected_activities)
          return vitals unless vitals.blank?


          if clinic_visit.blank? and user_selected_activities.match(/Manage TB Clinic Visits/i)
            task.encounter_type = "TB CLINIC VISIT"
            task.url = "/encounters/new/tb_clinic_visit?show&patient_id=#{patient.id}"
            return task
          elsif clinic_visit.blank? and not user_selected_activities.match(/Manage TB Clinic Visits/i)
            task.encounter_type = "TB CLINIC VISIT"
            task.url = "/patients/show/#{patient.id}"
            return task
          end if not PatientService.patient_tb_status(patient).match(/treatment/i)
        end

        #checks if vitals have been taken already
        vitals = PatientService.checks_if_vitals_are_need(patient,session_date,task,user_selected_activities)
        return vitals unless vitals.blank?

        if not PatientService.patient_tb_status(patient).match(/treatment/i)
          next
        end if not tb_reception_attributes.include?('Reason for visit: Follow-up')

        tb_registration = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
          :conditions =>["patient_id = ? AND encounter_type = ?",
            patient.id,EncounterType.find_by_name('TB REGISTRATION').id])

        tb_followup = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
          :conditions =>["DATE(encounter_datetime) = ? AND patient_id = ? AND encounter_type = ?",
            session_date.to_date,patient.id,EncounterType.find_by_name(type).id])
=begin
          #Not sure on what this commented block is doing - need to check
          if (tb_followup.encounter_datetime.to_date == tb_registration.encounter_datetime.to_date)
			      next
          end if not tb_followup.blank? and not tb_registration.blank?
=end
        if tb_registration.blank?
          task.encounter_type = 'TB PROGRAM ENROLMENT'
          task.url = "/patients/show/#{patient.id}"
          return task
        end if not tb_reception_attributes.include?('Reason for visit: Follow-up')

        if tb_followup.blank? and user_selected_activities.match(/Manage TB Treatment Visits/i)
          task.url = "/encounters/new/tb_visit?show&patient_id=#{patient.id}"
          return task
        elsif tb_followup.blank? and not user_selected_activities.match(/Manage TB Treatment Visits/i)
          task.url = "/patients/show/#{patient.id}"
          return task
        end

        obs_ans = Observation.find(Observation.find(:first,
            :order => "obs_datetime DESC,date_created DESC",
            :conditions => ["person_id = ? AND concept_id = ? AND DATE(obs_datetime) = ?",patient.id,
              ConceptName.find_by_name("ANY NEED TO SEE A CLINICIAN").concept_id,session_date])).to_s.strip.squish rescue nil

        if not obs_ans.blank?
          next if obs_ans.match(/ANY NEED TO SEE A CLINICIAN: NO/i)
          if obs_ans.match(/ANY NEED TO SEE A CLINICIAN: YES/i)
            tb_visits = Encounter.find(:all,:order => "encounter_datetime DESC,date_created DESC",
              :conditions =>["DATE(encounter_datetime) = ? AND patient_id = ? AND encounter_type = ?",
                session_date.to_date,patient.id,EncounterType.find_by_name('TB VISIT').id])
            if (tb_visits.length == 1)
              roles = current_user_roles.join(',') rescue ''
              if not (roles.match(/Clinician/i) or roles.match(/Doctor/i))
                task.encounter_type = 'TB VISIT'
                task.url = "/patients/show/#{patient.id}"
                return task
              elsif user_selected_activities.match(/Manage TB Treatment Visits/i)
                task.encounter_type = 'TB VISIT'
                task.url = "/encounters/new/tb_visit?show&patient_id=#{patient.id}"
                return task
              elsif not user_selected_activities.match(/Manage TB Treatment Visits/i)
                task.encounter_type = 'TB VISIT'
                task.url = "/patients/show/#{patient.id}"
                return task
              end
            end
          end
        end
      when 'HIV CLINIC CONSULTATION'
        next unless continue_tb_treatment(patient,session_date)

        next unless patient.patient_programs.collect{|p|p.program.name}.include?('HIV PROGRAM') rescue false
        clinic_visit = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
          :conditions =>["DATE(encounter_datetime) = ? AND patient_id = ? AND encounter_type = ?",
            session_date.to_date,patient.id,EncounterType.find_by_name('TB CLINIC VISIT').id])
        goto_hiv_clinic_consultation = clinic_visit.observations.map{|obs| obs.to_s.strip.upcase }.include? 'ART visit:  Yes'.upcase rescue false
        goto_hiv_clinic_consultation_answered = clinic_visit.observations.map{|obs| obs.to_s.strip.upcase }.include? 'ART visit:'.upcase rescue false

        next if not goto_hiv_clinic_consultation and goto_hiv_clinic_consultation_answered


        hiv_clinic_consultation = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
          :conditions =>["DATE(encounter_datetime) = ? AND patient_id = ? AND encounter_type = ?",
            session_date.to_date,patient.id,EncounterType.find_by_name(type).id])

        if hiv_clinic_consultation.blank? and user_selected_activities.match(/Manage HIV clinic consultations/i)
          task.url = "/encounters/new/hiv_clinic_consultation?patient_id=#{patient.id}"
          return task
        elsif hiv_clinic_consultation.blank? and not user_selected_activities.match(/Manage HIV clinic consultations/i)
          task.url = "/patients/show/#{patient.id}"
          return task
        end if not reason_for_art.upcase ==  'UNKNOWN'
      when 'TB ADHERENCE'
        drugs_given_before = false
        MedicationService.drug_given_before(patient,session_date).each do |order|
          next unless MedicationService.tb_medication(order.drug_order.drug)
          drugs_given_before = true
        end

        tb_adherence = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
          :conditions =>["DATE(encounter_datetime) = ? AND patient_id = ? AND encounter_type = ?",
            session_date.to_date,patient.id,EncounterType.find_by_name(type).id])

        if tb_adherence.blank? and user_selected_activities.match(/Manage TB adherence/i)
          task.url = "/encounters/new/tb_adherence?show&patient_id=#{patient.id}"
          return task
        elsif tb_adherence.blank? and not user_selected_activities.match(/Manage TB adherence/i)
          task.url = "/patients/show/#{patient.id}"
          return task
        end if drugs_given_before
      when 'ART ADHERENCE'
        next unless continue_tb_treatment(patient,session_date)
        art_drugs_given_before = false
        MedicationService.drug_given_before(patient,session_date).each do |order|
          next unless MedicationService.arv(order.drug_order.drug)
          art_drugs_given_before = true
        end

        MedicationService.art_drug_prescribed_before(patient,session_date).each do |order|
          arv_drugs_given = true
          break
        end unless arv_drugs_given

        art_adherence = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
          :conditions =>["DATE(encounter_datetime) = ? AND patient_id = ? AND encounter_type = ?",
            session_date.to_date,patient.id,EncounterType.find_by_name(type).id])

        if art_adherence.blank? and user_selected_activities.match(/Manage ART adherence/i)
          task.url = "/encounters/new/art_adherence?show&patient_id=#{patient.id}"
          return task
        elsif art_adherence.blank? and not user_selected_activities.match(/Manage ART adherence/i)
          task.url = "/patients/show/#{patient.id}"
          return task
        end if art_drugs_given_before
      when 'TREATMENT'
=begin
          tb_treatment_encounter = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
                                   :joins => "INNER JOIN obs USING(encounter_id)",
                                   :conditions =>["DATE(encounter_datetime) = ? AND patient_id = ? AND encounter_type = ? AND concept_id = ?",
                                   session_date.to_date,patient.id,EncounterType.find_by_name(type).id,ConceptName.find_by_name('TB regimen type').concept_id])
=end
        tb_treatment_encounter = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
          :joins => "INNER JOIN obs USING(encounter_id)",
          :conditions =>["DATE(encounter_datetime) = ? AND patient_id = ? AND encounter_type = ?",
            session_date.to_date,patient.id,EncounterType.find_by_name(type).id])

        next unless tb_treatment_encounter.blank?


        encounter_tb_visit = Encounter.find(:first,:conditions =>["patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) = ?",
            patient.id,EncounterType.find_by_name('TB VISIT').id,session_date],
          :order =>'encounter_datetime DESC,date_created DESC',:limit => 1)

        prescribe_drugs = encounter_tb_visit.observations.map{|obs| obs.to_s.squish.strip.upcase }.include? 'Prescribe drugs: Yes'.upcase rescue false

        if not prescribe_drugs
          encounter_tb_clinic_visit = Encounter.find(:first,:conditions =>["patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) = ?",
              patient.id,EncounterType.find_by_name('TB CLINIC VISIT').id,session_date],
            :order =>'encounter_datetime DESC,date_created DESC',:limit => 1)

          prescribe_drugs = encounter_tb_clinic_visit.observations.map{|obs| obs.to_s.squish.strip.upcase }.include? 'Prescribe drugs: Yes'.upcase rescue false
        end

        if tb_treatment_encounter.blank? and user_selected_activities.match(/Manage prescriptions/i)
          task.url = "/regimens/new?patient_id=#{patient.id}"
          return task
        elsif tb_treatment_encounter.blank? and not user_selected_activities.match(/Manage prescriptions/i)
          task.url = "/patients/show/#{patient.id}"
          return task
        end if prescribe_drugs



        art_treatment_encounter = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
          :joins => "INNER JOIN obs USING(encounter_id)",
          :conditions =>["DATE(encounter_datetime) = ? AND patient_id = ? AND encounter_type = ? AND concept_id = ?",
            session_date.to_date,patient.id,EncounterType.find_by_name(type).id,ConceptName.find_by_name('ARV regimen type').concept_id])

        encounter_hiv_clinic_consultation = Encounter.find(:first,:conditions =>["patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) = ?",
            patient.id,EncounterType.find_by_name('HIV CLINIC CONSULTATION').id,session_date],
          :order =>'encounter_datetime DESC,date_created DESC',:limit => 1)

        prescribe_drugs = false

        prescribe_drugs = encounter_hiv_clinic_consultation.observations.map{|obs| obs.to_s.squish.strip.upcase }.include? 'Prescribe drugs: Yes'.upcase rescue false

        if art_treatment_encounter.blank? and user_selected_activities.match(/Manage prescriptions/i)
          task.url = "/regimens/new?patient_id=#{patient.id}"
          return task
        elsif art_treatment_encounter.blank? and not user_selected_activities.match(/Manage prescriptions/i)
          task.url = "/patients/show/#{patient.id}"
          return task
        end if prescribe_drugs
      when 'DISPENSING'
        treatment = Encounter.find(:first,:conditions =>["patient_id = ? AND DATE(encounter_datetime) = ? AND encounter_type = ?",
            patient.id,session_date,EncounterType.find_by_name('TREATMENT').id])

        encounter = Encounter.find(:first,:conditions =>["patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) = ?",
            patient.id,EncounterType.find_by_name('DISPENSING').id,session_date],
          :order =>'encounter_datetime DESC,date_created DESC',:limit => 1)

        if encounter.blank? and user_selected_activities.match(/Manage drug dispensations/i)
          task.url = "/patients/treatment_dashboard/#{patient.id}"
          return task
        elsif encounter.blank? and not user_selected_activities.match(/Manage drug dispensations/i)
          task.url = "/patients/show/#{patient.id}"
          return task
        end if not treatment.blank?

        complete = DrugOrder.all_orders_complete(patient,session_date.to_date)

        if not complete and user_selected_activities.match(/Manage drug dispensations/i)
          task.url = "/patients/treatment_dashboard/#{patient.id}"
          return task
        elsif not complete and not user_selected_activities.match(/Manage drug dispensations/i)
          task.url = "/patients/show/#{patient.id}"
          return task
        end if not treatment.blank?

        appointment = Encounter.find(:first,:conditions =>["patient_id = ? AND
                        encounter_type = ? AND DATE(encounter_datetime) = ?",
            patient.id,EncounterType.find_by_name('APPOINTMENT').id,session_date],
          :order =>'encounter_datetime DESC,date_created DESC',:limit => 1)

        if complete and user_selected_activities.match(/Manage Appointments/i)
          start_date , end_date = DrugOrder.prescription_dates(patient,session_date.to_date)
          task.encounter_type = "Set Appointment date"
          task.url = "/encounters/new/appointment?end_date=#{end_date}&id=show&patient_id=#{patient.id}&start_date=#{start_date}"
          return task
        elsif complete and not user_selected_activities.match(/Manage Appointments/i)
          task.encounter_type = "Set Appointment date"
          task.url = "/patients/show/#{patient.id}"
          return task
        end if not treatment.blank? and appointment.blank?
      end
    end
    #task.encounter_type = 'Visit complete ...'
    task.encounter_type = 'NONE'
    task.url = "/patients/show/#{patient.id}"
    return task
  end

  def fast_track_next_form(location , patient , session_date = Date.today)
    task = (Task.first.nil?)? Task.new() : Task.first
    user_selected_activities = current_user.activities.collect{|a| a.upcase }.join(',') rescue []

    concept_id = ConceptName.find_by_name("Prescribe drugs").concept_id
    prescribe_drugs_question = Observation.find(:first,:conditions =>["person_id=? AND concept_id =? AND
              DATE(obs_datetime) =?", patient.id, concept_id, session_date])

    hiv_reception_enc = Encounter.find(:first,:conditions =>["patient_id = ? AND DATE(encounter_datetime) = ? AND
          encounter_type = ?", patient.id, session_date, EncounterType.find_by_name('HIV RECEPTION').id])

    adherence_enc = Encounter.find(:first,:conditions =>["patient_id = ? AND DATE(encounter_datetime) = ? AND encounter_type = ?",
        patient.id, session_date, EncounterType.find_by_name('ART ADHERENCE').id])

    treatment_enc = Encounter.find(:first,:conditions =>["patient_id = ? AND DATE(encounter_datetime) = ? AND encounter_type = ?",
        patient.id, session_date, EncounterType.find_by_name('TREATMENT').id])

    dispensation_enc = Encounter.find(:first,:conditions =>["patient_id = ? AND DATE(encounter_datetime) = ? AND encounter_type = ?",
        patient.id, session_date, EncounterType.find_by_name('DISPENSING').id])

    if hiv_reception_enc.blank?
      if (user_selected_activities.match(/Manage HIV reception visits/i))
        task.encounter_type = "HIV RECEPTION"
        task.url = "/encounters/new/hiv_reception?patient_id=#{patient.id}"
        return task
      else
        task.url = "/patients/show/#{patient.id}"
        return task
      end
    end

    if (adherence_enc.blank? )
      if (user_selected_activities.match(/Manage ART adherence/i))
        task.encounter_type = "ART ADHERENCE"
        task.url = "/encounters/new/art_adherence?patient_id=#{patient.id}"
        return task
      else
        task.url = "/patients/show/#{patient.id}"
        return task
      end
    end if not MedicationService.art_drug_given_before(patient,session_date).blank?

    unless prescribe_drugs_question.blank?

      if (prescribe_drugs_question.answer_string.squish.upcase == 'YES')
        if (treatment_enc.blank?)
          if (user_selected_activities.match(/Manage prescriptions/i))
            task.encounter_type = "TREATMENT"
            task.url = "/regimens/new?patient_id=#{patient.id}"
            return task
          else
            task.url = "/patients/show/#{patient.id}"
            return task
          end
        end

        if dispensation_enc.blank?
          if (user_selected_activities.match(/Manage drug dispensations/i))
            task.encounter_type = "DISPENSING"
            task.url = "/patients/treatment_dashboard/#{patient.id}"
            return task
          else
            task.url = "/patients/show/#{patient.id}"
            return task
          end
        end unless treatment_enc.blank?

      end

    end

    task.encounter_type = "NONE"
    task.url = "/patients/show/#{patient.id}"
    return task
  end

  def next_form(location , patient , session_date = Date.today)
    #for Oupatient departments
    task = (Task.first.nil?)? Task.new() : Task.first
    if location.name.match(/Outpatient/i)
      opd_reception = Encounter.find(:first,:conditions =>["patient_id = ? AND DATE(encounter_datetime) = ? AND encounter_type = ?",
          patient.id, session_date, EncounterType.find_by_name('OUTPATIENT RECEPTION').id])
      if opd_reception.blank?
        task.url = "/encounters/new/opd_reception?show&patient_id=#{patient.id}"
        task.encounter_type = 'OUTPATIENT RECEPTION'
      else
        task.encounter_type = 'NONE'
        task.url = "/patients/show/#{patient.id}"
      end
      return task
    end

    current_user_activities = current_user.activities
    if current_program_location == "TB program"
      return tb_next_form(location , patient , session_date)
    end

    if current_user_activities.blank?
      task.encounter_type = "NO TASKS SELECTED"
      task.url = "/patients/show/#{patient.id}"
      return task
    end

		pp = PatientProgram.find(:first, :joins => :location, :conditions => ["program_id = ? AND patient_id = ?", Program.find_by_concept_id(Concept.find_by_name('HIV PROGRAM').id).id,patient.id]).patient_states.last.program_workflow_state.concept.fullname	rescue ""

    current_day_encounters = Encounter.find(:all,
      :conditions =>["patient_id = ? AND DATE(encounter_datetime) = ?",
        patient.id,session_date.to_date]).map{|e|e.name.upcase}

    if current_day_encounters.include?("TB RECEPTION")
      return tb_next_form(location , patient , session_date)
    end

    #we get the sequence of clinic questions(encounters) form the GlobalProperty table
    #property: list.of.clinical.encounters.sequentially
    #property_value: ?

    #valid privileges for ART visit ....
    #1. Manage Vitals - VITALS
    #2. Manage pre ART visits - PART_FOLLOWUP
    #3. Manage HIV staging visits - HIV STAGING
    #4. Manage HIV reception visits - HIV RECEPTION
    #5. Manage HIV first visit - HIV CLINIC REGISTRATION
    #6. Manage drug dispensations - DISPENSING
    #7. Manage HIV clinic consultations - HIV CLINIC CONSULTATION
    #8. Manage TB reception visits -?
    #9. Manage prescriptions - TREATMENT
    #10. Manage appointments - APPOINTMENT
    #11. Manage ART adherence - ART ADHERENCE
    hiv_program_status = Patient.find_by_sql("
											SELECT patient_id, current_state_for_program(patient_id, 1, '#{session_date}') AS state, c.name as status
											FROM patient p INNER JOIN program_workflow_state pw ON pw.program_workflow_state_id = current_state_for_program(patient_id, 1, '#{session_date}')
											INNER JOIN concept_name c ON c.concept_id = pw.concept_id where p.patient_id = '#{patient.id}'").first.status rescue "Unknown"


    encounters_sequentially = CoreService.get_global_property_value('list.of.clinical.encounters.sequentially')

    encounters = encounters_sequentially.split(',')

    user_selected_activities = current_user.activities.collect{|a| a.upcase }.join(',') rescue []
    if encounters.blank? or user_selected_activities.blank?
      task.url = "/patients/show/#{patient.id}"
      return task
    end
    ############ FAST TRACK #################
    #fast_track_patient = false
    #latest_fast_track_answer = patient.person.observations.recent(1).question("FAST").first.answer_string.squish.upcase rescue nil
    #fast_track_patient = true if latest_fast_track_answer == 'YES'

    #fast_track_patient = false if (tb_suspected_or_confirmed?(patient, session_date) == true)
    #fast_track_patient = false if (is_patient_on_htn_treatment?(patient, session_date) == true)

    if (fast_track_patient?(patient, session_date) || fast_track_done_today(patient, session_date))
      #fast_track_done_today method: this is to for tracking a patient if the patient is a fast track after even the visit is done on that day
      return fast_track_next_form(location , patient , session_date)
    end
    ########### FAST TRACK END ##############

    art_reason = patient.person.observations.recent(1).question("REASON FOR ART ELIGIBILITY").all rescue nil
    reason_for_art = PatientService.reason_for_art_eligibility(patient)
    if not reason_for_art.blank? and reason_for_art.upcase == 'NONE'
      reason_for_art = nil
    end
    #raise encounters.to_yaml
    (encounters || []).each do | type |
      type =type.squish
		  next if pp.match(/patient\sdied/i)
			encounter_available = Encounter.find(:first,:conditions =>["patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) = ?",
          patient.id,EncounterType.find_by_name(type).id, session_date],
        :order =>'encounter_datetime DESC,date_created DESC',:limit => 1) rescue nil

      # next if encounter_available.nil?

      reception = Encounter.find(:first,:conditions =>["patient_id = ? AND DATE(encounter_datetime) = ? AND encounter_type = ?",
          patient.id,session_date,EncounterType.find_by_name('HIV RECEPTION').id]).observations.collect{| r | r.to_s}.join(',') rescue ''

      task.encounter_type = type
      case type
      when 'VITALS'
        if encounter_available.blank? and user_selected_activities.match(/Manage Vitals/i)
          task.url = "/encounters/new/vitals?patient_id=#{patient.id}"
          return task
        elsif encounter_available.blank? and not user_selected_activities.match(/Manage Vitals/i)
          task.url = "/patients/show/#{patient.id}"
          return task
        end if reception.match(/PATIENT PRESENT FOR CONSULTATION:  YES/i)
      when 'HIV CLINIC CONSULTATION'
        unless encounter_available.blank? and user_selected_activities.match(/Manage HIV clinic consultations/i)
          if (patient_has_stopped_fast_track_at_adherence?(patient, session_date))
            consultation_encounters_count = todays_consultation_encounters(patient, session_date)
            if (consultation_encounters_count == 1)
              task.url = "/encounters/new/hiv_clinic_consultation?patient_id=#{patient.id}"
              return task
            end
          end
        end

        if encounter_available.blank? and user_selected_activities.match(/Manage HIV clinic consultations/i)
          task.url = "/encounters/new/hiv_clinic_consultation?patient_id=#{patient.id}"
          return task
        elsif encounter_available.blank? and not user_selected_activities.match(/Manage HIV clinic consultations/i)
          task.url = "/patients/show/#{patient.id}"
          return task
        end

        #if a nurse has refered a patient to a doctor/clinic
        concept_id = ConceptName.find_by_name("Refer to ART clinician").concept_id
        ob = Observation.find(:first,:conditions =>["person_id = ? AND concept_id = ? AND obs_datetime >= ? AND obs_datetime <= ?",
            patient.id, concept_id, session_date, session_date.to_s + ' 23:59:59'],:order =>"obs_datetime DESC, date_created DESC")

        refer_to_clinician = ob.to_s.squish.upcase == 'Refer to ART clinician: yes'.upcase


        if current_user_roles.include?('Nurse')
          adherence_encounter_available = Encounter.find(:first,
            :conditions =>["patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) = ?",
              patient.id,EncounterType.find_by_name("ART ADHERENCE").id,session_date],
            :order =>'encounter_datetime DESC,date_created DESC',:limit => 1)

          arv_drugs_given = false
          MedicationService.art_drug_given_before(patient,session_date).each do |order|
            arv_drugs_given = true
            break
          end

          if arv_drugs_given
            if adherence_encounter_available.blank? and user_selected_activities.match(/Manage ART adherence/i)
              task.encounter_type = "ART ADHERENCE"
              task.url = "/encounters/new/art_adherence?show&patient_id=#{patient.id}"
              return task
            elsif adherence_encounter_available.blank? and not user_selected_activities.match(/Manage ART adherence/i)
              task.encounter_type = "ART ADHERENCE"
              task.url = "/patients/show/#{patient.id}"
              return task
            end if not MedicationService.art_drug_given_before(patient,session_date).blank?
          end
        end if refer_to_clinician


        if not encounter_available.blank? and refer_to_clinician
          task.url = "/patients/show/#{patient.id}"
          task.encounter_type = task.encounter_type + " (Clinician)"
          return task
        end if current_user_roles.include?('Nurse')

        roles = current_user_roles.join(',') rescue ''
        clinician_or_doctor = roles.match(/Clinician/i) or roles.match(/Doctor/i)

        if not encounter_available.blank? and refer_to_clinician

          if user_selected_activities.match(/Manage HIV clinic consultations/i)
            task.url = "/encounters/new/hiv_clinic_consultation?patient_id=#{patient.id}"
            task.encounter_type = task.encounter_type + " (Clinician)"
            return task
          elsif not user_selected_activities.match(/Manage HIV clinic consultations/i)
            task.url = "/patients/show/#{patient.id}"
            task.encounter_type = task.encounter_type + " (Clinician)"
            return task
          end
        end if clinician_or_doctor
      when 'HIV STAGING'
        next unless reason_for_art.blank?
        staging = session["#{patient.id}"]["#{session_date.to_date}"][:stage_patient] rescue []
        if ! staging.blank?
          next if staging == "No"
        end
        arv_drugs_given = false
        MedicationService.drug_given_before(patient,session_date).each do |order|
          next unless MedicationService.arv(order.drug_order.drug)
          arv_drugs_given = true
        end
        next if arv_drugs_given
        if encounter_available.blank? and user_selected_activities.match(/Manage HIV staging visits/i)
          task.url = "/encounters/new/hiv_staging?show&patient_id=#{patient.id}"
          return task
        elsif encounter_available.blank? and not user_selected_activities.match(/Manage HIV staging visits/i)
          task.url = "/patients/show/#{patient.id}"
          return task
        end if reason_for_art.nil? or reason_for_art.blank? or hiv_program_status == "Pre-ART (Continue)"
      when 'HIV RECEPTION'
        encounter_hiv_clinic_registration = Encounter.find(:first,:conditions =>["patient_id = ? AND encounter_type = ?",
            patient.id,EncounterType.find_by_name('HIV CLINIC REGISTRATION').id],
          :order =>'encounter_datetime DESC',:limit => 1)
        transfer_in = encounter_hiv_clinic_registration.observations.collect{|r|r.to_s.strip.upcase}.include?('HAS TRANSFER LETTER: YES'.upcase) rescue []
        hiv_staging = Encounter.find(:first,:conditions =>["patient_id = ? AND encounter_type = ?",
            patient.id,EncounterType.find_by_name('HIV STAGING').id],:order => "encounter_datetime DESC")

        if transfer_in and hiv_staging.blank? and user_selected_activities.match(/Manage HIV first visits/i)
          task.url = "/encounters/new/hiv_staging?show&patient_id=#{patient.id}"
          task.encounter_type = 'HIV STAGING'
          return task
        elsif encounter_available.blank? and user_selected_activities.match(/Manage HIV reception visits/i)
          task.url = "/encounters/new/hiv_reception?show&patient_id=#{patient.id}"
          return task
        elsif encounter_available.blank? and not user_selected_activities.match(/Manage HIV reception visits/i)
          task.url = "/patients/show/#{patient.id}"
          return task
        end
      when 'HIV CLINIC REGISTRATION'
        #encounter_hiv_clinic_registration = Encounter.find(:first,:conditions =>["patient_id = ? AND encounter_type = ?",
        #                              patient.id,EncounterType.find_by_name(type).id],
        #                             :order =>'encounter_datetime DESC',:limit => 1)

        hiv_clinic_registration = require_hiv_clinic_registration(patient)

        if hiv_clinic_registration and user_selected_activities.match(/Manage HIV first visits/i)
          task.url = "/encounters/new/hiv_clinic_registration?show&patient_id=#{patient.id}"
          return task
        elsif hiv_clinic_registration and not user_selected_activities.match(/Manage HIV first visits/i)
          task.url = "/patients/show/#{patient.id}"
          return task
        end
      when 'DISPENSING'
        encounter_hiv_clinic_consultation = Encounter.find(:first,:conditions =>["patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) = ?",
            patient.id,EncounterType.find_by_name('HIV CLINIC CONSULTATION').id,session_date],
          :order =>'encounter_datetime DESC,date_created DESC',:limit => 1)
        next unless encounter_hiv_clinic_consultation.observations.map{|obs| obs.to_s.strip.upcase }.include? 'Prescribe drugs:  Yes'.upcase

        treatment = Encounter.find(:first,:conditions =>["patient_id = ? AND DATE(encounter_datetime) = ? AND encounter_type = ?",
            patient.id,session_date,EncounterType.find_by_name('TREATMENT').id])

        if encounter_available.blank? and user_selected_activities.match(/Manage drug dispensations/i)
          task.url = "/patients/treatment_dashboard/#{patient.id}"
          return task
        elsif encounter_available.blank? and not user_selected_activities.match(/Manage drug dispensations/i)
          task.url = "/patients/show/#{patient.id}"
          return task
        end if not treatment.blank?
      when 'TREATMENT'
        encounter_hiv_clinic_consultation = Encounter.find(:first,:conditions =>["patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) = ?",
            patient.id,EncounterType.find_by_name('HIV CLINIC CONSULTATION').id,session_date],
          :order =>'encounter_datetime DESC,date_created DESC',:limit => 1)

        concept_id = ConceptName.find_by_name("Prescribe drugs").concept_id
        ob = Observation.find(:first,:conditions =>["person_id=? AND concept_id =?",
            patient.id,concept_id],:order =>"obs_datetime DESC,date_created DESC")

        prescribe_arvs = ob.to_s.squish.upcase == 'Prescribe drugs: Yes'.upcase

        concept_id = ConceptName.find_by_name("Refer to ART clinician").concept_id
        ob = Observation.find(:first,:conditions =>["person_id=? AND concept_id =?",
            patient.id,concept_id],:order =>"obs_datetime DESC,date_created DESC")

        not_refer_to_clinician = ob.to_s.squish.upcase == 'Refer to ART clinician: No'.upcase

        if prescribe_arvs and not_refer_to_clinician
          show_treatment = true
        else
          show_treatment = false
        end

        if encounter_available.blank? and user_selected_activities.match(/Manage prescriptions/i)
          task.url = "/regimens/new?patient_id=#{patient.id}"
          return task
        elsif encounter_available.blank? and not user_selected_activities.match(/Manage prescriptions/i)
          task.url = "/patients/show/#{patient.id}"
          return task
        end if show_treatment
      when 'ART ADHERENCE'
        arv_drugs_given = false
        MedicationService.art_drug_given_before(patient,session_date).each do |order|
          arv_drugs_given = true
          break
        end

        MedicationService.art_drug_prescribed_before(patient,session_date).each do |order|
          arv_drugs_given = true
          break
        end unless arv_drugs_given

        next unless arv_drugs_given

        if arv_drugs_given
          if encounter_available.blank? and user_selected_activities.match(/Manage ART adherence/i)
            task.url = "/encounters/new/art_adherence?show&patient_id=#{patient.id}"
            return task
          elsif encounter_available.blank? and not user_selected_activities.match(/Manage ART adherence/i)
            task.url = "/patients/show/#{patient.id}"
            return task
          end
        end
      end
    end
    #task.encounter_type = 'Visit complete ...'
    task.encounter_type = 'NONE'
    task.url = "/patients/show/#{patient.id}"
    return task
  end

  # Try to find the next task for the patient at the given location
  def main_next_task(location, patient, session_date = Date.today)

    if use_user_selected_activities
      begin
        return next_form(location , patient , session_date)
      rescue
        t = Task.last
        t.encounter_type = 'None'
        t.url = "/patients/show/#{patient.id}"
        return t
      end
    end
    all_tasks = Task.all(:order => 'sort_weight ASC')
    todays_encounters = patient.encounters.find_by_date(session_date)
    todays_encounter_types = todays_encounters.map{|e| e.type.name rescue ''}.uniq rescue []
    all_tasks.each do |task|
      next if todays_encounters.map{ | e | e.name }.include?(task.encounter_type)
      # Is the task for this location?
      next unless task.location.blank? || task.location == '*' || location.name.match(/#{task.location}/)

      # Have we already run this task?
      next if task.encounter_type.present? && todays_encounter_types.include?(task.encounter_type)

      # By default, we don't want to skip this task
      skip = false

      # Skip this task if this is a gender specific task and the gender does not match?
      # For example, if this is a female specific check and the patient is not female, we want to skip it
      skip = true if task.gender.present? && patient.person.gender != task.gender

      # Check for an observation made today with a specific value, skip this task unless that observation exists
      # For example, if this task is the art_clinician task we want to skip it unless REFER TO CLINICIAN = yes
      if task.has_obs_concept_id.present?
        if (task.has_obs_scope.blank? || task.has_obs_scope == 'TODAY')
          obs = Observation.first(:conditions => [
              'encounter_id IN (?) AND concept_id = ? AND (value_coded = ? OR value_drug = ? OR value_datetime = ? OR value_numeric = ? OR value_text = ?)',
              todays_encounters.map(&:encounter_id),
              task.has_obs_concept_id,
              task.has_obs_value_coded,
              task.has_obs_value_drug,
              task.has_obs_value_datetime,
              task.has_obs_value_numeric,
              task.has_obs_value_text])
        end

        # Only the most recent obs
        # For example, if there are mutliple REFER TO CLINICIAN = yes, than only take the most recent one
        if (task.has_obs_scope == 'RECENT')
          o = patient.person.observations.recent(1).first(:conditions => ['encounter_id IN (?) AND concept_id =? AND DATE(obs_datetime)=?', todays_encounters.map(&:encounter_id), task.has_obs_concept_id,session_date])
          obs = 0 if (!o.nil? && o.value_coded == task.has_obs_value_coded && o.value_drug == task.has_obs_value_drug &&
              o.value_datetime == task.has_obs_value_datetime && o.value_numeric == task.has_obs_value_numeric &&
              o.value_text == task.has_obs_value_text )
        end

        skip = true unless obs.present?
      end

      # Check for a particular current order type, skip this task unless the order exists
      # For example, if this task is /dispensation/new we want to skip it if there is not already a drug order
      if task.has_order_type_id.present?
        skip = true unless Order.unfinished.first(:conditions => {:order_type_id => task.has_order_type_id}).present?
      end

      # Check for a particular program at this location, skip this task if the patient is not in the required program
      # For example if this is the hiv_reception task, we want to skip it if the patient is not currently in the HIV PROGRAM
      if task.has_program_id.present? && (task.has_program_workflow_state_id.blank? || task.has_program_workflow_state_id == '*')
        patient_program = PatientProgram.current.first(:conditions => [
            'patient_program.patient_id = ? AND patient_program.location_id = ? AND patient_program.program_id = ?',
            patient.patient_id,
            Location.current_health_center.location_id,
            task.has_program_id])
        skip = true unless patient_program.present?
      end

      # Check for a particular program state at this location, skip this task if the patient does not have the required program/state
      # For example if this is the art_followup task, we want to skip it if the patient is not currently in the HIV PROGRAM with the state FOLLOWING
      if task.has_program_id.present? && task.has_program_workflow_state_id.present?
        patient_state = PatientState.current.first(:conditions => [
            'patient_program.patient_id = ? AND patient_program.location_id = ? AND patient_program.program_id = ? AND patient_state.state = ?',
            patient.patient_id,
            Location.current_health_center.location_id,
            task.has_program_id,
            task.has_program_workflow_state_id], :include => :patient_program)
        skip = true unless patient_state.present?
      end

      # Check for a particular relationship, skip this task if the patient does not have the relationship
      # For example, if there is a CHW training update, skip this task if the person is not a CHW
      if task.has_relationship_type_id.present?
        skip = true unless patient.relationships.first(
          :conditions => ['relationship.relationship = ?', task.has_relationship_type_id])
      end

      # Check for a particular identifier at this location
      # For example, this patient can only get to the Pre-ART room if they already have a pre-ART number, otherwise they need to go back to registration
      if task.has_identifier_type_id.present?
        skip = true unless patient.patient_identifiers.first(
          :conditions => ['patient_identifier.identifier_type = ? AND patient_identifier.location_id = ?', task.has_identifier_type_id, Location.current_health_center.location_id])
      end

      if task.has_encounter_type_today.present?
        enc = nil
        if todays_encounters.collect{|e|e.name}.include?(task.has_encounter_type_today)
          enc = task.has_encounter_type_today
        end
        skip = true unless enc.present?
      end

      arv_drugs_given = false
      MedicationService.art_drug_given_before(patient,session_date).each do |order|
        arv_drugs_given = true
        break
      end

      if task.encounter_type == 'ART ADHERENCE' and not arv_drugs_given
        skip = true
      end

      if task.encounter_type == 'HIV CLINIC CONSULTATION' and (reason_for_art_eligibility(patient).blank? or reason_for_art_eligibility(patient).match(/unknown/i))
        skip = true
      end

      if task.encounter_type == 'HIV STAGING' and not (reason_for_art_eligibility(patient).blank? or reason_for_art_eligibility(patient).match(/unknown/i))
        skip = true
      end

      # Reverse the condition if the task wants the negative (for example, if the patient doesn't have a specific program yet, then run this task)
      skip = !skip if task.skip_if_has == 1

      # We need to skip this task for some reason
      next if skip

      if location.name.match(/HIV|ART/i) and not location.name.match(/Outpatient/i)
        task = validate_task(patient,task,location,session_date.to_date)
      end

      # Nothing failed, this is the next task, lets replace any macros
      task.url = task.url.gsub(/\{patient\}/, "#{patient.patient_id}")
      task.url = task.url.gsub(/\{person\}/, "#{patient.person.person_id rescue nil}")
      task.url = task.url.gsub(/\{location\}/, "#{location.location_id}")
      Rails.logger.debug "next_task: #{task.id} - #{task.description}"

      return task
    end
  end


  def validate_task(patient, task, location, session_date = Date.today)
    #return task unless task.has_program_id == 1
    return task if task.encounter_type == 'REGISTRATION'
    # allow EID patients at HIV clinic, but don't validate tasks
    return task if task.has_program_id == 4

    #check if the latest HIV program is closed - if yes, the app should redirect the user to update state screen
    if patient.encounters.find_by_encounter_type(EncounterType.find_by_name('HIV CLINIC REGISTRATION').id)
      latest_hiv_program = [] ; patient.patient_programs.collect{ | p |next unless p.program_id == 1 ; latest_hiv_program << p }
      if latest_hiv_program.last.closed?
        task.url = '/patients/programs_dashboard/{patient}' ; task.encounter_type = 'Program enrolment'
        return task
      end rescue nil
    end

    return task if task.url == "/patients/show/{patient}"

    art_encounters = ['HIV CLINIC REGISTRATION','HIV RECEPTION','VITALS','HIV STAGING','HIV CLINIC CONSULTATION','ART ADHERENCE','TREATMENT','DISPENSING']

    #if the following happens - that means the patient is a transfer in and the reception are trying to stage from the transfer in sheet
    if task.encounter_type == 'HIV STAGING' and location.name.match(/RECEPTION/i)
      return task
    end

    #if the following happens - that means the patient was refered to see a clinician
    if task.description.match(/REFER/i) and location.name.match(/Clinician/i)
      return task
    end

    if patient.encounters.find_by_encounter_type(EncounterType.find_by_name(art_encounters[0]).id).blank? and task.encounter_type != art_encounters[0]
      task.url = "/patients/summary?patient_id={patient}&skipped={encounter_type}"
      task.url = task.url.gsub(/\{encounter_type\}/, "#{art_encounters[0].gsub(' ','_')}")
      return task
    elsif patient.encounters.find_by_encounter_type(EncounterType.find_by_name(art_encounters[0]).id).blank? and task.encounter_type == art_encounters[0]
      return task
    end

    hiv_reception = Encounter.find(:first,
      :conditions =>["patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) = ?",
        patient.id,EncounterType.find_by_name(art_encounters[1]).id,session_date],
      :order =>'encounter_datetime DESC')

    if hiv_reception.blank? and task.encounter_type != art_encounters[1]
      task.url = "/patients/summary?patient_id={patient}&skipped={encounter_type}"
      task.url = task.url.gsub(/\{encounter_type\}/, "#{art_encounters[1].gsub(' ','_')}")
      return task
    elsif hiv_reception.blank? and task.encounter_type == art_encounters[1]
      return task
    end

    reception = Encounter.find(:first,:conditions =>["patient_id = ? AND DATE(encounter_datetime) = ? AND encounter_type = ?",
        patient.id,session_date,EncounterType.find_by_name(art_encounters[1]).id]).collect{|r|r.to_s}.join(',') rescue ''

    if reception.match(/PATIENT PRESENT FOR CONSULTATION:  YES/i)
      vitals = Encounter.find(:first,
        :conditions =>["patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) = ?",
          patient.id,EncounterType.find_by_name(art_encounters[2]).id,session_date],
        :order =>'encounter_datetime DESC')

      if vitals.blank? and task.encounter_type != art_encounters[2]
        task.url = "/patients/summary?patient_id={patient}&skipped={encounter_type}"
        task.url = task.url.gsub(/\{encounter_type\}/, "#{art_encounters[2].gsub(' ','_')}")
        return task
      elsif vitals.blank? and task.encounter_type == art_encounters[2]
        return task
      end
    end

    hiv_staging = patient.encounters.find_by_encounter_type(EncounterType.find_by_name(art_encounters[3]).id)
    art_reason = patient.person.observations.recent(1).question("REASON FOR ART ELIGIBILITY").all rescue nil
    reasons = art_reason.map{|c|ConceptName.find(c.value_coded_name_id).name}.join(',') rescue ''

    if ((reasons.blank?) and (task.encounter_type == art_encounters[3]))
      return task
    elsif hiv_staging.blank? and task.encounter_type != art_encounters[3]
      task.url = "/patients/summary?patient_id={patient}&skipped={encounter_type}"
      task.url = task.url.gsub(/\{encounter_type\}/, "#{art_encounters[3].gsub(' ','_')}")
      return task
    elsif hiv_staging.blank? and task.encounter_type == art_encounters[3]
      return task
    end

    pre_art_visit = Encounter.find(:first,
      :conditions =>["patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) = ?",
        patient.id,EncounterType.find_by_name('PART_FOLLOWUP').id,session_date],
      :order =>'encounter_datetime DESC',:limit => 1)

    if pre_art_visit.blank?
      art_visit = Encounter.find(:first,
        :conditions =>["patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) = ?",
          patient.id,EncounterType.find_by_name(art_encounters[4]).id,session_date],
        :order =>'encounter_datetime DESC',:limit => 1)

      if art_visit.blank? and task.encounter_type != art_encounters[4]
        #checks if we need to do a pre art visit
        if task.encounter_type == 'PART_FOLLOWUP'
          return task
        elsif reasons.upcase == 'UNKNOWN' or reasons.blank?
          task.url = "/patients/summary?patient_id={patient}&skipped={encounter_type}"
          return task
        end
        task.url = "/patients/summary?patient_id={patient}&skipped={encounter_type}"
        task.url = task.url.gsub(/\{encounter_type\}/, "#{art_encounters[4].gsub(' ','_')}")
        return task
      elsif art_visit.blank? and task.encounter_type == art_encounters[4]
        return task
      end
    end

    arv_drugs_given = false
    MedicationService.drug_given_before(patient,session_date).each do |order|
      next unless MedicationService.arv(order.drug_order.drug)
      arv_drugs_given = true
    end

    if arv_drugs_given
      art_adherance = Encounter.find(:first,
        :conditions =>["patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) = ?",
          patient.id,EncounterType.find_by_name(art_encounters[5]).id,session_date],
        :order =>'encounter_datetime DESC',:limit => 1)

      if art_adherance.blank? and task.encounter_type != art_encounters[5]
        task.url = "/patients/summary?patient_id={patient}&skipped={encounter_type}"
        task.url = task.url.gsub(/\{encounter_type\}/, "#{art_encounters[5].gsub(' ','_')}")
        return task
      elsif art_adherance.blank? and task.encounter_type == art_encounters[5]
        return task
      end
    end

    if PatientService.prescribe_arv_this_visit(patient, session_date)
      art_treatment = Encounter.find(:first,
        :conditions =>["patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) = ?",
          patient.id,EncounterType.find_by_name(art_encounters[6]).id,session_date],
        :order =>'encounter_datetime DESC',:limit => 1)
      if art_treatment.blank? and task.encounter_type != art_encounters[6]
        task.url = "/patients/summary?patient_id={patient}&skipped={encounter_type}"
        task.url = task.url.gsub(/\{encounter_type\}/, "#{art_encounters[6].gsub(' ','_')}")
        return task
      elsif art_treatment.blank? and task.encounter_type == art_encounters[6]
        return task
      end
    end

    task
  end


  def latest_state(patient_obj,visit_date)
    program_id = Program.find_by_name('HIV PROGRAM').id
    patient_state = PatientState.find(:first,
      :joins => "INNER JOIN patient_program p
       ON p.patient_program_id = patient_state.patient_program_id",
      :conditions =>["patient_state.voided = 0 AND p.voided = 0
       AND p.program_id = ? AND start_date <= ? AND p.patient_id =?",
        program_id,visit_date.to_date,patient_obj.id],
      :order => "start_date DESC, date_created DESC")

    return if patient_state.blank?
    ConceptName.find_by_concept_id(patient_state.program_workflow_state.concept_id).name
  end

	def require_hiv_clinic_registration(patient_obj = nil)
		require_registration = false
		patient = patient_obj || find_patient

		hiv_clinic_registration = Encounter.find(:first,:conditions =>["patient_id = ?
		              AND encounter_type = ?",patient.id,
        EncounterType.find_by_name("HIV CLINIC REGISTRATION").id],
      :order =>'encounter_datetime DESC,date_created DESC')

		require_registration = true if hiv_clinic_registration.blank?

		if !require_registration
			session_date = session[:datetime].to_date rescue Date.today

			current_outcome = latest_state(patient, session_date) || ""

			on_art_before = has_patient_been_on_art_before(patient)

			if current_outcome.match(/Transferred out/i)
				#if on_art_before
        require_registration = false
				#else
				#	require_registration = true
				#end
			end
		end
		return require_registration
	end

  def what_app?
    if current_user.activities.include?('Manage Lab Orders') or current_user.activities.include?('Manage Lab Results') or
        current_user.activities.include?('Manage Sputum Submissions') or current_user.activities.include?('Manage TB Clinic Visits') or
        current_user.activities.include?('Manage TB Reception Visits') or current_user.activities.include?('Manage TB Registration Visits') or
        current_user.activities.include?('Manage HIV Status Visits')
      'TB-ART'
    else
      'ART'
    end
  end

  def confirm_before_creating
    property = GlobalProperty.find_by_property("confirm.before.creating")
    property.property_value == 'true' rescue false
  end

  def vl_routine_check_activated
    GlobalProperty.find_by_property("activate.vl.routine.check").property_value.to_s == "true" rescue false
  end

  def cervical_cancer_screening_activated
    GlobalProperty.find_by_property("activate.cervical.cancer.screening").property_value.to_s == "true" rescue false
  end

  def patient_present(patient_id, date = Date.today)
    start_date = date.strftime("%Y-%m-%d 00:00:00")
    end_date = date.strftime("%Y-%m-%d 23:59:59")
    reception = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
      :conditions =>["patient_id = ? AND DATE(encounter_datetime) = ? AND encounter_type = ?
	AND encounter_datetime >= ? AND encounter_datetime <=?",patient_id,date,
        EncounterType.find_by_name('HIV RECEPTION').id,start_date,end_date])

    reception = reception.observations.collect{|r|r.to_s.squish}.join(',') rescue ''
    patient_present = reception.match(/PATIENT PRESENT FOR CONSULTATION: YES/i)
    return patient_present
  end

  def check_htn_workflow(patient, task)
    if not task.url.match(/VITALS/i) and not task.url.match(/REGIMENS/i) and not (task.url.match(/SHOW/i) && task.encounter_type == "NONE")
      return task
    end
    #This function is for managing interaction with HTN
    session_date = (session[:datetime].to_date) rescue Date.today

    referred_to_clinician = (Observation.last(:conditions => ["person_id = ? AND voided = 0
                          AND concept_id = ? AND obs_datetime BETWEEN ? AND ?",
          patient.patient_id,ConceptName.find_by_name("REFER PATIENT TO CLINICIAN").concept_id,
          session_date.strftime('%Y-%m-%d 00:00:00'),
          session_date.strftime('%Y-%m-%d 23:59:59')
        ]).answer_string.downcase.strip rescue nil) == "yes"

    referred_to_anc = (Observation.last(:conditions => ["person_id = ?
                    AND voided = 0 AND concept_id = ? AND obs_datetime BETWEEN ? AND ?",
          patient.patient_id,ConceptName.find_by_name("REFER TO ANC").concept_id,
          session_date.strftime('%Y-%m-%d 00:00:00'),
          session_date.strftime('%Y-%m-%d 23:59:59')
        ]).answer_string.downcase.strip rescue nil) == "yes"

    todays_encounters = patient.encounters.find_by_date(session_date)
    sbp_threshold = CoreService.get_global_property_value("htn.systolic.threshold").to_i
    dbp_threshold = CoreService.get_global_property_value("htn.diastolic.threshold").to_i
    if task.present? && task.url.present?
      #patients eligible for HTN will have their vitals taken with HTN module
      if task.url.match(/VITALS/i)
        return Task.new( :url=> "/htn_encounter/vitals?patient_id=#{patient.id}", :encounter_type => "Vitals")
      elsif task.url.match(/REGIMENS/i) || (task.url.match(/SHOW/i) && task.encounter_type == "NONE")
        #Alert and BP mgmt for patients on HTN or with two high BP readings
        bp = patient.current_bp((session[:datetime] || Time.now()))
        bp_management_done = todays_encounters.map{ | e | e.name }.include?("HYPERTENSION MANAGEMENT")
        medical_history = todays_encounters.map{ | e | e.name }.include?("MEDICAL HISTORY")

        #>>>>>>>>>>>>>>>>>BP INITIAL VISIT ENCOUNTER>>>>>>>>>>>>>>>>>>>>
        treatment_status_concept_id = Concept.find_by_name("TREATMENT STATUS").id
        bp_drugs_started = Observation.find(:last, :conditions => ["person_id =? AND concept_id =? AND
            value_text REGEXP ?", patient.id, treatment_status_concept_id, "BP Drugs started"])
        transfer_obs =  Observation.find(:last, :conditions => ["person_id =? AND concept_id =?",
            patient.id, Concept.find_by_name('TRANSFERRED').id]
        )
        unless bp_drugs_started.blank?
          if ((!bp[0].blank? && bp[0] <= sbp_threshold) && (!bp[1].blank?  && bp[1] <= dbp_threshold)) #Normal BP
            return Task.new(:url => "/htn_encounter/bp_management?patient_id=#{patient.id}",
              :encounter_type => "HYPERTENSION MANAGEMENT")
          end if transfer_obs.blank?
        end

        #>>>>>>>>>>>>>>>>>END>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

        #Check if latest BP was high for alert
        if !bp.blank? && todays_encounters.map{ | e | e.name }.count("VITALS") == 1
          if !bp_management_done && !medical_history && ((!bp[0].blank? && bp[0] > sbp_threshold) || (!bp[1].blank?  && bp[1] > dbp_threshold))
            return Task.new(:url => "/htn_encounter/bp_alert?patient_id=#{patient.id}", :encounter_type => "BP Alert")
          elsif !bp_management_done && medical_history && ((!bp[0].blank? && bp[0] > sbp_threshold) || (!bp[1].blank?  && bp[1] > dbp_threshold))
            if (referred_to_clinician && (current_user_roles.include?('Clinician') || current_user_roles.include?('Doctor')))
              return Task.new(:url => "/htn_encounter/bp_management?patient_id=#{patient.id}",
                :encounter_type => "HYPERTENSION MANAGEMENT")
            elsif !referred_to_clinician
              return Task.new(:url => "/htn_encounter/bp_management?patient_id=#{patient.id}",
                :encounter_type => "HYPERTENSION MANAGEMENT")
            else
              return Task.new(:url => "/patients/show/#{patient.id}",
                :encounter_type => "HYPERTENSION MANAGEMENT")
            end
          end
        end
        if !bp.blank? && ((!bp[0].blank? && bp[0] > sbp_threshold) || (!bp[1].blank?  && bp[1] > dbp_threshold)) && !bp_management_done
          unless referred_to_anc
            if (referred_to_clinician && (current_user_roles.include?('Clinician') || current_user_roles.include?('Doctor')))
              return Task.new(:url => "/htn_encounter/bp_management?patient_id=#{patient.id}",
                :encounter_type => "HYPERTENSION MANAGEMENT")
            elsif !referred_to_clinician
              return Task.new(:url => "/htn_encounter/bp_management?patient_id=#{patient.id}",
                :encounter_type => "HYPERTENSION MANAGEMENT")
            else
              return Task.new(:url => "/patients/show/#{patient.id}",
                :encounter_type => "HYPERTENSION MANAGEMENT")
            end
          end
        end

        if !bp.blank? && !bp_management_done && patient.programs.map{|x| x.name}.include?("HYPERTENSION PROGRAM")

          plan = Observation.find(:last,
            :conditions => ["person_id = ? AND concept_id = ?
                             AND obs_datetime <= ?",patient.id,Concept.find_by_name('Plan').id,
              (session[:datetime].to_date rescue Time.now().to_date).strftime('%Y-%m-%d 23:59:59')],
            :order => "obs_datetime DESC")

          unless (plan.blank? || plan.value_text.match(/ANNUAL/i)) && !referred_to_anc
            return Task.new(:url => "/htn_encounter/bp_management?patient_id=#{patient.id}",
              :encounter_type => "HYPERTENSION MANAGEMENT")
          end
        end

        #If BP was not high, check if patient is on BP treatment. This check may be redudant
        unless referred_to_anc
          if is_patient_on_htn_treatment?(patient, (session[:datetime].to_date rescue Time.now().to_date)) && !bp_management_done

            if (referred_to_clinician && (current_user_roles.include?('Clinician') || current_user_roles.include?('Doctor')))
              return Task.new(:url => "/htn_encounter/bp_management?patient_id=#{patient.id}",
                :encounter_type => "HYPERTENSION MANAGEMENT")
            elsif !referred_to_clinician
              return Task.new(:url => "/htn_encounter/bp_management?patient_id=#{patient.id}",
                :encounter_type => "HYPERTENSION MANAGEMENT")
            else
              return Task.new(:url => "/patients/show/#{patient.id}",
                :encounter_type => "HYPERTENSION MANAGEMENT")
            end
          end
        end
      end
    end
    return task
  end

  def is_patient_on_htn_treatment?(patient, date)
    if patient.programs.map{|x| x.name}.include?("HYPERTENSION PROGRAM")
      htn_program_id = Program.find_by_name("HYPERTENSION PROGRAM").id
      program = PatientProgram.find(:last,:conditions => ["patient_id = ? AND program_id = ? AND date_enrolled <= ?",
          patient.id,htn_program_id, date])
      unless program.blank?
        state = PatientState.find(:last, :conditions => ["patient_program_id = ? AND start_date <= ? ", program.id, date]) rescue nil
        current_state = ConceptName.find_by_concept_id(state.program_workflow_state.concept_id).name rescue ""
        if current_state.upcase == "ON TREATMENT"
          return true
        end
      end
    end
    return false
  end

  def military_ranks
    ranks = ["Second Lieutenant", "First Lieutenant", "Captain", "Major", "Lieutenant Colonel",
      "Colonel", "Brigadier General", "Major General", "Lieutenant General", "General"
    ]
    return ranks
  end
  
end
