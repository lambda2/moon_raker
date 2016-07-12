require "spec_helper"

describe MoonRaker::Extractor do
  it 'handles routes without (.:format)' do
    MoonRaker::Extractor.apis_from_routes.each do |(controller, action), apis|
      apis.each { |api| expect(api[:path]).not_to be_nil }
    end
  end
end
