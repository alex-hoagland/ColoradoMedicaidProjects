/*******************************************************************************
* Title: Create Medicaid-indexed prices
* Created by: Alex Hoagland
* Created on: 1/13/2022
* Last modified on: 
* Last modified by: Alex Hoagland

* Purpose: Based on methodology available in eAppendix for this paper: https://tinyurl.com/3vfe6cya
		   
* Notes: methodology (#s changed for this paper): 
	"We analyzed Medicaid price-normalized costs to facilitate comparisons between the
	overall health care utilization across coverage types, after removing the impact of differential
	prices for health care services in the difference insurance plans. To create this outcome, we
	calculated the mean costs of CPT procedure codes found in claims in the Medicaid database, and 
	then applied the mean Medicaid cost per procedure to all claims (whether they were Medicaid or
	Marketplace) to derive the price-normalized cost for each individual in our sample.
	The initial average costs of CPT procedure codes were calculated from claims with only a single
	unique CPT code, which accounted for **2,137** CPT codes. For the remaining codes found only in
	multiple-CPT claims, we iteratively calculated the average costs of the unknown CPT codes by
	subtracting total claim costs by the costs calculated from known codes. For the claims with “j”
	total CPT codes with “j-1” CPT codes with a calculated cost, where “j” is an integer, the
	remainder provides an estimate of the unknown CPT code’s cost. These averages were then
	stored and used in the next iteration to calculate remaining prices. This process had reached
	completion with a total of six iterations. This process allowed us to calculate prices for **3,235**
		CPT codes, leaving **1,197** unmatched codes, which represented only **9.0%** (9.0% in Medicaid, 10% in commercial, p < 0.001) of claims, for which
	we set the effective price to $0."
		
* Key edits: 
   -  TODO: what do we do with negative claims? 
*******************************************************************************/

***** 0. Directories & Packages 
global head "\\ad.bu.edu\bumcfiles\BUMC Projects\ColoradoAPCD"
global apcd "$head\raw\20.59_BU_Continuity_of_Medicaid\Medical_Claims_Header"
global apcdline "$head\raw\20.59_BU_Continuity_of_Medicaid\Medical_Claims_Line"
global sarah "$head\Sarah\Sarah Datasets"
global working "$head\Alex\Hoagland_WorkingData\Paper2"
global output "$head\Alex\Hoagland_Output\4.HealthOutcomesPaper"
********************************************************************************


***** 1. Start with all Medicaid claims, construct initial price index
use "$working\HO_inprogress_20210622.dta", clear
keep if group == 0 // only use Medicaid claims

// create prices (total costs and OOP)
gen oop = coinsurance + copay + deductible
replace oop = . if oop < 0
gen tc = oop + plan_paid 
replace tc = . if plan_paid < 0

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

* Use Medical Services Component of CPI
foreach v of varlist oop tc { 
	replace `v' = `v' / 1.0903 * (564.2/468.4) if service_year == 2014
	replace `v' = `v' / 1.0890 * (564.2/482) if service_year == 2015
	replace `v' = `v' / 1.0754 * (564.2/500.8) if service_year == 2016
	replace `v' = `v' / 1.0530 * (564.2/509) if service_year == 2017
	replace `v' = `v' / 1.0261 * (564.2/522.5) if service_year == 2018
	replace `v' = `v' / 1.0123 * (564.2/549.1) if service_year == 2019
}

drop if missing(cpt4_cd)

save "$working\MedicaidPrices_AllMedicaidClaims.dta", replace
********************************************************************************


***** 2. Initial price index is based off of single-CPT code claims
local mymode = "mean"
use "$working\MedicaidPrices_AllMedicaidClaims.dta", clear
bysort claim_id: keep if _N == 1 // initial pass is 214,513 of 784,348 claims (27%)
collapse (`mymode') tc oop (count) member_composite_id, by(cpt4_cd) fast // covers 2,137 unique CPT codes
rename tc working_tc
rename oop working_oop
rename member_ num_enrollees
keep if num_enrollees > 10 // require enough data points for an average
save "$working\MedicaidPrices.dta", replace
********************************************************************************


***** 3. Iterate for multiple-CPT code claims
local mymode = "mean"
use "$working\MedicaidPrices_AllMedicaidClaims.dta", clear
bysort claim_id: keep if _N > 1 // drop single-code claims
merge m:1 cpt4_cd using "$working\MedicaidPrices.dta", keep(1 3)

// calculate total price so far and subtract from oop / tc
bysort claim_id: ereplace working_tc = total(working_tc)
bysort claim_id: ereplace working_oop = total(working_oop)
replace tc = tc - working_tc
replace oop = oop - working_oop

// drop CPT codes that have already been used
drop if _merge == 3
drop _merge

// now limit attention to claims with a single CPT code and repeat steps in 2
// iteration 2: now 15,989 claims and 1,131 CPT codes (what to do with negatives? truncate to 0 early?)
// iteration 3: now 1,397 claims and 349 CPT codes
// iteration 4: now 92 CPT codes
// iteration 5: now 39 CPT codes
// iteration 6: now 13 CPT codes
// iteration 7: now 4 CPT codes

// if I require prices to be nonnegative
// iteration 2: now 861 CPT codes
// iteration 3: now 154 CPT codes
// iteration 4: now 29 CPT codes
// iteration 5: now 13 CPT codes
// iteration 6: now 2 CPT codes
// iteration 7: now 0 CPT codes
bysort claim_id: keep if _N == 1 
// drop if tc < 0 // require that prices are nonnegative (???)
collapse (`mymode') tc oop (count) member_composite_id, by(cpt4_cd) fast
rename tc working_tc
rename oop working_oop
rename member_ num_enrollees
keep if num_enrollees > 10 // require enough data points for an average
append using "$working\MedicaidPrices.dta" 
save "$working\MedicaidPrices.dta", replace
********************************************************************************


***** 3.a Iterate for multiple-CPT code claims -- for claims that occur infrequently in Medicaid sample
local mymode = "mean"
use "$working\MedicaidPrices_AllMedicaidClaims.dta", clear
bysort claim_id: keep if _N > 1 // drop single-code claims
merge m:1 cpt4_cd using "$working\MedicaidPrices.dta", keep(1 3)

// calculate total price so far and subtract from oop / tc
bysort claim_id: ereplace working_tc = total(working_tc)
bysort claim_id: ereplace working_oop = total(working_oop)
replace tc = tc - working_tc
replace oop = oop - working_oop

// drop CPT codes that have already been used
drop if _merge == 3
drop _merge

// now limit attention to claims with a single CPT code and repeat steps in 2
// iteration 2: now 15,989 claims and 1,131 CPT codes (what to do with negatives? truncate to 0 early?)
// iteration 3: now 1,397 claims and 349 CPT codes
// iteration 4: now 92 CPT codes
// iteration 5: now 39 CPT codes
// iteration 6: now 13 CPT codes
// iteration 7: now 4 CPT codes

// if I require prices to be nonnegative
// iteration 2: now 861 CPT codes
// iteration 3: now 154 CPT codes
// iteration 4: now 29 CPT codes
// iteration 5: now 13 CPT codes
// iteration 6: now 2 CPT codes
// iteration 7: now 0 CPT codes
bysort claim_id: keep if _N == 1 
// drop if tc < 0 // require that prices are nonnegative (???)
collapse (`mymode') tc oop (count) member_composite_id, by(cpt4_cd) fast
rename tc working_tc
rename oop working_oop
rename member_ num_enrollees
// keep if num_enrollees > 10 // require enough data points for an average
append using "$working\MedicaidPrices.dta" 
save "$working\MedicaidPrices.dta", replace
********************************************************************************


***** 4. Check what % of CPT codes in the commercial group have a (nonnegative?) price 
use "$working\HO_inprogress_20210622.dta", clear
keep if group == 1 // commercial claims
merge m:1 cpt4_cd using "$working\MedicaidPrices.dta", keep(1 3) 
	// 90.22% of claims are matched, or 93.29% of CPT codes
	// 87% have a nonnegative price associated with them, or 82% of CPT codes. 
	
	// If I redo this requiring prices to be nonnegative in each step: 
	// 90% of claims are matched, 90.5% of CPT codes
	// All of these have nonnegative prices
********************************************************************************


***** 5. Create a data set using these price indices at the person level
use "$working\HO_inprogress_20210622.dta", clear
merge m:1 cpt4_cd using "$working\MedicaidPrices.dta", keep(3) nogenerate 
drop num_enrollees
bysort claim_id: ereplace working_tc = total(working_tc)
bysort claim_id: ereplace working_oop = total(working_oop)

// Identify type of visit
do "$head\Alex\Hoagland_Code\Paper2\2_Descriptive\2d_SampleHealthUtilizationFRAG.do"

gen p_tc_prev = working_tc if ho_prev == 1
gen p_tc_pcp = working_tc if ho_pcp == 1
gen p_tc_op = working_tc if ho_op == 1
gen p_tc_ed = working_tc if ho_ed == 1
gen p_tc_ip = working_tc if ho_ip == 1
gen p_oop_prev = working_oop if ho_prev == 1
gen p_oop_pcp = working_oop if ho_pcp == 1
gen p_oop_op = working_oop if ho_op == 1
gen p_oop_ed = working_oop if ho_ed == 1
gen p_oop_ip = working_oop if ho_ip == 1

// collapse to visit level for all utilization counts/spending
// first, eliminate repeated payment measures (multiple lines per claim id)
drop cpt4_* 
duplicates drop

// collapse to claim level 
collapse (max) ho* (sum) working_tc working_oop p_* , /// (first) meanprice* medprice*, ///
	by(member_composite claim_id dob new_svcstart group) fast
	
replace ho_ed = 0 if ho_ip == 1 & ho_ed == 1 // no double counting
	
// assume all claims of a given type on a given day are a single visit
collapse (sum) working_tc working_oop p_* , /// (first) meanprice* medprice*, ///
	by(member_composite ho_* dob new_svcstart group) fast
	
replace p_tc_prev = . if ho_prev != 1
replace p_tc_pcp = . if ho_pcp != 1
replace p_tc_op = . if ho_op != 1
replace p_tc_ed = . if ho_ed != 1
replace p_tc_ip = . if ho_ip != 1
replace p_oop_prev = . if ho_prev != 1
replace p_oop_pcp = . if ho_pcp != 1
replace p_oop_op = . if ho_op != 1
replace p_oop_ed = . if ho_ed != 1
replace p_oop_ip = . if ho_ip != 1

// collapse to person level 
collapse (sum) ho_* working_tc working_oop (mean) p_*, /// (first) meanprice* medprice*
	by(member_composite dob group) fast

// merge in with data
preserve
use "$working\RestrictedSample_MedicaidPrices.dta", clear
cap drop ho_* working_* p_*
save "$working\RestrictedSample_MedicaidPrices.dta", replace
restore

merge 1:1 member_c dob using "$working\RestrictedSample_MedicaidPrices.dta", keep(2 3) nogenerate
foreach v of var ho* working_tc working_oop { 
	replace `v' = 0 if missing(`v')
}

compress
save "$working\RestrictedSample_MedicaidPrices", replace
********************************************************************************


***** 6. Re-run spending regressions (for total spending only)
use "$working\RestrictedSample_MedicaidPrices", clear

gen service_year = year(dob)
foreach v of varlist oop tc { 
	replace `v' = `v' / 1.0903 * (564.2/468.4) if service_year == 2014
	replace `v' = `v' / 1.0890 * (564.2/482) if service_year == 2015
	replace `v' = `v' / 1.0754 * (564.2/500.8) if service_year == 2016
	replace `v' = `v' / 1.0530 * (564.2/509) if service_year == 2017
	replace `v' = `v' / 1.0261 * (564.2/522.5) if service_year == 2018
	replace `v' = `v' / 1.0123 * (564.2/549.1) if service_year == 2019
}

// Added 9/21/2021: drop top 1% of spending (total cost) 
qui sum tc, d
gen todrop = (tc > `r(p99)')
drop if todrop == 1

// topcode # of visits too
replace ho_op = 50 if ho_op > 50
replace ho_pcp = 20 if ho_pcp > 20
replace ho_ed = 10 if ho_ed > 10

// Added 9/15/2021: Use unconditional means
replace p_tc_op = 0 if ho_op == 0
replace p_oop_op = 0 if ho_op == 0
replace p_tc_pcp = 0 if ho_pcp == 0 
replace p_oop_pcp = 0 if ho_pcp == 0
replace p_tc_prev = 0 if ho_prev == 0
replace p_oop_prev = 0 if ho_prev == 0
replace p_tc_ed = 0 if ho_ed == 0
replace p_oop_ed = 0 if ho_ed == 0
replace p_tc_ip = 0 if ho_ip == 0 
replace p_oop_ip = 0 if ho_ip == 0

// Aggregate to person level 
replace p_tc_op = p_tc_op * ho_op
replace p_oop_op = p_oop_op * ho_op
replace p_tc_pcp = p_tc_pcp * ho_pcp 
replace p_oop_pcp = p_oop_pcp * ho_pcp
replace p_tc_prev = p_tc_prev * ho_prev
replace p_oop_prev = p_oop_prev * ho_prev
replace p_tc_ed = p_tc_ed * ho_ed
replace p_oop_ed = p_oop_ed * ho_ed
replace p_tc_ip = p_tc_ip * ho_ip
replace p_oop_ip = p_oop_ip * ho_ip

local myvars age2 age3 mc_white mc_matblack mc_matasian mc_mathisp mc_bornoutside mc_mat_married mc_mat_hs mc_mat_coll mc_chronic mc_pnv mc_firstcare mc_complications mc_csec income2 income3 income4 income5 income6
		
local myouts_personweighted working_tc p_tc_op p_tc_pcp p_tc_ed p_tc_ip 

gen age1 = (inrange(mc_matage,18,27))
gen age2 = (inrange(mc_matage,30,39))
gen age3 = mc_matage >= 40

gen income2 = (inrange(income_re,101,138))
gen income3 = (inrange(income_re,139,200))
gen income4 = (inrange(income_re,201,265))
gen income5 = (inrange(income_re,266,300))
gen income6 = income_re > 300 & !missing(income_re)

gen byear = year(dob)

cls
foreach y of local myouts_personweighted { 
	
	// Gaussian model 
	// Average % change for each group
	qui sum `y' if group == 0
	qui gen mean1 = `r(mean)'
	qui sum `y' if group == 1
	qui gen mean2 = `r(mean)'
	qui gen amean = (mean1+mean2)/2
	
	di " "
	di "OUTCOME: `y'"
	ttest `y', by(group) unequal
	reg `y' group `myvars' i.byear
	drop mean1 mean2 amean
}
********************************************************************************