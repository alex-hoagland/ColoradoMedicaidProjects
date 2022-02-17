/*******************************************************************************
* Title: Understanding changes in enrollment for women on Medicaid postpartum
* Created by: Alex Hoagland
* Created on: 12/11/2020
* Last modified on: 
* Last modified by: Alex Hoagland

* Purpose: Questions this is answering:
	(1) You kept all of the enrollment months within Member_Composite_ID, not within only Member_ID, for everyone who matched with the birth record, right? 
	(2) we should not see so many women >138% FPL on Medicaid postpartum. To look into who these women are, can you provide me with two things:
		1. frequency of 'AID_DESC', 'program_recode', 'fed_pov_lvl_desc' from the income file among all the women in the sample
		2. frequency of 'AID_DESC', 'program_recode', 'fed_pov_lvl_desc' specifically for (i) incomes 138-265% FPL 
																						  (ii) any Medicaid enrollment (only Medicaid, not both) 3-12 months pp 
	(3) sensitivity analysis of requiring at least 60 days/2 month enrollment during the postpartum period?
	(4) Do the graphs look any different excluding 2014?
		   
* Notes: 
		
* Key edits: 
   -  
*******************************************************************************/


***** 0. Packages and directories
* ssc install ftools, replace
* ssc install moremata, replace // (used in “collapse (median) …”)
* ssc install boottest, replace // (for Stata 11 and 12)
* ftools, compile // (if we want to use the Mata functions directly)

global maindir "V:\raw\20.59_BU_Continuity_of_Medicaid\"
global birth "V:\Birth Records\working datasets\"
global temp "V:\Hoagland_Code\"

cd "V:\"
* set scheme unluttered
********************************************************************************


***** 1. Making sure I didn't miss any enrollment months for those who matched with the birth record
use "$temp\sampleenrollment_long.dta", clear
keep if inrange(pct_fpl_month2, 140, 150)
save "$temp\tocompare.dta", replace // 54,778 observations in this enrollment file
keep member_
duplicates drop // 2,115 women

* Merge this to member IDs, not member composite IDs
merge 1:m member_composite_id using ///
	"$maindir/Member_to_Member_Composite_Crosswalk/Member_to_Member_Composite_Crosswalk.dta", ///
	keep(1 3) nogenerate
keep member_*
sort member_id

* Using ftools to go faster (since this is 1:m merge, use the "join" command with "into")
join , into("$maindir\Member_Eligibility\Member_Eligibility.dta") by(member_id) keep(2 3)
********************************************************************************


***** 2. Examine those on Medicaid > 138% FPL postpartum
use "V:\Planned Enrollment\fullsample_income.dta", clear
*** First, frequency of variables for all women
tab aid_desc, sort
tab program_recode, sort
tab fed_pov_lvl_desc

*** Second, frequency of variables for those (i) with incomes 138-265% FPL (ii) who had any Medicaid enrollment (only Medicaid, not both) 3-12 months postpartum? 
preserve
use "$birth\birth record 2014_2019 Medicaid only 19plus.dta", clear
keep if pct_fpl_month2 > 138 & pct_fpl_month2 < 265
gen tokeep = 0
forvalues i = 3/12 { 
	replace tokeep = 1 if enrollment_month`i' == "Medicaid"
} 
keep if tokeep == 1

keep member_ dob vsid
collapse (min) dob, by(member_) fast // for this analysis, just look at the *first* offending DOB within each woman
save "$temp\tomerge.dta", replace
restore

* Keep just those women and time periods
merge m:1 member_ using "$temp\tomerge.dta", keep(3) nogenerate // filter on women
gen test_date = dob + 90
format test_date %td
drop if elig_end_dt < test_date+30 // need at least 30 days
gen end_dt = dob + 365
drop if elig_effect_strt >= end_dt-30 // need at least 30 days of enrollment in the 3-12 months pp period
format end_dt %td

tab aid_desc, sort
tab program_recode, sort
tab fed_pov_lvl_desc
********************************************************************************


***** 2.1. How are women qualifying while pregnant? 
* Frequency at 9 months before dob 
preserve
keep if elig_effect_strt <= dob-274 & dob-274 <= elig_end_dt
bysort member_ dob vsid: keep if _n == 1 // drops 6,947 duplicate enrollments
tab aid_, sort
restore

* Frequency at 6 months before dob
preserve
keep if elig_effect_strt <= dob-183 & dob-183 <= elig_end_dt
bysort member_ dob vsid: keep if _n == 1 // drops 6,226 duplicate enrollments
tab aid_, sort
restore

* Frequency at 1 months before dob
preserve
keep if elig_effect_strt <= dob-30 & dob-30 <= elig_end_dt
bysort member_ dob vsid: keep if _n == 1 // drops 5,138 duplicate enrollments
tab aid_, sort
restore
********************************************************************************


***** 3. Sensitivity analysis: requiring enrollment for 60+ days in order to be counted
use "$temp\sampleenrollment_long.dta", clear

local lbs 2 3 4
local days 30 60 
foreach l of local lbs { 
	foreach d of local days { 
		preserve
		do "$temp\1_RD_PreChecks\2b_MakePlot1_Stratified.do" "`l'" "`d'"
		restore
	}
} 
********************************************************************************


***** 4. Sensitivity analysis: dropping 2014 (ACA implementation)
local lbs 2 3 4
local days 30 60 
foreach l of local lbs { 
	foreach d of local days { 
		preserve
		do "$temp\1_RD_PreChecks\2b_MakePlot1_Stratified.do" "`l'" "`d'" "_Missing2014"
		restore
	}
} 
********************************************************************************
