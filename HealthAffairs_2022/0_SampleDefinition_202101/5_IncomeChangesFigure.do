/*******************************************************************************
* Title: Creates a figure for income changes postpartum
* Created by: Alex Hoagland
* Created on: 2/3/2021
* Last modified on: 
* Last modified by: Alex Hoagland

* Purpose: 
	
* Notes: 
		
* Key edits: 
   -  
*******************************************************************************/


***** 0. Packages and directories
global head "\\ad.bu.edu\bumcfiles\BUMC Projects\ColoradoAPCD"
global sarah "$head\Sarah\Sarah Datasets"
global working "$head\Alex\Hoagland_WorkingData"
global output "$head\Alex\Hoagland_Output\0.SampleDefinition"
********************************************************************************


***** 1. Begin with the delivery data set, merge in income file
use "$working\APCD_MedicaidDelivery_Sample.dta", clear
keep member_composite_id dob 
bysort member_composite_id (dob): gen j = _n
reshape wide dob, i(member_composite_id) j(j) // want one observation per member

merge 1:m member_composite_id using "$head\Planned Enrollment\prelim income data cleaning 9_10_20.dta", keep(3) nogenerate 

duplicates drop // there are duplicates in the income file
reshape long dob, i(member_composite_id age* fed* aid* elig*) j(birth_no) 
	// reshape back to one observation per birth
drop if missing(dob)

order member_ dob birth_no
sort member_ dob birth_no

drop if elig_end_dt < dob // clean up data -- want to make sure that the first 
						// entry for every birth covers the date of birth
bysort member_composite_id dob (elig_effect_strt): ///
	assert inrange(dob,elig_effect_strt,elig_end_dt) if _n == 1
bysort member_composite_id dob (elig_effect_strt): ///
	gen todrop = 1 if _n == 1 & !inrange(dob,elig_effect_strt,elig_end_dt) 
bysort member_composite_id dob (elig_effect_strt): ereplace todrop = max(todrop)
drop if todrop == 1
drop todrop
********************************************************************************


***** 2. How many women have different incomes over time (between 0 and 12 months pp)
* Flag all income changes
bysort member_composite_id dob (elig_effect_strt): ///
	gen newinc = (fed_pov_lvl_pc != fed_pov_lvl_pc[_n-1]) if _n > 1
	
* For each income change, identify time from dob
gen timepass = (elig_effect_strt - dob)/30 if newinc == 1
replace timepass = . if timepass <= 0 | timepass >= 13

* For each month, calculate switch in income
forvalues i = 0/12 { 
	gen switch`i' = (ceil(timepass) == `i')
}
collapse (max) switch*, by(member_composite_id dob) fast
collapse (mean) switch*, fast
gen i = 1
reshape long switch, i(i) j(month)
replace switch = switch * 100

twoway bar switch month, graphregion(color(white)) ///
	xtitle("Months Postpartum") ytitle("") ///
	subtitle("% of Births with Postpartum Income Changes") ///
	xsc(r(1(1)12)) xlab(1(1)12) ///
	note("Note: Measures any reported change in qualifying income compared to the qualifying income " ///
	"listed at the time of birth.")
	
local date: di %tdDNCY daily("$S_DATE", "DMY")
graph export "$output\IncomeChanges_MonthsPP_`date'.png", as(png) replace
********************************************************************************
