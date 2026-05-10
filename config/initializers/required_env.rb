REQUIRED_ENV_VARS = %w[GEMINI_API_KEY].freeze

REQUIRED_ENV_VARS.each do |var|
  raise "Missing required environment variable: #{var}" if ENV[var].blank?
end
