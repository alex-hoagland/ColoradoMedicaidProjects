/*******************************************************************************
* Title: Check enrollment distributions
* Created by: Alex Hoagland
* Created on: 12/9/2020
* Last modified on: 2/5/2021
* Last modified by: Alex Hoagland

* Purpose: Constructs enrollment histograms by income for women in our sample. 
		   
* Notes: 
		
* Key edits: 
   -  
*******************************************************************************/


***** 0. Packages and directories, load data
* ssc install binscatter

global head "\\ad.bu.edu\bumcfiles\BUMC Projects\ColoradoAPCD"
global sarah "$head\Sarah\Sarah Datasets"
global working "$head\Alex\Hoagland_WorkingData"
global output "$head\Alex\Hoagland_Output\0.SampleDefinition"

use "$working\APCD_MedicaidDelivery_Sample_WithIncome_20210304.dta", clear
drop if missing(in_mdcd) // drop those with no enrollment info
********************************************************************************


***** 1. Check sample sizes
fre in_comm in_mdcd in_mdcd_only if income_re < 133
fre in_comm in_mdcd in_mdcd_only if income_re >= 133

fre in_comm312 in_mdcd312 in_mdcd_only312 if income_re < 133
fre in_comm312 in_mdcd312 in_mdcd_only312 if income_re >= 133
********************************************************************************


***** 2. Check smoothness of enrollment distributions 
* Create graph of commercial enrollment duration
preserve
gen pct_fpl = round(income_re)

gen pct_durcomm = duration_comm / 365 * 100 // change duration to %

binscatter pct_durcomm pct_fpl, nq(100) linetype(qfit) rd(133) ///
	xtitle("Income (as % FPL)") ytitle("% of Postpartum Year Covered") ///
	subtitle("(Conditional) Average Commercial Coverage")  
local date: di %tdDNCY daily("$S_DATE", "DMY")
graph export "$output\CommercialCoverage_ConditionalYear_`date'.png", as(png) replace

replace pct_durcomm = 0 if missing(duration_comm312)

binscatter pct_durcomm pct_fpl, nq(100) linetype(qfit) rd(133) ///
	xtitle("Income (as % FPL)") ytitle("% of Postpartum Year Covered") ///
	subtitle("(Unconditional) Average Commercial Coverage")  
local date: di %tdDNCY daily("$S_DATE", "DMY")
graph export "$output\CommercialCoverage_UnconditionalYear_`date'.png", as(png) replace
drop pct_durcomm

gen pct_durcomm = duration_comm312 / 277 * 100 // change duration to %

binscatter pct_durcomm pct_fpl, nq(100) linetype(qfit) rd(133) ///
	xtitle("Income (as % FPL)") ytitle("% of 3-12 Months Postpartum Covered") ///
	subtitle("(Conditional) Average Commercial Coverage")  
local date: di %tdDNCY daily("$S_DATE", "DMY")
graph export "$output\CommercialCoverage_Conditional_`date'.png", as(png) replace

replace pct_durcomm = 0 if missing(duration_comm312)

binscatter pct_durcomm pct_fpl, nq(100) linetype(qfit) rd(133) ///
	xtitle("Income (as % FPL)") ytitle("% of 3-12 Months Postpartum Covered") ///
	subtitle("(Unconditional) Average Commercial Coverage")  
local date: di %tdDNCY daily("$S_DATE", "DMY")
graph export "$output\CommercialCoverage_Unconditional_`date'.png", as(png) replace
restore

* Create graph of Medicaid enrollment duration
preserve
gen pct_fpl = round(income_re)
gen pct_durmdcd = duration_mdcd / 365 * 100 // change duration to %

binscatter pct_durmdcd pct_fpl, nq(100) linetype(qfit) rd(133) ///
	xtitle("Income (as % FPL)") ytitle("% of Postpartum Year Covered") ///
	subtitle("(Conditional) Average Medicaid Coverage")  
local date: di %tdDNCY daily("$S_DATE", "DMY")
graph export "$output\MedicaidCoverage_ConditionalYear_`date'.png", as(png) replace

replace pct_durmdcd = 0 if missing(duration_mdcd312)

binscatter pct_durmdcd pct_fpl, nq(100) linetype(qfit) rd(133) ///
	xtitle("Income (as % FPL)") ytitle("% of Postpartum Year Covered") ///
	subtitle("(Unconditional) Average Medicaid Coverage")  
local date: di %tdDNCY daily("$S_DATE", "DMY")
graph export "$output\MedicaidCoverage_UnconditionalYear_`date'.png", as(png) replace
drop pct_durmdcd

gen pct_durmdcd = duration_mdcd312 / 277 * 100 // change duration to %

binscatter pct_durmdcd pct_fpl, nq(100) linetype(qfit) rd(133) ///
	xtitle("Income (as % FPL)") ytitle("% of 3-12 Months Postpartum Covered") ///
	subtitle("(Conditional) Average Medicaid Coverage")  
local date: di %tdDNCY daily("$S_DATE", "DMY")
graph export "$output\MedicaidCoverage_Conditional_`date'.png", as(png) replace

replace pct_durmdcd = 0 if missing(duration_mdcd312)

binscatter pct_durmdcd pct_fpl, nq(100) linetype(qfit) rd(133) ///
	xtitle("Income (as % FPL)") ytitle("% of 3-12 Months Postpartum Covered") ///
	subtitle("(Unconditional) Average Medicaid Coverage")  
local date: di %tdDNCY daily("$S_DATE", "DMY")
graph export "$output\MedicaidCoverage_Unconditional_`date'.png", as(png) replace
restore
********************************************************************************


***** 3. Enrollment Distribution Over Income
*** 0-12 months pp 
preserve

gen pfpl = round(income_re)
collapse (sum) in_*, by(pfpl) fast
keep if pfpl > 0 & pfpl < 300

gen total = in_mdcd_only + in_comm

twoway (bar in_mdcd_only pfpl) (rbar total in_mdcd_only pfpl), ///
		graphregion(color(white)) subtitle("Total Enrolled Lives by FPL: 0-12 Months Postpartum") ///
		legend(on) legend(order(1 "Medicaid Only" 2 "Any Commercial")) ///
		ylab(, angle(horizontal)) xtitle("Income (as % FPL)") ///
		xline(133, lpattern(dash) lcolor(ebblue)) xline(138, lpattern(dash) lcolor(red)) ///
		note("Note: Graph only shows enrollment for women with income in (0, 300)% FPL.")
local date: di %tdDNCY daily("$S_DATE", "DMY")
graph export "$output\EnrollmentDistribution_0-12MonthsPP`date'.png", ///
	as(png) replace
restore

*** Zoom this one in
preserve
keep if inrange(income_re,120,140)
gen pfpl = round(income_re)
collapse (sum) in_*, by(pfpl) fast

gen total = in_mdcd_only + in_comm

twoway (bar in_mdcd_only pfpl) (rbar total in_mdcd_only pfpl), ///
		graphregion(color(white)) subtitle("Total Enrolled Lives by FPL: 0-12 Months Postpartum") ///
		legend(on) legend(order(1 "Medicaid Only" 2 "Any Commercial")) ///
		ylab(, angle(horizontal)) xtitle("Income (as % FPL)") ///
		xline(133, lpattern(dash) lcolor(ebblue)) xline(138, lpattern(dash) lcolor(red)) ///
		note("Note: Graph only shows enrollment for women with income in (120,140)% FPL.")
local date: di %tdDNCY daily("$S_DATE", "DMY")
graph export "$output\EnrollmentDistribution_0-12MonthsPP_Zoomed`date'.png", ///
	as(png) replace
restore

*** 3-12 months pp 
preserve

gen pfpl = round(income_re)
collapse (sum) in_*, by(pfpl) fast
keep if pfpl > 0 & pfpl < 300

gen total = in_mdcd_only312 + in_comm312

twoway (bar in_mdcd_only312 pfpl) (rbar total in_mdcd_only312 pfpl), ///
		graphregion(color(white)) subtitle("Total Enrolled Lives by FPL: 3-12 Months Postpartum") ///
		legend(on) legend(order(1 "Medicaid Only" 2 "Any Commercial")) ///
		ylab(, angle(horizontal)) xtitle("Income (as % FPL)") xline(138, lpattern(dash) lcolor(red)) ///
		note("Note: Graph only shows enrollment for women with income in (0, 300)% FPL.")
local date: di %tdDNCY daily("$S_DATE", "DMY")
graph export "$output\EnrollmentDistribution_3-12MonthsPP`date'.png", ///
	as(png) replace
restore
********************************************************************************
