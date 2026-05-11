class GeminiService < ApplicationService
  API_KEY = ENV['GEMINI_API_KEY']
  API_BASE_URL = ENV['GEMINI_API_BASE_URL']
  DEFAULT_MODEL = ENV['GEMINI_MODEL']

  def initialize
    @http = HttpService.new
  end

  def generate_content(prompt, model: DEFAULT_MODEL, context: {}, agent_key: nil)
    conv = open_conversation_log(context, agent_key, model) if agent_key
    conv_write(conv, "# PR \##{context['pr_number']} — #{agent_key}\n\n")
    conv_write(conv, "**Model:** #{model}\n\n---\n\n")
    conv_write(conv, "## Prompt\n\n#{prompt}\n\n---\n\n")

    url = "#{API_BASE_URL}/models/#{model}:generateContent?key=#{API_KEY}"
    body = { contents: [{ parts: [{ text: prompt }] }] }
    response = @http.post(url, body: body)

    if response[:success]
      text = response[:body].dig('candidates', 0, 'content', 'parts', 0, 'text')
      conv_write(conv, "## Response\n\n#{text}\n")
      text
    else
      log_error("Gemini API error: #{response[:status]} - #{response[:raw_body]}")
      conv_write(conv, "## Error\n\n#{response[:status]} — #{response[:raw_body]}\n")
      nil
    end
  rescue HttpService::RequestError => e
    log_error("Gemini request failed: #{e.message}")
    nil
  ensure
    conv&.close
  end
end
