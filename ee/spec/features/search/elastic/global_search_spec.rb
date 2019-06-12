require 'spec_helper'

describe 'Global elastic search' do
  let(:user) { create(:user) }
  let(:project) { create(:project, :repository, :wiki_repo, namespace: user.namespace) }

  before do
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
    Gitlab::Elastic::Helper.create_empty_index

    project.add_maintainer(user)
    sign_in(user)
  end

  after do
    Gitlab::Elastic::Helper.delete_index
    stub_ee_application_setting(elasticsearch_search: false, elasticsearch_indexing: false)
  end

  describe 'I search through the issues and I see pagination' do
    before do
      create_list(:issue, 21, project: project, title: 'initial')

      Gitlab::Elastic::Helper.refresh_index
    end

    it "has a pagination" do
      visit dashboard_projects_path

      fill_in "search", with: "initial"
      click_button "Go"

      select_filter("Issues")
      expect(page).to have_selector('.gl-pagination .js-pagination-page', count: 2)
    end
  end

  describe 'I search through the blobs' do
    let(:project_2) { create(:project, :repository, :wiki_repo) }

    before do
      project.repository.index_blobs

      Gitlab::Elastic::Helper.refresh_index
    end

    it "finds files" do
      visit dashboard_projects_path

      fill_in "search", with: "application.js"
      click_button "Go"

      select_filter("Code")

      expect(page).to have_selector('.file-content .code')

      expect(page).to have_selector("span.line[lang='javascript']")
    end

    it 'Ignores nonexistent projects from stale index' do
      stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)

      project_2.repository.create_file(
        user,
        'thing.txt',
        ' function application.js ',
        message: 'supercalifragilisticexpialidocious',
        branch_name: 'master')

      project_2.repository.index_blobs
      Gitlab::Elastic::Helper.refresh_index
      project_2.destroy

      visit dashboard_projects_path

      fill_in "search", with: "application.js"
      click_button "Go"

      expect(page).not_to have_content 'supercalifragilisticexpialidocious'
    end
  end

  describe 'I search through the wiki blobs' do
    before do
      project.wiki.create_page('test.md', '# term')
      project.wiki.index_wiki_blobs

      Gitlab::Elastic::Helper.refresh_index
    end

    it "finds files" do
      visit dashboard_projects_path

      fill_in "search", with: "term"
      click_button "Go"

      select_filter("Wiki")

      expect(page).to have_selector('.file-content .code')

      expect(page).to have_selector("span.line[lang='markdown']")
    end
  end

  describe 'I search through the commits' do
    before do
      project.repository.index_commits
      Gitlab::Elastic::Helper.refresh_index
    end

    it "finds commits" do
      visit dashboard_projects_path

      fill_in "search", with: "add"
      click_button "Go"

      select_filter("Commits")

      expect(page).to have_selector('.commit-row-description')
      expect(page).to have_selector('.project-namespace')
    end

    it 'shows proper page 2 results' do
      visit dashboard_projects_path

      fill_in "search", with: "add"
      click_button "Go"

      expected_message = "Add directory structure for tree_helper spec"

      select_filter("Commits")
      expect(page).not_to have_content(expected_message)

      click_link 'Next'

      expect(page).to have_content(expected_message)
    end
  end
end
