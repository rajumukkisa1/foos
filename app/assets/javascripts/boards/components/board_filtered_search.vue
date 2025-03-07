<script>
import { pickBy, isEmpty } from 'lodash';
import { mapActions } from 'vuex';
import { getIdFromGraphQLId, isGid } from '~/graphql_shared/utils';
import { updateHistory, setUrlParams } from '~/lib/utils/url_utility';
import { __ } from '~/locale';
import { FILTERED_SEARCH_TERM } from '~/vue_shared/components/filtered_search_bar/constants';
import FilteredSearch from '~/vue_shared/components/filtered_search_bar/filtered_search_bar_root.vue';

export default {
  i18n: {
    search: __('Search'),
    label: __('Label'),
    author: __('Author'),
  },
  components: { FilteredSearch },
  inject: ['initialFilterParams'],
  props: {
    tokens: {
      type: Array,
      required: true,
    },
    eeFilters: {
      required: false,
      type: Object,
      default: () => ({}),
    },
  },
  data() {
    return {
      filterParams: this.initialFilterParams,
    };
  },
  computed: {
    getFilteredSearchValue() {
      const {
        authorUsername,
        labelName,
        assigneeUsername,
        search,
        milestoneTitle,
        iterationId,
        types,
        weight,
        epicId,
        myReactionEmoji,
        releaseTag,
        confidential,
      } = this.filterParams;
      const filteredSearchValue = [];

      if (authorUsername) {
        filteredSearchValue.push({
          type: 'author',
          value: { data: authorUsername, operator: '=' },
        });
      }

      if (assigneeUsername) {
        filteredSearchValue.push({
          type: 'assignee',
          value: { data: assigneeUsername, operator: '=' },
        });
      }

      if (types) {
        filteredSearchValue.push({
          type: 'type',
          value: { data: types, operator: '=' },
        });
      }

      if (labelName?.length) {
        filteredSearchValue.push(
          ...labelName.map((label) => ({
            type: 'label',
            value: { data: label, operator: '=' },
          })),
        );
      }

      if (milestoneTitle) {
        filteredSearchValue.push({
          type: 'milestone',
          value: { data: milestoneTitle, operator: '=' },
        });
      }

      if (iterationId) {
        filteredSearchValue.push({
          type: 'iteration',
          value: { data: iterationId, operator: '=' },
        });
      }

      if (weight) {
        filteredSearchValue.push({
          type: 'weight',
          value: { data: weight, operator: '=' },
        });
      }

      if (myReactionEmoji) {
        filteredSearchValue.push({
          type: 'my-reaction',
          value: { data: myReactionEmoji, operator: '=' },
        });
      }

      if (releaseTag) {
        filteredSearchValue.push({
          type: 'release',
          value: { data: releaseTag, operator: '=' },
        });
      }

      if (confidential !== undefined) {
        filteredSearchValue.push({
          type: 'confidential',
          value: { data: confidential },
        });
      }

      if (epicId) {
        filteredSearchValue.push({
          type: 'epic',
          value: { data: epicId, operator: '=' },
        });
      }

      if (this.filterParams['not[authorUsername]']) {
        filteredSearchValue.push({
          type: 'author',
          value: { data: this.filterParams['not[authorUsername]'], operator: '!=' },
        });
      }

      if (this.filterParams['not[milestoneTitle]']) {
        filteredSearchValue.push({
          type: 'milestone',
          value: { data: this.filterParams['not[milestoneTitle]'], operator: '!=' },
        });
      }

      if (this.filterParams['not[iteration_id]']) {
        filteredSearchValue.push({
          type: 'iteration_id',
          value: { data: this.filterParams['not[iteration_id]'], operator: '!=' },
        });
      }

      if (this.filterParams['not[weight]']) {
        filteredSearchValue.push({
          type: 'weight',
          value: { data: this.filterParams['not[weight]'], operator: '!=' },
        });
      }

      if (this.filterParams['not[assigneeUsername]']) {
        filteredSearchValue.push({
          type: 'assignee',
          value: { data: this.filterParams['not[assigneeUsername]'], operator: '!=' },
        });
      }

      if (this.filterParams['not[labelName]']) {
        filteredSearchValue.push(
          ...this.filterParams['not[labelName]'].map((label) => ({
            type: 'label',
            value: { data: label, operator: '!=' },
          })),
        );
      }

      if (this.filterParams['not[types]']) {
        filteredSearchValue.push({
          type: 'type',
          value: { data: this.filterParams['not[types]'], operator: '!=' },
        });
      }

      if (this.filterParams['not[epicId]']) {
        filteredSearchValue.push({
          type: 'epic',
          value: { data: this.filterParams['not[epicId]'], operator: '!=' },
        });
      }

      if (this.filterParams['not[myReactionEmoji]']) {
        filteredSearchValue.push({
          type: 'my-reaction',
          value: { data: this.filterParams['not[myReactionEmoji]'], operator: '!=' },
        });
      }

      if (this.filterParams['not[releaseTag]']) {
        filteredSearchValue.push({
          type: 'release',
          value: { data: this.filterParams['not[releaseTag]'], operator: '!=' },
        });
      }

      if (search) {
        filteredSearchValue.push(search);
      }

      return filteredSearchValue;
    },
    urlParams() {
      const {
        authorUsername,
        labelName,
        assigneeUsername,
        search,
        milestoneTitle,
        types,
        weight,
        epicId,
        myReactionEmoji,
        iterationId,
        releaseTag,
        confidential,
      } = this.filterParams;
      let notParams = {};

      if (Object.prototype.hasOwnProperty.call(this.filterParams, 'not')) {
        notParams = pickBy(
          {
            'not[label_name][]': this.filterParams.not.labelName,
            'not[author_username]': this.filterParams.not.authorUsername,
            'not[assignee_username]': this.filterParams.not.assigneeUsername,
            'not[types]': this.filterParams.not.types,
            'not[milestone_title]': this.filterParams.not.milestoneTitle,
            'not[weight]': this.filterParams.not.weight,
            'not[epic_id]': this.filterParams.not.epicId,
            'not[my_reaction_emoji]': this.filterParams.not.myReactionEmoji,
            'not[iteration_id]': this.filterParams.not.iterationId,
            'not[release_tag]': this.filterParams.not.releaseTag,
          },
          undefined,
        );
      }

      return {
        ...notParams,
        author_username: authorUsername,
        'label_name[]': labelName,
        assignee_username: assigneeUsername,
        milestone_title: milestoneTitle,
        iteration_id: iterationId,
        search,
        types,
        weight,
        epic_id: isGid(epicId) ? getIdFromGraphQLId(epicId) : epicId,
        my_reaction_emoji: myReactionEmoji,
        release_tag: releaseTag,
        confidential,
      };
    },
  },
  created() {
    if (!isEmpty(this.eeFilters)) {
      this.filterParams = this.eeFilters;
    }
  },
  methods: {
    ...mapActions(['performSearch']),
    handleFilter(filters) {
      this.filterParams = this.getFilterParams(filters);

      updateHistory({
        url: setUrlParams(this.urlParams, window.location.href, true, false, true),
        title: document.title,
        replace: true,
      });

      this.performSearch();
    },
    getFilterParams(filters = []) {
      const notFilters = filters.filter((item) => item.value.operator === '!=');
      const equalsFilters = filters.filter(
        (item) => item?.value?.operator === '=' || item.type === FILTERED_SEARCH_TERM,
      );

      return { ...this.generateParams(equalsFilters), not: { ...this.generateParams(notFilters) } };
    },
    generateParams(filters = []) {
      const filterParams = {};
      const labels = [];
      const plainText = [];

      filters.forEach((filter) => {
        switch (filter.type) {
          case 'author':
            filterParams.authorUsername = filter.value.data;
            break;
          case 'assignee':
            filterParams.assigneeUsername = filter.value.data;
            break;
          case 'type':
            filterParams.types = filter.value.data;
            break;
          case 'label':
            labels.push(filter.value.data);
            break;
          case 'milestone':
            filterParams.milestoneTitle = filter.value.data;
            break;
          case 'iteration':
            filterParams.iterationId = filter.value.data;
            break;
          case 'weight':
            filterParams.weight = filter.value.data;
            break;
          case 'epic':
            filterParams.epicId = filter.value.data;
            break;
          case 'my-reaction':
            filterParams.myReactionEmoji = filter.value.data;
            break;
          case 'release':
            filterParams.releaseTag = filter.value.data;
            break;
          case 'confidential':
            filterParams.confidential = filter.value.data;
            break;
          case 'filtered-search-term':
            if (filter.value.data) plainText.push(filter.value.data);
            break;
          default:
            break;
        }
      });

      if (labels.length) {
        filterParams.labelName = labels;
      }

      if (plainText.length) {
        filterParams.search = plainText.join(' ');
      }

      return filterParams;
    },
  },
};
</script>

<template>
  <filtered-search
    class="gl-w-full"
    namespace=""
    :tokens="tokens"
    :search-input-placeholder="$options.i18n.search"
    :initial-filter-value="getFilteredSearchValue"
    @onFilter="handleFilter"
  />
</template>
