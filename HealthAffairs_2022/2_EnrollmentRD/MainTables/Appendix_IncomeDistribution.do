/*******************************************************************************
* Title: Check enrollment distributions
* Created by: Alex Hoagland
* Created on: 12/9/2020
* Last modified on: 2/5/2021
* Last modified by: Alex Hoagland

* Purpose: Constructs enrollment histograms by income for women in our sample. 
		   
* Notes: 
		
* Key edits: 
   -  
*******************************************************************************/


***** 0. Packages and directories, load data
* ssc install binscatter

global head "\\ad.bu.edu\bumcfiles\BUMC Projects\ColoradoAPCD"
global sarah "$head\Sarah\Sarah Datasets"
global working "$head\Alex\Hoagland_WorkingData"
global output "$head\Alex\Hoagland_Output\3.EnrollmentPaper\"

cd "$head\Alex\"
use "$working\EnrollmentRD.dta", clear
********************************************************************************


***** 1. Check smoothness of income distributions 
hist income_re if inrange(income_re,0.1,300), ///
	percent fcolor(ebblue%20) lcolor(ebblue) ///
	graphregion(color(white)) ///
	xline(133,lcolor(orange) lpattern(dash)) ///
	xline(138,lcolor(red) lpattern(dash)) ///
	xtitle("Assigned Income (% of FPL)") ytitle("Percent") ylab(, angle(0)) 
graph export "$output\IncomeDistribution_Full.png", as(png) replace

replace income_re = round(income_re)
hist income_re if inrange(income_re,120,150), discrete ///
	percent fcolor(ebblue%20) lcolor(ebblue) ///
	graphregion(color(white)) ///
	xline(133,lcolor(orange) lpattern(dash)) ///
	xline(138,lcolor(red) lpattern(dash)) ///
	xtitle("Assigned Income (% of FPL)") ytitle("Percent") ylab(, angle(0)) 
graph export "$output\IncomeDistribution_Zoomed.png", as(png) replace
********************************************************************************
