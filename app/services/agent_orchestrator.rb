class AgentOrchestrator < ApplicationService
  CONFIG_PATH = Rails.root.join('config', 'agents.yml')

  AGENT_CLASSES = {
    'security' => SecurityAgent,
    'code_quality' => CodeQualityAgent,
    'performance' => PerformanceAgent
  }.freeze

  def initialize(settings)
    @config = YAML.safe_load_file(CONFIG_PATH)
    @gemini = GeminiService.new
    @settings = settings
  end

  def orchestrate_review(parsed_diff, pr_data, github_token:, repo_cloner: nil)
    log_info("AgentOrchestrator: Starting review for PR ##{pr_data['pr_number']}")

    routing_plan = create_review_plan(parsed_diff, pr_data)
    agent_results = execute_agents_with_routing(parsed_diff, pr_data, routing_plan[:routing], github_token, repo_cloner)
    agent_results.sort_by! { |r| -ReviewSettings.priority_weight(r[:priority]) }
    final_review = synthesize_review(pr_data, agent_results, routing_plan[:summary])

    log_info("AgentOrchestrator: Review complete for PR ##{pr_data['pr_number']}")
    { comment: final_review, agent_results: agent_results }
  end

  private

  def create_review_plan(parsed_diff, pr_data)
    log_info("AgentOrchestrator: Building routing plan")
    prompt = @config.dig('orchestrator', 'prompts', 'review_plan')
      .gsub('__PR_NUMBER__', pr_data['pr_number'].to_s)
      .gsub('__COMMENT__', pr_data['comment'])
      .gsub('__FILES_SUMMARY__', parsed_diff.keys.join(', '))

    raw = @gemini.generate_content(prompt, model: @config.dig('orchestrator', 'model'), context: pr_data, agent_key: 'orchestrator_plan')
    plan = parse_routing_plan(raw, parsed_diff.keys)

    log_info("AgentOrchestrator: Routing — #{plan[:routing].map { |k, v| "#{k}:#{v.size}" }.join(', ')}")
    plan
  end

  def parse_routing_plan(raw, all_files)
    return fallback_routing(all_files) unless raw

    clean = raw.strip.gsub(/\A```(?:json)?\s*|\s*```\z/, '')
    parsed = JSON.parse(clean)

    routing = AGENT_CLASSES.keys.each_with_object({}) do |key, h|
      h[key] = Array(parsed.dig('routing', key)).select { |f| all_files.include?(f) }
    end

    { summary: parsed['summary'].to_s, routing: routing }
  rescue JSON::ParserError
    log_error("AgentOrchestrator: Could not parse routing plan — using fallback")
    fallback_routing(all_files)
  end

  def fallback_routing(all_files)
    {
      summary: 'Standard comprehensive review',
      routing: AGENT_CLASSES.keys.each_with_object({}) { |k, h| h[k] = all_files.dup }
    }
  end

  def execute_agents_with_routing(parsed_diff, pr_data, routing, github_token, repo_cloner)
    github = GithubService.new(token: github_token)

    AGENT_CLASSES.filter_map do |key, agent_class|
      unless @settings.agent_enabled?(key)
        log_info("AgentOrchestrator: Skipping #{key} agent (disabled in settings)")
        next
      end

      files = routing[key] || []
      next if files.empty?

      log_info("AgentOrchestrator: Running #{key} agent on #{files.size} file(s)")
      result = agent_class.new(github_service: github, repo_cloner: repo_cloner, max_tool_calls: @settings.max_tool_calls).review(parsed_diff.slice(*files), pr_data)
      result[:priority] = @settings.priority_for(key)
      result[:files_reviewed] = files
      result
    rescue => e
      log_error("AgentOrchestrator: #{agent_class.name} failed — #{e.message}")
      { agent: key, findings: "Review failed: #{e.message}", priority: 'error', tool_calls: 0, files_reviewed: files }
    end
  end

  def synthesize_review(pr_data, agent_results, review_plan_summary)
    log_info("AgentOrchestrator: Synthesizing final review")

    agent_findings = agent_results.map do |r|
      "### #{r[:agent]} Review (#{r[:priority]} priority)\n#{r[:findings]}"
    end.join("\n\n")

    prompt = @config.dig('orchestrator', 'prompts', 'synthesize')
      .gsub('__PR_NUMBER__', pr_data['pr_number'].to_s)
      .gsub('__REVIEW_PLAN__', review_plan_summary.to_s)
      .gsub('__AGENT_FINDINGS__', agent_findings)

    @gemini.generate_content(prompt, model: @config.dig('orchestrator', 'model'), context: pr_data, agent_key: 'orchestrator_synthesize') ||
      format_fallback_review(agent_results, pr_data)
  end

  def format_fallback_review(agent_results, pr_data)
    lines = ["## AI Code Review — PR ##{pr_data['pr_number']}\n"]
    agent_results.each { |r| lines << "### #{r[:agent]} Review\n#{r[:findings]}\n" }
    lines.join("\n") + "\n---\n*Reviewed by AI Agent System*"
  end

end
