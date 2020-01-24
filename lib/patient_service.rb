module PatientService
	include CoreService
	require 'bean'
	require 'json'
	require 'rest_client'
	require 'dde_service'
	require 'medication_service'
  ############# new DDE API start###################################
  def self.dde_settings
    data = {}
    dde_ip = GlobalProperty.find_by_property('dde.address').property_value rescue "localhost"
    dde_port = GlobalProperty.find_by_property('dde.port').property_value rescue "3009"
    dde_username = GlobalProperty.find_by_property('dde.username').property_value rescue "admin"
    dde_password = GlobalProperty.find_by_property('dde.password').property_value rescue "admin"

    data["dde_ip"] = dde_ip
    data["dde_port"] = dde_port
    data["dde_username"] = dde_username
    data["dde_password"] = dde_password
    data["dde_address"] = "http://#{dde_ip}:#{dde_port}"

    return data
  end

  def self.initial_dde_authentication_token
    dde_address = "#{dde_settings["dde_address"]}/v1/authenticate"
    passed_params = {:username => "admin", :password => "admin"}
    headers = {:content_type => "json" }
    received_params = RestClient.post(dde_address, passed_params.to_json, headers)
    dde_token = JSON.parse(received_params)#["data"]["token"]
    return dde_token
  end

  def self.dde_authentication_token
    dde_address = "#{dde_settings["dde_address"]}/v1/authenticate"
    dde_username = dde_settings["dde_username"]
    dde_password = dde_settings["dde_password"]
    passed_params = {:username => dde_username, :password => dde_password}
    headers = {:content_type => "json" }
    received_params = RestClient.post(dde_address, passed_params.to_json, headers)
    dde_token = JSON.parse(received_params)#["data"]["token"]
    return dde_token
  end

  def self.add_dde_user(data)
    dde_address = "http://admin:admin@#{dde_settings["dde_ip"]}:#{dde_settings["dde_port"]}/v1/add_user"
    passed_params = {
      :username => data["username"],
      :password => data["password"],
      :application => "ART",
      :site_code => data["site_code"],
      :description => data["description"]
    }

    headers = {:content_type => "json" }
    received_params = RestClient.put(dde_address, passed_params.to_json, headers){|response, request, result|response}
    dde_token = JSON.parse(received_params)["data"]["token"]
    #return dde_token
  end

  def self.verify_dde_token_authenticity(dde_token)
    dde_address = "#{dde_settings["dde_address"]}/v1/authenticated/#{dde_token}"
    received_params = RestClient.get(dde_address) {|request, response, result| request}
    status = JSON.parse(received_params)["status"]
    return status
  end

  def self.search_dde_by_identifier(identifier, dde_token)
    dde_address = "#{dde_settings["dde_address"]}/v1/search_by_identifier/#{identifier}/#{dde_token}"
    received_params = RestClient.get(dde_address){|response, request, result|response}
    received_params = "{}" if received_params.blank?
    results = JSON.parse(received_params){|response, request, result|response}
    return results
  end

  def self.search_dde_by_name_and_gender(params, token)
    return [] if params[:given_name].blank?
    gender = {'M' => 'Male', 'F' => 'Female'}
    passed_params = {
      :given_name => params[:given_name],
      :family_name => params[:family_name],
      :gender => gender[params[:gender].upcase],
      :token => token
    }

    dde_address = "#{dde_settings["dde_address"]}/v1/search_by_name_and_gender"
    headers = {:content_type => "json" }
    received_params = RestClient.post(dde_address, passed_params.to_json, headers)
    results = JSON.parse(received_params)["data"]["hits"] rescue {}
    return results
  end

  def self.dde_advanced_search(params)
    passed_params = {
      :given_name => params[:given_name],
      :family_name => params[:family_name],
      :gender => params[:gender],
      :birthdate => params[:birthdate],
      :home_district => params[:home_district],
      :token => self.dde_authentication_token
    }

    dde_address = "#{dde_settings["dde_address"]}/v1/search_by_name_and_gender"
    received_params = RestClient.post(dde_address, passed_params)
    results = JSON.parse(received_params)["data"]["hits"]
    return results
  end

  def self.void_dde_patient(identifier)
    dde_token = self.dde_authentication_token
    dde_address = "#{dde_settings["dde_address"]}/v1/void_patient/#{identifier}/#{dde_token}"
    received_params = RestClient.get(dde_address)
    status = JSON.parse(received_params)["status"]
    return status
  end

  def self.update_dde_patient(person, dde_token)
    passed_params = self.generate_dde_data_to_be_updated(person, dde_token)
    dde_address = "#{dde_settings["dde_address"]}/v1/update_patient"
    headers = {:content_type => "json" }
    received_params = RestClient.post(dde_address, passed_params.to_json, headers)
    results = JSON.parse(received_params)
    return results
  end

  def self.add_dde_patient(params, dde_token)
    dde_address = "#{dde_settings["dde_address"]}/v1/add_patient"
    gender = {'M' => 'Male', 'F' => 'Female'}
    person = Person.new
    birthdate = "#{params["person"]['birth_year']}-#{params["person"]['birth_month']}-#{params["person"]['birth_day']}"
    birthdate = birthdate.to_date.strftime("%Y-%m-%d") rescue birthdate

    if params["person"]["birth_year"] == "Unknown"
      self.set_birthdate_by_age(person, params["person"]['age_estimate'], Date.today)
    else
      self.set_birthdate(person, params["person"]["birth_year"], params["person"]["birth_month"], params["person"]["birth_day"])
    end

    unless params["person"]['birthdate_estimated'].blank?
      person.birthdate_estimated = params["person"]['birthdate_estimated'].to_i
    end

    passed_params = {
      "family_name" => params["person"]["names"]["family_name"],
      "given_name" => params["person"]["names"]["given_name"],
      "middle_name" => params["person"]["names"]["middle_name"],
      "gender" => gender[params["person"]["gender"]],
      "attributes" => {},
      "birthdate" => person.birthdate.to_date.strftime("%Y-%m-%d"),
      "identifiers" => {},
      "birthdate_estimated" => (person.birthdate_estimated.to_i == 1),
      "current_residence" => params["person"]["addresses"]["city_village"],
      "current_village" => params["person"]["addresses"]["city_village"],
      "current_ta" => params["filter"]["t_a"],
      "current_district" => params["person"]["addresses"]["state_province"],

      "home_village" => params["person"]["addresses"]["neighborhood_cell"],
      "home_ta" => params["person"]["addresses"]["county_district"],
      "home_district" => params["person"]["addresses"]["address2"],
      "token" => dde_token
    }

    headers = {:content_type => "json" }
    received_params = RestClient.put(dde_address, passed_params.to_json, headers){|response, request, result|response}
    results = JSON.parse(received_params)
    return results
  end

  def self.add_dde_conflict_patient(dde_return_path, params, dde_token)
    dde_address = "#{dde_settings["dde_address"]}#{dde_return_path}"
    gender = {'M' => 'Male', 'F' => 'Female'}
    person = Person.new
    birthdate = "#{params["person"]['birth_year']}-#{params["person"]['birth_month']}-#{params["person"]['birth_day']}"
    birthdate = birthdate.to_date.strftime("%Y-%m-%d") rescue birthdate

    if params["person"]["birth_year"] == "Unknown"
      self.set_birthdate_by_age(person, params["person"]['age_estimate'], Date.today)
    else
      self.set_birthdate(person, params["person"]["birth_year"], params["person"]["birth_month"], params["person"]["birth_day"])
    end

    unless params["person"]['birthdate_estimated'].blank?
      person.birthdate_estimated = params["person"]['birthdate_estimated'].to_i
    end

    passed_params = {
      "family_name" => params["person"]["names"]["family_name"],
      "given_name" => params["person"]["names"]["given_name"],
      "middle_name" => params["person"]["names"]["middle_name"],
      "gender" => gender[params["person"]["gender"]],
      "attributes" => {},
      "birthdate" => person.birthdate.to_date.strftime("%Y-%m-%d"),
      "identifiers" => {},
      "birthdate_estimated" => (person.birthdate_estimated.to_i == 1),
      "current_residence" => (params["person"]["addresses"]["city_village"] rescue 'Other'),
      "current_village" => (params["person"]["addresses"]["city_village"] rescue 'Other'),
      "current_ta" => (params["filter"]["t_a"] rescue 'N/A'),
      "current_district" => (params["person"]["addresses"]["state_province"] rescue 'Other'),

      "home_village" => (params["person"]["addresses"]["neighborhood_cell"] rescue 'Other'),
      "home_ta" => (params["person"]["addresses"]["county_district"] rescue 'Other'),
      "home_district" => (params["person"]["addresses"]["address2"] rescue 'Other'),
      "token" => dde_token
    }

    headers = {:content_type => "json" }
    received_params = RestClient.put(dde_address, passed_params.to_json, headers){|response, request, result|response}
    results = JSON.parse(received_params)
    return results
  end

  def self.create_local_patient_from_dde(data)
    address_map = self.dde_openmrs_address_map
    city_village = address_map["city_village"]
    state_province = address_map["state_province"]
    neighborhood_cell = address_map["neighborhood_cell"]
    county_district = address_map["county_district"]
    address1 = address_map["address1"]
    address2 = address_map["address2"]

    demographics = {
      "person" =>
        {
        "occupation" => (data['attributes']['occupation'] rescue nil) ,
        "cell_phone_number" => (data['attributes']['cell_phone_number'] rescue nil),
        "home_phone_number" => (data['attributes']['home_phone_number'] rescue nil),
        "identifiers" => {"National id" => data["npid"]},
        "addresses"=>{
          "address1"=>(data['addresses']["#{address1}"] rescue nil),
          "address2"=>(data['addresses']["#{address2}"] rescue nil),
          "city_village"=>(data['addresses']["#{city_village}"] rescue nil),
          "state_province"=>(data['addresses']["#{state_province}"] rescue nil),
          "neighborhood_cell"=>(data['addresses']["#{neighborhood_cell}"] rescue nil),
          "county_district"=>(data['addresses']["#{county_district}"] rescue nil)
        },

        "age_estimate" => data["birthdate_estimated"] ,
        "birth_month"=> data["birthdate"].to_date.month ,
        "patient" =>{"identifiers"=>
            {"National id"=> data["npid"] }
        },
        "gender" => data["gender"] ,
        "birth_day" => data["birthdate"].to_date.day ,
        "names"=>
          {
          "family_name2" => (data['names']['family_name2'] rescue nil),
          "family_name" => (data['names']['family_name'] rescue nil) ,
          "given_name" => (data['names']['given_name'] rescue nil)
        },
        "birth_year" => data["birthdate"].to_date.year }
    }

    person = PatientService.create_from_form(demographics["person"])
    return person
  end

  def self.generate_dde_demographics(data, dde_token)
    old_npid = data["person"]["patient"]["identifiers"]["National id"]
    gender = {'M' => 'Male', 'F' => 'Female'}
    cell_phone_number = data["person"]["attributes"]["cell_phone_number"]
    cell_phone_number = "Unknown" if cell_phone_number.blank?

    occupation = data["person"]["attributes"]["occupation"]
    occupation = "Unknown" if occupation.blank?

    middle_name = data["person"]["names"]["middle_name"]
    middle_name = "N/A" if middle_name.blank?
    identifiers = data["person"]["patient"]["identifiers"]

    person = Person.new
    if data["person"]["birth_year"] == "Unknown"
      self.set_birthdate_by_age(person, data["person"]['age_estimate'], Date.today)
    else
      self.set_birthdate(person, data["person"]["birth_year"], data["person"]["birth_month"], data["person"]["birth_day"])
    end

    unless data["person"]['birthdate_estimated'].blank?
      person.birthdate_estimated = data["person"]['birthdate_estimated'].to_i
    end

    home_ta = data["person"]["addresses"]["county_district"]
    home_ta = "Other" if home_ta.blank?

    home_district = data["person"]["addresses"]["address2"]
    home_district = "Other" if home_district.blank?

    demographics = {
      "family_name" => data["person"]["names"]["family_name"],
      "given_name" => data["person"]["names"]["given_name"],
      "middle_name" => middle_name,
      "gender" => gender[data["person"]["gender"]],
      "attributes" => {
        "occupation" => occupation,
        "cell_phone_number" => cell_phone_number
      },
      "birthdate" => person.birthdate.to_date.strftime("%Y-%m-%d"),
      "identifiers" => identifiers,
      "birthdate_estimated" => (person.birthdate_estimated.to_i == 1),
      "current_residence" => data["person"]["addresses"]["city_village"],
      "current_village" => data["person"]["addresses"]["city_village"],
      "current_ta" => "N/A",
      "current_district" => data["person"]["addresses"]["state_province"],

      "home_village" => data["person"]["addresses"]["neighborhood_cell"],
      "home_ta" => home_ta,
      "home_district" => home_district,
      "token" => dde_token
    }.delete_if{|k, v|v.to_s.blank?}

    return demographics
  end

  def self.generate_dde_demographics_for_merge(data)
    data =  data["data"]["hits"][0]
    gender = {'M' => 'Male', 'F' => 'Female'}

    demographics = {
      "npid" => data["npid"],
      "family_name" => data["names"]["family_name"],
      "given_name" => data["names"]["given_name"],
      "middle_name" => data["names"]["middle_name"],
      "gender" => gender[data["gender"]],
      "attributes" => data["attributes"],
      "birthdate" => data["birthdate"].to_date.strftime("%Y-%m-%d"),
      "identifiers" => data["patient"]["identifiers"],
      "birthdate_estimated" => (data["birthdate_estimated"].to_i == 1),
      "current_residence" => data["addresses"]["current_residence"],
      "current_village" => data["addresses"]["current_village"],
      "current_ta" => data["addresses"]["current_ta"],
      "current_district" => data["addresses"]["current_district"],

      "home_village" => data["addresses"]["home_village"],
      "home_ta" => data["addresses"]["home_ta"],
      "home_district" => data["addresses"]["home_district"]
    }

    return demographics
  end

  def self.generate_dde_data_to_be_updated(person, dde_token)
    data = PatientService.demographics(person)
    gender = {'M' => 'Male', 'F' => 'Female'}

    #occupation = data["person"]["attributes"]["occupation"]
    #occupation = "Unknown" if occupation.blank?

    middle_name = data["person"]["names"]["middle_name"]
    middle_name = "N/A" if middle_name.blank?

    npid = data["person"]["patient"]["identifiers"]["National id"]
    #old_npid = data["person"]["patient"]["identifiers"]["Old Identification Number"]
    #cell_phone_number = data["person"]["attributes"]["cell_phone_number"]
    #occupation = data["person"]["attributes"]["occupation"]
    #home_phone_number = data["person"]["attributes"]["home_phone_number"]
    #office_phone_number = data["person"]["attributes"]["office_phone_number"]

    #attributes = {}
    #attributes["cell_phone_number"] = cell_phone_number unless cell_phone_number.blank?
    #attributes["occupation"] = occupation unless occupation.blank?
    #attributes["home_phone_number"] = home_phone_number unless home_phone_number.blank?
    #attributes["office_phone_number"] = office_phone_number unless office_phone_number.blank?

    #identifiers = {}
    #identifiers["Old Identification Number"] = old_npid unless old_npid.blank?
    #identifiers["National id"] = old_npid unless npid.blank?

    identifiers =  self.patient_identifier_map(person)
    attributes =  self.person_attributes_map(person)

    home_ta = data["person"]["addresses"]["county_district"]
    home_ta = "Other" if home_ta.blank?

    home_district = data["person"]["addresses"]["address2"]
    home_district = "Other" if home_district.blank?
    
    demographics = {
      "npid" => npid,
      "family_name" => data["person"]["names"]["family_name"],
      "given_name" => data["person"]["names"]["given_name"],
      "middle_name" => middle_name,
      "gender" => gender[data["person"]["gender"]],
      "attributes" => attributes,
      "birthdate" => person.birthdate.to_date.strftime("%Y-%m-%d"),
      "identifiers" => identifiers,
      "birthdate_estimated" => (person.birthdate_estimated.to_i == 1),
      "current_residence" => data["person"]["addresses"]["city_village"],
      "current_village" => data["person"]["addresses"]["city_village"],
      "current_ta" => "N/A",
      "current_district" => data["person"]["addresses"]["state_province"],

      "home_village" => data["person"]["addresses"]["neighborhood_cell"],
      "home_ta" => home_ta,
      "home_district" => home_district,
      "token" => dde_token
    }.delete_if{|k, v|v.to_s.blank?}

    return demographics
  end

  def self.add_dde_patient_after_search_by_identifier(data)
    dde_address = "#{dde_settings["dde_address"]}/v1/add_patient"
    headers = {:content_type => "json" }
    received_params = RestClient.put(dde_address, data.to_json, headers){|response, request, result|response}
    results = JSON.parse(received_params)
    return results
  end

  def self.add_dde_patient_after_search_by_name(data)
    dde_address = "#{dde_settings["dde_address"]}/v1/add_patient"
    headers = {:content_type => "json" }
    received_params = RestClient.put(dde_address, data.to_json, headers){|response, request, result|response}
    results = JSON.parse(received_params)
    return results
  end

  def self.merge_dde_patients(primary_pt_demographics, secondary_pt_demographics, dde_token)
    data = {
      "primary_record" => primary_pt_demographics,
      "secondary_record" => secondary_pt_demographics,
      "token" => dde_token
    }

    dde_address = "#{dde_settings["dde_address"]}/v1/merge_records"
    headers = {:content_type => "json" }
    received_params = RestClient.post(dde_address, data.to_json, headers)
    results = JSON.parse(received_params)
    return results
  end

  def self.assign_new_dde_npid(person, old_npid, new_npid)
    national_patient_identifier_type_id = PatientIdentifierType.find_by_name("National id").patient_identifier_type_id
    old_patient_identifier_type_id = PatientIdentifierType.find_by_name("Old Identification Number").patient_identifier_type_id

    patient_national_identifier = person.patient.patient_identifiers.find(:last, :conditions => ["identifier_type =?",
        national_patient_identifier_type_id])

    ActiveRecord::Base.transaction do
      new_old_identification_identifier = person.patient.patient_identifiers.new
      new_old_identification_identifier.identifier_type = old_patient_identifier_type_id
      new_old_identification_identifier.identifier = old_npid
      new_old_identification_identifier.save

      new_national_identification_identifier = person.patient.patient_identifiers.new
      new_national_identification_identifier.identifier_type = national_patient_identifier_type_id
      new_national_identification_identifier.identifier = new_npid
      new_national_identification_identifier.save

      patient_national_identifier.void
    end

    return new_npid
  end

  def self.dde_openmrs_address_map
    data = { 
      "city_village" => "current_residence",
      "state_province" => "current_district",
      "neighborhood_cell" => "home_village",
      "county_district" => "home_ta",
      "address2" => "home_district",
      "address1" => "current_residence"
    }
    return data
  end

  def self.patient_identifier_map(person)
    identifier_map = {}
    patient_identifiers = person.patient.patient_identifiers
    patient_identifiers.each do |pt|
      key = pt.type.name
      value = pt.identifier
      next if value.blank?
      identifier_map[key] = value
    end
    return identifier_map
  end

  def self.person_attributes_map(person)
    attributes_map = {}
    person_attributes = person.person_attributes
    person_attributes.each do |pa|
      key = pa.type.name.downcase.gsub(/\s/,'_') #From Home Phone Number to home_phone_number
      value = pa.value
      next if value.blank?
      attributes_map[key] = value
    end
    return attributes_map
  end

  def self.get_remote_dde_person(data)
    patient = PatientBean.new('')
    patient.person_id = data["_id"]
    patient.patient_id = 0
    patient.address = data["addresses"]["current_residence"]
    patient.national_id = data["npid"]
    patient.name = data["names"]["given_name"] + ' ' + data["names"]["family_name"]
    patient.first_name = data["names"]["given_name"]
    patient.last_name = data["names"]["family_name"]
    patient.sex = data["gender"]
    patient.birthdate = data["birthdate"].to_date
    patient.birthdate_estimated =  data["age_estimate"].to_i
    date_created =  data["created_at"].to_date rescue Date.today
    patient.age = self.cul_age(patient.birthdate , patient.birthdate_estimated , date_created, Date.today)
    patient.birth_date = self.get_birthdate_formatted(patient.birthdate,patient.birthdate_estimated)
    patient.home_district = data["addresses"]["home_district"]
    patient.current_district = data["addresses"]["current_district"]
    patient.traditional_authority = data["addresses"]["home_ta"]
    patient.current_residence = data["addresses"]["current_residence"]
    patient.landmark = ""
    patient.home_village = data["addresses"]["home_village"]
    patient.occupation = data["attributes"]["occupation"]
    patient.cell_phone_number = data["attributes"]["cell_phone_number"]
    patient.home_phone_number = data["attributes"]["home_phone_number"]
    patient.old_identification_number = data["patient"]["identifiers"]["National id"]
    patient
  end

  def self.update_local_demographics_from_dde(person, data)
    names = data["names"]
    #identifiers = data["patient"]["identifiers"] rescue {}
    addresses = data["addresses"]
    attributes = data["attributes"]
    birthdate = data["birthdate"]
    birthdate_estimated = data["birthdate_estimated"]
    gender = data["gender"]
    
    person_name = person.names[0]
    person_address = person.addresses[0]


    city_village = addresses["current_residence"] rescue nil
    state_province = addresses["current_district"] rescue nil
    neighborhood_cell = addresses["home_village"] rescue nil
    county_district = addresses["home_ta"] rescue nil
    address2 = addresses["home_district"] rescue nil
    address1 = addresses["current_residence"] rescue nil

    #person.gender = gender
    #person.birthdate = birthdate.to_date
    #person.birthdate_estimated = birthdate_estimated
    #person.save

    person.update_attributes({
        :gender => gender,
        :birthdate => birthdate.to_date,
        :birthdate_estimated => birthdate_estimated
      })

    person_name.given_name = names["given_name"]
    person_name.middle_name = names["middle_name"]
    person_name.family_name = names["family_name"]
    person_name.save

    person_address.address1 = address1
    person_address.address2 = address2
    person_address.city_village = city_village
    person_address.county_district = county_district
    person_address.state_province = state_province
    person_address.neighborhood_cell = neighborhood_cell
    person_address.save

    (attributes || {}).each do |key, value|
      person_attribute_type = PersonAttributeType.find_by_name(key)
      next if person_attribute_type.blank?
      person_attribute_type_id = person_attribute_type.id
      person_attrib = person.person_attributes.find_by_person_attribute_type_id(person_attribute_type_id)

      if person_attrib.blank?
        person_attrib = PersonAttribute.new
        person_attrib.person_id = person.person_id
        person_attrib.person_attribute_type_id = person_attribute_type_id
      end

      person_attrib.value = value
      person_attrib.save
    end
=begin
    #Leave this part commented out please!!. Do not update identifiers locally from DDE.
   #New patient object was being created as a side effect when side National id was being updated
    (identifiers || {}).each do |key, value|
      patient_identifier_type = PatientIdentifierType.find_by_name(key)
      next if patient_identifier_type.blank?
      patient_identifier_type_id = patient_identifier_type.id
      patient_ident = person.patient.patient_identifiers.find_by_identifier_type(patient_identifier_type_id)

      if patient_ident.blank?
        patient_ident = PatientIdentifier.new
        patient_ident.patient_id = person.person_id
        patient_ident.identifier_type = patient_identifier_type_id
      end

      patient_ident.identifier = value
      patient_ident.save
    end
=end
  end
  
  ############# new DDE API END###################################
  
  def self.search_demographics_from_remote(params)
    return [] if params[:person][:names]['given_name'].blank?
    dde_server = GlobalProperty.find_by_property("dde_server_ip").property_value rescue ""
    dde_server_username = GlobalProperty.find_by_property("dde_server_username").property_value rescue ""
    dde_server_password = GlobalProperty.find_by_property("dde_server_password").property_value rescue ""
    uri = "http://#{dde_server_username}:#{dde_server_password}@#{dde_server}/people/find_demographics.json/"

    return JSON.parse(RestClient.post(uri,params))
  end

  def self.search_from_remote(params)
    return [] if params[:given_name].blank?
    dde_server = GlobalProperty.find_by_property("dde_server_ip").property_value rescue ""
    dde_server_username = GlobalProperty.find_by_property("dde_server_username").property_value rescue ""
    dde_server_password = GlobalProperty.find_by_property("dde_server_password").property_value rescue ""
    uri = "http://#{dde_server_username}:#{dde_server_password}@#{dde_server}/people/find.json/"

    return JSON.parse(RestClient.post(uri,params))
  end

  def self.search_from_dde_by_identifier(identifier)
    dde_server = GlobalProperty.find_by_property("dde_server_ip").property_value rescue ""
    dde_server_username = GlobalProperty.find_by_property("dde_server_username").property_value rescue ""
    dde_server_password = GlobalProperty.find_by_property("dde_server_password").property_value rescue ""
    uri = "http://#{dde_server_username}:#{dde_server_password}@#{dde_server}/people/find.json"
    uri += "?value=#{identifier}"
    people = JSON.parse(RestClient.get(uri)) rescue nil
    return [] if people.blank?

    local_people = []
    people.each do |person|
      national_id = person['person']["value"] rescue nil
      old_national_id = person["person"]["old_identification_number"] rescue nil

      birthdate_year = person["person"]["data"]["birthdate"].to_date.year rescue "Unknown"
      birthdate_month = person["person"]["data"]["birthdate"].to_date.month rescue nil
      birthdate_day = person["person"]["data"]["birthdate"].to_date.day rescue nil
      birthdate_estimated = person["person"]["data"]["birthdate_estimated"]
      gender = person["person"]["data"]["gender"] == "F" ? "Female" : "Male"
      passed_person = {
        "person"=>{"occupation"=>person["person"]["data"]["attributes"]["occupation"],
          "age_estimate"=> birthdate_estimated ,
          "birthdate" => person["person"]["data"]["birthdate"],
          "cell_phone_number"=>person["person"]["data"]["attributes"]["cell_phone_number"],
          "birth_month"=> birthdate_month ,
          "addresses"=>{"address1"=> person["person"]["data"]["addresses"]["county_district"],
            "address2"=> person["person"]["data"]["addresses"]["address2"],
            "city_village"=> person["person"]["data"]["addresses"]["city_village"],
            "county_district"=> person["person"]["data"]["addresses"]["county_district"],
            "state_province" => person["person"]["data"]["addresses"]["state_province"],
            "neighborhood_cell" => person["person"]["data"]["addresses"]["neighborhood_cell"]},
          "gender"=> gender ,
          "patient"=>{"identifiers"=>{"National id" => national_id ,"Old national id" => old_national_id}},
          "birth_day"=>birthdate_day,
          "home_phone_number"=>person["person"]["data"]["attributes"]["home_phone_number"],
          "names"=>{"family_name"=>person["person"]["data"]["names"]["family_name"],
            "given_name"=>person["person"]["data"]["names"]["given_name"],
            "middle_name"=>""},
          "birth_year"=>birthdate_year,
          "id" => person["person"]["id"]},
        "filter_district"=>"",
        "filter"=>{"region"=>"",
          "t_a"=>""},
        "relation"=>""
      }
      local_people << passed_person
    end
    return local_people
  end

  def self.create_from_dde_server_only(params)
    address_params = params["person"]["addresses"]
    names_params = params["person"]["names"]
    patient_params = params["person"]["patient"]
    birthday_params = params["person"]
    params_to_process = params.reject{|key,value|
      key.match(/identifiers|addresses|patient|names|relation|cell_phone_number|home_phone_number|office_phone_number|agrees_to_be_visited_for_TB_therapy|agrees_phone_text_for_TB_therapy/)
    }
    birthday_params = params_to_process["person"].reject{|key,value| key.match(/gender/) }
    person_params = params_to_process["person"].reject{|key,value| key.match(/birth_|age_estimate|occupation/) }


    if person_params["gender"].to_s == "Female"
      person_params["gender"] = 'F'
    elsif person_params["gender"].to_s == "Male"
      person_params["gender"] = 'M'
    end

    unless birthday_params.empty?
      if birthday_params["birth_year"] == "Unknown"
        birthdate = Date.new(Date.today.year - birthday_params["age_estimate"].to_i, 7, 1)
        birthdate_estimated = 1
      else
        year = birthday_params["birth_year"]
        month = birthday_params["birth_month"]
        day = birthday_params["birth_day"]

        month_i = (month || 0).to_i
        month_i = Date::MONTHNAMES.index(month) if month_i == 0 || month_i.blank?
        month_i = Date::ABBR_MONTHNAMES.index(month) if month_i == 0 || month_i.blank?

        if month_i == 0 || month == "Unknown"
          birthdate = Date.new(year.to_i,7,1)
          birthdate_estimated = 1
        elsif day.blank? || day == "Unknown" || day == 0
          birthdate = Date.new(year.to_i,month_i,15)
          birthdate_estimated = 1
        else
          birthdate = Date.new(year.to_i,month_i,day.to_i)
          birthdate_estimated = 0
        end
      end
    else
      birthdate_estimated = 0
    end


    passed_params = {"person"=>
        {"data" =>
          {"addresses"=>
            {"state_province"=> address_params["state_province"],
            "address2"=> address_params["address2"],
            "address1"=> address_params["address1"],
            "neighborhood_cell"=> address_params["neighborhood_cell"],
            "city_village"=> address_params["city_village"],
            "county_district"=> address_params["county_district"]
          },
          "attributes"=>
            {"occupation"=> params["person"]["occupation"],
            "cell_phone_number" => params["person"]["cell_phone_number"],
            "home_phone_number" => params["person"]["home_phone_number"] || nil,
						"office_phone_number" => params["person"]["office_phone_number"] || nil},
          "patient"=>
            {"identifiers"=>
              {"old_identification_number"=> params["person"]["patient"]["identifiers"]["old_identification_number"]}},
          "gender"=> person_params["gender"],
          "birthdate"=> birthdate,
          "birthdate_estimated"=> birthdate_estimated ,
          "names"=>{"family_name"=> names_params["family_name"],
            "given_name"=> names_params["given_name"]
          }}}}

    @dde_server = GlobalProperty.find_by_property("dde_server_ip").property_value rescue ""
    @dde_server_username = GlobalProperty.find_by_property("dde_server_username").property_value rescue ""
    @dde_server_password = GlobalProperty.find_by_property("dde_server_password").property_value rescue ""

    uri = "http://#{@dde_server_username}:#{@dde_server_password}@#{@dde_server}/people.json/"
    received_params = RestClient.post(uri,passed_params)

    return JSON.parse(received_params)["npid"]["value"]
  end

  def self.get_dde_person(person, current_date = Date.today)
    patient = PatientBean.new('')
    patient.person_id = person["person"]["id"]
    patient.patient_id = 0
    patient.address = person["person"]["addresses"]["city_village"]
    patient.national_id = person["person"]["patient"]["identifiers"]["National id"]
    patient.national_id = person["person"]["value"] if patient.national_id.blank? rescue nil
    patient.name = person["person"]["names"]["given_name"] + ' ' + person["person"]["names"]["family_name"] rescue nil
    patient.first_name = person["person"]["names"]["given_name"] rescue nil
    patient.last_name = person["person"]["names"]["family_name"] rescue nil
    patient.sex = person["person"]["gender"]
    patient.birthdate = person["person"]["birthdate"].to_date
    patient.birthdate_estimated =  person["person"]["age_estimate"].to_i rescue 0
    date_created =  person["person"]["date_created"].to_date rescue Date.today
    patient.age = self.cul_age(patient.birthdate , patient.birthdate_estimated , date_created, Date.today)
    patient.birth_date = self.get_birthdate_formatted(patient.birthdate,patient.birthdate_estimated)
    patient.home_district = person["person"]["addresses"]["address2"]
    patient.current_district = person["person"]["addresses"]["state_province"]
    patient.traditional_authority = person["person"]["addresses"]["county_district"]
    patient.current_residence = person["person"]["addresses"]["city_village"]
    patient.landmark = person["person"]["addresses"]["address1"]
    patient.home_village = person["person"]["addresses"]["neighborhood_cell"]
    patient.occupation = person["person"]["occupation"]
    patient.cell_phone_number = person["person"]["cell_phone_number"]
    patient.home_phone_number = person["person"]["home_phone_number"]
    patient.old_identification_number = person["person"]["patient"]["identifiers"]["Old national id"]
    patient.national_id  = patient.old_identification_number if patient.national_id.blank?
    patient
  end


  def self.cul_age(birthdate , birthdate_estimated , date_created = Date.today, today = Date.today)

    # This code which better accounts for leap years
    patient_age = (today.year - birthdate.year) + ((today.month - birthdate.month) + ((today.day - birthdate.day) < 0 ? -1 : 0) < 0 ? -1 : 0)

    # If the birthdate was estimated this year, we round up the age, that way if
    # it is March and the patient says they are 25, they stay 25 (not become 24)
    birth_date = birthdate
    estimate = birthdate_estimated == 1
    patient_age += (estimate && birth_date.month == 7 && birth_date.day == 1  &&
        today.month < birth_date.month && date_created.year == today.year) ? 1 : 0
  end

  def self.get_birthdate_formatted(birthdate,birthdate_estimated)
    if birthdate_estimated == 1
      if birthdate.day == 1 and birthdate.month == 7
        birthdate.strftime("??/???/%Y")
      elsif birthdate.day == 15
        birthdate.strftime("??/%b/%Y")
      elsif birthdate.day == 1 and birthdate.month == 1
        birthdate.strftime("??/???/%Y")
      else
	      birthdate.strftime("%d/%b/%Y") unless birthdate.blank?
      end
    else
      birthdate.strftime("%d/%b/%Y")
    end
  end
  #............................................................. new code

  def self.create_patient_from_dde(params)
    old_identifier = params["identifier"] rescue nil
	  address_params = params["person"]["addresses"]
		names_params = params["person"]["names"]
		patient_params = params["person"]["patient"]
    birthday_params = params["person"]
		params_to_process = params.reject{|key,value|
      key.match(/identifiers|addresses|patient|names|relation|cell_phone_number|home_phone_number|office_phone_number|agrees_to_be_visited_for_TB_therapy|agrees_phone_text_for_TB_therapy/)
    }
		birthday_params = params_to_process["person"].reject{|key,value| key.match(/gender/) }
		person_params = params_to_process["person"].reject{|key,value| key.match(/birth_|age_estimate|occupation/) }


		if person_params["gender"].to_s == "Female"
      person_params["gender"] = 'F'
		elsif person_params["gender"].to_s == "Male"
      person_params["gender"] = 'M'
		end

		unless birthday_params.empty?
		  if birthday_params["birth_year"] == "Unknown"
			  birthdate = Date.new(Date.today.year - birthday_params["age_estimate"].to_i, 7, 1)
        birthdate_estimated = 1
		  else
			  year = birthday_params["birth_year"]
        month = birthday_params["birth_month"]
        day = birthday_params["birth_day"]

        month_i = (month || 0).to_i
        month_i = Date::MONTHNAMES.index(month) if month_i == 0 || month_i.blank?
        month_i = Date::ABBR_MONTHNAMES.index(month) if month_i == 0 || month_i.blank?

        if month_i == 0 || month == "Unknown"
          birthdate = Date.new(year.to_i,7,1)
          birthdate_estimated = 1
        elsif day.blank? || day == "Unknown" || day == 0
          birthdate = Date.new(year.to_i,month_i,15)
          birthdate_estimated = 1
        else
          birthdate = Date.new(year.to_i,month_i,day.to_i)
          birthdate_estimated = 0
        end
		  end
    else
      birthdate_estimated = 0
		end

    passed_params = {"person"=>
        {"data" =>
          {"addresses"=>
            {"state_province"=> address_params["state_province"],
            "address2"=> address_params["address2"],
            "address1"=> address_params["address1"],
            "neighborhood_cell"=> address_params["neighborhood_cell"],
            "city_village"=> address_params["city_village"],
            "county_district"=> address_params["county_district"]
          },
          "attributes"=>
            {"occupation"=> params["person"]["occupation"],
            "cell_phone_number" => params["person"]["cell_phone_number"],
            "office_phone_number" => params["person"]["office_phone_number"] || nil,
            "home_phone_number" => params["person"]["home_phone_number"] || nil },
          "patient"=>
            {"identifiers"=> {"old_identification_number"=> old_identifier}},
          "gender"=> person_params["gender"],
          "birthdate"=> birthdate,
          "birthdate_estimated"=> birthdate_estimated ,
          "names"=>{"family_name"=> names_params["family_name"],
            "given_name"=> names_params["given_name"]
          }}}}

    if !params["remote"]

      @dde_server = GlobalProperty.find_by_property("dde_server_ip").property_value rescue ""

      @dde_server_username = GlobalProperty.find_by_property("dde_server_username").property_value rescue ""

      @dde_server_password = GlobalProperty.find_by_property("dde_server_password").property_value rescue ""

      uri = "http://#{@dde_server_username}:#{@dde_server_password}@#{@dde_server}/people.json/"
      received_params = RestClient.post(uri,passed_params)

      national_id = JSON.parse(received_params)["npid"]["value"]
    else
      national_id = params["person"]["patient"]["identifiers"]["National id"]
      national_id = params["person"]["value"] if national_id.blank? rescue nil
      return national_id
    end

	  person = self.create_from_form(params[:person] || params["person"])

    identifier_type = PatientIdentifierType.find_by_name("National id") || PatientIdentifierType.find_by_name("Unknown id")
    person.patient.patient_identifiers.create("identifier" => national_id,
      "identifier_type" => identifier_type.patient_identifier_type_id) unless national_id.blank?
    return person
  end

  def self.remote_demographics(person_obj)
    demo = demographics(person_obj)

    demographics = {
      "person" =>
        {"attributes" => {
          "occupation" => demo['person']['attributes']['occupation'],
          "cell_phone_number" => demo['person']['attributes']['cell_phone_number'] || nil,
          "home_phone_number" => demo['person']['attributes']['home_phone_number'] || nil,
          "office_phone_number" => demo['person']['attributes']['office_phone_number'] || nil
        } ,

        "addresses"=>{"address1"=>demo['person']['addresses']['address1'],
          "address2"=>demo['person']['addresses']['address2'],
          "city_village"=>demo['person']['addresses']['city_village'],
          "state_province"=>demo['person']['addresses']['state_province'],
          "neighborhood_cell"=>demo['person']['addresses']['neighborhood_cell'],
          "county_district"=>demo['person']['addresses']['county_district']},

        "age_estimate" => person_obj.birthdate_estimated ,
        "birth_month"=> person_obj.birthdate.month ,
        "patient" =>{"identifiers"=>
            {"National id"=> demo['person']['patient']['identifiers']['National id'] }
        },
        "gender" => person_obj.gender.first ,
        "birth_day" => person_obj.birthdate.day ,
        "date_changed" => demo['person']['date_changed'] ,
        "names"=>
          {
          "family_name2" => demo['person']['names']['family_name2'],
          "family_name" => demo['person']['names']['family_name'] ,
          "given_name" => demo['person']['names']['given_name']
        },
        "birth_year" => person_obj.birthdate.year }
    }
  end

  def self.demographics(person_obj)

    if person_obj.birthdate_estimated==1
      birth_day = "Unknown"
      if person_obj.birthdate.month == 7 and person_obj.birthdate.day == 1
        birth_month = "Unknown"
      else
        birth_month = person_obj.birthdate.month
      end
    else
      birth_month = person_obj.birthdate.month rescue nil
      birth_day = person_obj.birthdate.day rescue nil
    end

    demographics = {"person" => {
        "date_changed" => person_obj.date_changed.to_s,
        "gender" => person_obj.gender,
				"birthdate" => person_obj.birthdate, 
        "birth_year" => person_obj.birthdate.year || nil,
        "birth_month" => birth_month,
        "birth_day" => birth_day,
        "names" => {
          "given_name" => person_obj.names.first.given_name,
          "middle_name" => person_obj.names.first.middle_name,
          "family_name" => person_obj.names.first.family_name,
          "family_name2" => person_obj.names.first.family_name2
        },
        "addresses"=>{"address1"=>(person_obj.addresses.first.address1 rescue ''),
          "address2"=>(person_obj.addresses.first.address2 rescue ''),
          "city_village"=>(person_obj.addresses.first.city_village rescue ''),
          "state_province"=>(person_obj.addresses.first.state_province rescue ''),
          "neighborhood_cell"=>(person_obj.addresses.first.neighborhood_cell rescue ''),
          "county_district"=>(person_obj.addresses.first.county_district rescue '')},

        "attributes" => {"occupation" => self.get_attribute(person_obj, 'Occupation'),
          "cell_phone_number" => self.get_attribute(person_obj, 'Cell Phone Number'),
					"home_phone_number" => self.get_attribute(person_obj, 'Home Phone Number'),
					"office_phone_number" => self.get_attribute(person_obj, 'Office Phone Number')}}}

    if not person_obj.patient.patient_identifiers.blank?
      demographics["person"]["patient"] = {"identifiers" => {}}
      person_obj.patient.patient_identifiers.each{|identifier|
        demographics["person"]["patient"]["identifiers"][identifier.type.name] = identifier.identifier
      }
    end

    return demographics
  end

  def self.current_treatment_encounter(patient, date = Time.now(), provider = user_person_id)
    type = EncounterType.find_by_name("TREATMENT")
    encounter = patient.encounters.find(:first,:conditions =>["encounter_datetime BETWEEN ? AND ? AND encounter_type = ?",
        date.to_date.strftime('%Y-%m-%d 00:00:00'),
        date.to_date.strftime('%Y-%m-%d 23:59:59'),
        type.id])
    encounter ||= patient.encounters.create(:encounter_type => type.id,:encounter_datetime => date, :provider_id => provider)
  end

  def self.count_by_type_for_date(date)
    # This query can be very time consuming, because of this we will not consider
    # that some of the encounters on the specific date may have been voided
    ActiveRecord::Base.connection.select_all("SELECT count(*) as number, encounter_type FROM encounter GROUP BY encounter_type")
    todays_encounters = Encounter.find(:all, :include => "type", :conditions => ["encounter_datetime BETWEEN TIMESTAMP (?) AND TIMESTAMP (?)",
        date.to_date.strftime('%Y-%m-%d 00:00:00'),
        date.to_date.strftime('%Y-%m-%d 23:59:59')
      ])
    encounters_by_type = Hash.new(0)
    todays_encounters.each{|encounter|
      next if encounter.type.nil?
      encounters_by_type[encounter.type.name] += 1
    }
    encounters_by_type
  end

  def self.phone_numbers(person_obj)
    phone_numbers = {}

    phone_numbers['Cell phone number'] = self.get_attribute(person_obj, 'Cell phone number') rescue nil
    phone_numbers['Office phone number'] = self.get_attribute(person_obj, 'Office phone number') rescue nil
    phone_numbers['Home phone number'] = self.get_attribute(person_obj, 'Home phone number') rescue nil

    phone_numbers
  end

  def self.initial_encounter
    Encounter.find_by_sql("SELECT * FROM encounter ORDER BY encounter_datetime LIMIT 1").first
  end

  def self.create_remote_person(received_params)
    #raise known_demographics.to_yaml

    #Format params for ART
    new_params = received_params[:person]
    known_demographics = Hash.new()
    new_params['gender'] == 'F' ? new_params['gender'] = "Female" : new_params['gender'] = "Male"

    known_demographics = {
      "occupation"=>"#{new_params[:occupation]}",
      "patient_year"=>"#{new_params[:birth_year]}",
      "patient"=>{
        "gender"=>"#{new_params[:gender]}",
        "birthplace"=>"#{new_params[:addresses][:address2]}",
        "creator" => 1,
        "changed_by" => 1
      },
      "p_address"=>{
        "identifier"=>"#{new_params[:addresses][:state_province]}"},
      "home_phone"=>{
        "identifier"=>"#{new_params[:home_phone_number]}"},
      "cell_phone"=>{
        "identifier"=>"#{new_params[:cell_phone_number]}"},
      "office_phone"=>{
        "identifier"=>"#{new_params[:office_phone_number]}"},
      "patient_id"=>"",
      "patient_day"=>"#{new_params[:birth_day]}",
      "patientaddress"=>{"city_village"=>"#{new_params[:addresses][:city_village]}"},
      "patient_name"=>{
        "family_name"=>"#{new_params[:names][:family_name]}",
        "given_name"=>"#{new_params[:names][:given_name]}", "creator" => 1
      },
      "patient_month"=>"#{new_params[:birth_month]}",
      "patient_age"=>{
        "age_estimate"=>"#{new_params[:age_estimate]}"
      },
      "age"=>{
        "identifier"=>""
      },
      "current_ta"=>{
        "identifier"=>"#{new_params[:addresses][:county_district]}"}
    }

    servers = GlobalProperty.find(:first,
      :conditions => {:property => "remote_servers.parent"}).property_value.split(/,/) rescue nil
    server_address_and_port = servers.to_s.split(':')
    server_address = server_address_and_port.first
    server_port = server_address_and_port.second
    login = GlobalProperty.find(:first,
      :conditions => {:property => "remote_bart.username"}).property_value.split(/,/) rescue ''
    password = GlobalProperty.find(:first,
      :conditions => {:property => "remote_bart.password"}).property_value.split(/,/) rescue ''

    if server_port.blank?
      uri = "http://#{login.first}:#{password.first}@#{server_address}/patient/create_remote"
    else
      uri = "http://#{login.first}:#{password.first}@#{server_address}:#{server_port}/patient/create_remote"
    end
    output = RestClient.post(uri,known_demographics)

    results = []
    results.push output if output and output.match(/person/)
    result = results.sort{|a,b|b.length <=> a.length}.first
    result ? person = JSON.parse(result) : nil

    begin
      person["person"]["addresses"]["address1"] = "#{new_params[:addresses][:address1]}"
      person["person"]["names"]["middle_name"] = "#{new_params[:names][:middle_name]}"
      person["person"]["occupation"] = known_demographics["occupation"]
      person["person"]["cell_phone_number"] = known_demographics["cell_phone"]["identifier"]
      person["person"]["home_phone_number"] = known_demographics["home_phone"]["identifier"]
      person["person"]["office_phone_number"] = known_demographics["office_phone"]["identifier"]
      person["person"]["attributes"].delete("occupation")
      person["person"]["attributes"].delete("cell_phone_number")
      person["person"]["attributes"].delete("home_phone_number")
      person["person"]["attributes"].delete("office_phone_number")
    rescue
    end

    return person
  end

  def self.find_remote_person(known_demographics)
    servers = GlobalProperty.find(:first, :conditions => {:property => "remote_servers.parent"}).property_value.split(/,/) rescue nil
    server_address_and_port = servers.to_s.split(':')
    server_address = server_address_and_port.first
    server_port = server_address_and_port.second

    return nil if servers.blank?

    # use ssh to establish a secure connection then query the localhost
    # use wget to login (using cookies and sessions) and set the location
    # then pull down the demographics
    # TODO fix login/pass and location with something better

    login = GlobalProperty.find(:first, :conditions => {:property => "remote_bart.username"}).property_value.split(/,/) rescue ""
    password = GlobalProperty.find(:first, :conditions => {:property => "remote_bart.password"}).property_value.split(/,/) rescue ""

    # TODO need better logic here to select the best result or merge them
    # Currently returning the longest result - assuming that it has the most information
    # Can't return multiple results because there will be redundant data from sites

    if server_port.blank?
      uri = "http://#{login.first}:#{password.first}@#{server_address}/people/demographics"
    else
      uri = "http://#{login.first}:#{password.first}@#{server_address}:#{server_port}/people/demographics"
    end

    output = RestClient.post(uri,known_demographics)

    results = []
    results.push output if output and output.match(/person/)
    result = results.sort{|a,b|b.length <=> a.length}.first
    result ? person = JSON.parse(result) : nil

    return {} if person.blank?

    #Stupid hack to structure the hash for openmrs 1.7
    person["person"]["occupation"] = person["person"]["attributes"]["occupation"]
    person["person"]["cell_phone_number"] = person["person"]["attributes"]["cell_phone_number"]
    person["person"]["home_phone_number"] =  person["person"]["attributes"]["home_phone_number"]
    person["person"]["office_phone_number"] = person["person"]["attributes"]["office_phone_number"]
    person["person"]["attributes"].delete("occupation")
    person["person"]["attributes"].delete("cell_phone_number")
    person["person"]["attributes"].delete("home_phone_number")
    person["person"]["attributes"].delete("office_phone_number")

    person
  end

  def self.find_remote_person_by_identifier(identifier)
    known_demographics = {:person => {:patient => { :identifiers => {"National id" => identifier }}}}
    find_remote_person(known_demographics)
  end

  def self.find_person_by_demographics(person_demographics)
    national_id = person_demographics["person"]["patient"]["identifiers"]["National id"] rescue nil
    national_id = person_demographics["person"]["value"] if national_id.blank? rescue nil
    results = search_by_identifier(national_id) unless national_id.nil?

    return results unless results.blank?

    gender = person_demographics["person"]["gender"] rescue nil
    given_name = person_demographics["person"]["names"]["given_name"] rescue nil
    family_name = person_demographics["person"]["names"]["family_name"] rescue nil

    search_params = {:gender => gender, :given_name => given_name, :family_name => family_name }

    results = person_search(search_params)
  end

  def self.checks_if_labs_results_are_avalable_to_be_shown(patient , session_date , task)
    lab_result = Encounter.find(:first,:order => "encounter_datetime DESC",
      :conditions =>[" encounter_datetime <= TIMESTAMP(?) AND patient_id = ? AND encounter_type = ?",
        session_date.to_date.strftime('%Y-%m-%d 23:59:59'),
        patient.id,
        EncounterType.find_by_name('LAB RESULTS').id])

    give_lab_results = Encounter.find(:first,:order => "encounter_datetime DESC",
      :conditions =>["encounter_datetime >= TIMESTAMP(?)
                                AND patient_id = ? AND encounter_type = ?",
        lab_result.encounter_datetime.to_date.strftime('%Y-%m-%d 00:00:00') , patient.id,
        EncounterType.find_by_name('GIVE LAB RESULTS').id]) rescue nil

    if not lab_result.blank? and give_lab_results.blank?
      task.encounter_type = 'GIVE LAB RESULTS'
      task.url = "/encounters/new/give_lab_results?patient_id=#{patient.id}"
      return task
    end

    if not give_lab_results.blank?
      if not give_lab_results.observations.collect{|obs|obs.to_s.squish}.include?('Laboratory results given to patient: Yes')
        task.encounter_type = 'GIVE LAB RESULTS'
        task.url = "/encounters/new/give_lab_results?patient_id=#{patient.id}"
        return task
      end if not (give_lab_results.encounter_datetime.to_date == session_date.to_date)
    end

  end

  def self.services(current_user_id, session_date)
  	services_concept_id = ConceptName.find_by_name('SERVICES').concept_id

    @start_date = session_date.to_date
    @end_date = session_date.to_date

    registration_services_hash = {} ; services = []
    registration_services_hash['SERVICES'] = {'Casualty' => 0,'Dental' => 0,'Eye' => 0,'Family Planing' => 0,'Medical' => 0,'OB/Gyn' => 0,'Orthopedics' => 0,'Other' => 0,'Pediatrics' => 0,'Skin' => 0,'STI Clinic' => 0,'Surgical' => 0}


    #services = Observation.find(:all, :conditions => ["DATE(obs_datetime) = ? AND concept_id = ?", Date.today.to_date, ConceptName.find_by_name("SERVICES").concept_id], :order => "obs_datetime desc")

    services = Observation.find(:all, :conditions => ["DATE(obs_datetime) = ? AND concept_id = ? AND creator = ?", session_date.to_date, ConceptName.find_by_name("SERVICES").concept_id, current_user_id], :order => "obs_datetime desc")#.uniq.reverse.first(5) rescue []

    ( services || [] ).each do | service |
      if service.value_text.capitalize == 'Casualty'
        registration_services_hash['SERVICES']['Casualty'] += 1
      elsif service.value_text.capitalize == 'Eye'
        registration_services_hash['SERVICES']['Eye'] += 1
      elsif service.value_text.capitalize == 'Family Planing'
        registration_services_hash['SERVICES']['Family Planing'] += 1
      elsif service.value_text.capitalize == 'Dental'
        registration_services_hash['SERVICES']['Dental'] += 1
      elsif service.value_text.capitalize == 'Medical'
        registration_services_hash['SERVICES']['Medical'] += 1
      elsif service.value_text.capitalize == 'OB/Gyn'
        registration_services_hash['SERVICES']['OB/Gyn'] += 1
      elsif service.value_text.capitalize == 'Orthopedics'
        registration_services_hash['SERVICES']['Orthopedics'] += 1
      elsif service.value_text.capitalize == 'Pediatrics'
        registration_services_hash['SERVICES']['Pediatrics'] += 1
      elsif service.value_text.capitalize == ' Skin '
        registration_services_hash['SERVICES']['Skin'] += 1
      elsif service.value_text.capitalize == 'STI Clinic'
        registration_services_hash['SERVICES']['STI Clinic'] += 1
      elsif service.value_text.capitalize == 'Surgical'
        registration_services_hash['SERVICES']['Surgical'] += 1
      else
        registration_services_hash['SERVICES']['Other'] += 1
      end
    end

  	return services
  end

  def self.all_services(session_date)
  	services_concept_id = ConceptName.find_by_name('SERVICES').concept_id

    @start_date = session_date.to_date
    @end_date = session_date.to_date

    registration_services_hash = {} ; services = []
    registration_services_hash['SERVICES'] = {'Casualty' => 0,'Dental' => 0,'Eye' => 0,'Family Planing' => 0,'Medical' => 0,'OB/Gyn' => 0,'Orthopedics' => 0,'Other' => 0,'Pediatrics' => 0,'Skin' => 0,'STI Clinic' => 0,'Surgical' => 0}

    services = Observation.find(:all, :conditions => ["DATE(date_created) = ? AND concept_id = ?", Date.today.to_date, ConceptName.find_by_name("SERVICES").concept_id], :order => "obs_datetime desc")

    ( services || [] ).each do | service |
      if service.value_text.capitalize == 'Casualty'
        registration_services_hash['SERVICES']['Casualty'] += 1
      elsif service.value_text.capitalize == 'Eye'
        registration_services_hash['SERVICES']['Eye'] += 1
      elsif service.value_text.capitalize == 'Family Planing'
        registration_services_hash['SERVICES']['Family Planing'] += 1
      elsif service.value_text.capitalize == 'Dental'
        registration_services_hash['SERVICES']['Dental'] += 1
      elsif service.value_text.capitalize == 'Medical'
        registration_services_hash['SERVICES']['Medical'] += 1
      elsif service.value_text.capitalize == 'OB/Gyn'
        registration_services_hash['SERVICES']['OB/Gyn'] += 1
      elsif service.value_text.capitalize == 'Orthopedics'
        registration_services_hash['SERVICES']['Orthopedics'] += 1
      elsif service.value_text.capitalize == 'Pediatrics'
        registration_services_hash['SERVICES']['Pediatrics'] += 1
      elsif service.value_text.capitalize == ' Skin '
        registration_services_hash['SERVICES']['Skin'] += 1
      elsif service.value_text.capitalize == 'STI Clinic'
        registration_services_hash['SERVICES']['STI Clinic'] += 1
      elsif service.value_text.capitalize == 'Surgical'
        registration_services_hash['SERVICES']['Surgical'] += 1
      else
        registration_services_hash['SERVICES']['Other'] += 1
      end
    end

  	return services
  end

  def self.all_patient_services
  	services = Observation.find(:all, :conditions => ["DATE(date_created) = ? AND concept_id = ?", Date.today.to_date, ConceptName.find_by_name("SERVICES").concept_id], :order => "obs_datetime desc")
  end

	def self.guardian_present?(patient_id, date=Date.today)
    encounter_type_id = EncounterType.find_by_name("HIV Reception").id
    concept_id  = ConceptName.find_by_name("Guardian present").concept_id
    encounter = Encounter.find_by_sql("SELECT *
                                        FROM encounter
                                        WHERE patient_id = #{patient_id} AND DATE(date_created) = DATE('#{date.strftime("%Y-%m-%d")}') AND encounter_type = #{encounter_type_id}
                                        AND voided = 0
                                        ORDER BY date_created DESC").first rescue nil

    guardian_present=encounter.observations.find_last_by_concept_id(concept_id).to_s unless encounter.nil?

    return false if guardian_present.blank?
    return false if guardian_present.match(/No/)
    return true
  end

	def self.patient_and_guardian_present?(patient_id, date=Date.today)
    patient_present = self.patient_present?(patient_id, date)
    guardian_present = self.guardian_present?(patient_id, date)

    return false if !patient_present || !guardian_present
    return true
  end

  def self.patient_present?(patient_id, date=Date.today)
    encounter_type_id = EncounterType.find_by_name("HIV Reception").id
    concept_id  = ConceptName.find_by_name("Patient present").concept_id
    encounter = Encounter.find_by_sql("SELECT *
                                        FROM encounter
                                        WHERE patient_id = #{patient_id} AND DATE(date_created) = DATE('#{date.strftime("%Y-%m-%d")}') AND encounter_type = #{encounter_type_id}
                                        ORDER BY date_created DESC").last rescue nil

    patient_present = encounter.observations.find_last_by_concept_id(concept_id).to_s unless encounter.nil?

    return false if patient_present.blank?
    return false if patient_present.match(/No/)
    return true
  end

  def self.patient_national_id_label(patient)
	  patient_bean = get_patient(patient.person)
    return unless patient_bean.national_id
    sex =  patient_bean.sex.match(/F/i) ? "(F)" : "(M)"

    address = patient_bean.current_district rescue ""
    if address.blank?
      address = patient_bean.current_residence rescue ""
    else
      address += ", " + patient_bean.current_residence unless patient_bean.current_residence.blank?
    end

    label = ZebraPrinter::StandardLabel.new
    label.font_size = 2
    label.font_horizontal_multiplier = 2
    label.font_vertical_multiplier = 2
    label.left_margin = 50
    label.draw_barcode(50,180,0,1,4,15,120,false,"#{patient_bean.national_id}")
    label.draw_multi_text("#{patient_bean.name.titleize}")
    label.draw_multi_text("#{patient_bean.national_id_with_dashes} #{patient_bean.birth_date}#{sex}")
    label.draw_multi_text("#{address}" ) unless address.blank?
    label.print(1)
  end

  def self.recent_sputum_submissions(patient_id)
    sputum_concept_names = ["AAFB(1st)", "AAFB(2nd)", "AAFB(3rd)", "Culture(1st)", "Culture(2nd)"]
    sputum_concept_ids = ConceptName.find(:all, :conditions => ["name IN (?)", sputum_concept_names]).map(&:concept_id).join(",")
    main_concept = ConceptName.find_by_name('Sputum submission').concept_id

    obs = Observation.find_by_sql("SELECT * FROM obs WHERE person_id = #{patient_id} AND concept_id = #{main_concept}
                                  AND (value_coded in ('#{sputum_concept_ids}')
                                    OR value_text in ('#{sputum_concept_names}'))
                                  ORDER BY obs_datetime DESC LIMIT 3")

    #Observation.find(:all, :conditions => ["person_id = ? AND concept_id = ? AND (value_coded in (?)
    #               OR value_text in (?))",patient_id,
    #  ConceptName.find_by_name('Sputum submission').concept_id, sputum_concept_ids, sputum_concept_names],
    #:order => "obs_datetime desc", :limit => 3) rescue []
  end

  def self.recent_sputum_results(patient_id)
    sputum_concept_names = ["AAFB(1st) results", "AAFB(2nd) results", "AAFB(3rd) results", "Culture(1st) Results", "Culture-2 Results"]
    sputum_concept_ids = ConceptName.find(:all,
      :conditions => ["name IN (?)", sputum_concept_names]).map(&:concept_id).join(",")
    obs = Observation.find_by_sql("SELECT * FROM obs WHERE person_id = #{patient_id} AND concept_id IN ('#{sputum_concept_ids}')
                                  ORDER BY obs_datetime DESC LIMIT 3")
    #obs = Observation.find_by_sql(:all,
    #                      :conditions => ["person_id = ? AND concept_id IN (?)", patient_id, sputum_concept_ids],
    #                      :order => "obs_datetime desc",
    #                      :limit => 3)
  end

  def self.sputum_results_by_date(patient_id)
    sputum_concept_names = ["AAFB(1st) results", "AAFB(2nd) results", "AAFB(3rd) results"]
    sputum_concept_ids = ConceptName.find(:all,
      :conditions => ["name IN (?)", sputum_concept_names]).map(&:concept_id).join(",")
    obs = Observation.find_by_sql("SELECT * FROM obs WHERE person_id = #{patient_id} AND concept_id IN ('#{sputum_concept_ids}')
                                  ORDER BY obs_datetime DESC")
    #obs = Observation.find(:all,
    #                  :conditions => ["person_id = ? AND concept_id IN (?)", patient_id, sputum_concept_ids],
    #                  :order => "obs_datetime desc")
  end

	def self.sputum_by_date(sputum_list, date)
		i = 0;
		list = Hash.new("")
		while (i < sputum_list.count)
			if ((sputum_list[i].obs_datetime.to_date >= date - 10) && (sputum_list[i].obs_datetime.to_date <= date + 10))
        list["acc1"] = sputum_list[i].accession_number
        list["result1"] = sputum_list[i].answer_string
        list["acc2"] = sputum_list[i+1].accession_number
        list["result2"] = sputum_list[i+1].answer_string
        return list
			end rescue nil
			i+=1
		end
	end

	def self.pre_art_start_date(patient)

    start_date = Encounter.find_by_sql(" SELECT * FROM encounter e
								INNER JOIN encounter_type et ON et.encounter_type_id = e.encounter_type
								INNER JOIN obs ON obs.encounter_id = e.encounter_id
								WHERE obs.person_id = '#{patient.id}' AND et.name = 'HIV RECEPTION'
								ORDER BY e.encounter_datetime DESC LIMIT 1").first.obs_datetime rescue nil
	end
  def self.sputum_orders_without_submission(patient_id)
    self.recent_sputum_orders(patient_id).collect{|order| order unless Observation.find(:all, :conditions => ["person_id = ? AND concept_id = ?", patient_id, Concept.find_by_name("Sputum submission")]).map{|o| o.accession_number}.include?(order.accession_number)}.compact #rescue []
  end

  def self.recent_sputum_orders(patient_id)
    sputum_concept_names = ["AAFB(1st)", "AAFB(2nd)", "AAFB(3rd)", "Culture(1st)", "Culture(2nd)"]
    sputum_concept_ids = ConceptName.find(:all, :conditions => ["name IN (?)", sputum_concept_names]).map(&:concept_id)
    Observation.find(:all, :conditions => ["person_id = ? AND concept_id = ? AND (value_coded in (?) OR value_text in (?))", patient_id, ConceptName.find_by_name('Tests ordered').concept_id, sputum_concept_ids, sputum_concept_names], :order => "obs_datetime desc", :limit => 3)
  end

  def self.hiv_test_date(patient_id)
    test_date = Observation.find(:last, :conditions => ["person_id = ? AND concept_id = ?", patient_id, ConceptName.find_by_name("HIV test date").concept_id]).value_datetime rescue nil
    return test_date
  end

  def self.months_since_last_hiv_test(patient_id)
    #this can be done better
    session_date = Observation.find(:last, :conditions => ["person_id = ? AND concept_id = ?", patient_id, ConceptName.find_by_name("HIV test date").concept_id]).obs_datetime rescue Date.today

    today =  session_date
    hiv_test_date = self.hiv_test_date(patient_id)
    months = (today.year * 12 + today.month) - (hiv_test_date.year * 12 + hiv_test_date.month) rescue nil
    return months
  end

  def self.patient_hiv_status(patient)
    status = Concept.find(Observation.find(:first,
        :order => "obs_datetime DESC,date_created DESC",
        :conditions => ["value_coded IS NOT NULL AND person_id = ? AND concept_id = ?", patient.id,
          ConceptName.find_by_name("HIV STATUS").concept_id]).value_coded).fullname rescue "UNKNOWN"

    if status.upcase == 'UNKNOWN'
      return patient.patient_programs.collect{|p|p.program.name}.include?('HIV PROGRAM') ? 'Positive' : status
    end
    return status
  end

  def self.patient_hiv_status_by_date(patient, date)
    status = Concept.find(Observation.find(:last,
        :order => "obs_datetime DESC,date_created DESC",
        :conditions => ["value_coded IS NOT NULL AND person_id = ? AND concept_id = ? AND obs_datetime BETWEEN ? AND ?", patient.id,
          ConceptName.find_by_name("HIV STATUS").concept_id,date - 20,date + 20]).value_coded).fullname rescue "UNKNOWN"
    if status.upcase == 'UNKNOWN'
      return "Unknown"
    end
    return status
  end

  def self.patient_is_child?(patient)
    return self.get_patient_attribute_value(patient, "age") <= 14 unless self.get_patient_attribute_value(patient, "age").nil?
    return false
  end

  def self.get_patient_attribute_value(patient, attribute_name, session_date = Date.today)

    patient_bean = get_patient(patient.person)
    if patient_bean.sex.upcase == 'MALE'
   		sex = 'M'
    elsif patient_bean.sex.upcase == 'FEMALE'
   		sex = 'F'
    end

    case attribute_name.upcase
    when "AGE"
      return patient_bean.age
    when "RESIDENCE"
      return patient_bean.address
    when "CURRENT_HEIGHT"
      obs = patient.person.observations.before((session_date + 1.days).to_date).question("HEIGHT (CM)").all
      return obs.first.answer_string.to_f rescue 0
    when "CURRENT_WEIGHT"
      obs = patient.person.observations.before((session_date + 1.days).to_date).question("WEIGHT (KG)").all
      return obs.first.answer_string.to_f rescue 0
    when "INITIAL_WEIGHT"
      obs = patient.person.observations.old(1).question("WEIGHT (KG)").all
      return obs.last.answer_string.to_f rescue 0
    when "INITIAL_HEIGHT"
      obs = patient.person.observations.old(1).question("HEIGHT (CM)").all
      return obs.last.answer_string.to_f rescue 0
    when "INITIAL_BMI"
      obs = patient.person.observations.old(1).question("BMI").all
      return obs.last.answer_string.to_f rescue nil
    when "MIN_WEIGHT"
      return WeightHeight.min_weight(sex, patient_bean.age_in_months).to_f
    when "MAX_WEIGHT"
      return WeightHeight.max_weight(sex, patient_bean.age_in_months).to_f
    when "MIN_HEIGHT"
      return WeightHeight.min_height(sex, patient_bean.age_in_months).to_f
    when "MAX_HEIGHT"
      return WeightHeight.max_height(sex, patient_bean.age_in_months).to_f
    end

  end

  def self.patient_tb_status(patient)
		state = Concept.find(Observation.find(:first,
				:order => "obs_datetime DESC,date_created DESC",
				:conditions => ["person_id = ? AND concept_id = ? AND value_coded IS NOT NULL", patient.id,
          ConceptName.find_by_name("TB STATUS").concept_id]).value_coded).fullname rescue "UNKNOWN"
    programs = patient.patient_programs.all
    programs.each do |prog|
      if prog.program.name.upcase == "TB PROGRAM"
        state = ProgramWorkflowState.find_state(prog.patient_states.last.state).concept.fullname rescue state
      end
    end
		state
  end

  def self.reason_for_art_eligibility(patient)
=begin
    reasons = patient.person.observations.recent(1).question("REASON FOR ART ELIGIBILITY").all rescue nil
    reasons.map{|c|ConceptName.find(c.value_coded_name_id).name}.join(',') rescue nil
=end
    reason_for_art = ActiveRecord::Base.connection.select_one <<EOF
      SELECT patient_reason_for_starting_art_text(#{patient.patient_id}) reason;
EOF

    return reason_for_art['reason']
  end

  def self.patient_appointment_dates(patient, start_date, end_date = nil)

    end_date = start_date if end_date.nil?

    appointment_date_concept_id = Concept.find_by_name("APPOINTMENT DATE").concept_id rescue nil

    appointments = Observation.find(:all,
      :conditions => ["obs.value_datetime BETWEEN TIMESTAMP(?) AND TIMESTAMP(?) AND " +
          "obs.concept_id = ? AND obs.voided = 0 AND obs.person_id = ?",
        start_date.to_date.strftime('%Y-%m-%d 00:00:00'),
        end_date.to_date.strftime('%Y-%m-%d 23:59:59'),
        appointment_date_concept_id, patient.id])

    appointments
  end



  def self.get_patient_identifier(patient, identifier_type)
    patient_identifier_type_id = PatientIdentifierType.find_by_name(identifier_type).patient_identifier_type_id rescue nil
    patient_identifier = PatientIdentifier.find(:first, :select => "identifier",
      :conditions  =>["patient_id = ? and identifier_type = ?", patient.id, patient_identifier_type_id],
      :order => "date_created DESC" ).identifier rescue nil
    return patient_identifier
  end

  def self.patient_printing_message(new_patient , archived_patient , creating_new_filing_number_for_patient = false)
    arv_code = Location.current_arv_code
    new_patient_bean = get_patient(new_patient.person)
    archived_patient_bean = get_patient(archived_patient.person) rescue nil

    new_patient_name = new_patient_bean.name
    new_filing_number = patient_printing_filing_number_label(new_patient_bean.filing_number)
    inactive_identifier = PatientIdentifier.inactive(:first,:order => 'date_created DESC',
      :conditions => ['identifier_type = ? AND patient_id = ?',PatientIdentifierType.
          find_by_name("Archived filing number").patient_identifier_type_id,
        archived_patient.person.id]).identifier rescue nil
    old_archive_filing_number = patient_printing_filing_number_label(old_filing_number(new_patient, "Archived filing number"))

    unless archived_patient.blank?
      old_active_filing_number = patient_printing_filing_number_label(old_filing_number(archived_patient))
      new_archive_filing_number = patient_printing_filing_number_label(archived_patient_bean.archived_filing_number)
    end

    if new_patient and archived_patient and creating_new_filing_number_for_patient
      table = <<EOF
<div id='patients_info_div'>
<table id = 'filing_info'>
<tr>
  <th class='filing_instraction'>Filing actions required</th>
  <th class='filing_instraction'>Name</th>
  <th style="text-align:left;">Old label</th>
  <th style="text-align:left;">New label</th>
</tr>

<tr>
  <td style='text-align:left;'>Active → Dormant</td>
  <td class = 'filing_instraction'>#{archived_patient_bean.name}</td>
  <td class = 'old_label'>#{old_active_filing_number}</td>
  <td class='new_label'>#{new_archive_filing_number}</td>
</tr>

<tr>
  <td style='text-align:left;'>Add → Active</td>
  <td class = 'filing_instraction'>#{new_patient_name}</td>
  <td class = 'old_label'>#{old_archive_filing_number}</td>
  <td class='new_label'>#{new_filing_number}</td>
</tr>
</table>
</div>
EOF
    elsif new_patient and creating_new_filing_number_for_patient
      table = <<EOF
<div id='patients_info_div'>
<table id = 'filing_info'>
<tr>
  <th class='filing_instraction'>Filing actions required</th>
  <th class='filing_instraction'>Name</th>
  <th>&nbsp;</th>
  <th style="text-align:left;">New label</th>
</tr>

<tr>
  <td style='text-align:left;'>Add → Active</td>
  <td class = 'filing_instraction'>#{new_patient_name}</td>
  <td class = 'filing_instraction'>&nbsp;</td>
  <td class='new_label'>#{new_filing_number}</td>
</tr>
</table>
</div>
EOF
    elsif new_patient and archived_patient and not creating_new_filing_number_for_patient
      table = <<EOF
<div id='patients_info_div'>
<table id = 'filing_info'>
<tr>
  <th class='filing_instraction'>Filing actions required</th>
  <th class='filing_instraction'>Name</th>
  <th style="text-align:left;">Old label</th>
  <th style="text-align:left;">New label</th>
</tr>
<tr>
  <td style='text-align:left;'>Add → Active</td>
  <td class = 'filing_instraction'>#{new_patient_name}</td>
  <td class = 'old_label'>#{old_archive_filing_number}</td>
  <td class='new_label'>#{new_filing_number}</td>
</tr>
</table>
</div>
EOF
    elsif new_patient and not creating_new_filing_number_for_patient
      table = <<EOF
<div id='patients_info_div'>
<table id = 'filing_info'>
<tr>
  <th class='filing_instraction'>Filing actions required</th>
  <th class='filing_instraction'>Name</th>
  <th>Old label</th>
  <th style="text-align:left;">New label</th>
</tr>

<tr>
  <td style='text-align:left;'>Add → Active</td>
  <td class = 'filing_instraction'>#{new_patient_name}</td>
  <td class = 'old_label'>#{old_archive_filing_number}</td>
  <td class='new_label'>#{new_filing_number}</td>
</tr>
</table>
</div>
EOF
    end

    return table
  end

  def self.patient_age_at_initiation(patient, initiation_date = nil)
    return self.age(patient.person, initiation_date) unless initiation_date.nil?
  end

  def self.art_patient?(patient)
    program_id = Program.find_by_name('HIV PROGRAM').id
    enrolled = PatientProgram.find(:first,:conditions =>["program_id = ? AND patient_id = ?",program_id,patient.id]).blank?
    return true unless enrolled
    false
  end

  #data cleaning :- moved from patient.rb
  def self.current_diagnoses(patient_id)
    patient = Patient.find(patient_id)
    patient.encounters.current.all(:include => [:observations]).map{|encounter|
      encounter.observations.all(
        :conditions => ["obs.concept_id = ? OR obs.concept_id = ?",
          ConceptName.find_by_name("DIAGNOSIS").concept_id,
          ConceptName.find_by_name("DIAGNOSIS, NON-CODED").concept_id])
    }.flatten.compact
  end

  def self.patient_art_start_date(patient_id)
    self.date_antiretrovirals_started(Patient.find(patient_id))
    #date = ActiveRecord::Base.connection.select_value <<EOF
    #SELECT patient_start_date(#{patient_id})
    #EOF
    #return date.to_date rescue nil
  end

  def self.prescribe_arv_this_visit(patient, date = Date.today)
    encounter_type = EncounterType.find_by_name('ART VISIT')
    yes_concept = ConceptName.find_by_name('YES').concept_id
    refer_concept = ConceptName.find_by_name('PRESCRIBE ARVS THIS VISIT').concept_id
    refer_patient = Encounter.find(:first,
      :joins => 'INNER JOIN obs USING (encounter_id)',
      :conditions => ["encounter_type = ? AND concept_id = ? AND person_id = ? AND value_coded = ? AND obs_datetime BETWEEN ? AND ?",
        encounter_type.id,refer_concept,patient.id,yes_concept,
        date.to_date.strftime('%Y-%m-%d 00:00:00'),
        date.to_date.strftime('%Y-%m-%d 23:59:59')
      ],
      :order => 'encounter_datetime DESC,date_created DESC')
    return false if refer_patient.blank?
    return true
  end

  def self.get_debugger_details(person, current_date = Date.today)
		patient = PatientBean.new('')
		patient.person_id = person.id
		patient.name = person.names.first.given_name + ' ' + person.names.first.family_name rescue nil
		patient.patient_id = person.patient.id
		patient.age = age(person, current_date)
		patient.age_in_months = age_in_months(person, current_date)
		patient.arv_number = get_patient_identifier(person.patient, 'ARV Number')
		patient.splitted_arv_number = patient.arv_number.split("-").last.to_i rescue 0
		patient
	end

  def self.get_patient(person, current_date = Date.today)
    patient = PatientBean.new('')
    patient.person_id = person.id
    patient.patient_id = person.patient.id
    patient.arv_number = get_patient_identifier(person.patient, 'ARV Number')
    patient.address = person.addresses.first.city_village rescue nil
    patient.national_id = get_patient_identifier(person.patient, 'National id')
	  patient.national_id_with_dashes = get_national_id_with_dashes(person.patient) rescue nil
    names = person.names rescue nil
    patient.name = names[names.length > 1 ? (names.length - 1) : 0].given_name + ' ' + names[names.length > 1 ? (names.length - 1) : 0].family_name rescue nil
		patient.first_name = names[names.length > 1 ? (names.length - 1) : 0].given_name rescue nil
		patient.last_name = names[names.length > 1 ? (names.length - 1) : 0].family_name rescue nil
    patient.sex = sex(person)
    if age(person, current_date).blank?
      patient.age = 0
    else
      patient.age = age(person, current_date)
    end
    patient.age_in_months = age_in_months(person, current_date)
    patient.dead = person.dead
    patient.birth_date = birthdate_formatted(person)
    patient.birthdate_estimated = person.birthdate_estimated
    patient.current_district = person.addresses.first.state_province rescue nil
    patient.home_district = person.addresses.first.address2 rescue nil
    patient.traditional_authority = person.addresses.first.county_district rescue nil
    patient.current_residence = person.addresses.first.city_village rescue nil
    patient.landmark = person.addresses.first.address1 rescue nil
    patient.home_village = person.addresses.first.neighborhood_cell rescue nil
    patient.mothers_surname = person.names.first.family_name2 rescue nil
    patient.eid_number = get_patient_identifier(person.patient, 'EID Number') rescue nil
    patient.pre_art_number = get_patient_identifier(person.patient, 'Pre ART Number (Old format)') rescue nil
    patient.archived_filing_number = get_patient_identifier(person.patient, 'Archived filing number')rescue nil
    patient.filing_number = get_patient_identifier(person.patient, 'Filing Number')
    patient.occupation = get_attribute(person, 'Occupation')
    patient.cell_phone_number = get_attribute(person, 'Cell phone number')
    patient.office_phone_number = get_attribute(person, 'Office phone number')
    patient.home_phone_number = get_attribute(person, 'Home phone number')
    patient.regiment_id = get_attribute(person, 'Regiment ID')
    patient.date_joined_military = get_attribute(person, 'Date Joined Military')
    patient.military_rank = get_attribute(person, 'Military Rank')
    patient.guardian = art_guardian(person.patient) rescue nil
    patient
  end

  def self.art_guardian(patient)
    person_id = Relationship.find(:first,:order => "date_created DESC",
      :conditions =>["person_a = ?",patient.person.id]).person_b rescue nil
    guardian_name = name(Person.find(person_id))
    guardian_name rescue nil
  end

  def self.name(person)
    "#{person.names.first.given_name} #{person.names.first.family_name}".titleize rescue nil
  end

  def self.age(person, today = Date.today)
    return nil if person.birthdate.nil?

    # This code which better accounts for leap years
    patient_age = (today.year - person.birthdate.year) + ((today.month - person.birthdate.month) + ((today.day - person.birthdate.day) < 0 ? -1 : 0) < 0 ? -1 : 0)

    # If the birthdate was estimated this year, we round up the age, that way if
    # it is March and the patient says they are 25, they stay 25 (not become 24)
    birth_date=person.birthdate
    estimate=person.birthdate_estimated==1
    patient_age += (estimate && birth_date.month == 7 && birth_date.day == 1  &&
        today.month < birth_date.month && person.date_created.year == today.year) ? 1 : 0
  end

  def self.old_filing_number(patient, type = 'Filing Number')
    identifier_type = PatientIdentifierType.find_by_name(type)
    PatientIdentifier.find_by_sql(["
      SELECT * FROM patient_identifier
      WHERE patient_id = ?
      AND identifier_type = ?
      AND voided = 1
      ORDER BY date_created DESC
      LIMIT 1",patient.id,identifier_type.id]).first.identifier rescue nil
  end

  def self.patient_to_be_archived(patient)
    active_identifier_type = PatientIdentifierType.find_by_name("Filing Number")
=begin
    PatientIdentifier.find_by_sql(["
      SELECT * FROM patient_identifier
      WHERE voided = 1 AND identifier_type = ? AND void_reason = ? ORDER BY date_created DESC",
        active_identifier_type.id,"Archived - filing number given to:#{patient.id}"]).first.patient rescue nil
=end


    PatientIdentifier.find_by_sql(["SELECT * FROM patient_identifier WHERE voided = 1
     AND identifier_type = ? AND void_reason = 'Archived - filing number given to:#{patient.id}'
     ORDER BY date_created DESC",active_identifier_type.id]).first.patient rescue nil

  end

  def self.set_patient_filing_number(patient) #changed from set_filing_number after being moved from patient model
    next_filing_number = PatientIdentifier.next_filing_number # gets the new filing number!
    # checks if the the new filing number has passed the filing number limit...
    # move dormant patient from active to dormant filing area ... if needed
    self.next_filing_number_to_be_archived(patient, next_filing_number)
  end

  def self.next_filing_number_to_be_archived(current_patient , next_filing_number)
    ActiveRecord::Base.transaction do
      global_property_value = CoreService.get_global_property_value("filing.number.limit")

      if global_property_value.blank?
        global_property_value = '10000'
      end

      active_filing_number_identifier_type = PatientIdentifierType.find_by_name("Filing Number")
      dormant_filing_number_identifier_type = PatientIdentifierType.find_by_name('Archived filing number')

      patient_to_be_archived = []

      if (next_filing_number[5..-1].to_i > global_property_value.to_i)
        return []
=begin 
        #we have a new way of archiving files
                    
        patient_ids = PatientIdentifier.find_by_sql("
          SELECT DISTINCT(patient_id) patient_id FROM patient_identifier
          WHERE voided = 0 AND identifier_type = #{active_filing_number_identifier_type.id}
          GROUP BY identifier
          ").map(&:patient_id)

        patient_to_be_archived = Person.find_by_sql(["
          SELECT * FROM person WHERE person_id IN(?) AND dead = 1 AND voided = 0 LIMIT 1", 
            patient_ids]).first.patient rescue nil
      else
        #assigning "patient_to_be_archived" filing number to the new patient
        filing_number = PatientIdentifier.new()
        filing_number.patient_id = current_patient.id
        filing_number.identifier_type = active_filing_number_identifier_type.id
        filing_number.identifier = next_filing_number
        filing_number.save
        return 
      end

      unless patient_to_be_archived.blank?
        filing_number = PatientIdentifier.new()
        filing_number.patient_id = patient_to_be_archived.id
        filing_number.identifier_type = dormant_filing_number_identifier_type.id
        filing_number.identifier = PatientIdentifier.next_filing_number("Archived filing number")
        filing_number.save

        #assigning "patient_to_be_archived" filing number to the new patient
        filing_number= PatientIdentifier.new()
        filing_number.patient_id = current_patient.id
        filing_number.identifier_type = active_filing_number_identifier_type.id
        filing_number.identifier = self.get_patient_identifier(patient_to_be_archived, 'Filing Number')
        filing_number.save

        #void current filing number
        current_filing_numbers =  PatientIdentifier.find(:all,
          :conditions=>["patient_id=? AND identifier_type = ?",
            patient_to_be_archived.id,PatientIdentifierType.find_by_name("Filing Number").id])

        current_filing_numbers.each do | f_number |
          f_number.voided = 1
          f_number.voided_by = User.current.id
          f_number.void_reason = "Archived - filing number given to:#{current_patient.id}"
          f_number.date_voided = Time.now()
          f_number.save
        end

        return patient_to_be_archived
=end
      else
        #void current dormant filing number
        current_filing_numbers =  PatientIdentifier.find(:all,
          :conditions=>["patient_id=? AND identifier_type = ?",
            current_patient.patient_id,
            PatientIdentifierType.find_by_name("Archived filing Number").id])

        (current_filing_numbers || []).each do | f_number |
          f_number.voided = 1
          f_number.voided_by = User.current.id
          f_number.void_reason = "Given active filing number: #{next_filing_number}"
          f_number.date_voided = Time.now()
          f_number.save
        end

        filing_number = PatientIdentifier.new()
        filing_number.patient_id = current_patient.patient_id
        filing_number.identifier_type = active_filing_number_identifier_type.id
        filing_number.identifier = next_filing_number
        filing_number.save
        return current_patient
      end
    end

  end
  
  def self.archive_patient(primary, secondary)

    active_filing_number_identifier_type = PatientIdentifierType.find_by_name("Filing Number")
    dormant_filing_number_identifier_type = PatientIdentifierType.find_by_name('Archived filing number')

    filing_number = PatientIdentifier.new()
    filing_number.patient_id = secondary.id
    filing_number.identifier_type = dormant_filing_number_identifier_type.id
    filing_number.identifier = PatientIdentifier.next_filing_number("Archived filing number")
    filing_number.save

    #assigning "patient_to_be_archived" filing number to the new patient
    filing_number= PatientIdentifier.new()
    filing_number.patient_id = primary.id
    filing_number.identifier_type = active_filing_number_identifier_type.id
    filing_number.identifier = self.get_patient_identifier(secondary, 'Filing Number')
    filing_number.save

    #void current filing number
    current_filing_numbers =  PatientIdentifier.find(:all,
      :conditions=>["patient_id=? AND identifier_type = ?",
        secondary.id,PatientIdentifierType.find_by_name("Filing Number").id])

    current_filing_numbers.each do | f_number |
      f_number.voided = 1
      f_number.voided_by = User.current.id
      f_number.void_reason = "Archived - filing number given to:#{primary.id}"
      f_number.date_voided = Time.now()
      f_number.save
    end

    return nil
  end

  def self.get_patient_to_be_archived_that_has_transfered_out(patient_ids = [])
    #The following function will get all transferred out patients
    #with active filling numbers and select one to be archived
    return nil if patient_ids.blank?

    transfers = ActiveRecord::Base.connection.select_all <<EOF
    SELECT pp.patient_id, c.name outcome, start_date,end_date, s.date_created date_outcome_created
    FROM program p
    INNER JOIN patient_program pp ON pp.program_id = p.program_id
    INNER JOIN patient_state s ON pp.patient_program_id = s.patient_program_id
    INNER JOIN program_workflow_state f ON s.state = f.program_workflow_state_id
    INNER JOIN concept_name c ON c.concept_id = f.concept_id
    WHERE s.voided = 0 AND p.program_id = 1 AND pp.patient_id IN(#{patient_ids.join(',')})
    HAVING start_date = (SELECT MAX(start_date) FROM patient_state t
    WHERE patient_program_id = s.patient_program_id)
    AND date_outcome_created = (SELECT MAX(date_created) FROM patient_state t
    WHERE patient_program_id = s.patient_program_id)
    AND (outcome LIKE '%transferred out%');
EOF

    return nil if transfers.blank?
    transfers.sort_by { |k, v| k['start_date'].to_date }.first['patient_id'].to_i
  end


  def self.get_patient_to_be_archived_based_on_waste_state(limit)
    #The following function will get all transferred out patients
    #with active filling numbers and select one to be archived
    limit_one = (limit - 15)
    limit_two = (limit)

    active_filing_number_identifier_type = PatientIdentifierType.find_by_name("Filing Number")

    patient_ids = PatientIdentifier.find_by_sql("
      SELECT DISTINCT(patient_id) patient_id FROM patient_identifier
      WHERE voided = 0 AND identifier_type = #{active_filing_number_identifier_type.id}
      GROUP BY identifier
      ").map(&:patient_id)
   
   
    duplicate_identifiers = []
    data = PatientIdentifier.find_by_sql("
      SELECT identifier, count(identifier) AS c 
      FROM patient_identifier WHERE voided = 0 
      AND identifier_type = #{active_filing_number_identifier_type.id}
      GROUP BY identifier HAVING c > 1")
    
    (data || []).map do |i|
      duplicate_identifiers << "'#{i['identifier']}'"
    end
  
    duplicate_identifiers = [] if duplicate_identifiers.blank?
   
    #here we remove all ids that have any encounter today.
    patient_ids_with_todays_encounters = Encounter.find_by_sql("
      SELECT DISTINCT(patient_id) patient_id FROM encounter
        WHERE voided = 0 AND encounter_datetime BETWEEN '#{Date.today.strftime('%Y-%m-%d 00:00:00')}'
              AND '#{Date.today.strftime('%Y-%m-%d 23:59:59')}'
      ").map(&:patient_id)

    filing_number_identifier_type = PatientIdentifierType.find_by_name('Filing number').id

    patient_ids_with_todays_active_filing_numbers = PatientIdentifier.find_by_sql("
      SELECT DISTINCT(patient_id) patient_id FROM patient_identifier
      WHERE voided = 0 AND date_created BETWEEN '#{Date.today.strftime('%Y-%m-%d 00:00:00')}'
      AND '#{Date.today.strftime('%Y-%m-%d 23:59:59')}'
      AND identifier_type = #{filing_number_identifier_type}").map(&:patient_id)

    patient_ids = (patient_ids - patient_ids_with_todays_encounters)
    patient_ids = (patient_ids - patient_ids_with_todays_active_filing_numbers)
    patient_ids = [0] if patient_ids.blank?


    patient_ids_with_future_app = ActiveRecord::Base.connection.select_all <<EOF
    SELECT person_id FROM obs WHERE concept_id = #{ConceptName.find_by_name('Appointment date').concept_id} 
    AND voided = 0 AND value_datetime >= '#{(Date.today - 2.month).strftime('%Y-%m-%d 00:00:00')}'
    GROUP BY person_id;
EOF

    no_patient_ids = patient_ids_with_future_app.map{|ad| ad['person_id'].to_i }
    no_patient_ids = [0] if patient_ids_with_future_app.blank?

    unless duplicate_identifiers.blank?
      sql_path = "AND i.identifier NOT IN (#{duplicate_identifiers.join(',')})"
    else
      sql_path = ''
    end

    outcomes = ActiveRecord::Base.connection.select_all <<EOF
SELECT p.patient_id,state,start_date,end_date FROM patient_state s
INNER JOIN patient_program p ON p.patient_program_id = s.patient_program_id
INNER JOIN patient_identifier i ON p.patient_id = i.patient_id
AND i.identifier_type = #{filing_number_identifier_type} AND i.voided = 0
WHERE p.patient_id IN(#{patient_ids.join(',')}) 
AND p.patient_id NOT IN (#{no_patient_ids.join(',')})
#{sql_path}
AND state IN (2, 3, 4, 5, 6, 8)
  AND state != 7
  AND start_date = (SELECT max(start_date) FROM patient_state t
  WHERE t.patient_program_id = s.patient_program_id)
GROUP BY p.patient_id ORDER BY state
LIMIT #{limit_one}, #{limit_two};
EOF

    if outcomes.blank? or outcomes.length < 5

      encounter_patient_ids = Encounter.find_by_sql(" 
      SELECT patient_id, MAX(encounter_datetime) max_encounter_datetime
      FROM  encounter WHERE patient_id IN(#{patient_ids.join(',')}) 
      AND voided = 0 GROUP BY patient_id 
      HAVING max_encounter_datetime <= '#{(Date.today - 150.day).to_date.strftime('%Y-%m-%d 23:59:59')}';
        ").map{ |e| e.patient_id }.uniq rescue nil

      encounter_patient_ids = [0] if encounter_patient_ids.blank?

      outcomes = ActiveRecord::Base.connection.select_all <<EOF
SELECT p.patient_id,state,start_date,end_date  FROM patient_state s
INNER JOIN patient_program p ON p.patient_program_id = s.patient_program_id
INNER JOIN patient_identifier i ON p.patient_id = i.patient_id
AND i.identifier_type = #{filing_number_identifier_type} AND i.voided = 0
WHERE p.patient_id IN(#{patient_ids.join(',')}) 
AND p.patient_id NOT IN (#{no_patient_ids.join(',')})
AND start_date = (SELECT max(start_date) FROM patient_state t
    WHERE t.patient_program_id = s.patient_program_id)
AND p.patient_id IN (#{encounter_patient_ids.join(',')})
GROUP BY p.patient_id 
ORDER BY state LIMIT #{limit_one}, #{limit_two};
EOF

    
    end

    return outcomes rescue nil
  end

  def self.patients_with_the_least_encounter_datetime(patient_ids = [])
    #The following function will get all patients with the least
    #encounter datetime (HIV/ART clinic)
    return nil if patient_ids.blank?

    encounter_type_name = ['HIV CLINIC REGISTRATION','VITALS','HIV CLINIC CONSULTATION',
      'TREATMENT','HIV RECEPTION','HIV STAGING','DISPENSING','APPOINTMENT']
    encounter_type_ids = EncounterType.find(:all,:conditions => ["name IN (?)",encounter_type_name]).map{|n|n.id}

    #Patients with an appointment in the past month and the next 6 weeks from
    #current date
    appointment_encounter_type = EncounterType.find(:first,:conditions => ["name IN (?)",'APPOINTMENT'])
    appointment_concept_id = ConceptName.find_by_name("APPOINTMENT DATE").id
    start_date = (Date.today - 7.month).strftime('%Y-%m-%d 00:00:00')
    end_date = (Date.today + 5.year).strftime('%Y-%m-%d 23:59:59')

    patient_not_to_be_archived = Encounter.find_by_sql(["
      SELECT patient_id FROM encounter
      INNER JOIN obs ON obs.encounter_id = encounter.encounter_id AND obs.concept_id = #{appointment_concept_id}
      WHERE encounter.voided = 0 AND obs.value_datetime BETWEEN (?) AND (?)
      AND encounter_type = ? AND obs.voided = 0 GROUP BY patient_id",start_date,end_date,
        appointment_encounter_type]).map(&:patient_id)
    patient_not_to_be_archived = [0] if patient_not_to_be_archived.blank?

    #Patients with at least an encounter of type: encounter_type_name in the past 7 months
    #and the next 7 months from current date
    patient_not_to_be_archived_with_an_encounter = Encounter.find_by_sql(["
      SELECT patient_id FROM encounter
      WHERE encounter.voided = 0 AND encounter_datetime BETWEEN (?) AND (?)
      AND encounter_type IN(?)
      GROUP BY patient_id",start_date,end_date,encounter_type_ids]).map(&:patient_id)

    patient_not_to_be_archived_with_an_encounter = [0] if patient_not_to_be_archived_with_an_encounter.blank?

    patient_not_to_be_archived = patient_not_to_be_archived && patient_not_to_be_archived_with_an_encounter

    return Encounter.find_by_sql(["
      SELECT patient_id
      FROM encounter
      WHERE encounter.voided = 0 AND patient_id IN (?) AND patient_id NOT IN (?)
        AND encounter_type IN (?)
      ORDER BY encounter_datetime ASC LIMIT 1
        ",patient_ids, patient_not_to_be_archived, encounter_type_ids,
      ]).first.patient rescue nil
  end

	def self.patient_printing_filing_number_label(number=nil)
		return number[5..5] + " " + number[6..7] + " " + number[8..-1] unless number.nil?
	end

	def self.create_from_form(params)
    return nil if params.blank?
		address_params = params["addresses"]
		names_params = params["names"]
		patient_params = params["patient"]
		params_to_process = params.reject{|key,value| key.match(/addresses|patient|names|relation|cell_phone_number|home_phone_number|office_phone_number|agrees_to_be_visited_for_TB_therapy|agrees_phone_text_for_TB_therapy|regiment_id|date_joined_military|military_rank/) }
		birthday_params = params_to_process.reject{|key,value| key.match(/gender/) }
		person_params = params_to_process.reject{|key,value| key.match(/birth_|age_estimate|occupation|identifiers/) }

		if person_params["gender"].to_s == "Female"
      person_params["gender"] = 'F'
		elsif person_params["gender"].to_s == "Male"
      person_params["gender"] = 'M'
		end

		person = Person.create(person_params)

		unless birthday_params.empty?
		  if birthday_params["birth_year"] == "Unknown"
        self.set_birthdate_by_age(person, birthday_params["age_estimate"], person.session_datetime || Date.today)
		  else
        self.set_birthdate(person, birthday_params["birth_year"], birthday_params["birth_month"], birthday_params["birth_day"])
		  end
		end

    unless person_params['birthdate_estimated'].blank?
      person.birthdate_estimated = person_params['birthdate_estimated'].to_i
    end

		person.save

		person.names.create(names_params)
		person.addresses.create(address_params) unless address_params.empty? rescue nil

		person.person_attributes.create(
		  :person_attribute_type_id => PersonAttributeType.find_by_name("Occupation").person_attribute_type_id,
		  :value => params["occupation"]) unless params["occupation"].blank? rescue nil

		person.person_attributes.create(
		  :person_attribute_type_id => PersonAttributeType.find_by_name("Cell Phone Number").person_attribute_type_id,
		  :value => params["cell_phone_number"]) unless params["cell_phone_number"].blank? rescue nil

		person.person_attributes.create(
		  :person_attribute_type_id => PersonAttributeType.find_by_name("Office Phone Number").person_attribute_type_id,
		  :value => params["office_phone_number"]) unless params["office_phone_number"].blank? rescue nil

		person.person_attributes.create(
		  :person_attribute_type_id => PersonAttributeType.find_by_name("Home Phone Number").person_attribute_type_id,
		  :value => params["home_phone_number"]) unless params["home_phone_number"].blank? rescue nil

    ##### MILITARY START #####
    person.person_attributes.create(
		  :person_attribute_type_id => PersonAttributeType.find_by_name("Regiment ID").person_attribute_type_id,
		  :value => params["regiment_id"]) unless params["regiment_id"].blank? rescue nil

    person.person_attributes.create(
		  :person_attribute_type_id => PersonAttributeType.find_by_name("Date Joined Military").person_attribute_type_id,
		  :value => params["date_joined_military"]) unless params["date_joined_military"].blank? rescue nil
    
    person.person_attributes.create(
		  :person_attribute_type_id => PersonAttributeType.find_by_name("Military Rank").person_attribute_type_id,
		  :value => params["military_rank"]) unless params["military_rank"].blank? rescue nil

    ##### MILITARY END #####
    # TODO handle the birthplace attribute

		if (!patient_params.nil?)
		  patient = person.create_patient
      params["identifiers"].each{|identifier_type_name, identifier|
        next if identifier.blank?
        identifier_type = PatientIdentifierType.find_by_name(identifier_type_name) || PatientIdentifierType.find_by_name("Unknown id")
        patient.patient_identifiers.create("identifier" => identifier, "identifier_type" => identifier_type.patient_identifier_type_id)
		  } if params["identifiers"]
=begin
		  patient_params["identifiers"].each{|identifier_type_name, identifier|
        next if identifier.blank?
        identifier_type = PatientIdentifierType.find_by_name(identifier_type_name) || PatientIdentifierType.find_by_name("Unknown id")
        patient.patient_identifiers.create("identifier" => identifier, "identifier_type" => identifier_type.patient_identifier_type_id)
		  } if patient_params["identifiers"]
=end
		  # This might actually be a national id, but currently we wouldn't know
		  #patient.patient_identifiers.create("identifier" => patient_params["identifier"], "identifier_type" => PatientIdentifierType.find_by_name("Unknown id")) unless params["identifier"].blank?
		end

		return person
	end

  def self.patient_defaulted_dates(patient_obj, session_date)
    #raise session_date.to_yaml
    #getting all patient's dispensations encounters
    all_dispensations = Observation.find_by_sql("SELECT obs.person_id, obs.obs_datetime AS obs_datetime, d.order_id
                            FROM drug_order d
                              LEFT JOIN orders o ON d.order_id = o.order_id
                              LEFT JOIN obs ON d.order_id = obs.order_id
                            WHERE d.drug_inventory_id IN (SELECT drug_id FROM drug
                                                          WHERE concept_id IN (SELECT concept_id
                                                                               FROM concept_set
                                                                               WHERE concept_set = 1085))
                                                          AND quantity > 0
                                                          AND obs.voided = 0
                                                          AND o.voided = 0
                                                          and obs.person_id = #{patient_obj.patient_id}
                                                          GROUP BY DATE(obs_datetime) order by obs_datetime")

    outcome_dates = []
    dates = 0
    total_dispensations = all_dispensations.length
    defaulted_dates = all_dispensations.map(&:obs_datetime)

    all_dispensations.each do |disp_date|
      d = ((dates - total_dispensations) + 1)

      prev_dispenation_date = all_dispensations[d].obs_datetime.to_date

      if d == 0
        previous_date = session_date
        defaulted_state = ActiveRecord::Base.connection.select_value "
        SELECT current_defaulter(#{disp_date.person_id},'#{previous_date}')"

        if defaulted_state.to_i == 1
          defaulted_date = ActiveRecord::Base.connection.select_value "
            SELECT current_defaulter_date(#{disp_date.person_id}, '#{previous_date}')"

          outcome_dates << defaulted_date.to_date if !defaulted_dates.include?(defaulted_date.to_date)
        end
      else
        previous_date = prev_dispenation_date.to_date

        defaulted_state = ActiveRecord::Base.connection.select_value "
        SELECT current_defaulter(#{disp_date.person_id},'#{previous_date}')"

        if defaulted_state.to_i == 1
          defaulted_date = ActiveRecord::Base.connection.select_value "
            SELECT current_defaulter_date(#{disp_date.person_id}, '#{previous_date}')"

          outcome_dates << defaulted_date.to_date if !defaulted_dates.include?(defaulted_date.to_date)
        end
      end

      dates += 1
    end
    #raise outcome_dates.to_yaml
    return outcome_dates
  end

  # Get the any BMI-related alert for this patient
  def self.current_bmi_alert(patient_weight, patient_height)
    weight = patient_weight
    height = patient_height
    alert = nil
    unless weight == 0 || height == 0
      current_bmi = (weight/(height*height)*10000).round(1);
      if current_bmi <= 18.5 && current_bmi > 17.0
        alert = 'Low BMI: Eligible for counseling'
      elsif current_bmi <= 17.0
        alert = 'Low BMI: Eligible for therapeutic feeding'
      end
    end

    alert
  end

  def self.sex(person)
    value = nil
    if person.gender == "M"
      value = "Male"
    elsif person.gender == "F"
      value = "Female"
    end
    value
  end

  def self.person_search_by_identifier_and_name(params)
    people = []
    given_name = params[:name].squish.split(' ')[0]
    family_name = params[:name].squish.split(' ')[1] rescue ''
    identifier = params[:identifier]

    people = Person.find(:all, :limit => 15, :joins =>"INNER JOIN person_name USING(person_id)
     INNER JOIN patient_identifier i ON i.patient_id = person.person_id AND i.voided = 0", :conditions => [
        "identifier = ? AND \
     person_name.given_name LIKE (?) AND \
     person_name.family_name LIKE (?)",
        identifier,
        "%#{given_name}%",
        "%#{family_name}%"
      ],:limit => 10,:order => "birthdate DESC")

    if people.length < 15
      people_like = Person.find(:all, :limit => 15,
        :joins =>"INNER JOIN person_name_code ON person_name_code.person_name_id = person.person_id
      INNER JOIN patient_identifier i ON i.patient_id = person.person_id AND i.voided = 0",
        :conditions => ["identifier = ? AND \
     ((person_name_code.given_name_code LIKE ? AND \
     person_name_code.family_name_code LIKE ?))",
          identifier,
          (given_name || '').soundex,
          (family_name || '').soundex
        ], :order => "birthdate DESC")
      people = (people + people_like).uniq rescue people
    end

    return people.uniq[0..9] rescue people
  end

  def self.person_search(params)
    people = []
    people = search_by_identifier(params[:identifier]) if params[:identifier]

    return people unless people.blank? || people.size > 1

    gender = params[:gender]
    given_name = params[:given_name].squish unless params[:given_name].blank?
    family_name = params[:family_name].squish unless params[:family_name].blank?

    people = Person.find(:all, :limit => 15, :include => [{:names => [:person_name_code]}, :patient], :conditions => [
        "gender = ? AND \
     person_name.given_name = ? AND \
     person_name.family_name = ?",
        gender,
        given_name,
        family_name
      ],:limit => 10,:order => "birthdate DESC") if people.blank?

    if people.length < 15
=begin
       matching_people = people.collect{| person |
       person.person_id
        #                  }

=end

      people_like = Person.find(:all, :limit => 15, :include => [{:names => [:person_name_code]}, :patient], :conditions => [
          "gender = ? AND \
     ((person_name_code.given_name_code LIKE ? AND \
     person_name_code.family_name_code LIKE ?))",
          gender,
          (given_name || '').soundex,
          (family_name || '').soundex
        ], :order => "person_name.given_name ASC, person_name_code.family_name_code ASC,birthdate DESC")
      people = (people + people_like).uniq rescue people
    end
=begin
    raise "done"

people = Person.find(:all, :include => [{:names => [:person_name_code]}, :patient], :conditions => [
        "gender = ? AND \
     (person_name.given_name LIKE ? OR person_name_code.given_name_code LIKE ?) AND \
     (person_name.family_name LIKE ? OR person_name_code.family_name_code LIKE ?)",
        params[:gender],
        params[:given_name],
        (params[:given_name] || '').soundex,
        params[:family_name],
        (params[:family_name] || '').soundex
      ]) if people.blank?

    raise "afta pulling"
=end
    return people.uniq[0..9] rescue people
  end

  def self.person_search_from_dde(params)
    search_string = "given_name=#{params[:given_name]}"
    search_string += "&family_name=#{params[:family_name]}"
    search_string += "&gender=#{params[:gender]}"
    uri = "http://admin:admin@http://192.168.6.183:3001/people/find.json?#{search_string}"
    JSON.parse(RestClient.get(uri)) rescue []
  end

  def self.search_by_identifier(identifier)
    unless identifier.match(/#{Location.current_health_center.neighborhood_cell}-ARV/i) || identifier.match(/-TB/i) || identifier.match(/-HCC/i)
      identifier = identifier.gsub("-","").strip
    end

		if identifier.match(/-TB/i)
			people = PatientIdentifier.find_by_sql("SELECT * FROM patient_identifier
                WHERE REPLACE(identifier, ' ', '') = REPLACE('#{identifier}', ' ', '') AND voided =0 ").map{|id|
        id.patient.person
      }
		else
			people = PatientIdentifier.find_all_by_identifier(identifier).map{|id|
        id.patient.person
      } unless identifier.blank? rescue nil
		end

    return people unless people.blank?
    create_from_dde_server = CoreService.get_global_property_value('create.from.dde.server').to_s == "true" rescue false
    if create_from_dde_server
      dde_server = GlobalProperty.find_by_property("dde_server_ip").property_value rescue ""
      dde_server_username = GlobalProperty.find_by_property("dde_server_username").property_value rescue ""
      dde_server_password = GlobalProperty.find_by_property("dde_server_password").property_value rescue ""
      uri = "http://#{dde_server_username}:#{dde_server_password}@#{dde_server}/people/find.json"
      uri += "?value=#{identifier}"
      p = JSON.parse(RestClient.get(uri)) rescue nil
      return [] if p.blank?
      return "found duplicate identifiers" if p.count > 1
      p = p.first
      passed_national_id = (p["person"]["patient"]["identifiers"]["National id"]) rescue nil
      passed_national_id = (p["person"]["value"]) if passed_national_id.blank? rescue nil
      if passed_national_id.blank?
        return [DDEService.get_remote_person(p["person"]["id"])]
      end

      birthdate_year = p["person"]["birthdate"].to_date.year rescue "Unknown"
      birthdate_month = p["person"]["birthdate"].to_date.month rescue nil
      birthdate_day = p["person"]["birthdate"].to_date.day rescue nil
      birthdate_estimated = p["person"]["birthdate_estimated"]
      gender = p["person"]["gender"] == "F" ? "Female" : "Male"

      passed = {
        "person"=>{"occupation"=>p["person"]["data"]["attributes"]["occupation"],
          "age_estimate"=> birthdate_estimated,
          "cell_phone_number"=>p["person"]["data"]["attributes"]["cell_phone_number"],
          "birth_month"=> birthdate_month ,
          "addresses"=>{"address1"=>p["person"]["data"]["addresses"]["address1"],
            "address2"=>p["person"]["data"]["addresses"]["address2"],
            "city_village"=>p["person"]["data"]["addresses"]["city_village"],
            "state_province"=>p["person"]["data"]["addresses"]["state_province"],
            "neighborhood_cell"=>p["person"]["data"]["addresses"]["neighborhood_cell"],
            "county_district"=>p["person"]["data"]["addresses"]["county_district"]},
          "gender"=> gender ,
          "patient"=>{"identifiers"=>{"National id" => p["person"]["value"]}},
          "birth_day"=>birthdate_day,
          "home_phone_number"=>p["person"]["data"]["attributes"]["home_phone_number"],
          "names"=>{"family_name"=>p["person"]["data"]["names"]["family_name"],
            "given_name"=>p["person"]["data"]["names"]["given_name"],
            "middle_name"=>""},
          "birth_year"=>birthdate_year},
        "filter_district"=>"",
        "filter"=>{"region"=>"",
          "t_a"=>""},
        "relation"=>""
      }

      unless passed_national_id.blank?
        patient = PatientIdentifier.find(:first,
          :conditions =>["voided = 0 AND identifier = ?",passed_national_id]).patient rescue nil
        return [patient.person] unless patient.blank?
      end

      passed["person"].merge!("identifiers" => {"National id" => passed_national_id})
      return [self.create_from_form(passed["person"])]
    end
    return people
  end

  def self.set_birthdate_by_age(person, age, today = Date.today)
    person.birthdate = Date.new(today.year - age.to_i, 7, 1)
    person.birthdate_estimated = 1
  end

  def self.set_birthdate(person, year = nil, month = nil, day = nil)
    raise "No year passed for estimated birthdate" if year.nil?

    # Handle months by name or number (split this out to a date method)
    month_i = (month || 0).to_i
    month_i = Date::MONTHNAMES.index(month) if month_i == 0 || month_i.blank?
    month_i = Date::ABBR_MONTHNAMES.index(month) if month_i == 0 || month_i.blank?

    if month_i == 0 || month == "Unknown"
      person.birthdate = Date.new(year.to_i,7,1)
      person.birthdate_estimated = 1
    elsif day.blank? || day == "Unknown" || day == 0
      person.birthdate = Date.new(year.to_i,month_i,15)
      person.birthdate_estimated = 1
    else
      person.birthdate = Date.new(year.to_i,month_i,day.to_i)
      person.birthdate_estimated = 0
    end
  end

  def self.birthdate_formatted(person)
    if person.birthdate_estimated==1
      if person.birthdate.nil?
				return '00/00/0000'
      else
		    if person.birthdate.day == 1 and person.birthdate.month == 7
		      person.birthdate.strftime("??/???/%Y")
		    elsif person.birthdate.day == 15
		      person.birthdate.strftime("??/%b/%Y")
		    elsif person.birthdate.day == 1 and person.birthdate.month == 1
		      person.birthdate.strftime("??/???/%Y")
		    else
		      person.birthdate.strftime("%d/%b/%Y") unless person.birthdate.blank? rescue " "
		    end
      end
    else
      if !person.birthdate.blank?
        person.birthdate.strftime("%d/%b/%Y")
      else
        return '00/00/0000'
      end
    end
  end

  def self.age_in_months(person, today = Date.today)
    if !person.birthdate.blank?
      years = (today.year - person.birthdate.year)
      months = (today.month - person.birthdate.month)
      (years * 12) + months
    else
      return 0
    end
  end

  def self.period_on_treatment(start_date, today = Date.today)
    years = (today.year - start_date.year)
    months = (today.month - start_date.month)
    (years * 12) + months
  end

  def self.date_started_second_line_regimen(patient)
    regimen_category = Concept.find_by_name("Regimen Category")
    regimen_indices = ["7A","8A","9P"]
    regimen_indices = "'" + regimen_indices.join("','") + "'"
    encounter_datetime = Observation.find_by_sql("SELECT * FROM obs o INNER JOIN encounter enc ON
      o.encounter_id= enc.encounter_id AND
      enc.encounter_type= (SELECT encounter_type_id FROM encounter_type WHERE
      name='DISPENSING') AND o.concept_id=#{regimen_category.id} AND enc.patient_id=#{patient.id} AND
      value_text IN (#{regimen_indices}) AND enc.voided = 0
      order by enc.date_created ASC LIMIT 1").first.encounter_datetime rescue ""
    if (encounter_datetime.blank? || encounter_datetime == "")
      encounter_datetime = Observation.find_by_sql("SELECT * FROM obs o INNER JOIN encounter enc ON
      o.encounter_id= enc.encounter_id AND
      enc.encounter_type= (SELECT encounter_type_id FROM encounter_type WHERE
      name='TREATMENT') AND o.concept_id=#{regimen_category.id} AND enc.patient_id=#{patient.id} AND
      value_text IN (#{regimen_indices}) AND enc.voided = 0
      order by enc.date_created ASC LIMIT 1").first.encounter_datetime rescue ""
    end
    return encounter_datetime.to_date rescue nil
  end

  def self.get_attribute(person, attribute)
    PersonAttribute.find(:first,:conditions =>["voided = 0 AND person_attribute_type_id = ? AND person_id = ?",
        PersonAttributeType.find_by_name(attribute).id, person.id]).value rescue nil
  end

  def self.is_transfer_in(patient)
    patient_transfer_in = patient.person.observations.recent(1).question("HAS TRANSFER LETTER").all rescue nil
    return false if patient_transfer_in.blank?
    return true
  end

  def self.next_lab_encounter(patient , encounter = nil , session_date = Date.today)
    if encounter.blank?
      type = EncounterType.find_by_name('LAB ORDERS').id
      lab_order = Encounter.find(:first,
        :order => "encounter_datetime DESC,date_created DESC",
        :conditions =>["patient_id = ? AND encounter_type = ?",patient.id,type])
      return 'NO LAB ORDERS' if lab_order.blank?
      return
    end

    case encounter.name.upcase
    when 'LAB ORDERS'
      type = EncounterType.find_by_name('SPUTUM SUBMISSION').id
      sputum_sub = Encounter.find(:first,:joins => "INNER JOIN obs USING(encounter_id)",
        :conditions =>["obs.accession_number IN (?) AND patient_id = ? AND encounter_type = ?",
          encounter.observations.map{|r|r.accession_number}.compact,encounter.patient_id,type])

      return type if sputum_sub.blank?
      return sputum_sub
    when 'SPUTUM SUBMISSION'
      type = EncounterType.find_by_name('LAB RESULTS').id
      lab_results = Encounter.find(:first,:joins => "INNER JOIN obs USING(encounter_id)",
        :conditions =>["obs.accession_number IN (?) AND patient_id = ? AND encounter_type = ?",
          encounter.observations.map{|r|r.accession_number}.compact,encounter.patient_id,type])

      type = EncounterType.find_by_name('LAB ORDERS').id
      lab_order = Encounter.find(:first,:joins => "INNER JOIN obs USING(encounter_id)",
        :conditions =>["obs.accession_number IN (?) AND patient_id = ? AND encounter_type = ?",
          encounter.observations.map{|r|r.accession_number}.compact,encounter.patient_id,type])

      return lab_order if lab_results.blank? and not lab_order.blank?
      return if lab_results.blank?
      return lab_results
    when 'LAB RESULTS'
      type = EncounterType.find_by_name('SPUTUM SUBMISSION').id
      sputum_sub = Encounter.find(:first,:joins => "INNER JOIN obs USING(encounter_id)",
        :conditions =>["obs.accession_number IN (?) AND patient_id = ? AND encounter_type = ?",
          encounter.observations.map{|r|r.accession_number}.compact,encounter.patient_id,type])

      return if sputum_sub.blank?
      return sputum_sub
    end
  end

  def self.checks_if_vitals_are_need(patient , session_date, task , user_selected_activities)

    #..............................................................................
    if self.current_program_location == 'TB program'
      reception = Encounter.find(:first,:conditions =>["patient_id = ? AND
        DATE(encounter_datetime) = ? AND encounter_type = ?",patient.id,session_date,
          EncounterType.find_by_name('TB RECEPTION').id]).observations.collect{| r | r.to_s}.join(',') rescue ''
    else
      reception = Encounter.find(:first,:conditions =>["patient_id = ? AND
        DATE(encounter_datetime) = ? AND encounter_type = ?",patient.id,session_date,
          EncounterType.find_by_name('HIV RECEPTION').id]).observations.collect{| r | r.to_s}.join(',') rescue ''
    end

    if reception.match(/PATIENT PRESENT FOR CONSULTATION:  NO/i)
      return nil
    end
    #..............................................................................


    first_vitals = Encounter.find(:first,:order => "encounter_datetime DESC",
      :conditions =>["patient_id = ? AND encounter_type = ?",
        patient.id,EncounterType.find_by_name('VITALS').id])


    if first_vitals.blank?
      encounter = Encounter.find(:first,:order => "encounter_datetime DESC",
        :conditions =>["patient_id = ? AND encounter_type = ?",patient.id,
          EncounterType.find_by_name('LAB ORDERS').id])

      sup_result = self.next_lab_encounter(patient , encounter, session_date)

      reception = Encounter.find(:first,:order => "encounter_datetime DESC",
        :conditions =>["encounter_datetime BETWEEN ? AND ? AND patient_id = ? AND encounter_type = ?",
          session_date.to_date.strftime('%Y-%m-%d 00:00:00'),
          session_date.to_date.strftime('%Y-%m-%d 23:59:59'),
          patient.id,
          EncounterType.find_by_name('TB RECEPTION').id])

      if reception.blank? and not sup_result.blank?
        if user_selected_activities.match(/Manage TB Reception Visits/i)
          task.encounter_type = 'TB RECEPTION'
          task.url = "/encounters/new/tb_reception?show&patient_id=#{patient.id}"
          return task
        elsif not user_selected_activities.match(/Manage TB Reception Visits/i)
          task.encounter_type = 'TB RECEPTION'
          task.url = "/patients/show/#{patient.id}"
          return task
        end
      end if not (sup_result == 'NO LAB ORDERS')
    end

    if first_vitals.blank? and user_selected_activities.match(/Manage Vitals/i)
      task.encounter_type = 'VITALS'
      task.url = "/encounters/new/vitals?patient_id=#{patient.id}"
      return task
    elsif first_vitals.blank? and not user_selected_activities.match(/Manage Vitals/i)
      task.encounter_type = 'VITALS'
      task.url = "/patients/show/#{patient.id}"
      return task
    end

    return if self.patient_tb_status(patient).match(/treatment/i) and not self.patient_hiv_status(patient).match(/Positive/i)

    vitals = Encounter.find(:first,:order => "encounter_datetime DESC",
      :conditions =>["encounter_datetime BETWEEN ? AND ? AND patient_id = ? AND encounter_type = ?",
        session_date.to_date.strftime('%Y-%m-%d 00:00:00'),
        session_date.to_date.strftime('%Y-%m-%d 23:59:59'),
        patient.id,
        EncounterType.find_by_name('VITALS').id])

    if vitals.blank? and user_selected_activities.match(/Manage Vitals/i)
      task.encounter_type = 'VITALS'
      task.url = "/encounters/new/vitals?patient_id=#{patient.id}"
      return task
    elsif vitals.blank? and not user_selected_activities.match(/Manage Vitals/i)
      task.encounter_type = 'VITALS'
      task.url = "/patients/show/#{patient.id}"
      return task
    end
  end

  def self.need_art_enrollment(task,patient,location,session_date,user_selected_activities,reason_for_art)
    return unless self.patient_hiv_status(patient).match(/Positive/i)

    enrolled_in_hiv_program = Concept.find(Observation.find(:first,
        :order => "obs_datetime DESC,date_created DESC",
        :conditions => ["person_id = ? AND concept_id = ?",patient.id,
          ConceptName.find_by_name("Patient enrolled in IMB HIV program").concept_id]).value_coded).concept_names.map{|c|c.name}[0].upcase rescue nil

    return unless enrolled_in_hiv_program == 'YES'

    #return if not reason_for_art.upcase == 'UNKNOWN' and not reason_for_art.blank?

    art_initial = Encounter.find(:first,:conditions =>["patient_id = ? AND encounter_type = ?",
        patient.id,EncounterType.find_by_name('ART_INITIAL').id],
      :order =>'encounter_datetime DESC,date_created DESC',:limit => 1)

    if art_initial.blank? and user_selected_activities.match(/Manage HIV first visits/i)
      task.encounter_type = 'ART_INITIAL'
      task.url = "/encounters/new/art_initial?show&patient_id=#{patient.id}"
      return task
    elsif art_initial.blank? and not user_selected_activities.match(/Manage HIV first visits/i)
      task.encounter_type = 'ART_INITIAL'
      task.url = "/patients/show/#{patient.id}"
      return task
    end

    hiv_staging = Encounter.find(:first,:order => "encounter_datetime DESC",
      :conditions =>["patient_id = ? AND encounter_type = ?",
        patient.id,EncounterType.find_by_name('HIV STAGING').id])

    if hiv_staging.blank? and user_selected_activities.match(/Manage HIV staging visits/i)
      extended_staging_questions = CoreService.get_global_property_value('use.extended.staging.questions')
      extended_staging_questions = extended_staging_questions.property_value == 'yes' rescue false
      task.encounter_type = 'HIV STAGING'
      task.url = "/encounters/new/hiv_staging?show&patient_id=#{patient.id}" if not extended_staging_questions
      task.url = "/encounters/new/llh_hiv_staging?show&patient_id=#{patient.id}" if extended_staging_questions
      return task
    elsif hiv_staging.blank? and not user_selected_activities.match(/Manage HIV staging visits/i)
      task.encounter_type = 'HIV STAGING'
      task.url = "/patients/show/#{patient.id}"
      return task
    end

    pre_art_visit = Encounter.find(:first,:order => "encounter_datetime DESC",
      :conditions =>["patient_id = ? AND encounter_type = ?",
        patient.id,EncounterType.find_by_name('PART_FOLLOWUP').id])

    if pre_art_visit.blank? and user_selected_activities.match(/Manage pre ART visits/i)
      task.encounter_type = 'Pre ART visit'
      task.url = "/encounters/new/pre_art_visit?show&patient_id=#{patient.id}"
      return task
    elsif pre_art_visit.blank? and not user_selected_activities.match(/Manage pre ART visits/i)
      task.encounter_type = 'Pre ART visit'
      task.url = "/patients/show/#{patient.id}"
      return task
    end if reason_for_art.upcase ==  'UNKNOWN' or reason_for_art.blank?


    art_visit = Encounter.find(:first,:order => "encounter_datetime DESC",
      :conditions =>["patient_id = ? AND encounter_type = ?",
        patient.id,EncounterType.find_by_name('ART VISIT').id])

    if art_visit.blank? and user_selected_activities.match(/Manage ART visits/i)
      task.encounter_type = 'ART VISIT'
      task.url = "/encounters/new/art_visit?show&patient_id=#{patient.id}"
      return task
    elsif art_visit.blank? and not user_selected_activities.match(/Manage ART visits/i)
      task.encounter_type = 'ART VISIT'
      task.url = "/patients/show/#{patient.id}"
      return task
    end

    treatment_encounter = Encounter.find(:first,:order => "encounter_datetime DESC",
      :joins =>"INNER JOIN obs USING(encounter_id)",
      :conditions =>["patient_id = ? AND encounter_type = ? AND concept_id = ?",
        patient.id,EncounterType.find_by_name('TREATMENT').id,ConceptName.find_by_name('ARV regimen type').concept_id])

    prescribe_drugs = art_visit.observations.map{|obs| obs.to_s.squish.strip.upcase }.include? 'Prescribe arvs this visit: Yes'.upcase rescue false

    if not prescribe_drugs
      prescribe_drugs = pre_art_visit.observations.map{|obs| obs.to_s.squish.strip.upcase }.include? 'Prescribe drugs: Yes'.upcase rescue false
    end

    if treatment_encounter.blank? and user_selected_activities.match(/Manage prescriptions/i)
      task.encounter_type = 'TREATMENT'
      task.url = "/regimens/new?patient_id=#{patient.id}"
      return task
    elsif treatment_encounter.blank? and not user_selected_activities.match(/Manage prescriptions/i)
      task.encounter_type = 'TREATMENT'
      task.url = "/patients/show/#{patient.id}"
      return task
    end if prescribe_drugs
  end

  def self.get_national_id(patient, force = true)
    id = patient.patient_identifiers.find_by_identifier_type(PatientIdentifierType.find_by_name("National id").id).identifier rescue nil
    return id unless force
    id ||= PatientIdentifierType.find_by_name("National id").next_identifier(:patient => patient).identifier rescue nil
    id
  end

  def self.get_remote_national_id(patient)
    id = patient.patient_identifiers.find_by_identifier_type(PatientIdentifierType.find_by_name("National id").id).identifier rescue nil
    return id unless id.blank?
    PatientIdentifierType.find_by_name("National id").next_identifier(:patient => patient).identifier rescue nil
  end

  def self.get_national_id_with_dashes(patient, force = true)
    id = self.get_national_id(patient, force)
    length = id.length
    case length
    when 13
      id[0..4] + "-" + id[5..8] + "-" + id[9..-1] rescue id
    when 9
      id[0..2] + "-" + id[3..6] + "-" + id[7..-1] rescue id
    when 6
      id[0..2] + "-" + id[3..-1] rescue id
    else
      id
    end
  end

  # Move orders, observations and encounters to new patient and
  # void names, addresses, attributes and identifiers of the old patient
  def self.merge_patients(old_patient, new_patient)
    old_patient.orders.each do |o|
      o.patient = new_patient
      o.save
    end

    old_patient.person.observations.each do |obs|
      obs.person_id = new_patient.person.person_id
      obs.save
    end

    old_patient.encounters.each do |o|
      o.patient = new_patient
      o.save
    end

    void_reason = "Patient merged with #{new_patient.patient_id}"
    old_patient.person.addresses.each { |pa|           pa.void(void_reason) }
    old_patient.person.names.each { |pn|               pn.void(void_reason) }
    old_patient.person.person_attributes.each { |pa|   pa.void(void_reason) }
    old_patient.patient_identifiers.each { |pi|        pi.void(void_reason) }
    old_patient.patient_programs.each { |pp|           pp.void(void_reason) }
  end
=begin
  def self.date_antiretrovirals_started(patient)

    concept_id = ConceptName.find_by_name('Date antiretrovirals started').concept_id
		start_date = Observation.find(:all, :conditions => ["concept_id = ? and person_id = ?", concept_id, patient.id]).first.value_text rescue ""
		#raise start_date.to_yaml
		if start_date.blank? || start_date == ""
    start_date = ActiveRecord::Base.connection.select_value "
      SELECT earliest_start_date FROM earliest_start_date
      WHERE patient_id = #{patient.id} LIMIT 1"
    art_start_date = start_date
    #raise art_start_date.to_s
      if art_start_date.blank?
        raise "hdhdh".inspect
        concept_id = ConceptName.find_by_name('ART START DATE').concept_id
        start_date = Observation.find(:all, :conditions => ["concept_id = ? AND
        person_id = ?", concept_id, patient.id], :order => "obs_datetime DESC").first.value_datetime rescue ""
      end
		end
    start_date.to_date rescue nil
  end
=end

  def self.date_antiretrovirals_started(patient)
    concept_id = ConceptName.find_by_name('ART START DATE').concept_id
    start_date = Observation.find(:first, :conditions => ["concept_id = ? AND
    person_id = ?", concept_id, patient.id]).value_datetime rescue ""

    if start_date.blank? || start_date == ""
      concept_id = ConceptName.find_by_name('Date antiretrovirals started').concept_id
      start_date = Observation.find(:first, :conditions => ["concept_id = ? AND
      person_id = ?", concept_id, patient.id]).value_text rescue ""
      art_start_date = start_date
      if art_start_date.blank? || art_start_date == ""
        start_date = ActiveRecord::Base.connection.select_value "
        SELECT earliest_start_date_at_clinic(#{patient.id});"
      end
    end

    start_date.to_date rescue nil
  end

  def self.date_dispensation_date_after(patient, date_after)
    arv_concept = ConceptName.find_by_name("ANTIRETROVIRAL DRUGS").concept_id
    start_date = ActiveRecord::Base.connection.select_value "
    SELECT DATE(obs.obs_datetime) AS obs_datetime
    FROM drug_order d
        LEFT JOIN orders o ON d.order_id = o.order_id
        LEFT JOIN obs ON d.order_id = obs.order_id
    WHERE d.drug_inventory_id IN (SELECT drug_id FROM drug WHERE concept_id IN (SELECT concept_id FROM concept_set WHERE concept_set = #{arv_concept}))
        AND quantity > 0
        AND obs.voided = 0
        AND o.voided = 0
        AND obs.person_id = #{patient.id}
        AND DATE(obs.obs_datetime) > DATE(#{date_after})
    ORDER BY obs.obs_datetime ASC
    LIMIT 1
    "
    start_date.to_date rescue nil

  end

  def self.date_of_first_dispensation(patient)

    arv_concept = ConceptName.find_by_name("ANTIRETROVIRAL DRUGS").concept_id

    start_date = ActiveRecord::Base.connection.select_value "
    SELECT DATE(obs.obs_datetime) AS obs_datetime
    FROM drug_order d
        LEFT JOIN orders o ON d.order_id = o.order_id
        LEFT JOIN obs ON d.order_id = obs.order_id
    WHERE d.drug_inventory_id IN (SELECT drug_id FROM drug WHERE concept_id IN (SELECT concept_id FROM concept_set WHERE concept_set = #{arv_concept}))
        AND quantity > 0
        AND obs.voided = 0
        AND o.voided = 0
        AND obs.person_id = #{patient.id}
    ORDER BY obs.obs_datetime ASC
    LIMIT 1
    "
    start_date.to_date rescue nil

  end

  def self.previous_referral_section(person_obj,session_date)

    services = Observation.find(:all, :conditions => ["person_id = ? AND concept_id = ?", person_obj.id, ConceptName.find_by_name("SERVICES").concept_id], :order => "obs_datetime desc").uniq.reverse.first(5) rescue []

		previous_services = []
		services.map do |service|
			if service.obs_datetime.to_date < session_date
				previous_services << service
			end
		end
		return previous_services
  end

  def self.occupations
    ['','Driver','Housewife','Messenger','Business','Farmer','Salesperson','Teacher',
      'Student','Security guard','Domestic worker', 'Police','Office worker',
      'Preschool child','Mechanic','Prisoner','Craftsman','Healthcare Worker','Soldier'].sort.concat(["Other","Unknown"])
  end

  def self.tb_drug_given_before(patient, date = Date.today)
    clinic_encounters =  [
      'SOURCE OF REFERRAL','UPDATE HIV STATUS','LAB ORDERS',
      'SPUTUM SUBMISSION','LAB RESULTS','TB_INITIAL',
      'TB RECEPTION','TB REGISTRATION','TB VISIT',
      'TB ADHERENCE','TB CLINIC VISIT','DISPENSING'
    ]

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
      !MedicationService.tb_medication(order.drug_order.drug)
    end
  end

  def self.earliest_start_date_patient_data(patient_id)
    record = ActiveRecord::Base.connection.select_all("
    select
        `p`.`patient_id` AS `patient_id`,
        cast(patient_start_date(`p`.`patient_id`) as date) AS `date_enrolled`,
        date_antiretrovirals_started(`p`.`patient_id`, min(`s`.`start_date`)) AS `earliest_start_date`,
        `person`.`death_date` AS `death_date`, `person`.`birthdate`,
         TIMESTAMPDIFF(YEAR,`person`.`birthdate`,  min(`s`.`start_date`)) AS `age_at_initiation`,
         TIMESTAMPDIFF(DAY,`person`.`birthdate`,  min(`s`.`start_date`)) AS `age_in_days`
    from
        ((`patient_program` `p`
        left join `patient_state` `s` ON ((`p`.`patient_program_id` = `s`.`patient_program_id`)))
        left join `person` ON ((`person`.`person_id` = `p`.`patient_id`)))
    where
        (
          (`p`.`voided` = 0)
          and (`s`.`voided` = 0)
          and (`p`.`program_id` = 1)
          and (`s`.`state` = 7)
          and `p`.`patient_id` = #{patient_id}
        )
    group by `p`.`patient_id`").collect do |p|
      {
        :birthdate => (p['birthdate'].to_date rescue nil),
        :date_enrolled => (p['date_enrolled'].to_date rescue nil),
        :earliest_start_date => (p['earliest_start_date'].to_date rescue nil),
        :death_date => (p['death_date'].to_date rescue nil),
        :age_at_initiation => (p['age_at_initiation'].to_i rescue nil),
        :age_in_days => (p['age_in_days'].to_i rescue nil)
      }
    end

    return record.first rescue nil
  end

  def self.appointment_type(patient, session_date)
    appointment_type_id = ConceptName.find_by_name('Appointment type').concept_id

    Observation.find(:first, :conditions => ["concept_id = ? AND person_id = ?
      AND obs_datetime BETWEEN ? AND ?", appointment_type_id, patient.id,
        session_date.strftime('%Y-%m-%d 00:00:00'),
        session_date.strftime('%Y-%m-%d 23:59:59')])
  end

  def self.patient_initiated(patient_id, session_date)
    ans = ActiveRecord::Base.connection.select_value <<EOF
      SELECT re_initiated_check(#{patient_id}, '#{session_date.to_date}');
EOF
  
    return ans if ans == 'Re-initiated'
    end_date = session_date.strftime('%Y-%m-%d 23:59:59') 
    concept_id = ConceptName.find_by_name('Amount dispensed').concept_id
  
   

    hiv_clinic_registration = Encounter.find(:last,:conditions =>["encounter_type = ? AND 
      patient_id = ? AND (encounter_datetime BETWEEN ? AND ?)",
        EncounterType.find_by_name("HIV CLINIC REGISTRATION").id, patient_id,
        end_date.to_date.strftime('%Y-%m-%d 00:00:00'), end_date])

    (hiv_clinic_registration.observations || []).map do | obs |
      concept_name = obs.to_s.split(':')[0].strip rescue nil
      next if concept_name.blank?
      case concept_name
      when 'Date ART last taken'
        last_art_drugs_date_taken = obs.value_datetime.to_date rescue nil
        unless last_art_drugs_date_taken.blank?
          days = ActiveRecord::Base.connection.select_value <<EOF
            SELECT timestampdiff(day, '#{last_art_drugs_date_taken.to_date}', '#{session_date.to_date}') AS days;
EOF

          return 'Re-initiated' if days.to_i > 14
          return 'Continuing' if days.to_i <= 14
        end
      end
    end unless hiv_clinic_registration.blank?
 
  
   
    dispensed_arvs = Observation.find(:all, :conditions =>["person_id = ? 
      AND concept_id = ? AND obs_datetime <= ?", patient_id, concept_id, end_date]).map(&:value_drug)

    return 'Initiation' if dispensed_arvs.blank?
    arv_drug_concepts = MedicationService.arv_drugs.map(&:concept_id) 
    arvs_found = ActiveRecord::Base.connection.select_all <<EOF
      SELECT * FROM drug WHERE concept_id IN(#{arv_drug_concepts.join(',')})
      AND drug_id IN(#{dispensed_arvs.join(',')});
EOF

    return arvs_found.blank? == true ? 'Initiation' : 'Continuing'
  end

  private

  def self.current_program_location
    current_user_activities = User.current.activities
    if Location.current_location.name.downcase == 'outpatient'
      return "OPD"
    elsif current_user_activities.include?('Manage Lab Orders') or current_user_activities.include?('Manage Lab Results') or
        current_user_activities.include?('Manage Sputum Submissions') or current_user_activities.include?('Manage TB Clinic Visits') or
        current_user_activities.include?('Manage TB Reception Visits') or current_user_activities.include?('Manage TB Registration Visits') or
        current_user_activities.include?('Manage HIV Status Visits')
      return 'TB program'
    else #if current_user_activities
      return 'HIV program'
    end
  end

end