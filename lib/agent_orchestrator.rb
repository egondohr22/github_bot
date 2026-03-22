require 'yaml'
require 'json'
require_relative 'agents/security_agent'
require_relative 'agents/code_quality_agent'
require_relative 'agents/performance_agent'
require_relative 'gemini_service'

class AgentOrchestrator
  CONFIG_PATH = File.join(__dir__, '..', 'config', 'agents.yml')

  AGENT_CLASSES = {
    'security'     => Agents::SecurityAgent,
    'code_quality' => Agents::CodeQualityAgent,
    'performance'  => Agents::PerformanceAgent,
  }.freeze

  def initialize
    @config = YAML.load_file(CONFIG_PATH)
    @gemini = GeminiService.new
  end

  def orchestrate_review(parsed_diff, pr_data)
    log_info("AgentOrchestrator: Starting agentic review for PR ##{pr_data['pr_number']}")

    routing_plan = create_review_plan(parsed_diff, pr_data)
    log_info("AgentOrchestrator: Review plan created — #{routing_plan[:summary].to_s.slice(0, 80)}")

    agent_results = execute_agents_with_routing(parsed_diff, pr_data, routing_plan[:routing])
    log_info("AgentOrchestrator: All agents completed")

    final_review = synthesize_review(pr_data, agent_results, routing_plan[:summary])
    log_info("AgentOrchestrator: Final review synthesized")

    final_review
  end

  private

  def create_review_plan(parsed_diff, pr_data)
    log_info("AgentOrchestrator: Asking Gemini to create routing plan")
    prompt = @config.dig('orchestrator', 'prompts', 'review_plan')
      .gsub('__PR_NUMBER__', pr_data['pr_number'].to_s)
      .gsub('__COMMENT__',   pr_data['comment'] || 'No description')
      .gsub('__FILES_SUMMARY__', parsed_diff.keys.join(', '))

    model = @config.dig('orchestrator', 'model')
    raw   = @gemini.generate_content(prompt, model: model)
    plan  = parse_routing_plan(raw, parsed_diff.keys)

    routing_summary = plan[:routing].map { |k, v| "#{k}:#{v.size}" }.join(', ')
    log_info("AgentOrchestrator: File routing — #{routing_summary}")

    plan
  end

  def parse_routing_plan(raw, all_files)
    return fallback_routing(all_files) unless raw

    clean  = raw.strip.gsub(/\A```(?:json)?\s*|\s*```\z/, '')
    parsed = JSON.parse(clean)

    routing = AGENT_CLASSES.keys.each_with_object({}) do |key, h|
      h[key] = Array(parsed.dig('routing', key)).select { |f| all_files.include?(f) }
    end

    { summary: parsed['summary'].to_s, routing: routing }
  rescue JSON::ParserError
    log_error("AgentOrchestrator: Could not parse routing plan JSON, falling back to all-files routing")
    fallback_routing(all_files)
  end

  def fallback_routing(all_files)
    {
      summary: "Standard comprehensive review",
      routing: AGENT_CLASSES.keys.each_with_object({}) { |k, h| h[k] = all_files.dup }
    }
  end

  def execute_agents_with_routing(parsed_diff, pr_data, routing)
    results = []

    AGENT_CLASSES.each do |key, agent_class|
      files = routing[key] || []

      if files.empty?
        log_info("AgentOrchestrator: Skipping #{key} agent — no files assigned")
        next
      end

      scoped_diff = parsed_diff.slice(*files)
      log_info("AgentOrchestrator: Running #{key} agent on #{files.size} file(s): #{files.join(', ')}")

      begin
        result = agent_class.new.review(scoped_diff, pr_data)
        results << result
        log_info("AgentOrchestrator: #{result[:agent]} completed")
      rescue => e
        log_error("AgentOrchestrator: #{agent_class.name} failed — #{e.message}")
        results << {
          agent:    key.split('_').map(&:capitalize).join,
          findings: "Review failed: #{e.message}",
          priority: 'error'
        }
      end
    end

    results
  end

  def synthesize_review(pr_data, agent_results, review_plan_summary)
    log_info("AgentOrchestrator: Asking Gemini to synthesize final review")

    agent_findings = agent_results.map do |result|
      "### #{result[:agent]} Review (#{result[:priority]} priority)\n#{result[:findings]}"
    end.join("\n\n")

    prompt = @config.dig('orchestrator', 'prompts', 'synthesize')
      .gsub('__PR_NUMBER__',      pr_data['pr_number'].to_s)
      .gsub('__REVIEW_PLAN__',    review_plan_summary.to_s)
      .gsub('__AGENT_FINDINGS__', agent_findings)

    model        = @config.dig('orchestrator', 'model')
    final_review = @gemini.generate_content(prompt, model: model)

    if final_review
      final_review
    else
      log_error("AgentOrchestrator: Gemini synthesis failed, returning agent findings directly")
      format_fallback_review(agent_results, pr_data)
    end
  end

  def format_fallback_review(agent_results, pr_data)
    review = "## AI Code Review - PR ##{pr_data['pr_number']}\n\n"
    agent_results.each do |result|
      review += "### #{result[:agent]} Review\n#{result[:findings]}\n\n"
    end
    review + "\n---\n*Reviewed by AI Agent System*"
  end

  def log_info(message)
    if defined?(Rails)
      Rails.logger.info message
    else
      puts "[INFO] #{message}"
    end
  end

  def log_error(message)
    if defined?(Rails)
      Rails.logger.error message
    else
      puts "[ERROR] #{message}"
    end
  end
end
