require 'active_support/all'
require 'graphql'
require 'pry'
require 'sinatra/base'
require 'sinatra/reloader'
require 'sinatra/cross_origin'
require 'net/http'
require 'json'

class Statuses
  class << self
    def list_all
      activity_feed_events = graphql(ACTIVITY_FEED_EVENTS_QUERY).
                               dig('data', 'activity_feed_events')

      raise "Cannot find activity_feed_events in GraphQL response" unless activity_feed_events

      statuses = activity_feed_events.group_by { |entry| entry.dig("common", "applet_id") }.
                   select { |k, v| k.present? }.
                   transform_values { |v| v.sort_by { |e| DateTime.parse(e["created_at"])}.last }.
                   transform_values { |v| v["item_type"] }.
                   map { |k, v| {"slug" => k, "status" => v == "success" ? "Healthy" : "NotHealthy"} }

      applet_ids = statuses.map { |s| '"' + s["slug"] + '"' }.join(",")
      applet_details = graphql(LIVE_APPELTS_GRAPHQL, applet_ids: applet_ids)
                         .dig("data", "live_applets")
      raise "Cannot find live_applets details in GraphQL response" unless applet_details

      applet_details = applet_details.map {  |ad| ad["applet"] }.map { |e| [e["id"], e["name"]] }.to_h
      statuses.each { |s| s["name"] = applet_details[s["slug"]] }

      statuses
    end

    private

    GRAPHQL_ENDPOINT = 'https://ifttt.com/api/v3/graph'
    JWT=ENV["JWT"]

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

    LIVE_APPELTS_GRAPHQL = <<~GRAPHQL
  query {
    live_applets(applet_ids: [%{applet_ids}]) {
      applet {
        id,
        name
      }
    }
  }
  GRAPHQL

    def graphql(query, **params)
      puts "Making GraphQL call..."
      uri = URI(GRAPHQL_ENDPOINT)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true if uri.scheme == 'https'

      request = Net::HTTP::Post.new(uri.path)
      request.body = JSON.dump({ query: sprintf(query, params) })
      request['Content-Type'] = 'application/json'
      request['Authorization'] = %Q{Token jwt="#{JWT}"}
      response = http.request(request)
      puts "Making GraphQL call... done"
      JSON.parse(response.body)
    end
  end
end
