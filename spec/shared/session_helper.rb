##
# For the default driver for capabara: Capybara.current_session.driver.class == Capybara::RackTest::Driver.
# But if driver is another one like Capybara::Selenium::Driver, would need to change session management calls.
module SessionHelper
  extend ActiveSupport::Concern

  included do
    [:post, :put, :patch, :delete, :follow_redirect!].each do|method|
      define_method method do|*args, &block|
        page.driver.browser.send(method, *args, &block)
      end
    end

    def request
      Capybara.current_session.driver.request
    end

    def response
      Capybara.current_session.driver.response
    end

    def cookies
      request.cookies
    end

    ##
    # More accurate structure to include signed cookies.
    def cookies_jar
      ActionDispatch::Request.new(page.driver.request.env).cookie_jar
    end

    def reset_sessions!
      Capybara.reset_sessions!
    end

    ##
    # @source could be HTML or plain text JSON source.
    def json_from_page(source)
      json_source = if source.starts_with?('<')
          page_node = Nokogiri::HTML(source)
          page_node.search("//pre").text
      else
        source
      end
      JSON.parse(json_source)
    end

    def fetch_json(page_url)
      visit page_url
      json_from_page(page.body)
    end
  end

end