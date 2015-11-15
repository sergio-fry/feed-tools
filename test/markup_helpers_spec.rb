require 'minitest/autorun'
require './lib/markup_helpers'
  
describe MarkupHelpers do
  include MarkupHelpers

  describe "#cleanup_html" do
    it "should remove by css" do
      html = "Hi <span class='direction'>there</span>"
      result = cleanup_html(html, ["remove css .direction"])

      result.must_equal "Hi "
    end

    it "should remove by regexp" do
      html = "Hi there"
      result = cleanup_html(html, ["remove regexp /rE/i"])

      result.must_equal "Hi the"
    end
  end
end
