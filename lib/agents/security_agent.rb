require_relative 'base_agent'

module Agents
  class SecurityAgent < BaseAgent
    def review(parsed_diff, context = {})
      log_info("SecurityAgent: Starting security review")
      findings = run_agentic_loop(parsed_diff, context, :security)
      {
        agent: 'Security',
        findings: findings,
        priority: @config.dig('agents', 'security', 'priority')
      }
    end
  end
end
