class GenericClinicController < ApplicationController
  require 'rest-client'
  def index
    return_uri = session[:return_uri]
    if !return_uri.blank?
      session[:return_uri] = []
      redirect_to return_uri.to_s
      return
    end

    (session || {}).each do |name , values|
      next unless name == 'patient_id'
      session[name] = nil
    end

    session[:cohort] = nil
    @facility = Location.current_health_center.name rescue ''

    @location = Location.find(session[:location_id]).name rescue ""

    @date = (session[:datetime].to_date rescue Date.today).strftime("%Y-%m-%d")

    @user = current_user.name rescue ""

    @roles = current_user.user_roles.collect{|r| r.role} rescue []
    session[:stage_patient] = ""

    portal_status = CoreService.get_global_property_value("portal.status").to_s.squish.upcase rescue ""
    portal_address = CoreService.get_global_property_value("portal.address").to_s rescue ""
    portal_port = CoreService.get_global_property_value("portal.port").to_s rescue ""
    @portal_uri = "http://#{portal_address}:#{portal_port}" rescue ""
    
    render :template => 'clinic/index', :layout => false
  end

  def reports
    @reports = [
      ["Supervision","/clinic/supervision"],
      ["Data Cleaning Tools", "/report/data_cleaning"],
      ["Stock report","/drug/date_select"]
    ]

    render :template => 'clinic/reports', :layout => 'clinic'
  end

  def supervision
    @supervision_tools = [["Data that was Updated","summary_of_records_that_were_updated"],
      ["Drug Adherence Level","adherence_histogram_for_all_patients_in_the_quarter"],
      ["Visits by Day", "visits_by_day"],
      ["Non-eligible Patients in Cohort", "non_eligible_patients_in_cohort"]]

    @landing_dashboard = 'clinic_supervision'

    render :template => 'clinic/supervision', :layout => 'clinic'
  end

  def properties
    @settings = [
      ["Set clinic days","/properties/clinic_days"],
      ["View clinic holidays","/properties/clinic_holidays"],
      ["Set clinic holidays","/properties/set_clinic_holidays"],
      ["Set site code", "/properties/site_code"],
      ["Set appointment limit", "/properties/set_appointment_limit"]
    ]
    render :template => 'clinic/properties', :layout => 'clinic'
  end

  def management
    @reports = [
      ["New stock","delivery"],
      ["Edit stock","edit_stock"],
      ["Print Barcode","print_barcode"],
      ["Expiring drugs","date_select"],
      ["Removed from shelves","date_select"],
      ["Stock report","date_select"]
    ]
    render :template => 'clinic/management', :layout => 'clinic'
  end

  def printing
    render :template => 'clinic/printing', :layout => 'clinic'
  end

  def users
    render :template => 'clinic/users', :layout => 'clinic'
  end

  def administration
    @reports =  [
      ['/clinic/users','User accounts/settings'],
      ['/clinic/management','Drug Management'],
      ['/clinic/location_management','Location Management']
    ]
    @landing_dashboard = 'clinic_administration'
    render :template => 'clinic/administration', :layout => 'clinic'
  end

  def overview_tab
    simple_overview_property = CoreService.get_global_property_value("simple_application_dashboard") rescue nil

    simple_overview = false
    if simple_overview_property != nil
      if simple_overview_property == 'true'
        simple_overview = true
      end
    end

    @types = CoreService.get_global_property_value("statistics.show_encounter_types") rescue EncounterType.all.map(&:name).join(",")
    @types = @types.split(/,/)

    @me = Encounter.statistics(@types,
      :conditions => ['encounter_datetime BETWEEN ? AND ? AND encounter.creator = ?',
        Date.today.strftime('%Y-%m-%d 00:00:00'),
        Date.today.strftime('%Y-%m-%d 23:59:59'),
        current_user.user_id])
    @today = Encounter.statistics(@types,
      :conditions => ['encounter_datetime BETWEEN ? AND ?',
        Date.today.strftime('%Y-%m-%d 00:00:00'),
        Date.today.strftime('%Y-%m-%d 23:59:59')])

    if !simple_overview
      @year = Encounter.statistics(@types,
        :conditions => ['encounter_datetime BETWEEN ? AND ?',
          Date.today.strftime('%Y-01-01 00:00:00'),
          Date.today.strftime('%Y-12-31 23:59:59')])
      @ever = Encounter.statistics(@types)
    end

    @user = User.find(current_user.user_id).person.name rescue ""

    if simple_overview
      render :template => 'clinic/overview_simple.rhtml' , :layout => false
      return
    end
    render :layout => false
  end

  def viral_load_tab
    if national_lims_activated
      settings = YAML.load_file("#{Rails.root}/config/lims.yml")[Rails.env]
      url = settings['lims_national_dashboard_ip'] + "/api/viral_load_stats"
      url_undispatched_vl = settings['lims_national_dashboard_ip'] + "/api/undispatched_viral_load"
    end
    undispatched_viral_load = JSON.parse(RestClient.get(url_undispatched_vl)) rescue {}

    data = JSON.parse(RestClient.get(url)) rescue {}
    
    if !undispatched_viral_load.blank?
      @total_count = undispatched_viral_load.length
		end

    data.keys.each do |category|
			data[category].each do |order|
					order['date_time'] = order['date_time'].to_date.strftime("%d-%b-%Y") if (order['date_time'] rescue false)
			end
		end 

    @data = {}
    @data['pending'] = data['pending'] || []
    @data['rejected'] = data['rejected'] || []
    @data['less_than_1000_not_given'] = []
    @data['less_than_1000_given'] = []
    @data['more_than_1000_not_given'] = []
    @data['more_than_1000_given'] = []
    counter =1
    check = 1
    (data['completed'] || []).each do |order|
      results = (order['results']['Viral Load'] || order['results']['Viral load'] || order['results']['VL'])
      counter = results.length
     if !results.blank?
  	timestamp = results.keys.sort.last
              
        if !results[timestamp]['results'].blank?

          result = results[timestamp]['results']
     
          vl = (result['Viral Load'] || result['Viral load'] || result['VL']).strip
		  if (vl.match(/\</) && vl.scan(/\d+/).last.to_i <= 1000)
                    @data['less_than_1000_not_given'] << order
                  elsif (vl.match(/\d+/))
                    @data['more_than_1000_not_given'] << order
                  end
        end

     end

     end
    
    

    (data['reviewed'] || []).each do |order|
      results = (order['results']['Viral load'] || order['results']['Viral Load'] || order['results']['VL'])
      timestamp = results.keys.sort.last
      result = results[timestamp]['results']
      vl = (result['Viral load'] || result['Viral Load'] || result['VL'])
      if (vl.match(/\</) && vl.scan(/\d+/).last.to_i <= 1000)
        @data['less_than_1000_given'] << order
      elsif (vl.match(/\d+/))
        @data['more_than_1000_given'] << order
      end
    end

    @data["available"] = @data["more_than_1000_not_given"] + @data["less_than_1000_not_given"]

    render :layout => false
  end

  def reports_tab
    @reports = [
      #Cohort disaggregated button was moved to main cohort report
      #["Cohort disaggregated","/cohort_tool/disaggregated_cohort_menu"],
      ["Cohort / Disaggregated","/cohort_tool/revised_cohort_menu"],
      ["Cohort analyzer","/report/summarize_cohort_report?type=summary"],
      ["Cohort Survival Analysis","/cohort_tool/revised_cohort_survival_analysis_menu"],
      ["Supervision","/clinic/supervision_tab"],
      ["Data Cleaning Tools", "/clinic/data_cleaning_tab"],
      
      ["Drug dispensation","/report/drug_menu"],
      ["Pre-ART","/cohort_tool/cohort_menu?type=pre_art"],
      ["View appointments","/properties/select_date"],
      ["Missed Appointments", "/report/missed_appointment_duration?type=missed"],
      ["Defaulted patients", "/report/missed_appointment_duration?type=defaulter"],
      ["Avg ART clinic duration for patients", "/report/avg_waiting_time_for_art_patients"],
      ["Flat tables reports", "/cohort_tool/flat_tables_revised_cohort_menu"],
      ["HTN Reports", "/cohort_tool/select_htn_date"],
      ["Fast Track Reports", "/cohort_tool/select_fast_track_date"],
      ["PEPFAR disaggregated report","/report/missed_appointment_duration?type=disaggregated"],
      ["DHA-Fast Track Reports", "/cohort_tool/select_dha_fast_track_date"]
    ]

    show_user_feedback = GlobalProperty.find_by_property('show.user.feedback').property_value == 'true' rescue false
    if show_user_feedback 
      @reports << ["Individual performance stats", "/notification_tracker/individual_feedback"]
    end

  	if what_app? == 'TB-ART'
  		@reports <<  ["Case Findings", "/cohort_tool/case_findings_quarter"] << ["TB Register","/cohort_tool/report_duration?report_name=tb_register"] #<< ["Laboratory Register","/cohort_tool/report_duration?report_name=lab_register"]

  	end
    @reports = [
      ["Diagnosis","/drug/date_select?goto=/report/age_group_select?type=diagnosis"],
      # ["Patient Level Data","/drug/date_select?goto=/report/age_group_select?type=patient_level_data"],
      ["Disaggregated Diagnosis","/drug/date_select?goto=/report/age_group_select?type=disaggregated_diagnosis"],
      ["Referrals","/drug/date_select?goto=/report/opd?type=referrals"],
      #["Total Visits","/drug/date_select?goto=/report/age_group_select?type=total_visits"],
      #["User Stats","/drug/date_select?goto=/report/age_group_select?type=user_stats"],
      ["User Stats","/"],
      # ["Total registered","/drug/date_select?goto=/report/age_group_select?type=total_registered"],
      ["Diagnosis (By address)","/drug/date_select?goto=/report/age_group_select?type=diagnosis_by_address"],
      ["Diagnosis + demographics","/drug/date_select?goto=/report/age_group_select?type=diagnosis_by_demographics"]
    ] if Location.current_location.name.match(/Outpatient/i)
    render :layout => false
  end

  def summarised_report
    puts "We are here"
  end

  def data_cleaning_tab
    @reports = [
      ['Missing Prescriptions' , '/cohort_tool/select?report_type=dispensations_without_prescriptions'],
      ['Missing Dispensations' , '/cohort_tool/select?report_type=prescriptions_without_dispensations'],
      ['Multiple Start Reasons' , '/cohort_tool/select?report_type=patients_with_multiple_start_reasons'],
      ['Out of range ARV number' , '/cohort_tool/select?report_type=out_of_range_arv_number'],
      ['Data Consistency Check' , '/cohort_tool/data_consistency_check_menu']
    ]
    render :layout => false
  end

  def properties_tab
    if current_program_location.match(/HIV program/i)
      @settings = [
        ["Set Clinic Days","/properties/clinic_days"],
        ["View Clinic Holidays","/properties/clinic_holidays"],
        ["Ask Pills remaining at home","/properties/creation?value=ask_pills_remaining_at_home"],
        ["Set Clinic Holidays","/properties/set_clinic_holidays"],
        ["Set Site Code", "/properties/site_code"],
        ["Manage Roles", "/properties/set_role_privileges"],
        ["Use Extended Staging Format", "/properties/creation?value=use_extended_staging_format"],
        ["Use User Selected Task(s)", "/properties/creation?value=use_user_selected_activities"],
        ["Use Filing Numbers", "/properties/creation?value=use_filing_numbers"],
        ["Show Lab Results", "/properties/creation?value=show_lab_results"],
        ["Set Appointment Limit", "/properties/set_appointment_limit"]
      ]
    else
      @settings = []
    end
    render :layout => false
  end

  def administration_tab

    role = current_user.user_roles.map{|r|r.role}

    if role.include?("Pharmacist")
      @reports = [['/clinic/management_tab','Drug Management']]
    else
      if create_from_dde_server
        merge_patients_url = '/patients/dde_duplicates'
      else  
        merge_patients_url = '/patients/merge_menu'
      end
      @reports =  [
        ['/clinic/users_tab','User Accounts/Settings'],
        ['/clinic/location_management_tab','Location Management'],
        ['/people/tranfer_patient_in','Transfer Patient in'],
        ['/patients/duplicate_menu','Possible patient duplicates'],
        [merge_patients_url,'Merge Patients']

      ]

      if current_user.admin?
        @reports << ['/clinic/management_tab','Drug Management']
        @reports << ['/clinic/pharmacy_error_correction_menu','Pharmacy Error Correction']
        @reports << ['/clinic/system_configurations','View System Configurations']
      end
    end

    @landing_dashboard = 'clinic_administration'
    render :layout => false
  end

  def pharmacy_error_correction_menu
    @formatted = GenericDrugController.new.preformat_regimen
    @drugs = {}
    @cms_drugs = {}

    (DrugCms.find_by_sql("SELECT * FROM drug_cms") rescue []).each do |drug|
      drug_name = Drug.find(drug.drug_inventory_id).name
      @cms_drugs[drug_name] = drug.name
      @drugs[drug_name] = "#{drug.short_name} #{drug.strength} "
    end

    render :layout => "application"
  end

  def select_pharmacy_obs_date
    @verification_type = params[:verification]
    drug = Drug.find_by_name(params[:drug_name])
    @key_value_data = {}
    @encounter_dates = []

    pharmacy_observations = Pharmacy.find(:all, :conditions => ["drug_id =? AND value_text =?", drug.drug_id,
        params[:verification]], :order => "encounter_date DESC"
    )

    pharmacy_observations.each do |obs|
      encounter_date = obs.encounter_date.to_date.strftime("%d-%b-%Y") rescue obs.encounter_date
      next if obs.value_numeric.to_i == 0
      next if obs.pack_size.to_i == 0
      tins = obs.value_numeric.to_i/obs.pack_size.to_i
      @encounter_dates << ["#{encounter_date} - #{tins} tins", obs.id]
      @key_value_data[obs.id] = tins
    end

    render :layout => "application"
  end

  def update_pharmacy_obs
    pharmacy_obs = Pharmacy.find(params[:pharmacy_obs_id])
    pharmacy_obs.value_numeric = (params[:number_of_tins].to_i * pharmacy_obs.pack_size.to_i)
    pharmacy_obs.save
    redirect_to('/clinic')
  end

  def system_configurations
    @current_location = Location.current_health_center.name
    @cervical_cancer_property = GlobalProperty.find_by_property("activate.cervical.cancer.screening").property_value.to_s == "true"rescue "Not Set"
    @drug_management_property = GlobalProperty.find_by_property("activate.drug.management").property_value.to_s == "true" rescue "Not Set"
    @hypertension_management_property = GlobalProperty.find_by_property("activate.htn.enhancement").property_value.to_s == "true" rescue "Not Set"
    @vl_management_property = GlobalProperty.find_by_property("activate.vl.routine.check").property_value.to_s == "true" rescue "Not Set"
    @ask_pills_property = GlobalProperty.find_by_property("ask.pills.remaining.at.home").property_value.to_s == "true" rescue "Not Set"
    @confirm_before_creating_property = GlobalProperty.find_by_property("confirm.before.creating").property_value.to_s == "true" rescue "Not Set"
    @enter_lab_results_property = GlobalProperty.find_by_property("enter.lab.results").property_value.to_s == "true" rescue "Not Set"

    @export_cohort_data_property = (session["export.cohort.data"].downcase == "yes" rescue 'Not Set')
    @extended_family_panning_property = GlobalProperty.find_by_property("extended.family.planning").property_value.to_s == "true" rescue "Not Set"
    @systollic_blood_pressure_property = CoreService.get_global_property_value("htn.systolic.threshold").to_i
    @diastollic_blood_pressure_property = CoreService.get_global_property_value("htn.diastolic.threshold").to_i

    @htn_screening_age_property = CoreService.get_global_property_value("htn.screening.age.threshold")
    @site_code_property = Location.find(Location.current_health_center.id).neighborhood_cell
    @filing_number_property = CoreService.get_global_property_value("filing.number.limit")
    @appointment_limit_property = GlobalProperty.find_by_property("clinic.appointment.limit").property_value rescue "Not Set"

    @show_lab_results_property = GlobalProperty.find_by_property("show.lab.results").property_value.to_s == "true" rescue "Not Set"
    @extended_staging_property = GlobalProperty.find_by_property("use.extended.staging.questions").property_value.to_s == "true" rescue "Not Set"

    @use_filing_number_property = GlobalProperty.find_by_property("use.filing.numbers").property_value.to_s == "true" rescue false
    @use_user_selected_activities_property = GlobalProperty.find_by_property("use.user.selected.activities").property_value.to_s == "true" rescue "Not Set"

    mailing_members = GlobalProperty.find_by_property("mailing.members").property_value.split(";") rescue []
    @mailing_members = []
    mailing_members.each do |member|
      email_address = member.split(":").last
      @mailing_members << email_address
    end

    @clinic_days = GlobalProperty.find_by_property("clinic.days").property_value.split(",") rescue "Not Set"
    @clinic_holidays = GlobalProperty.find_by_property("clinic.holidays").property_value.split(",").collect{|d|
      d.to_date.strftime("%d-%b-%Y")
    } rescue []
    render :layout => "report"
  end

  def supervision_tab
    @reports = [
      ["Data that was Updated","/cohort_tool/select?report_type=summary_of_records_that_were_updated"],
      ["Drug Adherence Level","/cohort_tool/select?report_type=adherence_histogram_for_all_patients_in_the_quarter"],
      ["Visits by Day", "/cohort_tool/select?report_type=visits_by_day"],
      ["Non-eligible Patients in Cohort", "/cohort_tool/select?report_type=non_eligible_patients_in_cohort"]
    ]
    @landing_dashboard = 'clinic_supervision'
    render :layout => false
  end

  def users_tab
    render :layout => false
  end

  def location_management
    @reports =  [
      ['/location/new?act=create','Add location'],
      ['/location.new?act=delete','Delete location'],
      ['/location/new?act=print','Print location']
    ]
    render :template => 'clinic/location_management', :layout => 'clinic'
  end

  def location_management_tab
    @reports =  [
      ['/location/new?act=print','Print location']
    ]
    if current_user.admin?
      @reports << ['/location/new?act=create','Add location']
      @reports << ['/location/new?act=delete','Delete location']
    end
    render :layout => false
  end

  def management_tab
    #PB - Removed (from warehouse) From Enter Receipts ....and also deactivated reports from this .
    @reports = [
      ["Enter <br /> Receipts","delivery"],
      ["Enter Verified <br /> Physical Stock Count","delivery?id=verification"],
      ["Print<br />Barcode","print_barcode"],
      #["Expiring<br />drugs","date_select"],
      ["Enter Product <br /> Relocation / Disposal","delivery?id=relocation"],
      #["Stock<br />report","date_select"],
      #["Stock <br />Charts","stock_movement_menu?goto=stoke_movement"]
      ["Edit <br /> Product Display Names","capture_cms_drugs"],
      ["HIV Product <br /> Stock Report","drug_stock_report"],
      ["Manage <br /> Drug Sets","new_drug_sets"],
      ["Drug Movement <br /> Report","drug_movement_report_menu"]
    ]
    render :layout => false
  end

  def lab_tab
    #only applicable in the sputum submission area
    enc_date = session[:datetime].to_date rescue Date.today
    @types = ['LAB ORDERS', 'SPUTUM SUBMISSION', 'LAB RESULTS', 'GIVE LAB RESULTS']
    @me = Encounter.statistics(@types, :conditions => ['DATE(encounter_datetime) = ? AND encounter.creator = ?', enc_date, current_user.user_id])
    @today = Encounter.statistics(@types, :conditions => ['DATE(encounter_datetime) = ?', enc_date])
    @user = User.find(current_user.user_id).name rescue ""

    render :template => 'clinic/lab_tab.rhtml' , :layout => false
  end

end
