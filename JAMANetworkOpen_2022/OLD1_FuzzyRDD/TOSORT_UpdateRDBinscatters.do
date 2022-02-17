forvalues i = 6/6 {	
	use "$working\FuzzyRDD_Limited_3.dta", clear
	quietly{
		* Generate new outcome variables
		forvalues m = 6/9 { 
			gen newout_`m'_comm = (tot_duration_comm >= `m'*30)
			gen newout_`m'_mdcd = (tot_duration_mdcd >= `m'*30)
			
			* Only count these if enrollment is observed for desired period
			replace newout_`m'_comm = . if tot_duration < `m'*30
			replace newout_`m'_mdcd = . if tot_duration < `m'*30
		}
		
		foreach v of var newout* { 
			replace `v' = . if missing(outcome2)
		}
		
		*** Generate running variables for income
		drop if missing(income_re)
		
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

	drop if tot_duration < `i'*30
	drop if newout_`i'_comm == 0 & newout_`i'_mdcd == 0
	
	binscatter newout_`i'_mdcd income_re, rd(138) nq(50) linetype(qfit) ysc(r(.75(.05)1)) ylab(0.75(0.05)1) ytitle("") xtitle("Income (% FPL)")
	graph save  "\\ad.bu.edu\bumcfiles\BUMC Projects\ColoradoAPCD\Alex\Hoagland_Output\4.HealthOutcomesPaper\Updated_RDPlots\Binscatter_`i'mMdcd.gph", replace
	graph export  "\\ad.bu.edu\bumcfiles\BUMC Projects\ColoradoAPCD\Alex\Hoagland_Output\4.HealthOutcomesPaper\Updated_RDPlots\Binscatter_`i'mMdcd.png", as(png) replace
	
	binscatter newout_`i'_comm income_re, rd(138) nq(50) linetype(qfit) ysc(r(0(.05).25)) ylab(0(0.05)0.25) ytitle("") xtitle("Income (% FPL)")
	graph save  "\\ad.bu.edu\bumcfiles\BUMC Projects\ColoradoAPCD\Alex\Hoagland_Output\4.HealthOutcomesPaper\Updated_RDPlots\Binscatter_`i'mComm.gph", replace
	graph export  "\\ad.bu.edu\bumcfiles\BUMC Projects\ColoradoAPCD\Alex\Hoagland_Output\4.HealthOutcomesPaper\Updated_RDPlots\Binscatter_`i'mComm.png", as(png) replace
}
