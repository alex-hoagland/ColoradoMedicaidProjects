/*******************************************************************************
* Title: Merge delivery information and enrollment file
* Created by: Alex Hoagland
* Created on: 1/23/2021
* Last modified on: March 2021
* Last modified by: Alex Hoagland

* Purpose: Provides summary infor for (i) full year pp and (ii) 3-12 months pp: 	
	- Proportion and N of sample who had any Medicaid
	- Proportion and N of sample who had any commercial enrollment
	- Mean months of postpartum commercial and Medicaid enrollment
	- Proportion and N who we lose from the data altogether postpartum 
		(they are either uninsured or they went to a plan that isn't in the APCD)
		
* Notes: 
		
* Key edits: 
   -  2.11.2021: updated duration measures to "tot_duration*" variables
	   - these account for the fact that some spells overlap, and constructs a 
		 measure of the total days during a span that a birth record has coverage
		 of a certain type
   -  2.11.2021: added a measure of coverage disruption
   -  2.25.2021: added (i) count of gaps and (ii) duration of gaps
   -  3.3.2021: added measure of outcome variables for the 0-2 months postpartum window
*******************************************************************************/

***** 0. Directories & Packages 
global head "\\ad.bu.edu\bumcfiles\BUMC Projects\ColoradoAPCD"
global sarah "$head\Sarah\Sarah Datasets"
global working "$head\Alex\Hoagland_WorkingData\Paper1"
global output "$head\Alex\Hoagland_Output\0.SampleDefinition"
********************************************************************************


***** 1. Prep and merge data
use "$working\APCD_MedicaidDelivery_Sample_IDsOnly.dta", clear

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
	
* generate enrollment duration in days
gen duration = min(ub, elig_end_dt) - max(elig_start_dt, dob)

// A (slow) way to aggregate duration across multiple potentially overlapping spells
gen tot_duration = 0
forvalues i = 0/364 {
	gen test = inrange(dob+`i',elig_start_dt,elig_end_dt)
	bysort member_composite_id dob: ereplace test = max(test)
	replace tot_duration = tot_duration + test
	drop test
}
********************************************************************************	


***** 2. Identify outcomes in the 0-12 month window
* Proportion and N of sample who had any Medicaid
gen in_mdcd = (line_of_business_cd == 2)

* Proportion and N of sample who had any commercial enrollment
gen in_comm = (line_of_business_cd == 3)

* Mean months of postpartum commercial and Medicaid enrollment
gen duration_comm = duration if in_comm == 1
gen duration_mdcd = duration if in_mdcd == 1

// A (slow) way to aggregate duration across multiple potentially overlapping spells
gen tot_duration_comm = 0
gen tot_duration_mdcd = 0
forvalues i = 0/364 {
	gen test = inrange(dob+`i',elig_start_dt,elig_end_dt)
	bysort member_composite_id dob: ereplace test = max(test) // should just be 1 if there is any insurance in that date
	
	gen test2 = inrange(dob+`i',elig_start_dt,elig_end_dt) & in_comm == 1
	bysort member_composite_id dob: ereplace test2 = max(test2) // count if there is any commercial enrollment on that date
	replace tot_duration_comm = tot_duration_comm + test2 if in_comm == 1
	replace tot_duration_mdcd = tot_duration_mdcd + test if in_mdcd == 1 & test2 == 0 
		// don't count those in both as in Medicaid
	drop test*
}

* Proportion and N who we lose from the data altogether postpartum 
bysort member_composite_id birth_no: egen latestdate = max(elig_end_dt)
gen dropout = (ub-latestdate > 30) 
	// Missing more than 30 days at the end of the postpartum year
	
* Identify number of switches (as any time the line_of_business_cd variable changes within a year)
bysort member_composite_id dob (elig_start_dt): gen switch = ///
	(line_of_business_cd != line_of_business_cd[_n-1])
bysort member_composite_id dob (elig_start_dt): replace switch = 0 if _n == 1 // don't count first observation as a switch
bysort member_composite_id dob: ereplace switch = total(switch)
gen disrupt = (switch > 0) // any switches

* generate a count for gaps
bysort member_composite_id dob (elig_start_dt): gen gap = (elig_start_dt > elig_end_dt[_n-1]+1) 
bysort member_composite_id dob (elig_start_dt): replace gap = 0 if _n == 1
	
* generate duration of gaps (in days)
bysort member_composite_id dob (elig_start_dt): gen gap_length = elig_start_dt - elig_end_dt[_n-1]+1 if gap == 1

"$working\Enroll_inProgress_20210715.dta", replace
********************************************************************************


***** 3a. Identify outcomes in the 3-12 month window
gen date312 = dob + 90
gen window312 = (elig_end_dt > date312) 
	// any enrollment spells that *overlap* the 3-12 month period

* Proportion and N of sample who had any Medicaid/commercial
gen in_mdcd312 = in_mdcd if window312 == 1
gen in_comm312 = in_comm if window312 == 1

* Mean months of postpartum commercial and Medicaid enrollment
gen duration312 = min(ub, elig_end_dt) - max(elig_start_dt, date312)
gen duration_comm312 = duration312 if in_comm == 1 & window312 == 1
gen duration_mdcd312 = duration312 if in_mdcd == 1 & window312 == 1

gen tot_duration312 = 0
gen tot_duration_comm312 = 0
gen tot_duration_mdcd312 = 0
forvalues i = 0/275 {
	gen test = inrange(date312+`i',elig_start_dt,elig_end_dt)
	bysort member_composite_id dob: ereplace test = max(test)
	
	gen test2 = inrange(dob+`i',elig_start_dt,elig_end_dt) & in_comm312 == 1
	bysort member_composite_id dob: ereplace test2 = max(test2) // count if there is any commercial enrollment on that date
	
	replace tot_duration312 = tot_duration312 + test
	replace tot_duration_comm312 = tot_duration_comm312 + test2 if in_comm312 == 1
	replace tot_duration_mdcd312 = tot_duration_mdcd312 + test if in_mdcd312 == 1 & test2 == 0
	drop test*
}

* Identify number of switches (as any time the line_of_business_cd variable changes within a year)
bysort member_composite_id dob (elig_start_dt): gen switch312 = ///
	(line_of_business_cd != line_of_business_cd[_n-1])
bysort member_composite_id dob (elig_start_dt): replace switch312 = 0 if _n == 1 
bysort member_composite_id dob (elig_start_dt): replace switch312 = 0 if window312 == 0
bysort member_composite_id dob: ereplace switch312 = total(switch312)
gen disrupt312 = (switch312 > 0) // any switches

* generate a count for gaps
bysort member_composite_id dob (elig_start_dt): gen gap312 = (elig_start_dt > elig_end_dt[_n-1]+1) 
bysort member_composite_id dob (elig_start_dt): replace gap312 = 0 if _n == 1
bysort member_composite_id dob (elig_start_dt): replace gap312 = 0 if elig_start_dt < date312 // only count during window
	
* generate duration of gaps (in days)
bysort member_composite_id dob (elig_start_dt): gen gap_length312 = elig_start_dt - max(elig_end_dt[_n-1],date312) + 1 ///
	if gap312 == 1
replace gap312 = 0 if gap_length312 ==0 
replace gap_length312 = . if gap_length312 ==0 
********************************************************************************

***** Added for HA revisions (7.10): count those switching to no reported coverage as disruptions
gen disrupt_new = disrupt312
gen disrupt_new_count = 0

forvalues d = 60/364 { 
	gen test = inrange(dob+`d',elig_start_dt,elig_end_dt) 
	gen test2 = inrange(dob+`d'+1, elig_start_dt, elig_end_dt)
	bysort member_composite_id dob: ereplace test = max(test)
	bysort member_composite_id dob: ereplace test2 = max(test2)
	replace disrupt_new = 1 if disrupt_new == 0 & test == 1 & test2 == 0
	replace disrupt_new_count = disrupt_new_count + 1 if test == 1 & test2 == 0
	drop test*
}
********************************************************************************


***** 3b. Identify outcomes in the 0-2 month window
* Proportion and N of sample who had any Medicaid
gen in_mdcd02 = in_mdcd if window312 == 0

* Proportion and N of sample who had any commercial enrollment
gen in_comm02 = in_comm if window312 == 0

* Mean months of postpartum commercial and Medicaid enrollment
gen duration02 = min(date312, elig_end_dt) - max(elig_start_dt, dob)
gen duration_comm02 = duration02 if in_comm == 1 & window312 == 0
gen duration_mdcd02 = duration02 if in_mdcd == 1 & window312 == 0

gen tot_duration02 = 0
gen tot_duration_comm02 = 0
gen tot_duration_mdcd02 = 0
forvalues i = 0/89 {
	gen test = inrange(dob+`i',elig_start_dt,elig_end_dt)
	bysort member_composite_id dob: ereplace test = max(test)
	replace tot_duration02 = tot_duration02 + test
	replace tot_duration_comm02 = tot_duration_comm02 + test if in_comm02 == 1
	replace tot_duration_mdcd02 = tot_duration_mdcd02 + test if in_mdcd02 == 1 &in_comm02 == 0
	drop test*
}

* Identify number of switches (as any time the line_of_business_cd variable changes within a year)
bysort member_composite_id dob (elig_start_dt): gen switch02 = ///
	(line_of_business_cd != line_of_business_cd[_n-1])
bysort member_composite_id dob (elig_start_dt): replace switch02 = 0 if _n == 1 
bysort member_composite_id dob (elig_start_dt): replace switch02 = 0 if window312 == 1
bysort member_composite_id dob: ereplace switch02 = total(switch02)
gen disrupt02 = (switch02 > 0) // any switches

* generate a count for switches
bysort member_composite_id dob (elig_start_dt): gen gap02 = (elig_start_dt > elig_end_dt[_n-1]+1) 
bysort member_composite_id dob (elig_start_dt): replace gap02 = 0 if _n == 1
bysort member_composite_id dob (elig_start_dt): replace gap02 = 0 if elig_start_dt >= date312 // only count during window
	
* generate duration of gaps (in days)
bysort member_composite_id dob (elig_start_dt): gen gap_length02 = elig_start_dt - max(elig_end_dt[_n-1],dob) + 1 ///
	if gap312 == 1
replace gap02 = 0 if gap_length02 ==0 
replace gap_length02 = . if gap_length02 ==0 
********************************************************************************


***** 4. Collapse and build table
* Collapse to birth level
collapse (max) tot_* in_* duration_* dropout disrupt* switch* ///
		(sum) gap*, /// 
		by(member_composite_id dob) fast 
// note: if missing in_comm312 or in_mdcd312, it is because they are a dropout. 

* Update disruption measure for gap in coverage
gen any_gap = (gap > 0 | gap_length > 0)
gen any_gap312 = (gap312 > 0 | gap_length312 > 0)
gen any_gap02 = (gap02 > 0 | gap_length02 > 0)
gen any_switch = disrupt
gen any_switch312 = disrupt312
gen any_switch02 = disrupt02
replace disrupt = 1 if any_gap == 1
replace disrupt312 = 1 if any_gap312 == 1
replace disrupt02 = 1 if any_gap02 == 1

gen in_mdcd_only = (in_mdcd == 1 & in_comm == 0)
gen in_mdcd_only312 = (in_mdcd312 == 1 & in_comm312 == 0)
gen in_mdcd_only02 = (in_mdcd02 == 1 & in_comm02 == 0)
********************************************************************************


***** 5. Merge back into main file (delivery information)
merge 1:1 member_composite_id dob using "$working\APCD_MedicaidDelivery_Sample.dta", ///
	keep(2 3) nogenerate
compress
save "$working\APCD_MedicaidDelivery_Sample.dta", replace
********************************************************************************