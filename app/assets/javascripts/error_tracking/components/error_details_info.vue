<script>
import { GlLink, GlIcon, GlCard, GlTooltipDirective } from '@gitlab/ui';
import TimeAgoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';
import TrackEventDirective from '~/vue_shared/directives/track_event';
import { trackClickErrorLinkToSentryOptions } from '../events_tracking';

const CARD_CLASS = 'gl-mr-7 gl-w-15p gl-min-w-fit-content';
const HEADER_CLASS =
  'gl-p-2 gl-font-weight-bold gl-display-flex gl-justify-content-center gl-align-items-center';
const BODY_CLASS =
  'gl-display-flex gl-justify-content-center gl-align-items-center gl-flex-direction-column gl-my-0 gl-p-4 gl-font-weight-bold gl-text-center gl-flex-grow-1 gl-font-lg';

export default {
  components: {
    GlCard,
    GlLink,
    TimeAgoTooltip,
    GlIcon,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
    TrackEvent: TrackEventDirective,
  },
  props: {
    error: {
      type: Object,
      required: true,
    },
  },
  computed: {
    firstReleaseLink() {
      return `${this.error.externalBaseUrl}/releases/${this.error.firstReleaseVersion}`;
    },
    lastReleaseLink() {
      return `${this.error.externalBaseUrl}/releases/${this.error.lastReleaseVersion}`;
    },
    shortFirstReleaseVersion() {
      return this.error.firstReleaseVersion?.substr(0, 10);
    },
    shortLastReleaseVersion() {
      return this.error.lastReleaseVersion?.substr(0, 10);
    },
    shortGitlabCommit() {
      return this.error.gitlabCommit?.substr(0, 10);
    },
  },
  methods: {
    trackClickErrorLinkToSentryOptions,
  },
  CARD_CLASS,
  HEADER_CLASS,
  BODY_CLASS,
};
</script>

<template>
  <div>
    <div
      v-if="error"
      class="gl-display-flex gl-flex-wrap gl-justify-content-center gl-my-7 gl-row-gap-6"
    >
      <gl-card
        :class="$options.CARD_CLASS"
        :body-class="$options.BODY_CLASS"
        :header-class="$options.HEADER_CLASS"
        data-testid="error-count-card"
      >
        <template #header>
          {{ __('Events') }}
        </template>

        <template #default>
          {{ error.count }}
        </template>
      </gl-card>

      <!-- user count is currently not supported for integrated error tracking https://gitlab.com/gitlab-org/opstrace/opstrace/-/issues/2345 -->
      <gl-card
        v-if="!error.integrated"
        :class="$options.CARD_CLASS"
        :body-class="$options.BODY_CLASS"
        :header-class="$options.HEADER_CLASS"
        data-testid="user-count-card"
      >
        <template #header>
          {{ __('Users') }}
        </template>

        <template #default>
          {{ error.userCount }}
        </template>
      </gl-card>

      <gl-card
        v-if="error.firstSeen"
        :class="$options.CARD_CLASS"
        :body-class="$options.BODY_CLASS"
        :header-class="$options.HEADER_CLASS"
        data-testid="first-release-card"
      >
        <template #header>
          {{ __('First seen') }}
        </template>

        <template v-if="error.integrated" #default>
          <time-ago-tooltip :time="error.firstSeen" />
          <span v-if="shortFirstReleaseVersion" class="gl-font-sm gl-text-secondary">
            <gl-icon name="commit" class="gl-mr-1" :size="12" />{{ shortFirstReleaseVersion }}
          </span>
        </template>

        <template v-else #default>
          <gl-link :href="firstReleaseLink" target="_blank" class="gl-font-lg">
            <time-ago-tooltip :time="error.firstSeen" />
          </gl-link>
        </template>
      </gl-card>

      <gl-card
        v-if="error.lastSeen"
        :class="$options.CARD_CLASS"
        :body-class="$options.BODY_CLASS"
        :header-class="$options.HEADER_CLASS"
        data-testid="last-release-card"
      >
        <template #header>
          {{ __('Last seen') }}
        </template>

        <template v-if="error.integrated" #default>
          <time-ago-tooltip :time="error.lastSeen" />
          <span v-if="shortLastReleaseVersion" class="gl-font-sm gl-text-secondary">
            <gl-icon name="commit" class="gl-mr-1" :size="12" />{{ shortLastReleaseVersion }}
          </span>
        </template>

        <template v-else #default>
          <gl-link :href="lastReleaseLink" target="_blank" class="gl-font-lg">
            <time-ago-tooltip :time="error.lastSeen" />
          </gl-link>
        </template>
      </gl-card>

      <gl-card
        v-if="!error.integrated && error.gitlabCommit"
        :class="$options.CARD_CLASS"
        :body-class="$options.BODY_CLASS"
        :header-class="$options.HEADER_CLASS"
        data-testid="gitlab-commit-card"
      >
        <template #header>
          {{ __('GitLab commit') }}
        </template>

        <template #default>
          <gl-link :href="error.gitlabCommitPath" class="gl-font-lg">
            {{ shortGitlabCommit }}
          </gl-link>
        </template>
      </gl-card>
    </div>
    <div v-if="!error.integrated" class="py-3">
      <span class="gl-font-weight-bold">{{ __('Sentry event') }}:</span>
      <gl-link
        v-track-event="trackClickErrorLinkToSentryOptions(error.externalUrl)"
        :href="error.externalUrl"
        target="_blank"
        data-testid="external-url-link"
      >
        <span class="text-truncate">{{ error.externalUrl }}</span>
        <gl-icon name="external-link" class="ml-1 flex-shrink-0" />
      </gl-link>
    </div>
  </div>
</template>
