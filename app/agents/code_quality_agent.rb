class CodeQualityAgent < BaseAgent
  def review(parsed_diff, context = {})
    log_info("CodeQualityAgent: Starting code quality review")
    run_agentic_loop(parsed_diff, context, :code_quality).merge(
      agent:    'Code Quality',
      priority: @config.dig('agents', 'code_quality', 'priority')
    )
  end
end
