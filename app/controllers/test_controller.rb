class TestController < ApplicationController
  def index
    render json: { status: 'ok', message: 'Test endpoint is working' }
  end
end
