class ReportingReportDesignResource < ActiveRecord::Base
	set_table_name :reporting_report_design_resource
	set_primary_key :id
	include Openmrs


	def self.save_cohort_attributes(cohort_year,cohort_quarter,cohort_attributes)
		report_design = ReportingReportDesign.find_by_name("Q#{cohort_quarter} #{cohort_year}")
		if report_design.blank?
      begin
        report_def = SerializedObject.find_by_name('Cohort report trail') 
      rescue
        report_def = nil
      end

      if report_def.blank?
        report_def = SerializedObject.new()
        report_def.name =                 'Cohort report trail'
        report_def.type =  	      	      'Report'
        report_def.subtype =              'Quartery'
        report_def.serialization_class =  'Quartery Report'
        report_def.serialized_data =      'Cohort indicators'
        report_def.save
      end

		  report_design = ReportingReportDesign.create(:name => "Q#{cohort_quarter} #{cohort_year}",
		  	:description => "MOH report, done every quarter",
		  	:renderer_type => 'PDF',
		  	:report_definition_id => report_def.id)
		end  

		@cohort_indicators = {
			"total_other_patients"=>"All others (not circled)", 
      "patients_with_7_plus_doses_missed_at_their_last_visit"=>"Adherence: 4+ Doses",
			"unknown_age"=>"Unknown age",
			"cum_pregnant_females_all_ages"=>"Cumulative female pregnant patients (all ages)",
			"died_within_the_2nd_month_of_art_initiation"=>"Died within the 2nd month of art initiation",
			"no_tb"=>"Never TB or TB over 2 years ago",
			"six_a"=>"Regimen: 6 A",
			"elleven_p"=>"Regimen: 11 P",
			"cum_children_24_months_14_years_at_art_initiation"=>"Cumulative Children 24 m - 14 yrs at ART initiation",
			"cum_no_tb"=>"Cumulative Never TB or TB over 2 years ago",
			"cum_current_episode_of_tb"=>"Cumulative Current episode of TB",
			"who_stage_two"=>" CD4 below threshold",
			"cum_non_pregnant_females"=>"Cumulative FNP:Non-pregnant Females (all ages)", 
			"asymptomatic"=>"Asy:Asymptomatic / mild",
			"cum_initiated_on_art_first_time"=>"Cumulative Patients initiated on ART first time",
			"pregnant_women"=>"Pregnant women",
			"defaulted"=>"Defaulted (more than 2 months overdue after expected to have run out of ARVs", 
  "four_p"=>" Regimen: 4 P",
  "tb_within_the_last_two_years"=>"TB within the last 2 years", 
  "total_patients_without_side_effects"=>"Side Effects:as of the last visit before end of quarter", 
  "cum_pregnant_women"=>"Cumulative Pregnant Women", 
  "cum_re_initiated_on_art"=>"Cumulative Patients re-initiated on ART", 
  "cum_all_males"=>"Cumulative Males (all ages)",
  "cum_children_12_23_months"=>"Cumulative Children 12-59 months", 
  "current_episode_of_tb"=>"Current episode of TB", 
  "re_initiated_on_art"=>"Patients re-initiated on ART", 
  "cum_unknown_other_reason_outside_guidelines"=>"Cumulative Unknown / reason outside guidelines", 
  "cum_kaposis_sarcoma"=>"Cumulative Kaposi's Sarcoma", 
  "three_p"=>"Regimen: 3 A", 
  "cum_children_below_24_months_at_art_initiation"=>"Cumulative Children below 24 m at ART initiation", 
  "total_patients_with_side_effects"=>"Any side effects", 
  "adults_at_art_initiation"=>"Adults 15 years or older at ART initiation", 
  "total_patients_on_family_planning"=>"PIFP:Apprx. % of women who received Depo at ART in the last quarter", 
  "zero_a"=>"Regimen: 0 A", 
  "total_pregnant_women"=>"Pregnant/BreastFeeding as of the last visit before end of quarter", 
  "nine_a"=>"Regimen: 9 A", 
  "two_p"=>"Regimen: 2 P", 
  "cum_adults_at_art_initiation"=>"Cumulative Adults 15 years or older at ART initiation", 
  "cum_breastfeeding_mothers"=>"Cumulative Breastfeeding mothers ", 
  "died_total"=>"Died Total", 
  "tb_confirmed_currently_not_yet_on_tb_treatment"=>"TB conf.", 
  "transfered_out"=>"Transferred Out", 
  "cum_who_stage_four"=>"Cumulative  WHO stage 4", 
  "cum_presumed_severe_hiv_disease_in_infants"=>"Cumulative Pres. Sev. HIV disease age < 12 m", 
  "twelve_a"=>"Regimen: 12 A", 
  "children_12_23_months"=>"Children 12-59 mths", 
  "tb_not_suspected"=>"Current TB status any form of TB", 
  "one_p"=>"Regimen: 1 P", 
  "breastfeeding_mothers"=>"Breastfeeding mothers", 
  "tb_confirmed_on_tb_treatment"=>"TB conf.", 
  "patients_with_0_6_doses_missed_at_their_last_visit"=>"Adnerence: as of the last visit before end of quarter", 
  "cum_transfer_in"=>"Cumulative Patients transferred in on ART ", 
  "total_patients_on_arvs_and_ipt"=>"Apprx. % of patients retained in <b>ART</b> who are currently on IPT", 
  "total_breastfeeding_women"=>"Total Breastfeeding Women", 
  "total_alive_and_on_art"=>" Total alive and on ART", 
  "kaposis_sarcoma"=>"Kaposi's Sarcoma", 
  "five_a"=>"Regimen: 5 A", 
  "cum_tb_within_the_last_two_years"=>"Cumulative TB within the last 2 years", 
  "unknown_regimen"=>"Specify above regimens counted as 'Other' Other (paed. / adult)", 
  "total_patients_with_screened_bp"=>"BP screen:Apprx. % of adult ART patients with BP recorded at least once this year", 
  "elleven_a"=>"Regimen: 11 A", 
  "died_within_the_3rd_month_of_art_initiation"=>"M3: Died within the 3rd month after ART initiation", 
  "cum_unknown_age"=>"Cumulative Unknown Age", 
  "cum_total_registered"=>"Cumulative Total Registered", 
  "eight_a"=>"Regimen: 8 A", 
  "transfer_in"=>"Patients transferred in on ART", 
  "confirmed_hiv_infection_in_infants_pcr"=>"PCR:Infants < 12 mths PCR+", 
  "four_a"=>"Regimen: 4 A", 
  "who_stage_four"=>"WHO stage 4", 
  "non_pregnant_females"=>"FNP: Non-pregnant Females (all ages)", 
  "cum_who_stage_two"=>"Cumulative CD4 below threshold", 
  "cum_confirmed_hiv_infection_in_infants_pcr"=>"Cumulative PCR: Infants < 12 mths PCR+", 
  "unknown_tb_status"=>"Unknown (not circled)", 
  "three_a"=>"Regimen 3 A", 
  "zero_p"=>"Regimen: 0 P", 
  "total_patients_on_arvs_and_cpt"=>"Apprx. % of patients retained in <b>ART</b> who are currently on CPT", 
  "tb_suspected"=>"TB Suspected", 
  "unknown_side_effects"=>"Unkown (not circled)", 
  "seven_a"=>"Regimen: 7 A", 
  "total_registered"=>"Total Registered", 
  "nine_p"=>"Regimen: 9 A", 
  "died_within_the_1st_month_of_art_initiation"=>"Died within the 1st month after ART initiation", 
  "pregnant_females_all_ages"=>"FP: Pregnant Females (all ages)", 
  "patients_with_unknown_adhrence"=>"Unknown (not circled)", 
  "two_a"=>"Regimen: 2 A", 
  "died_after_the_3rd_month_of_art_initiation"=>"Died within the 3rd month after ART initiation", 
  "who_stage_three"=>"WHO stage 3", 
  "cum_asymptomatic"=>"Cumulative Asymptomatic / mild", 
  "unknown_other_reason_outside_guidelines"=>"Unknown / reason outside guidelines", 
  "ten_a"=>"Regimen: 10 A", 
  "initiated_on_art_first_time"=>"Patients initiated on ART first time", 
  "cum_who_stage_three"=>"Cumulative WHO stage 3", 
  "presumed_severe_hiv_disease_in_infants"=>"Pres. Sev. HIV disease age < 12 m", 
  "children_24_months_14_years_at_art_initiation"=>"Children 24 m - 14 yrs at ART initiation", 
  "one_a"=>"Regimen: 1 A", 
  "all_males"=>"Males (all ages)", 
  "stopped_art"=>"Stopped taking ARVs (clinician or patient own decision, last known alive)", 
  "children_below_24_months_at_art_initiation"=>"Children below 24 m at ART initiation"}


		(cohort_attributes || {}).each do |name,count|
			#raise "#{name} #{count}"
			resource = ReportingReportDesignResource.find(:first, 
				:conditions =>["name = ? AND report_design_id = ?",
				@cohort_indicators[name], report_design.id])

			resource = ReportingReportDesignResource.new() if resource.blank?
			resource.name = @cohort_indicators[name]
			resource.description = "Q#{cohort_quarter} #{cohort_year}"
			resource.contents= count
			resource.report_design_id =report_design.id
			resource.save
		end
	end

end
