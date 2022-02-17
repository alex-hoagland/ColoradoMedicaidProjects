/*******************************************************************************
* Title: Make Outcome Variables
* Created by: Alex Hoagland
* Created on: 2/11/2021
* Last modified on: 2/11/2021
* Last modified by: Alex Hoagland

* Purpose: 
		   
* Notes: 
		
* Key edits: 
   -  
*******************************************************************************/


***** 0. Packages and directories, load data
* ssc install binscatter

global head "\\ad.bu.edu\bumcfiles\BUMC Projects\ColoradoAPCD"
global sarah "$head\Sarah\Sarah Datasets"
global working "$head\Alex\Hoagland_WorkingData"
global output "$head\Alex\Hoagland_Output\1.CovariateSmoothness"

use "$working\APCD_MedicaidDelivery_Sample_WithIncome_20210304.dta", clear
********************************************************************************


***** 1. Outcome variables
gen outcome1 = !missing(in_mdcd) // any enrollment in the year postpartum
gen outcome2 = in_comm // note: all outcomes from here on have missing values for dropouts
gen outcome3 = tot_duration // duration of coverage (in days)
gen outcome4 = disrupt // probability of disruptions
gen outcome5 = gap // count of gaps 
gen outcome9 = any_gap // likelihood of any gap
gen outcome6 = gap_length // length (in days) of all gaps

label var outcome1  "Any enrollment pp"
label var outcome2 "Pr(Any commercial enrollment pp)"
label var outcome3 "Duration of enrollment pp"
label var outcome4 "Any coverage disruption pp"
label var outcome5 "Number of pp coverage gaps"
label var outcome9 "Pr(Any coverage gaps)"
label var outcome6 "Gap duration (% of postpartum year)"

// change duration to months, not days
replace outcome3 = outcome3/30 
replace outcome6 = outcome6/365*100 // change to fraction of year 

compress
save "$working\EnrollmentRD.dta", replace
********************************************************************************


***** 2. Pull in Marketplace identifiers
keep member_composite_id dob 
bysort member_composite_id (dob): gen j = _n
reshape wide dob, i(member_composite_id) j(j)
merge 1:m member_composite_id using ///
	"$sarah\enrollment 2014-19 females 19plus_exchange_merge", ///
	keep(3) nogenerate
	
*** Max of exchange_offering within plan, + any with populated metal tier
gen exflag = (exchange_offering == "Y")
bysort member_id: ereplace exflag = max(exflag)
replace exflag = 1 if exflag == 0 & !missing(metallic_value) & metallic_value > 0

*** Reshape those with marketplace coverage
drop if exflag == 0
bysort member_composite_id member_id plan_effective_dt eligibility_dt: gen test = _n
drop if test == 2 // 5 observations that aren't unique
reshape long dob, i(member_composite_id member_id plan_effective_dt eligibility_dt) j(birth_no)

*** Keep only claims that have eligibility_dts w/in postpartum year
drop if missing(dob) | plan_effective_dt_year < year(dob) - 1
gen elig_start_dt = date(eligibility_dt, "YMD")
keep if inrange(elig_start_dt, dob,dob+365)

** Collapse to max of flag and metallic tier for each birth
collapse (max) exflag metallic_value, by(member_composite_id dob) fast
merge 1:1 member_composite_id dob using "$working\EnrollmentRD.dta", keep(2 3) nogenerate
********************************************************************************


***** 3. Add in outcomes for specific (mutually exclusive) enrollment types
gen outcome7 = in_mdcd_only
gen outcome8 = (exflag == 1) 
replace outcome8 = . if outcome1 == 0
replace outcome2 = 0 if outcome8 == 1 & !missing(outcome2)

label var outcome7 "Pr(Only Medicaid enrollment pp)"
label var outcome8 "Pr(Any Marketplace enrollment pp)"

compress
forvalues i = 1/9 { 
	order outcome`i', last
}
save "$working\EnrollmentRD.dta", replace
********************************************************************************