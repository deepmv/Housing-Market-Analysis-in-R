
R version 3.3.2 (2016-10-31) -- "Sincere Pumpkin Patch"
Copyright (C) 2016 The R Foundation for Statistical Computing
Platform: x86_64-apple-darwin13.4.0 (64-bit)

R is free software and comes with ABSOLUTELY NO WARRANTY.
You are welcome to redistribute it under certain conditions.
Type 'license()' or 'licence()' for distribution details.

  Natural language support but running in an English locale

R is a collaborative project with many contributors.
Type 'contributors()' for more information and
'citation()' on how to cite R or R packages in publications.

Type 'demo()' for some demos, 'help()' for on-line help, or
'help.start()' for an HTML browser interface to help.
Type 'q()' to quit R.

[R.app GUI 1.68 (7288) x86_64-apple-darwin13.4.0]

[Workspace restored from /Users/vaghanideep/.RData]
[History restored from /Users/vaghanideep/.Rapp.history]

> ---
title: "Boston Housing Market Analysis"
output:
  html_document: default
  word_document: default
---

```{r}
#Using import.io we scraped data from Redfin.com for all the houses with the limit they have. We scrpaed data using different zipcodes and merged the csv using terminal commands and use that as our main table.

#cleaning the Environment for fresh start
rm(list())
```

```{r}
#setting the workdirectory to get import the scraped csv into the work environment
setwd("/Users/vaghanideep/desktop")
```

```{r}
#improting main table in R environment which was scraped using import.io. 
Housingmain <- read.csv("main Data.csv")
```

```{r}
#Using zipcode package to clean zipcodes in mainhousing table so that R doesnt neglect the first "0" in zipcodes
library(zipcode)
Housingmain$ZIP <- clean.zipcodes(Housingmain$ZIP)
```

```{r}
#Creating Empty DataFrame to collect scraped data for the crime stats from moving.com
CrimeStats <- data.frame(Zipcode=character(), 
                         TotalCrimeRisk=numeric(), 
                        PersonalCrimeRisk=numeric(), 
                        PropertyCrimeRisk=numeric(), 
                        stringsAsFactors=FALSE)
```

```{r}
#List of zipcodes to be Scraped data for various zip codes from moving.com website.
View(Zipcodes) #Dataframe of thirty zipcodes used in project
```

```{r}
#Writing Function to get url from moving.com for various zipcode to scrape data from different urls.
mainurl <- function(zipcode) { 
  url <- paste("http://www.moving.com/real-estate/city-profile/results.asp?Zip=", zipcode, sep="")
  print(url)
}

```

```{r}
#Example Outputs
mainurl(02115)
```

```{r}
#Using Zipcode dataframe we just have to enter sequential number to get urls to scrape.
mainurl(Zipcodes[2,])
```

```{r}
mainurl(Zipcodes[3,])
```

```{r}
library(bitops)
library(xml2)
library(rvest)
library(stringr)

#Storing url generted from the above fucntion as "Crime"
Crime <- mainurl(02118)
Crime <- read_html(Crime)

#This will create the scrapelist for the url generated from the above function. 
scrapelist <- Crime %>% html_nodes("table:nth-child(7) td:nth-child(3) , table:nth-child(7) th:nth-child(3) , table:nth-child(7) .first_cpth , table:nth-child(7) td:nth-child(1) a") %>% html_text() %>% str_trim()

#This will fill the empty dataframe created with the scraped webpage information
scrapelist01 <- cbind(CrimeStats, scrapelist)

#This way after getting url from all the "30" zip codes of Boston we formed 30 "scrapelist01, scrapelist02....scrapelist30" and got table crimestats and renamed it to "Crimemain"" Dataframe

#After retreving all the scrapelist we renamed CrimeStats into Crimemain table and it has all the data we needed for the table
```

```{r}
#Removing "." from the column names of different data frames so that it will not trouble during quering in SQLite Database while retriving data.

names(Housingmain) <- gsub(x = names(Housingmain),
                         pattern = "\\.",
                         replacement = " ")
```

```{r}
names(Income) <- gsub(x = names(Income),
                         pattern = "\\.",
                         replacement = " ")
```

```{r}
names(Residential) <- gsub(x = names(Residential),
                        pattern = "\\.",
                        replacement = " ")
```

```{r}
names(Demographics) <- gsub(x = names(Demographics),
                         pattern = "\\.", replacement = " ")
```

```{r}
#Removing Whitespaces from the Dataframes
names(Housingmain) <- gsub(" ", "", names(Housingmain))
```

```{r}
names(Residential) <- gsub(" ", "", names(Residential))
```

```{r}
names(Income) <- gsub(" ", "", names(Income))
```

```{r}
names(Demographics) <- gsub(" ", "", names(Demographics))
```

```{r}
#Replacing NA values in main table to random unique values so that we can set listing.ID as Primary key during making database design.
Housingmain$LISTINGID[is.na(Housingmain$LISTINGID)] <- sample(1:4579, size=sum(is.na(Housingmain$LISTINGID)), replace=F)
```

```{r}
#Replacing NA in Days in Market column with the avg. number of days of the column so that intergrity of data is maintained and we can ask some of the questions in the project we had.

Housingmain$DAYSONMARKET[is.na(Housingmain$DAYSONMARKET)] <- round(mean(Housingmain$DAYSONMARKET, na.rm = TRUE))
```

Calcuating if there are any other NA in the Days on Market table
```{r}
sum(is.na(Housingmain$DAYSONMARKET))
```

```{r}
#Converting the data class of the price to numeric to make sure we can present on visual graphs for comperisions
Housingmain$PRICE <- as.numeric(Housingmain$PRICE)

#Removing unwanted columns in Income Dataframe
Income$X <- NULL
```

```{r}
#Converting population column in Demographics to interger from factors and replacing all "NA" to "0" 
Demographics$Population <- as.integer(Demographics$Population)
Demographics$Population[is.na(Demographics$Population)] <- 0
```

```{r}
#We are removing commas from the  population column in dataframe to convert it into numeric to get total population of Boston. 
Demographics$Population <- as.numeric(gsub(",","",Demographics$Population))
```

```{r}
sum(Demographics$Population)
#[1] 609167 Here the output validates our integrity of Data as the total population of Boston is around 630,000 and our data of population of different zipcodes comes to around that total.
```

Creating the Database using SQlite and Sqldf packages to store our Data.
```{r}
#Making Database of the extracted and shaped dataframes of the housig market using SQLite packages. Connecting them with the SQLite databases and querying required results.

library(proto)
library(gsubfn)
library(sqldf)
library(RSQLite)
library(sqldf)

BostonHousingMarket <- dbConnect(SQLite(), dbmane="BostonHouingMarket.sqlite")
dbWriteTable(conn = BostonHousingMarket, name="HousingMain", value = Housingmain, row.names=FALSE, overwrite=TRUE, field.types=NULL)

dbWriteTable(conn = BostonHousingMarket, name="Demographics", value = Demographics, row.names=FALSE, overwrite=TRUE, field.types=NULL)

dbWriteTable(conn = BostonHousingMarket, name="Income", value = Income, row.names=FALSE, overwrite=TRUE, field.types=NULL)

dbWriteTable(conn = BostonHousingMarket, name="Residential", value = Residential, row.names=FALSE, overwrite=TRUE, field.types=NULL)

dbWriteTable(conn = BostonHousingMarket, name="CrimeRate", value = Crimemain, row.names=FALSE, overwrite=TRUE, field.types=NULL)
```

Listing the tables we created in BostonHousingMarket Database
```{r}
dbListTables(BostonHousingMarket)
```

Listing the tables in Income table of Database
```{r}
dbListFields(BostonHousingMarket, "Income")
```

Listing the table in Main HousingMain table of the Database
```{r}
dbListFields(BostonHousingMarket, "HousingMain")
```

```{r}
dbGetQuery(conn = BostonHousingMarket, 'Select count(*) from Demographics')
```

Creating Dataframe of the Crimerisk vs zipcode vs price to get idea of how bad the crime is vs price in particular zipcode
```{r}
Crimeprice <- data.frame(dbGetQuery(conn = BostonHousingMarket, 
'Select CrimeRate.TotalCrimeRisk, CrimeRate.PersonalCrimeRisk, HousingMain.PRICE, HousingMain.ZIP, HousingMain.LOCATION, HousingMain.PROPERTYTYPE
                                     from CrimeRate
                                    left join HousingMain on 
                                    CrimeRate.Zipcode=HousingMain.ZIP 
order by CrimeRate.TotalCrimeRisk
                                   '))
                                   
```

```{r}
head(Crimeprice)
```

Creating dataframe of Public transportaion info vs zipode vs price to compare price vs public transportaion availability
```{r}
Publictransportation <- data.frame(dbGetQuery(conn = BostonHousingMarket, 
                                               'Select Residential.MedianTravelTimetoWork, Residential.TransportationtoWorkPublic, HousingMain.PRICE, HousingMain.ZIP, HousingMain.LOCATION, HousingMain.PROPERTYTYPE
                                               from Residential 
                                               left join HousingMain on 
                                               Residential.Zipcode=HousingMain.ZIP
                                              ORDER BY Residential.MedianTravelTimetoWork'
                                              ))
```

```{r}
head(Publictransportation)
```

Creating Dataframe of the population info versus the zipcode to get info on price vs population 
```{r}
Populasinfo <- data.frame(dbGetQuery(conn = BostonHousingMarket,                                               'Select Demographics.Population, Demographics.Male, Demographics.Female, HousingMain.ZIP, HousingMain.LOCATION, HousingMain.PRICE, HousingMain.PROPERTYTYPE
                from Demographics 
                left join HousingMain on                                                Demographics.Zipcode=HousingMain.ZIP 
Order by Demographics.Population'))
```

```{r}
head(Populasinfo)
```


