class PatientsController < GenericPatientsController
  
  def exitcare_dashboard
    @patient = Patient.find(params[:id])
    @patient_bean = PatientService.get_patient(@patient.person)
    @reason_for_art_eligibility = PatientService.reason_for_art_eligibility(@patient)
    @arv_number = PatientService.get_patient_identifier(@patient, 'ARV Number')
    @exit_states = concept_set("EXIT FROM CARE").flatten.uniq!
    @exit_states.delete("Treatment never started") if CoreService.get_global_property_value('mpc.lighthouse.states') == false
    render :template => 'dashboards/exitcare_dashboard.rhtml', :layout => false
  end

  def exitcare
    @programs = @patient.patient_programs.all
    @restricted = ProgramLocationRestriction.all(:conditions => {:location_id => Location.current_health_center.id })
    @restricted.each do |restriction|
      @programs = restriction.filter_programs(@programs)
    end
    render :template => 'dashboards/exitcare_tab', :layout => false
  end
  def exitcare_history
    @patient = Patient.find(params[:patient_id])
    encounter_type = EncounterType.find_by_name("EXIT FROM HIV CARE").id

    @encounters = Encounter.find(:all,  
      :conditions => [" patient_id = ? AND encounter_type = ?",
        @patient.id, encounter_type])
    @creator_name = {}
    @encounters.each do |encounter|
      id = encounter.creator
      user_name = User.find(id).person.names.first
      @creator_name[id] = '(' + user_name.given_name.first + '. ' + user_name.family_name + ')'
    end
  
    render :template => 'dashboards/exitcare_tab', :layout => false
  end

  def edit_tb_number
    if request.post?
      @number = params[:current]
      @patient_id = params[:id]
      numbers_array = params[:tb_number].chars.each_slice(4).map(&:join)
      x = numbers_array.length - 1
      year = numbers_array[0].to_i
      surfix = ""
      (1..x).each { |i| surfix = "#{surfix}#{numbers_array[i].squish}" }
      if year > Date.today.year || surfix.to_i < 1
        #flash[:notice] = "Date can not be greater than current year Or number can not be 0"
        render :template => "people/find_by_tb_number" and return
      end
      if PatientIdentifier.site_prefix == "MPC"
        prefix = "LL"
      else
        prefix = PatientIdentifier.site_prefix
      end
      tb_number = "#{prefix}-TB #{year} #{surfix.to_i}"
      people = PatientIdentifier.find_by_sql("SELECT * FROM patient_identifier
                WHERE REPLACE(identifier, ' ', '') = REPLACE('#{tb_number}', ' ', '') AND voided = 0 ")
      if people.length > 0
        flash[:notice] = "Patient found with number #{tb_number}" 
        render :template => "people/find_by_tb_number" and return
      else
        people = PatientIdentifier.find_by_sql("SELECT * FROM patient_identifier
                WHERE REPLACE(identifier, ' ', '') = REPLACE('#{@number}', ' ', '')
                AND voided = 0 AND identifier_type = 7 AND patient_id = #{@patient_id}").first
        people.identifier = tb_number
        people.save!
        redirect_to "/patients/tb_treatment_card?patient_id=#{@patient_id}" and return
      end
    else
      @number = params[:number]
      @patient_id = params[:id]
      render :template => "people/find_by_tb_number"
    end
  end

  def patient_transfer_out_label(patient_id)
    date = session[:datetime].to_date rescue Date.today
    patient = Patient.find(patient_id)
    demographics = mastercard_demographics(patient)
   
    who_stage = demographics.reason_for_art_eligibility 
    initial_staging_conditions = demographics.who_clinical_conditions.split(';')
    destination = demographics.transferred_out_to
   
    label = ZebraPrinter::Label.new(776, 329, 'T')
    label.line_spacing = 0
    label.top_margin = 30
    label.bottom_margin = 30
    label.left_margin = 25
    label.x = 25
    label.y = 30
    label.font_size = 3
    label.font_horizontal_multiplier = 1
    label.font_vertical_multiplier = 1
   
    # 25, 30
    # Patient personanl data 
    label.draw_multi_text("#{Location.current_health_center.name} transfer out label", {:font_reverse => true})
    label.draw_multi_text("To #{destination}", {:font_reverse => false}) unless destination.blank?
    label.draw_multi_text("ARV number: #{demographics.arv_number}", {:font_reverse => true})
    label.draw_multi_text("Name: #{demographics.name} (#{demographics.sex.first})\nAge: #{demographics.age}", {:font_reverse => false})

    # Print information on Diagnosis!
    art_start_date = PatientService.date_antiretrovirals_started(patient).strftime("%d-%b-%Y") rescue nil
    label.draw_multi_text("Stage defining conditions:", {:font_reverse => true})
    label.draw_multi_text("Reason for starting: #{who_stage}", {:font_reverse => false})
    label.draw_multi_text("ART start date: #{art_start_date}",{:font_reverse => false})
    label.draw_multi_text("Other diagnosis:", {:font_reverse => true})
    # !!!! TODO
    staging_conditions = ""
    count = 1
    initial_staging_conditions.each{|condition|
      if staging_conditions.blank?
        staging_conditions = "(#{count}) #{condition}" unless condition.blank?
      else
        staging_conditions+= " (#{count+=1}) #{condition}" unless condition.blank?
      end
    }
    label.draw_multi_text("#{staging_conditions}", {:font_reverse => false})

    # Print information on current status of the patient transfering out!
    init_ht = "Init HT: #{demographics.init_ht}"                    
    init_wt = "Init WT: #{demographics.init_wt}"

    first_cd4_count = "CD count " + demographics.cd4_count if demographics.cd4_count
    unless demographics.cd4_count_date.blank?
      first_cd4_count_date = "CD count date #{demographics.cd4_count_date.strftime('%d-%b-%Y')}"
    end
    # renamed current status to Initial height/weight as per minimum requirements
    label.draw_multi_text("Initial Height/Weight", {:font_reverse => true})
    label.draw_multi_text("#{init_ht} #{init_wt}", {:font_reverse => false})
    label.draw_multi_text("#{first_cd4_count}", {:font_reverse => false})
    label.draw_multi_text("#{first_cd4_count_date}", {:font_reverse => false})
 
    # Print information on current treatment of the patient transfering out!

    demographics.reg = []

    concept_id = Concept.find_by_name('AMOUNT DISPENSED').id
    previous_orders = Order.find(:all, :select => "obs.obs_datetime, drug_order.drug_inventory_id", :joins =>"INNER JOIN obs ON obs.order_id = orders.order_id LEFT JOIN drug_order ON orders.order_id = drug_order.order_id",
      :conditions =>["obs.person_id = ? AND obs.concept_id = ?
        	AND obs_datetime <=?",
        patient.id, concept_id, date.strftime('%Y-%m-%d 23:59:59')],
      :order => "obs_datetime DESC")

    previous_date = nil
    drugs = []

    finished = false

    previous_orders.each do |order|
      drug = Drug.find(order.drug_inventory_id)
      next unless MedicationService.arv(drug)
      next if finished

      if previous_date.blank?
        previous_date = order.obs_datetime.to_date
      end
      if previous_date == order.obs_datetime.to_date
        demographics.reg << (drug.concept.shortname || drug.concept.fullname)
        previous_date = order.obs_datetime.to_date
      else
        if !drugs.blank?
          finished = true
        end
      end
    end

    demographics.reg = demographics.reg.uniq.join(" + ")

    label.draw_multi_text("Current ART drugs", {:font_reverse => true})
    label.draw_multi_text("#{demographics.reg}", {:font_reverse => false})
    label.draw_multi_text("Transfer out date:", {:font_reverse => true})
    label.draw_multi_text("#{date.strftime("%d-%b-%Y")}", {:font_reverse => false})

    label.print(1)
  end

  def patient_visit_label(patient, date = Date.today)
    result = Location.find(session[:location_id]).name.match(/outpatient/i)
    unless result
      return mastercard_visit_label(patient,date)
    else
      label = ZebraPrinter::StandardLabel.new
      label.font_size = 3
      label.font_horizontal_multiplier = 1
      label.font_vertical_multiplier = 1
      label.left_margin = 50
      encs = patient.encounters.find(:all,:conditions =>["DATE(encounter_datetime) = ?",date])
      return nil if encs.blank?

      label.draw_multi_text("Visit: #{encs.first.encounter_datetime.strftime("%d/%b/%Y %H:%M")}", :font_reverse => true)
      encs.each {|encounter|
        next if encounter.name.upcase == "REGISTRATION"
        next if encounter.name.upcase == "HIV REGISTRATION"
        next if encounter.name.upcase == "HIV STAGING"
        next if encounter.name.upcase == "HIV CLINIC CONSULTATION"
        next if encounter.name.upcase == "VITALS"
        next if encounter.name.upcase == "ART ADHERENCE"
        encounter.to_s.split("<b>").each do |string|
          concept_name = string.split("</b>:")[0].strip rescue nil
          obs_value = string.split("</b>:")[1].strip rescue nil
          next if string.match(/Workstation location/i)
          next if obs_value.blank?
          label.draw_multi_text("#{encounter.name.humanize} - #{concept_name}: #{obs_value}", :font_reverse => false)
        end
      }
      label.print(1)
    end
  end

  def mastercard_visit_label(patient, date = Date.today)
  	patient_bean = PatientService.get_patient(patient.person)
    visit = visits(patient, date)[date] rescue {}

		owner = " :Patient visit"

		if PatientService.patient_present?(patient.id) == false and PatientService.guardian_present?(patient.id) == true
			owner = " :Guardian Visit"
		end

    return if visit.blank? 
    visit_data = mastercard_visit_data(visit)
    arv_number = patient_bean.arv_number || patient_bean.national_id
    pill_count = visit.pills.collect{|c|c.join(",")}.join(' ') rescue nil

    vl_result = ""
    if vl_routine_check_activated
      latest_vl_result = Lab.latest_viral_load_result(@patient)
      unless latest_vl_result.blank?
        vl_result = "VL: " +latest_vl_result[:modifier].to_s + latest_vl_result[:latest_result].to_s
      end
    end

    label = ZebraPrinter::StandardLabel.new
    #label.draw_text("Printed: #{Date.today.strftime('%b %d %Y')}",597,280,0,1,1,1,false)
    label.draw_text("#{seen_by(patient,date)}",597,250,0,1,1,1,false)
    label.draw_text("#{date.strftime("%B %d %Y").upcase}",25,30,0,3,1,1,false)
    label.draw_text("#{arv_number}",565,30,0,3,1,1,true)
    label.draw_text("#{patient_bean.name}(#{patient_bean.sex}) #{owner}",25,60,0,3,1,1,false)
    label.draw_text("#{'(' + visit.visit_by + ')' unless visit.visit_by.blank?}",255,30,0,2,1,1,false)
    label.draw_text("#{visit.height.to_s + 'cm' if !visit.height.blank?}  #{visit.weight.to_s + 'kg' if !visit.weight.blank?}  #{'BMI:' + visit.bmi.to_s if !visit.bmi.blank?} #{vl_result} #{'(PC:' + pill_count[0..24] + ')' unless pill_count.blank?}",25,95,0,2,1,1,false)
    label.draw_text("SE",25,130,0,3,1,1,false)
    label.draw_text("TB",110,130,0,3,1,1,false)
    label.draw_text("Adh",185,130,0,3,1,1,false)
    label.draw_text("DRUG(S) GIVEN",255,130,0,3,1,1,false)
    label.draw_text("OUTC",577,130,0,3,1,1,false)
    label.draw_line(25,150,800,5)
    label.draw_text("#{visit.tb_status}",110,160,0,2,1,1,false)
    label.draw_text("#{adherence_to_show(visit.adherence).gsub('%', '\\\\%') rescue nil}",185,160,0,2,1,1,false)
    label.draw_text("#{visit_data['outcome']}",577,160,0,2,1,1,false)
    label.draw_text("#{visit_data['outcome_date']}",655,130,0,2,1,1,false)
    label.draw_text("#{visit_data['next_appointment']}",577,190,0,2,1,1,false) if visit_data['next_appointment']
    starting_index = 25
    start_line = 160

    visit_data.each{|key,values|
      data = values.last rescue nil
      next if data.blank?
      bold = false
      #bold = true if key.include?("side_eff") and data !="None"
      #bold = true if key.include?("arv_given") 
      starting_index = values.first.to_i
      starting_line = start_line 
      starting_line = start_line + 30 if key.include?("2")
      starting_line = start_line + 60 if key.include?("3")
      starting_line = start_line + 90 if key.include?("4")
      starting_line = start_line + 120 if key.include?("5")
      starting_line = start_line + 150 if key.include?("6")
      starting_line = start_line + 180 if key.include?("7")
      starting_line = start_line + 210 if key.include?("8")
      starting_line = start_line + 240 if key.include?("9")
      next if starting_index == 0
      label.draw_text("#{data}",starting_index,starting_line,0,2,1,1,bold)
    } rescue []
    label.print(2)
  end
 
  def area_chart_peds
    patient = Patient.find(params[:patient_id])
    person = patient.person
    birthdate = person.birthdate.to_date rescue nil

    concept_id = ConceptName.find_by_name("Weight (Kg)").concept_id
    session_date = (session[:datetime].to_date rescue Date.today).strftime('%Y-%m-%d 23:59:59')
    obs = []

    weight_trail = {} ; current_date = (session_date.to_date - 2.year).to_date

    weight_trail_data = ActiveRecord::Base.connection.select_all <<EOF
    SELECT * FROM obs WHERE person_id = #{patient.id}
    AND concept_id = #{concept_id} AND voided = 0 AND 
    obs_datetime BETWEEN '#{(session_date.to_date - 2.year).strftime('%Y-%m-%d 00:00:00')}' 
    AND '#{session_date}' ORDER BY obs_datetime LIMIT 100;
EOF


    (weight_trail_data || []).each do |weight|
      current_date = weight['obs_datetime'].to_date
      year = current_date.year

      months = ActiveRecord::Base.connection.select_one <<EOF
      SELECT timestampdiff(month, DATE('#{birthdate.to_date}'), DATE('#{current_date.to_date}')) AS `month`;
EOF

      month = months['month'].to_i
      next if month > 58
      begin
        weight_trail[month] =  weight['value_numeric'].squish.to_f
      rescue
        next
      end

    end

    months = ActiveRecord::Base.connection.select_one <<EOF
    SELECT timestampdiff(month, DATE('#{birthdate.to_date}'), DATE('#{session_date.to_date}')) AS `month`;
EOF

    @sorted_weight_trail = []
    (weight_trail || {}).sort_by{|x, y | x}.each do |m, weight|
      @sorted_weight_trail << [m, weight.to_f]
    end

    age_in_months = (session_date.to_date.year * 12 + session_date.to_date.month) - (birthdate.year * 12 + birthdate.month)
    sex = (person.gender == 'Male' || person.gender == 'M') ? 0 : 1
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

    render :layout => false
  end
   
  def baby_chart

    @patient = Patient.find(params[:patient_id])
    @baby = @patient

    if (@baby.person.gender.downcase.match(/f/i))
      file =  File.open(RAILS_ROOT + "/public/data/weight_for_age_girls.txt", "r")
    else
      file =  File.open(RAILS_ROOT + "/public/data/weight_for_age_boys.txt", "r")
    end
    @file = []

    file.each{ |parameters|

      line = parameters
      line = line.split(" ").join(",")
      @file << line

    }

    #get available weights

    @weights = []
    birthdate_sec = @patient.person.birthdate

    ids = ConceptName.find(:all, :conditions => ["name IN (?)", ["WEIGHT", "BIRTH WEIGHT", "BIRTH WEIGHT AT ADMISSION", "WEIGHT (KG)"]]).collect{|concept|
      concept.concept_id}

    Observation.find(:all, :conditions => ["person_id = ? AND concept_id IN (?)",
        @patient.id, ids]).each do |ob|
      age = ((((ob.value_datetime.to_date rescue ob.obs_datetime.to_date) rescue ob.date_created.to_date) - birthdate_sec).days.to_i/(60*60*24)).to_s rescue nil
      weight = ob.answer_string.to_i rescue nil
      next if age.blank? || weight.blank?
      weight = (weight > 100) ? weight/1000.0 : weight # quick check of weight in grams and that in KG's
      @weights << age + "," + weight.to_s if !age.blank? && !weight.blank?

    end

    if !params[:cur_weight].blank?
      wt = params[:cur_weight].to_f
      weight = (wt > 100) ? wt/1000.0 : wt
      age = (((session[:datetime].to_date rescue Date.today) - birthdate_sec).days.to_i/(60*60*24)).to_s rescue nil
      @weights << age + "," + weight.to_s if !age.blank? && !weight.blank?
    end
    
    if params[:tab]
      render :template => "/patients/tab_baby_chart", :layout => false
    else
      render :template => "/patients/baby_chart", :layout => false
    end
  end

  def set_allow_hiv_staging_sessions
    current_date = session[:datetime].to_date rescue Date.today
    patient = Patient.find(params[:patient_id])
    session["#{patient.id}"] = {} if session["#{patient.id}"].blank?
    session["#{patient.id}"]["#{current_date}"] = {} if session["#{patient.id}"]["#{current_date}"].blank?
    session["#{patient.id}"]["#{current_date}"][:stage_patient] = nil
    render :text => "true" and return
  end

  def set_deny_hiv_staging_sessions
    current_date = session[:datetime].to_date rescue Date.today
    patient = Patient.find(params[:patient_id])
    session["#{patient.id}"] = {} if session["#{patient.id}"].blank?
    session["#{patient.id}"]["#{current_date}"] = {} if session["#{patient.id}"]["#{current_date}"].blank?
    session["#{patient.id}"]["#{current_date}"][:stage_patient] = "No"
    next_url = (next_task(patient))
    render :text => next_url and return
  end

  def hiv_viral_load
    @person = Patient.find(params[:patient_id]).person
    #@template variable is used to access helper method in a controller.
    if !(@template.improved_viral_load_check(@person.patient) == true)
      redirect_to (next_task(@person.patient)) and return
    end
    session_date = session[:datetime].blank? ? Date.today : session[:datetime].to_date
		patient = @person.patient
		@outcome = patient.patient_programs.last.patient_states.last.program_workflow_state.concept.fullname rescue nil

		@current_hiv_program_state = PatientProgram.find(:first, :joins => :location, :conditions => ["program_id = ? AND patient_id = ? AND location.location_id = ?", Program.find_by_concept_id(Concept.find_by_name('HIV PROGRAM').id).id,@person.id, Location.current_health_center.location_id]).patient_states.last.program_workflow_state.concept.fullname rescue ''

		@task = main_next_task(Location.current_location, @person.patient, session_date)
		@patient_bean = PatientService.get_patient(@person)

		@art_start_date = PatientService.date_antiretrovirals_started(@person.patient)
    @second_line_treatment_start_date = PatientService.date_started_second_line_regimen(@person.patient) rescue nil
    @duration_in_months = PatientService.period_on_treatment(@art_start_date) rescue nil

		@second_line_duration_in_months = PatientService.period_on_treatment(@second_line_treatment_start_date) rescue nil
    @patient_identifiers = LabController.new.id_identifiers(patient)
 
    @results = Lab.latest_result_by_test_type(@person.patient, 'HIV_viral_load', @patient_identifiers) rescue nil
    @latest_date = @results[0].split('::')[0].to_date rescue nil
    @latest_result = @results[1]["TestValue"] rescue nil
    @modifier = @results[1]["Range"] rescue nil
    @reason_for_art = PatientService.reason_for_art_eligibility(patient)
    @vl_request = Observation.find(:last, :conditions => ["person_id = ? AND concept_id = ? AND value_coded IS NOT NULL",
        patient.patient_id, Concept.find_by_name("Viral load").concept_id]
    ).answer_string.squish.upcase rescue nil

    @repeat_vl_request = Observation.find(:last, :conditions => ["person_id = ? AND concept_id = ?
                AND value_text =?", patient.patient_id, Concept.find_by_name("Viral load").concept_id,
        "Repeat"]).answer_string.squish.upcase rescue nil

    @repeat_vl_obs_date = Observation.find(:last, :conditions => ["person_id = ? AND concept_id = ?
              AND value_text =?", patient.patient_id, Concept.find_by_name("Viral load").concept_id,
        "Repeat"]).obs_datetime.to_date rescue nil

    @date_vl_result_given = Observation.find(:last, :conditions => ["
          person_id =? AND concept_id =? AND value_text REGEXP ?", @person.id,
        Concept.find_by_name("Viral load").concept_id, 'Result given to patient']).value_datetime rescue nil
    @enter_lab_results = GlobalProperty.find_by_property('enter.lab.results').property_value == 'true' rescue false

    @vl_result_hash = Patient.vl_result_hash(patient)
		render :layout => false
  end

  def set_hiv_viral_load_session_variable
    patient = Patient.find(params[:patient_id])
    session[:hiv_viral_load_today_patient] = params[:patient_id]
    next_url = (next_task(patient))
    render :text => next_url and return
  end

  def set_cervical_cancer_session_variable
    patient = Patient.find(params[:patient_id])
    session[:cervical_cancer_patient] = params[:patient_id]
    next_url = (next_task(patient))
    render :text => next_url and return
  end

  def render_date_enrolled_in_art
    patient_identifier = PatientIdentifier.find_by_identifier(params[:identifier])
    date_enrolled = ""
    unless patient_identifier.blank?
      patient_id = patient_identifier.patient_id
      patient_temp_earliest_start_date = ActiveRecord::Base.connection.select_all("SELECT date_enrolled FROM temp_earliest_start_date WHERE patient_id = #{patient_id}")
      date_enrolled = patient_temp_earliest_start_date.last["date_enrolled"] rescue nil
    end
    render :text => date_enrolled and return
  end

  def get_patient_vl_trail
    patient = Patient.find(params[:patient_id])

    if national_lims_activated
      settings = YAML.load_file("#{Rails.root}/config/lims.yml")[Rails.env]
      national_id_type = PatientIdentifierType.find_by_name("National id").id
      npid = patient.patient_identifiers.find_by_identifier_type(national_id_type).identifier
      url = settings['lims_national_dashboard_ip'] + "/api/vl_result_by_npid?npid=#{npid}&test_status=verified__reviewed"
      trail_url = settings['lims_national_dashboard_ip'] + "/api/patient_lab_trail?npid=#{npid}"

      data = JSON.parse(RestClient.get(url)) rescue []
      @latest_date = data.last[0].to_date rescue nil
      @latest_result = data.last[1]["Viral Load"] rescue nil

      @latest_result = "Rejected" if (data.last[1]["Viral Load"] rescue nil) == "Rejected"

      @modifier = '' #data.last[1]["Viral Load"].strip.scan(/\<\=|\=\>|\=|\<|\>/).first rescue

      @date_vl_result_given = nil
      if ((data.last[2].downcase == "reviewed") rescue false)
        @date_vl_result_given = Observation.find(:last, :conditions => ["
          person_id =? AND concept_id =? AND value_text REGEXP ? AND DATE(obs_datetime) = ?", patient.id,
                                                                        Concept.find_by_name("Viral load").concept_id, 'Result given to patient', data.last[3].to_date]).value_datetime rescue nil

        @date_vl_result_given = data.last[3].to_date if @date_vl_result_given.blank?
      end

      #[["97426", {"result_given"=>"no", "result"=>"253522", "date_result_given"=>"", "date_of_sample"=>Sun, 17 Aug 2014, "second_line_switch"=>"no"}]]
      trail = JSON.parse(RestClient.get(trail_url)) rescue []

      @vl_result_hash = {}
      (trail || []).each do |order|
        results = order['results']['Viral Load']
        if (order['sample_status'] || order['status']).match(/rejected|voided/i)
          @vl_result_hash[order['_id']] = {"result_given" =>  'no',
                                             "result" => (order['sample_status'] || order['status']).humanize,
                                             "date_of_sample" => order['date_time'].to_date,
                                             "date_result_given" => "",
                                             "switched_to_second_line" => '?'
          }
          next
        end

        next if results.blank?
        timestamp = results.keys.sort.last rescue nil
        next if (!(order['sample_status'] || order['status']).match(/rejected|voided/)) && (!['verified', 'reviewed'].include?(results[timestamp]['test_status'].downcase.strip) rescue true)
        result = results[timestamp]['results']

        date_given = nil
        if ((results[timestamp]['test_status'].downcase.strip == "reviewed") rescue false)
          date_given = Observation.find(:last, :conditions => ["
                    person_id =? AND concept_id =? AND value_text REGEXP ? AND DATE(obs_datetime) = ?", patient.id,
                                                               Concept.find_by_name("Viral load").concept_id, 'Result given to patient', timestamp.to_date]).value_datetime rescue nil
          date_given = date_given.to_date.strftime('%d-%b-%Y');

          date_given = timestamp.to_date.to_date if date_given.blank?
        end

        @vl_result_hash[order['_id']] = {"result_given" => (results[timestamp]['test_status'].downcase.strip == 'reviewed' ? 'yes' : 'no'),
                                           "result" => (result["Viral Load"] rescue nil),
                                           "date_of_sample" => order['date_time'].to_date.strftime('%d-%b-%Y'),
                                           "date_result_given" => date_given,
                                           "switched_to_second_line" => '?'
        }

      end

    else

      vl_result_hash = Patient.vl_result_hash(Patient.find(params[:patient_id]))
      vl_data = {}

      vl_result_hash.each do |accession_num, values|
        vl_data[accession_num] = {}
        range = values["range"]
        date_of_sample = values["date_of_sample"].strftime("%d-%b-%Y") rescue values["date_of_sample"]
        result = range.to_s + " " + values["result"]
        result_given = values["date_result_given"].strftime("%d-%b-%Y") rescue values["date_result_given"]
        date_result_given = values["date_result_given"]
        switched_to_second_line = values["second_line_switch"]

        vl_data[accession_num]["date_of_sample"] = date_of_sample
        vl_data[accession_num]["result"] = result
        vl_data[accession_num]["result_given"] = result_given
        vl_data[accession_num]["date_result_given"] = date_result_given
        vl_data[accession_num]["switched_to_second_line"] = switched_to_second_line

      end

    end

    render :text => @vl_result_hash.to_json and return
  end

  def change_reason_for_starting_art
    if request.post?
      encounter_type = EncounterType.find_by_name('HIV STAGING')
      encounter = Encounter.find(:last, 
        :conditions =>["patient_id = ? AND encounter_type = ?",
        params[:patient_id], encounter_type.id])

      if encounter.blank?
        redirect_to "/patients/mastercard?patient_id=#{params[:patient_id]}" and return
      else
        reason_for_starting = ConceptName.find_by_name('Reason for ART eligibility').concept_id
        (encounter.observations || []).each do |ob|
          next unless ob.concept_id == reason_for_starting
          ob.void('Given another reason for starting')
        end
      
        value_coded = params[:observations][0]['value_coded_or_text']

        Observation.create(:concept_id => reason_for_starting,
          :person_id => encounter.patient_id, :encounter_id => encounter.id,
          :obs_datetime => encounter.encounter_datetime, :value_coded => value_coded)
        
        redirect_to "/patients/mastercard?patient_id=#{encounter.patient_id}" and return
      end
    else
      @patient = Patient.find(params[:patient_id])
      @reasons_for_starting_art = []
      
      reasons_for_starting_art = ['HIV DNA polymerase chain reaction',
        'Unknown','None','HIV infected','Patient pregnant',
        'Asymptomatic', 'Currently breastfeeding child',
        'WHO stage II adult','WHO stage III adult',
        'WHO stage IV adult', 'WHO stage I peds',
        'WHO stage II peds','WHO stage III peds',
        'WHO stage IV peds', 'Lymphocyte count below threshold with who stage 2',
        'WHO stage I adult','Presumed severe HIV criteria in infants',
        'CD4 count <= 350', 'CD4 count <= 750',
        'CD4 count less than or equal to 250',
        'Presumed Severe HIV',
        'Lymphocyte count below threshold with who stage 1',
        'CD4 count less than or equal to 500']

      concepts = ConceptName.find(:all, 
        :conditions => ["name IN(?)", reasons_for_starting_art],
        :group => "name")

      (concepts).each do |c|
        @reasons_for_starting_art << [c.name.gsub('<=',' less than or equal to '), c.concept_id]
      end

      @reasons_for_starting_art = @reasons_for_starting_art.sort_by{|x,y|x}

    end
  end

  def past_filing_numbers
    @patient_identifiers = ActiveRecord::Base.connection.select_all <<EOF
    SELECT identifier, date_created FROM patient_identifier WHERE patient_id = #{params[:id]}
    AND identifier_type IN(17,18);
EOF
 
    render :layout => 'menu'
  end

end
