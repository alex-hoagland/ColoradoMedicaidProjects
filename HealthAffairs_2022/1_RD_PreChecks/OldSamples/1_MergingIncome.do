/*******************************************************************************
* Title: Merging birth records with enrollment
* Created by: Alex Hoagland
* Created on: 11/18/2020
* Last modified on: 12/2/2020
* Last modified by: Alex Hoagland

* Purpose: Constructs distribution of all enrollment (Medicaid, commercial, Marketplace)
	by income (over FPL). This is a smoothness checks.
		   
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


***** 1. Begin with birth records--main sample 
*** (only have to run this once)
*** Note: this is the sample of CO births from 2014-2018 by women (19+) enrolled on Medicaid @ time of delivery
// use "$birth\birth record 2014_2019 Medicaid only 19plus.dta", clear
// gen dob2 = date(dob, "MDY")
// drop dob
// rename dob2 dob
// format dob %td 
// order member_composite_id vsid dob
// save "$birth\birth record 2014_2019 Medicaid only 19plus.dta", replace
********************************************************************************

***** 2. Merge in Income Data
use "$birth\birth record 2014_2019 Medicaid only 19plus.dta", clear
keep member_composite_id // for a proper merge
duplicates drop 

merge 1:m member_composite_id using "V:\Planned Enrollment\prelim income data cleaning 9_10_20.dta", ///
	keep(3) nogenerate // keepusing(elig* fed_pov_lvl_pc) // About 1/5 of the missing women merged here

gen pct_fpl = fed_pov_lvl_pc * 100 // TODO: Check this

*** Reshape to one observation per member_composite_id
bysort member_composite_id (elig_effect_strt): gen j = _n
drop gndr age fed_pov_lvl_cd fed_pov_lvl_pc aid_cd elig_cat program_recode 
reshape wide pct_fpl elig* fed_pov_lvl_desc aid_desc, i(member_composite_id) j(j)

*** Merge this file back in to original birth record data
merge 1:m member_composite_id using "$birth\birth record 2014_2019 Medicaid only 19plus.dta", ///
	keep(2 3) nogenerate
	
reshape long pct_fpl elig_effect_strt elig_end_dt fed_pov_lvl_desc aid_desc, i(member_composite_id dob vsid yr) j(num_income_record)
drop if missing(elig_effect_strt) & num_income_record > 1
compress
save "V:\Planned Enrollment\fullsample_income.dta", replace // a long file for all incomes 
********************************************************************************


***** 3. Create income variables (THIS IS UNDER CONSTRUCTION)
*** Assign two incomes: income at 9 months pp, and the first available income (in that time frame) when the woman qualified for pregnancy Medicaid
// *** Identifying pct_fpl for each month after dob
// gen dob2 = date(dob, "MDY")
// drop dob
// rename dob2 dob
// format dob %td 
// order member_composite_id vsid dob
// sort member_composite_id vsid dob elig_effect_strt
//
// replace pct_fpl = 0 if missing(pct_fpl) & !missing(elig_effect_strt) // these are windows w/o income, not missing info
// forvalues i = 0/12 {
// 	gen pct_fpl_month`i' = pct_fpl if ((dob + `i'*30) >= elig_effect_strt & (dob + `i'*30) <= elig_end_dt)
// 	bysort member_composite_id vsid dob: ereplace pct_fpl_month`i' = max(pct_fpl_month`i')
// }

order member_ dob vsid num_income_record elig* aid_desc fed_pov* pct_fpl

*** a. Income at dob-274 (9 months pp)
gen income_9mopp = pct_fpl if elig_effect_strt <= dob-274 & dob-274 <= elig_end_dt
* make sure each woman-dob only has one income assigned
* note: some women have 2 but they have the same income measure, so I'm doing this funky way
gen test = income_9
bysort member_ dob vsid (test): carryforward test, replace
bysort member_ dob vsid (test): gen test2 = (test[1] != test[_N]) // 1.28% of births have multiple sources covering them
gen flag_9mo = (test2 == 1)
* Assign income as mean if there is a problem (for now; hopefully for these women we can use income measure b.)
replace income_9 = test if flag_9mo == 0
bysort member_ dob vsid: ereplace income_9 = mean(income_9) if flag_9mo == 1
drop test*

*** b. First pregnancy-qualifying income (PREFERRED) 
sort member_ dob vsid num_income_record
drop if elig_end_dt < dob-275 // To start, drop all incomes that are more than 9 months before delivery
drop if elig_effect_strt >= dob // Don't look at eligibilities after birth either
gen inpreg = (strpos(aid_desc, "Pregnant") | strpos(aid_desc, "Prenatal"))
gen test = elig_effect_strt if inpreg == 1
bysort member_ dob vsid: ereplace test = min(test) //earliest eligibility start date with pregnancy info
gen income_pregqual = pct_fpl if inpreg == 1 & elig_effect_strt == test 

preserve
drop test // at this point, about 90% of women in the sample have this income measure assigned.
drop if missing(income_pregqual) 
bysort member_composite_id dob (income_pregqual): gen test = (income_pregqual[1] != income_pregqual[_N])
sort test member_ dob // note: there are about 14 women who have multiple income measures on the same day for pregnancy qualification
restore

collapse (max) income_pregqual, by(member_composite_id dob) fast 

**************** 	DON'T GO PAST THIS -- UNDER CONSTRUCTION	 *****************************************************************************
* make sure each woman-dob only has one income assigned
* note: some women have 2 but they have the same income measure, so I'm doing this funky way
gen test = income_pregq
bysort member_ dob vsid (test): carryforward test, replace
bysort member_ dob vsid (test): gen test2 = (test[1] != test[_N]) // 0.01% of births have multiple sources covering them here
gen flag_pregq = (test2 == 1)
drop test*

* Also want to flag those whose income are measured far away from 9 months
gen first_trim = (!missing(income_pregq) & elig_end_dt >= dob - 183)
replace first_trim = . if missing(income_pregq) // 13.45% of births have pregnancy income measured after the first trimester
replace flag_pregq = 1 if first_trim == 0
bysort member_ dob vsid: ereplace flag_pregq = max(flag_pregq)
* Assign incomes for all here (since there aren't many duplicates)
bysort member_ dob vsid: ereplace income_p = mean(income_p)
drop first_trim inpreg

	* Check that the income measured matches the aid description variables
	preserve
	keep if income_9 == pct_fpl | income_pregq == pct_fpl

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
	replace inrange = . if missing(pct_fpl) // matches 99% of the time
	restore

keep member_composite_id vsid dob income_* flag_*
drop flag_non
duplicates drop
gen income_match = (income_9 == income_p) // Only about 26.5% of births have the same income measure across both. 

* Merge into main data
merge 1:m member_composite_id dob using "$birth\birth record 2014_2019 Medicaid only 19plus.dta", nogenerate
order income* flag*, last

compress
save "$birth\birth record 2014_2019 Medicaid only 19plus.dta", replace
********************************************************************************
