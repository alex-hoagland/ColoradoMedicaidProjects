/*******************************************************************************
* Title: Enrollment RDs: Subgroup Analysis
* Created by: Alex Hoagland
* Created on: 3/12/2021
* Last modified on: 
* Last modified by: Alex Hoagland

* Purpose: 
		   
* Notes:
		
* Key edits: 

*******************************************************************************/


***** 0. Packages and directories, load data
local group = "mc_mat_coll" 

global head "\\ad.bu.edu\bumcfiles\BUMC Projects\ColoradoAPCD"
global sarah "$head\Sarah\Sarah Datasets"
global working "$head\Alex\Hoagland_WorkingData"
//cap mkdir "$head\Alex\Hoagland_Output\2.RDGraphs\Parametric\Subgroup\`group'\"
//global output "$head\Alex\Hoagland_Output\2.RDGraphs\Parametric\Subgroup\`group'\"

use "$working\EnrollmentRD.dta", clear
drop if inrange(income_re,133.01,137.99) // if you want the "donut" approach
local covar "mc_mathisp mc_matblack mc_white mc_mat_hs mc_mat_coll mc_complications mc_mat_married mc_pnv mc_chronic mc_matage mc_csec mc_preterm" 
	// any covariates you want
local cutoff = 138
local model = 2

cls
forvalues i = 1/9 {
	local outcome = "outcome`i'" // Choose outcome here to specify different models for different outcomes/ 
	//local model = 6 // Models vary in f(income). Models are: 1. Linear
					//									     2. Linear Interaction
					//									     3. Quadratic
					//									     4. Quadratic Interaction
					//									     5. Cubic
					//									     6. Cubic Interaction
	********************************************************************************


	***** Prepare the RD variables
	quietly{
		cap drop treated centered *_inter quad cub inter_main
		* Treatment dummy
		gen treated = (income_re >= `cutoff')

		* Center the cut variable
		gen centered = income_re - `cutoff'

		* Create appropriate interactions/quadratic terms
		* Create variables for any of the desired models here
		gen lin_inter = centered * treated
		gen quad = centered * centered
		gen quad_inter = quad * treated
		gen cub = centered * quad
		gen cub_inter = cub * treated
		
		* Interact treatment dummy with main group
		gen inter_main = treated * `group'
	}
	********************************************************************************


	***** Parametric RDs (robust standard errors; discuss this?)
	//cls
	di "Outcome`i', Model `model'"
	if (`model' == 1) { 
		reg `outcome' treated `group' inter_main centered `covar', robust
	}
	else if (`model' == 2) { 
		reg `outcome' treated `group' inter_main centered lin_inter `covar', robust
	}
	else if (`model' == 3) { 
		reg `outcome' treated `group' inter_main centered quad `covar', robust
	}
	else if (`model' == 4) { 
		reg `outcome' treated `group' inter_main centered quad lin_inter quad_inter `covar', robust
	}
	else if (`model' == 5) { 
		reg `outcome' treated `group' inter_main centered quad cub `covar', robust
	}
	else if (`model' == 6) { 
		reg `outcome' treated `group' inter_main centered quad cub lin_inter quad_inter cub_inter `covar', robust
	}
	********************************************************************************
}

* Report mean of group variable 
sum `group', d
********************************************************************************