# frozen_string_literal: true

RSpec.describe Skullrax::DashboardController, type: :request do
  include Devise::Test::IntegrationHelpers

  describe 'GET /skullrax' do
    context 'when user is an admin' do
      before do
        admin = create(:admin, email: 'admin@example.com')
        sign_in admin
      end

      it 'returns http success' do
        get '/skullrax'
        expect(response).to have_http_status(:success)
      end

      it 'renders the dashboard component' do
        get '/skullrax'
        expect(response.body).to be_present
      end
    end

    context 'when user is logged in but not an admin' do
      before do
        user = create(:user, email: 'user@example.com')
        sign_in user
      end

      it 'redirects to root path' do
        get '/skullrax'
        expect(response).to have_http_status(:redirect)
        expect(response.location).to match(%r{^http://www.example.com/\?})
      end

      it 'sets an alert message' do
        get '/skullrax'
        follow_redirect!
        expect(response.body).to include('You are not authorized to access Skullrax')
      end
    end

    context 'when user is not signed in' do
      it 'redirects (via authenticate_user!)' do
        get '/skullrax'
        expect(response).not_to have_http_status(:success)
      end
    end
  end
end
