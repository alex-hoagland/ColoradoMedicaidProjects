/*******************************************************************************
* Title: Enrollment RDs: Parametric
* Created by: Alex Hoagland
* Created on: 3/12/2021
* Last modified on: 3/12/2021
* Last modified by: Alex Hoagland

* Purpose: 
		   
* Notes:
		
* Key edits: 
 
*******************************************************************************/


***** 0. Packages and directories, load data
*ssc install rdrobust
*ssc install rd

global head "\\ad.bu.edu\bumcfiles\BUMC Projects\ColoradoAPCD"
global sarah "$head\Sarah\Sarah Datasets"
global working "$head\Alex\Hoagland_WorkingData"
global output "$head\Alex\Hoagland_Output\2.RDGraphs\Parametric\"

use "$working\EnrollmentRD.dta", clear
drop if inrange(income_re,133.01,137.99) // if you want the "donut" approach

local covar "mc_mathisp mc_matblack mc_white mc_mat_hs mc_mat_coll mc_complications mc_mat_married mc_pnv mc_chronic mc_matage mc_csec mc_preterm" 
	// any covariates you want
local cutoff = 138
local model = 1
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
		cap drop treated centered *_inter quad cub bin*
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
	}
	********************************************************************************


	***** Parametric RDs (robust standard errors; discuss this?)
	//cls
	di "Outcome`i', Model `model'"
	if (`model' == 1) { 
		reg `outcome' treated centered `covar', robust
		local r2r = e(r2)
	}
	else if (`model' == 2) { 
		reg `outcome' treated centered lin_inter `covar', robust
		local r2r = e(r2)
	}
	else if (`model' == 3) { 
		reg `outcome' treated centered quad `covar', robust
		local r2r = e(r2)
	}
	else if (`model' == 4) { 
		reg `outcome' treated centered quad lin_inter quad_inter `covar', robust
		local r2r = e(r2)
	}
	else if (`model' == 5) { 
		reg `outcome' treated centered quad cub `covar', robust
		local r2r = e(r2)
	}
	else if (`model' == 6) { 
		reg `outcome' treated centered quad cub lin_inter quad_inter cub_inter `covar', robust
		local r2r = e(r2)
	}
	********************************************************************************


	***** Assess fit of model with data and outcome (Lee and Lemieux (2010))
	quietly{
		binscatter `outcome' centered, nq(50) rd(`cutoff') linetype(qfit) ///
			genxq(bins)
		graph drop * 
		forvalues i = 1/48 { 
			gen bin`i' = (bins == `i')
		}

		* Unrestricted regression
		if (`model' == 1) { 
			qui reg `outcome' treated centered bin* `covar', robust
			local r2u = e(r2)
			local myn = e(N)
		}
		else if (`model' == 2) { 
			qui reg `outcome' treated centered lin_inter bin* `covar', robust
			local r2u = e(r2)
			local myn = e(N)
		}
		else if (`model' == 3) { 
			qui reg `outcome' treated centered quad bin* `covar', robust
			local r2u = e(r2)
			local myn = e(N)
		}
		else if (`model' == 4) { 
			qui reg `outcome' treated centered quad lin_inter quad_inter bin* `covar', robust
			local r2u = e(r2)
			local myn = e(N)
		}
		else if (`model' == 5) { 
			qui reg `outcome' treated centered quad cub bin* `covar', robust
			local r2u = e(r2)
			local myn = e(N)
		}
		else if (`model' == 6) { 
			qui reg `outcome' treated centered quad cub lin_inter quad_inter cub_inter bin* `covar', robust
			local r2u = e(r2)
			local myn = e(N)
		}
	}

	* F stat for test
	local F = ((`r2u'-`r2r')/50)/((1-`r2u')/(`myn'-50-1))
	di "F stat: `F'"
	di "p-value:"
	di 1-F(50,`myn'-50-1,`F')
}
********************************************************************************