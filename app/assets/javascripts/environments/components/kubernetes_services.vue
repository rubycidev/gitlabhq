<script>
import { GlTab, GlLoadingIcon, GlBadge } from '@gitlab/ui';
import { s__ } from '~/locale';
import {
  getAge,
  generateServicePortsString,
} from '~/kubernetes_dashboard/helpers/k8s_integration_helper';
import WorkloadTable from '~/kubernetes_dashboard/components/workload_table.vue';
import { SERVICES_TABLE_FIELDS } from '~/kubernetes_dashboard/constants';
import k8sServicesQuery from '../graphql/queries/k8s_services.query.graphql';
import { SERVICES_LIMIT_PER_PAGE } from '../constants';

export default {
  components: {
    GlTab,
    GlBadge,
    WorkloadTable,
    GlLoadingIcon,
  },
  apollo: {
    k8sServices: {
      query: k8sServicesQuery,
      variables() {
        return {
          configuration: this.configuration,
          namespace: this.namespace,
        };
      },
      update(data) {
        return data?.k8sServices || [];
      },
      error(error) {
        this.$emit('cluster-error', error.message);
      },
    },
  },
  props: {
    configuration: {
      required: true,
      type: Object,
    },
    namespace: {
      required: true,
      type: String,
    },
  },
  computed: {
    servicesItems() {
      if (!this.k8sServices?.length) return [];

      return this.k8sServices.map((service) => {
        return {
          name: service?.metadata?.name,
          namespace: service?.metadata?.namespace,
          type: service?.spec?.type,
          clusterIP: service?.spec?.clusterIP,
          externalIP: service?.spec?.externalIP,
          ports: generateServicePortsString(service?.spec?.ports),
          age: getAge(service?.metadata?.creationTimestamp),
        };
      });
    },
    servicesLoading() {
      return this.$apollo.queries.k8sServices.loading;
    },
  },
  i18n: {
    servicesTitle: s__('Environment|Services'),
  },
  SERVICES_TABLE_FIELDS,
  SERVICES_LIMIT_PER_PAGE,
};
</script>
<template>
  <gl-tab>
    <template #title>
      {{ $options.i18n.servicesTitle }}
      <gl-badge size="sm" class="gl-tab-counter-badge">{{ servicesItems.length }}</gl-badge>
    </template>

    <gl-loading-icon v-if="servicesLoading" />

    <workload-table
      v-else
      :items="servicesItems"
      :fields="$options.SERVICES_TABLE_FIELDS"
      :page-size="$options.SERVICES_LIMIT_PER_PAGE"
      :row-clickable="false"
      class="gl-mt-5"
    />
  </gl-tab>
</template>
