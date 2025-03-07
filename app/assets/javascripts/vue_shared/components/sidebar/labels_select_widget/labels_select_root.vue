<script>
import { debounce } from 'lodash';
import { MutationOperationMode, getIdFromGraphQLId } from '~/graphql_shared/utils';
import createFlash from '~/flash';
import { IssuableType } from '~/issues/show/constants';
import { __ } from '~/locale';
import SidebarEditableItem from '~/sidebar/components/sidebar_editable_item.vue';
import { issuableLabelsQueries } from '~/sidebar/constants';
import { DEBOUNCE_DROPDOWN_DELAY, DropdownVariant } from './constants';
import DropdownContents from './dropdown_contents.vue';
import DropdownValue from './dropdown_value.vue';
import DropdownValueCollapsed from './dropdown_value_collapsed.vue';
import {
  isDropdownVariantSidebar,
  isDropdownVariantStandalone,
  isDropdownVariantEmbedded,
} from './utils';

export default {
  components: {
    DropdownValue,
    DropdownContents,
    DropdownValueCollapsed,
    SidebarEditableItem,
  },
  inject: {
    allowLabelEdit: {
      default: false,
    },
  },
  props: {
    iid: {
      type: String,
      required: false,
      default: '',
    },
    fullPath: {
      type: String,
      required: true,
    },
    allowLabelRemove: {
      type: Boolean,
      required: false,
      default: false,
    },
    allowMultiselect: {
      type: Boolean,
      required: false,
      default: false,
    },
    variant: {
      type: String,
      required: false,
      default: DropdownVariant.Sidebar,
    },
    labelsFilterBasePath: {
      type: String,
      required: false,
      default: '',
    },
    labelsFilterParam: {
      type: String,
      required: false,
      default: 'label_name',
    },
    dropdownButtonText: {
      type: String,
      required: false,
      default: __('Label'),
    },
    labelsListTitle: {
      type: String,
      required: false,
      default: __('Assign labels'),
    },
    labelsCreateTitle: {
      type: String,
      required: false,
      default: __('Create group label'),
    },
    footerCreateLabelTitle: {
      type: String,
      required: false,
      default: __('Create group label'),
    },
    footerManageLabelTitle: {
      type: String,
      required: false,
      default: __('Manage group labels'),
    },
    issuableType: {
      type: String,
      required: true,
    },
    workspaceType: {
      type: String,
      required: true,
    },
    attrWorkspacePath: {
      type: String,
      required: true,
    },
    labelCreateType: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      contentIsOnViewport: true,
      issuableLabels: [],
      labelsSelectInProgress: false,
      oldIid: null,
      sidebarExpandedOnClick: false,
    };
  },
  computed: {
    isLoading() {
      return this.labelsSelectInProgress || this.$apollo.queries.issuableLabels.loading;
    },
    issuableLabelIds() {
      return this.issuableLabels.map((label) => label.id);
    },
  },
  apollo: {
    issuableLabels: {
      query() {
        return issuableLabelsQueries[this.issuableType].issuableQuery;
      },
      skip() {
        return !isDropdownVariantSidebar(this.variant);
      },
      variables() {
        return {
          iid: this.iid,
          fullPath: this.fullPath,
        };
      },
      update(data) {
        return data.workspace?.issuable?.labels.nodes || [];
      },
      error() {
        createFlash({ message: __('Error fetching labels.') });
      },
    },
  },
  watch: {
    iid(_, oldVal) {
      this.oldIid = oldVal;
    },
  },
  mounted() {
    document.addEventListener('toggleSidebarRevealLabelsDropdown', this.handleCollapsedValueClick);
  },
  beforeDestroy() {
    document.removeEventListener(
      'toggleSidebarRevealLabelsDropdown',
      this.handleCollapsedValueClick,
    );
  },
  methods: {
    handleDropdownClose(labels) {
      if (this.iid !== '') {
        this.updateSelectedLabels(this.getUpdateVariables(labels));
      } else {
        this.$emit('updateSelectedLabels', { labels });
      }

      this.collapseEditableItem();
    },
    collapseEditableItem() {
      this.$refs.editable?.collapse();
      if (this.sidebarExpandedOnClick) {
        this.sidebarExpandedOnClick = false;
        this.$emit('toggleCollapse');
      }
    },
    handleCollapsedValueClick() {
      this.sidebarExpandedOnClick = true;
      this.$emit('toggleCollapse');
      debounce(() => {
        this.$refs.editable.toggle();
        this.$refs.dropdownContents.showDropdown();
      }, DEBOUNCE_DROPDOWN_DELAY)();
    },
    getUpdateVariables(labels) {
      let labelIds = [];

      labelIds = labels.map(({ id }) => id);
      const currentIid = this.oldIid || this.iid;

      const updateVariables = {
        iid: currentIid,
        projectPath: this.fullPath,
        labelIds,
      };

      switch (this.issuableType) {
        case IssuableType.Issue:
          return updateVariables;
        case IssuableType.MergeRequest:
          return {
            ...updateVariables,
            operationMode: MutationOperationMode.Replace,
          };
        case IssuableType.Epic:
          return {
            iid: currentIid,
            groupPath: this.fullPath,
            addLabelIds: labelIds.map((id) => getIdFromGraphQLId(id)),
            removeLabelIds: this.issuableLabelIds
              .filter((id) => !labelIds.includes(id))
              .map((id) => getIdFromGraphQLId(id)),
          };
        default:
          return {};
      }
    },
    updateSelectedLabels(inputVariables) {
      this.labelsSelectInProgress = true;

      this.$apollo
        .mutate({
          mutation: issuableLabelsQueries[this.issuableType].mutation,
          variables: { input: inputVariables },
        })
        .then(({ data }) => {
          if (data.updateIssuableLabels?.errors?.length) {
            throw new Error();
          }

          this.$emit('updateSelectedLabels', {
            id: data.updateIssuableLabels?.issuable?.id,
            labels: data.updateIssuableLabels?.issuable?.labels?.nodes,
          });
        })
        .catch((error) =>
          createFlash({
            message: __('An error occurred while updating labels.'),
            captureError: true,
            error,
          }),
        )
        .finally(() => {
          this.labelsSelectInProgress = false;
        });
    },
    getRemoveVariables(labelId) {
      const removeVariables = {
        iid: this.iid,
        projectPath: this.fullPath,
      };

      switch (this.issuableType) {
        case IssuableType.Issue:
          return {
            ...removeVariables,
            removeLabelIds: [labelId],
          };
        case IssuableType.MergeRequest:
          return {
            ...removeVariables,
            labelIds: [labelId],
            operationMode: MutationOperationMode.Remove,
          };
        case IssuableType.Epic:
          return {
            iid: this.iid,
            removeLabelIds: [getIdFromGraphQLId(labelId)],
            groupPath: this.fullPath,
          };
        default:
          return {};
      }
    },
    handleLabelRemove(labelId) {
      this.updateSelectedLabels(this.getRemoveVariables(labelId));
      this.$emit('onLabelRemove', labelId);
    },
    isDropdownVariantSidebar,
    isDropdownVariantStandalone,
    isDropdownVariantEmbedded,
  },
};
</script>

<template>
  <div
    class="labels-select-wrapper gl-relative"
    :class="{
      'is-standalone': isDropdownVariantStandalone(variant),
      'is-embedded': isDropdownVariantEmbedded(variant),
    }"
    data-qa-selector="labels_block"
  >
    <template v-if="isDropdownVariantSidebar(variant)">
      <dropdown-value-collapsed
        ref="dropdownButtonCollapsed"
        :labels="issuableLabels"
        @onValueClick="handleCollapsedValueClick"
      />
      <sidebar-editable-item
        ref="editable"
        :title="__('Labels')"
        :loading="isLoading"
        :can-edit="allowLabelEdit"
        @open="oldIid = null"
      >
        <template #collapsed>
          <dropdown-value
            :disable-labels="labelsSelectInProgress"
            :selected-labels="issuableLabels"
            :allow-label-remove="allowLabelRemove"
            :labels-filter-base-path="labelsFilterBasePath"
            :labels-filter-param="labelsFilterParam"
            @onLabelRemove="handleLabelRemove"
          >
            <slot></slot>
          </dropdown-value>
        </template>
        <template #default="{ edit }">
          <dropdown-value
            :disable-labels="labelsSelectInProgress"
            :selected-labels="issuableLabels"
            :allow-label-remove="allowLabelRemove"
            :labels-filter-base-path="labelsFilterBasePath"
            :labels-filter-param="labelsFilterParam"
            class="gl-mb-2"
            @onLabelRemove="handleLabelRemove"
          >
            <slot></slot>
          </dropdown-value>
          <dropdown-contents
            ref="dropdownContents"
            :dropdown-button-text="dropdownButtonText"
            :allow-multiselect="allowMultiselect"
            :labels-list-title="labelsListTitle"
            :footer-create-label-title="footerCreateLabelTitle"
            :footer-manage-label-title="footerManageLabelTitle"
            :labels-create-title="labelsCreateTitle"
            :selected-labels="issuableLabels"
            :variant="variant"
            :is-visible="edit"
            :full-path="fullPath"
            :workspace-type="workspaceType"
            :attr-workspace-path="attrWorkspacePath"
            :label-create-type="labelCreateType"
            @setLabels="handleDropdownClose"
            @closeDropdown="collapseEditableItem"
          />
        </template>
      </sidebar-editable-item>
    </template>
    <dropdown-contents
      v-else
      ref="dropdownContents"
      :allow-multiselect="allowMultiselect"
      :dropdown-button-text="dropdownButtonText"
      :labels-list-title="labelsListTitle"
      :footer-create-label-title="footerCreateLabelTitle"
      :footer-manage-label-title="footerManageLabelTitle"
      :labels-create-title="labelsCreateTitle"
      :selected-labels="issuableLabels"
      :variant="variant"
      :full-path="fullPath"
      :workspace-type="workspaceType"
      :attr-workspace-path="attrWorkspacePath"
      :label-create-type="labelCreateType"
      @setLabels="handleDropdownClose"
    />
  </div>
</template>
