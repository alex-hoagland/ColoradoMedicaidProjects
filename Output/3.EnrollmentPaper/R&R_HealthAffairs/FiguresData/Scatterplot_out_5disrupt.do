insheet using \\ad.bu.edu\bumcfiles\BUMC Projects\ColoradoAPCD\Alex\Hoagland_Output\3.EnrollmentPaper\R&R_HealthAffairs/FiguresData/Scatterplot_out_5disrupt.csv

twoway (scatter out_5disrupt income_re, mcolor(navy) lcolor(maroon)) , graphregion(fcolor(white)) xline(138, lpattern(dash) lcolor(gs8)) xtitle(income_re) ytitle(out_5disrupt) legend(off order()) ytitle("Average Probability of Any Coverage Disruption") ylab(, angle(0)) xtitle("Income (% FPL)") xline(138,lcolor(red) lpattern(dash))
