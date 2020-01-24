class SerializedObject < ActiveRecord::Base
	set_table_name :serialized_object
	set_primary_key :serialized_object_id
	include Openmrs

end
