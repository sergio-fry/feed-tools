require 'minitest/autorun'
require './lib/markup_helpers'
  
describe MarkupHelpers do
  include MarkupHelpers

  describe "#cleanup_html" do
    it "should remove by css" do
      html = "Hi <span class='direction'>there</span>"
      assert_equal to_html(cleanup_html(html, ["remove css .direction"])), "Hi "
    end

    it "should remove by regexp" do
      html = "Hi there"
      assert_equal to_html(cleanup_html(html, ["remove regexp /rE/i"])), "Hi the"
    end

    it "should select by css" do
      html = "text before <div class='content'>Content</div> text after"

      html = to_html cleanup_html(html, ["select css .content"])

      assert_equal html.include?("Content"), true
      assert_equal html.include?("text before"), false
      assert_equal html.include?("text after"), false
    end
  end

  describe "#processor_markdown" do
    it "should eval markdown syntax" do
      html = "Hi *there*"
      assert_equal to_html(processor_markdown(html)).include?("<em>there</em>"), true
    end
  end

  describe "#processor_fix_headers" do
    it "should downgrade headers if h1 present" do
      html = "Text <h1>Header</h1> more text"
      assert_equal to_html(processor_fix_headers(html)).include?("<h2>Header</h2>"), true
    end

    it "should upgrade headers if no h2 present" do
      html = "Text <h3>Header</h3> more text"
      assert_equal to_html(processor_fix_headers(html)).include?("<h2>Header</h2>"), true
    end
  end


  describe "#processor_sanitize" do
    it "should remove js" do
      html = "Text <script>alert()</script>"
      assert_equal to_html(processor_sanitize(html)).include?("script"), false
    end
  end

  describe "#processor_fix_paragraphs" do
    it "should replace brs to p" do
      html = "Hi <br><br> there"
      assert_equal to_html(processor_fix_paragraphs(html)).include?("<p>"), true
    end
  end

  describe "#processor_remove_empty_paragraphs" do
    it "should remove empty paragraphs" do
      html = "<p></p>Text"
      assert_equal to_html(processor_remove_empty_paragraphs(html)).include?("<p>"), false
    end

    it "should not remove nonempty paragraphs" do
      html = "<p>Text</p>"
      assert_equal to_html(processor_remove_empty_paragraphs(html)).include?("<p>"), true
    end
  end
end
