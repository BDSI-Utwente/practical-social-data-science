import os
import pandas as pd

from atproto import Client
from dotenv import load_dotenv
from datetime import datetime, timedelta


# You'll need to authenticate with BlueSky. In the Python SDK, you'll have to do this
# manually.
# 
# 0. Create a BlueSky account and an App password.
#    - bsky.app, create account
#    - settings -> privacy and security -> app passwords
# 
# !!! This is a password that gives anyone who has it full access you your account!
#     Don't loose it, don't put the password in your code file - treat it like any
#     other sensitive password. 
# 
# 1. Provide authentication to the atproto client.
#   
# I put my credentials in a `.env` file next to the code, and made sure this file 
# is not included in version control by adding a `.gitignore` file. We can then 
# use the dotenv package to load them into the environment for this session.
load_dotenv()

# Initialize BlueSky client and authenticate
client = Client()
client.login(
    os.getenv("BLUESKY_APP_USER"),
    os.getenv("BLUESKY_APP_PASS")
)


# we can now query the BlueSky API, using a variety of functions. We could create
# posts, comments, like posts, follow or ban accounts and more from within Python,
# but we're mostly interested in seeing what other people post. 

# for example, the 'top' posts on opening day of the winter olympic(s)
posts_opening = client.app.bsky.feed.search_posts({
    "q": "olympic",
    "sort": "hot",
    "since": datetime(2026, 2, 6).isoformat() + "+02:00",
    "until": datetime(2026, 2, 7).isoformat() + "+02:00"
})

# Convert to DataFrame and display
df_opening = pd.DataFrame([
    {
        "author_handle": post.author.handle,
        "author_name": post.author.display_name,
        "text": post.record.text
    }
    for post in posts_opening.posts
])
print(df_opening.head())

# or posts about Lindsey Vonn's ill-fated ski run
posts_vonn = client.app.bsky.feed.search_posts({
    "q": '"Lindsey Vonn"',
    "sort": "hot",
    "since": datetime(2026, 2, 6).isoformat() + "+02:00",
    "until": datetime(2026, 2, 12).isoformat() + "+02:00"
})

df_vonn = pd.DataFrame([
    {
        "author_handle": post.author.handle,
        "author_name": post.author.display_name,
        "text": post.record.text
    }
    for post in posts_vonn.posts
])
print(df_vonn.head())


# let's have a look at sentiment during the olympics. We can use the same search terms, 
# but now we want to track how sentiment changes over time.

# The most basic approach would be to simply get posts during the duration of the olympics, 
# and then group them by day. 
print("\nFetching posts for full Olympics period (Feb 6-22)...")
posts_full = client.app.bsky.feed.search_posts(
    { "q": "olympic",
      "sort": "hot",
      "since": datetime(2026, 2, 6).isoformat() + "+02:00",
      "until": datetime(2026, 2, 22).isoformat() + "+02:00",
      "limit": 100
    })
df_full = pd.DataFrame([
    {
        "timestamp": post.indexed_at,
        "date": pd.to_datetime(post.indexed_at).date()
    }
    for post in posts_full.posts
])
print(df_full['date'].value_counts().sort_index())


# note that we can only get a maximum of 100 posts with this approach, if we want more posts
# we'll need to handle pagination ourselves. Let's write a simple function to do that for us.
def fetch_posts_paginated(q, since, until, limit=1000): 
    all_posts = []
    cursor = None
    
    # we'll also handle the date formatting here, to make it easier to call 
    # this function with datetime objects
    while len(all_posts) < limit:
        response = client.app.bsky.feed.search_posts({
            "q": q,
            "sort": "hot",
            "since": since.isoformat() + "+02:00",
            "until": until.isoformat() + "+02:00",
            "cursor": cursor,
            "limit": min(100, limit - len(all_posts))  # fetch in batches of up to 100
        })
        
        all_posts.extend(response.posts)
        print("Fetched {} posts (total: {})".format(len(response.posts), len(all_posts)))
        
        if not response.cursor:
            break  # no more pages
        
        cursor = response.cursor

    # while we're at it, we might as well convert the posts to a pandas df
    df = pd.DataFrame([
        {
            "uri": post.uri,
            "indexed_at": post.indexed_at,
            "author_handle": post.author.handle,
            "author_name": post.author.display_name,
            "text": post.record.text,
        }
        for post in all_posts
    ])
    
    return df


# we should now be able to fetch larger batches of posts
posts_full_paginated = fetch_posts_paginated(
    q="olympic",
    since=datetime(2026, 2, 6),
    until=datetime(2026, 2, 22),
    limit=1000
)
posts_full_paginated['date'] = pd.to_datetime(posts_full_paginated['indexed_at']).dt.date
print(posts_full_paginated['date'].value_counts().sort_index())

# we could grab many more posts, but we still wouldn't know if we have enough posts for each
# day. If we have 100 posts on the first day, but only 10 on the second, then our sentiment 
# analysis will be much more reliable for the first day than for the second. We could try 
# to get all posts for the entire period, but we'll quickly run out of time and memory, even
# for a relatively short period like this, and for the relatively lower volume of posts on BlueSky.

# if we want to track sentiment over time, we probably want to get more posts, and we may 
# want to make sure we have enough posts for each day. We can do this by running the search
# function separately for each day, and then combining the results. 
posts_day_1 = fetch_posts_paginated("olympic", datetime(2026, 2, 6), datetime(2026, 2, 7), 500)
# ...
posts_day_17 = fetch_posts_paginated("olympic", datetime(2026, 2, 22), datetime(2026, 2, 23), 500)

# this will quickly become verbose and error-prone, so let's automate our approach. We start
# by making a creating a date range for the Olympics period
dates = pd.date_range(start="2026-02-06", end="2026-02-22", freq='D')

# and then simply loop through the dates, fetching posts for each day and storing them in a dictionary.
# (note that this deviates from the R version, where we used a mapping approach. That is also possible 
# in Python, but a simple loop is more straightforward here.) 
# I'm setting the limit relatively low to not create too much traffic and get quick feedback while 
# testing, for a final run we probably want to grab more posts.

posts_by_date = {}
for date in dates: 
    print(f"\nFetching posts for {date.date()}...")
    posts_by_date[date] = fetch_posts_paginated("olympic", date, date + timedelta(days=1), limit=500)

# note that this is a 'ridiculously parallel' task, and we could easily gather multiple
# batches simultaneously. The `furrr` package provides a set of functions analogous to 
# those in purrr that makes this easy to do. That said, we should be careful not to 
# overload the API with too many requests at the same time, both because of the risk of
# getting blocked, and because we are good netizens who appreciate that the BlueSky API
# is still easily accessible and free.

# either way, we end up with a dictionary of results, with one element for each query. 
posts_by_date

# we can combine these into a single df for easier analysis, keeping the since date as a 
# column to track when each post was made.
all_posts_by_date = pd.concat(posts_by_date.values(), ignore_index=True)
all_posts_by_date['since'] = pd.to_datetime(all_posts_by_date['indexed_at']).dt.tz_convert('UTC+02:00').dt.date

# Visualize post distribution across days
print("\nPosts per day:")
print(all_posts_by_date['since'].value_counts().sort_index())

# Visualize posting patterns by hour of day
all_posts_by_date['hour_of_day'] = pd.to_datetime(all_posts_by_date['indexed_at']).dt.hour
print("\nPosts by hour of day:")
print(all_posts_by_date['hour_of_day'].value_counts().sort_index())

# Finally, let's store the results we've obtained so far. The simplest and most 
# portable format is usually a plain csv file (just stay away from MS Excel). 
all_posts_by_date.to_csv("data/posts-python.csv", index=False)

# You may have noticed we've only selected a few fields from the post objects to 
# include in our dataframe. The original posts contain more data for authors, replies,
# embeds, tags, mentions, etc., as nested data structures. These are hard to store 
# in a flat csv format.
# 
# If we were interested in this data (we're not in this case), we could have used 
# a binary format to fully represent the data 'object' as Python sees it, but which may
# be harder to read in a future where Python is no longer maintained, or transport 
# to other software.
# Pickle format (preserves Python objects)
all_posts_by_date.to_pickle("data/posts-python.pkl")

# Or we could use a more portable format that can represent nested data and is easy 
# to read and write in many programming languages, but is harder to use than a flat
# data format. 
all_posts_by_date.to_json("data/posts-python.json", orient="records", indent=2)
