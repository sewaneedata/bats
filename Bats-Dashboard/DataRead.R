# Hallie Rutten, Monae Scott, Shelby Cline
# DataLab 2022, Sewanee Bat Study

#--PREP--######################################################################

# load libraries -----
library(tidyverse)
library(lubridate)
library(readxl)
library(scales)
library(plotly)
library(ggthemes)

#--BATS--######################################################################

# read bat acoustic data -----
bats <- readRDS('../../data-bats.RData')
#bats <- read.csv('../../data-bats.csv')

# calculate new vars -----
bats <- bats %>% 
  mutate(year = year(DATE), 
         monthN = month(DATE),
         month = month.abb[monthN],
         hour = hour(TIME),
         siteID = paste(COMPARTMENT,SITE, sep='_'),
         siteDate = paste(SITE, DATE),
         AUTO.ID = gsub("CORTOW", "CORRAF", AUTO.ID),
         AUTO.ID = ifelse(grepl('noID',AUTO.ID,ignore.case=TRUE),'no.ID',AUTO.ID) )
# Any bat listed as CORTOW should be listed as CORRAF (Amy text)

# cave status column -----
cave_obligate = c('MYOLEI','MYOAUS','MYOLUC','MYOSOD','MYOGRI','MYOSEP')
seasonal_cave_obligate = c('PERSUB',"EPTFUS", "CORRAF")
non_cave_obligate = c('LASBOR','NYCHUM','LASNOC','LASCIN')
bats <- bats %>%
  mutate( obligate = ifelse(AUTO.ID %in% cave_obligate, "cave obligate", AUTO.ID),
          obligate = ifelse(AUTO.ID %in% non_cave_obligate, "not cave obligate", obligate),
          obligate = ifelse(AUTO.ID %in% seasonal_cave_obligate, "seasonal cave obligate", obligate))

# species group column -----
EPTFUS.LASNOC = c("EPTFUS", "LASNOC")
LASBOR.NYCHUM = c("LASBOR", "NYCHUM")
bats <- bats %>% 
  mutate(ID_group = ifelse(grepl("^MYO", AUTO.ID), "MYOTIS", AUTO.ID),
         ID_group = ifelse(AUTO.ID %in% EPTFUS.LASNOC, "EPTFUS.LASNOC", ID_group),
         ID_group = ifelse(AUTO.ID %in% LASBOR.NYCHUM, "LASBOR.NYCHUM", ID_group))



#--SENSORS--###################################################################

# read sensor site and date data -----
sensors <- read_csv('../../sensorCSdates.csv', show_col_types=FALSE) 
sensors <- sensors %>% 
  mutate( siteID = gsub('-','_',siteID),
          LONGITUDE = -abs(LONGITUDE), 
          LATITUDE = abs(LATITUDE),
          habitat = toupper(habitat),
          habitat = gsub(" FOREST","",habitat),
          habitat = gsub("UNAMANAGED","UNMANAGED",habitat),
          habitat = gsub("UNAMANGED","UNMANAGED",habitat) )

# make each date one entry -----
sns <- sensors %>% select(-startDate,-endDate)
sensorDates <- data.frame()
for(i in 1:nrow(sensors) ){
  temp <- data.frame()
  if( is.na(sensors$endDate[i]) ){ sensors$endDate[i] <- as.Date(Sys.Date()) }
  DATE <- seq(sensors$startDate[i], sensors$endDate[i], by="days")
  temp <- data.frame(DATE)
  for(var in names(sns) ){
    temp[var] <- sns[i,which(names(sns)==var)]
  }
  sensorDates <- rbind(sensorDates,temp)
}
sensorDates <- distinct(sensorDates)

# join bats and sensor site data -----
bats <- left_join(bats,sensorDates, by=c('siteID','DATE'))

# clean environment -----
rm(sns,temp,DATE,i,var)



#--SPECIES--###################################################################

# read basic names -----
batspecies <- read_excel("../../BatSpecies.xlsx")

# join bats and species names data -----
bats <- left_join(bats,batspecies, by="AUTO.ID")

# group common names -----
bats <- bats %>% 
  mutate( group_common = ifelse(ID_group=="MYOTIS", "Genus Myotis", Common),
          group_common = ifelse(ID_group=="EPTFUS.LASNOC",
                                "Big Brown Bat/Silver-haired Bat",group_common),
          group_common = ifelse(ID_group=="LASBOR.NYCHUM",
                                "Red Bat/Evening Bat", group_common) )

# group scientific names -----
bats <- bats %>% 
  mutate( group_species = ifelse(ID_group=="MYOTIS", "Myotis species", Scientific),
          group_species = ifelse(ID_group=="EPTFUS.LASNOC",
                                "Eptesicus fuscus/Lasionycteris noctivagans", group_species),
          group_species = ifelse(ID_group=="LASBOR.NYCHUM",
                                "Lasiurus borealis/Nycticeius humeralis", group_species) )



#--WEATHER--###################################################################

# hourly weather data -----
weather.hourly <- read_xlsx("../../SUD Weather Station.xlsx", sheet=2) %>% 
  rename( AvgTemp = `Air Temp Avg (C)`,
          MaxWind = `wind speed (high) (m/s)`,
          MinWind = `wind speed (low) (m/s)`,
          rain = `Rain (mm)` ) %>% 
  mutate( DATE = date(Timestamp),
          year=year(Timestamp),
          monthN=month(Timestamp),
          month=month.abb[monthN],
          hour=hour(Timestamp),
          AvgWind = (MaxWind+MinWind)/2 ) %>% 
  select( DATE, year, month, monthN, hour, AvgWind, AvgTemp)

# recorded rain data -----
rain.hourly <- read_xlsx("../../SUD Weather Station.xlsx", sheet = 3) %>% 
  rename( rain.intensity = `Rain Intensity (mm/sec)` ) %>% 
  mutate( DATE = date(Timestamp),
          year=year(Timestamp),
          monthN=month(Timestamp),
          month=month.abb[monthN],
          hour=hour(Timestamp) ) %>% 
  select(-Timestamp)

# weather join -----
weather <- left_join( weather.hourly, rain.hourly, 
                      by=c('DATE','year','month','monthN','hour') )


