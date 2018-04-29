require 'test_helper'

class ProductsControllerTest < ActionDispatch::IntegrationTest
  test "should get search" do
    get products_search_url
    assert_response :success
  end

  test "should get upload" do
    get products_upload_url
    assert_response :success
  end

end
