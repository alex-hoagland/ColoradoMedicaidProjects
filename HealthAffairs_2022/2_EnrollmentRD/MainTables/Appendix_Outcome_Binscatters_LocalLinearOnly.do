/*******************************************************************************
* Title: Enrollment RD (Paper 2): Local linear RD table
* Created by: Alex Hoagland
* Created on: 3/22/2021
* Last modified on: 
* Last modified by: Alex Hoagland

* Purpose: 
		   
* Notes:
		
* Key edits: 
	- 4.15: Added shading of bandwidths from "donut" local linear regression to 
		binscatters. 
	- 4.16 (this version!): only fits local linear line through bandwidth plot
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
use "$working\Paper1\EnrollmentRD.dta", clear
drop if inrange(income_re,133.01,137.99)

* List covariates
local covar "mc_mathisp mc_matblack mc_white mc_mat_hs mc_mat_coll mc_complications mc_mat_married mc_pnv mc_chronic mc_matage mc_csec mc_preterm" 

* If you want to run this for a single variable
// local myvar "mc_mat_hs"
// gen group = 0 if `myvar' == 0
// replace group = 1 if `myvar' == 1
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


***** 1. First, run RD regressions and save data for lines
foreach v of var out_* { 
	preserve
	cap rdplot `v' income_re, c(138) kernel(uniform) genvars hide
		// this command throws an error, ignore it
	rename rdplot_id id
	collapse (max) income_re rdplot*, by(id) fast
	compress
	save "$working\tomerge_plot_`v'", replace
	restore
}

foreach v of var out_* {
    preserve
	use "$working\tomerge_plot_`v'", clear
	drop if missing(id) 
	save, replace
	restore
}

foreach v of var out_* { 
	merge m:1 income_re using "$working\tomerge_plot_`v'", keepusing(rdplot_hat) ///
		keep(1 3) nogenerate
	rename rdplot_hat yhat_`v'
}
********************************************************************************


***** Read in bandwidths
preserve
import delimited "$working\Paper1\Bandwidths.csv", clear
drop if missing(bw)
gen i = 1
reshape wide bw, i(i) j(ïoutcome)
cap drop v3
save "$working\Paper1\tomerge.dta", replace
restore

gen i = 1 
merge m:1 i using "$working\Paper1\tomerge.dta", nogenerate
********************************************************************************


***** Binscatters of outcome variables with local linear regressions shown
foreach v of var out_* { 
	if inlist("`v'","out_1anycomm","out_2anymarket","out_3onlymed", ///
		"out_5disrupt") {
		local ylab = "Probability"
		local mybw = substr("`v'",5,1)
	} 
	else if inlist("`v'","out_4enroldur","out_8gapdur") { 
		local ylab = "Months"
		local mybw = substr("`v'",5,1)
	}
	else if inlist("`v'","out_10anyswitch","out_11anygap") {
	    local ylab = "Probability"
		local mybw = substr("`v'",5,2)
	}
	else {
		local ylab = "Number"
		local mybw = substr("`v'",5,1)
	}
	
	binscatter `v' income_re, nq(100) genxq(bins_`v') rd(138) linetype(none) ///
	ytitle("`ylab'") ylab(, angle(0)) xtitle("Income (% FPL)") ///
	 xline(138,lcolor(red) lpattern(dash))
	
 	preserve
		collapse (mean) income_re yhat_`v' `v' bw`mybw', by(bins_`v')
		
		// want to make sure qfit goes to end of shaded area
		gen diff = abs(income_re-(138-bw`mybw'))
		egen testdiff = min(diff)
		replace income_re = 138-bw`mybw' if diff == testdiff
		drop diff testdiff
		gen diff = abs(income_re-(138+bw`mybw'))
		egen testdiff = min(diff)
		replace income_re = 138+bw`mybw' if diff == testdiff
		drop diff testdiff
		
		local lb = round(138 - bw`mybw'[1])
		local ub = round(138 + bw`mybw'[1])
		twoway (scatter `v' income_re, color(ebblue%30)) ///
		(qfit yhat_`v' income_re if inrange(income_re,`lb',137.9), lcolor(ebblue) lwidth(medthick)) ///
		(qfit yhat_`v' income_re if inrange(income_re,138,`ub'), lcolor(ebblue) lwidth(medthick)), ///
		xline(`lb'(0.1)`ub', lcolor(gray*0.20)) xline(138, lcolor(red) lpattern(dash)) ///
		graphregion(color(white)) ytitle("`ylab'") ylab(, angle(0)) xtitle("Income (% FPL)") ///
		legend(off)
 	restore
  	graph save "$output/LocalLinearBinscatter_`v'.gph", replace
  	graph export "$output/LocalLinearBinscatter_`v'.png", as(png) replace
}
********************************************************************************