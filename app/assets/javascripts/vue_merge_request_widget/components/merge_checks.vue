<script>
import { GlSkeletonLoader } from '@gitlab/ui';
import { __, n__, sprintf } from '~/locale';
import { TYPENAME_MERGE_REQUEST } from '~/graphql_shared/constants';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import {
  COMPONENTS,
  FAILURE_REASONS,
} from '~/vue_merge_request_widget/components/checks/constants';
import mergeRequestQueryVariablesMixin from '../mixins/merge_request_query_variables';
import mergeChecksQuery from '../queries/merge_checks.query.graphql';
import mergeChecksSubscription from '../queries/merge_checks.subscription.graphql';
import StateContainer from './state_container.vue';
import BoldText from './bold_text.vue';

export default {
  apollo: {
    state: {
      query: mergeChecksQuery,
      skip() {
        return !this.mr;
      },
      variables() {
        return this.mergeRequestQueryVariables;
      },
      update: (data) => data?.project?.mergeRequest,
      subscribeToMore: {
        document() {
          return mergeChecksSubscription;
        },
        skip() {
          return !this.mr?.id;
        },
        variables() {
          return {
            issuableId: convertToGraphQLId(TYPENAME_MERGE_REQUEST, this.mr?.id),
          };
        },
        updateQuery(
          _,
          {
            subscriptionData: {
              data: { mergeRequestMergeStatusUpdated },
            },
          },
        ) {
          if (mergeRequestMergeStatusUpdated) {
            this.state = mergeRequestMergeStatusUpdated;
          }
        },
      },
    },
  },
  components: {
    GlSkeletonLoader,
    StateContainer,
    BoldText,
  },
  mixins: [mergeRequestQueryVariablesMixin],
  props: {
    mr: {
      type: Object,
      required: true,
    },
    service: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      collapsed: true,
      collapsedCount: 0,
      state: {},
    };
  },
  computed: {
    isLoading() {
      return this.$apollo.queries.state.loading;
    },
    statusIcon() {
      return this.failedChecks.length ? 'failed' : 'success';
    },
    summaryText() {
      if (!this.failedChecks.length) {
        return this.state?.userPermissions?.canMerge
          ? __('%{boldStart}Ready to merge!%{boldEnd}')
          : __(
              '%{boldStart}Ready to merge by members who can write to the target branch.%{boldEnd}',
            );
      }

      return sprintf(
        n__(
          '%{boldStart}Merge blocked:%{boldEnd} %{count} check failed',
          '%{boldStart}Merge blocked:%{boldEnd} %{count} checks failed',
          this.failedChecks.length,
        ),
        { count: this.failedChecks.length },
      );
    },
    checks() {
      return this.state?.mergeabilityChecks || [];
    },
    sortedChecks() {
      const order = ['FAILED', 'SUCCESS'];

      return [...this.checks]
        .filter((s) => {
          if (this.isStatusInactive(s) || !this.hasMessage(s)) return false;
          if (this.collapsedCount > 0 && this.collapsed) return false;

          return this.collapsed ? this.isStatusFailed(s) : true;
        })
        .sort((a, b) => order.indexOf(a.status) - order.indexOf(b.status));
    },
    failedChecks() {
      return this.checks.filter((c) => this.isStatusFailed(c));
    },
    showChecks() {
      if (this.collapsed && this.collapsedCount > 0) return false;

      return this.failedChecks.length > 0 || !this.collapsed;
    },
  },
  methods: {
    toggleCollapsed() {
      this.collapsed = !this.collapsed;
      this.collapsedCount += 1;
    },
    checkComponent(check) {
      return COMPONENTS[check.identifier.toLowerCase()] || COMPONENTS.default;
    },
    hasMessage(check) {
      return Boolean(FAILURE_REASONS[check.identifier.toLowerCase()]);
    },
    isStatusInactive(check) {
      return check.status === 'INACTIVE';
    },
    isStatusFailed(check) {
      return check.status === 'FAILED';
    },
  },
};
</script>

<template>
  <div class="gl-rounded-0!">
    <state-container
      :is-loading="isLoading"
      :status="statusIcon"
      is-collapsible
      collapse-on-desktop
      :collapsed="collapsed"
      :expand-details-tooltip="__('Expand merge checks')"
      :collapse-details-tooltip="__('Collapse merge checks')"
      @toggle="toggleCollapsed"
    >
      <template v-if="isLoading" #loading>
        <gl-skeleton-loader :width="334" :height="24">
          <rect x="0" y="0" width="24" height="24" rx="4" />
          <rect x="32" y="2" width="302" height="20" rx="4" />
        </gl-skeleton-loader>
      </template>
      <template v-else>
        <bold-text :message="summaryText" />
      </template>
    </state-container>
    <div
      v-if="showChecks"
      class="gl-border-t-1 gl-border-t-solid gl-border-gray-100 gl-relative gl-bg-gray-10"
      data-testid="merge-checks-full"
    >
      <div class="gl-px-5">
        <component
          :is="checkComponent(check)"
          v-for="(check, index) in sortedChecks"
          :key="index"
          :class="{
            'gl-border-b-solid gl-border-b-1 gl-border-gray-100': index !== sortedChecks.length - 1,
          }"
          :check="check"
          :mr="mr"
          :service="service"
          data-testid="merge-check"
        />
      </div>
    </div>
  </div>
</template>
