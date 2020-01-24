class NotificationTrackerController < ApplicationController
  
  def track
    patient_id = session[:active_patient_id]
    notification = NotificationTracker.create_notification(params[:notification_name], params[:response_text], patient_id)  
    render :text => notification.to_json and return
  end

  def patients_seen
    visit_date = params[:visit_date].to_date rescue Date.today

    num_of_patients_seen = ActiveRecord::Base.connection.select_one <<EOF
    SELECT count(*) AS seen FROM patient_seen WHERE visit_date = '#{visit_date}';
EOF

    incomplete = ActiveRecord::Base.connection.select_one <<EOF
    SELECT count(*) AS incomplete FROM overall_record_complete_status o 
    INNER JOIN patient_seen s ON s.patient_seen_id = o.patient_seen_id
    WHERE s.visit_date = '#{visit_date}';
EOF

    render :text => {:total => num_of_patients_seen['seen'].to_i,
      :incomplete => incomplete['incomplete'].to_i,
      :incomplete_percentage =>( ((incomplete['incomplete'].to_f/num_of_patients_seen['seen'].to_i)*100).to_i rescue 0 ),
      :complete_percentage => ( (100 - ((incomplete['incomplete'].to_f/num_of_patients_seen['seen'].to_i)*100).to_i) rescue 0 ) ,
      :complete => (num_of_patients_seen['seen'].to_i - incomplete['incomplete'].to_i)}.to_json

  end

  def visit_status_trends
  	trends = get_visit_status_trends(params[:visit_date].to_date)
    render :text => trends.to_json
  end

  def individual_feedback
    if request.post?
      NotificationTracker.create(:notification_name => 'Individual summary shown (all reports)',
        :notification_response => 'Yes', :patient_id => 0,
        :notification_datetime => Time.now(), 
        :user_id => User.current.id)

      redirect_to '/' and return
    else
      NotificationTracker.create(:notification_name => 'Individual summary shown',
        :notification_response => 'Yes', :patient_id => 0,
        :notification_datetime => Time.now(), 
        :user_id => User.current.id)
    end

		@main_date =  (Date.today - 1.day)
    start_date 	= @main_date.strftime('%Y-%m-%d 00:00:00') 
    end_date 		= @main_date.strftime('%Y-%m-%d 23:59:59') 

	  hiv_encounter_types = ['HIV RECEPTION','HIV STAGING',
      'VITALS','PART_FOLLOWUP','HIV CLINIC REGISTRATION',
      'DISPENSING','HIV CLINIC CONSULTATION','TREATMENT','ART ADHERENCE','APPOINTMENT']

	  hiv_encounter_type_ids = EncounterType.find(:all, 
      :conditions =>["name IN(?)", hiv_encounter_types]).map(&:id)

	  patients_seen = ActiveRecord::Base.connection.select_all <<EOF
		SELECT count(e.patient_id), e.patient_id FROM encounter e
		WHERE encounter_datetime BETWEEN '#{start_date}' AND '#{end_date}'
		AND e.voided = 0 AND e.creator = #{User.current.id}
		AND encounter_type IN(#{hiv_encounter_type_ids.join(',')}) 
		GROUP BY e.patient_id;
EOF

		seen = []

		(patients_seen || [] ).each do |p|
			seen << p['patient_id'].to_i
		end

	  incomplete = ActiveRecord::Base.connection.select_all <<EOF
		SELECT i.ppi_id, t2.visit_date, t2.user_id, s.patient_id FROM overall_record_complete_status t
		INNER JOIN patient_seen s on s.patient_seen_id = t.patient_seen_id
		INNER JOIN provider_patient_interactions i ON i.patient_id = s.patient_id
		INNER JOIN providers_who_interacted_with_patients t2 ON t2.pi_id = i.pi_id
		where user_id = #{User.current.id} 
		AND t2.visit_date BETWEEN '#{start_date}' AND '#{end_date}';
EOF

		incomplete_visits = []

		(incomplete || [] ).each do |p|
			incomplete_visits << p['patient_id'].to_i
		end

		@incomplete_visits = incomplete_visits.length rescue 0
		@patients_seen = seen.length rescue 0

		total_seen  = seen.length
		incomplete  = incomplete_visits.length
		complete    = (total_seen - incomplete)

		@incomplete_percentage = ( ((incomplete.to_f/total_seen.to_f)*100).to_i rescue 0)
		@complete_percentage 	= ( (100 - ((incomplete.to_f/total_seen.to_f)*100).to_i) rescue 0) 

		@individual_trends = get_individual_visit_status_trends(@main_date)
  end

  def individual_feedback_clinical_assessment
    date        = params[:session_date].to_date rescue (Date.today - 1.day)
    user_id     = User.current.id

    recommendations = ActiveRecord::Base.connection.select_all <<EOF
      SELECT notification_name, notification_response, notification_datetime, patient_id 
      FROM notification_tracker where user_id = #{user_id}
      AND notification_datetime BETWEEN '#{date.strftime('%Y-%m-%d 00:00:00')}'
      AND '#{date.strftime('%Y-%m-%d 23:59:59')}' 
      GROUP BY notification_name, notification_response, notification_datetime, patient_id 
      ORDER BY notification_datetime DESC;
EOF
    
    responses = []
    (recommendations || []).each do |r|
      next unless r['notification_name'].match(/weight loss|family planning method|booking|medication induced/i)
      next unless r['notification_response'].match(/Confirm weight loss|Look for another date|Select other regimens/i)
      description = get_notification_description(r['notification_name'])
      patient_id = r['patient_id'].to_i

      if r['notification_name'].match(/family planning method/i)
        user_response = get_user_response_on_family_planning_methods(user_id, patient_id, r['notification_datetime'])
        unless user_response.include?('NONE')
          next
        end
        user_response = user_response.join(',') rescue nil
      else
        user_response = r['notification_response']
      end

      recommendation = get_recommendation(r['notification_name'])
      responses << {
        :name =>  r['notification_name'],
        :description => description,
        :response => user_response,
        :recommendation => recommendation
      }
    
      responses = responses.uniq
    end

    render :text => responses.to_json 
  end

  def shown
    noti = NotificationTracker.create(:notification_name => 'Daily summary shown',
      :notification_response => 'Yes', :patient_id => 0,
      :notification_datetime => Time.now(), 
      :user_id => User.current.id)

    render :text => noti.to_json 
  end

  def missed_encounters
		session_date = params[:session_date].to_date 

   	encounters = ActiveRecord::Base.connection.select_all <<EOF
		SELECT missed_encounter_type_id FROM encounters_missed e
		INNER JOIN provider_patient_interactions p ON e.ppi_id = p.ppi_id
		INNER JOIN providers_who_interacted_with_patients x on x.pi_id = p.pi_id
		WHERE user_id = #{User.current.id} AND visit_date = '#{session_date}'
EOF

		missed_encounters_hash = Hash.new(0)

		(encounters || []).each do |e|
			encounter_type = EncounterType.find(e['missed_encounter_type_id'].to_i)
			missed_encounters_hash[encounter_type.name] += 1
		end
    
    render :text => missed_encounters_hash.to_json 
  end

	private

  def get_user_response_on_family_planning_methods(user_id, patient_id, notification_datetime)
    start_date  = notification_datetime.to_time.strftime('%Y-%m-%d %H:%M:%S')
    end_date    = notification_datetime.to_date.strftime('%Y-%m-%d 23:59:59')

    concept_id  = ConceptName.find_by_name('FAMILY PLANNING, ACTION TO TAKE').concept_id
    answers     = Observation.find(:last, :conditions =>["concept_id = ? AND creator = ?
      AND person_id = ? AND obs_datetime BETWEEN ? AND ?", 
      concept_id, user_id, patient_id, start_date, end_date])

    ans = []
    (answers || []).each do |a|
      ans << ConceptName.find_by_concept_id(a.value_coded).name.upcase
    end

    return ans
  end

  def get_recommendation(notification_name)
    if notification_name.match(/weight loss/i)
      return "Select 'Yes' to Weight loss: Review documented previous weight whenever available
      as reported weight loss can be unreliable. 
      Investigate any consistent weight loss over 2 or more consecutive visits. Remember to confirm that
      the scale is correctly calibrated and any heavy clothing was removed"
    elsif notification_name.match(/family planning method/i)
      return "Unless patient wants to get pregnant provide neccessary family planning methods"
    elsif notification_name.match(/Over booking/i)
      return "Select a different date to avoid patient overcrowding."
    elsif notification_name.match(/Booking on a holiday/i)
      return "Select a different date to avoid patient coming on a clinic holiday."
    elsif notification_name.match(/medication induced/i)
      return "Select a different regimen"
    end
  end

  def get_notification_description(notification_name)
    if notification_name.match(/weight loss/i)
      return "Decrease in patient's weight: 10% or more since last recorded weight"
    elsif notification_name.match(/family planning method/i)
      return "Avoid unwanted pregnancies, regardless of HIV infection status. 
      Use ‘dual protection’ – condoms alone are not enough for family planning as they have to be used very consistently."
    elsif notification_name.match(/Over booking/i)
      return "The number of patient reverved to come on that day has reached the maximum number that the cinic can comfortably handle"
    elsif notification_name.match(/Booking on a holiday/i)
      return "None clinic day: the patient will come on a day that the clinic will be closed"
    elsif notification_name.match(/medication induced/i)
      return "Medication prescribed are causing side effects."
    end
  end

  def get_visit_status_trends(param_date)
    visit_dates = ActiveRecord::Base.connection.select_all <<EOF
    SELECT DISTINCT(visit_date) visit_date 
    FROM patient_seen e 
    WHERE visit_date BETWEEN '#{param_date - 6.day}'
    AND '#{param_date}'
    ORDER BY visit_date; 
EOF

    trends = []

    (visit_dates || []).each do |vdate|
      visit_date = vdate['visit_date'].to_date

      num_of_patients_seen = ActiveRecord::Base.connection.select_one <<EOF
      SELECT count(*) AS seen FROM patient_seen WHERE visit_date = '#{visit_date}';
EOF

      incomplete = ActiveRecord::Base.connection.select_one <<EOF
      SELECT count(*) AS incomplete FROM overall_record_complete_status o 
      INNER JOIN patient_seen s ON s.patient_seen_id = o.patient_seen_id
      WHERE s.visit_date = '#{visit_date}';
EOF

      total_seen  = num_of_patients_seen['seen'].to_i
      incomplete  = incomplete['incomplete'].to_i
      complete    = (total_seen - incomplete)

      trends << { :total_seen => total_seen, :incomplete => incomplete,
        :complete => complete, :visit_date => visit_date.strftime('%d/%b/%y') }

    end

    return trends
  end

  def get_individual_visit_status_trends(param_date)

	  hiv_encounter_types = ['HIV RECEPTION','HIV STAGING',
      'VITALS','PART_FOLLOWUP','HIV CLINIC REGISTRATION',
      'DISPENSING','HIV CLINIC CONSULTATION','TREATMENT','ART ADHERENCE','APPOINTMENT']

	  hiv_encounter_type_ids = EncounterType.find(:all, 
      :conditions =>["name IN(?)", hiv_encounter_types]).map(&:id)
		
		visit_dates = ((param_date - 4.day)..param_date).map{ |date| date }
    trends = []

    (visit_dates || []).each do |vdate|
			start_date 	= vdate.strftime('%Y-%m-%d 00:00:00') 
			end_date 		= vdate.strftime('%Y-%m-%d 23:59:59') 

			patients_seen = ActiveRecord::Base.connection.select_all <<EOF
			SELECT count(e.patient_id), e.patient_id FROM encounter e
			WHERE encounter_datetime BETWEEN '#{start_date}' AND '#{end_date}'
			AND e.voided = 0 AND e.creator = #{User.current.id}
			AND encounter_type IN(#{hiv_encounter_type_ids.join(',')}) 
			GROUP BY e.patient_id;
EOF

			seen = []

			(patients_seen || [] ).each do |p|
				seen << p['patient_id'].to_i
			end

			incomplete = ActiveRecord::Base.connection.select_all <<EOF
			SELECT i.ppi_id, t2.visit_date, t2.user_id, s.patient_id FROM overall_record_complete_status t
			INNER JOIN patient_seen s on s.patient_seen_id = t.patient_seen_id
			INNER JOIN provider_patient_interactions i ON i.patient_id = s.patient_id
			INNER JOIN providers_who_interacted_with_patients t2 ON t2.pi_id = i.pi_id
			where user_id = #{User.current.id} 
			AND t2.visit_date BETWEEN '#{start_date}' AND '#{end_date}';
EOF

			incomplete_visits = []

			(incomplete || [] ).each do |p|
				incomplete_visits << p['patient_id'].to_i
			end

      total_seen  = seen.length
      incomplete  = incomplete_visits.length
      complete    = (total_seen - incomplete)

      trends << { :total_seen => total_seen, :incomplete => incomplete,
        :complete => complete, :visit_date => vdate.strftime('%d/%b/%Y') }
		end

		return trends
  end

end
