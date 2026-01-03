require_relative 'base_agent'

module Agents
  class SecurityAgent < BaseAgent
    def review(parsed_diff, context = {})
      log_info("SecurityAgent: Starting security review")

      system_message = <<~SYSTEM
        You are a Ruby on Rails security expert. Your sole focus is identifying security vulnerabilities.

        Focus on:
        - SQL injection vulnerabilities
        - Cross-Site Scripting (XSS) risks
        - CSRF token issues
        - Mass assignment vulnerabilities (strong parameters)
        - Authentication/Authorization bypasses
        - Unsafe redirects or file operations
        - Secret/credential exposure
        - Insecure deserialization

        Provide ONLY critical security findings. Be concise and specific.
        Format: List each issue with file, line context, and fix suggestion.
      SYSTEM

      prompt = <<~PROMPT
        Review this Rails code diff for SECURITY VULNERABILITIES ONLY:

        #{format_diff_for_prompt(parsed_diff)}

        Respond with:
        1. Critical security issues found (or "No critical security issues found")
        2. For each issue: specific location, vulnerability type, and recommended fix

        Keep it concise and actionable.
      PROMPT

      response = query_ollama(prompt, system_message)

      {
        agent: 'Security',
        findings: response || "Unable to complete security review",
        priority: 'critical'
      }
    end
  end
end
