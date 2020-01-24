class MohRegimenIngredient < ActiveRecord::Base
  set_table_name "moh_regimen_ingredient"
  set_primary_key "ingredient_id"

  belongs_to :regimen, :class_name => 'MohRegimen', :foreign_key => :regimen_id

  def self.get_moh_regimen_ingredient_min_max_weight(index, drug_id)
    i = MohRegimenIngredient.find(:first, :conditions => ["drug_inventory_id = ? AND regimen_id = ?", drug_id, index])
    return [i.min_weight, i.max_weight] #unless i.blank?
  end

end
