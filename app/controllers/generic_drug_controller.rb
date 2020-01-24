class GenericDrugController < ApplicationController

  def name
    drug_list = ['Triomune baby', 'Stavudine', 'Lamivudine', 'Zidovudine', 'and', 'Nevirapine', 'Tenofavir',
      'Atazanavir', 'Ritonavir', 'Abacavir', '(', ')'
    ]
    regimen = Regimen.find(:all, :order => 'regimen_index',
      :conditions => ['program_id = ?', 1],
      :include => :regimen_drug_orders) #.to_yaml
    regimen = regimen.map do |r|
      [r.regimen_drug_orders.map(&:to_s)[0].split(':')[0]]
    end
    @names = []
    regimen.uniq.each { |r|
      drug_list.each { |listed|
        r = r.to_s.gsub(listed.to_s, "")
      }
      @names << r
    }
    other = ["Cotrimoxazole (960mg)", "Cotrimoxazole (480mg tablet)", "INH or H (Isoniazid 300mg tablet)", "INH or H (Isoniazid 100mg tablet)"]
    @names += other
    # regimens = regimens.map{|d|
    # concept_name = (d.concept.concept_names.typed("SHORT").first ||	d.concept.concept_names.typed("FULLY_SPECIFIED").first).name
    # if d.regimen_index.blank?
    #	["#{concept_name}", d.concept_id, d.regimen_index.to_i]
    #	else
    #		["#{d.regimen_index} - #{concept_name}", d.concept_id, d.regimen_index.to_i]
    #	end
    #}.sort_by{| r | r[2]}.uniq

    #@names = Drug.find(:all,:conditions =>["name LIKE ?","%" + params[:search_string] + "%"]).collect{|drug| drug.name}
    render :text => "<li>" + @names.map { |n| n }.join("</li><li>") + "</li>"
  end

  def list_stock
    @drugs = session[:"#{params[:id]}"].sort
    render :layout => 'report'
  end

  def regimen_name_map
    drug_list = ['Triomune baby', 'Stavudine', 'Lamivudine', 'Zidovudine', 'and', 'Nevirapine', 'Tenofavir',
      'Atazanavir', 'Ritonavir', 'Abacavir', '(', ')', 'Lopinavir', 'Efavirenz', 'Isoniazid'
    ]
    more_regimen = ["LPV/r (Lopinavir and Ritonavir syrup)", "LPV/r (Lopinavir and Ritonavir 200/50mg tablet)", "LPV/r (Lopinavir and Ritonavir 100/25mg tablet)", "EFV (Efavirenz 600mg tablet)", "EFV (Efavirenz 200mg tablet)"]
    other = ["Cotrimoxazole (960mg)", "Cotrimoxazole (480mg tablet)", "INH or H (Isoniazid 300mg tablet)", "INH or H (Isoniazid 100mg tablet)"]
    regimen = Regimen.find(:all, :order => 'regimen_index',
      :conditions => ['program_id = ?', 1],
      :include => :regimen_drug_orders) #.to_yaml
    #raise regimen.to_yaml
    regimen = regimen.map do |r|
      if !r.regimen_drug_orders.blank?
        [r.regimen_drug_orders.map(&:to_s)[0].split(':')[0]]
      else
        []
      end
    end

    @names = {}
    regimen.uniq.each { |r|
      fullname = r
      drug_list.each { |listed|
        r = r.to_s.gsub(listed.to_s, "")
      }
      @names["#{fullname}"] = r
    }
    more_regimen.each { |r|
      fullname = r
      drug_list.each { |listed|
        r = r.to_s.gsub(listed.to_s, "")
      }
      @names["#{fullname}"] = r
    }
    other.each { |drug|
      @names[drug] = drug
    }
    return @names

  end

  def add_controllers
    drugs = params[:drug].split(",")
    drugs.each { |drug|
      if drug != ""

      end
    }
  end

  def verified_stock
    @delivery_date = params[:observations].first["value_datetime"]

    @formatted = preformat_regimen
    @drug_short_names = {} #regimen_name_map
    @drug_weights = {}
    @drugs = []
    @drug_cms_names = {}
    @drug_cms_packsizes = {}
    (DrugCms.find_by_sql("SELECT * FROM drug_cms") rescue []).each do |drug|
      drug_name = Drug.find(drug.drug_inventory_id).name
      @drug_cms_names[drug_name] = drug.name
      @drug_cms_packsizes[drug_name] = drug.pack_size
      @drug_short_names[drug_name] = "#{drug.short_name} #{drug.strength} #{drug.tabs}"
      current_stock = Pharmacy.last_physical_count(drug.drug_inventory_id)/drug.pack_size
      @drug_weights[drug.weight] =  [drug.name, drug_name, drug.short_name, drug.tabs, drug.pack_size,
        current_stock, drug.strength]
      @drugs << drug_name
    end

  end

  def set_receipts

    @delivery_date = params[:observations].first["value_datetime"]
    @drugs = params[:drug_name]
    @formatted = preformat_regimen
    @drug_short_names = {} #regimen_name_map
    @drug_cms_names = {}
    @drug_cms_packsizes = {}
    (DrugCms.find_by_sql("SELECT * FROM drug_cms") rescue []).each do |drug|
      drug_name = Drug.find(drug.drug_inventory_id).name
      @drug_cms_names[drug_name] = drug.name
      @drug_cms_packsizes[drug_name] = drug.pack_size
      @drug_short_names[drug_name] = "#{drug.short_name} #{drug.strength} #{drug.tabs}"
    end
    @list = []
    @expiring = {}
    @formatted.each { |drug|
      @drugs.each { |received|
        if drug == received
          @list << drug
          @expiring["#{drug}"] = calculate_dispensed("#{drug}", @delivery_date)
        end
      }
    }

  end

  def pull_receipt_drugs

    data = {}

    Pharmacy.active.find_all_by_value_text(params[:barcode]).each { |entry|

      drug = Drug.find(entry.drug_id).name
      qty_size = entry.pack_size.blank? ? 60 : entry.pack_size.to_i

      data[drug] = {} if data[drug].blank?
      data[drug][qty_size] = {} if data[drug][qty_size].blank?
      data[drug][qty_size]["tins"] = (entry.value_numeric.to_i/qty_size).round
      data[drug][qty_size]["pack_size"] = qty_size
      data[drug][qty_size]["id"] = entry.id
    }

    render :text => data.to_json
  end

  def void

    user_id = current_user.user_id
    delivery = Pharmacy.find(params[:id])
    delivery.voided = 1
    delivery.void_reason = params[:reason]
    delivery.date_voided = (session[:datetime].to_date rescue Date.today)
    delivery.changed_by = user_id
    delivery.save
    render :text => "Done".to_json
  end

  def delivery
    @formatted = preformat_regimen.sort
    @drugs = {} #regimen_name_map
    @cms_drugs = {}

    (DrugCms.find_by_sql("SELECT * FROM drug_cms") rescue []).each do |drug|
      drug_name = Drug.find(drug.drug_inventory_id).name
      @cms_drugs[drug_name] = drug.name
      @drugs[drug_name] = "#{drug.short_name} #{drug.strength} "
    end

    #raise @formatted.to_yaml
  end

  def capture_cms_drugs
    @drugs = preformat_regimen
    @drugs_hash = {}
    @drugs.each do |drug_name|
      drug_id = Drug.find_by_name(drug_name).drug_id
      drug_cms = DrugCms.find(drug_id) rescue nil
      next if drug_cms.blank?
      @drugs_hash[drug_name] = {}
      @drugs_hash[drug_name]["full_name"] =  drug_cms.name
      @drugs_hash[drug_name]["short_name"] = drug_cms.short_name
      @drugs_hash[drug_name]["drug_code"] = drug_cms.code
      @drugs_hash[drug_name]["pack_size"] = drug_cms.pack_size
    end
    #drug_inventory_ids = DrugCms.all.map(&:drug_inventory_id)
    #@drugs.delete_if{|drug_name|drug_inventory_ids.include?(Drug.find_by_name(drug_name).drug_id)}
  end

  def create_cms_drug_packs
    drug_inventory_id = Drug.find_by_name(params[:drug_name]).drug_id
    drug_code = params[:drug_code]
    drug_name = params[:cms_name]
    drug_short_name = params[:cms_short_name]
    pack_size = params[:pack_size].to_i

    drug_cms = DrugCms.find_by_drug_inventory_id(drug_inventory_id)
    drug_cms = DrugCms.new if drug_cms.blank?
    drug_cms.drug_inventory_id = drug_inventory_id
    drug_cms.name = drug_name
    drug_cms.short_name = drug_short_name
    drug_cms.code = drug_code
    drug_cms.pack_size = pack_size
    drug_cms.save
    redirect_to "/clinic" and return
  end

  def drug_stock_report
    @drugs = preformat_regimen
    
    drug_cms_hash = {}
    DrugCms.all.each do |drug_cms|
      drug_cms_hash[drug_cms.drug_inventory_id] = drug_cms.name
    end

    @stock_hash = {}
    @drugs.each do |drug_name|
      drug_id = Drug.find_by_name(drug_name).drug_id
      next if drug_cms_hash[drug_id].blank?
      latest_drug_stock = Pharmacy.latest_drug_stock(drug_id)
      @stock_hash[drug_id] = {}
      drug_cms_name = drug_cms_hash[drug_id]
      @stock_hash[drug_id]["name"] = drug_cms_name
      @stock_hash[drug_id]["latest_drug_stock"] = latest_drug_stock.to_i
    end
    
    @stock_hash = @stock_hash.sort_by{|drug_id, values|values["latest_drug_stock"].to_i}.reverse
  end
  
  def calculate_dispensed(drug_name, delivery_date)

    drug_id = Drug.find_by_name(drug_name).id
    current_stock = Pharmacy.current_stock_as_from(drug_id, Pharmacy.first_delivery_date(drug_id), delivery_date.to_date)

    expiry = 0
    Pharmacy.currently_expiring_drugs(delivery_date.to_date, drug_id).each { |stock|
      #raise stock[1].to_yaml
      expiry += stock[1]["delivered_stock"]

    }
    if current_stock > 0 and current_stock <= expiry
      expiry = current_stock
    elsif current_stock > expiry
      expiry = expiry
    else
      expiry = 0
    end

    return expiry
  end

  def create_stock
    #raise params.to_yaml
    params[:obs].each { |ob_variations|

      drug_id = Drug.find_by_name(ob_variations[0]).id rescue (raise "Missing drug #{ob_variations[0]}".to_s)

      ob_variations[1].each { |delivered|

        delivery_date = params[:delivery_date].to_date
        barcode = params[:identifier]
        drug_short_names = regimen_name_map

        if (drug_comes_in_packs(ob_variations[0], drug_short_names))
          number_of_tins = delivered["amount"].to_f
          number_of_pills_per_tin = delivered["expire_amount"].to_f
        else
          number_of_tins = delivered["expire_amount"].to_f
          number_of_pills_per_tin = delivered["amount"].to_f
        end

        expiry_date = delivered["date"].sub(/^\d+/, "01").to_date.end_of_month rescue
        (raise "Invalid Date #{delivered["date"]}".to_s) rescue Date.today
        number_of_pills = (number_of_tins * number_of_pills_per_tin)
        next if number_of_pills == 0

        Pharmacy.new_delivery(drug_id, number_of_pills, delivery_date, nil, expiry_date, barcode, nil, number_of_pills_per_tin)
      }
    }

    redirect_to "/clinic"
  end

  def edit_stock
    if request.method == :post
      disposal_date = params[:disposal_date].to_date
      params[:obs].each { |ob_variations|
        #drug_id = Drug.find_by_name(ob_variations[0]).id rescue (raise "Missing drug #{ob_variations[0]}".to_s)
        drug = Drug.find_by_name(ob_variations[0])
        ob_variations[1].each { |ob|
          reason = ob[:reason]
          authorisation_code = ob[:authcode]
          #barcode = params[:identifier]
          drug_short_names = regimen_name_map

          if (drug_comes_in_packs(ob_variations[0], drug_short_names))
            number_of_tins = ob["packsize"].to_f
            number_of_pills_per_tin = ob["units"].to_f
          else
            number_of_tins = ob["units"].to_f
            number_of_pills_per_tin = ob["packsize"].to_f
          end

          number_of_pills = (number_of_tins * number_of_pills_per_tin)
          next if number_of_pills == 0
          Pharmacy.alter(drug, number_of_pills, disposal_date, reason, authorisation_code)
        }
      }
      redirect_to "/clinic" # /management"
    else

      @drugs = params[:drug_name]
      @formatted = preformat_regimen
      @drug_short_names = {} #regimen_name_map
      @drug_cms_names = {}

      @drug_cms_packsizes = {}
      (DrugCms.find_by_sql("SELECT * FROM drug_cms") rescue []).each do |drug|
        drug_name = Drug.find(drug.drug_inventory_id).name
        @drug_cms_names[drug_name] = drug.name
        @drug_cms_packsizes[drug_name] = drug.pack_size
        @drug_short_names[drug_name] = "#{drug.short_name} #{drug.strength} #{drug.tabs}"
      end

      if params[:relocation_or_disposal].match(/RELOCATIONS/i)
        @mode = 'RELOCATIONS'
        @relocation_date = params[:relocation_date].to_date
        @relocation_facility = Location.find(params[:relocation_facility]).name
        render :template => "/drug/relocations" and return
      else
        @mode = 'DISPOSAL'
        @disposal_date = params[:disposal_date].to_date
        #@disposal_reason = params[:disposal_reason]
        render :template => "/drug/edit_stock" and return
      end
    end
  end

  def create_relocation
    relocation_date = params[:relocation_date].to_date
    relocation_facility = params[:relocation_facility]
    params[:obs].each { |ob_variations|
      drug = Drug.find_by_name(ob_variations[0]) rescue (raise "Missing drug #{ob_variations[0]}".to_s)

      ob_variations[1].each { |ob|
        reason = ob[:reason]
        authorisation_code = ob[:authcode]
        #barcode = params[:identifier]
        drug_short_names = regimen_name_map

        if (drug_comes_in_packs(ob_variations[0], drug_short_names))
          number_of_tins = ob["packsize"].to_f
          number_of_pills_per_tin = ob["units"].to_f
        else
          number_of_tins = ob["units"].to_f
          number_of_pills_per_tin = ob["packsize"].to_f
        end

        number_of_pills = (number_of_tins * number_of_pills_per_tin)
        next if number_of_pills == 0
        Pharmacy.alter(drug, number_of_pills, relocation_date, 'Relocation', authorisation_code, relocation_facility)
      }
    }
    redirect_to "/clinic"
  end

  def set_quantity

  end

  def verification
    obs = params[:observations]
    edit_reason = obs[0]['value_coded_or_text']
    encounter_datetime = obs[0]['value_datetime']
    drug_id = Drug.find_by_name(params[:drug_name]).id
    pills = (params[:number_of_pills_per_tin].to_i * params[:number_of_tins].to_i)
    date = encounter_datetime || Date.today
    Pharmacy.verified_stock(drug_id, date, pills)
    redirect_to "/clinic" # /management"
  end

  def months_of_stock
    @start_date = params[:start_date].to_date
    @end_date = params[:end_date].to_date

    @month_on_stock = (@end_date.year * 12 + @end_date.month) - (@start_date.year * 12 + @start_date.month)
    @month_on_stock = 1 if @month_on_stock == 0

    @stocks = []
    all_drugs = regimen_name_map
    @formatted = preformat_regimen
    @formatted.each { |drug_id|

      drug = Drug.find_by_name("#{drug_id}")
      expected = (Pharmacy.current_stock_as_from(drug.id, @start_date, @end_date) / 60).round
      confirmed_closing = (Pharmacy.verify_closing_stock_count(drug.id, params[:start_date], params[:end_date]) / 60).round

      dispensed = (Pharmacy.dispensed_drugs_since(drug.id, params[:start_date], params[:end_date]) / 60).round
      consumption = (dispensed.to_i / @month_on_stock) rescue 0
      @months_of_stock = (confirmed_closing.to_i / consumption.to_i) rescue 0
      @months_of_stock = 0 if @months_of_stock.blank?

      @months_of_stock = 9 if @months_of_stock > 9
      drug_name = all_drugs["#{drug.name}"] rescue drug.name
      name = "<span>#{drug_name}  <b>#{expected}</b></span>"
      name = "<span>#{drug_name}  <b>#{expected}  No consumption</b></span>" if @months_of_stock == 0
      @stocks << [name, (@months_of_stock.to_i rescue 0)]
    }

    @stocks = @stocks.to_json
    render :partial => "months_of_stock" and return
  end

  def stoke_movement
    if params[:report_type] != "Stock Movement"
      @drugs = regimen_name_map
    end

    obs = params[:observations]
    #raise obs[1]['value_datetime'].to_yaml
    params[:start_date] = obs[0]['value_datetime']
    params[:end_date] = obs[1]['value_datetime']
    @start_date = params[:start_date].to_date
    @end_date = params[:end_date].to_date

    @month_on_stock = (@end_date.year * 12 + @end_date.month) - (@start_date.year * 12 + @start_date.month)

    @month_on_stock = 1 if @month_on_stock == 0
    if params[:report_type] == "Stock Movement"
      params[:drug_id] = Drug.find_by_name(params[:drug_name]).id
      @drug = Drug.find(params[:drug_id]).name
    end


    render :layout => false
  end

  def get_name
    @drug_short_names = regimen_name_map
    id = params[:value] if !params[:value].blank?
    id = params[:pack_size] if !params[:pack_size].blank?
    id = params[:short] if !params[:short].blank?
    name = @drug_short_names[Drug.find(id).name] rescue Drug.find(id).name
    name = name.gsub("(", "")
    name = name.gsub(")", "")
    splitted = name.split(" ")
    i = 1
    letters = " "
    while (i < splitted.length) do
      if splitted[i].upcase == "ISONIAZID"
        i += 1
        next
      end
      if splitted[i].upcase == "OR" or splitted[i].upcase == "H"
        splitted[0] = "#{splitted[0]} #{splitted[i]}"
      else
        letters = "#{letters} #{splitted[i]}"
      end
      i += 1
    end
    name = splitted[0] if !params[:short].blank?
    name = letters if !params[:pack_size].blank?
    render :text => "#{name}"
  end

  def stock_report
    #raise params.to_yaml
    if params[:type] == 'Supervision' and !params[:type].blank?
      params[:quarter] = params[:quarter1]
    end
    if params[:quarter] != "Select date range" and !params[:quarter].blank?
      @end_date = params[:quarter].split('To')[1].squish.split('/')
      @start_date = params[:quarter].split('To')[0].squish.split('/')
      end_day = @end_date[0]
      end_month = @end_date[1]
      end_year = @end_date[2]
      @end_date = "#{end_year}-#{end_month}-#{end_day}".to_date

      start_day = @start_date[0]
      start_month = @start_date[1]
      start_year = @start_date[2]
      @start_date = "#{start_year}-#{start_month}-#{start_day}".to_date
    end

    @current_location_name = Location.current_health_center.name rescue ''
    if @start_date.blank?
      @start_date = params[:start_date].to_date if not params[:start_date].blank?
      @end_date = params[:end_date].to_date rescue params[:delivery_date].to_date rescue ""
    end

    #TODO
    current_stock = preformat_regimen
    drugs = regimen_name_map
    @drug_array = drugs
    @formatted = current_stock
    encounter_type = PharmacyEncounterType.find_by_name("New deliveries").id
    #new_deliveries = Pharmacy.active.find(:all,
    #  :conditions =>["pharmacy_encounter_type=?",encounter_type],
    #  :order => "encounter_date DESC,date_created DESC")

    new_deliveries = Pharmacy.find_by_sql("
                     SELECT distinct(drug_id) FROM pharmacy_obs")

    type = params[:type]
    if @start_date.blank?

      encounter_type = PharmacyEncounterType.find_by_name('Tins currently in stock').id
      @start_date = Pharmacy.find_by_sql("SELECT * FROM pharmacy_obs
                                     WHERE pharmacy_encounter_type = #{encounter_type}
                                     AND DATE(encounter_date) <= '#{@end_date}' AND vaue_text = '#{type}'
        ").first.encounter_date rescue []
      if @start_date.blank?
        @start_date = @end_date - 3.months
        @start_date = @start_date.beginning_of_month
      end
    end
    @days = @end_date - @start_date

    @month_on_stock = (@end_date.year * 12 + @end_date.month) - (@start_date.year * 12 + @start_date.month)

    @month_on_stock = 1 if @month_on_stock == 0

    #current_stock = {}
    new_deliveries.each { |delivery|
      current_stock[delivery.drug_id] = delivery if current_stock[delivery.drug_id].blank?
    }

    @stock = {}
    encounter_type_id = PharmacyEncounterType.find_by_name('Tins currently in stock').id
    current_stock.each { |delivery|
      drug = Drug.find_by_name("#{delivery}")
      first_date = Pharmacy.active.find(:first, :conditions => ["drug_id =?",
          drug.id], :order => "encounter_date").encounter_date.to_date rescue nil
      next if first_date.blank?
      next if first_date > @end_date

      start_date = @start_date
      end_date = @end_date

      # drug = Drug.find(delivery.drug_id)

      drug_name = drugs["#{drug.name}"]
      if drug_name.blank?
        drug_name = drug.name
      end

      obs = Pharmacy.active.find(:first,
        :conditions => ["pharmacy_encounter_type = ? AND  encounter_date > ? AND encounter_date <= ?
                        AND drug_id = ? AND value_text = '#{type}'",
          encounter_type_id, @start_date, @end_date, drug.id],
        :order => 'encounter_date DESC,date_created DESC') #.id rescue 0
      end_pharmacy_id = obs.id rescue 0
      expiring_units = obs.expiring_units rescue "Not <br>Available"
      expiry_date = obs.expiry_date rescue "Not <>"
      start_pharmacy_id = Pharmacy.active.find(:first,
        :conditions => ["pharmacy_encounter_type = ? AND encounter_date <= ? AND drug_id = ? AND value_text = 'Supervision'",
          encounter_type_id, start_date, drug.id],
        :order => 'encounter_date DESC,date_created DESC').id rescue 0

      #Pharmacy.verify_stock_count(drug.id,start_date,end_date)
      @stock[drug_name] = {"confirmed_closing" => 0, "dispensed" => 0, "current_stock" => 0,
        "confirmed_opening" => 0, "start_date" => start_date, "end_date" => end_date,
        "relocated" => 0, "receipts" => 0, "expected" => 0, "drug_id" => drug.id}
      @stock[drug_name]["dispensed"] = Pharmacy.dispensed_drugs_since(drug.id, start_date, end_date)
      @stock[drug_name]["confirmed_opening"] = Pharmacy.verify_stock_count(drug.id, start_date, start_date, type)
      @stock[drug_name]["confirmed_closing"] = Pharmacy.verify_closing_stock_count(drug.id, start_date, end_date, type)
      @stock[drug_name]["current_stock"] = Pharmacy.current_stock_as_from(drug.id, start_date, end_date)
      @stock[drug_name]["relocated"] = Pharmacy.relocated(drug.id, start_date, end_date)
      @stock[drug_name]["receipts"] = Pharmacy.receipts(drug.id, start_date, end_date)
      @stock[drug_name]["expected"] = Pharmacy.expected(drug.id, start_date, end_date)
      @stock[drug_name]["end_pharmacy_id"] = end_pharmacy_id
      @stock[drug_name]["start_pharmacy_id"] = start_pharmacy_id
      @stock[drug_name]["expiring_units"] = expiring_units
    }

    #@stock.sort{|a,b| (a[0] == b[0]) ? a[1] <=> b[1] : a[0] <=> b[0] }
  end

  def current_stock
    drug = Drug.find_by_name(params[:drug])
    start_date = Date.today
    end_date = start_date + 30.days
    expected = Pharmacy.expected(drug.id, start_date, end_date)
    render :text => (expected.to_json)
  end

  def stock_chart
    encounter_type = PharmacyEncounterType.find_by_name("Tins currently in stock").id
    #new_deliveries = Pharmacy.active.find(:first,
    # :conditions =>["pharmacy_encounter_type=? AND drug_id =? AND encounter_date >= ? AND encounter_date <= ?",encounter_type, params[:drug_id], params[:start_date], params[:end_date] ],
    #  :order => "encounter_date DESC,date_created DESC")

    @stocks = []
    current_stock = {}
    @start_year = params[:start_date].to_date.year
    @start_month = params[:start_date].to_date.month
    @start_day = params[:start_date].to_date.day

    @end_year = params[:end_date].to_date.year
    @end_month = params[:end_date].to_date.month
    @end_day = params[:end_date].to_date.day

    start_date = params[:start_date].to_date.strftime('%Y-%m-%d 00:00:00')
    end_date = params[:end_date].to_date.strftime('%Y-%m-%d 23:59:59')

    dates = DrugOrder.find_by_sql("
                      SELECT DISTINCT(DATE(start_date)) AS startdate FROM drug_order
                      INNER JOIN orders o USING(order_id)
                      WHERE drug_inventory_id = #{params[:drug_id]}
                      AND DATE(start_date) >= '#{start_date}'
                      AND DATE(start_date) <= '#{end_date}'")

    dates.each { |date|
      new_deliveries = Pharmacy.expected(params[:drug_id], params[:start_date], date.startdate)
      current_stock[date.startdate] = (new_deliveries / 60).round
    }
    @name = regimen_name_map[Drug.find(params[:drug_id]).name]

    (current_stock || {}).sort { |a, b| a[0].to_date <=> b[0].to_date }.each do |date, weight|
      @stocks << [date.to_date, weight]
    end

    redirect_to "/drug/stock_movement_menu" and return if @stocks.blank?
    @stocks = @stocks.sort_by { |atr| atr[0] }.to_json

    render :partial => "stoke_chart" and return
  end

  def preformat_regimen

    formatted = []
    (DrugCms.find_by_sql("SELECT name, drug_inventory_id FROM drug_cms") rescue []).each do |drug|
      formatted << Drug.find(drug.drug_inventory_id).name
    end

    return formatted
  end

  def date_select
    encounter_type = PharmacyEncounterType.find_by_name("Tins currently in stock").id
    @supervision_dates = []
    tracker = []
    Pharmacy.find_by_sql("
                      SELECT distinct(encounter_date) FROM pharmacy_obs WHERE pharmacy_encounter_type = #{encounter_type} AND encounter_date <= '#{Date.today}'
                     AND value_text = 'Supervision' ORDER BY encounter_date DESC").each { |encounter_dates|

      if tracker.length < 1
        tracker << encounter_dates.encounter_date
        next
      end
      @supervision_dates << "#{encounter_dates.encounter_date.to_date.strftime('%d/%m/%Y')} To #{tracker.last.to_date.strftime('%d/%m/%Y')}"
      tracker << encounter_dates.encounter_date
    }
    tracker = []
    @clinic_dates = []
    Pharmacy.find_by_sql("
                      SELECT distinct(encounter_date) FROM pharmacy_obs WHERE pharmacy_encounter_type = #{encounter_type} AND encounter_date <= '#{Date.today}'
                     AND UCASE(value_text) = 'CLINIC' ORDER BY encounter_date DESC").each { |encounter_dates|

      if tracker.length < 1
        tracker << encounter_dates.encounter_date
        next
      end
      @clinic_dates << "#{encounter_dates.encounter_date.to_date.strftime('%d/%m/%Y')} To #{tracker.last.to_date.strftime('%d/%m/%Y')}"
      tracker << encounter_dates.encounter_date
    }
    #raise @clinic_dates.to_yaml
    @goto = params[:goto]
    @goto = 'stock_report' if @goto.blank?
    @drugs = Regimen.find_by_sql(
      "select distinct(d.name) from regimen r
    inner join regimen_drug_order rd on rd.regimen_id = r.regimen_id
    inner join drug d on d.drug_id = rd.drug_inventory_id
    where r.regimen_index is not null
    and r.regimen_index != 0
      ").collect { |drug| drug.name }.compact.sort.uniq rescue []
    other = ["Cotrimoxazole (960mg)", "Cotrimoxazole (480mg tablet)", "INH or H (Isoniazid 300mg tablet)", "INH or H (Isoniazid 100mg tablet)"]
    @drugs += other
  end

  def stock_movement_menu
    @formatted = preformat_regimen
    @names = regimen_name_map
  end

  def print_barcode
    if request.post?
      print_and_redirect("/drug/print?drug_id=#{params[:drug_id]}&quantity=#{params[:pill_count]}", "/drug/print_barcode")
    else
      @drugs = Drug.find(:all, :conditions => ["name IS NOT NULL"])
    end
  end

  def print
    pill_count = params[:quantity]
    drug = Drug.find(params[:drug_id])
    drug_name = drug.name
    drug_name1=""
    drug_name2=""
    drug_quantity = pill_count
    drug_barcode = "#{drug.id}-#{drug_quantity}"
    drug_string_length =drug_name.length

    if drug_name.length > 27
      drug_name1 = drug_name[0..25]
      drug_name2 = drug_name[26..-1]
    end

    if drug_string_length <= 27
      label = ZebraPrinter::StandardLabel.new
      label.draw_text("#{drug_name}", 40, 30, 0, 2, 2, 2, false)
      label.draw_text("Quantity: #{drug_quantity}", 40, 80, 0, 2, 2, 2, false)
      label.draw_barcode(40, 130, 0, 1, 5, 15, 120, true, "#{drug_barcode}")
    else
      label = ZebraPrinter::StandardLabel.new
      label.draw_text("#{drug_name1}", 40, 30, 0, 2, 2, 2, false)
      label.draw_text("#{drug_name2}", 40, 80, 0, 2, 2, 2, false)
      label.draw_text("Quantity: #{drug_quantity}", 40, 130, 0, 2, 2, 2, false)
      label.draw_barcode(40, 180, 0, 1, 5, 15, 100, true, "#{drug_barcode}")
    end

    create_drug_tins(params[:drug_id], params[:quantity])
    send_data(label.print(1), :type => "application/label; charset=utf-8", :stream => false, :filename => "#{drug_barcode}.lbl", :disposition => "inline")

  end

  def create_drug_tins(drug_id, pill_count)
    drug_order_barcode = DrugOrderBarcode.find(:first, :conditions => ["drug_id =? AND tabs =?",
        drug_id, pill_count])
    DrugOrderBarcode.create(
      :drug_id => drug_id,
      :tabs => pill_count
    ) if drug_order_barcode.blank? #We don't want to create duplicates of drug vs tins

  end

  def expiring
    @logo = CoreService.get_global_property_value('logo') rescue ''
    @start_date = params[:start_date].to_date
    @end_date = params[:end_date].to_date
    @expiring_drugs = Pharmacy.expiring_drugs(@start_date, @end_date)
    render :layout => "menu"
  end

  def removed_from_shelves
    @start_date = params[:start_date].to_date
    @end_date = params[:end_date].to_date
    @drugs_removed = Pharmacy.removed_from_shelves(@start_date, @end_date)
    render :layout => "menu"
  end

  def available_name
    ids = Pharmacy.active.find(:all).collect { |p| p.drug_id } rescue []
    @names = Drug.find(:all, :conditions => ["name LIKE ? AND drug_id IN (?)", "%" +
          params[:search_string] + "%", ids]).collect { |drug| drug.name }
    render :text => "<li>" + @names.map { |n| n }.join("</li><li>") + "</li>"
  end

  def drug_comes_in_packs(drug, drug_short_names)

    name = drug_short_names[drug]
    name = name.gsub("(", "") rescue ""
    name = name.gsub(")", "") rescue ""
    splitted = name.split(" ") rescue ""
    i = 1
    while (i < splitted.length) do
      if splitted[i].upcase == "ISONIAZID"
        i += 1; next
      end

      if splitted[i].upcase == "OR" or splitted[i].upcase == "H"
        splitted[0] = "#{splitted[0]} #{splitted[i]}"
      end

      i += 1
    end

    return (splitted[0] == 'INH or H' || splitted[0] == 'Cotrimoxazole') ? true : false
  end

  def stock_report_edit

    if request.post?

      drug_short_names = regimen_name_map
      unless params[:obs].blank?
        params[:obs].each { |obs|
          drug_id = Drug.find_by_name(obs[0]).id rescue []
          next if drug_id.blank?
          tins = obs[1]["amount"].to_i
          pack_size = 60
          pack_size = obs[1]['pills_per_tin'].to_i if  ((obs[1]['pills_per_tin'].present?) rescue false)

          expiring_units = obs[1]['expire_amount']
          expiry_date = nil

          expiring_units = nil if (tins == 0)
          expiry_date = nil if (tins == 0)

          if tins != 0
            expiry_date = obs[1]['date'].to_date.end_of_month
          end

          if tins.to_i == 0 && expiring_units.to_i == 0
            pack_size = nil
          end

          pills = tins * pack_size rescue nil

          Pharmacy.verified_stock(drug_id, params[:delivery_date], pills, expiry_date, expiring_units, params[:type], pack_size)

        }

      else
        obs = params[:observations]
        edit_reason = obs[0]['value_coded_or_text'] rescue nil
        encounter_datetime = params[:encounter_date]
        drug_id = params[:drug_id]
        pills = (params[:number_of_pills_per_tin].to_i * params[:number_of_tins].to_i)
        date = encounter_datetime || Date.today

        unless edit_reason.blank?
          Pharmacy.drug_dispensed_stock_adjustment(drug_id, pills, date, edit_reason)
        else

          pharmacy = Pharmacy.find(drug_id)
          pharmacy.value_numeric = pills
          pharmacy.save!

        end
      end
      redirect_to '/'
    else
      @edit_reason = params[:edit_reason]
      @drug_id = params[:drug_id]
      @encounter_date = params[:date]
      @max_date = params[:max_date]
      @start_date = params[:start_date]
      @end_date = params[:end_date]
    end
  end

  def drug_movement_report_menu
    @drugs = []
    drugs = preformat_regimen
    drugs.each do |drug_name|
      drug_id = Drug.find_by_name(drug_name).drug_id
      drug_cms = DrugCms.find(drug_id) rescue nil
      next if drug_cms.blank?
      @drugs << [drug_name, drug_id]
    end
    @drugs = @drugs.sort_by{|k, v|k}
  end

  def process_drug_movement_report
    start_year = params[:start_year]
    start_month = params[:start_month]
    start_day = params[:start_day]
    end_year = params[:end_year]
    end_month = params[:end_month]
    end_day = params[:end_day]
    drug_id = params[:drug_id]
    
    start_date = (start_year + "-" + start_month + "-" + start_day).to_date
    end_date = (end_year + "-" + end_month + "-" + end_day).to_date
    packsize = Pharmacy.pack_size(drug_id)
    @drug_name = Drug.find(drug_id).name

    @stocks = {}
    ((start_date..end_date).to_a).each do |date|
      stock_level = (Pharmacy.drug_stock_on(drug_id, date)/packsize).round rescue 0
      @stocks[date]= {"stock_count" => stock_level,"pack_size" => packsize}
    end
    
    render :layout => "report"
  end
  
end
