require_relative 'base_agent'

module Agents
  class TestingAgent < BaseAgent
    def review(parsed_diff, context = {})
      log_info("TestingAgent: Starting testing review")

      system_message = <<~SYSTEM
        You are a Ruby on Rails testing expert specializing in RSpec and testing best practices.

        Focus on:
        - Missing test coverage for new code
        - Untested edge cases
        - Missing error handling tests
        - Test quality and maintainability
        - Missing integration/unit tests
        - Brittle or fragile tests
        - Test data setup issues

        Identify gaps in testing. Be specific.
        Format: List testing concerns with recommendations.
      SYSTEM

      prompt = <<~PROMPT
        Review this Rails code diff for TESTING CONCERNS:

        #{format_diff_for_prompt(parsed_diff)}

        Respond with:
        1. Testing gaps or concerns (or "Testing appears adequate")
        2. For each concern: what needs testing and why
        3. Suggest specific test scenarios

        Focus on critical paths and edge cases. Be concise.
      PROMPT

      response = query_ollama(prompt, system_message)

      {
        agent: 'Testing',
        findings: response || "Unable to complete testing review",
        priority: 'medium'
      }
    end
  end
end
