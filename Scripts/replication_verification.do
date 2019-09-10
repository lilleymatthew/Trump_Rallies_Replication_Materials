* Title: 	replication_cerification.do
* Version: 	04 September 2019
* Author:	Matthew Lilley & Brian Wheaton
* Purpose: 	Summary statistics of data used in replication


*******************************************************************************
* (0) Start of file
*******************************************************************************

* Stata Version
version 15.1

* Set Working Directory
*cd "C:/Users/mlilley/Documents/Interesting Questions/Trump Rallies"
cd "C:/Users/mlilley/Dropbox/Trump Rallies"
*cd "C:\Dropbox\Trump Rallies"


capture log close
log using "Log Files/Trump_rallies_data_verification.log", replace
set more off
clear all
macro drop _all

set emptycells keep

*******************************************************************************
* (1) Load data and Import
*******************************************************************************

* College Education
use Intermediate/college_educated.dta, clear

* Jewish Population (and Total Population)
merge 1:1 fips using Intermediate/jewish_population.dta, keep(master match) nogenerate

* 2012 Presidential Election 
merge 1:1 fips using Intermediate/presidential_election.dta, keep(master match) keepusing(gop2012share) nogenerate

* SPLC Hate Groups
merge m:1 state using Intermediate/hate_groups.dta, keep(master match) nogenerate
* Fill Unmatched Data as Having No Hate Groups
replace hategroupscount = 0 if missing(hategroupscount)

* Expand Data Set by Month
expand 12
bysort fips: gen month = _n

gen monthyear = mofd(mdy(month,01,2016))
format monthyear %tm

* Trump Rallies
merge 1:1 fips monthyear using Intermediate/Trump_rallies.dta, keep(master match) keepusing(rallycount) nogenerate
rename rallycount trumprallycount
* Fill Unmatched Data as Having Zero Rallies
replace trumprallycount = 0 if missing(trumprallycount)

** Clinton Rallies
merge 1:1 fips monthyear using Intermediate/Clinton_rallies.dta, keep(master match) keepusing(rallycount) nogenerate
rename rallycount clintonrallycount
* Fill Unmatched Data as Having Zero Rallies
replace clintonrallycount = 0 if missing(clintonrallycount)

* ADL Hate Incidents
merge 1:1 fips monthyear using Intermediate/hate_incidents.dta, keep(master match) keepusing(incidentcount) nogenerate
* Fill Unmatched Data as Having Zero Incidents
replace incidentcount = 0 if missing(incidentcount)

* Crime
merge m:1 fips using Intermediate/crime_data.dta, keep(master match) keepusing(violent_crime_rate property_crime_rate) nogenerate
* Fix NYC
summarize violent_crime_rate if fips == 36061
local nyc_violent = r(mean)
summarize property_crime_rate if fips == 36061
local nyc_property = r(mean)
replace violent_crime_rate = `nyc_violent' if state_fips == 36 & violent_crime_rate == .
replace property_crime_rate = `nyc_property' if state_fips == 36 & property_crime_rate == .

replace violent_crime_rate = 0 if violent_crime_rate == .
replace property_crime_rate = 0 if property_crime_rate == .

* Census Regions
merge m:1 state_fips using Intermediate/census_regions.dta, keep(master match) keepusing(region division) nogenerate

* Presence of Trump Rally - Time Structure
bysort fips (monthyear): gen trumprallyoccured = sum(trumprallycount) > 0 

* Presence of Clinton Rally - Time Structure
bysort fips (monthyear): gen clintonrallyoccured = sum(clintonrallycount) > 0 


*******************************************************************************
* (2) Data Verification
*******************************************************************************

* Trump Rally-Month Pairs
tab trumprallycount

* Summary statistics of variables in regression
summarize incidentcount trumprallyoccured collegeshare jewishpopshare gop2012share hategroupscount violent_crime_rate property_crime_rate

* Population Differences by Presence of Rally (Ever)
bysort fips (trumprallyoccured): keep if _n == _N
table trumprallyoccured, contents(mean censuspop10)

*******************************************************************************
* (3) End of file
*******************************************************************************

log close
exit, clear

