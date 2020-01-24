class CohortDriller
	def self.get_cohort_difference(start_date, end_date, revised_cohort, flat_table_cumulative, flat_table_outcomes, flat_table_cpt_ipt_pfip_and_bp_screen, flat_table_pregnant_and_breastfeeding, flat_table_alive_and_ART_details)
		#revised_cohort, flat_table_cumulative, flat_table_outcomes, flat_table_cpt_ipt_pfip_and_bp_screen, flat_table_pregnant_and_breastfeeding, flat_table_alive_and_ART_details
		#raise flat_table_alive_and_ART_details.to_yaml
		#total registered revised and flat_tables

		revised_cohort_date = '2016-04-01'.to_date

		@revised_total_registered = []
		@revised_cum_total_registered = []

		@revised_total_registered = [] 
		(revised_cohort.total_registered || []).each do |patient|
			@revised_total_registered << patient["patient_id"].to_i
		end
		@revised_cum_total_registered = [] 
		(revised_cohort.cum_total_registered || []).each do |patient|
			@revised_cum_total_registered << patient["patient_id"].to_i
		end

	  @flat_total_registered 	= []
	  @flat_cum_total_reg 		=	[]
	  @flat_first_timers = []
	  @flat_cum_first_timers = []
	  @flat_re_initiated = []
	  @flat_cum_re_initiated = []
	  @flat_transfer_in = []
	  @flat_cum_transfer_in = []

	  @flat_all_males = []
	  @flat_all_females = []
	  @flat_all_pregnant_females = []
	  @flat_non_pregnant_females = []
	  @flat_cum_all_males = []
	  @flat_cum_all_females = []
	  @flat_cum_all_pregnant_females = []
	  @flat_cum_non_pregnant_females = []
	  @flat_unknown_gender = []
	  @flat_cum_unknown_gender = []

	  @flat_children_below_24_mnths = []
	  @flat_children_between_24mnths_to_24mnths = []
	  @flat_adults = []
	  @flat_unknown_age = []
	  @flat_cum_children_below_24_mnths = []
	  @flat_cum_children_between_24mnths_to_24mnths = []
	  @flat_cum_adults = []
	  @flat_cum_unknown_age = []

		@flat_presumed_severe_hiv_disease_in_infants = []
		@flat_cum_presumed_severe_hiv_disease_in_infants = []
		@flat_confirmed_hiv_infection_in_infants_pcr = []
		@flat_cum_confirmed_hiv_infection_in_infants_pcr = []
		@flat_asymptomatic = []
		@flat_cum_asymptomatic = []
		@flat_who_stage_two = []
		@flat_cum_who_stage_two = []
		@flat_children_12_23_months = []
		@flat_cum_children_12_23_months = []
		@flat_breastfeeding_mothers = []
		@flat_cum_breastfeeding_mothers = []
		@flat_pregnant_women = []
		@flat_cum_pregnant_women = []
		@flat_who_stage_three = []
		@flat_cum_who_stage_three = []
		@flat_who_stage_four = []
		@flat_cum_who_stage_four = []
		@flat_unknown_other_reason_outside_guidelines = []
		@flat_cum_unknown_other_reason_outside_guidelines = []

		@flat_kaposis_sarcoma = []
		@flat_no_tb = []
		@flat_tb_within_last_2yrs = []
		@flat_current_tb = []
		@flat_cum_kaposis_sarcoma = []
		@flat_cum_no_tb = []
		@flat_cum_tb_within_last_2yrs = []
		@flat_cum_current_tb = []

		current_episode_of_tb = ['Pulmonary tuberculosis (current)', 'Extrapulmonary tuberculosis (EPTB)', 'Pulmonary tuberculosis']
		tb_within_the_last_two_years = ['Pulmonary tuberculosis within the last 2 years', 'Ptb within the past two years']

		who_stage_2_reasons = ['WHO stage II adult', 'WHO stage II adults', 'WHO stage II peds', 'WHO stage 2', 'WHO stage I adult', 'WHO stage I peds', 'WHO stage 1', 'LYMPHOCYTE COUNT BELOW THRESHOLD WITH WHO STAGE 1', 'LYMPHOCYTE COUNT BELOW THRESHOLD WITH WHO STAGE 2', 'LYMPHOCYTES']
 		@asymptomatic_reasons = ['WHO stage II adult', 'WHO stage II adults', 'WHO stage II peds', 'WHO stage 2', 'WHO stage I adult', 'WHO stage I peds', 'WHO stage 1', 'LYMPHOCYTE COUNT BELOW THRESHOLD WITH WHO STAGE 1', 'LYMPHOCYTE COUNT BELOW THRESHOLD WITH WHO STAGE 2', 'LYMPHOCYTES']
      
		@cd4_below_threshold_reasons = ["CD4 count <= 350", "CD4 count less than or equal to 350", "CD4 count <= 750", "CD4 count less than or equal to 750", "CD4 count less than or equal to 250", "CD4 count <= 250", "CD4 count less than or equal to 500", "CD4 count <= 500"]

	  (flat_table_cumulative || []).each do |patient|
	  	date_enrolled = patient[:date_enrolled].to_date
	  	earliest_start_date = patient[:earliest_start_date].to_date

			if date_enrolled >= start_date.to_date && date_enrolled <= end_date.to_date
	  		@flat_total_registered << patient[:patient_id].to_i
	  		#patient newly stage defining conditions

	  		if patient[:kaposis_sarcoma] == "Yes"
	  			if patient[:kaposis_sarcoma_v_date] <= patient[:date_enrolled]
	  				@flat_kaposis_sarcoma << patient[:patient_id].to_i
	  			end
	  		else
		  		if patient[:who_stages_criteria_present] == "Kaposis sarcoma"
		  			if patient[:who_stages_criteria_present_v_date] <= patient[:date_enrolled]
	  					@flat_kaposis_sarcoma << patient[:patient_id].to_i
	  				end
		  		end
	  		end

	  		if patient[:pulmonary_tuberculosis] == "Yes" 
	  			if patient[:pulmonary_tuberculosis_v_date] <= patient[:date_enrolled]
	  				@flat_current_tb << patient[:patient_id].to_i
	  			end
	  		elsif patient[:extrapulmonary_tuberculosis] == "Yes"
	  			if patient[:extrapulmonary_tuberculosis_v_date] <= patient[:date_enrolled]
	  				@flat_current_tb << patient[:patient_id].to_i
	  			end
	  		else
	  			if current_episode_of_tb.include?(patient[:who_stages_criteria_present])
	  				if patient[:who_stages_criteria_present_v_date] <= patient[:date_enrolled]
	  					@flat_current_tb << patient[:patient_id].to_i
		  			end
		  		end
	  		end

	  		if patient[:pulmonary_tuberculosis_last_2_years] == "Yes"
	  			if patient[:pulmonary_tuberculosis_last_2_years_v_date] <= patient[:date_enrolled]
	  				@flat_tb_within_last_2yrs << patient[:patient_id].to_i
	  			end
	  		else
	  			if tb_within_the_last_two_years.include?(patient[:who_stages_criteria_present])
	  				if patient[:who_stages_criteria_present_v_date] <= patient[:date_enrolled]
	  					@flat_tb_within_last_2yrs << patient[:patient_id].to_i
	  				end
		  		end
	  		end

	  		#patient newly reason) for starting
	  		if patient[:reason_for_starting] == "Presumed Severe HIV" || patient[:reason_for_starting] == "Presumed severe HIV criteria in infants"
	  			@flat_presumed_severe_hiv_disease_in_infants << patient[:patient_id].to_i
	  		elsif patient[:reason_for_starting] == "Patient pregnant" || patient[:reason_for_starting] == "Patient pregnant at initiation"
	  			@flat_pregnant_women << patient[:patient_id].to_i
	  		elsif patient[:reason_for_starting] == "HIV DNA polymerase chain reaction" || patient[:reason_for_starting] == "HIV PCR"
	  			@flat_confirmed_hiv_infection_in_infants_pcr << patient[:patient_id].to_i
	  		elsif patient[:reason_for_starting] == "HIV Infected" || patient[:reason_for_starting] == "HIV infected"
	  			@flat_children_12_23_months << patient[:patient_id].to_i
	  		elsif patient[:reason_for_starting] == "Currently breastfeeding child" || patient[:reason_for_starting] == "Breastfeeding"
	  			@flat_breastfeeding_mothers << patient[:patient_id].to_i
	  		elsif patient[:reason_for_starting] == "WHO stage IV adult" || patient[:reason_for_starting] == "WHO stage IV peds" ||  patient[:reason_for_starting] == "WHO stage 4"
	  			@flat_who_stage_four << patient[:patient_id].to_i
	  		elsif patient[:reason_for_starting] == "WHO stage III adult" || patient[:reason_for_starting] == "WHO stage III peds" || patient[:reason_for_starting] == "WHO stage 3"
	  			@flat_who_stage_three << patient[:patient_id].to_i
	  		elsif patient[:reason_for_starting] == "Asymptomatic" 
	  			@flat_asymptomatic << patient[:patient_id].to_i
	  		elsif @asymptomatic_reasons.include?(patient[:reason_for_starting])
	  			if patient[:date_enrolled] >= revised_cohort_date.to_date && patient[:date_enrolled] <= end_date.to_date
	  				@flat_asymptomatic << patient[:patient_id].to_i
	  			end 
	  		elsif @cd4_below_threshold_reasons.include?(patient[:reason_for_starting])
	  			@flat_who_stage_two << patient[:patient_id].to_i
	  		end

	 			if patient[:reason_for_starting] == "Unknown"  || patient[:reason_for_starting] == 'None'
	 				@flat_unknown_other_reason_outside_guidelines << patient[:patient_id].to_i
	 			end

	 			if @asymptomatic_reasons.include?(patient[:reason_for_starting])
	  			if patient[:date_enrolled].to_date < revised_cohort_date.to_date && patient[:date_enrolled].to_date <= end_date.to_date 
	  				@flat_unknown_other_reason_outside_guidelines << patient[:patient_id].to_i
	 				end
	  		end 

	  		#patient newly age groups
	  		if patient[:age_at_initiation].to_i >= 0 && patient[:age_at_initiation].to_i < 2
	  			@flat_children_below_24_mnths << patient[:patient_id].to_i
	  		elsif patient[:age_at_initiation].to_i >= 2 && patient[:age_at_initiation].to_i < 15
	  			@flat_children_between_24mnths_to_24mnths << patient[:patient_id].to_i
	  		elsif patient[:age_at_initiation].to_i >= 15 && patient[:age_at_initiation].to_i < 500
	  			@flat_adults << patient[:patient_id].to_i
	  		else
	  			@flat_unknown_age << patient[:patient_id].to_i
	  		end

	  		#patient newly gender and pregnancy and non-pregnancy
	  		if patient[:gender] == "M"
	  			@flat_all_males << patient[:patient_id].to_i
	  		end
	  		if patient[:gender] == "F" 
	  			@flat_all_females << patient[:patient_id].to_i
	  			if patient[:patient_pregnant] == "Yes"
	  				@flat_all_pregnant_females  << patient[:patient_id].to_i
	  			end	
	  			
	  			if patient[:patient_pregnant] != "Yes" 
	  				@flat_non_pregnant_females << patient[:patient_id].to_i
	  			end
	  		else
	  			@flat_unknown_gender << patient[:patient_id].to_i
	  		end

	  		#patient newly re_initiated and transfer-ins
	  		if date_enrolled == earliest_start_date
	  			@flat_first_timers << patient[:patient_id].to_i
	  		else
	  			if !@flat_first_timers.include?(patient[:patient_id].to_i)
	  				if patient[:re_initiated] == "Re-initiated"
	  					@flat_re_initiated << patient[:patient_id].to_i
	  				else
	  					@flat_transfer_in << patient[:patient_id].to_i
	  				end
	  			end
	  		end
	  	end
	  	if date_enrolled >= "1900-01-01".to_date && date_enrolled <= end_date.to_date
	  		@flat_cum_total_reg << patient[:patient_id].to_i
	  		#stage defining conditions

	  		if patient[:kaposis_sarcoma] == "Yes"
	  			if patient[:kaposis_sarcoma_v_date] <= patient[:date_enrolled]
	  				@flat_cum_kaposis_sarcoma << patient[:patient_id].to_i
	  			end
	  		else
		  		if patient[:who_stages_criteria_present] == "Kaposis sarcoma"
		  			if !patient[:who_stages_criteria_present_v_date].blank?
			  			if patient[:who_stages_criteria_present_v_date] <= patient[:date_enrolled]
		  					@flat_cum_kaposis_sarcoma << patient[:patient_id].to_i
		  				end
		  			else
		  				@flat_cum_kaposis_sarcoma << patient[:patient_id].to_i		
		  			end
		  		end
	  		end

	  		if patient[:pulmonary_tuberculosis] == "Yes"
	  			if patient[:pulmonary_tuberculosis_v_date] <= patient[:date_enrolled]
	  				@flat_cum_current_tb << patient[:patient_id].to_i
	  			end
	  		elsif patient[:extrapulmonary_tuberculosis] == "Yes"
	  			if patient[:extrapulmonary_tuberculosis_v_date] <= patient[:date_enrolled]
	  				@flat_cum_current_tb << patient[:patient_id].to_i
	  			end
	  		else
	  			if current_episode_of_tb.include?(patient[:who_stages_criteria_present])
	  				if !patient[:who_stages_criteria_present_v_date].blank?
		  				if patient[:who_stages_criteria_present_v_date] <= patient[:date_enrolled]
		  					@flat_cum_current_tb << patient[:patient_id].to_i
			  			end
			  		else
		  				@flat_cum_current_tb << patient[:patient_id].to_i			  			
			  		end
		  		end
	  		end

	  		if patient[:pulmonary_tuberculosis_last_2_years] == "Yes"
	  			if patient[:pulmonary_tuberculosis_last_2_years_v_date] <= patient[:date_enrolled]
	  				@flat_cum_tb_within_last_2yrs << patient[:patient_id].to_i
	  			end
	  		else
	  			if tb_within_the_last_two_years.include?(patient[:who_stages_criteria_present])
	  				if !patient[:who_stages_criteria_present_v_date].blank?
	  					if patient[:who_stages_criteria_present_v_date] <= patient[:date_enrolled]
	  						@flat_cum_tb_within_last_2yrs << patient[:patient_id].to_i
	  					end
	  				else
	  					@flat_cum_tb_within_last_2yrs << patient[:patient_id].to_i
	  				end
		  		end
	  		end
	  		
	  		#patient newly reason for starting
	  		if patient[:reason_for_starting] == "Presumed Severe HIV" || patient[:reason_for_starting] == "Presumed severe HIV criteria in infants"
	  			@flat_cum_presumed_severe_hiv_disease_in_infants << patient[:patient_id].to_i
	  		end
	  		if patient[:reason_for_starting] == "Patient pregnant" || patient[:reason_for_starting] == "Patient pregnant at initiation"
	  			@flat_cum_pregnant_women << patient[:patient_id].to_i
	  		end
	  		if patient[:reason_for_starting] == "HIV DNA polymerase chain reaction" || patient[:reason_for_starting] == "HIV PCR"
	  			@flat_cum_confirmed_hiv_infection_in_infants_pcr << patient[:patient_id].to_i
	  		end
	  		if patient[:reason_for_starting] == "HIV Infected" || patient[:reason_for_starting] == "HIV infected"
	  			@flat_cum_children_12_23_months << patient[:patient_id].to_i
	  		end
	  		if patient[:reason_for_starting] == "Currently breastfeeding child" || patient[:reason_for_starting] == "Breastfeeding"
	  			@flat_cum_breastfeeding_mothers << patient[:patient_id].to_i
	  		end
	  		if patient[:reason_for_starting] == "WHO stage IV adult" || patient[:reason_for_starting] == "WHO stage IV peds" ||  patient[:reason_for_starting] == "WHO stage 4"
	  			@flat_cum_who_stage_four << patient[:patient_id].to_i
	  		end
	  		if patient[:reason_for_starting] == "WHO stage III adult" || patient[:reason_for_starting] == "WHO stage III peds" || patient[:reason_for_starting] == "WHO stage 3"
	  			@flat_cum_who_stage_three << patient[:patient_id].to_i
	  		end
	  		if patient[:reason_for_starting] == "Asymptomatic" 
	  			@flat_cum_asymptomatic << patient[:patient_id].to_i
	  		end
	  		if @asymptomatic_reasons.include?(patient[:reason_for_starting])
	  			if patient[:date_enrolled] >= revised_cohort_date.to_date && patient[:date_enrolled] <= end_date.to_date
	  				@flat_cum_asymptomatic << patient[:patient_id].to_i
	 				end
	 			end

	 			if patient[:reason_for_starting] == "Unknown"  || patient[:reason_for_starting] == 'None'
	 				@flat_cum_unknown_other_reason_outside_guidelines << patient[:patient_id].to_i
	 			end

	 			if @asymptomatic_reasons.include?(patient[:reason_for_starting])
	  			if patient[:date_enrolled].to_date < revised_cohort_date.to_date && patient[:date_enrolled].to_date <= end_date.to_date 
	  				@flat_cum_unknown_other_reason_outside_guidelines << patient[:patient_id].to_i
	 				end
	  		end 

	  		if @cd4_below_threshold_reasons.include?(patient[:reason_for_starting])
	  			@flat_cum_who_stage_two << patient[:patient_id].to_i
	  		end

	  		#patient newly age groups
	  		if patient[:age_at_initiation].to_i >= 0 && patient[:age_at_initiation].to_i < 2
	  			@flat_cum_children_below_24_mnths << patient[:patient_id].to_i
	  		end
	  		if patient[:age_at_initiation].to_i >= 2 && patient[:age_at_initiation].to_i < 15
	  			@flat_cum_children_between_24mnths_to_24mnths << patient[:patient_id].to_i
	  		end
	  		if patient[:age_at_initiation].to_i >= 15 && patient[:age_at_initiation].to_i < 500
	  			@flat_cum_adults << patient[:patient_id].to_i
	  		end

	  		if patient[:gender] == "M"
	  			@flat_cum_all_males << patient[:patient_id].to_i
	  		end

	  		if patient[:gender] == "F"
	  			@flat_cum_all_females << patient[:patient_id].to_i
	  			if patient[:patient_pregnant] == "Yes"
	  				@flat_cum_all_pregnant_females  << patient[:patient_id].to_i
	  			end	
	  			
	  			if patient[:patient_pregnant] != "Yes"
	  				@flat_cum_non_pregnant_females << patient[:patient_id].to_i
	  			end
	  		else
	  			@flat_cum_unknown_gender << patient[:patient_id].to_i
	  		end


	  		if date_enrolled == earliest_start_date
	  			@flat_cum_first_timers << patient[:patient_id].to_i
	  		else
	  			#patient newly re_initiated and transfer-ins
	  			if !@flat_cum_first_timers.include?(patient[:patient_id].to_i)
	  				if patient[:re_initiated] == "Re-initiated"
	  					@flat_cum_re_initiated << patient[:patient_id].to_i
	  				else
	  					@flat_cum_transfer_in << patient[:patient_id].to_i
	  				end
	  			end
	  		end
	  	end
	  end

	  @flat_pregnant_transfer_in = []
	  @flat_cum_pregnant_transfer_in = []
	  (@flat_all_females || []).each do |patient_id|
	  	if @flat_transfer_in.include?(patient_id) && @flat_pregnant_women.include?(patient_id)
	  		@flat_pregnant_transfer_in << patient_id
	  	end
	  end

	  (@flat_cum_all_females || []).each do |patient_id|
	  	if @flat_cum_transfer_in.include?(patient_id) && @flat_cum_pregnant_women.include?(patient_id)
	  		@flat_cum_pregnant_transfer_in << patient_id
	  	end
	  end
	  
#-------------------------------------------------------------------------------------------------------------------Total Registered

	  #Patient revised Initiated on ART for the first time
	  @revised_first_timers = []
	  @revised_cum_first_timers = []

		(revised_cohort.initiated_on_art_first_time || []).each do |patient|
			@revised_first_timers << patient["patient_id"].to_i
		end

		(revised_cohort.cum_initiated_on_art_first_time || []).each do |patient|
			@revised_cum_first_timers << patient["patient_id"].to_i
		end

		@revised_transfer_in = []
	  @revised_cum_transfer_in = []

	  (revised_cohort.transfer_in || []).each do |patient|
			@revised_transfer_in << patient["patient_id"].to_i
		end

		(revised_cohort.cum_transfer_in || []).each do |patient|
			@revised_cum_transfer_in << patient["patient_id"].to_i
		end
	 
	 	@revised_re_initiated = []
	  @revised_cum_re_initiated = []

	  (revised_cohort.re_initiated_on_art || []).each do |patient|
			@revised_re_initiated << patient["patient_id"].to_i
		end

		(revised_cohort.cum_re_initiated_on_art || []).each do |patient|
			@revised_cum_re_initiated << patient["patient_id"].to_i
		end
#-------------------------------------------------------------------------------------------------------------------Revised FT, TI and Re-IN

	  #Revised Males
	  @revised_males = []
		@revised_cum_males = []

	  (revised_cohort.all_males || []).each do |patient|
			@revised_males << patient["patient_id"].to_i
		end

		(revised_cohort.cum_all_males || []).each do |patient|
			@revised_cum_males << patient["patient_id"].to_i
		end

	  #Revised Pregnant women
	  @revised_pregnant_females = []
	  @revised_cum_pregnant_females = []

	  (revised_cohort.pregnant_females_all_ages || []).each do |patient|
			@revised_pregnant_females << patient
		end

		(revised_cohort.cum_pregnant_females_all_ages || []).each do |patient|
			@revised_cum_pregnant_females << patient
		end


	  #Revised Non-pregnant women
	  @revised_non_pregnant_females = []
	  @revised_cum_non_pregnant_females = []

	  (revised_cohort.non_pregnant_females || []).each do |patient|
			@revised_non_pregnant_females << patient["patient_id"].to_i
		end

		(revised_cohort.cum_non_pregnant_females || []).each do |patient|
			@revised_cum_non_pregnant_females << patient["patient_id"].to_i
		end
#-------------------------------------------------------------------------------------------------------------------Revised Males, Preg and Non-preg

	  #Children below  24 months on initiation
		@revised_children_below_24_months_at_art_initiation = []
		@revised_cum_children_below_24_months_at_art_initiation = []

	  (revised_cohort.children_below_24_months_at_art_initiation || []).each do |patient|
			@revised_children_below_24_months_at_art_initiation << patient["patient_id"].to_i
		end

		(revised_cohort.cum_children_below_24_months_at_art_initiation || []).each do |patient|
			@revised_cum_children_below_24_months_at_art_initiation << patient["patient_id"].to_i
		end

	  #Children 24months - 14 years at ART initiation
	  @revised_children_24_months_14_years_at_art_initiation = []
	  @revised_cum_children_24_months_14_years_at_art_initiation = []

	  (revised_cohort.children_24_months_14_years_at_art_initiation || []).each do |patient|
			@revised_children_24_months_14_years_at_art_initiation << patient["patient_id"].to_i
		end

		(revised_cohort.cum_children_24_months_14_years_at_art_initiation || []).each do |patient|
			@revised_cum_children_24_months_14_years_at_art_initiation << patient["patient_id"].to_i
		end

	  #Adults
	  @revised_adults_at_art_initiation = []
	  @revised_cum_adults_at_art_initiation = []

	  (revised_cohort.adults_at_art_initiation || []).each do |patient|
			@revised_adults_at_art_initiation << patient["patient_id"].to_i
		end

		(revised_cohort.cum_adults_at_art_initiation || []).each do |patient|
			@revised_cum_adults_at_art_initiation << patient["patient_id"].to_i
		end

	  #unknown age
	  @revised_unknown_age = []
	  @revised_cum_unknown_age = []

	  (revised_cohort.unknown_age || []).each do |patient|
			@revised_unknown_age << patient["patient_id"].to_i
		end

		(revised_cohort.cum_unknown_age || []).each do |patient|
			@revised_cum_unknown_age << patient["patient_id"].to_i
		end
#-------------------------------------------------------------------------------------------------------------------Revised children, adults and unknown age	  

	  #Reason for starting
	  @revised_presumed_severe_hiv_disease_in_infants = []
		@revised_cum_presumed_severe_hiv_disease_in_infants = []

		(revised_cohort.presumed_severe_hiv_disease_in_infants || []).each do |patient|
			@revised_presumed_severe_hiv_disease_in_infants << patient[:patient_id].to_i
		end

		(revised_cohort.cum_presumed_severe_hiv_disease_in_infants || []).each do |patient|
			@revised_cum_presumed_severe_hiv_disease_in_infants << patient[:patient_id].to_i
		end

		@revised_confirmed_hiv_infection_in_infants_pcr = []
		@revised_cum_confirmed_hiv_infection_in_infants_pcr = []

		(revised_cohort.confirmed_hiv_infection_in_infants_pcr || []).each do |patient|
			@revised_confirmed_hiv_infection_in_infants_pcr << patient[:patient_id].to_i
		end

		(revised_cohort.cum_confirmed_hiv_infection_in_infants_pcr || []).each do |patient|
			@revised_cum_confirmed_hiv_infection_in_infants_pcr << patient[:patient_id].to_i
		end

		@revised_asymptomatic = []
		@revised_cum_asymptomatic = []

		(revised_cohort.asymptomatic || []).each do |patient|
			@revised_asymptomatic << patient[:patient_id].to_i
		end

		(revised_cohort.cum_asymptomatic || []).each do |patient|
			@revised_cum_asymptomatic << patient[:patient_id].to_i
		end

		@revised_who_stage_two = []
		@revised_cum_who_stage_two = []

		(revised_cohort.who_stage_two || []).each do |patient|
			@revised_who_stage_two << patient[:patient_id].to_i
		end

		(revised_cohort.cum_who_stage_two || []).each do |patient|
			@revised_cum_who_stage_two << patient[:patient_id].to_i
		end

		@revised_children_12_23_months = []
		@revised_cum_children_12_23_months = []

		(revised_cohort.children_12_23_months || []).each do |patient|
			@revised_children_12_23_months << patient[:patient_id].to_i
		end

		(revised_cohort.cum_children_12_23_months || []).each do |patient|
			@revised_cum_children_12_23_months << patient[:patient_id].to_i
		end

		@revised_breastfeeding_mothers = []
		@revised_cum_breastfeeding_mothers = []

		(revised_cohort.breastfeeding_mothers || []).each do |patient|
			@revised_breastfeeding_mothers << patient[:patient_id].to_i
		end

		(revised_cohort.cum_breastfeeding_mothers || []).each do |patient|
			@revised_cum_breastfeeding_mothers << patient[:patient_id].to_i
		end

		@revised_pregnant_women = []
		@revised_cum_pregnant_women = []

		(revised_cohort.pregnant_women || []).each do |patient|
			@revised_pregnant_women << patient[:patient_id].to_i
		end

		(revised_cohort.cum_pregnant_women || []).each do |patient|
			@revised_cum_pregnant_women << patient[:patient_id].to_i
		end

		@revised_who_stage_three = []
		@revised_cum_who_stage_three = []

		(revised_cohort.who_stage_three || []).each do |patient|
			@revised_who_stage_three << patient[:patient_id].to_i
		end

		(revised_cohort.cum_who_stage_three || []).each do |patient|
			@revised_cum_who_stage_three << patient[:patient_id].to_i
		end

		@revised_who_stage_four = []
		@revised_cum_who_stage_four = []

		(revised_cohort.who_stage_four || []).each do |patient|
			@revised_who_stage_four << patient[:patient_id].to_i
		end

		(revised_cohort.cum_who_stage_four || []).each do |patient|
			@revised_cum_who_stage_four << patient[:patient_id].to_i
		end

		@revised_unknown_other_reason_outside_guidelines = []
		@revised_cum_unknown_other_reason_outside_guidelines = []

		(revised_cohort.unknown_other_reason_outside_guidelines || []).each do |patient|
			@revised_unknown_other_reason_outside_guidelines << patient[:patient_id].to_i
		end

		(revised_cohort.cum_unknown_other_reason_outside_guidelines || []).each do |patient|
			@revised_cum_unknown_other_reason_outside_guidelines << patient[:patient_id].to_i
		end
#-------------------------------------------------------------------------------------------------------------------Revised reason for starting  

	  #No TB
	  @revised_cum_no_tb = []
		@revised_no_tb = []

		(revised_cohort.no_tb || []).each do |patient|
			@revised_no_tb << patient
		end

		(revised_cohort.cum_no_tb || []).each do |patient|
			@revised_cum_no_tb << patient
		end
	  
	  #TB within 2 years
	  @revised_tb_within_the_last_two_years = []
	  @revised_cum_tb_within_the_last_two_years = []

		(revised_cohort.tb_within_the_last_two_years || []).each do |patient|
			@revised_tb_within_the_last_two_years << patient["patient_id"].to_i
		end

		(revised_cohort.cum_tb_within_the_last_two_years || []).each do |patient|
			@revised_cum_tb_within_the_last_two_years << patient["patient_id"].to_i
		end

	  #Current TB
	  @revised_current_episode_of_tb = []
		@revised_cum_current_episode_of_tb = []
		
		(revised_cohort.current_episode_of_tb || []).each do |patient|
			@revised_current_episode_of_tb << patient["patient_id"].to_i
		end

		(revised_cohort.cum_current_episode_of_tb || []).each do |patient|
			@revised_cum_current_episode_of_tb << patient["patient_id"].to_i
		end

	  #KS
	  @revised_kaposis_sarcoma = []
		@revised_cum_kaposis_sarcoma = []

		(revised_cohort.kaposis_sarcoma || []).each do |patient|
			@revised_kaposis_sarcoma << patient["patient_id"].to_i
		end

		(revised_cohort.cum_kaposis_sarcoma || []).each do |patient|
			@revised_cum_kaposis_sarcoma << patient["patient_id"].to_i
		end
#-------------------------------------------------------------------------------------------------------------------Revised Stage defining conditions  

		#Alive and on ARVs
		@revised_total_alive_and_on_art  = []

		(revised_cohort.total_alive_and_on_art || []).each do |patient|
			@revised_total_alive_and_on_art << patient["patient_id"].to_i
		end

		#Died
		@revised_died_within_the_1st_month_of_art_initiation = []

		(revised_cohort.died_within_the_1st_month_of_art_initiation || []).each do |patient|
			@revised_died_within_the_1st_month_of_art_initiation << patient["patient_id"].to_i
		end

		@revised_died_within_the_2nd_month_of_art_initiation = []
		
		(revised_cohort.died_within_the_2nd_month_of_art_initiation || []).each do |patient|
			@revised_died_within_the_2nd_month_of_art_initiation << patient["patient_id"].to_i
		end

		@revised_died_within_the_3rd_month_of_art_initiation = []

		(revised_cohort.died_within_the_3rd_month_of_art_initiation || []).each do |patient|
			@revised_died_within_the_3rd_month_of_art_initiation << patient["patient_id"].to_i
		end

		@revised_died_after_the_3rd_month_of_art_initiation  = []
		
		(revised_cohort.died_after_the_3rd_month_of_art_initiation || []).each do |patient|
			@revised_died_after_the_3rd_month_of_art_initiation << patient["patient_id"].to_i
		end		

		@revised_died_total = []
		
		(revised_cohort.died_total || []).each do |patient|
			@revised_died_total << patient["patient_id"].to_i
		end
		
		#defaulter
		@revised_defaulted = []

		(revised_cohort.defaulted || []).each do |patient|
			@revised_defaulted << patient["patient_id"].to_i
		end

		#Stopped ART
		@revised_stopped_art = []

		(revised_cohort.stopped_art || []).each do |patient|
			@revised_stopped_art << patient["patient_id"].to_i
		end

		#transferred out
		@revised_transfered_out = []

		(revised_cohort.transfered_out || []).each do |patient|
			@revised_transfered_out << patient["patient_id"].to_i
		end

		#unknown outcome
		@revised_unknown_outcome = []
		
		(revised_cohort.unknown_outcome || []).each do |patient|
			@revised_unknown_outcome << patient["patient_id"].to_i
		end		
#-------------------------------------------------------------------------------------------------------------------Revised Patient Outcomes		
		@flat_total_alive_and_on_art = []
		@flat_died_total = []
		@flat_transfered_out = []
		@flat_defaulted = []
		@flat_stopped_art = []
		@flat_unknown_outcome = []
		@flat_died_within_the_1st_month_of_art_initiation = []
		@flat_died_within_the_2nd_month_of_art_initiation = []
		@flat_died_within_the_3rd_month_of_art_initiation = []
		@flat_died_after_the_3rd_month_of_art_initiation  = []

		(flat_table_outcomes || []).each do |patient|
			if patient[:cum_outcome] == "On antiretrovirals"
				@flat_total_alive_and_on_art << patient[:patient_id].to_i
			elsif patient[:cum_outcome] == "Patient died"
				@flat_died_total << patient[:patient_id].to_i
			elsif patient[:cum_outcome] == "Patient transferred out"
				@flat_transfered_out << patient[:patient_id].to_i
			elsif patient[:cum_outcome] == "Defaulted"
				@flat_defaulted << patient[:patient_id].to_i
			elsif patient[:cum_outcome] == "Treatment stopped"
				@flat_stopped_art << patient[:patient_id].to_i
			else
				@flat_unknown_outcome << patient[:patient_id].to_i
			end

			if patient[:died_in] == "1st month"
				@flat_died_within_the_1st_month_of_art_initiation << patient[:patient_id].to_i
			elsif patient[:died_in] == "2nd month"
				@flat_died_within_the_2nd_month_of_art_initiation << patient[:patient_id].to_i
			elsif patient[:died_in] == "3rd month"
				@flat_died_within_the_3rd_month_of_art_initiation << patient[:patient_id].to_i
			elsif patient[:died_in] == "4+ months"
				@flat_died_after_the_3rd_month_of_art_initiation << patient[:patient_id].to_i
			end
		end
#-------------------------------------------------------------------------------------------------------------------Flat Patient Outcomes		
  	@revised_zero_a = []
   	(revised_cohort.zero_a || []).each do |patient|
			@revised_zero_a << patient[:patient_id].to_i
		end

   	@revised_zero_p = [] 
		
		(revised_cohort.zero_p || []).each do |patient|
			@revised_zero_p << patient[:patient_id].to_i
		end

   	@revised_two_a = [] 
   	
		(revised_cohort.two_a || []).each do |patient|
			@revised_two_a << patient[:patient_id].to_i
		end

   	@revised_two_p = [] 

		(revised_cohort.two_p || []).each do |patient|
			@revised_two_p << patient[:patient_id].to_i
		end

   	@revised_four_a = [] 
   	
		(revised_cohort.four_a || []).each do |patient|
			@revised_four_a << patient[:patient_id].to_i
		end

   	@revised_four_p = [] 
   	
		(revised_cohort.four_p || []).each do |patient|
			@revised_four_p << patient[:patient_id].to_i
		end

   	@revised_five_a = [] 
   	
		(revised_cohort.five_a || []).each do |patient|
			@revised_five_a << patient[:patient_id].to_i
		end


   	@revised_six_a = []
   
		(revised_cohort.six_a || []).each do |patient|
			@revised_six_a << patient[:patient_id].to_i
		end


   	@revised_seven_a = [] 
   	
		(revised_cohort.seven_a || []).each do |patient|
			@revised_seven_a << patient[:patient_id].to_i
		end

   	@revised_eight_a = [] 
   	
		(revised_cohort.eight_a || []).each do |patient|
			@revised_eight_a << patient[:patient_id].to_i
		end

   	@revised_nine_a = [] 
   	
   	(revised_cohort.nine_a || []).each do |patient|
			@revised_nine_a << patient[:patient_id].to_i
		end

   	@revised_nine_p = [] 
   	
		(revised_cohort.nine_p || []).each do |patient|
			@revised_nine_p << patient[:patient_id].to_i
		end

   	@revised_ten_a = [] 
   	
		(revised_cohort.ten_a || []).each do |patient|
			@revised_ten_a << patient[:patient_id].to_i
		end

   	@revised_elleven_a = [] 
   	
   	(revised_cohort.elleven_a || []).each do |patient|
			@revised_elleven_a << patient[:patient_id].to_i
		end
   	
   	@revised_elleven_p = [] 
   	
		(revised_cohort.elleven_p || []).each do |patient|
			@revised_elleven_p << patient[:patient_id].to_i
		end

   	@revised_twelve_a = [] 
   	
		(revised_cohort.twelve_a || []).each do |patient|
			@revised_twelve_a << patient[:patient_id].to_i
		end

   	@revised_unknown_regimen = []

		(revised_cohort.unknown_regimen || []).each do |patient|
			@revised_unknown_regimen << patient[:patient_id].to_i
		end
#-------------------------------------------------------------------------------------------------------------------Revised patient regimen
		@flat_zero_a = []
   	@flat_zero_p = []  
   	@flat_two_a = [] 
   	@flat_two_p = [] 
   	@flat_four_a = [] 
   	@flat_four_p = [] 
   	@flat_five_a = [] 
   	@flat_six_a = []
   	@flat_seven_a = [] 
   	@flat_eight_a = [] 
    @flat_nine_a = [] 
   	@flat_nine_p = [] 
   	@flat_ten_a = [] 
   	@flat_elleven_a = [] 
   	@flat_elleven_p = [] 
   	@flat_twelve_a = [] 
   	@flat_unknown_regimen = []

   	@flat_tb_not_suspected = []
		@flat_tb_suspected = []
		@flat_tb_confirmed_currently_not_yet_on_tb_treatment = []
		@flat_tb_confirmed_on_tb_treatment = []
		@flat_unknown_tb_status = []

		@flat_patients_with_0_6_doses_missed_at_their_last_visit = []
		@flat_patients_with_7_plus_doses_missed_at_their_last_visit = []
		@flat_patients_with_unknown_adhrence = []

		@flat_total_patients_with_side_effects = []
		@flat_total_patients_without_side_effects = []


		(@flat_total_alive_and_on_art || []).each do |patient_id|
			(flat_table_alive_and_ART_details || []).each do |patient|
				if patient[:patient_id].to_i == patient_id
					#regimen category
					if patient[:regimen_category] == "0A"
						@flat_zero_a << patient[:patient_id].to_i
					elsif patient[:regimen_category] == "0P"
						@flat_zero_p << patient[:patient_id].to_i
					elsif patient[:regimen_category] == "1A"
						@flat_unknown_regimen << patient[:patient_id].to_i
					elsif patient[:regimen_category] ==	"1P"
						@flat_unknown_regimen << patient[:patient_id].to_i
					elsif patient[:regimen_category] == "2A"
						@flat_two_a << patient[:patient_id].to_i
					elsif patient[:regimen_category] == "2P"
						@flat_two_p << patient[:patient_id].to_i
					elsif patient[:regimen_category] == "3A"
						@flat_unknown_regimen << patient[:patient_id].to_i
					elsif patient[:regimen_category] == "3P"
						@flat_unknown_regimen << patient[:patient_id].to_i
					elsif patient[:regimen_category] == "4A"
						@flat_four_a << patient[:patient_id].to_i
					elsif patient[:regimen_category] == "4P"
						@flat_four_p << patient[:patient_id].to_i
					elsif patient[:regimen_category] == "5A"
						@flat_five_a << patient[:patient_id].to_i
					elsif patient[:regimen_category] == "6A"
						@flat_six_a << patient[:patient_id].to_i
					elsif patient[:regimen_category] == "7A"
						@flat_seven_a << patient[:patient_id].to_i
					elsif patient[:regimen_category] ==	"8A"
						@flat_eight_a << patient[:patient_id].to_i
					elsif patient[:regimen_category] == "9A"
						@flat_nine_a << patient[:patient_id].to_i
					elsif patient[:regimen_category] == "9P"
						@flat_nine_p << patient[:patient_id].to_i
					elsif patient[:regimen_category] == "10A"
						@flat_ten_a << patient[:patient_id].to_i
					elsif patient[:regimen_category] == "11A"
						@flat_elleven_a << patient[:patient_id].to_i
					elsif patient[:regimen_category] == "11P"
						@flat_elleven_p << patient[:patient_id].to_i
					elsif patient[:regimen_category] == "12A"
						@flat_twelve_a << patient[:patient_id].to_i
					else
						@flat_unknown_regimen << patient[:patient_id].to_i					
					end


					#adherence
					if patient[:patient_art_adherence] == "Adherent"
						@flat_patients_with_0_6_doses_missed_at_their_last_visit << patient[:patient_id].to_i
					elsif patient[:patient_art_adherence] == "Not adherent"
						@flat_patients_with_7_plus_doses_missed_at_their_last_visit << patient[:patient_id].to_i
					end

					#side effects
					if patient[:patient_side_effect] == "Yes"
						@flat_total_patients_with_side_effects << patient[:patient_id].to_i
					elsif patient[:patient_side_effect] == "No"
						@flat_total_patients_without_side_effects << patient[:patient_id].to_i
					end

					#TB status
					if patient[:tb_status] == "TB NOT Suspected"
						@flat_tb_not_suspected << patient[:patient_id].to_i
					elsif patient[:tb_status] == "TB Suspected"
						@flat_tb_suspected << patient[:patient_id].to_i
					elsif patient[:tb_status] == "Confirmed TB on treatment"
						@flat_tb_confirmed_on_tb_treatment << patient[:patient_id].to_i
					elsif patient[:tb_status] == "TB Confirmed NOT on treatment"
						@flat_tb_confirmed_currently_not_yet_on_tb_treatment << patient[:patient_id].to_i
					elsif patient[:tb_status] == "Confirmed TB NOT on treatment"
						@flat_tb_confirmed_currently_not_yet_on_tb_treatment << patient[:patient_id].to_i 
					end

				end
			end
		end
#-------------------------------------------------------------------------------------------------------------------Flat patient regimen, adherence, TB status and side effects

   	@revised_patients_with_0_6_doses_missed_at_their_last_visit = []

		(revised_cohort.patients_with_0_6_doses_missed_at_their_last_visit || []).each do |patient|
			@revised_patients_with_0_6_doses_missed_at_their_last_visit << patient
		end

   	@revised_patients_with_7_plus_doses_missed_at_their_last_visit = []
   	
		(revised_cohort.patients_with_7_plus_doses_missed_at_their_last_visit || []).each do |patient|
			@revised_patients_with_7_plus_doses_missed_at_their_last_visit << patient
		end
   	
   	@revised_patients_with_unknown_adhrence = []
	
		(revised_cohort.patients_with_unknown_adhrence || []).each do |patient|
			@revised_patients_with_unknown_adhrence << patient
		end
#-------------------------------------------------------------------------------------------------------------------Revised patient adherence		

    @revised_tb_not_suspected = []
    @revised_tb_suspected	= []
		@revised_tb_confirmed_currently_not_yet_on_tb_treatment = []
		@revised_tb_confirmed_on_tb_treatment = []
		@revised_unknown_tb_status = []
   	
		(revised_cohort.tb_not_suspected || []).each do |patient|
			@revised_tb_not_suspected << patient[:patient_id].to_i 
		end

   	@revised_tb_suspected = []
   	
		(revised_cohort.tb_suspected || []).each do |patient|
			@revised_tb_suspected << patient[:patient_id].to_i 
		end

   	@revised_tb_confirmed_currently_not_yet_on_tb_treatment = []

		(revised_cohort.tb_confirmed_currently_not_yet_on_tb_treatment || []).each do |patient|
			@revised_tb_confirmed_currently_not_yet_on_tb_treatment << patient[:patient_id].to_i 
		end

   	@revised_tb_confirmed_on_tb_treatment = []
		
		(revised_cohort.tb_confirmed_on_tb_treatment || []).each do |patient|
			@revised_tb_confirmed_on_tb_treatment << patient[:patient_id].to_i 
		end

   	@revised_unknown_tb_status = []

		(revised_cohort.unknown_tb_status || []).each do |patient|
			@revised_unknown_tb_status << patient[:patient_id].to_i 
		end
#-------------------------------------------------------------------------------------------------------------------Revised TB status

	  @revised_total_patients_with_side_effects = []

		(revised_cohort.total_patients_with_side_effects || []).each do |patient|
			@revised_total_patients_with_side_effects << patient["patient_id"].to_i
		end

   	@revised_total_patients_without_side_effects = [] 
   
		(revised_cohort.total_patients_without_side_effects || []).each do |patient|
			@revised_total_patients_without_side_effects << patient
		end

   @revised_unknown_side_effects = []

		(revised_cohort.unknown_side_effects || []).each do |patient|
			@revised_unknown_side_effects << patient
		end
#-------------------------------------------------------------------------------------------------------------------Revised Side Effects
	
		@revised_total_pregnancy	=	[]
		@revised_total_breastfeeding	=	[]
		@revised_other_patient	= []

		(revised_cohort.total_pregnant_women || []).each do |patient|
			@revised_total_pregnancy << patient["person_id"].to_i
		end

		(revised_cohort.total_breastfeeding_women || []).each do |patient|
			@revised_total_breastfeeding << patient["person_id"].to_i
		end

		(revised_cohort.total_other_patients || []).each do |patient|
			@revised_other_patient << patient
		end
#-------------------------------------------------------------------------------------------------------------------Revised Total Pregnant and Breastfeeding
		@flat_other_patient = []
		@flat_patient_pregnant = []
		@flat_patient_breastfeeding = []

		(flat_table_pregnant_and_breastfeeding || []).each do |patient|
		 	if patient[:patient_pregnant] == "Yes"
		 		@flat_patient_pregnant << patient[:patient_id].to_i
		 	end
		 	if patient[:patient_breastfeeding] == "Yes"
		 		@flat_patient_breastfeeding << patient[:patient_id].to_i
		 	end
		 	if patient[:other_patient] == "Other Patient"
		 		@flat_other_patient << patient[:patient_id].to_i
		 	end
		 end
#-------------------------------------------------------------------------------------------------------------------Flat Total Pregnant and Breastfeeding

	@flat_cpt_ids = []
	@flat_ipt_ids = []
	@flat_pfip_ids = []
	@flat_bp_screen_ids = []

	(flat_table_cpt_ipt_pfip_and_bp_screen || []).each do |patient|
		@flat_cpt_idsa = patient[:cpt_ids].to_a
		@flat_ipt_idsa = patient[:ipt_ids].to_a
		@flat_pfip_idsa = patient[:pfip_ids].to_a
		@flat_bp_screen_idsa = patient[:bp_screen_ids].to_a
	end

	(@flat_cpt_idsa || []).each do |p|
		@flat_cpt_ids << p
	end

	(@flat_ipt_idsa || []).each do |p|
		@flat_ipt_ids << p
	end

	(@flat_pfip_idsa || []).each do |p|
		@flat_pfip_ids << p
	end

	(@flat_bp_screen_idsa || []).each do |p|
		@flat_bp_screen_ids << p
	end

	@revised_cpt_ids = []
	@revised_ipt_ids = []
	@revised_pfip_ids = []
	@revised_bp_screen_ids = []

	(revised_cohort.total_patients_with_screened_bp_ids || []).each do |bp|
		@revised_bp_screen_ids << bp["person_id"].to_i
	end

	(revised_cohort.total_patients_on_arvs_and_cpt_ids || []).each do |cpt|
		@revised_cpt_ids << cpt["patient_id"].to_i 
	end

	(revised_cohort.total_patients_on_arvs_and_ipt_ids || []).each do |ipt|
		@revised_ipt_ids << ipt["patient_id"].to_i 
	end

	(revised_cohort.total_patients_on_family_planning_ids || []).each do |pfip|
		@revised_pfip_ids << pfip["person_id"].to_i
	end
#-------------------------------------------------------------------------------------------------------------------cpt/ipt/bp screen/pfip% both flat and revised

		@total_registered_diff = @revised_total_registered - @flat_total_registered | @flat_total_registered - @revised_total_registered
		@total_cum_registered_diff = @revised_cum_total_registered - @flat_cum_total_reg | @flat_cum_total_reg - @revised_cum_total_registered

		@first_timers_diff = @revised_first_timers - @flat_first_timers | @flat_first_timers - @revised_first_timers
		@cum_first_times_diff	= @revised_cum_first_timers - @flat_cum_first_timers | @flat_cum_first_timers - @revised_cum_first_timers
		
		@transfer_in_diff = @revised_transfer_in - @flat_transfer_in | @flat_transfer_in - @revised_transfer_in
		@cum_transfer_in_diff = @revised_cum_transfer_in - @flat_cum_transfer_in | @flat_cum_transfer_in - @revised_cum_transfer_in
		
		@re_initiated_diff = 	@revised_re_initiated - @flat_re_initiated | @flat_re_initiated - @revised_re_initiated
		@cum_re_initiated_diff = @revised_cum_re_initiated - @flat_cum_re_initiated | @flat_cum_re_initiated - @revised_cum_re_initiated

		@flat_all_preg_females = @flat_pregnant_transfer_in + @flat_all_pregnant_females
		@flat_cum_all_preg_females = @flat_cum_pregnant_transfer_in + @flat_cum_all_pregnant_females

		@flat_all_non_pregnant_females = @flat_all_females - @flat_all_preg_females
		@flat_cum_all_non_pregnant_females = @flat_cum_all_females - @flat_cum_all_preg_females

		@male_diff = @revised_males - @flat_all_males | @flat_all_males - @revised_males
		@cum_male_diff = @revised_cum_males - @flat_cum_all_males | @flat_cum_all_males - @revised_cum_males
		
		@pregnant_females__diff = @revised_pregnant_females - @flat_all_preg_females | @flat_all_preg_females - @revised_pregnant_females
		@cum_pregnant_females_diff = @revised_cum_pregnant_females - @flat_cum_all_preg_females | @flat_cum_all_preg_females - @revised_cum_pregnant_females
		
		@non_pregnant_diff = @revised_non_pregnant_females - @flat_all_non_pregnant_females | @flat_all_non_pregnant_females - @revised_non_pregnant_females
		@cum_non_pregnant = @revised_cum_non_pregnant_females - @flat_cum_all_non_pregnant_females | @flat_cum_all_non_pregnant_females - @revised_cum_non_pregnant_females

		#age groups
		@revised_unknown_age = @revised_total_registered - (@revised_children_below_24_months_at_art_initiation + @revised_children_24_months_14_years_at_art_initiation + @revised_adults_at_art_initiation)
		@revised_cum_unknown_age = @revised_cum_total_registered - (@revised_cum_children_below_24_months_at_art_initiation + @revised_cum_children_24_months_14_years_at_art_initiation + @revised_cum_adults_at_art_initiation)

		@children_below_24_months_at_art_initiation_diff = @revised_children_below_24_months_at_art_initiation - @flat_children_below_24_mnths | @flat_children_below_24_mnths - @revised_children_below_24_months_at_art_initiation
		@cum_children_below_24_months_at_art_initiation_diff = @revised_cum_children_below_24_months_at_art_initiation - @flat_cum_children_below_24_mnths | @flat_cum_children_below_24_mnths - @revised_cum_children_below_24_months_at_art_initiation
		
		@children_24_months_14_years_at_art_initiation_diff = @revised_children_24_months_14_years_at_art_initiation - @flat_children_between_24mnths_to_24mnths | @flat_children_between_24mnths_to_24mnths - @revised_children_24_months_14_years_at_art_initiation
		@cum_children_24_months_14_years_at_art_initiation_diff = @revised_cum_children_24_months_14_years_at_art_initiation - @flat_cum_children_between_24mnths_to_24mnths | @flat_cum_children_between_24mnths_to_24mnths - @revised_cum_children_24_months_14_years_at_art_initiation
		
		@adults_at_art_diff = @revised_adults_at_art_initiation - @flat_adults | @flat_adults - @revised_adults_at_art_initiation
		@cum_adults_at_art_initiation_diff = @revised_cum_adults_at_art_initiation - @flat_cum_adults | @flat_cum_adults - @revised_cum_adults_at_art_initiation
		
		@unknown_age_diff = @revised_unknown_age - @flat_unknown_age | @flat_unknown_age - @revised_unknown_age
		@cum_unknown_age_diff = @revised_cum_unknown_age - @flat_cum_unknown_age | @flat_cum_unknown_age - @revised_cum_unknown_age

		#Reason for startin
		@presumed_severe_hiv_disease_in_infants_diff = @revised_presumed_severe_hiv_disease_in_infants - @flat_presumed_severe_hiv_disease_in_infants | @flat_presumed_severe_hiv_disease_in_infants - @revised_presumed_severe_hiv_disease_in_infants
		@cum_presumed_severe_hiv_disease_in_infants_diff = @revised_cum_presumed_severe_hiv_disease_in_infants - @flat_cum_presumed_severe_hiv_disease_in_infants | @flat_cum_presumed_severe_hiv_disease_in_infants - @revised_cum_presumed_severe_hiv_disease_in_infants
		
		@confirmed_hiv_infection_in_infants_pcr_diff = @revised_confirmed_hiv_infection_in_infants_pcr - @flat_confirmed_hiv_infection_in_infants_pcr | @flat_confirmed_hiv_infection_in_infants_pcr - @revised_confirmed_hiv_infection_in_infants_pcr
		@cum_confirmed_hiv_infection_in_infants_pcr_diff = @revised_cum_confirmed_hiv_infection_in_infants_pcr - @flat_cum_confirmed_hiv_infection_in_infants_pcr | @flat_cum_confirmed_hiv_infection_in_infants_pcr - @revised_cum_confirmed_hiv_infection_in_infants_pcr
		
		@asymptomatic_diff = @revised_asymptomatic - @flat_asymptomatic | @flat_asymptomatic - @revised_asymptomatic
		@cum_asymptomatic_diff = @revised_cum_asymptomatic - @flat_cum_asymptomatic | @flat_cum_asymptomatic - @revised_cum_asymptomatic
		
		@who_stage_two_diff = @revised_who_stage_two - @flat_who_stage_two | @flat_who_stage_two - @revised_who_stage_two
		@cum_who_stage_two_diff = @revised_cum_who_stage_two - @flat_cum_who_stage_two | @flat_cum_who_stage_two - @revised_cum_who_stage_two
		
		@children_12_23_months_diff = @revised_children_12_23_months - @flat_children_12_23_months | @flat_children_12_23_months - @revised_children_12_23_months
		@cum_children_12_23_months_diff = @revised_cum_children_12_23_months - @flat_cum_children_12_23_months | @flat_cum_children_12_23_months - @revised_cum_children_12_23_months
		
		@breastfeeding_mothers_diff = @revised_breastfeeding_mothers - @flat_breastfeeding_mothers | @flat_breastfeeding_mothers - @revised_breastfeeding_mothers
		@cum_breastfeeding_mothers_diff = @revised_cum_breastfeeding_mothers - @flat_cum_breastfeeding_mothers | @flat_cum_breastfeeding_mothers - @revised_cum_breastfeeding_mothers
		
		@pregnant_women_diff = @revised_pregnant_women - @flat_pregnant_women | @flat_pregnant_women - @revised_pregnant_women
		@cum_pregnant_women_diff = @revised_cum_pregnant_women - @flat_cum_pregnant_women | @flat_cum_pregnant_women - @revised_cum_pregnant_women
		
		@who_stage_three_diff = @revised_who_stage_three - @flat_who_stage_three | @flat_who_stage_three - @revised_who_stage_three
		@cum_who_stage_three_diff = @revised_cum_who_stage_three - @flat_cum_who_stage_three | @flat_cum_who_stage_three - @revised_cum_who_stage_three
		
		@who_stage_four_diff = @revised_who_stage_four- @flat_who_stage_four | @flat_who_stage_four - @revised_who_stage_four
		@cum_who_stage_four_diff = @revised_cum_who_stage_four -  @flat_cum_who_stage_four | @flat_cum_who_stage_four - @revised_cum_who_stage_four
		
		@unknown_other_reason_outside_guidelines_diff = @revised_unknown_other_reason_outside_guidelines - @flat_unknown_other_reason_outside_guidelines | @flat_unknown_other_reason_outside_guidelines - @revised_unknown_other_reason_outside_guidelines
		@cum_unknown_other_reason_outside_guidelines_diff = @revised_cum_unknown_other_reason_outside_guidelines - @flat_cum_unknown_other_reason_outside_guidelines | @flat_cum_unknown_other_reason_outside_guidelines - @revised_cum_unknown_other_reason_outside_guidelines
		
		@tb_within_the_last_two_years_flat = @flat_tb_within_last_2yrs - @flat_current_tb
		@cum_tb_within_the_last_two_years_flat = @flat_cum_tb_within_last_2yrs - @flat_cum_current_tb
		
		@unknown_tb_flat = @flat_total_registered - (@flat_current_tb + @tb_within_the_last_two_years_flat)
		@cum_unknown_tb_flat = @flat_cum_total_reg - (@flat_cum_current_tb + @cum_tb_within_the_last_two_years_flat)

		@cum_no_tb_diff = @revised_cum_no_tb - @cum_unknown_tb_flat | @cum_unknown_tb_flat - @revised_cum_no_tb  
		@no_tb_diff = @revised_no_tb - @unknown_tb_flat | @unknown_tb_flat - @revised_no_tb


		@tb_within_the_last_two_years_diff = @revised_tb_within_the_last_two_years - @tb_within_the_last_two_years_flat | @tb_within_the_last_two_years_flat - @revised_tb_within_the_last_two_years
		@cum_tb_within_the_last_two_years_diff = @revised_cum_tb_within_the_last_two_years - @cum_tb_within_the_last_two_years_flat | @cum_tb_within_the_last_two_years_flat - @revised_cum_tb_within_the_last_two_years
		
		@current_episode_of_tb_diff = @revised_current_episode_of_tb - @flat_current_tb | @flat_current_tb - @revised_current_episode_of_tb
		@cum_current_episode_of_tb_diff = @revised_cum_current_episode_of_tb - @flat_cum_current_tb | @flat_cum_current_tb - @revised_cum_current_episode_of_tb
		
		@kaposis_sarcoma_diff = @revised_kaposis_sarcoma - @flat_kaposis_sarcoma | @flat_kaposis_sarcoma - @revised_kaposis_sarcoma
		@cum_kaposis_sarcoma_diff = @revised_cum_kaposis_sarcoma - @flat_cum_kaposis_sarcoma | @flat_cum_kaposis_sarcoma - @revised_cum_kaposis_sarcoma

		#ouctomes
		@total_alive_and_on_art_diff = @revised_total_alive_and_on_art - @flat_total_alive_and_on_art | @flat_total_alive_and_on_art - @revised_total_alive_and_on_art
		@died_within_the_1st_month_of_art_initiation_diff = @revised_died_within_the_1st_month_of_art_initiation - @flat_died_within_the_1st_month_of_art_initiation | @flat_died_within_the_1st_month_of_art_initiation - @revised_died_within_the_1st_month_of_art_initiation
		@died_within_the_2nd_month_of_art_initiation_diff = @revised_died_within_the_2nd_month_of_art_initiation - @flat_died_within_the_2nd_month_of_art_initiation | @flat_died_within_the_2nd_month_of_art_initiation - @revised_died_within_the_2nd_month_of_art_initiation
		@died_within_the_3rd_month_of_art_initiation_diff = @revised_died_within_the_3rd_month_of_art_initiation - @flat_died_within_the_3rd_month_of_art_initiation | @flat_died_within_the_3rd_month_of_art_initiation - @revised_died_within_the_3rd_month_of_art_initiation
		@died_after_the_3rd_month_of_art_initiation_diff = @revised_died_after_the_3rd_month_of_art_initiation - @flat_died_after_the_3rd_month_of_art_initiation | @flat_died_after_the_3rd_month_of_art_initiation - @revised_died_after_the_3rd_month_of_art_initiation
		@died_total_diff = @revised_died_total - @flat_died_total | @flat_died_total - @revised_died_total
		@defaulted_diff = @revised_defaulted - @flat_defaulted | @flat_defaulted - @revised_defaulted
		@stopped_art_diff = @revised_stopped_art - @flat_stopped_art | @flat_stopped_art - @revised_stopped_art
		@transfered_out_diff = @revised_transfered_out - @flat_transfered_out | @flat_transfered_out - @revised_transfered_out
		@unknown_outcome_diff = @revised_unknown_outcome - @flat_unknown_outcome | @flat_unknown_outcome - @revised_unknown_outcome

		#regimens
		@zero_a_diff = @revised_zero_a - @flat_zero_a | @flat_zero_a - @revised_zero_a
		@zero_p_diff = @revised_zero_p - @flat_zero_p | @flat_zero_p - @revised_zero_p
		@two_a_diff = @revised_two_a - @flat_two_a  | @flat_two_a - @revised_two_a
		@two_p_diff = @revised_two_p - @flat_two_p  | @flat_two_p - @revised_two_p
		@four_a_diff = @revised_four_a - @flat_four_a  | @flat_four_a - @revised_four_a
		@four_p_diff = @revised_four_p - @flat_four_p  | @flat_four_p - @revised_four_p
		@five_a_diff = @revised_five_a - @flat_five_a  | @flat_five_a - @revised_five_a
		@six_a_diff = @revised_six_a - @flat_six_a | @flat_six_a - @revised_six_a
		@seven_a_diff = @revised_seven_a - @flat_seven_a  | @flat_seven_a - @revised_seven_a
		@eight_a_diff = @revised_eight_a - @flat_eight_a  | @flat_eight_a - @revised_eight_a
		@nine_a_diff = @revised_nine_a - @flat_nine_a  | @flat_nine_a - @revised_nine_a
		@nine_p_diff = @revised_nine_p - @flat_nine_p  | @flat_nine_p - @revised_nine_p
		@ten_a_diff = @revised_ten_a - @flat_ten_a  | @flat_ten_a - @revised_ten_a
		@elleven_a_diff = @revised_elleven_a - @flat_elleven_a  | @flat_elleven_a - @revised_elleven_a
		@elleven_p_diff = @revised_elleven_p - @flat_elleven_p  | @flat_elleven_p - @revised_elleven_p
		@twelve_a_diff = @revised_twelve_a - @flat_twelve_a  | @flat_twelve_a - @revised_twelve_a
		@unknown_regimen_diff = @revised_unknown_regimen - @flat_unknown_regimen | @flat_unknown_regimen - @revised_unknown_regimen

		#side effects
		@unknown_side_effects_flat = @flat_total_alive_and_on_art - (@flat_total_patients_with_side_effects + @flat_total_patients_without_side_effects)
		@total_patients_with_side_effects_diff  = @revised_total_patients_with_side_effects - @flat_total_patients_with_side_effects  | @flat_total_patients_with_side_effects - @revised_total_patients_with_side_effects
		@total_patients_without_side_effects_diff  = @revised_total_patients_without_side_effects - @flat_total_patients_without_side_effects  | @flat_total_patients_without_side_effects - @revised_total_patients_without_side_effects
		@unknown_side_effects_diff  = @revised_unknown_side_effects - @unknown_side_effects_flat  | @unknown_side_effects_flat - @revised_unknown_side_effects

		#tb status
		@tb_not_suspected_diff = @revised_tb_not_suspected - @flat_tb_not_suspected  | @flat_tb_not_suspected - @revised_tb_not_suspected
		@tb_suspected_diff = @revised_tb_suspected - @flat_tb_suspected  | @flat_tb_suspected - @revised_tb_suspected
		@tb_confirmed_currently_not_yet_on_tb_treatment_diff = @revised_tb_confirmed_currently_not_yet_on_tb_treatment - @flat_tb_confirmed_currently_not_yet_on_tb_treatment  | @flat_tb_confirmed_currently_not_yet_on_tb_treatment - @revised_tb_confirmed_currently_not_yet_on_tb_treatment
		@tb_confirmed_on_tb_treatment_diff = @revised_tb_confirmed_on_tb_treatment - @flat_tb_confirmed_on_tb_treatment  | @flat_tb_confirmed_on_tb_treatment - @revised_tb_confirmed_on_tb_treatment
		@unknown_tb_status_diff = @revised_unknown_tb_status - @flat_unknown_tb_status  | @flat_unknown_tb_status - @revised_unknown_tb_status

		#breastfeeding and pregnant
		@total_pregnancy_diff	= @revised_total_pregnancy - @flat_patient_pregnant  | @flat_patient_pregnant - @revised_total_pregnancy
		@total_breastfeeding_diff	= @revised_total_breastfeeding - @flat_patient_breastfeeding  | @flat_patient_breastfeeding - @revised_total_breastfeeding
		@other_patient_diff	= @revised_other_patient - @flat_other_patient  | @flat_other_patient - @revised_other_patient

		#adherence
		@unknown_adherence_flat = @flat_total_alive_and_on_art - (@flat_patients_with_0_6_doses_missed_at_their_last_visit + @flat_patients_with_7_plus_doses_missed_at_their_last_visit)
		@patients_with_0_6_doses_missed_at_their_last_visit_diff  = @revised_patients_with_0_6_doses_missed_at_their_last_visit - @flat_patients_with_0_6_doses_missed_at_their_last_visit  | @flat_patients_with_0_6_doses_missed_at_their_last_visit - @revised_patients_with_0_6_doses_missed_at_their_last_visit
		@patients_with_7_plus_doses_missed_at_their_last_visit_diff  = @revised_patients_with_7_plus_doses_missed_at_their_last_visit - @flat_patients_with_7_plus_doses_missed_at_their_last_visit  | @flat_patients_with_7_plus_doses_missed_at_their_last_visit - @revised_patients_with_7_plus_doses_missed_at_their_last_visit
		@patients_with_unknown_adhrence_diff = @revised_patients_with_unknown_adhrence - @unknown_adherence_flat  | @unknown_adherence_flat - @revised_patients_with_unknown_adhrence
		
		#cpt / ipt / pifp / bp screen
    @cpt_usage_diff = @flat_cpt_ids - @revised_cpt_ids | @revised_cpt_ids - @flat_cpt_ids
		@ipt_usage_diff =	@flat_ipt_ids - @revised_ipt_ids | @revised_ipt_ids - @flat_ipt_ids
		@pfip_usage_diff = @flat_pfip_ids - @revised_pfip_ids | @revised_pfip_ids - @flat_pfip_ids
		@bp_screen_usage_diff = @flat_bp_screen_ids - @revised_bp_screen_ids | @revised_bp_screen_ids - @flat_bp_screen_ids


		@cohort_differences = [["Newly Total Registered",@revised_total_registered.count, @flat_total_registered.count, @total_registered_diff],
			["Cum Total Registered", "#{@revised_cum_total_registered.count}", "#{@flat_cum_total_reg.count}", @total_cum_registered_diff],
			["Newly First Timers", "#{@revised_first_timers.count}", "#{@flat_first_timers.count}", @first_timers_diff],
			["Cum First Timers","#{@revised_cum_first_timers.count}", "#{@flat_cum_first_timers.count}", @cum_first_times_diff],
			["Newlt Transfer-ins","#{@revised_transfer_in.count}", "#{@flat_transfer_in.count}", @transfer_in_diff],
			["Cum Transfer-ins","#{@revised_cum_transfer_in.count}", "#{@flat_cum_transfer_in.count}",@cum_transfer_in_diff],
			["Newly Re-Initiated","#{@revised_re_initiated.count}", "#{@flat_re_initiated.count}", @re_initiated_diff],
			["Cum Re-Initiated","#{@revised_cum_re_initiated.count}", "#{@flat_cum_re_initiated.count}",@cum_re_initiated_diff],

			["Newly Males", @revised_males.count, @flat_all_males.count, @male_diff],
			["Cum Males", @revised_cum_males.count, @flat_cum_all_males.count, @cum_male_diff],
			["Newly Pregnant Females", @revised_pregnant_females.count, @flat_all_pregnant_females.count, @pregnant_females__diff],
			["Cum Pregnant Females", @revised_cum_pregnant_females.count, @flat_cum_all_preg_females.count, @cum_pregnant_females_diff],
			["Newly Non pregnant", @revised_non_pregnant_females.count, @flat_non_pregnant_females.count, @non_pregnant_diff],
			["Cum Non pregnant", @revised_cum_non_pregnant_females.count, @flat_cum_non_pregnant_females.count, @cum_non_pregnant],


			["Newly Children below 24 m at ART initiation", @revised_children_below_24_months_at_art_initiation.count, @flat_children_below_24_mnths.count, @children_below_24_months_at_art_initiation_diff],
			["Cum Children below 24 m at ART initiation", @revised_cum_children_below_24_months_at_art_initiation.count, @flat_cum_children_below_24_mnths.count, @cum_children_below_24_months_at_art_initiation_diff],
			["Newly Children 24 m - 14 yrs at ART initiation", @revised_children_24_months_14_years_at_art_initiation.count, @flat_children_between_24mnths_to_24mnths.count, @children_24_months_14_years_at_art_initiation_diff],
			["Cum Children 24 m - 14 yrs at ART initiation", @revised_cum_children_24_months_14_years_at_art_initiation.count, @flat_cum_children_between_24mnths_to_24mnths.count, @cum_children_24_months_14_years_at_art_initiation_diff],
			["Newly Adults 15 years or older at ART initiation", @revised_adults_at_art_initiation.count, @flat_adults.count, @adults_at_art_diff],
			["Cum Adults 15 years or older at ART initiation", @revised_cum_adults_at_art_initiation.count, @flat_cum_adults.count, @cum_adults_at_art_initiation_diff],
			["Newly Unknown age", @revised_unknown_age.count, @flat_unknown_age.count, @unknown_age_diff],
			["Cum Unknown age", @revised_cum_unknown_age.count, @flat_cum_unknown_age.count, @cum_unknown_age_diff],
	
			["Newly Pres Sev HIV disease age lass 12 m", @revised_presumed_severe_hiv_disease_in_infants.count, @flat_presumed_severe_hiv_disease_in_infants.count, @presumed_severe_hiv_disease_in_infants_diff],
			["Cum Pres Sev HIV disease age less 12 m", @revised_cum_presumed_severe_hiv_disease_in_infants.count, @flat_cum_presumed_severe_hiv_disease_in_infants.count, @cum_presumed_severe_hiv_disease_in_infants_diff],
			["Newly Infants less 12 mths PCR", @revised_confirmed_hiv_infection_in_infants_pcr.count, @flat_confirmed_hiv_infection_in_infants_pcr.count, @confirmed_hiv_infection_in_infants_pcr_diff],
			["Cum Infants less 12 mths PCR", @revised_cum_confirmed_hiv_infection_in_infants_pcr.count, @flat_cum_confirmed_hiv_infection_in_infants_pcr.count, @cum_confirmed_hiv_infection_in_infants_pcr_diff],
			["Newly Children 12-59 mths", @revised_children_12_23_months.count, @flat_children_12_23_months.count, @children_12_23_months_diff],
			["Cum Children 12-59 mths", @revised_cum_children_12_23_months.count, @flat_cum_children_12_23_months.count, @cum_children_12_23_months_diff],
			["Newly Pregnant women", @revised_pregnant_women.count, @flat_pregnant_women.count, @pregnant_women_diff],
			["Cum Pregnant women", @revised_cum_pregnant_women.count, @flat_cum_pregnant_women.count, @cum_pregnant_women_diff],
			["Newly Breastfeeding mothers", @revised_breastfeeding_mothers.count, @flat_breastfeeding_mothers.count, @breastfeeding_mothers_diff],
			["Cum Breastfeeding mothers", @revised_cum_breastfeeding_mothers.count, @flat_cum_breastfeeding_mothers.count, @cum_breastfeeding_mothers_diff],
			["Newly CD4 below threshold", @revised_who_stage_two.count, @flat_who_stage_two.count, @who_stage_two_diff],
			["Cum CD4 below threshold", @revised_cum_who_stage_two.count, @flat_cum_who_stage_two.count, @cum_who_stage_two_diff],
			["Newly Asymptomatic", @revised_asymptomatic.count, @flat_asymptomatic.count, @asymptomatic_diff],
			["Cum Asymptomatic", @revised_cum_asymptomatic.count, @flat_cum_asymptomatic.count, @cum_asymptomatic_diff],
			["Newly WHO stage 3", @revised_who_stage_three.count, @flat_who_stage_three.count, @who_stage_three_diff],
			["Cum WHO stage 3", @revised_cum_who_stage_three.count, @flat_cum_who_stage_three.count, @cum_who_stage_three_diff],
			["Newly WHO stage 4", @revised_who_stage_four.count, @flat_who_stage_four.count, @who_stage_four_diff],
			["Cum WHO stage 4", @revised_cum_who_stage_four.count,  @flat_cum_who_stage_four.count, @cum_who_stage_four_diff],
			["Newly Unknown reason", @revised_unknown_other_reason_outside_guidelines.count, @flat_unknown_other_reason_outside_guidelines.count, @unknown_other_reason_outside_guidelines_diff],
			["Cum Unknown reason", @revised_cum_unknown_other_reason_outside_guidelines.count, @flat_cum_unknown_other_reason_outside_guidelines.count, @cum_unknown_other_reason_outside_guidelines_diff],

			["Newly Never TB or TB over 2 years ago", @revised_no_tb.count, @unknown_tb_flat.count, @no_tb_diff],
			["Cum Never TB or TB over 2 years ago", @revised_cum_no_tb.count, @cum_unknown_tb_flat.count, @cum_no_tb_diff],
			["Newly TB within the last 2 years", @revised_tb_within_the_last_two_years.count, @tb_within_the_last_two_years_flat.count, @tb_within_the_last_two_years_diff],
			["Cum TB within the last 2 years", @revised_cum_tb_within_the_last_two_years.count, @cum_tb_within_the_last_two_years_flat.count, @cum_tb_within_the_last_two_years_diff],
			["Current episode of TB", @revised_current_episode_of_tb.count, @flat_current_tb.count, @current_episode_of_tb_diff],
			["Cum Current episode of TB", @revised_cum_current_episode_of_tb.count, @flat_cum_current_tb.count, @cum_current_episode_of_tb_diff],
			["Newly Kaposis Sarcoma", @revised_kaposis_sarcoma.count, @flat_kaposis_sarcoma.count, @kaposis_sarcoma_diff],
			["Cum Kaposis Sarcoma", @revised_cum_kaposis_sarcoma.count, @flat_cum_kaposis_sarcoma.count, @cum_kaposis_sarcoma_diff],

			["Total alive and on ART", @revised_total_alive_and_on_art.count, @flat_total_alive_and_on_art.count, @total_alive_and_on_art_diff],
			["Died within the 1st month after ART initiation", @revised_died_within_the_1st_month_of_art_initiation.count, @flat_died_within_the_1st_month_of_art_initiation.count, @died_within_the_1st_month_of_art_initiation_diff],
			["Died within the 2nd month after ART initiation", @revised_died_within_the_2nd_month_of_art_initiation.count, @flat_died_within_the_2nd_month_of_art_initiation.count, @died_within_the_2nd_month_of_art_initiation_diff],
			["Died within the 3rd month after ART initiation", @revised_died_within_the_3rd_month_of_art_initiation.count, @flat_died_within_the_3rd_month_of_art_initiation.count, @died_within_the_3rd_month_of_art_initiation_diff],
			["Died after the end of the 3rd month after ART initiation", @revised_died_after_the_3rd_month_of_art_initiation.count, @flat_died_after_the_3rd_month_of_art_initiation.count, @died_after_the_3rd_month_of_art_initiation_diff],
			["Died total", @revised_died_total.count, @flat_died_total.count, @died_total_diff],
			["Defaulted", @revised_defaulted.count, @flat_defaulted.count, @defaulted_diff],
			["Stopped taking ARVs", @revised_stopped_art.count, @flat_stopped_art.count, @stopped_art_diff],
			["Transferred Out", @revised_transfered_out.count, @flat_transfered_out.count, @transfered_out_diff],
			["Unknown Outcome", @revised_unknown_outcome.count, @flat_unknown_outcome.count, @unknown_outcome_diff],

			["0P" ,@revised_zero_p.count, @flat_zero_p.count, @zero_p_diff],
			["2P" ,@revised_two_p.count, @flat_two_p.count, @two_p_diff],
			["4P" ,@revised_four_p.count, @flat_four_p.count, @four_p_diff],
			["9P" ,@revised_nine_p.count, @flat_nine_p.count, @nine_p_diff],
			["11P" ,@revised_elleven_p.count, @flat_elleven_p.count, @elleven_p_diff],

			["0A" ,@revised_zero_a.count, @flat_zero_a.count, @zero_a_diff ],
			["2A" ,@revised_two_a.count, @flat_two_a.count, @two_a_diff],
			["4A" ,@revised_four_a.count, @flat_four_a.count, @four_a_diff],
			["5A" ,@revised_five_a.count, @flat_five_a.count, @five_a_diff],
			["6A" ,@revised_six_a.count, @flat_six_a.count, @six_a_diff],
			["7A" ,@revised_seven_a.count, @flat_seven_a.count, @seven_a_diff ],
			["8A" ,@revised_eight_a.count, @flat_eight_a.count, @eight_a_diff  ],
			["9A" ,@revised_nine_a.count, @flat_nine_a.count, @nine_a_diff ],
			["10A" ,@revised_ten_a.count, @flat_ten_a.count, @ten_a_diff ],
			["11A" ,@revised_elleven_a.count, @flat_elleven_a.count, @elleven_a_diff ],
			["12A" ,@revised_twelve_a.count, @flat_twelve_a.count, @twelve_a_diff ],
			["Unknown Regimen" ,@revised_unknown_regimen.count, @flat_unknown_regimen.count, @unknown_regimen_diff ],

			["TB not suspected", @revised_tb_not_suspected.count, @flat_tb_not_suspected.count, @tb_not_suspected_diff],
			["TB suspected", @revised_tb_suspected.count, @flat_tb_suspected.count, @tb_suspected_diff],
			["TB conf not on Rx", @revised_tb_confirmed_currently_not_yet_on_tb_treatment.count, @flat_tb_confirmed_currently_not_yet_on_tb_treatment.count, @tb_confirmed_currently_not_yet_on_tb_treatment_diff],
			["TB conf on TB Rx", @revised_tb_confirmed_on_tb_treatment.count, @flat_tb_confirmed_on_tb_treatment.count, @tb_confirmed_on_tb_treatment_diff],
			["Unknown TB status", @revised_unknown_tb_status.count, @flat_unknown_tb_status.count, @unknown_tb_status_diff],

			["Any side effects", @revised_total_patients_with_side_effects.count, @flat_total_patients_with_side_effects.count, @total_patients_with_side_effects_diff],
			["No Side effects", @revised_total_patients_without_side_effects.count, @flat_total_patients_without_side_effects.count, @total_patients_without_side_effects_diff],
			["Unknown Side effects", @revised_unknown_side_effects.count, @unknown_side_effects_flat.count, @unknown_side_effects_diff],

			["0 to 3 doses missed", @revised_patients_with_0_6_doses_missed_at_their_last_visit.count, @flat_patients_with_0_6_doses_missed_at_their_last_visit.count,  @patients_with_0_6_doses_missed_at_their_last_visit_diff],
			["4 plus doses missed", @revised_patients_with_7_plus_doses_missed_at_their_last_visit.count, @flat_patients_with_7_plus_doses_missed_at_their_last_visit.count,  @patients_with_7_plus_doses_missed_at_their_last_visit_diff],
			["Unknown adherence", @revised_patients_with_unknown_adhrence.count, @unknown_adherence_flat.count,  @patients_with_unknown_adhrence_diff],

			["Total Pregnant" ,@revised_total_pregnancy.count, @flat_patient_pregnant.count, @total_pregnancy_diff],
			["Total Breastfeeding" ,@revised_total_breastfeeding.count, @flat_patient_breastfeeding.count, @total_breastfeeding_diff],
			["Other Patient" ,@revised_other_patient.count, @flat_other_patient.count, @other_patient_diff],

			["Patients returnted on ART currently on CPT", @revised_cpt_ids.count, @flat_cpt_ids.count, @cpt_usage_diff],
			["Patients returnted on ART currently on IPT", @revised_ipt_ids.count, @flat_ipt_ids.count, @ipt_usage_diff ],
			["Women who received Depo in the last Quarter", @revised_pfip_ids.count, @flat_pfip_ids.count, @pfip_usage_diff ],
			["ART patients with BP recorded", @revised_bp_screen_ids.count, @flat_bp_screen_ids.count, @bp_screen_usage_diff]
		]

		return @cohort_differences
	end
end
