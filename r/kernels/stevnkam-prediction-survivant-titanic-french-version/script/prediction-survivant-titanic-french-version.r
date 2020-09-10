
---
title: ' Prediction de la mort sur Titanic'
output:
  html_notebook: default
  html_document: default
---

## I. Introduction

### 1.1 Chargeons les librairies que nous aurons besoin



```{r}
library('ggplot2')  # pour la visualisation
library('ggthemes') # pour la visualisation
library('scales') # pour la visualisation
library('dplyr') # pour la manipulation
library('mice')  # pour la manipulation
library('prettyR')
library('randomForest') # l'algorithme de classifcation 
library('AUC')
library('Rcpp')
library('ROCR')
library('rpart')
#pour la prédiction des survivants

```


### 1.2 Chargeons les donneées dans l'environnement de travail

```{r}
train <- read.csv("../input/train.csv", header = TRUE, stringsAsFactors = FALSE)
train$IsTrain <- TRUE
test <- read.csv("../input/test.csv", header = TRUE, stringsAsFactors = FALSE)
test$IsTrain <- FALSE
# L'instruction stringAsFactor=F permet de dire à R : ne transforme pas automatiquement tous 
#les champs String en Factor

# Dans un elan d'exploration de donneée nous allons fusionner les deux data train et test
test$Survived <- NA
full <- rbind(train, test)


# Regardons le contenu de full 

str(full)
```

# Décrivons les variables : 

Variable   ................        Description

Survived     ->                                    variable à predire vie(1) mort(0) 

Pclass      ->                                    La classe du passager

Name    ->                                         Le nom du passager

Age  ->                                            le nom du passager

Sex     ->                                         le sex du passager

SibSp   ->                                         Nomre de freres et soeurs/epouses à bord

Parch      ->                                      Nombre de parents/enfant à bord

Ticket          ->                                Indique le numero du ticket du passager

Fare            ->                                Indique le le prix du ticket

Cabin               ->                          indique la cabine du passager

Embarked               ->                         Indique le porte d emquation du passager


## 2. L ingénierie des variables (Lart de savoir observer)

### Extraction du titre (genre Mr. , Mme, ...) et du prenom

### 2.1 Extraction du titre

```{r}
full$title <- gsub('(.*,)|(\\..*)', '', full$Name)
```

### Regardons le contenu de title

```{r}
table(full$title)
```

When you save the notebook, an HTML file containing the code and output will be saved alongside it (click the *Preview* button or press *Cmd+Shift+K* to preview the HTML file).


# On observe qu'il y a des titres non significatifs (the countess, Rev,..), on peut les considerer donc comme des tites rares

```{r}
 rare_title <- c( ' Capt', ' Col', ' Don', ' Dona', ' Dr', ' Jonkheer', ' Major', ' Rev', ' the Countess', ' Lady')
```
 # Simplifions de ce fait cette colonne avec des regroupements 
 
```{r}
full$title[full$title == ' Mlle'] <- 'Miss'
full$title[full$title == ' Ms'] <- 'Miss'
full$title[full$title == ' Mme'] <- 'Mrs'
full$title[full$title %in% rare_title] <- 'rare_title'
    
```

# Regardons tout cela 

```{r}
table(full$Sex, full$title)
```

# 2.2. Créons la collone Surname par extraction de l'information de la colonne Name

```{r}
full$SurName <- sapply(full$Name, function(x) strsplit(x, split = '[,.]')[[1]][1])
```

# qu'est il arrivé aux familles? Rasseblons les

```{r}
# definissons la taille des familles
full$Fsize <- full$SibSp + full$Parch + 1;

# Creons une variable pour identifier les familles

full$Family <- paste(full$SurName, full$Fsize, sep = '-')
```


### Visualisation 

# visualisons la relation qui existe entre la taille des famille(Fsize) et la survie(Survived)

```{r}
ggplot(full[1:891,], aes(x=Fsize, fill= factor(Survived))) +
  geom_bar(stat = 'count', position = 'dodge') + scale_x_continuous(breaks = c(1:1)) +
  labs(x = 'family Size') +
  theme_few()
```



# Divisons les famille en sous partie

```{r}

full$FsizeD[full$Fsize == 1] <- 'singleton'
full$FsizeD[full$Fsize < 5 & full$Fsize >1] <- 'small'
full$FsizeD[full$Fsize > 4] <- 'large'

```

# Observons un peu tout ca 

```{r}
mosaicplot(table(full$FsizeD, full$Survived), main = 'Taille de la famille par la survie', shade = TRUE)
```

# Occupons des valeurs manquantes

En principe vu que les donneé ne sont pas gigantsque on va pas supprimer les lignes comportant les valeurs manquantes, mais on va essayer de prédire la valeur de ses donneées manquantes.

# Cherchons les colonnes qui ont des champs vides ou nulle

```{r}
colSums(is.na(full))
```

### Nous remarquons qu'il y a 263 valeurs manquantes de la variable Age. Nous pouvons donc essayer de predire la valeur de ses donneées manquantes :

Regardons un peu le resume de Age

```{r}
summary(full$Age)
```



```{r}
age_model <- rpart(Age ~ Pclass + Sex + SibSp + Parch + Fare + Embarked + title, 
                   
                   data = full[!is.na(full$Age), ], method = "anova")

full$Age[is.na(full$Age)] <- predict(age_model, full[is.na(full$Age),]) 

summary(full$Age)
```
Il y a une valeur manquante dans Fare

Nous allons utliser la methode visuelle et la non  visuelle 

```{r}
summary(full$Fare)
```
La methode ci-dessous est rapide si on a deja une idee des indices de la valeur manquante : 
```{r}
ggplot(full[full$Pclass == '3' & full$Embarked == 'S', ], 
  aes(x = Fare)) +
  geom_density(fill = '#99d6ff', alpha=0.4) + 
  geom_vline(aes(xintercept=median(Fare, na.rm=T)),
    colour='red', linetype='dashed', lwd=1) +
  scale_x_continuous(labels=dollar_format()) +
  theme_few()
```

Trouvons la valeur de la mediane : 

```{r}

full$Fare[1044] <- median(full[full$Pclass == '3' & full$Embarked == 'S', ]$Fare, na.rm = TRUE)

# full$Fare[1044]  a reçu comme valeur :

median(full[full$Pclass == '3' & full$Embarked == 'S', ]$Fare, na.rm = TRUE)
```
```{r}
summary(full$Fare)
```

Dans le cas contraire, nous allons calculer la mediane directement

```{r}
fare.pclass.na <- full$Pclass[is.na(full$Fare)]
fare.median <- median(full$Fare[full$Pclass==fare.pclass.na], na.rm = TRUE)
full[is.na(full$Fare), "Fare"] <- fare.median
summary(full$Fare)

```

Verifions l'existance d'un champs considere comme : " "

```{r}
colSums(full == '')
```

Nous remarquons qu il existe deux valeurs absence dans la variable Embarqued 

Essayons de trouver les valeurs qui correspondent à ces valeurs : 

```{r}
# filtrons les valeurs manquantes et excluons les du data frame
embark_fake <- full %>%
  filter(PassengerId != 62 & PassengerId !=830)
```
Resultat du filtre : les deux valeurs exclus

```{r}
colSums(embark_fake == '')
```

Essayons de visualiser tout cela avec boxplot

```{r}
ggplot(embark_fake, aes(x=Embarked, y=Fare, fill = factor(Pclass))) +
  geom_boxplot() +
  geom_hline(aes(yintercept = 80) , 
colours = 'red' , linetype = 'dashed' , lwd = 2) + 
  scale_y_continuous(labels = dollar_format())  + 
  theme_few()
```
On observe que la median port d embarquation C coinde avec le prix 8,5
 Donc on peut remplacer les variables manquantes par 'C'
 
 
```{r}
table(full$Embarked)
```

```{r}
full[full$Embarked == "", "Embarked"] <- "C"
full$Embarked[c(62, 830)] <- 'C'
table(full$Embarked)
full$Pclass[is.na(full$Pclass)] <- 'Adult'
```
 Regardons un peu la relation qui peut exister entre l age et survie, et considerons un peu que le sex est un predicateur significatif
 
 
```{r}
ggplot(full[1:891,], aes(Age, fill = factor(Survived))) +
  
  geom_histogram() + 
  
  facet_grid(.~Sex) +
  
  theme_few()

```


Vu que l age est significatif, separons cette variable en grande famille : les Adultes et les enfants

```{r}
full$class[full$Age < 18] <- 'Child'
full$class[full$Age > 18] <- 'Adult'

```
Essayons de regarder la classe et la survie 
```{r}
table(full$class,full$Survived)
```

```{r}
full$class <- as.factor(full$class)
# Make variables factors into factors
full$class <- as.factor(full$class)

full$Sex <- as.factor(full$Sex)
full$title <- as.factor(full$title)
full$FsizeD <- as.factor(full$FsizeD)
full$Embarked <- as.factor(full$Embarked)

# Set a random seed
set.seed(129)
```

Regardons sil existe encore des valeurs manquantes

```{r}
md.pattern(full)
```

```{r}
train <- full[1:891,]
test <- full[892:1309,]
train <- train[, colSums(is.na(train)) == 0]
survived.eq <- "factor(Survived) ~ Pclass + Sex + Age + SibSp + Parch + Fare + Embarked + title + FsizeD"
survived.formula <- as.formula(survived.eq)
```


Definissons les variables de notre modele : 


```{r}
model <- randomForest(formula = survived.formula, data = train, ntree = 500, 
                              mtry = 3, 
                              nodesize = 0.01 * nrow(train))

model1 <- randomForest(formula = survived.formula, 
                               data = train, 
                               ntree = 500, 
                               mtry = 3, 
                               nodesize = 0.01 * nrow(test))

model2 <- randomForest(formula = survived.formula, 
                               data = train, 
                               ntree = 1000, 
                               mtry = 3,
                               nodesize = 0.01 * nrow(train))

model3 <- randomForest(formula = survived.formula, 
                               data = train, 
                               ntree = 1000, 
                               mtry = 3, 
                               nodesize = 0.01 * nrow(test))
```

 Le hors-sac (OOB) erreur est l erreur moyenne pour chaque z_icalculées en utilisant les prédictions des arbres qui ne contiennent pas z_idans leur échantillon bootstrap respective. Cela permet à RandomForestClassifierêtre en forme et validée tout en étant formés

```{r}
       par(mfrow=c(2,2),oma=c(0,0,2,0))
plot(model)
plot(model1)
plot(model2)
plot(model3)
title(main="le taux d'erreur OOB(hors sac) pour chaque modele ",outer=TRUE)
       
```

 Regardons la matrice de confusion de chaque modele


```{r}
      model$confusion
```


```{r}
model1$confusion
```

```{r}
model2$confusion
```

```{r}
model3$confusion
```

Afiichons limportance de chaque variable sur un modele

```{r}
par(mfrow=c(2,2),oma=c(0,0,2,0))
varImpPlot(model)
varImpPlot(model1)
varImpPlot(model2)
varImpPlot(model3)
title(main="Importance by model",outer=TRUE)
```
```{r}

```




```{r}
acc <- 1-model$err.rate[nrow(model$err.rate),1]
acc1 <- 1-model1$err.rate[nrow(model1$err.rate),1]
acc2 <- 1-model2$err.rate[nrow(model1$err.rate),1]
acc3 <- 1-model3$err.rate[nrow(model1$err.rate),1]
acc_all <- rbind(acc,acc1,acc2,acc3)
plot(acc_all, main="Accuracy by model", col=c(1,2,3,4), pch=16)
legend("bottomright", legend=c("model", "model1", "model2", "model3"), cex=0.7, col=c(1,2,3,4), pch=16)
```

```{r}
importance <- importance(model)
importance1 <- importance(model1)
importance2 <- importance(model2)
importance3 <- importance(model3)
```



```{r}
varImportance <- data.frame(Variables = row.names(importance), 
                            Importance = round(importance[ ,'MeanDecreaseGini'],2))
# Create a rank variable based on importance
rankImportance <- varImportance %>%
  mutate(Rank = paste0('#',dense_rank(desc(Importance))))

# Use ggplot2 to visualize the relative importance of variables
ggplot(rankImportance, aes(x = reorder(Variables, Importance), 
    y = Importance, fill = Importance)) +
  geom_bar(stat='identity') + 
  geom_text(aes(x = Variables, y = 0.5, label = Rank),
    hjust=0, vjust=0.55, size = 4, colour = 'red') +
  labs(x = 'Variables') +
  coord_flip() + 
  theme_few()
```


```{r}
# Predict
predict1 <- predict(model,type="prob",newdata=train)[,2]
predict2 <- predict(model1,type="prob",newdata=train)[,2]
predict3 <- predict(model2,type="prob",newdata=train)[,2]
predict4 <- predict(model3,type="prob",newdata=train)[,2]

```


```{r}
# Prediction
rf.pred <- prediction(predict1, train$Survived)
rf.pred1 <- prediction(predict2, train$Survived)
rf.pred2 <- prediction(predict3, train$Survived)
rf.pred3 <- prediction(predict4, train$Survived)
```


```{r}
# Performance
tt.rf.perf <- performance(rf.pred,"tpr","fpr")
tt.rf.perf1 <- performance(rf.pred1,"tpr","fpr")
tt.rf.perf2 <- performance(rf.pred2,"tpr","fpr")
tt.rf.perf3 <- performance(rf.pred3,"tpr","fpr")
```


```{r}
# Calculate AUC
rf.auc <- performance(rf.pred,"auc")
rf.auc1 <- performance(rf.pred1,"auc")
rf.auc2 <- performance(rf.pred2,"auc")
rf.auc3 <- performance(rf.pred3,"auc")
```


```{r}
# Converting S4 class to vector
tt.rf.auc <- unlist(slot(rf.auc, "y.values"))
tt.rf.auc1 <- unlist(slot(rf.auc1, "y.values"))
tt.rf.auc2 <- unlist(slot(rf.auc2, "y.values"))
tt.rf.auc3 <- unlist(slot(rf.auc3, "y.values"))
auc <- rbind(tt.rf.auc,tt.rf.auc1,tt.rf.auc2,tt.rf.auc3)
auc
```


```{r}
# Minimum and Maximum AUC
minauc <- min(round(auc, digits = 4))
maxauc <- max(round(auc, digits = 4))
minauct <- paste(c("min(AUC) = "),minauc,sep="")
maxauct <- paste(c("max(AUC) = "),maxauc,sep="")
```



```{r}
plot(tt.rf.perf,main="ROC Curve for Random Forest",col=1,lwd=1) # Black
plot(tt.rf.perf1,col=2,lwd=1, add=TRUE) # Red
plot(tt.rf.perf2,col=3,lwd=1, add=TRUE) # Green
plot(tt.rf.perf3,col=4,lwd=1, add=TRUE) # Blue
abline(a=0,b=1,lwd=2,lty=2,col="gray")
legend('bottom',c(minauct,maxauct),cex=0.7, border = FALSE)
legend("bottomright", legend=c("model", "model1", "model2", "model3"), cex=0.7, col=c(1,2,3,4), lwd=1)
```


```{r}
titanic1.pred <- predict(model1, newdata = test)
titanic3.pred <- predict(model3, newdata = test)

PassengerId <- test$PassengerId

output1.df <- as.data.frame(PassengerId)
output3.df <- as.data.frame(PassengerId)

output1.df$Survived <- titanic1.pred
output3.df$Survived <- titanic3.pred

write.csv(output1.df, file="rf_model1.csv", row.names = FALSE)
write.csv(output3.df, file="rf_model3.csv", row.names = FALSE)
```