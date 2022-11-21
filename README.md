# twitter-bookmarks-export

Blog post: [Exporting As Many of Your Twitter Bookmarks As Possible](https://ryanfb.github.io/etc/2022/11/21/exporting_as_many_of_your_twitter_bookmarks_as_possible.html)

Export as many of your Twitter Bookmarks as possible to JSON. This will also delete all your Twitter Bookmarks, 50 Bookmarks at a time, to get around API limits. The Bookmarks fetch API is unreliable, so this program runs until manually interrupted. You'll need a Twitter Developer account with an OAuth 2.0 Client ID and Client Secret, as described [here](https://github.com/jarulsamy/Twitter-Archive/blob/master/docs/twitter_dev_setup.md) (set the callback URI to `http://localhost:8080`). Export these as `CLIENT_ID` and `CLIENT_SECRET` before running, e.g.:

    CLIENT_ID='asdfasdf' CLIENT_SECRET='fdsafda-asdfasdf' bundle exec ./bookmarks_export.rb

Based on [this Twitter API sample code](https://github.com/twitterdev/Twitter-API-v2-sample-code/blob/main/Bookmarks-lookup/bookmarks_lookup.rb).
