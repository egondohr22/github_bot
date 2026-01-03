require_relative 'base_agent'

module Agents
  class CodeQualityAgent < BaseAgent
    def review(parsed_diff, context = {})
      log_info("CodeQualityAgent: Starting code quality review")

      system_message = <<~SYSTEM
        You are a Ruby on Rails code quality expert. Focus on best practices and maintainability.

        Focus on:
        - Rails conventions (fat models, skinny controllers)
        - SOLID principles violations
        - Code smells (long methods, god objects)
        - DRY violations
        - Naming conventions
        - Method complexity
        - Proper use of Rails idioms
        - Code readability

        Provide constructive feedback. Be concise.
        Format: List issues with specific suggestions.
      SYSTEM

      prompt = <<~PROMPT
        Review this Rails code diff for CODE QUALITY and BEST PRACTICES:

        #{format_diff_for_prompt(parsed_diff)}

        Respond with:
        1. Code quality issues (or "Code follows Rails best practices")
        2. For each issue: location, problem description, suggested improvement

        Focus on significant issues. Keep it concise.
      PROMPT

      response = query_ollama(prompt, system_message)

      {
        agent: 'Code Quality',
        findings: response || "Unable to complete code quality review",
        priority: 'high'
      }
    end
  end
end
