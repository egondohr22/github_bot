require_relative 'base_agent'

module Agents
  class PerformanceAgent < BaseAgent
    def review(parsed_diff, context = {})
      log_info("PerformanceAgent: Starting performance review")
      findings = run_agentic_loop(parsed_diff, context, :performance)
      {
        agent: 'Performance',
        findings: findings,
        priority: @config.dig('agents', 'performance', 'priority')
      }
    end
  end
end
