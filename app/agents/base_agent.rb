class BaseAgent < ApplicationService
  CONFIG_PATH = Rails.root.join('config', 'agents.yml')

  def initialize(github_service: nil, repo_cloner: nil)
    @config = YAML.safe_load_file(CONFIG_PATH)
    timeout = @config.dig('agents', 'ollama_timeout')
    @ollama = OllamaService.new(read_timeout: timeout)
    @github = github_service
    @cloner = repo_cloner
  end

  def review(parsed_diff, context = {})
    raise NotImplementedError, "Subclasses must implement #review"
  end

  protected

  def run_agentic_loop(parsed_diff, context, agent_key)
    agent_cfg = @config.dig('agents', agent_key.to_s)
    tools_instruction = @config.dig('agents', 'tools_instruction').strip
    system_message = "#{agent_cfg['system_prompt'].strip}\n\n#{tools_instruction}"
    model = @config.dig('agents', 'model')
    temperature = @config.dig('agents', 'temperature')
    max_tool_calls = @config.dig('agents', 'max_tool_calls')

    log_info("#{self.class.name}: Starting review with model=#{model}")

    user_prompt = initial_prompt(parsed_diff, max_tool_calls)
    messages = [
      { role: 'system', content: system_message },
      { role: 'user', content: user_prompt }
    ]

    tool_calls_made = 0

    conv = open_conversation_log(context, agent_key, model)
    conv_write(conv, "# PR \##{context['pr_number']} — #{self.class.name}\n\n")
    conv_write(conv, "**Model:** #{model} | **Agent:** #{agent_key}\n\n---\n\n")
    conv_write(conv, "## System\n\n#{system_message}\n\n---\n\n")
    conv_write(conv, "## User\n\n#{user_prompt}\n\n---\n\n")

    findings = loop do
      response_text = @ollama.chat(messages, model: model, temperature: temperature)

      unless response_text
        conv_write(conv, "## No response from model\n\n")
        break "Agent failed to respond."
      end

      messages << { role: 'assistant', content: response_text }
      conv_write(conv, "## Assistant\n\n#{response_text}\n\n---\n\n")
      parsed = parse_json_response(response_text)

      if parsed['done']
        break parsed['message'] || "No findings."
      end

      if parsed['tool_call'] && tool_calls_made < max_tool_calls
        tool_name = parsed['tool_call']['name']
        tool_args = parsed['tool_call']['args'] || {}
        tool_result = execute_tool(parsed['tool_call'], context)
        tool_calls_made += 1

        log_info("#{self.class.name}: tool=#{tool_name} (#{tool_calls_made}/#{max_tool_calls})")
        conv_write(conv, "## Tool Call \##{tool_calls_made}: `#{tool_name}`\n\n")
        conv_write(conv, "**Args:** `#{tool_args.to_json}`\n\n**Result:**\n\n```\n#{tool_result}\n```\n\n---\n\n")
        remaining = max_tool_calls - tool_calls_made
        messages << { role: 'user', content: "Tool result:\n#{tool_result}\n\n(#{remaining} tool calls remaining)" }
      else
        break parsed['message'] || response_text
      end
    end

    log_info("#{self.class.name}: Done — #{tool_calls_made} tool calls")
    conv_write(conv, "## Summary\n\n**Tool calls:** #{tool_calls_made}\n\n### Findings\n\n#{findings}\n")
    conv.close

    { findings: findings, tool_calls: tool_calls_made }
  end

  private

  def initial_prompt(parsed_diff, max_tool_calls)
    <<~PROMPT
      Review the following code diff:

      #{format_diff_for_prompt(parsed_diff)}

      You have #{max_tool_calls} tool calls available. Respond with JSON only.
    PROMPT
  end

  def execute_tool(tool_call, context)
    name = tool_call['name']
    args = tool_call['args']
    owner = context['owner']
    repo = context['repo']
    ref = context['head_branch']

    case name
    when 'get_file'
      path = args['path']
      return "Missing 'path' argument." unless path
      if @cloner&.cloned?
        @cloner.get_file(path) || "File not found: #{path}"
      else
        @github&.get_file_content(owner: owner, repo: repo, path: path, ref: ref) || "File not found: #{path}"
      end
    when 'search_codebase'
      query = args['query']
      return "Missing 'query' argument." unless query
      if @cloner&.cloned?
        results = @cloner.search(query)
        results.empty? ? "No results for: #{query}" : results.map { |r| "#{r[:path]}:#{r[:line]}: #{r[:content]}" }.join("\n")
      else
        results = @github&.search_code(owner: owner, repo: repo, query: query) || []
        results.empty? ? "No results found for: #{query}" : results.map { |r| r[:path] }.join("\n")
      end
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
