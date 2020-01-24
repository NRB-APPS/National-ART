User.current = User.find_by_username('admin')
ScriptStarted = Time.now
Source_path = '/home/user/Desktop/Work/Fuchia/msf'
Destination_path = '/home/user/Desktop/Work/Fuchia/msf/'
require 'fastercsv'

def start
  #returns a hash of references
  references = get_references
  person_sql = "INSERT INTO person (person_id, birthdate, birthdate_estimated, dead, gender, death_date, date_created, creator, uuid) VALUES "
  patient_sql = "INSERT INTO patient (patient_id,creator,date_created) VALUES "
  person_name_sql = "INSERT INTO person_name (person_id,middle_name,given_name,family_name,creator,date_created,uuid) VALUES "
  person_address_sql = "INSERT INTO person_address (person_id, city_village, date_created, creator, uuid) VALUES "
  person_attribute_sql = "INSERT INTO person_attribute (person_id, value, date_created, person_attribute_type_id, creator, uuid) VALUES "

  `cd #{Destination_path} && touch person.sql patient.sql person_name.sql person_address.sql person_attribute.sql`
  `echo -n '#{person_sql}' >> #{Destination_path}person.sql`
  `echo -n '#{patient_sql}' >> #{Destination_path}patient.sql`
  `echo -n '#{person_name_sql}' >> #{Destination_path}person_name.sql`
  `echo -n '#{person_address_sql}' >>  #{Destination_path}person_address.sql`
  `echo -n '#{person_attribute_sql}' >> #{Destination_path}person_attribute.sql`

  FasterCSV.foreach("#{Source_path}/TbPatient.csv", :headers => true, :quote_char => '"', :col_sep =>',', :row_sep =>:auto) do |row|
    names = row[9].split(' ')
    given_name = nil ; middle_name = nil ; family_name = nil

    (names || []).each_with_index do |name, i|
      next if name.blank?
      n = name.titleize.squish
      n = n.gsub('*','Unknown')
      given_name = n if i == 0
      if i == 1 and names.length > 2
	middle_name = n
      else
        family_name = n if i == 1
      end
      family_name = n if i == 2
    end

    age_estimate = false
    gender = row[10].squish.to_i rescue 'Unknown'
    date_created = row[1]
    date_created = get_proper_date(date_created)
    date_created = date_created.to_date.strftime("%Y-%m-%d 01:00:00") rescue Date.today.strftime("%Y-%m-%d 01:00:00")
    age_estimate_date_created = row[14]
    date_of_death =get_proper_date(row[21]) unless row[21].blank?
    is_dead = row[20] rescue nil
    city_village = row[3] rescue nil
    occupation = row[4] rescue nil
    age = row[12]
    city_village = references[city_village]
    city_village = "Unknown" if city_village.blank?
    occupation = references[occupation]
    occupation = "Unknown" if occupation.blank?


    if row[11].blank?
      age_estimate = true
      if !age_estimate_date_created.blank? and !age.blank?
        age_estimate_date_created = get_proper_date(age_estimate_date_created)
        dob = Date.new(age_estimate_date_created.to_date.year - age.to_i, 7, 1)
     else
       dob = "1900-01-01"
     end
    else
      dob = get_proper_date(row[11])
    end

    unless gender == 'Unknown'
      gender = gender == 0 ? 'M' : 'F'
    end

    death_date = date_of_death.to_date unless date_of_death.blank?
    gender = gender unless gender == 'Unknown'

    uuid = ActiveRecord::Base.connection.select_one <<EOF
    select uuid();
EOF

  if death_date.blank?
    insert_person = "(#{row[0]}, \"#{dob.to_date}\",#{age_estimate}, #{is_dead}, \"#{gender}\",null,\"#{date_created}\", #{User.current.id}, \"#{uuid.values.first}\"),"
  else
    insert_person = "(#{row[0]}, \"#{dob.to_date}\",#{age_estimate}, #{is_dead},\"#{gender}\",\"#{ date_of_death}\",\"#{date_created}\", #{User.current.id},"
    insert_person += "\"#{uuid.values.first}\"),"
  end

  puts ">>>Person #{row[0]}"
  `echo -n '#{insert_person}' >> #{Destination_path}person.sql`

  insert_patient = "(#{row[0]},#{User.current.id},\"#{date_created}\"),"
  puts ">>>Patient details for #{row[0]}"
  `echo -n '#{insert_patient}' >> #{Destination_path}patient.sql`

  uuid = ActiveRecord::Base.connection.select_one <<EOF
    select uuid();
EOF

    insert_person_name = "(#{row[0]},\"#{middle_name}\",\"#{given_name}\",\"#{family_name}\",#{User.current.id},\"#{date_created}\",\"#{uuid.values.first}\"),"
    puts ">>>Person name for #{row[0]}"
    `echo -n '#{insert_person_name}' >>  #{Destination_path}person_name.sql`

    uuid = ActiveRecord::Base.connection.select_one <<EOF
            select uuid();
EOF
    insert_person_address = "(#{row[0]},\"#{city_village}\", \"#{date_created}\", #{User.current.id}, \"#{uuid.values.first}\"),"
    puts ">>>Person address for #{row[0]}"
    `echo -n '#{insert_person_address}' >> #{Destination_path}person_address.sql`

    uuid = ActiveRecord::Base.connection.select_one <<EOF
        select uuid();
EOF
    attr_type_id = PersonAttributeType.find_by_name("Occupation").id
    insert_person_attr = "(#{row[0]}, \"#{occupation}\", \"#{date_created}\", \"#{attr_type_id}\", #{User.current.id}, \"#{uuid.values.first}\"),"
    puts ">>>Person attributes for #{row[0]}"
    `echo -n '#{insert_person_attr}' >> #{Destination_path}person_attribute.sql`
  end

  puts "...........Please wait..............."
  person_file_content = File.read("#{Destination_path}person.sql")[0...-1]
  File.open("#{Destination_path}person.sql", "w"){|sql| sql.puts person_file_content << ";"}

  patient_file_content = File.read("#{Destination_path}patient.sql")[0...-1]
  File.open("#{Destination_path}patient.sql", "w"){|sql| sql.puts patient_file_content << ";"}

  person_name_file_content = File.read("#{Destination_path}person_name.sql")[0...-1]
  File.open("#{Destination_path}person_name.sql", "w"){|sql| sql.puts person_name_file_content << ";"}

  person_address_file_content = File.read("#{Destination_path}person_address.sql")[0...-1]
  File.open("#{Destination_path}person_address.sql", "w"){|sql| sql.puts person_address_file_content << ";"}

  person_attribute_file_content = File.read("#{Destination_path}person_attribute.sql")[0...-1]
  File.open("#{Destination_path}person_attribute.sql", "w"){|sql| sql.puts person_attribute_file_content << ";"}

  puts "Script time #{ScriptStarted} - #{Time.now}"
end

def get_proper_date (unfomatted_date)
    unfomatted_date = unfomatted_date.split("/")
    year_of_birth = unfomatted_date[2].split(" ")
    year_of_birth = year_of_birth[0]
    current_year = Date.today.year.to_s

    if year_of_birth.to_i > current_year[-2..-1].to_i
      year = "19#{year_of_birth}"
    else
      year = "20#{year_of_birth}"
    end

    fomatted_date = "#{year}-#{unfomatted_date[0]}-#{unfomatted_date[1]}"
end

def generate_date_of_birth(age, date_recorded)
  age = age.to_i
  date_of_birth = date_recorded.to_date - age.year
end

#function that loads csv file data into a hash
def get_references
  references_hash = {}
  FasterCSV.foreach("#{Source_path}/TbReference.csv", :quote_char => '"', :col_sep =>',', :row_sep =>:auto) do |row|
    references_hash[row[0]] = row[6]
  end
  return references_hash
end
start
