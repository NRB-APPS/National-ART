=begin
def load_concepts
  encounter_types = ["CERVICAL CANCER SCREENING"]
  concept_names = ["VIA REFERRAL", "VIA Results", "VIA RESULTS AVAILABLE?", "POSITIVE CRYO",
    "CRYO DELAYED DATE", "VIA REFERRAL OUTCOME", "CRYO DONE DATE", "EVER HAD VIA?", "VIA DONE DATE",
    "PATIENT WENT FOR VIA?"
    ]

  encounter_types.each do |encounter_type_name|
    encounter_exists = EncounterType.find_by_name(encounter_type_name)
    next unless encounter_exists.blank?
    puts "Creating Encounter: #{encounter_type_name}"
    encounter_type = EncounterType.new
    encounter_type.name = encounter_type_name
    encounter_type.creator =  1
    encounter_type.date_created = DateTime.now
    encounter_type.save
  end

  concept_names.each do |name|
    cn = ConceptName.find_by_name(name)
    next unless cn.blank?
    ActiveRecord::Base.transaction do
      puts "Creating Concept: #{name}"
      concept = Concept.new
      concept.datatype_id = 4
      concept.class_id = 2
      concept.creator = 1
      concept.save

      concept_name = ConceptName.new
      concept_name.concept_id = concept.concept_id
      concept_name.creator = 1
      concept_name.concept_name_type = 'FULLY_SPECIFIED'
      concept_name.name = name
      concept_name.save
    end
  end

  puts "Done"
end

load_concepts
=end