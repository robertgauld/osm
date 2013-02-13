# encoding: utf-8
require 'spec_helper'
require 'date'

describe "Event" do

  it "Create Event" do
    data = {
      :id => 1,
      :section_id => 2,
      :name => 'Event name',
      :start => DateTime.new(2001, 1, 2, 12 ,0 ,0),
      :finish => nil,
      :cost => 'Free',
      :location => 'Somewhere',
      :notes => 'None',
      :archived => '0',
      :columns => [],
      :notepad => 'notepad',
      :public_notepad => 'public notepad',
      :confirm_by_date => Date.new(2002, 1, 2),
      :allow_changes => true,
      :reminders => false,
      :attendance_limit => 3,
      :attendance_limit_includes_leaders => true,
    }
    event = Osm::Event.new(data)

    event.id.should == 1
    event.section_id.should == 2
    event.name.should == 'Event name'
    event.start.should == DateTime.new(2001, 1, 2, 12, 0, 0)
    event.finish.should == nil
    event.cost.should == 'Free'
    event.location.should == 'Somewhere'
    event.notes.should == 'None'
    event.archived.should be_false
    event.columns.should == []
    event.notepad.should == 'notepad'
    event.public_notepad.should == 'public notepad'
    event.confirm_by_date.should == Date.new(2002, 1, 2)
    event.allow_changes.should == true
    event.reminders.should == false
    event.attendance_limit.should == 3
    event.attendance_limit_includes_leaders.should == true
    event.valid?.should be_true
  end

  it "Correctly tells if attendance is limited" do
    Osm::Event.new(:attendance_limit => 0).limited_attendance?.should be_false
    Osm::Event.new(:attendance_limit => 1).limited_attendance?.should be_true
  end


  it "Create Event::Attendance" do
    data = {
      :member_id => 1,
      :grouping_id => 2,
      :row => 3,
      :columns => [],
      :event => Osm::Event.new(:id => 1, :section_id => 1, :name => 'Name', :columns => [])
    }

    ea = Osm::Event::Attendance.new(data)  
    ea.member_id.should == 1
    ea.grouping_id.should == 2
    ea.fields.should == {}
    ea.row.should == 3
    ea.valid?.should be_true
  end


  describe "Using the API" do

    before :each do
      events_body = {
        'identifier' => 'eventid',
        'label' => 'name',
        'items' => [{
          'eventid' => '2',
          'name' => 'An Event',
          'startdate' => '2001-02-03',
          'enddate' => '2001-02-05',
          'starttime' => '00:00:00',
          'endtime' => '12:00:00',
          'cost' => '0.00',
          'location' => 'Somewhere',
          'notes' => 'Notes',
          'sectionid' => 1,
          'googlecalendar' => nil,
          'archived' => '0',
          'confdate' => nil,
          'allowchanges' => '1',
          'disablereminders' => '1',
          'attendancelimit' => '3',
          'limitincludesleaders' => '1',
        }]
      }

      event_body = {
        'eventid' => '2',
        'name' => 'An Event',
        'startdate' => '2001-01-02',
        'enddate' => '2001-02-05',
        'starttime' => '00:00:00',
        'endtime' => '12:00:00',
        'cost' => '0.00',
        'location' => 'Somewhere',
        'notes' => 'Notes',
        'notepad' => 'notepad',
        'publicnotes' => 'public notepad',
        'config' => '[{"id":"f_1","name":"Name","pL":"Label"}]',
        'sectionid' => '1',
        'googlecalendar' => nil,
        'archived' => '0',
        'confdate' => '2002-01-02',
        'allowchanges' => '1',
        'disablereminders' => '1',
        'pnnotepad' => '',
        'structure' => [],
        'attendancelimit' => '3',
        'limitincludesleaders' => '1',
      }

      FakeWeb.register_uri(:post, "https://www.onlinescoutmanager.co.uk/events.php?action=getEvents&sectionid=1&showArchived=true", :body => events_body.to_json)
      FakeWeb.register_uri(:post, "https://www.onlinescoutmanager.co.uk/events.php?action=getEvent&sectionid=1&eventid=2", :body => event_body.to_json)

      Osm::Model.stub(:get_user_permissions) { {:events => [:read, :write]} }
    end

    it "Get events for section" do
      events = Osm::Event.get_for_section(@api, 1)
      events.size.should == 1
      event = events[0]
      event.id.should == 2
      event.section_id.should == 1
      event.name.should == 'An Event'
      event.start.should == Date.new(2001, 1, 2)
      event.finish.should == DateTime.new(2001, 2, 5, 12, 0, 0)
      event.cost.should == '0.00'
      event.location.should == 'Somewhere'
      event.notes.should == 'Notes'
      event.archived.should be_false
      event.notepad.should == 'notepad'
      event.public_notepad.should == 'public notepad'
      event.confirm_by_date.should == Date.new(2002, 1, 2)
      event.allow_changes.should == true
      event.reminders.should == false
      event.attendance_limit.should == 3
      event.attendance_limit_includes_leaders.should == true
      event.columns[0].id.should == 'f_1'
      event.columns[0].name.should == 'Name'
      event.columns[0].label.should == 'Label'
      event.valid?.should be_true
    end

    it "Fetch events for a section honoring archived option" do
      body = {
        'identifier' => 'eventid',
        'label' => 'name',
        'items' => [{
          'eventid' => '1',
          'name' => 'An Event',
          'startdate' => '2001-02-03',
          'enddate' => nil,
          'starttime' => '00:00:00',
          'endtime' => '00:00:00',
          'cost' => '0.00',
          'location' => '',
          'notes' => '',
          'sectionid' => 1,
          'googlecalendar' => nil,
          'archived' => '0'
        },{
          'eventid' => '2',
          'name' => 'An Archived Event',
          'startdate' => '2001-02-03',
          'enddate' => nil,
          'starttime' => '00:00:00',
          'endtime' => '00:00:00',
          'cost' => '0.00',
          'location' => '',
          'notes' => '',
          'sectionid' => 1,
          'googlecalendar' => nil,
          'archived' => '1'
        }]
      }

      FakeWeb.register_uri(:post, "https://www.onlinescoutmanager.co.uk/events.php?action=getEvents&sectionid=1&showArchived=true", :body => body.to_json)
      FakeWeb.register_uri(:post, "https://www.onlinescoutmanager.co.uk/events.php?action=getEvent&sectionid=1&eventid=1", :body => {'config' => '[]', 'archived' => '0', 'eventid' => '1'}.to_json)
      FakeWeb.register_uri(:post, "https://www.onlinescoutmanager.co.uk/events.php?action=getEvent&sectionid=1&eventid=2", :body => {'config' => '[]', 'archived' => '1', 'eventid' => '2'}.to_json)

      events = Osm::Event.get_for_section(@api, 1)
      all_events = Osm::Event.get_for_section(@api, 1, {:include_archived => true})

      events.size.should == 1
      events[0].id == 1
      all_events.size.should == 2
    end

    it "Get event" do
      event = Osm::Event.get(@api, 1, 2)
      event.should_not be_nil
      event.id.should == 2
    end

    describe "Tells if there are spaces" do

      it "No limit" do
        event = Osm::Event.new(:attendance_limit => 0, :id => 1, :section_id => 2)
        event.spaces?(@api).should be_true
        event.spaces(@api).should == nil
      end

      it "Under limit" do
        FakeWeb.register_uri(:post, 'https://www.onlinescoutmanager.co.uk/events.php?action=getEventAttendance&eventid=1&sectionid=2&termid=3', :body => {
          'identifier' => 'scoutid',
          'eventid' => '1',
          'items' => [
            {
              'scoutid' => '4',
              'attending' => 'Yes',
              'firstname' => 'First',
              'lastname' => 'Last',
              'dob' => '1980-01-02',
              'patrolid' => '2',
              'f_1' => 'a',
            },
          ]
        }.to_json)
        Osm::Term.stub(:get_current_term_for_section) { Osm::Term.new(:id => 3) }

        event = Osm::Event.new(:attendance_limit => 2, :id => 1, :section_id => 2)
        event.spaces?(@api).should be_true
        event.spaces(@api).should == 1
      end

      it "Over limit" do
        FakeWeb.register_uri(:post, 'https://www.onlinescoutmanager.co.uk/events.php?action=getEventAttendance&eventid=1&sectionid=2&termid=3', :body => {
          'identifier' => 'scoutid',
          'eventid' => '1',
          'items' => [
            {
              'scoutid' => '4',
              'attending' => 'Yes',
              'firstname' => 'First',
              'lastname' => 'Last',
              'dob' => '1980-01-02',
              'patrolid' => '2',
              'f_1' => 'a',
            },{
              'scoutid' => '5',
              'attending' => 'Yes',
              'firstname' => 'First',
              'lastname' => 'Last',
              'dob' => '1980-01-02',
              'patrolid' => '2',
              'f_1' => 'a',
            },{
              'scoutid' => '6',
              'attending' => 'Yes',
              'firstname' => 'First',
              'lastname' => 'Last',
              'dob' => '1980-01-02',
              'patrolid' => '2',
              'f_1' => 'a',
            }
          ]
        }.to_json)
        Osm::Term.stub(:get_current_term_for_section) { Osm::Term.new(:id => 3) }

        event = Osm::Event.new(:attendance_limit => 2, :id => 1, :section_id => 2)
        event.spaces?(@api).should be_false
        event.spaces(@api).should == -1
      end

      it "At limit" do
        FakeWeb.register_uri(:post, 'https://www.onlinescoutmanager.co.uk/events.php?action=getEventAttendance&eventid=1&sectionid=2&termid=3', :body => {
          'identifier' => 'scoutid',
          'eventid' => '1',
          'items' => [
            {
              'scoutid' => '4',
              'attending' => 'Yes',
              'firstname' => 'First',
              'lastname' => 'Last',
              'dob' => '1980-01-02',
              'patrolid' => '2',
              'f_1' => 'a',
            },{
              'scoutid' => '5',
              'attending' => 'Yes',
              'firstname' => 'First',
              'lastname' => 'Last',
              'dob' => '1980-01-02',
              'patrolid' => '2',
              'f_1' => 'a',
            }
          ]
        }.to_json)
        Osm::Term.stub(:get_current_term_for_section) { Osm::Term.new(:id => 3) }

        event = Osm::Event.new(:attendance_limit => 2, :id => 1, :section_id => 2)
        event.spaces?(@api).should be_false
        event.spaces(@api).should == 0
      end

    end

    it "Create (succeded)" do
      url = 'https://www.onlinescoutmanager.co.uk/events.php?action=addEvent&sectionid=1'
      post_data = {
        'apiid' => @CONFIGURATION[:api][:osm][:id],
        'token' => @CONFIGURATION[:api][:osm][:token],
        'userid' => 'user_id',
        'secret' => 'secret',
        'name' => 'Test event',
        'startdate' => '2000-01-02',
        'enddate' => '2001-02-03',
        'starttime' => '03:04:05',
        'endtime' => '04:05:06',
        'cost' => '1.23',
        'location' => 'Somewhere',
        'notes' => 'none',
        'confdate' => '2000-01-01',
        'allowChanges' => 'true',
        'disablereminders' => 'false',
        'attendancelimit' => 3,
        'limitincludesleaders' => true,
      }

      Osm::Event.stub(:get_for_section) { [] }
      HTTParty.should_receive(:post).with(url, {:body => post_data}) { OsmTest::DummyHttpResult.new(:response=>{:code=>'200', :body=>'{"id":2}'}) }

      event = Osm::Event.create(@api, {
        :section_id => 1,
        :name => 'Test event',
        :start => DateTime.new(2000, 1, 2, 3, 4, 5),
        :finish => DateTime.new(2001, 2, 3, 4, 5, 6),
        :cost => '1.23',
        :location => 'Somewhere',
        :notes => 'none',
        :columns => [],
        :notepad => '',
        :public_notepad => '',
        :confirm_by_date => Date.new(2000, 1, 1),
        :allow_changes => true,
        :reminders => true,
        :attendance_limit => 3,
        :attendance_limit_includes_leaders => true,
      })
      event.should_not be_nil
      event.id.should == 2
    end

    it "Create (failed)" do
      Osm::Event.stub(:get_for_section) { [] }
      HTTParty.should_receive(:post) { OsmTest::DummyHttpResult.new(:response=>{:code=>'200', :body=>'{}'}) }

      event = Osm::Event.create(@api, {
        :section_id => 1,
        :name => 'Test event',
        :start => DateTime.new(2000, 01, 02, 03, 04, 05),
        :finish => DateTime.new(2001, 02, 03, 04, 05, 06),
        :cost => '1.23',
        :location => 'Somewhere',
        :notes => 'none',
        :columns => [],
        :notepad => '',
        :public_notepad => '',
        :confirm_by_date => nil,
        :allow_changes => true,
        :reminders => true,
      })
      event.should be_nil
    end


    it "Update (succeded)" do
      url = 'https://www.onlinescoutmanager.co.uk/events.php?action=addEvent&sectionid=1'
      post_data = {
        'apiid' => @CONFIGURATION[:api][:osm][:id],
        'token' => @CONFIGURATION[:api][:osm][:token],
        'userid' => 'user_id',
        'secret' => 'secret',
        'name' => 'Test event',
        'startdate' => '2000-01-02',
        'enddate' => '2001-02-03',
        'starttime' => '03:04:05',
        'endtime' => '04:05:06',
        'cost' => '1.23',
        'location' => 'Somewhere',
        'notes' => 'none',
        'eventid' => 2,
        'confdate' => '',
        'allowChanges' => 'true',
        'disablereminders' => 'false',
        'attendancelimit' => 3,
        'limitincludesleaders' => true,
      }

      HTTParty.should_receive(:post).with(url, {:body => post_data}) { OsmTest::DummyHttpResult.new(:response=>{:code=>'200', :body=>'{"id":2}'}) }
      HTTParty.should_receive(:post).with('https://www.onlinescoutmanager.co.uk/events.php?action=saveNotepad&sectionid=1', {:body=>{"eventid"=>2, "notepad"=>"notepad", "userid"=>"user_id", "secret"=>"secret", "apiid"=>"1", "token"=>"API TOKEN"}}) { OsmTest::DummyHttpResult.new(:response=>{:code=>'200', :body=>'{}'}) }
      HTTParty.should_receive(:post).with('https://www.onlinescoutmanager.co.uk/events.php?action=saveNotepad&sectionid=1', {:body=>{"eventid"=>2, "pnnotepad"=>"public notepad", "userid"=>"user_id", "secret"=>"secret", "apiid"=>"1", "token"=>"API TOKEN"}}) { OsmTest::DummyHttpResult.new(:response=>{:code=>'200', :body=>'{}'}) }

      event = Osm::Event.new(
        :section_id => 1,
        :name => 'Test event',
        :start => DateTime.new(2000, 01, 02, 03, 04, 05),
        :finish => DateTime.new(2001, 02, 03, 04, 05, 06),
        :cost => '1.23',
        :location => 'Somewhere',
        :notes => 'none',
        :id => 2,
        :confirm_by_date => nil,
        :allow_changes => true,
        :reminders => true,
        :notepad => 'notepad',
        :public_notepad => 'public notepad',
        :attendance_limit => 3,
        :attendance_limit_includes_leaders => true,
      )
      event.update(@api).should be_true
    end

    it "Update (failed)" do
      HTTParty.should_receive(:post).exactly(3).times { OsmTest::DummyHttpResult.new(:response=>{:code=>'200', :body=>'{}'}) }

      event = Osm::Event.new(
        :section_id => 1,
        :name => 'Test event',
        :start => DateTime.new(2000, 01, 02, 03, 04, 05),
        :finish => DateTime.new(2001, 02, 03, 04, 05, 06),
        :cost => '1.23',
        :location => 'Somewhere',
        :notes => 'none',
        :id => 2
      )
      event.update(@api).should be_false
    end


    it "Delete (succeded)" do
      url = 'https://www.onlinescoutmanager.co.uk/events.php?action=deleteEvent&sectionid=1&eventid=2'
      post_data = {
        'apiid' => @CONFIGURATION[:api][:osm][:id],
        'token' => @CONFIGURATION[:api][:osm][:token],
        'userid' => 'user_id',
        'secret' => 'secret',
      }

      HTTParty.should_receive(:post).with(url, {:body => post_data}) { OsmTest::DummyHttpResult.new(:response=>{:code=>'200', :body=>'{"ok":true}'}) }

      event = Osm::Event.new(
        :section_id => 1,
        :name => 'Test event',
        :start => DateTime.new(2000, 01, 02, 03, 04, 05),
        :finish => DateTime.new(2001, 02, 03, 04, 05, 06),
        :cost => '1.23',
        :location => 'Somewhere',
        :notes => 'none',
        :id => 2
      )
      event.delete(@api).should be_true
    end

    it "Delete (failed)" do
      HTTParty.should_receive(:post) { OsmTest::DummyHttpResult.new(:response=>{:code=>'200', :body=>'{"ok":false}'}) }

      event = Osm::Event.new(
        :section_id => 1,
        :name => 'Test event',
        :start => DateTime.new(2000, 01, 02, 03, 04, 05),
        :finish => DateTime.new(2001, 02, 03, 04, 05, 06),
        :cost => '1.23',
        :location => 'Somewhere',
        :notes => 'none',
        :id => 2
      )
      event.delete(@api).should be_false
    end


    it "Get attendance" do
      attendance_body = {
	'identifier' => 'scoutid',
	'eventid' => '2',
	'items' => [
          {
	    'scoutid' => '1',
	    'attending' => 'Yes',
            'firstname' => 'First',
            'lastname' => 'Last',
            'dob' => '1980-01-02',
            'patrolid' => '2',
            'f_1' => 'a',
          }
        ]
      }

      FakeWeb.register_uri(:post, "https://www.onlinescoutmanager.co.uk/events.php?action=getEventAttendance&eventid=2&sectionid=1&termid=3", :body => attendance_body.to_json)

      event = Osm::Event.new(:id => 2, :section_id => 1)
      event.should_not be_nil
      attendance = event.get_attendance(@api, 3)
      attendance.is_a?(Array).should be_true
      ea = attendance[0]
      ea.member_id.should == 1
      ea.grouping_id.should == 2
      ea.fields.should == {
        'firstname' => 'First',
        'lastname' => 'Last',
        'dob' => Date.new(1980, 1, 2),
        'attending' => true,
        'f_1' => 'a',
      }
      ea.row.should == 0
    end

    it "Update attendance (succeded)" do
      ea = Osm::Event::Attendance.new(:row => 0, :member_id => 4, :fields => {'f_1' => 'TEST'}, :event => Osm::Event.new(:id => 2, :section_id => 1))

      HTTParty.should_receive(:post).with(
        "https://www.onlinescoutmanager.co.uk/events.php?action=updateScout",
        {:body => {
          'scoutid' => 4,
          'column' => 'f_1',
          'value' => 'TEST',
          'sectionid' => 1,
          'row' => 0,
          'eventid' => 2,
          'apiid' => @CONFIGURATION[:api][:osm][:id],
          'token' => @CONFIGURATION[:api][:osm][:token],
          'userid' => 'user_id',
          'secret' => 'secret',
        }}
      ) { OsmTest::DummyHttpResult.new(:response=>{:code=>'200', :body=>'{}'}) }

      ea.update(@api, 'f_1').should be_true
    end


    it "Add column (succeded)" do
      url = 'https://www.onlinescoutmanager.co.uk/events.php?action=addColumn&sectionid=1&eventid=2'
      post_data = {
        'apiid' => @CONFIGURATION[:api][:osm][:id],
        'token' => @CONFIGURATION[:api][:osm][:token],
        'userid' => 'user_id',
        'secret' => 'secret',
        'columnName' => 'Test name',
        'parentLabel' => 'Test label',
      }
      body = {
        'eventid' => '2',
        'config' => '[{"id":"f_1","name":"Test name","pL":"Test label"}]'
      }
      HTTParty.should_receive(:post).with(url, {:body => post_data}) { OsmTest::DummyHttpResult.new(:response=>{:code=>'200', :body=>body.to_json}) }

      event = Osm::Event.new(:id => 2, :section_id => 1)
      event.should_not be_nil
      event.add_column(@api, 'Test name', 'Test label').should be_true
      column = event.columns[0]
      column.id.should == 'f_1'
      column.name.should == 'Test name'
      column.label.should == 'Test label'
    end

    it "Add column (failed)" do
      HTTParty.should_receive(:post) { OsmTest::DummyHttpResult.new(:response=>{:code=>'200', :body=>'{"config":"[]"}'}) }

      event = Osm::Event.new(:id => 2, :section_id => 1)
      event.should_not be_nil
      event.add_column(@api, 'Test name', 'Test label').should be_false
    end


    it "Update column (succeded)" do
      url = 'https://www.onlinescoutmanager.co.uk/events.php?action=renameColumn&sectionid=1&eventid=2'
      post_data = {
        'apiid' => @CONFIGURATION[:api][:osm][:id],
        'token' => @CONFIGURATION[:api][:osm][:token],
        'userid' => 'user_id',
        'secret' => 'secret',
        'columnId' => 'f_1',
        'columnName' => 'New name',
        'pL' => 'New label',
      }
      body = {
        'eventid' => '2',
        'config' => '[{"id":"f_1","name":"New name","pL":"New label"}]'
      }
      HTTParty.should_receive(:post).with(url, {:body => post_data}) { OsmTest::DummyHttpResult.new(:response=>{:code=>'200', :body=>body.to_json}) }

      event = Osm::Event.new(:id => 2, :section_id => 1)
      event.columns = [Osm::Event::Column.new(:id => 'f_1', :event => event)]
      column = event.columns[0]
      column.name = 'New name'
      column.label = 'New label'

      column.update(@api).should be_true

      column.name.should == 'New name'
      column.label.should == 'New label'
      event.columns[0].name.should == 'New name'
      event.columns[0].label.should == 'New label'
    end

    it "Update column (failed)" do
      HTTParty.should_receive(:post) { OsmTest::DummyHttpResult.new(:response=>{:code=>'200', :body=>'{"config":"[]"}'}) }

      event = Osm::Event.new(:id => 2, :section_id => 1)
      column = Osm::Event::Column.new(:id => 'f_1', :event => event)
      event.columns = [column]
      column.update(@api).should be_false
    end


    it "Delete column (succeded)" do
      url = 'https://www.onlinescoutmanager.co.uk/events.php?action=deleteColumn&sectionid=1&eventid=2'
      post_data = {
        'apiid' => @CONFIGURATION[:api][:osm][:id],
        'token' => @CONFIGURATION[:api][:osm][:token],
        'userid' => 'user_id',
        'secret' => 'secret',
        'columnId' => 'f_1'
      }

      HTTParty.should_receive(:post).with(url, {:body => post_data}) { OsmTest::DummyHttpResult.new(:response=>{:code=>'200', :body=>'{"eventid":"2","config":"[]"}'}) }

      event = Osm::Event.new(:id => 2, :section_id => 1)
      column = Osm::Event::Column.new(:id => 'f_1', :event => event)
      event.columns = [column]

      column.delete(@api).should be_true
      event.columns.should == []
    end

    it "Delete column (failed)" do
      HTTParty.should_receive(:post) { OsmTest::DummyHttpResult.new(:response=>{:code=>'200', :body=>'{"config":"[{\"id\":\"f_1\"}]"}'}) }

      event = Osm::Event.new(:id => 2, :section_id => 1)
      column = Osm::Event::Column.new(:id => 'f_1', :event => event)
      event.columns = [column]
      column.delete(@api).should be_false
    end

  end


  describe "API Strangeness" do
    it "handles a non existant array when no events" do
      data = '{"identifier":"eventid","label":"name"}'
      FakeWeb.register_uri(:post, "https://www.onlinescoutmanager.co.uk/events.php?action=getEvents&sectionid=1&showArchived=true", :body => data)
      events = Osm::Event.get_for_section(@api, 1).should == []
    end
  end

end