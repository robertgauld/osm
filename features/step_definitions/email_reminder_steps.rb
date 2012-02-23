Given /^"([^"]*)" has a reminder email for section (\d*) on "([^"]*)"$/ do |email_address, section_id, day|
  day = {
    'Sunday' => 0,
    'Monday' => 1,
    'Tuesday' => 2,
    'Wednesday' => 3,
    'Thursday' => 4,
    'Friday' => 5,
    'Saturday' => 6,
  }[day]
  user = User.find_by_email_address(email_address)
  er = EmailReminder.create :user => user, :send_on => day, :section_id => section_id.to_i
end

Given /^"([^"]*)" has an? (.*) item in (?:her|his|their) "(.*)" email reminder for section (\d*)$/ do |email_address, type, day, section_id|
  section_id = section_id.to_i
  types = {
    'birthday' => EmailReminderItemBirthday,
    'event' => EmailReminderItemEvent,
    'programme' => EmailReminderItemProgramme,
    'not seen' => EmailReminderItemNotSeen,
    'due badge' => EmailReminderItemDueBadge,
  }
  user = User.find_by_email_address(email_address)
  er = nil
  user.email_reminders.each do |reminder|
    if (reminder.section_id == section_id) && %w{Sunday Monday Tuesday Wednesday Thursday Friday Saturday}[reminder.send_on].eql?(day)
      er = reminder
    end
  end
  types[type].create :email_reminder => er
end


When /^"([^"]*)"'s reminder email for section (\d*) on "([^"]*)" is sent$/ do |email_address, section_id, day|
  section_id = section_id.to_i
  user = User.find_by_email_address(email_address)
  user.email_reminders.each do |reminder|
    if (reminder.section_id == section_id) && %w{Sunday Monday Tuesday Wednesday Thursday Friday Saturday}[reminder.send_on].eql?(day)
      reminder.send_email
    end
  end
end


Then /^"([^"]*)" should have (\d+) email reminder$/ do |email_address, count|
  user = User.find_by_email_address(email_address)
  user.email_reminders.count.should == count.to_i
end