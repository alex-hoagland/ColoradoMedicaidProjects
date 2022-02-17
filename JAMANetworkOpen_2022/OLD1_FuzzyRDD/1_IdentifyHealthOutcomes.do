/*******************************************************************************
* Title: Identfy health outcomes
* Created by: Alex Hoagland
* Created on: 4/9/2021
* Last modified on: 
* Last modified by: Alex Hoagland

* Purpose: Identifies health outcomes for births/women in our sample.
		   
* Notes: 
		
* Key edits: 
   -  
*******************************************************************************/

***** 0. Directories & Packages 
global sarah "\\ad.bu.edu\bumcfiles\BUMC Projects\ColoradoAPCD\Sarah\Sarah Datasets"
global working "\\ad.bu.edu\bumcfiles\BUMC Projects\ColoradoAPCD\Alex\Hoagland_WorkingData\Paper2"
global output "\\ad.bu.edu\bumcfiles\BUMC Projects\ColoradoAPCD\Alex\Hoagland_Output\4.HealthOutcomesPaper"

// ssc install icd9, replace // icd-9 diagnoses
// ssc install icd9p, replace // icd-9 procedures
// ssc install icd10cm, replace // US icd-10-CM (not ICD-10-WHO) diagnoses
// ssc install icd10pcs, replace  // US icd-10 (not WHO) procedures
********************************************************************************


***** 1. Load medical claims data for our sample
* First, transform sample into list of member_composite_id's and DOBs to keep
use "$working\EnrollmentRD.dta", clear
keep member_c dob 
bysort member_c (dob): gen j = _n
reshape wide dob, i(member_c) j(j)
save "$working\AllBirths.dta", replace

* Merge in all claims to filter
merge 1:m member_composite_id using ///
	"$sarah\header_line_2014on_19up_medicaid.dta", ///	
	keep(1 3) nogenerate
	
* Drop claims associated with delivery
gen new_admit = date(admit_dt , "YMD")
gen new_discharge = date(discharge_dt , "YMD")
gen new_svcstart = date(service_start_dt , "YMD")
gen new_svcend= date(service_end_dt , "YMD")
forvalues i = 1/6 { 
	drop if !missing(dob`i') & ///
	((!missing(new_dis) & inrange(dob`i',new_adm,new_dis)) | ///
	dob`i' == new_adm | ///
	(!missing(new_svcend) & inrange(dob`i',new_svcstart, new_svcend)))
}
********************************************************************************


***** 2. Outcomes 
// drop procedures happening outside of pp year for any of the births (to speed things up)
gen tokeep = 0 
forvalues i = 1/6 {
replace tokeep = 1 if !missing(dob`i') & inrange(new_svcstart,dob`i'+1,dob`i'+365)
}
keep if tokeep == 1
drop tokeep

replace place_of_service_cd = "" if strpos(place_of_service_cd , "U")
destring place_of_service_cd, gen(pos)
save "$working\HO_inprogress.dta", replace

use "$working\HO_inprogress.dta", clear
cap drop ho* 
* Identifying IP hospitalizations (progressively imposing restrictions)
// gen crit1 = (claim_type_cd == 3) // Inpatient claim type
// bysort member_id member_composite_id claim_id: ereplace crit1 = max(crit1)
gen crit2 = (!missing(new_discharge) & !missing(new_admit_dt) & new_discharge > new_admit_dt) // need to be kept >= 24 hours
bysort member_id member_composite_id claim_id: ereplace crit2 = max(crit2)
gen crit3 = (inlist(pos,21,51,56,61) | ///
		substr(revenue_cd, 1, 2) == "01" | inlist(substr(revenue_cd,1,3),"020","021")) // appropriate POS or revenue codes
bysort member_id member_composite_id claim_id: ereplace crit3 = max(crit3)
gen ho_ip = (crit2 == 1 & crit3 == 1)
label var ho_ip "Health outcome: Any inpatient stay"

* Any ED use 
gen ho_ed = (er_flag == "Y" | place_of_s == "23")
replace ho_ed = 0 if revenue_cd != "0981" & substr(revenue_cd,1,3) != "045"
bysort member_composite_id member_id claim_id : ereplace ho_ed = max(ho_ed) 
label var ho_ed "Health outcome: Any ED Use"

* Any postpartum severe maternal morbidity (see attached list of codes)
gen psmm = 0 

// DIAGNOSIS CODES
foreach v of var admit_diagnosis principal_diagnosis { 
	* Three-string codes
	replace psmm = 1 if inlist(substr(`v',1,3),"410","I21","I22", /// AMI
											   "411","I71","I79") | /// Aneurysm
						inlist(substr(`v',1,3),"N17", /// Acute renal failure
												"J80", /// Adult respiratory distress
												"I46", /// Cardiac arrest
												"D65", /// Disseminated intravascular...
												"O15") | /// Eclampsia
						inlist(substr(`v',1,3),"430","431","432","433","434","436","437") | /// cerebrovascular disorders
						inlist(substr(`v',1,3),"I60","I61","I62","I63","I64","I65","I66","I67","I68") | /// cerebrovascular disorders
						inlist(substr(`v',1,3),"038", "O85","A40","A41", /// sepsis
												"R57", /// shock
												"I26") // embolism
												
	* Four-string codes
	replace psmm = 1 if inlist(substr(`v',1,4),"5845","5486","5847","5848","5849","6693","O904") | /// Acute renal failure
						inlist(substr(`v',1,4),"5185","7991","J951","J952","J953","J960","J962","R092") | /// Adult respiratory distress
						inlist(substr(`v',1,4),"6731","O881", /// Amniotic fluid embolism
												"4275","I490") | /// Cardiac arrest
						inlist(substr(`v',1,4),"2866","2869","6663","D688","D689","O723") | /// Disseminated intravascular...
						inlist(substr(`v',1,4),"6426", /// Eclampsia
												"9971", /// heart failure
												"6715","6740","O873") | /// cerebrovascular disorders
						inlist(substr(`v',1,4),"5184","4281","4280","J810","I501","I509") | /// AHF
						inlist(substr(`v',1,4),"6680","6681","6682") | /// Anesthesia complications 
						inlist(substr(`v',1,4),"O740","O741","O742","O743","O890","O891","O892") | /// Anesthesia complications
						inlist(substr(`v',1,4),"6702","A327", /// sepsis
												"6691","7855","9950","9954","9980","O751") | /// shock
						inlist(substr(`v',1,4),"D570") | /// sickle cell
						inlist(substr(`v',1,4),"4151","6730","6732","6733","6738","O880","O882","O883","O888") // embolism
												
	* 5-string codes
	replace psmm = 1 if inlist(substr(`v',1,5),"51881","51882","51884","J9582") | /// Adult respiratory distress
						inlist(substr(`v',1,5),"42741","42742","I490", /// Cardiac arrest
												"I9712","I9713") | /// heart failure 
						inlist(substr(`v',1,5),"99702","O2251","O2252","O2253","I9781","I9782") | /// cerebrovascular disorders
						inlist(substr(`v',1,5),"42821","42823","42831","42833","42841","42843") | /// AHF
						inlist(substr(`v',1,5),"I5020","I5021","I5023","I5030","I5031","I5033","I5040","I5041","I5043") | /// AHF
						inlist(substr(`v',1,5),"99591","99592","O8604","R6520", /// sepsis
												"R6521") | /// shock
						inlist(substr(`v',1,5),"28242","28262","28264","28269","D5721","D5741","D5781") // sickle cell
						
	* All others
	replace psmm = 1 if inlist(`v', "I97710", "I97711", "T80211A", "T814XXA", "T8144XX","T782XXA") | ///
						inlist(`v',"T882XXA", "T886XXA", "T8110XA" , "T8111XA", "T8119XA")
}

// PROCEDURE CODES
replace psmm = 1 if inlist(substr(icd_primary_p,1,3),"996","990","683","684","685","686") | ///
					inlist(substr(icd_primary_p,1,3),"687","688","689","311")
replace psmm = 1 if inlist(icd_primary_p,"9390","9601","9602","9603","9605")
replace psmm = 1 if inlist(icd_primary_p,"5A2204Z","5A12012","30233H1","30233L1", "30233K1", "30233M1") | ///
	inlist(icd_primary_p,"30233N1","30233P1","30233R1","30233T1","30233H0","30233L0", "30233K0", "30233M0") | ///
	inlist(icd_primary_p,"30233N0","30233P0","30233R0","30233T0","30230H1","30230L1", "30230K1", "30230M1") | ///
	inlist(icd_primary_p,"30230N1","30230P1","30230R1","30230T1","30230H0","30230L0", "30230K0", "30230M0") | ///
	inlist(icd_primary_p,"30230N0","30230P0","30230R0","30230T0","30240H1","30240L1", "30240K1", "30240M1") | ///
	inlist(icd_primary_p,"30240N1","30240P1","30240R1","30240T1","30240H0","30240L0", "30240K0", "30240M0") | ///
	inlist(icd_primary_p,"30240N0","30240P0","30240R0","30240T0","30243H1","30243L1", "30243K1", "30243M1") |  ///
	inlist(icd_primary_p,"30243N1","30243P1","30243R1","30243T1","30243H0","30243L0", "30243K0", "30243M0") | ///
	inlist(icd_primary_p,"30243N0","30243P0","30243R0","30243T0","30250H1","30250L1", "30250K1", "30250M1") | ///
	inlist(icd_primary_p,"30250N1","30250P1","30250R1","30250T1","30250H0","30250L0", "30250K0", "30250M0") | ///
	inlist(icd_primary_p,"30250N0","30250P0","30250R0","30250T0","30253H1","30253L1", "30253K1", "30253M1") | ///
	inlist(icd_primary_p,"30253N1","30253P1","30253R1","30253T1","30253H0","30253L0", "30253K0", "30253M0") | ///
	inlist(icd_primary_p,"30253N0","30253P0","30253R0","30253T0","30260H1","30260L1", "30260K1", "30260M1") | ///
	inlist(icd_primary_p,"30260N1","30260P1","30260R1","30260T1","30260H0","30260L0", "30260K0", "30260M0") | ///
	inlist(icd_primary_p,"30260N0","30260P0","30260R0","30260T0","30263H1","30263L1", "30263K1", "30263M1") | ///
	inlist(icd_primary_p,"30263N1","30263P1","30263R1","30263T1","30263H0","30263L0", "30263K0", "30263M0") | ///
	inlist(icd_primary_p,"30263N0","30263P0","30263R0","30263T0","0UT90ZZ", "0UT94ZZ", "0UT97ZZ", "0UT98ZZ") | ///
	inlist(icd_primary_p,"0UT9FZZ","0B110Z", "0B110F", "0B113", "0B114","5A1935Z", "5A1945Z","5A1955Z")
	
// Require PSMM codes to be inpatient/ED POS
gen ho_psmm = (psmm == 1 & (ho_ip == 1 | ho_ed == 1))
bysort member_c member_id claim_id: ereplace ho_psmm = max(ho_psmm)
label var ho_psmm "Health Outcome: PSMM"
********************************************************************************


***** 3. Reshape, keep only those w/in 12 months of birth
keep if inlist(1, ho_ip,ho_ed,ho_psmm)
collapse (max) ho_* (min) new_admit_dt new_svcstart, by(member_composite_id dob* claim_id) fast
reshape long dob, i(member_composite_id claim_id new*) j(birth_no)
drop if missing(dob)

gen ub = dob + 365
format ub %td
keep if inrange(new_admit_dt,dob,ub) | inrange(new_svcstart,dob,ub)

compress
save "$working\AllHealthOutcomes", replace

*** Collapse to enrollee level
collapse (max) ho*, by(member_c dob) fast 
merge 1:1 member_c dob using "$working\EnrollmentRD.dta", keep(2 3) nogenerate
foreach v of var ho* { 
	replace `v' = 0 if missing(`v')
}
save "$working\FuzzyRDD", replace

use "$working\AllHealthOutcomes", clear // add rates
collapse (sum) ho*, by(member_c dob) fast
foreach v of varlist ho* { 
	rename `v' rate_`v'
}
merge 1:1 member_c dob using "$working\FuzzyRDD.dta", keep(2 3) nogenerate
foreach v of var ho* { 
	replace `v' = 0 if missing(`v')
}
compress
save "$working\FuzzyRDD", replace
********************************************************************************


***** 4. Check incidence over course of postpartum year
cls
forvalues i = 1/4 {
	use "$working\AllHealthOutcomes", clear
	keep if inrange(new_admit_dt,dob+90*(`i'-1),dob+90*`i') | inrange(new_svcstart,dob+90*(`i'-1),dob+90*`i')
	collapse (max) ho*, by(member_c dob) fast
	merge 1:1 member_c dob using "$working\EnrollmentRD.dta", keep(2 3) nogenerate
	fre ho*
}
********************************************************************************


***** 5. Compute frequencies over postpartum year
use "$working\AllHealthOutcomes", clear
gen date = min(new_admit_dt, new_svcstart)
format date %td
gen days_since_birth = date - dob + 1
drop if days_since_birth <= 0

* Histograms
hist days_, graphregion(color(white)) xtitle("Days Since Birth") subtitle("All Events")
graph export "$output\OutcomeFreqs\AllEvents.png", as(png) replace

label var ho_ip1 "Health Outcome: Any Inpatient (Measure 1)"
label var ho_ip2 "Health Outcome: Any Inpatient (Measure 2)"
label var ho_ed "Health Outcome: Any ED Visit"
label var ho_psmm "Health Outcome: PSMM"
foreach v of var ho* { 
	local mylab: var label `v' 
	hist days_, graphregion(color(white)) xtitle("Days Since Birth") subtitle("`mylab'")
graph export "$output\OutcomeFreqs\`v'.png", as(png) replace
}

* Table of frequencies by month 
gen months = floor(days_since_birth/30)
forvalues i = 0/12 { 
	di "MONTH `i'"
	foreach v of var ho* { 
		fre `v' if months == `i'
	}
}
********************************************************************************