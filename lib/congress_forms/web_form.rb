module CongressForms
  class WebForm < Form
    attr_accessor :bioguide, :actions
    attr_accessor :success_status, :success_content
    attr_accessor :updated_at

    def self.parse(file)
      yaml = YAML.load_file(file)

      actions = yaml.dig("contact_form", "steps").map do |step|
        Actions.build(step)
      end.flatten

      new(
        actions,
        bioguide: yaml["bioguide"],
        success_status:
          yaml.dig("contact_form", "success", "headers", "status"),
        success_content:
          yaml.dig("contact_form", "success", "body", "contains"),
        updated_at: File.mtime(file)
      )
    end

    def self.create_browser
      if ENV["HEADLESS"] == "0"
        Capybara::Session.new(:chrome)
      else
        Capybara::Session.new(:headless_chrome)
      end.tap do |browser|
        browser.current_window.resize_to(1920, 1080)
      end
    end

    def initialize(actions = [], bioguide: nil,
                   success_status: nil,
                   success_content: nil,
                   updated_at: nil)
      self.bioguide = bioguide
      self.actions = actions
      self.success_status = success_status
      self.success_content = success_content
      self.updated_at = updated_at
    end

    def required_params
      required_actions = actions.dup

      required_actions.select!(&:required?)
      required_actions.select!(&:placeholder_value?)

      required_actions.map do |action|
        {
          value: action.value,
          max_length: action.max_length,
          options: action.select_options
        }
      end
    end

    def fill(values, browser: self.class.create_browser, submit: true)
      actions.each do |action|
        break if action.submit? && !submit

        action.perform(browser, values)
      end
    rescue Capybara::CapybaraError => e
      raise Error, e.message
    end
  end
end
