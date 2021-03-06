
# Trying to use the logistic regression!
# The result is little worse than in random forrest (datacamp tutorial), but I'm looking forward to improve the model.
#
#
#

library("dplyr")

options(stringsAsFactors=FALSE)

# The train and test data is stored in the ../input directory
train <- read.csv("../input/train.csv")
test  <- read.csv("../input/test.csv")

train$Age[is.na(train$Age)]<-mean(na.omit(train$Age))
train$Fare[is.na(train$Fare)]<-mean(na.omit(train$Fare))
train$Embarked[is.na(train$Embarked)]<-"S"
train$SibSp[is.na(train$SibSp)]<-0
train$Parch[is.na(train$Parch)]<-0

test$Age[is.na(test$Age)]<-mean(na.omit(test$Age))
test$Fare[is.na(test$Fare)]<-mean(na.omit(test$Fare))
test$Embarked[is.na(test$Embarked)]<-"S"
test$SibSp[is.na(test$SibSp)]<-0
test$Parch[is.na(test$Parch)]<-0

train$Age<-(train$Age-mean(train$Age))/sd(train$Age)
test$Age<-(test$Age-mean(test$Age))/sd(test$Age)

train<-mutate(train,Sex=as.factor(Sex),Pclass=as.factor(Pclass),Survived=as.factor(Survived),Embarked=as.factor(Embarked),Family=SibSp+Parch)
test<-mutate(test,Sex=as.factor(Sex),Pclass=as.factor(Pclass),Embarked=as.factor(Embarked),Family=SibSp+Parch)

# The best one I've found atm.
m_logit <- glm(data=train, Survived ~ Pclass*Fare+Sex*Age*Family+Sex*I(Age^2)+I(Family^2),
               family=binomial(link="logit"),x=TRUE)
summary(m_logit)

## This model is much more clear imo, but have worse accuracy :(
#m_logit <- glm(data=train, as.factor(Survived) ~ Pclass+Sex*Age+I(Age^2)+I(Family^2),
#               family=binomial(link="logit"),x=TRUE) 

pr_logit <- predict(m_logit,test)

pr_test<-pr_logit

sigmoid <- function(x){
  result <- 1.0 / (1.0 + exp(-x))
  return(result)
}

pr_test[sigmoid(pr_test)>=0.6]=1
pr_test[sigmoid(pr_test)<0.6]=0

my_logit <- data.frame(PassengerId=test$PassengerId, Survived=pr_test)


write.csv(my_logit, file = "my_solution_logit.csv", row.names = FALSE) 

