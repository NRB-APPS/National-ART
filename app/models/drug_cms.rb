class DrugCms < ActiveRecord::Base
  set_table_name :drug_cms
	set_primary_key :drug_inventory_id
  include Openmrs

end
