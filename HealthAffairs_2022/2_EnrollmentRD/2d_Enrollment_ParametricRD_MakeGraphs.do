/*******************************************************************************
* Title: Enrollment RDs: Parametric
* Created by: Alex Hoagland
* Created on: 3/12/2021
* Last modified on: 3/12/2021
* Last modified by: Alex Hoagland

* Purpose: plots the predicted income function with data to assess model fit
		   
* Notes:
		
* Key edits: 
 
*******************************************************************************/


***** 0. Packages and directories, load data
*ssc install rdrobust
*ssc install rd

local covar "mc_mathisp mc_matblack mc_white mc_mat_hs mc_mat_coll mc_complications mc_mat_married mc_pnv mc_chronic mc_matage mc_csec mc_preterm" 
	// any covariates you want
local cutoff = 138

global head "\\ad.bu.edu\bumcfiles\BUMC Projects\ColoradoAPCD"
global sarah "$head\Sarah\Sarah Datasets"
global working "$head\Alex\Hoagland_WorkingData"

use "$working\EnrollmentRD.dta", clear
drop if inrange(income_re,133.01,137.99) // if you want the "donut" approach

cls
* Loop through all models
forvalues m = 1/6 {
	local model = `m'
	cap mkdir "$head\Alex\Hoagland_Output\2.RDGraphs\Parametric\Model`model'"
	global output "$head\Alex\Hoagland_Output\2.RDGraphs\Parametric\Model`model'"
	
	* Loop through all outcomes
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
			cap drop treated centered *_inter quad cub yhat
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
			predict yhat, xb
		}
		else if (`model' == 2) { 
			reg `outcome' treated centered lin_inter `covar', robust
			predict yhat, xb
		}
		else if (`model' == 3) { 
			reg `outcome' treated centered quad `covar', robust
			predict yhat, xb
		}
		else if (`model' == 4) { 
			reg `outcome' treated centered quad lin_inter quad_inter `covar', robust
			predict yhat, xb
		}
		else if (`model' == 5) { 
			reg `outcome' treated centered quad cub `covar', robust
			predict yhat, xb
		}
		else if (`model' == 6) { 
			reg `outcome' treated centered quad cub lin_inter quad_inter cub_inter `covar', robust
			predict yhat, xb
		}
		********************************************************************************
		
		***** Make the binscatters
		local mylab: var lab `outcome'
		qui sum `outcome' if abs(centered) < 150
		local max1 = r(max)
		qui sum yhat if abs(centered) < 150
		local max2 = r(max)
		local mymax = round(max(`max1', `max2'))
		local div = `mymax'/5
		binscatter `outcome' yhat centered if abs(centered) < 150, nq(100) rd(0) linetype(qfit) ///
			ytitle("") xtitle("Income (Centered at 138% FPL)") ///
			subtitle("Outcome: `mylab' and predicted values from model `m'") ///
			xsc(r(-150(50)150)) xlab(-150(50)150) ///
			legend(order(1 "Sample Values" 2 "Predicted Values"))
		graph export "$output/ModelFit_model`model'_Outcome`i'.png", as(png) replace
	// 	ysc(r(0(`div')`mymax')) ylab(0(`div')`mymax') ///
	}
}
********************************************************************************