require "spec_helper"

describe ConcernsController do

  it "displays is every controller the concern is included" do
    expect(MoonRaker["concern_resources#index"]).to be
    expect(MoonRaker["concern_resources#show"]).to be
  end

  it "should reply to valid request" do
    get :show, :id => '5', :session => "secret_hash"
    assert_response :success
  end

  it "should pass if required parameter is missing" do
    expect { get :show, :id => '5' }.not_to raise_error
  end

  it "peserved the order of methods being defined in file" do
    doc_methods = MoonRaker.get_resource_description('concern_resources')._methods.keys
    expect(doc_methods).to eq([:index, :show, :create, :update, :custom])
  end

  it "replaces a placeholder doc specified in concern with a real path" do
    path = MoonRaker["concern_resources#index"].apis.first.path
    expect(path).to eq('/api/concerns')

    path = MoonRaker["concern_resources#show"].apis.first.path
    expect(path).to eq('/concern_resources/:id')

    path = MoonRaker["concern_resources#custom"].apis.first.path
    expect(path).to eq('/concern_resources/custom')
  end

  it "replaces placeholders in param names and descriptions" do
    create_desc = MoonRaker["concern_resources#create"].params[:user]
    name_param, concern_type_param = create_desc.validator.params_ordered
    expect(name_param.desc).to include "Name of a user"
    expect(concern_type_param.name).to eq(:user_type)
  end
end

