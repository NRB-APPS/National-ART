class GenericSessionsController < ApplicationController
	skip_before_filter :authenticate_user!, :except => [:location, :update]
	skip_before_filter :location_required

	def new
	end


	def create
		user = User.authenticate(params[:login], params[:password])
		sign_in(:user, user) if user
		authenticate_user! if user

		session[:return_uri] = nil
		session[:datetime] = nil

		if user_signed_in?
			current_user.reset_authentication_token
			#my_token = current_user.authentication_token
			#User.find_for_authentication_token()
			#self.current_user = user
      #if create_from_dde_server
      #dde_authentication_token_result = PatientService.dde_authentication_token
      #dde_token_status = dde_authentication_token_result["status"]
      #if (dde_token_status.to_s == "200")
      #session[:dde_token] = dde_authentication_token_result["data"]["token"]
      #else
      #session[:dde_token] = nil
      #end
      #end

			redirect_to '/clinic'
		else
			note_failed_signin
			@login = params[:login]
			render :action => 'new'
		end
	end

	# Form for entering the location information
	def location
		@login_wards = (CoreService.get_global_property_value('facility.login_wards')).split(',') rescue []
		if (CoreService.get_global_property_value('select_login_location').to_s == "true" rescue false)
			render :template => 'sessions/select_location'
		end
    
    @activate_drug_management = CoreService.get_global_property_value('activate.drug.management').to_s == "true" rescue false
=begin
    if (@activate_drug_management)
      @stock = {}
      drug_names = GenericDrugController.new.preformat_regimen
      drug_names.each do |drug_name|
        drug = Drug.find_by_name(drug_name)
        drug_pack_size = Pharmacy.pack_size(drug.id)
        current_stock = (Pharmacy.latest_drug_stock(drug.id)/drug_pack_size).to_i #In tins
        next unless (current_stock.to_i == 0)
        consumption_rate = Pharmacy.average_drug_consumption(drug.id)
        stock_out_days = ((current_stock * drug_pack_size)/consumption_rate).to_i rescue 0 #To avoid division by zero error when consumption_rate is zero
        estimated_stock_out_date = (Date.today + stock_out_days).strftime('%d-%b-%Y')
        estimated_stock_out_date = "(N/A)" if (consumption_rate.to_i <= 0)
        estimated_stock_out_date = "Stocked out" if (current_stock <= 0) #We don't want to estimate the stock out date if there is no stock available

        @stock[drug.id] = {}
        @stock[drug.id]["drug_name"] = drug.name
        @stock[drug.id]["current_stock"] = current_stock
        @stock[drug.id]["consumption_rate"] = consumption_rate.to_f.round(1)
        @stock[drug.id]["estimated_stock_out_date"] = estimated_stock_out_date
        @stock[drug.id]["drug_pack_size"] = drug_pack_size
      end
      @stock = @stock.sort_by{|drug_id, values|values["drug_name"]}
    end
=end
	end

  def stock_levels_graph
    @current_heath_center_name = Location.current_health_center.name rescue '?'
    @list = {}
=begin
    drug_names = GenericDrugController.new.preformat_regimen
    drug_cms_hash = {}
    DrugCms.all.each do |drug_cms|
      drug_cms_hash[drug_cms.drug_inventory_id] = drug_cms.name
    end
=end
    DrugCms.all.each do |drug_cms|

      drug = Drug.find(drug_cms.drug_inventory_id)
      drug_pack_size = drug_cms.pack_size #Pharmacy.pack_size(drug.id)
      current_stock = (Pharmacy.latest_drug_stock(drug.id)/drug_pack_size).to_i #In tins
      consumption_rate = Pharmacy.average_drug_consumption(drug.id)

      stock_level = current_stock
      disp_rate = ((30 * consumption_rate)/drug_pack_size).to_f #rate is an avg of pills dispensed per day. here we convert it to tins per month
      consumption_rate = ((30 * consumption_rate)/drug_pack_size) #rate is an avg of pills dispensed per day. here we convert it to tins per month

      expected = stock_level.round
      month_of_stock = (expected/consumption_rate) rescue 0
      stocked_out = (disp_rate.to_i != 0 && month_of_stock.to_f.round(3) == 0.00)

      active = (disp_rate.to_i == 0 && stock_level.to_i != 0)? false : true
      drug_cms_name = drug_cms.name
      
      @list[drug_cms_name] = {
        "month_of_stock" => month_of_stock,
        "stock_level" => stock_level,
        "consumption_rate" => (disp_rate.round(2)),
        "stocked_out" => stocked_out,
        "active" => active
      }

    end
    
    @list = @list.sort_by{|k, v|k}

    render :layout => false
  end

  def stock_levels_graph_paeds
    @current_heath_center_name = Location.current_health_center.name rescue '?'
    @list = {}
    paeds_drug_ids = [733, 968, 732, 736, 30, 74, 979, 963, 24]
    paediatric_drugs = DrugCms.find(:all, :conditions => ["drug_inventory_id IN (?)", paeds_drug_ids])
    paediatric_drugs.each do |drug_cms|

      drug = Drug.find(drug_cms.drug_inventory_id)
      drug_pack_size = drug_cms.pack_size #Pharmacy.pack_size(drug.id)
      current_stock = (Pharmacy.latest_drug_stock(drug.id)/drug_pack_size).to_i #In tins
      consumption_rate = Pharmacy.average_drug_consumption(drug.id)

      stock_level = current_stock
      disp_rate = ((30 * consumption_rate)/drug_pack_size).to_f #rate is an avg of pills dispensed per day. here we convert it to tins per month
      consumption_rate = ((30 * consumption_rate)/drug_pack_size) #rate is an avg of pills dispensed per day. here we convert it to tins per month

      expected = stock_level.round
      month_of_stock = (expected/consumption_rate) rescue 0
      stocked_out = (disp_rate.to_i != 0 && month_of_stock.to_f.round(3) == 0.00)

      active = (disp_rate.to_i == 0 && stock_level.to_i != 0)? false : true
      drug_cms_name = drug_cms.name

      stock_expiry_date = Pharmacy.latest_expiry_date_for_drug(drug.id)
      date_diff_in_months = 0
      unless stock_expiry_date.blank? #Date diff in months
        date_diff_in_months = (stock_expiry_date.year * 12 + stock_expiry_date.month) - (Date.today.year * 12 + Date.today.month)
        if (date_diff_in_months > 0 && date_diff_in_months < month_of_stock)
          
        else
          date_diff_in_months = 0
          #raise stock_expiry_date.inspect
        end

      end
      
      date_diff_in_months = 0 if disp_rate.to_i == 0
      month_of_stock = month_of_stock - date_diff_in_months
      
      @list[drug_cms_name] = {
        "month_of_stock" => month_of_stock,
        "stock_level" => stock_level,
        "drug" => drug.id,
        "consumption_rate" => (disp_rate.round(2)),
        "stocked_out" => stocked_out,
        "expiry_stock" => date_diff_in_months,
        "active" => active
      }

    end
    @list = @list.sort_by{|k, v|k}

    render :layout => false
  end

  def stock_levels_graph_adults
    @current_heath_center_name = Location.current_health_center.name rescue '?'
    @list = {}

    adult_drug_ids = [976, 977, 978, 954, 22,969, 731, 39, 11, 735, 734, 932, 73, 576, 297, 931]
    adult_drugs = DrugCms.find(:all, :conditions => ["drug_inventory_id IN (?)", adult_drug_ids])

    adult_drugs.each do |drug_cms|
      drug = Drug.find(drug_cms.drug_inventory_id)
      drug_pack_size = drug_cms.pack_size #Pharmacy.pack_size(drug.id)
      current_stock = (Pharmacy.latest_drug_stock(drug.id)/drug_pack_size).to_i #In tins
      consumption_rate = Pharmacy.average_drug_consumption(drug.id)

      stock_level = current_stock
      disp_rate = ((30 * consumption_rate)/drug_pack_size).to_f #rate is an avg of pills dispensed per day. here we convert it to tins per month
      consumption_rate = ((30 * consumption_rate)/drug_pack_size) #rate is an avg of pills dispensed per day. here we convert it to tins per month

      expected = stock_level.round
      month_of_stock = (expected/consumption_rate) rescue 0
      stocked_out = (disp_rate.to_i != 0 && month_of_stock.to_f.round(3) == 0.00)

      active = (disp_rate.to_i == 0 && stock_level.to_i != 0)? false : true
      drug_cms_name = drug_cms.name

      stock_expiry_date = Pharmacy.latest_expiry_date_for_drug(drug.id)
      date_diff_in_months = 0
      unless stock_expiry_date.blank? #Date diff in months
        date_diff_in_months = (stock_expiry_date.year * 12 + stock_expiry_date.month) - (Date.today.year * 12 + Date.today.month)
        if (date_diff_in_months > 0 && date_diff_in_months < month_of_stock)

        else
          date_diff_in_months = 0
          #raise stock_expiry_date.inspect
        end

      end
      date_diff_in_months = 0 if disp_rate.to_i == 0
      month_of_stock = month_of_stock - date_diff_in_months
      
      @list[drug_cms_name] = {
        "month_of_stock" => month_of_stock,
        "stock_level" => stock_level,
        "drug" => drug.id,
        "consumption_rate" => (disp_rate.round(2)),
        "stocked_out" => stocked_out,
        "expiry_stock" => date_diff_in_months,
        "active" => active
      }

    end
    @list = @list.sort_by{|k, v|k}
    render :layout => false
  end

	# Update the session with the location information
	def update    
		# First try by id, then by name
		location = Location.find(params[:location]) rescue nil
		location ||= Location.find_by_name(params[:location]) rescue nil

		valid_location = (generic_locations.include?(location.name)) rescue false

		unless location and valid_location
			flash[:error] = "Invalid workstation location"

			@login_wards = (CoreService.get_global_property_value('facility.login_wards')).split(',') rescue []
			if (CoreService.get_global_property_value('select_login_location').to_s == "true" rescue false)
				render :template => 'sessions/select_location'
			else
				render :action => 'location'
			end
			return    
		end

		self.current_location = location
		role = current_user.user_roles.map{|r|r.role}

		if use_user_selected_activities and not location.name.match(/Outpatient/i) and not role.include?("Pharmacist")
			redirect_to "/user/programs/#{current_user.id}"
		else
			redirect_to '/clinic'
		end
	end

	def destroy
		sign_out(current_user) if !current_user.blank?
		self.current_location = nil

    portal_status = CoreService.get_global_property_value("portal.status").to_s.squish.upcase rescue ""
    portal_address = CoreService.get_global_property_value("portal.address").to_s rescue ""
    portal_port = CoreService.get_global_property_value("portal.port").to_s rescue ""


    if portal_status == 'ON'
      uri = "http://#{portal_address}:#{portal_port}"
      redirect_to(uri) and return
    else
      flash[:notice] = "You have been logged out."
      redirect_back_or_default('/') and return
    end
		
	end

	protected
  # Track failed login attempts
  def note_failed_signin
    flash[:error] = "Invalid user name or password"
    logger.warn "Failed login for '#{params[:login]}' from #{request.remote_ip} at #{Time.now.utc}"
  end
end
