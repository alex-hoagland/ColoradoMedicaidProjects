/*******************************************************************************
* Title: Spending Figure by Month
* Created by: Alex Hoagland
* Created on: 9/24/2021
* Last modified on: 
* Last modified by: Alex Hoagland

* Purpose: Shows average/median total/OOP spending by month after delivery in each group
		   
* Notes: 
		
* Key edits: 
   -  
*******************************************************************************/

***** 0. Directories & Packages
* ssc install psmatch2 

global head "\\ad.bu.edu\bumcfiles\BUMC Projects\ColoradoAPCD"
global sarah "\\ad.bu.edu\bumcfiles\BUMC Projects\ColoradoAPCD\Sarah\Sarah Datasets"
global apcd "$head\raw\20.59_BU_Continuity_of_Medicaid\Medical_Claims_Header"
global working "\\ad.bu.edu\bumcfiles\BUMC Projects\ColoradoAPCD\Alex\Hoagland_WorkingData\Paper2"
global output "\\ad.bu.edu\bumcfiles\BUMC Projects\ColoradoAPCD\Alex\Hoagland_Output\4.HealthOutcomesPaper"
********************************************************************************


***** 1. Pull in Monthly Spending Data
use "$working\RestrictedSample_AllBirths.dta", clear

* Merge in all claims to filter
merge 1:m member_composite_id using ///
	"$apcd\Medical_Claims_Header.dta", ///	
	keep(3) nogenerate

* Keep only claims from 0-365 days postpartum (rough way -- prior to reshaping later)
gen new_admit = date(admit_dt , "YMD")
gen new_svcstart = date(service_start_dt , "YMD")
gen tokeep = 0 
forvalues i = 1/4 { 
	replace tokeep = 1 if inrange(new_svcstart,dob`i',dob`i'+365) & !missing(dob`i')
}
keep if tokeep == 1

* Now reshape to associate claims with specific births
//drop service_qty units _merge line_no ndc_cd
duplicates drop
//egen id = group(member_composite_id claim_id billing* new_* cpt* revenue_cd service* place*), missing
egen id = group(member_composite_id claim_id billing* new_* service*), missing
reshape long dob group_, i(id) j(birth_no)
drop if missing(dob) 
keep if inrange(new_svcstart, dob, dob+365)
drop id

egen date = rowmin(new_admit new_svcstart)
gen month = floor((date-dob)/30)
drop if month < 0

gen oop = coinsurance + copay + deductible
replace oop = . if oop < 0
gen tc = oop + plan_paid 
replace tc = . if plan_paid < 0

compress
save "$working\Spending_FullYear_20210924.dta", replace
********************************************************************************


***** 2. Collapse to mean and median spending by group/month
use "$working\Spending_FullYear_20210924.dta", clear

// first, eliminate repeated payment measures (multiple lines per claim id)
cap drop cpt4_* 
duplicates drop

* Correct to 2020 USD
cap gen service_year = year(new_svcstart)
foreach v of varlist oop tc { 
	replace `v' = `v' * 1.0903 if service_year == 2014
	replace `v' = `v' * 1.0890 if service_year == 2015
	replace `v' = `v' * 1.0754 if service_year == 2016
	replace `v' = `v' * 1.0530 if service_year == 2017
	replace `v' = `v' * 1.0261 if service_year == 2018
	replace `v' = `v' * 1.0123 if service_year == 2019
}

// Added 1/10/2022: change to 2020 USD using *medical services* component of CPI
// Source: https://www.statista.com/statistics/187228/consumer-price-index-for-medical-care-services-in-the-us-since-1960/
foreach v of varlist oop tc { 
	replace `v' = `v' / 1.0903 * (564.2/468.4) if service_year == 2014
	replace `v' = `v' / 1.0890 * (564.2/482) if service_year == 2015
	replace `v' = `v' / 1.0754 * (564.2/500.8) if service_year == 2016
	replace `v' = `v' / 1.0530 * (564.2/509) if service_year == 2017
	replace `v' = `v' / 1.0261 * (564.2/522.5) if service_year == 2018
	replace `v' = `v' / 1.0123 * (564.2/549.1) if service_year == 2019
}

// Added 9.29.2021: for claims with COB, replace commercial oop costs to be 0
gen cob = (cob_flag == "Y")
bysort member_composite_id dob new_admit new_svcstart charge_amt: ereplace cob = max(cob)
replace oop = 0 if line_of_business_cd == 3 & cob == 1

// further reduce those without COB flags but with same provider ID and charge amount
gen toreplace = 0 
bysort member_composite_id dob billing_provider_composite_id principal_diagnosis_cd /// 
	new_admit new_svcstart: replace toreplace = _N
replace oop = 0 if line_of_business_cd == 3 & toreplace > 1

// First, collapse to person level
collapse (sum) oop tc, by(member_c dob group_ month) fast
replace oop = 5000 if oop > 5000 // topcode tc and oop
replace tc = 10000 if tc > 10000
egen newid = group(member_c dob)

// Balance panel with 0s if need be
// bysort newid: egen lmonth = max(month)
// fillin newid month
// bysort newid: ereplace lmonth = mean(lmonth)
// drop if month > lmonth & missing(group) // don't balance through end of year if attrition
// bysort newid: ereplace group = mean(group)
// replace tc =0 if missing(tc) 
// replace oop = 0 if missing(oop) 

// Added 9/21/2021: drop top 1% of spending (total cost and OOP) 
// qui sum tc, d
// gen todrop = (tc > `r(p99)')
// // qui sum oop, d
// // replace todrop = 1 if oop > `r(p99)'
// drop if todrop == 1

// Then, collapse to group mean/medians with SEs around mean
collapse (mean) oop tc (sd) sd_oop=oop sd_tc=tc ///
	(count) n_oop=oop n_tc=tc (p50) med_oop=oop med_tc=tc, by(group month) fast

gen se_oop = sd_oop/sqrt(n_oop)
gen se_tc = sd_tc/sqrt(n_tc)
gen lb_oop = oop-1.96*se_oop
gen ub_oop = oop+1.96*se_oop
gen lb_tc = tc-1.96*se_tc
gen ub_tc = tc+1.96*se_tc

// Graph: Total spending (means and medians by group)
// preserve
// twoway (line tc month if group == 0, lcolor(maroon)) (line tc month if group == 1, lcolor(navy)) ///
// 	(rarea lb_tc ub_tc month if group == 0, lcolor(ebblue%30) fcolor(ebblue%30)) /// 
// 	(rarea lb_tc ub_tc month if group == 1, lcolor(gold%30) fcolor(gold%30)) /// 
// 	(scatter tc month if group == 0, color(maroon)) (scatter tc month if group == 1, color(navy)), ///
// 	graphregion(color(white)) legend(order(1 "Medicaid Coverage" 2 "Commercial Coverage")) ///
// 	xtitle("Month of Postpartum Year") ytitle("tc Spending") ylab(,angle(horizontal)) ///
// 	xsc(r(0(1)12)) xlab(0(1)12)
// graph export "$output\Figure_MonthlyTC20210929.png", as(png) replace
//
// drop if month < 3
// twoway (line tc month if group == 0, lcolor(maroon)) (line tc month if group == 1, lcolor(navy)) ///
// 	(rarea lb_tc ub_tc month if group == 0, lcolor(ebblue%30) fcolor(ebblue%30)) /// 
// 	(rarea lb_tc ub_tc month if group == 1, lcolor(gold%30) fcolor(gold%30)) /// 
// 	(scatter tc month if group == 0, color(maroon)) (scatter tc month if group == 1, color(navy)), ///
// 	graphregion(color(white)) legend(order(1 "Medicaid Coverage" 2 "Commercial Coverage")) ///
// 	xtitle("Month of Postpartum Year") ytitle("tc Spending") ylab(,angle(horizontal)) ///
// 	xsc(r(3(1)12)) xlab(3(1)12)
// graph export "$output\Figure_MonthlyTC20210929_9Months.png", as(png) replace
// restore

// Graph: OOP spending (means by group)
preserve
// twoway (line oop month if group == 0, lcolor(maroon)) (line oop month if group == 1, lcolor(navy)) ///
// 	(rarea lb_oop ub_oop month if group == 0, lcolor(ebblue%30) fcolor(ebblue%30)) /// 
// 	(rarea lb_oop ub_oop month if group == 1, lcolor(gold%30) fcolor(gold%30)) /// 
// 	(scatter oop month if group == 0, color(maroon)) (scatter oop month if group == 1, color(navy)), ///
// 	graphregion(color(white)) legend(order(1 "Medicaid Coverage" 2 "Commercial Coverage")) ///
// 	xtitle("Month of Postpartum Year") ytitle("OOP Spending") ylab(,angle(horizontal)) ///
// 	xsc(r(0(1)12)) xlab(0(1)12)
// graph export "$output\Figure_MonthlyOOP20210929.png", as(png) replace

drop if month < 3
twoway (line oop month if group == 0, lcolor(maroon)) (line oop month if group == 1, lcolor(navy)) ///
	(rarea lb_oop ub_oop month if group == 0, lcolor(ebblue%30) fcolor(ebblue%30)) /// 
	(rarea lb_oop ub_oop month if group == 1, lcolor(gold%30) fcolor(gold%30)) /// 
	(scatter oop month if group == 0, color(maroon)) (scatter oop month if group == 1, color(navy)), ///
	graphregion(color(white)) legend(order(1 "Medicaid Coverage" 2 "Commercial Coverage")) ///
	xtitle("Month of Postpartum Year") ytitle("OOP Spending") ylab(,angle(horizontal)) ///
	xsc(r(3(1)12)) xlab(3(1)12)
graph export "$output\Figure_MonthlyOOP20210929_9Months.eps", as(eps) replace
graph export "$output\Figure_MonthlyOOP20210929_9Months.png", as(png) replace
restore
********************************************************************************

