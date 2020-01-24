def regimens
  regimens = {}
  #regimens["9A"] = [[3, 6, 9523], [6,10, 9523], [10, 14, 9523], [14, 20, 9523], [20, 25, 9523], [25, 200, 9523]]
  regimens["9A"] = [[25, 200, 9523]]
  #regimens["10P"] = [[35, 200, 2992]]
  regimens["10P"] = [[3, 25, 2992]]
  #regimens["11P"] = [[3, 6, 2994], [6,10, 2994], [10, 14, 2994], [14, 20, 2994], [20, 25, 2994], [25, 200, 2994]]
  regimens["11P"] = [[3, 6, 2994], [6,10, 2994], [10, 14, 2994], [14, 20, 2994], [20, 25, 2994]]
  #regimens["11A"] = [[3, 6, 2994], [6,10, 2994], [10, 14, 2994], [14, 20, 2994], [20, 25, 2994], [25, 200, 2994]]
  regimens["11A"] = [[25, 200, 2994]]
  regimens["12A"] = [[35, 200, 9524]]

  ActiveRecord::Base.transaction do
    regimens.sort_by{|k, v|k.to_i}.each do |regimen_index, values|
      values.each do |min_weight, max_weight, concept_id|
        regimen = Regimen.new
        regimen.concept_id = concept_id
        regimen.regimen_index = regimen_index
        regimen.min_weight = min_weight
        regimen.max_weight = max_weight
        regimen.program_id = 1
        regimen.creator = 1
        regimen.date_created = Date.today
        regimen.save
        puts "Added Regimen #{regimen_index}"
      end
    end
  end
  
end

#regimens

def regimen_drug_orders
  regimen_drug_orders = {}
=begin
  regimen_drug_orders["9A"] = {
    969 => [
      [3, 6, 2, "TWICE A DAY (BD)", "1 tab(s) TWICE A DAY (BD)", 1],
      [6, 10, 3, "TWICE A DAY (BD)", "1.5 tab(s) TWICE A DAY (BD)", 1.5],
      [10, 14, 4, "TWICE A DAY (BD)", "2 tab(s) TWICE A DAY (BD)", 2],
      [14, 20, 5, "TWICE A DAY (BD)", "2.5 tab(s) TWICE A DAY (BD)", 2.5],
      [20, 25, 6, "TWICE A DAY (BD)", "3 tab(s) TWICE A DAY (BD)", 3],
      [25, 200, 1, "ONCE A DAY (OD)", "1 tab(s) ONCE A DAY (OD)", 1]
    ],
    73 => [
      [3, 6, 2, "TWICE A DAY (BD)", "1 tab(s) TWICE A DAY (BD)", 1],
      [6, 10, 3, "TWICE A DAY (BD)", "1.5 tab(s) TWICE A DAY (BD)", 1.5],
      [10, 14, 4, "TWICE A DAY (BD)", "2 tab(s) TWICE A DAY (BD)", 2],
      [14, 20, 5, "TWICE A DAY (BD)", "2.5 tab(s) TWICE A DAY (BD)", 2.5],
      [20, 25, 6, "TWICE A DAY (BD)", "3 tab(s) TWICE A DAY (BD)", 3],
      [25, 200, 1, "ONCE A DAY (OD)", "1 tab(s) ONCE A DAY (OD)", 1]
    ]
  }
=end
  regimen_drug_orders["9A"] = {
    969 => [
      [25, 200, 1, "ONCE A DAY (OD)", "1 tab(s) ONCE A DAY (OD)", 1]
    ],
    73 => [
      [25, 200, 1, "ONCE A DAY (OD)", "1 tab(s) ONCE A DAY (OD)", 1]
    ]
  }
=begin
  regimen_drug_orders["10P"] = {
    734 => [
      [35, 200, 1, "ONCE A DAY (OD)", "1 tab(s) ONCE A DAY (OD)", 1]
    ],
    73 => [
      [35, 200, 1, "ONCE A DAY (OD)", "1 tab(s) ONCE A DAY (OD)", 1]
    ]
  }
=end
  regimen_drug_orders["10P"] = {
    734 => [
      [3, 25, 1, "ONCE A DAY (OD)", "1 tab(s) ONCE A DAY (OD)", 1]
    ],
    73 => [
      [3, 25, 1, "ONCE A DAY (OD)", "1 tab(s) ONCE A DAY (OD)", 1]
    ]
  }
=begin
  regimen_drug_orders["11P"] = {
    736 => [
      [3, 6, 2, "TWICE A DAY (BD)", "2 tab(s) TWICE A DAY (BD)", 1],
      [6, 10, 3, "TWICE A DAY (BD)", "1.5 tab(s) TWICE A DAY (BD)", 1.5],
      [10, 14, 4, "TWICE A DAY (BD)", "2 tab(s) TWICE A DAY (BD)", 2],
      [14, 20, 5, "TWICE A DAY (BD)", "2.5 tab(s) TWICE A DAY (BD)", 2.5],
      [20, 25, 6, "TWICE A DAY (BD)", "3 tab(s) TWICE A DAY (BD)", 3],
      [25, 200, 2, "TWICE A DAY (BD)", "2 tab(s) ONCE A DAY (OD)", 1]
    ],
    73 => [
      [3, 6, 2, "TWICE A DAY (BD)", "1 tab(s) TWICE A DAY (BD)", 1],
      [6, 10, 3, "TWICE A DAY (BD)", "1.5 tab(s) TWICE A DAY (BD)", 1.5],
      [10, 14, 4, "TWICE A DAY (BD)", "1 tab(s) TWICE A DAY (BD)", 2],
      [14, 20, 5, "TWICE A DAY (BD)", "2.5 tab(s) TWICE A DAY (BD)", 2.5],
      [20, 25, 6, "TWICE A DAY (BD)", "3 tab(s) TWICE A DAY (BD)", 3],
      [25, 200, 1, "ONCE A DAY (OD)", "1 tab(s) ONCE A DAY (OD)", 1]
    ]
  }
=end
  regimen_drug_orders["11P"] = {
    736 => [
      [3, 6, 2, "TWICE A DAY (BD)", "2 tab(s) TWICE A DAY (BD)", 1],
      [6, 10, 3, "TWICE A DAY (BD)", "1.5 tab(s) TWICE A DAY (BD)", 1.5],
      [10, 14, 4, "TWICE A DAY (BD)", "2 tab(s) TWICE A DAY (BD)", 2],
      [14, 20, 5, "TWICE A DAY (BD)", "2.5 tab(s) TWICE A DAY (BD)", 2.5],
      [20, 25, 6, "TWICE A DAY (BD)", "3 tab(s) TWICE A DAY (BD)", 3]
    ],
    73 => [
      [3, 6, 2, "TWICE A DAY (BD)", "1 tab(s) TWICE A DAY (BD)", 1],
      [6, 10, 3, "TWICE A DAY (BD)", "1.5 tab(s) TWICE A DAY (BD)", 1.5],
      [10, 14, 4, "TWICE A DAY (BD)", "1 tab(s) TWICE A DAY (BD)", 2],
      [14, 20, 5, "TWICE A DAY (BD)", "2.5 tab(s) TWICE A DAY (BD)", 2.5],
      [20, 25, 6, "TWICE A DAY (BD)", "3 tab(s) TWICE A DAY (BD)", 3]
    ]
  }
=begin
  regimen_drug_orders["11A"] = {
    39 => [
      [3, 6, 2, "TWICE A DAY (BD)", "1 tab(s) TWICE A DAY (BD)", 1],
      [6, 10, 3, "TWICE A DAY (BD)", "1.5 tab(s) TWICE A DAY (BD)", 1.5],
      [10, 14, 4, "TWICE A DAY (BD)", "2 tab(s) TWICE A DAY (BD)", 2],
      [14, 20, 5, "TWICE A DAY (BD)", "2.5 tab(s) TWICE A DAY (BD)", 2.5],
      [20, 25, 6, "TWICE A DAY (BD)", "3 tab(s) TWICE A DAY (BD)", 3],
      [25, 200, 2, "TWICE A DAY (BD)", "1 tab(s) TWICE A DAY (BD)", 1]
    ],
    73 => [
      [3, 6, 2, "TWICE A DAY (BD)", "1 tab(s) TWICE A DAY (BD)", 1],
      [6, 10, 3, "TWICE A DAY (BD)", "1.5 tab(s) TWICE A DAY (BD)", 1.5],
      [10, 14, 4, "TWICE A DAY (BD)", "2 tab(s) TWICE A DAY (BD)", 2],
      [14, 20, 5, "TWICE A DAY (BD)", "2.5 tab(s) TWICE A DAY (BD)", 2.5],
      [20, 25, 6, "TWICE A DAY (BD)", "3 tab(s) TWICE A DAY (BD)", 3],
      [25, 200, 1, "ONCE A DAY (OD)", "1 tab(s) ONCE A DAY (OD)", 1]
    ]
  }
=end
  regimen_drug_orders["11A"] = {
    39 => [
      [25, 200, 2, "TWICE A DAY (BD)", "1 tab(s) TWICE A DAY (BD)", 1]
    ],
    73 => [
      [25, 200, 1, "ONCE A DAY (OD)", "1 tab(s) ONCE A DAY (OD)", 1]
    ]
  }
  
  regimen_drug_orders["12A"] = {
    976 => [
      [35, 200, 2, "TWICE A DAY (BD)", "1 tab(s) TWICE A DAY (BD)", 1]
    ],
    977 => [
      [35, 200, 1, "ONCE A DAY (OD)", "1 tab(s) ONCE A DAY (OD)", 1]
    ],
    28 => [
      [35, 200, 1, "ONCE A DAY (OD)", "1 tab(s) ONCE A DAY (OD)", 1]
    ],
    954 => [
      [35, 200, 1, "ONCE A DAY (OD)", "1 tab(s) ONCE A DAY (OD)", 1]
    ]
  }
  
  ActiveRecord::Base.transaction do
    regimen_drug_orders.sort_by{|k, v|k.to_i}.each do |regimen_index, values|
      values.each do |drug_id, regimen_data|
        regimen_data.each do |data|
          min_weight = data[0]
          max_weight = data[1]
          equivalent_daily_dose = data[2]
          frequency = data[3]
          instructions = data[4]
          dose = data[5]
          regimen = Regimen.find(:last, :conditions => ["regimen_index =? AND min_weight =? AND max_weight =?",
              regimen_index, min_weight, max_weight])
          regimen_id = regimen.regimen_id

          regimen_drug_order = RegimenDrugOrder.new
          regimen_drug_order.regimen_id = regimen_id
          regimen_drug_order.drug_inventory_id = drug_id
          regimen_drug_order.dose = dose
          regimen_drug_order.equivalent_daily_dose = equivalent_daily_dose
          regimen_drug_order.units = "tab(s)"
          regimen_drug_order.frequency = frequency
          regimen_drug_order.instructions = instructions
          regimen_drug_order.creator = 1
          regimen_drug_order.date_created = Date.today
          regimen_drug_order.save
        end
      end
    end
  end
  
end

#regimen_drug_orders