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

local myvars age1 age2 age3 mc_matasian mc_white mc_matblack mc_mat_otherrace /// 
		mc_mathisp mc_bornoutside mc_mat_married mc_mat_hs mc_mat_coll mc_chronic mc_pnv ///
		mc_firstcare mc_complications mc_csec ///
		income1 income2 income3 income4 income5 income6
********************************************************************************


***** 1. Generate outcome variables
use "$working/RestrictedSample_20210915.dta", clear

// Added 9/21/2021: drop top 1% of spending (total cost and OOP) 
qui sum tc, d
gen todrop = (tc > `r(p99)')
// qui sum oop, d
// replace todrop = 1 if oop > `r(p99)'
drop if todrop == 1


// quietly{
// 	* Generate new outcome variables
// 	forvalues m = 6/9 { 
// 		gen newout_`m'_comm = (cont_enroll_comm >= `m'*30)
// 		gen newout_`m'_mdcd = (cont_enroll_mdcd >= `m'*30)
//		
// 		* Only count these if enrollment is observed for desired period
// 		replace newout_`m'_comm = . if tot_duration < `m'*30
// 		replace newout_`m'_mdcd = . if tot_duration < `m'*30
// 	}
//	
// 	foreach v of var newout* { 
// 	    replace `v' = . if missing(outcome2)
// 	}
//	
	gen age1 = (inrange(mc_matage,18,29))
	gen age2 = (inrange(mc_matage,30,39))
	gen age3 = mc_matage >= 40

	gen income1 = (inrange(income_re,0,100))
	gen income2 = (inrange(income_re,101,138))
	gen income3 = (inrange(income_re,139,200))
	gen income4 = (inrange(income_re,201,265))
	gen income5 = (inrange(income_re,266,300))
	gen income6 = (inrange(income_re,301,400))
// }
//
// * Only keep sample with 9 months of one or another
// keep if newout_9_comm == 1 | newout_9_mdcd == 1
// gen group = (newout_9_comm == 1)
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
	 using Tab1_FRAG.csv, /// 
	cells("sum(pattern(1 1 0) fmt(0)) mean(pattern(1 1 0) fmt(4)) Var(pattern(1 1 0) fmt(4)) p(pattern(0 0 1) fmt(4))") replace
********************************************************************************