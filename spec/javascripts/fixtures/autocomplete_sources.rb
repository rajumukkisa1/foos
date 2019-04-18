# frozen_string_literal: true

require 'spec_helper'

describe Projects::AutocompleteSourcesController, '(JavaScript fixtures)', type: :controller do
  include JavaScriptFixturesHelpers

  let_it_be(:admin) { create(:admin) }
  let_it_be(:group) { create(:group, name: 'frontend-fixtures') }
  let_it_be(:project) { create(:project, namespace: group, path: 'autocomplete-sources-project') }
  let_it_be(:issue) { create(:issue, project: project) }

  before(:all) do
    clean_frontend_fixtures('autocomplete_sources/')
  end

  before do
    sign_in(admin)
  end

  it 'autocomplete_sources/labels.json' do |example|
    issue.labels << create(:label, project: project, title: 'bug')
    issue.labels << create(:label, project: project, title: 'critical')

    create(:label, project: project, title: 'feature')
    create(:label, project: project, title: 'documentation')

    get :labels,
        format: :json,
        params: {
            namespace_id: group.path,
            project_id: project.path,
            type: issue.class.name,
            type_id: issue.id
        }

    expect(response).to be_success
    store_frontend_fixture(response, example.description)
  end
end
