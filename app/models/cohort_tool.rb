class CohortTool < ActiveRecord::Base
  set_table_name "encounter"
  
  def self.survival_analysis(survival_start_date=@start_date,
      survival_end_date=@end_date,
      outcome_end_date=@end_date, min_age=nil, max_age=nil)
    # Make sure these are always dates
    survival_start_date = survival_start_date.to_date
    survival_end_date = survival_end_date.to_date
    outcome_end_date = outcome_end_date.to_date

    date_ranges = Array.new
    first_registration_date = PatientRegistrationDate.find(:first,
      :order => 'registration_date').registration_date

    while (survival_start_date -= 1.year) >= first_registration_date
      survival_end_date   -= 1.year
      date_ranges << {:start_date => survival_start_date,
        :end_date   => survival_end_date
      }
    end

    survival_analysis_outcomes = Array.new

    date_ranges.each_with_index do |date_range, i|
      outcomes_hash = Hash.new(0)
      all_outcomes = self.outcomes(date_range[:start_date], date_range[:end_date], outcome_end_date, min_age, max_age)

      outcomes_hash["Title"] = "#{(i+1)*12} month survival: outcomes by end of #{outcome_end_date.strftime('%B %Y')}"
      outcomes_hash["Start Date"] = date_range[:start_date]
      outcomes_hash["End Date"] = date_range[:end_date]

      survival_cohort = Reports::CohortByRegistrationDate.new(date_range[:start_date], date_range[:end_date])
      if max_age.nil?
        outcomes_hash["Total"] = survival_cohort.patients_started_on_arv_therapy.length rescue all_outcomes.values.sum
      else
        outcomes_hash["Total"] = all_outcomes.values.sum
      end
      outcomes_hash["Unknown"] = outcomes_hash["Total"] - all_outcomes.values.sum
      outcomes_hash["outcomes"] = all_outcomes

      # if there are no patients registered in that quarter, we must have
      # passed the real date when the clinic opened
      break if outcomes_hash["Total"] == 0
      
      survival_analysis_outcomes << outcomes_hash 
    end
    survival_analysis_outcomes
  end

  def self.cohort(period)
    date_range = Report.generate_cohort_date_range(period)
    start_date = date_range[0] ; end_date = date_range[1]
    cohort = Cohort.new()

    cohort.total_registered = SurvivalAnalysis.report(cohort)
  end



  def self.total_on_pre_art(end_date = Date.today, regimen_ids=[])

    patients = []
    earliest_start_date = {}
    return if regimen_ids.blank?
    concept_name = ConceptName.find_all_by_name("Pre-art (continue)")
    state = ProgramWorkflowState.find( :first, :conditions => ["concept_id IN (?)",
        concept_name.map{|c|c.concept_id}]).program_workflow_state_id
    PatientProgram.find_by_sql(
      "SELECT p.patient_id, p.date_enrolled FROM patient_program p
          INNER JOIN person pe ON pe.person_id = p.patient_id
          INNER JOIN patient pa ON pe.person_id = pa.patient_id
					WHERE DATE(p.date_enrolled) <= '#{end_date}'
          AND DATE(p.date_completed) IS NULL
          AND pa.patient_id IN (#{regimen_ids})
          AND p.program_id = 1
          AND pa.voided = 0").each do | patient |
      earliest_start_date[patient.patient_id] = patient.date_enrolled
      patients << patient.patient_id
    end
		return patients.uniq, earliest_start_date

  end

  def self.patient_ids_with_regimens(end_date = @end_date, program_id=nil)
    patient_ids = []

    PatientProgram.find_by_sql("
                  SELECT DISTINCT(patient_id), patient_program_id FROM patient_program
                  WHERE program_id = #{program_id}
                  AND DATE(date_enrolled) <= '#{end_date}'
                  AND patient_id NOT IN (SELECT patient_id FROM earliest_start_date WHERE earliest_start_date <= '#{end_date}')
                  AND voided = 0
                  ORDER BY date_enrolled desc, patient_program_id DESC").each { |patient|
                    patient_ids << patient.patient_id
                  }

    return patient_ids.uniq
  end

  def self.confirmed_on_pre_art(end_date = Date.today, start_date=nil, regimen_ids=[])
    patients = []
    if start_date
      conditions = "AND DATE(date_enrolled) >= '#{start_date}'"
    end
    concept_id = ConceptName.find_all_by_name("Pre-art (continue)").first.concept_id
    state = ProgramWorkflowState.find( :first,
      :conditions => ["concept_id = '#{concept_id}'"]).program_workflow_state_id

    PatientProgram.find_by_sql(
      "SELECT e.patient_id, current_state_for_program(e.patient_id, 1, '#{end_date}') AS state
					FROM patient_program e
					WHERE DATE(date_enrolled) <= '#{end_date}' #{conditions}
          AND e.patient_id IN (#{regimen_ids})
					HAVING state = #{state}").each do | patient |
      patients << patient.patient_id
    end
		return patients

  end
  
  def self.defaulted_patients(start_date, end_date, regimen_ids=[])
    #PB 2015-09-24 : added e.voided = 0 to exclude voided patients
    #PB 2015-12-30 : added check for HIV program  and also those that are not Transfered Outs, dead or treatment_stopped
    CohortRevise.create_temp_earliest_start_date_table(end_date.to_date)
    CohortRevise.update_cum_outcome(end_date.to_date)
    
		patients = []
    unless regimen_ids.blank?
       conditions = "AND e.patient_id IN (#{regimen_ids})"
    end
		
    data = ActiveRecord::Base.connection.select_all <<EOF
    SELECT
    (SELECT identifier FROM patient_identifier i WHERE i.patient_id = e.patient_id
    AND i.voided = 0 AND i.identifier_type = #{PatientIdentifierType.find_by_name('ARV number').id} 
    ORDER BY date_created DESC limit 1) AS arv_number,
    e.*, o.cum_outcome FROM temp_earliest_start_date e 
    RIGHT JOIN temp_patient_outcomes o ON o.patient_id = e.patient_id
    WHERE date_enrolled <='#{end_date.to_date.strftime('%Y-%m-%d')}'
    AND cum_outcome = 'Defaulted' #{conditions};
EOF

    patient_data = {}

    #HIV encounter types: 
    hiv_encounter_types = ['HIV RECEPTION','HIV STAGING','VITALS','PART_FOLLOWUP','HIV CLINIC REGISTRATION',
    'DISPENSING','HIV CLINIC CONSULTATION','TREATMENT','ART ADHERENCE','APPOINTMENT']

    hiv_encounter_type_ids = EncounterType.find(:all, :conditions =>["name IN(?)", 
    hiv_encounter_types]).map(&:id)

    (data || []).each do |d|
      defaulted_date = PatientDefaultedDate.get_report_latest_defaulted_date(d['patient_id'].to_i, start_date.to_date, end_date.to_date)

      unless defaulted_date.blank?
        next if defaulted_date.to_date > end_date.to_date
      
        last_visit_date = Encounter.find(:first, :select => ("MAX(encounter_datetime) AS ldate"),
          :conditions =>["encounter_datetime <= ? AND patient_id = ? AND encounter_type IN(?)", end_date.to_date.strftime('%Y-%m-%d 23:59:59'), 
          d['patient_id'].to_i, hiv_encounter_type_ids])['ldate'].to_date rescue nil

        #next if last_visit_date > end_date.to_date
        #next if defaulted_date.to_date < last_visit_date

        names = PersonName.find(:first, :conditions =>["person_id = ? AND voided = 0", 
          d['patient_id'].to_i], :order => "date_created DESC, person_name_id DESC")

        unless names.blank?
          first_name = names.given_name #rescue nil
          last_name = names.family_name #rescue nil

          person_address = PersonAddress.find(:first, :conditions =>["person_id = ? AND voided = 0", 
           d['patient_id'].to_i], :order => "date_created DESC, person_address_id DESC")
          district = person_address.state_province rescue 'Unknown'
          village = person_address.city_village rescue 'Unknown'
          landmark = person_address.address1 rescue 'Unknown'

          patient_data[d['patient_id'].to_i] = {
            :arv_number => d['arv_number'],
            :earliest_start_date => (d['earliest_start_date'].to_date rescue nil),
            :date_enrolled => (d['date_enrolled'].to_date rescue nil),
            :birthdate => (d['birthdate'].to_date rescue nil),
            :gender => (d['gender']),
            :phone_number => self.get_phone(d['patient_id'].to_i),
            :death_date => (d['death_date'].to_date rescue nil),
            :outcome => d['cum_outcome'],
            :last_name => last_name, 
            :first_name => first_name,
            :district => district,
            :village => village,
            :landmark => landmark,
            :latest_defaulted_date => defaulted_date,
            :last_visit_date => (last_visit_date.strftime('%d/%b/%Y') rescue nil)
          }
        end
      end
    end
      
    return patient_data
	end

  def self.get_phone(patient_id)
    patient = Patient.find(patient_id)
    phone = PatientService.get_attribute(patient, "Cell phone number")

    if phone.nil?
      phone = PatientService.get_attribute(patient, "Home phone number")
      if phone.nil?
        phone = PatientService.get_attribute(patient, "Office phone number")
      end
    end
    return phone.nil? ? " " : phone
  end

  def self.outcomes_total(outcome, end_date=Date.today, regimen_ids = [], start_date = nil)

    concept_name = ConceptName.find_all_by_name(outcome)
    state = ProgramWorkflowState.find(
      :first,
      :conditions => ["concept_id IN (?)",
				concept_name.map{|c|c.concept_id}]
    ).program_workflow_state_id
		patients = []
    earliest_start_date = {}
    if ! regimen_ids.blank?
      conditions = "AND e.patient_id IN (#{regimen_ids})"
    end

    if ! start_date.blank?
      start_date = "AND earliest_start_date >= '#{start_date}'"
    end

		PatientProgram.find_by_sql("SELECT earliest_start_date, e.patient_id, current_state_for_program(e.patient_id, 1, '#{end_date}') AS state
 									FROM earliest_start_date e
									WHERE earliest_start_date <= '#{end_date}' #{start_date} #{conditions}
									HAVING state = #{state}").each do | patient |
      earliest_start_date[patient.patient_id] = patient.earliest_start_date
      patients << patient.patient_id
    end
		return patients, earliest_start_date
  end

  def self.exposed_on_pre_art(end_date = Date.today, start_date=nil)
    patients = []
    if start_date
      conditions = "AND DATE(e.date_enrolled) >= '#{start_date}'"
    end
    concept_name = ConceptName.find_all_by_name("Exposed Child (Continue)")
    state = ProgramWorkflowState.find( :first, :conditions => ["concept_id IN (?)", concept_name.map{|c|c.concept_id}]).program_workflow_state_id

    PatientProgram.find_by_sql(
      "SELECT e.patient_id, current_state_for_program(e.patient_id, 1, '#{end_date}') AS state
					FROM patient_program e
					LEFT JOIN start_date_observation sdo ON e.patient_id = sdo.person_id
          LEFT JOIN patient p ON e.patient_id = p.patient_id
					WHERE DATE(e.date_enrolled) <= '#{end_date}' #{conditions}
          AND p.voided = 0
					GROUP BY e.patient_id
					HAVING state = #{state}").each do | patient |
      patients << patient.patient_id
    end
		return patients

  end

  def self.registered(start_date, end_date, regimen_id=[])
    patients = []
    return if regimen_id.blank?
    concept_name = ConceptName.find_all_by_name("Pre-art (continue)")
    state = ProgramWorkflowState.find( :first, :conditions => ["concept_id IN (?)",
        concept_name.map{|c|c.concept_id}]).program_workflow_state_id

    PatientProgram.find_by_sql(
      "SELECT p.patient_id FROM patient_program p
          INNER JOIN person pe ON pe.person_id = p.patient_id
          INNER JOIN patient pa ON pe.person_id = pa.patient_id
					WHERE DATE(p.date_enrolled) <= '#{end_date}'
          AND DATE(p.date_enrolled) >= '#{start_date}'
          AND pa.patient_id IN (#{regimen_id})
          AND p.program_id = 1
          AND pa.voided = 0").each do | patient |
      patients << patient.patient_id
    end
=begin
     PatientProgram.find_by_sql(
						"SELECT e.patient_id, current_state_for_program(e.patient_id, 1, '#{end_date}') AS state,
					IF(ISNULL(MIN(sdo.value_datetime)), earliest_start_date, MIN(sdo.value_datetime)) AS initiation_date
					FROM earliest_start_date e
					LEFT JOIN start_date_observation sdo ON e.patient_id = sdo.person_id
          LEFT JOIN patient p ON e.patient_id = p.patient_id
					WHERE earliest_start_date >= '#{start_date}'
          AND p.voided = 0
          AND p.patient_id NOT IN (#{regimen_id})
          AND earliest_start_date <= '#{end_date}'
					GROUP BY e.patient_id").each do | patient |
							patients << patient.patient_id
					end
=end
		return patients.uniq

  end

  def self.male_total(patient_id)
    return [] if patient_id.blank?
    males = []
    (patient_id || []).each do |patient|
      current_patient = Person.find(patient).gender rescue "Unknown"
      if current_patient.upcase == "M" or current_patient.upcase == "MALE"
        males << patient
      end
    end
    return males
  end

  def self.female_non_pregnant(patient_ids)
    return [] if patient_ids.blank?
    females = []
    (patient_ids || []).each do |patient|
      current_patient = Person.find(patient).gender rescue "Unknown"
      if current_patient.upcase == "F" or current_patient.upcase == "FEMALE"
        females << patient
      end
    end
		return females
	end

  def self.infants_less_than_2_months(patient_ids)
    return [] if patient_ids.blank?
    infants = []
    (patient_ids || []).each do |patient|
      current_patient = Patient.find(patient) rescue "Unknown"
      unless current_patient == "Unknown"
        current_patient = PatientService.age_in_months(current_patient.person, current_patient.date_created)
        #if current_patient.upcase == "F" or current_patient.upcase == "FEMALE"
        infants << patient if current_patient.to_i < 2
      end
    end
		return infants
	end

  def self.infants_between_2_and_24_months(patient_ids)
    return [] if patient_ids.blank?
    infants = []
    (patient_ids || []).each do |patient|
      current_patient = Patient.find(patient) rescue "Unknown"
      unless current_patient == "Unknown"
        current_patient = PatientService.age_in_months(current_patient.person, current_patient.date_created)
        #if current_patient.upcase == "F" or current_patient.upcase == "FEMALE"
        infants << patient if current_patient.to_i >= 2 and current_patient.to_i < 24
      end
    end
		return infants
	end

  def self.infants_between_24months_and_14_years(patient_ids)
    return [] if patient_ids.blank?
    infants = []
    (patient_ids || []).each do |patient|
      current_patient = Patient.find(patient) rescue "Unknown"
      unless current_patient == "Unknown"
        current_months = PatientService.age_in_months(current_patient.person, current_patient.date_created)
        current_age = PatientService.age(current_patient.person, current_patient.date_created)
        #if current_patient.upcase == "F" or current_patient.upcase == "FEMALE"
        infants << patient if current_months.to_i >= 24 and current_age.to_i <= 14
      end
    end
		return infants
	end

  def self.adults(patient_ids)
    return [] if patient_ids.blank?
    adults = []
    
    (patient_ids || []).each do |patient|
      current_patient = Patient.find(patient) rescue "Unknown"

      unless current_patient == "Unknown"
        current_age = PatientService.age(current_patient.person, current_patient.date_created)
        #if current_patient.upcase == "F" or current_patient.upcase == "FEMALE"
        adults << patient if current_age.to_i > 14
      end
    end
		return adults
	end

  def self.pregnant_women(patient_ids, end_date = Date.today, start_date = nil)
    return [] if patient_ids.blank?
    if start_date
      conditions = "AND DATE(p.date_enrolled) >= '#{start_date}'"
    end
    patients = []
    PatientProgram.find_by_sql("SELECT patient_id, o.obs_datetime
				FROM patient_program p
			  INNER JOIN patient_pregnant_obs o ON p.patient_id = o.person_id
				WHERE DATE(p.date_enrolled) <= '#{end_date}' #{conditions}
        AND p.patient_id IN (#{patient_ids})
				AND DATEDIFF(o.obs_datetime, p.date_enrolled) <= 30
				AND DATEDIFF(o.obs_datetime, p.date_enrolled) > -1
        GROUP BY patient_id").each do | patient |
			patients << patient.patient_id
		end
    return patients
  end

  def self.patients_initiated_on_pre_art_first_time(patient_ids, end_date, start_date = nil )
    patients = []
    if ! start_date.blank?
      conditions = "AND DATE(obs_datetime) >= '#{start_date}'"
    end
    concept = ConceptName.find_by_name("Ever registered at ART clinic").concept_id
    concept_answer = ConceptName.find_by_name("NO").concept_id
    with = []
    without = []
    Observation.find_by_sql("SELECT distinct(person_id) , concept_id, value_coded
                             FROM obs
                             WHERE voided = 0
                             AND person_id IN (#{patient_ids})
                             AND DATE(obs_datetime) <= '#{end_date}' #{conditions}").each do | patient |

      if patient.concept_id == concept
        if patient.value_coded == concept_answer
          without << patient.person_id
        else
          with << patient.person_id
        end

      else
        without << patient.person_id
      end
		end

    patients = without.uniq - with.uniq
    return patients.uniq
  end

  def self.patients_reinitiated_on_pre_art(patient_ids, end_date, start_date = nil )
    patients = []
		if start_date
      conditions = "AND DATE(obs_datetime) >= '#{start_date}'"
    end
    encounter_id = EncounterType.find_by_name('HIV clinic registration').id
    concept = ConceptName.find_by_name("Ever registered at ART clinic").concept_id
    concept_answer = ConceptName.find_by_name("YES").concept_id

    Observation.find_by_sql("SELECT person_id FROM obs o
                             INNER JOIN encounter e ON e.encounter_id = o.encounter_id
                             WHERE concept_id = #{concept}
                             AND o.value_coded = #{concept_answer}
                             AND e.encounter_type = #{encounter_id}
                             AND o.voided = 0
                             AND person_id IN (#{patient_ids})
                             AND DATE(obs_datetime) <= '#{end_date}' #{conditions}
                             ORDER BY MAX(e.encounter_datetime) DESC").each do | person |
			next if patients.include?(person.person_id)
      patients << person.person_id
		end
  end

  def self.patients_transferred_in(patient_ids, end_date, start_date = nil )
    patients = []
		if start_date
      conditions = "AND DATE(obs_datetime) >= '#{start_date}'"
    end
    concept = ConceptName.find_by_name("has transfer letter").concept_id
    concept_answer = ConceptName.find_by_name("YES").concept_id

    Observation.find_by_sql("SELECT distinct(person_id) FROM obs
                             WHERE concept_id = #{concept}
                             AND value_coded = #{concept_answer}
                             AND voided = 0
                             AND person_id IN (#{patient_ids})
                             AND DATE(obs_datetime) <= '#{end_date}' #{conditions}").each do | patient |
			patients << patient.person_id
		end
  end
end
