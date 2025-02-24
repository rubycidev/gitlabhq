<script>
import Participants from '~/sidebar/components/participants/participants.vue';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import {
  WIDGET_TYPE_ASSIGNEES,
  WIDGET_TYPE_HEALTH_STATUS,
  WIDGET_TYPE_HIERARCHY,
  WIDGET_TYPE_ITERATION,
  WIDGET_TYPE_LABELS,
  WIDGET_TYPE_MILESTONE,
  WIDGET_TYPE_PARTICIPANTS,
  WIDGET_TYPE_PROGRESS,
  WIDGET_TYPE_START_AND_DUE_DATE,
  WIDGET_TYPE_WEIGHT,
  WIDGET_TYPE_COLOR,
  WORK_ITEM_TYPE_VALUE_KEY_RESULT,
  WORK_ITEM_TYPE_VALUE_OBJECTIVE,
  WORK_ITEM_TYPE_VALUE_TASK,
} from '../constants';
import WorkItemAssigneesInline from './work_item_assignees_inline.vue';
import WorkItemAssigneesWithEdit from './work_item_assignees_with_edit.vue';
import WorkItemDueDateInline from './work_item_due_date_inline.vue';
import WorkItemDueDateWithEdit from './work_item_due_date_with_edit.vue';
import WorkItemLabels from './work_item_labels.vue';
import WorkItemMilestoneInline from './work_item_milestone_inline.vue';
import WorkItemMilestoneWithEdit from './work_item_milestone_with_edit.vue';
import WorkItemParentInline from './work_item_parent_inline.vue';
import WorkItemParent from './work_item_parent_with_edit.vue';

export default {
  components: {
    Participants,
    WorkItemLabels,
    WorkItemMilestoneInline,
    WorkItemMilestoneWithEdit,
    WorkItemAssigneesInline,
    WorkItemAssigneesWithEdit,
    WorkItemDueDateInline,
    WorkItemDueDateWithEdit,
    WorkItemParent,
    WorkItemParentInline,
    WorkItemWeightInline: () =>
      import('ee_component/work_items/components/work_item_weight_inline.vue'),
    WorkItemWeight: () =>
      import('ee_component/work_items/components/work_item_weight_with_edit.vue'),
    WorkItemProgress: () => import('ee_component/work_items/components/work_item_progress.vue'),
    WorkItemIterationInline: () =>
      import('ee_component/work_items/components/work_item_iteration_inline.vue'),
    WorkItemIteration: () =>
      import('ee_component/work_items/components/work_item_iteration_with_edit.vue'),
    WorkItemHealthStatus: () =>
      import('ee_component/work_items/components/work_item_health_status_with_edit.vue'),
    WorkItemHealthStatusInline: () =>
      import('ee_component/work_items/components/work_item_health_status_inline.vue'),
    WorkItemColorInline: () =>
      import('ee_component/work_items/components/work_item_color_inline.vue'),
  },
  mixins: [glFeatureFlagMixin()],
  props: {
    fullPath: {
      type: String,
      required: true,
    },
    workItem: {
      type: Object,
      required: true,
    },
  },
  computed: {
    workItemType() {
      return this.workItem.workItemType?.name;
    },
    canUpdate() {
      return this.workItem?.userPermissions?.updateWorkItem;
    },
    canDelete() {
      return this.workItem?.userPermissions?.deleteWorkItem;
    },
    workItemAssignees() {
      return this.isWidgetPresent(WIDGET_TYPE_ASSIGNEES);
    },
    workItemLabels() {
      return this.isWidgetPresent(WIDGET_TYPE_LABELS);
    },
    workItemDueDate() {
      return this.isWidgetPresent(WIDGET_TYPE_START_AND_DUE_DATE);
    },
    workItemWeight() {
      return this.isWidgetPresent(WIDGET_TYPE_WEIGHT);
    },
    workItemParticipants() {
      return this.isWidgetPresent(WIDGET_TYPE_PARTICIPANTS);
    },
    workItemProgress() {
      return this.isWidgetPresent(WIDGET_TYPE_PROGRESS);
    },
    workItemIteration() {
      return this.isWidgetPresent(WIDGET_TYPE_ITERATION);
    },
    workItemHealthStatus() {
      return this.isWidgetPresent(WIDGET_TYPE_HEALTH_STATUS);
    },
    workItemHierarchy() {
      return this.isWidgetPresent(WIDGET_TYPE_HIERARCHY);
    },
    workItemMilestone() {
      return this.isWidgetPresent(WIDGET_TYPE_MILESTONE);
    },
    showWorkItemParent() {
      return (
        this.workItemType === WORK_ITEM_TYPE_VALUE_OBJECTIVE ||
        this.workItemType === WORK_ITEM_TYPE_VALUE_KEY_RESULT ||
        this.workItemType === WORK_ITEM_TYPE_VALUE_TASK
      );
    },
    workItemParent() {
      return this.isWidgetPresent(WIDGET_TYPE_HIERARCHY)?.parent;
    },
    workItemColor() {
      return this.isWidgetPresent(WIDGET_TYPE_COLOR);
    },
  },
  methods: {
    isWidgetPresent(type) {
      return this.workItem?.widgets?.find((widget) => widget.type === type);
    },
  },
};
</script>

<template>
  <div class="work-item-attributes-wrapper">
    <template v-if="workItemAssignees">
      <work-item-assignees-with-edit
        v-if="glFeatures.workItemsMvc2"
        class="gl-mb-5"
        :can-update="canUpdate"
        :full-path="fullPath"
        :work-item-id="workItem.id"
        :assignees="workItemAssignees.assignees.nodes"
        :allows-multiple-assignees="workItemAssignees.allowsMultipleAssignees"
        :work-item-type="workItemType"
        :can-invite-members="workItemAssignees.canInviteMembers"
        @error="$emit('error', $event)"
      />
      <work-item-assignees-inline
        v-else
        :can-update="canUpdate"
        :full-path="fullPath"
        :work-item-id="workItem.id"
        :assignees="workItemAssignees.assignees.nodes"
        :allows-multiple-assignees="workItemAssignees.allowsMultipleAssignees"
        :work-item-type="workItemType"
        :can-invite-members="workItemAssignees.canInviteMembers"
        @error="$emit('error', $event)"
      />
    </template>
    <work-item-labels
      v-if="workItemLabels"
      :can-update="canUpdate"
      :full-path="fullPath"
      :work-item-id="workItem.id"
      :work-item-iid="workItem.iid"
      @error="$emit('error', $event)"
    />
    <template v-if="workItemDueDate">
      <work-item-due-date-with-edit
        v-if="glFeatures.workItemsMvc2"
        :can-update="canUpdate"
        :due-date="workItemDueDate.dueDate"
        :start-date="workItemDueDate.startDate"
        :work-item-type="workItemType"
        :work-item="workItem"
        @error="$emit('error', $event)"
      />
      <work-item-due-date-inline
        v-else
        :can-update="canUpdate"
        :due-date="workItemDueDate.dueDate"
        :start-date="workItemDueDate.startDate"
        :work-item-id="workItem.id"
        :work-item-type="workItemType"
        @error="$emit('error', $event)"
      />
    </template>
    <template v-if="workItemMilestone">
      <work-item-milestone-with-edit
        v-if="glFeatures.workItemsMvc2"
        class="gl-mb-5"
        :full-path="fullPath"
        :work-item-id="workItem.id"
        :work-item-milestone="workItemMilestone.milestone"
        :work-item-type="workItemType"
        :can-update="canUpdate"
        @error="$emit('error', $event)"
      />
      <work-item-milestone-inline
        v-else
        class="gl-mb-5"
        :full-path="fullPath"
        :work-item-id="workItem.id"
        :work-item-milestone="workItemMilestone.milestone"
        :work-item-type="workItemType"
        :can-update="canUpdate"
        @error="$emit('error', $event)"
      />
    </template>
    <template v-if="workItemWeight">
      <work-item-weight
        v-if="glFeatures.workItemsMvc2"
        class="gl-mb-5"
        :can-update="canUpdate"
        :weight="workItemWeight.weight"
        :work-item-id="workItem.id"
        :work-item-iid="workItem.iid"
        :work-item-type="workItemType"
        @error="$emit('error', $event)"
      />
      <work-item-weight-inline
        v-else
        class="gl-mb-5"
        :can-update="canUpdate"
        :weight="workItemWeight.weight"
        :work-item-id="workItem.id"
        :work-item-iid="workItem.iid"
        :work-item-type="workItemType"
        @error="$emit('error', $event)"
      />
    </template>
    <work-item-progress
      v-if="workItemProgress"
      class="gl-mb-5"
      :can-update="canUpdate"
      :progress="workItemProgress.progress"
      :work-item-id="workItem.id"
      :work-item-type="workItemType"
      @error="$emit('error', $event)"
    />
    <template v-if="workItemIteration">
      <work-item-iteration
        v-if="glFeatures.workItemsMvc2"
        class="gl-mb-5"
        :full-path="fullPath"
        :iteration="workItemIteration.iteration"
        :can-update="canUpdate"
        :work-item-id="workItem.id"
        :work-item-iid="workItem.iid"
        :work-item-type="workItemType"
        @error="$emit('error', $event)"
      />
      <work-item-iteration-inline
        v-else
        class="gl-mb-5"
        :full-path="fullPath"
        :iteration="workItemIteration.iteration"
        :can-update="canUpdate"
        :work-item-id="workItem.id"
        :work-item-iid="workItem.iid"
        :work-item-type="workItemType"
        @error="$emit('error', $event)"
      />
    </template>
    <template v-if="workItemHealthStatus">
      <work-item-health-status
        v-if="glFeatures.workItemsMvc2"
        class="gl-mb-5"
        :health-status="workItemHealthStatus.healthStatus"
        :can-update="canUpdate"
        :work-item-id="workItem.id"
        :work-item-iid="workItem.iid"
        :work-item-type="workItemType"
        @error="$emit('error', $event)"
      />
      <work-item-health-status-inline
        v-else
        class="gl-mb-5"
        :health-status="workItemHealthStatus.healthStatus"
        :can-update="canUpdate"
        :work-item-id="workItem.id"
        :work-item-iid="workItem.iid"
        :work-item-type="workItemType"
        @error="$emit('error', $event)"
      />
    </template>
    <template v-if="showWorkItemParent">
      <work-item-parent
        v-if="glFeatures.workItemsMvc2"
        class="gl-mb-5"
        :can-update="canUpdate"
        :work-item-id="workItem.id"
        :work-item-type="workItemType"
        :parent="workItemParent"
        @error="$emit('error', $event)"
      />
      <work-item-parent-inline
        v-else
        class="gl-mb-5"
        :can-update="canUpdate"
        :work-item-id="workItem.id"
        :work-item-type="workItemType"
        :parent="workItemParent"
        @error="$emit('error', $event)"
      />
    </template>
    <work-item-color-inline
      v-if="workItemColor"
      class="gl-mb-5"
      :work-item="workItem"
      :can-update="canUpdate"
      @error="$emit('error', $event)"
    />
    <participants
      v-if="workItemParticipants && glFeatures.workItemsMvc"
      class="gl-mb-5"
      :number-of-less-participants="10"
      :participants="workItemParticipants.participants.nodes"
    />
  </div>
</template>
