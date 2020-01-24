require 'rest-client'
class SendResultsToCouchdb < ActiveRecord::Base
  def self.add_record(data)
  	file = "#{Rails.root}/config/couchdb.yml"
  	couchdb_details = YAML.load(File.read(file))
    database = couchdb_details["source_database"]
    username = couchdb_details["source_username"]
    password = couchdb_details["source_password"]
    port = couchdb_details["source_port"]
    ip_address = couchdb_details["source_address"]

    target_database = couchdb_details["sync_database"]
    target_username = couchdb_details["sync_username"]
    target_password = couchdb_details["sync_password"]
    target_port = couchdb_details["sync_port"]
    target_address = couchdb_details["sync_address"]
    
    doc_type = "StockLevelCouchdb"

    `curl -X PUT http://#{username}:#{password}@#{ip_address}:#{port}/#{database}`
    `cd #{Rails.root}/db && curl -X PUT -d @couch_views.js http://#{username}:#{password}@#{ip_address}:#{port}/#{database}/_design/StockLevelCouchdb`

    key = data[:date].to_date.strftime("%Y/%m/%d")
    info = JSON.parse(`curl -X GET http://#{username}:#{password}@#{ip_address}:#{port}/#{database}/_design/#{doc_type}/_view/by_date?key=\\\"#{key}\\\"`)
    uuid = info['rows'].first['id'] rescue nil
    doc = JSON.parse(`curl -X GET http://#{username}:#{password}@#{ip_address}:#{port}/#{database}/#{uuid}`) rescue nil

    if !doc['date'].blank?
      doc["dispensations"] = data[:dispensations]
      doc["prescriptions"] = data[:prescriptions]
      doc["stock_level"] = data[:stock_level]
      doc["consumption_rate"] = data[:consumption_rate]
      doc["relocations"] = data[:relocations]
      doc["receipts"] = data[:receipts]
      doc["supervision_verification"] = data[:supervision_verification]
      doc["supervision_verification_in_details"] = data[:supervision_verification_in_details]
      doc["type"] = doc_type

      RestClient.post("http://#{username}:#{password}@#{ip_address}:#{port}/#{database}", doc.to_json, :content_type => "application/json")
    else
      url = "http://#{username}:#{password}@#{ip_address}:#{port}/#{database}/"
      data["type"] = doc_type
      RestClient.post(url, data.to_json, :content_type => "application/json")
    end

    `curl -X POST  http://#{ip_address}:#{port}/_replicate -d '{"source":"http://#{username}:#{password}@#{ip_address}:#{port}/#{database}","target":"http://#{target_username}:#{target_password}@#{target_address}:#{target_port}/#{target_database}", "continuous":true}' -H "Content-Type: application/json"`

  end
  
end
