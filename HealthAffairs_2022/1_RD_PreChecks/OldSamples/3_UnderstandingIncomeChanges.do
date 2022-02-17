/*******************************************************************************
* Title: Understanding changes in income for women on Medicaid postpartum
* Created by: Alex Hoagland
* Created on: 12/11/2020
* Last modified on: 
* Last modified by: Alex Hoagland

* Purpose: Examine:
	(1) how many (%) women have different incomes over time,
	(2) mean number of income changes per woman, 
	(3) when those income changes occur
	(4) rate of missing data by months postpartum
		   
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


***** 1. How many women have different incomes over time (between 0 and 12 months pp)
*** Note: this is the sample of CO births from 2014-2018 by women (19+) enrolled on Medicaid @ time of delivery
use "$birth\birth record 2014_2019 Medicaid only 19plus.dta", clear
keep member_composite_id dob vsid pct_fpl*
reshape long pct_fpl_month, i(member_ dob vsid) j(months_pp)
gen income_date = dob+months_pp*30
format income_date %td

* ID income changes
bysort member_ dob vsid (months_pp): gen inc_change = (pct_ != pct_[_n-1])
bysort member_ dob vsid (months_pp): replace inc_change = . if _n == 1
replace inc_change = . if pct_ == .

* How many women switch incomes at least once?
preserve
collapse (max) inc_change, by(member_ dob vsid) fast
drop if missing(inc_change) // 66.5% of women have income changes pp.
sum inc_change
restore

*** How many women have changes in their fed poverty level *description*?
preserve
use "V:\Planned Enrollment\fullsample_income.dta", clear
gen lb = . 
gen ub = . 

replace lb = 0 if strpos(fed_pov_lvl_desc, "Up to")
replace lb = 41 if strpos(fed_pov_lvl_desc, "41")
replace lb = 60 if strpos(fed_pov_lvl_desc, "60")
replace lb = 69 if strpos(fed_pov_lvl_desc, "69")
replace lb = 101 if strpos(fed_pov_lvl_desc, "101")
replace lb = 108 if strpos(fed_pov_lvl_desc, "108")
replace lb = 134 if strpos(fed_pov_lvl_desc, "134")
replace lb = 139 if strpos(fed_pov_lvl_desc, "139")
replace lb = 143 if strpos(fed_pov_lvl_desc, "143")
replace lb = 157 if strpos(fed_pov_lvl_desc, "157")
replace lb = 186 if strpos(fed_pov_lvl_desc, "186")
replace lb = 191 if strpos(fed_pov_lvl_desc, "191")
replace lb = 196 if strpos(fed_pov_lvl_desc, "196")
replace lb = 201 if strpos(fed_pov_lvl_desc, "201")
replace lb = 206 if strpos(fed_pov_lvl_desc, "206")
replace lb = 214 if strpos(fed_pov_lvl_desc, "214")
replace lb = 251 if strpos(fed_pov_lvl_desc, "251")
replace lb = 261 if strpos(fed_pov_lvl_desc, "261")
replace lb = 300 if strpos(fed_pov_lvl_desc, "300")
replace lb = 450 if strpos(fed_pov_lvl_desc, "Over 450")

replace ub = 40 if strpos(fed_pov_lvl_desc, "Up to")
replace ub = 59 if strpos(fed_pov_lvl_desc, "41")
replace ub = 68 if strpos(fed_pov_lvl_desc, "60")
replace ub = 100 if strpos(fed_pov_lvl_desc, "69")
replace ub = 107 if strpos(fed_pov_lvl_desc, "101")
replace ub = 133 if strpos(fed_pov_lvl_desc, "108")
replace ub = 138 if strpos(fed_pov_lvl_desc, "134")
replace ub = 142 if strpos(fed_pov_lvl_desc, "139")
replace ub = 156 if strpos(fed_pov_lvl_desc, "143")
replace ub = 185 if strpos(fed_pov_lvl_desc, "157")
replace ub = 190 if strpos(fed_pov_lvl_desc, "186")
replace ub = 195 if strpos(fed_pov_lvl_desc, "191")
replace ub = 200 if strpos(fed_pov_lvl_desc, "196")
replace ub = 205 if strpos(fed_pov_lvl_desc, "201")
replace ub = 213 if strpos(fed_pov_lvl_desc, "206")
replace ub = 250 if strpos(fed_pov_lvl_desc, "214")
replace ub = 260 if strpos(fed_pov_lvl_desc, "251")
replace ub = 300 if strpos(fed_pov_lvl_desc, "261")
replace ub = 450 if strpos(fed_pov_lvl_desc, "300")
replace ub = 1000 if strpos(fed_pov_lvl_desc, "Over 450")

gen inrange = inrange(pct_fpl, lb, ub)
replace inrange = . if missing(pct_fpl) // this matches 96% of the time. 
restore
********************************************************************************


***** 2. Mean number of income changes per woman
preserve
collapse (sum) inc_change, by(member_ dob vsid) fast
sum inc_change // Average # of changes = 1.28
restore
********************************************************************************


***** 3. When those income changes occur (i) with respect to the date of delivery? and (ii) over calendar year
*** Frequency of income changes with respect to months pp
hist months_pp if inc_change == 1, discrete percent ///
	xtitle("Months Postpartum") subtitle("Frequency of income changes postpartum") ///
	xsc(r(1(1)12)) xlab(1(1)12)
graph export "$temp\Output\IncomeDistributions\IncomeChanges_MonthsPP.png", as(png) replace
	// seems like most income changes happen in the 3rd month pp.

*** Frequency of income changes by calendar month
gen month = month(income_date)
hist month if inc_change == 1, discrete percent ///
	xtitle("Month of Year") subtitle("Frequency of income changes postpartum") ///
	xsc(r(1(1)12)) xlab(1(1)12)
graph export "$temp\Output\IncomeDistributions\IncomeChanges_MonthofYear.png", as(png) replace
	// maybe more likely in January and April, but not by much?
	// are changes in pct_fpl in January just mechanical, because of changes in the poverty line?
********************************************************************************


***** 4. Frequency of missing data
// note: this is not having 0 income, but being missing from income file altogether
gen missing = (missing(pct_fpl))
collapse (mean) missing, by(months_pp) fast
replace missing = missing*100
format missing %4.2f
********************************************************************************
