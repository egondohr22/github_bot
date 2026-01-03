require_relative '../ollama_service'

module Agents
  class BaseAgent
    def initialize
      @ollama = OllamaService.new
    end

    def review(parsed_diff, context = {})
      raise NotImplementedError, "Subclasses must implement #review"
    end

    protected

    def format_diff_for_prompt(parsed_diff)
      diff_text = ""
      parsed_diff.each do |file, changes|
        diff_text += "File: #{file}\n"
        diff_text += "Before:\n```ruby\n#{changes[:before]}\n```\n\n"
        diff_text += "After:\n```ruby\n#{changes[:after]}\n```\n\n"
        diff_text += "---\n\n"
      end
      diff_text
    end

    def query_ollama(prompt, system_message)
      @ollama.generate(prompt, system: system_message, temperature: 0.3)
    end

    def log_info(message)
      if defined?(Rails)
        Rails.logger.info message
      else
        puts "[INFO] #{message}"
      end
    end
  end
end
