class GeminiService < ApplicationService
  API_KEY      = ENV['GEMINI_API_KEY']
  API_BASE_URL  = ENV['GEMINI_API_BASE_URL']
  DEFAULT_MODEL = ENV['GEMINI_MODEL']

  def initialize
    @http = HttpService.new
  end

  def generate_content(prompt, model: DEFAULT_MODEL)
    url      = "#{API_BASE_URL}/models/#{model}:generateContent?key=#{API_KEY}"
    body     = { contents: [{ parts: [{ text: prompt }] }] }
    response = @http.post(url, body: body)

    if response[:success]
      response[:body].dig('candidates', 0, 'content', 'parts', 0, 'text')
    else
      log_error("Gemini API error: #{response[:status]} - #{response[:raw_body]}")
      nil
    end
  rescue HttpService::RequestError => e
    log_error("Gemini request failed: #{e.message}")
    nil
  end
end
