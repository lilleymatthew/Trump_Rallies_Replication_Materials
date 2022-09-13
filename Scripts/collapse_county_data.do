* Title: 	collapse_county_data.do
* Version: 	9 September 2019
* Author:	Matthew Lilley & Brian Wheaton
* Purpose: 	Import data from various files and collapse to county (state, county-month) level


*******************************************************************************
* (0) Start of file
*******************************************************************************

* Stata Version
version 15.1

* Set Working Directory
cd "C:/Users/mlilley/Dropbox/Trump Rallies"
*cd "C:\Dropbox\Trump Rallies"

capture log close
log using "Log Files/Trump_rallies_import.log", replace
set more off
clear all
macro drop _all

*******************************************************************************
* (1) Load data and Import
*******************************************************************************

** Trump Rallies

import delimited "Cleaned/rally_counties_merged.csv", delimiter(",") clear 

gen rallydate = date(date,"DMY")
gen monthyear = mofd(rallydate)
format monthyear %tm

gen fips = state_fips * 1000 + countyfips

* Collapse to Month-County Level
drop if year(rallydate) != 2016

gen count = 1
collapse (count) rallycount = count, by(fips monthyear state state_fips countyname countyfips)

save Intermediate/Trump_rallies.dta, replace


** Clinton Rallies

import delimited "Cleaned/clinton_rally_counties_merged.csv", delimiter(",") clear 

drop if candidatesinvolved == "Kaine"

gen rallydate = date(date,"DMY")
gen monthyear = mofd(rallydate)
format monthyear %tm

gen fips = state_fips * 1000 + countyfips

* Collapse to Month-County Level
drop if year(rallydate) != 2016

gen count = 1
collapse (count) rallycount = count, by(fips monthyear state state_fips countyname countyfips)

save Intermediate/Clinton_rallies.dta, replace


** ADL Hate Incidents
import delimited "Cleaned/ADL_data_counties.csv", delimiter(",") clear 

gen incidentdate = mdy(month,01,2016)
gen monthyear = mofd(incidentdate)
format monthyear %tm

* Fill State FIPS Data
bysort state_abbrev (state_fips): replace state_fips = state_fips[_n-1] if missing(state_fips)

gen fips = state_fips * 1000 + countyfips

* Collapse to Month-County Level
gen count = 1
collapse (count) incidentcount = count, by(fips monthyear state state_fips countyname countyfips)

save Intermediate/hate_incidents.dta, replace


** SPLC Hate Groups
import delimited "Cleaned/splc-hate-groups-2016.csv", delimiter(",") clear 

gen count = 1
collapse (count) hategroupscount = count, by(state)

save Intermediate/hate_groups.dta, replace


** Jewish Population (and Total Population)
import delimited "Cleaned/N-JewishMapUS_2011_MapData.csv", delimiter(",") clear 

keep fipscode bermanest censuspop10

* Remove Puerto Rico
drop if fipscode >= 72000

* Reset Placeholder Codes to Zero Population
*replace bermanest = 0 if bermanest == 49 | bermanest == 101

* Per Capita Jewish Population
gen jewishpopshare = bermanest / censuspop10

keep jewishpopshare censuspop10 fipscode
rename fipscode fips

save Intermediate/jewish_population.dta, replace


** College Education
import delimited "Cleaned/nhgis0001_ds215_20155_2015_county.csv", delimiter(",") clear 

gen fips = statea * 1000 + countya

* Remove Puerto Rico
drop if statea == 72

* Per Capita College Attainment (Bachelor's Degree or Higher)
gen collegeshare = (admze022 + admze023 + admze024 + admze025) / admze001

keep state statea county countya fips collegeshare

rename (countya statea) (countyfips state_fips)

save Intermediate/college_educated.dta, replace


** 2012 Presidential Election (Most states)
import delimited "Cleaned/County_Presidential_Election_Data_2012_0_0_2.csv", delimiter(",") clear  

destring state_fips countyfips willardmittromney totalvote, force replace

gen fips = state_fips * 1000 + countyfips

* Romney Vote Share
gen gop2012share = willardmittromney / totalvote

keep fips state_fips countyfips gop2012share

tempfile Returns_Minus_Alaska

save "`Returns_Minus_Alaska'"


** 2012 Presidential Election (Alaska)
import delimited "Cleaned/Alaska_Borough_Returns_2012.csv", delimiter(",") clear

replace romney = subinstr(romney,"%","",.)

destring romney, replace

replace romney = romney/100

rename romney gop2012share

gen fips = state_fips * 1000 + countyfips

keep fips state_fips countyfips gop2012share

append using "`Returns_Minus_Alaska'"

save Intermediate/presidential_election.dta, replace


** 2015 UCR Crime Data
use "Cleaned/UCR_2015_County_Data", clear

keep fips state_fips countyfips *rate

save Intermediate/crime_data, replace


** 2015 UCR Hate Crime Data
use "Cleaned/UCR_2016_County_Hate_Crimes_Monthly", clear

keep fips state_fips countyfips hate_crimes month

gen crimedate = mdy(month,01,2016)
gen monthyear = mofd(crimedate)
format monthyear %tm

save Intermediate/hate_crimes, replace


** Census Regions
import delimited "Cleaned/state-geocodes-v2017.csv", delimiter(",") varnames(6) clear

drop if statefips == 0

rename statefips state_fips

label define censusregions_lbl 1 "Northeast" 2 "Midwest"  3 "South" 4 "West", add
label values region censusregions_lbl

save Intermediate/census_regions.dta, replace


** Taco Bell Locations
use "Cleaned/Taco_Bell_Locations", clear

save Intermediate/taco_bell_locations, replace


** Urban Population Share
import delimited "Cleaned/nhgis0036_ds172_2010_county.csv", delimiter(",") clear 

gen fips = statea * 1000 + countya

* Remove Puerto Rico
drop if statea == 72

* Urban Population Share 
gen urbanshare = h7w002 / h7w001 

keep state statea county countya fips urbanshare

rename (countya statea) (countyfips state_fips)

save Intermediate/urban_share.dta, replace


*******************************************************************************
* (2) End of file
*******************************************************************************

log close
exit, clear

