# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ :name => 'Chicago' }, { :name => 'Copenhagen' }])
#   Major.create(:name => 'Daley', :city => cities.first)

# Validation rules for cohort report
require 'fastercsv'
require 'spreadsheet'
puts "Adding validation rules for cohort reports"
FasterCSV.foreach('db/validation_rules.csv',
  :col_sep => ',', :headers => :first_row) do |row|

  expr = row['expr'] || ''
  desc = row['desc'].to_s
  type_id = row['type_id']
  next if desc.blank?
  check = ValidationRule.find_by_desc(desc)

  if check.blank?
    ValidationRule.create :expr => expr.strip, :desc => desc, :type_id => type_id
  else

  end
end

def load_cms_drugs
  cms_drugs = Spreadsheet.open "#{Rails.root}/script/cms.xls"
  sheet1 = cms_drugs.worksheet 0

  ActiveRecord::Base.transaction do
    sheet1.each 1 do |row|
      drug_name = row[0]
      drug_code = row[1]
      drug_inventory_id = row[2]
      drug_short_name = row[3]
      drug_tabs = row[4]
      weight = row[5]
      strength = row[6]
      puts "#{drug_name} ......... #{drug_inventory_id}"
      pack_size = drug_name.split(/[^\d]/).last rescue nil
      next if drug_inventory_id.blank?
      next if pack_size.blank?
      drug_cms = DrugCms.find(drug_inventory_id) rescue nil
      drug_cms = DrugCms.new if drug_cms.blank?
      drug_cms.drug_inventory_id = drug_inventory_id
      drug_cms.name = drug_name
      drug_cms.short_name = drug_short_name
      drug_cms.tabs = drug_tabs
      drug_cms.code = drug_code
      drug_cms.pack_size = pack_size
      drug_cms.weight = weight
      drug_cms.strength = strength
      drug_cms.save
    end
  end
end

load_cms_drugs
