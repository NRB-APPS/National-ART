require 'fastercsv'
User.current = User.find_by_username('admin')
ScriptStared = Time.now()

Hiv_reception_encounter = EncounterType.find_by_name("Hiv reception")
Vitals = EncounterType.find_by_name("Vitals")
HIV_staging = EncounterType.find_by_name("HIV staging")
Treatment = EncounterType.find_by_name("TREATMENT")
Dispension = EncounterType.find_by_name("DISPENSING")
Encounter_id = Encounter.last
Order_id = Order.last
Appointment = EncounterType.find_by_name("APPOINTMENT")
HIV_clinic_consultation = EncounterType.find_by_name("HIV CLINIC CONSULTATION")

Source_path = '/home/deliwe/Desktop/Work/Fuchia/msf'
Destination_path = '/home/deliwe/Desktop/Work/Fuchia/msf/msf_sql/'

@@staging_conditions = []
@@patient_visits = {}
@@drug_map = {}
@@drug_follow_up = {}

def start
  obs =  "INSERT INTO obs (person_id, encounter_id, concept_id, value_numeric,value_coded, value_datetime,value_drug, order_id, obs_datetime, creator, uuid) VALUES "
  encounter =  "INSERT INTO encounter (encounter_id, encounter_type, patient_id, provider_id, encounter_datetime, creator, uuid) VALUES "
  order = "INSERT INTO orders (order_id, order_type_id, orderer, concept_id, encounter_id, start_date, auto_expire_date, creator, date_created, patient_id, uuid) VALUES "
  drug_order = "INSERT INTO drug_order (order_id, drug_inventory_id, dose, equivalent_daily_dose, units, frequency, quantity) VALUES "

  `touch #{Destination_path}encounters.sql && echo -n '#{encounter}' >> #{Destination_path}encounters.sql`
  `touch #{Destination_path}observations.sql && echo -n '#{obs}' >> #{Destination_path}observations.sql`
  `touch #{Destination_path}orders.sql && echo -n '#{order}' >> #{Destination_path}orders.sql`
  `touch #{Destination_path}drug_orders.sql && echo -n '#{drug_order}' >> #{Destination_path}drug_orders.sql`

  if Encounter_id.blank?
    encounter_id = 1
  else
    encounter_id = Encounter_id.id + 1
  end

  if Order_id.blank?
    order_id = 1
  else
    order_id = Order_id.id.to_i + 1
  end

  FasterCSV.foreach("#{Source_path}/tb_follow_up.csv", :headers => true, :quote_char => '"', :col_sep => ',', :row_sep => :auto) do |row|
    patient_id = row[3].to_i
    date_created = get_proper_date(row[9]).to_date rescue nil
    next_visit = get_proper_date(row[10]).to_date rescue nil
    ref_id = row[0].to_i
    next if date_created.blank? || patient_id.blank?
    start_date = date_created.strftime("%Y-%m-%d 00:00:00")
    end_date = date_created.strftime("%Y-%m-%d 23:59:59")
    begin
      patient = Patient.find(patient_id)
    rescue
      ############## code to log errors ########
      next
    end
    encounter = Encounter.find(:all, :conditions => ["patient_id = ? and encounter_datetime
     between ? and ? and encounter_type = ?",patient_id, start_date, end_date,
     Hiv_reception_encounter.id])

    if encounter.blank?
      puts ">>>#{encounter_id} ############# HIV Clinic reception for #{patient_id}"
      self.create_hiv_reception(encounter_id, patient_id, date_created)
      encounter_id = encounter_id.to_i + 1
    else
      puts "Patient has encounters recorded!!"
    end

    ############################### creating vitals ###########################################
    weight = row[28].to_f rescue nil
    height = row[29].to_f rescue nil
    vitals_encounter = nil

    puts ">>>#{encounter_id} ############# Vitals for #{patient_id}"
    unless weight.blank?
      vitals_encounter = self.create_encounter(encounter_id, patient_id, Vitals.id, date_created)
      self.create_observation_value_numeric(vitals_encounter, "Weight (kg)", weight)
      encounter_id = encounter_id.to_i + 1
    end

    unless height.blank?
      vitals_encounter = self.create_encounter(encounter_id, patient_id, Vitals.id, date_created) if vitals_encounter.blank?
      self.create_observation_value_numeric(vitals_encounter, "Height (cm)", height)
      encounter_id = encounter_id.to_i + 1 if vitals_encounter.blank?
    end
    ###########################################################################################

    diagnostic = row[30] rescue nil
    diagnostic_2 = row[31] rescue nil
    cd4_count = row[23].to_i
    date_cd4_count = get_proper_date(row[14]).to_date unless row[14].blank?

    ############################ hiv staging and clinical consultation #########################
    s_c = @@patient_visits[ref_id] rescue []

    hiv_staging_encounter = Encounter.find(:last, :conditions => ["patient_id = ? and encounter_datetime <= ?
    and encounter_type = ?",patient_id, end_date, HIV_staging.id])

    if hiv_staging_encounter.blank?

      puts ">>>#{encounter_id} ############# HIV Staging for #{patient_id}"

      hiv_staging_encounter = self.create_encounter(encounter_id, patient_id, HIV_staging.id, date_created) if hiv_staging_encounter.blank?
      encounter_id = encounter_id + 1
      (s_c || []).each do |cond|
        self.create_observation_value_coded(hiv_staging_encounter, "WHO Stage defining conditions not explicitly asked adult", cond)
      end
      encounter_id = encounter_id + 1
    end
=begin
  if diagnostic_2.match(/preg/i) || diagnostic.match(/preg/i)
    self.create_observation_value_coded(hiv_staging_encounter, 'Pregnant', 'Yes')
  end rescue nil
=end
    if !cd4_count.blank? && !date_cd4_count.blank?
      self.create_observation_value_numeric(hiv_staging_encounter, 'CD4 count', cd4_count)
      self.create_observation_value_datetime(hiv_staging_encounter, 'Date of CD4 count', date_cd4_count)
    end rescue nil

    puts ">>>#{encounter_id} ############# Clinic consultation for #{patient_id}"

    hiv_clinic_registration_encounter = self.create_encounter(encounter_id, patient_id, HIV_clinic_consultation.id, date_created)
    encounter_id = encounter_id + 1

    if diagnostic_2.match(/preg/i) || diagnostic.match(/preg/i)
      self.create_observation_value_coded(hiv_clinic_registration_encounter, 'Pregnant', 'Yes')
    end rescue nil

    if diagnostic_2.match(/NEUROPATH/i) || diagnostic.match(/NEUROPATH/i)
      self.create_observation_value_coded(hiv_clinic_registration_encounter,'MALAWI ART SIDE EFFECTS', 'Peripheral neuropathy')
    end rescue nil

    if diagnostic_2.match(/anaemia/i) || diagnostic.match(/anaemia/i)
      self.create_observation_value_coded(hiv_clinic_registration_encounter, 'MALAWI ART SIDE EFFECTS', 'Anemia')
    end rescue nil

    if diagnostic_2.match(/jaundice/i) || diagnostic.match(/jaundice/i)
      self.create_observation_value_coded(hiv_clinic_registration_encounter,'MALAWI ART SIDE EFFECTS', 'Jaundice')
    end rescue nil

    if diagnostic_2.match(/psychosis/i) || diagnostic.match(/psychosis/i)
      self.create_observation_value_coded(hiv_clinic_registration_encounter, 'MALAWI ART SIDE EFFECTS','Psychosis')
    end rescue nil

          # >>>>>>>>>>>>>>>>>>> Associated symptoms <<<<<<<<<<<<<<<<<<<<< #
    if diagnostic_2.match(/cough/i) || diagnostic.match(/cough/i)
      self.create_observation_value_coded(hiv_clinic_registration_encounter, 'TB symptoms', 'Cough')
    end rescue nil

    if diagnostic_2.match(/fever/i) || diagnostic.match(/fever/i)
      self.create_observation_value_coded(hiv_clinic_registration_encounter, 'TB symptoms',  'Fever')
    end rescue nil

    if diagnostic_2.match(/malnutrition/i) || diagnostic.match(/malnutrition/i) || diagnostic_2(/failure to thrive/i) || diagnostic(/failure to thrive/i) || diagnostic_2(/weight loss/i) || diagnostic(/weight loss/i)
      self.create_observation_value_coded(hiv_clinic_registration_encounter, 'TB symptoms',  'Weight loss / Failure to thrive / malnutrition')
    end rescue nil

    ##########################################################################################

    medication_on_this_visit = @@drug_follow_up[ref_id] rescue nil

    ############################ treatment and dispensation ##################################################

    puts "#{encounter_id} ##################### Treatment for #{patient_id}"

    treatment_encounter = self.create_encounter(encounter_id, patient_id, Treatment.id, date_created)
    encounter_id = encounter_id + 1

    puts "#{encounter_id} ##################### Dispensation for #{patient_id}"

    dispensing_encounter = self.create_encounter(encounter_id, patient_id, Dispension.id, date_created)
    encounter_id = encounter_id + 1

    (medication_on_this_visit || []).each do |medications|

      (medications || []).each do |medication|
        medication = "Aspirin (300mg tablet)" if medication.match(/Unknown/i)

        drug = Drug.find_by_name(medication)

        if next_visit.blank?
          n_visit = (date_created.to_date + 28.day).to_date
        else
          n_visit = next_visit
        end
        puts "#####{medication}"
        drug_id = drug.id

        self.create_order(order_id, treatment_encounter, date_created, n_visit, drug_id)

        weight_during_visit = PatientService.get_patient_attribute_value(patient, "current_weight", date_created)
        age_during_visit = (date_created.year - patient.person.birthdate.year).to_i

        if weight_during_visit.blank?
          if age > 18
            weight_during_visit = 50.0
          elsif age >= 14 and age <= 18
            weight_during_visit = 35.0
          elsif age >= 10 and age < 14
            weight_during_visit = 20.0
          elsif age >= 5 and age < 10
            weight_during_visit = 15.0
          else
            weight_during_visit = 5.0
          end
        end

        regimens = Regimen.find(:all, :conditions => ["#{weight_during_visit} >= FORMAT(min_weight,2) and #{weight_during_visit} <= FORMAT(max_weight,2)"])
        regimen_drug_order = ""
        regimens.each do |regimen|
          regimen_drug_order = RegimenDrugOrder.find(:first, :conditions => ["regimen_id = #{regimen.regimen_id} AND drug_inventory_id = ?", drug_id])
          if !regimen_drug_order.blank?
            break
          end
        end

        if regimen_drug_order.blank?
          drug_frequency = "ONCE A DAY"
          dose = "1.0"
          units = "tab(s)"
        else
          drug_frequency = regimen_drug_order.frequency
          dose = regimen_drug_order.dose
          units = regimen_drug_order.units
        end
=begin
      moh_regimen_doses = MohRegimenDoses.find(:first,
        :joins =>"INNER JOIN moh_regimen_ingredient i ON i.dose_id = moh_regimen_doses.dose_id",
        :conditions => ["drug_inventory_id = ? AND #{weight_during_visit.to_f} >= FORMAT(min_weight,2)
      AND #{weight_during_visit.to_f} <= FORMAT(max_weight,2)", drug.id])
=end
        if dose.blank?
          pills_per_day = 1.0
        else
          if drug_frequency.match(/ONCE A DAY/i) || drug_frequency.match(/IN THE EVENING/i) || drug_frequency.match(/IN THE MORNING/i)
            pills_per_day = dose
          elsif drug_frequency.match(/TWICE/i)
            pills_per_day = dose.to_i * 2
          end
        end

        duration = (n_visit - date_created).to_i
        quantity = (duration * pills_per_day.to_i)
      # pill_given = DrugOrder.calculate_complete_pack(drug, quantity)

        self.create_drug_order(order_id, drug_id, dose, pills_per_day, units, drug_frequency, quantity)
        self.create_observation_value_drug(dispensing_encounter, "Amount dispensed", drug_id, quantity, order_id)
        order_id = order_id + 1
      # medication_pills_dispensed[drug.id] = pill_given

      end
=begin
      if moh_regimen_doses.blank?
        pills_per_day = 1.0
      else
        pills_per_day = (moh_regimen_doses.am.to_f + moh_regimen_doses.pm.to_f).to_f
        puts "******************************* #{pills_per_day}"
      end

      duration = (date_created - n_visit).to_i
      units = (duration * pills_per_day)
      pill_given = DrugOrder.calculate_complete_pack(drug, units)

      medication_pills_dispensed[drug.id] = pill_given
      #puts "............. #{medication_pills_dispensed[drug.id]}"
=end
    end

    ##########################################################################################

    ################################ set appointment #########################################
    if !next_visit.blank?
      puts ">>>#{encounter_id} ############# Appointment for: #{patient_id}"
      appointment_encounter = self.create_encounter(encounter_id, patient_id, Appointment.id, date_created)
      encounter_id = encounter_id + 1
      self.create_observation_value_datetime(appointment_encounter, "Appointment date", next_visit)
    end
    ##########################################################################################

  end
  puts "...............please wait............"
  encounter_sql = File.read("#{Destination_path}encounters.sql")[0...-1]
  File.open("#{Destination_path}encounters.sql", "w") {|sql| sql.puts encounter_sql << ";"}

  observation_sql = File.read("#{Destination_path}observations.sql")[0...-1]
  File.open("#{Destination_path}observations.sql", "w") {|sql| sql.puts observation_sql << ";"}

  order_sql = File.read("#{Destination_path}orders.sql")[0...-1]
  File.open("#{Destination_path}orders.sql", "w") {|sql| sql.puts order_sql << ";"}

  drug_order_sql = File.read("#{Destination_path}drug_orders.sql")[0...-1]
  File.open("#{Destination_path}drug_orders.sql", "w") {|sql| sql.puts drug_order_sql << ";"}

  puts "Script time: #{ScriptStared} - #{Time.now()}"
end

#function that loads csv file data into a hash
def get_references(parent_path, ref_id)
  FasterCSV.foreach("#{parent_path}/TbReference.csv", :headers => true, :quote_char => '"', :col_sep =>',', :row_sep =>:auto) do |row|
    if row[0].to_i.equal?(ref_id.to_i)
     return row[6]
    end
  end
end

#function that patient_drug csv to a hash
def get_patient_drug(parent_path, patient_id)
  count = 0
  drug_ref = Array.new
  FasterCSV.foreach ("#{parent_path}/TbPatientDrug.csv", :headers =>true, :quote_char => '"', :col_sep => ',', :row_sep =>:auto) do |row|
    if row[3].to_i.equal?(patient_id.to_i)
      drug_ref.insert(count,row[4])
      count = count + 1
    end
  end
  return drug_ref
end

def self.create_hiv_reception(enc_id, patient_id, date_created)
  encounter = self.create_encounter(enc_id, patient_id, Hiv_reception_encounter.id, date_created)
  if !encounter.blank?
    self.create_observation_value_coded(encounter,  "Guardian present", "No")
    self.create_observation_value_coded(encounter, "Patient present", "Yes")
  end
end

def self.create_encounter(encounter_id, patient_id, encounter_type_id, date_created)
  if !patient_id.blank?
    encounter = Encounter.new
    encounter.id = encounter_id
    encounter.encounter_type = encounter_type_id
    encounter.patient_id = patient_id
    encounter.encounter_datetime = date_created.strftime("%Y-%m-%d 00:00:00")

    uuid = ActiveRecord::Base.connection.select_one <<EOF
     select uuid();
EOF
    date_created =date_created.strftime("%Y-%m-%d 00:00:00")

    insert_encounters = "(\"#{encounter_id}\",\"#{encounter_type_id}\",\"#{patient_id}\",\"#{User.current.id}\",\"#{date_created}\","
    insert_encounters += "\"#{User.current.id}\",\"#{uuid.values.first}\"),"

    `echo -n '#{insert_encounters}' >> #{Destination_path}encounters.sql`
  end

  return encounter
end

def self.create_observation_value_numeric(encounter, concept_name, value)
    concept_id = ConceptName.find_by_name(concept_name).concept_id

    uuid = ActiveRecord::Base.connection.select_one <<EOF
     select uuid();
EOF

    insert_observation = "(#{encounter.patient_id},#{encounter.id},#{concept_id},"
    insert_observation += "\"#{value}\",null,null,null,null,\"#{encounter.encounter_datetime.strftime("%Y-%m-%d 00:00:00")}\","
    insert_observation += "\"#{User.current.id}\",\"#{uuid.values.first}\"),"

    `echo -n '#{insert_observation}' >> #{Destination_path}observations.sql`
end

def self.create_observation_value_coded(encounter, concept_name, value_coded_concept_name)
    concept_id = ConceptName.find_by_name(concept_name).concept_id
    value_coded = ConceptName.find_by_name(value_coded_concept_name).concept_id

    uuid =ActiveRecord::Base.connection.select_one <<EOF
     select uuid();
EOF
    insert_observation_value_coded = "(#{encounter.patient_id},#{encounter.id},#{concept_id},null,"
    insert_observation_value_coded += "\"#{value_coded}\",null,null,null,\"#{encounter.encounter_datetime.strftime("%Y-%m-%d 00:00:00")}\","
    insert_observation_value_coded += "\"#{User.current.id}\",\"#{uuid.values.first}\"),"

    `echo -n '#{insert_observation_value_coded}' >> #{Destination_path}observations.sql`
end

def self.create_observation_value_datetime(encounter, concept_name, date)
    concept_id = ConceptName.find_by_name(concept_name).concept_id

    uuid =ActiveRecord::Base.connection.select_one <<EOF
     select uuid();
EOF
    insert_observation_value_datetime = "(#{encounter.patient_id},#{encounter.id},#{concept_id},null,null,"
    insert_observation_value_datetime += "\"#{date.strftime("%Y-%m-%d %H:%M:%S")}\",null,null,\"#{encounter.encounter_datetime.strftime("%Y-%m-%d 00:00:00")}\","
    insert_observation_value_datetime += "\"#{User.current.id}\",\"#{uuid.values.first}\"),"

    `echo -n '#{insert_observation_value_datetime}' >> #{Destination_path}observations.sql`
end

def self.create_observation_value_drug(encounter, concept_name, value_drug, drug_amount, order_id)
    concept_id = ConceptName.find_by_name(concept_name).concept_id

    uuid =ActiveRecord::Base.connection.select_one <<EOF
     select uuid();
EOF
    insert_observation_value_coded = "(#{encounter.patient_id},#{encounter.id},#{concept_id},#{drug_amount},"
    insert_observation_value_coded += "null,null,#{value_drug},#{order_id},\"#{encounter.encounter_datetime.strftime("%Y-%m-%d 00:00:00")}\","
    insert_observation_value_coded += "\"#{User.current.id}\",\"#{uuid.values.first}\"),"

    `echo -n '#{insert_observation_value_coded}' >> #{Destination_path}observations.sql`
end

def self.create_order(order_id, encounter, start_date, end_date, drug_id)

    uuid =ActiveRecord::Base.connection.select_one <<EOF
      select uuid();
EOF
    insert_order = "(#{order_id},1,#{User.current.id},#{drug_id},#{encounter.id},\"#{start_date.strftime("%Y-%m-%d 00:00:00")}\","
    insert_order += "\"#{end_date.strftime("%Y-%m-%d 00:00:00")}\",#{User.current.id},\"#{encounter.encounter_datetime.strftime("%Y-%m-%d 00:00:00")}\","
    insert_order += "#{encounter.patient_id},\"#{uuid.values.first}\"),"

    `echo -n '#{insert_order}' >> #{Destination_path}orders.sql`

    return order_id
end

def self.create_drug_order(order_id, drug_id, dose, pills_per_day, units, drug_frequency, quantity)

    insert_drug_order = "(#{order_id},#{drug_id},#{dose},#{pills_per_day},\"#{units}\",\"#{drug_frequency}\",#{quantity}),"

    `echo -n '#{insert_drug_order}' >> #{Destination_path}drug_orders.sql`
end

def get_proper_date (unfomatted_date)
  if !unfomatted_date.blank?
    unfomatted_date = unfomatted_date.split("/")
    year_of_birth = unfomatted_date[2].split(" ")
    year_of_birth = year_of_birth[0]
    current_year = Date.today.year.to_s

    if year_of_birth.to_i > current_year[-2..-1].to_i
      year = "19#{year_of_birth}"
    else
      year = "20#{year_of_birth}"
    end

    fomatted_date = "#{year}-#{unfomatted_date[0]}-#{unfomatted_date[1]}"
  else
    return nil
  end
end

def setup_staging_conditions

  @@conditions_map = {"Weight loss >10%" => 'Severe weight loss >10% and/or BMI <18.5kg/m^2, unexplained',
    	"Fever, unexplained" => 'Fever, persistent unexplained, intermittent or constant, >1 month',
    	"In bed > 50 of normal daytime due to sickness" => 'Unknown',
   	  "Kaposi sarcoma" => 'Kaposi sarcoma',
	    "Herpes zoster" => 'Herpes zoster',
	    "Wasting syndrome by HIV/stunting/severe malnutrition" => 'HIV wasting syndrome (severe weight loss + persistent fever or severe weight loss + chronic diarrhoea)',
	    "Minor mucocutaneous manifestations" => 'Minor mucocutaneous manifestations',
	    "Weight loss <10%" => 'Moderate weight loss less than or equal to 10 percent, unexplained',
	    "Pulmonary TB" => 'Pulmonary TB (current)',
	    "URTI" => 'URTI',
	    "Diarrhoea unexplained" => 'Diarrhoea, chronic (>1 month) unexplained',
	    "Oral candidiasis" => 'Oral candidiasis',
	    "Bacterial pneumonia, severe" => 'Bacterial pneumonia, severe recurrent',
    	"Asymptomatic" => 'Asymptomatic',
    	"Extrapulmonary and disseminated TB" => 'Extrapulmonary tuberculosis (EPTB)',
    	"Bacterial infections, severe" => 'Bacterial infections, severe recurrent  (empyema, pyomyositis, meningitis, bone/joint infections but EXCLUDING pneumonia)',
    	"Candidiasis oesophagus/trachea/bronchi /lungs" => 'Candidiasis of oseophagus',
    	"Cryptococcosis extrapulmonary" => 'Cryptococcosis, extrapulmonary',
    	"Vulvovaginal candidiasis > 1 month..." => 'Candidiasis vulvovaginal',
    	"In bed < 50 of normal daytime due to sickness" => 'Unknown',
    	"Oral hairy leukoplakia" => 'Oral hairy leukoplakia',
    	"Herpes simplex infection" => 'Herpes simplex',
    	"Encephalopathy by HIV" => 'Encephalopathy HIV',
    	"Lymphoma cerebral or B non Hodgkin" => 'Lymphoma (cerebral or B-cell non hodgkin)',
    	"Cytomegalovirus infection" => 'Cytomegalovirus infection',
    	"Mycosis disseminated" => 'Disseminated mycosis (coccidiomycosis or histoplasmosis)',
    	"Toxoplasmosis of the brain" => 'Toxoplasmosis of the brain',
    	"Septicaemia recurrent" => 'Unknown',
    	"HIV-associated nephropathy" => 'HIV associated nephropathy',
    	"Pneumocystis pneumonia" => 'Pneumocystis pneumonia',
    	"Angular cheilitis" => 'Angular cheilitis',
    	"Isosporiasis" => 'Isosporiasis',
    	"Seborrheic dermatitis" => 'Seborrhoeic dermatitis',
    	"Wart infection" => 'Wart virus infection',
    	"Papular pruritic eruption" => 'Papular pruritic eruptions',
      "Malnutrition moderate" => 'Malnutrition',
      "Progressive multifocal leukoencephalopathy" => 'Progressive multifocal leukoencephalopathy',
      "Unexplained anaemia/neutropenia/trombocytopenia" => 'Unexplained anaemia, neutropaenia, or throbocytopaenia',
      "Acute necrotizing ulcerative stomatitis" => ' Acute necrotizing ulcerative stomatitis, gingivitis or periodontitis',
      "Oral ulcerations" => 'Oral ulcerations, recurrent',
      "Persistent generalized lymphadenopathy" => 'Persistent generalized lymphadenopathy'
  }

  conditions = []

  FasterCSV.foreach("#{Source_path}/TbFollowUpDiagnosis.csv", :headers => true, :quote_char => '"', :col_sep => ',', :row_sep => :auto) do |row|
    conditions << row[4].to_i
    conditions = conditions.uniq
  end
=begin
  FasterCSV.foreach("#{Source_path}/TbPatientDiagnosis.csv", :headers => true, :quote_char => '"', :col_sep => ',', :row_sep => :auto) do |row|
    patient_id = row[3].to_i
    date_created = get_proper_date(row[1]).to_date rescue nil
    next if date_created.blank?

    if @@patient_visits[patient_id].blank?
      @@patient_visits[patient_id] = {}
      @@patient_visits[patient_id][date_created] = []
   else
      if @@patient_visits[patient_id][date_created].blank?
        @@patient_visits[patient_id][date_created] = []
      end
   end
   @@patient_visits[patient_id][date_created] << @@conditions_map[get_references(Source_path,row[4])]
   @@patient_visits[patient_id][date_created] = @@patient_visits[patient_id][date_created].uniq
  end
=end
  FasterCSV.foreach("#{Source_path}/TbFollowUpDiagnosis.csv", :headers => true, :quote_char => '"', :col_sep => ',', :row_sep => :auto) do |row|
    follow_up_reference = row[3].to_i

    if @@patient_visits[follow_up_reference].blank?
      @@patient_visits[follow_up_reference] = []
    end
    @@patient_visits[follow_up_reference] << @@conditions_map[get_references(Source_path, row[4])]
    @@patient_visits[follow_up_reference] = @@patient_visits[follow_up_reference].uniq
  end
end

def drug_mapping
  @@drug_map = {
    "Cotrimoxazole prophylaxis" => ['Cotrimoxazole (960mg)'],
    "FDC3 (AZT-3TC-NVP)" => ['AZT/3TC (Zidovudine and Lamivudine 300/150mg)'],
    "Efavirenz 600" => ['EFV (Efavirenz 600mg tablet)'],
    "Isoniazide prophylaxis" => ['INH or H (Isoniazid 100mg tablet)'],
    "FDC11 (TDF-3TC-EFV)" => ['TDF/3TC/EFV (300/300/600mg tablet)'],
    "FDC1 (D4T30-3TC-NVP)" => ['d4T/3TC (Stavudine Lamivudine 30/150 tablet)','NVP (Nevirapine 200 mg tablet)'],
    "Lamivudine" => ['3TC (Lamivudine 150mg tablet)'],
    "Stavudine (dosage unspecified)" => ['d4T (Stavudine 30mg tablet)'],
    "Nevirapine" => ['NVP (Nevirapine 200 mg tablet)'],
    "FDC2 pediatric (AZT-3TC-NVPp)" => ['AZT/3TC/NVP (60/30/50mg tablet)'],
    "FDC10 (TDF-3TC)" => ['TDF/3TC (Tenofavir and Lamivudine 300/300mg tablet'],
    "Atazanavir/Ritonavir" => ['ATV/r (Atazanavir 300mg/Ritonavir 100mg)'],
    "FDC2 (D4T40-3TC-NVP)" => ['Triomune-40'],
    "FDC5 (D4T30-3TC)" => ['Triomune-30'],
    "Dapsone prophylaxis" => ['Dapsone (100mg tablet)'],
    "Kaletra (Lopinavir/Ritonavir) pediatric" => ['LPV/r (Lopinavir and Ritonavir 100/25mg tablet)'],
    "FDC5 pediatric (ABC-3TCp)" => ['ABC/3TC (Abacavir and Lamivudine 60/30mg tablet)'],
    "FDC7 (AZT-3TC)" => ['AZT/3TC (Zidovudine and Lamivudine 300/150mg)'],
    "Fluconazole secondary prophylaxis" => ['Fluconazole (200mg tablet)'],
    "FDC4 pediatric (AZT-3TCp)" => ['AZT/3TC (Zidovudine and Lamivudine 60/30 tablet)'],
    "Stavudine 30" => ['d4T (Stavudine 30mg tablet)'],
    "FDC1 pediatric (D4T30-3TC-NVPp)" => ['Triomune baby (d4T/3TC/NVP 6/30/50mg tablet)'],
    "Kaletra (Lopinavir/Ritonavir)" => ['LPV/r (Lopinavir and Ritonavir 200/50mg tablet)'],
    "Efavirenz pediatric" =>['EFV (Efavirenz 50mg tablet)'],
    "Nevirapine pediatric" => ['NVP (Nevirapine 50 mg tablet)'],
    "Lamivudine pediatric" => ['3TC (Lamivudine syrup 10mg/mL from 100mL bottle)'],
    "Abacavir pediatric" => ['Unknown'],
    "Ritonavir" => ['Ritonavir 100mg'],
    "Darunavir" => ['Darunavir 600mg'],
    "Raltegravir" => ['RAL (Raltegravir 400mg)'],
    "Abacavir" => ['ABC (Abacavir 300mg tablet)'],
    "Fluconazole primary prophylaxis" => ['FCZ (Fluconazole 150mg tablet)'],
    "Tenofovir" => ['TDF (Tenofavir 300 mg tablet)'],
    "FDC3 pediatric (D4T30-3TCp)" =>  ['d4T/3TC (Stavudine Lamivudine 30/150 tablet)'],
    "Zidovudine" => ['AZT (Zidovudine 300mg tablet)'],
    "FDC12 (TDF-3TC-NVP)" => ['TDF/3TC (Tenofavir and Lamivudine 300/300mg tablet'],
    "Nelfinavir" => ['NFV(Nelfinavir)'],
    "Didanosine 250" => ['DDI (Didanosine 125mg tablet)'],
    "Zidovudine (Mother to child)" => ['AZT (Zidovudine 300mg tablet)'],
    "Nevirapine (Mother to child)" => ['NVP (Nevirapine 200 mg tablet)'],
    "Didanosine 400" => ['DDI (Didanosine 200mg tablet)'],
    "Other ARV 2" => ['Unknown'],
    "Zidovudine pediatric" => ['AZT (Zidovudine 100mg tablet)'],
    "FDC6 (D4T40-3TC)" => ['d4T/3TC (Stavudine Lamivudine 30/150 tablet)'],
    "Other ARV 1" => ['Unknown'],
    "Stavudine pediatric" => ['d4T (Stavudine 30mg tablet)'],
    "Stavudine 40" => ['d4T (Stavudine 40mg tablet)'],
    "Nelfinavir pediatric" => ['NFV(Nelfinavir)'],
    "Efavirenz 800" => ['EFV (Efavirenz 600mg tablet)'],
    "Atazanavir" => ['ATV/(Atazanavir)'],
    "NVP Single Dose + (AZT-3TC) regimen (Mother to child)" => ['AZT/3TC (Zidovudine and Lamivudine 300/150mg)','NVP (Nevirapine 200 mg tablet)']
  }

  FasterCSV.foreach("#{Source_path}/TbFollowUpDrug.csv", :headers => true, :quote_char => '"', :col_sep => ',', :row_sep => :auto) do |row|
    follow_up_ref = row[3].to_i
    date_created = get_proper_date(row[1]).to_date rescue nil
    next if date_created.blank?

    if @@drug_follow_up[follow_up_ref].blank?
      @@drug_follow_up[follow_up_ref] = []
    end
    @@drug_follow_up[follow_up_ref] << @@drug_map[@@referenes[row[4].to_i]]
    @@drug_follow_up[follow_up_ref] = @@drug_follow_up[follow_up_ref].uniq
    puts "Mapping medication: #{@@drug_map[@@referenes[row[4].to_i]]} ...."
  end

end

@@referenes = {}

def set_referenes
  FasterCSV.foreach("#{Source_path}/TbReference.csv", :headers => true, :quote_char => '"', :col_sep => ',', :row_sep => :auto) do |row|
    @@referenes[row[0].to_i] = row[6]
   # puts ":: #{row[6]}"
  end
end


set_referenes
drug_mapping
setup_staging_conditions
start
