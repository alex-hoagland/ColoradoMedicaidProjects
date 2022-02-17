/*******************************************************************************
* Title: Main Binscatters Only
* Created by: Alex Hoagland
* Created on: 2/11/2021
* Last modified on: 2/11/2021
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

local cutoff = 138
********************************************************************************


***** Binscatters of our main outcome variables
local mylab: var lab outcome3
binscatter outcome3 income_re, nq(100) rd(`cutoff') linetype(qfit) ///
	ytitle("Months") ylab(, angle(0)) xtitle("Income (% FPL)") name(out3)
* graph export "$output/Binscatter_outcome3_C`cutoff'.png", as(png) replace

local mylab: var lab outcome4
binscatter outcome4 income_re, nq(100) rd(`cutoff') linetype(qfit) ///
	ytitle("Probability") ylab(, angle(0)) xtitle("Income (% FPL)") name(out4)
* graph export "$output/Binscatter_outcome4_C`cutoff'.png", as(png) replace
********************************************************************************
