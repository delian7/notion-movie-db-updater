
require 'logger'
require 'notion-ruby-client'

class NotionError < StandardError; end

NOTION_DATABASE_ID = ENV['NOTION_DATABASE_ID']
LOGGER = Logger.new($stdout)
LOGGER.level = ENV['LOG_LEVEL'] || Logger::INFO

class NotionClient
  def initialize
    @client = Notion::Client.new(token: ENV['NOTION_TOKEN'])
  rescue StandardError => e
    LOGGER.error("Failed to initialize Notion client: #{e.message}")
    raise NotionError, "Failed to initialize Notion client: #{e.message}"
  end

  def get_movies_to_update
    notion_database_id = ENV['NOTION_DATABASE_ID']
    LOGGER.info("Fetching movies to update from database: #{notion_database_id}")

    response = @client.database_query(
      database_id: notion_database_id,
      filter: {
        property: 'Synced',
        checkbox: {
          equals: false
        }
      }
    )

    LOGGER.info("Found #{response.results.size} movies to update")

    response.results
  rescue StandardError => e
    LOGGER.error("Failed to fetch movies: #{e.message}")
    raise NotionError, "Failed to fetch movies: #{e.message}"
  end

  def update_movie(page_id, imdb_data)
    LOGGER.info("Updating movie page: #{page_id}")
    @client.update_page(
      page_id: page_id,
      properties: {
        'Rating': { number: imdb_data['averageRating']&.to_f },
        'Description': { rich_text: [ { text: { content: imdb_data['description'] } } ] },
        'Genres': { multi_select: imdb_data['genres']&.map { |genre| { name: genre } } },
        'Release Year': { number: imdb_data['startYear']&.to_i },
        'Poster': { files: [{ name: 'Poster', external: { url: imdb_data['primaryImage'] } } ] },
        'Trailer': { url: imdb_data['trailer'] },
        'IMDB ID': { rich_text: [{ text: { content: imdb_data['id'] } } ] },
        'IMDB Link': { url: imdb_data['url'] },
        'Synced': { checkbox: true }
      }
    )
    LOGGER.info("Successfully updated movie: #{page_id}")
  rescue StandardError => e
    LOGGER.error("Failed to update movie #{page_id}: #{e.message}")
    raise NotionError, "Failed to update movie #{page_id}: #{e.message}"
  end
end
