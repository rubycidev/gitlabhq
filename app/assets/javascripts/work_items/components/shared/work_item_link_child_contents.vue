<script>
import {
  GlLabel,
  GlLink,
  GlIcon,
  GlButton,
  GlAvatar,
  GlAvatarLink,
  GlAvatarsInline,
  GlTooltip,
  GlTooltipDirective,
} from '@gitlab/ui';
import { __, s__, sprintf } from '~/locale';
import { isScopedLabel } from '~/lib/utils/common_utils';
import RichTimestampTooltip from '~/vue_shared/components/rich_timestamp_tooltip.vue';
import WorkItemLinkChildMetadata from 'ee_else_ce/work_items/components/shared/work_item_link_child_metadata.vue';
import {
  STATE_OPEN,
  WIDGET_TYPE_PROGRESS,
  WIDGET_TYPE_HIERARCHY,
  WIDGET_TYPE_HEALTH_STATUS,
  WIDGET_TYPE_MILESTONE,
  WIDGET_TYPE_ASSIGNEES,
  WIDGET_TYPE_LABELS,
  WORK_ITEM_NAME_TO_ICON_MAP,
} from '../../constants';

export default {
  i18n: {
    confidential: __('Confidential'),
    created: __('Created'),
    closed: __('Closed'),
    remove: s__('WorkItem|Remove'),
  },
  components: {
    GlLabel,
    GlLink,
    GlIcon,
    GlButton,
    GlAvatar,
    GlAvatarLink,
    GlAvatarsInline,
    GlTooltip,
    RichTimestampTooltip,
    WorkItemLinkChildMetadata,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    childItem: {
      type: Object,
      required: true,
    },
    canUpdate: {
      type: Boolean,
      required: true,
    },
    showLabels: {
      type: Boolean,
      required: false,
      default: true,
    },
    workItemFullPath: {
      type: String,
      required: false,
      default: '',
    },
  },
  computed: {
    labels() {
      return this.metadataWidgets[WIDGET_TYPE_LABELS]?.labels?.nodes || [];
    },
    metadataWidgets() {
      return this.childItem.widgets?.reduce((metadataWidgets, widget) => {
        // Skip Hierarchy widget as it is not part of metadata.
        if (widget.type && widget.type !== WIDGET_TYPE_HIERARCHY) {
          // eslint-disable-next-line no-param-reassign
          metadataWidgets[widget.type] = widget;
        }
        return metadataWidgets;
      }, {});
    },
    assignees() {
      return this.metadataWidgets[WIDGET_TYPE_ASSIGNEES]?.assignees?.nodes || [];
    },
    assigneesCollapsedTooltip() {
      if (this.assignees.length > 2) {
        return sprintf(s__('WorkItem|%{count} more assignees'), {
          count: this.assignees.length - 2,
        });
      }
      return '';
    },
    allowsScopedLabels() {
      return this.metadataWidgets[WIDGET_TYPE_LABELS]?.allowsScopedLabels;
    },
    isChildItemOpen() {
      return this.childItem.state === STATE_OPEN;
    },
    iconName() {
      return WORK_ITEM_NAME_TO_ICON_MAP[this.childItemType];
    },
    statusIconName() {
      return this.isChildItemOpen ? 'issue-open-m' : 'issue-close';
    },
    childItemType() {
      return this.childItem.workItemType.name;
    },
    statusIconClass() {
      return this.isChildItemOpen ? 'gl-text-green-500' : 'gl-text-blue-500';
    },
    stateTimestamp() {
      return this.isChildItemOpen ? this.childItem.createdAt : this.childItem.closedAt;
    },
    stateTimestampTypeText() {
      return this.isChildItemOpen ? this.$options.i18n.created : this.$options.i18n.closed;
    },
    hasMetadata() {
      if (this.metadataWidgets) {
        return (
          Number.isInteger(this.metadataWidgets[WIDGET_TYPE_PROGRESS]?.progress) ||
          Boolean(this.metadataWidgets[WIDGET_TYPE_HEALTH_STATUS]?.healthStatus) ||
          Boolean(this.metadataWidgets[WIDGET_TYPE_MILESTONE]?.milestone) ||
          this.metadataWidgets[WIDGET_TYPE_ASSIGNEES]?.assignees?.nodes.length > 0 ||
          this.metadataWidgets[WIDGET_TYPE_LABELS]?.labels?.nodes.length > 0
        );
      }
      return false;
    },
    showRemove() {
      return this.canUpdate;
    },
    displayLabels() {
      return this.showLabels && this.labels.length;
    },
    displayReference() {
      // The reference is replaced by work item fullpath in case the project and group are same.
      // e.g., gitlab-org/gitlab-test#45 will be shown as #45
      return this.childItem.reference.replace(new RegExp(`${this.workItemFullPath}(?!-)`, 'g'), '');
    },
  },
  methods: {
    showScopedLabel(label) {
      return isScopedLabel(label) && this.allowsScopedLabels;
    },
  },
};
</script>

<template>
  <div
    class="item-body work-item-link-child gl-relative gl-display-flex gl-flex-grow-1 gl-overflow-break-word gl-min-w-0 gl-rounded-base gl-p-3 gl-gap-3"
    data-testid="links-child"
  >
    <div ref="stateIcon" class="gl-cursor-help">
      <gl-icon class="gl-text-secondary" :name="iconName" />
      <gl-tooltip :target="() => $refs.stateIcon">
        {{ childItemType }}
      </gl-tooltip>
    </div>
    <div class="gl-display-flex gl-flex-direction-column gl-flex-grow-1 gl-flex-wrap gl-min-w-0">
      <div
        class="gl-display-flex gl-flex-wrap flex-xl-nowrap gl-justify-content-space-between gl-gap-3 gl-min-w-0 gl-mb-2"
      >
        <div class="item-title gl-min-w-0">
          <span v-if="childItem.confidential">
            <gl-icon
              v-gl-tooltip.top
              name="eye-slash"
              class="gl-text-orange-500"
              data-testid="confidential-icon"
              :aria-label="$options.i18n.confidential"
              :title="$options.i18n.confidential"
            />
          </span>
          <gl-link
            :href="childItem.webUrl"
            class="gl-overflow-break-word gl-font-weight-semibold"
            @click="$emit('click', $event)"
            @mouseover="$emit('mouseover')"
            @mouseout="$emit('mouseout')"
          >
            {{ childItem.title }}
          </gl-link>
        </div>
        <div class="gl-display-flex gl-justify-content-end">
          <gl-avatars-inline
            v-if="assignees.length"
            :avatars="assignees"
            collapsed
            :max-visible="2"
            :avatar-size="16"
            badge-tooltip-prop="name"
            :badge-sr-only-text="assigneesCollapsedTooltip"
            class="gl-white-space-nowrap gl-mr-3"
          >
            <template #avatar="{ avatar }">
              <gl-avatar-link v-gl-tooltip :href="avatar.webUrl" :title="avatar.name">
                <gl-avatar :alt="avatar.name" :src="avatar.avatarUrl" :size="16" />
              </gl-avatar-link>
            </template>
          </gl-avatars-inline>
          <span
            :id="`statusIcon-${childItem.id}`"
            class="gl-cursor-help"
            data-testid="item-status-icon"
          >
            <gl-icon
              class="gl-text-secondary"
              :class="statusIconClass"
              :name="statusIconName"
              :aria-label="stateTimestampTypeText"
            />
          </span>
          <rich-timestamp-tooltip
            :target="`statusIcon-${childItem.id}`"
            :raw-timestamp="stateTimestamp"
            :timestamp-type-text="stateTimestampTypeText"
          />
        </div>
      </div>
      <work-item-link-child-metadata
        :reference="displayReference"
        :iid="childItem.iid"
        :metadata-widgets="metadataWidgets"
        class="ml-xl-0"
      />
      <div v-if="displayLabels" class="gl-display-flex gl-flex-wrap">
        <gl-label
          v-for="label in labels"
          :key="label.id"
          :title="label.title"
          :background-color="label.color"
          :description="label.description"
          :scoped="showScopedLabel(label)"
          class="gl-mt-2 gl-mr-2 gl-mb-auto gl-label-sm"
          tooltip-placement="top"
        />
      </div>
    </div>
    <div v-if="canUpdate">
      <gl-button
        v-gl-tooltip
        :class="{ 'gl-visibility-visible': showRemove }"
        class="gl-visibility-hidden gl-mt-n2"
        category="tertiary"
        size="small"
        icon="close"
        :aria-label="$options.i18n.remove"
        :title="$options.i18n.remove"
        data-testid="remove-work-item-link"
        @click="$emit('removeChild', childItem)"
      />
    </div>
  </div>
</template>
