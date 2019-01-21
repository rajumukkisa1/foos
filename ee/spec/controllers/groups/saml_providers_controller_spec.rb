require 'spec_helper'

describe Groups::SamlProvidersController do
  let(:saml_provider) { create(:saml_provider, group: group) }
  let(:group) { create(:group, :private, parent_id: nil) }
  let(:user) { create(:user) }

  before do
    sign_in(user)
  end

  def stub_saml_config(enabled:)
    providers = enabled ? %i(group_saml) : []
    allow(Devise).to receive(:omniauth_providers).and_return(providers)
  end

  shared_examples '404 status' do
    it 'returns 404 status' do
      group.add_owner(user)

      subject

      expect(response).to have_gitlab_http_status(404)
    end
  end

  shared_examples 'configuration is prevented' do
    describe 'GET #show' do
      subject { get :show, params: { group_id: group } }

      it_behaves_like '404 status'
    end

    describe 'POST #create' do
      subject { post :create, params: { group_id: group, saml_provider: { enabled: 'false' } } }

      it_behaves_like '404 status'
    end

    describe 'PUT #update' do
      subject { put :update, params: { group_id: group, saml_provider: { enabled: 'false' } } }

      it_behaves_like '404 status'
    end
  end

  context 'when per group saml is unlicensed' do
    before do
      stub_licensed_features(group_saml: false)
      stub_saml_config(enabled: true)
    end

    it_behaves_like 'configuration is prevented'
  end

  context 'when per group saml is unconfigured' do
    before do
      stub_licensed_features(group_saml: true)
      stub_saml_config(enabled: false)
    end

    it_behaves_like 'configuration is prevented'
  end

  context 'when per group saml feature is enabled' do
    before do
      stub_saml_config(enabled: true)
      stub_licensed_features(group_saml: true)
    end

    describe 'GET #show' do
      subject { get :show, params: { group_id: group } }

      it 'shows configuration page' do
        group.add_owner(user)

        subject

        expect(response).to render_template 'groups/saml_providers/show'
      end

      context 'not on a top level group', :nested_groups do
        let(:group) { create(:group, :nested) }

        it_behaves_like '404 status'
      end

      context 'with unauthorized user' do
        it 'responds with 404' do
          group.add_developer(user)

          subject

          expect(response).to have_http_status(404)
        end
      end
    end

    describe 'PUT #update' do
      subject { put :update, params: { group_id: group, saml_provider: { enforced_sso: 'true' } } }

      before do
        group.add_owner(user)
      end

      context 'enforced sso enabled' do
        it 'updates the flag' do
          stub_feature_flags(enforced_sso: true)

          expect { subject }.to change { saml_provider.reload.enforced_sso }.to(true)
        end
      end

      context 'enforced sso disabled' do
        it 'does not update the flag' do
          stub_feature_flags(enforced_sso: false)

          expect { subject }.not_to change { saml_provider.reload.enforced_sso }.from(false)
        end
      end
    end
  end
end
