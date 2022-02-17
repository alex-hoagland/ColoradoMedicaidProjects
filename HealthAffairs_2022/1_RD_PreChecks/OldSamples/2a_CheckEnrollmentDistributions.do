/*******************************************************************************
* Title: Check enrollment distributions
* Created by: Alex Hoagland
* Created on: 12/9/2020
* Last modified on: 12/2/2020
* Last modified by: Alex Hoagland

* Purpose: Constructs enrollment histograms by income for women in our sample. 
		   
* Notes: - as the x-axis variable, uses income measured at 60 days pp.
		
* Key edits: 
   -  
*******************************************************************************/


***** 0. Packages and directories, load data
global maindir "V:\raw\20.59_BU_Continuity_of_Medicaid\"-
global birth "V:\Birth Records\working datasets\"
global temp "V:\Hoagland_Code\"

cd "V:\"
use "$birth\birth record 2014_2019 Medicaid only 19plus.dta", clear
********************************************************************************


***** 1. Check smoothness of enrollment distributions (based on income at that point)
forvalues i = 0/12 {
	preserve
	
	gen in_mdcd = (enrollment_month`i' == "Medicaid")
	gen in_com = (enrollment_month`i' == "Commercial")
	gen in_mult = (enrollment_month`i' == "Multiple")
	gen in_other = (enrollment_month`i' == "Other")
	
	replace pct_fpl_month`i' = round(pct_fpl_month`i')
	collapse (sum) in_*, by(pct_fpl_month`i') fast

	gen com = in_mdcd + in_c
	gen oth = in_mdcd + in_c + in_o
	gen mul = in_mdcd + in_c + in_o + in_mul
	
	drop if pct_fpl == 0 | missing(pct_fpl) | pct_fpl > 300
	twoway (bar in_mdcd pct_fpl) (rbar in_mdcd com pct_fpl) (rbar com oth pct_fpl) (rbar oth mul pct_fpl), /// 
		graphregion(color(white)) subtitle("Total Enrolled Lives by FPL: `i' Months Postpartum (N = 117,617 unique births)") ///
		legend(on) legend(order(1 "Medicaid" 2 "Commercial" 3 "Other" 4 "Multiple")) ///
		ylab(, angle(horizontal)) xtitle("Income (as % FPL)") xline(138, lpattern(dash) lcolor(red)) ///
		note("Note: Does not show enrollment for women with 0 income, or those with income above 300% FPL.")
	graph export "$temp\Output\EnrollmentDistributions\Enrollment_`i'MonthsPostpartum.png", as(png) replace
	
	binscatter mul pct_fpl, nq(100) linetype(qfit) rd(138) ///
		xtitle("Income (as % FPL)") ytitle("") ///
		subtitle("Total Enrolled Lives by FPL: `i' Months Postpartum (N = 117,617 unique births)")
	graph export "$temp\Output\EnrollmentDistributions\EnrollmentBinScatter_`i'MonthsPostpartum.png", as(png) replace
	
	restore
}
********************************************************************************


***** 2. Making the plots Sarah requested
*** Plot 1 (with respect to woman's income at time of birth)
preserve
gen on = 0
forvalues i = 3/12 { 
	replace on = 1 if enrollment_month`i' == "Medicaid" | enrollment_month`i' == "Commercial" | enrollment_month`i' == "Multiple"
} 

replace pct_fpl_month0 = round(pct_fpl_month0)
collapse (sum) on, by(pct_fpl_month0) fast
keep if pct_fpl > 0 & pct_fpl < 300

twoway (bar on pct_fpl) , ///
		graphregion(color(white)) subtitle("Plot 1: All enrolled in Medicaid/Commercial 3-12 Months Postpartum") ///
		ylab(, angle(horizontal)) xtitle("Income (as % FPL)") ytitle(" " ) ///
		xline(138, lpattern(dash) lcolor(red)) ///
		note("Note: Enrollment counted relative to women's income at time of birth." ///
			"Does not show enrollment for women with 0 income, or those with income above 300% FPL.")
graph export "$temp\Output\EnrollmentDistributions\Plot1.png", as(png) replace
	
binscatter on pct_fpl, nq(100) linetype(qfit) rd(138) ///
	xtitle("Income (as % FPL)") ytitle("") ///
	subtitle("Plot 1: All enrolled in Medicaid/Commercial 3-12 Months Postpartum") ///
	note("Note: Income is measured at time of birth.")
graph export "$temp\Output\EnrollmentDistributions\Plot1_Binscatter.png", as(png) replace

restore

*** Plot 1a (with respect to woman's income 60 days pp; split out)
preserve
gen on_me = 0
gen on_co = 0
gen on_mu = 0
forvalues i = 3/12 { 
	replace on_me = 1 if enrollment_month`i' == "Medicaid"
	replace on_co = 1 if enrollment_month`i' == "Commercial"
	replace on_mu = 1 if enrollment_month`i' == "Multiple"
} 
replace on_mu = 1 if on_me == 1 & on_co == 1
replace on_me = 0 if on_mu == 1
replace on_co = 0 if on_mu == 1
egen test = rowmax(on_*)
replace test = . if test == 0
qui sum test
local lives = `r(N)'

gen pfpl = pct_fpl_month2
replace pfpl = round(pfpl)
collapse (sum) on_*, by(pfpl) fast
keep if pfpl > 0 & pfpl < 300

gen com = on_me + on_c
gen mul = on_me + on_c + on_mu

twoway (bar on_me pfpl) (rbar on_me com pfpl) (rbar com mul pfpl), /// 
		graphregion(color(white)) subtitle("Total Enrolled Lives by FPL: `i' Months Postpartum (N = `lives' unique births)") ///
		legend(on) legend(order(1 "Medicaid" 2 "Commercial" 3 "Multiple")) ///
		ylab(, angle(horizontal)) xtitle("Income (as % FPL)") xline(138, lpattern(dash) lcolor(red)) ///
		note("Note: Measures income 60 days postpartum." ///
			"Only shows enrollment for women with income in (0, 300)% FPL.")
graph export "$temp\Output\EnrollmentDistributions\Plot1a.png", as(png) replace
restore

*** Checking this result 
use "$temp\sampleenrollment_long.dta", clear
gen month = month(dob)+3
gen year = year(dob)
replace year = year+1 if month > 12
replace month = month - 12 if month > 12
gen day = day(dob)
gen pp_s = mdy(month,day,year)
gen pp_e = dob + 365
format pp_s %td
format pp_e %td
drop year month day
drop if pp_s > end_dt | pp_e < start_dt

* Identify all enrollment covering at least 30 days between pp_s and pp_e
gen on = (end_dt > pp_s + 30 & end_dt <= pp_e)
replace on = 1 if (start_dt <= pp_e - 30 & end_dt > pp_e)
drop if on == 0
drop if insurance_type == "Other"

* Identify coverage at individual level, plus months of enrollment
gen on_me = (insurance_type == "Medicaid")
gen on_co = (insurance_type == "Commercial")
gen on_mu = (insurance_type == "Multiple")
gen de_me = min(end_dt,pp_e)-max(start_dt,pp_s)+1 if on_me == 1
gen de_co = min(end_dt,pp_e)-max(start_dt,pp_s)+1 if on_co == 1
gen de_mu = min(end_dt,pp_e)-max(start_dt,pp_s)+1 if on_mu == 1
collapse (max) on_* (sum) de_* (first) pct_fpl_month2, by(member_composite_id dob vsid) fast
replace on_mu = 1 if on_co == 1 & on_me == 1
replace on_co = 0 if on_mu == 1
replace on_me = 0 if on_mu == 1
ereplace de_mu = rowtotal(de_me de_co) if de_me > 0 & de_co > 0
replace de_co = 0 if on_mu == 1
replace de_me = 0 if on_mu == 1

* Create graph of enrollment frequency
preserve
replace pct_fpl = round(pct_fpl)
collapse (sum) on_*, by(pct_fpl) fast
keep if pct_fpl > 0 & pct_fpl < 300

gen com = on_me + on_c
gen mul = on_me + on_c + on_mu

twoway (bar on_me pct_fpl) (rbar on_me com pct_fpl) (rbar com mul pct_fpl), /// 
		graphregion(color(white)) subtitle("Total Enrolled Lives by FPL: Enrollment Spanning 2-12 Months Postpartum") ///
		legend(on) legend(order(1 "Medicaid" 2 "Commercial" 3 "Multiple")) ///
		ylab(, angle(horizontal)) xtitle("Income (as % FPL)") xline(138, lpattern(dash) lcolor(red)) ///
		note("Note: Counts enrollment in any program for at least 1 month between 2 and 12 months postpartum (inclusive)." ///
			"Measures income 60 days postpartum." ///
			"Only shows enrollment for women with income in (0, 300)% FPL.")
graph export "$temp\Output\EnrollmentDistributions\EnrollmentStratified_byFPL_2-12MonthsPP.png", as(png) replace
restore

* Create graph of enrollment duration
preserve
replace pct_fpl = round(pct_fpl)

foreach v of var de_* {
	replace `v' = `v' / 277 * 100
}

collapse (mean) de_*, by(pct_fpl) fast
keep if pct_fpl > 0 & pct_fpl < 300
replace de_co = de_co + de_mu

twoway (line de_me pct_fpl) (line de_co pct_fpl), /// 
		graphregion(color(white)) subtitle("% of Period Covered by Insurance Type: 3-12 Months Postpartum") ///
		legend(on) legend(order(1 "Medicaid" 2 "Commercial/Multiple")) ///
		ylab(, angle(horizontal)) xtitle("Income (as % FPL)") xline(138, lpattern(dash) lcolor(red)) ///
		note("Note: Counts enrollment in any program for at least 1 month between 3 and 12 months postpartum (inclusive)." ///
			"Measures income 60 days postpartum." ///
			"Only shows enrollment for women with income in (0, 300)% FPL.")
graph export "$temp\Output\EnrollmentDistributions\EnrollmentDuration_byFPL_3-12MonthsPP.png", as(png) replace
restore
********************************************************************************

*** Plot 1b (with respect to woman's income 3 months postpartum)
preserve
gen on = 0
forvalues i = 3/12 { 
	replace on = 1 if enrollment_month`i' == "Medicaid" | enrollment_month`i' == "Commercial" | enrollment_month`i' == "Multiple"
} 

replace pct_fpl_month3 = round(pct_fpl_month3)
collapse (sum) on, by(pct_fpl_month3) fast
keep if pct_fpl > 0 & pct_fpl < 300

twoway (bar on pct_fpl) , ///
		graphregion(color(white)) subtitle("Plot 1a: All enrolled in Medicaid/Commercial 3-12 Months Postpartum") ///
		ylab(, angle(horizontal)) xtitle("Income (as % FPL)") ytitle(" " ) ///
		xline(138, lpattern(dash) lcolor(red)) ///
		note("Note: Enrollment counted relative to women's income 3 months postpartum." ///
			"Does not show enrollment for women with 0 income, or those with income above 300% FPL.")
graph export "$temp\Output\EnrollmentDistributions\Plot1b.png", as(png) replace
	
binscatter on pct_fpl, nq(100) linetype(qfit) rd(138) ///
	xtitle("Income (as % FPL)") ytitle("") ///
	subtitle("Plot 1a: All enrolled in Medicaid/Commercial 3-12 Months Postpartum") ///
	note("Note: Income is measured 3 months postpartum.")
graph export "$temp\Output\EnrollmentDistributions\Plot1b_Binscatter.png", as(png) replace

restore

*** Plot 2 (with respect to woman's income at time of birth)
preserve
gen on = 0
forvalues i = 0/12 { 
	replace on = 1 if enrollment_month`i' == "Medicaid" | enrollment_month`i' == "Commercial" | enrollment_month`i' == "Multiple"
} 

replace pct_fpl_month0 = round(pct_fpl_month0)
collapse (sum) on, by(pct_fpl_month0) fast
keep if pct_fpl > 0 & pct_fpl < 300

twoway (bar on pct_fpl) , ///
		graphregion(color(white)) subtitle("Plot 2: All enrolled in Medicaid/Commercial 0-12 Months Postpartum") ///
		ylab(, angle(horizontal)) xtitle("Income (as % FPL)") ytitle(" " ) ///
		xline(138, lpattern(dash) lcolor(red)) ///
		note("Note: Enrollment counted relative to women's income at time of birth." ///
			"Does not show enrollment for women with 0 income, or those with income above 300% FPL.")
graph export "$temp\Output\EnrollmentDistributions\Plot2.png", as(png) replace
	
binscatter on pct_fpl, nq(100) linetype(qfit) rd(138) ///
	xtitle("Income (as % FPL)") ytitle("") ///
	subtitle("Plot 2: All enrolled in Medicaid/Commercial 0-12 Months Postpartum") ///
	note("Note: Income is measured at time of birth.")
graph export "$temp\Output\EnrollmentDistributions\Plot2_Binscatter.png", as(png) replace

restore

*** Plot 3 (with respect to woman's income at time of birth)
preserve
gen on = 0
forvalues i = 2/12 { 
	replace on = 1 if enrollment_month`i' == "Medicaid" | enrollment_month`i' == "Commercial" | enrollment_month`i' == "Multiple"
} 

replace pct_fpl_month0 = round(pct_fpl_month0)
collapse (sum) on, by(pct_fpl_month0) fast
keep if pct_fpl > 0 & pct_fpl < 300

twoway (bar on pct_fpl) , ///
		graphregion(color(white)) subtitle("Plot 3: All enrolled in Medicaid/Commercial 2-12 Months Postpartum") ///
		ylab(, angle(horizontal)) xtitle("Income (as % FPL)") ytitle(" " ) ///
		xline(138, lpattern(dash) lcolor(red)) ///
		note("Note: Enrollment counted relative to women's income at time of birth." ///
			"Does not show enrollment for women with 0 income, or those with income above 300% FPL.")
graph export "$temp\Output\EnrollmentDistributions\Plot3.png", as(png) replace
	
binscatter on pct_fpl, nq(100) linetype(qfit) rd(138) ///
	xtitle("Income (as % FPL)") ytitle("") ///
	subtitle("Plot 3: All enrolled in Medicaid/Commercial 2-12 Months Postpartum") ///
	note("Note: Income is measured at time of birth.")
graph export "$temp\Output\EnrollmentDistributions\Plot3_Binscatter.png", as(png) replace

restore

*** Plot 4 (with respect to woman's income at time of birth)
preserve
gen on = 0
forvalues i = 4/12 { 
	replace on = 1 if enrollment_month`i' == "Medicaid" | enrollment_month`i' == "Commercial" | enrollment_month`i' == "Multiple"
} 

replace pct_fpl_month0 = round(pct_fpl_month0)
collapse (sum) on, by(pct_fpl_month0) fast
keep if pct_fpl > 0 & pct_fpl < 300

twoway (bar on pct_fpl) , ///
		graphregion(color(white)) subtitle("Plot 4: All enrolled in Medicaid/Commercial 4-12 Months Postpartum") ///
		ylab(, angle(horizontal)) xtitle("Income (as % FPL)") ytitle(" " ) ///
		xline(138, lpattern(dash) lcolor(red)) ///
		note("Note: Enrollment counted relative to women's income at time of birth." ///
			"Does not show enrollment for women with 0 income, or those with income above 300% FPL.")
graph export "$temp\Output\EnrollmentDistributions\Plot4.png", as(png) replace
	
binscatter on pct_fpl, nq(100) linetype(qfit) rd(138) ///
	xtitle("Income (as % FPL)") ytitle("") ///
	subtitle("Plot 4: All enrolled in Medicaid/Commercial 4-12 Months Postpartum") ///
	note("Note: Income is measured at time of birth.")
graph export "$temp\Output\EnrollmentDistributions\Plot4_Binscatter.png", as(png) replace

restore
********************************************************************************
