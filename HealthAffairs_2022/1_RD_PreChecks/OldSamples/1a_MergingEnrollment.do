/*******************************************************************************
* Title: Merging in the enrollment file
* Created by: Alex Hoagland
* Created on: 11/18/2020
* Last modified on: 12/9/2020
* Last modified by: Alex Hoagland

* Purpose: Pulls enrollment data with our sample of interest. 
		   
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


***** 1. Merge in enrollment data
use "$birth\birth record 2014_2019 Medicaid only 19plus.dta", clear
keep member_composite_id 
duplicates drop

*** Need to merge in all the associated member ids
merge 1:m member_composite_id using ///
	"$maindir/Member_to_Member_Composite_Crosswalk/Member_to_Member_Composite_Crosswalk.dta", ///
	keep(1 3) nogenerate
keep member_* dob
sort member_id
save "$temp\SampleMemberIDs.dta", replace

*** If I try to merge this straight in, we run into an I/O issue on my computer, so
*** need to do it in pieces
* local myvalues 10000001 20000001 30000001 40000001 50000001 60000001 70000001 80000000 90000001 100000001 up to 210000001
local myvalues 220000001 230000001 240000001 250000001
foreach v of local myvalues { 
	local lb = `v'-10000000
	di "Working on values `lb' to `v'"
	use in `lb'/`v' using "$maindir\Member_Eligibility\Member_Eligibility.dta", clear
	merge m:1 member_id using "$temp\SampleMemberIDs.dta", keep(3) nogenerate
	*append using "$temp\working.dta"
	compress
	save "$temp\working_`v'.dta", replace
} 
use in 210000001/l using "$maindir\Member_Eligibility\Member_Eligibility.dta", clear
merge m:1 member_id using "$temp\SampleMemberIDs.dta", keep(3) nogenerate
compress
save "$temp\working_220000001.dta", replace

* Combine files 
clear
gen member_id = . 
save "$temp\sampleeligibility.dta"
local files: dir "$temp" files "working_*"
foreach f of local files {
	append using "$temp\`f'"
	* rm "$temp\`f'.dta"
	}
compress
duplicates drop
save "$temp\sampleeligibility.dta"

* Reshape to individual level (member_composite_id)
keep member_composite_id eligibility_dt insurance_product_type_cd

gen in_mdcd = (inlist(insurance_product_type_cd,"MC", "CP", "MM"))
gen in_com = (in_mdcd == 0)
collapse (max) in_*, by(member_composite_id eligibility_dt) fast

gen insurance_type = ""
replace insurance_type = "Multiple" if in_mdcd == 1 & in_com == 1
replace insurance_type = "Medicaid" if missing(insurance_type) & in_mdcd == 1
replace insurance_type = "Commercial" if missing(insurance_type) & in_com == 1
drop in_*

bysort member_composite_id (eligibility_dt): gen j = _n
reshape wide insurance_type eligibility_dt, i(member_composite_id) j(j)

* Merge back into original birth record data
merge 1:m member_composite_id using "$birth\birth record 2014_2019 Medicaid only 19plus.dta", ///
	keep(2 3) nogenerate
reshape long insurance_type eligibility_dt, i(member_composite_id dob vsid yr) j(num_elig_record)
drop if missing(insurance_type) & num_elig_record > 1

* Drop records that ended before the DOB
gen start_dt = date(eligibility_dt, "YMD")
format start_dt %td
bysort member_composite_id dob vsid (num_elig_record): gen end_dt = date(eligibility_dt[_n+1], "YMD")-1
format end_dt %td
replace end_dt = 21883 if missing(end_dt) // last day in sample (11/30/2019)
drop if end_dt < dob

compress
save "$temp\sampleenrollment_long", replace
********************************************************************************


***** 2. Identify variables
* Identify first available pregnancy income

* Generate enrollment variables for each month postpartum
forvalues i = 0/12 {
	gen enrollment_month`i' = insurance_type if ((dob + `i'*30) >= start_dt & (dob + `i'*30) <= end_dt)
	bysort member_composite_id vsid dob (enrollment_month`i'): replace enrollment_month`i' = enrollment_month`i'[_N]
		// At this point, I know there is only one enrollment record per woman-birth-month, so sorting it like this gives me the appropriate enrollment
}

* Merge into main data
keep member_composite_id vsid dob enrollment_month*
duplicates drop
merge 1:1 member_composite_id vsid dob using "$birth\birth record 2014_2019 Medicaid only 19plus.dta", ///
	keep(2 3) nogenerate
order enrollment_month*, last

compress
save "$birth\birth record 2014_2019 Medicaid only 19plus.dta", replace
********************************************************************************
