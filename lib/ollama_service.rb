require_relative 'http_service'

class OllamaService
  DEFAULT_MODEL = 'deepseek-coder:6.7b'
  API_BASE_URL = 'http://localhost:11434'

  def initialize(base_url: nil)
    @base_url = base_url || ENV['OLLAMA_URL'] || API_BASE_URL
    # Use longer timeout for local LLM inference (5 minutes read, 30 sec open)
    @http_service = HttpService.new(read_timeout: 300, open_timeout: 30)
  end

  def generate(prompt, model: DEFAULT_MODEL, system: nil, temperature: 0.3)
    url = "#{@base_url}/api/generate"

    body = {
      model: model,
      prompt: prompt,
      stream: false,
      options: {
        temperature: temperature,
        num_predict: 2000
      }
    }

    body[:system] = system if system

    response = @http_service.post(url, body: body)

    if response[:success]
      extract_response(response[:body])
    else
      log_error("Ollama API error: #{response[:status]} - #{response[:raw_body]}")
      nil
    end
  rescue HttpService::RequestError => e
    log_error("Ollama API request failed: #{e.message}")
    nil
  end

  def chat(messages, model: DEFAULT_MODEL, temperature: 0.3)
    url = "#{@base_url}/api/chat"

    body = {
      model: model,
      messages: messages,
      stream: false,
      options: {
        temperature: temperature,
        num_predict: 2000
      }
    }

    response = @http_service.post(url, body: body)

    if response[:success]
      extract_chat_response(response[:body])
    else
      log_error("Ollama API error: #{response[:status]} - #{response[:raw_body]}")
      nil
    end
  rescue HttpService::RequestError => e
    log_error("Ollama API request failed: #{e.message}")
    nil
  end

  def check_model_availability(model: DEFAULT_MODEL)
    url = "#{@base_url}/api/tags"

    response = @http_service.get(url)

    if response[:success]
      models = response[:body]['models'] || []
      models.any? { |m| m['name'] == model }
    else
      log_error("Failed to check model availability: #{response[:status]}")
      false
    end
  rescue HttpService::RequestError => e
    log_error("Ollama connection failed: #{e.message}")
    false
  end

  private

  def extract_response(body)
    body['response']
  end

  def extract_chat_response(body)
    body.dig('message', 'content')
  end

  def log_error(message)
    if defined?(Rails)
      Rails.logger.error message
    else
      puts "[ERROR] #{message}"
    end
  end
end
