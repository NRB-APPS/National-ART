#!/bin/bash
date "+%H:%M:%S  %d/%m/%y"
#PATH=echo $PATH


cd /var/www/national_art && script/data_consistency_check_runner script/data_consistency_checks.rb
cd config

parse_yaml() {
   local prefix=$2
   local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')
   sed -ne "s|^\($s\)\($w\)$s:$s\"\(.*\)\"$s\$|\1$fs\2$fs\3|p" \
        -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p"  $1 |
   awk -F$fs '{
      indent = length($1)/1;
      vname[indent] = $2;
      for (i in vname) {if (i > indent) {delete vname[i]}}
      if (length($3) > 0) {
         vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
         printf("%s%s%s=\"%s\"\n", "'$prefix'",vn, $2, $3);
      }
   }'
}

eval $(parse_yaml couchdb_config.yml "site_")

source_url=http://$site_username:$site_password@$site_ip_address:$site_port/$site_database
target_url=http://$site_dashboard_username:$site_dashboard_password@$site_dashboard_host:$site_dashboard_port/$site_dashboard_database
curl -X POST  http://$site_ip_address:$site_port/_replicate -d '{"target":"'"$target_url"'","source":"'"$source_url"'", "continuous":true}' -H "Content-Type: application/json"
