/*******************************************************************************
* Title: Appendix figures: smoothness of covariates
* Created by: Alex Hoagland
* Created on: 11/18/2020
* Last modified on: 3/22/2021
* Last modified by: Alex Hoagland

* Purpose: 
		   
* Notes: 
		
* Key edits: 
   -  
*******************************************************************************/


***** 0. Packages and directories, load data
* ssc install binscatter

global head "\\ad.bu.edu\bumcfiles\BUMC Projects\ColoradoAPCD"
global sarah "$head\Sarah\Sarah Datasets"
global working "$head\Alex\Hoagland_WorkingData"
global output "$head\Alex\Hoagland_Output\1.CovariateSmoothness"

use "$working\Paper1\EnrollmentRD.dta", clear
drop if inrange(income_re, 133.01, 137.99)
********************************************************************************


***** 1. Check smoothness of birth record covariates
foreach v of varlist mc_* {	
	binscatter `v' income_re if inrange(income_re, 0.01, 300), line(qfit) rd(133) nq(100) ///
		xline(133, lpattern(dash) lcolor(red)) ///
		xtitle("Income as % of FPL") ytitle("Probability") ///
		ylab(, angle(0)) ///
		savegraph("$output\Binscatter_`v'.gph") replace
}
********************************************************************************
