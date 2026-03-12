library(wordcloud2)
library(tidyverse)
library(tidytext)
library(topicmodels)

# wordclouds can be a simple but sometimes effective approach
# let's make one for each day...
wordclouds <- tokens |> 
  count(day, word, name = "freq") |> 
  anti_join(tidytext::get_stopwords()) |> 
  nest_by(day) |> 
  purrr::pmap(\(day, data) {
    data |> 
      arrange(-freq) |> 
      wordcloud2::wordcloud2()
  })
wordclouds

# predictably, a handful of common words including our search 
# term dominate the most common words on each day. We can use
# TF-IDF to highlight words specific to a given day.
tokens_tf_idf <- tokens |> 
  count(day, word, name = "freq") |> 
  tidytext::bind_tf_idf(word, day, freq)

# the most common words (high tf), occur every day, and have 
# 0 idf. In general, words that occur on most days will have
# low idf, whereas words that occur only on a single day will
# have higher idf. 
tokens_tf_idf |> 
  arrange(desc(tf)) |> 
  head(10)

# many tokens that occur only on one day also occur with low 
# frequency. 
tokens_tf_idf |> 
  arrange(desc(idf))

# What we're mostly interested in are tokens with 
# high frequency, on one or few days. 
tokens_tf_idf |> 
  arrange(desc(tf_idf))

# promising. Let's hook that into the wordcloud.
wordclouds <- tokens_tf_idf |> 
  anti_join(tidytext::get_stopwords()) |> 
  nest_by(day) |> 
  purrr::pmap(\(day, data) {
    data |> 
      filter(tf_idf > 0) |>
      mutate(freq = tf_idf / min(tf_idf)) |>
      arrange(desc(freq)) |>
      wordcloud2::wordcloud2()
  })

# 
wordclouds[[4]]


# a more thorough approach would be topic modelling, e.g.
# latent Dirichlet allocation. The package topicmodels 
# implements this, but requires a document-term-matrix.
dtm <- tokens |> 
  filter(n() > 10, .by = word) |>
  count(uri, word) |> 
  anti_join(tidytext::get_stopwords()) |>

  # let's also remove anyting with 'olympic', 'games', or 'winter'
  filter(str_detect(word, "olympic|winter|games", negate = TRUE)) |> 
  tidytext::cast_dtm(document = uri, term = word, value = n)

# let's try identifying four distinct topics, but we'll 
# reduce the sparsity (uncommon terms) a bit first.
lda <- topicmodels::LDA(dtm, 2)

# and 'tidy' the result into a simple table
topics <- tidytext::tidy(lda, matrix = "beta")

# let's have a look at our topics...
top_terms <- topics |>
  slice_max(beta, n = 10, by = topic) |> 
  arrange(topic, desc(beta)) |>
  print(n = 40)

# not the most insightful of topics, I'm afraid.
top_terms |> 
  mutate(term = reorder_within(term, beta, topic)) |> 
  ggplot(aes(x = beta, y = term, fill = factor(topic))) + 
  geom_col() + 
  facet_wrap(vars(topic), scales = "free") + 
  scale_y_reordered()
