<script>
import { GlButton } from '@gitlab/ui';
import csrf from '~/lib/utils/csrf';
import { __, s__ } from '~/locale';
import { formDataValidator } from '../constants';
import CustomMetricsFormFields from './custom_metrics_form_fields.vue';
import DeleteCustomMetricModal from './delete_custom_metric_modal.vue';

export default {
  components: {
    CustomMetricsFormFields,
    DeleteCustomMetricModal,
    GlButton,
  },
  props: {
    customMetricsPath: {
      type: String,
      required: false,
      default: '',
    },
    metricPersisted: {
      type: Boolean,
      required: true,
    },
    editIntegrationPath: {
      type: String,
      required: true,
    },
    validateQueryPath: {
      type: String,
      required: true,
    },
    formData: {
      type: Object,
      required: true,
      validator: formDataValidator,
    },
  },
  data() {
    return {
      formIsValid: null,
      errorMessage: '',
    };
  },
  computed: {
    saveButtonText() {
      return this.metricPersisted ? __('Save Changes') : s__('Metrics|Create metric');
    },
    titleText() {
      return this.metricPersisted ? s__('Metrics|Edit metric') : s__('Metrics|New metric');
    },
  },
  created() {
    this.csrf = csrf.token != null ? csrf.token : '';
    this.formOperation = this.metricPersisted ? 'patch' : 'post';
  },
  methods: {
    formValidation(isValid) {
      this.formIsValid = isValid;
    },
    submit() {
      this.$refs.form.submit();
    },
  },
};
</script>
<template>
  <div class="row my-3">
    <h4 class="gl-mt-0 col-lg-8 offset-lg-2">{{ titleText }}</h4>
    <form ref="form" class="col-lg-8 offset-lg-2" :action="customMetricsPath" method="post">
      <custom-metrics-form-fields
        :form-operation="formOperation"
        :form-data="formData"
        :metric-persisted="metricPersisted"
        :validate-query-path="validateQueryPath"
        @formValidation="formValidation"
      />
      <div class="form-actions">
        <gl-button variant="confirm" category="primary" :disabled="!formIsValid" @click="submit">
          {{ saveButtonText }}
        </gl-button>
        <gl-button class="gl-float-right" :href="editIntegrationPath">{{ __('Cancel') }}</gl-button>
        <delete-custom-metric-modal
          v-if="metricPersisted"
          :delete-metric-url="customMetricsPath"
          :csrf-token="csrf"
        />
      </div>
    </form>
  </div>
</template>
