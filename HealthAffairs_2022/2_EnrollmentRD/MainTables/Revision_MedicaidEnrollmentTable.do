/*******************************************************************************
* Title: Enrollment RD (Paper 1): Summary stats table
* Created by: Alex Hoagland
* Created on: 3/22/2021
* Last modified on: =
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
global output "$head\Alex\Hoagland_Output\3.EnrollmentPaper\"

cd "$head\Alex\"
use "$working\EnrollmentRD_20211015.dta", clear
drop if inrange(income_re,133.01,137.99)
********************************************************************************


***** Group based on income assignment date 
gen group = (income_assign == 0) // income assessed at the desired time 
	// first of the month after 60 days postpartum
replace group = 2 if inrange(income_assign, 1, 60) // income filled sometime postpartum
replace group = 3 if inrange(income_assign, 61, 150) // last trimester
replace group = 4 if inrange(income_assign, 151, 240) // second trimester
replace group = 5 if inrange(income_assign, 241, 330) // first trimester
replace group = 6 if income_assign > 330 // not assessed while pregnant
replace group = . if missing(income_assign)

forvalues i = 1/6 {
	qui sum tot_duration_mdcd if income_re >= 138 & group == `i'
	di "Average Medicaid duration for income group `i' is " `r(mean)'/365*12
}
********************************************************************************