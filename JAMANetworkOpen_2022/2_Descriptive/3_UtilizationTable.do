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


***** 1. Generate outcome variables
use "$working/RestrictedSample_20210929.dta", clear

// Added 9/21/2021: drop top 1% of spending (total cost and OOP) 
qui sum tc, d
gen todrop = (tc > `r(p99)')
// qui sum oop, d
// replace todrop = 1 if oop > `r(p99)'
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

// Add binary variables for any visit
foreach v of var ho_* { 
    gen bin_`v' = (`v' > 0 & !missing(`v'))*100
}

// ID variables
local myouts bin_ho_op bin_ho_pcp bin_ho_ed bin_ho_ip ///
	ho_op ho_pcp ho_ed ho_ip /// 
	tc p_tc_op p_tc_pcp p_tc_ed p_tc_ip ///
	oop p_oop_op p_oop_pcp p_oop_ed p_oop_ip 
	
// local weighted_tc p_tc_prev p_tc_ed p_tc_ip 
// local weighted_oop p_oop_prev p_oop_ed p_oop_ip
********************************************************************************


***** PERSON LEVEL DATA: Unadjusted means and differnces 
estimates clear
cls
foreach v of var `myouts' { 
	di "VAR: `v'"
	estpost sum `v' if group == 0, d
	matrix meang0=e(mean)
	estpost sum `v' if group == 1, d
	matrix meang1=e(mean)
	eststo ttest_`v': qui estpost ttest `v', by(group) unequal 
	estadd matrix meang0
	estadd matrix meang1
}
********************************************************************************


// ***** (WEIGHTED) VISIT LEVEL DATA: Unadjusted means and differences
// foreach v of var ho_* { 
//     replace `v' = 1 if `v' == 0
// }
// 	// replace weights = 1 if weights = 0 (one person with 0 visits counts as one person with 1 visit)
//	
// cls
//
// foreach v of var `weighted_tc' { 
//     di "VAR: `v'"
// 	local suf = substr("`v'", 6, .)
// 	sum `v' if group == 0 [fw=ho_`suf']
// 	sum `v' if group == 1 [fw=ho_`suf']
// 	reg `v' group [fw=ho_`suf']
// }
//
// foreach v of var `weighted_oop' { 
//     di "VAR: `v'"
// 	local suf = substr("`v'", 7, .)
// 	sum `v' if group == 0 [fw=ho_`suf']
// 	sum `v' if group == 1 [fw=ho_`suf']
// 	reg `v' group [fw=ho_`suf']
// }
// ********************************************************************************


***** Build table
cd "$output"
esttab ttest_* using Tab2a_FRAG.csv, ///
	noobs cells("meang0(fmt(3)) meang1(fmt(3)) b(star fmt(3)) se(fmt(3)) p(fmt(3))") ///
	star(* 0.5 ** .01 *** 0.001) ///
	collabels("Mu1" "Mu2" "Diff." "Std. Error" "p") replace
********************************************************************************