require 'pry'

require 'sinatra/base'
require 'sinatra/reloader'
require 'sinatra/cross_origin'
require 'json'

require 'active_support/all'


require 'graphql'
require 'json'
require 'net/http'

# Define the GraphQL query
ACTIVITY_FEED_EVENTS_QUERY = <<~GRAPHQL
  query {
    activity_feed_events(limit: 1000) {
      id
      created_at
      item_type
      ife {
        error_code
        message
        title
      }
      common {
        applet_id
        content_text
        feed_category
      }
    }
  }
GRAPHQL

# Set the GraphQL endpoint URL
GRAPHQL_ENDPOINT = 'https://ifttt.com/api/v3/graph'
JWT=ENV["JWT"]

def graphql(query)
  puts "Making GraphQL call..."
  uri = URI(GRAPHQL_ENDPOINT)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true if uri.scheme == 'https'

  request = Net::HTTP::Post.new(uri.path)
  request.body = JSON.dump({ query: query })
  request['Content-Type'] = 'application/json'
  request['Authorization'] = %Q{Token jwt="#{JWT}"}
  response = http.request(request)
  puts "Making GraphQL call... done"
  JSON.parse(response.body)
end

def get_health_statuses
  activity_feed_events = graphql(ACTIVITY_FEED_EVENTS_QUERY).
                           dig('data', 'activity_feed_events')

  raise "Cannot find activity_feed_events in GraphQL response" unless activity_feed_events

  statuses = activity_feed_events.group_by { |entry| entry.dig("common", "applet_id") }.
               select { |k, v| k.present? }.
               transform_values { |v| v.sort_by { |e| DateTime.parse(e["created_at"])}.last }.
               transform_values { |v| v["item_type"] }.
               map { |k, v| {"slug" => k, "status" => v == "success" ? "Healthy" : "NotHealthy"} }

  puts "Totally #{statuses.size} parsed events"

  applet_slugs = statuses.map { |s| '"' + s["slug"] + '"' }.join(",")
  live_appelts_graphql = <<~GRAPHQL
  query {
    live_applets(applet_ids: [#{applet_slugs}]) {
      applet {
        id,
        name
      }
    }
  }
GRAPHQL
  applet_details = graphql(live_appelts_graphql)
                     .dig("data", "live_applets")
  raise "Cannot find live_applets details in GraphQL response" unless applet_details
  applet_details = applet_details.map {  |ad| ad["applet"] }.map { |e| [e["id"], e["name"]] }.to_h
  statuses.each { |s| s["name"] = applet_details[s["slug"]] }

  statuses
end

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

    get_health_statuses.to_json
    # # Dummy response for demonstration purposes
    # [
    #   { "slug": "applet1", "name": "Applet 1", "status": "Healthy" },
    #   { "slug": "applet2", "name": "Applet 2", "status": "NotHealthy" }
    # ].to_json
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
