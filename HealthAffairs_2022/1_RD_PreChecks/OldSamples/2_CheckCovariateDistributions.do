/*******************************************************************************
* Title: Check smoothness of birth record covariates by income
* Created by: Alex Hoagland
* Created on: 11/18/2020
* Last modified on: 12/9/2020
* Last modified by: Alex Hoagland

* Purpose: 
		   
* Notes: 
		
* Key edits: 
   -  
*******************************************************************************/


***** 0. Packages and directories
global maindir "V:\raw\20.59_BU_Continuity_of_Medicaid\"
global birth "V:\Birth Records\working datasets\"
global temp "V:\Hoagland_Code\"

cd "V:\"
* set scheme unluttered
********************************************************************************


***** 1. Check smoothness of income distributions
forvalues i = 0/12 {
	* Make histogram
	qui sum member_composite_id if pct_fpl_month`i' == 0
	local zero = `r(N)'
	qui sum member_composite_id if !missing(pct_fpl_month`i')
	local perc = round(`zero'/`r(N)'*100)
	hist pct_fpl_month`i' if pct_fpl_month`i' > 0, lcolor(midblue) fcolor(midblue%20) ///
		xtitle("Income as % of FPL") ytitle(" ") subtitle("Income Distribution: `i' months postpartum") ///
		xline(138, lpattern(dash) lcolor(red)) ///
		note("Note: Red dashed line indicates 138% of the FPL." ///
			 "Histograms do not show `perc'% of the sample who have zero income at this point in time.") //  ///
			 * "The p-value of the modified Chow test suggests a break in the distribution around `p'% FPL.")
	graph export "$temp\Output\IncomeDistributions\Income_`i'MonthsPostpartum.png", as(png) replace
}
********************************************************************************


***** 2. Check smoothness of other covariates
*** Construct variables
// matage, already done

// chronic condition
gen ft = substr(motherheight, 1, 2) // convert height to inches
gen inc = substr(motherheight, 4, 2)
replace ft = "" if ft == "?"
destring ft inc, replace
replace inc = inc + ft * 12
drop ft
replace priorweight = "" if priorweight == "?" // convert weight to lbs
destring priorweight, replace
gen bmi = priorweight / inc^2 * 703 // calculate BMI
drop inc
gen diabetes = (rfdiabprepreg == "True")
gen ht = (rfhyperprepreg == "True")
gen chronic = ((bmi > 30 & !missing(bmi)) | diabetes == 1 | ht == 1) 
drop diabetes ht bmi

// method of delivery
gen csec = (methodcesar == "True")

// complications of delivery
gen complications = (rfeclampsia == "True" | rfhypergest == "True" | rfhellp  == "True" | rfdiabgest == "True")
replace complications = 1 if plurality > 1 & !missing(plurality)

// Mother's education -- check doc
gen mat_hs = (meduc >= 2 & !missing(meduc))
gen mat_coll = (meduc >= 4 & !missing(meduc))

// Mother's ethnicity
gen mathisp = (methnic >= 200 & !missing(methnic))

// Mother's race -- check doc
gen matblack = (mracebrg == 2 | mracebrg == 22)
gen mat_racialmin = (mracebrg != 1 & mracebrg != 21)
replace mat_racialmin = 1 if mathisp == 1

// Mother's marital status
gen mat_married = (marital == "CM")

// # of prenatal visits
replace pnv = "" if pnv == "?"
destring pnv, replace

// Preterm birth
replace estgest = "" if estgest == "?"
destring estgest, replace
gen preterm = (estgest < 37)

*** Label variables
label var matage "Average maternal age" 
label var chronic "Pr(Mother has any chronic coniditions)"
label var csec "Pr(Ceasarean delivery)"
label var complications "Pr(Complications during pregnancy)"
label var mat_hs "Pr(Mother completed HS)"
label var mat_coll "Pr(Mother completed college)"
label var mathisp "Pr(Mother is Hispanic)"
label var matblack "Pr(Mother is Black)"
label var mat_racialmin "Pr(Mother is any Racial/Ethnic Minority)"
label var mat_married "Pr(Mother is married)"
label var pnv "Average # of prenatal visits"
label var preterm "Pr(Preterm birth)"

*** Make graphs and test for breaks
local myvars matage chronic csec complications mathisp matblack mat_hs mat_coll ///
	mat_racialmin mat_married pnv preterm // update this list as needed
foreach v of local myvars {
	local mylab: variable label `v'
	di "Variable: `mylab'"
	
	preserve
	rename pct_fpl_month2 pct_fpl
	replace pct_fpl = round(pct_fpl)
	collapse (mean) `v', by(pct_fpl) fast
	
	* Regressions
	gen dum = (pct_fpl > 138)
	gen inter = dum*pct_fpl
	reg `v' pct_fpl dum inter if pct_fpl < 238 & pct_fpl > 38
	
	mat b = e(b)
	local left = round(b[1,1], 0.001)
	local right = round(b[1,1], 0.001)+ round(b[1,3], 0.001)
	mat v = e(V)
	local k = colsof(b)
	mat z = J(1, `k', 0)
	mat p = J(1, `k', 0)

	forval j = 1/`k' {
	local z = b[1,`j'] / sqrt( v[`j', `j'] )
	local p = 2* (1 - normal(abs(`z' )) )
	mat z[1,`j'] = `z'
	mat p[1,`j'] = `p'
	}
	local p = p[1,3]
	
	twoway (bar `v' pct_fpl if pct_fpl < 250), xline(138, lpattern(dash) lcolor(red)) ///
		xtitle("Income as % of FPL") ytitle(" ") subtitle("`mylab' by FPL") ///
		note("Note: Income is measured 60 days postpartum. Red dashed line indicates 138% of the FPL." ///
			 "The slope on the interval (50, 138) is `left' and `right' on the interval (138, 238)." ///
			 "The test of equality of these slopes returns a p-value of `p'.")
		* ysc(r(0(5)40)) ylab(0(5)40)
	graph export "$temp\Output\CovariateSmoothness\Smoothness_`v'.png", as(png) replace
	restore
}

*** Also, binscatters!
local myvars matage chronic csec complications mathisp matblack mat_hs mat_coll ///
	mat_racialmin mat_married pnv preterm // update this list as needed
foreach v of local myvars {
	local mylab: variable label `v'
	di "Variable: `mylab'"
	
	binscatter `v' pct_fpl_month2 if pct_fpl_month2 > 0 & pct_fpl_month2 < 200, line(qfit) rd(138) nq(100) ///
		xline(138, lpattern(dash) lcolor(red)) ///
		xtitle("Income as % of FPL") ytitle(" ") subtitle("`mylab' by FPL") ///
		note("Note: Income is measured 60 days postpartum. Red dashed line indicates 138% of the FPL.") ///
		savegraph("$temp\Output\CovariateSmoothness\Binscatter_`v'.png") replace
}
********************************************************************************
