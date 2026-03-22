require 'yaml'
require_relative 'agents/security_agent'
require_relative 'agents/code_quality_agent'
require_relative 'agents/performance_agent'
require_relative 'gemini_service'

class AgentOrchestrator
  CONFIG_PATH = File.join(__dir__, '..', 'config', 'agents.yml')

  def initialize
    @config = YAML.load_file(CONFIG_PATH)
    @agents = [
      Agents::SecurityAgent.new,
      # Agents::CodeQualityAgent.new,
      # Agents::PerformanceAgent.new
    ]
    @gemini = GeminiService.new
  end

  def orchestrate_review(parsed_diff, pr_data)
    log_info("AgentOrchestrator: Starting agentic review for PR ##{pr_data['pr_number']}")

    review_plan = create_review_plan(parsed_diff, pr_data)
    log_info("AgentOrchestrator: Review plan created")

    agent_results = execute_agents_sequentially(parsed_diff, pr_data)
    log_info("AgentOrchestrator: All agents completed")

    final_review = synthesize_review(pr_data, agent_results, review_plan)
    log_info("AgentOrchestrator: Final review synthesized")

    final_review
  end

  private

  def create_review_plan(parsed_diff, pr_data)
    log_info("AgentOrchestrator: Asking Gemini to create review plan")
    prompt = @config.dig('orchestrator', 'prompts', 'review_plan')
      .gsub('__PR_NUMBER__', pr_data['pr_number'].to_s)
      .gsub('__COMMENT__',   pr_data['comment'] || 'No description')
      .gsub('__FILES_SUMMARY__', parsed_diff.keys.join(', '))

    model = @config.dig('orchestrator', 'model')
    @gemini.generate_content(prompt, model: model) || "Standard comprehensive review"
  end

  def execute_agents_sequentially(parsed_diff, pr_data)
    results = []
    @agents.each do |agent|
      begin
        result = agent.review(parsed_diff, pr_data)
        results << result
        log_info("AgentOrchestrator: #{result[:agent]} completed")
      rescue => e
        log_error("AgentOrchestrator: #{agent.class.name} failed - #{e.message}")
        results << {
          agent: agent.class.name.split('::').last.gsub('Agent', ''),
          findings: "Review failed: #{e.message}",
          priority: 'error'
        }
      end
    end
    results
  end

  def synthesize_review(pr_data, agent_results, review_plan)
    log_info("AgentOrchestrator: Asking Gemini to synthesize final review")

    agent_findings = agent_results.map do |result|
      "### #{result[:agent]} Review (#{result[:priority]} priority)\n#{result[:findings]}"
    end.join("\n\n")

    prompt = @config.dig('orchestrator', 'prompts', 'synthesize')
      .gsub('__PR_NUMBER__',     pr_data['pr_number'].to_s)
      .gsub('__REVIEW_PLAN__',   review_plan.to_s)
      .gsub('__AGENT_FINDINGS__', agent_findings)

    model = @config.dig('orchestrator', 'model')
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
