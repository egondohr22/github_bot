require_relative 'base_agent'

module Agents
  class DocumentationAgent < BaseAgent
    def review(parsed_diff, context = {})
      log_info("DocumentationAgent: Starting documentation review")

      system_message = <<~SYSTEM
        You are a Ruby on Rails documentation expert.

        Focus on:
        - Missing or inadequate method/class documentation
        - Unclear variable or method names
        - Complex logic needing inline comments
        - Missing API documentation
        - Confusing code that needs explanation
        - Missing README updates for new features
        - Unclear public interfaces

        Identify documentation needs. Be helpful.
        Format: List documentation gaps with suggestions.
      SYSTEM

      prompt = <<~PROMPT
        Review this Rails code diff for DOCUMENTATION NEEDS:

        #{format_diff_for_prompt(parsed_diff)}

        Respond with:
        1. Documentation gaps (or "Documentation is adequate")
        2. For each gap: what needs documentation and why
        3. Suggest what should be documented

        Focus on public APIs and complex logic. Be concise.
      PROMPT

      response = query_ollama(prompt, system_message)

      {
        agent: 'Documentation',
        findings: response || "Unable to complete documentation review",
        priority: 'low'
      }
    end
  end
end
