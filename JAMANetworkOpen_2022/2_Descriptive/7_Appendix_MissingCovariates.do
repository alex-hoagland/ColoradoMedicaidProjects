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

local myvars age mc_matasian mc_white mc_matblack mc_mat_otherrace /// 
		mc_mathisp mc_bornoutside mc_mat_married mc_mat_hs mc_mat_coll mc_chronic mc_pnv ///
		mc_firstcare mc_complications mc_csec income
********************************************************************************


***** 1. Generate outcome variables
use "$working/RestrictedSample_20210915.dta", clear

// Added 9/21/2021: drop top 1% of spending (total cost and OOP) 
qui sum tc, d
gen todrop = (tc > `r(p99)')
// qui sum oop, d
// replace todrop = 1 if oop > `r(p99)'
drop if todrop == 1

gen age1 = mc_matage
gen income = income_re

* Replace each variable with missing info
foreach v of local myvars { 
	replace `v' = missing(`v')
}
********************************************************************************


*** Unweighted summary stats
* teffects ipw (group) (`myvars'), pomeans
eststo unweighted_mdcd: estpost sum `myvars' if group == 0
eststo unweighted_comm: estpost sum `myvars' if group == 1
eststo unweighted_diff: qui estpost ttest `myvars', by(group) unequal
********************************************************************************


*** Weighted summary stats
* Generate weight
// qui psmatch2 group `myvars', logit 
// eststo weighted_mdcd: qui estpost ci `myvars' if group == 0 [fweight=_weight]
// eststo weighted_comm: qui estpost ci `myvars' if group == 1 [fweight=_weight]
// eststo weighted_diff: qui estpost ttest `myvars', by(group) unequal
********************************************************************************


***** Build table
cd "$output"
esttab unweighted_mdcd unweighted_comm unweighted_diff /// weighted_mdcd weighted_comm weighted_diff
	 using Appendix6_FRAG.csv, /// 
	cells("sum(pattern(1 1 0) fmt(0)) mean(pattern(1 1 0) fmt(4)) Var(pattern(1 1 0) fmt(4)) p(pattern(0 0 1) fmt(4))") replace
********************************************************************************