class Patient < ActiveRecord::Base
  set_table_name "patient"
  set_primary_key "patient_id"
  include Openmrs

  has_one :person, :foreign_key => :person_id, :conditions => {:voided => 0}
  has_many :patient_identifiers, :foreign_key => :patient_id, :dependent => :destroy, :conditions => {:voided => 0}
  has_many :patient_programs, :conditions => {:voided => 0}
  has_many :programs, :through => :patient_programs
  has_many :relationships, :foreign_key => :person_a, :dependent => :destroy, :conditions => {:voided => 0}
  has_many :orders, :conditions => {:voided => 0}
  has_many :encounters, :conditions => {:voided => 0} do

    def find_by_date(encounter_date)
      encounter_date = Date.today unless encounter_date
      find(:all, :conditions => ["encounter_datetime BETWEEN ? AND ?",
          encounter_date.to_date.strftime('%Y-%m-%d 00:00:00'),
          encounter_date.to_date.strftime('%Y-%m-%d 23:59:59')
        ]) # Use the SQL DATE function to compare just the date part
    end
  end

  def after_void(reason = nil)
    self.person.void(reason) rescue nil
    self.patient_identifiers.each {|row| row.void(reason) }
    self.patient_programs.each {|row| row.void(reason) }
    self.orders.each {|row| row.void(reason) }
    self.encounters.each {|row| row.void(reason) }
  end

  def current_bp(date = Date.today)
    encounter_id = self.encounters.last(:conditions => ["encounter_type = ? AND DATE(encounter_datetime) = ?",
        EncounterType.find_by_name("VITALS").id, date.to_date]).id rescue nil

    ans = [(Observation.last(:conditions => ["encounter_id = ? AND concept_id = ?", encounter_id,
            ConceptName.find_by_name("SYSTOLIC BLOOD PRESSURE").concept_id]).answer_string.to_i rescue nil),
      (Observation.last(:conditions => ["encounter_id = ? AND concept_id = ?", encounter_id,
            ConceptName.find_by_name("DIASTOLIC BLOOD PRESSURE").concept_id]).answer_string.to_i rescue nil)
    ]
    ans = ans.reject(&:blank?)
  end

  def physical_address
    return PersonAddress.find_by_person_id(self.id, :conditions => "voided = 0").city_village rescue nil
  end

  def name
    "#{self.person.names[0].given_name rescue ''} #{self.person.names[0].family_name rescue ''}"
  end

  def self.duplicates(attributes)
    search_str = ''
    ( attributes.sort || [] ).each do | attribute |
      search_str+= ":#{attribute}" unless search_str.blank?
      search_str = attribute if search_str.blank?
    end rescue []

    return if search_str.blank?
    duplicates = {}
    patients = Patient.find(:all) # AND DATE(date_created >= ?) AND DATE(date_created <= ?)",
    #'2005-01-01'.to_date,'2010-12-31'.to_date])

    ( patients || [] ).each do | patient |
      if search_str.upcase == "DOB:NAME"
        next if patient.name.blank?
        next if patient.person.birthdate.blank?
        duplicates["#{patient.name}:#{patient.person.birthdate}"] = [] if duplicates["#{patient.name}:#{patient.person.birthdate}"].blank?
        duplicates["#{patient.name}:#{patient.person.birthdate}"] << patient
      elsif search_str.upcase == "DOB:ADDRESS"
        next if patient.physical_address.blank?
        next if patient.person.birthdate.blank?
        duplicates["#{patient.name}:#{patient.physical_address}"] = [] if duplicates["#{patient.name}:#{patient.physical_address}"].blank?
        duplicates["#{patient.name}:#{patient.physical_address}"] << patient
      elsif search_str.upcase == "DOB:LOCATION (PHYSICAL)"
        next if patient.person.birthdate.blank?
        next if patient.person.addresses.last.county_district.blank?
        duplicates["#{patient.person.addresses.last.county_district}:#{patient.physical_address}"] = [] if duplicates["#{patient.person.addresses.last.county_district}:#{patient.physical_address}"].blank?
        duplicates["#{patient.person.addresses.last.county_district}:#{patient.physical_address}"] << patient
      elsif search_str.upcase == "ADDRESS:DOB"
        next if patient.person.birthdate.blank?
        next if patient.physical_address.blank?
        if duplicates["#{patient.physical_address}:#{patient.person.birthdate}"].blank?
          duplicates["#{patient.physical_address}:#{patient.person.birthdate}"] = []
        end
        duplicates["#{patient.physical_address}:#{patient.person.birthdate}"] << patient
      elsif search_str.upcase == "ADDRESS:LOCATION (PHYSICAL)"
        next if patient.person.addresses.last.county_district.blank?
        next if patient.physical_address.blank?
        if duplicates["#{patient.physical_address}:#{patient.person.addresses.last.county_district}"].blank?
          duplicates["#{patient.physical_address}:#{patient.person.addresses.last.county_district}"] = []
        end
        duplicates["#{patient.physical_address}:#{patient.person.addresses.last.county_district}"] << patient
      elsif search_str.upcase == "ADDRESS:NAME"
        next if patient.name.blank?
        next if patient.physical_address.blank?
        if duplicates["#{patient.physical_address}:#{patient.name}"].blank?
          duplicates["#{patient.physical_address}:#{patient.name}"] = []
        end
        duplicates["#{patient.physical_address}:#{patient.name}"] << patient
      elsif search_str.upcase == "ADDRESS:LOCATION (PHYSICAL)"
        next if patient.person.addresses.last.county_district.blank?
        next if patient.physical_address.blank?
        if duplicates["#{patient.physical_address}:#{patient.person.addresses.last.county_district}"].blank?
          duplicates["#{patient.physical_address}:#{patient.person.addresses.last.county_district}"] = []
        end
        duplicates["#{patient.physical_address}:#{patient.person.addresses.last.county_district}"] << patient
      elsif search_str.upcase == "DOB:LOCATION (PHYSICAL)"
        next if patient.person.addresses.last.county_district.blank?
        next if patient.person.birthdate.blank?
        if duplicates["#{patient.person.birthdate}:#{patient.person.addresses.last.county_district}"].blank?
          duplicates["#{patient.person.birthdate}:#{patient.person.addresses.last.county_district}"] = []
        end
        duplicates["#{patient.person.birthdate}:#{patient.person.addresses.last.county_district}"] << patient
      elsif search_str.upcase == "LOCATION (PHYSICAL):NAME"
        next if patient.name.blank?
        next if patient.person.addresses.last.county_district.blank?
        if duplicates["#{patient.person.addresses.last.county_district}:#{patient.name}"].blank?
          duplicates["#{patient.person.addresses.last.county_district}:#{patient.name}"] = []
        end
        duplicates["#{patient.person.addresses.last.county_district}:#{patient.name}"] << patient
      elsif search_str.upcase == "ADDRESS:DOB:LOCATION (PHYSICAL):NAME"
        next if patient.name.blank?
        next if patient.person.birthdate.blank?
        next if patient.physical_address.blank?
        next if patient.person.addresses.last.county_district.blank?
        if duplicates["#{patient.name}:#{patient.person.birthdate}:#{patient.physical_address}:#{patient.person.addresses.last.county_district}"].blank?
          duplicates["#{patient.name}:#{patient.person.birthdate}:#{patient.physical_address}:#{patient.person.addresses.last.county_district}"] = []
        end
        duplicates["#{patient.name}:#{patient.person.birthdate}:#{patient.physical_address}:#{patient.person.addresses.last.county_district}"] << patient
      elsif search_str.upcase == "ADDRESS"
        next if patient.physical_address.blank?
        if duplicates[patient.physical_address].blank?
          duplicates[patient.physical_address] = []
        end
        duplicates[patient.physical_address] << patient
      elsif search_str.upcase == "DOB"
        next if patient.person.birthdate.blank?
        if duplicates[patient.person.birthdate].blank?
          duplicates[patient.person.birthdate] = []
        end
        duplicates[patient.person.birthdate] << patient
      elsif search_str.upcase == "LOCATION (PHYSICAL)"
        next if patient.person.addresses.last.county_district.blank?
        if duplicates[patient.person.addresses.last.county_district].blank?
          duplicates[patient.person.addresses.last.county_district] = []
        end
        duplicates[patient.person.addresses.last.county_district] << patient
      elsif search_str.upcase == "NAME"
        next if patient.name.blank?
        if duplicates[patient.name].blank?
          duplicates[patient.name] = []
        end
        duplicates[patient.name] << patient
      end
    end
    hash_to = {}
    duplicates.each do |key,pats |
      next unless pats.length > 1
      hash_to[key] = pats
    end
    hash_to
  end

  def self.merge(patient_id, secondary_patient_id)
    patient = Patient.find(patient_id, :include => [:patient_identifiers, :patient_programs, {:person => [:names]}])
    secondary_patient = Patient.find(secondary_patient_id, :include => [:patient_identifiers, :patient_programs, {:person => [:names]}])
    sec_pt_arv_numbers = PatientIdentifier.find(:all, :conditions => ["patient_id =? AND identifier_type =?",
        secondary_patient_id, PatientIdentifierType.find_by_name('ARV NUMBER').id]).map(&:identifier) rescue []

    national_ids = PatientIdentifier.find(:all, :conditions => ["patient_id =? AND identifier_type =?",
        secondary_patient_id, PatientIdentifierType.find_by_name('National id').id]).map(&:identifier) rescue []

    old_id = PatientIdentifierType.find_by_name("Old Identification Number").id
    national_id = PatientIdentifierType.find_by_name("National id").id

    unless sec_pt_arv_numbers.blank?
      sec_pt_arv_numbers.each do |arv_number|
        ActiveRecord::Base.connection.execute("
          UPDATE patient_identifier SET voided = 1, date_voided=NOW(),voided_by=#{User.current.user_id},
          void_reason = 'merged with patient #{patient_id}'
          WHERE patient_id = #{secondary_patient_id}
          AND identifier = '#{arv_number}'")
      end
    end

    unless national_ids.blank?
      ActiveRecord::Base.connection.execute("
          UPDATE patient_identifier SET identifier_type = #{old_id}, patient_id = #{patient_id} WHERE patient_id = #{secondary_patient_id}
          AND identifier_type = #{national_id}")
    end

    ActiveRecord::Base.transaction do
      secondary_patient.patient_identifiers.each {|r|

        if patient.patient_identifiers.map(&:identifier).each{| i | i.upcase }.include?(r.identifier.upcase)
          ActiveRecord::Base.connection.execute("
          UPDATE patient_identifier SET voided = 1, date_voided=NOW(),voided_by=#{User.current.user_id},
          void_reason = 'merged with patient #{patient_id}'
          WHERE patient_id = #{secondary_patient_id}
          AND identifier_type = #{r.identifier_type}
          AND identifier = '#{r.identifier}'")
        else
          ActiveRecord::Base.connection.execute <<EOF
UPDATE patient_identifier SET patient_id = #{patient_id}
WHERE patient_id = #{secondary_patient_id}
AND identifier_type = #{r.identifier_type}
AND identifier = "#{r.identifier}"
EOF
        end
      }

      secondary_patient.person.names.each {|r|
        if patient.person.names.map{|pn| "#{pn.given_name.upcase rescue ''} #{pn.family_name.upcase rescue ''}"}.include?("#{r.given_name.upcase rescue ''} #{r.family_name.upcase rescue ''}")
          ActiveRecord::Base.connection.execute("
        UPDATE person_name SET voided = 1, date_voided=NOW(),voided_by=#{User.current.user_id},
        void_reason = 'merged with patient #{patient_id}'
        WHERE person_id = #{secondary_patient_id}
        AND person_name_id = #{r.person_name_id}")
        end
      }

      secondary_patient.person.addresses.each {|r|
        if patient.person.addresses.map{|pa| "#{pa.city_village.upcase rescue ''}"}.include?("#{r.city_village.upcase rescue ''}")
          ActiveRecord::Base.connection.execute("
        UPDATE person_address SET voided = 1, date_voided=NOW(),voided_by=#{User.current.user_id},
        void_reason = 'merged with patient #{patient_id}'
        WHERE person_id = #{secondary_patient_id}")
        else
          ActiveRecord::Base.connection.execute <<EOF
UPDATE person_address SET person_id = #{patient_id}
WHERE person_id = #{secondary_patient_id}
AND person_address_id = #{r.person_address_id}
EOF
        end
      }

      secondary_patient.patient_programs.each {|r|
        if patient.patient_programs.map(&:program_id).include?(r.program_id)
          ActiveRecord::Base.connection.execute("
        UPDATE patient_program SET voided = 1, date_voided=NOW(),voided_by=#{User.current.user_id},
        void_reason = 'merged with patient #{patient_id}'
        WHERE patient_id = #{secondary_patient_id}
        AND patient_program_id = #{r.patient_program_id}")
        else
          ActiveRecord::Base.connection.execute <<EOF
UPDATE patient_program SET patient_id = #{patient_id}
WHERE patient_id = #{secondary_patient_id}
AND patient_program_id = #{r.patient_program_id}
EOF
        end
      }

      ActiveRecord::Base.connection.execute("
        UPDATE patient SET voided = 1, date_voided=NOW(),voided_by=#{User.current.user_id},
        void_reason = 'merged with patient #{patient_id}'
        WHERE patient_id = #{secondary_patient_id}")

      ActiveRecord::Base.connection.execute("UPDATE person_attribute SET person_id = #{patient_id} WHERE person_id = #{secondary_patient_id}")
      ActiveRecord::Base.connection.execute("UPDATE person_address SET person_id = #{patient_id} WHERE person_id = #{secondary_patient_id}")
      ActiveRecord::Base.connection.execute("UPDATE encounter SET patient_id = #{patient_id} WHERE patient_id = #{secondary_patient_id}")
      ActiveRecord::Base.connection.execute("UPDATE obs SET person_id = #{patient_id} WHERE person_id = #{secondary_patient_id}")
      ActiveRecord::Base.connection.execute("UPDATE note SET patient_id = #{patient_id} WHERE patient_id = #{secondary_patient_id}")
      #ActiveRecord::Base.connection.execute("UPDATE person SET person_id = #{patient_id} WHERE person_id = #{secondary_patient_id}")
    end
  end

  def self.vl_result_hash(patient)
    encounter_type = EncounterType.find_by_name("REQUEST").id
    viral_load = Concept.find_by_name("Hiv viral load").concept_id
    identifiers = LabController.new.id_identifiers(patient)
    second_line_regimens = patient.second_line_regimens
    national_ids = identifiers
    vl_hash = {}
    results = Lab.find_by_sql(["
        SELECT * FROM Lab_Sample s
        INNER JOIN Lab_Parameter p ON p.sample_id = s.sample_id
        INNER JOIN codes_TestType c ON p.testtype = c.testtype
        INNER JOIN (SELECT DISTINCT rec_id, short_name FROM map_lab_panel) m ON c.panel_id = m.rec_id
        WHERE s.patientid IN (?)
        AND short_name = ?
        AND s.deleteyn = 0
        AND s.attribute = 'pass'", national_ids, 'HIV_viral_load'
      ]).collect do | result |
      [
        result.Sample_ID,
        result.Range,
        result.TESTVALUE,
        result.TESTDATE
      ]
    end

    results.each do |result|

      accession_number = result[0]
      range = result[1]
      vl_result = result[2]
      date_of_sample = result[3].to_date rescue 'Unknown'

      vl_hash[accession_number] = {} if vl_hash[accession_number].blank?
      vl_hash[accession_number]["result"] = {} if vl_hash[accession_number]["result"].blank?
      vl_hash[accession_number]["result"] = vl_result
      vl_hash[accession_number]["range"] = range
      vl_hash[accession_number]["date_of_sample"] = {} if vl_hash[accession_number]["date_of_sample"].blank?
      vl_hash[accession_number]["date_of_sample"] = date_of_sample

      vl_lab_sample_obs = Observation.find(:last, :joins => [:encounter], :conditions => ["
        person_id =? AND encounter_type =? AND concept_id =? AND accession_number =?
        AND value_text LIKE (?)",
          patient.id, encounter_type, viral_load, accession_number.to_i, '%Result given to patient%']) rescue nil


      unless vl_lab_sample_obs.blank?
        vl_hash[accession_number]["result_given"] = {} if vl_hash[accession_number]["result_given"].blank?
        vl_hash[accession_number]["result_given"] = "yes"
        vl_hash[accession_number]["date_result_given"] = {} if vl_hash[accession_number]["date_result_given"].blank?
        vl_hash[accession_number]["date_result_given"] = vl_lab_sample_obs.value_datetime.to_date
      else
        vl_hash[accession_number]["result_given"] = {} if vl_hash[accession_number]["result_given"].blank?
        vl_hash[accession_number]["result_given"] = "no"
        vl_hash[accession_number]["date_result_given"] = {} if vl_hash[accession_number]["date_result_given"].blank?
        vl_hash[accession_number]["date_result_given"] = ""
      end

      switched_to_second_line_obs = Observation.find(:last, :joins => [:encounter], :conditions => ["
        person_id =? AND encounter_type =? AND concept_id =? AND accession_number =?
        AND value_text LIKE (?)",
          patient.id, encounter_type, viral_load, accession_number.to_i, '%Patient switched to second line%']) rescue nil

      unless second_line_regimens.blank?
        date_switched = second_line_regimens.first[1]
        date_switched = date_switched.to_date.strftime("%d-%b-%Y") rescue date_switched

        vl_hash[accession_number]["second_line_switch"] = {} if vl_hash[accession_number]["second_line_switch"].blank?
        vl_hash[accession_number]["second_line_switch"] = "yes (#{date_switched})"
      else
        unless switched_to_second_line_obs.blank?
          vl_hash[accession_number]["second_line_switch"] = {} if vl_hash[accession_number]["second_line_switch"].blank?
          vl_hash[accession_number]["second_line_switch"] = "yes"
        else
          vl_hash[accession_number]["second_line_switch"] = {} if vl_hash[accession_number]["second_line_switch"].blank?
          vl_hash[accession_number]["second_line_switch"] = "no"
        end
      end
    end

    return vl_hash.sort_by{|key, value| (value["date_of_sample"].to_date rescue 'Unknown') }.reverse rescue {}
  end

  def self.allergic_to_sulpher(patient, date = Date.today)
    return  Observation.find(Observation.find(:first,
        :order => "obs_datetime DESC,date_created DESC",
        :conditions => ["person_id = ? AND concept_id = ?
      AND DATE(obs_datetime) <= ?", patient.id,
          ConceptName.find_by_name("Allergic to sulphur").concept_id,
          date])).answer_string.strip.squish rescue ''
  end

  def self.obs_available_in(patient, encounter_array, date = Date.today)
    return Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
      :conditions => ["patient_id = ? AND encounter_type IN (?) AND DATE(encounter_datetime) = ?",
        patient.id, EncounterType.find(:all,:select => 'encounter_type_id',
          :conditions => ["name IN (?)",encounter_array]),date.to_date]).observations rescue []
  end

  def self.tb_encounter(patient)
    return Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
      :conditions=>["patient_id = ? AND encounter_type = ?",
        patient.id, EncounterType.find_by_name("TB visit").id]) rescue nil
  end

  def self.current_hiv_program_state(patient)
    return PatientProgram.find(:first, :joins => :location,
      :conditions => ["patient_id = ? AND program_id = ? AND location.location_id = ? AND date_completed IS NULL",
        patient.id, Program.find_by_concept_id(Concept.find_by_name('HIV PROGRAM').id).id,
        Location.current_health_center]).patient_states.current.first.program_workflow_state.concept.fullname rescue ''
  end

  def self.hiv_encounter(patient, encounter, date = Date.today)
    return Encounter.find(:all,:order => "encounter_datetime DESC,date_created DESC",
      :conditions =>["DATE(encounter_datetime) = ? AND patient_id = ? AND encounter_type = ?",
        date.to_date, patient.id, EncounterType.find_by_name(encounter).id],
      :include => [:observations])
  end

  def self.concept_set(concept)
    concept_id = ConceptName.find_by_name(concept).concept_id
    set = ConceptSet.find_all_by_concept_set(concept_id, :order => 'sort_weight')
    symptoms_ids = set.map{|item|next if item.concept.blank? ; item.concept_id }
    return symptoms_ids
  end

  def self.regimen_index(hiv_regimen_map)
    return Regimen.find_by_sql("select distinct(c.name) as name, r.regimen_index as reg_index from concept_name c
    inner join regimen r on r.concept_id = c.concept_id
    where c.concept_id = '#{hiv_regimen_map}' and  concept_name_type = 'short' limit 1").map{|regimen| regimen.reg_index}
  end

  def date_started_art
    amount_dispensed = ConceptName.find_by_name('Amount dispensed').concept_id
    eal_dispension_date =  ActiveRecord::Base.connection.select_value("SELECT MIN(obs_datetime) 
      FROM obs WHERE concept_id = #{amount_dispensed} AND person_id = #{self.patient_id}").to_date rescue nil

    return  ActiveRecord::Base.connection.select_value("SELECT date_antiretrovirals_started(#{self.patient_id},
      '#{eal_dispension_date.to_date.to_s}');").to_date rescue nil
  end

  def self.type_of_hiv_confirmatory_test(patient, session_date = Date.today)
    hiv_confirmatory_test_concept_id = Concept.find_by_name('CONFIRMATORY HIV TEST TYPE').concept_id

    hiv_confirmatory_answer_string = patient.person.observations.find(:last, :conditions => ["DATE(obs_datetime) <= ? AND concept_id =?",
        session_date, hiv_confirmatory_test_concept_id]
    ).answer_string.squish.upcase rescue nil

    return hiv_confirmatory_answer_string
  end

  def self.date_of_hiv_clinic_registration(patient, session_date = Date.today)
    encounter_type_id = EncounterType.find_by_name("HIV CLINIC REGISTRATION").encounter_type_id
    hiv_clinic_reg_enc = patient.encounters.find(:last, :conditions => ["encounter_type =? AND 
        DATE(encounter_datetime) < ?", encounter_type_id, session_date])

    unless hiv_clinic_reg_enc.blank?
      reg_date = (hiv_clinic_reg_enc.encounter_datetime.to_date rescue hiv_clinic_reg_enc.encounter_datetime)
      return reg_date
    end

    return ""
  end

  def self.cpt_prescribed_in_the_last_prescription?(patient, session_date = Date.today)
    last_order_date = patient.orders.find(:last, :joins => [:encounter], :conditions => ["DATE(encounter_datetime) < ?",
        session_date]).encounter.encounter_datetime.to_date rescue nil
    return false if last_order_date.blank?
    last_orders = patient.orders.find(:all, :joins => [:encounter], :conditions => ["DATE(encounter_datetime) =?",
        last_order_date])

    last_orders.each do |order|
      drug_name = order.drug_order.drug.name rescue nil
      next if drug_name.blank?
      if drug_name.match(/COTRI/i)
        return true
        break
      end
    end

    return false
  end

  def self.ipt_prescribed_in_the_last_prescription?(patient, session_date = Date.today)
    last_order_date = patient.orders.find(:last, :joins => [:encounter], :conditions => ["DATE(encounter_datetime) < ?",
        session_date]).encounter.encounter_datetime.to_date rescue nil
    return false if last_order_date.blank?
    last_orders = patient.orders.find(:all, :joins => [:encounter], :conditions => ["DATE(encounter_datetime) =?",
        last_order_date])

    last_orders.each do |order|
      drug_name = order.drug_order.drug.name rescue nil
      next if drug_name.blank?
      if drug_name.match(/ISONIAZID/i)
        return true
        break
      end
    end

    return false
  end

  def self.history_of_side_effects(patient, session_date = Date.today)
    side_effects = {}
    encounter_type_id = EncounterType.find_by_name("HIV CLINIC CONSULTATION").encounter_type_id
    side_effects_concept_id = Concept.find_by_name("MLW ART SIDE EFFECTS").concept_id
    
    hiv_clinic_consultation_encounters = patient.encounters.find(:all, :conditions => ["encounter_type =? AND
      DATE(encounter_datetime) <= ?", encounter_type_id, session_date.to_date])

    hiv_clinic_consultation_encounters.each do |enc|
      encounter_datetime = enc.encounter_datetime.to_date.strftime("%d/%b/%Y")
      observation_answers = enc.observations.find(:all, :conditions => ["concept_id =?",
          side_effects_concept_id]).collect{|o|o.answer_string.squish}.compact
      side_effects[encounter_datetime] = observation_answers unless observation_answers.blank?
    end

    return side_effects
  end
=begin
side_effects_concept_id = Concept.find_by_name("MALAWI ART SIDE EFFECTS").concept_id
    symptom_present_conept_id = Concept.find_by_name("SYMPTOM PRESENT").concept_id

    @side_effects_answers = @patient.person.observations.find(:all, :conditions => ["concept_id IN (?) AND
        DATE(obs_datetime) =?", [side_effects_concept_id, symptom_present_conept_id], session_date]
    ).collect{|o|o.answer_string.squish}
=end

  def self.contraindications(patient, session_date = Date.today)
    side_effects_concept_id = Concept.find_by_name("MALAWI ART SIDE EFFECTS").concept_id
    symptom_present_concept_id = Concept.find_by_name("SYMPTOM PRESENT").concept_id

    encounter_type_id = EncounterType.find_by_name("HIV CLINIC CONSULTATION").encounter_type_id
    encounter = patient.encounters.find(:first, :conditions => ["encounter_type =? AND
        DATE(encounter_datetime) <= ?", encounter_type_id, session_date])
    return [] if encounter.blank?

    contraindications = patient.person.observations.find(:all, :conditions => ["concept_id IN (?) AND
        DATE(obs_datetime) <= ? AND encounter_id =?", [side_effects_concept_id, symptom_present_concept_id],
        session_date, encounter.id]
    ).collect{|o|o.answer_string.squish}

    return contraindications
  end

  def self.date_of_first_hiv_clinic_enc(patient, session_date = Date.today)
    
    encounter_type_id = EncounterType.find_by_name("HIV CLINIC CONSULTATION").encounter_type_id
    encounter_datetime = patient.encounters.find(:first, :conditions => ["encounter_type =? AND 
        DATE(encounter_datetime) <= ?", encounter_type_id, session_date]
    ).encounter_datetime.to_date.strftime("%d/%b/%Y") rescue nil

    return encounter_datetime
  end

  def self.todays_side_effects(patient, session_date = Date.today)
    side_effects_concept_id = Concept.find_by_name("MALAWI ART SIDE EFFECTS").concept_id
    symptom_present_conept_id = Concept.find_by_name("SYMPTOM PRESENT").concept_id

    side_effects_observations = patient.person.observations.find(:all, :conditions => ["concept_id IN (?) AND
        DATE(obs_datetime) = ?", [side_effects_concept_id, symptom_present_conept_id], session_date]
    )
    side_effects_contraindications = []
    side_effects_observations.each do |obs|
      next if !obs.obs_group_id.blank?
      child_obs = Observation.find(:last, :conditions => ["obs_group_id = ?", obs.obs_id])
      unless child_obs.blank?
        answer_string = child_obs.answer_string.squish
        next if answer_string.match(/NO/i)
        side_effects_contraindications << child_obs.concept.fullname
      end
    end

    return side_effects_contraindications
  end

  def self.side_effects_obs_ever(patient, session_date = Date.today)
    side_effects_concept_id = Concept.find_by_name("MALAWI ART SIDE EFFECTS").concept_id
    symptom_present_conept_id = Concept.find_by_name("SYMPTOM PRESENT").concept_id

    side_effects_observations = patient.person.observations.find(:all, :conditions => ["concept_id IN (?) AND
        DATE(obs_datetime) <= ?", [side_effects_concept_id, symptom_present_conept_id], session_date]
    )
    side_effects_obs_ever = []
    side_effects_observations.each do |obs|
      next if !obs.obs_group_id.blank?
      child_obs = Observation.find(:last, :conditions => ["obs_group_id = ?", obs.obs_id])
      unless child_obs.blank?
        answer_string = child_obs.answer_string.squish
        next if answer_string.match(/NO/i)
        side_effects_obs_ever << obs
        #side_effects_ever << child_obs.concept.fullname
      end
    end

    return side_effects_obs_ever
  end

  def self.previous_weight(patient, session_date)
    weight_concept_id = Concept.find_by_name("WEIGHT").concept_id

    previous_patient_weight = patient.person.observations.find(:last, :conditions => ["concept_id =? AND
        DATE(obs_datetime) < ?", weight_concept_id, session_date]
    ).answer_string.squish rescue 0

    return previous_patient_weight
  end

  def self.ever_had_dispensations(patient, session_date)
    dispensing_enc_type_id =  EncounterType.find_by_name('DISPENSING').id
    dispensation_encounters = patient.encounters.find(:all, :conditions => ["encounter_type =? AND
        (DATE(encounter_datetime) < ? OR DATE(encounter_datetime) > ?)", dispensing_enc_type_id, session_date, session_date])
    return true unless dispensation_encounters.blank?
    return false
  end

  def self.latest_outcome_date(patient)
    outcome_dates = []
    hiv_program_id = Program.find_by_name("HIV PROGRAM").id
    hiv_program = patient.patient_programs.find(:last, :conditions => ["program_id = ?", hiv_program_id])

    hiv_program.patient_states.each do |ps|
      outcome_dates << ps.start_date
    end rescue nil
    
    return outcome_dates.last
  end

  def self.states(patient)
    hiv_program_id = Program.find_by_name("HIV PROGRAM").id
    hiv_program = patient.patient_programs.find(:last, :conditions => ["program_id = ?", hiv_program_id])
    return hiv_program.patient_states
  end

  def self.has_inconsistency_outcome_dates?(patient)
    hiv_program_id = Program.find_by_name("HIV PROGRAM").id
    hiv_program = patient.patient_programs.find(:last, :conditions => ["program_id = ?", hiv_program_id])
    outcome_dates = hiv_program.patient_states.collect{|ps|[ps.start_date, ps.end_date]} rescue []
    inconsistency_outcome = false

    death_date = patient.person.death_date.to_date rescue patient.person.death_date
    outcome_dates.each do |dates|
      start_date = dates[0].to_date rescue dates[0]
      end_date = dates[1].to_date rescue dates[1]

      if start_date > end_date
        inconsistency_outcome = true
      end unless end_date.blank?

      unless death_date.blank?
        if death_date < start_date
          inconsistency_outcome = true
        end
      end

    end

    return inconsistency_outcome
  end

  def second_line_regimens
	  regimen_category = Concept.find_by_name("Regimen Category")

    regimen_observations = Observation.find(:all, :conditions => ["concept_id = ? AND
        person_id = ?", regimen_category.id, self.patient_id])

    second_line_regimen_indices = ["7A","8A","9P", "9A"]
    data = {}
    regimen_observations.each do |obs|
      regimen = obs.answer_string.squish.upcase rescue nil
      obs_datetime = obs.obs_datetime
      next if regimen.blank?
      if second_line_regimen_indices.include?(regimen.to_s)
        if data[regimen].blank?
          data[regimen] = {}
          data[regimen] = obs_datetime.to_date.strftime("%d/%b/%Y")
        end
      end
    end
    
    return data
  end

  def tb_status(encounter_datetime)
    tb_status_concept_id = ConceptName.find_by_name('TB STATUS').concept_id
    tb_obs = Observation.find(:last, :joins => [:encounter], :conditions => ["concept_id =? AND
        DATE(encounter_datetime) =? AND patient_id =?", tb_status_concept_id, encounter_datetime.to_date, self.patient_id])
    answer_string = tb_obs.answer_string.squish rescue ""
    return answer_string
  end

  def regimen(encounter_datetime)
    regimen_category_concept_id = Concept.find_by_name("Regimen Category").concept_id

    regimen_obs = Observation.find(:last, :joins => [:encounter], :conditions => ["concept_id =? AND
        DATE(encounter_datetime) =? AND patient_id =?", regimen_category_concept_id, encounter_datetime.to_date, self.patient_id]
    )
    answer_string = regimen_obs.answer_string.squish rescue ""
    return answer_string
  end

  def vl_result(encounter_datetime)
    identifiers = LabController.new.id_identifiers(self)
    national_ids = identifiers


    results = Lab.find_by_sql(["
        SELECT * FROM Lab_Sample s
        INNER JOIN Lab_Parameter p ON p.sample_id = s.sample_id
        INNER JOIN codes_TestType c ON p.testtype = c.testtype
        INNER JOIN (SELECT DISTINCT rec_id, short_name FROM map_lab_panel) m ON c.panel_id = m.rec_id
        WHERE s.patientid IN (?)
        AND short_name = ?
        AND s.deleteyn = 0
        AND s.attribute = 'pass'", national_ids, 'HIV_viral_load'
      ]).collect{ | result |result.Range.to_s + " " + result.TESTVALUE.to_s}
    
    return results
  end

  def adherence(encounter_datetime)
    drug_order_adherence_concept_id = Concept.find_by_name("DRUG ORDER ADHERENCE").concept_id

    regimen_obs = Observation.find(:last, :joins => [:encounter], :conditions => ["concept_id =? AND
        DATE(encounter_datetime) =? AND patient_id =?", drug_order_adherence_concept_id, encounter_datetime.to_date, self.patient_id]
    )
    answer_string = regimen_obs.answer_string.squish rescue ""
    return answer_string
  end

  def side_effects(encounter_datetime)
    side_effects_concept_id = Concept.find_by_name("MALAWI ART SIDE EFFECTS").concept_id
    symptom_present_conept_id = Concept.find_by_name("SYMPTOM PRESENT").concept_id

    side_effects_observations = self.person.observations.find(:all, :joins => [:encounter],
      :conditions => ["concept_id IN (?) AND DATE(encounter_datetime) =?",
        [side_effects_concept_id, symptom_present_conept_id], encounter_datetime.to_date]
    )

    side_effects = []
    side_effects_observations.each do |obs|
      next if !obs.obs_group_id.blank?
      child_obs = Observation.find(:last, :conditions => ["obs_group_id = ?", obs.obs_id])

      unless child_obs.blank?
        answer_string = child_obs.answer_string.squish
        next if answer_string.match(/NO/i)
        side_effects << child_obs.concept.fullname
      end
    end

    return side_effects.join(", ")
  end

  def hypertension(encounter_datetime)
    bp = self.current_bp(encounter_datetime.to_date)
    return "" if bp.blank?
    return bp[0].to_s + "/" + bp[1].to_s
  end
  
end
