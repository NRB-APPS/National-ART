require 'faker'
def start
=begin
  names = PersonName.find_by_sql("SELECT * FROM person_name")

  (names || []).each_with_index do |name, i|
    name.update_attributes(:given_name => Faker::Name.first_name, 
    :family_name => Faker::Name.last_name, 
    :middle_name => Faker::Name.first_name)

    puts ".............. #{i + 1} of #{names.length}"
  end

  names = PersonAddress.find_by_sql("SELECT * FROM person_address")

  (names || []).each_with_index do |name, i|
    name.update_attributes(
    :address1 =>  Faker::Address.city, 
    :address2 => Faker::Address.city, 
    :city_village => Faker::Address.street_address,
    :state_province =>  Faker::Address.city, 
    :postal_code => Faker::Address.zip, 
    :country =>  Faker::Address.city 
    )

    puts ".............. #{i + 1} of #{names.length}"
  end
=end
  names = PatientIdentifier.find_by_sql("SELECT * FROM patient_identifier")

  (names || []).each_with_index do |name, i|
    name.update_attributes(:identifier => Faker::Address.postcode)

    puts ".............. #{i + 1} of #{names.length}"

  end
end

start
