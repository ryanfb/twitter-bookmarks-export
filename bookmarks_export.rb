#!/usr/bin/env ruby
# Based on: https://github.com/twitterdev/Twitter-API-v2-sample-code/blob/main/Bookmarks-lookup/bookmarks_lookup.rb
require 'json'
require 'typhoeus'
require 'twitter_oauth2'

# First, you will need to enable OAuth 2.0 in your App’s auth settings in the Developer Portal to get your client ID.
# Inside your terminal you will need to set an enviornment variable
# export CLIENT_ID='your-client-id'
client_id = ENV["CLIENT_ID"]

# If you have selected a type of App that is a confidential client you will need to set a client secret.
# Confidential Clients securely authenticate with the authorization server.

# Inside your terminal you will need to set an enviornment variable
# export CLIENT_SECRET='your-client-secret'

# Remove the comment on the following line if you are using a confidential client
client_secret = ENV["CLIENT_SECRET"]


# Replace the following URL with your callback URL, which can be obtained from your App's auth settings.
redirect_uri = "http://localhost:8080"

# Start an OAuth 2.0 session with a public client
# client = TwitterOAuth2::Client.new(
#   identifier: "#{client_id}",
#   redirect_uri: "#{redirect_uri}"
# )

# Start an OAuth 2.0 session with a confidential client

# Remove the comment on the following lines if you are using a confidential client
client = TwitterOAuth2::Client.new(
  identifier: "#{client_id}",
  secret: "#{client_secret}",
  redirect_uri: "#{redirect_uri}"
)

# Create your authorize url
authorization_url = client.authorization_uri(
  # Update scopes if needed
  scope: [
    :'users.read',
    :'tweet.read',
    :'bookmark.read',
    :'bookmark.write',
    :'offline.access'
  ]
)

# Set code verifier and state
code_verifier = client.code_verifier
state = client.state

# Visit the URL to authorize your App to make requests on behalf of a user
puts 'Visit the following URL to authorize your App on behalf of your Twitter handle in a browser:'
puts authorization_url
`open "#{authorization_url}"`

print 'Paste in the full URL after you authorized your App: ' and STDOUT.flush

# Fetch your access token
full_text = gets.chop
new_code = full_text.split("code=")
code = new_code[1]
client.authorization_code = code

# Your access token
token_response = client.access_token! code_verifier

# Make a request to the users/me endpoint to get your user ID
def users_me(url, token_response)
  options = {
    method: 'get',
    headers: {
      "User-Agent": "BookmarksSampleCode",
      "Authorization": "Bearer #{token_response}"
    },
  }

  request = Typhoeus::Request.new(url, options)
  response = request.run

  return response
end

def refresh_token(twitter_client, input_token)
  warn 'Refreshing Twitter OAuth token...'
  twitter_client.refresh_token = input_token.refresh_token
  return twitter_client.access_token!
rescue StandardError => e
  warn e.inspect
  sleep 10
  retry
end

url = "https://api.twitter.com/2/users/me"
me_response = users_me(url, token_response)

json_s = JSON.parse(me_response.body)
user_id = json_s["data"]["id"]

# Make a request to the bookmarks url
bookmarks_url = "https://api.twitter.com/2/users/#{user_id}/bookmarks"

def delete_bookmark(bookmarks_url, token_response, tweet_id)
  warn "Deleting bookmarked tweet: #{tweet_id}"
  options = {
    method: 'delete',
    headers: {
      "User-Agent": "BookmarksSampleCode",
      "Authorization": "Bearer #{token_response}"
    }
  }
  
  request = Typhoeus::Request.new(bookmarks_url + "/#{tweet_id}", options)
  response = request.run

  return response
end

def bookmarked_tweets(bookmarks_url, token_response, pagination_token = nil)
  options = {
    method: 'get',
    headers: {
      "User-Agent": "BookmarksSampleCode",
      "Authorization": "Bearer #{token_response}"
    },
    params: {
      'max_results': 100,
      'expansions': 'attachments.poll_ids,attachments.media_keys,author_id,entities.mentions.username,geo.place_id,in_reply_to_user_id,referenced_tweets.id,referenced_tweets.id.author_id',
      'media.fields': 'duration_ms,height,media_key,preview_image_url,type,url,width,public_metrics,alt_text,variants',
      'place.fields': 'contained_within,country,country_code,full_name,geo,id,name,place_type',
      'poll.fields': 'duration_minutes,end_datetime,id,options,voting_status',
      'tweet.fields': 'attachments,author_id,context_annotations,conversation_id,created_at,entities,geo,id,in_reply_to_user_id,lang,public_metrics,possibly_sensitive,referenced_tweets,reply_settings,source,text,withheld',
      'user.fields': 'created_at,description,entities,id,location,name,profile_image_url,protected,public_metrics,url,username,verified,withheld'
    }
  }

  unless pagination_token.nil?
    options[:params]['pagination_token'] = pagination_token
  end

  request = Typhoeus::Request.new(bookmarks_url, options)
  response = request.run

  return response
end

def fetch_all_bookmarks(bookmarks_url, token_response)
  bookmarks_data = []
  response = bookmarked_tweets(bookmarks_url, token_response)
  parsed_body = JSON.parse(response.body) 
  # warn parsed_body['meta']['next_token']
  if parsed_body['data'].nil?
    warn "Got #{response.code}: #{response.body.inspect}"
  else
    bookmarks_data |= parsed_body['data']
    until parsed_body['meta']['next_token'].nil? do
      sleep 1
      response = bookmarked_tweets(bookmarks_url, token_response, parsed_body['meta']['next_token'])
      parsed_body = JSON.parse(response.body) 
      # warn parsed_body['meta']['next_token']
      if parsed_body['data'].nil?
        warn "Got #{response.code}: #{response.body.inspect}"
      else
        bookmarks_data |= parsed_body['data']
      end
    end
  end
  return bookmarks_data
end

def delete_bookmarks(bookmarks_url, token_response, bookmarks_data, start_position)
  deleted_count = 0
  (start_position..start_position+49).each do |i|
    if i < bookmarks_data.length
      tweet_id = bookmarks_data[i]['id']
      delete_bookmark(bookmarks_url, token_response, tweet_id)
      deleted_count += 1
    end
  end
  warn "#{deleted_count} bookmarks deleted"
  return deleted_count
end

all_bookmarks = []
deleted_bookmarks_count = 0
fetches_done = 0
bookmarks_in_last_fetch = 0
warn 'Initial bookmarks fetch...'
new_bookmarks = fetch_all_bookmarks(bookmarks_url, token_response)
bookmarks_file = "bookmarks_#{user_id}.json"

until false do
  begin
    fetches_done += 1
    bookmarks_in_last_fetch = all_bookmarks.length
    all_bookmarks |= new_bookmarks
    warn "Writing #{all_bookmarks.length} bookmarks to #{bookmarks_file} (#{new_bookmarks.length} fetched)"
    File.open(bookmarks_file, 'w'){|file| file.write(JSON.pretty_generate(all_bookmarks))}
    if all_bookmarks.length > 0
      warn 'Deleting up to 50 bookmarks so that we can fetch more...'
      deleted_bookmarks_count += delete_bookmarks(bookmarks_url, token_response, all_bookmarks, deleted_bookmarks_count)
    end
    token_response = refresh_token(client, token_response)
    warn "Sleeping for 15 minutes after #{fetches_done} bookmark fetches (#{all_bookmarks.length} bookmarks archived, #{all_bookmarks.length - bookmarks_in_last_fetch} new bookmarks added in last fetch from #{new_bookmarks.length} bookmarks retrieved)...next fetch at #{Time.now + (15*60)}"
    sleep(15*60)
    warn 'Fetching more bookmarks...'
    new_bookmarks = fetch_all_bookmarks(bookmarks_url, token_response)
  rescue StandardError => e
    warn e.inspect
    sleep 10
    retry
  end
end
