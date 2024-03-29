class PatientProgram < ActiveRecord::Base
  set_table_name "patient_program"
  set_primary_key "patient_program_id"
  include Openmrs
  belongs_to :patient, :conditions => {:voided => 0}
  belongs_to :program, :conditions => {:retired => 0}
  belongs_to :location, :conditions => {:retired => 0}
  has_many :patient_states, :class_name => 'PatientState', :conditions => {:voided => 0}, :order => 'start_date, date_created', :dependent => :destroy

  named_scope :current, :conditions => ['date_enrolled < NOW() AND (date_completed IS NULL OR date_completed > NOW())']
  named_scope :local, lambda{|| {:conditions => ['location_id IN (?)',  Location.current_health_center.children.map{|l|l.id} + [Location.current_health_center.id] ]}}

  named_scope :in_programs, lambda{|names| names.blank? ? {} : {:include => :program, :conditions => ['program.name IN (?)', Array(names)]}}
  named_scope :not_completed, lambda{||  {:conditions => ['date_completed IS NULL']}}

  named_scope :in_uncompleted_programs, lambda{|names| names.blank? ? {} : {:include => :program, :conditions => ['program.name IN (?) AND date_completed IS NULL', Array(names)]}}

  validates_presence_of :date_enrolled, :program_id

  def validate
    PatientProgram.find_all_by_patient_id(self.patient_id).each{|patient_program|
      next if self.program == patient_program.program
      if self.program == patient_program.program and self.location and self.location.related_to_location?(patient_program.location) and patient_program.date_enrolled <= self.date_enrolled and (patient_program.date_completed.nil? or self.date_enrolled <= patient_program.date_completed)
        errors.add_to_base "Patient already enrolled in program #{self.program.name rescue nil} at #{self.date_enrolled.to_date} at #{self.location.parent.name rescue self.location.name}"
      end
    }
  end

  def after_void(reason = nil)
    self.patient_states.each{|row| row.void(reason) }
  end

  def debug
    puts self.to_yaml
    return
    puts "Name: #{self.program.concept.fullname}" rescue nil
    puts "Date enrolled: #{self.date_enrolled}"

  end

  def to_s
	if !self.program.concept.shortname.blank?
    	"#{self.program.concept.shortname} (at #{location.name rescue nil})"
	else
    	"#{self.program.concept.fullname} (at #{location.name rescue nil})"
	end
  end
  
  def transition(params)
	#raise params.to_yaml
    ActiveRecord::Base.transaction do
      # Find the state by name
      # Used upcase below as we were having problems matching the concept fullname with the state
      # I hope this will sort the problem and doesnt break anything
      
      # PB -- reverted the code below to its original state after fixing the metadata -----------
      #raise params.to_yaml
      #params[:state] = 'PATIENT TRANSFERRED (EXTERNAL FACILITY)' if ConceptName.find_all_by_name('PATIENT TRANSFERRED OUT').blank? and params[:state].upcase == "PATIENT TRANSFERRED OUT"
      #params[:state] = 'PATIENT TRANSFERRED (WITHIN FACILITY)' if ConceptName.find_all_by_name('PATIENT TRANSFERRED IN').blank? and params[:state].upcase == "PATIENT TRANSFERRED IN"

      selected_state = self.program.program_workflows.map(&:program_workflow_states).flatten.select{|pws| pws.concept.fullname.upcase() == params[:state].upcase()}.first rescue nil
      state = self.patient_states.last rescue []
      if (state && selected_state == state.program_workflow_state)
        # do nothing as we are already there
      else
        # Check if there is an open state and close it
        if (state && state.end_date.blank?)
          state.end_date = params[:start_date]
          state.save!
        end
        # Create the new state
        state = self.patient_states.new({
          :state => selected_state.program_workflow_state_id,
          :start_date => params[:start_date] || Date.today,
          :end_date => params[:end_date]
        })
        state.save!

		if selected_state.terminal == 1
			complete(params[:start_date])
		else
			complete(nil)
		end

      end
    end
  end

  
  def complete(end_date = nil)
    self.date_completed = end_date
    self.save!
  end
  
  # This is a pretty clumsy way of finding which regimen the patient is on.
  # Eventually it would be good to have a way to associate a program with a
  # regimen type without doing it manually. Note, the location of the regimen
  # obs must be the current health center, not the station!
  def current_regimen
    location_id = Location.current_health_center.location_id
		obs = patient.person.observations.recent(1).all(:joins => :encounter, :conditions => ['value_coded IN (?) AND encounter.location_id = ?', regimens, location_id])
    obs.first.value_coded rescue nil
  end

  # Actually returns +Concept+s of suitable +Regimen+s for the given +weight+
  def regimens(weight=nil)
    self.program.regimens(weight)
  end

  def closed?
    (self.date_completed.blank? == false)
  end

  def current_state(date = Date.today)
   state = PatientState.find(:last, :conditions => ["patient_program_id = ? AND start_date <= ? ", self.patient_program_id, date]) rescue nil
   return ConceptName.find_by_concept_id(state.program_workflow_state.concept_id).name.upcase rescue ""
  end
end
