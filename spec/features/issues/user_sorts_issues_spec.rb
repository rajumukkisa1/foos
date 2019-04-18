require "spec_helper"

describe "User sorts issues" do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project_empty_repo, :public, group: group) }
  let_it_be(:issue1) { create(:issue, project: project) }
  let_it_be(:issue2) { create(:issue, project: project) }
  let_it_be(:issue3) { create(:issue, project: project) }

  before do
    create_list(:award_emoji, 2, :upvote, awardable: issue1)
    create_list(:award_emoji, 2, :downvote, awardable: issue2)
    create(:award_emoji, :downvote, awardable: issue1)
    create(:award_emoji, :upvote, awardable: issue2)

    sign_in(user)

    visit(project_issues_path(project))
  end

  it 'keeps the sort option' do
    find('.filter-dropdown-container .dropdown').click

    page.within('ul.dropdown-menu.dropdown-menu-right li') do
      click_link('Milestone')
    end

    visit(issues_dashboard_path(assignee_username: user.username))

    expect(find('.issues-filters a.is-active')).to have_content('Milestone')

    visit(project_issues_path(project))

    expect(find('.issues-filters a.is-active')).to have_content('Milestone')

    visit(issues_group_path(group))

    expect(find('.issues-filters a.is-active')).to have_content('Milestone')
  end

  it "sorts by popularity" do
    find('.filter-dropdown-container .dropdown').click

    page.within('ul.dropdown-menu.dropdown-menu-right li') do
      click_link("Popularity")
    end

    page.within(".issues-list") do
      page.within("li.issue:nth-child(1)") do
        expect(page).to have_content(issue1.title)
      end

      page.within("li.issue:nth-child(2)") do
        expect(page).to have_content(issue2.title)
      end

      page.within("li.issue:nth-child(3)") do
        expect(page).to have_content(issue3.title)
      end
    end
  end
end
