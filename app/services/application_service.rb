require 'fileutils'

class ApplicationService
  private

  LOG_DIR = Rails.root.join('log', 'conversations')

  def open_conversation_log(context, agent_key, model)
    FileUtils.mkdir_p(LOG_DIR)
    pr = context['pr_number']
    ts = Time.now.strftime('%Y%m%d_%H%M%S')
    File.open(LOG_DIR.join("pr#{pr}_#{agent_key}_#{ts}.md"), 'w')
  rescue => e
    log_error("#{self.class.name}: Could not open conversation log: #{e.message}")
    nil
  end

  def conv_write(file, text)
    file&.write(text)
    file&.flush
  end

  def log_info(message)
    Rails.logger.info "-------\n#{message}\n-------"
  end

  def log_error(message)
    Rails.logger.error "-------\n#{message}\n-------"
  end
end
