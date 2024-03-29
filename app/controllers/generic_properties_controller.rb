class GenericPropertiesController < ApplicationController
  def set_clinic_holidays
    @clinic_holidays = CoreService.get_global_property_value('clinic.holidays') rescue nil
  end

  def create_clinic_holidays
    if request.post? and not params[:holidays].blank?
      clinic_holidays = GlobalProperty.find_by_property('clinic.holidays')
      if clinic_holidays.blank?
        clinic_holidays = GlobalProperty.new()  
        clinic_holidays.property = 'clinic.holidays'
        clinic_holidays.description = 'day month year when clinic will be closed'
      end
      clinic_holidays.property_value = params[:holidays].split(',').uniq.join(',')
      clinic_holidays.save 
      flash[:notice] = 'Date(s) successfully created.'
      redirect_to '/properties/clinic_holidays' and return
		else
      redirect_to '/properties/set_clinic_holidays' and return
		end
  end

  def clinic_holidays
    @holidays = CoreService.get_global_property_value('clinic.holidays') rescue []
    
    #deleting all holidays that do not belong in the current year.
    current_year_holidays = []
    (@holidays.split(',')).each do |holiday|
      next unless holiday.to_date.year >= Date.today.year
      current_year_holidays << holiday
    end unless @holidays.blank?


    unless current_year_holidays.blank?
      global_property = GlobalProperty.find_by_property('clinic.holidays')
      global_property.update_attributes(:property_value => current_year_holidays.join(','))
    end 

    @holidays = current_year_holidays.collect{|date|date.to_date}.sort rescue []
    render :layout => "menu"
  end

  def clinic_days
    if request.post? 
      ['peads','all'].each do | age_group |
        if age_group == 'peads'
          clinic_days = GlobalProperty.find_by_property('peads.clinic.days')
          weekdays = params[:peadswkdays]
        else
          clinic_days = GlobalProperty.find_by_property('clinic.days')
          weekdays = params[:weekdays]
        end

        if clinic_days.blank?
          clinic_days = GlobalProperty.new()  
          clinic_days.property = 'clinic.days'
          clinic_days.property = 'peads.clinic.days' if age_group == 'peads'
          clinic_days.description = 'Week days when the clinic is open'
        end
        weekdays = weekdays.split(',').collect{ |wd|wd.capitalize }
        clinic_days.property_value = weekdays.join(',') 
        clinic_days.save 
      end
      flash[:notice] = "Week day(s) successfully created."
      redirect_to "/properties/clinic_days" and return
    end
    @peads_clinic_days = CoreService.get_global_property_value('peads.clinic.days') rescue nil
    @clinic_days = CoreService.get_global_property_value('clinic.days') rescue nil
    render :layout => "menu"
  end

  def show_clinic_days
    @clinic_days = week_days('clinic.days')
    @peads_clinic_days = week_days('peads.clinic.days')
    render :layout => "menu"
  end

  def week_days(property)
    wkdays = {}
    days = CoreService.get_global_property_value(property) rescue ''
    days.split(',').map do | day |
      wkdays[day] = 'X'
    end rescue nil
    return wkdays
  end

  def mailing_management
    @members = GlobalProperty.find_by_property("mailing.members").property_value.split(";") rescue []
    @enable = GlobalProperty.find_by_property("enable.mailing").property_value rescue "true"
  end

  def edit_members
    member = params[:id]
    all_members = GlobalProperty.find_by_property("mailing.members") rescue []
   
    if ! all_members.blank?
      all_members.property_value = all_members.property_value.gsub("#{member};", "")
      all_members.save
    end
    redirect_to "/properties/mailing_management" and return
  end

  def disable_mail
    enable = GlobalProperty.find_by_property("enable.mailing") rescue nil
    if enable.blank?
      nabled = GlobalProperty.new()
      nabled.property = "enable.mailing"
      nabled.property_value = "false"
      nabled.save
    else
      if enable.property_value == "true"
        enable.property_value = "false"
      else
        enable.property_value = "true"
      end
      enable.save
    end
    redirect_to "/properties/mailing_management" and return
  end

  def new_mail
    if request.post?
      members = GlobalProperty.find_by_property("mailing.members") rescue nil
      #raise members.property_value.to_yaml
      if members.blank?
        list = GlobalProperty.new()
        list.property = "mailing.members"
        list.property_value = "#{params[:first_name]}:#{params[:last_name]}:#{params[:email]};"
        list.save
      else
        members.property_value = "#{members.property_value}#{params[:first_name]}:#{params[:last_name]}:#{params[:email]};"
        members.save
      end
      redirect_to "/properties/mailing_management" and return
      #raise members.to_yaml
    end
  end

  def site_code  
    location = Location.find(Location.current_health_center.id)
    @neighborhood_cell = location.neighborhood_cell
    if request.post?
      location = Location.find(Location.current_health_center.id)
      location.neighborhood_cell = params[:site_code]
      if location.save
        if params[:view_configuration]
          redirect_to("/clinic/system_configurations") and return
        end
      
        redirect_to "/clinic" and return  # /properties
      else
        flash[:error] = "Site code not created.  (#{params[:site_code]})"
      end
    end
  end

  def site_appointment_limit
    if request.post? and not params[:appointment_limit].blank?
      appointment_limit = GlobalProperty.find_by_property('clinic.appointment.limit')

      if appointment_limit.blank?
        appointment_limit = GlobalProperty.new()  
        appointment_limit.property = 'clinic.appointment.limit'
        appointment_limit.description = 'number of appointments allowed per clinic day'
      end
      appointment_limit.property_value = params[:appointment_limit]
      appointment_limit.save 
      # redirect_to "/clinic/properties" and return
      if params[:view_configuration]
        redirect_to("/clinic/system_configurations") and return
      end
      redirect_to "/clinic" and return
    end
  end
  
  def set_role_privileges
    if request.post?
      role = params[:role]['title']
      privileges = params[:role]['privileges']

      RolePrivilege.find(:all,:conditions => ["role = ?",role]).each do | privilege |
        privilege.destroy
      end

      privileges.each do | privilege |
        role_privilege = RolePrivilege.new()
        role_privilege.role = Role.find_by_role(role)
        role_privilege.privilege = Privilege.find_by_privilege(privilege)
        role_privilege.save
      end
      if params[:id]
        redirect_to "/patients/show/#{params[:id]}" and return
      else
        redirect_to "/clinic" and return
      end
    else
      @privileges = Privilege.find(:all).collect{|r|r.privilege}
      @activities = RolePrivilege.find(:all).collect{ |r|r.privilege.privilege }
    end
  end

  def selected_roles
    render :text => "<li>" + RolePrivilege.find(:all, 
      :conditions =>["role = ?", params[:role]]).collect { |r|
      r.privilege.privilege
    }.uniq.join("</li><li>") + "</li>"
  end

  def creation
    if request.post?     
      global_property = GlobalProperty.find_by_property(params[:property]) || GlobalProperty.new()
      global_property.property = params[:property]
      global_property.property_value = (params[:property_value].downcase == "yes").to_s
      global_property.save
      if params[:view_configuration]
        redirect_to("/clinic/system_configurations") and return
      end
      redirect_to '/clinic' and return
    end
  end

end
