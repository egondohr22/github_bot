require_relative 'base_agent'

module Agents
  class CodeQualityAgent < BaseAgent
    def review(parsed_diff, context = {})
      log_info("CodeQualityAgent: Starting code quality review")
      findings = run_agentic_loop(parsed_diff, context, :code_quality)
      {
        agent: 'Code Quality',
        findings: findings,
        priority: @config.dig('agents', 'code_quality', 'priority')
      }
    end
  end
end
