# encoding: utf-8
require 'spec_helper'

describe "Badges" do


  describe "Using the OSM API" do

    it "Get due badges" do
      data = {
        'pending' => {
          'badge_name' => [
            {
              'scoutid' => '1',
              'firstname' => 'John',
              'lastname' => 'Doe',
              'level' => '',
              'extra' => '',
            }
          ],
          'staged_staged_participation' => [{
              'sid' => '2',
              'firstname' => 'Jane',
              'lastname' => 'Doe',
              'level' => '2',
              'extra' => 'Lvl 2'
            }, {
              'sid' => '1',
              'firstname' => 'John',
              'lastname' => 'Doe',
              'level' => '2',
              'extra' => 'Lvl 2'
            }
          ]
        },

        'description' => {
          'badge_name' => {
            'name' => 'Badge Name',
            'section' => 'cubs',
            'type' => 'activity',
            'badge' => 'badge_name'
          },
          'staged_staged_participation' => {
            'name' => 'Participation',
            'section' => 'staged',
            'type' => 'staged',
            'badge' => 'participation'
          }
        }
      }
      FakeWeb.register_uri(:post, "https://www.onlinescoutmanager.co.uk/challenges.php?action=outstandingBadges&section=cubs&sectionid=1&termid=2", :body => data.to_json)

      db = Osm::Badges.get_due_badges(@api, Osm::Section.new(:id => 1, :type => :cubs), 2)
      db.empty?.should == false
      db.descriptions.should == {'badge_name_1'=>'Badge Name', 'staged_staged_participation_2'=>'Participation (Level 2)'}
      db.by_member.should == {'John Doe'=>['badge_name_1', 'staged_staged_participation_2'], 'Jane Doe'=>['staged_staged_participation_2']}
      db.totals.should == {'staged_staged_participation_2'=>2, 'badge_name_1'=>1}
      db.valid?.should be_true
    end

    it "handles an empty array representing no due badges" do
      FakeWeb.register_uri(:post, "https://www.onlinescoutmanager.co.uk/challenges.php?action=outstandingBadges&section=cubs&sectionid=1&termid=2", :body => '[]')
      db = Osm::Badges.get_due_badges(@api, Osm::Section.new(:id => 1, :type => :cubs), 2)
      db.should_not == nil
    end


    it "Fetch badge stock levels" do
      badges_body = {
        'stock' => {
          'sectionid' => '1',
          'badge_1' => '1',
          'badge_2' => '2'
        }
      }
      FakeWeb.register_uri(:post, "https://www.onlinescoutmanager.co.uk/challenges.php?action=getInitialBadges&type=core&sectionid=1&section=beavers&termid=2", :body => badges_body.to_json)
      Osm::Term.stub(:get_current_term_for_section) { Osm::Term.new(:id => 2) }

      section = Osm::Section.new(:id => 1, :type => :beavers)
      Osm::Badges.get_stock(@api, section).should == {'badge_1' => 1, 'badge_2' => 2}
    end

    describe "Update badge stock levels" do

      it "Succeds" do
        url = "https://www.onlinescoutmanager.co.uk/challenges.php?action=updateStock"
        HTTParty.should_receive(:post).with(url, {:body => {
          'apiid' => @CONFIGURATION[:api][:osm][:id],
          'token' => @CONFIGURATION[:api][:osm][:token],
          'userid' => 'user_id',
          'secret' => 'secret',
          'stock' => 10,
          'table' => 'badge',
          'sectionid' => 1,
          'section' => :beavers,
        }}) { OsmTest::DummyHttpResult.new(:response=>{:code=>'200', :body=>'{"sectionid":"1","badge":"10"}'}) }

        section = Osm::Section.new(:id => 1, :type => :beavers)
        Osm::Badges.update_stock(@api, section, 'badge', 10).should be_true
      end

      it "Fails" do
        HTTParty.stub(:post) { OsmTest::DummyHttpResult.new(:response=>{:code=>'200', :body=>'{"sectionid":"1","badge":"1"}'}) }
        section = Osm::Section.new(:id => 1, :type => :beavers)
        Osm::Badges.update_stock(@api, section, 'badge', 10).should be_false
      end

    end

  end

end