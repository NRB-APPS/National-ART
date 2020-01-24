require 'rest-client'
class ValidationResult < ActiveRecord::Base
  belongs_to :validation_rule, :foreign_key => "rule_id"

  def self.add_record(data)
  	file = "#{Rails.root}/config/couchdb_config.yml"
  	couchdb_details = YAML.load(File.read(file))
    database = couchdb_details["database"]
    username = couchdb_details["username"]
    password = couchdb_details["password"]
    port = couchdb_details["port"]
    ip_address = couchdb_details["ip_address"]
    #raise "#{Rails.root}"
    `curl -X PUT http://#{username}:#{password}@#{ip_address}:#{port}/#{database}`
    `cd #{Rails.root}/db && curl -X PUT -d @couch_views.js http://#{username}:#{password}@#{ip_address}:#{port}/#{database}/_design/query`

    key = data['rule'].strip.gsub(' ', '_') + "_" + data['date_checked'].to_time.strftime("%Y%m%d")
    info = JSON.parse(`curl -X GET http://#{username}:#{password}@#{ip_address}:#{port}/#{database}/_design/query/_view/by_rule_and_date_checked?key=\\\"#{key}\\\"`)
    uuid = info['rows'].first['id'] rescue nil
    doc = JSON.parse(`curl -X GET http://#{username}:#{password}@#{ip_address}:#{port}/#{database}/#{uuid}`) rescue nil
    #raise doc.to_json
    if !doc['date_checked'].blank?
      doc["failures"] = data['failures']
      RestClient.post("http://#{username}:#{password}@#{ip_address}:#{port}/#{database}", doc.to_json, :content_type => "application/json")
    else
      url = "http://#{username}:#{password}@#{ip_address}:#{port}/#{database}/"
      RestClient.post(url, data.to_json, :content_type => "application/json")
    end
  end
end
