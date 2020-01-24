Instructions on DHA data extraction:
1. git pull
2. change the database.yml to point to the appropriate dataset under production section.
3. load bart2_schema additions.yml (the latest one)
4. open  script/ALL_sites_scripts/dha_patient_level_data.rb using your favourite editor and change the following on line 13:
		-  "/home/user/dha_patient_level_data_" + "#{facility_name}" + ".csv" replace the user with the name of your home folder. 
        - for example deliwe is the name of my home folder then the statement will look like: "/home/deliwe/dha_patient_level_data_" + "#{facility_name}" + ".csv"
        - save the file
5. on the terminal run this:
   script/runner script/ALL_sites_scripts/dha_patient_level_data.rb
6. This will take a while depending on the size of the data. After it has finished it will save a file dha_patient_level_data_name_of_the_facility.csv. For example, if you  are running St_Martins data the name will be dha_patient_level_data_St Martin Hospital.csv. This file wil be saved in your home folder, the path you have specified above.
