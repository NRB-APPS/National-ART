class PeopleController < GenericPeopleController
  def create_person_from_anc
    ActiveRecord::Base.transaction do
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
          :birthdate_estimated => birthdate_estimated,
          :creator => 1
        })

      person.names.create({
          :given_name => params["person"]["names"]["given_name"],
          :family_name => params["person"]["names"]["family_name"],
          :family_name2 => params["person"]["names"]["family_name2"],
          :creator => 1
        })

      person.addresses.create({
          :address1 => params["person"]["addresses"]["address1"],
          :address2 => params["person"]["addresses"]["address2"],
          :city_village => params["person"]["addresses"]["city_village"],
          :county_district => params["person"]["addresses"]["county_district"],
          :creator => 1
        })

      person.person_attributes.create(
        :person_attribute_type_id => PersonAttributeType.find_by_name("Occupation").person_attribute_type_id,
        :value => params["person"]["attributes"]["occupation"],
        :creator => 1) unless params["person"]["attributes"]["occupation"].blank?

      person.person_attributes.create(
        :person_attribute_type_id => PersonAttributeType.find_by_name("Cell Phone Number").person_attribute_type_id,
        :value => params["person"]["attributes"]["cell_phone_number"],
        :creator => 1) unless params["person"]["attributes"]["cell_phone_number"].blank?

      person.person_attributes.create(
        :person_attribute_type_id => PersonAttributeType.find_by_name("Office Phone Number").person_attribute_type_id,
        :value => params["person"]["attributes"]["office_phone_number"],
        :creator => 1) unless params["person"]["attributes"]["office_phone_number"].blank?

      person.person_attributes.create(
        :person_attribute_type_id => PersonAttributeType.find_by_name("Home Phone Number").person_attribute_type_id,
        :value => params["person"]["attributes"]["home_phone_number"],
        :creator => 1) unless params["person"]["attributes"]["home_phone_number"].blank?

      patient = person.create_patient({:creator => 1})
      patient.patient_identifiers.create({
          :identifier => params["patient"]["identifiers"]["National id"],
          :identifier_type => PatientIdentifierType.find_by_name("NATIONAL ID").patient_identifier_type_id,
          :creator => 1
        })
    end
    render :text => "true" and return
  end

  def create_person_from_dmht
    User.current = User.first

    if create_from_dde_server
      national_id = DDEService.create_patient_from_dde(params, true)
      params["person"]["identifiers"] = {"national id" => national_id}
      PatientService.create_from_form(params["person"])
    else
      health_center_id = Location.current_health_center.location_id.to_s
      national_id_version = "1"
      national_id_prefix = "P#{national_id_version}#{health_center_id.rjust(3,"0")}"

      last_national_id = PatientIdentifier.find(:first,:order=>"identifier desc", :conditions => ["identifier_type = ? AND left(identifier,5)= ?", 
          PatientIdentifierType.find_by_name("NATIONAL ID").patient_identifier_type_id, national_id_prefix]
      )
      
      last_national_id_number = last_national_id.identifier rescue "0"

      next_number = (last_national_id_number[5..-2].to_i+1).to_s.rjust(7,"0")
      new_national_id_no_check_digit = "#{national_id_prefix}#{next_number}"
      check_digit = PatientIdentifier.calculate_checkdigit(new_national_id_no_check_digit[1..-1])
      national_id = "#{new_national_id_no_check_digit}#{check_digit}"

      params["person"]["identifiers"] = {"national id" => "#{national_id}"}
      PatientService.create_from_form(params["person"])
    end

    render :text => national_id and return
  end

  def find_person_from_dmht
    people = PatientService.search_by_identifier(params["identifier"])
    demographics = []
    
    if (people.length == 1)
      patient_demographics = PatientService.demographics(people.first)
      patient_demographics["person"]["attributes"].delete_if{|k, v|v.blank?}
      demographics << patient_demographics
    elsif (people.length > 1)
      people.each do |person|
        patient_demographics = PatientService.demographics(person)
        patient_demographics["person"]["attributes"].delete_if{|k, v|v.blank?}
        demographics << patient_demographics
      end
    end

    render :json => demographics and return
  end

  def reassign_remote_identifier
    User.current = User.first
    Location.current_location = Location.current_health_center
    
    person = Person.find(:first,:joins => "INNER JOIN patient_identifier i
      ON i.patient_id = person.person_id AND i.voided = 0 AND person.voided=0
      INNER JOIN person_name n ON n.person_id=person.person_id AND n.voided = 0",
      :conditions => ["identifier = ? AND n.given_name = ? AND n.family_name = ? AND gender = ?",
        params[:national_id],params[:given_name],params[:family_name],params[:gender]])
    patient = person.patient
    
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
           AND voided = 0", patient.id,params[:national_id]])
    npid.voided = 1
    npid.void_reason = "Given another national ID"
    npid.date_voided = Time.now()
    npid.voided_by = 1
    npid.save

    patient_demographics = PatientService.demographics(person)
    patient_demographics["person"]["attributes"].delete_if{|k, v|v.blank?}
    
    render :json => patient_demographics and return

  end

  def dde_duplicates
    @dde_duplicates = {}
    session[:duplicate_npid] = params[:npid]
    dde_search_results = PatientService.search_dde_by_identifier(params[:npid], session[:dde_token])
    dde_hits = dde_search_results["data"]["hits"] rescue []
    i = 1
    
    dde_hits.each do |dde_hit|
      @dde_duplicates[i] = {}
      @dde_duplicates[i]["first_name"] = dde_hit["names"]["given_name"]
      @dde_duplicates[i]["family_name"] = dde_hit["names"]["family_name"]
      @dde_duplicates[i]["gender"] = dde_hit["gender"]
      @dde_duplicates[i]["birthdate"] = dde_hit["birthdate"]
      @dde_duplicates[i]["npid"] = dde_hit["_id"]
      @dde_duplicates[i]["current_village"] = dde_hit["addresses"]["current_village"]
      @dde_duplicates[i]["home_village"] = dde_hit["addresses"]["home_village"]
      @dde_duplicates[i]["current_residence"] = dde_hit["addresses"]["current_residence"]
      @dde_duplicates[i]["home_district"] = dde_hit["addresses"]["home_district"]
      i = i + 1;
    end

    render :layout => 'menu'
  end

  def search_person
    people = PatientService.person_search(params)
    @html = ''
    @lims_npid = params['identifier'];
    @tracking_number = params['tracking_number'];
    people.each do |person|
      patient = person.patient
      next if patient.blank?
      next if person.addresses.blank?
      bean = PatientService.get_patient(patient.person)
      date_of_birth = person.birthdate.strftime('%d/%b/%Y') rescue nil
      person = {:name => bean.name,
                :gender => person.gender,
                :birthdate => date_of_birth,
                :age => person.age,
                :home_address => bean.traditional_authority,
                :home_district => bean.home_district,
                :residence => bean.current_residence,
                :national_id => bean.national_id,
                :lims_npid => @lims_npid,
                :tracking_number => @tracking_number}
      @html+= <<EOF
        <li onclick='viewPatient(#{person.to_json})'>#{bean.name.upcase || '&nbsp;'}</li>
EOF
    end

    render :text => (people.blank? ? "<span id='no_results'>No results found!</span>" : @html)
  end

end
 
