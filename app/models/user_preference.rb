# frozen_string_literal: true

class UserPreference < MainClusterwide::ApplicationRecord
  # We could use enums, but Rails 4 doesn't support multiple
  # enum options with same name for multiple fields, also it creates
  # extra methods that aren't really needed here.
  NOTES_FILTERS = { all_notes: 0, only_comments: 1, only_activity: 2 }.freeze
  TIME_DISPLAY_FORMATS = { system: 0, non_iso_format: 1, iso_format: 2 }.freeze

  belongs_to :user
  belongs_to :home_organization, class_name: "Organizations::Organization", optional: true

  scope :with_user, -> { joins(:user) }
  scope :gitpod_enabled, -> { where(gitpod_enabled: true) }

  validates :issue_notes_filter, :merge_request_notes_filter, inclusion: { in: NOTES_FILTERS.values }, presence: true
  validates :tab_width, numericality: {
    only_integer: true,
    greater_than_or_equal_to: Gitlab::TabWidth::MIN,
    less_than_or_equal_to: Gitlab::TabWidth::MAX
  }
  validates :diffs_deletion_color, :diffs_addition_color,
    format: { with: ColorsHelper::HEX_COLOR_PATTERN },
    allow_blank: true

  validates :time_display_relative, allow_nil: false, inclusion: { in: [true, false] }
  validates :render_whitespace_in_code, allow_nil: false, inclusion: { in: [true, false] }
  validates :pass_user_identities_to_ci_jwt, allow_nil: false, inclusion: { in: [true, false] }

  validates :pinned_nav_items, json_schema: { filename: 'pinned_nav_items' }

  validates :time_display_format, inclusion: { in: TIME_DISPLAY_FORMATS.values }, presence: true

  validate :user_belongs_to_home_organization, if: :home_organization_changed?

  attribute :tab_width, default: -> { Gitlab::TabWidth::DEFAULT }
  attribute :time_display_relative, default: true
  attribute :time_display_format, default: 0
  attribute :render_whitespace_in_code, default: false
  attribute :project_shortcut_buttons, default: true
  attribute :keyboard_shortcuts_enabled, default: true
  attribute :use_web_ide_extension_marketplace, default: false

  enum visibility_pipeline_id_type: { id: 0, iid: 1 }

  class << self
    def notes_filters
      {
        s_('Notes|Show all activity') => NOTES_FILTERS[:all_notes],
        s_('Notes|Show comments only') => NOTES_FILTERS[:only_comments],
        s_('Notes|Show history only') => NOTES_FILTERS[:only_activity]
      }
    end
  end

  def user_belongs_to_home_organization
    # If we don't ignore the default organization id below then all users need to have their corresponding entry
    # with default organization id as organization id in the `organization_users` table.
    # Otherwise, the user won't be able to the default organization as the home organization.
    return if home_organization_id == Organizations::Organization::DEFAULT_ORGANIZATION_ID
    return if user.user_belongs_to_organization?(home_organization_id)

    errors.add(:user, _("is not part of the given organization"))
  end

  def set_notes_filter(filter_id, issuable)
    # No need to update the column if the value is already set.
    if filter_id && NOTES_FILTERS.value?(filter_id)
      field = notes_filter_field_for(issuable)
      self[field] = filter_id

      save if attribute_changed?(field)
    end

    notes_filter_for(issuable)
  end

  # Returns the current discussion filter for a given issuable
  # or issuable type.
  def notes_filter_for(resource)
    self[notes_filter_field_for(resource)]
  end

  def tab_width
    read_attribute(:tab_width) || self.class.column_defaults['tab_width']
  end

  def tab_width=(value)
    if value.nil?
      default = self.class.column_defaults['tab_width']
      super(default)
    else
      super(value)
    end
  end

  class << self
    def time_display_formats
      {
        s_('Time Display|System') => TIME_DISPLAY_FORMATS[:system],
        s_('Time Display|12-hour: 2:34 PM') => TIME_DISPLAY_FORMATS[:non_iso_format],
        s_('Time Display|24-hour: 14:34') => TIME_DISPLAY_FORMATS[:iso_format]
      }
    end
  end

  def time_display_relative
    value = read_attribute(:time_display_relative)
    return value unless value.nil?

    self.class.column_defaults['time_display_relative']
  end

  def time_display_relative=(value)
    if value.nil?
      default = self.class.column_defaults['time_display_relative']
      super(default)
    else
      super(value)
    end
  end

  def render_whitespace_in_code
    value = read_attribute(:render_whitespace_in_code)
    return value unless value.nil?

    self.class.column_defaults['render_whitespace_in_code']
  end

  def render_whitespace_in_code=(value)
    if value.nil?
      default = self.class.column_defaults['render_whitespace_in_code']
      super(default)
    else
      super(value)
    end
  end

  private

  def notes_filter_field_for(resource)
    field_key =
      if resource.is_a?(Issuable)
        resource.model_name.param_key
      else
        resource
      end

    "#{field_key}_notes_filter"
  end
end

UserPreference.prepend_mod_with('UserPreference')
