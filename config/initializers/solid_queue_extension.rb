module CustomProcess
  def heartbeat
    ActiveRecord::Base.logger.silence { super }
  end
end

Rails.application.config.after_initialize do
  SolidQueue::Process.send(:prepend, CustomProcess)
end