require 'json'
require 'yaml'
require_relative '../ollama_service'
require_relative '../github_service'

module Agents
  class BaseAgent
    CONFIG_PATH = File.join(__dir__, '..', '..', 'config', 'agents.yml')

    def initialize
      @config = YAML.load_file(CONFIG_PATH)
      timeout = @config.dig('agents', 'ollama_timeout') || 1800
      @ollama = OllamaService.new(read_timeout: timeout)
    end

    def review(parsed_diff, context = {})
      raise NotImplementedError, "Subclasses must implement #review"
    end

    protected

    def run_agentic_loop(parsed_diff, context, agent_key)
      @github = build_github_service(context)

      agent_cfg       = @config.dig('agents', agent_key.to_s)
      tools_instruction = @config.dig('agents', 'tools_instruction').strip
      system_message  = "#{agent_cfg['system_prompt'].strip}\n\n#{tools_instruction}"

      model         = @config.dig('agents', 'model')
      temperature   = @config.dig('agents', 'temperature')
      max_tool_calls = @config.dig('agents', 'max_tool_calls')

      messages = [
        { role: 'system',  content: system_message },
        { role: 'user',    content: initial_prompt(parsed_diff) }
      ]

      tool_calls_made = 0

      loop do
        response_text = @ollama.chat(messages, model: model, temperature: temperature)

        return "Agent failed to respond." unless response_text

        messages << { role: 'assistant', content: response_text }
        parsed = parse_json_response(response_text)

        return parsed['message'] || "No findings." if parsed['done']

        if parsed['tool_call'] && tool_calls_made < max_tool_calls
          tool_result = execute_tool(parsed['tool_call'], context)
          log_info("#{self.class.name}: tool=#{parsed['tool_call']['name']} calls=#{tool_calls_made + 1}")
          messages << { role: 'user', content: "Tool result:\n#{tool_result}" }
          tool_calls_made += 1
        else
          return parsed['message'] || response_text
        end
      end
    end

    private

    def initial_prompt(parsed_diff)
      <<~PROMPT
        Review the following code diff:

        #{format_diff_for_prompt(parsed_diff)}

        Respond with JSON only.
      PROMPT
    end

    def execute_tool(tool_call, context)
      name  = tool_call['name']
      args  = tool_call['args'] || {}
      owner = context['owner']
      repo  = context['repo']
      ref   = context['head_branch'] || 'HEAD'

      case name
      when 'get_file'
        path = args['path']
        return "Missing 'path' argument." unless path
        @github&.get_file_content(owner: owner, repo: repo, path: path, ref: ref) || "File not found: #{path}"
      when 'search_codebase'
        query = args['query']
        return "Missing 'query' argument." unless query
        results = @github&.search_code(owner: owner, repo: repo, query: query) || []
        results.empty? ? "No results found for: #{query}" : results.map { |r| r[:path] }.join("\n")
      else
        "Unknown tool: #{name}. Available tools: get_file, search_codebase."
      end
    rescue => e
      "Tool execution error: #{e.message}"
    end

    def parse_json_response(text)
      clean = text.strip.gsub(/\A```(?:json)?\s*|\s*```\z/, '')
      JSON.parse(clean)
    rescue JSON::ParserError
      { 'message' => text, 'done' => true }
    end

    def build_github_service(context)
      return nil unless context['owner'] && context['repo']
      GitHubService.new
    rescue ArgumentError
      nil
    end

    def format_diff_for_prompt(parsed_diff)
      parsed_diff.map do |file, changes|
        <<~ENTRY
          File: #{file}
          Before:
          ```ruby
          #{changes[:before]}
          ```
          After:
          ```ruby
          #{changes[:after]}
          ```
          ---
        ENTRY
      end.join("\n")
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
