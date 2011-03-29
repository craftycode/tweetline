#!/usr/bin/ruby

require 'rubygems'
require 'twitter'
require 'json'

Twitter.configure do |config|
  File.open(File.expand_path('~/.tweetlinerc')) do |yaml|
    options = YAML.load(yaml)
    config.consumer_key = options[:consumer_key]
    config.consumer_secret = options[:consumer_secret]
    config.oauth_token = options[:oauth_token]
    config.oauth_token_secret = options[:oauth_token_secret]
  end
end

STDOUT.sync = true

@is_piped_to_tweetline = `ps -ax -o pid,args | grep -E "^#{Process.pid+1}"` =~ /\/tl[^\/]*$/

def time_stamp(time)
  time = Time.parse(time)
  format = '%I:%M %p'
  format = '%m/%d/%y ' + format unless time.yday == Time.now.yday

  return time.strftime(format)
end

def cat_tweet(tweet_id, created_at, name, screen_name, text)
  put_tweet(tweet_id, created_at, name, screen_name, text)
  
  tweet = Twitter.status(tweet_id)
  puts "Conversation:", "" if tweet.in_reply_to_status_id
  while tweet.in_reply_to_status_id
    tweet = Twitter.status(tweet.in_reply_to_status_id)
    put_tweet(tweet.id, tweet.created_at, tweet.user.name, tweet.user.screen_name, tweet.text)
  end
end

def say_tweet(tweet_id, created_at, name, screen_name, text)
  tweet_text = text.strip.gsub(/http:.*?( |$)/, '').gsub(/^RT/, '').gsub(/@/, '').split(/ /).map{|s| s.gsub(/[^A-Za-z0-9.!?,']/, '')}.join(' ')
  connector = text.strip =~ /^RT/ ? " retweets " : "says"
  # puts name, "     #{connector} #{tweet_text}", ""
  put_tweet(tweet_id, created_at, name, screen_name, text)
  `say #{name} #{connector} "#{tweet_text}"`
end

def put_tweet(tweet_id, created_at, name, screen_name, text)
  if STDOUT.fcntl(Fcntl::F_GETFL, 0) == 1 and @is_piped_to_tweetline
    puts({"id" => tweet_id, "created_at" => created_at, "name" => name, "screen_name" => screen_name, "text" => text}.to_json)
  else
    puts "#{name} (@#{screen_name}) [#{time_stamp(created_at)}]", "     #{text} (#{tweet_id})", ""
  end
end

def each_tweet(options={:count => 10})
  if STDIN.fcntl(Fcntl::F_GETFL, 0) == 0
    STDIN.each do |line|
      yield JSON.load(line)
    end
  else
    if options[:screen_name]
      screen_name = options.delete(:screen_name)
      timeline = Twitter.user_timeline(screen_name, options)
    else
      timeline = Twitter.home_timeline(options)
    end
    timeline.each do |tweet|
      yield({"id" => tweet.id, "created_at" => tweet.created_at, "name" => tweet.user.name, "screen_name" => tweet.user.screen_name, "text" => tweet.text})
    end
  end
end

if ARGV[0] == "say"
  each_tweet(:count => 1) do |tweet|
    say_tweet(tweet["id"], tweet["created_at"], tweet["name"], tweet["screen_name"], tweet["text"])
  end
elsif ARGV[0] == "json"
  each_tweet do |tweet|
    puts tweet.to_json
  end
elsif ARGV[0] == "yaml"
  each_tweet do |tweet|
    puts tweet.to_yaml
  end
elsif ARGV[0] == "ls" or ARGV.length == 0
  options = {:count => 10}
  options[:screen_name] = ARGV[1] if ARGV[1]
  each_tweet(options) do |tweet|
    put_tweet(tweet["id"], tweet["created_at"], tweet["name"], tweet["screen_name"], tweet["text"])
  end
elsif ARGV[0] == "retweet"
  if ARGV[1]
    Twitter.retweet(ARGV[1])
  else
    each_tweet do |tweet|
      Twitter.retweet(tweet["id"])
      puts "Retweeted:" unless @is_piped_to_tweetline
      put_tweet(tweet["id"], tweet["created_at"], tweet["name"], tweet["screen_name"], tweet["text"])
    end
  end
elsif ARGV[0] == "cat"
  if ARGV[1]
    tweet = Twitter.status(ARGV[1])
    cat_tweet(tweet.id, tweet.created_at, tweet.user.name, tweet.user.screen_name, tweet.text)
  else
    each_tweet do |tweet|
      cat_tweet(tweet["id"], tweet["created_at"], tweet["name"], tweet["screen_name"], tweet["text"])
    end
  end
elsif ARGV[0] == "tail"
  if ARGV[1] == "-f"
    previous_id = "1"
    count = 1
    while true
      begin
        Twitter.home_timeline(:count => count, :since_id => previous_id).reverse_each do |tweet|
          put_tweet(tweet.id, tweet.created_at, tweet.user.name, tweet.user.screen_name, tweet.text)
          previous_id = tweet.id
        end
      rescue
        put_tweet("", Time.now.to_s, "Tweetline", "tweetline", "Twitter is having issues.")
      end
      count = 5
      sleep(30)
    end
  else
    count = ARGV[1] == "-n" && ARGV[2].to_i > 0 ? ARGV[2].to_i : 10
    Twitter.home_timeline(:count => count).reverse_each do |tweet|
      put_tweet(tweet.id, tweet.created_at, tweet.user.name, tweet.user.screen_name, tweet.text)
    end
  end
elsif ARGV[0] == "update"
  Twitter.update(ARGV[1..-1].join(' '))
end
