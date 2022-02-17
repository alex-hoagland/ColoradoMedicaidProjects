/*******************************************************************************
* Title: Enrollment RD (Paper 2): Local linear RD table
* Created by: Alex Hoagland
* Created on: 3/22/2021
* Last modified on: 
* Last modified by: Alex Hoagland

* Purpose: 
		   
* Notes:
		
* Key edits: 
	- 4.15: Added shading of bandwidths from "donut" local linear regression to 
		binscatters. 
	- 4.16 (this version!): only fits local linear line through bandwidth plot
*******************************************************************************/


***** 0. Packages and directories, load data
* ssc install estout, replace
* ssc install rdrobust
* ssc install rd

global head "\\ad.bu.edu\bumcfiles\BUMC Projects\ColoradoAPCD"
global sarah "$head\Sarah\Sarah Datasets"
global working "$head\Alex\Hoagland_WorkingData\Paper1"
global output "$head\Alex\Hoagland_Output\3.EnrollmentPaper\R&R_HealthAffairs"

cd "$head\Alex\"
use "$working\EnrollmentRD.dta", clear
drop if inrange(income_re,133.01,137.99)

* List covariates
local covar "mc_mathisp mc_matblack mc_white mc_mat_hs mc_mat_coll mc_complications mc_mat_married mc_pnv mc_chronic mc_matage mc_csec mc_preterm" 

* If you want to run this for a single variable
// local myvar "mc_mat_hs"
// gen group = 0 if `myvar' == 0
// replace group = 1 if `myvar' == 1
********************************************************************************


***** Reorder/rename outcome variables
rename outcome7 out_3onlymed
rename outcome3 out_4enroldur
rename disrupt_new out_5disrupt

// Make sure you're only looking at the sample with enrollment info
foreach v of var out_* { 
    replace `v' = . if missing(out_3)
} 

drop out_3
********************************************************************************


***** 1. First, run RD regressions and save data for lines
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
		
		sum 
		gen weight_t = 1-abs(centered/138) if centered < 0
		replace weight_t = 1-abs(centered/861.9) if centered > 0
		replace weight_t = 1 if centered == 0
	}
	
foreach v of var out_* {
	reg `v' treated centered quad ///
		lin_inter quad_inter `covar' [aw=weight_t], robust
	predict yhat_`v', xb
}
********************************************************************************


***** Binscatters of outcome variables with polynomial regressions shown
foreach v of var out_* { 
	if inlist("`v'","out_1anycomm","out_2anymarket","out_3onlymed", ///
		"out_5disrupt") {
		local ylab = "Average Probability of Any Coverage Disruption"
		local mybw = substr("`v'",5,1)
	} 
	else if inlist("`v'","out_4enroldur","out_8gapdur") { 
		local ylab = "Average Months Enrolled During Postpartum Year"
		local mybw = substr("`v'",5,1)
	}
	else if inlist("`v'","out_10anyswitch","out_11anygap") {
	    local ylab = "Probability"
		local mybw = substr("`v'",5,2)
	}
	else {
		local ylab = "Number"
		local mybw = substr("`v'",5,1)
	}
	
	binscatter `v' income_re, nq(100) genxq(bins_`v') rd(138) linetype(none) ///
	ytitle("`ylab'") ylab(, angle(0)) xtitle("Income (% FPL)") ///
	 xline(138,lcolor(red) lpattern(dash)) savedata("$output/FiguresData/Scatterplot_`v'")
	
 	preserve
		collapse (mean) income_re yhat_`v' `v' , by(bins_`v')
		
// 		// want to make sure qfit goes to end of shaded area
// 		gen diff = abs(income_re-(138-bw`mybw'))
// 		egen testdiff = min(diff)
// 		replace income_re = 138-bw`mybw' if diff == testdiff
// 		drop diff testdiff
// 		gen diff = abs(income_re-(138+bw`mybw'))
// 		egen testdiff = min(diff)
// 		replace income_re = 138+bw`mybw' if diff == testdiff
// 		drop diff testdiff
		
		twoway (scatter `v' income_re, color(ebblue%30)) ///
		(qfit yhat_`v' income_re if inrange(income_re,0,137.9), lcolor(ebblue) lwidth(medthick)) ///
		(qfit yhat_`v' income_re if inrange(income_re,138,500), lcolor(ebblue) lwidth(medthick)), ///
		xline(138, lcolor(red) lpattern(dash)) ///
		graphregion(color(white)) ytitle("`ylab'") ylab(, angle(0)) xtitle("Income (% FPL)") ///
		legend(off)
 	restore
  	graph save "$output/LocalLinearBinscatter_`v'.gph", replace
  	graph export "$output/LocalLinearBinscatter_`v'.eps", as(eps) replace
}
********************************************************************************