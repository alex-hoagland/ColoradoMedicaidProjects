/*******************************************************************************
* Title: Analyze APCD Sample Size
* Created by: Alex Hoagland
* Created on: 1/22/2021
* Last modified on: 
* Last modified by: Alex Hoagland

* Purpose: Uses results from 1_IdentifyDeliveries to examine yearly sample sizes + 
	insurance coverage over time
		   
* Notes: - for now, this is only 2014 and on. Earlier data?
		
* Key edits: 
   -  
*******************************************************************************/

***** 0. Directories & Packages 
global raw "\\ad.bu.edu\bumcfiles\BUMC Projects\ColoradoAPCD\raw\20.59_BU_Continuity_of_Medicaid"
global sarah "\\ad.bu.edu\bumcfiles\BUMC Projects\ColoradoAPCD\Sarah\Sarah Datasets"
global working "C:\Users\alcobe\Desktop\Hoagland_WorkingData"
global output "C:\Users\alcobe\Desktop\Hoagland_Output\0.SampleDefinition"
********************************************************************************


***** 1. Prep data
use "$working\APCD_MedicaidDelivery_Sample.dta", clear
********************************************************************************


***** 2. Sample sizes over time (by payer: Medicaid or commercial)
// note: currently we are only examining Medicaid-paid births
gen year = year(dob)
gen n = 1
collapse (sum) births=n, by(year) fast
twoway line births year, graphregion(color(white)) ///
	subtitle("# of Medicaid-Paid Births by Year in Colorado") xtitle("Year") ytitle("")
graph export "$output\BirthsByYear.png", as(png) replace
********************************************************************************


***** 3. Identify payer over time from -9 months to 12 months around DOB. 
use "$working\APCD_MedicaidDelivery_Sample.dta", clear
keep member_composite_id dob 
bysort member_* (dob): gen j = _n
reshape wide dob, i(member_*) j(j) // only want one observation per member
compress
save "$working\APCD_MedicaidDelivery_Sample_IDsOnly.dta", replace

*** Merge this with header file
merge 1:m member_* using "$raw\Medical_Claims_Header\Medical_Claims_Header.dta", ///
	keep(3) nogenerate // 10.7 million claims, 93% of which are Medicaid-paid
	
*** Keep only claims within (-9months, 12 months) around DOB
forvalues i = 1/8 {
    gen lb`i' = dob`i'-274
	gen ub`i' = dob`i'+365
}

gen svcdate = date(service_start_dt, "YMD")
gen tokeep = (inrange(svcdate, lb1,ub1))
forvalues i = 2/8 { 
    replace tokeep = 1 if inrange(svcdate, lb`i', ub`i') & !missing(lb`i') & !missing(ub`i')
} 
keep if tokeep == 1 // left with 5.7 M claims, 96.3% of which are Medicaid

*** Analyze payers
* Need to reshape to have each claim duplicated across multiple births -- may take a while
reshape long dob, i(member_composite_id claim_id) j(birth_no)
drop if missing(dob)
drop lb* ub*
gen lb = dob-274
gen ub = dob+365
keep if inrange(svcdate, lb, ub)

* Group claims into months pre-/post-partum
gen dayspassed = svcdate - dob
gen monthspassed = floor(dayspassed / 30)
drop if monthspassed < -9 | monthspassed > 12

* Identify any commercial coverage per birth-month
gen comm = (!inlist(insurance_product_type_cd, "CP", "MC", "MM"))
collapse (max) comm, by(member_composite_id dob monthspassed) fast // birth-level
collapse (mean) comm, by(monthspassed) fast // month level
replace comm = comm * 100 // change to %
twoway line comm monthspassed, graphregion(color(white)) ///
    xline(0, lpattern(dash) lcolor(red)) ///
	xtitle("Months around Birth") ytitle("") ///
	subtitle("% of Women/Births with *any* Commercial Coverage") ///
	xsc(r(-9(1)12)) xlab(-9(1)12)
graph export "$output/CommercialCoverage_byYear.png", as(png) replace
********************************************************************************