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


***** 1. Collapse to outcome by group
use "$working/RestrictedSample_20210915.dta", clear
drop *_op 

collapse (mean) tc oop p_* /// 
	(sd) sd_tc=tc sd_tc_prev=p_tc_prev sd_tc_ed=p_tc_ed sd_tc_ip=p_tc_ip ///
		sd_oop=oop sd_oop_prev=p_oop_prev sd_oop_ed=p_oop_ed sd_oop_ip=p_oop_ip ///
	(count) n_tc=tc n_tc_prev=p_tc_prev n_tc_ed=p_tc_ed n_tc_ip=p_tc_ip ///
		n_oop=oop n_oop_prev=p_oop_prev n_oop_ed=p_oop_ed n_oop_ip=p_oop_ip, by(group) fast
		
foreach v of var p_* { 
	local s = substr("`v'", 3, .)
	rename `v' `s'
}
	
// generate SEs and bounds
foreach v of var tc* oop* { 
	gen se_`v' = sd_`v' / sqrt(n_`v')
	gen lb_`v' = `v' - 1.96*se_`v'
	gen ub_`v' = `v' + 1.96*se_`v'
}

// measure in $000's
// foreach v of var tc* oop* lb_* ub_* { 
// 	replace `v' = `v' / 1000
// }


// reshape for graph 
// graph 1: billed costs
preserve
drop oop_* *oop* sd* se* n*
rename tc tc_1
rename lb_tc lb_tc_1
rename ub_tc ub_tc_1
rename *op *2
rename *ed *3
rename *ip *4
reshape long tc_ lb_tc_ ub_tc_, i(group) j(type)

gen test = group if type == 1
replace test = group + 3 if type == 2
replace test = group + 6 if type == 3
replace test = group + 9 if type == 4
twoway (bar tc_ test) (rcap lb_ ub_ test), graphregion(color(white)) ///
	legend(off) ylab(,angle(horizontal)) ///
	xlabel(.5 "All Services" 3.5 "Outpatient Visits" 6.5 "ED Visits" 9.5 "Inpatient Visits") ///
	xtitle("") subtitle("Billed Spending ($000's')")
restore

// graph 2: OOP costs
preserve
drop tc_* *tc* sd* se* n*
rename oop oop_1
rename lb_oop lb_oop_1
rename ub_oop ub_oop_1
rename *prev *2
rename *ed *3
rename *ip *4
reshape long oop_ lb_oop_ ub_oop_, i(group) j(type)

gen test = group if type == 1
replace test = group + 3 if type == 2
replace test = group + 6 if type == 3
replace test = group + 9 if type == 4
twoway (bar oop_ test if group == 0, lcolor(midgreen) fcolor(midgreen%60)) ///
	(bar oop_ test if group == 1, lcolor(ebblue) fcolor(ebblue%60)) ///
	(rcap lb_ ub_ test, color(gs4)), graphregion(color(white)) ///
	legend(order(1 "Medicaid" 2 "Commercial")) ylab(,angle(horizontal)) ///
	xlabel(.5 "All Services" 3.5 "Preventive Visits" 6.5 "ED Visits" 9.5 "Inpatient Visits") ///
	xtitle("") subtitle("OOP Spending ($000's)")
graph export "$output\Figure_OOP_20210915.png", as(png) replace

drop if type == 4
twoway (bar oop_ test if group == 0, lcolor(midgreen) fcolor(midgreen%60)) ///
	(bar oop_ test if group == 1, lcolor(ebblue) fcolor(ebblue%60)) ///
	(rcap lb_ ub_ test, color(gs4)), graphregion(color(white)) ///
	legend(order(1 "Medicaid" 2 "Commercial")) ylab(,angle(horizontal)) ///
	xlabel(.5 "All Services" 3.5 "Preventive Visits" 6.5 "ED Visits") ///
	xtitle("") subtitle("OOP Spending ($000's)")
graph export "$output\Figure_OOP_NoIP_20210915.png", as(png) replace
restore

preserve
drop tc_* *tc* sd* se* n*
rename oop oop_1
rename lb_oop lb_oop_1
rename ub_oop ub_oop_1
rename *prev *2
rename *ed *3
rename *ip *4
reshape long oop_ lb_oop_ ub_oop_, i(group) j(type)

gen test = group if type == 1
replace test = group + 3 if type == 3
replace test = group + 6 if type == 4

drop if type == 2
twoway (bar oop_ test if group == 0, lcolor(midgreen) fcolor(midgreen%60)) ///
	(bar oop_ test if group == 1, lcolor(ebblue) fcolor(ebblue%60)) ///
	(rcap lb_ ub_ test, color(gs4)), graphregion(color(white)) ///
	legend(order(1 "Medicaid" 2 "Commercial")) ylab(,angle(horizontal)) ///
	xlabel(.5 "All Services" 3.5 "ED Visits" 6.5 "Inpatient Stays") ///
	xtitle("") subtitle("OOP Spending ($000's)")
graph export "$output\Figure_OOP_NoPrev_20210915.png", as(png) replace
restore

// graph 2: OOP costs -- multiple y-axes
preserve
drop tc_* *tc* sd* se* n*
rename oop oop_1
rename lb_oop lb_oop_1
rename ub_oop ub_oop_1
rename *op *2
rename *ed *3
rename *ip *4
reshape long oop_ lb_oop_ ub_oop_, i(group) j(type)

gen test = group if type == 1
replace test = group + 3 if type == 2
replace test = group + 6 if type == 3
replace test = group + 9 if type == 4

gen yax = (type >= 3)
foreach v of var oop* lb_* ub_* { 
	replace `v' = `v' * 1000
}

twoway (bar oop_ test if group == 0 & yax == 0, yaxis(1) lcolor(midgreen) fcolor(midgreen%60)) ///
	(bar oop_ test if group == 1 & yax == 0, yaxis(1) lcolor(ebblue) fcolor(ebblue%60)) ///
	(bar oop_ test if group == 0 & yax == 1, yaxis(2) lcolor(midgreen) fcolor(midgreen%60)) ///
	(bar oop_ test if group == 1 & yax == 1, yaxis(2) lcolor(ebblue) fcolor(ebblue%60)) ///
	(rcap lb_ ub_ test if yax == 0, yaxis(1) color(gs4)) ///
	(rcap lb_ ub_ test if yax == 1, yaxis(2) color(gs4)), graphregion(color(white)) ///
	legend(order(1 "Medicaid" 2 "Commercial")) legend(region(lstyle(none))) ///
	ylab(,axis(1) angle(horizontal)) ylab(,axis(2) angle(horizontal)) ///
	ytitle("Overall & Outpatient Spending (2018 USD)", axis(1)) ytitle("ED & Inpatient Spending (2018 USD)",axis(2)) ///
	xlabel(.5 "All Services" 3.5 "Outpatient Visits" 6.5 "ED Visits" 9.5 "Inpatient Visits") ///
	xtitle("") subtitle("OOP Spending")
graph export "$output\Figure_OOP_2Axes_20210810.png", as(png) replace
restore

// graph 2: OOP costs -- multiple panels
// Panel 1: Medicaid only
preserve
keep if group == 0
drop tc_* *tc* sd* se* n*
rename oop oop_1
rename lb_oop lb_oop_1
rename ub_oop ub_oop_1
rename *prev *2
rename *ed *3
rename *ip *4
reshape long oop_ lb_oop_ ub_oop_, i(group) j(type)

// graph bar oop_, over(type) asyvars

gen test = group if type == 1
replace test = group + 1 if type == 2
replace test = group + 2 if type == 3
replace test = group + 3 if type == 4
twoway (bar oop_ test if test == 0, lcolor(midgreen) fcolor(midgreen%60)) ///
	(bar oop_ test if test == 1, lcolor(ebblue) fcolor(ebblue%60)) ///
	(bar oop_ test if test == 2, lcolor(gold) fcolor(gold%60)) ///
	(bar oop_ test if test == 3, lcolor(maroon) fcolor(maroon%60)) ///
	(rcap lb_ ub_ test, color(gs4)), graphregion(color(white)) ///
	legend(off) ylab(,angle(horizontal)) ///
	xlabel(0 "All Services" 1 "Preventive Visits" 2 "ED Visits" 3 "Inpatient Visits") ///
	xtitle("") ///
	ysc(r(0(100)500)) ylab(0(100)500) ytitle("OOP Spending (2020 USD)")
graph export "$output\Figure_OOP_2Panels_A_20210915.png", as(png) replace
restore

// Panel 2: Commercial
preserve
keep if group == 1
drop tc_* *tc* sd* se* n*
rename oop oop_1
rename lb_oop lb_oop_1
rename ub_oop ub_oop_1
rename *prev *2
rename *ed *3
rename *ip *4
reshape long oop_ lb_oop_ ub_oop_, i(group) j(type)

// graph bar oop_, over(type) asyvars

gen test = group if type == 1
replace test = group + 1 if type == 2
replace test = group + 2 if type == 3
replace test = group + 3 if type == 4
twoway (bar oop_ test if test == 1, lcolor(midgreen) fcolor(midgreen%60)) ///
	(bar oop_ test if test == 2, lcolor(ebblue) fcolor(ebblue%60)) ///
	(bar oop_ test if test == 3, lcolor(gold) fcolor(gold%60)) ///
	(bar oop_ test if test == 4, lcolor(maroon) fcolor(maroon%60)) ///
	(rcap lb_ ub_ test, color(gs4)), graphregion(color(white)) ///
	legend(off) ylab(,angle(horizontal)) ///
	xlabel(1 "All Services" 2 "Preventive Visits" 3 "ED Visits" 4 "Inpatient Visits") ///
	xtitle("") ///
	ysc(r(0(2500)15000)) ylab(0(2500)15000) ytitle("OOP Spending (2020 USD)")
graph export "$output\Figure_OOP_2Panels_B_20210915.png", as(png) replace
restore
********************************************************************************

