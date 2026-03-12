library(tidyverse)
library(tidytext)
library(syuzhet)
library(textdata)

# we created a dataset of winter olympic games related posts in the 
# previous step. Load the file if necessary.
posts <- read_csv("data/posts.csv") 

# or if - like me - you are easily entertained by punny names...
posts <- vroom::vroom("data/posts.csv")

# let's take only the columns we'll need
post_texts <- posts |> select(uri, day = since, timestamp = indexed_at, text)

# at it's core, basic sentiment analysis is nothing more than counting
# the number of words associated with a given sentiment. The steps are 
# simple: 
#  - split each post into individual words (tokenize)
#  - match each word to a pre-defined sentiment dictionary (lexicon)
#  - calculate sentiment per post
#  - calculate sentiment per day

# split sentences into word-sized tokens (see the tidytext documentation
# for many other options)
tokens <- tidytext::unnest_tokens(post_texts, word, text)
tokens

# get a sentiment 'lexicon'  
sentiment <- tidytext::get_sentiments("afinn")
sentiment

# match words with sentiments
token_sentiment <- left_join(tokens, sentiment, by = join_by(word))

# note that most words won't be in the dictionary...
token_sentiment |> select(word, value) |> print(n = 20)
token_sentiment |> select(word, value) |> filter(value > 0)
token_sentiment |> select(word, value) |> filter(value < 0)

# most positive tokens
token_sentiment |> count(word, value) |> arrange(desc(value), desc(n))

# warning: not safe for work! 
# most negative tokens
# token_sentiment |> count(word, value) |> arrange(value, desc(n))

# summarize emotion per post, filling in 0 for 'missing' words
post_sentiment <- token_sentiment |> 
  mutate(value = replace_na(value, 0)) |>
  summarize(sentiment = mean(value), .by = uri)
post_sentiment

# combine back with the post texts
post_texts_sentiments <- left_join(post_texts, post_sentiment, by = join_by(uri))
post_texts_sentiments |> arrange(desc(sentiment))
post_texts_sentiments |> arrange(sentiment)
# note: we've made some choices here that might affect our results. 
# Would stemming tokens and removing stopwords matter?
# What would have happened if we removed words that aren't in the lexicon? 
# What would have happened if we summed instead of averaged sentiment?
# How could you add sentiment for emoijis?

# summarize emotion per day
post_sentiments_per_day <- post_texts_sentiments |> 
  summarize(sentiment = mean(sentiment, na.rm = TRUE), .by = day)

# are we seeing noise or patterns? What happened on feb 12th?
post_sentiments_per_day |> 
  ggplot(aes(x = day, y = sentiment)) + 
  geom_line()

# there are a number of other lexicons easily available, with different 
# sentiment categories 
tidytext::get_sentiments("nrc") |> count(sentiment)
tidytext::get_sentiments("bing") |> count(sentiment)
tidytext::get_sentiments("loughran") |> count(sentiment)

# or in other packages...
syuzhet::get_sentiment_dictionary("syuzhet")

# nrc is also available for other languages...
syuzhet::get_sentiment_dictionary("nrc", "dutch") |> head()



# let's have a quick look with the NRC lexicon for a broader range 
# of emotions. The basic process is the same....
sentiment_nrc <- tidytext::get_sentiments("nrc")

# match tokens with sentiments
token_sentiments <- left_join(tokens, sentiment_nrc, by = join_by(word))

# we get a warning about many-to-many relationships. This is because
# 1) words can be repeated in several posts, and 2) each word can be 
# associated with mutliple sentiments. 
# We do have a minor problem, as we can't simply calculate average 
# sentiment values anymore - we'll have to count the number of times 
# each sentiment is associated with a post. 
post_sentiments <- token_sentiments |> 
  filter(!is.na(sentiment)) |> 
  count(uri, sentiment)
post_sentiments

# we probably want to 'normalize' these value for post length, e.g. 
# the number of tokens. 
tokens_per_post <- tokens |> 
  count(uri, name = "n_tokens") |> 
  complete(uri = posts$uri, fill = list(n_tokens = 0))
post_sentiments_norm <- post_sentiments |> 
  # we'll want to 'complete' the data to fill in rows for 'null sentiments'
  complete(uri = posts$uri, sentiment, fill = list(n = 0, n_norm = 0)) |>
  
  # join in number of tokens per post 
  left_join(tokens_per_post, by = join_by(uri)) |> 
  
  # join in post text and metadata
  left_join(posts, by = join_by(uri)) |>
  mutate(n_norm = n / (n_tokens+1)) # n_t+1 to avoid division by zero

# most emotive posts per emotion
post_sentiments_norm |> 
  slice_max(desc(n_norm), n = 5, by = sentiment) |> 
  arrange(sentiment, desc(n_norm)) |>
  select(sentiment, n_norm, text, author_name) |>
  print(n=100)
  
# average emotion over time
post_sentiments_norm |> 
  
  # summarize per day
  summarize(avg = mean(n_norm), .by = c(since, sentiment))  |> 
  ggplot(aes(x = since, y = avg, colour = sentiment)) + 
  geom_line()


