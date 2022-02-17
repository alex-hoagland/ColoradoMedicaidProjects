/*******************************************************************************
* Title: Merge in birth record to main sample, 
	check smoothness of birth record covariates by income
* Created by: Alex Hoagland
* Created on: 11/18/2020
* Last modified on: 2/11/2021
* Last modified by: Alex Hoagland

* Purpose: 
		   
* Notes: 
		
* Key edits: 
   -  
*******************************************************************************/


***** 0. Packages and directories, load data
* ssc install binscatter

global head "\\ad.bu.edu\bumcfiles\BUMC Projects\ColoradoAPCD"
global sarah "$head\Sarah\Sarah Datasets"
global working "$head\Alex\Hoagland_WorkingData"
global output "$head\Alex\Hoagland_Output\1.CovariateSmoothness"

use "$working\APCD_MedicaidDelivery_Sample_WithIncome_20210304.dta", clear
********************************************************************************


***** 1. Merge in birth records data, assess merge
keep member_composite_id dob income_re
bysort member_composite_id (dob): gen j = _n
reshape wide dob income_re, i(member_composite_id) j(j) 
	// need to be at the member_composite_id level
merge 1:m member_composite_id using "$head\Birth Records\raw\CO_mom_birth_record_2012_2019.dta", keep(1 3)
rename dob dob_br
reshape long dob income_re, i(member_composite_id dob_br vsid) j(birth_no)
drop if missing(dob)
gen test = date(dob_br, "MDY")
drop dob_br
rename test dob_br
gen datewindow = dob-dob_br // how far apart are births (in days?)
drop if abs(datewindow) > 30 // doesn't drop many

*** Create important covariates
rename matage mc_matage // matage, already done
replace mc_matage = "" if mc_matage == "?"
destring mc_matage, replace

// chronic condition
gen mc_ft = substr(motherheight, 1, 2) // convert height to inches
gen mc_inc = substr(motherheight, 4, 2)
replace mc_ft = "" if mc_ft == "?"
destring mc_ft mc_inc, replace
replace mc_inc = mc_inc + mc_ft * 12
drop mc_ft
replace priorweight = "" if priorweight == "?" // convert weight to lbs
destring priorweight, replace
gen mc_bmi = priorweight / mc_inc^2 * 703 // calculate BMI
drop mc_inc
gen mc_diabetes = (rfdiabprepreg == "True")
gen mc_ht = (rfhyperprepreg == "True")
gen mc_chronic = ((mc_bmi > 30 & !missing(mc_bmi)) | mc_diabetes == 1 | mc_ht == 1) 
drop mc_diabetes mc_ht mc_bmi

// method of delivery
gen mc_csec = (methodcesar == "True")

// complications of delivery
gen mc_complications = (rfeclampsia == "True" | rfhypergest == "True" | rfhellp  == "True" | ///
		rfdiabgest == "True" | mmtransfusion == "True" | mmlac3rd4th == "True" | mmuterusrupture == "True" | ///
		mmhysterunplan == "True" | mmintcare == "True")
replace mc_complications = 1 if plurality > 1 & !missing(plurality)

// Mother's education -- check doc
gen mc_mat_hs = (meduc >= 2 & !missing(meduc))
gen mc_mat_coll = (meduc >= 4 & !missing(meduc))

// Mother's ethnicity
gen mc_mathisp = (methnic >= 200 & !missing(methnic))

// Mother's race -- check doc
gen mc_white = (mracebrg == 1)
gen mc_matblack = (mracebrg == 2 | mracebrg == 22)
gen mc_matasian = inrange(mracebrg,4,10) | mracebrg == 24
gen mc_mat_racialmin = (mracebrg != 1 & mracebrg != 21)
replace mc_mat_racialmin = 1 if mc_mathisp == 1
gen mc_mat_otherrace = (mc_white == 0 & mc_matblack == 0 & mc_matasian == 0)

// Mother's marital status
gen mc_mat_married = (marital == "CM")

// # of prenatal visits and care initiation 
replace pnv = "" if pnv == "?" // note: missing values are unknown, not 0
destring pnv, replace
rename pnv mc_pnv

// Month care began -- this variable is a little messy
replace monthcarebegan = "1" if monthcarebegan == "FI"
replace monthcarebegan = "2" if monthcarebegan == "2n"
replace monthcarebegan = "" if inlist(monthcarebegan,"SE","UN","ni","?")
destring monthcarebegan, replace
gen mc_firstcare_firsttrim = (monthcarebegan <= 3)

// Preterm birth
replace estgest = "" if estgest == "?"
destring estgest, replace
gen mc_preterm = (estgest < 37)

// Mother born outside of us 
gen mc_bornoutsideus = (matbirthplace > 99999000056 & !missing(matbirthplace))

*** Label variables
label var mc_matage "Average maternal age" 
label var mc_chronic "Pr(Mother has any chronic coniditions)"
label var mc_csec "Pr(Ceasarean delivery)"
label var mc_complications "Pr(Complications during pregnancy)"
label var mc_mat_hs "Pr(Mother completed HS)"
label var mc_mat_coll "Pr(Mother completed college)"
label var mc_mathisp "Pr(Mother is Hispanic)"
label var mc_white "Pr(Mother is White)"
label var mc_matblack "Pr(Mother is Black)"
label var mc_matasian "Pr(Mother is Asian)"
label var mc_mat_racialmin "Pr(Mother is any Racial/Ethnic Minority)"
label var mc_mat_otherrace "Pr(Mother is any Other Race)"
label var mc_mat_married "Pr(Mother is married)"
label var mc_pnv "Average # of prenatal visits"
label var mc_firstcare_firsttrim "Pr(PN Care Began in First Trimester)"
label var mc_preterm "Pr(Preterm birth)"
label var mc_bornoutsideus "Pr(Mother was Born Outside the US)"

*** Merge back in to original sample file
keep member_composite_id dob* mc_*
duplicates drop // there are duplicates here, only differ on the vsid var
drop dob_br 

// note: there are some births with multiple, differing records. Need to decide what to do with them? For now, dropping them. 
bysort member_composite_id dob: egen flag = max(_n)
bysort member_composite_id dob: drop if flag > 1
merge 1:1 member_composite_id dob using "$working\APCD_MedicaidDelivery_Sample_WithIncome_20210304.dta", nogenerate
********************************************************************************


***** 2. Check smoothness of birth record covariates
foreach v of varlist mc_* {
	local mylab: variable label `v'
	di "Variable: `mylab'"
	
	binscatter `v' income_re if inrange(income_re, 0.01, 300), line(qfit) rd(133) nq(100) ///
		xline(133, lpattern(dash) lcolor(red)) ///
		xtitle("Income as % of FPL") ytitle(" ") subtitle("`mylab' by FPL") ///
		note("Red dashed line indicates 133% of the FPL.") ///
		savegraph("$output\Binscatter_`v'.png") replace
}

compress
save "$working\APCD_MedicaidDelivery_Sample_WithIncome_20210304.dta", replace
********************************************************************************
