class CohortService

 #Newly registered in quarter
 attr_accessor :total_registered, :transfer_in, :initiated_on_art_first_time, :re_initiated_on_art,
               :pregnant_females_all_ages, :non_pregnant_females, :children_below_24_months_at_art_initiation,
               :children_24_months_14_years_at_art_initiation, :adults_at_art_initiation, :unknown_age,
               :presumed_severe_hiv_disease_in_infants, :confirmed_hiv_infection_in_infants_pcr,
               :tb_within_the_last_two_years, :current_episode_of_tb, :kaposis_sarcoma,
               :presumed_severe_hiv_disease_in_infants, :confirmed_hiv_infection_in_infants_pcr,:asymptomatic,
               :who_stage_two, :children_12_23_months, :breastfeeding_mothers, :pregnant_women,
               :who_stage_three, :who_stage_four, :unknown_other_reason_outside_guidelines, :all_males, :unknown_age


 #Cumulative ever registered
 attr_accessor :cum_total_registered, :cum_transfer_in, :cum_initiated_on_art_first_time, :cum_re_initiated_on_art,
               :cum_pregnant_females_all_ages, :cum_non_pregnant_females, :cum_children_below_24_months_at_art_initiation,
               :cum_children_24_months_14_years_at_art_initiation, :cum_adults_at_art_initiation, :cum_unknown_age,
               :cum_presumed_severe_hiv_disease_in_infants, :cum_confirmed_hiv_infection_in_infants_pcr,
               :cum_tb_within_the_last_two_years, :cum_current_episode_of_tb, :cum_kaposis_sarcoma, :no_tb, :cum_no_tb,
               :cum_presumed_severe_hiv_disease_in_infants, :cum_confirmed_hiv_infection_in_infants_pcr, :cum_asymptomatic,
               :cum_who_stage_two, :cum_children_12_23_months, :cum_breastfeeding_mothers, :cum_pregnant_women,
               :cum_who_stage_three, :cum_who_stage_four, :cum_unknown_other_reason_outside_guidelines, :cum_all_males, :cum_unknown_age

  #Primary Outcomes (Cumulative)
  attr_accessor :total_alive_and_on_art, :died_within_the_1st_month_of_art_initiation,
                :died_within_the_2nd_month_of_art_initiation, :died_within_the_3rd_month_of_art_initiation,
                :died_after_the_3rd_month_of_art_initiation, :died_total, :defaulted, :stopped_art,
                :transfered_out, :unknown_outcome

  #Secondary Outcomes (Cumulative)
  attr_accessor :zero_a, :zero_p, :one_a, :one_p, :two_a, :two_p, :three_a, :three_p, :four_a, :four_p, :five_a, :six_a,
                :seven_a, :eight_a, :nine_a, :nine_p, :ten_a, :elleven_a, :elleven_p, :twelve_a, :unknown_regimen

  #Adherence
  attr_accessor :patients_with_0_6_doses_missed_at_their_last_visit, :patients_with_7_plus_doses_missed_at_their_last_visit,
                :patients_with_unknown_adhrence

  #Current TB status,any form of TB
  attr_accessor :tb_not_suspected, :tb_suspected, :tb_confirmed_currently_not_yet_on_tb_treatment,
                :tb_confirmed_on_tb_treatment, :unknown_tb_status

  #Total patients with side effects
  attr_accessor :total_patients_with_side_effects, :total_patients_without_side_effects, :unknown_side_effects

  #survival analysis: Number of new patients registered on ART within a certain period of time
  attr_accessor :general_survival_analysis, :women_survival_analysis, :children_survival_analysis

  #Patient pregnancy and/or breastfeeding status as of end of quarter
  attr_accessor :total_pregnant_women, :total_breastfeeding_women, :total_other_patients

  #Percentage of CPT, IPT, Family planning, BP screened patients
  attr_accessor :total_patients_on_arvs_and_cpt, :total_patients_on_arvs_and_ipt, :total_patients_on_family_planning, :total_patients_with_screened_bp, :total_patients_on_arvs_and_cpt_ids, :total_patients_on_arvs_and_ipt_ids, :total_patients_on_family_planning_ids, :total_patients_with_screened_bp_ids

	def initialize(name)
		@name = name
	end
end
