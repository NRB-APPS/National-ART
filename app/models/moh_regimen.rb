class MohRegimen < ActiveRecord::Base
  set_table_name "moh_regimens"
  set_primary_key "regimen_id"

  has_many :ingredients, :foreign_key => :regimen_id
  has_many :ingredients, :class_name => 'MohRegimenIngredient', :foreign_key => :regimen_id

end
