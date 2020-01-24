class PropertiesController < GenericPropertiesController
	def export_cohort_data
    if request.post? and not params[:export_cohort_data].blank?
      session["export.cohort.data"] = params[:export_cohort_data]
      
      if params[:view_configuration]
        redirect_to("/clinic/system_configurations") and return
      end

      redirect_to '/clinic' and return
    end
	end

	def staging_options
    global_setting = GlobalProperty.find_by_property("use.extended.staging.questions")
    global_setting.property_value = "false"
    global_setting.property_value = "true" if params['staging_options'].to_s.match(/extended/i)
    global_setting.save

    if params[:view_configuration]
      redirect_to("/clinic/system_configurations") and return
    end
    
    redirect_to '/clinic' and return
	end

  def filing_number
    if request.post?
			filing_limit = GlobalProperty.find_by_property("filing.number.limit") rescue nil
      if filing_limit.nil?
        filing_limit = GlobalProperty.new
        filing_limit.property = "filing.number.limit"
        filing_limit.description = "Maximum number for archiving of files to begin"
        filing_limit.property_value = params[:filing_number]
        filing_limit.save
      else
        filing_limit = GlobalProperty.find_by_property("filing.number.limit")
        filing_limit.property_value = params[:filing_number]
        filing_limit.save
      end

      if params[:view_configuration]
        redirect_to("/clinic/system_configurations") and return
      end
      
      redirect_to '/clinic' and return
    end
  end

  def set_htn_age_threshold

    if request.post?
      age_threshold = GlobalProperty.find_by_property('htn.screening.age.threshold')

      if age_threshold.blank?
        age_threshold = GlobalProperty.new()
        age_threshold.property = "htn.screening.age.threshold"
        age_threshold.description = "Defines the age at which patients will start being screened for hypertension"
      end

      age_threshold.property_value = params[:value]
      age_threshold.save

      if params[:view_configuration]
        redirect_to("/clinic/system_configurations") and return
      end
      
      redirect_to "/clinic" and return
    end
  end

  def set_htn_bp_thresholds
    if request.post?
      diastolic_threshold = GlobalProperty.find_by_property('htn.diastolic.threshold')
      systolic_threshold = GlobalProperty.find_by_property('htn.systolic.threshold')

      if diastolic_threshold.blank?
        diastolic_threshold = GlobalProperty.new()
        diastolic_threshold.property = 'htn.diastolic.threshold'
        diastolic_threshold.description = "Defines the measurement at which diastolic blood pressure is considered high"
      end

      if systolic_threshold.blank?
        systolic_threshold = GlobalProperty.new()
        systolic_threshold.property = 'htn.systolic.threshold'
        systolic_threshold.description = "Defines the measurement at which systolic blood pressure is considered high"
      end

      diastolic_threshold.property_value = params[:diastolic]
      diastolic_threshold.save
      systolic_threshold.property_value = params[:systolic]
      systolic_threshold.save

      if params[:view_configuration]
        redirect_to("/clinic/system_configurations") and return
      end
      
      redirect_to "/clinic" and return
    end
  end

  def cervical_cancer_module_properties
    cervical_cancer_min_age_property = "cervical.cancer.min.age"
    cervical_cancer_max_age_property = "cervical.cancer.max.age"
    daily_referral_limit_concept = "cervical.cancer.daily.referral.limit"
    current_daily_referral_limit = GlobalProperty.find_by_property(daily_referral_limit_concept).property_value rescue '??'

    cervical_cancer_property = (CoreService.get_global_property_value('activate.cervical.cancer.screening') == "true")
    current_cervical_min_age  = GlobalProperty.find_by_property(cervical_cancer_min_age_property).property_value rescue '??'
    current_cervical_max_age  = GlobalProperty.find_by_property(cervical_cancer_max_age_property).property_value rescue '??'

    age_limits = "<span style='color: orange; font-style: italic;'>Current Age Limit</span> : <span style='color: orange; font-weight: bold;'>#{current_cervical_min_age.to_s + ' to ' + current_cervical_max_age}</span>"
    daily_referral_limit = "<span style='color: orange; font-style: italic;'>Current Daily Limit is </span> <span style='color: orange; font-weight: bold;'>#{current_daily_referral_limit}</span>"

    @reports =  [
      ["/properties/set_cervical_cancer_age_limits","Set Age Limit (#{age_limits})"],
      ['/properties/set_daily_referral_limit',"Set Daily Referral Limit (#{daily_referral_limit})"]
    ]
    if !cervical_cancer_property
      status = "<span style='color: orange; font-style: italic;'>Status </span>: <span style='color: orange; font-weight: bold;'>DEACTIVATED</span>"
      @reports << ['/properties/activate_cervical_cancer_screening_module',"Activate (#{status})"]
    else
      status = "<span style='color: orange; font-style: italic;'>Status </span>: <span style='color: orange; font-weight: bold;'>ACTIVATED</span>"
      @reports << ['/properties/deativate_cervical_cancer',"Deactivate #{status}"]
    end
    # render :layout => 'clinic'
    render :template => 'properties/cervical_cancer_module_properties', :layout => false
  end

  def activate_cervical_cancer_screening_module
    cervical_cancer_screening_property = "activate.cervical.cancer.screening"
    global_property = GlobalProperty.find_by_property(cervical_cancer_screening_property) || GlobalProperty.new()
    global_property.property = cervical_cancer_screening_property
    global_property.property_value = "true"
    global_property.save
    redirect_to "/clinic" and return
  end

  
  def deativate_cervical_cancer
    cervical_property = GlobalProperty.find_by_property('activate.cervical.cancer.screening')
    cervical_property.delete if cervical_property
    redirect_to "/clinic" and return
  end

  def set_cervical_cancer_age_limits
    cervical_cancer_min_age_property = "cervical.cancer.min.age"
    cervical_cancer_max_age_property = "cervical.cancer.max.age"
    @global_property_min = GlobalProperty.find_by_property(cervical_cancer_min_age_property).property_value rescue ""
    @global_property_max = GlobalProperty.find_by_property(cervical_cancer_max_age_property).property_value rescue ""
    
    if request.post?
      min_age = params[:min_age].to_i
      max_age = params[:max_age].to_i

      if max_age < min_age
        flash[:notice] = "Max age is greater than min age"
        redirect_to("/properties/set_cervical_cancer_age_limits") and return
      end

      ActiveRecord::Base.transaction do
        global_property_min = GlobalProperty.find_by_property(cervical_cancer_min_age_property) || GlobalProperty.new()
        global_property_min.property = cervical_cancer_min_age_property
        global_property_min.property_value = min_age
        global_property_min.save

        global_property_max = GlobalProperty.find_by_property(cervical_cancer_max_age_property) || GlobalProperty.new()
        global_property_max.property = cervical_cancer_max_age_property
        global_property_max.property_value = max_age
        global_property_max.save
      end

      redirect_to '/clinic' and return
    end
  end

  def set_daily_referral_limit
    daily_referral_limit_concept = "cervical.cancer.daily.referral.limit"
    @global_property_referral_limit = GlobalProperty.find_by_property(daily_referral_limit_concept).property_value rescue ""
    
    if request.post?
      global_property_daily_referral_limit = GlobalProperty.find_by_property(daily_referral_limit_concept) || GlobalProperty.new()
      global_property_daily_referral_limit.property = daily_referral_limit_concept
      global_property_daily_referral_limit.property_value = params[:daily_referral_limit]
      global_property_daily_referral_limit.save     
      redirect_to '/clinic' and return
    end
    
  end

  def create_new_art_guide_line_start_date
    new_art_start_date_concept = "new.art.start.date"
    if request.post?
      new_start_date = (params[:start_day].to_s + '-' + params[:start_month].to_s + '-' + params[:start_year].to_s).to_date
      global_property_new_art_start_date = GlobalProperty.find_by_property(new_art_start_date_concept) || GlobalProperty.new()
      global_property_new_art_start_date.property = new_art_start_date_concept
      global_property_new_art_start_date.property_value = new_start_date
      global_property_new_art_start_date.save
      redirect_to '/clinic' and return
    end
  end

  def dde_code_map
    @site_code = PatientIdentifier.site_prefix
    @dde_code = PatientIdentifier.dde_code
  end

  def create_dde_code_map
    global_property_dde_status = GlobalProperty.find_by_property('dde.code') || GlobalProperty.new()
    global_property_dde_status.property = 'dde.code'
    global_property_dde_status.property_value = params[:dde_code]
    global_property_dde_status.save
    redirect_to("/clinic") and return
  end
  
  def dde_properties_menu
    @dde_status = GlobalProperty.find_by_property('dde.status').property_value rescue ""
    @dde_status = 'Yes' if @dde_status.match(/ON/i)
    @dde_status = 'No' if @dde_status.match(/OFF/i)
    @dde_address = GlobalProperty.find_by_property('dde.address').property_value rescue ""
    @dde_port = GlobalProperty.find_by_property('dde.port').property_value rescue ""
    @dde_username = GlobalProperty.find_by_property('dde.username').property_value rescue ""
    @dde_password = GlobalProperty.find_by_property('dde.password').property_value rescue ""
  end

  def portal_properties_menu
    @portal_status = GlobalProperty.find_by_property('portal.status').property_value rescue ""
    @portal_status = 'Yes' if @portal_status.match(/ON/i)
    @portal_status = 'No' if @portal_status.match(/OFF/i)
    @portal_address = GlobalProperty.find_by_property('portal.address').property_value rescue ""
    @portal_port = GlobalProperty.find_by_property('portal.port').property_value rescue ""
  end

  def create_dde_properties
    dde_status = params[:dde_status]
    if dde_status.squish.downcase == 'yes'
      dde_status = 'ON'
    else
      dde_status = 'OFF'
    end

    ActiveRecord::Base.transaction do
      global_property_dde_status = GlobalProperty.find_by_property('dde.status') || GlobalProperty.new()
      global_property_dde_status.property = 'dde.status'
      global_property_dde_status.property_value = dde_status
      global_property_dde_status.save

      if (dde_status == 'ON') #Do this part only when DDE is activated
        global_property_dde_address = GlobalProperty.find_by_property('dde.address') || GlobalProperty.new()
        global_property_dde_address.property = 'dde.address'
        global_property_dde_address.property_value = params[:dde_address]
        global_property_dde_address.save

        global_property_dde_port = GlobalProperty.find_by_property('dde.port') || GlobalProperty.new()
        global_property_dde_port.property = 'dde.port'
        global_property_dde_port.property_value = params[:dde_port]
        global_property_dde_port.save

        global_property_dde_username = GlobalProperty.find_by_property('dde.username') || GlobalProperty.new()
        global_property_dde_username.property = 'dde.username'
        global_property_dde_username.property_value = params[:dde_username]
        global_property_dde_username.save

        global_property_dde_password = GlobalProperty.find_by_property('dde.password') || GlobalProperty.new()
        global_property_dde_password.property = 'dde.password'
        global_property_dde_password.property_value = params[:dde_password]
        global_property_dde_password.save
      end
      
    end

    if (dde_status == 'ON')
      site_code = PatientIdentifier.dde_code#PatientIdentifier.site_prefix
      data = {
        "username" => "#{params[:dde_username]}",
        "password"  => "#{params[:dde_password]}",
        "site_code" => site_code,
        "application" =>"ART",
        "description" => "DDE user in an ART app"
      }
      dde_token = PatientService.add_dde_user(data)
      if dde_token.blank?
        flash[:notice] = "DDE user already exists."
        redirect_to("/properties/dde_properties_menu") and return
      end
      session[:dde_token] = dde_token unless dde_token.blank?
    end
    
    redirect_to("/clinic") and return
  end

  def create_portal_properties
    portal_status = params[:portal_status]
    
    if portal_status.squish.downcase == 'yes'
      portal_status = 'ON'
    else
      portal_status = 'OFF'
    end

    ActiveRecord::Base.transaction do
      global_property_portal_status = GlobalProperty.find_by_property('portal.status') || GlobalProperty.new()
      global_property_portal_status.property = 'portal.status'
      global_property_portal_status.property_value = portal_status
      global_property_portal_status.save

      if (portal_status == 'ON') #Do this part only when PORTAL is activated
        global_property_portal_address = GlobalProperty.find_by_property('portal.address') || GlobalProperty.new()
        global_property_portal_address.property = 'portal.address'
        global_property_portal_address.property_value = params[:portal_address]
        global_property_portal_address.save

        global_property_portal_port = GlobalProperty.find_by_property('portal.port') || GlobalProperty.new()
        global_property_portal_port.property = 'portal.port'
        global_property_portal_port.property_value = params[:portal_port]
        global_property_portal_port.save
      end

    end

    redirect_to("/clinic") and return
  end

end
