class BaseAgent < ApplicationService
  CONFIG_PATH = Rails.root.join('config', 'agents.yml')

  def initialize(github_service: nil)
    @config  = YAML.safe_load_file(CONFIG_PATH)
    timeout  = @config.dig('agents', 'ollama_timeout')
    @ollama  = OllamaService.new(read_timeout: timeout)
    @github  = github_service
  end

  def review(parsed_diff, context = {})
    raise NotImplementedError, "Subclasses must implement #review"
  end

  protected

  def run_agentic_loop(parsed_diff, context, agent_key)
    agent_cfg         = @config.dig('agents', agent_key.to_s)
    tools_instruction = @config.dig('agents', 'tools_instruction').strip
    system_message    = "#{agent_cfg['system_prompt'].strip}\n\n#{tools_instruction}"
    model             = @config.dig('agents', 'model')
    temperature       = @config.dig('agents', 'temperature')
    max_tool_calls    = @config.dig('agents', 'max_tool_calls')

    log_info("#{self.class.name}: Starting review with model=#{model}")

    messages = [
      { role: 'system', content: system_message },
      { role: 'user',   content: initial_prompt(parsed_diff) }
    ]

    tool_calls_made = 0
    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    findings = loop do
      response_text = @ollama.chat(messages, model: model, temperature: temperature)

      unless response_text
        break "Agent failed to respond."
      end

      messages << { role: 'assistant', content: response_text }
      parsed = parse_json_response(response_text)

      if parsed['done']
        break parsed['message'] || "No findings."
      end

      if parsed['tool_call'] && tool_calls_made < max_tool_calls
        tool_name   = parsed['tool_call']['name']
        tool_result = execute_tool(parsed['tool_call'], context)
        tool_calls_made += 1

        log_info("#{self.class.name}: tool=#{tool_name} (#{tool_calls_made}/#{max_tool_calls})")
        messages << { role: 'user', content: "Tool result:\n#{tool_result}" }
      else
        break parsed['message'] || response_text
      end
    end

    duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round
    log_info("#{self.class.name}: Done in #{duration_ms}ms, #{tool_calls_made} tool calls")

    { findings: findings, tool_calls: tool_calls_made, duration_ms: duration_ms }
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
    ref   = context['head_branch']

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
      "Unknown tool: #{name}. Available: get_file, search_codebase."
    end
  rescue => e
    "Tool execution error: #{e.message}"
  end

  def parse_json_response(text)
    JSON.parse(text.strip.gsub(/\A```(?:json)?\s*|\s*```\z/, ''))
  rescue JSON::ParserError
    { 'message' => text, 'done' => true }
  end

  def format_diff_for_prompt(parsed_diff)
    parsed_diff.map do |file, changes|
      <<~ENTRY
        File: #{file}
        Before:
        ```
        #{changes[:before]}
        ```
        After:
        ```
        #{changes[:after]}
        ```
        ---
      ENTRY
    end.join("\n")
  end
end
