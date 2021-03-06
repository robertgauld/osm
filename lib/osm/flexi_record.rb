module Osm

  class FlexiRecord < Osm::Model
    # @!attribute [rw] id
    #   @return [Fixnum] the id for the flexi_record
    # @!attribute [rw] section_id
    #   @return [Fixnum] the section the member belongs to
    # @!attribute [rw] name
    #   @return [String] the flexi record's name name

    attribute :id, :type => Integer
    attribute :section_id, :type => Integer
    attribute :name, :type => String

    if ActiveModel::VERSION::MAJOR < 4
      attr_accessible :id, :section_id, :name
    end

    validates_numericality_of :id, :only_integer=>true, :greater_than=>0, :unless => Proc.new { |r| r.id.nil? }
    validates_numericality_of :section_id, :only_integer=>true, :greater_than=>0
    validates_presence_of :name


    # Get structure for the flexi record
    # @param [Osm::Api] api The api to use to make the request
    # @!macro options_get
    # @return [Array<Osm::FlexiRecordColumn>] representing the columns of the flexi record
    def get_columns(api, options={})
      require_ability_to(api, :read, :flexi, section_id, options)
      cache_key = ['flexi_record_columns', self.id]

      if !options[:no_cache] && Osm::Model.cache_exist?(api, cache_key)
        return cache_read(api, cache_key)
      end

      data = api.perform_query("extras.php?action=getExtra&sectionid=#{self.section_id}&extraid=#{self.id}")

      structure = []
      data['structure'].each do |item|
        item['rows'].each do |row|
          structure.push Osm::FlexiRecord::Column.new(
            :id => row['field'],
            :name => row['name'],
            :editable => row['editable'] || false,
            :flexi_record => self,
          )
        end
      end
      cache_write(api, cache_key, structure)

      return structure
    end

    # Add a column in OSM
    # @param [Osm::Api] api The api to use to make the request
    # @param [String] name The name for the created column
    # @return [Boolean] whether the column was created in OSM
    def add_column(api, name)
      require_ability_to(api, :write, :flexi, section_id)
      raise ArgumentError, 'name is invalid' if name.blank?

      data = api.perform_query("extras.php?action=addColumn&sectionid=#{section_id}&extraid=#{id}", {
        'columnName' => name,
      })

      if (data.is_a?(Hash) && data.has_key?('config'))
        ActiveSupport::JSON.decode(data['config']).each do |field|
          if field['name'] == name
            # The cached fields for the flexi record will be out of date - remove them
            cache_delete(api, ['flexi_record_columns', id])
            return true
          end
        end
      end
      return false
    end

    # Get data for flexi record
    # @param [Osm::Api] api The api to use to make the request
    # @param [Osm::Term, Fixnum, #to_i, nil] term The term (or its ID) to get the register for, passing nil causes the current term to be used
    # @!macro options_get
    # @return [Array<FlexiRecordData>]
    def get_data(api, term=nil, options={})
      require_ability_to(api, :read, :flexi, section_id, options)
      section = Osm::Section.get(api, self.section_id)
      term_id = term.nil? ? Osm::Term.get_current_term_for_section(api, section).id : term.to_i
      cache_key = ['flexi_record_data', id, term_id]

      if !options[:no_cache] && Osm::Model.cache_exist?(api, cache_key)
        return cache_read(api, cache_key)
      end

      data = api.perform_query("extras.php?action=getExtraRecords&sectionid=#{section.id}&extraid=#{id}&termid=#{term_id}&section=#{section.type}")

      to_return = []
      data['items'].each do |item|
        unless item['scoutid'].to_i < 0  # It's a total row
          fields = item.select { |key, value|
            ['firstname', 'lastname', 'dob', 'total', 'completed', 'age'].include?(key) || key.to_s.match(/\Af_\d+\Z/)
          }
          fields.merge!(
            'dob' => item['dob'].empty? ? nil : item['dob'],
            'total' => item['total'].to_s.empty? ? nil : item['total'],
            'completed' => item['completed'].to_s.empty? ? nil : item['completed'],
            'age' => item['age'].empty? ? nil : item['age'],
          )
  
          to_return.push Osm::FlexiRecord::Data.new(
            :member_id => Osm::to_i_or_nil(item['scoutid']),
            :grouping_id => Osm::to_i_or_nil(item['patrolid'].eql?('') ? nil : item['patrolid']),
            :fields => fields,
            :flexi_record => self,
          )
        end
      end

      cache_write(api, cache_key, to_return)
      return to_return
    end

    # Compare FlexiRecord based on section_id then name
    def <=>(another)
      result = self.section_id.to_i <=> another.try(:section_id).to_i
      result = self.name.to_s <=> another.try(:name).to_s if result == 0
      return result
    end



    class Column < Osm::Model
      # @!attribute [rw] flexi_record
      #   @return [Boolean] The FlexiRecord this column belongs to
      # @!attribute [rw] id
      #   @return [String] OSM identifier for the field. Special ones are 'dob', 'total', 'completed', 'age', 'firstname' and 'lastname', user ones are of the format 'f\_NUMBER'
      # @!attribute [rw] name
      #   @return [String] Human readable name for the field
      # @!attribute [rw] editable
      #   @return [Boolean] Wether the field can be edited

      attribute :flexi_record, :type => Object
      attribute :id, :type => String
      attribute :name, :type => String
      attribute :editable, :type => Boolean, :default => false

      if ActiveModel::VERSION::MAJOR < 4
        attr_accessible :flexi_record, :id, :name, :editable
      end

      validates_presence_of :flexi_record
      validates_presence_of :id
      validates_presence_of :name
      validates_inclusion_of :editable, :in => [true, false]

      # @!method initialize
      #   Initialize a new FlexiRecord::Column
      #   @param [Hash] attributes The hash of attributes (see attributes for descriptions, use Symbol of attribute name as the key)


      # Update a column in OSM
      # @param [Osm::Api] api The api to use to make the request
      # @return [Boolean] whether the column was updated in OSM
      # @raise [Osm::ObjectIsInvalid] If the Column is invalid
      # @raise [Osm::Forbidden] If the COlumn is not editable
      def update(api)
        raise Osm::ObjectIsInvalid, 'column is invalid' unless valid?
        require_ability_to(api, :write, :flexi, flexi_record.section_id)
        raise Osm::Forbidden, 'this column is not editable' unless self.editable

        data = api.perform_query("extras.php?action=renameColumn&sectionid=#{flexi_record.section_id}&extraid=#{flexi_record.id}", {
          'columnId' => self.id,
          'columnName' => self.name,
        })

        if (data.is_a?(Hash) && data.has_key?('config'))
          ActiveSupport::JSON.decode(data['config']).each do |f|
            if (f['id'] == self.id) && (f['name'] == self.name)
              reset_changed_attributes
              # The cached columns for the flexi record will be out of date - remove them
              cache_delete(api, ['flexi_record_columns', flexi_record.id])
              return true
            end
          end
        end
        return false
      end

      # Delete a column in OSM
      # @param [Osm::Api] api The api to use to make the request
      # @return [Boolean] whether the column was deleted from OSM
      # @raise [Osm::Forbidden] If this Column is not editable
      def delete(api)
        require_ability_to(api, :write, :flexi, flexi_record.section_id)
        raise Osm::Forbidden, 'this column is not editable' unless self.editable

        data = api.perform_query("extras.php?action=deleteColumn&sectionid=#{flexi_record.section_id}&extraid=#{flexi_record.id}", {
          'columnId' => self.id,
        })

        if (data.is_a?(Hash) && data.has_key?('config'))
          ActiveSupport::JSON.decode(data['config']).each do |f|
            if f['id'] == self.id
              # It wasn't deleted
              return false
            end
          end
        end

        # The cached columns for the flexi record will be out of date - remove them
        cache_delete(api, ['flexi_record_columns', flexi_record.id])
        return true
      end

      # Compare Column based on flexi_record then id
      def <=>(another)
        result = self.flexi_record <=> another.try(:flexi_record)
        if result == 0
          if id.match(/\Af_\d+\Z/)
            # This is a user column
            unless another.try(:id).to_s.match(/\Af_\d+\Z/)
              return 1
            end
          else
            # This is a system column
            if another.try(:id).to_s.match(/\Af_\d+\Z/)
              return -1
            end
          end
          result = self.id <=> another.try(:id)
        end
        return result
      end

      def inspect
        Osm.inspect_instance(self, options={:replace_with => {'flexi_record' => :id}})
      end

    end # Class FlexiRecord::Column


    class Data < Osm::Model
      SORT_BY = [:flexi_record, :grouping_id, :member_id]

      # @!attribute [rw] flexi_record
      #   @return [Boolean] The FlexiRecord this column belongs to
      # @!attribute [rw] member_id
      #   @return [Fixnum] OSM id for the member
      # @!attribute [rw] grouping__id
      #   @return [Fixnum] OSM id for the grouping the member is in
      # @!attribute [rw] fields
      #   @return [DirtyHashy] Keys are the field's id, values are the field values

      attribute :flexi_record, :type => Object
      attribute :member_id, :type => Integer
      attribute :grouping_id, :type => Integer
      attribute :fields, :default => {}

      if ActiveModel::VERSION::MAJOR < 4
        attr_accessible :flexi_record, :member_id, :grouping_id, :fields
      end

      validates_presence_of :flexi_record
      validates_numericality_of :member_id, :only_integer=>true, :greater_than=>0
      validates_numericality_of :grouping_id, :only_integer=>true, :greater_than_or_equal_to=>-2
      validates :fields, :hash => {:key_type => String}


      # @!method initialize
      #   Initialize a new FlexiRecord::Data
      #   @param [Hash] attributes The hash of attributes (see attributes for descriptions, use Symbol of attribute name as the key)
      # Override initialize to set @orig_attributes
      old_initialize = instance_method(:initialize)
      define_method :initialize do |*args|
        ret_val = old_initialize.bind(self).call(*args)
        self.fields = DirtyHashy.new(self.fields)
        self.fields.clean_up!
        return ret_val
      end


      # Update data in OSM
      # @param [Osm::Api] api The api to use to make the request
      # @return [Boolean] whether the data was updated in OSM
      # @raise [Osm::ObjectIsInvalid] If the Data is invalid
      def update(api)
        raise Osm::ObjectIsInvalid, 'data is invalid' unless valid?
        require_ability_to(api, :write, :flexi, flexi_record.section_id)

        term_id = Osm::Term.get_current_term_for_section(api, flexi_record.section_id).id

        updated = true
        editable_fields = flexi_record.get_columns(api).select{ |c| c.editable }.map{ |i| i.id }
        fields.changes.each do |field, (was,now)|
          if editable_fields.include?(field)
            data = api.perform_query("extras.php?action=updateScout", {
              'termid' => term_id,
              'scoutid' => self.member_id,
              'column' => field,
              'value' => now,
              'sectionid' => flexi_record.section_id,
              'extraid' => flexi_record.id,
            })
            if (data.is_a?(Hash) && data['items'].is_a?(Array))
              data['items'].each do |item|
                if item['scoutid'] == member_id.to_s  # Find this member from the list of all members
                  updated = false unless item[field] == now
                end
              end
            else
              updated = false
            end
          end
        end

        if updated
          fields.clean_up!
          # The cached datas for the flexi record will be out of date - remove them
          cache_delete(api, ['flexi_record_data', flexi_record.id])
        end

        return updated
      end

      # Compare Data based on flexi_record, grouping_id then member_id
      def <=>(another)
        result = self.flexi_record <=> another.try(:flexi_record)
        result = self.grouping_id <=> another.try(:grouping_id) if result == 0
        result = self.member_id <=> another.try(:member_id) if result == 0
        return result
      end

      def inspect
        Osm.inspect_instance(self, options={:replace_with => {'flexi_record' => :id}})
      end

    end # Class FlexiRecord::Data

  end # Class FlexiRecord
  
end # Module
