Connection = ActiveRecord::Base.connection

def start
  #get all the obs
  hiv_consultation_obs = []
  hiv_consultation_obs = ActiveRecord::Base.connection.select_all <<EOF
    SELECT o.* FROM encounter e
     INNER JOIN obs o ON o.encounter_id = e.encounter_id
    AND e.encounter_type = 53
    AND o.concept_id = 7755;
EOF
  #loop through and update the flat_table2 and flat_cohort_table
  (hiv_consultation_obs || []).each do |obs|
    updating_side_effects(obs['person_id'].to_i, obs['encounter_id'].to_i, obs['value_coded'].to_i, obs['obs_datetime'], obs['voided'].to_i)
    #update malawi_art_side_effects
    #update tb routine screening fields
  end


end

def updating_side_effects(obs_person_id, obs_encounter_id, side_effect_id, obs_visit_date, obs_voided)
  puts "Working on patient_id: #{obs_person_id}"
  #pull the answer
  side_effect_answer =  Connection.select_one("
          SELECT c.name as name
          FROM obs o
            INNER JOIN concept_name c on c.concept_name_id = o.value_coded_name_id
          WHERE encounter_id = #{obs_encounter_id} AND o.concept_id = #{side_effect_id}
          AND obs_datetime = '#{obs_visit_date}' AND person_id = #{obs_person_id} AND concept_name_type = 'FULLY_SPECIFIED'
          AND c.voided  = 0")

  patient_check = []
  patient_check = Connection.select_one("SELECT ID FROM flat_table2
                        WHERE patient_id = #{obs_person_id}
                        and visit_date = DATE('#{obs_visit_date}')")

  unless side_effect_answer.blank?
    case side_effect_id
      when 821 #peripheral_neuropathy
        if patient_check.blank? #check patient_not_in_flat_table2
  #insert
  Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, side_effects_peripheral_neuropathy, side_effects_peripheral_neuropathy_enc_id)
VALUES('#{obs_person_id}', DATE('#{obs_visit_date}'), '#{side_effect_answer['name']}', '#{obs_encounter_id}') ;
EOF
        else #check patient_not_in_flat_table2
          if obs_voided == 0 #if voided
    Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_peripheral_neuropathy = '#{side_effect_answer['name']}', side_effects_peripheral_neuropathy_enc_id = '#{obs_encounter_id}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          else #else voided
    Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_peripheral_neuropathy = NULL, side_effects_peripheral_neuropathy_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end voided
        end #check patient_not_in_flat_table2
#----------------------------------------------------------------------------------------------------------end peripheral_neuropathy
      when 151 #abdominal_pain
        if patient_check.blank? #check patient_not_in_flat_table2
          #insert
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, side_effects_abdominal_pain, side_effects_abdominal_pain_enc_id)
VALUES('#{obs_person_id}', DATE('#{obs_visit_date}'), '#{side_effect_answer['name']}', '#{obs_encounter_id}') ;
EOF
        else #check patient_not_in_flat_table2
          if obs_voided == 0 #if voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_abdominal_pain = '#{side_effect_answer['name']}', side_effects_abdominal_pain_enc_id = '#{obs_encounter_id}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          else #else voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_abdominal_pain = NULL, side_effects_abdominal_pain_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end voided
        end #check patient_not_in_flat_table2
#----------------------------------------------------------------------------------------------------------end abdominal_pain
      when 5106 #abdominal_pain
        if patient_check.blank? #check patient_not_in_flat_table2
          #insert
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, side_effects_abdominal_pain, side_effects_abdominal_pain_enc_id)
VALUES('#{obs_person_id}', DATE('#{obs_visit_date}'), '#{side_effect_answer['name']}', '#{obs_encounter_id}') ;
EOF
        else #check patient_not_in_flat_table2
          if obs_voided == 0 #if voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_abdominal_pain = '#{side_effect_answer['name']}', side_effects_abdominal_pain_enc_id = '#{obs_encounter_id}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          else #else voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_abdominal_pain = NULL, side_effects_abdominal_pain_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end voided
        end #check patient_not_in_flat_table2
#----------------------------------------------------------------------------------------------------------end abdominal_pain
      when 5987 #abdominal_pain
        if patient_check.blank? #check patient_not_in_flat_table2
          #insert
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, side_effects_abdominal_pain, side_effects_abdominal_pain_enc_id)
VALUES('#{obs_person_id}', DATE('#{obs_visit_date}'), '#{side_effect_answer['name']}', '#{obs_encounter_id}') ;
EOF
        else #check patient_not_in_flat_table2
          if obs_voided == 0 #if voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_abdominal_pain = '#{side_effect_answer['name']}', side_effects_abdominal_pain_enc_id = '#{obs_encounter_id}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          else #else voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_abdominal_pain = NULL, side_effects_abdominal_pain_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end voided
        end #check patient_not_in_flat_table2
#----------------------------------------------------------------------------------------------------------end abdominal_pain
      when 3 #anemia
        if patient_check.blank? #check patient_not_in_flat_table2
          #insert
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, side_effects_anemia, side_effects_anemia_enc_id)
VALUES('#{obs_person_id}', DATE('#{obs_visit_date}'), '#{side_effect_answer['name']}', '#{obs_encounter_id}') ;
EOF
        else #check patient_not_in_flat_table2
          if obs_voided == 0 #if voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_anemia = '#{side_effect_answer['name']}', side_effects_anemia_enc_id = '#{obs_encounter_id}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          else #else voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_anemia = NULL, side_effects_anemia_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end voided
        end #check patient_not_in_flat_table2
#----------------------------------------------------------------------------------------------------------end anemia
      when 868 #anorexia
        if patient_check.blank? #check patient_not_in_flat_table2
          #insert
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, side_effects_anorexia, side_effects_anorexia_enc_id)
VALUES('#{obs_person_id}', DATE('#{obs_visit_date}'), '#{side_effect_answer['name']}', '#{obs_encounter_id}') ;
EOF
        else #check patient_not_in_flat_table2
          if obs_voided == 0 #if voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_anorexia = '#{side_effect_answer['name']}', side_effects_anorexia_enc_id = '#{obs_encounter_id}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          else #else voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_anorexia = NULL, side_effects_anorexia_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end voided
        end #check patient_not_in_flat_table2
#------------------------------------------------------------------------------------------------------------------end anorexia
      when 5953 #blurry_vision
        if patient_check.blank? #check patient_not_in_flat_table2
          #insert
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, side_effects_blurry_vision, side_effects_blurry_vision_enc_id)
VALUES('#{obs_person_id}', DATE('#{obs_visit_date}'), '#{side_effect_answer['name']}', '#{obs_encounter_id}') ;
EOF
        else #check patient_not_in_flat_table2
          if obs_voided == 0 #if voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_blurry_vision = '#{side_effect_answer['name']}', side_effects_blurry_vision_enc_id = '#{obs_encounter_id}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          else #else voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_blurry_vision = NULL, side_effects_blurry_vision_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end voided
        end #check patient_not_in_flat_table2
#-----------------------------------------------------------------------------------------------------------------end blurry_vision
      when 107 #cough
        if patient_check.blank? #check patient_not_in_flat_table2
          #insert
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, side_effects_cough, side_effects_cough_enc_id)
VALUES('#{obs_person_id}', DATE('#{obs_visit_date}'), '#{side_effect_answer['name']}', '#{obs_encounter_id}') ;
EOF
        else #check patient_not_in_flat_table2
          if obs_voided == 0 #if voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_cough = '#{side_effect_answer['name']}', side_effects_cough_enc_id = '#{obs_encounter_id}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          else #else voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_cough = NULL, side_effects_cough_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end voided
        end #check patient_not_in_flat_table2
#---------------------------------------------------------------------------------------------------------------end cough
      when 5956 #cough
        if patient_check.blank? #check patient_not_in_flat_table2
          #insert
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, side_effects_cough, side_effects_cough_enc_id)
VALUES('#{obs_person_id}', DATE('#{obs_visit_date}'), '#{side_effect_answer['name']}', '#{obs_encounter_id}') ;
EOF
        else #check patient_not_in_flat_table2
          if obs_voided == 0 #if voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_cough = '#{side_effect_answer['name']}', side_effects_cough_enc_id = '#{obs_encounter_id}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          else #else voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_cough = NULL, side_effects_cough_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end voided
        end #check patient_not_in_flat_table2
#---------------------------------------------------------------------------------------------------------------end cough
      when 16 #diarrhea
        if patient_check.blank? #check patient_not_in_flat_table2
          #insert
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, side_effects_diarrhea, side_effects_diarrhea_enc_id)
VALUES('#{obs_person_id}', DATE('#{obs_visit_date}'), '#{side_effect_answer['name']}', '#{obs_encounter_id}') ;
EOF
        else #check patient_not_in_flat_table2
          if obs_voided == 0 #if voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_diarrhea = '#{side_effect_answer['name']}', side_effects_diarrhea_enc_id = '#{obs_encounter_id}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          else #else voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_diarrhea = NULL, side_effects_diarrhea_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end voided
        end #check patient_not_in_flat_table2
#------------------------------------------------------------------------------------------------------------------end diarrhea
      when 5983 #diarrhea
        if patient_check.blank? #check patient_not_in_flat_table2
          #insert
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, side_effects_diarrhea, side_effects_diarrhea_enc_id)
VALUES('#{obs_person_id}', DATE('#{obs_visit_date}'), '#{side_effect_answer['name']}', '#{obs_encounter_id}') ;
EOF
        else #check patient_not_in_flat_table2
          if obs_voided == 0 #if voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_diarrhea = '#{side_effect_answer['name']}', side_effects_diarrhea_enc_id = '#{obs_encounter_id}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          else #else voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_diarrhea = NULL, side_effects_diarrhea_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end voided
        end #check patient_not_in_flat_table2
#------------------------------------------------------------------------------------------------------------------end diarrhea
      when 877 #diziness
        if patient_check.blank? #check patient_not_in_flat_table2
          #insert
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, side_effects_diziness, side_effects_diziness_enc_id)
VALUES('#{obs_person_id}', DATE('#{obs_visit_date}'), '#{side_effect_answer['name']}', '#{obs_encounter_id}') ;
EOF
        else #check patient_not_in_flat_table2
          if obs_voided == 0 #if voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_diziness = '#{side_effect_answer['name']}', side_effects_diziness_enc_id = '#{obs_encounter_id}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          else #else voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_diziness = NULL, side_effects_diziness_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end voided
        end #check patient_not_in_flat_table2
#----------------------------------------------------------------------------------------------------------------end diziness
      when 5945 #fever
        if patient_check.blank? #check patient_not_in_flat_table2
          #insert
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, side_effects_fever, side_effects_fever_enc_id)
VALUES('#{obs_person_id}', DATE('#{obs_visit_date}'), '#{side_effect_answer['name']}', '#{obs_encounter_id}') ;
EOF
        else #check patient_not_in_flat_table2
          if obs_voided == 0 #if voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_fever = '#{side_effect_answer['name']}', side_effects_fever_enc_id = '#{obs_encounter_id}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          else #else voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_fever = NULL, side_effects_fever_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end voided
        end #check patient_not_in_flat_table2
#-----------------------------------------------------------------------------------------------------------------end fever
      when 9440 #gynaecomastia
        if patient_check.blank? #check patient_not_in_flat_table2
          #insert
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, side_effects_gynaecomastia, side_effects_gynaecomastia_enc_id)
VALUES('#{obs_person_id}', DATE('#{obs_visit_date}'), '#{side_effect_answer['name']}', '#{obs_encounter_id}') ;
EOF
        else #check patient_not_in_flat_table2
          if obs_voided == 0 #if voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_gynaecomastia = '#{side_effect_answer['name']}', side_effects_gynaecomastia_enc_id = '#{obs_encounter_id}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          else #else voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_gynaecomastia = NULL, side_effects_gynaecomastia_enc_id = NULL WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end voided
        end #check patient_not_in_flat_table2
#-----------------------------------------------------------------------------------------------------------end gynaecomastia
      when 29 #hepatitis
        if patient_check.blank? #check patient_not_in_flat_table2
          #insert
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, side_effects_hepatitis, side_effects_hepatitis_enc_id)
VALUES('#{obs_person_id}', DATE('#{obs_visit_date}'), '#{side_effect_answer['name']}', '#{obs_encounter_id}') ;
EOF
        else #check patient_not_in_flat_table2
          if obs_voided == 0 #if voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_hepatitis = '#{side_effect_answer['name']}', side_effects_hepatitis_enc_id = '#{obs_encounter_id}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          else #else voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_hepatitis = NULL, side_effects_hepatitis_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end voided
        end #check patient_not_in_flat_table2
#-----------------------------------------------------------------------------------------------------------end jaundice
      when 215 #jaundice
        if patient_check.blank? #check patient_not_in_flat_table2
          #insert
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, side_effects_jaundice, side_effects_jaundice_enc_id)
VALUES('#{obs_person_id}', DATE('#{obs_visit_date}'), '#{side_effect_answer['name']}', '#{obs_encounter_id}') ;
EOF
        else #check patient_not_in_flat_table2
          if obs_voided == 0 #if voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_jaundice = '#{side_effect_answer['name']}', side_effects_jaundice_enc_id = '#{obs_encounter_id}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          else #else voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_jaundice = NULL, side_effects_jaundice_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end voided
        end #check patient_not_in_flat_table2
#-----------------------------------------------------------------------------------------------------------end jaundice
      when 9242 #kidney_failure
        if patient_check.blank? #check patient_not_in_flat_table2
          #insert
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, side_effects_kidney_failure, side_effects_kidney_failure_enc_id)
VALUES('#{obs_person_id}', DATE('#{obs_visit_date}'), '#{side_effect_answer['name']}', '#{obs_encounter_id}') ;
EOF
        else #check patient_not_in_flat_table2
          if obs_voided == 0 #if voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_kidney_failure = '#{side_effect_answer['name']}', side_effects_kidney_failure_enc_id = '#{obs_encounter_id}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          else #else voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_kidney_failure = NULL, side_effects_kidney_failure_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end voided
        end #check patient_not_in_flat_table2
#-----------------------------------------------------------------------------------------------------------end kidney_failure
      when 1458 #lactic_acidosis
        if patient_check.blank? #check patient_not_in_flat_table2
          #insert
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, side_effects_lactic_acidosis, side_effects_lactic_acidosis_enc_id)
VALUES('#{obs_person_id}', DATE('#{obs_visit_date}'), '#{side_effect_answer['name']}', '#{obs_encounter_id}') ;
EOF
        else #check patient_not_in_flat_table2
          if obs_voided == 0 #if voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_lactic_acidosis = '#{side_effect_answer['name']}', side_effects_lactic_acidosis_enc_id = '#{obs_encounter_id}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          else #else voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_lactic_acidosis = NULL, side_effects_lactic_acidosis_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end voided
        end #check patient_not_in_flat_table2
#-----------------------------------------------------------------------------------------------------------end lactic_acidosis
      when 7952 #leg_pain_numbness
        if patient_check.blank? #check patient_not_in_flat_table2
          #insert
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, side_effects_leg_pain_numbness, side_effects_leg_pain_numbness_enc_id)
VALUES('#{obs_person_id}', DATE('#{obs_visit_date}'), '#{side_effect_answer['name']}', '#{obs_encounter_id}') ;
EOF
        else #check patient_not_in_flat_table2
          if obs_voided == 0 #if voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_leg_pain_numbness = '#{side_effect_answer['name']}', side_effects_leg_pain_numbness_enc_id = '#{obs_encounter_id}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          else #else voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_leg_pain_numbness = NULL, side_effects_leg_pain_numbness_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end voided
        end #check patient_not_in_flat_table2
#-----------------------------------------------------------------------------------------------------------end leg_pain_numbness
      when 2148 #lipodystrophy
        if patient_check.blank? #check patient_not_in_flat_table2
          #insert
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, side_effects_lipodystrophy, side_effects_lipodystrophy_enc_id)
VALUES('#{obs_person_id}', DATE('#{obs_visit_date}'), '#{side_effect_answer['name']}', '#{obs_encounter_id}') ;
EOF
        else #check patient_not_in_flat_table2
          if obs_voided == 0 #if voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_lipodystrophy = '#{side_effect_answer['name']}', side_effects_lipodystrophy_enc_id = '#{obs_encounter_id}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          else #else voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_lipodystrophy = NULL, side_effects_lipodystrophy_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end voided
        end #check patient_not_in_flat_table2
#-----------------------------------------------------------------------------------------------------------end lipodystrophy
      when 2150 #nightmares
        if patient_check.blank? #check patient_not_in_flat_table2
          #insert
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, side_effects_nightmares, side_effects_nightmares_enc_id)
VALUES('#{obs_person_id}', DATE('#{obs_visit_date}'), '#{side_effect_answer['name']}', '#{obs_encounter_id}') ;
EOF
        else #check patient_not_in_flat_table2
          if obs_voided == 0 #if voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_nightmares = '#{side_effect_answer['name']}', side_effects_nightmares_enc_id = '#{obs_encounter_id}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          else #else voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_nightmares = NULL, side_effects_nightmares_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end voided
        end #check patient_not_in_flat_table2
#-----------------------------------------------------------------------------------------------------------end nightmares
      when 1066 #symptom_no
        if patient_check.blank? #check patient_not_in_flat_table2
          #insert
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, side_effects_no, side_effects_no_enc_id)
VALUES('#{obs_person_id}', DATE('#{obs_visit_date}'), '#{side_effect_answer['name']}', '#{obs_encounter_id}') ;
EOF
        else #check patient_not_in_flat_table2
          if obs_voided == 0 #if voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_no = '#{side_effect_answer['name']}', side_effects_no_enc_id = '#{obs_encounter_id}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          else #else voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_no = NULL, side_effects_no_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end voided
        end #check patient_not_in_flat_table2
#-----------------------------------------------------------------------------------------------------------end side effects no
      when 6408 #other
        if patient_check.blank? #check patient_not_in_flat_table2
          #insert
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, side_effects_other, side_effects_other_enc_id)
VALUES('#{obs_person_id}', DATE('#{obs_visit_date}'), '#{side_effect_answer['name']}', '#{obs_encounter_id}') ;
EOF
        else #check patient_not_in_flat_table2
          if obs_voided == 0 #if voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_other = '#{side_effect_answer['name']}', side_effects_other_enc_id = '#{obs_encounter_id}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          else #else voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_other = NULL, side_effects_other_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end voided
        end #check patient_not_in_flat_table2
#---------------------------------------------------------------------------------------------------------------------------end other
      when 219 #psychosis
        if patient_check.blank? #check patient_not_in_flat_table2
          #insert
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, side_effects_psychosis, side_effects_psychosis_enc_id)
VALUES('#{obs_person_id}', DATE('#{obs_visit_date}'), '#{side_effect_answer['name']}', '#{obs_encounter_id}') ;
EOF
        else #check patient_not_in_flat_table2
          if obs_voided == 0 #if voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_psychosis = '#{side_effect_answer['name']}', side_effects_psychosis_enc_id = '#{obs_encounter_id}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          else #else voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_psychosis = NULL, side_effects_psychosis_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end voided
        end #check patient_not_in_flat_table2
#-------------------------------------------------------------------------------------------------------------------------end psychosis
      when 3681 #renal_failure
        if patient_check.blank? #check patient_not_in_flat_table2
          #insert
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, side_effects_renal_failure, side_effects_renal_failure_enc_id)
VALUES('#{obs_person_id}', DATE('#{obs_visit_date}'), '#{side_effect_answer['name']}', '#{obs_encounter_id}') ;
EOF
        else #check patient_not_in_flat_table2
          if obs_voided == 0 #if voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_renal_failure = '#{side_effect_answer['name']}', side_effects_renal_failure_enc_id = '#{obs_encounter_id}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          else #else voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_renal_failure = NULL, side_effects_renal_failure_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end voided
        end #check patient_not_in_flat_table2
#-------------------------------------------------------------------------------------------------------------------------end renal_failure
      when 512 #skin_rash
        if patient_check.blank? #check patient_not_in_flat_table2
          #insert
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, side_effects_skin_rash, side_effects_skin_rash_enc_id)
VALUES('#{obs_person_id}', DATE('#{obs_visit_date}'), '#{side_effect_answer['name']}', '#{obs_encounter_id}') ;
EOF
        else #check patient_not_in_flat_table2
          if obs_voided == 0 #if voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_skin_rash = '#{side_effect_answer['name']}', side_effects_skin_rash_enc_id = '#{obs_encounter_id}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          else #else voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_skin_rash = NULL, side_effects_skin_rash_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end voided
        end #check patient_not_in_flat_table2
#-------------------------------------------------------------------------------------------------------------------------end skin_rash
      when 5980 #vomiting
        if patient_check.blank? #check patient_not_in_flat_table2
          #insert
          Connection.execute <<EOF
INSERT INTO flat_table2 (patient_id, visit_date, side_effects_vomiting, side_effects_vomiting_enc_id)
VALUES('#{obs_person_id}', DATE('#{obs_visit_date}'), '#{side_effect_answer['name']}', '#{obs_encounter_id}') ;
EOF
        else #check patient_not_in_flat_table2
          if obs_voided == 0 #if voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_vomiting = '#{side_effect_answer['name']}', side_effects_vomiting_enc_id = '#{obs_encounter_id}'
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          else #else voided
            Connection.execute <<EOF
UPDATE flat_table2
SET  side_effects_vomiting = NULL, side_effects_vomiting_enc_id = NULL
WHERE flat_table2.id = '#{patient_check['ID']}';
EOF
          end #end voided
        end #check patient_not_in_flat_table2
#-------------------------------------------------------------------------------------------------------------------------end skin_rash
    end
  end

  puts "Finished working on patient_id: #{obs_person_id}"

end

start
