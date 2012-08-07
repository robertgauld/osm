# @!macro [new] options_get
#   @param [Hash] options
#   @option options [Boolean] :no_cache (optional) if true then the data will be retreived from OSM not the cache

# @!macro [new] options_api_data
#   @param [Hash] api_data
#   @option api_data [String] 'userid' (optional) the OSM userid to make the request as
#   @option api_data [String] 'secret' (optional) the OSM secret belonging to the above user


module Osm

  class Api

    @@default_cache_ttl = 30 * 60     # The default caching time for responses from OSM (in seconds)
                                      # Some things will only be cached for half this time
                                      # Whereas others will be cached for twice this time
                                      # Most items however will be cached for this time

    @@user_access = Hash.new

    # Initialize a new API connection
    # If passing user details then both must be passed
    # @param [String] userid osm userid of the user to act as
    # @param [String] secret osm secret of the user to act as
    # @param [Symbol] site wether to use OSM (:scout) or OGM (:guide), defaults to the value set for the class
    # @return nil
    def initialize(userid=nil, secret=nil, site=@@api_site)
      raise ArgumentError, 'You must pass a secret if you are passing a userid' if secret.nil? && !userid.nil?
      raise ArgumentError, 'You must pass a userid if you are passing a secret' if userid.nil? && !secret.nil?
      raise ArgumentError, 'site is invalid, if passed it should be either :scout or :guide' unless [:scout, :guide].include?(site)

      @base_url = 'https://www.onlinescoutmanager.co.uk' if site == :scout
      @base_url = 'http://www.onlineguidemanager.co.uk' if site == :guide
      set_user(userid, secret)
      nil
    end

    # Configure the API options used by all instances of the class
    # @param [Hash] options
    # @option options [String] :api_id the apiid given to you for using the OSM id
    # @option options [String] :api_token the token which goes with the above api
    # @option options [String] :api_name the name displayed in the External Access tab of OSM
    # @option options [Symbol] :api_sate wether to use OSM (if :scout) or OGM (if :guide)
    # @option options [FixNum] :default_cache_ttl (optional, default = 30.minutes) The default TTL value for the cache, note that some items are cached for twice this time and others are cached for half this time (in seconds).
    # @return nil
    def self.configure(options)
      raise ArgumentError, ':api_id does not exist in options hash' if options[:api_id].nil?
      raise ArgumentError, ':api_token does not exist in options hash' if options[:api_token].nil?
      raise ArgumentError, ':api_name does not exist in options hash' if options[:api_name].nil?
      raise ArgumentError, ':api_site does not exist in options hash or is invalid, this should be set to either :scout or :guide' unless [:scout, :guide].include?(options[:api_site])
      raise ArgumentError, ':default_cache_ttl must be greater than 0' unless (options[:default_cache_ttl].nil? || options[:default_cache_ttl].to_i > 0)

      @@api_id = options[:api_id].to_s
      @@api_token = options[:api_token].to_s
      @@api_name = options[:api_name].to_s
      @@api_site = options[:api_site]
      @@default_cache_ttl = options[:default_cache_ttl].to_i unless options[:default_cache_ttl].nil?
      nil
    end

    # Get the API ID used in this class
    # @return [String] the API ID
    def self.api_id
      return @@api_id
    end

    # Get the API name displayed in the External Access tab of OSM
    # @return [String] the API name
    def self.api_name
      return @@api_name
    end

    # Get the userid and secret to be able to act as a certain user on the OSM system
    # Also set's the 'current user'
    # @param [String] email the login email address of the user on OSM
    # @param [String] password the login password of the user on OSM
    # @return [Hash] a hash containing the following keys:
    #   * 'userid' - the userid to use in future requests
    #   * 'secret' - the secret to use in future requests
    def authorize(email, password)
      api_data = {
        'email' => email,
        'password' => password,
      }
      data = perform_query('users.php?action=authorise', api_data)
      set_user(data['userid'], data['secret'])
      return data
    end

    # Get the user's roles
    # @!macro options_get
    # @!macro options_api_data
    # @return [Array<Osm::Role>]
    def get_roles(options={}, api_data={})

      if !options[:no_cache] && Rails.cache.exist?("OSMAPI-roles-#{api_data[:userid] || @userid}")
        return Rails.cache.read("OSMAPI-roles-#{api_data[:userid] || @userid}")
      end

      data = perform_query('api.php?action=getUserRoles', api_data)

      result = Array.new
      data.each do |item|
        role = Osm::Role.new(item)
        result.push role
        Rails.cache.write("OSMAPI-section-#{role.section.id}", role.section, :expires_in => @@default_cache_ttl*2)
        self.user_can_access :section, role.section.id, api_data
      end
      Rails.cache.write("OSMAPI-roles-#{api_data[:userid] || @userid}", result, :expires_in => @@default_cache_ttl*2)

      return result
    end

    # Get the user's notepads
    # @!macro options_get
    # @!macro options_api_data
    # @return [Hash] a hash (keys are section IDs, values are a string)
    def get_notepads(options={}, api_data={})
      if !options[:no_cache] && Rails.cache.exist?("OSMAPI-notepads-#{api_data[:userid] || @userid}")
        return Rails.cache.read("OSMAPI-notepads-#{api_data[:userid] || @userid}")
      end

      notepads = perform_query('api.php?action=getNotepads', api_data)
      return {} unless notepads.is_a?(Hash)

      data = {}
      notepads.each do |key, value|
        data[key.to_i] = value
        Rails.cache.write("OSMAPI-notepad-#{key}", value, :expires_in => @@default_cache_ttl*2)
      end

      Rails.cache.write("OSMAPI-notepads-#{api_data[:userid] || @userid}", data, :expires_in => @@default_cache_ttl*2)
      return data
    end

    # Get the notepad for a specified section
    # @param [FixNum] section_id the section id of the required section
    # @!macro options_get
    # @!macro options_api_data
    # @return nil if an error occured or the user does not have access to that section
    # @return [String] the content of the notepad otherwise
    def get_notepad(section_id, options={}, api_data={})
      if !options[:no_cache] && Rails.cache.exist?("OSMAPI-notepad-#{section_id}") && self.user_can_access?(:section, section_id, api_data)
        return Rails.cache.read("OSMAPI-notepad-#{section_id}")
      end

      notepads = get_notepads(options, api_data)
      return nil unless notepads.is_a? Hash

      notepads.each_key do |key|
        return notepads[key] if key == section_id
      end

      return nil
    end

    # Get the section (and its configuration)
    # @param [FixNum] section_id the section id of the required section
    # @!macro options_get
    # @!macro options_api_data
    # @return nil if an error occured or the user does not have access to that section
    # @return [Osm::Section]
    def get_section(section_id, options={}, api_data={})

      if !options[:no_cache] && Rails.cache.exist?("OSMAPI-section-#{section_id}") && self.user_can_access?(:section, section_id, api_data)
        return Rails.cache.read("OSMAPI-section-#{section_id}")
      end

      roles = get_roles(options, api_data)
      return nil unless roles.is_a? Array

      roles.each do |role|
        return role.section if role.section.id == section_id
      end

      return nil
    end

    # Get the groupings (e.g. patrols, sixes, lodges) for a given section
    # @param [FixNum] section_id the section to get the programme for
    # @!macro options_get
    # @!macro options_api_data
    # @return [Array<Osm::Grouping>]
    def get_groupings(section_id, options={}, api_data={})
      if !options[:no_cache] && Rails.cache.exist?("OSMAPI-groupings-#{section_id}") && self.user_can_access?(:section, section_id, api_data)
        return Rails.cache.read("OSMAPI-groupings-#{section_id}")
      end

      data = perform_query("users.php?action=getPatrols&sectionid=#{section_id}", api_data)

      result = Array.new
      data['patrols'].each do |item|
        grouping = Osm::Grouping.new(item)
        result.push grouping
        Rails.cache.write("OSMAPI-grouping-#{grouping.id}", grouping, :expires_in => @@default_cache_ttl*2)
        self.user_can_access :grouping, grouping.id, api_data
      end
      Rails.cache.write("OSMAPI-groupings-#{section_id}", result, :expires_in => @@default_cache_ttl*2)

      return result
    end

    # Get the terms that the OSM user can access
    # @!macro options_get
    # @!macro options_api_data
    # @return [Array<Osm::Term>]
    def get_terms(options={}, api_data={})
      if !options[:no_cache] && Rails.cache.exist?("OSMAPI-terms-#{api_data[:userid] || @userid}")
        return Rails.cache.read("OSMAPI-terms-#{api_data[:userid] || @userid}")
      end

      data = perform_query('api.php?action=getTerms', api_data)

      result = Array.new
      data.each_key do |key|
        data[key].each do |item|
          term = Osm::Term.new(item)
          result.push term
          Rails.cache.write("OSMAPI-term-#{term.id}", term, :expires_in => @@default_cache_ttl*2)
          self.user_can_access :term, term.id, api_data
        end
      end

      Rails.cache.write("OSMAPI-terms-#{api_data[:userid] || @userid}", result, :expires_in => @@default_cache_ttl*2)
      return result
    end

    # Get a term
    # @param [FixNum] term_id the id of the required term
    # @!macro options_get
    # @!macro options_api_data
    # @return nil if an error occured or the user does not have access to that term
    # @return [Osm::Term]
    def get_term(term_id, options={}, api_data={})
      if !options[:no_cache] && Rails.cache.exist?("OSMAPI-term-#{term_id}") && self.user_can_access?(:term, term_id, api_data)
        return Rails.cache.read("OSMAPI-term-#{term_id}")
      end

      terms = get_terms(options)
      return nil unless terms.is_a? Array

      terms.each do |term|
        return term if term.id == term_id
      end

      return nil
    end

    # Get the programme for a given term
    # @param [FixNum] section_id the section to get the programme for
    # @param [FixNum] term_id the term to get the programme for
    # @!macro options_get
    # @!macro options_api_data
    # @return [Array<Osm::Evening>]
    def get_programme(section_id, term_id, options={}, api_data={})
      if !options[:no_cache] && Rails.cache.exist?("OSMAPI-programme-#{section_id}-#{term_id}") && self.user_can_access?(:programme, section_id, api_data)
        return Rails.cache.read("OSMAPI-programme-#{section_id}-#{term_id}")
      end

      data = perform_query("programme.php?action=getProgramme&sectionid=#{section_id}&termid=#{term_id}", api_data)

      result = Array.new
      data = {'items'=>[],'activities'=>{}} if data.is_a? Array
      self.user_can_access(:programme, section_id, api_data) unless data.is_a? Array
      items = data['items'] || []
      activities = data['activities'] || {}

      items.each do |item|
        evening = Osm::Evening.new(item, activities[item['eveningid']])
        result.push evening
        evening.activities.each do |activity|
          self.user_can_access :activity, activity.activity_id, api_data
        end
      end

      Rails.cache.write("OSMAPI-programme-#{section_id}-#{term_id}", result, :expires_in => @@default_cache_ttl)
      return result
    end

    # Get activity details
    # @param [FixNum] activity_id the activity ID
    # @param [FixNum] version the version of the activity to retreive, if nil the latest version will be assumed
    # @!macro options_get
    # @!macro options_api_data
    # @return [Osm::Activity]
    def get_activity(activity_id, version=nil, options={}, api_data={})
      if !options[:no_cache] && Rails.cache.exist?("OSMAPI-activity-#{activity_id}-#{version}") && self.user_can_access?(:activity, activity_id, api_data)
        return Rails.cache.read("OSMAPI-activity-#{activity_id}-#{version}")
      end

      data = nil
      if version.nil?
        data = perform_query("programme.php?action=getActivity&id=#{activity_id}", api_data)
      else
        data = perform_query("programme.php?action=getActivity&id=#{activity_id}&version=#{version}", api_data)
      end

      activity = Osm::Activity.new(data)
      Rails.cache.write("OSMAPI-activity-#{activity_id}-#{nil}", activity, :expires_in => @@default_cache_ttl*2) if version.nil?
      Rails.cache.write("OSMAPI-activity-#{activity_id}-#{activity.version}", activity, :expires_in => @@default_cache_ttl/2)
      self.user_can_access :activity, activity.id, api_data

      return activity
    end

    # Get member details
    # @param [FixNum] section_id the section to get details for
    # @param [FixNum] term_id the term to get details for, if nil the current term is assumed
    # @!macro options_get
    # @!macro options_api_data
    # @return [Array<Osm::Member>]
    def get_members(section_id, term_id=nil, options={}, api_data={})
      term_id = Osm::find_current_term_id(self, section_id, api_data) if term_id.nil?

      if !options[:no_cache] && Rails.cache.exist?("OSMAPI-members-#{section_id}-#{term_id}") && self.user_can_access?(:member, section_id, api_data)
        return Rails.cache.read("OSMAPI-members-#{section_id}-#{term_id}")
      end

      data = perform_query("users.php?action=getUserDetails&sectionid=#{section_id}&termid=#{term_id}", api_data)

      result = Array.new
      data['items'].each do |item|
        result.push Osm::Member.new(item)
      end
      self.user_can_access :member, section_id, api_data
      Rails.cache.write("OSMAPI-members-#{section_id}-#{term_id}", result, :expires_in => @@default_cache_ttl)

      return result
    end

    # Get API access details for a given section
    # @param [FixNum] section_id the section to get details for
    # @!macro options_get
    # @!macro options_api_data
    # @return [Array<Osm::ApiAccess>]
    def get_api_access(section_id, options={}, api_data={})
      if !options[:no_cache] && Rails.cache.exist?("OSMAPI-api_access-#{api_data['userid'] || @userid}-#{section_id}")
        return Rails.cache.read("OSMAPI-api_access-#{api_data['userid'] || @userid}-#{section_id}")
      end

      data = perform_query("users.php?action=getAPIAccess&sectionid=#{section_id}", api_data)

      result = Array.new
      data['apis'].each do |item|
        this_item = Osm::ApiAccess.new(item)
        result.push this_item
        self.user_can_access(:programme, section_id, api_data) if this_item.can_read?(:programme)
        self.user_can_access(:member, section_id, api_data) if this_item.can_read?(:member)
        self.user_can_access(:badge, section_id, api_data) if this_item.can_read?(:badge)
        Rails.cache.write("OSMAPI-api_access-#{api_data['userid'] || @userid}-#{section_id}-#{this_item.id}", this_item, :expires_in => @@default_cache_ttl*2)
      end

      return result
    end

    # Get our API access details for a given section
    # @param [FixNum] section_id the section to get details for
    # @!macro options_get
    # @!macro options_api_data
    # @return [Osm::ApiAccess]
    def get_our_api_access(section_id, options={}, api_data={})
      if !options[:no_cache] && Rails.cache.exist?("OSMAPI-api_access-#{api_data['userid'] || @userid}-#{section_id}-#{Osm::Api.api_id}")
        return Rails.cache.read("OSMAPI-api_access-#{api_data['userid'] || @userid}-#{section_id}-#{Osm::Api.api_id}")
      end

      data = get_api_access(section_id, options)
      found = nil
      data.each do |item|
        found = item if item.our_api?
      end

      return found
    end

    # Get events
    # @param [FixNum] section_id the section to get details for
    # @!macro options_get
    # @!macro options_api_data
    # @return [Array<Osm::Event>]
    def get_events(section_id, options={}, api_data={})
      if !options[:no_cache] && Rails.cache.exist?("OSMAPI-events-#{section_id}") && self.user_can_access?(:programme, section_id, api_data)
        return Rails.cache.read("OSMAPI-events-#{section_id}")
      end

      data = perform_query("events.php?action=getEvents&sectionid=#{section_id}", api_data)

      result = Array.new
      unless data['items'].nil?
        data['items'].each do |item|
          result.push Osm::Event.new(item)
        end
      end
      self.user_can_access :programme, section_id, api_data
      Rails.cache.write("OSMAPI-events-#{section_id}", result, :expires_in => @@default_cache_ttl)

      return result
    end

    # Get due badges
    # @param [FixNum] section_id the section to get details for
    # @!macro options_get
    # @!macro options_api_data
    # @return [Osm::DueBadges]
    def get_due_badges(section_id, term_id=nil, options={}, api_data={})
      term_id = Osm::find_current_term_id(self, section_id, api_data) if term_id.nil?

      if !options[:no_cache] && Rails.cache.exist?("OSMAPI-due_badges-#{section_id}-#{term_id}") && self.user_can_access?(:badge, section_id, api_data)
        return Rails.cache.read("OSMAPI-due_badges-#{section_id}-#{term_id}")
      end

      section_type = get_section(section_id, api_data).type.to_s
      data = perform_query("challenges.php?action=outstandingBadges&section=#{section_type}&sectionid=#{section_id}&termid=#{term_id}", api_data)

      data = Osm::DueBadges.new(data)
      self.user_can_access :badge, section_id, api_data
      Rails.cache.write("OSMAPI-due_badges-#{section_id}-#{term_id}", data, :expires_in => @@default_cache_ttl*2)

      return data
    end

    # Get register structure
    # @param [FixNum] section_id the section to get details for
    # @!macro options_get
    # @!macro options_api_data
    # @return [Array<Hash>] representing the rows of the register
    def get_register_structure(section_id, term_id=nil, options={}, api_data={})
      term_id = Osm::find_current_term_id(self, section_id, api_data) if term_id.nil?

      if !options[:no_cache] && Rails.cache.exist?("OSMAPI-register_structure-#{section_id}-#{term_id}") && self.user_can_access?(:register, section_id, api_data)
        return Rails.cache.read("OSMAPI-register_structure-#{section_id}-#{term_id}")
      end

      data = perform_query("users.php?action=registerStructure&sectionid=#{section_id}&termid=#{term_id}", api_data)

      data.each_with_index do |item, item_index|
        data[item_index] = item = Osm::symbolize_hash(item)
        item[:rows].each_with_index do |row, row_index|
          item[:rows][row_index] = row = Osm::symbolize_hash(row)
        end
      end
      self.user_can_access :register, section_id, api_data
      Rails.cache.write("OSMAPI-register_structure-#{section_id}-#{term_id}", data, :expires_in => @@default_cache_ttl/2)

      return data
    end

    # Get register
    # @param [FixNum] section_id the section to get details for
    # @!macro options_get
    # @!macro options_api_data
    # @return [Array<Hash>] representing the attendance of each member
    def get_register(section_id, term_id=nil, options={}, api_data={})
      term_id = Osm::find_current_term_id(self, section_id, api_data) if term_id.nil?

      if !options[:no_cache] && Rails.cache.exist?("OSMAPI-register-#{section_id}-#{term_id}") && self.user_can_access?(:register, section_id, api_data)
        return Rails.cache.read("OSMAPI-register-#{section_id}-#{term_id}")
      end

      data = perform_query("users.php?action=register&sectionid=#{section_id}&termid=#{term_id}", api_data)

      data = data['items']
      data.each do |item|
        item = Osm::symbolize_hash(item)
        item[:scoutid] = item[:scoutid].to_i
        item[:sectionid] = item[:sectionid].to_i
        item[:patrolid] = item[:patrolid].to_i
      end
      self.user_can_access :register, section_id, api_data
      Rails.cache.write("OSMAPI-register-#{section_id}-#{term_id}", data, :expires_in => @@default_cache_ttl/2)
      return data
    end

    # Create an evening in OSM
    # @param [FixNum] section_id the id of the section to add the term to
    # @param [Date] meeting_date the date of the meeting
    # @!macro options_api_data
    # @return [Boolean] if the operation suceeded or not
    def create_evening(section_id, meeting_date, api_data={})
      section_id = section_id.to_i
      evening_api_data = {
        'meetingdate' => meeting_date.strftime('%Y-%m-%d'),
        'sectionid' => section_id,
        'activityid' => -1
      }

      data = perform_query("programme.php?action=addActivityToProgramme", api_data.merge(evening_api_data))

      # The cached programmes for the section will be out of date - remove them
      get_terms(api_data).each do |term|
        Rails.cache.delete("OSMAPI-programme-#{term.section_id}-#{term.id}") if term.section_id == section_id
      end

      return data.is_a?(Hash) && (data['result'] == 0)
    end

    # Update an evening in OSM
    # @param [Osm::Evening] evening the evening to update
    # @!macro options_api_data
    # @return [Boolean] if the operation suceeded or not
    def update_evening(evening, api_data={})
      response = perform_query("programme.php?action=editEvening", api_data.merge(evening.data_for_saving))

      # The cached programmes for the section will be out of date - remove them
      get_terms(api_data).each do |term|
        Rails.cache.delete("OSMAPI-programme-#{term.section_id}-#{term.id}") if term.section_id == programme_item.section_id
      end

      return response.is_a?(Hash) && (response['result'] == 0)
    end


    protected
    # Set access permission for the current user on a resource stored in the cache
    # @param [Symbol] resource_type a symbol representing the resource type (:section, :grouping, :term, :activity, :programme, :member, :badge, :register)
    # @param [FixNum] resource_id the id of the resource being checked
    # @param [Hash] api_data the data hash used in accessing the api
    # @param [Boolean] permission wether the user can access the resource
    # @return [Boolean] the permission which was set
    def user_can_access(resource_type, resource_id, api_data, permission=true)
      user = (api_data['userid'] || @userid).to_i
      resource_id = resource_id.to_i
      resource_type = resource_type.to_sym

      @@user_access[user] = {} if @@user_access[user].nil?
      @@user_access[user][resource_type] = {} if @@user_access[user][resource_type].nil?

      @@user_access[user][resource_type][resource_id] = permission
    end

    # Get access permission for the current user on a resource stored in the cache
    # @param [Symbol] resource_type a symbol representing the resource type (:section, :grouping, :term, :activity, :programme, :member, :badge, :register)
    # @param [FixNum] resource_id the id of the resource being checked
    # @param [Hash] api_data the data hash used in accessing the api
    # @return nil if the combination of user and resource has not been set
    # @return [Boolean] if the user can access the resource
    def user_can_access?(resource_type, resource_id, api_data)
      user = (api_data['userid'] || @userid).to_i
      resource_id = resource_id.to_i
      resource_type = resource_type.to_sym

      return nil if @@user_access[user].nil?
      return nil if @@user_access[user][resource_type].nil?
      return @@user_access[user][resource_type][resource_id]
    end


    private
    # Set the OSM user to make future requests as
    # @param [String] userid the OSM userid to use (get this using the authorize method)
    # @param [String] secret the OSM secret to use (get this using the authorize method)
    def set_user(userid, secret)
      @userid = userid
      @secret = secret
    end

    # Make the query to the OSM API
    # @param [String] url the script on the remote server to invoke
    # @param [Hash] api_data a hash containing the values to be sent to the server
    # @return [Hash, Array, String] the parsed JSON returned by OSM
    def perform_query(url, api_data={})
      api_data['apiid'] = @@api_id
      api_data['token'] = @@api_token

      if api_data['userid'].nil? && api_data['secret'].nil?
        unless @userid.nil? || @secret.nil?
          api_data['userid'] = @userid
          api_data['secret'] = @secret
        end
      end

      if Rails.env.development?
        puts "Making OSM API request to #{url}"
        puts api_data.to_s
      end

      begin
        result = HTTParty.post("#{@base_url}/#{url}", {:body => api_data})
      rescue SocketError, TimeoutError, OpenSSL::SSL::SSLError
        raise ConnectionError.new('A problem occured on the internet.')
      end
      raise ConnectionError.new("HTTP Status code was #{result.response.code}") if !result.response.code.eql?('200')

      if Rails.env.development?
        puts "Result from OSM request to #{url}"
        puts result.response.body
      end

      raise Error.new(result.response.body) unless looks_like_json?(result.response.body)
      decoded = ActiveSupport::JSON.decode(result.response.body)
      osm_error = get_osm_error(decoded)
      raise Error.new(osm_error) if osm_error
      return decoded        
    end

    # Check if text looks like it's JSON
    # @param [String] text what to look at
    # @return [Boolean]
    def looks_like_json?(text)
      (['[', '{'].include?(text[0]))
    end

    # Get the error returned by OSM
    # @param data what OSM gave us
    # @return false if no error message was found
    # @return [String] the error message
    def get_osm_error(data)
      return false unless data.is_a?(Hash)
      to_return = data['error'] || data['err'] || false
      to_return = false if to_return.blank?
      puts "OSM API ERROR: #{to_return}" if Rails.env.development? && to_return
      return to_return
    end

  end

end
