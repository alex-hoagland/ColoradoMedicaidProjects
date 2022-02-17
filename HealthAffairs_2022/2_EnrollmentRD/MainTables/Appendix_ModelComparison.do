/*******************************************************************************
* Title: Enrollment RD (Paper 2): Local linear RD table
* Created by: Alex Hoagland
* Created on: 3/22/2021
* Last modified on: 
* Last modified by: Alex Hoagland

* Purpose: 
		   
* Notes:
		
* Key edits: 
 
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
rename outcome2 out_1anycomm
rename outcome8 out_2anymarket
rename outcome7 out_3onlymed

rename outcome3 out_4enroldur
rename disrupt_new out_5disrupt
rename disrupt_new_count out_6countdisrupt 
rename outcome5 out_7countgaps 
rename outcome6 out_8gapdur 
gen out_9countswitch = switch
gen out_10anyswitch = (switch > 0 & !missing(switch))
gen out_11anygap = (out_7countgaps > 0 & !missing(out_7))

gen out_12durcomm = tot_duration_comm/30
gen out_13durmdcd = tot_duration_mdcd/30
gen out_14durany = tot_duration/30
gen out_15lossany = ((out_6 > switch + gap) & !missing(out_6) & !missing(switch) & !missing(gap))

// change this one from fraction of year to months 
replace out_8gapdur = out_8gapdur/100*(365/30)

* Order variables
order out_1a out_2 out_3 out_4 out_5 out_6 out_7 out_8 out_9 out_10 out_11 out_12 out_13 out_14 out_15

// Make sure you're only looking at the sample with enrollment info
foreach v of var out_* { 
    replace `v' = . if missing(out_3)
} 
********************************************************************************


***** Local linear regression
// foreach v of var out_* {
// 	rdrobust `v' income_re, c(138) deriv(0) masspoints(off)
// 	eststo ll_`v'
// }
********************************************************************************


***** Parametric models: linear interaction
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
		
		* triangular weights
		gen weight_t = 1-abs(centered/138) if centered < 0
		replace weight_t = 1-abs(centered/861.9) if centered > 0
		replace weight_t = 1 if centered == 0
	}
	
foreach v of var out_* {
	reg `v' treated centered ///
		lin_inter `covar' [aw=weight_t], robust
	eststo lin_`v'
}
********************************************************************************


***** Parametric models: quadratic interaction
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
	
foreach v of var out_* {
	reg `v' treated centered quad ///
		lin_inter quad_inter `covar' [aw=weight_t], robust
	eststo quad_`v'
}
********************************************************************************


***** Parametric models: cubic interaction
// quietly{
// 		cap drop treated centered *_inter quad cub
// 		* Treatment dummy
// 		gen treated = (income_re >= 138)
//
// 		* Center the cut variable
// 		gen centered = income_re - 138
//
// 		* Create appropriate interactions/quadratic terms
// 		* Create variables for any of the desired models here
// 		gen lin_inter = centered * treated
// 		gen quad = centered * centered
// 		gen quad_inter = quad * treated
// 		gen cub = centered * quad
// 		gen cub_inter = cub * treated
// 	}
//	
// foreach v of var out_* {
// 	reg `v' treated centered quad cub ///
// 		lin_inter quad_inter cub_inter `covar' [aw=weight_t], robust
// 	eststo cub_`v'
// }
// ********************************************************************************
//
//
//	
// ***** Build table (2 pieces?)
// cd "$output"
// esttab ll* lin* quad* cub* using Appendix_ModelComparison_FRAG.csv, replace ///
// 	cells(b(fmt(2) star) ci(fmt(2) par) p(fmt(3) par))	
********************************************************************************