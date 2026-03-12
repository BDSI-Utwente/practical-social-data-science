library(tidyverse)
library(atrrr)
library(dotenv)


# You'll need to authenticate with BlueSky. I'll do this manually and explicitly 
# provide the credentials to the atrrr package, but there the package will prompt 
# you to do this interactively if you use a function that requires authentication 
# without having authenticated first. 
# 
# 0. Create a BlueSky account and an App password.
#    - bsky.app, create account
#    - settings -> privacy and security -> app passwords
# 
# !!! This is a password that gives anyone who has it full access you your account!
#     Don't loose it, don't put the password in your code file - treat it like any
#     other sensitive password. 
# 
# 1. Provide authentication to the atrrr package.
#   
# I put my credentials in a `.env` file next to the code, and made sure this file 
# is not included in version control by adding a `.gitignore` file. We can then 
# use the dotenv package to load them into the environment for this session.
dotenv::load_dot_env()

# create an auth token to use in the rest of our atrrr interactions.
atrrr::auth(Sys.getenv("BLUESKY_APP_USER"), Sys.getenv("BLUESKY_APP_PASS"))

# we can now query the BlueSky API, using a variety of functions. We could create
# posts, comments, like posts, follow or ban accounts and more from within R, but 
# we're mostly interested in seeing what other people post. 

# for example, the 'top' posts on opening day of the winter olympic(s)
posts <- atrrr::search_post("olympic", sort="top", since="2026-02-06", until="2026-02-07")
posts |> select(author_handle, author_name, text)

# or posts about Lindsey Vonn's ill-fated ski run
posts <- atrrr::search_post('"Lindsey Vonn"', sort="top", since="2026-02-06", until="2026-02-12")
posts |> select(author_handle, author_name, text)

# let's have a look at sentiment during the olympics. We can use the same search terms, 
# but now we want to track how sentiment changes over time.

# The most basic approach would be to simply get posts during the duration of the olympics, 
# and then group them by day. 
posts <- atrrr::search_post("olympic", sort="top", since="2026-02-06", until="2026-02-22")
posts |> 
  mutate(day = lubridate::date(indexed_at)) |> 
  count(day)

# we could grab many more posts, but we still wouldn't know if we have enough posts for each
# day. If we have 100 posts on the first day, but only 10 on the second, then our sentiment 
# analysis will be much more reliable for the first day than for the second. We could try 
# to get all posts for the entire period, but we'll quickly run out of time and memory, even
# for a relatively short period like this, and for the relatively lower volume of posts on BlueSky.

# if we want to track sentiment over time, we probably want to get more posts, and we may 
# want to make sure we have enough posts for each day. We can do this by running the search
# function separately for each day, and then combining the results. 
posts_day_1 <- atrrr::search_post("olympic", sort="top", since="2026-02-06", until="2026-02-07", limit=500)
# ....
posts_day_4 <- atrrr::search_post("olympic", sort="top", since="2026-02-09", until="2026-02-10", limit=500)
# and so forth, for each day of the olympics.

# this will quickly become verbose and error-prone, so let's automate our approach. We start
# by making a list of dates we want to query. 
dates <- tibble(since = seq(date("2026-02-06"), date("2026-02-22")), until = since + days(1))
dates

# and run the search function for each row. We could 'manually' run a loop, but a more 
# convenient approach is to use a 'mapping' function from package `purrr`. 
# the `pmap` function takes each row, and uses the column names to match values to the 
# arguments of the `atrrr::search_post` function. Any extra parameters that we supply 
# are applied as 'static' arguments for all rows.

# I'm setting the limit to 100 to not create too much traffic and get quick feedback
# while testing, for a final run we probably want to grab more posts.
result_list <- purrr::pmap(dates, atrrr::search_post, sort="top", q="olympic", limit=1000)

# There's one practical problem with this approach: either the atrrr package or the 
# BlueSky API occasionally creates an error, which causes our entire batch to fail - 
# even if we already succesfully downloaded several days of posts. We can create a 
# little helper function to 'cache' intermediate results. 
.search_posts_cached <- function(q, since, until, sort, limit) {
  # we'll take the most basic approach of storing cached results to disk, with a 
  # filename based on the search parameters. 
  cache_file <- glue::glue(".cached_{q}_{since}_{until}_{sort}_{limit}.rds")

  # we then check if that file exists. If so, load and return the file contents
  if (file.exists(cache_file)){
    data <- read_rds(cache_file)
    return(data)
  }

  # if not, we'll fetch the data and save it before returning
  data <- atrrr::search_post(q, since=since, until=until, sort=sort, limit=limit)
  write_rds(data, cache_file)
  
  # finally, return the data
  data
}

# we can then use this wrapper function in our mapping
result_list <- purrr::pmap(dates, .search_posts_cached, sort="top", q="olympic", limit=1000)

# this caching approach also has the additional benefit that if we run the exact same 
# query again, we get the cached results back almost instantly. 

# note that this is a 'ridiculously parallel' task, and we could easily gather multiple
# batches simultaneously. The `furrr` package provides a set of functions analogous to 
# those in purrr that makes this easy to do. That said, we should be careful not to 
# overload the API with too many requests at the same time, both because of the risk of
# getting blocked, and because we are good netizens who appreciate that the BlueSky API
# is still easily accessible and free.

# either way, we end up with a list of results, with one element for each query. 
result_list

# we can combine these back with the queries
results <- dates |> mutate(results = result_list)

# and unnest the results into a single 'long' dataset for further analysis
posts <- results |> unnest(results)
posts
posts |> select(author_name, text)

# rough first look, how much data do we have per day? 
posts |> 
  count(since) |>
  ggplot(aes(x = since, y = n)) +
  geom_line()

# at what time of day are these posts made?
posts |>
  mutate(hour_of_day = lubridate::hour(indexed_at)) |> 
  count(hour_of_day) |> 
  ggplot(aes(x = hour_of_day, y = n)) + 
  geom_smooth()

# There are ~200 posts for some days, and 100 for others. The `atrrr` package fetches posts
# in batches, until it reaches the limit. Batches are usually 100 posts, but not always 
# which explains why we have 100 posts for some days, and 199 for others. We may want to cull
# the extra posts to make sure we have similar samples for each day:
posts <- posts |> 
  slice_head(n = 100, by = since) # make sure to change 100 to whatever limit you used!

# Finally, let's store the results we've obtained so far. The simplest and most 
# portable format is usually a plain csv file (just stay away from MS Excel). 
write_csv(posts, "posts.csv")

# You may have noticed that some of the results were still nested. For example, 
# there was more data for authors, posts, embeds, tags, mentions, etc.. When we 
# saved a complex data structure as a 'flat' csv, that data was lost. 
# 
# If we were interested in this data (we're not in this case), we could have used 
# a binary format to fully represent the data 'object' as R sees it, but which may be 
# harder to read in a future where R is no longer maintained.
write_rds(posts, file = "posts.rds")

# Or use a format that can handle nested data structures, but still cannot fully
# represent all details of the data, and may be harder to use in other software.
jsonlite::write_json(posts, "posts.json")
