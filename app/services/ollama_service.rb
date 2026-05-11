class OllamaService < ApplicationService
  API_BASE_URL = ENV['OLLAMA_API_BASE_URL']

  def initialize(read_timeout: 300)
    @http = HttpService.new(read_timeout: read_timeout, open_timeout: 30)
  end

  def generate(prompt, model:, system: nil, temperature: 0.3)
    body = {
      model: model,
      prompt: prompt,
      stream: false,
      options: { temperature: temperature, num_predict: 2000 }
    }
    body[:system] = system if system

    response = @http.post("#{API_BASE_URL}/api/generate", body: body)
    if response[:success]
      response[:body]['response']
    else
      log_error("Ollama API error: #{response[:status]} - #{response[:raw_body]}")
      nil
    end
  rescue HttpService::RequestError => e
    log_error("Ollama request failed: #{e.message}")
    nil
  end

  def chat(messages, model:, temperature: 0.3)
    body = {
      model: model,
      messages: messages,
      stream: false,
      options: { temperature: temperature, num_predict: 2000 }
    }

    response = @http.post("#{API_BASE_URL}/api/chat", body: body)
    if response[:success]
      response[:body].dig('message', 'content')
    else
      log_error("Ollama API error: #{response[:status]} - #{response[:raw_body]}")
      nil
    end
  rescue HttpService::RequestError => e
    log_error("Ollama request failed: #{e.message}")
    nil
  end

  def model_available?(model:)
    response = @http.get("#{API_BASE_URL}/api/tags")
    response[:success] && (response[:body]['models'] || []).any? { |m| m['name'] == model }
  rescue HttpService::RequestError => e
    log_error("Ollama connection failed: #{e.message}")
    false
  end
end
