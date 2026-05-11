class SecurityAgent < BaseAgent
  def review(parsed_diff, context = {})
    log_info("SecurityAgent: Starting security review")
    run_agentic_loop(parsed_diff, context, :security).merge(
      agent: 'Security',
      priority: @config.dig('agents', 'security', 'priority')
    )
  end
end
