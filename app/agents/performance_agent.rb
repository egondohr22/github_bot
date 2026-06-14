class PerformanceAgent < BaseAgent
  def review(parsed_diff, context = {})
    log_info("PerformanceAgent: Starting performance review")
    run_agentic_loop(parsed_diff, context, :performance).merge(agent: 'Performance')
  end
end
