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
    erb File.read('./.well-known/ai-plugin.json')
  end

  get '/openapi.yaml' do
    erb File.read('./openapi.yaml')
  end

  get '/logo.png' do
    content_type 'image/png'
    File.read('./logo.png')
  end

  get '/oauth' do
    puts "OAuth key value pairs from the ChatGPT Request: #{params}"
    url = "#{params['redirect_uri']}?code=#{OPENAI_CODE}"
    puts "URL: #{url}"
    erb "<a href='<%=url%>'>Click to authorize</a>"
  end

  # Variables
  OPENAI_CLIENT_ID = "ifttt_health_checker_plugin_client_id"
  OPENAI_CLIENT_SECRET = "ifttt_health_checker_plugin_secret"
  OPENAI_CODE = "abc123"
  OPENAI_TOKEN = "def456"

  # Route for handling the OAuth exchange
  post '/auth/oauth_exchange' do
    request_payload = JSON.parse(request.body.read)

    puts "oauth_exchange request=#{request_payload}"

    raise 'bad client ID' unless request_payload['client_id'] == OPENAI_CLIENT_ID
    raise 'bad client secret' unless request_payload['client_secret'] == OPENAI_CLIENT_SECRET
    raise RuntimeError, 'bad code' unless request_payload['code'] == OPENAI_CODE

    content_type :json
    { "access_token": OPENAI_TOKEN,  "token_type": "bearer" }.to_json
  end

  run! if app_file == $0
end
