<script>
import {
  GlCard,
  GlSprintf,
  GlPopover,
  GlLink,
  GlButton,
  GlBadge,
  GlLoadingIcon,
  GlModalDirective,
} from '@gitlab/ui';
import { mapState } from 'vuex';
import {
  AGENT_CARD_INFO,
  CERTIFICATE_BASED_CARD_INFO,
  MAX_CLUSTERS_LIST,
  INSTALL_AGENT_MODAL_ID,
} from '../constants';
import Clusters from './clusters.vue';
import Agents from './agents.vue';

export default {
  components: {
    GlCard,
    GlSprintf,
    GlPopover,
    GlLink,
    GlButton,
    GlBadge,
    GlLoadingIcon,
    Clusters,
    Agents,
  },
  directives: {
    GlModalDirective,
  },
  MAX_CLUSTERS_LIST,
  INSTALL_AGENT_MODAL_ID,
  i18n: {
    agent: AGENT_CARD_INFO,
    certificate: CERTIFICATE_BASED_CARD_INFO,
  },
  inject: ['addClusterPath'],
  props: {
    defaultBranchName: {
      default: '.noBranch',
      required: false,
      type: String,
    },
  },
  data() {
    return {
      loadingAgents: true,
      totalAgents: null,
    };
  },
  computed: {
    ...mapState(['loadingClusters', 'totalClusters']),
    isLoading() {
      return this.loadingAgents || this.loadingClusters;
    },
    agentsCardTitle() {
      let cardTitle;
      if (this.totalAgents > 0) {
        cardTitle = {
          message: AGENT_CARD_INFO.title,
          number: this.totalAgents < MAX_CLUSTERS_LIST ? this.totalAgents : MAX_CLUSTERS_LIST,
          total: this.totalAgents,
        };
      } else {
        cardTitle = {
          message: AGENT_CARD_INFO.emptyTitle,
        };
      }

      return cardTitle;
    },
    clustersCardTitle() {
      let cardTitle;
      if (this.totalClusters > 0) {
        cardTitle = {
          message: CERTIFICATE_BASED_CARD_INFO.title,
          number: this.totalClusters < MAX_CLUSTERS_LIST ? this.totalClusters : MAX_CLUSTERS_LIST,
          total: this.totalClusters,
        };
      } else {
        cardTitle = {
          message: CERTIFICATE_BASED_CARD_INFO.emptyTitle,
        };
      }

      return cardTitle;
    },
  },
  methods: {
    cardFooterNumber(number) {
      return number > MAX_CLUSTERS_LIST ? number : '';
    },
    onAgentsLoad(number) {
      this.totalAgents = number;
      this.loadingAgents = false;
    },
    changeTab($event, tab) {
      $event.preventDefault();
      this.$emit('changeTab', tab);
    },
  },
};
</script>
<template>
  <div>
    <gl-loading-icon v-if="isLoading" size="md" />
    <div v-show="!isLoading" data-testid="clusters-cards-container">
      <gl-card
        header-class="gl-bg-white gl-display-flex gl-align-items-center gl-justify-content-space-between gl-py-4"
        body-class="gl-pb-0"
        footer-class="gl-text-right"
      >
        <template #header>
          <h3 data-testid="agent-card-title" class="gl-my-0 gl-font-weight-normal gl-font-size-h2">
            <gl-sprintf :message="agentsCardTitle.message"
              ><template #number>{{ agentsCardTitle.number }}</template>
              <template #total>{{ agentsCardTitle.total }}</template>
            </gl-sprintf>
          </h3>

          <gl-badge id="clusters-recommended-badge" variant="info">{{
            $options.i18n.agent.tooltip.label
          }}</gl-badge>

          <gl-popover
            target="clusters-recommended-badge"
            container="viewport"
            placement="bottom"
            :title="$options.i18n.agent.tooltip.title"
          >
            <p class="gl-mb-0">
              <gl-sprintf :message="$options.i18n.agent.tooltip.text">
                <template #link="{ content }">
                  <gl-link
                    :href="$options.i18n.agent.tooltip.link"
                    target="_blank"
                    class="gl-font-sm"
                  >
                    {{ content }}</gl-link
                  >
                </template>
              </gl-sprintf>
            </p>
          </gl-popover>
        </template>

        <agents
          :limit="$options.MAX_CLUSTERS_LIST"
          :default-branch-name="defaultBranchName"
          :is-child-component="true"
          @onAgentsLoad="onAgentsLoad"
        />

        <template #footer>
          <gl-link
            v-if="totalAgents"
            data-testid="agents-tab-footer-link"
            :href="`?tab=${$options.i18n.agent.tabName}`"
            @click="changeTab($event, $options.i18n.agent.tabName)"
            ><gl-sprintf :message="$options.i18n.agent.footerText"
              ><template #number>{{ cardFooterNumber(totalAgents) }}</template></gl-sprintf
            ></gl-link
          ><gl-button
            v-gl-modal-directive="$options.INSTALL_AGENT_MODAL_ID"
            class="gl-ml-4"
            category="secondary"
            variant="confirm"
            >{{ $options.i18n.agent.actionText }}</gl-button
          >
        </template>
      </gl-card>

      <gl-card
        class="gl-mt-6"
        header-class="gl-bg-white gl-display-flex gl-align-items-center gl-justify-content-space-between"
        body-class="gl-pb-0"
        footer-class="gl-text-right"
      >
        <template #header>
          <h3
            class="gl-my-1 gl-font-weight-normal gl-font-size-h2"
            data-testid="clusters-card-title"
          >
            <gl-sprintf :message="clustersCardTitle.message"
              ><template #number>{{ clustersCardTitle.number }}</template>
              <template #total>{{ clustersCardTitle.total }}</template>
            </gl-sprintf>
          </h3>
          <gl-badge variant="warning">{{ $options.i18n.certificate.badgeText }}</gl-badge>
        </template>

        <clusters :limit="$options.MAX_CLUSTERS_LIST" :is-child-component="true" />

        <template #footer>
          <gl-link
            v-if="totalClusters"
            data-testid="clusters-tab-footer-link"
            :href="`?tab=${$options.i18n.certificate.tabName}`"
            @click="changeTab($event, $options.i18n.certificate.tabName)"
            ><gl-sprintf :message="$options.i18n.certificate.footerText"
              ><template #number>{{ cardFooterNumber(totalClusters) }}</template></gl-sprintf
            ></gl-link
          ><gl-button
            category="secondary"
            data-qa-selector="connect_existing_cluster_button"
            variant="confirm"
            class="gl-ml-4"
            :href="addClusterPath"
            >{{ $options.i18n.certificate.actionText }}</gl-button
          >
        </template>
      </gl-card>
    </div>
  </div>
</template>
