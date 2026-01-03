require_relative 'base_agent'

module Agents
  class PerformanceAgent < BaseAgent
    def review(parsed_diff, context = {})
      log_info("PerformanceAgent: Starting performance review")

      system_message = <<~SYSTEM
        You are a Ruby on Rails performance optimization expert.

        Focus on:
        - N+1 query problems
        - Missing eager loading (includes, joins, preload)
        - Missing database indexes
        - Inefficient ActiveRecord queries
        - Memory leaks (large object allocation)
        - Missing caching opportunities
        - Inefficient loops and iterations
        - Unnecessary database calls

        Identify performance bottlenecks. Be specific.
        Format: List issues with optimization suggestions.
      SYSTEM

      prompt = <<~PROMPT
        Review this Rails code diff for PERFORMANCE ISSUES:

        #{format_diff_for_prompt(parsed_diff)}

        Respond with:
        1. Performance concerns (or "No significant performance issues")
        2. For each issue: location, problem, and specific optimization

        Focus on database queries and expensive operations. Be concise.
      PROMPT

      response = query_ollama(prompt, system_message)

      {
        agent: 'Performance',
        findings: response || "Unable to complete performance review",
        priority: 'high'
      }
    end
  end
end
