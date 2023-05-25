require 'pry'
require 'sinatra/base'
require 'sinatra/reloader'
require 'sinatra/cross_origin'

require_relative 'models/statuses'

class App < Sinatra::Base
  configure :development do
    register Sinatra::Reloader
  end

  configure do
    enable :cross_origin
  end

  before do
    response.headers["Allow"] = "GET, PUT, POST, DELETE, OPTIONS"
    response.headers["Access-Control-Allow-Headers"] = "*"
    response.headers["Access-Control-Allow-Origin"] = "*"
    request_logger = Logger.new(STDOUT)
    request_logger.info("Request: #{request.request_method} #{request.url}")
    @plugin_host = "https://#{request.env['HTTP_HOST']}"
  end

  options "*" do
    200
  end

  get '/check_health' do
    content_type :json

    Statuses.list_all.to_json
  end

  get '/.well-known/ai-plugin.json' do
    content_type :json
    ERB.
      new(File.read('./.well-known/ai-plugin.json')).
      result(binding)
  end

  get '/openapi.yaml' do
    ERB.
      new(File.read('./openapi.yaml')).
      result(binding)
  end

  get '/logo.png' do
    content_type 'image/png'
    File.read('./logo.png')
  end

 run! if app_file == $0
end
