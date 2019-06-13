require 'spec_helper'

describe ProjectAlias do
  subject { build(:project_alias) }

  it { is_expected.to belong_to(:project) }

  it { is_expected.to validate_presence_of(:project) }
  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_uniqueness_of(:name) }
end
