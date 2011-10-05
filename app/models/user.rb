class User < ActiveRecord::Base
  authenticates_with_sorcery!  
  
  attr_accessible :name, :email_address, :password, :password_confirmation

  before_save :email_is_lowercase

  validates_presence_of :name

  validates_presence_of :email_address
  validates_uniqueness_of :email_address
  validates_format_of :email_address, :with => /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/i, :message => 'does not look like an email address'
  
  validates_presence_of :password, :on => :create
  validates_confirmation_of :password, :on => :create
  validates_presence_of :password, :unless => Proc.new { |record| record.send(sorcery_config.password_attribute_name).nil? }
  validates_confirmation_of :password, :unless => Proc.new { |record| record.send(sorcery_config.password_attribute_name).nil? }
  validates_length_of :password, :minimum=>8, :unless => Proc.new { |record| record.send(sorcery_config.password_attribute_name).nil? }
  validate :password_different_types, :password_not_email_address, :password_not_name, :unless => Proc.new { |record| record.send(sorcery_config.password_attribute_name).nil? }


  def change_password!(new_password, new_password_confirmation=new_password)
    self.password = new_password
    self.password_confirmation = new_password_confirmation

    if valid? && errors.none?
      return super(new_password)
    else
      return false
    end
  end

  
  private
  # TODO make password_complexity - is length ^ alphabet_size > threshold ???
  def password_different_types
    require_different_types = 2
    pass = send(sorcery_config.password_attribute_name)
    lower_case = pass.gsub(/[^a-z]/, '').length
    upper_case = pass.gsub(/[^A-Z]/, '').length
    numeric = pass.gsub(/[^0-9]/, '').length
    other = pass.length - (lower_case + upper_case + numeric)

    types = (lower_case == 0) ? 0 : 1
    types += (upper_case == 0) ? 0 : 1
    types += (numeric == 0) ? 0 : 1
    types += (other == 0) ? 0 : 1

    if types < require_different_types
      errors.add(:password, "does not use at least #{require_different_types} different types of character, you used #{types}")
    end
  end
  
  def password_not_email_address
    if send(sorcery_config.password_attribute_name).downcase.strip.eql?(email_address.downcase.strip)
      errors.add(:password, 'is not allowed to be your email address')
    end
  end

  def password_not_name
    block_size = 2
    name = self.name.downcase
    pass = send(sorcery_config.password_attribute_name).downcase
    for i in 0..(name.length - block_size)
      find = name[i..(i+(block_size-1))]
      if pass.include?(find)
        errors.add(:password, 'is not allowed to contain part of your name')
      end
    end
  end

  def email_is_lowercase
    email_address.downcase!
  end

  public
  # fix sorcery bug involving sqlite
  def self.load_from_token(token, token_attr_name, token_expiration_date_attr)
    return nil if token.blank?
    user = User.find_by_sql("SELECT * from users WHERE trim(#{token_attr_name}) = '#{token}'").first
    if !user.blank? && !user.send(token_expiration_date_attr).nil?
      return Time.now.utc < user.send(token_expiration_date_attr) ? user : nil
    end
    user
  end
  
end
