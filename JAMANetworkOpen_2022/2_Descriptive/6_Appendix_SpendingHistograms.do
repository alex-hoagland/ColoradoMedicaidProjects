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
* ssc install psmatch2 

global sarah "\\ad.bu.edu\bumcfiles\BUMC Projects\ColoradoAPCD\Sarah\Sarah Datasets"
global working "\\ad.bu.edu\bumcfiles\BUMC Projects\ColoradoAPCD\Alex\Hoagland_WorkingData\Paper2"
global output "\\ad.bu.edu\bumcfiles\BUMC Projects\ColoradoAPCD\Alex\Hoagland_Output\4.HealthOutcomesPaper"
********************************************************************************


***** 1. Generate regression variables
use "$working/RestrictedSample_20210929.dta", clear

* Transform costs
// replace tc = tc / 1000
replace tc = 250000 if tc > 250000
// drop if tc <= 0
twoway  (hist tc if group == 0, lcolor(ebblue) fcolor(ebblue%30) percent), ///
	graphregion(color(white)) xtitle("Total Spending, Months 3-12 Postpartum") ///
	ytitle("%", angle(horizontal)) ylab(,angle(horizontal)) ///
	xsc(r(0(50000)250000)) xlab(0(50000)250000)
graph export "$output/SpendingHistogram_Mdcd.png", as(png) replace
	
twoway  (hist tc if group == 1, lcolor(red) fcolor(red%30) percent), ///
	graphregion(color(white)) xtitle("Total Spending, Months 3-12 Postpartum") ///
	ytitle("%", angle(horizontal)) ylab(,angle(horizontal)) ///
	xsc(r(0(50000)250000)) xlab(0(50000)250000)
graph export "$output/SpendingHistogram_Comm.png", as(png) replace
********************************************************************************

