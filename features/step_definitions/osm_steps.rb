Given /^an OSM request to "([^"]*)" will work$/ do |description|
  url = get_osm_url(description)
  FakeWeb.register_uri(:post, "https://www.onlinescoutmanager.co.uk/#{url}", :body => get_osm_body(description)) unless url.nil?
end

Given /^an OSM request to "([^"]*)" will not work$/ do |description|
  url = get_osm_url(description)
  FakeWeb.register_uri(:post, "https://www.onlinescoutmanager.co.uk/#{url}", :body => '{"error":"A simulated OSM API error occured"}') unless url.nil?
end

Given /^"([^"]*)" is connected to OSM$/ do |email|
  user = User.find_by_email_address(email)
  user.osm_userid = 1234
  user.osm_secret = 5678
  user.save!
end

Given /^an OSM request to "([^"]*)" will give (\d+) roles?$/ do |description, roles|
  roles = roles.to_i
  body = '['
  (1..roles).each do |role|
    body += '{"sectionConfig":"{\"subscription_level\":3,\"subscription_expires\":\"2013-01-05\",\"sectionType\":\"cubs\",\"columnNames\":{\"phone1\":\"Home Phone\",\"phone2\":\"Parent 1 Phone\",\"address\":\"Member\'s Address\",\"phone3\":\"Parent 2 Phone\",\"address2\":\"Address 2\",\"phone4\":\"Alternate Contact Phone\",\"subs\":\"Gender\",\"email1\":\"Parent 1 Email\",\"medical\":\"Medical / Dietary\",\"email2\":\"Parent 2 Email\",\"ethnicity\":\"Gift Aid\",\"email3\":\"Member\'s Email\",\"religion\":\"Religion\",\"email4\":\"Email 4\",\"school\":\"School\"},\"numscouts\":10,\"hasUsedBadgeRecords\":true,\"hasProgramme\":true,\"extraRecords\":[{\"name\":\"Subs\",\"extraid\":\"529\"}],\"wizard\":\"false\",\"fields\":{\"email1\":true,\"email2\":true,\"email3\":true,\"email4\":false,\"address\":true,\"address2\":false,\"phone1\":true,\"phone2\":true,\"phone3\":true,\"phone4\":true,\"school\":false,\"religion\":true,\"ethnicity\":true,\"medical\":true,\"patrol\":true,\"subs\":true,\"saved\":true},\"intouch\":{\"address\":true,\"address2\":false,\"email1\":false,\"email2\":false,\"email3\":false,\"email4\":false,\"phone1\":true,\"phone2\":true,\"phone3\":true,\"phone4\":true,\"medical\":false},\"mobFields\":{\"email1\":false,\"email2\":false,\"email3\":false,\"email4\":false,\"address\":true,\"address2\":false,\"phone1\":true,\"phone2\":true,\"phone3\":true,\"phone4\":true,\"school\":false,\"religion\":false,\"ethnicity\":true,\"medical\":true,\"patrol\":true,\"subs\":false}}","groupname":"1st Somewhere","groupid":"1","groupNormalised":"1","sectionid":"' + role.to_s + '","sectionname":"Section ' + role.to_s + '","section":"cubs","isDefault":"' + (role == 1 ? '1' : '0') + '","permissions":{"badge":100,"member":100,"user":100,"register":100,"contact":100,"programme":100,"originator":1,"events":100,"finance":100,"flexi":100}},'
  end
  body[-1] = ']'
  url = get_osm_url(description)
  FakeWeb.register_uri(:post, "https://www.onlinescoutmanager.co.uk/#{url}", :body => body) unless url.nil?
end

Given /^an OSM request to get sections will give (\d+) sections?$/ do |sections|
  url = 'api.php?action=getSectionConfig'

  sections = sections.to_i
  data = {}
  (1..sections).each do |section|
    data[section.to_s] = {
      "subscription_level"=>3, "subscription_expires"=>"2013-01-05", "sectionType"=>"cubs",
      "columnNames"=>{"phone1"=>"Phone 1", "phone2"=>"Phone 2", "address"=>"Address", "phone3"=>"Phone 3", "address2"=>"Address 2", "phone4"=>"Phone 4", "subs"=>"Subs", "email1"=>"Email 1", "medical"=>"Medical / Dietary", "email2"=>"Email 2", "ethnicity"=>"Ethnicity", "email3"=>"Email 3", "religion"=>"Religion", "email4"=>"Email 4", "school"=>"School"},
      "numscouts"=>11, "hasUsedBadgeRecords"=>true, "hasProgramme"=>true,
      "extraRecords"=>[{"name"=>"Extra Record #{section.to_s}", "extraid"=>section.to_s}],
      "wizard"=>"false",
      "fields"=>{"email1"=>true, "email2"=>true, "email3"=>true, "email4"=>false, "address"=>true, "address2"=>false, "phone1"=>true, "phone2"=>true, "phone3"=>true, "phone4"=>true, "school"=>false, "religion"=>true, "ethnicity"=>true, "medical"=>true, "patrol"=>true, "subs"=>true, "saved"=>true},
      "intouch"=>{"address"=>true, "address2"=>false, "email1"=>false, "email2"=>false, "email3"=>false, "email4"=>false, "phone1"=>true, "phone2"=>true, "phone3"=>true, "phone4"=>true, "medical"=>false},
      "mobFields"=>{"email1"=>false, "email2"=>false, "email3"=>false, "email4"=>false, "address"=>true, "address2"=>false, "phone1"=>true, "phone2"=>true, "phone3"=>true, "phone4"=>true, "school"=>false, "religion"=>false, "ethnicity"=>true, "medical"=>true, "patrol"=>true, "subs"=>false}
    }
  end

  FakeWeb.register_uri(:post, "https://www.onlinescoutmanager.co.uk/#{url}", :body => data.to_json)
end


Given /^an OSM request to get_api_access for section "([^"]*)" will have the permissions$/ do |section, table|

  permissions = Array.new
  table.hashes.each do |hash|
     permissions.push [hash['permission'], hash['granted']]
  end

  body = '{"apis":[{"apiid":"' + OSM::API.api_id + '","name":"Test API","permissions":{'
  permissions.each do |permission|
    permission[1] = 0 if permission[1].eql?('none')
    permission[1] = 10 if permission[1].eql?('read')
    permission[1] = 20 if permission[1].eql?('write') || permission[1].eql?('read/write')
    body += "\"#{permission[0]}\":\"#{permission[1]}\","
  end
  body[-1] = '}'
  body += '}]}'

  url = get_osm_url('get_api_access')
  FakeWeb.register_uri(:post, "https://www.onlinescoutmanager.co.uk/#{url}&sectionid=#{section}", :body => body) unless url.nil?
end

Given /^an OSM request to get members for section (\d+) in term (\d+) will have the members$/ do |section_id, term_id, table|
  url = "users.php?action=getUserDetails&sectionid=#{section_id}&termid=#{term_id}"

  members = Array.new
  table.hashes.each do |hash|
     members.push [hash['email1'], hash['email2'], hash['email3'], hash['email4'], hash['grouping_id']]
  end

  body = '{"identifier":"scoutid","items":['
  members.each do |member|
    body += "{\"scoutid\":\"1\",\"sectionid\":\"#{section_id}\",\"type\":\"\",\"firstname\":\"A\",\"lastname\":\"Member\",\"email1\":\"#{member[0]}\",\"email2\":\"#{member[1]}\",\"email3\":\"#{member[2]}\",\"email4\":\"#{member[3]}\",\"phone1\":\"\",\"phone2\":\"\",\"phone3\":\"\",\"phone4\":\"\",\"address\":\"\",\"address2\":\"\",\"dob\":\"2000-01-01\",\"started\":\"2006-01-01\",\"joining_in_yrs\":\"-1\",\"parents\":\"\",\"notes\":\"\",\"medical\":\"\",\"religion\":\"\",\"school\":\"\",\"ethnicity\":\"\",\"subs\":\"Male\",\"patrolid\":\"#{member[4]}\",\"patrolleader\":\"0\",\"joined\":\"2006-01-01\",\"age\":\"6 \\/ 0\",\"yrs\":9,\"patrol\":\"\"},"
  end
  body[-1] = ']'
  body += '}'

  FakeWeb.register_uri(:post, "https://www.onlinescoutmanager.co.uk/#{url}", :body => body)
end

Given /^an OSM request to get events for section (\d+) will have the events$/ do |section_id, table|
  url = "events.php?action=getEvents&sectionid=#{section_id}"

  events = Array.new
  table.hashes.each_with_index do |hash, index|
    event = {
      "eventid" => index.to_s,
      "name" => hash['name'],
      "startdate" => hash['in how many days'].to_i.days.from_now.strftime('%Y-%m-%d'),
      "enddate" => nil,
      "starttime" => "00:00:00",
      "endtime" => "00:00:00",
      "cost" => "0.00",
      "location" => "",
      "notes" => "",
      "sectionid" => section_id,
      "googlecalendar" => nil
    }
    events.push event
  end

  data = {
    "identifier" => "eventid",
    "label" => "name",
    "items" => events
  }

  FakeWeb.register_uri(:post, "https://www.onlinescoutmanager.co.uk/#{url}", :body => data.to_json)
end

Given /^an OSM request to get the register structure for term (\d+) and section (\d+) will cover the last (\d+) weeks$/ do |term_id, section_id, weeks|
  weeks = weeks.to_i
  url = "users.php?action=registerStructure&sectionid=#{section_id}&termid=#{term_id}"

  rows = []
  range = weeks..1
  range.each_with_index do |ago, index|
    date = ago.weeks.ago.strftime('%Y-%m-%d')
    row = {
      "name" => date,
      "field" => date,
      "formatter" => "doneFormatter",
      "width" => "110px",
      "tooltip" => "Programme Item #{index}"
    }
    rows.push row
  end
  
  data = [
    {"rows"=>[{"name"=>"First name","field"=>"firstname","width"=>"100px"},{"name"=>"Last name","field"=>"lastname","width"=>"100px"},{"name"=>"Total","field"=>"total","width"=>"60px"}],"noscroll"=>true},
    {"rows"=>rows}
  ]

  FakeWeb.register_uri(:post, "https://www.onlinescoutmanager.co.uk/#{url}", :body => data.to_json)
end

Given /^an OSM request to get the register for term (\d+) and section (\d+) will have the following members and attendance$/ do |term_id, section_id, table|
  url = "users.php?action=register&sectionid=#{section_id}&termid=#{term_id}"

  rows = []
  table.hashes.each_with_index do |hash, index|
    from_weeks_ago = hash['from weeks ago'].to_i
    to_weeks_ago = hash['to weeks ago'].to_i
    row = {
      'scoutid' => index.to_s,
      'firstname' => hash['name'],
      'lastname' => 'Smith',
      'sectionid' => section_id,
      'patrolid' => '1',
      'total' => from_weeks_ago - to_weeks_ago
    }
    range = from_weeks_ago..to_weeks_ago
    range.each do |ago|
      row[ago.weeks.ago.strftime('%Y-%m-%d')] = '1'
    end
    rows.push row
  end


  
  data = {
    'identifier' => 'scoutid',
    'label' => "name",
    'items' => rows
  }

  FakeWeb.register_uri(:post, "https://www.onlinescoutmanager.co.uk/#{url}", :body => data.to_json)
end

Given /^an OSM request to get due badges for section (\d+) and term (\d+) will result in the following being due their "([^"]*)" badge$/ do |section_id, term_id, badge_name, table|
  url = "challenges.php?action=outstandingBadges&sectionid=#{section_id}&termid=#{term_id}"

  badge_symbol = badge_name.downcase.gsub(/ /, '_')

  members = []
  table.hashes.each_with_index do |hash, index|
    member = {
      'scoutid' => index.to_s,
      'firstname' => hash['name'],
      'lastname' => 'Smith',
      'completed' => hash['completed'],
      'extra' => hash['extra'],
    }
    members.push member
  end
  
  data = {
    'pending' => {badge_symbol=>members},
    'description' => {badge_symbol => {'name'=>badge_name, 'section'=>'section_type', 'type'=>'core','badge'=>badge_symbol}}
  }

  FakeWeb.register_uri(:post, "https://www.onlinescoutmanager.co.uk/#{url}", :body => data.to_json)
end

Given /^an OSM request to get groupings for section (\d+) will have the groupings?$/ do |section_id, table|
  url = "users.php?action=getPatrols&sectionid=#{section_id}"

  groupings = Array.new
  table.hashes.each do |hash|
     groupings.push [hash['grouping_id'], hash['name']]
  end

  body = '{"patrols":['
  groupings.each do |grouping|
    body += "{\"patrolid\":\"#{grouping[0]}\",\"name\":\"#{grouping[1]}\",\"active\":1},"
  end
  body[-1] = ']'
  body += '}'

  FakeWeb.register_uri(:post, "https://www.onlinescoutmanager.co.uk/#{url}", :body => body)
end

Given /^an OSM request to get terms for section (\d+) will have the terms?$/ do |section_id, table|
  url = "api.php?action=getTerms"

  terms = Array.new
  table.hashes.each do |hash|
     terms.push [hash['term_id'], hash['name']]
  end

  body = '{"' + section_id + '":['
  terms.each do |term|
    body += "{\"termid\":\"#{term[0]}\",\"name\":\"#{term[1]}\",\"sectionid\":\"#{section_id}\",\"startdate\":\"#{1.month.ago.to_date.to_s('yyyy-mm-dd')}\",\"enddate\":\"#{1.month.from_now.to_date.to_s('yyyy-mm-dd')}\"},"
  end
  body[-1] = ']'
  body += '}'

  FakeWeb.register_uri(:post, "https://www.onlinescoutmanager.co.uk/#{url}", :body => body)
end

Given /^an OSM request to get programme for section (\d+) term (\d+) will have (\d+) programme items?$/ do |section, term, items|
  url = "programme.php?action=getProgramme&sectionid=#{section}&termid=#{term}"
  items = items.to_i

  item = []
  (1..items).each do |n|
    item.push ({
      'eveningid' => "#{n}",
      'sectionid' => "#{section}",
      'title' => "Weekly Meeting #{n}",
      'notesforparents' => '',
      'games' => '',
      'prenotes' => '',
      'postnotes' => '',
      'leaders' => '',
      'meetingdate' => (Date.today + n.days).strftime ,
      'starttime' => '19:15:00',
      'endtime' => '20:30:00',
      'googlecalendar' => ''
    })
  end
  
  activity = {}
  (1..items).each do |n|
    act = []
    (1..items).each do |m|
      act.push ({
        "activityid" => "#{n}#{m}",
        "title" => "Activity #{n}#{m}",
        "notes" => "",
        "eveningid" => "#{n}"
      })
    end
    activity["#{n}"] = act
  end

  body = {
    'items' => item,
    'activities' => activity
  }

  FakeWeb.register_uri(:post, "https://www.onlinescoutmanager.co.uk/#{url}", :body => body.to_json)
end

Given /^an OSM request to get activity (\d+) will have tags "(.+)"$/ do |activity_id, tags|
  url = "programme.php?action=getActivity&id=#{activity_id}"

  body = {
    'details' => {
      'activityid' => "#{activity_id}",
      'version' => '0',
      'groupid' => '1',
      'userid' => '1',
      'title' => "Activity #{activity_id}",
      'description' => '',
      'resources' => '',
      'instructions' => '',
      'runningtime' => '',
      'location' => 'indoors',
      'shared' => '0',
      'rating' => '0',
      'facebook' => ''
    },
    'editable'=>false,
    'rating'=>'0',
    'used'=>'2',
    'versions' => [
      {
        'value' => '0',
        'userid' => '1',
        'firstname' => 'Alice',
        'label' => 'Current version - Alice',
        'selected' => 'selected'
      }
    ],
    'sections'=> ['beavers', 'cubs', 'scouts', 'explorers'],
    'tags' => tags.split(', ')
  }

  FakeWeb.register_uri(:post, "https://www.onlinescoutmanager.co.uk/#{url}", :body => body.to_json)
end



Then /^"([^"]*)" should be connected to OSM$/ do |email|
  user = User.find_by_email_address(email)
  user.connected_to_osm?.should == true
end

Then /^"([^"]*)" should not be connected to OSM$/ do |email|
  user = User.find_by_email_address(email)
  user.connected_to_osm?.should == false
end


def get_osm_url(description)
  return 'users.php?action=authorise' if description.eql?('authorize')
  return 'api.php?action=getUserRoles' if description.eql?('get roles')
  return 'users.php?action=getAPIAccess' if description.eql?('get_api_access')
  return nil
end

def get_osm_body(description)
  return '{"secret":"abc123","userid":"1234"}' if description.eql?('authorize')
  return nil
end