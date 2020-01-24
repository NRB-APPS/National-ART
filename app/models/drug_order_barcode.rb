class DrugOrderBarcode < ActiveRecord::Base
  set_table_name "drug_order_barcodes"
  set_primary_key "drug_order_barcode_id"
  belongs_to :drug, :foreign_key => "drug_id"

  def self.reset
    barcodes = {}
    barcodes[60] = [22, 968, 39, 736, 731,732,733,969, 74,976,954,977]
    barcodes[30] = [11,932,734,735]
    barcodes[120]  = [978, 73]
    barcodes[90] = [30]
    barcodes[10] = [576,963,297]

    self.delete_all
    barcodes.each do |pills_per_bottle, drug_ids|
      (drug_ids || []).each do |drug_id|
        self.create(:drug_id => drug_id, :tabs => pills_per_bottle)
      end
    end

    return 'Reseted ....'
  end

end
