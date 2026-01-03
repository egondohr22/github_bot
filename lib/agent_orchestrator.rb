require_relative 'agents/security_agent'
require_relative 'agents/code_quality_agent'
require_relative 'agents/performance_agent'
require_relative 'agents/testing_agent'
require_relative 'agents/documentation_agent'
require_relative 'gemini_service'

class AgentOrchestrator
  def initialize
    @agents = [
      Agents::SecurityAgent.new,
      Agents::CodeQualityAgent.new,
      Agents::PerformanceAgent.new,
      Agents::TestingAgent.new,
      Agents::DocumentationAgent.new
    ]
    @gemini_manager = GeminiService.new
  end

  def orchestrate_review(parsed_diff, pr_data)
    log_info("AgentOrchestrator: Starting agentic review for PR ##{pr_data['pr_number']}")

    # Step 1: Gemini analyzes the PR and creates review plan
    review_plan = create_review_plan(parsed_diff, pr_data)
    log_info("AgentOrchestrator: Review plan created")

    # Step 2: Execute agents sequentially
    agent_results = execute_agents_sequentially(parsed_diff, pr_data)
    log_info("AgentOrchestrator: All agents completed")

    # Step 3: Gemini synthesizes final review
    final_review = synthesize_review(parsed_diff, pr_data, agent_results, review_plan)
    log_info("AgentOrchestrator: Final review synthesized")

    final_review
  end

  private

  def create_review_plan(parsed_diff, pr_data)
    log_info("AgentOrchestrator: Asking Gemini to create review plan")

    files_summary = parsed_diff.keys.join(", ")

    prompt = <<~PROMPT
      You are the manager of a code review team. Analyze this Pull Request and create a brief review plan.

      PR ##{pr_data['pr_number']}: #{pr_data['comment'] || 'No description'}
      Files changed: #{files_summary}

      Your specialized review agents are:
      1. Security Agent - Finds vulnerabilities
      2. Code Quality Agent - Checks best practices
      3. Performance Agent - Identifies bottlenecks
      4. Testing Agent - Reviews test coverage
      5. Documentation Agent - Checks documentation

      Create a brief review plan (2-3 sentences) outlining what aspects are most important for this PR.
      Consider the types of files changed and the nature of the changes.
    PROMPT

    @gemini_manager.generate_content(prompt) || "Standard comprehensive review"
  end

  def execute_agents_sequentially(parsed_diff, pr_data)
    results = []

    @agents.each do |agent|
      begin
        result = agent.review(parsed_diff, pr_data)
        results << result
        log_info("AgentOrchestrator: #{result[:agent]} completed")

        # Small delay between agents to avoid overwhelming the system
        sleep(0.5)
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

  def synthesize_review(parsed_diff, pr_data, agent_results, review_plan)
    log_info("AgentOrchestrator: Asking Gemini to synthesize final review")

    # Format agent findings
    agent_findings = agent_results.map do |result|
      "### #{result[:agent]} Review (#{result[:priority]} priority)\n#{result[:findings]}"
    end.join("\n\n")

    prompt = <<~PROMPT
      You are the manager synthesizing a comprehensive code review for Pull Request ##{pr_data['pr_number']}.

      Review Plan: #{review_plan}

      Your team of specialized agents has completed their reviews. Synthesize their findings into a cohesive, professional review comment.

      Agent Findings:
      #{agent_findings}

      Create a final review comment that:
      1. Starts with a brief summary of the PR
      2. Organizes findings by priority (Critical → High → Medium → Low)
      3. Is clear, actionable, and professional
      4. Highlights the most important issues
      5. Ends with overall assessment and recommendation (Approve/Request Changes/Comment)

      Use markdown formatting. Be concise but thorough.
    PROMPT

    final_review = @gemini_manager.generate_content(prompt)

    if final_review
      final_review
    else
      # Fallback: return agent findings directly
      log_error("AgentOrchestrator: Gemini synthesis failed, returning agent findings")
      format_fallback_review(agent_results, pr_data)
    end
  end

  def format_fallback_review(agent_results, pr_data)
    review = "## AI Code Review - PR ##{pr_data['pr_number']}\n\n"

    agent_results.each do |result|
      review += "### #{result[:agent]} Review\n"
      review += "#{result[:findings]}\n\n"
    end

    review += "\n---\n*Reviewed by AI Agent System*"
    review
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
