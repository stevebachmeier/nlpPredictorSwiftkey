# ==============================================================================
# ANALYSIS
# ==============================================================================
library(data.table)
library(stringr)

# ---- LOAD FILES ----
# all_1grams_nostopwords <- data.table(read.csv(file="data/all_1grams_noStopwords.txt",
#                                               header=T, sep=",", stringsAsFactors=F))
all_1grams <- data.table(read.csv(file="data/all_1grams.txt", 
                                  header=T, sep=",", stringsAsFactors=F))
all_2grams <- data.table(read.csv(file="data/all_2grams.txt", 
                                  header=T, sep=",", stringsAsFactors=F))
all_3grams <- data.table(read.csv(file="data/all_3grams.txt", 
                                  header=T, sep=",", stringsAsFactors=F))
all_4grams <- data.table(read.csv(file="data/all_4grams.txt", 
                                  header=T, sep=",", stringsAsFactors=F))

# ---- STUPID BACKOFF ----
nlpPredictor <- function(input) {
  # input="Hey! How long will this" # profiling
  # input="what time is" # merging bug
  # input="Don't do that! This way we" # check for sub-grepping
  # input="What the hell do you want to do at the end of "
  # input="I like how the same people are in almost all of Adam Sandler's"
  # input="i do not"
  alpha <- 0.4 # Stupid backoff factor
  
  ngrams_matched <- data.table(
    ngram=character(), pred=character(), freq=numeric(), S=numeric())
  ngrams_matched_bo1 <- data.table(
    ngram=character(), pred=character(), freq=numeric(), S=numeric())
  ngrams_matched_bo2 <- data.table(
    ngram=character(), pred=character(), freq=numeric(), S=numeric())
  ngrams_matched_bo3 <- data.table(
    ngram=character(), pred=character(), freq=numeric(), S=numeric())
  
  preds <- data.table(pred=all_1grams$ngram, S=0)
  preds_bo1 <- data.table(pred=all_1grams$ngram, S=0)
  preds_bo2 <- data.table(pred=all_1grams$ngram, S=0)
  preds_bo3 <- data.table(pred=all_1grams$ngram, S=0)
  
  # Initial search
  source("f_cleanWords.R")
  input_tokens <- cleanWords(input) %>% strsplit(" ")
  search_tokens <- tail(input_tokens[[1]], 3)
  search_string <- paste0("*", paste(search_tokens, collapse="_"), "_")
  n <- length(search_tokens)
  
  if (n == 3) {
    ngrams_matched <- all_4grams[grep(search_string, all_4grams$ngram, fixed=T),]
  } else if (n == 2) {
    ngrams_matched <- all_3grams[grep(search_string, all_3grams$ngram, fixed=T),]
  } else if (n == 1) {
    ngrams_matched <- all_2grams[grep(search_string, all_2grams$ngram, fixed=T),]
  } else {
    ngrams_matched <- all_1grams
  }
  
  ngrams_matched$pred <- str_remove(ngrams_matched$ngram, 
                                    pattern=paste0("\\", search_string))
  ngrams_matched$S <- alpha^0 * ngrams_matched$freq / sum(ngrams_matched$freq)
  preds <- merge(x=preds, y=ngrams_matched[,3:4], by="pred", all.x=T, sort=F)
  preds[, S.x:=NULL]
  colnames(preds)[2] <- c("S")
  preds$S[is.na(preds$S)] <- 0
  
  # Stupid backoff #1
  search_tokens_bo1 <- search_tokens[-1]
  search_string_bo1 <- paste0("*", paste(search_tokens_bo1, collapse="_"), "_")
  n_bo1 <- length(search_tokens_bo1)
  
  if ((n_bo1 != n) & (n_bo1 == 2)) {
    ngrams_matched_bo1 <- all_3grams[grep(search_string_bo1, all_3grams$ngram, fixed=T),]
  } else if ((n_bo1 != n) & (n_bo1 == 1)) {
    ngrams_matched_bo1 <- all_2grams[grep(search_string_bo1, all_2grams$ngram, fixed=T),]
  } else if (n_bo1 != n) {
    ngrams_matched_bo1 <- all_1grams
  }
  
  ngrams_matched_bo1$pred <- str_remove(ngrams_matched_bo1$ngram,
                                        pattern=paste0("\\", search_string_bo1))
  ngrams_matched_bo1$S <- alpha^1 * (ngrams_matched_bo1$freq / sum(ngrams_matched_bo1$freq))
  if (nrow(ngrams_matched_bo1) != 0) {
    preds_bo1 <- merge(x=preds_bo1, y=ngrams_matched_bo1[,3:4], by="pred", all.x=T, sort=F)
    preds_bo1[, S.x:=NULL]
    colnames(preds_bo1)[2] <- c("S")
    preds_bo1$S[is.na(preds_bo1$S)] <- 0
  }
  
  # Stupid backoff #2
  search_tokens_bo2 <- search_tokens_bo1[-1]
  search_string_bo2 <- paste0("*", paste(search_tokens_bo2, collapse="_"), "_")
  n_bo2 <- length(search_tokens_bo2)
  
  if ((n_bo2 != n_bo1) & (n_bo2 == 1)) {
    ngrams_matched_bo2 <- all_2grams[grep(search_string_bo2, all_2grams$ngram, fixed=T),]
  } else if (n_bo2 != n_bo1) {
    ngrams_matched_bo2 <- all_1grams
  }
  
  ngrams_matched_bo2$pred <- str_remove(ngrams_matched_bo2$ngram,
                                        pattern=paste0("\\", search_string_bo2))
  ngrams_matched_bo2$S <- alpha^2 * (ngrams_matched_bo2$freq / sum(ngrams_matched_bo2$freq))
  if (nrow(ngrams_matched_bo2) != 0) {
    preds_bo2 <- merge(x=preds_bo2, y=ngrams_matched_bo2[,3:4], by="pred", all.x=T, sort=F)
    preds_bo2[, S.x:=NULL]
    colnames(preds_bo2)[2] <- c("S")
    preds_bo2$S[is.na(preds_bo2$S)] <- 0
  }
  
  # Stupid backoff #3
  if (n_bo2 == 1) {
    ngrams_matched_bo3 <- all_1grams
  }
  
  ngrams_matched_bo3$pred <- ngrams_matched_bo3$ngram
  ngrams_matched_bo3$S <- alpha^3 * (ngrams_matched_bo3$freq / sum(ngrams_matched_bo3$freq))
  
  if (nrow(ngrams_matched_bo3) != 0) {
    preds_bo3 <- merge(x=preds_bo3, y=ngrams_matched_bo3[,3:4], by="pred", all.x=T, sort=F)
    preds_bo3[, S.x:=NULL]
    colnames(preds_bo3)[2] <- c("S")
    preds_bo3$S[is.na(preds_bo3$S)] <- 0
  }
  
  # Combine predictions
  predictions <- data.table(word=preds$pred, S_0=preds$S, S_bo1=preds_bo1$S, 
                            S_bo2=preds_bo2$S, S_bo3=preds_bo3$S, 
                            S=(preds$S + preds_bo1$S + preds_bo2$S + preds_bo3$S))
  predictions <- predictions[order(-S)]
  
  c(predictions[1:3,1])$word # For benchmark.R
  
  # cat(paste(input, ":", "\n",
  #           "  [1] ", predictions[1]$word, "(S=",round(predictions[1]$S, 2),")", "\n",
  #           "  [2] ", predictions[2]$word, "(S=",round(predictions[2]$S, 2),")", "\n",
  #           "  [3] ", predictions[3]$word, "(S=",round(predictions[3]$S, 2),")"))
  
  # predictions
}
