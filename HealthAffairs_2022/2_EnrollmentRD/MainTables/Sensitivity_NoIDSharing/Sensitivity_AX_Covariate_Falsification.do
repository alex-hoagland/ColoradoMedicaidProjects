/*******************************************************************************
* Title: Enrollment RD (Paper 1): Falsification tests with covariates as outcomes
* Created by: Alex Hoagland
* Created on: 3/23/2021
* Last modified on: 
* Last modified by: Alex Hoagland

* Purpose: 
		   
* Notes:
		
* Key edits: 
 
*******************************************************************************/


* ssc install estout, replace

global head "\\ad.bu.edu\bumcfiles\BUMC Projects\ColoradoAPCD"
global sarah "$head\Sarah\Sarah Datasets"
global working "$head\Alex\Hoagland_WorkingData\Paper1"
global output "$head\Alex\Hoagland_Output\3.EnrollmentPaper\Sensitivity_NoIDSharing"

cd "$head\Alex\"
use "$working\FuzzyRDD_Limited_3.dta", clear
drop if inrange(income_re,133.01,137.99)

* List covariates
local covar mc_matage mc_white mc_matblack mc_matasian mc_mathisp ///
	mc_mat_other mc_born ///
	mc_mat_hs mc_mat_coll mc_mat_married ///
	 mc_pnv mc_firstcare mc_chronic mc_preterm mc_complications mc_csec 

* If you want to run this for a single variable
// local myvar "mc_mat_hs"
// gen group = 0 if `myvar' == 0
// replace group = 1 if `myvar' == 1

* Method: 1 is standard, 2 is local linear, 3 is parametric with limited bandwidth
local method = 2
local bw = 30 // only used if method == 3
********************************************************************************


***** 1. First method: standard parameteric
// note: this returns very precise 0s, possibly due to overfitting? 
if (`method' == 1) {
    ***** Loop for all covariates
	local covcount = 0
	foreach c of local covar { 
		local covcount = `covcount' + 1
		
		***** Summarize for either group 
		// 	eststo full_low`covcount': qui estpost sum out_* if income_re <= 133
		// 	eststo full_high`covcount': qui estpost sum out_* if income_re >= 138

		***** Run full parametric subgroup RD
		** Prepare the RD variables
		quietly{
			cap drop treated centered *_inter quad cub
			* Treatment dummy
			gen treated = (income_re >= 138)

			* Center the cut variable
			gen centered = income_re - 138

			* Create appropriate interactions/quadratic terms
			* Create variables for any of the desired models here
			gen lin_inter = centered * treated
			gen quad = centered * centered
			gen quad_inter = quad * treated
			gen cub = centered * quad
			gen cub_inter = cub * treated
		}

		// Need to drop `c' from `covar' before including 
		local newcov = regexr("`covar'","`c'"," ")
		local newcov = regexr("`newcov'","mc_mat_other"," ")
		reg `c' treated centered quad cub ///
				lin_inter quad_inter cub_inter `newcov', vce(cluster member_c)
			eststo rd`covcount'_`v'
	}
			
	***** Build table 
	cd "$output"		
	esttab rd* using Appendix_CovTab_FRAG.csv, replace ///
		cells(b(fmt(2) star) ci(fmt(2) par) p(fmt(3) par))	
}
else if (`method' == 2) { 
    // local linear regression instead of parametric
    foreach c of local covar {
	    local newcov = regexr("`covar'","`c'"," ")
		local newcov = regexr("`newcov'","mc_mat_other"," ")
    	rdrobust `c' income_re, c(138) deriv(0) masspoints(off) ///
			vce(cluster member_composite_id) covs(`newcov') kernel(uniform)
		eststo rd_`c'
	}
	
	***** Build table
	cd "$output"		
	esttab rd* using Appendix_CovTab_FRAG.csv, replace ///
		cells(b(fmt(2) star) ci(fmt(2) par) p(fmt(3) par))	
}
else if (`method' == 3) {
    ***** Loop for all covariates
	local covcount = 0
	foreach c of local covar { 
		local covcount = `covcount' + 1
		
		***** Summarize for either group 
		// 	eststo full_low`covcount': qui estpost sum out_* if income_re <= 133
		// 	eststo full_high`covcount': qui estpost sum out_* if income_re >= 138

		***** Run full parametric subgroup RD
		** Prepare the RD variables
		quietly{
			cap drop treated centered *_inter quad cub
			* Treatment dummy
			gen treated = (income_re >= 138)

			* Center the cut variable
			gen centered = income_re - 138

			* Create appropriate interactions/quadratic terms
			* Create variables for any of the desired models here
			gen lin_inter = centered * treated
			gen quad = centered * centered
			gen quad_inter = quad * treated
			gen cub = centered * quad
			gen cub_inter = cub * treated
		}

		local newcov = regexr("`covar'","`c'"," ")
		local newcov = regexr("`newcov'","mc_mat_other"," ")
		reg `c' treated centered quad cub ///
				lin_inter quad_inter cub_inter `newcov' ///
				if inrange(centered, -`bw',`bw'), ///
				vce(cluster member_composite_id)
			eststo rd`covcount'_`v'
	}
			
	***** Build table 
	cd "$output"		
	esttab rd* using Appendix_CovTab_FRAG.csv, replace ///
		cells(b(fmt(2) star) ci(fmt(2) par) p(fmt(3) par))
}
********************************************************************************