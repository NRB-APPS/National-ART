class DataGeneratorController < ApplicationController 
  
  def patients_without_any_encs
    render :text => DataGeneratorService.list_of_patients_without_any_encounters.to_json and return 
  end

  def normal_visits
  	params[:patient_ids].each do |patient_id|
  		DataGeneratorService.create_normal_visit(patient_id)
  	end
    render :text => true and return 
  end

  def transfer_in_visits
  	params[:patient_ids].each do |patient_id|
  		DataGeneratorService.create_transfer_in_visit(patient_id)
  	end
    render :text => true and return
  end

  def re_initiation_visits
  	params[:patient_ids].each do |patient_id|
  		DataGeneratorService.create_re_initiation_visit(patient_id)
  	end
    render :text => true and return
  end

end
