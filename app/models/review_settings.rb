# Wraps the per-user review config stored in the `settings` table (a jsonb hash
# under the key "review"). Every getter returns the user's stored value, or
# falls back to a default defined here when it isn't set. The rest of the app
# only talks to this wrapper, so defaults live in exactly one place.
class ReviewSettings
  KEY = "review".freeze

  DEFAULT_MAX_TOOL_CALLS = 15
  MIN_TOOL_CALLS = 1
  MAX_TOOL_CALLS = 50

  # Ordered low → high; the index is the emphasis weight used during synthesis.
  PRIORITY_LEVELS = %w[low medium high critical].freeze
  DEFAULT_PRIORITY = "medium".freeze

  DEFAULT_PRIORITIES = {
    "security"     => "critical",
    "code_quality" => "high",
    "performance"  => "high"
  }.freeze

  def self.available_agents
    AgentOrchestrator::AGENT_CLASSES.keys
  end

  def self.priority_weight(priority)
    PRIORITY_LEVELS.index(priority.to_s) || -1
  end

  def self.for(user)
    new(Setting.get(user, KEY))
  end

  def initialize(stored = {})
    @stored = stored || {}
  end

  def max_tool_calls
    (@stored["max_tool_calls"] || DEFAULT_MAX_TOOL_CALLS).to_i.clamp(MIN_TOOL_CALLS, MAX_TOOL_CALLS)
  end

  def enabled_agents
    return self.class.available_agents unless @stored.key?("enabled_agents")

    Array(@stored["enabled_agents"]).map(&:to_s)
  end

  def agent_enabled?(name)
    enabled_agents.include?(name.to_s)
  end

  def priority_for(name)
    level = @stored.dig("agent_priorities", name.to_s).to_s.downcase
    return level if PRIORITY_LEVELS.include?(level)

    DEFAULT_PRIORITIES[name.to_s] || DEFAULT_PRIORITY
  end
end
