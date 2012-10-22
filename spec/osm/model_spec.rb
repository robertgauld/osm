# encoding: utf-8
require 'spec_helper'


describe "Model" do

  class ModelTester < Osm::Model
    def self.test_get_config
      {
        :cache => @@cache,
        :prepend_to_key => @@cache_prepend,
        :ttl => @@cache_ttl,
      }
    end

    def self.cache(method, *options)
      self.send("cache_#{method}", *options)
    end
  end


  it "Create" do
    model = Osm::Model.new
    model.should_not be_nil
  end


  it "Configure" do
    options = {
      :cache => OsmTest::Cache,
      :ttl => 100,
      :prepend_to_key => 'Hi',
    }

    Osm::Model.configure(options)
    config = ModelTester.test_get_config
    config.should == options
  end

  it "Configure (allows empty Hash)" do
    Osm::Model.configure({})
    config = ModelTester.test_get_config
    config[:cache].should be_nil
    config[:ttl].should == 600
    config[:prepend_to_key].should == 'OSMAPI'
  end

  it "Configure (bad arguments)" do
    expect{ Osm::Model.configure(@CONFIGURATION[:cache].merge(:prepend_to_key => :invalid)) }.to raise_error(ArgumentError, ':prepend_to_key must be a String')

    expect{ Osm::Model.configure(@CONFIGURATION[:cache].merge(:ttl => :invalid)) }.to raise_error(ArgumentError, ':ttl must be a FixNum greater than 0')
    expect{ Osm::Model.configure(@CONFIGURATION[:cache].merge(:ttl => 0)) }.to raise_error(ArgumentError, ':ttl must be a FixNum greater than 0')

    expect{ Osm::Model.configure(@CONFIGURATION[:cache].merge(:cache => String)) }.to raise_error(ArgumentError, ':cache must have a exist? method')
  end


  describe "Caching" do

    it "Checks for existance" do
      OsmTest::Cache.should_receive('exist?').with('OSMAPI-osm-key') { true }
      ModelTester.cache('exist?', @api, 'key').should be_true
    end

    it "Writes" do
      OsmTest::Cache.should_receive('write').with('OSMAPI-osm-key', 'data', {:expires_in=>600}) { true }
      ModelTester.cache('write', @api, 'key', 'data').should be_true
    end

    it "Reads" do
      OsmTest::Cache.should_receive('read').with('OSMAPI-osm-key') { 'data' }
      ModelTester.cache('read', @api, 'key').should == 'data'
    end

    it "Deletes" do
      OsmTest::Cache.should_receive('delete').with('OSMAPI-osm-key') { true }
      ModelTester.cache('delete', @api, 'key').should be_true
    end

    it "Behaves when cache is nil (no caching)" do
      Osm::Model.configure({:cache => nil})
      ModelTester.cache('exist?', @api, 'key').should be_false
      ModelTester.cache('write', @api, 'key', 'data').should be_false
      ModelTester.cache('read', @api, 'key').should be_nil
      ModelTester.cache('delete', @api, 'key').should be_true
    end

    it "Builds a key from an array" do
      ModelTester.cache('key', @api, ['a', 'b']).should == 'OSMAPI-osm-a-b'
    end

  end


  describe "Get User Permissions" do

    it "From cache" do
      permissions = {1 => {:a => [:read, :write]}, 2 => {:a => [:read]}}
      OsmTest::Cache.should_receive('exist?').with('OSMAPI-osm-permissions-user_id') { true }
      OsmTest::Cache.should_receive('read').with('OSMAPI-osm-permissions-user_id') { permissions }
      ModelTester.get_user_permissions(@api).should == permissions
    end

    it "From API" do
      permissions = {1 => {:a => [:read, :write]}, 2 => {:a => [:read]}}
      OsmTest::Cache.should_receive('exist?').with('OSMAPI-osm-permissions-user_id') { false }
      Osm::Section.should_receive('fetch_user_permissions').with(@api) { permissions }
      ModelTester.get_user_permissions(@api).should == permissions
    end

    it "Single section" do
      permissions = {1 => {:a => [:read, :write]}, 2 => {:a => [:read]}}
      OsmTest::Cache.should_receive('exist?').with('OSMAPI-osm-permissions-user_id').twice { true }
      OsmTest::Cache.should_receive('read').with('OSMAPI-osm-permissions-user_id').twice { permissions }
      ModelTester.get_user_permissions(@api, 1).should == permissions[1]
      ModelTester.get_user_permissions(@api, 2).should == permissions[2]
    end

  end


  describe "Set User Permissions" do

    it "All Sections" do
      permissions = {1 => {:a => [:read, :write]}, 2 => {:a => [:read]}}
      OsmTest::Cache.should_receive('write').with('OSMAPI-osm-permissions-user_id', permissions, {:expires_in=>600}) { true }
      ModelTester.set_user_permissions(@api, permissions)
    end

    it "Single section" do
      permissions = {1 => {:a => [:read, :write]}, 2 => {:a => [:read]}}
      OsmTest::Cache.should_receive('exist?').with('OSMAPI-osm-permissions-user_id') { true }
      OsmTest::Cache.should_receive('read').with('OSMAPI-osm-permissions-user_id') { permissions }
      OsmTest::Cache.should_receive('write').with('OSMAPI-osm-permissions-user_id', permissions.merge(3 => {:a => [:read]}), {:expires_in=>600}) { true }
      ModelTester.set_user_permissions(@api, 3, {:a => [:read]})
    end

  end

end