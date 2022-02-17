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
global sarah "\\ad.bu.edu\bumcfiles\BUMC Projects\ColoradoAPCD\Sarah\Sarah Datasets"
global working "\\ad.bu.edu\bumcfiles\BUMC Projects\ColoradoAPCD\Alex\Hoagland_WorkingData\Paper2"
global output "\\ad.bu.edu\bumcfiles\BUMC Projects\ColoradoAPCD\Alex\Hoagland_Output\4.HealthOutcomesPaper"
********************************************************************************


***** 1. First Stage Regressions
use "$working\FuzzyRDD_Limited_3.dta", clear
quietly{
	* Generate new outcome variables
	forvalues m = 6/9 { 
		gen newout_`m'_comm = (tot_duration_comm >= `m'*30)
		gen newout_`m'_mdcd = (tot_duration_mdcd >= `m'*30)
		
		* Only count these if enrollment is observed for desired period
		replace newout_`m'_comm = . if tot_duration < `m'*30
		replace newout_`m'_mdcd = . if tot_duration < `m'*30
	}
	
	foreach v of var newout* { 
	    replace `v' = . if missing(outcome2)
	}
	
	*** Generate running variables for income
	drop if missing(income_re)
	
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

*** Regressions 
local covar "mc_mathisp mc_matblack mc_white mc_mat_hs mc_mat_coll mc_complications mc_mat_married mc_pnv mc_chronic mc_matage mc_csec mc_preterm" 
cls
foreach v of var newout* {
   forvalues i = 1/4 { 
       di "Outcome: `v'; model: `i'"
		if (`i' == 1) { 
			reg `v' treated `covar'
			test treated
		}
		else if (`i' == 2) { 
			reg `v' treated centered lin_inter `covar'
			test treated
		}
		else if (`i' == 3) { 
			reg `v' treated centered lin_inter quad* `covar'
			test treated
		}
		else if (`i' == 4) { 
			reg `v' treated centered lin_inter quad* cub* `covar'
			test treated
		}
	}	
}
********************************************************************************