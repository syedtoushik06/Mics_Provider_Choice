* ==============================================================================
* BANGLADESH MICS6: ANTIBIOTIC SOURCE CHANNEL ANALYSIS - URBAN ONLY
* ==============================================================================

clear all
set more off
set linesize 120
version 16.0


* ==============================================================================
* SECTION 0: FILE PATHS
* ==============================================================================

local raw_data_path  "C:/Users/HP/Desktop/MICS/Bangladesh MICS6 SPSS Datasets/"
local output_path    "C:/Users/HP/Desktop/MICS/Output/Urban/"

cap mkdir "`output_path'"


* ==============================================================================
* SECTION 1: LOAD AND MERGE 
* ==============================================================================

* --- 1a. Household dataset ---
import spss using "`raw_data_path'hh.sav", clear
rename *, lower
tempfile hh_temp
save "`hh_temp'"

* --- 1b. Household Listing (HL) dataset ---
import spss using "`raw_data_path'hl.sav", clear
rename *, lower
tempfile hl_temp
save "`hl_temp'"

* --- 1c. Women (mothers) dataset ---
import spss using "`raw_data_path'wm.sav", clear
rename *, lower
rename ln uf4
tempfile women_temp
save "`women_temp'"

* --- 1d. Child dataset (base) ---
import spss using "`raw_data_path'ch.sav", clear
rename *, lower

* --- 1e. Merge women data ---
merge m:1 hh1 hh2 uf4 using "`women_temp'", keep(master match) nogen

* --- 1f. Merge household data ---
merge m:1 hh1 hh2 using "`hh_temp'", keep(master match) nogen


* ==============================================================================
* SECTION 2: FILTER FOR URBAN ONLY
* ==============================================================================

* Keep only urban households (hh6 == 1)
keep if hh6 == 1
di "Urban households retained: N = " _N


* ==============================================================================
* SECTION 3: DEFINE SICK-CHILD SAMPLE
* ==============================================================================

gen byte child_had_ari = (ca17 == 1 | inlist(ca18, 1, 3)) if !missing(ca17, ca18)
replace  child_had_ari = 0 if missing(child_had_ari)
label variable child_had_ari "Child had acute respiratory infection (ARI)"
label define lbl_yesno 0 "No" 1 "Yes"
label values child_had_ari lbl_yesno

gen byte child_was_sick = 0
replace child_was_sick = 1 if ca1 == 1
replace child_was_sick = 1 if ca14 == 1
replace child_was_sick = 1 if ca16 == 1
replace child_was_sick = 1 if child_had_ari == 1
replace child_was_sick = . if missing(ca1) & missing(ca14) & missing(ca16) & missing(child_had_ari)

label variable child_was_sick "Child was sick in the last 2 weeks"
label values child_was_sick lbl_yesno

keep if child_was_sick == 1
di "Sick children retained (Urban): N = " _N


* ==============================================================================
* SECTION 4: CARE-SEEKING
* ==============================================================================

gen byte care_was_sought = 0
replace care_was_sought = 1 if (ca5 == 1 & ca1 == 1)
replace care_was_sought = 1 if (ca20 == 1 & (ca14 == 1 | ca16 == 1 | child_had_ari == 1))
label variable care_was_sought "Care was sought for illness"
label values care_was_sought lbl_yesno


* ==============================================================================
* SECTION 5: ANTIBIOTIC USE
* ==============================================================================

gen byte ab_given_diarrhea = .
replace ab_given_diarrhea = 0 if ca1 == 1 & missing(ca13a) & missing(ca13l)
replace ab_given_diarrhea = 1 if ca1 == 1 & ///
    (ca13a == "A" | ca13a == "a" | ca13l == "L" | ca13l == "l")
label variable ab_given_diarrhea "Antibiotic given for diarrhea"
label values ab_given_diarrhea lbl_yesno

gen byte ab_given_fever_ari = .
replace ab_given_fever_ari = 0 if (ca14 == 1 | ca16 == 1 | child_had_ari == 1) & ///
    missing(ca23l) & missing(ca23m) & missing(ca23n) & missing(ca23o)
replace ab_given_fever_ari = 1 if (ca14 == 1 | ca16 == 1 | child_had_ari == 1) & ///
    (ca23l == "L" | ca23l == "l" | ca23m == "M" | ca23m == "m" | ///
     ca23n == "N" | ca23n == "n" | ca23o == "O" | ca23o == "o")
label variable ab_given_fever_ari "Antibiotic given for fever, cough, or ARI"
label values ab_given_fever_ari lbl_yesno

gen byte child_received_ab = 0
replace child_received_ab = 1 if ab_given_diarrhea == 1 | ab_given_fever_ari == 1
label variable child_received_ab "Child received any antibiotic"
label values child_received_ab lbl_yesno

replace care_was_sought = 1 if child_received_ab == 1


* ==============================================================================
* SECTION 6: CLASSIFY ANTIBIOTIC SOURCE CHANNEL
* ==============================================================================

gen byte channel_code = .
label variable channel_code "Antibiotic source channel"
label define lbl_channel 1 "Formal source" 2 "Informal source"
label values channel_code lbl_channel

* Fever / ARI: formal sources
foreach v in ca25a ca25b ca25c ca25d ca25e ca25h ca25i ca25j ca25l ca25m ca25n ca25o ca25w {
    replace channel_code = 1 if ab_given_fever_ari == 1 & missing(channel_code) & ///
        !missing(`v') & `v' != ""
}

* Fever / ARI: informal sources
foreach v in ca25k ca25p ca25q ca25r ca25w {
    replace channel_code = 2 if ab_given_fever_ari == 1 & missing(channel_code) & ///
        !missing(`v') & `v' != ""
}

* Diarrhea: formal sources
foreach v in ca6a ca6b ca6c ca6d ca6e ca6h ca6i ca6j ca6l ca6m ca6n ca6o ca6w {
    replace channel_code = 1 if ab_given_diarrhea == 1 & missing(channel_code) & ///
        !missing(`v') & `v' != ""
}

* Diarrhea: informal sources
foreach v in ca6k ca6p ca6q ca6r ca6w ca6x {
    replace channel_code = 2 if ab_given_diarrhea == 1 & missing(channel_code) & ///
        !missing(`v') & `v' != ""
}

replace channel_code = 2 if child_received_ab == 1 & missing(channel_code)


* ==============================================================================
* SECTION 7: OUTCOME VARIABLES
* ==============================================================================

gen byte informal_source = 0 if child_received_ab == 1
replace informal_source = 1 if child_received_ab == 1 & channel_code == 2
label variable informal_source "Antibiotic obtained from an informal source"
label define lbl_ab_source_bin 0 "Formal source" 1 "Informal source"
label values informal_source lbl_ab_source_bin

gen byte ab_source_3cat = 0 if care_was_sought == 1
replace ab_source_3cat = 1 if care_was_sought == 1 & child_received_ab == 1 & channel_code == 1
replace ab_source_3cat = 2 if care_was_sought == 1 & child_received_ab == 1 & channel_code == 2
label variable ab_source_3cat "Antibiotic source: none / formal / informal"
label define lbl_ab_source3 0 "No antibiotic used" 1 "Antibiotic – formal source" 2 "Antibiotic – informal source"
label values ab_source_3cat lbl_ab_source3


* ==============================================================================
* SECTION 8: INDEPENDENT (PREDICTOR) VARIABLES
* ==============================================================================

* ------------------------------------------------------------------------------
* 8a. CHILD FACTORS
* ------------------------------------------------------------------------------

gen byte child_is_male = (hl4 == 1) if !missing(hl4)
label variable child_is_male "Child is male"
label define lbl_child_sex 0 "Female" 1 "Male"
label values child_is_male lbl_child_sex

gen byte child_age_group = .
replace child_age_group = 1 if cage >= 0 & cage <= 5
replace child_age_group = 2 if cage >= 6 & cage <= 11
replace child_age_group = 3 if cage >= 12 & cage <= 23
replace child_age_group = 4 if cage >= 24 & cage <= 35
replace child_age_group = 5 if cage >= 36 & cage <= 47
replace child_age_group = 6 if cage >= 48 & cage <= 59
label variable child_age_group "Child age group (months)"
label define lbl_age_group 1 "0–5 months" 2 "6–11 months" 3 "12–23 months" ///
                           4 "24–35 months" 5 "36–47 months" 6 "48–59 months"
label values child_age_group lbl_age_group

gen child_age_months = cage
label variable child_age_months "Child age in months"

gen byte child_stunted = (haz2 < -2) if !missing(haz2)
gen byte child_wasted = (whz2 < -2) if !missing(whz2)
gen byte child_underweight = (waz2 < -2) if !missing(waz2)

gen byte child_malnourished = 0
replace child_malnourished = 1 if child_stunted == 1 | child_wasted == 1 | child_underweight == 1
replace child_malnourished = . if missing(haz2) & missing(whz2) & missing(waz2)
label variable child_malnourished "Child is malnourished"
label values child_malnourished lbl_yesno

gen byte child_had_diarrhea = (ca1 == 1) if !missing(ca1)
gen byte child_had_fever = (ca14 == 1) if !missing(ca14)
gen byte child_had_cough = (ca16 == 1) if !missing(ca16)
label values child_had_diarrhea lbl_yesno
label values child_had_fever lbl_yesno
label values child_had_cough lbl_yesno

gen byte child_had_multiple_illnesses = 0
replace child_had_multiple_illnesses = 1 if ///
    (child_had_diarrhea == 1 & child_had_fever == 1) | ///
    (child_had_diarrhea == 1 & child_had_cough == 1) | ///
    (child_had_fever == 1 & child_had_cough == 1)
replace child_had_multiple_illnesses = . if missing(child_had_diarrhea) & missing(child_had_fever) & missing(child_had_cough)
label variable child_had_multiple_illnesses "Child had two or more illnesses"
label values child_had_multiple_illnesses lbl_yesno

* ------------------------------------------------------------------------------
* 8b. CAREGIVER/MOTHER FACTORS
* ------------------------------------------------------------------------------

* Mother's age at child's birth
capture confirm variable magebrt
if !_rc {
    gen double mother_age_at_birth = magebrt if !missing(magebrt)
}
else {
    gen double mother_age_at_birth = (cdob - wdob) / 12 if !missing(cdob, wdob)
    replace mother_age_at_birth = . if mother_age_at_birth < 12 | mother_age_at_birth > 55
}

gen byte mother_age_group = .
replace mother_age_group = 1 if mother_age_at_birth < 20
replace mother_age_group = 2 if mother_age_at_birth >= 20 & mother_age_at_birth < 30
replace mother_age_group = 3 if mother_age_at_birth >= 30 & mother_age_at_birth < 40
replace mother_age_group = 4 if mother_age_at_birth >= 40
label define lbl_mother_age 1 "<20 years" 2 "20-29 years" 3 "30-39 years" 4 "40+ years"
label values mother_age_group lbl_mother_age

gen byte mother_was_teenager = (mother_age_at_birth < 20) if !missing(mother_age_at_birth)
label variable mother_was_teenager "Mother was a teenager at child's birth"
label values mother_was_teenager lbl_yesno

gen byte mother_edu_level = melevel if !missing(melevel)
label variable mother_edu_level "Mother's education level"
label define lbl_mother_edu 0 "No education" 1 "Primary" 2 "Secondary" 3 "Higher"
label values mother_edu_level lbl_mother_edu

gen byte mother_can_read = 0 if wb14 == 1 | wb14 == 2
replace mother_can_read = 1 if wb14 == 3
label variable mother_can_read "Mother can read"
label values mother_can_read lbl_yesno

gen byte had_4plus_anc_visits = (mn5 >= 4) if !missing(mn5)
label variable had_4plus_anc_visits "Mother had 4+ ANC visits"
label values had_4plus_anc_visits lbl_yesno

gen byte delivered_at_facility = inrange(mn20, 21, 36) if !missing(mn20)
label variable delivered_at_facility "Born at health facility"
label values delivered_at_facility lbl_yesno

* ------------------------------------------------------------------------------
* 8c. FATHER/HUSBAND FACTORS (from WM data)
* ------------------------------------------------------------------------------

* Husband's age (from women's dataset)
gen husband_age = ma2 if ma2 < 95
label variable husband_age "Husband's age"

* Polygamous household
gen polygamous = (ma3 == 1) if !missing(ma3)
label variable polygamous "Polygamous household"
label values polygamous lbl_yesno

* Husband's education (if available in WM)
capture confirm variable ma9
if !_rc {
    gen byte husband_edu_level = ma9 if !missing(ma9)
    label variable husband_edu_level "Husband's education level"
    label define lbl_father_edu 0 "No education" 1 "Primary" 2 "Secondary" 3 "Higher"
    label values husband_edu_level lbl_father_edu
}
else {
    di "Note: Husband's education not available in WM data"
    gen byte husband_edu_level = .
}

* ------------------------------------------------------------------------------
* 8d. HOUSEHOLD CHARACTERISTICS
* ------------------------------------------------------------------------------

gen byte hh_wealth_quintile = windex5 if !missing(windex5)
label variable hh_wealth_quintile "Household wealth quintile"
label define lbl_wealth 1 "Poorest (Q1)" 2 "Poor (Q2)" 3 "Middle (Q3)" ///
                        4 "Upper-middle (Q4)" 5 "Richest (Q5)"
label values hh_wealth_quintile lbl_wealth

gen byte hh_is_urban = (hh6 == 1) if !missing(hh6)
label variable hh_is_urban "Urban residence"
label values hh_is_urban lbl_yesno

gen byte hhhead_edu_level = helevel if !missing(helevel)
label variable hhhead_edu_level "Household head education"
label define lbl_hhhead_edu 0 "No education" 1 "Primary" 2 "Secondary" 3 "Higher"
label values hhhead_edu_level lbl_hhhead_edu

gen byte family_size = hh48 if !missing(hh48) & hh48 < 30
gen byte family_size_cat = .
replace family_size_cat = 1 if family_size >= 1 & family_size <= 3
replace family_size_cat = 2 if family_size >= 4 & family_size <= 6
replace family_size_cat = 3 if family_size >= 7
label define lbl_familysize 1 "Small (1-3 members)" 2 "Medium (4-6 members)" 3 "Large (7+ members)"
label values family_size_cat lbl_familysize

gen double crowding_ratio = hh48 / hc3 if !missing(hh48, hc3) & hc3 > 0 & hc3 < 20
gen byte crowding_category = .
replace crowding_category = 1 if crowding_ratio < 3
replace crowding_category = 2 if crowding_ratio >= 3 & crowding_ratio < 5
replace crowding_category = 3 if crowding_ratio >= 5
label define lbl_crowding 1 "Low (<3 persons/room)" 2 "Medium (3-4 persons/room)" 3 "High (5+ persons/room)"
label values crowding_category lbl_crowding

* ------------------------------------------------------------------------------
* 8e. ENVIRONMENTAL FACTORS
* ------------------------------------------------------------------------------

gen byte uses_clean_fuel = inlist(eu1, 1, 2, 4) if !missing(eu1)
label variable uses_clean_fuel "Uses clean cooking fuel"
label values uses_clean_fuel lbl_yesno

gen byte has_safe_water = inlist(ws1, 11, 12, 13, 14, 21, 31, 41, 51, 91) if !missing(ws1)
label variable has_safe_water "Has improved water source"
label values has_safe_water lbl_yesno

gen byte has_safe_toilet = inlist(ws11, 11, 12, 13, 21, 22) if !missing(ws11)
label variable has_safe_toilet "Has improved sanitation"
label values has_safe_toilet lbl_yesno

gen byte has_electricity = (hc8 == 1 | hc8 == 2) if !missing(hc8)
label variable has_electricity "Has electricity"
label values has_electricity lbl_yesno

* ------------------------------------------------------------------------------
* 8f. INFORMATION/MEDIA ACCESS
* ------------------------------------------------------------------------------

gen byte has_media_access = 0
replace has_media_access = 1 if (mt3 >= 2 & !missing(mt3)) | (mt2 >= 2 & !missing(mt2)) | (mt1 >= 2 & !missing(mt1))
label variable has_media_access "Has media access (weekly)"
label values has_media_access lbl_yesno

gen byte owns_mobile_phone = (mt11 == 1) if !missing(mt11)
label variable owns_mobile_phone "Owns mobile phone"
label values owns_mobile_phone lbl_yesno

* ------------------------------------------------------------------------------
* 8g. TREATMENT FACTORS
* ------------------------------------------------------------------------------

gen byte received_ors_zinc = 0
replace received_ors_zinc = 1 if (ca7a == 1 | ca7b == 1) & ca7c == 1 & ca1 == 1
replace received_ors_zinc = . if ca1 != 1
label variable received_ors_zinc "Received ORS and zinc"
label values received_ors_zinc lbl_yesno


* ==============================================================================
* SECTION 9: SURVEY DESIGN SETUP
* ==============================================================================

* Create stratum if missing
capture confirm variable stratum
if _rc {
    egen stratum = group(hh7 hh6)
}

* Set survey design
svyset psu [pw = chweight], strata(stratum) singleunit(centered) vce(linearized)

di "Survey design summary (Urban):"
svydes


* ==============================================================================
* SECTION 10: SAVE ANALYSIS DATASET - URBAN
* ==============================================================================

* Keep ALL variables that exist
keep hh1 hh2 chweight psu stratum ///
     child_was_sick care_was_sought ///
     child_received_ab channel_code ab_source_3cat informal_source ///
     ab_given_diarrhea ab_given_fever_ari ///
     child_is_male child_age_group child_age_months ///
     child_stunted child_wasted child_underweight child_malnourished ///
     child_had_diarrhea child_had_fever child_had_cough child_had_ari child_had_multiple_illnesses ///
     mother_age_at_birth mother_age_group mother_was_teenager ///
     mother_edu_level mother_can_read ///
     had_4plus_anc_visits delivered_at_facility ///
     husband_age polygamous husband_edu_level ///
     hh_wealth_quintile hh_is_urban ///
     hhhead_edu_level family_size family_size_cat crowding_ratio crowding_category ///
     uses_clean_fuel has_safe_water has_safe_toilet has_electricity ///
     has_media_access owns_mobile_phone ///
     received_ors_zinc

* Save the dataset
save "`output_path'MICS6_Antibiotic_Analysis_Urban.dta", replace
export delimited using "`output_path'MICS6_Antibiotic_Analysis_Urban.csv", replace

di "Urban analysis dataset saved with " _N " observations"


* ==============================================================================
* SECTION 11: DESCRIPTIVE ANALYSIS - URBAN
* ==============================================================================

di _n "============================================================"
di "DESCRIPTIVE RESULTS - URBAN"
di "============================================================"

di _n "Total sick children (Urban): " _N

qui count if care_was_sought == 1
di "Care sought: " r(N) " (" %3.1f (r(N)/_N)*100 "%)"

qui count if child_received_ab == 1
di "Antibiotics received: " r(N) " (" %3.1f (r(N)/_N)*100 "%)"

di _n "Among antibiotic users (Urban):"
tab informal_source if child_received_ab == 1

di _n "Predictor distributions (antibiotic users - Urban):"
foreach var in child_is_male child_age_group mother_edu_level hh_wealth_quintile {
    di _n "Tabulation of `var':"
    tab `var' if child_received_ab == 1, missing


* ==============================================================================
* SECTION 12: BINARY LOGISTIC REGRESSION - URBAN
* Outcome: informal_source (1=Informal, 0=Formal)
* ==============================================================================

di _n "============================================================"
di "BINARY LOGISTIC REGRESSION - URBAN"
di "Outcome: Informal vs Formal antibiotic source"
di "============================================================"

preserve

* Keep only antibiotic users
keep if child_received_ab == 1
local n_ab_users = _N
di "Antibiotic users (Urban analytic sample): " `n_ab_users'
di ""

if `n_ab_users' >= 30 {
    
    * ==========================================================================
    * MODEL 1: UNADJUSTED (CRUDE) ODDS RATIOS - URBAN
    * ==========================================================================
    di _n "================================================================================"
    di "MODEL 1: UNADJUSTED (CRUDE) ODDS RATIOS - URBAN"
    di "================================================================================"
    
    * Wealth Quintile
    di _n "Wealth Quintile (Ref: Poorest):"
    svy: logit informal_source i.hh_wealth_quintile, or
    
    * Mother's Education
    di _n "Mother's Education (Ref: No education):"
    svy: logit informal_source i.mother_edu_level, or
    
    * Child Age Group
    di _n "Child Age Group (Ref: 0-5 months):"
    svy: logit informal_source i.child_age_group, or
    
    * Child Sex
    di _n "Child Sex (Ref: Female):"
    svy: logit informal_source i.child_is_male, or
    
    * Child had Diarrhea
    di _n "Child had Diarrhea (Ref: No):"
    svy: logit informal_source i.child_had_diarrhea, or
    
    * Child had Fever
    di _n "Child had Fever (Ref: No):"
    svy: logit informal_source i.child_had_fever, or
    
    * Child had Cough
    di _n "Child had Cough (Ref: No):"
    svy: logit informal_source i.child_had_cough, or
    
    * Child had ARI
    di _n "Child had ARI (Ref: No):"
    svy: logit informal_source i.child_had_ari, or
    
    * Child Malnourished
    di _n "Child Malnourished (Ref: No):"
    svy: logit informal_source i.child_malnourished, or
    
    * Mother was Teenager
    di _n "Mother was Teenager (Ref: No):"
    svy: logit informal_source i.mother_was_teenager, or
    
    * Mother Can Read
    di _n "Mother Can Read (Ref: No):"
    svy: logit informal_source i.mother_can_read, or
    
    * Facility Delivery
    di _n "Facility Delivery (Ref: Home):"
    svy: logit informal_source i.delivered_at_facility, or
    
    * ANC (4+ Visits)
    di _n "ANC (4+ Visits) (Ref: <4 visits):"
    svy: logit informal_source i.had_4plus_anc_visits, or
    
    * Household Head Education
    di _n "Household Head Education (Ref: No education):"
    svy: logit informal_source i.hhhead_edu_level, or
    
    * Family Size
    di _n "Family Size (Ref: Small 1-3):"
    svy: logit informal_source i.family_size_cat, or
    
    * Crowding
    di _n "Crowding (Ref: Low <3/room):"
    svy: logit informal_source i.crowding_category, or
    
    * Clean Cooking Fuel
    di _n "Clean Cooking Fuel (Ref: No):"
    svy: logit informal_source i.uses_clean_fuel, or
    
    * Safe Water
    di _n "Access to Clean Water (Ref: Unimproved):"
    svy: logit informal_source i.has_safe_water, or
    
    * Safe Toilet
    di _n "Access to Clean Toilet (Ref: Unimproved):"
    svy: logit informal_source i.has_safe_toilet, or
    
    * Electricity
    di _n "Electricity (Ref: No):"
    svy: logit informal_source i.has_electricity, or
    
    * Media Access
    di _n "Media Access (Weekly) (Ref: No):"
    svy: logit informal_source i.has_media_access, or
    
    * Mobile Phone Ownership
    di _n "Mobile Phone Ownership (Ref: No):"
    svy: logit informal_source i.owns_mobile_phone, or
    
    * Received ORS and Zinc (Diarrhea cases only)
    di _n "Received ORS and Zinc (Diarrhea Cases Only, Ref: No):"
    svy: logit informal_source i.received_ors_zinc if child_had_diarrhea == 1, or
    
    
    * ==========================================================================
    * MODEL 2: ADJUSTED (MULTIVARIABLE) ODDS RATIOS - URBAN
    * ==========================================================================
    di _n ""
    di _n "================================================================================"
    di "MODEL 2: ADJUSTED (MULTIVARIABLE) ODDS RATIOS - URBAN"
    di "================================================================================"

    * Model 2a: Demographic variables only
    di _n "Model 2a: Adjusted for Wealth, Mother's Education, Child Age, Sex"
    svy: logit informal_source i.hh_wealth_quintile i.mother_edu_level i.child_age_group i.child_is_male
    svy: logit, or

    * Model 2b: Add clinical variables (Diarrhea, Fever)
    di _n "Model 2b: + Diarrhea and Fever"
    svy: logit informal_source i.hh_wealth_quintile i.mother_edu_level i.child_age_group i.child_is_male i.child_had_diarrhea i.child_had_fever
    svy: logit, or

    * Model 2c: Add environmental factors (Electricity)
    di _n "Model 2c: + Electricity"
    svy: logit informal_source i.hh_wealth_quintile i.mother_edu_level i.child_age_group i.child_is_male i.child_had_diarrhea i.child_had_fever i.has_electricity
    svy: logit, or

    * Model 2d: Add media access
    di _n "Model 2d: + Media Access (FINAL ADJUSTED MODEL - URBAN)"
    svy: logit informal_source i.hh_wealth_quintile i.mother_edu_level i.child_age_group i.child_is_male i.child_had_diarrhea i.child_had_fever i.has_electricity i.has_media_access
    svy: logit, or
    
    * Model 2e: FULL MODEL
    di _n "Model 2e: FULL MODEL - URBAN"
    svy: logit informal_source i.hh_wealth_quintile i.mother_edu_level i.child_age_group i.child_is_male i.child_had_diarrhea i.child_had_fever i.child_had_cough i.child_had_ari i.child_malnourished i.mother_was_teenager i.mother_can_read i.delivered_at_facility i.had_4plus_anc_visits i.hhhead_edu_level i.family_size_cat i.crowding_category i.uses_clean_fuel i.has_safe_water i.has_safe_toilet i.has_electricity i.has_media_access i.owns_mobile_phone
    svy: logit, or
}


restore

* ==============================================================================
* SECTION 13: MULTINOMIAL LOGISTIC REGRESSION - URBAN
* Outcome: ab_source_3cat (0=No antibiotic, 1=Formal, 2=Informal)
* ==============================================================================

di _n ""
di _n "============================================================"
di "MULTINOMIAL LOGISTIC REGRESSION - URBAN"
di "Outcome: No antibiotic / Formal antibiotic / Informal antibiotic"
di "============================================================"

* Keep only treatment seekers
keep if care_was_sought == 1
local n_treatment = _N
di "Treatment seekers (Urban): " `n_treatment'

if `n_treatment' >= 50 {
    
    * Multinomial Model 1: Basic model
    di _n "Multinomial Model 1: Basic model (Ref: No antibiotic) - URBAN"
    svy: mlogit ab_source_3cat i.hh_wealth_quintile i.mother_edu_level i.child_age_group i.child_is_male, baseoutcome(0) rrr
    
    * Multinomial Model 2: Add clinical variables
    di _n "Multinomial Model 2: + Diarrhea and Fever (Ref: No antibiotic) - URBAN"
    svy: mlogit ab_source_3cat i.hh_wealth_quintile i.mother_edu_level i.child_age_group i.child_is_male i.child_had_diarrhea i.child_had_fever, baseoutcome(0) rrr
    
    * Multinomial Model 3: Full model
    di _n "Multinomial Model 3: Full model (Ref: No antibiotic) - URBAN"
    svy: mlogit ab_source_3cat i.hh_wealth_quintile i.mother_edu_level i.child_age_group i.child_is_male i.child_had_diarrhea i.child_had_fever i.has_electricity i.has_media_access, baseoutcome(0) rrr
}

restore

di _n ""
di "============================================================"
di "URBAN ANALYSIS COMPLETE"
di "============================================================"

* ==============================================================================
* SECTION 14: COMPLETION SUMMARY - URBAN
* ==============================================================================

di _n "============================================================"
di "URBAN ANALYSIS COMPLETE"
di "============================================================"
di "Output saved to: `output_path'"
di "Files: MICS6_Antibiotic_Analysis_Urban.dta and .csv"
di ""
di "URBAN SAMPLE SUMMARY:"
di "  Total sick children:            " _N
qui count if care_was_sought == 1
di "  Care sought:                    " r(N)
qui count if child_received_ab == 1
di "  Antibiotic users:               " r(N)
qui count if informal_source == 0 & child_received_ab == 1
di "  Formal source users:            " r(N)
qui count if informal_source == 1 & child_received_ab == 1
di "  Informal source users:          " r(N)
di "============================================================"

* ==============================================================================
* END OF URBAN DO-FILE
* ==============================================================================