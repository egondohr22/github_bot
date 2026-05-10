class ApplicationService
  private

  def log_info(message)
    Rails.logger.info "-------\n#{message}\n-------"
  end

  def log_error(message)
    Rails.logger.error "-------\n#{message}\n-------"
  end
end
