require 'fastercsv'
User.current = User.find_by_username('admin')
ScriptStared = Time.now()
@@program = Program.find_by_name('HIV program')
@@reason_for_starting = ConceptName.find_by_name("Reason for ART eligibility").concept

def start
  patient_data = Observation.find(:all, :conditions => ["concept_id = ?", @@reason_for_starting.id], :group => 'person_id')

  (patient_data|| []).each_with_index do |data, i|
    begin
      start_date = data.obs_datetime.to_date
      patient_id = data.person_id.to_i
      puts "........................ #{(i + 1)} of #{patient_data.count}"
    rescue
      puts "############## ERROR"
      next
    end

    patient_program = PatientProgram.create(:patient_id => patient_id,
      :program_id => @@program.id, :date_enrolled => start_date.strftime('%Y-%m-%d 00:00:00'))

    last_state = PatientState.create(:patient_program_id => patient_program.id, :state => 7, :start_date => start_date)


    begin
      death_date = Person.find(patient_id).death_date.to_date
      last_state.update_attributes(:end_date => death_date)
      last_state = PatientState.create(:patient_program_id => patient_program.id, :state => 3, 
        :start_date => death_date, :end_date => death_date)

      #puts "Update outcome to dead: #{patient_id}  #{death_date}"
    rescue
      #puts "Update outcome to On ART: #{patient_id}  #{start_date}"
    end

    FasterCSV.foreach("/home/mwatha/TbPatient.csv", :headers => true, :quote_char => '"', :col_sep => ',', :row_sep => :auto) do |row|
      begin
        csv_patient_id = row[0].to_i
      rescue
        next
      end

      next unless csv_patient_id == patient_id
  
      begin
        transfer_out = row[22].to_i == 1 ? true : false 
        transfer_out_date = get_proper_date(row[23]).to_date

        last_state.update_attributes(:end_date => transfer_out_date)
        PatientState.create(:patient_program_id => patient_program.id, :state => 2, 
          :start_date => transfer_out_date, :end_date => transfer_out_date)
        #puts "Update outcome to transfer out: #{patient_id}  #{transfer_out_date}"
      rescue
        #puts "Update outcome to On ART: #{patient_id}  #{start_date}"
      end 

      break 
    end


  end

end

def get_proper_date(unfomatted_date)
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


start
