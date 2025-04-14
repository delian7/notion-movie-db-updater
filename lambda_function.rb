# frozen_string_literal: true

require 'json'
require 'logger'
require 'byebug'

require_relative 'src/notion_client.rb'
require_relative 'src/imdb_client.rb'

LOGGER = Logger.new($stdout)
LOGGER.level = ENV['LOG_LEVEL'] || Logger::INFO

def process_movies
  LOGGER.info("Starting movie update process")
  notion = NotionClient.new
  imdb = ImdbClient.new
  movies = notion.get_movies_to_update

  updated_count = 0
  error_count = 0

  movies.each do |movie|
    name = movie.properties['Name']&.title[0]&.plain_text

    begin
      imdb_id = movie.properties['IMDB ID']&.rich_text[0]&.plain_text
      imdb_data = imdb_id ? imdb.get_movie_data(imdb_id) : imdb.search_movies(name)[0]
      # unless imdb_data.dig(0, 'id')
      #   LOGGER.warn("Skipping movie #{movie.id}: Invalid IMDB data received")
      #   next
      # end

      notion.update_movie(movie.id, imdb_data)
      updated_count += 1
    rescue StandardError => e
      error_count += 1
      LOGGER.error("Error processing movie #{movie.id}: #{e.message}")
    end
  end

  LOGGER.info("Movie update process completed. Updated: #{updated_count}, Errors: #{error_count}")
  { movies_updated: updated_count, errors: error_count }
end

def lambda_handler(event:, context:) # rubocop:disable Lint/UnusedMethodArgument
  http_method = event['httpMethod']
  # resource = event['resource']
  # raw_data = event.dig('queryStringParameters', 'raw_data')

  case http_method
  when 'POST'
    result = process_movies
    send_response(result)
  else
    method_not_allowed_response
  end
rescue StandardError => e
  error_response(e)
end

def send_response(data)
  {
    'statusCode' => 200,
    'body' => JSON.generate(data)
  }
end

def method_not_allowed_response
  {
    'statusCode' => 405,
    'body' => JSON.generate({ error: 'Method Not Allowed' })
  }
end

def error_response(error)
  {
    'statusCode' => 500,
    'body' => JSON.generate({ error: error.message })
  }
end
