<script>
import { GlTooltipDirective, GlLink, GlButton } from '@gitlab/ui';
import { __, sprintf } from '~/locale';
import SafeHtml from '~/vue_shared/directives/safe_html';
import defaultAvatarUrl from 'images/no_avatar.png';
import TimeagoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';
import UserAvatarLink from '~/vue_shared/components/user_avatar/user_avatar_link.vue';
import UserAvatarImage from '~/vue_shared/components/user_avatar/user_avatar_image.vue';
import getRefMixin from '../mixins/get_ref';

export default {
  components: {
    UserAvatarLink,
    TimeagoTooltip,
    GlButton,
    GlLink,
    UserAvatarImage,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
    SafeHtml,
  },
  mixins: [getRefMixin],
  props: {
    commit: {
      type: Object,
      required: true,
    },
    span: {
      type: Number,
      required: false,
      default: null,
    },
    prevBlameLink: {
      type: String,
      required: false,
      default: null,
    },
  },
  data() {
    return { showDescription: false };
  },
  computed: {
    commitDescription() {
      // Strip the newline at the beginning
      return this.commit?.descriptionHtml?.replace(/^&#x000A;/, '');
    },
    avatarLinkAltText() {
      return sprintf(__(`%{username}'s avatar`), { username: this.commit.authorName });
    },
    truncateAuthorName() {
      return typeof this.span === 'number' && this.span < 3;
    },
  },
  methods: {
    toggleShowDescription() {
      this.showDescription = !this.showDescription;
    },
  },
  defaultAvatarUrl,
  safeHtmlConfig: {
    ADD_TAGS: ['gl-emoji'],
  },
  i18n: {
    toggleCommitDescription: __('Toggle commit description'),
    authored: __('authored'),
  },
};
</script>

<template>
  <div class="well-segment commit gl-min-h-8 gl-p-2 gl-w-full gl-display-flex">
    <user-avatar-link
      v-if="commit.author"
      :link-href="commit.author.webPath"
      :img-src="commit.author.avatarUrl"
      :img-alt="avatarLinkAltText"
      :img-size="32"
      class="gl-my-2 gl-mr-4"
    />
    <user-avatar-image
      v-else
      class="gl-my-2 gl-mr-4"
      :img-src="commit.authorGravatar || $options.defaultAvatarUrl"
      :size="32"
    />
    <div class="commit-detail flex-list gl-display-flex gl-flex-grow-1 gl-min-w-0">
      <div
        class="commit-content gl-w-full gl-display-inline-flex gl-flex-wrap gl-align-items-baseline"
        data-testid="commit-content"
      >
        <div
          class="gl-flex-basis-full gl-display-inline-flex gl-align-items-center gl-column-gap-3"
        >
          <gl-link
            v-safe-html:[$options.safeHtmlConfig]="commit.titleHtml"
            :href="commit.webPath"
            :class="{ 'gl-font-style-italic': !commit.message }"
            class="commit-row-message item-title gl-line-clamp-1 gl-word-break-all!"
          />
          <gl-button
            v-if="commit.descriptionHtml"
            v-gl-tooltip
            :class="{ open: showDescription }"
            :title="$options.i18n.toggleCommitDescription"
            :aria-label="$options.i18n.toggleCommitDescription"
            :selected="showDescription"
            class="text-expander gl-ml-0!"
            icon="ellipsis_h"
            @click="toggleShowDescription"
          />
        </div>
        <div
          class="committer gl-flex-basis-full"
          :class="{ 'gl-display-inline-flex': truncateAuthorName }"
          data-testid="committer"
        >
          <gl-link
            v-if="commit.author"
            :href="commit.author.webPath"
            class="commit-author-link js-user-link"
            :class="{ 'gl-display-inline-block gl-text-truncate': truncateAuthorName }"
          >
            {{ commit.author.name }}</gl-link
          >
          <template v-else>
            {{ commit.authorName }}
          </template>
          {{ $options.i18n.authored }}
          <timeago-tooltip :time="commit.authoredDate" tooltip-placement="bottom" />
        </div>
        <pre
          v-if="commitDescription"
          v-safe-html:[$options.safeHtmlConfig]="commitDescription"
          :class="{ 'gl-display-block!': showDescription }"
          class="commit-row-description gl-mb-3 gl-white-space-pre-line"
        ></pre>
      </div>
      <div class="gl-flex-grow-1"></div>
      <slot></slot>
    </div>
    <div v-if="prevBlameLink" v-safe-html:[$options.safeHtmlConfig]="prevBlameLink"></div>
  </div>
</template>
