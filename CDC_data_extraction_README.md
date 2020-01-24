Instructions on CDC data extraction:
1. git pull
2. change the database.yml to point to the appropriate dataset under production section.
3. load bart2_schema additions.yml
4. on the terminal run this:
   script/runner script/ALL_sites_scripts/cdc_art_data_extraction.rb
5. This will take a while depending on the size of the data. After it has finished it will save a file CDCDataExtraction_name_of_the_facility.txt. For example, if you  are running St_Martins data the name will be CDCDataExtraction_St_Martins.csv
