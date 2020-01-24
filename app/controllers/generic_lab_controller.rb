class GenericLabController < ApplicationController
  def results
    @results = []
    @patient = Patient.find(params[:id])
    patient_ids = id_identifiers(@patient)
    @patient_bean = PatientService.get_patient(@patient.person)
    (Lab.results(@patient, patient_ids) || []).map do | short_name , test_name , range , value , test_date |
      @results << [short_name.gsub('_',' '),"/lab/view?test=#{short_name}&patient_id=#{@patient.id}"]
    end

    @lims_activated = YAML.load_file("#{Rails.root}/config/lims.yml")[Rails.env]['enable_lims'] rescue false
    @enter_lab_results = GlobalProperty.find_by_property('enter.lab.results').property_value == 'true' rescue false
    render :layout => 'menu'
  end

  def view
    @patient = Patient.find(params[:patient_id])
    @patient_bean = PatientService.get_patient(@patient.person)
    @test = params[:test]
    patient_ids = id_identifiers(@patient)
    @results = Lab.results_by_type(@patient, @test, patient_ids)

    @all = {}
    (@results || []).map do |key,values|
      date = key.split("::")[0].to_date rescue "1900-01-01".to_date
      name = key.split("::")[1].strip
      value = values["TestValue"]
      next if date == "1900-01-01".to_date and value.blank?
      next if ((Date.today - 2.year) > date)
      @all[name] = [] if @all[name].blank?
      @all[name] << [date,value]
      @all[name] = @all[name].sort
    end

    @table_th = build_table(@results) unless @results.blank?
    render :layout => 'menu'
  end

  def build_table(results)
    available_dates = Array.new()
    available_test_types = Array.new()
    html_tag = Array.new()
    html_tag_to_display = nil

    results.each do | key , values |
      date = key.split("::")[0].to_date rescue 'Unknown'
      available_dates << date
      available_test_types << key.split("::")[1]
    end

    available_dates = available_dates.compact.uniq.sort.reverse rescue []
    available_test_types = available_test_types.compact.uniq rescue []
    return if available_dates.blank?


    #from the available test dates we create
    #the top row which holds all the lab run test date  - quick hack :)
    @table_tr = "<tr><th>&nbsp;</th>" ; count = 0
    available_dates.map do | date |
      @table_tr += "<th id='#{count+=1}'>#{date}</th>"
    end ; @table_tr += "</tr>"

    #same here - we create all the row which will hold the actual
    #lab results .. quick hack :)
    @table_tr_data = ''
    available_test_types.map do | type |
      @table_tr_data += "<tr><td><a href = '#' onmousedown=\"graph('#{type}');\">#{type.gsub('_',' ')}</a></td>"
      count = 0
      available_dates.map do | date |
        @table_tr_data += "<td id = '#{type}_#{count+=1}' id='#{date}::#{type}'></td>"
      end
      @table_tr_data += "</tr>"
    end

    results.each do | key , values |
      value = values['Range'].to_s + ' ' + values['TestValue'].to_s
      @table_tr_data = @table_tr_data.sub(" id='#{key}'>"," class=#{}>#{value}")
    end


    return (@table_tr + @table_tr_data)
  end

  def graph
    @results = []
    params[:results].split(';').map do | result |

      date = result.split(',')[0].to_date rescue '1900-01-01'
      modifier = result.split(',')[1].split(" ")[0].sub('more_than','>').sub('less_than','<')
      value = result.split(',')[1].sub('more_than','').sub('less_than','').sub('=','') rescue nil
      next if value.blank?
      value = value.to_f

      @results << [ date , value, modifier ]
    end

    @patient = Patient.find(params[:patient_id])
    @patient_bean = PatientService.get_patient(@patient.person)
    @type = params[:type]
    @test = params[:test]
    render :layout => 'menu'
  end

  def id_identifiers(patient)
    identifier_type = ["Legacy Pediatric id","National id","Legacy National id","Old Identification Number"]
    identifier_types = PatientIdentifierType.find(:all,
      :conditions=>["name IN (?)",identifier_type]
    ).collect{| type |type.id }

    identifiers = []
    PatientIdentifier.find(:all,
      :conditions=>["patient_id=? AND identifier_type IN (?)",
        patient.id,identifier_types]).each{| i | identifiers << i.identifier }

    patient_obj = PatientService.get_patient(patient.person)

    ActiveRecord::Base.connection.select_all("SELECT * FROM patient_identifier
      WHERE identifier_type IN(#{identifier_types.join(',')})
      AND voided = 1 AND patient_id = #{patient.id}
      AND void_reason LIKE '%Given new national ID: #{patient_obj.national_id}%'").collect{|r| identifiers << r['identifier']}
    return identifiers
  end

  def viral_load_result
    person_id = params[:person_id] || params[:patient_id]
    session[:hiv_viral_load_today_patient] = (params[:person_id] || params[:patient_id])
    @patient = Patient.find(person_id)
  end

  def create_viral_load_result
    person = Person.find(params[:patient_id])
    patient_bean = PatientService.get_patient(person)

    test_date_or_year = params[:test_year]
    test_month = params[:test_month]
    test_day = params[:test_day]

    test_date = test_date_or_year.to_date rescue (test_date_or_year.to_s + '-' + test_month.to_s + '-' + test_day.to_s).to_date
    date = test_date

    test_type = LabTestType.find(:first,
      :conditions =>["TestName = ?",params[:lab_result].to_s])

    test_modifier = params[:test_value].to_s.match(/=|>|</)[0]
    test_value = params[:test_value].to_s.gsub('>','').gsub('<','').gsub('=','')
    available_test_type = LabTestType.find(:all,:conditions=>["TestType IN (?)", test_type.TestType]).collect{|n|n.Panel_ID}

    lab_test_table = LabTestTable.new()
    lab_test_table.TestOrdered = LabPanel.test_name(available_test_type)[0]
    lab_test_table.Pat_ID = patient_bean.national_id
    lab_test_table.OrderDate = date
    lab_test_table.OrderTime = Time.now().strftime("%H:%M:%S")
    lab_test_table.OrderedBy = current_user.id
    lab_test_table.Location = Location.current_health_center.name
    lab_test_table.save

    lab_test_table.reload

    lab_sample = LabSample.new()
    lab_sample.AccessionNum = lab_test_table.AccessionNum
    lab_sample.USERID = current_user.id
    lab_sample.TESTDATE = date
    lab_sample.PATIENTID = patient_bean.national_id
    lab_sample.DATE = date
    lab_sample.TIME = Time.now().strftime("%H:%M:%S")
    lab_sample.SOURCE = Location.current_location.id
    lab_sample.DeleteYN = 0
    lab_sample.Attribute = "pass"
    lab_sample.TimeStamp = Time.now()
    lab_sample.save

    lab_sample.reload

    lab_parameter = LabParameter.new()
    lab_parameter.Sample_ID = lab_sample.Sample_ID
    lab_parameter.TESTTYPE =  test_type.TestType
    lab_parameter.TESTVALUE = test_value
    lab_parameter.TimeStamp = Time.now()
    lab_parameter.Range = test_modifier
    lab_parameter.save

    #create an order

    settings = YAML.load_file("#{Rails.root}/config/lims.yml")[Rails.env]
    create_url = "#{settings['national-repo-node']}/create_hl7_order"
    
    if national_lims_activated
      json = { :return_path => "http://#{request.host}:#{request.port}",
               :district => settings['district'],
               :health_facility_name => settings['facility_name'],
               :first_name=> patient_bean.name.split(/\s+/).first,
               :last_name=>  patient_bean.name.split(/\s+/).last,
               :middle_name=>"",
               :date_of_birth=> (person.birthdate rescue nil),
               :gender=> ((patient_bean.sex == "Female") ? "F" : "M"),
               :national_patient_id=> patient_bean.national_id,
               :phone_number=> (patient_bean.cell_phone_number ||
                   patient_bean.home_phone_number ||
                   patient_bean.office_phone_number),
               :reason_for_test=> '',
               :sample_collector_last_name=> '',
               :sample_collector_first_name=> '',
               :sample_collector_phone_number=> '',
               :sample_collector_id=> '',
               :sample_order_location=> Location.current_location.name,
               :sample_type=> "Blood",
               :date_sample_drawn=> "",
               :tests=> ["Viral Load"],
               :sample_priority=> 'Routine',
               :target_lab=> settings['receiving_facility'],
               :tracking_number => "",
               :art_start_date => "",
               :date_dispatched => "",
               :date_received => Time.now,
               :return_json => 'true'
      }

      test_date = "#{params[:test_year]}/#{params[:test_month]}/#{params[:test_day]}".to_datetime.strftime("%Y%m%d%H%M%S")
      #Post to NLIMS
      data = JSON.parse(RestClient::Request.execute(:method => 'post',  :url => create_url, :payload => json.to_json, :headers => {"Content-Type" => "application/json"})) #rescue nil


      if !data.blank?
        order                          = {"_id"           => data["tracking_number"],
                                          "sample_status" => "specimen-accepted"}

        h                              = {}
        h['test_status']               = "verified"
        h['remarks']                   = ""
        h['datetime_started']          = ""
        h['datetime_completed']        = test_date
        h['who_updated']               = {}
        who                            = current_user
        h['who_updated']['first_name'] = who.name.strip.scan(/^\w+/).first
        h['who_updated']['last_name']  = who.name.strip.scan(/\w+$/).last
        h['who_updated']['ID_number']  = who.username

        h['results']                   = {"Viral Load" => (params[:test_value].first rescue "") }
        order['results']               = {}
        order['results']["Viral Load"] = h

        remote_post_url = "#{settings['central_repo']}/pass_json/"
        RestClient::Request.execute(:method => 'post',  :url => remote_post_url, :payload => order.to_json, :headers => {"Content-Type" => "application/json"})

      end
    end

    unless params[:go_to_patient_dashboard].blank?
      redirect_to ("/lab/give_result?patient_id=#{params[:patient_id]}&go_to_patient_dashboard=true") and return if params[:result_given].match(/YES/i)
      redirect_to ("/patients/show/#{params[:patient_id]}") and return
    end

    unless params[:go_to_next_task].blank?
      patient = Patient.find(params[:patient_id])
      redirect_to ("/lab/give_result?patient_id=#{params[:patient_id]}&go_to_next_task=true") and return if params[:result_given].match(/YES/i)
      redirect_to next_task(patient) and return
    end

    redirect_to ("/lab/give_result?patient_id=#{params[:patient_id]}") and return if params[:result_given].match(/YES/i)
    redirect_to("/people/confirm?found_person_id=#{params[:patient_id]}") and return
  end

  def result_given_to_patient
    patient_id = params[:patient_id]
    date_or_year_given = params[:set_year]
    month_given = params[:set_month]
    day_given = params[:set_day]
    date_given_result = date_or_year_given.to_date rescue (date_or_year_given.to_s + '-' + month_given.to_s + '-' + day_given).to_date
    patient = Patient.find(patient_id)
    encounter_type = EncounterType.find_by_name("REQUEST").id
    viral_load = Concept.find_by_name("Hiv viral load").concept_id

    national_ids = id_identifiers(Patient.find(patient_id)) #For testing purposes

    vl_lab_sample = LabSample.find_by_sql(["
        SELECT * FROM Lab_Sample s
        INNER JOIN Lab_Parameter p ON p.sample_id = s.sample_id
        INNER JOIN codes_TestType c ON p.testtype = c.testtype
        INNER JOIN (SELECT DISTINCT rec_id, short_name FROM map_lab_panel) m ON c.panel_id = m.rec_id
        WHERE s.patientid IN (?)
        AND short_name = ?
        AND s.deleteyn = 0
        AND s.attribute = 'pass'
        ORDER BY DATE(TESTDATE) DESC",national_ids,'HIV_viral_load'
      ]).first rescue nil

    vl_lab_sample_obs = Observation.find(:last, :readonly => false, :joins => [:encounter], :conditions => ["
        person_id =? AND encounter_type =? AND concept_id =? AND accession_number =?",
        patient.id, encounter_type, viral_load, vl_lab_sample.Sample_ID.to_i]) rescue nil
    #raise (vl_lab_sample.Sample_ID.to_s + ' : ' + vl_lab_sample_obs.accession_number).inspect
    unless vl_lab_sample.blank?
      enc = patient.encounters.current.find_by_encounter_type(encounter_type)
      enc ||= patient.encounters.create(:encounter_type => encounter_type)
      obs = nil
      unless vl_lab_sample_obs.blank?

        obs = vl_lab_sample_obs
      else
        obs = Observation.new
      end

      obs.person_id = patient_id
      obs.concept_id = Concept.find_by_name("Hiv viral load").concept_id
      obs.value_text = "Result given to patient"
      obs.value_datetime = date_given_result
      obs.accession_number = vl_lab_sample.Sample_ID
      obs.encounter_id = enc.id
      obs.obs_datetime = Time.now
      obs.save
    end

    counselling_done = params[:counselling_done]
    unless counselling_done.blank?
      status = counselling_done.match(/yes/i)?'done':'not done'
      obs = Observation.new
      obs.person_id = patient_id
      obs.concept_id = Concept.find_by_name("Hiv viral load").concept_id
      obs.value_text = "Adherent counselling #{status}"
      obs.accession_number = vl_lab_sample.Sample_ID unless vl_lab_sample.blank?
      obs.encounter_id = enc.id
      obs.obs_datetime = Time.now
      obs.save
    end

    if national_lims_activated
      settings = YAML.load_file("#{Rails.root}/config/lims.yml")[Rails.env]

      national_id_type = PatientIdentifierType.find_by_name("National id").id
      npid = patient.patient_identifiers.find_by_identifier_type(national_id_type).identifier

      get_url = settings['lims_national_dashboard_ip'] + "/api/vl_result_by_npid?npid=#{npid}&raw=true&test_status=verified"
      data = JSON.parse(RestClient.get(get_url)) rescue []

      if !data.blank?
        result        = data['results']['Viral Load']
        timestamp     = result.keys.sort.last
        result        = result[timestamp]

        order                          = {"_id"           => data["_id"],
                                          "sample_status" => data["status"]}

        h                              = {}
        h['test_status']               = "reviewed"
        h['remarks']                   = result['remarks'] rescue nil
        h['datetime_started']          = result['datetime_started'] rescue nil
        h['datetime_completed']        = result['datetime_completed'] rescue nil
        h['who_updated']               = {}
        who                            = current_user
        h['who_updated']['first_name'] = who.name.strip.scan(/^\w+/).first
        h['who_updated']['last_name']  = who.name.strip.scan(/\w+$/).last
        h['who_updated']['ID_number']  = who.username

        h['results']                   = result['results']
        order['results']               = {}
        order['results']["Viral Load"] = h

        remote_post_url = "#{settings['central_repo']}/pass_json/"
        RestClient::Request.execute(:method => 'post',  :url => remote_post_url, :payload => order.to_json, :headers => {"Content-Type" => "application/json"})
      end
    end

    unless params[:go_to_patient_dashboard].blank?
      redirect_to ("/patients/show/#{params[:patient_id]}") and return
    end

    unless params[:go_to_next_task].blank?
      patient = Patient.find(params[:patient_id])
      redirect_to next_task(patient) and return
    end

    redirect_to("/people/confirm?found_person_id=#{params[:patient_id]}") and return
  end

  def patient_switched_to_second_line
    patient_id = params[:patient_id]
    counselling_done = params[:counselling_done]
    #>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
    date_or_year_switched = params[:set_year]
    month_switched = params[:set_month]
    day_switched = params[:set_day]
    date_switched = date_or_year_switched.to_date rescue (date_or_year_switched.to_s + '-' + month_switched.to_s + '-' + day_switched).to_date
    #>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
    patient = Patient.find(patient_id)
    encounter_type = EncounterType.find_by_name("REQUEST").id
    viral_load = Concept.find_by_name("Hiv viral load").concept_id

    national_ids = id_identifiers(Patient.find(patient_id))
    vl_lab_sample = LabSample.find_by_sql(["
        SELECT * FROM Lab_Sample s
        INNER JOIN Lab_Parameter p ON p.sample_id = s.sample_id
        INNER JOIN codes_TestType c ON p.testtype = c.testtype
        INNER JOIN (SELECT DISTINCT rec_id, short_name FROM map_lab_panel) m ON c.panel_id = m.rec_id
        WHERE s.patientid IN (?)
        AND short_name = ?
        AND s.deleteyn = 0
        AND s.attribute = 'pass'
        ORDER BY DATE(TESTDATE) DESC",national_ids,'HIV_viral_load'
      ]).first rescue nil

    second_line_obs = Observation.find(:last, :readonly => false, :joins => [:encounter], :conditions => ["
        person_id =? AND encounter_type =? AND concept_id =? AND accession_number =?
        AND value_text LIKE (?)",
        patient.id, encounter_type, viral_load, vl_lab_sample.Sample_ID.to_i, '%Patient switched to second line%']) rescue nil

    enc = patient.encounters.current.find_by_encounter_type(encounter_type)
    enc ||= patient.encounters.create(:encounter_type => encounter_type)
    obs = second_line_obs unless second_line_obs.blank?
    obs = Observation.new if second_line_obs.blank?
    obs.person_id = patient_id
    obs.concept_id = Concept.find_by_name("Hiv viral load").concept_id
    obs.value_text = "Patient switched to second line"
    obs.accession_number = vl_lab_sample.Sample_ID unless vl_lab_sample.blank?
    obs.value_datetime = date_switched
    obs.encounter_id = enc.id
    obs.obs_datetime = Time.now
    obs.save
=begin
    status = counselling_done.match(/yes/i)?'done':'not done'
    obs = Observation.new
    obs.person_id = patient_id
    obs.concept_id = Concept.find_by_name("Hiv viral load").concept_id
    obs.value_text = "Adherent counselling #{status}"
    obs.accession_number = vl_lab_sample.Sample_ID unless vl_lab_sample.blank?
    obs.encounter_id = enc.id
    obs.obs_datetime = Time.now
    obs.save
=end
    redirect_to("/people/confirm?found_person_id=#{params[:patient_id]}")
  end

  def new
    @available_test = LabTestType.available_test
    @lab_test = ['']
    LabTestType.find(:all,
      :conditions =>["REPLACE(TestName,'_',' ') LIKE ?","%#{params[:name]}%"],
      :order =>"TestName ASC").map{|test|
      @lab_test << [test.TestName.gsub('_',' '),test.TestName]
    }
    @patient_id = params[:patient_id]
    @patient = Patient.find(params[:patient_id])
  end

  def create
    patient_bean = PatientService.get_patient(Person.find(params[:patient_id]))
    date = params[:test_date].to_date rescue "1900-01-01".to_date

    test_type = LabTestType.find(:first,
      :conditions =>["TestName = ?",params[:lab_result].to_s])

    test_modifier = params[:test_value].to_s.match(/=|>|</)[0]
    test_value = params[:test_value].to_s.gsub('>','').gsub('<','').gsub('=','')
    available_test_type = LabTestType.find(:all,:conditions=>["TestType IN (?)", test_type.TestType]).collect{|n|n.Panel_ID}

    lab_test_table = LabTestTable.new()
    lab_test_table.TestOrdered = LabPanel.test_name(available_test_type)[0]
    lab_test_table.Pat_ID = patient_bean.national_id
    lab_test_table.OrderDate = date
    lab_test_table.OrderTime = Time.now().strftime("%H:%M:%S")
    lab_test_table.OrderedBy = current_user.id
    lab_test_table.Location = Location.current_health_center.name
    lab_test_table.save

    # try
    # lab_test_table.reload
    # sleep(1) while ltt.AccessionNum <= LabTestTable.last.AccessionNum
    lab_test_table.reload

    lab_sample = LabSample.new()
    lab_sample.AccessionNum = lab_test_table.AccessionNum
    lab_sample.USERID = current_user.id
    lab_sample.TESTDATE = date
    lab_sample.PATIENTID = patient_bean.national_id
    lab_sample.DATE = date
    lab_sample.TIME = Time.now().strftime("%H:%M:%S")
    lab_sample.SOURCE = Location.current_location.id
    lab_sample.DeleteYN = 0
    lab_sample.Attribute = "pass"
    lab_sample.TimeStamp = Time.now()
    lab_sample.save

    lab_sample.reload

    lab_parameter = LabParameter.new()
    lab_parameter.Sample_ID = lab_sample.Sample_ID
    lab_parameter.TESTTYPE =  test_type.TestType
    lab_parameter.TESTVALUE = test_value
    lab_parameter.TimeStamp = Time.now()
    lab_parameter.Range = test_modifier
    lab_parameter.save
    #This is for viral load feature
    #Needs to be reworked
=begin
    unless params[:result_given].blank?
      patient = Patient.find(params[:patient_id])
      type = EncounterType.find_by_name("REQUEST")
      encounter = patient.encounters.current.find_by_encounter_type(type.id)
      encounter ||= patient.encounters.create(:encounter_type => type.id)
      observation = {}
          observation[:concept_name] = "DATE OF RETURNED RESULT"
          observation[:encounter_id] = encounter.id
          observation[:accession_number] = lab_parameter.Sample_ID
          observation[:obs_datetime] = encounter.encounter_datetime || Time.now()
          observation[:person_id] ||= encounter.patient_id
          observation[:value_datetime] = params[:date_result_given]
          observation[:value_text]
          Observation.create(observation)
    end
=end
    redirect_to :action => "results" , :id => patient_bean.patient_id
  end

  def edit_lims_lab_results
    @patient = Patient.find(params[:patient_id])
    npid = id_identifiers(@patient)
    @patient_bean = PatientService.get_patient(@patient.person)

    if national_lims_activated
      settings = YAML.load_file("#{Rails.root}/config/lims.yml")[Rails.env]
      url = settings['lims_national_dashboard_ip'] + "/api/patient_lab_trail?npid=#{npid}"
    end
    data = JSON.parse(RestClient.get(url)) rescue {}

    @lims_lab_results = {}
    count = 0

    (data || []).each do |results|
      @lims_lab_results[count] = {}

      track_number = results['_id']
      test_name = results['sample_type']
      test_result = []
      test_dates = []
      results['results']['Viral Load'].keys.sort.each do |key|
        t_result = results['results']['Viral Load'][key]['results']['Viral Load'] rescue nil
        test_result << t_result unless t_result.blank?
        test_dates << key.to_date.strftime('%d/%b/%Y') unless t_result.blank?
      end

      @lims_lab_results[count] = {
          'test_date' => test_dates[test_dates.length - 1],
          'test_type' => results['test_types'][0],
          'test_name' => test_name,
          'test_value' => test_result.last,
          'lab_sample_id' => track_number,
          'range' => ''
      }

      count = count + 1
    end

    render :layout => 'menu'
  end

  def edit_lab_results
    @patient = Patient.find(params[:patient_id])
    patient_ids = id_identifiers(@patient)
    @patient_bean = PatientService.get_patient(@patient.person)
    
    results = Lab.find_by_sql(["
        SELECT * FROM Lab_Sample s
        INNER JOIN Lab_Parameter p ON p.sample_id = s.sample_id
        INNER JOIN codes_TestType c ON p.testtype = c.testtype
        INNER JOIN (SELECT DISTINCT rec_id, short_name FROM map_lab_panel) m ON c.panel_id = m.rec_id
        WHERE s.patientid IN (?)
        AND short_name = ?
        AND s.deleteyn = 0
        AND s.attribute = 'pass'
        ORDER BY DATE(TESTDATE) DESC",patient_ids,'HIV_viral_load'
      ])

    @hash = {}
    count = 1
    results.each do |result|
      @hash[count] = {}
      lab_sample_id = result.Sample_ID
      test_type = result.TESTTYPE
      test_name = result.TestName
      range = result.Range
      test_value = result.TESTVALUE
      test_date = result.TESTDATE
      @hash[count] = {
        "lab_sample_id" => lab_sample_id,
        "test_type" => test_type,
        "test_name" => test_name,
        "range" => range,
        "test_value" => test_value,
        "test_date" => (test_date.to_date.strftime("%d/%b/%Y") rescue test_date)
      }
      count = count + 1
    end
    render :layout => 'menu'
  end

  def edit_specific_result

    @patient = Patient.find(params[:patient_id])

    if !national_lims_activated
    #
    # else
    #   @patient = Patient.find(params[:patient_id])
      lab_sample_id = params[:lab_sample_id]
      test_type = params[:test_type]
      lab_parameter = LabParameter.find(:last, :conditions => ["Sample_ID =? AND TESTTYPE=?", lab_sample_id, test_type ])
      @test_result = lab_parameter.Range.to_s + '' + lab_parameter.TESTVALUE.to_s
      lab_sample = LabSample.find(lab_sample_id)
      @test_date = lab_sample.TESTDATE.to_date
    end
  end

  def update_specific_result

    @patient = Patient.find(params[:patient_id])

    if national_lims_activated

      npid = id_identifiers(@patient)
      settings = YAML.load_file("#{Rails.root}/config/lims.yml")[Rails.env]
      get_url = "#{settings['lims_national_dashboard_ip']}/api/pull_vl_by_id?id=#{params['lab_sample_id']}"

      lab_sample_id = params[:lab_sample_id]
      test_type = params[:test_type]
      test_value = params[:test_value]
      test_date = params[:test_date]

      @lims_data = {'test_type'=>test_type,
                    'patient_id'=>npid,
                    'lab_sample_id'=>lab_sample_id,
                    'test_value' => test_value,
                    'test_date' => test_date}

        data = JSON.parse(RestClient.get(get_url)) rescue []

        if !data.blank?
          result        = data['results']['Viral Load']
          timestamp     = @lims_data['test_date'].to_time
          result        = result[timestamp]

          order                          = {"_id"           => @lims_data['lab_sample_id'],
                                            "sample_status" => data["status"]}

          h                              = {}
          h['test_status']               = "reviewed"
          h['remarks']                   = result['remarks'] rescue nil
          h['datetime_started']          = @lims_data['test_date']
          h['datetime_completed']        = result['datetime_completed'] rescue nil
          h['who_updated']               = {}
          who                            = current_user
          h['who_updated']['first_name'] = who.name.strip.scan(/^\w+/).first
          h['who_updated']['last_name']  = who.name.strip.scan(/\w+$/).last
          h['who_updated']['ID_number']  = who.username

          h['results'] = {'Viral Load' => @lims_data['test_value'][0]}
          order['results']               = {}
          order['results']["Viral Load"] = h

          remote_post_url = "#{settings['central_repo']}/pass_json/"
          RestClient::Request.execute(:method => 'post',  :url => remote_post_url, :payload => order.to_json, :headers => {"Content-Type" => "application/json"})
        end

      redirect_to :action => "edit_lims_lab_results", :patient_id => params[:patient_id] and return

    else

      lab_sample_id = params[:lab_sample_id]
      test_type = params[:test_type]
      test_modifier = params[:test_value].to_s.match(/=|>|</)[0]
      test_value = params[:test_value].to_s.gsub('>','').gsub('<','').gsub('=','')
      test_date = params[:test_date].to_date

      ActiveRecord::Base.transaction do
        lab_parameter = LabParameter.find(:last, :conditions => ["Sample_ID =? AND TESTTYPE=?", lab_sample_id, test_type ])
        lab_parameter.Range = test_modifier
        lab_parameter.TESTVALUE = test_value
        lab_parameter.save

        lab_sample = LabSample.find(lab_sample_id)
        lab_sample.TESTDATE = test_date
        lab_sample.save
      end
      redirect_to :action => "edit_lab_results", :patient_id => params[:patient_id] and return
    end

  end

  def delete_lab_results
    lab_sample_id = params[:lab_sample_id]
    test_type = params[:test_type]
    lab_parameter = LabParameter.find(:last, :conditions => ["Sample_ID =? AND TESTTYPE=?", lab_sample_id, test_type ])
    sample_id = lab_parameter.Sample_ID rescue ""
    lab_observations = Observation.find(:all, :conditions => ["accession_number IS NOT NULL AND accession_number=?", sample_id])
    encounter = ""
    ActiveRecord::Base.transaction do
      (lab_observations || []).each do |observation|
        encounter = observation.encounter if encounter.blank?
        observation.void("Lab Result deleted in health data")
      end
      encounter.void("Lab Result deleted in health data") unless encounter.blank?
      lab_parameter.delete
    end
    
    redirect_to :action => "edit_lab_results", :patient_id => params[:patient_id] and return
  end

  def update_national_id
    settings = YAML.load_file("#{Rails.root}/config/lims.yml")[Rails.env]

    if national_lims_activated
      tracking_number = params['track_num']
      national_id = params['national_id']
      get_url = "#{settings['lims_national_dashboard_ip']}/api/pull_vl_by_id?id=#{tracking_number}"

      data = JSON.parse(RestClient.get(get_url)) rescue []

      if !data.blank?

        data['patient']['national_id'] = "11MKDKDjkkncxkonncjjHJH J onxzoicnzxo"
        who                            = current_user
        data['who_updated']['first_name'] = who.name.strip.scan(/^\w+/).first
        data['who_updated']['last_name']  = who.name.strip.scan(/\w+$/).last
        data['who_updated']['ID_number']  = who.username

        remote_post_url = "#{settings['central_repo']}/pass_json/"
        RestClient::Request.execute(:method => 'post',  :url => remote_post_url, :payload => order.to_json, :headers => {"Content-Type" => "application/json"})

        # render :json => data
      end
    end
  end

end
