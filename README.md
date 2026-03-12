# Practical Social Data Science

## Overview

This repository contains example code and slides for a workshop on practical social media use in research from a data science perspective, presented at the one-day networking conference “From Posts to Insights: Navigating Social Media Data Challenges in Research”, funded by Open Science NL at the University of Twente.

Example code is provided for both **R** and **Python**, with parallel implementations of key data science workflows. Participants will learn the basics of using an API to acquire data, perform sentiment analysis and identify trends.

## Project Structure

### `/examples`
Contains practical examples demonstrating key workflows:

- **1_getting_data**: Retrieve and prepare social media data
  - `1_getting_data.R` - R implementation
  - `1_getting_data.py` - Python implementation
  
- **2_sentiment_analysis**: Analyze sentiment in text data
  - `2_sentiment_analysis.R` - R implementation
  - `2_sentiment_analysis.py` - Python implementation

- **99_extras_hot_topics**: Bonus analysis for identifying trending topics
  - `99_extras_hot_topics.R` - R implementation

- **data/**: Sample datasets downloaded in the _getting data_ scripts.
  - `posts.csv` / `posts.json` - Post data in different formats
  - `posts.rds` - R-native serialized data
  - `posts-python.csv` / `posts-python.json` - Python-specific samples

### `/slides`
Source code and html version of slides accompanying the workshop.

- `presentation.qmd` - Quarto presentation source
- `presentation.html` - Rendered presentation
- `assets/` - Supporting images and resources

## Setup Instructions

### R Setup

#### Prerequisites
- R 4.5.1 or higher
- RStudio or Positron IDE

#### Installation

This project uses **renv** for reproducible package management. To set up the R environment:

```r
# Install renv if not already installed
install.packages("renv")

# Restore packages from the lockfile
renv::restore()
```

#### Key R Packages
- `tidyverse` - Data manipulation and visualization
- `dplyr` - Data wrangling
- `ggplot2` - Grammar of graphics visualization
- `tidytext` - Text analysis
- `stringr` - String manipulation
- `topicmodels` - Topic modeling (if needed)

### Python Setup

#### Prerequisites
- A recent version of Python (I've used 3.13)

#### Installation

This project uses a `pyproject.toml` configuration for Python dependencies. To set up the Python environment:

```bash
# Using pip
pip install -e .

# Or using uv (if available)
uv pip install -e .
```

#### Key Python Packages
- `pandas` - Data manipulation
- `nltk` - Natural Language Toolkit
- `afinn` - Sentiment analysis (AFINN lexicon)
- `atproto` - Bluesky API client
- `matplotlib` - Data visualization
- `python-dotenv` - Environment variable management


### Environment Variables

Create a `.env` file in the project root with any necessary API credentials:

```
BLUESKY_APP_PASS=your-app-password
BLUESKY_APP_USER=your-handle.bsky.social
```

## License

See LICENSE file for details.