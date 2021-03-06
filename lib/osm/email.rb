module Osm
  
  class Email
    TAGS = [{id: 'FIRSTNAME', description: "Member's first name"}, {id: 'LASTNAME', description: "Member's last name"}]

    # Get a list of selected email address for selected members ready to pass to send_email method
    # @param [Osm::Api] api The api to use to make the request
    # @param [Osm::Section, Fixnum, #to_i] section The section (or its ID) to send the message to
    # @param [Array<symbol>] contacts The contacts to get for members (:primary, :secondary and/or :member)
    # @param [Array<Osm::Member, Fixnum, #to_i>] members The members (or their IDs) to get the email addresses for
    # @return [Hash] member_id -> {firstname [String], lastname [String], emails [Array<String>]}
    def self.get_emails_for_contacts(api, section, contacts, members)
      # Convert contacts into OSM's format
      contacts = [*contacts]
      fail ArgumentError, "You must pass at least one contact" if contacts.none?
      contact_group_map = {
        primary: '"contact_primary_1"',
        secondary: '"contact_primary_2"',
        member: '"contact_primary_member"'
      }
      contacts.map! do |contact|
        mapped = contact_group_map[contact]
        fail ArgumentError, "Invalid contact - #{contact.inspect}" if mapped.nil?
        mapped
      end

      # Convert member_ids to array of numbers
      members = [*members]
      fail ArgumentError, "You must pass at least one member" if members.none?
      members.map!{ |member| member.to_i }

      data = api.perform_query("/ext/members/email/?action=getSelectedEmailsFromContacts&sectionid=#{section.to_i}&scouts=#{members.join(',')}", {
        'contactGroups' => "[#{contacts.join(',')}]"
      })
      if data.is_a?(Hash)
        data = data['emails']
        return data if data.is_a?(Hash)
      end
      return false
    end

    # Get a list of selected email address for selected members ready to pass to send_email method
    # @param [Osm::Api] api The api to use to make the request
    # @param [Osm::Section, Fixnum, #to_i] section The section (or its ID) to send the message to
    # @param [Hash] send_to Email addresses to send the email to: member_id -> {firstname [String], lastname [String], emails [Array<String>]}
    # @param [String, nil] cc Email address (if any) to cc
    # @param [String] from Email address to send the email from
    # @param [String] from Email subject The subject of the email
    # @param [String] from Email body The bosy of the email
    # @return [Boolean] Whether OSM reported the email as sent
    def self.send_email(api, section, send_to, cc='', from, subject, body)
      data = api.perform_query('ext/members/email/?action=send', {
        'sectionid' => section.to_i,
        'emails' => send_to.to_json,
        'scouts' => send_to.keys.join(','),
        'cc' => cc,
        'from' => from,
        'subject' => subject,
        'body' => body,
      })

      return data.is_a?(Hash) && data['ok']
    end


    class DeliveryReport < Osm::Model
      class Recipient < Osm::Model; end    # Ensure class exists for definition of validations
      TIME_FORMAT = '%d/%m/%Y %H:%M'
      VALID_STATUSES = [:processed, :delivered, :bounced]

      # @!attribute [rw] id
      #   @return [Fixnum] the id of the email
      # @!attribute [rw] sent_at
      #   @return [Time] when the email was sent
      # @!attribute [rw] subject
      #   @return [String] the subject line of the email
      # @!attribute [rw] recipients
      #   @return [Array<Osm::DeliveryReport::Email::Recipient>]
      # @!attribute [rw] section_id
      #   @return [Fixnum] the id of the section which sent the email

      attribute :id, type: Integer
      attribute :sent_at, type: DateTime
      attribute :subject, type: String
      attribute :recipients, type: Object, default: []
      attribute :section_id, type: Integer

      if ActiveModel::VERSION::MAJOR < 4
        attr_accessible :id, :sent_at, :subject, :recipients, :section_id
      end

      validates_numericality_of :id, only_integer: true, greater_than: 0
      validates_numericality_of :section_id, only_integer: true, greater_than: 0
      validates_presence_of :sent_at
      validates_presence_of :subject
      validates :recipients, array_of: {item_type: Osm::Email::DeliveryReport::Recipient, item_valid: true}


      # @!method initialize
      #   Initialize a new DeliveryReport
      #   @param [Hash] attributes The hash of attributes (see attributes for descriptions, use Symbol of attribute name as the key)


      # Get delivery reports
      # @param [Osm::Api] api The api to use to make the request
      # @param [Osm::Section, Fixnum, #to_i] section The section (or its ID) to get the reports for
      # @!macro options_get
      # @return [Array<Osm::Email::DeliveryReport>]
      def self.get_for_section(api, section, options={})
        Osm::Model.require_access_to_section(api, section, options)
        section_id = section.to_i
        cache_key = ['email_delivery_reports', section_id]

        if !options[:no_cache] && Osm::Model.cache_exist?(api, cache_key)
          return cache_read(api, cache_key)
        end

        reports = []
        recipients = {}
        data = api.perform_query("ext/settings/emails/?action=getDeliveryReport&sectionid=#{section_id}")
        data.each do |item|
          case item['type']

          when 'email'
            # Create an Osm::Email::DeliveryReport in reports array
            id = Osm::to_i_or_nil(item['id'])
            sent_at_str, subject = item['name'].to_s.split(' - ', 2).map{ |i| i.to_s.strip }
            reports.push Osm::Email::DeliveryReport.new(
              id:         id,
              sent_at:    Time.strptime(sent_at_str, TIME_FORMAT),
              subject:    subject,
              section_id: section_id,
            )
            recipients[id] = []

          when 'oneEmail'
            # Create an Osm::Email::DeliveryReport::Email::Recipient in recipients[email_id] array
            report_id, id = item['id'].to_s.strip.split('-').map{ |i| Osm::to_i_or_nil(i) }
            status = item['status_raw'].to_sym
            status = :bounced if status.eql?(:bounce)
            member_id = Osm::to_i_or_nil(item['member_id'])
            recipients[report_id].push Osm::Email::DeliveryReport::Recipient.new(
              id:         id,
              address:    item['email'],
              status:     status,
              member_id:  member_id,
            )

          end
        end # each item in data

        # Add recipients to reports
        reports.each do |report|
          recs = recipients[report.id]
          # Set report for each recipient
          recs.each do |recipient|
            recipient.delivery_report = report
          end
          report.recipients = recs
        end

        cache_write(api, cache_key, reports)
        return reports
      end

      # Get email contents for this report
      # @param [Osm::Api] api The api to use to make the request
      # @!macro options_get
      # @return [Osm::Email::DeliveryReport::Email]
      def get_email(api, options={})
        Osm::Model.require_access_to_section(api, section_id, options)
        cache_key = ['email_delivery_reports_email', section_id, id]

        if !options[:no_cache] && Osm::Model.cache_exist?(api, cache_key)
          return cache_read(api, cache_key)
        end

        email = Osm::Email::DeliveryReport::Email.fetch_from_osm(api, section_id, id)

        cache_write(api, cache_key, email)
        return email
      end

      # @!method processed_recipients
      #   The recipients of the message with a status of :processed
      #   @return (Array<Osm::Email::DeliveryReport::Recipient>)
      # @!method processed_recipients?
      #   Whether there are recipients of the message with a status of :processed
      #   @return (Boolean)
      # @!method delivered_recipients
      #   Count the recipients of the message with a status of :delivered
      #   @return (Array<Osm::Email::DeliveryReport::Recipient>)
      # @!method delivered_recipients?
      #   Whether there are recipients of the message with a status of :delivered
      #   @return (Boolean)
      # @!method bounced_recipients
      #   Count the recipients of the message with a status of :bounced
      #   @return (Array<Osm::Email::DeliveryReport::Recipient>)
      # @!method bounced_recipients?
      #   Whether there are recipients of the message with a status of :bounced
      #   @return (Boolean)
      VALID_STATUSES.each do |attribute|
        define_method "#{attribute}_recipients" do
          recipients.select{ |r| r.status.eql?(attribute) }
        end
        define_method "#{attribute}_recipients?" do
          send("#{attribute}_recipients").any?
        end
      end


      def to_s
        "#{sent_at.strftime(TIME_FORMAT)} - #{subject}"
      end

      def <=>(another)
        result = self.sent_at <=> another.try(:sent_at)
        result = self.id <=> another.try(:id) if result.eql?(0)
        return result
      end


      class Recipient < Osm::Model
        SORT_BY = [:delivery_report, :id]
        VALID_STATUSES = Osm::Email::DeliveryReport::VALID_STATUSES.clone

        # @!attribute [rw] id
        #   @return [Fixnum] the id of the email recipient
        # @!attribute [rw] delivery_report
        #   @return [Osm::Email::DeliveryReport] the report this recipient belongs to
        # @!attribute [rw] address
        #   @return [String] the email address of the recipient
        # @!attribute [rw] status
        #   @return [Symbol] the status of the email sent to the recipient
        # @!attribute [rw] member_id
        #   @return [Fixnum] the id of the member the email was sent to

        attribute :id, type: Integer
        attribute :delivery_report, type: Object
        attribute :address, type: String
        attribute :status, type: Object, default: :unknown
        attribute :member_id, type: Integer

        if ActiveModel::VERSION::MAJOR < 4
          attr_accessible :id, :delivery_report, :address, :status, :member_id
        end

        validates_numericality_of :id, only_integer: true, greater_than: 0
        validates_numericality_of :member_id, only_integer: true, greater_than: 0
        validates_presence_of :address
        validates_presence_of :delivery_report
        validates_inclusion_of :status, :in => VALID_STATUSES


        # @!method initialize
        #   Initialize a new DeliveryReport::Recipient
        #   @param [Hash] attributes The hash of attributes (see attributes for descriptions, use Symbol of attribute name as the key)


        # Get email contents for this recipient
        # @param [Osm::Api] api The api to use to make the request
        # @!macro options_get
        # @return [Osm::Email::DeliveryReport::Email]
        def get_email(api, options={})
          Osm::Model.require_access_to_section(api, delivery_report.section_id, options)
          cache_key = ['email_delivery_reports_email', delivery_report.section_id, delivery_report.id, id]

          if !options[:no_cache] && Osm::Model.cache_exist?(api, cache_key)
            return cache_read(api, cache_key)
          end

          email = Osm::Email::DeliveryReport::Email.fetch_from_osm(api, delivery_report.section_id, delivery_report.id, member_id, address)

          cache_write(api, cache_key, email)
          return email
        end

        # Unblock email address from being sent emails
        # @param [Osm::Api] api The api to use to make the request
        # @param [Boolean] whether removal was successful
        def unblock_address(api)
          return true unless bounced?

          data = api.perform_query('ext/settings/emails/?action=unBlockEmail', {
            'section_id' => delivery_report.section_id,
            'email'      => address,
            'email_id'   => delivery_report.id
          })

          if data.is_a?(Hash)
            fail Osm::Error, data['error'].to_s unless data['error'].nil?
            return !!data['status']
          end
          return false
        end

        # @!method processed?
        #   Check if the email to this recipient has been processes
        #   @return (Boolean)
        # @!method delivered?
        #   Check if the email to this recipient was delivered
        #   @return (Boolean)
        # @!method bounced?
        #   Check if the email to this recipient bounced
        #   @return (Boolean)
        VALID_STATUSES.each do |attribute|
          define_method "#{attribute}?" do
            status.eql?(attribute)
          end
        end

        def to_s
          "#{address} - #{status}"
        end

        def inspect
          Osm::inspect_instance(self, {replace_with: {'delivery_report' => :id}})
        end

      end # class Osm::Email::DeliveryReport::Recipient


      class Email < Osm::Model
        SORT_BY = [:subject, :from, :to]

        # @!attribute [rw] to
        #   @return [String] who the email was sent to (possibly nil)
        # @!attribute [rw] from
        #   @return [String] who the email was sent from
        # @!attribute [rw] subject
        #   @return [String] the subject of the email
        # @!attribute [rw] body
        #   @return [String] the body of the email

        attribute :to, type: String
        attribute :from, type: String
        attribute :subject, type: String
        attribute :body, type: String

        if ActiveModel::VERSION::MAJOR < 4
          attr_accessible :to, :from, :subject, :body
        end

        validates_presence_of :to
        validates_presence_of :from
        validates_presence_of :subject
        validates_presence_of :body


        # @!method initialize
        #   Initialize a new DeliveryReport::Email
        #   @param [Hash] attributes The hash of attributes (see attributes for descriptions, use Symbol of attribute name as the key)


        def to_s
          "To: #{to}\nFrom: #{from}\n\n#{subject}\n\n#{body.gsub(/<\/?[^>]*>/, '')}"
        end

        protected
        # Get email contents
        # @param [Osm::Api] api The api to use to make the request
        # @param [Integer] section_id
        # @param [Integer] email_id
        # @param [String] email_address
        # @return [Osm::Email::DeliveryReport::Email]
        def self.fetch_from_osm(api, section_id, email_id, member_id=nil, email_address='')
          Osm::Model.require_access_to_section(api, section_id)

          data = api.perform_query("ext/settings/emails/?action=getSentEmail&section_id=#{section_id}&email_id=#{email_id}&email=#{email_address}&member_id=#{member_id}")
          fail Osm::Error, "Unexpected format for response - got a #{data.class}" unless data.is_a?(Hash)
          fail Osm::Error, data['error'].to_s unless data['status']
          fail Osm::Error, "Unexpected format for meta data - got a #{data.class}" unless data['data'].is_a?(Hash)

          body = api.perform_query("ext/settings/emails/?action=getSentEmailContent&section_id=#{section_id}&email_id=#{email_id}&email=#{email_address}&member_id=#{member_id}", {}, true)
          fail Osm::Error, data if data.eql?('Email not found')

          email_data = data['data']
          new(
            to:       email_data['to'],
            from:     email_data['from'],
            subject:  email_data['subject'],
            body:     body,
          )
        end

      end # class Osm::Email::DeliveryReport::Email

    end # class Osm::Email::DeliveryReport

  end # class Osm::Email

end
