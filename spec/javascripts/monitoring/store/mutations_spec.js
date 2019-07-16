import mutations from '~/monitoring/stores/mutations';
import * as types from '~/monitoring/stores/mutation_types';
import state from '~/monitoring/stores/state';
import {
  metricsNewGroupsAPIResponse,
  deploymentData,
  metricsDashboardResponse,
  dashboardGitResponse,
} from '../mock_data';

describe('Monitoring mutations', () => {
  let stateCopy;

  beforeEach(() => {
    stateCopy = state();
  });

  describe(types.RECEIVE_METRICS_DATA_SUCCESS, () => {
    let groups;

    beforeEach(() => {
      stateCopy.groups = [];
      groups = metricsNewGroupsAPIResponse;
    });

    it('normalizes values', () => {
      mutations[types.RECEIVE_METRICS_DATA_SUCCESS](stateCopy, groups);

      const expectedLabel = 'Pod average';
      const { label, query_range } = stateCopy.groups[0].panels[0].metrics[0];

      expect(label).toEqual(expectedLabel);
      expect(query_range.length).toBeGreaterThan(0);
    });

    it('contains one group, which it has one panel and one metrics property', () => {
      mutations[types.RECEIVE_METRICS_DATA_SUCCESS](stateCopy, groups);

      expect(stateCopy.groups).toBeDefined();
      expect(stateCopy.groups.length).toEqual(1);
      expect(stateCopy.groups[0].panels.length).toEqual(1);
      expect(stateCopy.groups[0].panels[0].metrics.length).toEqual(1);
    });

    it('assigns queries a metric id', () => {
      mutations[types.RECEIVE_METRICS_DATA_SUCCESS](stateCopy, groups);

      expect(stateCopy.groups[0].panels[0].metrics[0].metric_id).toEqual(17);
    });

    describe('dashboard endpoint enabled', () => {
      const dashboardGroups = metricsDashboardResponse.dashboard.panel_groups;

      it('aliases group panels to metrics for backwards compatibility', () => {
        mutations[types.RECEIVE_METRICS_DATA_SUCCESS](stateCopy, dashboardGroups);

        expect(stateCopy.groups[0].metrics[0]).toBeDefined();
      });

      it('aliases panel metrics to queries for backwards compatibility', () => {
        mutations[types.RECEIVE_METRICS_DATA_SUCCESS](stateCopy, dashboardGroups);

        expect(stateCopy.groups[0].metrics[0].queries).toBeDefined();
      });
    });
  });

  describe(types.RECEIVE_DEPLOYMENTS_DATA_SUCCESS, () => {
    it('stores the deployment data', () => {
      stateCopy.deploymentData = [];
      mutations[types.RECEIVE_DEPLOYMENTS_DATA_SUCCESS](stateCopy, deploymentData);

      expect(stateCopy.deploymentData).toBeDefined();
      expect(stateCopy.deploymentData.length).toEqual(3);
      expect(typeof stateCopy.deploymentData[0]).toEqual('object');
    });
  });

  describe('SET_ENDPOINTS', () => {
    it('should set all the endpoints', () => {
      mutations[types.SET_ENDPOINTS](stateCopy, {
        metricsEndpoint: 'additional_metrics.json',
        environmentsEndpoint: 'environments.json',
        deploymentsEndpoint: 'deployments.json',
        dashboardEndpoint: 'dashboard.json',
        projectPath: '/gitlab-org/gitlab-ce',
      });

      expect(stateCopy.metricsEndpoint).toEqual('additional_metrics.json');
      expect(stateCopy.environmentsEndpoint).toEqual('environments.json');
      expect(stateCopy.deploymentsEndpoint).toEqual('deployments.json');
      expect(stateCopy.dashboardEndpoint).toEqual('dashboard.json');
      expect(stateCopy.projectPath).toEqual('/gitlab-org/gitlab-ce');
    });
  });

  describe('SET_QUERY_RESULT', () => {
    const metricId = 12;
    const result = [{ values: [[0, 1], [1, 1], [1, 3]] }];

    beforeEach(() => {
      const dashboardGroups = metricsDashboardResponse.dashboard.panel_groups;
      mutations[types.RECEIVE_METRICS_DATA_SUCCESS](stateCopy, dashboardGroups);
    });

    it('clears empty state', () => {
      mutations[types.SET_QUERY_RESULT](stateCopy, {
        metricId,
        result,
      });

      expect(stateCopy.showEmptyState).toBe(false);
    });

    it('sets metricsWithData value', () => {
      mutations[types.SET_QUERY_RESULT](stateCopy, {
        metricId,
        result,
      });

      expect(stateCopy.metricsWithData).toEqual([12]);
    });

    it('does not store empty results', () => {
      mutations[types.SET_QUERY_RESULT](stateCopy, {
        metricId,
        result: [],
      });

      expect(stateCopy.metricsWithData).toEqual([]);
    });
  });

  describe('SET_ALL_DASHBOARDS', () => {
    it('stores the dashboards loaded from the git repository', () => {
      mutations[types.SET_ALL_DASHBOARDS](stateCopy, dashboardGitResponse);

      expect(stateCopy.allDashboards).toEqual(dashboardGitResponse);
    });
  });
});
