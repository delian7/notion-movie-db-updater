require 'dotenv/load'
require 'httparty'
require 'logger'

class ImdbError < StandardError; end
LOGGER = Logger.new($stdout)
LOGGER.level = ENV['LOG_LEVEL'] || Logger::INFO

class ImdbClient
  include HTTParty
  base_uri 'https://imdb236.p.rapidapi.com/imdb'

  def search_movies(title)
    LOGGER.info("Searching for movie with title: #{title}")

    setup_client_request

    response = self.class.get("/search?originalTitleAutocomplete=#{URI.encode_www_form_component(title)}&type=movie&rows=25&sortOrder=DESC&sortField=numVotes")
    raise ImdbError, "IMDB API error: #{response['errorMessage']}" if response['errorMessage'].to_s.length.positive?

    data = JSON.parse(response.body)
    data['results'] || []
  rescue StandardError => e
    LOGGER.error("Failed to search movies with title #{title}: #{e.message}")
    raise ImdbError, "Failed to search movies with title #{title}: #{e.message}"
  end

  def get_movie_data(imdb_id)
    LOGGER.info("Fetching data for movie: #{imdb_id}")
    setup_client_request

    response = self.class.get("/#{imdb_id}")
    raise ImdbError, "IMDB API error: #{response['errorMessage']}" if response['errorMessage'].to_s.length.positive?

    JSON.parse(response.body)
  rescue StandardError => e
    LOGGER.error("Failed to fetch IMDB data for #{imdb_id}: #{e.message}")
    raise ImdbError, "Failed to fetch IMDB data for #{imdb_id}: #{e.message}"
  end

  private

  def cache_key(imdb_id)
    "imdb:#{imdb_id}"
  end

  def setup_client_request
    imdb_api_key = ENV['IMDB_API_KEY']
    self.class.headers(
      'X-RapidAPI-Host' => 'imdb236.p.rapidapi.com',
      'X-RapidAPI-Key' => imdb_api_key,
      'Content-Type' => 'application/json'
    )
  end
end
