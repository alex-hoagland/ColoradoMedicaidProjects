insheet using \\ad.bu.edu\bumcfiles\BUMC Projects\ColoradoAPCD\Alex\Hoagland_Output\2.RDGraphs\Donut\/Binscatter_outcome3_data.csv

twoway (scatter outcome3 income_re, mcolor(navy) lcolor(maroon)) (function .0000735489513099*x^2+-.0153895352780215*x+10.9644831887042, range(0 138) lcolor(maroon)) (function 2.82411024077e-06*x^2+-.0012934079498632*x+9.002622807755472, range(138 424.0855308449399) lcolor(maroon)), graphregion(fcolor(white)) xline(138, lpattern(dash) lcolor(gs8)) xtitle(income_re) ytitle(outcome3) legend(off order()) ytitle("Months") ylab(, angle(0)) xtitle("Income (% FPL)")
