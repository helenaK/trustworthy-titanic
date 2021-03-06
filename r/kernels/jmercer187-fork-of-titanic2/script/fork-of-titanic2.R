# This R environment comes with all of CRAN preinstalled, as well as many other helpful packages
# The environment is defined by the kaggle/rstats docker image: https://github.com/kaggle/docker-rstats
# For example, here's several helpful packages to load in 

library(ggplot2) # Data visualization
library(readr) # CSV file I/O, e.g. the read_csv function
library(rpart)
library(party)
library(randomForest)

# Input data files are available in the "../input/" directory.
# For example, running this (by clicking run or pressing Shift+Enter) will list the files in the input directory

system("ls ../input")

# Any results you write to the current directory are saved as output.


train <- read.csv("../input/train.csv", header = TRUE, stringsAsFactors = F)
test <- read.csv("../input/test.csv", header = TRUE, stringsAsFactors = F)

test$Survived <- NA

combi <- rbind(train, test)

# create child flag
combi$Child <- 0
combi$Child[test$Age < 18] <- 1

# break down fares into discrete buckets
combi$Fare2 <- "30+"
combi$Fare2[combi$Fare < 30 & combi$Fare >= 20] <- "20-30"
combi$Fare2[combi$Fare < 20 & combi$Fare >= 10] <- "10-20"
combi$Fare2[combi$Fare < 10] <- "<10"


# this pulls apart strings and gives us all titles
combi$Title <- gsub('(.*, )|(\\..*)', '', combi$Name)

# now let's boil down the titles into something easier to work with:
rare.title <- c("Dona", "Lady", "the Countess", "Capt", "Col", "Don", "Dr", "Major", "Rev", "Sir", "Jonkheer")

combi$Title[combi$Title == 'Mlle'] <- 'Miss'
combi$Title[combi$Title == 'Ms'] <- 'Miss'
combi$Title[combi$Title == 'Mme'] <- 'Miss'
combi$Title[combi$Title %in% rare.title] <- 'Rare Title'

# not let's break up the passengers into their families .. maybe knowing family size could help the algo?
# get surnames
combi$Surname <- sapply(combi$Name, FUN = function(x) { strsplit(x, split = "[,.]")[[1]][1] })

# get family sizes
combi$FamilySize <- combi$SibSp + combi$Parch + 1

# combine family sizes and surnames
combi$FamilyUnit <- paste(combi$Surname, as.character(combi$FamilySize), sep = "_")

# make family size discrete, incorporate survival penalty for singletons and families of 5+
combi$FamilySize2[combi$FamilySize == 1] <- 'singleton'
combi$FamilySize2[combi$FamilySize < 5 & combi$FamilySize > 1] <- 'small'
combi$FamilySize2[combi$FamilySize > 4] <- 'large'

# cut up fare slices
combi$Fare3[combi$Fare <= 5] <- '0-5'
combi$Fare3[combi$Fare > 5 & combi$Fare <= 11] <- '6-10'
combi$Fare3[combi$Fare > 11 & combi$Fare <= 15] <- '11-15'
combi$Fare3[combi$Fare > 15 & combi$Fare <= 20] <- '16-20'
combi$Fare3[combi$Fare > 20 & combi$Fare <= 25] <- '21-25'
combi$Fare3[combi$Fare > 25 & combi$Fare <= 30] <- '26-30'
combi$Fare3[combi$Fare > 30 & combi$Fare <= 40] <- '31-40'
combi$Fare3[combi$Fare > 40 & combi$Fare <= 60] <- '41-60'
combi$Fare3[combi$Fare > 60 & combi$Fare <= 100] <- '60-100'
combi$Fare3[combi$Fare > 100 & combi$Fare <= 200] <- '101-200'
combi$Fare3[combi$Fare > 200] <- '200+'


# use a decision tree to fill in missing Age values
Agefit <- rpart(Age ~ Pclass + Sex + SibSp + Parch + Embarked + Title + FamilySize,
                data = combi[!is.na(combi$Age),],
                method = "anova")

combi$Age[is.na(combi$Age)] <- predict(Agefit, combi[is.na(combi$Age),])

# Since their fare was $80 for 1st class, they most likely embarked from 'C'
combi$Embarked[c(62, 830)] <- "C"

# Replace missing fare value with median fare for class/embarkment
combi$Fare[1044] <- median(combi[combi$Pclass == "3" & combi$Embarked == "S",]$Fare, na.rm = TRUE)
combi$Fare2[1044] <- "<10"

# turn character cols to factors so randomForests doesn't get all wiggedy wack
combi$Name <- as.factor(combi$Name)
combi$Sex <- as.factor(combi$Sex)
combi$Embarked <- as.factor(combi$Embarked)
combi$Fare3 <- as.factor(combi$Fare2)
combi$Title <- as.factor(combi$Title)
combi$Surname <- as.factor(combi$Surname)
combi$FamilySize <- as.factor(combi$FamilySize)
combi$FamilySize2 <- as.factor(combi$FamilySize2)

# split the combined dataset back up into train / test for the algo to work with
train <- combi[1:891,]
test <- combi[892:1309,]


set.seed(187)

fit3 <- randomForest(factor(Survived) ~ Pclass + Sex + Age + SibSp + Parch + Fare3 + Embarked + Title + FamilySize2 + Child,
           data = train,
           importance = TRUE,
           ntree = 2000, 
           mtry = 5)
Prediction <- predict(fit3, test)
submit <- data.frame(PassengerId = test$PassengerId, Survived = Prediction)
write.csv(submit, file = "randoforest6.csv", row.names = FALSE)

# ok but let's try this other method tho

#set.seed(187)

#fit4 <- cforest(factor(Survived) ~ Pclass + Sex + Age + SibSp + Parch + Fare + Embarked + Title + FamilySize,
           #data = train,
           #controls = cforest_unbiased(ntree = 2000, mtry = 2))
#Prediction <- predict(fit4, test, OOB = TRUE, type = "response")
#submit <- data.frame(PassengerId = test$PassengerId, Survived = Prediction)
#write.csv(submit, file = "randoforest2.csv", row.names = FALSE)