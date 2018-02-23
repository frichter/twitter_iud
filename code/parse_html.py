#!/usr/bin/env python2

## python 2
from bs4 import BeautifulSoup
import re
import types
import os
from datetime import datetime

os.chdir("/Users/felixrichter/Dropbox/PhD/twitter_iud/")

# upload all tweets into soup instance
## start_07_07.end_16_03 start_16_03.end_17_11
with open("data_all/web_scraping_streams/start_16_03.end_17_11.txt", 'r') as html_doc:
    soup = BeautifulSoup(html_doc, 'html.parser')

# soup.find("div", { "class" : "content"})
# count the total number of tweets
soup.find_all("div", { "class" : "content"}).__len__()
# 7170
# 3946 ## for new batch
# should equal count from below

tweet_i = soup.find_all("div", { "class" : "content"})[0]

# add all tweets to a dict
count = 0
tweet_dict = {}
for tweet_i in soup.find_all("div", { "class" : "content"}):
    try:
        tweet_dict_single = {}
        tweet_dict_single['userid'] = tweet_i.a["data-user-id"]
        tweet_dict_single['fullname'] = tweet_i.strong.string
        ## for older
        # tweet_dict_single['username'] = tweet_i.find(class_ = "username js-action-profile-name").b.string
        ## for newer (03/2016 through 11/2017)
        tweet_dict_single['username'] = tweet_i.find(class_ = "username u-dir").b.string
        tweet_dict_single['text'] = tweet_i.find("div", { "class" : "js-tweet-text-container"}).get_text(strip = True)
        tweet_dict_single['retweets'] = tweet_i.find(class_ = re.compile("ProfileTweet-action--retweet")).span["data-tweet-stat-count"]
        tweet_dict_single['favorites'] = tweet_i.find(class_ = re.compile("ProfileTweet-action--favorite")).span["data-tweet-stat-count"]
        if tweet_i.small.a.has_attr("title"):
            tweet_date_time = tweet_i.small.a["title"]
        else:
            tweet_date_time = tweet_i.small.a["data-original-title"]
        tweet_dict_single['date_time'] = datetime.strptime(tweet_date_time, '%I:%M %p - %d %b %Y')
        tweet_dict_single['link'] = tweet_i.small.a["href"]
        tweet_dict[count] = tweet_dict_single
        count += 1
    except:
        # print(tweet_i.a["data-user-id"])
        pass

print count

##########
# save dict as json (not pickle)
# http://stackoverflow.com/questions/2259270/pickle-or-json
# https://www.quora.com/How-do-I-write-a-dictionary-to-a-file-in-Python

# import json
# def json_serial(obj):
#     """JSON serializer for objects not serializable by default json code"""
#     if isinstance(obj, datetime):
#         serial = obj.isoformat()
#         return serial
#     raise TypeError ("Type not serializable")
#
# with open("data_all/tweet_dict_batch2.json", "w") as f:
#     json.dump(tweet_dict, f, default=json_serial)
#
# with open("data_all/tweet_dict.json", "w\r") as f:
#     tweet_dict = json.dump(f, default=json_serial)
# haven't figured out how to import with
# date decoding
# http://stackoverflow.com/questions/8793448/how-to-convert-to-a-python-datetime-object-with-json-loads


#########################
# categorize by IUD brand
#########################

# mirena, skyla, liletta, and/or none
mirena_re = re.compile('mirena', flags=re.I)
skyla_re = re.compile('skyla', flags=re.I)
liletta_re = re.compile('liletta', flags=re.I)
kyleena_re = re.compile('kyleena', flags=re.I)
# flag ignores case
count = 0
for key, value in tweet_dict.iteritems():
    tweet_i = tweet_dict[key]
    tweet_dict[key]['brand'] = ""
    if re.search(mirena_re, tweet_i['text']):
        tweet_dict[key]['brand'] += "mirena "
    if re.search(skyla_re, tweet_i['text']):
        tweet_dict[key]['brand'] += "skyla "
    if re.search(liletta_re, tweet_i['text']):
        tweet_dict[key]['brand'] += "liletta "
    if re.search(kyleena_re, tweet_i['text']):
        tweet_dict[key]['brand'] += "kyleena "
    if not tweet_i['brand']:
        tweet_dict[key]['brand'] = "none"
        print tweet_i['text']
    count += 1

print count


##################################################
# exclude tweets with the following issues
##################################################

rm_names_re = re.compile('skyla|kyleena', flags=re.I) ##
## baby skyla|skyla baby|baby girl skyla
## skyla/kyleena in the username/real name/@ ## this is too difficult
rm_text_re = re.compile('skylababy|babygirlskyla|babyskyla', flags=re.I) ##

count = 0
keys_to_rm = []
for key, value in tweet_dict.iteritems():
    tweet_i = tweet_dict[key]
    ## first check text for keys you want to exclude
    if re.search(rm_text_re, tweet_i['text']):
        print(tweet_i['text'])
        keys_to_rm.append(key)
        count += 1
    ## then check twitter handle and username for keys you want to exclude
    elif tweet_i['fullname']:
        if re.search(rm_names_re, tweet_i['fullname']):
            print(tweet_i['fullname'])
            keys_to_rm.append(key)
            count += 1
    elif tweet_i['username']:
        if re.search(rm_names_re, tweet_i['username']):
            print(tweet_i['username'])
            keys_to_rm.append(key)
            count += 1


count
len(tweet_dict)
### delete the tweets you don't want
for key in keys_to_rm:
    if key in tweet_dict:
        del tweet_dict[key]


len(tweet_dict)

#######################
# add key for sentiment
#######################

score_afinn_dict = {}
with open("sentiment_score_dict/AFINN-111.txt", 'r') as f:
    for line in f:
        term, score  = line.split("\t")
        score_afinn_dict[term] = int(score)

with open("sentiment_score_dict/dodds_2015_scores.txt", 'r') as f_scores:
    score_list = [i.strip() for i in f_scores]

with open("sentiment_score_dict/dodds_2015_words.txt", 'r') as f_words:
    word_list = [i.strip() for i in f_words]

score_dodd_dict = dict(zip(word_list, score_list))

# decision: use average or absolute score per tweet?
# http://journals.plos.org/plosone/article?id=10.1371/journal.pone.0026752
# uses average



count = 0
for key, value in tweet_dict.iteritems():
    tweet_text = tweet_dict[key]['text'].encode('utf-8').lower().strip()
    # calcuate AFINN
    score_afinn = 0
    sent_words_list = []
    # not clear where breakpoints are in tweets
    # similar to DNA alignment problem..
    for eachkey in score_afinn_dict.keys():
        if tweet_text.find(eachkey) != -1:
            score_afinn += int(score_afinn_dict[eachkey])
            sent_words_list.append(eachkey)
    if sent_words_list:
        score_afinn_avg = score_afinn/len(sent_words_list)
    else:
        score_afinn_avg = 0
    tweet_dict[key]['score_afinn'] = score_afinn_avg
    tweet_dict[key]['score_afinn_words'] = sent_words_list
    # calculate dodd score
    score_dodd = 0
    sent_words_list = []
    tweet_text_list = tweet_text.split()
    for tweet_text_word in tweet_text_list:
        if tweet_text_word in score_dodd_dict.keys():
            score_dodd += float(score_dodd_dict[tweet_text_word])
            sent_words_list.append(tweet_text_word)
    if sent_words_list:
        score_dodd_avg = score_dodd/len(sent_words_list)
    else:
        score_dodd_avg = 0
    tweet_dict[key]['score_dodd'] = score_dodd_avg
    tweet_dict[key]['score_dodd_words'] = sent_words_list
    count += 1
    if count % 100 == 0:
        print(count)


print count


### removed tweet 4 earlier..
tweet_dict[2]['text']
tweet_dict[2]['score_dodd']
tweet_dict[2]['score_dodd_words']
tweet_dict[2]['score_afinn']
tweet_dict[2]['score_afinn_words']


#######################
# categorize by source
#######################

with open("user_categorize/batch_w_kyleena/individuals.txt", "rU") as  f:
    individ_list = [i.strip() for i in f]

with open("user_categorize/batch_w_kyleena/orgs.txt", "rU") as  f: 
    orgs_list = [i.strip() for i in f]

with open("user_categorize/batch_w_kyleena/providers.txt", "rU") as  f: 
    providers_list = [i.strip() for i in f]

with open("user_categorize/batch_w_kyleena/law.txt", "rU") as  f: 
    law_list = [i.strip() for i in f]

## using += allows us note if there were some inconsistent classifications
count = 0
for key, value in tweet_dict.iteritems():
    tweet_i = tweet_dict[key]
    tweet_dict[key]['source'] = ""
    if any(e == tweet_i['username'] for e in orgs_list):
        tweet_dict[key]['source'] += "org "
    if any(e == tweet_i['username'] for e in providers_list):
        tweet_dict[key]['source'] += "provider "
    if any(e == tweet_i['username'] for e in law_list):
        tweet_dict[key]['source'] += "law "
    if any(e == tweet_i['username'] for e in individ_list):
        tweet_dict[key]['source'] += "individual "
    if tweet_dict[key]['source']:
        count += 1

# number of tweets that still need to be categorized:
7170-count
# 139


#####################################
# export elements you'd like to graph
#####################################

outfile = "data_all/feats_interest_11_30_2017.txt"
open(outfile, 'w').close()

tweet_feats_list = ['username', 'date_time', 'source', \
    'score_dodd', 'score_afinn', 'brand', 'retweets', \
    'favorites']
# do not try exporting the tweet text

count = 0
with open(outfile, 'a+') as outf:
    # outf.write("\t")
    outf.write("\t".join(tweet_feats_list))
    outf.write("\n")

for key, value in tweet_dict.iteritems():
    with open(outfile, 'a+') as outf:
        tweet = tweet_dict[key]
        tweet_out_list = [str(tweet[i]) for i in tweet_feats_list]
        tweet_out_list.append("\n")
        newline = "\t".join(tweet_out_list)
        outf.write(newline)
        count += 1

######################
# find specific tweets
######################

def FindTweet(tweet_dict, user):
    for key, value in tweet_dict.iteritems():
        if tweet_dict[key]['username'] == user:
            print value

FindTweet(tweet_dict, "DrJenGunter")


#############################################
# saving dict as 2 separate databases for IRB
#############################################

# required under identifiers:
# userid, full name, user name, date and link to tweet (URLs)
out_tweets_path = "data_all/id_tweets.txt"
out_ident_path = "data_all/id_identifiables.txt"

count = 0
missed_count = 0
with open(out_tweets_path, 'wb') as out_tweets_f, open(out_ident_path, 'wb') as out_ident_f:
    for key, value in tweet_dict.iteritems():
        try:
            tweet = tweet_dict[key]
            # print key, tweet['text']
            text_id_list = (str(key), tweet['text'], "\n")
            # print text_id_list
            text_id = "\t".join(text_id_list).encode('utf-8')
            # print text_id
            out_tweets_f.write(text_id)
            other_id_list = (str(key), tweet['userid'], \
                tweet['username'], str(tweet['fullname']), \
                str(tweet['date_time']), tweet['link'], "\n")
            # print other_id_list
            other_id = "\t".join(other_id_list).encode('utf-8')
            # print other_id
            out_ident_f.write(other_id)
            count += 1
            # if count > 20:
            #     break
            if count % 100 == 0:
                print count
        except:
            print value
            missed_count += 1



count # 6949
missed_count # 221
########################
# randomly sample tweets
########################


individual_rand = "MsSamber|NikkiLizMurray|Kfedore|tatelawgroup|JustforJunior|" + \
    "AlexBerish|DopeChubbyChick|DBBettiePDX|MinaMeow|Just_Kelleigh"
law_rand = "LeeMurphyLaw|lawyersource|NYAccidentLaw|LifeSciLaw360|AmherstLawyer" + \
    "|ennisennislaw|GwilliamLaw|attorneygroup|JusticeForYouWA|SCLawyersWeekly"
org_rand = "UW_PTC|DailyWHPR|HealthWatchZone|mediahealth|fertilefoods|" + \
    "asafmiddleTN|BeNicePrenatal|pregnancyqsorg|familymoms|lcrtl"
provider_rand = "JenLincolnMD|FutureRNina|obgyndoctor|MichaelBensonMD|" + \
    "drval|DrCarrieOBGYN|kchoma|ChickpeaMD|KPobgyndoc|Doc_Megz"


user_list = (individual_rand, law_rand, org_rand, provider_rand)
user_re = re.compile("|".join(user_list))


out_f_loc = "data_all/random_tweets.txt"
count = 0
missed_count = 0
with open(out_f_loc, 'wb') as out_f:
    for key, tweet in tweet_dict.iteritems():
        if re.search(user_re, tweet['username']):
            tweet_id_list = (str(key), tweet['username'], tweet['fullname'], \
                tweet['brand'], str(tweet['source']), \
                str(tweet['date_time']), str(tweet['score_dodd']), \
                tweet['text'], "\n")
            tweet_id_out = "\t".join(tweet_id_list).encode('utf-8')
            # print tweet_id_out
            out_f.write(tweet_id_out)
            count += 1



    re.match()
    # print key, tweet['text']
    text_id_list = (str(key), tweet['text'], "\n")
    # print text_id_list
    text_id = "\t".join(text_id_list).encode('utf-8')
    # print text_id
    out_tweets_f.write(text_id)
    other_id_list = (str(key), tweet['userid'], \
        tweet['username'], str(tweet['fullname']), \
        str(tweet['date_time']), tweet['link'], "\n")







################## Notes
#

# soup.find_all('li')
# # pyquery not enough documentation, would need to learn jquery

# # goal to extract:
# # data-user-id, username, fullname, tweet-timestamp,
# # div class="js-tweet-text-container"
# soup.find(class='js-tweet-text-container')

# soup.div['class']
# # [u'stream']
# print soup.div.div.prettify()
# soup.div.div['class']
# # [u'tweet', u'original-tweet', u'js-original-tweet', u'js-stream-tweet', u'js-actionable-tweet', u'js-profile-popup-actionable', u'']

# soup.div.div.contents.__len__() # list
# soup.div.children # iterator
# list(soup.div.div.descendants).__len__() # list
# list(soup.li.descendants).__len__()

# soup.contents.__len__() # list
# soup.children # iterator
# list(soup.descendants).__len__() # list
# soup.find_all('li').__len__()

# for string in soup.stripped_strings:
#     print(repr(string))

# for sibling in soup.div.div.next_siblings:
#     print(repr(sibling))

# for element in soup.li.next_elements:
#     if element.li:
#         print(repr(element))

# def has_class_but_no_id(tag):
#     return tag.has_attr('class') and not tag.has_attr('id')
# soup.find_all(has_class_but_no_id)
