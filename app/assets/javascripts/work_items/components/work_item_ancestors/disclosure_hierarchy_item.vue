<!-- eslint-disable vue/multi-word-component-names -->
<script>
import iconSpriteInfo from '@gitlab/svgs/dist/icons.json';
import { GlIcon, GlLink } from '@gitlab/ui';

export default {
  components: {
    GlIcon,
    GlLink,
  },
  props: {
    /**
     * Path item in the form:
     * ```
     * {
     *   title:    String, required
     *   icon:     String, optional
     * }
     * ```
     */
    item: {
      type: Object,
      required: false,
      default: () => {},
    },
    itemId: {
      type: String,
      required: false,
      default: null,
    },
  },
  methods: {
    shouldDisplayIcon(icon) {
      return icon && iconSpriteInfo.icons.includes(icon);
    },
  },
};
</script>

<template>
  <li class="disclosure-hierarchy-item gl-display-flex gl-min-w-0">
    <gl-link
      :id="itemId"
      :href="item.webUrl"
      class="disclosure-hierarchy-button gl-text-gray-900 gl-hover-text-decoration-none gl-active-text-decoration-none!"
    >
      <gl-icon
        v-if="shouldDisplayIcon(item.icon)"
        :name="item.icon"
        class="gl-mx-2 gl-text-gray-600 gl-flex-shrink-0"
      />
      <span class="gl-z-index-200 gl-text-truncate">{{ item.title }}</span>
    </gl-link>
    <!--
      @slot Additional content to be displayed in an item.
      @binding {Object} item The item being rendered.
      @binding {String} itemId The rendered item's ID.
    -->
    <slot :item="item" :item-id="itemId"></slot>
  </li>
</template>
