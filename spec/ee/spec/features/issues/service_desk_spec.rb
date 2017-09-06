require 'spec_helper'

describe 'Service Desk Issue Tracker', js: true do
  let(:project) { create(:project, :private, service_desk_enabled: true) }
  let(:user) { create(:user) }

  before do
    allow(License).to receive(:feature_available?).and_call_original
    allow(License).to receive(:feature_available?).with(:service_desk) { true }

    project.add_master(user)
    sign_in(user)
  end

  describe 'navigation to service desk' do
    before do
      visit project_path(project)
      find('.sidebar-top-level-items .shortcuts-issues').click
      find('a[title="Service Desk"]').click
    end

    it 'can navigate to the service desk from link in the sidebar' do
      expect(page).to have_content('Use Service Desk to connect with your users')
    end
  end

  describe 'issues list' do
    context 'when service desk has not been activated' do
      let(:project_without_service_desk) { create(:project, :private, service_desk_enabled: false) }

      describe 'service desk info content' do
        before do
          project_without_service_desk.add_master(user)
          visit service_desk_project_issues_path(project_without_service_desk)
        end

        it 'displays the large info box' do
          expect(page).to have_css('.empty-state')
        end

        it 'has a link to the documentation' do
          expect(page).to have_link('Read more', href: help_page_path('user/project/service_desk'))
        end

        it 'does show a button configure service desk' do
          expect(page).to have_link('Turn on Service Desk')
        end
      end
    end

    context 'when service desk has been activated' do
      before do
        allow(Gitlab::IncomingEmail).to receive(:enabled?) { true }
        allow(Gitlab::IncomingEmail).to receive(:supports_wildcard?) { true }
      end

      context 'when there are no issues' do
        describe 'service desk info content' do
          before do
            visit service_desk_project_issues_path(project)
          end

          it 'displays the large info box' do
            expect(page).to have_css('.empty-state')
          end

          it 'has a link to the documentation' do
            expect(page).to have_link('Read more', href: help_page_path('user/project/service_desk'))
          end

          it 'does not show a button configure service desk' do
            expect(page).not_to have_link('Turn on Service Desk')
          end

          it 'shows the service desk email address' do
            expect(page).to have_content(project.service_desk_address)
          end
        end
      end

      context 'when there are issues' do
        let(:support_bot) { User.support_bot }
        let(:other_user) { create(:user) }
        let!(:service_desk_issue) { create(:issue, project: project, author: support_bot) }
        let!(:other_user_issue) { create(:issue, project: project, author: other_user) }

        describe 'service desk info content' do
          before do
            visit service_desk_project_issues_path(project)
          end

          it 'displays the small info box' do
            expect(page).to have_css('.non-empty-state')
          end

          it 'has a link to the documentation' do
            expect(page).to have_link('Read more', href: help_page_path('user/project/service_desk'))
          end

          it 'does not show a button configure service desk' do
            expect(page).not_to have_link('Turn on Service Desk')
          end

          it 'shows the service desk email address' do
            expect(page).to have_content(project.service_desk_address)
          end
        end

        describe 'issues list' do
          before do
            visit service_desk_project_issues_path(project)
          end

          it 'only displays issues created by support bot' do
            expect(page).to have_selector('.issues-list .issue', count: 1)
          end
        end

        describe 'search box' do
          before do
            visit service_desk_project_issues_path(project)
          end

          it 'displays the support bot author token' do
            author_token = find('.filtered-search-token .value')
            expect(author_token).to have_content('Support Bot')
          end

          it 'support bot author token cannot be deleted' do
            find('.input-token .filtered-search').native.send_key(:backspace)
            expect(page).to have_selector('.js-visual-token', count: 1)
          end
        end
      end
    end
  end
end
