#!/bin/bash

usage(){
  echo "Usage: $0 ENVIRONMENT SITE"
  echo
  echo "ENVIRONMENT should be: development|test|production"
  echo "Available SITES:"
  ls -1 db/data
}

ENV=$1
SITE=$2

if [ -z "$ENV" ] || [ -z "$SITE" ] ; then
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

echo "DROP DATABASE $DATABASE;" | mysql --host=$HOST --user=$USERNAME --password=$PASSWORD
echo "CREATE DATABASE $DATABASE;" | mysql --host=$HOST --user=$USERNAME --password=$PASSWORD


mysql --host=$HOST --user=$USERNAME --password=$PASSWORD $DATABASE < db/initial_setup/openmrs_1_7_2_concept_server_full_db.sql
#echo "schema additions"
mysql --host=$HOST --user=$USERNAME --password=$PASSWORD $DATABASE < db/initial_setup/schema_bart2_additions.sql
#mysql --host=$HOST --user=$USERNAME --password=$PASSWORD $DATABASE < db/bart2_views_schema_additions.sql
#echo "defaults"
mysql --host=$HOST --user=$USERNAME --password=$PASSWORD $DATABASE < db/initial_setup/defaults.sql
#echo "user schema modifications"
#mysql --host=$HOST --user=$USERNAME --password=$PASSWORD $DATABASE < db/user_schema_modifications.sql
mysql --host=$HOST --user=$USERNAME --password=$PASSWORD $DATABASE < db/initial_setup/malawi_regions.sql
mysql --host=$HOST --user=$USERNAME --password=$PASSWORD $DATABASE < db/initial_setup/mysql_functions.sql
mysql --host=$HOST --user=$USERNAME --password=$PASSWORD $DATABASE < db/initial_setup/drug_ingredient.sql
mysql --host=$HOST --user=$USERNAME --password=$PASSWORD $DATABASE < db/initial_setup/pharmacy.sql
mysql --host=$HOST --user=$USERNAME --password=$PASSWORD $DATABASE < db/initial_setup/national_id.sql
mysql --host=$HOST --user=$USERNAME --password=$PASSWORD $DATABASE < db/initial_setup/weight_for_heights.sql
mysql --host=$HOST --user=$USERNAME --password=$PASSWORD $DATABASE < db/data/${SITE}/${SITE}.sql
mysql --host=$HOST --user=$USERNAME --password=$PASSWORD $DATABASE < db/data/${SITE}/tasks.sql
mysql --host=$HOST --user=$USERNAME --password=$PASSWORD $DATABASE < db/initial_setup/moh_regimens_only.sql
#mysql --host=$HOST --user=$USERNAME --password=$PASSWORD $DATABASE < db/regimen_indexes.sql
mysql --host=$HOST --user=$USERNAME --password=$PASSWORD $DATABASE < db/initial_setup/retrospective_station_entries.sql
mysql --host=$HOST --user=$USERNAME --password=$PASSWORD $DATABASE < db/initial_setup/create_dde_server_connection.sql

#mysql --host=$HOST --user=$USERNAME --password=$PASSWORD $DATABASE < db/privilege.sql
#mysql --host=$HOST --user=$USERNAME --password=$PASSWORD $DATABASE < db/bart2_role_privileges.sql
mysql --host=$HOST --user=$USERNAME --password=$PASSWORD $DATABASE < db/migrate/create_weight_height_for_ages.sql
mysql --host=$HOST --user=$USERNAME --password=$PASSWORD $DATABASE < db/migrate/insert_weight_for_ages.sql
mysql --host=$HOST --user=$USERNAME --password=$PASSWORD $DATABASE < db/openmrs_metadata_1_7.sql
mysql --host=$HOST --user=$USERNAME --password=$PASSWORD $DATABASE < db/initial_setup/regimens.sql

mysql --host=$HOST --user=$USERNAME --password=$PASSWORD $DATABASE < db/initial_setup/modular_tables.sql

#rake openmrs:bootstrap:load:defaults RAILS_ENV=$ENV
#rake openmrs:bootstrap:load:site SITE=$SITE RAILS_ENV=production#

export RAILS_ENV=$ENV

bundle exec rake db:migrate db:seed

mysql --host=$HOST --user=$USERNAME --password=$PASSWORD $DATABASE < db/bart2_views_schema_additions.sql
mysql --host=$HOST --user=$USERNAME --password=$PASSWORD $DATABASE < db/revised_regimens.sql

echo "After completing database setup, you are advised to run the following:"
echo "rake test"
echo "rake cucumber"
