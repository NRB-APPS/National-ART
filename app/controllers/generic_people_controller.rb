class GenericPeopleController < ApplicationController
  @@test  = nil

	def index
		redirect_to "/clinic"
	end

	def new
		@occupations = occupations
    @military_ranks = military_ranks
	end

	def identifiers
	end

  def create_confirm
    @search_results = {}
    @patients = []

    (PatientService.search_demographics_from_remote(params[:user_entered_params]) || []).each do |data|
      national_id = data["person"]["data"]["patient"]["identifiers"]["National id"] rescue nil
      national_id = data["person"]["value"] if national_id.blank? rescue nil
      national_id = data["npid"]["value"] if national_id.blank? rescue nil
      national_id = data["person"]["data"]["patient"]["identifiers"]["old_identification_number"] if national_id.blank? rescue nil

      next if national_id.blank?
      results = PersonSearch.new(national_id)
      results.national_id = national_id
      results.current_residence = data["person"]["data"]["addresses"]["city_village"]
      results.person_id = 0
      results.home_district = data["person"]["data"]["addresses"]["address2"]
      results.neighborhood_cell = data["person"]["data"]["addresses"]["neighborhood_cell"]
      results.traditional_authority =  data["person"]["data"]["addresses"]["county_district"]
      results.name = data["person"]["data"]["names"]["given_name"] + " " + data["person"]["data"]["names"]["family_name"]
      gender = data["person"]["data"]["gender"]
      results.occupation = data["person"]["data"]["occupation"]
      results.sex = (gender == 'M' ? 'Male' : 'Female')
      results.birthdate_estimated = (data["person"]["data"]["birthdate_estimated"]).to_i
      results.birth_date = birthdate_formatted((data["person"]["data"]["birthdate"]).to_date , results.birthdate_estimated)
      results.birthdate = (data["person"]["data"]["birthdate"]).to_date
      results.age = cul_age(results.birthdate.to_date , results.birthdate_estimated)
      @search_results[results.national_id] = results
    end if create_from_dde_server

    (params[:people_ids] || []).each do |person_id|
      patient = PatientService.get_patient(Person.find(person_id))

      results = PersonSearch.new(patient.national_id || patient.patient_id)
      results.national_id = patient.national_id
      results.birth_date = patient.birth_date
      results.current_residence = patient.current_residence
      results.guardian = patient.guardian
      results.person_id = patient.person_id
      results.home_district = patient.home_district
      results.neighborhood_cell = patient.home_village
      results.current_district = patient.current_district
      results.traditional_authority = patient.traditional_authority
      results.mothers_surname = patient.mothers_surname
      results.dead = patient.dead
      results.arv_number = patient.arv_number
      results.eid_number = patient.eid_number
      results.pre_art_number = patient.pre_art_number
      results.name = patient.name
      results.sex = patient.sex
      results.age = patient.age
      @search_results.delete_if{|x,y| x == results.national_id }
      @patients << results
    end

		(@search_results || {}).each do | npid , data |
			@patients << data
		end

    @parameters = params[:user_entered_params]
    render :layout => 'menu'
  end

	def create_remote
    #raise params.inspect
    authenticate_or_request_with_http_basic do |username, password|
      user = User.authenticate(username, password)
      raise "Wrong user credentials" if user.blank?
      sign_in(:user, user)
      set_current_user
    end

		if Location.current_location.blank?
			Location.current_location = Location.find(CoreService.get_global_property_value('current_health_center_id'))
		end rescue []

    patient = nil
    if create_from_dde_server
      address2 = (params["patient"]["birthplace"] rescue nil)
      city_village = (params["patientaddress"]["city_village"] rescue nil)
      county_district = (params["current_ta"]["identifier"] rescue nil)
      state_province = (params["p_address"]["identifier"] rescue nil)

      passed_params = {"region" => "" ,
				"person"=>{"occupation"=> params["occupation"] ,
					"age_estimate"=> params["patient_age"]["age_estimate"] ,
					"cell_phone_number"=> params["cell_phone"]["identifier"] || nil,
          "home_phone_number"=> params['home_phone']['identifier'] || nil,
          "office_phone_number"=> params['office_phone']['identifier'] || nil,
					"birth_month"=> params["patient_month"],
          "addresses"=>
            {"state_province"=> (params["addresses"]["state_province"] rescue state_province),
            "address2"=> (params["addresses"]["address2"] rescue address2),
            "address1"=> (params["addresses"]["address1"] rescue nil),
            "neighborhood_cell"=> (params["addresses"]["neighborhood_cell"] rescue nil),
            "city_village"=> (params["addresses"]["city_village"] rescue city_village),
            "county_district"=> (params["addresses"]["county_district"] rescue county_district)},
					"gender"=>  params["patient"]["gender"],
					"patient"=>"",
					"birth_day"=>  params["patient_day"] ,
					"home_phone_number"=> params["home_phone"]["identifier"] ,
					"names"=>{"family_name"=> params["patient_name"]["family_name"],
						"given_name"=> params["patient_name"]["given_name"],
						"middle_name"=> params["patient_name"]["middle_name"] },
					"birth_year"=> params["patient_year"] },
				"filter_district"=> params["patient"]["birthplace"] ,
				"filter"=>{"region"=> "" ,
					"t_a"=> "",
					"t_a_a"=>""},
				"relation"=>"",
				"p"=>{"'address2_a'"=>"",
					"addresses"=>{"county_district_a"=>"",
						"city_village_a"=>""}},
				"identifier"=>""}

      person = PatientService.create_patient_from_dde(passed_params)
    else
      #raise params["addresses"].to_yaml
      state = params["addresses"]["state_province"] rescue nil
      address2 = params["addresses"]["address2"] rescue nil
      address1 = params["addresses"]["address1"] rescue nil
      address  = params["addresses"]["neighborhood_cell"] rescue nil
      city_village = params["addresses"]["city_village"] rescue nil
      district = params["addresses"]["county_district"] rescue nil
      person_params = {"occupation"=> params[:occupation],
        "age_estimate"=> params['patient_age']['age_estimate'],
        "cell_phone_number"=> params['cell_phone']['identifier'] || nil,
        "home_phone_number"=> params['home_phone']['identifier'] || nil,
        "office_phone_number"=> params['office_phone']['identifier'] || nil,
        "birth_month"=> params[:patient_month],
        "addresses"=>
          {"state_province"=> state,
          "address2"=> address2,
          "address1"=> address1,
          "neighborhood_cell"=> address,
          "city_village"=> city_village,
          "county_district"=> district},
        "gender" => params['patient']['gender'],
        "birth_day" => params[:patient_day],
        "names"=> {"family_name2"=>"Unknown",
					"family_name"=> params['patient_name']['family_name'],
					"given_name"=> params['patient_name']['given_name'] },
        "birth_year"=> params[:patient_year] }

      person = PatientService.create_from_form(person_params)

      if person
        patient = Patient.new()
        patient.patient_id = person.id
        patient.save
        PatientService.patient_national_id_label(patient)
      end
    end

    person["patient"] = {
      "identifiers"=>
        {"National id"=> PatientService.get_national_id(patient) }
    }  if !patient.blank?

		render :text => PatientService.remote_demographics(person).to_json
	end

	def remote_demographics
		# Search by the demographics that were passed in and then return demographics
		people = PatientService.find_person_by_demographics(params)
		result = people.empty? ? {} : PatientService.demographics(people.last)

		render :text => result.to_json
	end

  def search_remote_people
		# Search people by demographics that were passed in and then return demographics
		people = PatientService.find_person_by_demographics(params)
    results = []
    people.each do |person|
      results << PatientService.demographics(person)
    end
		
		render :text => results.to_json
	end

	def art_information
		national_id = params["person"]["patient"]["identifiers"]["National id"] rescue nil
    national_id = params["person"]["value"] if national_id.blank? rescue nil
		art_info = Patient.art_info_for_remote(national_id)
		art_info = art_info_for_remote(national_id)
		render :text => art_info.to_json
	end

	def search
    found_person = nil
    if params[:identifier]
      local_results = PatientService.search_by_identifier(params[:identifier])
			if local_results.blank? and (params[:identifier].match(/#{Location.current_health_center.neighborhood_cell}-ARV/i) || params[:identifier].match(/-TB/i))
				flash[:notice] = "No matching person found with number #{params[:identifier]}"
				redirect_to :action => 'find_by_tb_number' if params[:identifier].match(/-TB/i)
				redirect_to :action => 'find_by_arv_number' if params[:identifier].match(/#{Location.current_health_center.neighborhood_cell}-ARV/i)
			end

      if local_results.length > 1
        redirect_to :action => 'duplicates' ,:search_params => params
        return
      elsif local_results.length == 1
        ####################################################hack to handle duplicates ########################################################
        person_to_be_chcked = PatientService.demographics(Person.find(local_results.first[:person_id].to_i))
        if CoreService.get_global_property_value('search.from.remote.app').to_s == 'true'
          remote_app_address = CoreService.get_global_property_value('remote.app.address').to_s
          uri = "http://#{remote_app_address}/check_for_duplicates/remote_app_search"
          search_from_remote_params =  {"identifier" => params[:identifier],
            "given_name" => person_to_be_chcked['person']['names']['given_name'],
            "family_name" => person_to_be_chcked['person']['names']['family_name'],
            "gender" => person_to_be_chcked['person']['gender'] }

          output = RestClient.post(uri,search_from_remote_params) rescue []
          remote_result = JSON.parse(output) rescue []
          unless remote_result.blank?
            redirect_to :controller =>'check_for_duplicates', :action => 'view',
              :identifier => params[:identifier] and return
          end
        end
        #################################################### end of: hack to handle duplicates ########################################################

        if create_from_dde_server
          dde_search_results = PatientService.search_dde_by_identifier(params[:identifier], session[:dde_token])
          dde_hits = dde_search_results["data"]["hits"] rescue []
          old_npid = person_to_be_chcked["person"]["patient"]["identifiers"]["National id"] #No need for rescue here. Let it crash so that we know the problem

          ####################### REPLACING DDE TEMP ID ########################
          if (dde_hits.length  == 1)
            new_npid = dde_hits[0]["npid"]
            #new National ID assignment
            #There is a need to check the validity of the patient national ID before being marked as old ID

            if params[:was_duplicate] #This parameter is coming from DDE duplicates page
              if (session[:duplicate_npid].to_s.squish != new_npid.to_s.squish) #if DDE has returned a new ID, Let's assume it is right
                national_id_replaced = true #when the scanned ID is not equal to the one returned by dde, get ready for print
              end rescue nil
            end
            
            if (old_npid != new_npid) #if DDE has returned a new ID, Let's assume it is right
              p = Person.find(local_results.first[:person_id].to_i)
              PatientService.assign_new_dde_npid(p, old_npid, new_npid)
              national_id_replaced = true
            end

            PatientService.update_local_demographics_from_dde(Person.find(local_results.first[:person_id].to_i), dde_hits[0]) rescue nil
          end
          ######################## REPLACING DDE TEMP ID END####################

          if dde_hits.length > 1
            #Locally available and remotely available + duplicates
            redirect_to("/people/dde_duplicates?npid=#{params[:identifier]}") and return
          end

          if dde_hits.length == 0
            #Locally available and remotely NOT available
            old_npid = params[:identifier]
            person = Person.find(local_results.first[:person_id].to_i)
            dde_demographics = PatientService.generate_dde_demographics(person_to_be_chcked, session[:dde_token])
            #dde_demographics = {"person" => dde_demographics}
            dde_response = PatientService.add_dde_patient_after_search_by_identifier(dde_demographics)
            dde_status = dde_response["status"]
            if dde_status.to_s == '201'
              new_npid = dde_response["data"]["npid"]
            end

            if dde_status.to_s == '409' #conflict
              dde_return_path = dde_response["return_path"]
              dde_response = PatientService.add_dde_conflict_patient(dde_return_path, dde_demographics, session[:dde_token])
              new_npid = dde_response["data"]["npid"]
            end

            PatientService.assign_new_dde_npid(person, old_npid, new_npid)
            national_id_replaced = true
          end
          
          if (params[:identifier].to_s.squish != new_npid.to_s.squish) #if DDE has returned a new ID, Let's assume it is right
            national_id_replaced = true #when the scanned ID is not equal to the one returned by dde, get ready for print
          end rescue nil

        end unless params[:identifier].match(/ARV|TB|HCC/i)
        found_person = local_results.first
      else
        # TODO - figure out how to write a test for this
        # This is sloppy - creating something as the result of a GET
        
        if create_from_dde_server
          #Results not found locally
          dde_search_results = PatientService.search_dde_by_identifier(params[:identifier], session[:dde_token])
          dde_hits = dde_search_results["data"]["hits"] rescue []
          if dde_hits.length == 1
            found_person = PatientService.create_local_patient_from_dde(dde_hits[0])
          end

          if dde_hits.length > 1
            redirect_to("/people/dde_duplicates?npid=#{params[:identifier]}") and return
          end

        end unless params[:identifier].match(/ARV|TB|HCC/i)
        
        if create_from_remote
          found_person_data = PatientService.find_remote_person_by_identifier(params[:identifier])
          found_person = PatientService.create_from_form(found_person_data['person']) unless found_person_data.blank?
        end
      end

      if found_person

        if params[:relation]
          redirect_to search_complete_url(found_person.id, params[:relation]) and return
        elsif national_id_replaced.to_s == "true"
          #creating patient's footprint so that we can track them later when they visit other sites
          #DDEService.create_footprint(PatientService.get_patient(found_person).national_id, "ART - #{ART_VERSION}")
          print_and_redirect("/patients/national_id_label?patient_id=#{found_person.id}", next_task(found_person.patient)) and return
          redirect_to :action => 'confirm', :found_person_id => found_person.id, :relation => params[:relation] and return
        else
          #creating patient's footprint so that we can track them later when they visit other sites
          #DDEService.create_footprint(PatientService.get_patient(found_person).national_id, "ART - #{ART_VERSION}")
          redirect_to :action => 'confirm',:found_person_id => found_person.id, :relation => params[:relation] and return
        end
      end
    end

    @relation = params[:relation]
    @people = PatientService.person_search(params)
    @search_results = {}
    @patients = []

    (PatientService.search_dde_by_name_and_gender(params, session[:dde_token]) || []).each do |data|
      national_id = data["npid"]
      next if national_id.blank?
      results = PersonSearch.new(national_id)
      results.national_id = national_id

      unless data["addresses"]["home_ta"].blank?
        results.traditional_authority = data["addresses"]["home_ta"]
      else
        results.traditional_authority = nil
      end 

      unless data["addresses"]["home_district"].blank?
        results.home_district = data["addresses"]["home_district"]
      else
        results.home_district = nil
      end 

      unless data["addresses"]["current_residence"].blank?
        results.current_residence =  data["addresses"]["current_residence"]
      else
        results.current_residence = nil
      end


      results.person_id = 0
      results.name = data["names"]["given_name"] + " " + data["names"]["family_name"]
      gender = data["gender"]
      results.occupation = (data["attributes"]["occupation"] rescue nil)
      results.sex = (gender == 'M' ? 'Male' : 'Female')
      results.birthdate_estimated = (data["birthdate_estimated"]).to_i
      results.birth_date = birthdate_formatted((data["birthdate"]).to_date , results.birthdate_estimated)
      results.birthdate = (data["birthdate"]).to_date
      results.age = cul_age(results.birthdate.to_date , results.birthdate_estimated)
      @search_results[results.national_id] = results
    end if create_from_dde_server

    (@people || []).each do | person |
      patient = PatientService.get_patient(person) rescue nil
      next if patient.blank?
      results = PersonSearch.new(patient.national_id || patient.patient_id)
      results.national_id = patient.national_id
      results.birth_date = patient.birth_date
      results.current_residence = patient.current_residence
      results.guardian = patient.guardian
      results.person_id = patient.person_id
      results.home_district = patient.home_district
      results.current_district = patient.current_district
      results.traditional_authority = patient.traditional_authority
      results.mothers_surname = patient.mothers_surname
      results.dead = patient.dead
      results.arv_number = patient.arv_number
      results.eid_number = patient.eid_number
      results.pre_art_number = patient.pre_art_number
      results.name = patient.name
      results.sex = patient.sex
      results.age = patient.age
      @search_results.delete_if{|x,y| x == results.national_id }
      @patients << results
    end

		(@search_results || {}).each do | npid , data |
			@patients << data
		end
	end

  def search_from_dde
		found_person = PatientService.person_search_from_dde(params)
    if found_person
      if params[:relation]
        redirect_to search_complete_url(found_person.id, params[:relation]) and return
      else
        redirect_to :action => 'confirm',
          :found_person_id => found_person.id,
          :relation => params[:relation] and return
      end
    else
      redirect_to :action => 'search' and return
    end
  end

	def confirm
		session_date = session[:datetime].blank? ? Date.today : session[:datetime].to_date

		@found_person_id = params[:found_person_id]
		@relation = params[:relation]
		@person = Person.find(@found_person_id) rescue nil
		patient = @person.patient
    @military_site_status = CoreService.get_global_property_value("military.site").to_s == "true" rescue false
    hiv_session = false
    if current_program_location == "HIV program"
      hiv_session = true
    end

    if Location.current_location.name.match(/HIV Reception/i)
      if use_filing_number and hiv_session
        duplicate_filing_numbers = PatientIdentifier.inconsistent_patient_filing_numbers(patient.patient_id)
        if not duplicate_filing_numbers.first.blank? or not duplicate_filing_numbers.last.blank?
          redirect_to "/people/inconsistent_patient_filing_numbers?patient_id=#{patient.patient_id}"
          return
        end

        ##### checks for duplicate filing_number
        duplicate_filing_number = PatientIdentifier.fetch_duplicate_filing_numbers(patient.patient_id)
        if not duplicate_filing_number.blank?
          redirect_to "/people/display_duplicate_filing_numbers?patient_id=#{patient.patient_id}&data=#{duplicate_filing_number}"
          return
        end
      end
    end
     
    render :layout => 'report'
	end

  def inconsistency_outcomes
    person = Person.find(params[:patient_id])
    @patient_bean = PatientService.get_patient(person)
    @patient_states = Patient.states(person.patient)
    @next_task = next_task(person.patient)
    render :layout => "menu"
  end
  
	def tranfer_patient_in
		@data_demo = {}
		if request.post?
			params[:data].split(',').each do | data |
				if data[0..4] == "Name:"
					@data_demo['name'] = data.split(':')[1]
					next
				end
				if data.match(/guardian/i)
					@data_demo['guardian'] = data.split(':')[1]
					next
				end
				if data.match(/sex/i)
					@data_demo['sex'] = data.split(':')[1]
					next
				end
				if data[0..3] == 'DOB:'
					@data_demo['dob'] = data.split(':')[1]
					next
				end
				if data.match(/National ID:/i)
					@data_demo['national_id'] = data.split(':')[1]
					next
				end
				if data[0..3] == "BMI:"
					@data_demo['bmi'] = data.split(':')[1]
					next
				end
				if data.match(/ARV number:/i)
					@data_demo['arv_number'] = data.split(':')[1]
					next
				end
				if data.match(/Address:/i)
					@data_demo['address'] = data.split(':')[1]
					next
				end
				if data.match(/1st pos HIV test site:/i)
					@data_demo['first_positive_hiv_test_site'] = data.split(':')[1]
					next
				end
				if data.match(/1st pos HIV test date:/i)
					@data_demo['first_positive_hiv_test_date'] = data.split(':')[1]
					next
				end
				if data.match(/FU:/i)
					@data_demo['agrees_to_followup'] = data.split(':')[1]
					next
				end
				if data.match(/1st line date:/i)
					@data_demo['date_of_first_line_regimen'] = data.split(':')[1]
					next
				end
				if data.match(/SR:/i)
					@data_demo['reason_for_art_eligibility'] = data.split(':')[1]
					next
				end
			end
		end
		render :layout => "menu"
	end

	# This method is just to allow the select box to submit, we could probably do this better
	def select
    if !params[:person][:patient][:identifiers]['National id'].blank? &&
        !params[:person][:names][:given_name].blank? &&
        !params[:person][:names][:family_name].blank?
      redirect_to :action => :search, :identifier => params[:person][:patient][:identifiers]['National id']
      return
    end rescue nil

    if !params[:identifier].blank? && !params[:given_name].blank? && !params[:family_name].blank?
      redirect_to :action => :search, :identifier => params[:identifier]
    elsif params[:person][:id] != '0' && Person.find(params[:person][:id]).dead == 1
      redirect_to :controller => :patients, :action => :show, :id => params[:person][:id]
    else
      if params[:person][:id] != '0'

        person = Person.find(params[:person][:id])
        #patient = DDEService::Patient.new(person.patient)
        patient_id = PatientService.get_patient_identifier(person.patient, "National id")
        old_npid = patient_id
        
        if create_from_dde_server
          unless params[:patient_guardian].blank?
            print_and_redirect("/patients/national_id_label?patient_id=#{person.id}", "/patients/guardians_dashboard/#{person.id}") and return
					end
          demographics = PatientService.demographics(person)
          dde_demographics = PatientService.generate_dde_demographics(demographics, session[:dde_token])
          #check if patient is not in DDE first
          dde_search_results = PatientService.search_dde_by_identifier(old_npid, session[:dde_token])
          dde_hits = dde_search_results["data"]["hits"] rescue []
          patient_exists_in_dde = dde_hits.length > 0

          if (dde_hits.length == 1)
            new_npid =  dde_hits[0]["npid"]
            if (old_npid != new_npid)
              PatientService.assign_new_dde_npid(person, old_npid, new_npid)
              print_and_redirect("/patients/national_id_label?patient_id=#{person.id}", next_task(person.patient)) and return
            end
          end

          if !patient_exists_in_dde
            dde_response = PatientService.add_dde_patient_after_search_by_name(dde_demographics)

            dde_status = dde_response["status"]

            if dde_status.to_s == '201' #created
              new_npid = dde_response["data"]["npid"]
              #new National ID assignment
              #There is a need to check the validity of the patient national ID before being marked as old ID

              if (old_npid != new_npid)
                PatientService.assign_new_dde_npid(person, old_npid, new_npid)
              end
              print_and_redirect("/patients/national_id_label?patient_id=#{person.id}", next_task(person.patient)) and return
            end

            if dde_status.to_s == '409' #conflict
              dde_return_path = dde_response["return_path"]
              data = {}
              data["return_path"] = dde_return_path
              data["data"] = dde_response["data"]
              data["params"] = demographics
              session[:dde_conflicts] = data
              redirect_to("/people/display_dde_conflicts") and return
              #PatientService.add_dde_conflict_patient(dde_return_path, params, session[:dde_token])
            end
          end
          #creating patient's footprint so that we can track them later when they visit other sites
          #DDEService.create_footprint(PatientService.get_patient(person).national_id, "ART - #{ART_VERSION}")
        end

      end
      redirect_to search_complete_url(params[:person][:id], params[:relation]) and return unless params[:person][:id].blank? || params[:person][:id] == '0'

      redirect_to :action => :new, :gender => params[:gender],
        :given_name => params[:given_name], :family_name => params[:family_name],
        :family_name2 => params[:family_name2], :address2 => params[:address2],
        :identifier => params[:identifier], :relation => params[:relation]
    end
	end

  def create
    #raise params.inspect
    #raise session[:dde_token].inspect
    if confirm_before_creating and not params[:force_create] == 'true' and params[:relation].blank?
      @parameters = params
      birthday_params = params.reject{|key,value| key.match(/gender/) }
      unless birthday_params.empty?
        if params[:person]['birth_year'] == "Unknown"
          birthdate = Date.new(Date.today.year - params[:person]["age_estimate"].to_i, 7, 1)
        else
          year = params[:person]["birth_year"].to_i
          month = params[:person]["birth_month"]
          day = params[:person]["birth_day"].to_i

          month_i = (month || 0).to_i
          month_i = Date::MONTHNAMES.index(month) if month_i == 0 || month_i.blank?
          month_i = Date::ABBR_MONTHNAMES.index(month) if month_i == 0 || month_i.blank?

          if month_i == 0 || month == "Unknown"
            birthdate = Date.new(year.to_i,7,1)
          elsif day.blank? || day == "Unknown" || day == 0
            birthdate = Date.new(year.to_i,month_i,15)
          else
            birthdate = Date.new(year.to_i,month_i,day.to_i)
          end
        end
      end

      start_birthdate = (birthdate - 5.year)
      end_birthdate   = (birthdate + 5.year)

      given_name_code = @parameters[:person][:names]['given_name'].soundex
      family_name_code = @parameters[:person][:names]['family_name'].soundex
      gender = @parameters[:person]['gender']
      ta = @parameters[:person][:addresses]['county_district']
      home_district = @parameters[:person][:addresses]['address2']
      home_village = @parameters[:person][:addresses]['neighborhood_cell']

      people = Person.find(:all,:joins =>"INNER JOIN person_name pn
       ON person.person_id = pn.person_id
       INNER JOIN person_name_code pnc ON pnc.person_name_id = pn.person_name_id
       INNER JOIN person_address pad ON pad.person_id = person.person_id",
        :conditions =>["(pad.address2 LIKE (?) OR pad.county_district LIKE (?)
       OR pad.neighborhood_cell LIKE (?)) AND pnc.given_name_code LIKE (?)
       AND pnc.family_name_code LIKE (?) AND person.gender = '#{gender}'
       AND (person.birthdate >= ? AND person.birthdate <= ?)","%#{home_district}%",
          "%#{ta}%","%#{home_village}%","%#{given_name_code}%","%#{family_name_code}%",
          start_birthdate,end_birthdate],:group => "person.person_id")

      if people
        people_ids = []
        (people).each do |person|
          people_ids << person.id
        end
      end


      #............................................................................
      @dde_search_results = {}
      (PatientService.search_demographics_from_remote(params) || []).each do |data|
        national_id = data["person"]["data"]["patient"]["identifiers"]["National id"] rescue nil
        national_id = data["person"]["value"] if national_id.blank? rescue nil
        national_id = data["npid"]["value"] if national_id.blank? rescue nil
        national_id = data["person"]["data"]["patient"]["identifiers"]["old_identification_number"] if national_id.blank? rescue nil

        next if national_id.blank?
        results = PersonSearch.new(national_id)
        results.national_id = national_id
        results.current_residence = data["person"]["data"]["addresses"]["city_village"]
        results.person_id = 0
        results.home_district = data["person"]["data"]["addresses"]["address2"]
        results.neighborhood_cell = data["person"]["data"]["addresses"]["neighborhood_cell"]
        results.traditional_authority =  data["person"]["data"]["addresses"]["county_district"]
        results.name = data["person"]["data"]["names"]["given_name"] + " " + data["person"]["data"]["names"]["family_name"]
        gender = data["person"]["data"]["gender"]
        results.occupation = data["person"]["data"]["occupation"]
        results.sex = (gender == 'M' ? 'Male' : 'Female')
        results.birthdate_estimated = (data["person"]["data"]["birthdate_estimated"]).to_i
        results.birth_date = birthdate_formatted((data["person"]["data"]["birthdate"]).to_date , results.birthdate_estimated)
        results.birthdate = (data["person"]["data"]["birthdate"]).to_date
        results.age = cul_age(results.birthdate.to_date , results.birthdate_estimated)
        @dde_search_results[results.national_id] = results
        break
      end if create_from_dde_server
      #............................................................................
      #if params
      if not people_ids.blank? or not @dde_search_results.blank?
        redirect_to :action => :create_confirm , :people_ids => people_ids ,
          :user_entered_params => @parameters and return
      end
    end

    hiv_session = false
    if current_program_location == "HIV program"
      hiv_session = true
    end
    success = false

    Person.session_datetime = session[:datetime].to_date rescue Date.today
    identifier = params[:identifier] rescue nil

    if identifier.blank?
      identifier = params[:person][:patient][:identifiers]['National id']
    end rescue nil

    if create_from_dde_server
      unless identifier.blank?
        #params[:person].merge!({"identifiers" => {"National id" => identifier}})
        success = true
        #person = PatientService.create_from_form(params[:person])
        if identifier.length != 6
          #patient = DDEService::Patient.new(person.patient)
          #national_id_replaced = patient.check_old_national_id(identifier)
        end
      else
        # person = PatientService.create_patient_from_dde(params)
        dde_response = PatientService.add_dde_patient(params, session[:dde_token])
        dde_status = dde_response["status"]

        if dde_status.to_s == '201'
          npid = dde_response["data"]["npid"]
          params["person"].merge!({"identifiers" => {"National id" => npid}})
          person = PatientService.create_from_form(params["person"])
        end

        if dde_status.to_s == '409' #conflict
          dde_return_path = dde_response["return_path"]
          data = {}
          data["return_path"] = dde_return_path
          data["data"] = dde_response["data"]
          data["params"] = params
          session[:dde_conflicts] = data
          redirect_to("/people/display_dde_conflicts") and return
          #PatientService.add_dde_conflict_patient(dde_return_path, params, session[:dde_token])
        end
        success = true
      end

      #If we are creating from DDE then we must create a footprint of the just created patient to
      #enable future

      DDEService.create_footprint(PatientService.get_patient(person).national_id, "ART - #{ART_VERSION}")


      #for now ART will use BART1 for patient/person creation until we upgrade BART1 to ART
      #if GlobalProperty.find_by_property('create.from.remote') and property_value == 'yes'
      #then we create person from remote machine
    elsif create_from_remote
      person_from_remote = PatientService.create_remote_person(params)
      person = PatientService.create_from_form(person_from_remote["person"]) unless person_from_remote.blank?

      if !person.blank?
        success = true
        PatientService.get_remote_national_id(person.patient)
      end
    else
      success = true
      params[:person].merge!({"identifiers" => {"National id" => identifier}}) unless identifier.blank?
      person = PatientService.create_from_form(params[:person])
    end

    if params[:person][:patient] && success
      PatientService.patient_national_id_label(person.patient)
      unless (params[:relation].blank?)
        redirect_to search_complete_url(person.id, params[:relation]) and return
      else
        if  ! params[:guardian_present].blank?
          new_encounter = {"encounter_datetime"=> (session[:datetime] rescue Date.today),
            "encounter_type_name"=>"HIV RECEPTION",
            "patient_id"=> person.id,
            "provider_id"=> current_user.id}

          encounter = Encounter.new(new_encounter)
          encounter.encounter_datetime = session[:datetime] rescue Date.today
          encounter.save

          reason_obs = {}
          reason_obs[:concept_name] = 'GUARDIAN PRESENT'
          reason_obs[:encounter_id] = encounter.id
          reason_obs[:obs_datetime] = encounter.encounter_datetime || Time.now()
          reason_obs[:person_id] ||= encounter.patient_id
          reason_obs['value_coded_or_text'] = params[:guardian_present]
          Observation.create(reason_obs)

          reason_obs = {}
          reason_obs[:concept_name] = 'PATIENT PRESENT'
          reason_obs[:encounter_id] = encounter.id
          reason_obs[:obs_datetime] = encounter.encounter_datetime || Time.now()
          reason_obs[:person_id] ||= encounter.patient_id
          reason_obs['value_coded_or_text'] = "YES"
          Observation.create(reason_obs)
        end
        if  params[:guardian_present] == "YES"
          redirect_to "/relationships/search?patient_id=#{person.id}&return_to=/people/redirections?person_id=#{person.id}" and return
        else
          redirect_to "/people/redirections?person_id=#{person.id}" and return
        end
        #raise use_filing_number.to_yaml

      end
    else
      # Does this ever get hit?
      redirect_to :action => "index"
    end
  end

  def display_dde_conflicts
    @dde_conflicts = session[:dde_conflicts]["data"]
    @demographics = session[:dde_conflicts]["params"]
    render :layout => "menu"
  end

  def create_new_dde_conflict_patient
    dde_return_path = session[:dde_conflicts]["return_path"]
    dde_params = session[:dde_conflicts]["params"]
    dde_token = session[:dde_token]
    dde_response = PatientService.add_dde_conflict_patient(dde_return_path, dde_params, dde_token)
    npid = dde_response["data"]["npid"]
    dde_params["person"].merge!({"identifiers" => {"National id" => npid}})
    person = PatientService.create_from_form(dde_params["person"])
    print_and_redirect("/patients/national_id_label?patient_id=#{person.id}", next_task(person.patient))
  end

  def create_dde_existing_patient_locally
    npid = params[:npid]
    dde_params = session[:dde_conflicts]["params"]
    dde_params["person"].merge!({"identifiers" => {"National id" => npid}})
    person = PatientService.create_from_form(dde_params["person"])
    print_and_redirect("/patients/national_id_label?patient_id=#{person.id}", next_task(person.patient))
  end
  
  def display_duplicate_filing_numbers
    duplicate_filing_numbers = PatientIdentifier.fetch_duplicate_filing_numbers(params[:patient_id])
    @active = duplicate_filing_numbers.first
    @dormant = duplicate_filing_numbers.last
  end
  
  def inconsistent_patient_filing_numbers
    duplicate_filing_numbers = PatientIdentifier.inconsistent_patient_filing_numbers(params[:patient_id])
    @active = duplicate_filing_numbers.first
    @dormant = duplicate_filing_numbers.last
  end
  
  def void_filing_numbers 

    identifiers = []
    (params[:filing_numbers].split(',') || []).each do |f|
      identifiers << "'#{f.squish}'"
    end

    ActiveRecord::Base.connection.execute <<EOF
      UPDATE patient_identifier SET voided = 1, void_reason = 'Patient had multiple filing numbers'
      WHERE voided = 0 AND patient_id = #{params[:patient_id]}
      AND identifier IN(#{identifiers.join(',')});
EOF

    redirect_to "/people/confirm?found_person_id=#{params[:patient_id]}"
  end

  def redirections
    person = Person.find(params[:person_id])
    hiv_session = false
    if current_program_location == "HIV program"
      hiv_session = true
    end
    
    if use_filing_number and hiv_session

      duplicate_filing_numbers = PatientIdentifier.inconsistent_patient_filing_numbers(person.person_id)
      if not duplicate_filing_numbers.first.blank? or not duplicate_filing_numbers.last.blank?
        redirect_to "/people/inconsistent_patient_filing_numbers?patient_id=#{person.person_id}"
        return
      end

      ##### checks for duplicate filing_number
      duplicate_filing_number = PatientIdentifier.fetch_duplicate_filing_numbers(person.person_id)
      if not duplicate_filing_number.blank?
        redirect_to "/people/display_duplicate_filing_numbers?patient_id=#{person.person_id}&data=#{duplicate_filing_number}"
        return
      end

      @archived_patient = PatientService.set_patient_filing_number(person.patient)

      if @archived_patient.blank?
        redirect_to "/patients/assign_filing_number_manually?patient_id=#{person.id}" and return
      else
        message = PatientService.patient_printing_message(person.patient, nil, creating_new_patient = true)
      end 
=begin
      unless message.blank?
        print_and_redirect("/patients/filing_number_national_id_and_archive_filing_number?patient_id=#{person.id}&:secondary_patient_id=#{@archived_patient.id}" , next_task(person.patient),message,true,person.id)
      else
        print_and_redirect("/patients/filing_number_and_national_id?patient_id=#{person.id}", next_task(person.patient))
      end
=end
      print_and_redirect("/patients/filing_number_and_national_id?patient_id=#{person.id}", next_task(person.patient)) && return
    else
      print_and_redirect("/patients/national_id_label?patient_id=#{person.id}", next_task(person.patient)) && return
    end

    redirect_to "/patients/show/#{person.id}"
  end

  def assign_filing_number_manually
  end

  def archive_patient
    primary = params[:primary_id]
    secondary = params[:secondary_id]

    patient_to_be_archived = Patient.find(secondary)
    current_patient = Patient.find(primary)
    PatientService.archive_patient(current_patient, patient_to_be_archived)

    message = PatientService.patient_printing_message(current_patient, patient_to_be_archived, creating_new_patient = true)
    print_and_redirect("/patients/filing_number_and_national_id?patient_id=#{primary}", next_task(current_patient), message, true, primary)
  end

  def load_patients_to_be_archived
    patients = PatientService.get_patient_to_be_archived_based_on_waste_state(params[:limit].to_i)
    data = [];

    filing_number_identifier_type = PatientIdentifierType.find_by_name('Filing number').id
    nat_identifier_type = PatientIdentifierType.find_by_name('National id').id

    (patients || []).each do |p|
      patient_id = p['patient_id']
     
      filing_number = PatientIdentifier.find_by_sql("SELECT identifier 
      number FROM patient_identifier WHERE voided = 0 AND patient_id = #{patient_id}
      AND identifier_type = #{filing_number_identifier_type}")
      
      number = filing_number.first['number'] rescue 'N/A'
    
      next if number.blank? || number == 'N/A'   
      count = PatientIdentifier.find(:all, 
        :conditions =>["identifier = ? AND identifier_type = ?", 
          number, filing_number_identifier_type])
      
      next if count.length > 1
     
      visit = Encounter.find_by_sql("SELECT MAX(encounter_datetime) 
      visit_date FROM encounter WHERE voided = 0 AND patient_id = #{patient_id}")
      
      visit_date = visit.first['visit_date'].to_date.strftime('%d/%b/%Y') rescue 'N/A'

      concept_name = ConceptName.find_by_name('Appointment date').concept_id
      app_date = Observation.find_by_sql("SELECT MAX(value_datetime) 
      app_date FROM obs WHERE voided = 0 AND person_id = #{patient_id}
      AND concept_id = #{concept_name}")
      
      app_date = app_date.first['app_date'].to_date.strftime('%d/%b/%Y') rescue 'N/A'
            
      state = ProgramWorkflowState.find(p['state']) rescue nil
      outcome = ConceptName.find_by_concept_id(state.concept_id).name unless state.blank?

      nat_number = PatientIdentifier.find_by_sql("SELECT identifier 
      number FROM patient_identifier WHERE voided = 0 AND patient_id = #{patient_id}
      AND identifier_type = #{nat_identifier_type}")
      
      nat_number = nat_number.first['number'] rescue 'N/A'

      data << {
        :outcome => outcome, :next_app => app_date,
        :patient_id => patient_id, :last_visit => visit_date,
        :filing_number => number, :national_id => nat_number
      }

    end

    render :text => data.to_json and return
  end


  def set_datetime
    if request.post?
      unless params[:set_day]== "" or params[:set_month]== "" or params[:set_year]== ""
        # set for 1 second after midnight to designate it as a retrospective date
        date_of_encounter = Time.mktime(params[:set_year].to_i,
					params[:set_month].to_i,
					params[:set_day].to_i,0,0,1)
        session[:datetime] = date_of_encounter #if date_of_encounter.to_date != Date.today
      end
      session[:stage_patient] = ""
      unless params[:id].blank?
        redirect_to next_task(Patient.find(params[:id]))
      else
        redirect_to :action => "index"
      end
    end
    @patient_id = params[:id]
  end

  def reset_datetime
    session[:datetime] = nil
    session[:stage_patient] = ""
    if params[:id].blank?
      redirect_to :action => "index" and return
    else
      redirect_to "/patients/show/#{params[:id]}" and return
    end
  end

  def find_by_arv_number
    if request.post?
      redirect_to :action => 'search' ,
        :identifier => "#{PatientIdentifier.site_prefix}-ARV-#{params[:arv_number]}" and return
    end
  end

  def find_by_hcc_number
    if request.post?
      redirect_to :action => 'search' ,
        :identifier => "#{PatientIdentifier.site_prefix}-HCC-#{params[:hcc_number]}" and return
    end
  end

  def find_by_filing_number
    if request.post?
      redirect_to :action => 'search' ,
        :identifier => "#{params[:prefix]}#{params[:filing_number]}" and return
    end
  end

  def find_by_tb_number
    if request.post?
      numbers_array = params[:tb_number].gsub(/\s+/, "").chars.each_slice(4).map(&:join)
      x = numbers_array.length - 1
      year = numbers_array[0].to_i
      surfix = ""
      (1..x).each { |i| surfix = "#{surfix}#{numbers_array[i].squish}" }
      if year > Date.today.year || surfix.to_i < 1
        render :template => "people/find_by_tb_number" and return
      end

      tb_number = "#{params[:tb_prefix].upcase}-TB #{year} #{surfix.to_i}"
      redirect_to :action => 'search' ,
        :identifier => tb_number and return
    end
  end

  def correct_tb_numbers
    @identifier_types = ["Legacy Pediatric id","National id","Legacy National id","Old Identification Number"]
    identifier_types = PatientIdentifierType.find(:all,
      :conditions=>["name IN (?)",@identifier_types]
    ).collect{| type |type.id }

    @patient = Patient.find(params[:patient_id] || params[:id])
    if request.post?
      current_date = Date.today
      current_date = session[:datetime].to_date if !session[:datetime].blank?

      prefix = params[:tb_prefix].upcase
      session_date = "#{prefix}-TB #{current_date.year.to_s}"
      patient_exists = PatientIdentifier.find(:all,
        :conditions => ['identifier_type = ?
                                         AND patient_id = ? AND voided = 0', params[:identifiers][0][:identifier_type].to_i , params[:patient_id]]).first

      if ! patient_exists.blank?
        patient_exists.voided = 1
        patient_exists.save
      end
      if params[:name].upcase == "VOIDING PERMANENTLY"
        redirect_to "/patients/tb_treatment_card?patient_id=#{params[:patient_id]}" and return
      end
      if !params[:number].blank?
        numbers_array = params[:number].gsub(/\s+/, "").chars.each_slice(4).map(&:join)
        x = numbers_array.length - 1
        year = numbers_array[0].to_i
        surfix = ""
        (1..x).each { |i| surfix = "#{surfix}#{numbers_array[i].squish}" }
        if year > Date.today.year || surfix.to_i < 1
          return
        end
        patient_number = "#{prefix}-TB #{year} #{surfix.to_i}"
        patient_exists = PatientIdentifier.find_by_sql("SELECT * FROM patient_identifier
                WHERE REPLACE(identifier, ' ', '') = REPLACE('#{patient_number}', ' ', '') AND voided =0 ").first

        if ! patient_exists.blank?
          patient_exists.identifier = patient_number
          patient_exists.save!
        else
          pat = PatientIdentifier.new()
          pat.patient_id = params[:patient_id]
          pat.identifier = patient_number
          pat.identifier_type = params[:identifiers][0][:identifier_type].to_i
          pat.location_id = params[:identifiers][0][:location_id].to_i
          pat.creator = 1
          pat.save!
        end
        redirect_to "/patients/tb_treatment_card?patient_id=#{params[:patient_id]}" and return
      end
      type = PatientIdentifier.find_by_sql("SELECT * FROM patient_identifier
																						WHERE identifier_type = #{params[:identifiers][0][:identifier_type].to_i} and identifier LIKE '%#{session_date}%'
																						AND voided = 0 ORDER BY patient_identifier_id DESC")
      type = type.first.identifier.split(" ") rescue ""
      if type.include?(current_date.year.to_s)
        surfix = (type.last.to_i + 1)
      else
        surfix = 1
      end
      pat = PatientIdentifier.new()
      pat.patient_id = params[:patient_id]
      pat.identifier = "#{session_date} #{surfix}"
      pat.identifier_type = params[:identifiers][0][:identifier_type].to_i
      pat.location_id = params[:identifiers][0][:location_id].to_i
      pat.creator = 1
      pat.save!

      redirect_to "/patients/tb_treatment_card?patient_id=#{params[:patient_id]}" and return
    end
  end

  # List traditional authority containing the string given in params[:value]
  def traditional_authority
    district_id = District.find_by_name("#{params[:filter_value]}").id
    traditional_authority_conditions = ["name LIKE (?) AND district_id = ?", "%#{params[:search_string]}%", district_id]

    traditional_authorities = TraditionalAuthority.find(:all,:conditions => traditional_authority_conditions, :order => 'name')
    traditional_authorities = traditional_authorities.map do |t_a|
      "<li value=\"#{t_a.name}\">#{t_a.name}</li>"
    end
    render :text => traditional_authorities.join('') + "<li value='Other'>Other</li>" and return
  end

  # Regions containing the string given in params[:value]
  def region_of_origin
    region_conditions = ["name LIKE (?)", "#{params[:value]}%"]

    regions = Region.find(:all,:conditions => region_conditions, :order => 'region_id')
    regions = regions.map do |r|
      "<li value=\"#{r.name}\">#{r.name}</li>"
    end
    render :text => regions.join('')  and return
  end

  def region
    region_conditions = ["name LIKE (?)", "#{params[:value]}%"]

    regions = Region.find(:all,:conditions => region_conditions, :order => 'region_id')
    regions = regions.map do |r|
      if r.name != "Foreign"
        "<li value=\"#{r.name}\">#{r.name}</li>"
      end
    end
    render :text => regions.join('')  and return
  end

  # Districts containing the string given in params[:value]
  def district
    region_id = Region.find_by_name("#{params[:filter_value]}").id
    region_conditions = ["name LIKE (?) AND region_id = ? ", "#{params[:search_string]}%", region_id]

    districts = District.find(:all,:conditions => region_conditions, :order => 'name')
    districts = districts.map do |d|
      "<li value=\"#{d.name}\">#{d.name}</li>"
    end
    render :text => districts.join('') + "<li value='Other'>Other</li>" and return
  end

  def tb_initialization_district
    districts = District.find(:all, :order => 'name')
    districts = districts.map do |d|
      "<li value=\"#{d.name}\">#{d.name}</li>"
    end
    render :text => districts.join('') + "<li value='Other'>Other</li>" and return
  end

	def tb_initialization_location
    locations = Location.find_by_sql("SELECT name FROM location WHERE description like '%Health Facility' AND name LIKE '#{params[:search_string]}%'order by name LIMIT 10")
    locations = locations.map do |d|
      "<li value=\"#{d.name}\">#{d.name}</li>"
    end
    render :text => locations.join('') + "<li value='Other'>Other</li>" and return
  end
	# Villages containing the string given in params[:value]
  def village
    traditional_authority_id = TraditionalAuthority.find_by_name("#{params[:filter_value]}").id
    village_conditions = ["name LIKE (?) AND traditional_authority_id = ?", "%#{params[:search_string]}%", traditional_authority_id]

    villages = Village.find(:all,:conditions => village_conditions, :order => 'name')
    villages = villages.map do |v|
      "<li value=\"" + v.name + "\">" + v.name + "</li>"
    end
    render :text => villages.join('') + "<li value='Other'>Other</li>" and return
  end

  # Landmark containing the string given in params[:value]
  def landmark
    landmarks = PersonAddress.find(:all, :select => "DISTINCT address1" , :conditions => ["city_village = (?) AND address1 LIKE (?)", "#{params[:filter_value]}", "#{params[:search_string]}%"])
    landmarks = landmarks.map do |v|
      "<li value=\"#{v.address1}\">#{v.address1}</li>"
    end
    render :text => landmarks.join('') + "<li value='Other'>Other</li>" and return
  end

=begin
  #This method was taken out of encounter model. It is been used in
  #people/index (view) which seems not to be used at present.
  def count_by_type_for_date(date)
    # This query can be very time consuming, because of this we will not consider
    # that some of the encounters on the specific date may have been voided
    ActiveRecord::Base.connection.select_all("SELECT count(*) as number, encounter_type FROM encounter GROUP BY encounter_type")
    todays_encounters = Encounter.find(:all, :include => "type", :conditions => ["DATE(encounter_datetime) = ?",date])
    encounters_by_type = Hash.new(0)
    todays_encounters.each{|encounter|
      next if encounter.type.nil?
      encounters_by_type[encounter.type.name] += 1
    }
    encounters_by_type
  end
=end

  def art_info_for_remote(national_id)

    patient = PatientService.search_by_identifier(national_id).first.patient rescue []
    return {} if patient.blank?

    results = {}
    result_hash = {}

    if PatientService.art_patient?(patient)
      clinic_encounters = ["APPOINTMENT","HIV CLINIC CONSULTATION","VITALS","HIV STAGING",'ART ADHERENCE','DISPENSING','HIV CLINIC REGISTRATION']
      clinic_encounter_ids = EncounterType.find(:all,:conditions => ["name IN (?)",clinic_encounters]).collect{| e | e.id }
      first_encounter_date = patient.encounters.find(:first,
        :order => 'encounter_datetime',
        :conditions => ['encounter_type IN (?)',clinic_encounter_ids]).encounter_datetime.strftime("%d-%b-%Y") rescue 'Uknown'

      last_encounter_date = patient.encounters.find(:first,
        :order => 'encounter_datetime DESC',
        :conditions => ['encounter_type IN (?)',clinic_encounter_ids]).encounter_datetime.strftime("%d-%b-%Y") rescue 'Uknown'


      art_start_date = PatientService.patient_art_start_date(patient.id).strftime("%d-%b-%Y") rescue 'Uknown'
      last_given_drugs = patient.person.observations.recent(1).question("ARV REGIMENS RECEIVED ABSTRACTED CONSTRUCT").last rescue nil
      last_given_drugs = last_given_drugs.value_text rescue 'Uknown'

      program_id = Program.find_by_name('HIV PROGRAM').id
      outcome = PatientProgram.find(:first,:conditions =>["program_id = ? AND patient_id = ?",program_id,patient.id],:order => "date_enrolled DESC")
      art_clinic_outcome = outcome.patient_states.last.program_workflow_state.concept.fullname rescue 'Unknown'

      date_tested_positive = patient.person.observations.recent(1).question("FIRST POSITIVE HIV TEST DATE").last rescue nil
      date_tested_positive = date_tested_positive.to_s.split(':')[1].strip.to_date.strftime("%d-%b-%Y") rescue 'Uknown'

      cd4_info = patient.person.observations.recent(1).question("CD4 COUNT").all rescue []
      cd4_data_and_date_hash = {}

      (cd4_info || []).map do | obs |
        cd4_data_and_date_hash[obs.obs_datetime.to_date.strftime("%d-%b-%Y")] = obs.value_numeric
      end

      result_hash = {
        'art_start_date' => art_start_date,
        'date_tested_positive' => date_tested_positive,
        'first_visit_date' => first_encounter_date,
        'last_visit_date' => last_encounter_date,
        'cd4_data' => cd4_data_and_date_hash,
        'last_given_drugs' => last_given_drugs,
        'art_clinic_outcome' => art_clinic_outcome,
        'arv_number' => PatientService.get_patient_identifier(patient, 'ARV Number')
      }
    end

    results["person"] = result_hash
    return results
  end

  def art_info_for_remote(national_id)
    patient = PatientService.search_by_identifier(national_id).first.patient rescue []
    return {} if patient.blank?

    results = {}
    result_hash = {}

    if PatientService.art_patient?(patient)
      clinic_encounters = ["APPOINTMENT","HIV CLINIC CONSULTATION","VITALS","HIV STAGING",'ART ADHERENCE','DISPENSING','HIV CLINIC REGISTRATION']
      clinic_encounter_ids = EncounterType.find(:all,:conditions => ["name IN (?)",clinic_encounters]).collect{| e | e.id }
      first_encounter_date = patient.encounters.find(:first,
        :order => 'encounter_datetime',
        :conditions => ['encounter_type IN (?)',clinic_encounter_ids]).encounter_datetime.strftime("%d-%b-%Y") rescue 'Uknown'

      last_encounter_date = patient.encounters.find(:first,
        :order => 'encounter_datetime DESC',
        :conditions => ['encounter_type IN (?)',clinic_encounter_ids]).encounter_datetime.strftime("%d-%b-%Y") rescue 'Uknown'

      art_start_date = patient.art_start_date.strftime("%d-%b-%Y") rescue 'Uknown'
      last_given_drugs = patient.person.observations.recent(1).question("ARV REGIMENS RECEIVED ABSTRACTED CONSTRUCT").last rescue nil
      last_given_drugs = last_given_drugs.value_text rescue 'Uknown'

			program_id = Program.find_by_name('HIV PROGRAM').id
      outcome = PatientProgram.find(:first,:conditions =>["program_id = ? AND patient_id = ?",program_id,patient.id],:order => "date_enrolled DESC")
      art_clinic_outcome = outcome.patient_states.last.program_workflow_state.concept.fullname rescue 'Unknown'

      date_tested_positive = patient.person.observations.recent(1).question("FIRST POSITIVE HIV TEST DATE").last rescue nil
      date_tested_positive = date_tested_positive.to_s.split(':')[1].strip.to_date.strftime("%d-%b-%Y") rescue 'Uknown'

      cd4_info = patient.person.observations.recent(1).question("CD4 COUNT").all rescue []
      cd4_data_and_date_hash = {}

      (cd4_info || []).map do | obs |
        cd4_data_and_date_hash[obs.obs_datetime.to_date.strftime("%d-%b-%Y")] = obs.value_numeric
      end

      result_hash = {
        'art_start_date' => art_start_date,
        'date_tested_positive' => date_tested_positive,
        'first_visit_date' => first_encounter_date,
				'last_visit_date' => last_encounter_date,
        'cd4_data' => cd4_data_and_date_hash,
        'last_given_drugs' => last_given_drugs,
        'art_clinic_outcome' => art_clinic_outcome,
        'arv_number' => PatientService.get_patient_identifier(patient, 'ARV Number')
      }
    end

    results["person"] = result_hash
    return results
  end

  def occupations
    occupations = ["MDF Active", "MDF Reserve", "MDF Retired", "Civilian"]
    return occupations
    #['','Driver','Housewife','Messenger','Business','Farmer','Salesperson','Teacher',
    #'Student','Security guard','Domestic worker', 'Police','Office worker',
    #'Preschool child','Mechanic','Prisoner','Craftsman','Healthcare Worker','Soldier'].sort.concat(["Other","Unknown"])

  end

  def edit
    # only allow these fields to prevent dangerous 'fields' e.g. 'destroy!'
    valid_fields = ['birthdate','gender']
    unless valid_fields.include? params[:field]
      redirect_to :controller => 'patients', :action => :demographics, :id => params[:id]
      return
    end

    @person = Person.find(params[:id])
    if request.post? && params[:field]
      if params[:field]== 'gender'
        @person.gender = params[:person][:gender]
      elsif params[:field] == 'birthdate'
        if params[:person][:birth_year] == "Unknown"
          @person.set_birthdate_by_age(params[:person]["age_estimate"])
        else
          PatientService.set_birthdate(@person, params[:person]["birth_year"],
						params[:person]["birth_month"],
						params[:person]["birth_day"])
        end
        @person.birthdate_estimated = 1 if params[:person]["birthdate_estimated"] == 'true'
        @person.save
      end
      @person.save
      redirect_to :controller => :patients, :action => :edit_demographics, :id => @person.id
    else
      @field = params[:field]
      @field_value = @person.send(@field)
    end
  end

  def dde_search
    # result = '[{"person":{"created_at":"2012-01-06T10:08:37Z","data":{"addresses":{"state_province":"Balaka","address2":"Hospital","city_village":"New Lines Houses","county_district":"Kalembo"},"birthdate":"1989-11-02","attributes":{"occupation":"Police","cell_phone_number":"0999925666"},"birthdate_estimated":"0","patient":{"identifiers":{"diabetes_number":""}},"gender":"M","names":{"family_name":"Banda","given_name":"Laz"}},"birthdate":"1989-11-02","creator_site_id":"1","birthdate_estimated":false,"updated_at":"2012-01-06T10:08:37Z","creator_id":"1","gender":"M","id":1,"family_name":"Banda","given_name":"Laz","remote_version_number":null,"version_number":"0","national_id":null}}]'

    @dde_server = GlobalProperty.find_by_property("dde_server_ip").property_value rescue ""

    @dde_server_username = GlobalProperty.find_by_property("dde_server_username").property_value rescue ""

    @dde_server_password = GlobalProperty.find_by_property("dde_server_password").property_value rescue ""

    url = "http://#{@dde_server_username}:#{@dde_server_password}@#{@dde_server}" +
      "/people/find.json?given_name=#{params[:given_name]}" +
      "&family_name=#{params[:family_name]}&gender=#{params[:gender]}"

    result = RestClient.get(url)
    render :text => result, :layout => false
  end

  def demographics
    @person = Person.find(params[:id])
		@patient_bean = PatientService.get_patient(@person)
		render :layout => 'menu'
  end

  def duplicates
    @duplicates = []
    people = PatientService.person_search(params[:search_params])
    people.each do |person|
      @duplicates << PatientService.get_patient(person)
    end unless people == "found duplicate identifiers"

    if create_from_dde_server
      @remote_duplicates = []
      PatientService.search_dde_by_identifier(params[:search_params][:identifier], session[:dde_token])["data"]["hits"].each do |search_result|
        @remote_duplicates << PatientService.get_remote_dde_person(search_result)
      end rescue nil
    end

    @selected_identifier = params[:search_params][:identifier]
    render :layout => 'menu'
  end

  def filter_duplicates
    people = PatientService.person_search_by_identifier_and_name(params)
    hash = {}
    (people || []).each do |person|
      patient = PatientService.get_patient(person)
      first_name =  patient.name.split[0] rescue ''
      last_name =  patient.name.split[1] rescue ''
      hash[person.person_id] = {"national_id" => params[:identifier],
        "first_name" => first_name,
        "last_name" => last_name, "dob" => patient.birth_date,
        "gender" => patient.sex, "age" => patient.age }
    end
    render :text => hash.to_json
  end

  def reassign_dde_national_id
    person = DDEService.reassign_dde_identification(params[:dde_person_id],params[:local_person_id])
    print_and_redirect("/patients/national_id_label?patient_id=#{person.id}", next_task(person.patient))
  end

  def remote_duplicates
    if params[:patient_id]
      @primary_patient = PatientService.get_patient(Person.find(params[:patient_id]))
    else
      @primary_patient = nil
    end

    @dde_duplicates = []
    if create_from_dde_server
      PatientService.search_from_dde_by_identifier(params[:identifier]).each do |person|
        @dde_duplicates << PatientService.get_dde_person(person)
      end
    end

    if @primary_patient.blank? and @dde_duplicates.blank?
      redirect_to :action => 'search',:identifier => params[:identifier] and return
    end
    render :layout => 'menu'
  end

  def reassign_national_identifier
    patient = Patient.find(params[:person_id])
    if create_from_dde_server
      passed_params = PatientService.demographics(patient.person)
      new_npid = PatientService.create_from_dde_server_only(passed_params)
      npid = PatientIdentifier.new()
      npid.patient_id = patient.id
      npid.identifier_type = PatientIdentifierType.find_by_name('National ID')
      npid.identifier = new_npid
      npid.save
    else
      PatientIdentifierType.find_by_name('National ID').next_identifier({:patient => patient})
    end
    npid = PatientIdentifier.find(:first,
      :conditions => ["patient_id = ? AND identifier = ?
           AND voided = 0", patient.id,params[:identifier]])
    npid.voided = 1
    npid.void_reason = "Given another national ID"
    npid.date_voided = Time.now()
    npid.voided_by = current_user.id
    npid.save

    print_and_redirect("/patients/national_id_label?patient_id=#{patient.id}", next_task(patient))
  end

  def create_person_from_dde
    person = DDEService.get_remote_person(params[:remote_person_id])

    print_and_redirect("/patients/national_id_label?patient_id=#{person.id}", next_task(person.patient))
  end

  def demographics_remote
    identifier = params[:person][:patient][:identifiers]["national_id"] rescue nil
    identifier = params["person"]["patient"]["identifiers"]["National id"] if identifier.nil?
    people = PatientService.search_by_identifier(identifier)
    render :text => "" and return if people.blank?
    render :text => PatientService.remote_demographics(people.first).to_json rescue nil
    return
  end

  def area_graph_adults
    @patient_bean = PatientService.get_patient(Person.find(params[:id]))
    weight_obs = Observation.find(:all,:joins =>"INNER JOIN encounter USING(encounter_id)",
      :conditions =>["patient_id=? AND encounter_type=?
      AND concept_id=?",params[:id],EncounterType.find_by_name('Vitals').id,
        ConceptName.find_by_name('WEIGHT (KG)').concept_id],
      :group =>"Date(encounter_datetime)",
      :order =>"encounter_datetime DESC")

    @start_date = weight_obs.last.obs_datetime.to_date rescue Date.today
    @weights = [] ; weights = {} ; count = 1
    (weight_obs || []).each do |weight|
      next if weight.value_numeric.blank?
      weights[weight.obs_datetime] = weight.value_numeric
      break if count > 12
      count+=1
    end

    (weights || {}).sort{|a,b|a[0].to_date <=> b[0].to_date}.each do |date,weight|
      @weights << [date.to_date , weight]
    end

    @weights = @weights.to_json
    render :partial => "area_chart_adults" and return
  end

  def find_by_menu
    @select_options = ["ARV Number", "HCC Number"]
    if use_filing_number
      @select_options << "Filing number (active)"
      @select_options << "Filing number (dormant)"
    end

    if request.post?
      redirect_to("/people/find_by_hcc_number") and return if (params[:find_by].match(/HCC/i))
      redirect_to("/people/find_by_arv_number") and return if (params[:find_by].match(/ARV/i))
      redirect_to("/people/find_by_filing_number/#{params[:find_by]}") and return if (params[:find_by].match(/filing/i))
    end

    #render :layout => "application"
  end
  
  ##############################################
  def get_patient_name
    patient_id = params[:patient_id]

    person = Person.find(patient_id)
    names = PersonName.find_last_by_person_id(patient_id)
    begin
      middle_name = names.middle_name unless names.middle_name.match(/N\/A|Unknown/i)
    rescue
      middle_name = nil
    end

    render :text => {
      :gender => person.gender, :age => person.age,
      :name => "#{names.given_name} #{middle_name} #{names.family_name}".squish,
      :birthdate => PatientService.birthdate_formatted(person)}.to_json
  end

  def get_initial_vital_signs
    patient_id = params[:patient_id]
    vitals = EncounterType.find_by_name('Vitals')
    vital_reading = Encounter.find(:first, 
      :conditions =>["encounter_type = ? AND patient_id = ?",
        vitals.id, patient_id],:select =>"MIN(encounter_datetime) AS date, encounter_id")

    begin 
      date = vital_reading['date'].to_date
      encounter_id = vital_reading['encounter_id'].to_i

      obs = Observation.find(:all, :conditions =>["person_id = ? 
        AND encounter_id = ? AND obs_datetime BETWEEN ? AND ?", 
          patient_id, encounter_id, date.strftime('%Y-%m-%d 00:00:00'),
          date.strftime('%Y-%m-%d 23:59:59')])
    rescue
      obs = []
    end

    weight  = nil
    height  = nil
    bmi     = nil

    (obs || []).each do |ob|
      name = ob.concept.fullname
      if name.match(/weight/i) and weight.blank?
        weight = ob.value_numeric.to_f rescue nil
      elsif name.match(/height/i) and height.blank?
        height = ob.value_numeric.to_f rescue nil
      end
    end

    if not weight.blank? and not height.blank?
      bmi = (weight.to_f/(height.to_f*height.to_f)*10000).round(1)
    end

    render :text => {
      :weight => weight,:height => height, :bmi => bmi}.to_json
  end

  def get_patient_identifiers
    patient_id = params[:patient_id]
    identifier_type = PatientIdentifierType.find_by_name('National ID')

    nid = PatientIdentifier.find(:first,
      :conditions => ["identifier_type = ? AND patient_id = ?",
        identifier_type.id, patient_id]).identifier rescue 'N/A'

    identifier_type = PatientIdentifierType.find_by_name('Filing number')
    filing_number = PatientIdentifier.find(:first,
      :conditions => ["identifier_type = ? AND patient_id = ?",
        identifier_type.id, patient_id]).identifier rescue nil

    if filing_number.blank?
      identifier_type = PatientIdentifierType.find_by_name('Archived filing number')
      filing_number = PatientIdentifier.find(:first,
        :conditions => ["identifier_type = ? AND patient_id = ?",
          identifier_type.id, patient_id]).identifier rescue nil
    end

    identifier_type = PatientIdentifierType.find_by_name('ARV Number')
    arv_number = PatientIdentifier.find(:first,
      :conditions => ["identifier_type = ? AND patient_id = ?",
        identifier_type.id, patient_id]).identifier rescue nil


    render :text => {
      :national_id => nid,
      :filing_number => filing_number,
      :arv_number => arv_number
    }.to_json
     
  end

  def get_patient_art_start_date
    patient_id = params[:patient_id]
    program_id = Program.find_by_name('HIV program').id

    date = Patient.find_by_sql <<EOF
SELECT
  date_antiretrovirals_started(#{patient_id}, min(`s`.`start_date`)) AS `earliest_start_date`
FROM patient_state s
INNER JOIN patient_program p ON p.patient_program_id = s.patient_program_id
WHERE s.voided = 0 AND (`p`.`program_id` = #{program_id}) 
AND p.voided = 0 AND (s.state = 7)
AND p.patient_id = #{patient_id}
GROUP BY p.patient_id;
EOF

    render :text => {
      :start_date => (date.first['earliest_start_date'].to_date.strftime('%d/%b/%Y') rescue nil)
    }.to_json
  end

  def get_patient_duration_on_art
    begin
      start_date = params[:start_date].to_date
      months = Patient.find_by_sql("SELECT timestampdiff(month, DATE('#{start_date}'), current_date()) AS months;")
      months = ("#{months.first['months'].to_i rescue nil} month(s)")
    rescue
      months = 'N/A'
    end

    render :text => {
      :duration => months
    }.to_json
  end

  def get_transfer_in
    patient_id = params[:patient_id]
    transfer_in_date = Person.find(patient_id).observations.recent(1).\
      question("ART start date").all.\
      collect{|o| o.value_datetime }.last.to_date rescue []

    render :text => {
      :transfer_in => transfer_in = (transfer_in_date.blank? == true ? 'No' : 'Yes'),
      :transfer_in_date => transfer_in_date
    }.to_json
  end

  def get_patient_current_regimen
    patient_id = params[:patient_id]
    current_reg = Patient.find_by_sql("SELECT patient_current_regimen(#{patient_id}, current_date()) AS regimen;")
    render :text => {
      :regimen => (current_reg.first['regimen'] rescue nil)
    }.to_json
  end

  def get_current_address
    patient_id = params[:patient_id]
    begin
      address = PersonAddress.find_last_by_person_id(patient_id)
      phaddress = address.city_village
      landmark = address.address1
    rescue
      address = 'Unknown'
      landmark = 'Unknown'
    end

    render :text => {:current_residence => phaddress, :landmark => landmark}.to_json 
  end

  def get_current_outcome
    patient_id = params[:patient_id]
    current_outcome = Patient.find_by_sql("SELECT patient_outcome(#{patient_id}, current_date()) AS outcome;")
    render :text => {
      :outcome => (current_outcome.first['outcome'] rescue nil)
    }.to_json
  end

  def get_occupation
    patient_id = params[:patient_id]
    person_attribute_type = PersonAttributeType.find_by_name('Occupation')

    occupation = PersonAttribute.find(:last,
      :conditions => ["person_attribute_type_id = ? AND person_id = ?",
        person_attribute_type.id, patient_id]).value rescue nil

    render :text => {:occupation =>occupation}.to_json
  end

  def get_guardian
    patient_id = params[:patient_id]
    relationship = Relationship.find(:last,:conditions =>["person_a = ?", patient_id])
    unless relationship.blank?
      names = PersonName.find_last_by_person_id(relationship.person_b)
      begin
        middle_name = names.middle_name unless names.middle_name.match(/N\/A|Unknown/i)
      rescue
        middle_name = nil
      end
      
      begin
        name = "#{names.given_name} #{middle_name} #{names.family_name}".squish
      rescue
        name = nil
      end
      
      type = RelationshipType.find(relationship.relationship).b_is_to_a rescue nil
      name = "#{name} (#{type})" unless type.blank? 
    end
    
    render :text => {:guardian_name => name}.to_json
  end

  def get_agrees_to_followup
    patient_id = params[:patient_id]
    agrees_to_followup = ConceptName.find_by_name('Agrees to followup').concept_id

    obs = Observation.find(:last,
      :conditions =>["person_id = ? AND concept_id = ?",
        patient_id, agrees_to_followup]).answer_string rescue nil

    render :text => {:agrees_to_followup => obs}.to_json
  end


  def get_tb_stats
    patient_id = params[:patient_id]
    tb_stats = []
    tb_stats  << ConceptName.find_by_name('Pulmonary tuberculosis within the last 2 years').concept_id
    tb_stats  << ConceptName.find_by_name('Extrapulmonary tuberculosis (EPTB)').concept_id
    tb_stats  << ConceptName.find_by_name('Pulmonary tuberculosis (current)').concept_id
    tb_stats  << ConceptName.find_by_name("Kaposis sarcoma").concept_id

    who_stage_criteria = ConceptName.find_by_name('Who stages criteria present').concept_id
    hiv_staging_type = EncounterType.find_by_name('HIV staging').id

    hiv_staging = Encounter.find(:last,
      :conditions =>["patient_id = ? AND encounter_type = ?",
        patient_id, hiv_staging_type],
      :select =>"DATE(MAX(encounter_datetime)) AS encounter_date, encounter_id")

    last_2_yrs  = 'N/A'
    eptb        = 'N/A'
    tb_current  = 'N/A'
    ks          = 'N/A'

    unless hiv_staging.blank?
      last_2_yrs  = 'No'
      eptb        = 'No'
      tb_current  = 'No'
      ks          = 'No'

      obs = Observation.find(:all,
        :joins => "INNER JOIN concept_name n ON n.concept_id = obs.value_coded AND n.voided = 0",
        :conditions =>["person_id = ? AND obs.concept_id = ? AND encounter_id = ?",
          patient_id, who_stage_criteria, hiv_staging['encounter_id']],
        :select => "n.name tb_stat, obs_datetime, value_text answer")
    
      (obs || []).each do |ob|
        name = ob['tb_stat']
        answer = ob['answer']
        next if answer.match(/No/i)

        if name.match(/last/i)
          last_2_yrs = 'Yes'
        elsif name.match(/eptb/i)
          eptb = 'Yes'
        elsif name.match(/current/i)
          tb_current = 'Yes'
        elsif name.match(/kapos/i)
          ks = 'Yes'
        end
      end  
    end

    render :text => {:ks => ks, :eptb => eptb, 
      :last_2_yrs => last_2_yrs, :tb_current => tb_current}.to_json
  end

  def get_date_place_of_pos_hiv_test
    patient_id = params[:patient_id]
    test_date = ConceptName.find_by_name('Confirmatory HIV test date').concept_id
    test_location = ConceptName.find_by_name('Confirmatory HIV test location').concept_id

    test_date = Observation.find(:last,
      :conditions =>["person_id = ? AND concept_id = ?",
        patient_id, test_date]).value_datetime.to_date.strftime('%d/%b/%Y') rescue 'N/A'

    test_location = Observation.find(:last,
      :conditions =>["person_id = ? AND concept_id = ?",
        patient_id, test_location]).value_text rescue nil

    render :text => {:test_date => test_date, :test_location => test_location}.to_json
  end
 
  def get_date_of_first_line
    patient_id = params[:patient_id]

    begin
      concept_id = ConceptName.find_by_name('ART START DATE').concept_id
      art_start_date = Observation.find(:last,
        :conditions =>["person_id = ? AND concept_id = ?",
          patient_id, concept_id], :select =>"value_datetime AS date_of_first_line")
      first_line_date = art_start_date['date_of_first_line'].to_date.strftime('%d/%b/%Y')
    rescue
      reg_category = ConceptName.find_by_name('Regimen Category').concept_id
      regimens = ['5A','6A','4P','4A','3P','3A','2A','2P','1A','1P','0A','0P']

      latest_date = Observation.find(:first,
        :conditions =>["person_id = ? AND concept_id = ? AND value_text IN(?)",
          patient_id, reg_category, regimens], :select =>"MIN(obs_datetime) AS date_of_first_line")
      first_line_date = latest_date['date_of_first_line'].to_date.strftime('%d/%b/%Y') rescue nil
    end

    render :text => {:first_line_date => first_line_date}.to_json
  end
   
  def get_patient_weight_trail
    patient_id = params[:patient_id]

    weight_obs = Observation.find(:all,:joins =>"INNER JOIN encounter USING(encounter_id)",
      :conditions =>["patient_id=? AND encounter_type=?
      AND concept_id=?",patient_id, EncounterType.find_by_name('Vitals').id,
        ConceptName.find_by_name('WEIGHT (KG)').concept_id],
      :group =>"Date(encounter_datetime)",
      :order =>"encounter_datetime DESC")

    @start_date = weight_obs.last.obs_datetime.to_date rescue Date.today
    @weights = [] ; weights = {} ; count = 1
    (weight_obs || []).each do |weight|
      next if weight.value_numeric.blank?
      weights[weight.obs_datetime] = weight.value_numeric
      break if count > 12
      count+=1
    end

    (weights || {}).sort{|a,b|a[0].to_date <=> b[0].to_date}.each do |date,weight|
      @weights << [date.to_date , weight]
    end

    render :text => @weights.to_json
  end

  def get_patient_next_task
    patient_id = params[:patient_id]
    patient = Patient.find(patient_id)
    session_date = session[:datetime].to_date rescue Date.today
    task = main_next_task(Location.current_location, Patient.find(patient_id), session_date)
    next_url = next_task(patient)
    render :text => {
      :task => task.encounter_type, :url => next_url
    }.to_json
  end

  def get_latest_vl_result

    patient_id = params[:patient_id]
    @patient = Patient.find(patient_id)
    @patient_identifiers = LabController.new.id_identifiers(@patient)
    results_available = 'false'
    @data = {}


    if national_lims_activated
      settings = YAML.load_file("#{Rails.root}/config/lims.yml")[Rails.env]
      url = settings['lims_national_dashboard_ip'] + "/api/vl_result_by_npid?npid=#{@patient_identifiers}&test_status=verified__reviewed"

      data = JSON.parse(RestClient.get(url)) rescue []

      results_available = 'true' if ((!data.blank? && data.last[2].downcase == 'verified') rescue false)

      vl_latest_date = data.last[0].to_date rescue nil
      vl_result = data.last[1]["Viral Load"] rescue nil

      vl_result = 'Rejected' if (data.last[1]['Viral Load'] rescue nil) == 'Rejected'

      date_vl_result_given = nil
      if ((data.last[2].downcase == 'reviewed') rescue false)
        date_vl_result_given = Observation.find(:last, :conditions => ['person_id =? AND concept_id =? AND value_text
                                                                         REGEXP ? AND DATE(obs_datetime) = ?',@patient.id,
            Concept.find_by_name('Viral load').concept_id,
            'Result given to patient', data.last[3].to_date]
        ).value_datetime rescue nil

        date_vl_result_given = data.last[3].to_date if date_vl_result_given.blank?
      end
    else

      results = Lab.latest_result_by_test_type(@patient, 'HIV_viral_load', @patient_identifiers) rescue nil
      results_available = 'true' if !results.blank?
      vl_latest_date = results[0].split('::')[0].to_date.strftime("%d-%b-%Y") rescue nil
      vl_latest_result = results[1]["TestValue"] rescue nil
      vl_modifier = results[1]["Range"] rescue nil

      vl_request = Observation.find(:last, :conditions => ["person_id = ? AND concept_id = ? AND value_coded IS NOT NULL",
          @patient.patient_id,
          Concept.find_by_name("Viral load").concept_id]).answer_string.squish.upcase rescue nil

      repeat_vl_request = Observation.find(:last, :conditions => ["person_id = ? AND concept_id = ?
                AND value_text =?", @patient.patient_id, Concept.find_by_name("Viral load").concept_id,
          "Repeat"]).answer_string.squish.upcase rescue nil

      date_vl_result_given = Observation.find(:last, :conditions => ["person_id =? AND concept_id =? AND value_text REGEXP ?",
          @patient.patient_id, Concept.find_by_name("Viral load").concept_id,
          'Result given to patient']).value_datetime.strftime("%d-%b-%Y") rescue nil

      data = {}
      if vl_latest_result.blank?
        if vl_request == "YES" || repeat_vl_request == "REPEAT"
          vl_result = "<span style='font-weight: bold; color: red;'>(Requested)</span>"
        else
          vl_result = "<span style='font-weight: bold; color: red;'>(Not requested)</span>"
        end
      else
        high_vl = true
        if (vl_latest_result.to_i < 1000)
          high_vl = false
        end

        if (vl_latest_result.to_i == 1000)
          if (vl_modifier == '<')
            high_vl = false
          end
        end
        vl_result =  vl_modifier.to_s + vl_latest_result.to_s
        if high_vl
          vl_result = "<span style='color: red; font-weight: bolder;'>#{vl_result}</span>"
        end
      end

    end
    @data["vl_result"] = vl_result
    @data["vl_date"] = vl_latest_date
    @data["vl_date_given"] = date_vl_result_given
    @data["results_available"] = results_available
    render :text => @data.to_json and return
  end
  
  def get_reason_for_starting_art
    patient_id = params[:patient_id]
    reason_for_art_eligibility = Patient.find_by_sql("SELECT patient_reason_for_starting_art_text(#{patient_id}) AS reason;")
    render :text => {
      :reason_for_starting_art => (reason_for_art_eligibility.first['reason'] rescue nil)
    }.to_json
  end

  def get_military_rank
    person = Person.find(params[:patient_id])
    attribute_type = PersonAttributeType.find_by_name("Military Rank").id rescue ""
    person_attribute = person.person_attributes.find_by_person_attribute_type_id(attribute_type)
    value = person_attribute.value rescue ""
    render :text => value and return
  end

  def update_person_address
    @patient = Patient.find(params[:patient_id])
    if request.post?
      person_address = PersonAddress.find(:last, :conditions => ["person_id =?", params[:patient_id]])
      if person_address.blank?
        person_address = PersonAddress.new
        person_address.person_id = params[:patient_id]
      end
      person_address.city_village = params[:person][:addresses][:city_village]
      person_address.state_province = params[:person][:addresses][:state_province]
      person_address.township_division = params[:person][:addresses][:township_division]
      person_address.save

      Person.update_date_changed(params[:patient_id])

      next_task = next_task(@patient)
      redirect_to(next_task) and return
    end
  end

  def get_person_address
    person_address = PersonAddress.find(:last, :conditions => ["person_id =?", params[:patient_id]])
    city_village = person_address.city_village rescue nil
    state_province = person_address.state_province rescue nil
    township_division = person_address.township_division rescue nil

    data = {"city_village" => city_village, "state_province" => state_province, "township_division" => township_division}
    render :text => data.to_json and return
  end

  def address_still_valid
    Person.update_date_changed(params[:patient_id])
    patient = Patient.find(params[:patient_id])
    next_task = next_task(patient)
    redirect_to(next_task) and return
  end

  def get_years_since_address_update
    patient = Patient.find(params[:patient_id])
    date_changed = patient.person.date_addressed_changed.to_date
    today = Date.today
    years = ((today - date_changed) / 365).to_i
    render :text => years and return
  end

	private

	def search_complete_url(found_person_id, primary_person_id)
		unless (primary_person_id.blank?)
			# Notice this swaps them!
			new_relationship_url(:patient_id => primary_person_id, :relation => found_person_id)
		else
			#
			# Hack reversed to continue testing overnight
			#
			# TODO: This needs to be redesigned!!!!!!!!!!!
			#
			#url_for(:controller => :encounters, :action => :new, :patient_id => found_person_id)
			patient = Person.find(found_person_id).patient
			show_confirmation = CoreService.get_global_property_value('show.patient.confirmation').to_s == "true" rescue false
			if show_confirmation
				url_for(:controller => :people, :action => :confirm , :found_person_id =>found_person_id)
			else
				next_task(patient)
			end
		end
	end

  def cul_age(birthdate , birthdate_estimated , date_created = Date.today, today = Date.today)

    # This code which better accounts for leap years
    patient_age = (today.year - birthdate.year) + ((today.month - birthdate.month) + ((today.day - birthdate.day) < 0 ? -1 : 0) < 0 ? -1 : 0)

    # If the birthdate was estimated this year, we round up the age, that way if
    # it is March and the patient says they are 25, they stay 25 (not become 24)
    birth_date = birthdate
    estimate = birthdate_estimated == 1
    patient_age += (estimate && birth_date.month == 7 && birth_date.day == 1  &&
        today.month < birth_date.month && date_created.year == today.year) ? 1 : 0
  end

  def birthdate_formatted(birthdate,birthdate_estimated)
    if birthdate_estimated == 1
      if birthdate.day == 1 and birthdate.month == 7
        birthdate.strftime("??/???/%Y")
      elsif birthdate.day == 15
        birthdate.strftime("??/%b/%Y")
      elsif birthdate.day == 1 and birthdate.month == 1
        birthdate.strftime("??/???/%Y")
      end
    else
      birthdate.strftime("%d/%b/%Y")
    end
  end
=begin
  def create_person_from_anc
    #ActiveRecord::Base.transaction do
        birth_day = params["person"]["birth_day"].to_i
        birth_month = params["person"]["birth_month"].to_i
        birthdate_estimated = 0
      if (birth_day == 0)
        birth_day = 1
        birthdate_estimated = 1
      end

      if (birth_month == 0)
        birth_month = 7
      end

      birthdate = Date.new(params["person"]["birth_year"].to_i,birth_month , birth_day)
      person = Person.create({
        :gender => params["person"]["gender"],
        :birthdate => birthdate,
        :birthdate_estimated => birthdate_estimated
      })

      person.names.create({
        :given_name => params["person"]["names"]["given_name"],
        :family_name => params["person"]["names"]["family_name"],
        :family_name2 => params["person"]["names"]["family_name2"]
      })

      person.addresses.create({
        :address1 => params["person"]["addresses"]["address1"],
        :address2 => params["person"]["addresses"]["address2"],
        :city_village => params["person"]["addresses"]["city_village"],
        :county_district => params["person"]["addresses"]["county_district"]
        })

      person.person_attributes.create(
		  :person_attribute_type_id => PersonAttributeType.find_by_name("Occupation").person_attribute_type_id,
		  :value => params["person"]["attributes"]["occupation"])

      person.person_attributes.create(
		  :person_attribute_type_id => PersonAttributeType.find_by_name("Cell Phone Number").person_attribute_type_id,
		  :value => params["person"]["attributes"]["cell_phone_number"])

      person.person_attributes.create(
        :person_attribute_type_id => PersonAttributeType.find_by_name("Office Phone Number").person_attribute_type_id,
        :value => params["person"]["attributes"]["office_phone_number"])

      person.person_attributes.create(
        :person_attribute_type_id => PersonAttributeType.find_by_name("Home Phone Number").person_attribute_type_id,
        :value => params["person"]["attributes"]["home_phone_number"])

      patient = person.create_patient
      patient.patient_identifiers.create({
          "identifier" => params["person"]["patient"]["identifiers"]["National id"],
          "identifier_type" => PatientIdentifierType.find_by_name("NATIONAL ID").patient_identifier_type_id
       })
    #end
    render :text => "true" and return
  end
=end


end
