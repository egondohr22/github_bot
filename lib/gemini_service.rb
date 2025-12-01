require_relative 'http_service'

class GeminiService
  API_BASE_URL = 'https://generativelanguage.googleapis.com/v1beta'
  DEFAULT_MODEL = 'gemini-2.5-flash'

  def initialize(api_key: nil)
    @api_key = api_key || ENV['GEMINI_API_KEY']
    @http_service = HttpService.new
    validate_api_key!
  end

  # Perform code review on diff
  def code_review(parsed_diff, pr_number: nil)
    prompt = build_code_review_prompt(parsed_diff, pr_number)
    generate_content(prompt)
  end

  # Generic content generation
  def generate_content(prompt, model: DEFAULT_MODEL)
    url = build_api_url(model)
    body = build_request_body(prompt)

    response = @http_service.post(url, body: body)

    if response[:success]
      extract_text_from_response(response[:body])
    else
      log_error("Gemini API error: #{response[:status]} - #{response[:raw_body]}")
      nil
    end
  rescue HttpService::RequestError => e
    log_error("Gemini API request failed: #{e.message}")
    nil
  end

  # Chat-style interaction
  def chat(messages, model: DEFAULT_MODEL)
    url = build_api_url(model)
    body = {
      contents: messages.map { |msg| format_message(msg) }
    }

    response = @http_service.post(url, body: body)

    if response[:success]
      extract_text_from_response(response[:body])
    else
      log_error("Gemini API error: #{response[:status]} - #{response[:raw_body]}")
      nil
    end
  rescue HttpService::RequestError => e
    log_error("Gemini API request failed: #{e.message}")
    nil
  end

  private

  def validate_api_key!
    unless @api_key
      raise ArgumentError, "GEMINI_API_KEY environment variable is not set"
    end
  end

  def build_api_url(model)
    "#{API_BASE_URL}/models/#{model}:generateContent?key=#{@api_key}"
  end

  def build_request_body(prompt)
    {
      contents: [{
        parts: [{
          text: prompt
        }]
      }]
    }
  end

  def build_code_review_prompt(parsed_diff, pr_number)
    prompt = ""
    prompt += "Please review the following code changes from Pull Request ##{pr_number}:\n\n" if pr_number
    prompt += "Please review the following code changes:\n\n" unless pr_number

    parsed_diff.each do |file, changes|
      prompt += "File: #{file}\n"
      prompt += "Before:\n```\n#{changes[:before]}\n```\n\n"
      prompt += "After:\n```\n#{changes[:after]}\n```\n\n"
      prompt += "---\n\n"
    end

    prompt += "Provide a concise code review focusing on:\n"
    prompt += "- Potential bugs or errors\n"
    prompt += "- Security issues\n"
    prompt += "- Performance concerns\n"
    prompt += "- Best practices and code quality\n"
    prompt += "- Suggestions for improvement\n"

    prompt
  end

  def format_message(msg)
    if msg.is_a?(Hash)
      {
        role: msg[:role] || 'user',
        parts: [{ text: msg[:text] }]
      }
    else
      {
        role: 'user',
        parts: [{ text: msg.to_s }]
      }
    end
  end

  def extract_text_from_response(body)
    body.dig('candidates', 0, 'content', 'parts', 0, 'text')
  end

  def log_error(message)
    if defined?(Rails)
      Rails.logger.error message
    else
      puts "[ERROR] #{message}"
    end
  end
end
