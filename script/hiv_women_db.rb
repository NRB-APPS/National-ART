=begin
    Author: mangochiman
    Purpose:
          1. Identify HIV infected women
          2. Delete all data in the system that are not related to HIV infected women.
            2.1 If the HIV infected woman has other programs that re not HIV related, delete them
    Start Date: 19/June/2015
    End Date: ??/June/2015
=end
require('mysql')
def hiv_infected_women
  puts "==========================SCRIPT STARTED============================================="
  username = YAML::load_file('config/database.yml')['development']['username']
  password = YAML::load_file('config/database.yml')['development']['password']
  database = YAML::load_file('config/database.yml')['development']['database']
  host = YAML::load_file('config/database.yml')['development']['host']
  new_db = database.to_s + '_hiv_women_db'
  connection = Mysql.new(host, username, password)
  connection.query("DROP database IF EXISTS #{new_db}")
  connection.query("create database #{new_db}")
  puts "Creating a dump. Please be patient as this may take long depending on your dataset..........."
  `mysqldump -u #{username} -p#{password} --events --routines --triggers #{database} > #{database}_dump.sql`
  puts "Loading Dump. Please be patient as this may take long depending on your dataset............."
  `mysql -u #{username} -p#{password} #{new_db} < #{database}_dump.sql`

  ActiveRecord::Base.establish_connection(
    :adapter  => "mysql",
    :host     => host,
    :username => username,
    :password => password,
    :database => new_db
  )#Creating new connection with the database that has just been_created

  hiv_infected_women_ids = ActiveRecord::Base.connection.select_all(
    "SELECT esd.patient_id FROM earliest_start_date esd INNER JOIN person p ON
      esd.patient_id = p.person_id AND p.gender = 'F'").collect{|i|i["patient_id"]}
  puts "Total HIV Infected women = #{hiv_infected_women_ids.count}"
  hiv_infected_women_ids = ['0'] if hiv_infected_women_ids.blank?

  #patients_to_be_deleted = Patient.find(:all, :conditions => ["patient_id NOT IN (?)",
  #hiv_infected_women_ids])
  patients_to_be_deleted = Patient.find_by_sql("SELECT * FROM patient WHERE patient_id NOT IN (#{hiv_infected_women_ids.join(', ')})")
  puts "Patients to be deleted = #{patients_to_be_deleted.count}"
  ActiveRecord::Base.connection.execute("SET FOREIGN_KEY_CHECKS=0")
  patients_to_be_deleted.each do |patient|
    puts "Deleting Records for patient with ID #{patient.id}"
    ActiveRecord::Base.transaction do
      ActiveRecord::Base.connection.execute("DELETE FROM person_address WHERE person_id=#{patient.id}")
      ActiveRecord::Base.connection.execute("DELETE FROM relationship WHERE person_a=#{patient.id}")
      ActiveRecord::Base.connection.execute("DELETE FROM person_attribute WHERE person_id=#{patient.id}")
      ActiveRecord::Base.connection.execute("DELETE FROM obs WHERE person_id=#{patient.id}")
      ActiveRecord::Base.connection.execute("DELETE FROM person WHERE person_id=#{patient.id}")
      ActiveRecord::Base.connection.execute("DELETE FROM patient WHERE patient_id=#{patient.id}")
      ActiveRecord::Base.connection.execute("
          DELETE pnc FROM person_name_code pnc INNER JOIN person_name pn ON pnc.person_name_id = pn.person_name_id
          WHERE pn.person_id = #{patient.id}
        ")
      ActiveRecord::Base.connection.execute("DELETE FROM person_name WHERE person_id=#{patient.id}")
      ActiveRecord::Base.connection.execute("
          DELETE drug_o FROM drug_order drug_o INNER JOIN orders o ON drug_o.order_id = o.order_id
          INNER JOIN encounter e ON e.encounter_id = o.encounter_id WHERE e.patient_id = #{patient.id}
        ")
      ActiveRecord::Base.connection.execute("
          DELETE o FROM orders o INNER JOIN encounter e ON o.encounter_id = e.encounter_id
          WHERE e.patient_id = #{patient.id}
        ")

      ActiveRecord::Base.connection.execute("
          DELETE FROM orders WHERE patient_id = #{patient.id}
        ")
      ActiveRecord::Base.connection.execute("DELETE FROM encounter WHERE patient_id=#{patient.id}")
      ActiveRecord::Base.connection.execute("
          DELETE ps FROM patient_state ps INNER JOIN patient_program pp ON
          ps.patient_program_id = pp.patient_program_id WHERE pp.patient_id = #{patient.id}
        ")
      ActiveRecord::Base.connection.execute("
          DELETE FROM patient_program WHERE patient_id = #{patient.id}
        ")
      ActiveRecord::Base.connection.execute("
          DELETE FROM patient_identifier WHERE patient_id = #{patient.id}
        ")

      ActiveRecord::Base.connection.execute("
          DELETE FROM relationship WHERE person_a= #{patient.id}
        ")
      
    end
  end

  #Checking and Deleting other non HIV related programs for HIV infected women
  hiv_program_id = Program.find_by_name('HIV PROGRAM').id
  hiv_infected_women_ids.each do |id|
    puts "Checking and deleting NON HIV programs. Patient ID #{id}"
    ActiveRecord::Base.connection.execute("
          DELETE ps FROM patient_state ps INNER JOIN patient_program pp ON
          ps.patient_program_id = pp.patient_program_id WHERE pp.patient_id = #{id} AND
          pp.program_id != #{hiv_program_id}
      ")
    ActiveRecord::Base.connection.execute("
          DELETE FROM patient_program WHERE patient_id = #{id} AND program_id!= #{hiv_program_id}
      ")
  end
  puts "================================DONE====================================================="
end

hiv_infected_women