/*******************************************************************************
* Title: Enrollment RDs
* Created by: Alex Hoagland
* Created on: 2/11/2021
* Last modified on: 2/11/2021
* Last modified by: Alex Hoagland

* Purpose: 
		   
* Notes: - Uses the package rdbwselect, based on Imbens and Kalyanaraman (2012)
		
* Key edits: 
   -  Todo: want to do with and without covariates? 
*******************************************************************************/


***** 0. Packages and directories, load data
ssc install rdrobust
ssc install rd

global head "\\ad.bu.edu\bumcfiles\BUMC Projects\ColoradoAPCD"
global sarah "$head\Sarah\Sarah Datasets"
global working "$head\Alex\Hoagland_WorkingData"
global output "$head\Alex\Hoagland_Output\2.RDGraphs\312monthOutcomes\"

use "$working\EnrollmentRD_312monthOutcomes.dta", clear
********************************************************************************


***** Binscatters of our outcome variables
local mylab: var lab outcome1
binscatter outcome1 income_re, nq(100) rd(133) linetype(qfit) ///
	ytitle("") xtitle("Income (% FPL)") ///
	ysc(r(0(.2)1)) ylab(0(.2)1) ///
	subtitle("Outcome: `mylab' as a function of income")
graph export "$output/Binscatter_outcome1_C133.png", as(png) replace
	
foreach v of var outcome2-outcome8 {
	local mylab: var lab `v'
	binscatter `v' income_re, nq(100) rd(133) linetype(qfit) ///
		ytitle("") xtitle("Income (% FPL)") ///
		subtitle("Outcome: `mylab' as a function of income") 
	graph export "$output/Binscatter_`v'_C133.png", as(png) replace
}

*** Naive bandwidth (30)
preserve
keep if inrange(income_re, 103,163)
local mylab: var lab outcome1
	binscatter outcome1 income_re, nq(50) rd(133) linetype(qfit) ///
		ytitle("") xtitle("Income (% FPL)") ///
		ysc(r(0(.2)1)) ylab(0(.2)1) ///
		subtitle("Outcome: `mylab' as a function of income") ///
		note("Uses 133%FPL as the cutoff point.")
	graph export "$output/Binscatter_outcome1_cropped133.png", as(png) replace
	
foreach v of var outcome2-outcome8 {
	local mylab: var lab `v'
	binscatter `v' income_re, nq(50) rd(133) linetype(qfit) ///
		ytitle("") xtitle("Income (% FPL)") ///
		subtitle("Outcome: `mylab' as a function of income") ///
		note("Uses 133%FPL as the cutoff point.")
	graph export "$output/Binscatter_`v'_cropped133.png", as(png) replace
}
restore
********************************************************************************


***** Summary table
summarize outcome* 
summarize outcome* if income_re < 133
summarize outcome* if income_re >= 133
summarize outcome* if inrange(income_re,103,132.99)
summarize outcome* if inrange(income_re,133,163)
********************************************************************************


***** Naive regression -- dummy for above/below cutoff, UPDATE LATER WITH NEW BW
* cutoff is 133
// preserve
// keep if inrange(income_re,118,148)
// gen on = (income_re >= 133)
// gen inter = income_re * on
// foreach v of var outcome* { 
//     reg `v' on, robust
//     * reg `v' income_re on inter, robust
// }
// restore
********************************************************************************


***** First round of RDs: no covariates, optimal bandwidth only
foreach v of var outcome* {
	local mylab: var lab `v'
	rdrobust `v' income_re, c(133) deriv(0) masspoints(off)
	rdplot `v' income_re if inrange(income_re, 93, 173), c(133) ///
		graph_options(graphregion(color(white)) subtitle("RD plot for outcome: `mylab'") ///
		xtitle("Income (% FPL)") note("Note: Cutoff is 133%FPL. Plot made using 'rdplot' command."))
	graph export "$output/RDPlot_`v'_C133.png", as(png) replace
}
********************************************************************************