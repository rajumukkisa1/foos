# frozen_string_literal: true

class AddEnforcedSsoToSamlProvider < ActiveRecord::Migration[5.0]
  include Gitlab::Database::MigrationHelpers

  DOWNTIME = false

  disable_ddl_transaction!

  def up
    add_column_with_default :saml_providers,
                            :enforced_sso,
                            :boolean,
                            default: false,
                            allow_null: false
  end

  def down
    remove_column(:saml_providers, :enforced_sso)
  end
end
