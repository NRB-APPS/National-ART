class NotificationTrackerUserActivities < ActiveRecord::Base
  set_table_name "notification_tracker_user_activities"
  set_primary_key "id"

  def self.create_selected_activity(activities)
    self.create(:user_id => User.current.id,
      :selected_activities => activities.join('##'),
      :login_datetime => Time.now())
  end

end
