
setwd("D:/Dropbox/PhD/twitter_iud/")
setwd("~/Dropbox/PhD/twitter_iud/")

p = c("magrittr", "purrr", "dplyr", "ggplot2", "tidyr", "readr")
lapply(p, require, character.only = TRUE)


#############
# iud vs time
#############

iud_list = list.files("data_all/iud_v_time", full.names = T) %>% lapply(function(x) x %>% read.table())
names(iud_list) = list.files("data_all/iud_v_time", full.names = F)
iud_df = lapply(1:7, function(x) iud_list[[x]] %>% mutate(y_m = as.Date(V1, format = "%Y-%b-%d"), iud = names(iud_list)[x] )) %>%
  rbind_all %>% select(-V1)

library(wesanderson)

## Using the histogram aggregation style approach
p = iud_df %>% 
  mutate(iud = gsub("_list.*", "", iud)) %>%
  mutate(`IUD Brand` = factor(iud, levels = c("mirena", "skyla", "liletta", "kyleena"))) %>%
  ggplot(data = ., aes(x = y_m, col = `IUD Brand`)) + 
  geom_freqpoly(position = 'identity', size = 1.5, bins = 50) + ## low res: 45, high res: 150
  scale_color_manual(values=wes_palette(n=5, name="Zissou")[c(1,3,5,2)]) + ##c(5,3,1)
  theme_classic()
p
# ggsave("results/time_series/iud_time_plot_updated_50bins.png", p, width = 5, height = 3.5)

pg = ggplot_build(p)
counts_tbl = pg$data %>% as.data.frame %>% select(x, y, group) %>% 
  spread(group, y)
names(counts_tbl) = c("Time_period", "Mirena", "Skyla", "Liletta", "Kyleena")
counts_tbl = counts_tbl %>% mutate(date_period_end = as.Date(Time_period, origin = "1970-01-01"))


## group by month
per_month_table = iud_df %>% 
  mutate(y_m = gsub("-[0-9][0-9]$", "", y_m)) %>% 
  mutate(iud = gsub("_list.*", "", iud)) %>% 
  group_by(iud, y_m) %>% tally %>% 
  ungroup() %>% 
  spread(key = iud, value = n, fill = 0) %>% 
  arrange(y_m) %>% 
  select(y_m, mirena, skyla, liletta, kyleena)

## plot by month
p = iud_df %>%
  mutate(y_m = gsub("-[0-9][0-9]$", "", y_m)) %>% 
  mutate(iud = gsub("_list.*", "", iud)) %>% 
  group_by(iud, y_m) %>% summarise(Tweets = n()) %>% 
  ungroup() %>% 
  filter(!grepl("2018|2017-12|2017-11", y_m)) %>% 
  mutate(`IUD Brand` = factor(iud, levels = c("mirena", "skyla", "liletta", "kyleena"))) %>%
  mutate(Year = y_m %>% gsub("$", "-01", .) %>% as.Date(., format = "%Y-%m-%d")) %>% 
  ggplot(data = ., aes(x = Year, y = Tweets, col = `IUD Brand`)) + 
  geom_line(size = 1.25) + ## low res: 45, high res: 150
  scale_color_manual(values=wes_palette(n=5, name="Zissou")[c(1,3,2,5)]) + ##c(5,3,1)
  theme_classic()
p
# ggsave("results/time_series/iud_time_by_month.png", p, width = 5, height = 3.5)


counts_tbl %>% mutate(row_sum = Mirena + Skyla + Liletta + Kyleena)

# counts_tbl %>%
#   select(date_period_end, Mirena, Skyla, Liletta, Kyleena) %>%
per_month_table %>% 
  mutate(total = mirena + skyla + liletta + kyleena) %>% 
  write_tsv("results/time_series/counts_per_month.txt")

################
# source vs time
################

# feat_table = read.table("data_all/feats_interest.txt", quote = "", sep = "\t", 
#                         header = TRUE, row.names = NULL)
# because R is being weird with column names..
# feat_names = names(feat_table)[-1]
# feat_table$favorites = NULL
# names(feat_table) = feat_names

feat_df = map_df(list.files("data_all", "feats_interest.*", full.names = T), read_tsv)

feat_df %>% group_by(source, brand) %>% tally

# categorize by brand, only keep tweets with an actual score
feat_df %<>%
  mutate(brand = as.character(brand)) %>%
  ## if tweet mentions more than one brand, set to most recently released brand
  mutate(brand = ifelse(grepl("skyla", brand), "skyla", brand)) %>%
  mutate(brand = ifelse(grepl("liletta", brand), "liletta", brand)) %>%
  mutate(brand = ifelse(grepl("kyleena", brand), "kyleena", brand)) %>%
  filter(!grepl("none", brand)) %>%
  mutate(brand = gsub(" ", "", brand)) %>%
  mutate(brand = as.factor(brand)) %>%
  ## besides 0, Dodd range is 5.2-8.4
  filter(source != "" & score_dodd > 0)


# source categories
feat_df %<>%
  mutate(source = as.character(source)) %>%
  # for the users categorized as both organization and individual, classify as org
  mutate(source = ifelse(grepl("org individual", source), "org", source)) %>%
  # for the users categorized as both organization/individual and law, classify as law
  mutate(source = ifelse(grepl("law", source), "law", source)) %>%
  mutate(source = gsub(" ", "", source)) %>%
  mutate(source = as.factor(source))

feat_df %>% group_by(source) %>% ## source brand
  summarise(sent_mean = mean(score_dodd) %>% round(2), 
            sent_ci_sd = 1.96*sd(score_dodd)/n(),
            Q1=quantile (score_dodd, probs=0.25),
            Q3=quantile (score_dodd, probs=0.75),
            sent_ci = (1.96*sd(score_dodd)) %>% round(2),
            sent_median = median(score_dodd) %>% round(2)) %>% 
  write_tsv("results/mean__ci_source.txt") ## mean__ci_source.txt ## mean__ci_brand.txt
  tally
feat_df %>% group_by(brand) %>% tally

# count the number of individuals in each source
feat_df %>% 
  select(username, source) %>%
  unique %>%
  group_by(source) %>% 
  tally

# convert to date time format
feat_df %<>% mutate(date_time = as.POSIXct(date_time))

# classifying sentiment
p = ggplot(data = feat_df, aes(x = score_dodd)) + 
  geom_histogram(bins = 100) +
  ggtitle("Sentiment score distribution")
p
# ggsave("results/hist_sentiment.png", plot = p, width = 5, height = 5, dpi = 300)

# sentiment vs source overall
# change the order in which items are graphed
source_order = c("org", "individual", "provider", "law")
# feat_table %>% group_by(source) %>% summarise(mean(score_dodd), median(score_dodd))

p = feat_df %>% 
  mutate(source = factor(source, levels = source_order)) %>% 
  ggplot(data = , aes(x = source, y = score_dodd)) + 
  # geom_violin(color = "grey80", width = 0.4) +
  geom_boxplot(width = 0.9, outlier.size = 0.75) +
  # facet_wrap(~ brand) +
  # ylim(0, 10) + 
  ggtitle("Sentiment score by source") +
  xlab("Source") + ylab("Sentiment score (Dodds, 2015)") +
  theme_classic()
p
# ggsave("results/plots_significant/sent_source_boxplot_updated.png",
#        plot = p, width = 3, height = 5, dpi = 300)

fit = aov(score_dodd ~ source, feat_df) 
sent_source_diff = TukeyHSD(fit)$source
write.table(sent_source_diff, file = "results/sent_vs_source_sig_updated.txt",
            quote = F, sep = "\t")
# add error bars and stars manually in ppt

## Per Brand ANOVA
PostHocCalcBrands = function(brand_i, feat_df) {
  fit = aov(score_dodd ~ source, feat_df %>% filter(brand == brand_i))#"mirena"
  sent_source_diff = TukeyHSD(fit)$source %>% 
    as.data.frame %>% mutate(brand = brand_i)
  return(sent_source_diff)
}

brand_list = c("liletta", "mirena", "skyla", "kyleena")
per_brand_df = lapply(brand_list, PostHocCalcBrands, feat_df) %>% bind_rows
write.table(per_brand_df, file = "results/sent_vs_source_by_brand_sig_updated.txt",
            quote = F, sep = "\t", row.names = F)

# sentiment vs brand
brand_order = c("mirena", "skyla", "liletta", "kyleena")

p = feat_df %>%
  mutate(brand = factor(brand, levels = brand_order)) %>% 
  ggplot(data = ., aes(x = brand, y = score_dodd)) + 
  # geom_violin() +
  geom_boxplot(width = 0.9, outlier.size = 0.75) +
  ggtitle("Sentiment score by IUD brand") +
  theme_classic()
p
ggsave("results/plots_significant/sent_brand_boxplot_updated.png", plot = p, width = 3, height = 5, dpi = 300)
fit = aov(score_dodd ~ brand, feat_df)
TukeyHSD(fit)$brand
write.table(TukeyHSD(fit)$brand, file = "results/sent_vs_brand_sig_updated.txt",
            quote = F, sep = "\t")

# sentiment vs source facet by m, m + s, m + s + l (stats via Tukey)
p = feat_df %>%
  filter(source != "" & score_dodd > 0) %>%
  ggplot(data = ., aes(x = source, y = score_dodd)) +
  # geom_violin() +
  geom_boxplot() +
  facet_wrap(~ brand) + 
  ggtitle("Sentiment score by source") +
  theme_classic()
p
ggsave("results/sent_source_boxplot_updated.png", plot = p, width = 5, height = 5, dpi = 300)


# source vs time
p = ggplot(data = feat_df, aes(x = date_time, col = source)) + 
  geom_freqpoly(position = 'identity', size = 1.25) +
  theme_bw() +
  facet_wrap(~ brand) + #, scales = "free"
  scale_colour_brewer(palette = "Set2") +
  xlab("Tweet date") +
  ylab("Tweets per month")
p
ggsave("results/time_series/source_time.png", plot = p, width = 10, height = 5, dpi = 300)

# retweets vs favorites colored by source
p = feat_df %>% 
  filter(source == "org") %>% 
  ggplot(data = ., aes(x = favorites, y = retweets)) + #, col = source
  geom_point() +
  # geom_jitter() +
  ylim(-5,50) + 
  xlim(-5,50) + 
  theme_bw()
p
ggsave("results/favorites_retweets_source.png", plot = p, width = 5, height = 5, dpi = 300)

# most popular tweets by source
feat_df %>% 
  group_by(source) %>% #brand
  # filter(score_dodd == max(score_dodd)) %>% 
  filter(retweets == max(retweets)) %>%
  # filter(favorites == max(favorites)) %>%
  ungroup()

###########################################
# check histogram distribution of sentiment
###########################################

p = ggplot(data = feat_table, aes(x = score_dodd)) + #fill = source_o, 
  geom_histogram(bins = 100, alpha = 0.5, position = "identity") +
  facet_wrap(~ source_o, scale = "free") + # brand source_o
  ggtitle("Sentiment score by source") +
  xlab("Source") + ylab("Sentiment score (Dodds, 2015)") +
  theme_bw()
p
ggsave("results/hist_sentiment_brand.scale_free.png", p, width = 8, height = 4)

# 
library(mclust)

ind_tweets = feat_table %>% filter(source == "org") %>% # individual org provider law
  select(score_dodd) %>% unlist %>% as.numeric
ind.gmm = Mclust(ind_tweets)
summary(ind.gmm, parameters = TRUE)

# ind.gmm.1 = Mclust(ind_tweets, G=1)
# ind.gmm.2 = Mclust(ind_tweets, G=2)
# 
# summary(ind.gmm.1)
# summary(ind.gmm.2)
# # plot(ind.gmm)
# logLik(ind.gmm) - logLik(ind.gmm.1)
# pchisq(231.446, df=3, lower.tail = FALSE, log.p = TRUE)

feat_table %>% filter(source == "individual") %>% 
  ggplot(., aes(x = score_dodd)) +
  # geom_histogram(bins = 800)
  geom_freqpoly(bins = 200) +
  geom_vline(xintercept = 5.326172, col = "red") +
  geom_vline(xintercept = 5.414039, col = "red") +
  theme_bw()

#############################################
# check differences after correcting for time
#############################################

head(feat_table)

design_df = model.matrix(~ source_o + brand, feat_table) %>% 
  cbind("score_dodd" = feat_table$score_dodd, "date_time" = feat_table$date_time) %>% 
  as.data.frame
head(design_df)
fit = lm(score_dodd ~ source_oindividual + 
           source_oprovider + source_olaw +
           brandskyla + brandliletta + date_time, design_df)
fit = lm(score_dodd ~ date_time*brandskyla + 
           date_time*brandliletta, design_df)
summary(fit)
cor.test(design_df$date_time, feat_table$score_dodd, method = "pearson")
# time does not account for 


##########################################
# classifying sentiment as pos/neg/neutral
##########################################

bound_lo = mean(feat_table$score_dodd) - sd(feat_table$score_dodd)/2
bound_hi = mean(feat_table$score_dodd) + sd(feat_table$score_dodd)/2

feat_table = feat_table %>% 
  mutate(sentiment = ifelse(score_dodd < bound_lo & score_afinn <= 0, 
                            "negative", "neutral")) %>%
  mutate(sentiment = ifelse(score_dodd > bound_hi & score_afinn >= 0, "positive", sentiment))
# score_afinn is all either 0 or -1..
# as.Date(date_time, format = "%Y-%b-%d")
feat_table %>% filter(sentiment == "positive") %>% dim
feat_table %>% filter(score_afinn >= 0) %>% dim

# sentiment vs time
p = ggplot(data = feat_table, aes(x = date_time, col = sentiment)) + 
  geom_freqpoly(position = 'identity') +
  # geom_histogram(position = "fill") +
  theme_bw() +
  xlab("Tweet date") +
  ylab("Tweets per month")
p
ggsave("figures/sentiment_time.png", plot = p, width = 5, height = 5, dpi = 300)

# source vs time, classified by sentiment
p = ggplot(data = feat_table, aes(x = date_time, fill = sentiment)) + 
  # geom_freqpoly(position = 'identity') +
  geom_histogram(position = "fill") +
  facet_wrap(~ source) + 
  theme_bw() +
  xlab("Tweet date") +
  ylab("Tweets per month")
p
ggsave("figures/sentiment_source_time.png", plot = p, width = 10, height = 5, dpi = 300)

feat_table %>% filter(favorites > 10 | retweets > 10)

# most retweeted tweet: Personal_Magic, 937
feat_table %>% arrange(desc(retweets)) %>% head
# favorite tweet: KailLowry, 363
feat_table %>% arrange(desc(favorites)) %>% head

#####################################################################
# randomly sampling 25 tweets from law, individual, provider, and org
#####################################################################

feat_table %>% 
  group_by(source) %>% 
  select(username) %>% unique %>% 
  sample_n(10) %>% 
  summarise(usernames = paste(username, collapse = "|")) %>% 
  ungroup %>% as.data.frame

##########################################
# binned over time with 100% stacked bar 
# graphs (remove unknown source), see how 
# ratios change over time
##########################################


##########################################
# retweets vs sentiment, favorites vs 
# sentiment, retweets vs favorites. get 
# correlation for each
##########################################

# http://stackoverflow.com/questions/29263046/how-to-draw-the-boxplot-with-significant-level

y_bar = c(2.4, 2.5, 2.5, 2.5, 2.4)
df1 <- data.frame(a = c(1, 1:3,3), b = )
df2 <- data.frame(a = c(1, 1,2, 2), b = c(35, 36, 36, 35))
df3 <- data.frame(a = c(2, 2, 3, 3), b = c(24, 25, 25, 24))
p + geom_line(data = df1, aes(x = a, y = b)) + annotate("text", x = 2, y = 42, label = "*", size = 8) +
  geom_line(data = df2, aes(x = a, y = b)) + annotate("text", x = 1.5, y = 38, label = "**", size = 8) +
  geom_line(data = df3, aes(x = a, y = b)) + annotate("text", x = 2.5, y = 27, label = "***", size = 8)
# http://stackoverflow.com/questions/17084566/put-stars-on-ggplot-barplots-and-boxplots-to-indicate-the-level-of-significanc
label.df = data.frame(Group = c("S1", "S2"),
                      Value = c(6, 9))
p + geom_text(data = label.df, label = "***")


