# frozen_string_literal: true

require 'roda'
require 'redis'
require 'json'
require 'oj'
require 'byebug'
##
# class App is base roda class like rack app
class App < Roda
  BASE_AUTH = [ENV.fetch('BASE_USERNAME', 'lol'), ENV.fetch('BASE_PASSWORD', 'kek')].freeze
  REDIS_URL = ENV.fetch('REDIS_URL')

  # PLUGINS
  plugin :default_headers,
         'Content-Type' => 'application/json'
  plugin :http_auth, authenticator: proc { |user, pass| BASE_AUTH == [user, pass] },
    unauthorized: ->(_request) { { errors: ['unauthorized'] }.to_json }

  # ROUTES
  route do |r|
    r.on '' do
      r.post do
        { success: true }.to_json if store_key!
      end

      r.get do
        { success: true, find: key_alive?(r.params['key']) }.to_json
      end
    end
  end

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
