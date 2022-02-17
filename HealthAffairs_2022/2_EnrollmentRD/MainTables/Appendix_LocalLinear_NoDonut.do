/*******************************************************************************
* Title: Enrollment RD (Paper 2): Local linear RD table -- no donut
* Created by: Alex Hoagland
* Created on: 3/22/2021
* Last modified on: 
* Last modified by: Alex Hoagland

* Purpose: 
		   
* Notes:
		
* Key edits: 
 
*******************************************************************************/


***** 0. Packages and directories, load data
* ssc install estout, replace
* ssc install rdrobust
* ssc install rd

global head "\\ad.bu.edu\bumcfiles\BUMC Projects\ColoradoAPCD"
global sarah "$head\Sarah\Sarah Datasets"
global working "$head\Alex\Hoagland_WorkingData"
global output "$head\Alex\Hoagland_Output\3.EnrollmentPaper\"

cd "$head\Alex\"
use "$working\EnrollmentRD.dta", clear
//drop if inrange(income_re,133.01,137.99)
********************************************************************************


***** Reorder/rename outcome variables
rename outcome2 out_1anycomm
rename outcome8 out_2anymarket
rename outcome7 out_3onlymed

rename outcome3 out_4enroldur
rename outcome4 out_5disrupt
egen out_6countdisrupt = rowtotal(gap switch)
rename outcome5 out_7countgaps 
rename outcome6 out_8gapdur 
gen out_9countswitch = switch
gen out_10anyswitch = (switch > 0 & !missing(switch))
gen out_11anygap = (out_7countgaps > 0 & !missing(out_7))

// change this one from fraction of year to months 
replace out_8gapdur = out_8gapdur/100*(365/30)

* Order variables
order out_1a out_2 out_3 out_4 out_5 out_6 out_7 out_8 out_9 out_10 out_11

// Make sure you're only looking at the sample with enrollment info
foreach v of var out_* { 
    replace `v' = . if missing(out_3)
}
********************************************************************************


***** Summarize on either side of the cutoff 
eststo full_low: qui estpost ci out_* if income_re < 138
eststo full_high: qui estpost ci out_* if income_re >= 138 
********************************************************************************


***** Run local linear RD
foreach v of var out_* {
	rdrobust `v' income_re, c(138) deriv(0) masspoints(off) //kernel(uniform)
	eststo rd_`v'
}
********************************************************************************


***** Run parametric RD
quietly{
		cap drop treated centered *_inter quad cub
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
	
foreach v of var out_* {
	reg `v' treated centered quad cub ///
		lin_inter quad_inter cub_inter `covar', vce(cluster member_c)
	eststo cub_`v'
}
********************************************************************************


***** Build table (2 pieces?)
cd "$output"
esttab full_low full_high using Appendix_NoDonuta_FRAG.csv, /// 
	cells("b(pattern(1 1) fmt(2)) se(pattern(1 1) fmt(2))") replace
	
esttab rd_out_1a* rd_out_2* rd_out_3* rd_out_4* rd_out_5* ///
	   rd_out_6* rd_out_7* rd_out_8* rd_out_9* rd_out_10* rd_out_11* ///
    using Appendix_NoDonutb_FRAG.csv, replace ///
	cells(b(fmt(2) star) ci(fmt(2) par) p(fmt(3) par))
	
	esttab cub_* using Appendix_NoDonutc_FRAG.csv, replace ///
	cells(b(fmt(2) star) ci(fmt(2) par) p(fmt(3) par))
********************************************************************************