#!/bin/bash
usage(){
  echo "Usage: $0 ENVIRONMENT"
  echo
  echo "ENVIRONMENT should be: development|production"
} 

ENV=$1

if [ -z "$ENV" ] ; then
  usage
  exit
fi

set -x # turns on stacktrace mode which gives useful debug information

if [ ! -x config/database.yml ] ; then
  cp config/database.yml.example config/database.yml
fi
	
USERNAME=`ruby -ryaml -e "puts YAML::load_file('config/database.yml')['${ENV}']['username']"`
PASSWORD=`ruby -ryaml -e "puts YAML::load_file('config/database.yml')['${ENV}']['password']"`
DATABASE=`ruby -ryaml -e "puts YAML::load_file('config/database.yml')['${ENV}']['database']"`
HOST=`ruby -ryaml -e "puts YAML::load_file('config/database.yml')['${ENV}']['host']"`

now=$(date +"%F %T")
echo "start time : $now"

echo "Regimen Category Fix"
 RAILS_ENV=${ENV} script/runner script/data_cleaning_scripts/regimen_category_fix_in_flat_tables.rb ${ENV}

echo "HIV staging fix"
 RAILS_ENV=${ENV}  script/runner script/data_cleaning_scripts/missing_reason_for_starting_fix.rb ${ENV}

#echo "Pregant status Fix"
# RAILS_ENV=${ENV}
# script/runner script/data_cleaning_scripts/patient_pregnant_fix.rb ${ENV}

#echo "Breastfeeding fix"
# RAILS_ENV=${ENV} script/runner script/data_cleaning_scripts/breastfeeding_fix.rb ${ENV}

echo "Updating flat_tables................"
 RAILS_ENV=${ENV} script/runner script/flat_table_initialization_scripts/flat_tables_updater.rb  ${ENV}

echo "Fixing who_stages_criteria_present in flat_tables"
	RAILS_ENV=${ENV} script/runner script/data_cleaning_scripts/who_stage_criteria_fix.rb  ${ENV}

later=$(date +"%F %T")
echo "start time : $now"
echo "end time : $later"
