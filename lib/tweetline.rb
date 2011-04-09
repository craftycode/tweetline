require 'thor'
require 'twitter'
require 'json'

module Tweetline
  class << self

    def cat_tweet(tweet_id, created_at, name, screen_name, text)
      Tweetline.put_tweet(tweet_id, created_at, name, screen_name, text)
      
      tweet = Twitter.status(tweet_id)
      puts "Conversation:", "" if tweet.in_reply_to_status_id
      while tweet.in_reply_to_status_id
        tweet = Twitter.status(tweet.in_reply_to_status_id)
        Tweetline.put_tweet(tweet.id, tweet.created_at, tweet.user.name, tweet.user.screen_name, tweet.text)
      end
    end

    def configure_twitter
      Twitter.configure do |config|
        File.open(File.expand_path('~/.tweetlinerc')) do |yaml|
          options = YAML.load(yaml)
          config.consumer_key = options[:consumer_key]
          config.consumer_secret = options[:consumer_secret]
          config.oauth_token = options[:oauth_token]
          config.oauth_token_secret = options[:oauth_token_secret]
        end
      end
    end

    def configure_pipes
      STDOUT.sync = true
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

    def is_piped_to_tweetline?
      @is_piped_to_tweetline |= `ps -ax -o pid,args | grep -E "^#{Process.pid+1}"` =~ /\/tl[^\/]*$/
    end

    def put_tweet(tweet_id, created_at, name, screen_name, text)
      if STDOUT.fcntl(Fcntl::F_GETFL, 0) == 1 and Tweetline.is_piped_to_tweetline?
        puts({"id" => tweet_id, "created_at" => created_at, "name" => name, "screen_name" => screen_name, "text" => text}.to_json)
      else
        puts "#{name} (@#{screen_name}) [#{time_stamp(created_at)}]", "     #{text} (#{tweet_id})", ""
      end
    end
    
    def say_tweet(tweet_id, created_at, name, screen_name, text)
      tweet_text = text.strip.gsub(/http:.*?( |$)/, '').gsub(/^RT/, '').gsub(/@/, '').split(/ /).map{|s| s.gsub(/[^A-Za-z0-9.!?,']/, '')}.join(' ')
      connector = text.strip =~ /^RT/ ? " retweets " : "says"
      # puts name, "     #{connector} #{tweet_text}", ""
      Tweetline.put_tweet(tweet_id, created_at, name, screen_name, text)
      `say #{name} #{connector} "#{tweet_text}"`
    end

    def time_stamp(time)
      time = Time.parse(time)
      format = '%I:%M %p'
      format = '%m/%d/%y ' + format unless time.yday == Time.now.yday
    
      return time.strftime(format)
    end
    
  end
end
