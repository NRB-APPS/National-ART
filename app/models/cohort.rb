
class Cohort

	attr :cohort, :art_defaulters
	attr_accessor :start_date, :end_date, :cohort, :patients_alive_and_on_art

	#attr_accessible :cohort

	@@first_registration_date = nil
	@@program_id = nil

	# Initialize class
	def initialize(start_date, end_date)
		@start_date = start_date #"#{start_date} 00:00:00"
		@end_date = "#{end_date} 23:59:59"
		@patient_earliest_start_date = {}

		@@cumulative_patient_list = {}
		@@newly_registraterd_patient_list = {}

		@@first_registration_date = PatientProgram.find(
		  :first,
		  :conditions =>["program_id = ? AND voided = 0",1],
		  :order => 'date_enrolled ASC'
		).date_enrolled.to_date rescue nil

		@@program_id = Program.find_by_name('HIV PROGRAM').program_id
	end

	def report(logger)
		return {} if @@first_registration_date.blank?
		cohort_report = {}
		start_time = Time.now.to_s

		#get all patients registered within the quarter
		#get all patients ever registered
		@patients_ever_reg ||= self.total_registered_cum(@@first_registration_date, @end_date)
		@patients_newly_reg ||= self.total_registered_newly(@patients_ever_reg, @start_date, @end_date)
    # calculate defaulters before starting different threads
    # We need total alive and on art to use for filter patients under secondary
    # outcomes (e.g. regimens, tb status, side effects)
    logger.info("defaulted " + Time.now.to_s)

    @art_defaulters ||= self.art_defaulted_patients(@patients_ever_reg)
    logger.info("alive_on_art " + Time.now.to_s)

    @patients_alive_and_on_art ||= self.total_alive_and_on_art(@patients_ever_reg, @art_defaulters)

    @side_effects ||= self.patients_with_side_effects(@patients_alive_and_on_art)

		threads = []

		threads << Thread.new do
			begin
				cohort_report['Total Presumed severe HIV disease in infants'] = []
				cohort_report['Total Confirmed HIV infection in infants (PCR)'] = []
				cohort_report['Total WHO stage 1 or 2, CD4 below threshold'] = []
				cohort_report['Total WHO stage 2, total lymphocytes'] = []
				cohort_report['Total Unknown reason'] = []
				cohort_report['Total WHO stage 3'] = []
				cohort_report['Total WHO stage 4'] = []
				cohort_report['Total Patient pregnant'] = []
				cohort_report['Total Patient breastfeeding'] = []
				cohort_report['Total HIV infected'] = []

				check_existing = []

				( self.start_reason(@patients_ever_reg, @@first_registration_date, @end_date) || [] ).each do | collection_reason |
					unless check_existing.include?(collection_reason.patient_id)
							check_existing << collection_reason.patient_id

							patient_object = Patient.find(collection_reason.patient_id)
							reason = PatientService.reason_for_art_eligibility(patient_object)

              if reason.nil?
                  cohort_report['Total Unknown reason'] << collection_reason.patient_id
              else
  							if reason.match(/WHO stage III/i)
  								cohort_report['Total WHO stage 3'] << collection_reason.patient_id
  							elsif reason.match(/WHO stage IV/i)
  								cohort_report['Total WHO stage 4'] << collection_reason.patient_id
  							elsif reason.match(/Confirmed/i)
  								cohort_report['Total Confirmed HIV infection in infants (PCR)'] << collection_reason.patient_id
  							elsif reason.match(/HIV DNA polymerase chain reaction/i)
  								cohort_report['Total Confirmed HIV infection in infants (PCR)'] << collection_reason.patient_id
                elsif reason.match(/Lymphocyte count below threshold with who stage 2/i)
  								cohort_report['Total WHO stage 2, total lymphocytes'] << collection_reason.patient_id
  							elsif reason.match(/WHO stage II adult/i)
  								cohort_report['Total WHO stage 1 or 2, CD4 below threshold'] << collection_reason.patient_id
  							elsif reason.match(/WHO stage II ped/i)
  								cohort_report['Total WHO stage 1 or 2, CD4 below threshold'] << collection_reason.patient_id

                elsif reason.match(/WHO stage I adult/i)
  								cohort_report['Total WHO stage 1 or 2, CD4 below threshold'] << collection_reason.patient_id
  							elsif reason.match(/WHO stage I ped/i)
  								cohort_report['Total WHO stage 1 or 2, CD4 below threshold'] << collection_reason.patient_id

  							elsif reason.match(/CD4 COUNT LESS/i)
  								cohort_report['Total WHO stage 1 or 2, CD4 below threshold'] << collection_reason.patient_id
  						 elsif reason.upcase.match(/CD4 COUNT <=/i)
  								cohort_report['Total WHO stage 1 or 2, CD4 below threshold'] << collection_reason.patient_id
  							elsif reason.match(/Presumed/i)
  								cohort_report['Total Presumed severe HIV disease in infants'] << collection_reason.patient_id
  							elsif reason.strip.humanize == 'Patient pregnant'
  								cohort_report['Total Patient pregnant'] << collection_reason.patient_id
  							elsif reason.match(/Breastfeeding/i)
  								cohort_report['Total Patient breastfeeding'] << collection_reason.patient_id
  							elsif reason.strip.upcase == 'HIV INFECTED'
  								cohort_report['Total HIV infected'] << collection_reason.patient_id
  							else
  								cohort_report['Total Unknown reason'] << collection_reason.patient_id
  							end
  					end
					end
				end
			rescue Exception => e
				Thread.current[:exception] = e
			end
		end

		#threads << Thread.new do
		#	begin
				cohort_report['Total registered'] = self.total_registered(@patients_ever_reg)
				cohort_report['Newly total registered'] = self.total_registered(@patients_newly_reg)

				logger.info("initiated_on_art " + Time.now.to_s)
				cohort_report['Patients reinitiated on ART'] = self.patients_reinitiated_on_art(@patients_newly_reg)
				cohort_report['Total Patients reinitiated on ART'] = self.patients_reinitiated_on_art(@patients_ever_reg)

				cohort_report['Patients initiated on ART'] = self.patients_initiated_on_art_first_time(@patients_newly_reg) - cohort_report['Patients reinitiated on ART']
				cohort_report['Total Patients initiated on ART'] = self.patients_initiated_on_art_first_time(@patients_ever_reg) - cohort_report['Total Patients reinitiated on ART']
		#	rescue Exception => e
			#	Thread.current[:exception] = e
		#	end
		#end

		#threads << Thread.new do
		#	begin
				logger.info("male " + Time.now.to_s)
				cohort_report['Newly registered male'] = self.total_registered_by_gender_age(@patients_newly_reg, @start_date, @end_date,'M')
				cohort_report['Total registered male'] = self.total_registered_by_gender_age(@patients_ever_reg, @@first_registration_date, @end_date,'M')

				logger.info("non-pregnant " + Time.now.to_s)
				cohort_report['Newly registered women (non-pregnant)'] = self.non_pregnant_women(@patients_newly_reg)
				cohort_report['Total registered women (non-pregnant)'] = self.non_pregnant_women(@patients_ever_reg)
		#	rescue Exception => e
		#		Thread.current[:exception] = e
		#	end
		#end

		#threads << Thread.new do
		#	begin
				logger.info("pregnant " + Time.now.to_s)
				cohort_report['Newly registered women (pregnant)'] = self.pregnant_women(@patients_newly_reg)
				cohort_report['Total registered women (pregnant)'] = self.pregnant_women(@patients_ever_reg)

		#	rescue Exception => e
		#		Thread.current[:exception] = e
		#	end
		#end

		#threads << Thread.new do
		#	begin
				logger.info("adults " + Time.now.to_s)
        cohort_report['Newly registered adults'] = self.total_registered_by_gender_age(@patients_newly_reg, @start_date, @end_date, nil, 5479, 109500)
        cohort_report['Total registered adults'] = self.total_registered_by_gender_age(@patients_ever_reg, @@first_registration_date, @end_date, nil, 5479, 109500)
		#	rescue Exception => e
		#		Thread.current[:exception] = e
		#	end
		#end

		#threads << Thread.new do
		#	begin
				logger.info("children " + Time.now.to_s)
				# Child min age = 2 yrs = (365.25 * 2) = 730.5 == 731 days to nearest day
      # Child min age = 2 yrs = (365.25 * 2) = 730.5 == 731 days to nearest day
        cohort_report['Newly registered children'] = self.total_registered_by_gender_age(@patients_newly_reg, @start_date, @end_date, nil, 731, 5479)
        cohort_report['Total registered children'] = self.total_registered_by_gender_age(@patients_ever_reg, @@first_registration_date, @end_date, nil, 731, 5479)
		#	rescue Exception => e
		#		Thread.current[:exception] = e
		#	end
	#	end

	#	threads << Thread.new do
		#	begin
				logger.info("infants " + Time.now.to_s)
        cohort_report['Newly registered infants'] = self.total_registered_by_gender_age(@patients_newly_reg, @start_date, @end_date, nil, 0, 731)
        cohort_report['Total registered infants'] = self.total_registered_by_gender_age(@patients_ever_reg, @@first_registration_date, @end_date, nil, 0, 731)
			#rescue Exception => e
			#	Thread.current[:exception] = e
			#end
		#end
		# Run the threads up to this point
		(threads || []).each do |thread|
			thread.join
		end

		threads = []

		threads << Thread.new do
			begin
				logger.info("start_reason " + Time.now.to_s)
				cohort_report['Presumed severe HIV disease in infants'] = []
				cohort_report['Confirmed HIV infection in infants (PCR)'] = []
				cohort_report['WHO stage 1 or 2, CD4 below threshold'] = []
				cohort_report['WHO stage 2, total lymphocytes'] = []
				cohort_report['Unknown reason'] = []
				cohort_report['WHO stage 3'] = []
				cohort_report['WHO stage 4'] = []
				cohort_report['Patient pregnant'] = []
				cohort_report['Patient breastfeeding'] = []
				cohort_report['HIV infected'] = []

				check_existing = []
 				( self.start_reason(@patients_newly_reg, @start_date, @end_date) || [] ).each do | collection_reason |
          unless check_existing.include?(collection_reason.patient_id)
							check_existing << collection_reason.patient_id
              patient_object = Patient.find(collection_reason.patient_id)
							reason = PatientService.reason_for_art_eligibility(patient_object)

							if reason.nil?
                cohort_report['Unknown reason'] << collection_reason.patient_id
              else
  							if reason.match(/Presumed/i)
  								cohort_report['Presumed severe HIV disease in infants'] << collection_reason.patient_id
  							elsif reason.match(/Confirmed/i)
  								cohort_report['Confirmed HIV infection in infants (PCR)'] << collection_reason.patient_id
  							elsif reason.match(/HIV DNA polymerase chain reaction/i)
  								cohort_report['Confirmed HIV infection in infants (PCR)'] << collection_reason.patient_id
  							elsif reason.match(/WHO STAGE III /i)
  								cohort_report['WHO stage 3'] << collection_reason.patient_id
  							elsif reason.match(/WHO STAGE IV /i)
  								cohort_report['WHO stage 4'] << collection_reason.patient_id
                elsif reason.match(/Lymphocyte count below threshold with who stage 2/i)
  								cohort_report['WHO stage 2, total lymphocytes'] << collection_reason.patient_id
  							elsif reason.match(/WHO STAGE II adult/i)
  								cohort_report['WHO stage 1 or 2, CD4 below threshold'] << collection_reason.patient_id
                elsif reason.match(/WHO STAGE II peds/i)
  								cohort_report['WHO stage 1 or 2, CD4 below threshold'] << collection_reason.patient_id
                elsif reason.match(/WHO STAGE I adult/i)
  								cohort_report['WHO stage 1 or 2, CD4 below threshold'] << collection_reason.patient_id
  							elsif reason.match(/WHO STAGE I peds/i)
  								cohort_report['WHO stage 1 or 2, CD4 below threshold'] << collection_reason.patient_id
  							elsif reason.upcase.match(/CD4 COUNT <=/i)
  								cohort_report['WHO stage 1 or 2, CD4 below threshold'] << collection_reason.patient_id
  							elsif reason.match(/CD4 COUNT LESS/i)
  								cohort_report['WHO stage 1 or 2, CD4 below threshold'] << collection_reason.patient_id
  							elsif reason.match(/CD4 count less/i)
  								cohort_report['WHO stage 1 or 2, CD4 below threshold'] << collection_reason.patient_id
  							elsif reason.strip.humanize == 'Patient pregnant'
  								cohort_report['Patient pregnant'] << collection_reason.patient_id
  							elsif reason.match(/Breastfeeding/i)
  								cohort_report['Patient breastfeeding'] << collection_reason.patient_id
  							elsif reason.strip.upcase == 'HIV INFECTED'
  								cohort_report['HIV infected'] << collection_reason.patient_id
  							else
  								cohort_report['Unknown reason'] << collection_reason.patient_id
  							end
  						end
          end
				end


			rescue Exception => e
				Thread.current[:exception] = e
			end
		end
		threads << Thread.new do
			begin
				cohort_report['Defaulted'] = @art_defaulters
				cohort_report['Total alive and on ART'] = @patients_alive_and_on_art
				cohort_report['Died total'] = self.total_number_of_dead_patients(@patients_ever_reg)

		  rescue Exception => e
		    Thread.current[:exception] = e
		  end
		end

		#threads << Thread.new do
		#	begin
				cohort_report['Died within the 1st month after ART initiation'] = self.total_number_of_died_within_range(@patients_ever_reg, 0, 30.4375)
		 # rescue Exception => e
		  #  Thread.current[:exception] = e
		 # end
		#end

		#threads << Thread.new do
		#	begin
				cohort_report['Died within the 2nd month after ART initiation'] = self.total_number_of_died_within_range(@patients_ever_reg, 30.4375, 60.875)
		 # rescue Exception => e
		  #  Thread.current[:exception] = e
		  #end
		#end

		#threads << Thread.new do
		#	begin
				cohort_report['Died within the 3rd month after ART initiation'] = self.total_number_of_died_within_range(@patients_ever_reg, 60.875, 91.3125)
		 # rescue Exception => e
		  #  Thread.current[:exception] = e
		  #end
		#end

		#threads << Thread.new do
		#	begin
				cohort_report['Died after the end of the 3rd month after ART initiation'] = self.total_number_of_died_within_range(@patients_ever_reg, 91.3125, 1000000)
		 # rescue Exception => e
		  #  Thread.current[:exception] = e
		  #end
		#end

		threads << Thread.new do
			begin

				logger.info("txfrd_out " + Time.now.to_s)
				cohort_report['Transferred out'] = self.transferred_out_patients(@patients_ever_reg)

				logger.info("stopped_arvs " + Time.now.to_s)
				cohort_report['Stopped taking ARVs'] = self.art_stopped_patients(@patients_ever_reg)

		  rescue Exception => e
		    Thread.current[:exception] = e
		  end
		end

		threads << Thread.new do
			begin
				logger.info("tb_status " + Time.now.to_s)
				tb_status_outcomes = self.tb_status(@patients_alive_and_on_art)
				cohort_report['TB suspected'] = tb_status_outcomes['TB STATUS']['Suspected']
				cohort_report['TB not suspected'] = tb_status_outcomes['TB STATUS']['Not Suspected']
				cohort_report['TB confirmed not treatment'] = tb_status_outcomes['TB STATUS']['Not on treatment']
				cohort_report['TB confirmed on treatment'] = tb_status_outcomes['TB STATUS']['On Treatment']
				#cohort_report['TB Unknown'] = tb_status_outcomes['TB STATUS']['Unknown']
				cohort_report['TB Unknown'] = cohort_report['Total alive and on ART'] -
				                              ((cohort_report['TB suspected']  || []) +
				                               (cohort_report['TB not suspected'] || []) +
				                               (cohort_report['TB confirmed not treatment'] || []) +
				                               (cohort_report['TB confirmed on treatment'] || []))
		  rescue Exception => e
		    Thread.current[:exception] = e
		  end
		end

		#raise self.corrected_regimens(@@first_registration_date).to_yaml
		threads << Thread.new do
			#begin
				#logger.info("regimens " + Time.now.to_s)
				cohort_report['Regimens'] = self.regimens_all(@patients_alive_and_on_art)
				regimens = self.regimens_all(@patients_alive_and_on_art)
        cohort_report['0A'] = regimens['0A']
				cohort_report['0P'] = regimens['0P']
				cohort_report['1A'] = regimens['1A']
				cohort_report['1P'] = regimens['1P']
				cohort_report['2A'] = regimens['2A']
				cohort_report['2P'] = regimens['2P']
				cohort_report['3A'] = regimens['3A']
				cohort_report['3P'] = regimens['3P']
				cohort_report['4A'] = regimens['4A']
				cohort_report['4P'] = regimens['4P']
				cohort_report['5A'] = regimens['5A']
				cohort_report['6A'] = regimens['6A']
				cohort_report['7A'] = regimens['7A']
				cohort_report['8A'] = regimens['8A']
				cohort_report['9P'] = regimens['9P']
				cohort_report['0A'] = regimens['0A']
				cohort_report['0P'] = regimens['0P']

				cohort_report['non-standard'] = cohort_report['Total alive and on ART'] -
				                                  ((cohort_report['0A'] || []) +
  				                                 (cohort_report['0P'] || []) +
                                           (cohort_report['1A'] || []) +
  				                                 (cohort_report['1P'] || []) +
  				                                 (cohort_report['2A'] || []) +
  				                                 (cohort_report['2P'] || []) +
  				                                 (cohort_report['3A'] || []) +
  				                                 (cohort_report['3P'] || []) +
  				                                 (cohort_report['4A'] || []) +
  				                                 (cohort_report['4P'] || []) +
  				                                 (cohort_report['5A'] || []) +
  				                                 (cohort_report['6A'] || []) +
  				                                 (cohort_report['7A'] || []) +
  				                                 (cohort_report['8A'] || []) +
  				                                 (cohort_report['9P'] || []) +
  				                                 (cohort_report['0A'] || []) +
  				                                 (cohort_report['0P'] || []))
		  #rescue Exception => e
		   # Thread.current[:exception] = e
		  #end
		end

		(threads || []).each do |thread|
			thread.join
		end

		threads = []

		threads << Thread.new do
			begin
				cohort_report['Total patients with side effects'] = self.patients_with_side_effects(@patients_alive_and_on_art)

				cohort_report['Total patients without side effects'] = self.patients_without_side_effects(@patients_alive_and_on_art)

				logger.info("current_episode_of_tb " + Time.now.to_s)
				cohort_report['Current episode of TB'] = self.current_episode_of_tb(@patients_newly_reg)
				cohort_report['Total Current episode of TB'] = self.current_episode_of_tb(@patients_ever_reg ,@@first_registration_date, @end_date)
			rescue Exception => e
				Thread.current[:exception] = e
			end
		end

		threads << Thread.new do
			begin
				logger.info("adherence " + Time.now.to_s)
				cohort_report['Patients with 0 - 6 doses missed at their last visit'] = self.patients_with_0_to_6_doses_missed_at_their_last_visit(@patients_alive_and_on_art)
				cohort_report['Patients with 7+ doses missed at their last visit'] = self.patients_with_7_plus_doses_missed_at_their_last_visit(@patients_alive_and_on_art)
			rescue Exception => e
				Thread.current[:exception] = e
			end
		end

		threads << Thread.new do
			begin
				logger.info("tb_within_last_year " + Time.now.to_s)
				# these 2 are counted after threads. Don't append .length here
				cohort_report['TB within the last 2 years'] = self.tb_within_the_last_2_yrs(@patients_newly_reg)
				cohort_report['Total TB within the last 2 years'] = self.tb_within_the_last_2_yrs(@patients_ever_reg, @@first_registration_date, @end_date)

				logger.info("ks " + Time.now.to_s)
				cohort_report['Kaposis Sarcoma'] = self.kaposis_sarcoma(@patients_newly_reg)
				cohort_report['Total Kaposis Sarcoma'] = self.kaposis_sarcoma(@patients_ever_reg, @@first_registration_date,@end_date)
		  rescue Exception => e
		    Thread.current[:exception] = e
		  end
		end

		(threads || []).each do |thread|
			thread.join
		end
		cohort_report['Total transferred in patients'] = transferred_in_patients(@patients_ever_reg)

		cohort_report['Newly transferred in patients'] = transferred_in_patients(@patients_newly_reg)

        #raise cohort_report['Total registered'].to_yaml
		cohort_report['Total Unknown age'] = cohort_report['Total registered'] - (cohort_report['Total registered adults'] +
				cohort_report['Total registered children'] +
				cohort_report['Total registered infants'])

		cohort_report['New Unknown age'] = cohort_report['Newly total registered']-(cohort_report['Newly registered adults'] +
				cohort_report['Newly registered children'] +
				cohort_report['Newly registered infants'])

    #Calculation of No TB has been changed temporarily to match that of BART 1.
    #This might be changed again after thorough discussions on how to pull TB within the last 2 years.
    #In BART1 we do not subtract Current episode of TB from TB within the past 2 years which was the case
    #in NART.

    #This change has also been implemented in cohort_validation model.
		current_episode = cohort_report['Current episode of TB']
		total_current_episode = cohort_report['Total Current episode of TB']

		cohort_report['tb_with_the_last_2yrs'] = (cohort_report['TB within the last 2 years'] || []) - (current_episode || [])
		cohort_report['total_tb_within_the_last_2yrs'] = (cohort_report['Total TB within the last 2 years'] || []) - (total_current_episode || [])

		cohort_report['No TB'] = (cohort_report['Newly total registered'] - ((current_episode || []) + (cohort_report['tb_with_the_last_2yrs'] || [])))
		cohort_report['Total No TB'] = (cohort_report['Total registered'] - ((total_current_episode || []) + (cohort_report['total_tb_within_the_last_2yrs'] || [])))

		cohort_report['No TB on report'] = ((cohort_report['Newly total registered'] || []).length - ((current_episode || []).length + (cohort_report['TB within the last 2 years'] || []).length))
		cohort_report['Total No TB on report'] = ((cohort_report['Total registered'] || []).length - ((total_current_episode || []).length + (cohort_report['Total TB within the last 2 years'] || []).length))

		cohort_report['Unknown outcomes'] = cohort_report['Total registered'] -
			(cohort_report['Total alive and on ART'] +
				cohort_report['Defaulted'] +
				(cohort_report['Died total'] || [] ) +
				(cohort_report['Stopped taking ARVs'] || []) +
				(cohort_report['Transferred out'] || []))

		#patients_with_0_6_doses_missed = []; patients_with_7_doses_missed = []

		#patients_with_0_6_doses_missed = cohort_report['Patients with 0 - 6 doses missed at their last visit']
		#patients_with_7_doses_missed = cohort_report['Patients with 7+ doses missed at their last visit']

		#patients_with_0_6_doses_missed = cohort_report['Patients with 0 - 6 doses missed at their last visit'].map{|person| person.person_id}
		#patients_with_7_doses_missed = cohort_report['Patients with 7+ doses missed at their last visit'].map{|person| person.person_id}

		#cohort_report['Unknown adherence'] = (cohort_report['Total alive and on ART'] -
			#	patients_with_0_6_doses_missed - patients_with_7_doses_missed)
			#raise cohort_report['Patients with 0 - 6 doses missed at their last visit'].to_yaml
		cohort_report['Unknown adherence'] = ((cohort_report['Total alive and on ART'] || [] ) -
				(cohort_report['Patients with 0 - 6 doses missed at their last visit'] || [] ) - (cohort_report['Patients with 7+ doses missed at their last visit'] || [] ))
		cohort_report['Earliest_start_dates'] = @patient_earliest_start_date
    cohort_report['Total patients with unknown side effects'] = cohort_report['Total alive and on ART']  -
                                                                                                  (cohort_report['Total patients with side effects'] +
                                                                                                    cohort_report['Total patients without side effects'])


		logger.info("start_time " + start_time)
		logger.info("end_time " + Time.now.to_s)

		self.cohort = cohort_report
		self.cohort
	end

	def total_registered(patient_list)
		patients = []
=begin
	  PatientProgram.find_by_sql("SELECT * FROM earliest_start_date
	    WHERE date_enrolled BETWEEN '#{start_date} 00:00:00' AND '#{end_date}'").each do | patient |
	    @patient_earliest_start_date[patient.patient_id]= patient.earliest_start_date
			patients << patient.patient_id
		end
=end
    patient_list.each do | patient |
			@patient_earliest_start_date[patient.patient_id]= patient.earliest_start_date
			patients << patient.patient_id.to_i
	  end
		return patients
	end

	def total_registered_cum(start_date = @start_date, end_date = @end_date)
		patients = []
	  PatientProgram.find_by_sql("SELECT * FROM earliest_start_date
	    WHERE date_enrolled <= '#{end_date}'").each do | patient |
			@patient_earliest_start_date[patient.patient_id]= patient.earliest_start_date
			patients << patient
		end
		return patients
	end

	def total_registered_newly(patient_list, start_date = @start_date, end_date = @end_date)
		patients = []
=begin
	  PatientProgram.find_by_sql("SELECT * FROM earliest_start_date
	    WHERE date_enrolled BETWEEN '#{start_date} 00:00:00' AND '#{end_date}'").each do | patient |
	    @patient_earliest_start_date[patient.patient_id]= patient.earliest_start_date
			patients << patient
		end
=end
		patient_list.each do |patient|
			if (patient.date_enrolled.to_date >= start_date.to_date)  && (patient.date_enrolled.to_date <= end_date.to_date)
				patients << patient
			end
		end

		if patients.blank?
			PatientProgram.find_by_sql("SELECT * FROM earliest_start_date
				WHERE date_enrolled BETWEEN '#{start_date} 00:00:00' AND '#{end_date}'").each do | patient |
				@patient_earliest_start_date[patient.patient_id]= patient.earliest_start_date
				patients << patient
			end
		else
			patients = patients
		end

		return patients
	end

  def transferred_in_patients(patient_list)
    patients = []
    patients_list = []
    #total_registered = self.total_registered(start_date, end_date)

    patients_lists = patient_list.map(&:patient_id)

    reinitiated_on_art = self.patients_reinitiated_on_art(patient_list)
    reinitiated_on_art = [0] if reinitiated_on_art.blank?
    first_time_on_arvs = self.patients_initiated_on_art_first_time(patient_list)
    first_time_on_arvs = [0] if first_time_on_arvs.blank?

    patients = (patients_lists - first_time_on_arvs - reinitiated_on_art) #.uniq!
=begin
    PatientProgram.find_by_sql("SELECT * FROM earliest_start_date
    WHERE date_enrolled BETWEEN '#{start_date} 00:00:00' AND '#{end_date}'
    AND DATE(date_enrolled) <> DATE(earliest_start_date)
    AND patient_id NOT IN(#{reinitiated_on_art.join(',')})").each_with_index do | patient, i |
      patients << patient.patient_id
    end

    patient_ids = patient_list.map(&:patient_id)
    patient_list.each do |patient|
     if patient.date_enrolled.to_date != patient.earliest_start_date.to_date
       patients_list << patient.patient_id
     end
    end
=end
=begin
		PatientProgram.find_by_sql("SELECT * FROM encounter enc
					      INNER JOIN clinic_registration_encounter e ON enc.patient_id = e.patient_id
					      INNER JOIN ever_registered_obs AS ero ON e.encounter_id = ero.encounter_id
					    WHERE enc.patient_id IN (#{patients_list.join(',')})
					    AND enc.patient_id NOT IN (#{reinitiated_on_art.join(',')})
                                            and ero.obs_id IS NULL
					    GROUP BY enc.patient_id").each_with_index do | patient, i |
										patients << patient.patient_id
		raise patients.to_yaml							end



     PatientProgram.find_by_sql("SELECT esd.*
     		FROM patients_on_arvs esd
     		INNER JOIN clinic_registration_encounter e ON esd.patient_id = e.patient_id
     		INNER JOIN ever_registered_obs AS ero ON e.encounter_id = ero.encounter_id
    		LEFT JOIN (SELECT * FROM obs o
    		           WHERE ((o.concept_id = 7751 AND
                      (DATEDIFF(o.obs_datetime,o.value_datetime)) > 60) OR
                      (o.concept_id = 7752 AND
                      (o.value_coded = 1066 )))) AS ro ON e.encounter_id = ro.encounter_id
            WHERE esd.patient_id IN (#{patients_list.join(',')})
            AND ro.obs_id IS NULL
            GROUP BY esd.patient_id").each do |patient|
           patients << patient.patient_id
   end
    #patients = (patients + patients_list).uniq!
=end
   return patients
  end

	def patients_initiated_on_art_first_time(patient_list)
    # Some patients have Ever registered at ART clinic = Yes but without any
    # original start date
    #
    # 7937 = Ever registered at ART clinic
    # 1065 = Yes
    #TODO remove reinitiated patients after threads in report method
    patients_reinitiated_on_arvs = []
    patients_reinitiated_on_arvs = self.patients_reinitiated_on_art(patient_list)
    patients = []
    patients_list = patient_list.map(&:patient_id)
    PatientProgram.find_by_sql("SELECT esd.*
      FROM patients_on_arvs esd
      LEFT JOIN clinic_registration_encounter e ON esd.patient_id = e.patient_id
      LEFT JOIN ever_registered_obs AS ero ON e.encounter_id = ero.encounter_id
      WHERE esd.patient_id IN (#{patients_list.join(',')}) AND
              (ero.obs_id IS NULL)
      GROUP BY esd.patient_id").each do | patient |
			patients << patient.patient_id
		end
    patients -= patients_reinitiated_on_arvs

    return patients
	end

	def total_registered_by_gender_age(patient_list, start_date = @start_date, end_date = @end_date, sex = nil, min_age = nil, max_age = nil)
		conditions = ''
		patients = []
		age_patient_list = []
		if min_age and max_age
=begin
			conditions = "AND esd.age_in_days >= #{min_age}
				        AND esd.age_in_days < #{max_age}"
=end
			patient_list.each do |patient|
				if (patient.age_in_days.to_i >= min_age) && (patient.age_in_days.to_i < max_age)
					age_patient_list << patient.patient_id.to_i
				end
			end
		end

		if age_patient_list.blank?
			patients_list = patient_list.map(&:patient_id)
		else
			patients_list = age_patient_list
		end

		if sex
		  conditions = "AND person.gender = '#{sex}'"
		end

		PatientProgram.find_by_sql(
		"SELECT *
		FROM person person
		WHERE person.person_id IN (#{patients_list.join(',')})
		#{conditions}
		AND person.voided = 0
		GROUP BY person.person_id").each do | patient |
			patients << patient.person_id.to_i
		end
=begin
		  PatientProgram.find_by_sql(
      "SELECT esd.patient_id, esd.earliest_start_date
	    FROM earliest_start_date esd
	    INNER JOIN person ON person.person_id = esd.patient_id
	    WHERE esd.date_enrolled BETWEEN '#{start_date} 00:00:00'
      AND '#{end_date}' #{conditions}").each do | patient |
			  patients << patient.patient_id
		  end
=end
		return patients

	end

	def non_pregnant_women(patient_list)
		all_women =  self.total_registered_by_gender_age(patient_list, start_date, end_date, 'F')
		non_pregnant_women = (all_women - self.pregnant_women(patient_list))
	end

	def pregnant_women(patient_list)
		transfer_ins_preg_women = []

		patients_list = patient_list.map(&:patient_id)
		PatientProgram.find_by_sql("select
                                    rfe.patient_id, rfe.earliest_start_date, p.obs_datetime, p.date_created
                                from
                                    reason_for_eligibility_obs rfe
                                 inner join patients_with_has_transfer_letter_yes p on p.person_id = rfe.patient_id
                                where
                                    rfe.reason_for_eligibility = 'Patient pregnant'
                                        and rfe.patient_id IN (#{patients_list.join(',')})
                                Group by rfe.patient_id").each do | patient |
                                        transfer_ins_preg_women << patient.patient_id
                                end

		patients = []
		PatientProgram.find_by_sql("SELECT patient_id, earliest_start_date, o.obs_datetime
				FROM patients_on_arvs p
					INNER JOIN patient_pregnant_obs o ON p.patient_id = o.person_id
				WHERE patient_id IN (#{patients_list.join(',')})
					AND DATEDIFF(o.obs_datetime, earliest_start_date) <= 30
					AND DATEDIFF(o.obs_datetime, earliest_start_date) > -1
        GROUP BY patient_id").each do | patient |
			patients << patient.patient_id
		end

		patients = (patients + transfer_ins_preg_women).uniq
		return patients
	end

	def start_reason(patient_list, start_date = @start_date, end_date = @end_date)
		#start_reason_hash = Hash.new(0)
		#reason_concept_id = ConceptName.find_by_name("REASON FOR ART ELIGIBILITY").concept_id
=begin
		 PatientProgram.find_by_sql("SELECT e.patient_id, name, o.obs_datetime FROM earliest_start_date e
				 LEFT JOIN obs o ON e.patient_id = o.person_id AND o.concept_id = #{reason_concept_id} AND o.voided = 0
				  AND o.obs_datetime >= '#{start_date}' AND o.obs_datetime <= '#{end_date}'
				LEFT JOIN concept_name n ON n.concept_id = o.value_coded AND n.concept_name_type = 'FULLY_SPECIFIED' AND n.voided = 0
				WHERE date_enrolled >= '#{start_date}'
				AND date_enrolled <= '#{end_date}'
				ORDER BY o.obs_datetime DESC")
=end
			patients_list = patient_list.map(&:patient_id)
			start_reason = []
			PatientProgram.find_by_sql("SELECT person_id as patient_id, name, obs_datetime FROM reason_for_art_eligibility_obs
			                             WHERE person_id IN (#{patients_list.join(',')})").each do |patient|
																	 start_reason << patient
																 end
     return start_reason
	end

	def tb_within_the_last_2_yrs(patient_list, start_date = @start_date, end_date = @end_date)
		tb_concept_id = ConceptName.find_by_name("PULMONARY TUBERCULOSIS WITHIN THE LAST 2 YEARS").concept_id
		self.patients_with_start_cause(patient_list, start_date, end_date, [tb_concept_id, 2624])
	end

	def patients_with_start_cause(patient_list, start_date = @start_date, end_date = @end_date, concept_ids = nil)
		patients = []
    patients_list = patient_list.map(&:patient_id)

		who_stg_crit_concept_id = ConceptName.find_by_name("WHO STAGES CRITERIA PRESENT").concept_id
		yes_concept_id = ConceptName.find_by_name("YES").concept_id

		if !concept_ids.blank?
			concept_ids = [concept_ids] if concept_ids.class != Array
      all_concept_ids = [concept_ids, who_stg_crit_concept_id]

			value_coded_ids = [concept_ids, yes_concept_id]
#=begin
			Encounter.find_by_sql("SELECT * FROM hiv_staging_conditions_obs
			                       WHERE concept_id IN (#{all_concept_ids.join(', ')})
														 AND value_coded in (#{value_coded_ids.join(',')})
														 AND person_id IN (#{patients_list.join(',')})
														 GROUP BY person_id").each do |patient|
														 		patients << patient.person_id
													 end
=begin
			concept_ids.each do | concept |

        Observation.find_by_sql("SELECT DISTINCT patient_id, earliest_start_date,
				                                current_value_for_obs_at_initiation(patient_id, earliest_start_date, 52, '#{concept}', '#{end_date}') AS obs_value
				 FROM patients_on_arvs e
              WHERE e.patient_id IN (#{patients_list.join(',')})
							GROUP BY e.patient_id
              HAVING obs_value = 1065").each do | patient |
          patients << patient.patient_id.to_i
        end

				Observation.find_by_sql("SELECT DISTINCT patient_id, earliest_start_date,
																current_value_for_obs_at_initiation(patient_id, earliest_start_date, 52, '#{who_stg_crit_concept_id}', '#{end_date}') AS obs_value
						  FROM patients_on_arvs e
						  WHERE e.patient_id IN (#{patients_list.join(',')})
							GROUP BY e.patient_id
							HAVING obs_value = '#{concept}'").each do | patient |
					patients << patient.patient_id.to_i
				end
      end
=end
		end
    patients = patients.uniq
    return patients

	end

	def kaposis_sarcoma(patient_list, start_date = @start_date, end_date = @end_date)
		concept_id = ConceptName.find_by_name("KAPOSIS SARCOMA").concept_id
		self.patients_with_start_cause(patient_list, start_date,end_date, concept_id)
	end

	def total_alive_and_on_art(patient_list = self.total_registered_cum, defaulted_patients = self.art_defaulted_patients(patient_list))
=begin
		on_art_concept_name = ConceptName.find_all_by_name('On antiretrovirals')
		state = ProgramWorkflowState.find(
		  :first,
		  :conditions => ["concept_id IN (?)",
					      on_art_concept_name.map{|c|c.concept_id}]
		).program_workflow_state_id

		PatientState.find_by_sql("SELECT * FROM (
			SELECT s.patient_program_id, patient_id,patient_state_id,start_date,
				   n.name name,state
			FROM patient_state s
			LEFT JOIN patient_program p ON p.patient_program_id = s.patient_program_id
			LEFT JOIN program_workflow pw ON pw.program_id = p.program_id
			LEFT JOIN program_workflow_state w ON w.program_workflow_id = pw.program_workflow_id
			AND w.program_workflow_state_id = s.state
			LEFT JOIN concept_name n ON w.concept_id = n.concept_id
			WHERE p.voided = 0 AND s.voided = 0
			AND (s.start_date >= '#{@@first_registration_date}'
			AND s.start_date <= '#{@end_date}')
			AND p.program_id = #{@@program_id}
			ORDER BY patient_state_id DESC, start_date DESC
		  ) K
		  GROUP BY K.patient_id HAVING (state = #{state})
		  ORDER BY K.patient_state_id DESC, K.start_date DESC")
=end
    patients_list = patient_list.map(&:patient_id)
		patients = []
		if @total_alive_and_on_art.blank?
=begin
			PatientProgram.find_by_sql("SELECT e.patient_id, current_state_for_program(e.patient_id, 1, '#{@end_date}') AS state
		 									FROM earliest_start_date e
											WHERE date_enrolled <=  '#{@end_date}'
											HAVING state = 7").reject{|t| defaulted_patients.include?(t.patient_id) }.each do | patient |
				patients << patient.patient_id
			end
=end
				PatientProgram.find_by_sql("SELECT e.patient_id, current_state_for_program(e.patient_id, 1, '#{@end_date}') AS state
												FROM encounter e
												WHERE patient_id IN (#{patients_list.join(',')})
												GROUP BY e.patient_id
												HAVING state = 7").reject{|t| defaulted_patients.include?(t.patient_id) }.each do | patient |
					patients << patient.patient_id.to_i
				end
			@total_alive_and_on_art = patients
		else
			patients = @total_alive_and_on_art
		end

		return patients
	end

	def total_number_of_dead_patients(patient_list)
		patients_list = patient_list.map(&:patient_id)
		self.outcomes_total(patients_list, 'PATIENT DIED')
	end

	def total_number_of_died_within_range(patient_list, min_days = 0, max_days = 0)
   concept_name = "PATIENT DIED"
	 patients = []

	 patients_list = [0]
   patients_list = patient_list.map(&:patient_id)

	 PatientProgram.find_by_sql("
      SELECT p.patient_id, current_state_for_program(p.patient_id, 1, '#{@end_date}') AS state, e.death_date, c.name as status FROM patient p
      INNER JOIN  program_workflow_state pw ON pw.program_workflow_state_id = current_state_for_program(p.patient_id, 1, '#{@end_date}')
      INNER join patients_on_arvs e ON e.patient_id = p.patient_id
      INNER JOIN concept_name c ON c.concept_id = pw.concept_id
      WHERE p.patient_id IN (#{patients_list.join(',')})
      AND  name = '#{concept_name}'
			AND DATEDIFF(e.death_date, e.earliest_start_date) BETWEEN #{min_days} AND #{max_days}
      AND e.death_date IS NOT NULL
			GROUP BY e.patient_id").each do | patient |
							patients << patient.patient_id.to_i
					end
		return patients
	end

  def self.miss_appointment(start_date, end_date)
      obs = []
      Observation.find_by_sql("
                  SELECT DISTINCT(person_id), obs_datetime, value_datetime FROM obs
                  WHERE concept_id = (SELECT concept_id FROM concept_name WHERE name = 'appointment date' LIMIT 1)
                  AND value_datetime BETWEEN '#{start_date}' AND '#{end_date}'
                  ORDER BY obs_datetime DESC").each { |person|
              patient = Person.find(person.person_id)
              obs << [patient.names.first.given_name, patient.names.first.family_name, person.value_datetime, person.obs_datetime]
              }
    return obs
  end

	def transferred_out_patients(patient_list)
	  #PB--reversed the code below to the original code after fixing the metadata
    #outcome = 'PATIENT TRANSFERRED (EXTERNAL FACILITY)' if ConceptName.find_all_by_name('PATIENT TRANSFERRED OUT').blank?
    #outcome = 'PATIENT TRANSFERRED OUT' if outcome.blank?
    patients_list = patient_list.map(&:patient_id)
		self.outcomes_total(patients_list, 'PATIENT TRANSFERRED OUT')
	end

	def art_defaulted_patients(patient_list)
		patients = []
		if @art_defaulters.blank?
=begin
			@art_defaulters ||= PatientProgram.find_by_sql("SELECT e.patient_id, current_defaulter(e.patient_id, '#{@end_date}') AS def
											FROM earliest_start_date e LEFT JOIN person p ON p.person_id = e.patient_id
											WHERE e.date_enrolled <=  '#{@end_date}' AND p.dead=0
											HAVING def = 1 AND current_state_for_program(patient_id, 1, '#{@end_date}') NOT IN (6, 2, 3)").each do | patient |
				patients << patient.patient_id
			end
=end
			cum_patient_list = patient_list.map(&:patient_id)
			@art_defaulters ||= PatientProgram.find_by_sql("SELECT p.person_id AS patient_id, current_defaulter(p.person_id, '#{@end_date}') AS def
											FROM person p
											WHERE p.dead = 0
											AND p.person_id IN (#{cum_patient_list.join(',')})
											GROUP BY p.person_id
											HAVING def = 1 AND current_state_for_program(p.person_id, 1, '#{@end_date}') NOT IN (6, 2, 3)").each do | patient |
				patients << patient.patient_id
			end
			@art_defaulters = patients
		else
			patients = @art_defaulters
    end

		return patients
	end

	def art_stopped_patients(patient_list)
		patients_list = patient_list.map(&:patient_id)
		self.outcomes_total(patients_list, 'Treatment stopped')
	end

	def tb_status(patient_list)
		tb_status_hash = {} ; status = []
		tb_status_hash['TB STATUS'] = {'Unknown' => 0,'Suspected' => 0,'Not Suspected' => 0,'On Treatment' => 0,'Not on treatment' => 0}
		tb_status_concept_id = ConceptName.find_by_name('TB STATUS').concept_id
		hiv_clinic_consultation_encounter_id = EncounterType.find_by_name('HIV CLINIC CONSULTATION').id
		states = Hash.new()

    #@art_defaulters ||= self.art_defaulted_patients
		#@patients_alive_and_on_art ||= self.total_alive_and_on_art(@art_defaulters)
		#@patient_id_on_art_and_alive = @patients_alive_and_on_art
		@patient_id_on_art_and_alive = [0] if @patient_id_on_art_and_alive.blank?

		joined_array = patient_list.join(',')
		PatientState.find_by_sql(
			"SELECT o.person_id, o.value_coded
											FROM obs o
											INNER JOIN encounter en ON en.encounter_id = o.encounter_id
											WHERE en.encounter_type = #{hiv_clinic_consultation_encounter_id}
											AND o.concept_id = #{tb_status_concept_id}
											AND o.obs_datetime <= '#{@end_date}'
											AND o.person_id IN (#{joined_array})
											GROUP BY o.person_id
											ORDER BY en.encounter_datetime ASC").each do |state|
			states[state.person_id] = state.value_coded
		end

		tb_not_suspected_id = ConceptName.find_by_name('TB NOT SUSPECTED').concept_id
		tb_suspected_id = ConceptName.find_by_name('TB SUSPECTED').concept_id
		tb_confirmed_on_treatment_id = ConceptName.find_by_name('CONFIRMED TB ON TREATMENT').concept_id
		tb_confirmed_not_on_treatment_id = ConceptName.find_by_name('CONFIRMED TB NOT ON TREATMENT').concept_id

		tb_status_hash['TB STATUS']['Not Suspected'] = []
		tb_status_hash['TB STATUS']['Suspected'] = []
		tb_status_hash['TB STATUS']['On Treatment'] = []
		tb_status_hash['TB STATUS']['Not on treatment'] = []
		tb_status_hash['TB STATUS']['Unknown'] = []

		( states || [] ).each do | patient_id, state |
			if state.to_i == tb_not_suspected_id
				tb_status_hash['TB STATUS']['Not Suspected'] << patient_id.to_i
			elsif state.to_i == tb_suspected_id
				tb_status_hash['TB STATUS']['Suspected'] << patient_id.to_i
			elsif state.to_i == tb_confirmed_on_treatment_id.to_i
				tb_status_hash['TB STATUS']['On Treatment'] << patient_id.to_i
			elsif state.to_i == tb_confirmed_not_on_treatment_id
				tb_status_hash['TB STATUS']['Not on treatment'] << patient_id.to_i
			else
				tb_status_hash['TB STATUS']['Unknown'] << patient_id.to_i
			end
		end
		# make sure that patients that do not have a TB Status observation,
    # are added to the unknown category
   	#other_unknowns = @patient_id_on_art_and_alive - (tb_status_hash['TB STATUS']['Not Suspected'] +
     #                               tb_status_hash['TB STATUS']['Suspected'] +
     #                               tb_status_hash['TB STATUS']['On Treatment'] +
      #                              tb_status_hash['TB STATUS']['Not on treatment'] +
      #                              tb_status_hash['TB STATUS']['Unknown'])

   # tb_status_hash['TB STATUS']['Unknown'] += other_unknowns
		tb_status_hash
	end

  def outcomes_total(patient_list, outcome, start_date=@start_date, end_date=@end_date)
    concept_name = ConceptName.find_all_by_name(outcome)
    if outcome == 'PATIENT DIED'
      condition = " AND p.death_date IS NOT NULL"
    end

    state = ProgramWorkflowState.find(:first, :conditions => ["concept_id IN (?)", concept_name.map{|c|c.concept_id}] ).program_workflow_state_id

		patients = []
=begin
    PatientProgram.find_by_sql("SELECT p.patient_id, current_state_for_program(p.patient_id, 1, '#{end_date}') AS state, c.name as status FROM patient p
                                INNER JOIN  program_workflow_state pw ON pw.program_workflow_state_id = current_state_for_program(p.patient_id, 1, '#{end_date}')
                                INNER join earliest_start_date e ON e.patient_id = p.patient_id
                                INNER JOIN concept_name c ON c.concept_id = pw.concept_id
                                WHERE date_enrolled BETWEEN '#{start_date}' AND '#{end_date}' #{condition}
                                AND  name = '#{outcome}'").each do | patient |
			patients << patient.patient_id.to_i
		end
=end
		PatientProgram.find_by_sql("SELECT p.patient_id,
		                                   current_state_for_program(p.patient_id, 1, '#{end_date}') AS state,
																			 c.name as status FROM patients_on_arvs p
																INNER JOIN  program_workflow_state pw ON pw.program_workflow_state_id = current_state_for_program(p.patient_id, 1, '#{end_date}')
																INNER JOIN concept_name c ON c.concept_id = pw.concept_id
																WHERE p.patient_id IN (#{patient_list.join(',')}) #{condition}
																AND  name = '#{outcome}'
																GROUP BY p.patient_id").each do | patient |
			patients << patient.patient_id.to_i
		end
		return patients
  end

	# Get patients reinitiated on art count
	def patients_reinitiated_on_art_ever
		patients = []
		Observation.find(:all, :joins => [:encounter], :conditions => ["concept_id = ? AND value_coded IN (?) AND encounter.voided = 0 \
			AND DATE_FORMAT(obs_datetime, '%Y-%m-%d') <= ?", ConceptName.find_by_name("EVER RECEIVED ART").concept_id,
				ConceptName.find(:all, :conditions => ["name = 'YES'"]).collect{|c| c.concept_id},
				@end_date.to_date.strftime("%Y-%m-%d")]).each do | patient |
			patients << patient.patient_id.to_i
		end
		return patients
	end

  def outcomes(start_date=@start_date, end_date=@end_date, outcome_end_date=@end_date,
			program_id = @@program_id, states = [], min_age=nil, max_age=nil)
    states = []

		if min_age or max_age
      conditions = "AND TRUNCATE(DATEDIFF(p.date_enrolled, person.birthdate)/365,0) >= #{min_age}
                    AND TRUNCATE(DATEDIFF(p.date_enrolled, person.birthdate)/365,0) <= #{max_age}"
    end

    PatientState.find_by_sql("SELECT  distinct(p.patient_id)
        FROM patient_state s
        INNER JOIN patient_program p ON p.patient_program_id = s.patient_program_id
        INNER JOIN earliest_start_date e ON e.patient_id = p.patient_id
				INNER JOIN person ON person.person_id = e.patient_id
        WHERE p.voided = 0 AND s.voided = 0 #{conditions}
        AND e.date_enrolled >= '#{start_date}'
        AND e.date_enrolled  <= '#{end_date}'
        AND p.program_id = #{program_id}
        AND s.start_date <= '#{outcome_end_date}'
			").each do |patient_id|
			states << patient_id.patient_id.to_i
		end

		return states
  end

	#Method added to avoid conflicting the already existing ones
	#More time is needed to upgade the code so that its relevant and according to standards

	def women_outcomes(start_date=@start_date, end_date=@end_date, outcome_end_date=@end_date,
			program_id = @@program_id, states = [], min_age=nil, max_age=nil)
		states = []
		coded_id = ConceptName.find_by_name("Yes").concept_id
		pregnant_id = ConceptName.find_by_name("Is patient pregnant?").concept_id
		breast_feeding_id = ConceptName.find_by_name("Is patient breast feeding?").concept_id
		PatientState.find_by_sql(" SELECT  distinct(p.patient_id)
					FROM patient_state s
					INNER JOIN patient_program p ON p.patient_program_id = s.patient_program_id
					INNER JOIN earliest_start_date e ON e.patient_id = p.patient_id
					INNER JOIN obs o on o.person_id = e.patient_id
					WHERE (e.date_enrolled  >= '#{start_date}'
					AND e.date_enrolled  <= '#{end_date}')
					AND s.start_date <= '#{outcome_end_date}'
					AND p.program_id = #{program_id}
					AND ((o.concept_id = '#{pregnant_id}'
								AND o.value_coded = '#{coded_id}'
								AND DATEDIFF(o.obs_datetime, e.earliest_start_date) <= 30
								AND DATEDIFF(o.obs_datetime, e.earliest_start_date) > -1)
								OR
						  (o.concept_id = '#{breast_feeding_id}'
								AND o.value_coded = '#{coded_id}'))
					").each do |patient_id|
			states << patient_id.patient_id.to_i
		end

		return states
  end


  def first_registration_date
    @@first_registration_date
  end

  def arv_regimens(regimen_category)
    regimens = []
    if regimen_category == "non-standard"
      regimen_category = "UNKNOWN ANTIRETROVIRAL DRUG"
    end

    self.regimens_all(patient_list = self.total_alive_and_on_art).each do |reg_name, patient_ids|

      if reg_name == regimen_category
        patient_ids.each do |patient_id|
					regimens << patient_id.to_i
        end
      end
    end
    regimens
  end

	def regimens_all(patient_list)
    regimen_hash = {}
    #@art_defaulters ||= self.art_defaulted_patients
    #@patients_alive_and_on_art ||= self.total_alive_and_on_art(@art_defaulters)
    patient_ids = patient_list
    patient_ids = [0] if patient_ids.blank?

    dispensing_encounter_id = EncounterType.find_by_name("DISPENSING").id
    regimen_category = ConceptName.find_by_name("REGIMEN CATEGORY").concept_id
    regimem_given_concept = ConceptName.find_by_name('ARV REGIMENS RECEIVED ABSTRACTED CONSTRUCT').concept_id
    unknown_regimen_given = ConceptName.find_by_name('UNKNOWN ANTIRETROVIRAL DRUG').concept_id

    earliest_start_dates = PatientProgram.find_by_sql(
                          "SELECT e.patient_id,
                          last_text_for_obs(e.patient_id, #{dispensing_encounter_id}, #{regimen_category}, #{regimem_given_concept}, #{unknown_regimen_given}, '#{end_date}') AS regimen_category
                          FROM patients_on_arvs e
                          WHERE patient_id IN(#{patient_ids.join(',')})
													GROUP BY e.patient_id
                          ")

    (earliest_start_dates || []).each do | value |

	    if (value.regimen_category.blank? or value.regimen_category == 'unknown_drug_value')
        regimen_hash['UNKNOWN ANTIRETROVIRAL DRUG'] ||= []
        regimen_hash['UNKNOWN ANTIRETROVIRAL DRUG'] << value.patient_id.to_i
      else
        regimen_hash[value.regimen_category] ||= []
        regimen_hash[value.regimen_category] << value.patient_id.to_i
      end
    end
    regimen_hash
  end


  def regimens_with_patient_ids(start_date = @start_date, end_date = @end_date)
    regimens = []
    regimen_hash = {}

    regimem_given_concept = ConceptName.find_by_name('ARV REGIMENS RECEIVED ABSTRACTED CONSTRUCT')
    PatientProgram.find_by_sql("SELECT patient_id , value_coded regimen_id, value_text regimen ,
                                age(LEFT(person.birthdate,10),LEFT(obs.obs_datetime,10),
                                LEFT(person.date_created,10),person.birthdate_estimated) person_age_at_drug_dispension
                                FROM obs
                                INNER JOIN patient_program p ON p.patient_id = obs.person_id
                                INNER JOIN patient_state s ON p.patient_program_id = s.patient_program_id
                                INNER JOIN person ON person.person_id = p.patient_id
                                WHERE p.program_id = #{@@program_id}
                                AND obs.concept_id = #{regimem_given_concept.concept_id}
                                AND patient_start_date(patient_id) >= '#{start_date}'
                                AND patient_start_date(patient_id) <= '#{end_date}'
                                GROUP BY patient_id
                                ORDER BY obs.obs_datetime DESC").each do | value |
                                  if value.regimen.blank?
																		value.regimen = ConceptName.find_by_concept_id(value.regimen_id).concept.shortname
		                                regimens << [value.regimen_id,
		                                             value.regimen,
		                                             value.person_age_at_drug_dispension
		                                            ]
		                              else
		                              	regimens << [value.regimen_id,
		                                             value.regimen,
		                                             value.person_age_at_drug_dispension
		                                            ]
		                              end
                                end
  end

  def patients_reinitiated_on_art(patient_list)
    patients = []; patients_with_date_last_taken_obs = []; patients_with_taken_arvs_in_past_2mths_no = []

    yes_concept = ConceptName.find_by_name('YES').concept_id
    no_concept = ConceptName.find_by_name('NO').concept_id
    date_art_last_taken_concept = ConceptName.find_by_name('DATE ART LAST TAKEN').concept_id
    taken_arvs_concept = ConceptName.find_by_name('HAS THE PATIENT TAKEN ART IN THE LAST TWO MONTHS').concept_id

     patients_list = patient_list.map(&:patient_id)
     if patients_list.blank?
        patients_list = [0]
      else
	patients_list = patients_list
      end

    PatientProgram.find_by_sql("SELECT esd.*
      FROM encounter esd
      LEFT JOIN clinic_registration_encounter e ON esd.patient_id = e.patient_id
      INNER JOIN ever_registered_obs AS ero ON e.encounter_id = ero.encounter_id
      LEFT JOIN obs o ON o.encounter_id = e.encounter_id AND
                         o.concept_id IN (#{date_art_last_taken_concept}) AND o.voided = 0
      WHERE  ((o.concept_id = #{date_art_last_taken_concept} AND
               (DATEDIFF(o.obs_datetime,o.value_datetime)) > 56))
            AND
            esd.patient_id IN (#{patients_list.join(',')})
      GROUP BY esd.patient_id").each do | patient |
			patients_with_date_last_taken_obs << patient.patient_id.to_i
			end

    patient_ids = patients_with_date_last_taken_obs
    patient_ids = [0] if patient_ids.blank?

    PatientProgram.find_by_sql("SELECT esd.*
      FROM encounter esd
      LEFT JOIN clinic_registration_encounter e ON esd.patient_id = e.patient_id
      INNER JOIN ever_registered_obs AS ero ON e.encounter_id = ero.encounter_id
      LEFT JOIN obs o ON o.encounter_id = e.encounter_id AND
                         o.concept_id IN (#{taken_arvs_concept}) AND o.voided = 0
      WHERE  ((o.concept_id = #{taken_arvs_concept} AND o.value_coded = #{no_concept}))
            AND
            esd.patient_id IN (#{patients_list.join(',')})
            AND esd.patient_id NOT IN (#{patient_ids.join(',')})
      GROUP BY esd.patient_id").each do | patient |
        patients_with_taken_arvs_in_past_2mths_no << patient.patient_id.to_i
      end

       return patients = (patients_with_date_last_taken_obs + patients_with_taken_arvs_in_past_2mths_no).uniq
    end

	def patients_with_doses_missed_at_their_last_visit(start_date = @start_date, end_date = @end_date)
		@art_defaulters ||= self.art_defaulted_patients
		@patients_alive_and_on_art ||= self.total_alive_and_on_art(@art_defaulters)
		patient_ids = @patients_alive_and_on_art
    patient_ids = [0] if patient_ids.blank?

		doses_missed_concept = ConceptName.find_by_name("MISSED HIV DRUG CONSTRUCT").concept_id

		patients = Observation.find_by_sql("SELECT DISTINCT person_id AS person_id,
          earliest_start_date, obs.value_numeric, obs.value_text
          FROM obs INNER JOIN earliest_start_date e ON obs.person_id = e.patient_id
					AND concept_id = #{doses_missed_concept}
					AND voided = 0

					AND date_enrolled >= '#{start_date} 00:00:00'
					AND date_enrolled <= '#{end_date}'
					AND person_id IN (#{patient_ids.join(',')})")
		return patients
	end

	def patients_not_adherent_at_their_last_visit(patient_list)
		#@art_defaulters ||= self.art_defaulted_patients
		#@patients_alive_and_on_art ||= self.total_alive_and_on_art(@art_defaulters)
		patient_ids = patient_list
    patient_ids = [] if patient_ids.blank?

		art_adherence_concept = ConceptName.find_by_name("WHAT WAS THE PATIENTS ADHERENCE FOR THIS DRUG ORDER").concept_id
		art_adherence_encounter = EncounterType.find_by_name("ART ADHERENCE").id

    latest_patient_obs = Observation.find(:all, :joins => [:encounter], :select => ["MAX(obs_id) obs_id, person_id"],
      :conditions => ["concept_id = ? AND DATE(obs_datetime) <= ? AND person_id IN (?) AND " +
          "encounter_type = ? AND value_text REGEXP ?", art_adherence_concept, end_date,
        patient_ids, EncounterType.find_by_name("ART ADHERENCE").id, '^-?[0-9]+$'],
      :group => [:person_id]).map{|o| o.obs_id}.uniq

    patients = Observation.find(:all, :joins => [:encounter], :select => ["person_id"],
      :conditions => ["obs_id IN (?) AND concept_id = ? AND DATE(obs_datetime) <= ? " +
          " AND person_id IN (?) AND encounter_type = ? AND value_text REGEXP ? AND value_text < 95", latest_patient_obs,
        art_adherence_concept, end_date, patient_ids, EncounterType.find_by_name("ART ADHERENCE").id, '^-?[0-9]+$']
    ).map{|o| o.person_id.to_i}.uniq
	end

	def patients_adherent_at_their_last_visit(patient_list)
		#@art_defaulters ||= self.art_defaulted_patients
		#@patients_alive_and_on_art ||= self.total_alive_and_on_art(@art_defaulters)
		patient_ids = patient_list
    patient_ids = [] if patient_ids.blank?

    patients_ids = patient_ids - self.patients_not_adherent_at_their_last_visit(patient_ids)

    return patients_ids

=begin
		art_adherence_concept = ConceptName.find_by_name("WHAT WAS THE PATIENTS ADHERENCE FOR THIS DRUG ORDER").concept_id
		art_adherence_encounter = EncounterType.find_by_name("ART ADHERENCE").id

    latest_patient_obs = Observation.find(:all, :joins => [:encounter], :select => ["MAX(obs_id) obs_id, person_id"],
      :conditions => ["concept_id = ? AND DATE(obs_datetime) <= ? AND person_id IN (?) AND " +
          "encounter_type = ? AND value_text REGEXP ?", art_adherence_concept, end_date,
        patient_ids, EncounterType.find_by_name("ART ADHERENCE").id, '^-?[0-9]+$'],
      :group => [:person_id]).map{|o| o.obs_id}.uniq

    patients = Observation.find(:all, :joins => [:encounter], :select => ["person_id"],
      :conditions => ["obs_id IN (?) AND concept_id = ? AND DATE(obs_datetime) <= ? " +
          " AND person_id IN (?) AND encounter_type = ? AND value_text REGEXP ? AND value_text >= 95", latest_patient_obs,
        art_adherence_concept, end_date, patient_ids, EncounterType.find_by_name("ART ADHERENCE").id, '^-?[0-9]+$']
    ).map{|o| o.person_id}.uniq
=end
		#patients = Observation.find_by_sql("SELECT DISTINCT e.patient_id, person_id AS person_id,
         # earliest_start_date, current_text_for_obs(obs.person_id,#{art_adherence_encounter},#{art_adherence_concept},'#{end_date}')
         # FROM obs INNER JOIN earliest_start_date e ON obs.person_id = e.patient_id
					#AND concept_id = #{art_adherence_concept}
				#	AND voided = 0
         # AND current_text_for_obs(obs.person_id,#{art_adherence_encounter},
          #{art_adherence_concept},'#{end_date}') BETWEEN 95 AND 105

				#	AND earliest_start_date >= '#{start_date}'
				#	AND earliest_start_date <= '#{end_date}'
				#	AND person_id IN (#{patient_ids.join(',')})")
=begin
				patients = []
		Encounter.find_by_sql("SELECT distinct(person_id)
														FROM  obs
														WHERE  concept_id = #{art_adherence_concept}
														AND person_id IN (#{patient_ids.join(',')})
														AND current_text_for_obs(obs.person_id,#{art_adherence_encounter},#{art_adherence_concept},'#{end_date}') BETWEEN 95 AND 105
														AND value_text IS NOT NULL
														AND Voided = 0").each{|person|
																	patients << person.person_id
														}
		return patients
=end
	end

	def patients_with_0_to_6_doses_missed_at_their_last_visit(patient_list)
    #patients_list = patient_list.map(&:patient_id)
    return patients_adherent_at_their_last_visit(patient_list)
=begin
		doses_missed_0_to_6 = []
		self.patients_with_doses_missed_at_their_last_visit.map do |doses_missed|
			missed_dose = doses_missed.value_text if !doses_missed.value_numeric
			if missed_dose.to_i < 7
				doses_missed_0_to_6 << doses_missed.person_id
			end
		end
		return doses_missed_0_to_6
=end
	end

	def patients_with_7_plus_doses_missed_at_their_last_visit(patient_list)
    return patients_not_adherent_at_their_last_visit(patient_list)
=begin
		doses_missed_7_plus = []
		self.patients_with_doses_missed_at_their_last_visit.map do |doses_missed|
			missed_dose = doses_missed.value_text if !doses_missed.value_numeric
			if missed_dose.to_i >= 7
				doses_missed_7_plus << doses_missed.person_id
			end
		end
		return doses_missed_7_plus
=end
	end

  # EXTRAPULMONARY TUBERCULOSIS (EPTB) and Pulmonary TB (Concept Id 42)
  # 8206
  def current_episode_of_tb(patient_list, start_date = @start_date, end_date = @end_date)
    tb_concept_id = ConceptName.find_by_name("EXTRAPULMONARY TUBERCULOSIS (EPTB)").concept_id
    self.patients_with_start_cause(patient_list, start_date, end_date, [tb_concept_id, 42, 8206])
  end

  def tb_status_with_patient_ids
    tb_status_hash = {} ; status = []
    tb_status_hash['TB STATUS'] = {'Unknown' => 0,'Suspected' => 0,'Not Suspected' => 0,'On Treatment' => 0,'Not on treatment' => 0}
    tb_status_concept_id = ConceptName.find_by_name('TB STATUS').concept_id
    hiv_clinic_consultation_encounter_id = EncounterType.find_by_name('HIV CLINIC CONSULTATION').id
=begin
    status = PatientState.find_by_sql("SELECT * FROM (
                          SELECT e.patient_id,n.name tbstatus,obs_datetime,e.encounter_datetime,s.state
                          FROM patient_state s
                          LEFT JOIN patient_program p ON p.patient_program_id = s.patient_program_id
                          LEFT JOIN encounter e ON e.patient_id = p.patient_id
                          LEFT JOIN obs ON obs.encounter_id = e.encounter_id
                          LEFT JOIN concept_name n ON obs.value_coded = n.concept_id
                          WHERE p.voided = 0
                          AND s.voided = 0
                          AND obs.obs_datetime = e.encounter_datetime
                          AND (s.start_date >= '#{start_date}'
                          AND s.start_date <= '#{end_date}')
                          AND obs.concept_id = #{tb_status_concept_id}
                          AND e.encounter_type = #{hiv_clinic_consultation_encounter_id}
                          AND p.program_id = #
{@@program_id}
                          ORDER BY e.encounter_datetime DESC, patient_state_id DESC , start_date DESC) K
                          GROUP BY K.patient_id
                          ORDER BY K.encounter_datetime DESC , K.obs_datetime DESC")
=end
		status = PatientProgram.find_by_sql("SELECT e.patient_id, current_value_for_obs(e.patient_id, #{hiv_clinic_consultation_encounter_id}, #{tb_status_concept_id}, '#{end_date}') AS obs_value
												FROM earliest_start_date e
												WHERE date_enrolled <= '#{end_date}'")
  end

  def patients_with_side_effects(patient_list)
    hiv_clinic_consultation_encounter_id = EncounterType.find_by_name("HIV CLINIC CONSULTATION").id
    symptom_concept = ConceptName.find_by_name('SYMPTOM PRESENT').concept_id
    drug_induced = ConceptName.find_by_name('DRUG INDUCED').concept_id
    side_effects = ConceptName.find_by_name('MALAWI ART SIDE EFFECTS').concept_id
		no_side_effects = ConceptName.find_by_name('No').concept_id

    #@patients_alive_and_on_art ||= self.total_alive_and_on_art
		@patients_alive_and_on_art = patient_list#.map(&:patient_id)
    patient_ids = @patients_alive_and_on_art

    patient_ids = [0] if patient_ids.blank?

    side_effects_patients = Encounter.find_by_sql("SELECT e.patient_id FROM encounter e
                                          INNER JOIN obs o ON o.encounter_id = e.encounter_id
                                          WHERE e.encounter_type = #{hiv_clinic_consultation_encounter_id}
                                          AND o.person_id IN (#{patient_ids.join(',')})
                                          AND o.concept_id = #{symptom_concept}
                                          AND o.voided = 0
                                          AND o.obs_datetime BETWEEN '#{start_date}' AND '#{end_date}'
                                          AND e.patient_id IN (select os.person_id from obs os where os.voided = 0
                                          AND os.person_id = e.patient_id AND os.concept_id = #{drug_induced})
																					AND o.value_coded NOT IN (#{no_side_effects})
                                          GROUP BY e.patient_id"
                                              )

     Encounter.find_by_sql("SELECT o.person_id AS patient_id FROM obs o
                                          WHERE o.concept_id = #{side_effects}
                                          AND o.person_id IN (#{patient_ids.join(',')})
                                          AND o.voided = 0
                                          AND o.obs_datetime BETWEEN '#{start_date}' AND '#{end_date}'
																					AND o.value_coded NOT IN (#{no_side_effects})
                                          GROUP BY o.person_id"
                                              ).each{|patient| side_effects_patients << patient}

		side_effects_patients.collect{|patient| patient.patient_id}.uniq #rescue []

	end

    def side_effect_patients(start_date = @start_date, end_date = @end_date)
    side_effect_concept_ids =[ConceptName.find_by_name('PERIPHERAL NEUROPATHY').concept_id,
			ConceptName.find_by_name('LEG PAIN / NUMBNESS').concept_id,
			ConceptName.find_by_name('HEPATITIS').concept_id,
			ConceptName.find_by_name('SKIN RASH').concept_id,
			ConceptName.find_by_name('JAUNDICE').concept_id]

    encounter_type = EncounterType.find_by_name('HIV CLINIC CONSULTATION')
    concept_ids = [ConceptName.find_by_name('SYMPTOM PRESENT').concept_id,
			ConceptName.find_by_name('DRUG INDUCED').concept_id]

    encounter_ids = Encounter.find(:all,:conditions => ["encounter_type = ?
                    AND (patient_start_date(patient_id) >= '#{start_date}'
                    AND patient_start_date(patient_id) <= '#{end_date}')
                    AND (encounter_datetime >= '#{start_date}'
                    AND encounter_datetime <= '#{end_date}')",
				encounter_type.id],:group => 'patient_id',:order => 'encounter_datetime DESC').map{| e | e.encounter_id }

    Observation.find(:all,
			:conditions => ["encounter_id IN (#{encounter_ids.join(',')})
                     AND concept_id IN (?)
                     AND value_coded IN (#{side_effect_concept_ids.join(',')})",
				concept_ids],
			:group =>'person_id')
  end

  def patients_without_side_effects(patient_list)
    hiv_clinic_consultation_encounter_id = EncounterType.find_by_name("HIV CLINIC CONSULTATION").id
    symptom_concept = ConceptName.find_by_name('SYMPTOM PRESENT').concept_id
    drug_induced = ConceptName.find_by_name('DRUG INDUCED').concept_id
    side_effects = ConceptName.find_by_name('MALAWI ART SIDE EFFECTS').concept_id
		no_side_effects = ConceptName.find_by_name('No').concept_id

    @patients_alive_and_on_art ||= patient_list
    patient_ids = @patients_alive_and_on_art

    patient_ids = [0] if patient_ids.blank?

    side_effects_patients = Encounter.find_by_sql("SELECT e.patient_id FROM encounter e
                                          INNER JOIN obs o ON o.encounter_id = e.encounter_id
                                          WHERE e.encounter_type = #{hiv_clinic_consultation_encounter_id}
                                          AND o.person_id IN (#{patient_ids.join(',')})
                                          AND o.concept_id = #{symptom_concept}
                                          AND o.voided = 0
                                          AND o.obs_datetime BETWEEN '#{start_date}' AND '#{end_date}'
                                          AND e.patient_id NOT IN (select os.person_id from obs os where os.voided = 0
                                          AND os.person_id = e.patient_id AND os.concept_id = #{drug_induced})
																					AND o.value_coded in (#{no_side_effects})
                                          GROUP BY e.patient_id"
                                              ).collect{|patient| patient.patient_id} rescue []

    other_effect =   Encounter.find_by_sql("SELECT o.person_id AS patient_id FROM obs o
                                          WHERE o.concept_id = #{side_effects}
                                          AND o.person_id IN (#{patient_ids.join(',')})
                                          AND o.voided = 0
                                          AND o.obs_datetime BETWEEN '#{start_date}' AND '#{end_date}'
																					AND o.value_coded IN (#{no_side_effects})
                                          GROUP BY o.person_id"
                                              ).collect{|patient| patient.patient_id} rescue []

    no_effects = side_effects_patients + other_effect
		no_effects.uniq

	end

  private

  def cohort_regimen_name(name , age)
    case name
		when 'd4T/3TC/NVP'
			return '1A' if age > 14
			return '1P'
		when 'd4T/3TC + d4T/3TC/NVP (Starter pack)'
			return '1A' if age > 14
			return '1P'
		when 'AZT/3TC/NVP'
			return '2A' if age > 14
			return '2P'
		when 'AZT/3TC + AZT/3TC/NVP (Starter pack)'
			return '2A' if age > 14
			return '2P'
		when 'd4T/3TC/EFV'
			return '3A' if age > 14
			return '3P'
		when 'AZT/3TC+EFV'
			return '4A' if age > 14
			return '4P'
		when 'TDF/3TC/EFV'
			return '5A' if age > 14
			return '5P'
		when 'TDF/3TC+NVP'
			return '6A' if age > 14
			return '6P'
		when 'TDF/3TC+LPV/r'
			return '7A' if age > 14
			return '7P'
		when 'AZT/3TC+LPV/r'
			return '8A' if age > 14
			return '8P'
		when 'ABC/3TC+LPV/r'
			return '9A' if age > 14
			return '9P'
		else
			return 'UNKNOWN ANTIRETROVIRAL DRUG'
    end
  end
end
