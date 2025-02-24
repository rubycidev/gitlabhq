<script>
import {
  GlSearchBoxByType,
  GlLabel,
  GlLoadingIcon,
  GlDropdownDivider,
  GlDropdownSectionHeader,
  GlFormCheckboxGroup,
  GlDropdownForm,
  GlAlert,
  GlOutsideDirective as Outside,
} from '@gitlab/ui';
// eslint-disable-next-line no-restricted-imports
import { mapActions, mapState, mapGetters } from 'vuex';
import { uniq } from 'lodash';
import { rgbFromHex } from '@gitlab/ui/dist/utils/utils';
import { slugify } from '~/lib/utils/text_utility';
import { isLoggedIn } from '~/lib/utils/common_utils';
import { sprintf } from '~/locale';

import DropdownKeyboardNavigation from '~/vue_shared/components/dropdown_keyboard_navigation.vue';

import { I18N } from '~/vue_shared/global_search/constants';
import LabelDropdownItems from './label_dropdown_items.vue';

import {
  FIRST_DROPDOWN_INDEX,
  SEARCH_BOX_INDEX,
  SEARCH_RESULTS_DESCRIPTION,
  SEARCH_INPUT_DESCRIPTION,
  labelFilterData,
} from './data';

import { trackSelectCheckbox, trackOpenDropdown } from './tracking';

export default {
  name: 'LabelFilter',
  directives: { Outside },
  components: {
    DropdownKeyboardNavigation,
    GlSearchBoxByType,
    LabelDropdownItems,
    GlLabel,
    GlDropdownDivider,
    GlDropdownSectionHeader,
    GlFormCheckboxGroup,
    GlDropdownForm,
    GlLoadingIcon,
    GlAlert,
  },
  data() {
    return {
      currentFocusIndex: SEARCH_BOX_INDEX,
      isFocused: false,
      isLoggedIn: isLoggedIn(),
    };
  },
  i18n: I18N,
  computed: {
    ...mapState(['searchLabelString', 'query', 'urlQuery', 'aggregations']),
    ...mapGetters([
      'filteredLabels',
      'filteredUnselectedLabels',
      'filteredAppliedSelectedLabels',
      'appliedSelectedLabels',
      'unselectedLabels',
      'unappliedNewLabels',
      'labelAggregationBuckets',
    ]),
    searchInputDescribeBy() {
      if (this.isLoggedIn) {
        return this.$options.i18n.SEARCH_INPUT_DESCRIBE_BY_WITH_DROPDOWN;
      }
      return this.$options.i18n.SEARCH_INPUT_DESCRIBE_BY_NO_DROPDOWN;
    },
    dropdownResultsDescription() {
      if (!('showSearchDropdown' in this)) {
        return ''; // This allows aria-live to see register an update when the dropdown is shown
      }

      if ('showDefaultItems' in this) {
        return sprintf(this.$options.i18n.SEARCH_DESCRIBED_BY_DEFAULT, {
          count: this.filteredLabels.length,
        });
      }

      return 'loading' in this
        ? this.$options.i18n.SEARCH_RESULTS_LOADING
        : sprintf(this.$options.i18n.SEARCH_DESCRIBED_BY_UPDATED, {
            count: this.filteredLabels.length,
          });
    },
    currentFocusedOption() {
      return this.filteredLabels[this.currentFocusIndex] || null;
    },
    currentFocusedId() {
      return `${slugify(this.currentFocusedOption?.parent_full_name || 'undefined-name')}_${slugify(
        this.currentFocusedOption?.title || 'undefined-title',
      )}`;
    },
    defaultIndex() {
      if ('showDefaultItems' in this) {
        return SEARCH_BOX_INDEX;
      }
      return FIRST_DROPDOWN_INDEX;
    },
    hasSelectedLabels() {
      return this.filteredAppliedSelectedLabels?.length > 0;
    },
    hasUnselectedLabels() {
      return this.filteredUnselectedLabels?.length > 0;
    },
    labelSearchBox() {
      return this.$refs.searchLabelInputBox?.$el.querySelector('[role=searchbox]');
    },
    combinedSelectedFilters() {
      const appliedSelectedLabelKeys = this.appliedSelectedLabels.map((label) => label.key);
      const { labels = [] } = this.query;

      return uniq([...appliedSelectedLabelKeys, ...labels]);
    },
    searchLabels: {
      get() {
        return this.searchLabelString;
      },
      set(value) {
        this.setLabelFilterSearch({ value });
      },
    },
    selectedLabels: {
      get() {
        return this.combinedSelectedFilters;
      },
      set(value) {
        this.setQuery({ key: this.$options.labelFilterData?.filterParam, value });
        trackSelectCheckbox(value);
      },
    },
  },
  async created() {
    if (this.urlQuery?.[labelFilterData.filterParam]?.length > 0) {
      await this.fetchAllAggregation();
    }
  },
  methods: {
    ...mapActions(['fetchAllAggregation', 'setQuery', 'closeLabel', 'setLabelFilterSearch']),
    async openDropdown() {
      this.isFocused = true;

      if (!this.aggregations.error && this.filteredLabels?.length === 0) {
        await this.fetchAllAggregation();
      }

      trackOpenDropdown();
    },
    closeDropdown(event) {
      const { target } = event;

      if (this.labelSearchBox !== target) {
        this.isFocused = false;
      }
    },
    onLabelClose(event) {
      if (!event?.target?.closest('.gl-label')?.dataset) {
        return;
      }

      const { key } = event.target.closest('.gl-label').dataset;
      this.closeLabel({ key });
    },
    inactiveLabelColor(label) {
      return `rgba(${rgbFromHex(label.color)}, 0.3)`;
    },
  },
  FIRST_DROPDOWN_INDEX,
  SEARCH_RESULTS_DESCRIPTION,
  SEARCH_INPUT_DESCRIPTION,
  labelFilterData,
};
</script>

<template>
  <div class="gl-pb-0 gl-md-pt-0 label-filter gl-relative">
    <div class="gl-mb-2 gl-font-weight-bold gl-font-sm" data-testid="label-filter-title">
      {{ $options.labelFilterData.header }}
    </div>
    <div>
      <gl-label
        v-for="label in unappliedNewLabels"
        :key="label.key"
        class="gl-mr-2 gl-mb-2 gl-bg-gray-10"
        :data-key="label.key"
        :background-color="inactiveLabelColor(label)"
        :title="label.title"
        :show-close-button="false"
        data-testid="unapplied-label"
      />
      <gl-label
        v-for="label in unselectedLabels"
        :key="label.key"
        class="gl-mr-2 gl-mb-2 gl-bg-gray-10"
        :data-key="label.key"
        :background-color="inactiveLabelColor(label)"
        :title="label.title"
        :show-close-button="false"
        data-testid="unselected-label"
      />
      <gl-label
        v-for="label in appliedSelectedLabels"
        :key="label.key"
        class="gl-mr-2 gl-mb-2 gl-bg-gray-10"
        :data-key="label.key"
        :background-color="label.color"
        :title="label.title"
        :show-close-button="true"
        data-testid="label"
        @close="onLabelClose"
      />
    </div>
    <gl-search-box-by-type
      ref="searchLabelInputBox"
      v-model="searchLabels"
      role="searchbox"
      autocomplete="off"
      :placeholder="$options.i18n.SEARCH_LABELS"
      :aria-activedescendant="currentFocusedId"
      :aria-describedby="$options.SEARCH_INPUT_DESCRIPTION"
      @focusin="openDropdown"
      @keydown.esc="closeDropdown"
    />
    <span :id="$options.SEARCH_INPUT_DESCRIPTION" role="region" class="gl-sr-only">{{
      searchInputDescribeBy
    }}</span>
    <span
      role="region"
      :data-testid="$options.SEARCH_RESULTS_DESCRIPTION"
      class="gl-sr-only"
      aria-live="polite"
      aria-atomic="true"
    >
      {{ dropdownResultsDescription }}
    </span>
    <div
      v-if="isFocused"
      v-outside="closeDropdown"
      data-testid="header-search-dropdown-menu"
      class="header-search-dropdown-menu gl-overflow-y-auto gl-absolute gl-bg-white gl-border-1 gl-rounded-base gl-border-solid gl-border-gray-200 gl-shadow-x0-y2-b4-s0 gl-mt-3 gl-z-index-2 gl-w-full! gl-min-w-full! gl-max-w-none!"
    >
      <div class="header-search-dropdown-content gl-py-2">
        <dropdown-keyboard-navigation
          v-model="currentFocusIndex"
          :max="filteredLabels.length - 1"
          :min="$options.FIRST_DROPDOWN_INDEX"
          :default-index="defaultIndex"
          :enable-cycle="true"
        />
        <div v-if="!aggregations.error && filteredLabels.length > 0">
          <gl-dropdown-section-header v-if="hasSelectedLabels || hasUnselectedLabels">{{
            $options.i18n.DROPDOWN_HEADER
          }}</gl-dropdown-section-header>
          <gl-dropdown-form>
            <gl-form-checkbox-group v-model="selectedLabels">
              <label-dropdown-items
                v-if="hasSelectedLabels"
                :labels="filteredAppliedSelectedLabels"
              />
              <gl-dropdown-divider v-if="hasSelectedLabels && hasUnselectedLabels" />
              <label-dropdown-items v-if="hasUnselectedLabels" :labels="filteredUnselectedLabels" />
            </gl-form-checkbox-group>
          </gl-dropdown-form>
        </div>
        <span
          v-if="!aggregations.error && filteredLabels.length === 0"
          class="gl-px-3"
          data-testid="no-labels-found-message"
          >{{ $options.i18n.NO_LABELS_FOUND }}</span
        >
        <gl-alert v-if="aggregations.error" :dismissible="false" variant="danger">
          {{ $options.i18n.AGGREGATIONS_ERROR_MESSAGE }}
        </gl-alert>
        <gl-loading-icon v-if="aggregations.fetching" size="lg" class="my-4" />
      </div>
    </div>
  </div>
</template>
