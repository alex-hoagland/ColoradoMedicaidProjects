/*******************************************************************************
* Title: First stage regressions
* Created by: Alex Hoagland
* Created on: 4/21/2021
* Last modified on: 
* Last modified by: Alex Hoagland

* Purpose: 
		   
* Notes: 
		
* Key edits: 
   -  
*******************************************************************************/

***** 0. Directories & Packages
* ssc install psmatch2 

global sarah "\\ad.bu.edu\bumcfiles\BUMC Projects\ColoradoAPCD\Sarah\Sarah Datasets"
global working "\\ad.bu.edu\bumcfiles\BUMC Projects\ColoradoAPCD\Alex\Hoagland_WorkingData\Paper2"
global output "\\ad.bu.edu\bumcfiles\BUMC Projects\ColoradoAPCD\Alex\Hoagland_Output\4.HealthOutcomesPaper"
********************************************************************************


***** 1. Start with restrictive sample (IDs that are 100% only moms)
use "$working\FuzzyRDD_Limited_3.dta", clear
keep member_composite_id dob
bysort member_ (dob): gen j = _n
reshape wide dob, i(member_) j(j)
save "$working\RestrictedSample_Enrollees.dta", replace
********************************************************************************


***** 2. Go to enrollment file for these women 
merge 1:m member_* using "$sarah\enrollment 2014-19 females 19plus_exchange_merge.dta", ///
	keep(3) nogenerate 
sort member_composite_id member_id eligibility_dt
cap drop _merge

*** Keep only enrollment spells within 1 year after births
egen earlybirth = rowmin(dob*)
egen latebirth = rowmax(dob*)
gen ub = latebirth + 365

gen elig_start_dt = date(eligibility_dt, "YMD")
bysort member_composite_id member_id (eligibility_dt): gen elig_end_dt = elig_start_dt[_n+1]-1
drop if elig_start_dt > ub // all eligibility periods starting after 1 year pp
drop if elig_end_dt < earlybirth // all eligibility periods before birth

* Need to reshape to have each enrollment spell duplicated across multiple births -- may take a while
reshape long dob, i(member_composite_id member_id elig_start_dt elig_end_dt) j(birth_no)
drop if missing(dob) 

* Finally clean spells one more time by dates
replace ub = dob + 365
drop if elig_start_dt > ub // all eligibility periods starting after 1 year pp
drop if elig_end_dt < dob // all periods ending before birth 
order member_composite_id member_id birth_no dob elig_start_dt elig_end_dt
sort member_composite_id member_id birth_no elig_start_dt

* collapse to one observation per enrollment spell
replace payer_cd = -99 if missing(payer_cd) // so ID will be created properly
egen enrollment_id = group(member_composite_id member_id dob birth_no ///
	insurance_* line_of* payer_cd)
drop if missing(enrollment_id) // just 3 obs.	

replace elig_end_dt = elig_start_dt + 30 if missing(elig_end_dt) // if last enrollment spell, assume it is a month long
drop if elig_end_dt < dob // all eligibility periods before birth
collapse (min) elig_start_dt (max) elig_end_dt, /// 
	by(member_composite_id member_id dob ub birth_no insurance_* line_of* payer_cd enrollment_id) fast
	
* Drop births in 2019, since there isn't sufficient follow-up data
drop if year(dob) == 2019
********************************************************************************


***** Focus on those with continuous enrollment from 61-365 days for: 
***** (i) Medicaid only and (ii) commercial only
gen in_mdcd = (line_of_business_cd == 2)
gen in_comm = (line_of_business_cd == 3)

gen tot_duration_comm = 0
gen tot_duration_mdcd = 0
forvalues i = 61/365 {
	gen test = inrange(dob+`i',elig_start_dt,elig_end_dt)
	bysort member_composite_id dob: ereplace test = max(test) 
		// should just be 1 if there is any insurance in that date
	
	gen test2 = inrange(dob+`i',elig_start_dt,elig_end_dt) & in_comm == 1
	bysort member_composite_id dob: ereplace test2 = max(test2) 
		// count if there is any commercial enrollment on that date
	replace tot_duration_comm = tot_duration_comm + test2 if in_comm == 1
	replace tot_duration_mdcd = tot_duration_mdcd + test if in_mdcd == 1 & test2 == 0 
		// don't count those in both as in Medicaid
	drop test*
}

* Keep only those whose tot_duration_comm or tot_duration_mdcd == 305
keep if tot_duration_comm >= 305 | tot_duration_mdcd >= 305

gen group = (tot_duration_comm >= 305) // group is 1 for commercial
collapse (max) group, by(member_composite_id dob) fast
merge 1:1 member_c dob using "$working/FuzzyRDD_Limited_3.dta", keep(3) nogenerate

compress
save "$working/RestrictedSample_20210622.dta", replace
********************************************************************************
