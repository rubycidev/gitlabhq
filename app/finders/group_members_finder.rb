# frozen_string_literal: true

class GroupMembersFinder < UnionFinder
  RELATIONS = %i[direct inherited descendants shared_from_groups].freeze
  DEFAULT_RELATIONS = %i[direct inherited].freeze
  INVALID_RELATION_TYPE_ERROR_MSG = "is not a valid relation type. Valid relation types are #{RELATIONS.join(', ')}."

  RELATIONS_DESCRIPTIONS = {
    direct: 'Members in the group itself',
    inherited: "Members in the group's ancestor groups",
    descendants: "Members in the group's subgroups",
    shared_from_groups: "Invited group's members"
  }.freeze

  include CreatedAtFilter

  # Params can be any of the following:
  #   two_factor: string. 'enabled' or 'disabled' are returning different set of data, other values are not effective.
  #   sort:       string
  #   search:     string
  #   created_after: datetime
  #   created_before: datetime
  #   non_invite:      boolean
  #   with_custom_role: boolean
  attr_reader :params

  def initialize(group, user = nil, params: {})
    @group = group
    @user = user
    @params = params
  end

  def execute(include_relations: DEFAULT_RELATIONS)
    groups = groups_by_relations(include_relations)

    members = all_group_members(groups)
    members = members.distinct_on_user_with_max_access_level if static_roles_only?

    filter_members(members)
  end

  private

  attr_reader :user, :group

  def groups_by_relations(include_relations)
    check_relation_arguments!(include_relations)

    related_groups = {}

    related_groups[:direct] = Group.by_id(group.id) if include_relations.include?(:direct)
    related_groups[:inherited] = group.ancestors if include_relations.include?(:inherited)
    related_groups[:descendants] = group.descendants if include_relations.include?(:descendants)

    if include_relations.include?(:shared_from_groups)
      related_groups[:shared_from_groups] =
        if group.member?(user) && Feature.enabled?(:webui_members_inherited_users, user)
          Group.shared_into_ancestors(group)
        else
          Group.shared_into_ancestors(group).public_or_visible_to_user(user)
        end
    end

    related_groups
  end

  def filter_members(members)
    members = members.search(params[:search]) if params[:search].present?
    members = members.sort_by_attribute(params[:sort]) if params[:sort].present?

    members = members.filter_by_2fa(params[:two_factor]) if params[:two_factor].present? && can_manage_members
    members = members.by_access_level(params[:access_levels]) if params[:access_levels].present?

    members = filter_by_user_type(members)
    members = apply_additional_filters(members)

    members = by_created_at(members)
    members = members.non_invite if params[:non_invite]

    members
  end

  def can_manage_members
    Ability.allowed?(user, :admin_group_member, group)
  end

  def group_members_list
    group.members
  end

  def all_group_members(groups)
    members_of_groups(groups).non_minimal_access
  end

  def members_of_groups(groups)
    groups_except_from_sharing = groups.except(:shared_from_groups).values
    groups_as_union = find_union(groups_except_from_sharing, Group)
    members = GroupMember.non_request.of_groups(groups_as_union)

    shared_from_groups = groups[:shared_from_groups]
    return members if shared_from_groups.nil?

    shared_members = GroupMember.non_request.of_groups(shared_from_groups)
    members_shared_with_group_access = members_shared_with_group_access(shared_members)

    # `members` and `members_shared_with_group_access` should have even select values
    find_union([members.select(group_member_columns), members_shared_with_group_access], GroupMember)
  end

  def members_shared_with_group_access(shared_members)
    group_group_link_table = GroupGroupLink.arel_table
    group_member_table = GroupMember.arel_table

    member_columns = group_member_columns.map do |column_name|
      if column_name == 'access_level'
        args = [group_group_link_table[:group_access], group_member_table[:access_level]]
        smallest_value_arel(args, 'access_level')
      else
        group_member_table[column_name]
      end
    end

    # rubocop:disable CodeReuse/ActiveRecord
    shared_members
      .joins("LEFT OUTER JOIN group_group_links ON members.source_id = group_group_links.shared_with_group_id")
      .select(member_columns)
    # rubocop:enable CodeReuse/ActiveRecord
  end

  def group_member_columns
    GroupMember.column_names
  end

  def smallest_value_arel(args, column_alias)
    Arel::Nodes::As.new(Arel::Nodes::NamedFunction.new('LEAST', args), Arel::Nodes::SqlLiteral.new(column_alias))
  end

  def check_relation_arguments!(include_relations)
    return if (include_relations - RELATIONS).empty?

    raise ArgumentError, "#{(include_relations - RELATIONS).first} #{INVALID_RELATION_TYPE_ERROR_MSG}"
  end

  def filter_by_user_type(members)
    return members unless params[:user_type] && can_manage_members

    members.filter_by_user_type(params[:user_type])
  end

  def apply_additional_filters(members)
    # overridden in EE to include additional filtering conditions.
    members
  end

  def static_roles_only?
    true
  end
end

GroupMembersFinder.prepend_mod_with('GroupMembersFinder')
