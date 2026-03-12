import pandas as pd
import nltk
import nltk.sentiment
import matplotlib.pyplot as plt

# we created a dataset of winter olympic games related posts in the
# previous step. Load the file if necessary.
posts = pd.read_csv("posts-python.csv")

# Select relevant columns
posts = posts[["uri", "since", "text"]].copy()
posts.rename(columns={"since": "day"}, inplace=True)

# at it's core, basic sentiment analysis is nothing more than counting
# the number of words associated with a given sentiment. The steps are
# simple:
#  - split each post into individual words (tokenize)
#  - match each word to a pre-defined sentiment dictionary (lexicon)
#  - calculate sentiment per post
#  - calculate sentiment per day

# we'll need to download some nltk resources for tokenization, stopwords,
# and lexicons before we can use them.
nltk.download("punkt")
nltk.download("punkt_tab")
nltk.download("stopwords")
nltk.download("vader_lexicon")

# split each post into individual words (tokens). For simplicity, we'll
# use some simple for loops
tokens = []
for index, post in posts.iterrows():
    for token in nltk.tokenize.word_tokenize(str(post.text)):
        tokens.append({"uri": post.uri, "word": token})

# cast to a data frame
tokens = pd.DataFrame(tokens)
        
# initialize vader sentiment analysis, and grab the built-in lexicon
vader = nltk.sentiment.SentimentIntensityAnalyzer()
vader.lexicon

# map words to sentiment value
tokens["sentiment"] = tokens["word"].map(vader.lexicon).fillna(0)

# most emotive tokens
tokens[["word", "sentiment"]].drop_duplicates().sort_values("sentiment").tail()

# warning: not safe for work!
# tokens[["word", "sentiment"]].drop_duplicates().sort_values("sentiment").head()

# calculate average sentiment per post by averaging word sentiment
post_sentiment = tokens.groupby("uri")["sentiment"].mean()

# and join the sentiment score back to the posts
posts = posts.merge(post_sentiment.rename("sentiment"), on="uri", how="left")

# most emotive posts
posts.sort_values("sentiment").tail()
posts.sort_values("sentiment").head()

# average sentiment per day
daily_sentiment = posts.groupby("day")["sentiment"].mean().reset_index()
daily_sentiment.columns = ["day", "avg_sentiment"]
daily_sentiment["day"] = pd.to_datetime(daily_sentiment["day"])
daily_sentiment = daily_sentiment.sort_values("day")
daily_sentiment

# are we seeing noise or patterns? What happened on feb 12th?
plt.figure(figsize=(12, 6))
plt.plot(
    daily_sentiment["day"], daily_sentiment["avg_sentiment"], marker="o", linewidth=2
)
plt.xlabel("Date")
plt.ylabel("Average Sentiment")
plt.title("Average Sentiment per Day - Winter Olympics 2026")
plt.grid(True, alpha=0.3)
plt.show()

# the vader sentiment analyzer is actually a bit more advanced
# than just matching words, let's use it as intended.
sentences = []

for index, post in posts.iterrows():
    for sentence in nltk.tokenize.sent_tokenize(str(post.text)):
        sentences.append({"uri": post.uri, "sentence": sentence})

# cast to df
sentences = pd.DataFrame(sentences)


# most emotive sentences
sentences["sentiment"] = [vader.polarity_scores(str(sentence))["compound"] for sentence in sentences.sentence]
sentences.sort_values("sentiment").tail()
sentences.sort_values("sentiment").head()

# get post sentiment by averaging sentences
post_sentiment = sentences.groupby("uri")["sentiment"].mean()
posts = posts.merge(post_sentiment.rename("sentiment_vader"), on="uri", how="left")

# comparing vader to 'bag of words' scores, there some striking differences
posts.sort_values("sentiment_vader").tail()
posts.sort_values("sentiment_vader").head()

# does it affect the overall patterns? 
daily_sentiment_vader = posts.groupby("day")["sentiment_vader"].mean().reset_index()
daily_sentiment_vader.columns = ["day", "avg_sentiment"]
daily_sentiment_vader["day"] = pd.to_datetime(daily_sentiment_vader["day"])
daily_sentiment_vader = daily_sentiment_vader.sort_values("day")

# overall patterns don't seem all that affected
plt.figure(figsize=(12, 6))
plt.plot(
    daily_sentiment["day"],
    daily_sentiment["avg_sentiment"],
    marker="o",
    linewidth=2,
    label="Naive (Bag of Words)",
)
plt.plot(
    daily_sentiment_vader["day"],
    daily_sentiment_vader["avg_sentiment"],
    marker="s",
    linewidth=2,
    label="VADER",
)
plt.xlabel("Date")
plt.ylabel("Average Sentiment")
plt.title("Sentiment Comparison: Naive vs VADER - Winter Olympics 2026")
plt.legend()
plt.grid(True, alpha=0.3)
plt.show()
