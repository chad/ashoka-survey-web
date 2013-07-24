class Response < ActiveRecord::Base

  MAX_PAGE_SIZE = 50

  module Status
    COMPLETE = "complete"
    INCOMPLETE = "incomplete"
  end

  belongs_to :survey
  has_many :answers, :dependent => :destroy
  has_many :records, :dependent => :destroy

  accepts_nested_attributes_for :answers

  attr_accessible :survey, :answers_attributes, :mobile_id, :survey_id, :status, :updated_at,
                  :latitude, :longitude, :ip_address, :state, :comment, :blank

  validates_presence_of :survey_id
  validates_presence_of :organization_id, :user_id, :unless => :survey_public?
  validates_associated :answers
  before_save :geocode, :reverse_geocode, :on => :create

  delegate :to_json_with_answers_and_choices, :to => :response_serializer
  delegate :questions, :to => :survey
  delegate :public?, :to => :survey, :prefix => true, :allow_nil => true

  reverse_geocoded_by :latitude, :longitude, :address => :location
  geocoded_by :ip_address, :latitude => :latitude, :longitude => :longitude
  acts_as_gmappable :lat => :latitude, :lng => :longitude, :check_process => false, :process_geocoding => false

  scope :earliest_first, order('updated_at')
  scope :completed, where(:status => Status::COMPLETE)

  before_save(:set_completed_date)

  validate :completed_response_cannot_be_marked_incomplete

  def self.created_between(from, to)
    where(:created_at => from..to)
  end

  def self.page_size(params_page_size=nil)
    if params_page_size.blank?
      MAX_PAGE_SIZE
    else
      [params_page_size.to_i, MAX_PAGE_SIZE].min
    end
  end

  def gmaps4rails_infowindow
    location
  end

  def last_update
    [answers.maximum('answers.updated_at'),
     self.updated_at].compact.max
  end

  def complete
    update_column(:status, Status::COMPLETE)
  end

  def incomplete
    update_column(:status, Status::INCOMPLETE)
  end

  def complete?
    status == Status::COMPLETE
  end

  def incomplete?
    status == Status::INCOMPLETE
  end

  def public?
    survey_public?
  end

  def update_valid_response_from_params(response_params)
    return unless response_params.present?
    begin
      transaction do
        update_attributes!(:status => response_params[:status]) if response_params[:status]
        update_attributes!(response_params)
      end
      true
    rescue ActiveRecord::RecordInvalid
      false
    end
  end

  def create_valid_response_from_params(response_params)
    transaction do
      update_attributes(response_params.except(:answers_attributes)) # Response isn't created before the answers, so we need to create the answers after this.
      update_attributes({:answers_attributes => response_params[:answers_attributes]}) if valid?
      update_records
      if invalid?
        destroy
        false
      else
        true
      end
    end
  end

  def set(survey_id, user_id, organization_id, session_token)
    self.survey_id = survey_id
    self.organization_id = organization_id
    self.user_id = user_id
    self.session_token = session_token
  end

  def create_blank_answers
    survey.first_level_elements.each { |element| element.create_blank_answers(:response_id => id) }
  end

  def sorted_answers
    survey.first_level_elements.map { |element| element.sorted_answers_for_response(id) }.flatten
  end

  def select_new_answers(answers_attributes)
    answers_attributes.reject do |_, answer_attributes|
      existing_answer = answers.find_by_id(answer_attributes['id'])
      existing_answer && (Time.parse(answer_attributes['updated_at']) < existing_answer.updated_at)
    end
  end

  def merge_status(params)
    return unless params[:updated_at]
    if Time.parse(params[:updated_at]) > updated_at
      case params[:status]
        when Status::COMPLETE
          complete
        when Status::INCOMPLETE
          incomplete
      end
    end
  end

  def update_records
    records = answers.includes(:record).map(&:record).compact.uniq
    records.each do |record|
      record.update_attributes(:response_id => self.id) unless record.response_id
    end
  end

  def response_serializer
    ResponseSerializer.new(self)
  end

  private
  def completed_response_cannot_be_marked_incomplete
    if self.status_was == Status::COMPLETE && self.status == Status::INCOMPLETE
      errors.add(:status, I18n.t("activerecord.errors.models.response.incomplete_to_complete_error"))
    end
  end

  def set_completed_date
    if status == Status::COMPLETE && self.completed_at.nil?
      self.completed_at = Time.now
    end
  end

  def five_first_level_answers
    answers.find_all { |answer| answer.question.first_level? }[0..4]
  end
end
