require 'pry'

require 'sinatra/base'
require 'sinatra/reloader'
require 'sinatra/cross_origin'
require 'json'

class App < Sinatra::Base
  configure :development do
    register Sinatra::Reloader
  end

  configure do
    enable :cross_origin
  end

  before do
    response.headers['Access-Control-Allow-Origin'] = '*'
    # Log the request details
    request_logger = Logger.new(STDOUT)
    request_logger.info("Request: #{request.request_method} #{request.url}")
  end

  options "*" do
    response.headers["Allow"] = "GET, PUT, POST, DELETE, OPTIONS"
    response.headers["Access-Control-Allow-Headers"] = "*"
    response.headers["Access-Control-Allow-Origin"] = "*"
    200
  end

  get '/check_health' do
    content_type :json

    # Your logic to check the health status of IFTTT applets goes here

    # Dummy response for demonstration purposes
    [
      { "slug": "applet1", "name": "Applet 1", "status": "Healthy" },
      { "slug": "applet2", "name": "Applet 2", "status": "NotHealthy" }
    ].to_json
  end

  get '/.well-known/ai-plugin.json' do
    content_type :json

    # Read and serve the ai-plugin.json file
    File.read('./.well-known/ai-plugin.json')
  end

  get '/openapi.yaml' do
    File.read('./openapi.yaml')
  end

  get '/logo.png' do
    content_type 'image/png'
    File.read('./logo.png')
  end

 run! if app_file == $0
end
