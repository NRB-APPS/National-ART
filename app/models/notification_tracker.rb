class NotificationTracker < ActiveRecord::Base
  set_table_name "notification_tracker"
  set_primary_key "tracker_id"

  belongs_to :user, :foreign_key => :user_id

  def self.create_notification(name, response, patient_id)
    self.create(:notification_name => name,
      :notification_response => response,
      :notification_datetime => Time.now(),
      :patient_id => patient_id,
      :user_id => User.current.id)
  end

end
