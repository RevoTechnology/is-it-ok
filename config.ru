# frozen_string_literal: true

require 'roda'
require 'redis'
require 'json'
require 'oj'
require 'ddtrace'

Datadog.configure do |c|
  c.use :rack, analytics_enabled: true, service_name: 'os-it-ok'
  c.use :redis
end

# rubocop:disable Style/MethodMissingSuper, Style/MissingRespondToMissing, Style/ModuleFunction
module Metrics
  extend self

  def method_missing(method, *args)
    statsd.send(method, *args)
  end

  def statsd
    @statsd ||= Datadog::Statsd.new('localhost', 8125)
  end
end
# rubocop:enable Style/MethodMissingSuper, Style/MissingRespondToMissing, Style/ModuleFunction

# class App is base roda class like rack app
class App < Roda
  BASE_AUTH = [ENV.fetch('BASE_USERNAME', 'lol'), ENV.fetch('BASE_PASSWORD', 'kek')].freeze
  REDIS_URL = ENV.fetch('REDIS_URL')

  # PLUGINS
  plugin :default_headers, 'Content-Type' => 'application/json'
  plugin :http_auth,
        authenticator: proc { |user, pass| BASE_AUTH == [user, pass] },
        unauthorized: ->(_request) { { errors: ['unauthorized'] }.to_json }

  # ROUTES
  route do |r|
    http_auth
    r.on '' do
      r.post do
        Metrics.increment('revo.is-it-ok.post')
        { success: true }.to_json if store_key!
      end

      r.get do
        alive = key_alive?(r.params['key'])
        Metrics.increment('revo.is-it-ok.get', tags: ["success:#{alive}"])
        { success: true, find: alive }.to_json
      end
    end
  end

  private

  def body
    Oj.load(request.body.read, symbol_keys: true)
  end

  def key_alive?(key)
    stored_time = redis_conn.get(key)
    return false unless stored_time

    (Time.now.to_i - stored_time.to_i) < 86_400
  end

  def store_key!
    redis_conn.set(body[:key], Time.now.to_i)
  end

  def redis_conn
    Redis.new(url: REDIS_URL)
  end
end

run App.freeze.app
