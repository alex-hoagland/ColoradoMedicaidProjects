/*******************************************************************************
* 	CODE SNIPPET: Merge this in with code files 1 and 1a
* Created by: Alex Hoagland

* Purpose: Pulls reason for Medicaid onto main enrollment file
		   
* Notes: 
		
* Key edits: 
   -  
*******************************************************************************/


***** 0. Packages and directories
global maindir "V:\raw\20.59_BU_Continuity_of_Medicaid\"
global birth "V:\Birth Records\working datasets\"
global temp "V:\Hoagland_Code\"

cd "V:\"
* set scheme unluttered
********************************************************************************


****** 1. Prepare income data to capture qualifying reasons for all Medicaid spells
use "V:\Planned Enrollment\fullsample_income.dta", clear
keep member_composite_id dob aid_desc elig_effect_strt elig_end_dt pct_fpl 
	// note: there are some records with same start date/qualifying reason, but 
	// different end dates--presumably an extension of some type?
	// I keep first income in this case (although these incomes are probably not 
	// going to be used).
collapse (first) pct_fpl (max) elig_end_dt, by(member_c dob aid_desc elig_effect_strt) fast

// there are 4,828 records with 2 qualifying types -- reshape to capture these. 
bysort member_c dob elig_effect_strt: gen test = _n
reshape wide aid_desc pct_fpl elig_end_dt, i(member_c dob elig_effect_strt) j(test)

compress
save "$temp\tomerge_qualifications.dta", replace
********************************************************************************


***** 2. Merge this in with my enrollment data
use "$temp\sampleenrollment_long.dta", clear
gen elig_effect_strt = date(eligibility_dt, "YMD")
format elig_effect_strt %td
merge m:1 member_c dob elig_effect_strt using "$temp\tomerge_qualifications.dta" 
order member_c-end_dt elig_effect_strt elig_end_dt1 aid_desc1-_merge
sort member_c dob elig_effect_strt

bysort member_c dob: carryforward elig_end_dt1, replace
bysort member_c dob: carryforward aid_desc1 pct_fpl1 if end_dt <= elig_end_dt1, replace
bysort member_c dob: carryforward elig_end_dt2, replace
bysort member_c dob: carryforward aid_desc2 pct_fpl2 if end_dt <= elig_end_dt2, replace

replace aid_desc1 = aid_desc2 if missing(aid_desc1) & !missing(aid_desc2) 
replace pct_fpl1 = pct_fpl2 if missing(pct_fpl1) & !missing(pct_fpl2)
replace aid_desc1 = "Commercial" if insurance_type == "Commercial" & missing(aid_desc1)

drop if _merge == 2 // used these only to get qualifying spells starting before observed period
drop _merge

drop elig_effect_strt elig_end_dt* // missing about 4% of Medicaid spells at this point
********************************************************************************


***** 3. Merge in pregnancy-qualifying income
cap drop income_pregqual
merge m:1 member_c dob using "$temp\tomerge.dta", keep(1 3) nogenerate

compress
save "$temp\sampleenrollment_long.dta", replace // remember there are about 10% of women without this income data yet. 
rm "$temp\tomerge_qualifications.dta"
********************************************************************************
