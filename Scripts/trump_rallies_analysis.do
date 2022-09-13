* Title: 	Trump_rallies_analysis.do
* Version: 	9 September 2019
* Author:	Matthew Lilley & Brian Wheaton
* Purpose: 	Merge collapsed data and run analysis


*******************************************************************************
* (0) Start of file
*******************************************************************************

* Stata Version
version 15.1

* Set Working Directory
cd "C:/Users/mlilley/Dropbox/Trump Rallies"
*cd "C:\Dropbox\Trump Rallies"

capture log close
log using "Log Files/Trump_rallies_analysis.log", replace
set more off
clear all
macro drop _all

set emptycells keep

*******************************************************************************
* (1) Load data and Import
*******************************************************************************

* College Education
use Intermediate/college_educated.dta, clear

label variable collegeshare "\% College"

* Jewish Population (and Total Population)
merge 1:1 fips using Intermediate/jewish_population.dta, keep(master match) nogenerate

label variable jewishpopshare "Jewish Pop. (p.c.)"

* 2012 Presidential Election 
merge 1:1 fips using Intermediate/presidential_election.dta, keep(master match) keepusing(gop2012share) nogenerate

label variable gop2012share "\% Rep. 2012" 

* SPLC Hate Groups
merge m:1 state using Intermediate/hate_groups.dta, keep(master match) nogenerate
* Fill Unmatched Data as Having No Hate Groups
replace hategroupscount = 0 if missing(hategroupscount)

label variable hategroupscount "# Hate Groups"

* Expand Data Set by Month
expand 12
bysort fips: gen month = _n

label define month_lbl 1 "January" 2 "February"  3 "March" 4 "April" 5 "May" 6 "June" 7 "July" 8 "August" 9 "September" 10 "October" 11 "November" 12 "December", add
label values month month_lbl

gen monthyear = mofd(mdy(month,01,2016))
format monthyear %tm

* Trump Rallies
merge 1:1 fips monthyear using Intermediate/Trump_rallies.dta, keep(master match) keepusing(rallycount) nogenerate
rename rallycount trumprallycount
* Fill Unmatched Data as Having Zero Rallies
replace trumprallycount = 0 if missing(trumprallycount)

label variable trumprallycount "Trump Rally Count"

* Clinton Rallies
merge 1:1 fips monthyear using Intermediate/Clinton_rallies.dta, keep(master match) keepusing(rallycount) nogenerate
rename rallycount clintonrallycount
* Fill Unmatched Data as Having Zero Rallies
replace clintonrallycount = 0 if missing(clintonrallycount)

label variable clintonrallycount "Clinton Rally Count"

* ADL Hate Incidents
merge 1:1 fips monthyear using Intermediate/hate_incidents.dta, keep(master match) keepusing(incidentcount) nogenerate
* Fill Unmatched Data as Having Zero Incidents
replace incidentcount = 0 if missing(incidentcount)

label variable incidentcount "Hate Incidents"

* FBI Hate Crimes
merge 1:1 fips monthyear using Intermediate/hate_crimes.dta, keep(master match) keepusing(hate_crimes) nogenerate
* Fix NYC
gen NYCcounty = inlist(fips,36061,36081,36085,36047,36005)
gen NotManhattan = (fips != 36061) if NYCcounty == 1
summarize censuspop10 if (NYCcounty == 1 & month == 1)
local NYC_pop = r(mean) * r(N) 
// Initially apply entire NYC data for month to all NYC counties
bysort NYCcounty monthyear (NotManhattan hate_crimes): replace hate_crimes = hate_crimes[_n-1] if NYCcounty == 1 & _n != 1
// Population weight
replace hate_crimes = round(hate_crimes * censuspop10 / `NYC_pop') if NYCcounty == 1
* Fill Unmatched Data as Having Zero Hate Crimes
replace hate_crimes = 0 if missing(hate_crimes)

label variable hate_crimes "Hate Crimes"

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

label variable violent_crime_rate "Violent Crime"
label variable property_crime_rate "Property Crime"

* Census Regions
merge m:1 state_fips using Intermediate/census_regions.dta, keep(master match) keepusing(region division) nogenerate

* Share Urban
merge m:1 fips using Intermediate/urban_share.dta, keep(master match) nogenerate

** Rally Time Structure
// Initially (as per WP) used occurence of rally YTD
// Now use rally prior month (set Jan to 0, not missing, ignore Dec 2020 rallies - seems to be what they say they did)

* Presence of Trump Rally - Time Structure
bysort fips (monthyear): gen trumprallyyet = sum(trumprallycount) > 0 

bysort fips (monthyear): gen trumprallyprevious = trumprallycount[_n-1] > 0 if !missing(trumprallycount[_n-1])
replace trumprallyprevious = 0 if missing(trumprallyprevious)

gen trumprallyoccured = trumprallyprevious
label variable trumprallyoccured "Trump Rally"

* Presence of Clinton Rally - Time Structure
bysort fips (monthyear): gen clintonrallyyet = sum(clintonrallycount) > 0 

bysort fips (monthyear): gen clintonrallyprevious = clintonrallycount[_n-1] > 0 if !missing(clintonrallycount[_n-1])
replace clintonrallyprevious = 0 if missing(clintonrallyprevious)

gen clintonrallyoccured = clintonrallyprevious
label variable clintonrallyoccured "Clinton Rally"

* Taco Bell Locations
merge m:1 fips using Intermediate/Taco_Bell_Locations, keep(master match) keepusing(taco_bell_locations) nogenerate
replace taco_bell_locations = 0 if taco_bell_locations == .

label variable taco_bell_locations "Restaurants"

*******************************************************************************
* (2) Regression Analysis
*******************************************************************************

* Negative Binomial Regressions
nbreg incidentcount trumprallyoccured collegeshare jewishpopshare gop2012share hategroupscount violent_crime_rate property_crime_rate ib(11).month ib(4).region, dispersion(mean) vce(cluster fips)
estimates store nb_baseline_trump

predict incident_hat if e(sample) == 1, xb

nbreg incidentcount clintonrallyoccured collegeshare jewishpopshare gop2012share hategroupscount violent_crime_rate property_crime_rate ib(11).month ib(4).region, dispersion(mean) vce(cluster fips)
estimates store nb_baseline_clinton

* Control for (Log) County Population
gen log_pop = ln(censuspop10)
label variable log_pop "Population (Log)"

nbreg incidentcount trumprallyoccured collegeshare jewishpopshare gop2012share hategroupscount violent_crime_rate property_crime_rate log_pop ib(11).month ib(4).region, dispersion(mean) vce(cluster fips)
estimates store nb_population_trump

nbreg incidentcount clintonrallyoccured collegeshare jewishpopshare gop2012share hategroupscount violent_crime_rate property_crime_rate log_pop ib(11).month ib(4).region, dispersion(mean) vce(cluster fips)
estimates store nb_population_clinton

* Control for Urban Population Share
label variable urbanshare "\% Urban Population"

nbreg incidentcount trumprallyoccured collegeshare jewishpopshare gop2012share hategroupscount violent_crime_rate property_crime_rate urbanshare ib(11).month ib(4).region, dispersion(mean) vce(cluster fips)
estimates store nb_urban_trump

nbreg incidentcount clintonrallyoccured collegeshare jewishpopshare gop2012share hategroupscount violent_crime_rate property_crime_rate urbanshare ib(11).month ib(4).region, dispersion(mean) vce(cluster fips)
estimates store nb_urban_clinton

* Control for Population and Urban Population Share
nbreg incidentcount trumprallyoccured collegeshare jewishpopshare gop2012share hategroupscount violent_crime_rate property_crime_rate urbanshare log_pop ib(11).month ib(4).region, dispersion(mean) vce(cluster fips)
estimates store nb_both_trump

nbreg incidentcount clintonrallyoccured collegeshare jewishpopshare gop2012share hategroupscount violent_crime_rate property_crime_rate urbanshare log_pop ib(11).month ib(4).region, dispersion(mean) vce(cluster fips)
estimates store nb_both_clinton

* Output
coefplot (nb_baseline_trump, color(red) ciopts(lcolor(red)) msymbol(O) keep(trumprallyoccured) eform label("Trump Effect (Baseline)")) (nb_baseline_clinton, color(blue) ciopts(lcolor(blue)) msymbol(O) keep(clintonrallyoccured) eform label("Clinton Effect (Baseline)")) (nb_urban_trump, color(red) ciopts(lcolor(red)) msymbol(D) keep(trumprallyoccured) eform label("Trump Effect (\% Urban Control)")) (nb_urban_clinton, color(blue) ciopts(lcolor(blue)) msymbol(D) keep(clintonrallyoccured) eform label("Clinton Effect (\% Urban Control)")) (nb_population_trump, color(red) ciopts(lcolor(red)) msymbol(T) keep(trumprallyoccured) eform label("Trump Effect (Pop. Control)")) (nb_population_clinton, color(blue) ciopts(lcolor(blue)) msymbol(T) keep(clintonrallyoccured) eform label("Clinton Effect (Pop. Control)")) (nb_both_trump, color(red) ciopts(lcolor(red)) msymbol(S) keep(trumprallyoccured) eform label("Trump Effect (Urban, Pop. Controls)")) (nb_both_clinton, color(blue) ciopts(lcolor(blue)) msymbol(S) keep(clintonrallyoccured) eform label("Clinton Effect (Urban, Pop. Controls)")), vertical omitted scheme(sj) xlabel(, nolabels notick) graphregion(color(white)) ytitle("Effect Size") title("Rally Effects in the Six Models") ylabel(1 "0%" 2 "100%" 3 "200%" 4 "300%" 5 "400%" 6 "500%" 7 "600%", angle(horizontal))
graph export "Figures/Rally_Effects.png", width(1024) height(768) replace

est table nb_*, stats(r2_p ll N) b(%9.4f) se(%9.4f) varlabel keep(trumprallyoccured clintonrallyoccured) modelwidth(18)

esttab nb_* using "Tables/Rally_Effects_Replication.tex", cells(b(star fmt(%9.4f)) se(par fmt(%9.4f))) ///
noomitted nobaselevels order(trumprallyoccured clintonrallyoccured log_pop jewishpopshare hategroupscount violent_crime_rate property_crime_rate gop2012share collegeshare *.region *.month) stats(r2_p ll N, fmt(%9.4f %9.2f %9.0g) labels("Pseudo R-squared" "Log Likelihood" "Observations")) legend label ///
style(tex) starlevels(* 0.10 ** 0.05 *** 0.01) mlabels(, depvars) collabels(none) title("Replication of Base Specification - Trump and Clinton Rally Effects") replace

estimates clear

* Fitted Value in Original Paper
gen incident_hat_feinberg = 1.182 * trumprallyoccured + 0.0002 * 100000 * jewishpopshare + 0.021 * hategroupscount + 0.009 * violent_crime_rate - 0.002 * property_crime_rate - 0.047 * 100 * gop2012share + 0.052 * 100 * collegeshare + 0.589 * (region == 1) - 0.410 * (region == 2) - 0.634 * (region == 3) - 0.940 * (month == 1) - 0.992 * (month == 2) - 0.388 * (month == 3) - 0.722 * (month == 4) - 0.755 * (month == 5) -0.745 * (month == 6) - 1.182 * (month == 7) -0.947 * (month == 8) - 0.931 * (month == 9) - 0.684 * (month == 10) - 0.442 * (month == 12) - 3.137 

correlate incident_hat_feinberg incident_hat

*******************************************************************************
* (3) Regression Analysis - FBI Hate Crimes
*******************************************************************************

* Negative Binomial Regressions
nbreg hate_crimes trumprallyoccured collegeshare jewishpopshare gop2012share hategroupscount violent_crime_rate property_crime_rate ib(11).month ib(4).region, dispersion(mean) vce(cluster fips)
estimates store nb_baseline_trump

nbreg hate_crimes clintonrallyoccured collegeshare jewishpopshare gop2012share hategroupscount violent_crime_rate property_crime_rate ib(11).month ib(4).region, dispersion(mean) vce(cluster fips)
estimates store nb_baseline_clinton

nbreg hate_crimes trumprallyoccured collegeshare jewishpopshare gop2012share hategroupscount violent_crime_rate property_crime_rate log_pop ib(11).month ib(4).region, dispersion(mean) vce(cluster fips)
estimates store nb_population_trump

nbreg hate_crimes clintonrallyoccured collegeshare jewishpopshare gop2012share hategroupscount violent_crime_rate property_crime_rate log_pop ib(11).month ib(4).region, dispersion(mean) vce(cluster fips)
estimates store nb_population_clinton

coefplot (nb_baseline_trump, color(red) ciopts(lcolor(red)) keep(trumprallyoccured) eform label("Trump Effect (Baseline)")) (nb_baseline_clinton, color(blue) ciopts(lcolor(blue)) keep(clintonrallyoccured) eform label("Clinton Effect (Baseline)")) (nb_population_trump, color(red) ciopts(lcolor(red)) keep(trumprallyoccured) eform label("Trump Effect (Pop. Control)")) (nb_population_clinton, color(blue) ciopts(lcolor(blue)) keep(clintonrallyoccured) eform label("Clinton Effect (Pop. Control)")), vertical omitted scheme(sj) xlabel(, nolabels notick) graphregion(color(white)) ytitle("Effect Size") title("Rally Effects in the Four Models") ylabel(1 "0%" 2 "100%" 3 "200%" 4 "300%" 5 "400%" 6 "500%" 7 "600%", angle(horizontal))
graph export "Figures/Rally_Effects_FBI_Hate.png", width(1024) height(768) replace

esttab nb_* using "Tables/Rally_Effects_FBI_Hate_Crimes.tex", cells(b(star fmt(%9.4f)) se(par fmt(%9.4f))) ///
noomitted nobaselevels order(trumprallyoccured clintonrallyoccured log_pop jewishpopshare hategroupscount violent_crime_rate property_crime_rate gop2012share collegeshare *.region *.month) stats(r2_p ll N, fmt(%9.4f %9.2f %9.0g) labels("Pseudo R-squared" "Log Likelihood" "Observations")) legend label ///
style(tex) starlevels(* 0.10 ** 0.05 *** 0.01) mlabels(, depvars) collabels(none) title("Base Specification with FBI Hate Crime Data") replace

estimates clear

*******************************************************************************
* (4) Regression Analysis - Pre-Rally Effects
*******************************************************************************

* Locations with Trump Rally, Pre-Rally
bysort fips (monthyear): gen trumpeverrally = trumprallyyet[_N]
gen beforetrumprally = trumpeverrally - trumprallyyet 

label variable beforetrumprally "Future Trump Rally"

* Locations with Clinton Rally, Pre-Rally
bysort fips (monthyear): gen clintoneverrally = clintonrallyyet[_N]
gen beforeclintonrally = clintoneverrally - clintonrallyyet 

label variable beforeclintonrally "Future Clinton Rally"

* Negative Binomial Regressions
nbreg incidentcount beforetrumprally collegeshare jewishpopshare gop2012share hategroupscount violent_crime_rate property_crime_rate ib(11).month ib(4).region, dispersion(mean) vce(cluster fips)
estimates store nb_baseline_trump

nbreg incidentcount beforeclintonrally collegeshare jewishpopshare gop2012share hategroupscount violent_crime_rate property_crime_rate ib(11).month ib(4).region, dispersion(mean) vce(cluster fips)
estimates store nb_baseline_clinton

est table nb_*, stats(r2_p ll N) b(%9.4f) se(%9.4f) varlabel keep(beforetrumprally beforeclintonrally) modelwidth(18)

esttab nb_* using "Tables/Future_Rally_Effects.tex", cells(b(star fmt(%9.4f)) se(par fmt(%9.4f))) ///
noomitted nobaselevels keep(beforetrumprally beforeclintonrally) stats(r2_p ll N, fmt(%9.4f %9.2f %9.0g) labels("Pseudo R-squared" "Log Likelihood" "Observations")) legend label ///
style(tex) starlevels(* 0.10 ** 0.05 *** 0.01) mlabels(, depvars) collabels(none) title("Falsification Test - Future Rally Effects on Past Hate Incidents") replace

estimates clear

*******************************************************************************
* (5) Regression Analysis - Taco Bell Effects, Population Specification
*******************************************************************************

* Scale Population Level
gen censuspop10_k = censuspop10 / 1000

label variable censuspop10_k "Population ('000)"

* Negative Binomial Regression, No Population Control
nbreg taco_bell_locations trumprallyoccured collegeshare jewishpopshare gop2012share hategroupscount violent_crime_rate property_crime_rate ib(11).month ib(4).region, dispersion(mean) vce(cluster fips)
estimates store nb_baseline_trump

* Negative Binomial Regression, Population Level Control
nbreg taco_bell_locations trumprallyoccured collegeshare jewishpopshare gop2012share hategroupscount violent_crime_rate property_crime_rate censuspop10_k ib(11).month ib(4).region, dispersion(mean) vce(cluster fips) difficult
estimates store nb_pop_level_trump

* Negative Binomial Regression, Population Log Control
nbreg taco_bell_locations trumprallyoccured collegeshare jewishpopshare gop2012share hategroupscount violent_crime_rate property_crime_rate log_pop ib(11).month ib(4).region, dispersion(mean) vce(cluster fips)
estimates store nb_pop_log_trump

est table nb_*, stats(r2_p ll N) b(%9.4f) se(%9.4f) varlabel keep(trumprallyoccured) modelwidth(18)

esttab nb_* using "Tables/Rally_Effects_Taco_Bell.tex", cells(b(star fmt(%9.4f)) se(par fmt(%9.4f))) ///
noomitted nobaselevels keep(trumprallyoccured censuspop10_k log_pop) stats(r2_p ll N, fmt(%9.4f %9.2f %9.0g) labels("Pseudo R-squared" "Log Likelihood" "Observations")) legend label ///
style(tex) starlevels(* 0.10 ** 0.05 *** 0.01) mlabels(, depvars) collabels(none) title("Falsification Test - Rally Effects on Taco Bell Locations") replace

estimates clear

// The specification using the level of population uses a different convergence 
// setting - standard method often gets stuck for this regression.

*******************************************************************************
* (6) Regression Analysis - Difference in Differences
*******************************************************************************

xtset fips

* Poisson Fixed Effects Regressions
xtpoisson incidentcount trumprallyoccured ib(11).month, fe r
estimates store did_hateincidents_trump

xtpoisson hate_crimes trumprallyoccured ib(11).month, fe r
estimates store did_hatecrimes_trump

xtpoisson incidentcount clintonrallyoccured ib(11).month, fe r
estimates store did_hateincidents_clinton

xtpoisson hate_crimes clintonrallyoccured ib(11).month, fe r
estimates store did_hatecrimes_clinton

est table did_*, stats(ll N) b(%9.4f) se(%9.4f) varlabel keep(trumprallyoccured clintonrallyoccured) modelwidth(18)

esttab did_* using "Tables/Rally_Effects_DiD.tex", cells(b(star fmt(%9.4f)) se(par fmt(%9.4f))) ///
noomitted nobaselevels keep(trumprallyoccured clintonrallyoccured) indicate("Month FE = *.month") stats(ll N, fmt(%9.2f %9.0g) labels("Log Likelihood" "Observations")) legend label ///
style(tex) starlevels(* 0.10 ** 0.05 *** 0.01) mlabels(, depvars) collabels(none) title("Difference in Differences Estimates") replace

export delimited full_data.csv, replace

estimates clear

*******************************************************************************
* (6) End of file
*******************************************************************************

log close
exit, clear

