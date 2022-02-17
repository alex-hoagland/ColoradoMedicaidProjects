/*******************************************************************************
* Title: Enrollment RD (Paper 1): Summary stats table
* Created by: Alex Hoagland
* Created on: 3/22/2021
* Last modified on: =
* Last modified by: Alex Hoagland

* Purpose: 
		   
* Notes:
		
* Key edits: 
 
*******************************************************************************/


***** 0. Packages and directories, load data
* ssc install estout, replace

global head "\\ad.bu.edu\bumcfiles\BUMC Projects\ColoradoAPCD"
global sarah "$head\Sarah\Sarah Datasets"
global working "$head\Alex\Hoagland_WorkingData\Paper1"
global output "$head\Alex\Hoagland_Output\3.EnrollmentPaper\Sensitivity_NoIDSharing"

cd "$head\Alex\"
use "$working\FuzzyRDD_Limited_3.dta", clear
drop if inrange(income_re,133.01,137.99)
********************************************************************************


***** Update percentage variables
foreach v of var mc_white mc_matblack mc_matasian mc_mathisp mc_mat_otherrace mc_bornoutsideus mc_mat_hs mc_mat_coll mc_mat_married mc_first mc_chronic mc_preterm mc_complications mc_csec {
    replace `v' = `v' * 100
}
********************************************************************************


***** Define variables of interest
local myvars mc_matage mc_white mc_matblack mc_matasian mc_mathisp	 mc_mat_otherrace mc_bornoutsideus mc_mat_hs mc_mat_coll mc_mat_married mc_pnv mc_first mc_chronic mc_preterm mc_complications mc_csec
********************************************************************************


***** Summarize on either side of the cutoff 
eststo full_low: qui estpost ci `myvars' if income_re < 138
eststo full_high: qui estpost ci `myvars' if income_re >= 138 
********************************************************************************


***** Summarize in the "narrow" bandwidth, test differences and report p-value
gen testgroup = . 

// largest bandwidth
// replace testgroup = 0 if inrange(income_re,84.01,133.01)
// replace testgroup = 1 if inrange(income_re,138.01,191.99)
// eststo bw_low: qui estpost ci `myvars' if inrange(income_re,84.01,133.01)
// eststo bw_high: qui estpost ci `myvars' if inrange(income_re,138.01,191.99)

// median bandwidth
replace testgroup = 0 if inrange(income_re,90.2,133.01)
replace testgroup = 1 if inrange(income_re,138.01,185.8)
eststo bw_low: qui estpost ci `myvars' if inrange(income_re,90.2,133.01)
eststo bw_high: qui estpost ci `myvars' if inrange(income_re,138.01,185.8)
eststo diff: qui estpost ttest `myvars', by(testgroup) unequal
********************************************************************************


***** Build table
cd "$output"
esttab full_low full_high bw_low bw_high diff using Tab1_FRAG.csv, /// 
	cells("b(pattern(1 1 1 1 0) fmt(2)) se(pattern(1 1 1 1 0) fmt(2)) p(pattern(0 0 0 0 1) par fmt(3))") replace
********************************************************************************