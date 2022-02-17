/*******************************************************************************
* Title: Enrollment RD (Paper 2): Placebo tests for appendix
* Created by: Alex Hoagland
* Created on: 3/30/2021
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
global working "$head\Alex\Hoagland_WorkingData"
global output "$head\Alex\Hoagland_Output\3.EnrollmentPaper\"

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
rename outcome4 out_5disrupt
egen out_6countdisrupt = rowtotal(gap switch)
rename outcome5 out_7countgaps 
rename outcome6 out_8gapdur 
gen out_9countswitch = switch
gen out_10anyswitch = (switch > 0 & !missing(switch))
gen out_11anygap = (out_7countgaps > 0 & !missing(out_7))

// change this one from fraction of year to months 
replace out_8gapdur = out_8gapdur/100*(365/30)

* Order variables
order out_1a out_2 out_3 out_4 out_5 out_6 out_7 out_8 out_9 out_10 out_11

// Make sure you're only looking at the sample with enrollment info
foreach v of var out_* { 
    replace `v' = . if missing(out_3)
} 
********************************************************************************


***** Local linear regression for 4 cutoffs
foreach v of var out_* {
	rdrobust `v' income_re, c(138) deriv(0) masspoints(off) kernel(uniform)
	eststo true_`v'
	rdrobust `v' income_re, c(90) deriv(0) masspoints(off) kernel(uniform)
	eststo f1_`v'
	rdrobust `v' income_re, c(200) deriv(0) masspoints(off) kernel(uniform)
	eststo f2_`v'
	rdrobust `v' income_re, c(250) deriv(0) masspoints(off) kernel(uniform)
	eststo f3_`v'
}
********************************************************************************

	
***** Build table 
cd "$output"
esttab true_* f1_* f2_* f3_* using Appendix_PlaceboTests_FRAG.csv, replace ///
	cells(b(fmt(2) star) ci(fmt(2) par))	
********************************************************************************