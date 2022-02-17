// deprecated -- looking at enrollment with a fixed income

// uses the income at time of pregnancy


***** 0. Set up data
use "$temp\sampleenrollment_long.dta", clear
********************************************************************************


***** 1. Look at enrollment by month using this income measure
* First, identify the start/end dates of enrollment *relative to DOB*
gen dobstart = start_dt - dob
gen dobend = end_dt - dob
drop if dobstart > 365 | dobend < 0

replace insurance_type = "Commercial" if insurance_type == "Multiple" // Count multiple as "any commercial"
replace aid_desc1 = "Commercial" if insurance_type == "Commercial"
replace aid_desc2 = "Commercial" if insurance_type == "Commercial"

forvalues i = 0/12 {
	preserve
	local j = `i' * 30
	
	keep if inrange(`j', dobstart, dobend) // keep only enrollment at 30 day-intervals following birth
	
	gen in_mdcd_p = (insurance_type == "Medicaid" & (strpos(aid_desc1, "Pregnant") | strpos(aid_desc2, "Pregnant") | strpos(aid_desc1, "Prenatal") | strpos(aid_desc2, "Prenatal")))
	gen in_mdcd_t = (strpos(aid_desc1, "Trans") | strpos(aid_desc2, "Trans"))
	gen in_mdcd_o = (insurance_type == "Medicaid" & in_mdcd_p == 0 & in_mdcd_t == 0)
	gen in_com = (insurance_type == "Commercial")
	
	collapse (max) in_* income_pregqual, by(member_ dob) fast // keep only one record per birth
	
	replace income_pregqual = round(income_pregqual) // create bins of enrollment by income levels
	collapse (sum) in_*, by(income_pregqual) fast

	gen com = in_mdcd_p + in_c
	gen tr = com + in_mdcd_t
	gen all = tr + in_mdcd_o
	
	drop if income_pregqual == 0 | missing(income_pregqual) | income_pregqual > 300
	twoway (bar in_mdcd_p income_pregqual) (rbar in_mdcd_p com income_pregqual) (rbar com tr income_pregqual) (rbar tr all income_pregqual), /// 
		graphregion(color(white)) subtitle("Enrollment Distribution at `j' Days Postpartum by Pregnancy-Qualifying Income") ///
		legend(on) legend(order(1 "Pregnancy Medicaid" 2 "Any Commercial Coverage" 3 "Transitional Medicaid" 4 "Other Medicaid")) ///
		ylab(, angle(horizontal)) xtitle("Income (as % FPL)") xline(138, lpattern(dash) lcolor(red)) ///
		note("Note: Does not show enrollment for women with 0 income, or those with income above 300% FPL.")
	graph export "$temp\Output\EnrollmentDistributions\Enrollment_`j'DaysPostpartum.png", as(png) replace
	
	binscatter in_mdcd_p income_pregqual, nq(100) linetype(qfit) rd(138) ///
		xtitle("Income (as % FPL)") ytitle("") ///
		subtitle("Number of Pregnancy Medicaid Enrollees at `j' Days Postpartum")
	graph export "$temp\Output\EnrollmentDistributions\EnrollmentBinScatter_MedicaidOnly_`j'DaysPostpartum.png", as(png) replace
	
	restore
}
********************************************************************************


***** 2. Limit analysis for women in (138, 175)% FPL
* Want a bar chart across months that shows the proportion of women in each of the following categories: 
    * Original Medicaid: the Medicaid coverage they were enrolled in at the time of birth
	* New Medicaid: any other Medicaid coverage, excluding transitional Medicaid
	* Transitional Medicaid
	* Commercial 
	* Missing from data (uninsured or other)
	
keep if inrange(income_preg , 138, 175)
replace insurance_type = "Commercial" if insurance_type == "Multiple" // Count "multiple" as commercial (for now)
replace aid_desc1 = "Commercial" if insurance_type == "Commercial" 

* Identify Medicaid source at time of birth
* fre aid_desc1 if inrange(0, dobstart, dobend) // Missing for 756 of these women
gen start_med = aid_desc1 if inrange(0, dobstart, dobend)
bysort member_c dob: carryforward start_med, replace

preserve
clear
gen month = . 
save "$temp\Output\MonthlyEnrollment_138-175FPL.dta", replace
restore

forvalues i = 0/12 {
	preserve
	local j = `i' * 30
	
	* Funky way to identify women who drop out of sample
	gen tokeep = (inrange(`j', dobstart, dobend)) // keep only enrollment at 30 day-intervals following birth
	bysort member_c dob: egen test = sum(tokeep)
	gen flag = (test == 0)
	bysort member_c dob: replace tokeep = 1 if _n == 1 & flag == 1
	keep if tokeep == 1
	
	* Types of enrollment
	gen in_commercial = (insurance_type == "Commercial")
	gen in_same = (aid_desc1 == start_med & start_med != "Commercial" & !strpos(start_med, "Trans") & !missing(start_med))
	gen in_mdcd_missing = (missing(aid_desc1) & insurance_type == "Medicaid")
	gen in_mdcd_transition = (strpos(aid_desc1, "Trans Med"))
	gen in_mdcd_new = (insurance_type == "Medicaid" & aid_desc1 != start_med & in_mdcd_missing == 0 & in_mdcd_transition == 0)
	gen in_missing = (flag == 1) // for women who disappear from sample (add later)
	
	collapse (sum) in_*, fast
	gen month = `i'

	egen total = rowtotal(in_*)
	foreach v of var in_* { 
		replace `v' = `v'/total * 100
	} 

	append using "$temp\Output\MonthlyEnrollment_138-175FPL.dta"
	save "$temp\Output\MonthlyEnrollment_138-175FPL.dta", replace
	
	restore
} 

use "$temp\Output\MonthlyEnrollment_138-175FPL.dta", clear
order in_same in_c in_mdcd_new in_mdcd_t
label var month "Months postpartum"
graph bar in_*, over(month) stack ///
	legend(label(1 "Pregnancy coverage") label(2 "*Any* commercial") label(3 "New (non-transitional) Medicaid") ///
		   label(4 "Transitional Medicaid") label(5 "New Medicaid (missing qualifying reason)") label(6 "Missing from data")) legend(on) ///
	ytitle("%") subtitle("Insurance Coverage for Women, 0--12 Months Postpartum")
graph export "$temp\Output\EnrollmentDistributions\MonthlyEnrollment_138-175FPL.png", as(png) replace
rm "$temp\Output\MonthlyEnrollment_138-175FPL.dta"
********************************************************************************


***** 3. Identify sample size of switches from pregnancy Medicaid to commercial, transitional Medicaid, and other Medicaid
* Full sample
gen start_med = aid_desc1 if inrange(0, dobstart, dobend)
bysort member_c dob: carryforward start_med, replace

gen in_mdcd_p = (insurance_type == "Medicaid" & (strpos(aid_desc1, "Pregnant") | strpos(aid_desc2, "Pregnant") | strpos(aid_desc1, "Prenatal") | strpos(aid_desc2, "Prenatal")))
gen in_mdcd_t = (strpos(aid_desc1, "Trans") | strpos(aid_desc2, "Trans"))
gen in_mdcd_o = (insurance_type == "Medicaid" & in_mdcd_p == 0 & in_mdcd_t == 0)
gen in_com = (insurance_type == "Commercial")

bysort member_c dob: gen switch_com = (aid_desc1[_n-1] == start_med & in_com == 1 & in_com[_n-1] == 0) 
	// a switch into commercial where the last period looked like the starting coverage
bysort member_c dob: gen switch_trans = (aid_desc1[_n-1] == start_med & in_mdcd_t == 1 & in_mdcd_t[_n-1] == 0) 
bysort member_c dob: gen switch_other = (aid_desc1[_n-1] == start_med & in_mdcd_o == 1 & in_mdcd_o[_n-1] == 0) 

preserve
keep if dobend > 60 & dobstart < 365 // keep the relevant time frame 
keep if inlist(1, switch_com, switch_trans, switch_other) // keep all switches
bysort member_c dob (num_elig_record): keep if _n == 1 // keep first switch per birth
collapse (sum) switch*, fast // collapse to number of each switch 
restore

preserve
keep if dobend > 60 & dobstart < 120 // keep the relevant time frame 
keep if inlist(1, switch_com, switch_trans, switch_other) // keep all switches
bysort member_c dob (num_elig_record): keep if _n == 1 // keep first switch per birth
collapse (sum) switch*, fast // collapse to number of each switch 
restore

preserve
keep if dobend > 60 & dobstart < 90 // keep the relevant time frame 
keep if inlist(1, switch_com, switch_trans, switch_other) // keep all switches
bysort member_c dob (num_elig_record): keep if _n == 1 // keep first switch per birth
collapse (sum) switch*, fast // collapse to number of each switch 
restore

preserve
keep if dobend > 60 & dobstart < 365 // keep the relevant time frame 
keep if switch_com == 1
bysort member_c dob (num_elig_record): keep if _n == 1 // keep first switch per birth
collapse (sum) switch*, by(yr) fast // collapse to number of each switch 
restore

* Income < 138% FPL
preserve
keep if income_pregqual < 138 & !missing(income_pregqual) // keep relevant subsample
keep if dobend > 60 & dobstart < 365 // keep the relevant time frame 
keep if inlist(1, switch_com, switch_trans, switch_other) // keep all switches
bysort member_c dob (num_elig_record): keep if _n == 1 // keep first switch per birth
collapse (sum) switch*, fast // collapse to number of each switch 
restore

preserve
keep if income_pregqual < 138 & !missing(income_pregqual) // keep relevant subsample
keep if dobend > 60 & dobstart < 120 // keep the relevant time frame 
keep if inlist(1, switch_com, switch_trans, switch_other) // keep all switches
bysort member_c dob (num_elig_record): keep if _n == 1 // keep first switch per birth
collapse (sum) switch*, fast // collapse to number of each switch 
restore

preserve
keep if income_pregqual < 138 & !missing(income_pregqual) // keep relevant subsample
keep if dobend > 60 & dobstart < 90 // keep the relevant time frame 
keep if inlist(1, switch_com, switch_trans, switch_other) // keep all switches
bysort member_c dob (num_elig_record): keep if _n == 1 // keep first switch per birth
collapse (sum) switch*, fast // collapse to number of each switch 
restore

preserve
keep if income_pregqual < 138 & !missing(income_pregqual) // keep relevant subsample
keep if dobend > 60 & dobstart < 365 // keep the relevant time frame 
keep if switch_com == 1
bysort member_c dob (num_elig_record): keep if _n == 1 // keep first switch per birth
collapse (sum) switch*, by(yr) fast // collapse to number of each switch 
restore

* Income > 138% FPL
preserve
keep if income_pregqual > 138 & !missing(income_pregqual) // keep relevant subsample
keep if dobend > 60 & dobstart < 365 // keep the relevant time frame 
keep if inlist(1, switch_com, switch_trans, switch_other) // keep all switches
bysort member_c dob (num_elig_record): keep if _n == 1 // keep first switch per birth
collapse (sum) switch*, fast // collapse to number of each switch 
restore

preserve
keep if income_pregqual > 138 & !missing(income_pregqual) // keep relevant subsample
keep if dobend > 60 & dobstart < 120 // keep the relevant time frame 
keep if inlist(1, switch_com, switch_trans, switch_other) // keep all switches
bysort member_c dob (num_elig_record): keep if _n == 1 // keep first switch per birth
collapse (sum) switch*, fast // collapse to number of each switch 
restore

preserve
keep if income_pregqual > 138 & !missing(income_pregqual) // keep relevant subsample
keep if dobend > 60 & dobstart < 90 // keep the relevant time frame 
keep if inlist(1, switch_com, switch_trans, switch_other) // keep all switches
bysort member_c dob (num_elig_record): keep if _n == 1 // keep first switch per birth
collapse (sum) switch*, fast // collapse to number of each switch 
restore

preserve
keep if income_pregqual > 138 & !missing(income_pregqual) // keep relevant subsample
keep if dobend > 60 & dobstart < 365 // keep the relevant time frame 
keep if switch_com == 1
bysort member_c dob (num_elig_record): keep if _n == 1 // keep first switch per birth
collapse (sum) switch*, by(yr) fast // collapse to number of each switch 
restore
********************************************************************************
