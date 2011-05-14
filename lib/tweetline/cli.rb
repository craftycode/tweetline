module Tweetline
  class CLI < Thor
    def initialize(*)
      super
      Tweetline.configure_twitter
      Tweetline.configure_pipes

      Signal.trap("SIGINT") do
        exit!
      end
    end

    default_task :ls

    desc "cat [ID]", "Display the details of a tweet with responses based on twitter id or piped in tweets."
    def cat(twitter_id = "")
      if twitter_id.strip.length > 0
        tweet = Twitter.status(ARGV[1])
        Tweetline.cat_tweet(tweet.id, tweet.created_at, tweet.user.name, tweet.user.screen_name, tweet.text)
      else
        Tweetline.each_tweet do |tweet|
          Tweetline.cat_tweet(tweet["id"], tweet["created_at"], tweet["name"], tweet["screen_name"], tweet["text"])
        end
      end
    end
  
    desc "follow [SCREEN_NAME]", "Follows the twitter user based on their screen name or piped in tweets."
    def follow(screen_name = "")
      if screen_name.strip.length > 0
        Twitter.follow(screen_name) 
      else
        Tweetline.each_tweet do |tweet|
          Twitter.follow(tweet["screen_name"])
          puts "Followed -> #{tweet["screen_name"]}" unless Twitter.is_piped_to_tweetline?
        end
      end
    end

    desc "grep PATTERN", "Display tweets matching pattern."
    def grep(pattern)
      Tweetline.each_tweet do |tweet|
	regex = Regexp.new(pattern)
        if regex =~ tweet["name"] or regex =~ tweet["screen_name"] or regex =~ tweet["text"]
          Tweetline.put_tweet(tweet["id"], tweet["created_at"], tweet["name"], tweet["screen_name"], tweet["text"])
	end
      end
    end
    
    desc "json", "Lists tweets from the timeline in JSON format."
    def json
      Tweetline.each_tweet do |tweet|
        puts tweet.to_json
      end
    end

    desc "ls [SCREEN_NAME]", "Lists tweets from the timeline."
    def ls(screen_name = "")
      options = {:count => 10}
      options[:screen_name] = screen_name if screen_name.strip.length > 0
      Tweetline.each_tweet(options) do |tweet|
        Tweetline.put_tweet(tweet["id"], tweet["created_at"], tweet["name"], tweet["screen_name"], tweet["text"])
      end
    end

    desc "reply ID, REPLY", "Replies to the specified tweet with @screenname at the beginning."
    def reply(twitter_id, status)
      status = "@#{Twitter.status(twitter_id).user.screen_name} #{status}"
      if status.length > 140
        puts ""
        puts "This status is too long."
	puts ""
	puts "     #{status[0..139]}"
	puts ""
      else
        Twitter.update(status, :in_reply_to_status_id => twitter_id)
      end
    end

    desc "retweet [ID]", "Retweets the tweet by the Twitter id or a group of piped in tweets."
    def retweet(twitter_id = "")
      if twitter_id.strip.length > 0
        Twitter.retweet(twitter_id)
      else
        Tweetline.each_tweet do |tweet|
          Twitter.retweet(tweet["id"])
          puts "Retweeted:" unless Twitter.is_piped_to_tweetline?
          Twitter.put_tweet(tweet["id"], tweet["created_at"], tweet["name"], tweet["screen_name"], tweet["text"])
        end
      end
    end

    desc "rm [ID]", "Removes the tweet by it's id or a list of piped in tweets."
    def rm(twitter_id = "")
      if twitter_id.strip.length > 0
        Twitter.status_destroy(twitter_id)
      else
        Tweetline.each_tweet do |tweet|
          Twitter.status_destroy(tweet["id"])
          puts "Removed:" unless Twitter.is_piped_to_tweetline?
          Twitter.put_tweet(tweet["id"], tweet["created_at"], tweet["name"], tweet["screen_name"], tweet["text"])
        end
      end
    end

    desc "say", "Speaks the tweet at the top of your timeline."
    def say
      Tweetline.each_tweet(:count => 1) do |tweet|
        Tweetline.say_tweet(tweet["id"], tweet["created_at"], tweet["name"], tweet["screen_name"], tweet["text"])
      end
    end

    desc "tail", "Displays recent tweets in chronological order."
    method_option :follow, :type => :boolean, :aliases => "-f", :default => false, :banner => "Continue following tweets as they are added."
    method_option :number, :type => :numeric, :aliases => "-n", :default => 10, :banner => "Specifies the number of tweets to display.  This option is ignored if the follow option is true."
    def tail
      previous_id = "1"
      begin
	if options[:follow] 
          if previous_id == "1"
	    count = 1 
	  else
            count = 100
	  end
	else
          count = options[:number]
	end
	tweets = Twitter.home_timeline(:count => count, :since_id => previous_id) rescue []
        tweets.reverse_each do |tweet|
          Tweetline.put_tweet(tweet.id, tweet.created_at, tweet.user.name, tweet.user.screen_name, tweet.text)
          previous_id = tweet.id
        end

	sleep(30) if options[:follow]

      end while options[:follow]
    end

    desc "unfollow [SCREEN_NAME]", "Unfollows the twitter user based on their screen name or piped in tweets."
    def unfollow(screen_name = "")
      if screen_name.strip.length > 0
        Twitter.unfollow(screen_name) 
      else
        Tweetline.each_tweet do |tweet|
          Twitter.unfollow(tweet["screen_name"])
          puts "Followed -> #{tweet["screen_name"]}" unless Twitter.is_piped_to_tweetline?
        end
      end
    end

    desc "update STATUS", "Updates your current Twitter status."
    def update(status)
      if status.length > 140
        puts ""
        puts "This status is too long."
	puts ""
	puts "     #{status[0..139]}"
	puts ""
      else
        Twitter.update(status)
      end
    end

    desc "yaml", "Lists tweets from the timeline in YAML format."
    def yaml
      Tweetline.each_tweet do |tweet|
        puts tweet.to_yaml
      end
    end
  end
end
