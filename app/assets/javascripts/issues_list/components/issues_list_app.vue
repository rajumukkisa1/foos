<script>
import {
  GlButton,
  GlEmptyState,
  GlFilteredSearchToken,
  GlIcon,
  GlLink,
  GlSprintf,
  GlTooltipDirective,
} from '@gitlab/ui';
import fuzzaldrinPlus from 'fuzzaldrin-plus';
import getIssuesQuery from 'ee_else_ce/issues_list/queries/get_issues.query.graphql';
import getIssuesCountsQuery from 'ee_else_ce/issues_list/queries/get_issues_counts.query.graphql';
import IssueCardTimeInfo from 'ee_else_ce/issues_list/components/issue_card_time_info.vue';
import createFlash, { FLASH_TYPES } from '~/flash';
import { TYPE_USER } from '~/graphql_shared/constants';
import { convertToGraphQLId, getIdFromGraphQLId } from '~/graphql_shared/utils';
import { ITEM_TYPE } from '~/groups/constants';
import CsvImportExportButtons from '~/issuable/components/csv_import_export_buttons.vue';
import IssuableByEmail from '~/issuable/components/issuable_by_email.vue';
import IssuableList from '~/vue_shared/issuable/list/components/issuable_list_root.vue';
import { IssuableListTabs, IssuableStates } from '~/vue_shared/issuable/list/constants';
import {
  CREATED_DESC,
  i18n,
  MAX_LIST_SIZE,
  PAGE_SIZE,
  PARAM_DUE_DATE,
  PARAM_SORT,
  PARAM_STATE,
  RELATIVE_POSITION_ASC,
  TOKEN_TYPE_ASSIGNEE,
  TOKEN_TYPE_AUTHOR,
  TOKEN_TYPE_CONFIDENTIAL,
  TOKEN_TYPE_LABEL,
  TOKEN_TYPE_MILESTONE,
  TOKEN_TYPE_MY_REACTION,
  TOKEN_TYPE_RELEASE,
  TOKEN_TYPE_TYPE,
  UPDATED_DESC,
  urlSortParams,
} from '~/issues_list/constants';
import {
  convertToApiParams,
  convertToSearchQuery,
  convertToUrlParams,
  getDueDateValue,
  getFilterTokens,
  getInitialPageParams,
  getSortKey,
  getSortOptions,
} from '~/issues_list/utils';
import axios from '~/lib/utils/axios_utils';
import { scrollUp } from '~/lib/utils/scroll_utils';
import { getParameterByName, joinPaths } from '~/lib/utils/url_utility';
import {
  DEFAULT_NONE_ANY,
  OPERATOR_IS_ONLY,
  TOKEN_TITLE_ASSIGNEE,
  TOKEN_TITLE_AUTHOR,
  TOKEN_TITLE_CONFIDENTIAL,
  TOKEN_TITLE_LABEL,
  TOKEN_TITLE_MILESTONE,
  TOKEN_TITLE_MY_REACTION,
  TOKEN_TITLE_RELEASE,
  TOKEN_TITLE_TYPE,
} from '~/vue_shared/components/filtered_search_bar/constants';
import eventHub from '../eventhub';
import reorderIssuesMutation from '../queries/reorder_issues.mutation.graphql';
import searchLabelsQuery from '../queries/search_labels.query.graphql';
import searchMilestonesQuery from '../queries/search_milestones.query.graphql';
import searchUsersQuery from '../queries/search_users.query.graphql';
import NewIssueDropdown from './new_issue_dropdown.vue';

const AuthorToken = () =>
  import('~/vue_shared/components/filtered_search_bar/tokens/author_token.vue');
const EmojiToken = () =>
  import('~/vue_shared/components/filtered_search_bar/tokens/emoji_token.vue');
const LabelToken = () =>
  import('~/vue_shared/components/filtered_search_bar/tokens/label_token.vue');
const MilestoneToken = () =>
  import('~/vue_shared/components/filtered_search_bar/tokens/milestone_token.vue');
const ReleaseToken = () =>
  import('~/vue_shared/components/filtered_search_bar/tokens/release_token.vue');

export default {
  i18n,
  IssuableListTabs,
  components: {
    CsvImportExportButtons,
    GlButton,
    GlEmptyState,
    GlIcon,
    GlLink,
    GlSprintf,
    IssuableByEmail,
    IssuableList,
    IssueCardTimeInfo,
    NewIssueDropdown,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  inject: {
    autocompleteAwardEmojisPath: {
      default: '',
    },
    calendarPath: {
      default: '',
    },
    canBulkUpdate: {
      default: false,
    },
    emptyStateSvgPath: {
      default: '',
    },
    exportCsvPath: {
      default: '',
    },
    fullPath: {
      default: '',
    },
    hasAnyIssues: {
      default: false,
    },
    hasAnyProjects: {
      default: false,
    },
    hasBlockedIssuesFeature: {
      default: false,
    },
    hasIssueWeightsFeature: {
      default: false,
    },
    hasMultipleIssueAssigneesFeature: {
      default: false,
    },
    initialEmail: {
      default: '',
    },
    isIssueRepositioningDisabled: {
      default: false,
    },
    isProject: {
      default: false,
    },
    isSignedIn: {
      default: false,
    },
    jiraIntegrationPath: {
      default: '',
    },
    newIssuePath: {
      default: '',
    },
    releasesPath: {
      default: '',
    },
    rssPath: {
      default: '',
    },
    showNewIssueLink: {
      default: false,
    },
    signInPath: {
      default: '',
    },
  },
  props: {
    eeSearchTokens: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  data() {
    const state = getParameterByName(PARAM_STATE);
    const defaultSortKey = state === IssuableStates.Closed ? UPDATED_DESC : CREATED_DESC;
    let sortKey = getSortKey(getParameterByName(PARAM_SORT)) || defaultSortKey;

    if (this.isIssueRepositioningDisabled && sortKey === RELATIVE_POSITION_ASC) {
      this.showIssueRepositioningMessage();
      sortKey = defaultSortKey;
    }

    return {
      dueDateFilter: getDueDateValue(getParameterByName(PARAM_DUE_DATE)),
      exportCsvPathWithQuery: this.getExportCsvPathWithQuery(),
      filterTokens: getFilterTokens(window.location.search),
      issues: [],
      issuesCounts: {},
      pageInfo: {},
      pageParams: getInitialPageParams(sortKey),
      showBulkEditSidebar: false,
      sortKey,
      state: state || IssuableStates.Opened,
    };
  },
  apollo: {
    issues: {
      query: getIssuesQuery,
      variables() {
        return this.queryVariables;
      },
      update(data) {
        return data[this.namespace]?.issues.nodes ?? [];
      },
      result({ data }) {
        this.pageInfo = data[this.namespace]?.issues.pageInfo ?? {};
        this.exportCsvPathWithQuery = this.getExportCsvPathWithQuery();
      },
      error(error) {
        createFlash({ message: this.$options.i18n.errorFetchingIssues, captureError: true, error });
      },
      skip() {
        return !this.hasAnyIssues;
      },
      debounce: 200,
    },
    issuesCounts: {
      query: getIssuesCountsQuery,
      variables() {
        return this.queryVariables;
      },
      update(data) {
        return data[this.namespace] ?? {};
      },
      error(error) {
        createFlash({ message: this.$options.i18n.errorFetchingCounts, captureError: true, error });
      },
      skip() {
        return !this.hasAnyIssues;
      },
      debounce: 200,
      context: {
        isSingleRequest: true,
      },
    },
  },
  computed: {
    queryVariables() {
      return {
        fullPath: this.fullPath,
        isProject: this.isProject,
        isSignedIn: this.isSignedIn,
        search: this.searchQuery,
        sort: this.sortKey,
        state: this.state,
        ...this.pageParams,
        ...this.apiFilterParams,
      };
    },
    namespace() {
      return this.isProject ? ITEM_TYPE.PROJECT : ITEM_TYPE.GROUP;
    },
    hasSearch() {
      return this.searchQuery || Object.keys(this.urlFilterParams).length;
    },
    isBulkEditButtonDisabled() {
      return this.showBulkEditSidebar || !this.issues.length;
    },
    isManualOrdering() {
      return this.sortKey === RELATIVE_POSITION_ASC;
    },
    isOpenTab() {
      return this.state === IssuableStates.Opened;
    },
    showCsvButtons() {
      return this.isProject && this.isSignedIn;
    },
    showNewIssueDropdown() {
      return !this.isProject && this.hasAnyProjects;
    },
    apiFilterParams() {
      return convertToApiParams(this.filterTokens);
    },
    urlFilterParams() {
      return convertToUrlParams(this.filterTokens);
    },
    searchQuery() {
      return convertToSearchQuery(this.filterTokens) || undefined;
    },
    searchTokens() {
      const preloadedAuthors = [];

      if (gon.current_user_id) {
        preloadedAuthors.push({
          id: convertToGraphQLId(TYPE_USER, gon.current_user_id),
          name: gon.current_user_fullname,
          username: gon.current_username,
          avatar_url: gon.current_user_avatar_url,
        });
      }

      const tokens = [
        {
          type: TOKEN_TYPE_AUTHOR,
          title: TOKEN_TITLE_AUTHOR,
          icon: 'pencil',
          token: AuthorToken,
          dataType: 'user',
          unique: true,
          defaultAuthors: [],
          fetchAuthors: this.fetchUsers,
          recentSuggestionsStorageKey: `${this.fullPath}-issues-recent-tokens-author`,
          preloadedAuthors,
        },
        {
          type: TOKEN_TYPE_ASSIGNEE,
          title: TOKEN_TITLE_ASSIGNEE,
          icon: 'user',
          token: AuthorToken,
          dataType: 'user',
          unique: !this.hasMultipleIssueAssigneesFeature,
          defaultAuthors: DEFAULT_NONE_ANY,
          fetchAuthors: this.fetchUsers,
          recentSuggestionsStorageKey: `${this.fullPath}-issues-recent-tokens-assignee`,
          preloadedAuthors,
        },
        {
          type: TOKEN_TYPE_MILESTONE,
          title: TOKEN_TITLE_MILESTONE,
          icon: 'clock',
          token: MilestoneToken,
          fetchMilestones: this.fetchMilestones,
          recentSuggestionsStorageKey: `${this.fullPath}-issues-recent-tokens-milestone`,
        },
        {
          type: TOKEN_TYPE_LABEL,
          title: TOKEN_TITLE_LABEL,
          icon: 'labels',
          token: LabelToken,
          defaultLabels: DEFAULT_NONE_ANY,
          fetchLabels: this.fetchLabels,
          recentSuggestionsStorageKey: `${this.fullPath}-issues-recent-tokens-label`,
        },
        {
          type: TOKEN_TYPE_TYPE,
          title: TOKEN_TITLE_TYPE,
          icon: 'issues',
          token: GlFilteredSearchToken,
          options: [
            { icon: 'issue-type-issue', title: 'issue', value: 'issue' },
            { icon: 'issue-type-incident', title: 'incident', value: 'incident' },
            { icon: 'issue-type-test-case', title: 'test_case', value: 'test_case' },
          ],
        },
      ];

      if (this.isProject) {
        tokens.push({
          type: TOKEN_TYPE_RELEASE,
          title: TOKEN_TITLE_RELEASE,
          icon: 'rocket',
          token: ReleaseToken,
          fetchReleases: this.fetchReleases,
          recentSuggestionsStorageKey: `${this.fullPath}-issues-recent-tokens-release`,
        });
      }

      if (this.isSignedIn) {
        tokens.push({
          type: TOKEN_TYPE_MY_REACTION,
          title: TOKEN_TITLE_MY_REACTION,
          icon: 'thumb-up',
          token: EmojiToken,
          unique: true,
          fetchEmojis: this.fetchEmojis,
          recentSuggestionsStorageKey: `${this.fullPath}-issues-recent-tokens-my_reaction`,
        });

        tokens.push({
          type: TOKEN_TYPE_CONFIDENTIAL,
          title: TOKEN_TITLE_CONFIDENTIAL,
          icon: 'eye-slash',
          token: GlFilteredSearchToken,
          unique: true,
          operators: OPERATOR_IS_ONLY,
          options: [
            { icon: 'eye-slash', value: 'yes', title: this.$options.i18n.confidentialYes },
            { icon: 'eye', value: 'no', title: this.$options.i18n.confidentialNo },
          ],
        });
      }

      if (this.eeSearchTokens.length) {
        tokens.push(...this.eeSearchTokens);
      }

      return tokens;
    },
    showPaginationControls() {
      return this.issues.length > 0 && (this.pageInfo.hasNextPage || this.pageInfo.hasPreviousPage);
    },
    sortOptions() {
      return getSortOptions(this.hasIssueWeightsFeature, this.hasBlockedIssuesFeature);
    },
    tabCounts() {
      const { openedIssues, closedIssues, allIssues } = this.issuesCounts;
      return {
        [IssuableStates.Opened]: openedIssues?.count,
        [IssuableStates.Closed]: closedIssues?.count,
        [IssuableStates.All]: allIssues?.count,
      };
    },
    currentTabCount() {
      return this.tabCounts[this.state] ?? 0;
    },
    urlParams() {
      return {
        due_date: this.dueDateFilter,
        search: this.searchQuery,
        sort: urlSortParams[this.sortKey],
        state: this.state,
        ...this.urlFilterParams,
      };
    },
  },
  created() {
    this.cache = {};
  },
  mounted() {
    eventHub.$on('issuables:toggleBulkEdit', this.toggleBulkEditSidebar);
  },
  beforeDestroy() {
    eventHub.$off('issuables:toggleBulkEdit', this.toggleBulkEditSidebar);
  },
  methods: {
    fetchWithCache(path, cacheName, searchKey, search, wrapData = false) {
      if (this.cache[cacheName]) {
        const data = search
          ? fuzzaldrinPlus.filter(this.cache[cacheName], search, { key: searchKey })
          : this.cache[cacheName].slice(0, MAX_LIST_SIZE);
        return wrapData ? Promise.resolve({ data }) : Promise.resolve(data);
      }

      return axios.get(path).then(({ data }) => {
        this.cache[cacheName] = data;
        const result = data.slice(0, MAX_LIST_SIZE);
        return wrapData ? { data: result } : result;
      });
    },
    fetchEmojis(search) {
      return this.fetchWithCache(this.autocompleteAwardEmojisPath, 'emojis', 'name', search);
    },
    fetchReleases(search) {
      return this.fetchWithCache(this.releasesPath, 'releases', 'tag', search);
    },
    fetchLabels(search) {
      return this.$apollo
        .query({
          query: searchLabelsQuery,
          variables: { fullPath: this.fullPath, search, isProject: this.isProject },
        })
        .then(({ data }) => data[this.namespace]?.labels.nodes)
        .then((labels) =>
          // TODO remove once we can search by title-only on the backend
          // https://gitlab.com/gitlab-org/gitlab/-/issues/346353
          labels.filter((label) => label.title.toLowerCase().includes(search.toLowerCase())),
        );
    },
    fetchMilestones(search) {
      return this.$apollo
        .query({
          query: searchMilestonesQuery,
          variables: { fullPath: this.fullPath, search, isProject: this.isProject },
        })
        .then(({ data }) => data[this.namespace]?.milestones.nodes);
    },
    fetchUsers(search) {
      return this.$apollo
        .query({
          query: searchUsersQuery,
          variables: { fullPath: this.fullPath, search, isProject: this.isProject },
        })
        .then(({ data }) =>
          data[this.namespace]?.[`${this.namespace}Members`].nodes.map((member) => member.user),
        );
    },
    getExportCsvPathWithQuery() {
      return `${this.exportCsvPath}${window.location.search}`;
    },
    getStatus(issue) {
      if (issue.closedAt && issue.moved) {
        return this.$options.i18n.closedMoved;
      }
      if (issue.closedAt) {
        return this.$options.i18n.closed;
      }
      return undefined;
    },
    handleUpdateLegacyBulkEdit() {
      // If "select all" checkbox was checked, wait for all checkboxes
      // to be checked before updating IssuableBulkUpdateSidebar class
      this.$nextTick(() => {
        eventHub.$emit('issuables:updateBulkEdit');
      });
    },
    async handleBulkUpdateClick() {
      if (!this.hasInitBulkEdit) {
        const initBulkUpdateSidebar = await import(
          '~/issuable/bulk_update_sidebar/issuable_init_bulk_update_sidebar'
        );
        initBulkUpdateSidebar.default.init('issuable_');

        const usersSelect = await import('~/users_select');
        const UsersSelect = usersSelect.default;
        new UsersSelect(); // eslint-disable-line no-new

        this.hasInitBulkEdit = true;
      }

      eventHub.$emit('issuables:enableBulkEdit');
    },
    handleClickTab(state) {
      if (this.state !== state) {
        this.pageParams = getInitialPageParams(this.sortKey);
      }
      this.state = state;
    },
    handleFilter(filter) {
      this.pageParams = getInitialPageParams(this.sortKey);
      this.filterTokens = filter;
    },
    handleNextPage() {
      this.pageParams = {
        afterCursor: this.pageInfo.endCursor,
        firstPageSize: PAGE_SIZE,
      };
      scrollUp();
    },
    handlePreviousPage() {
      this.pageParams = {
        beforeCursor: this.pageInfo.startCursor,
        lastPageSize: PAGE_SIZE,
      };
      scrollUp();
    },
    handleReorder({ newIndex, oldIndex }) {
      const issueToMove = this.issues[oldIndex];
      const isDragDropDownwards = newIndex > oldIndex;
      const isMovingToBeginning = newIndex === 0;
      const isMovingToEnd = newIndex === this.issues.length - 1;

      let moveBeforeId;
      let moveAfterId;

      if (isDragDropDownwards) {
        const afterIndex = isMovingToEnd ? newIndex : newIndex + 1;
        moveBeforeId = this.issues[newIndex].id;
        moveAfterId = this.issues[afterIndex].id;
      } else {
        const beforeIndex = isMovingToBeginning ? newIndex : newIndex - 1;
        moveBeforeId = this.issues[beforeIndex].id;
        moveAfterId = this.issues[newIndex].id;
      }

      return axios
        .put(joinPaths(issueToMove.webPath, 'reorder'), {
          move_before_id: isMovingToBeginning ? null : getIdFromGraphQLId(moveBeforeId),
          move_after_id: isMovingToEnd ? null : getIdFromGraphQLId(moveAfterId),
          group_full_path: this.isProject ? undefined : this.fullPath,
        })
        .then(() => {
          const serializedVariables = JSON.stringify(this.queryVariables);
          return this.$apollo.mutate({
            mutation: reorderIssuesMutation,
            variables: { oldIndex, newIndex, namespace: this.namespace, serializedVariables },
          });
        })
        .catch((error) => {
          createFlash({ message: this.$options.i18n.reorderError, captureError: true, error });
        });
    },
    handleSort(sortKey) {
      if (this.isIssueRepositioningDisabled && sortKey === RELATIVE_POSITION_ASC) {
        this.showIssueRepositioningMessage();
        return;
      }

      if (this.sortKey !== sortKey) {
        this.pageParams = getInitialPageParams(sortKey);
      }
      this.sortKey = sortKey;
    },
    showIssueRepositioningMessage() {
      createFlash({
        message: this.$options.i18n.issueRepositioningMessage,
        type: FLASH_TYPES.NOTICE,
      });
    },
    toggleBulkEditSidebar(showBulkEditSidebar) {
      this.showBulkEditSidebar = showBulkEditSidebar;
    },
  },
};
</script>

<template>
  <div v-if="hasAnyIssues">
    <issuable-list
      :namespace="fullPath"
      recent-searches-storage-key="issues"
      :search-input-placeholder="$options.i18n.searchPlaceholder"
      :search-tokens="searchTokens"
      :initial-filter-value="filterTokens"
      :sort-options="sortOptions"
      :initial-sort-by="sortKey"
      :issuables="issues"
      label-filter-param="label_name"
      :tabs="$options.IssuableListTabs"
      :current-tab="state"
      :tab-counts="tabCounts"
      :issuables-loading="$apollo.queries.issues.loading"
      :is-manual-ordering="isManualOrdering"
      :show-bulk-edit-sidebar="showBulkEditSidebar"
      :show-pagination-controls="showPaginationControls"
      :use-keyset-pagination="true"
      :has-next-page="pageInfo.hasNextPage"
      :has-previous-page="pageInfo.hasPreviousPage"
      :url-params="urlParams"
      @click-tab="handleClickTab"
      @filter="handleFilter"
      @next-page="handleNextPage"
      @previous-page="handlePreviousPage"
      @reorder="handleReorder"
      @sort="handleSort"
      @update-legacy-bulk-edit="handleUpdateLegacyBulkEdit"
    >
      <template #nav-actions>
        <gl-button
          v-gl-tooltip
          :href="rssPath"
          icon="rss"
          :title="$options.i18n.rssLabel"
          :aria-label="$options.i18n.rssLabel"
        />
        <gl-button
          v-gl-tooltip
          :href="calendarPath"
          icon="calendar"
          :title="$options.i18n.calendarLabel"
          :aria-label="$options.i18n.calendarLabel"
        />
        <csv-import-export-buttons
          v-if="showCsvButtons"
          class="gl-md-mr-3"
          :export-csv-path="exportCsvPathWithQuery"
          :issuable-count="currentTabCount"
        />
        <gl-button
          v-if="canBulkUpdate"
          :disabled="isBulkEditButtonDisabled"
          @click="handleBulkUpdateClick"
        >
          {{ $options.i18n.editIssues }}
        </gl-button>
        <gl-button v-if="showNewIssueLink" :href="newIssuePath" variant="confirm">
          {{ $options.i18n.newIssueLabel }}
        </gl-button>
        <new-issue-dropdown v-if="showNewIssueDropdown" />
      </template>

      <template #timeframe="{ issuable = {} }">
        <issue-card-time-info :issue="issuable" />
      </template>

      <template #status="{ issuable = {} }">
        {{ getStatus(issuable) }}
      </template>

      <template #statistics="{ issuable = {} }">
        <li
          v-if="issuable.mergeRequestsCount"
          v-gl-tooltip
          class="gl-display-none gl-sm-display-block"
          :title="$options.i18n.relatedMergeRequests"
          data-testid="merge-requests"
        >
          <gl-icon name="merge-request" />
          {{ issuable.mergeRequestsCount }}
        </li>
        <li
          v-if="issuable.upvotes"
          v-gl-tooltip
          class="issuable-upvotes gl-display-none gl-sm-display-block"
          :title="$options.i18n.upvotes"
          data-testid="issuable-upvotes"
        >
          <gl-icon name="thumb-up" />
          {{ issuable.upvotes }}
        </li>
        <li
          v-if="issuable.downvotes"
          v-gl-tooltip
          class="issuable-downvotes gl-display-none gl-sm-display-block"
          :title="$options.i18n.downvotes"
          data-testid="issuable-downvotes"
        >
          <gl-icon name="thumb-down" />
          {{ issuable.downvotes }}
        </li>
        <slot :issuable="issuable"></slot>
      </template>

      <template #empty-state>
        <gl-empty-state
          v-if="hasSearch"
          :description="$options.i18n.noSearchResultsDescription"
          :title="$options.i18n.noSearchResultsTitle"
          :svg-path="emptyStateSvgPath"
        >
          <template #actions>
            <gl-button v-if="showNewIssueLink" :href="newIssuePath" variant="confirm">
              {{ $options.i18n.newIssueLabel }}
            </gl-button>
          </template>
        </gl-empty-state>

        <gl-empty-state
          v-else-if="isOpenTab"
          :description="$options.i18n.noOpenIssuesDescription"
          :title="$options.i18n.noOpenIssuesTitle"
          :svg-path="emptyStateSvgPath"
        >
          <template #actions>
            <gl-button v-if="showNewIssueLink" :href="newIssuePath" variant="confirm">
              {{ $options.i18n.newIssueLabel }}
            </gl-button>
          </template>
        </gl-empty-state>

        <gl-empty-state
          v-else
          :title="$options.i18n.noClosedIssuesTitle"
          :svg-path="emptyStateSvgPath"
        />
      </template>
    </issuable-list>

    <issuable-by-email v-if="initialEmail" class="gl-text-center gl-pt-5 gl-pb-7" />
  </div>

  <div v-else-if="isSignedIn">
    <gl-empty-state
      :description="$options.i18n.noIssuesSignedInDescription"
      :title="$options.i18n.noIssuesSignedInTitle"
      :svg-path="emptyStateSvgPath"
    >
      <template #actions>
        <gl-button v-if="showNewIssueLink" :href="newIssuePath" variant="confirm">
          {{ $options.i18n.newIssueLabel }}
        </gl-button>
        <csv-import-export-buttons
          v-if="showCsvButtons"
          class="gl-mr-3"
          :export-csv-path="exportCsvPathWithQuery"
          :issuable-count="currentTabCount"
        />
        <new-issue-dropdown v-if="showNewIssueDropdown" />
      </template>
    </gl-empty-state>
    <hr />
    <p class="gl-text-center gl-font-weight-bold gl-mb-0">
      {{ $options.i18n.jiraIntegrationTitle }}
    </p>
    <p class="gl-text-center gl-mb-0">
      <gl-sprintf :message="$options.i18n.jiraIntegrationMessage">
        <template #jiraDocsLink="{ content }">
          <gl-link :href="jiraIntegrationPath">{{ content }}</gl-link>
        </template>
      </gl-sprintf>
    </p>
    <p class="gl-text-center gl-text-gray-500">
      {{ $options.i18n.jiraIntegrationSecondaryMessage }}
    </p>
  </div>

  <gl-empty-state
    v-else
    :description="$options.i18n.noIssuesSignedOutDescription"
    :title="$options.i18n.noIssuesSignedOutTitle"
    :svg-path="emptyStateSvgPath"
    :primary-button-text="$options.i18n.noIssuesSignedOutButtonText"
    :primary-button-link="signInPath"
  />
</template>
