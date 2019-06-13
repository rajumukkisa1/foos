FactoryBot.define do
  factory :project_alias do
    project
    name { FFaker::Name.unique.name.parameterize }
  end
end
