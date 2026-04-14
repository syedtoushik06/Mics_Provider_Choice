* ==============================================================================
* PROJECT: Factors Affecting Child Healthcare Provider Choice (MICS 2019)
* AUTHOR:  Syed Toushik Hossain (Batch IHE 15, IHE, DU)
* ==============================================================================

clear all
set more off
set linesize 120
version 16.0

* ------------------------------------------------------------------------------
* Set your file paths here
* ------------------------------------------------------------------------------
local path "C:/Users/HP/Desktop/MICS/Bangladesh MICS6 SPSS Datasets/"
local out  "C:/Users/HP/Desktop/MICS/Output/"

cap mkdir "`out'"

* ==============================================================================
* STEP 1: IMPORT AND SAVE SUB-MODULES
* ==============================================================================

* --- Household module ---
import spss using "`path'hh.sav", clear
rename *, lower
save "`out'hh_temp.dta", replace
di "HH module saved. N = `c(N)'"

* --- Women's module ---
import spss using "`path'wm.sav", clear
rename *, lower
rename ln uf4
save "`out'wm_temp.dta", replace
di "WM module saved. N = `c(N)'"

* ==============================================================================
* STEP 2: MASTER MERGE (STARTING FROM CHILD MODULE)
* ==============================================================================

import spss using "`path'ch.sav", clear
rename *, lower
di "Child module loaded. N = `c(N)'"

merge m:1 hh1 hh2 uf4 using "`out'wm_temp.dta", ///
    keep(master match) gen(_mwm)
di "After WM merge:"
tab _mwm

merge m:1 hh1 hh2 using "`out'hh_temp.dta", ///
    keep(master match) gen(_mhh)
di "After HH merge:"
tab _mhh

drop _mwm _mhh

foreach f in hh wm {
    erase "`out'`f'_temp.dta"
}

di "Merged dataset N = `c(N)'"

* ==============================================================================
* STEP 3: DEFINE SICK CHILDREN (ANALYTICAL POPULATION)
* ==============================================================================

gen ari = (ca16 == 1 & (ca17 == 1 | ca18 == 1))
label variable ari "Acute Respiratory Infection"

gen is_ill = (ca1 == 1 | ca14 == 1 | ari == 1)
label variable is_ill "Child had diarrhea, fever, or ARI in last 2 weeks"

count if is_ill == 1
keep if is_ill == 1
di "Analytical sample: N = `c(N)'"

* ==============================================================================
* STEP 4: RECODE MICS MISSING VALUE FLAGS
* ==============================================================================

local mics_cats ///
    ca1 ca14 ca16 ca17 ca18 ///
    melevel windex5 hh6 hh7 ws1 ws11 ///
    mt10 mt11 ///
    mn5 mn7 mn20 ///
    dv1a dv1b dv1c dv1d dv1e ///
    ha2 ha3 ha4 ha5 ha6 ///
    ma11

foreach var of local mics_cats {
    capture replace `var' = . if inlist(`var', 7, 8, 9, 97, 98, 99)
}

di "MICS flags recoded."

* ==============================================================================
* STEP 5: CONVERT PROVIDER STRING VARIABLES TO NUMERIC (0/1)
* ==============================================================================

local provvars ///
    ca6a  ca6b  ca6c  ca6d  ca6e  ca6h  ///
    ca6i  ca6j  ca6k  ca6l  ca6m  ca6n  ca6o  ca6p  ca6q  ca6r  ca6s  ca6w  ///
    ca21a ca21b ca21c ca21d ca21e ca21h ///
    ca21i ca21j ca21k ca21l ca21m ca21n ca21o ca21p ca21q ca21r ca21s ca21w

foreach var of local provvars {
    capture confirm variable `var'
    if !_rc {
        capture confirm string variable `var'
        if !_rc {
            gen byte `var'_num = (!missing(`var') & `var' != "")
            drop `var'
            rename `var'_num `var'
        }
        else {
            replace `var' = 0 if missing(`var')
        }
    }
    else {
        gen byte `var' = 0
    }
}

di "All provider variables converted to numeric 0/1."

* ==============================================================================
* STEP 6: GENERATE DEPENDENT VARIABLE — PROVIDER CHOICE
* ==============================================================================

capture label drop prov_lbl
label define prov_lbl ///
    0 "No care sought"      ///
    1 "Public provider"     ///
    2 "Private provider"    ///
    3 "Pharmacy/Traditional"

gen byte provider_choice = 0
label values provider_choice prov_lbl
label variable provider_choice "Healthcare provider type sought for sick child"

* PUBLIC MEDICAL SECTOR
* A=Govt Hospital  B=Govt Health Centre  C=Govt Health Post
* D=Community Health Worker (Govt)  E=Mobile/Outreach Clinic  H=Other Public
replace provider_choice = 1 if ///
    ca6a==1 | ca6b==1 | ca6c==1 | ca6d==1 | ca6e==1 | ca6h==1 | ///
    ca21a==1 | ca21b==1 | ca21c==1 | ca21d==1 | ca21e==1 | ca21h==1

* PRIVATE MEDICAL SECTOR
* I=Private Hospital  J=Private Physician  L=NGO CHW  M=Private Mobile
* N=NGO Clinic  O=Other Private  W=DK Public or Private
replace provider_choice = 2 if ///
    ca6i==1 | ca6j==1 | ca6l==1 | ca6m==1 | ca6n==1 | ca6o==1 | ca6w==1 | ///
    ca21i==1 | ca21j==1 | ca21l==1 | ca21m==1 | ca21n==1 | ca21o==1 | ca21w==1

* PHARMACY / TRADITIONAL / OTHER
* K=Pharmacy  P=Relative/Friend  Q=Shop/Market  R=Traditional  S=Charms
replace provider_choice = 3 if ///
    ca6k==1 | ca6p==1 | ca6q==1 | ca6r==1 | ca6s==1 | ///
    ca21k==1 | ca21p==1 | ca21q==1 | ca21r==1 | ca21s==1

di "Provider choice distribution:"
tab provider_choice, missing

* ==============================================================================
* STEP 7: GENERATE INDEPENDENT VARIABLES
* ==============================================================================

* ------------------------------------------------------------------------------
* 7.1 CHILD-LEVEL VARIABLES
* ------------------------------------------------------------------------------

gen malnourished = (haz2 < -2 | whz2 < -2 | waz2 < -2) ///
    if !missing(haz2, whz2, waz2)
label variable malnourished "Any malnutrition (HAZ, WAZ, or WHZ below -2 SD)"

gen illness_severity = (ca1==1) + (ca14==1) + (ari==1)
label variable illness_severity "Number of concurrent illnesses (1 to 3)"

gen is_firstborn = (cdob == wdobfc) if !missing(cdob, wdobfc)
label variable is_firstborn "Child is firstborn"

gen magebrt = (cdob - wdob) / 12 if !missing(cdob, wdob)
replace magebrt = . if magebrt < 12 | magebrt > 55
label variable magebrt "Mother's age at child's birth (years)"

gen teen_mother_at_birth = (magebrt < 20) if !missing(magebrt)
label variable teen_mother_at_birth "Mother was teenager at child's birth"

gen birth_interval = (cdob - wdobfc) ///
    if !missing(cdob, wdobfc) & is_firstborn == 0
label variable birth_interval "Months since mother's first child (proxy birth interval)"

gen has_health_card = (mn7 == 1) if !missing(mn7)
label variable has_health_card "Child has health card"

gen child_male = (hl4 == 1) if !missing(hl4)
label variable child_male "Child is male (1=male, 0=female)"

gen birth_registered = 0 if !missing(br1)
capture replace birth_registered = 1 if br1 == "Y"
capture replace birth_registered = 1 if br1 == 1
label variable birth_registered "Child's birth is officially registered"

* Child functional difficulty (ucf* variables, ages 24+ months)
gen child_disability = 0
foreach ucf_var of varlist ucf2 ucf3 ucf4 ucf7 ucf9 ucf11 ucf12 ucf13 ///
                            ucf14 ucf15 ucf16 ucf17 ucf18 ucf19 {
    capture confirm variable `ucf_var'
    if !_rc {
        capture replace child_disability = 1 if inlist(`ucf_var', 3, 4)
        capture replace child_disability = 1 if inlist(`ucf_var', "S", "C", "V", "L")
    }
}
replace child_disability = . if cage < 24
label variable child_disability "Child has at least one functional difficulty (2-4 yrs)"

gen ever_vaccinated = (mn7 == 1 | mn7 == 2) if !missing(mn7)
label variable ever_vaccinated "Child has ever been vaccinated (card seen/reported)"

capture gen num_u5_hh = wnum5 if !missing(wnum5)
capture label variable num_u5_hh "Number of children under 5 in household"

* ------------------------------------------------------------------------------
* 7.2 MATERNAL VARIABLES
* ------------------------------------------------------------------------------

* Health literacy — recode ha2-ha6 from string if needed
foreach havar in ha2 ha3 ha4 ha5 ha6 {
    capture confirm string variable `havar'
    if !_rc {
        gen `havar'_n = .
        replace `havar'_n = 1 if `havar' == "Y"
        replace `havar'_n = 2 if `havar' == "N"
        replace `havar'_n = 8 if `havar' == "D"
        drop `havar'
        rename `havar'_n `havar'
    }
}

gen health_literacy = (ha2==1) + (ha3==2) + (ha4==1) + (ha5==2) + (ha6==2) ///
    if !missing(ha2, ha3, ha4, ha5, ha6)
label variable health_literacy "HIV/health knowledge score (0 to 5)"

gen early_marriage = (ma11 < 18) if !missing(ma11)
label variable early_marriage "Mother married before age 18"

gen teen_mother_now = (wb4 < 20) if !missing(wb4)
label variable teen_mother_now "Mother currently a teenager (age < 20)"

* Maternal autonomy — recode dv1a-dv1e from string if needed
foreach dvvar in dv1a dv1b dv1c dv1d dv1e {
    capture confirm string variable `dvvar'
    if !_rc {
        gen `dvvar'_n = .
        replace `dvvar'_n = 1 if `dvvar' == "1"
        replace `dvvar'_n = 2 if `dvvar' == "2"
        replace `dvvar'_n = 3 if `dvvar' == "3"
        replace `dvvar'_n = 4 if `dvvar' == "4"
        replace `dvvar'_n = 5 if `dvvar' == "5"
        drop `dvvar'
        rename `dvvar'_n `dvvar'
    }
}

gen high_autonomy = (dv1a==2 & dv1b==2 & dv1c==2 & dv1d==2 & dv1e==2) ///
    if !missing(dv1a, dv1b, dv1c, dv1d, dv1e)
label variable high_autonomy "Full joint decision-making autonomy (all 5 domains)"

* Media exposure (radio not available in this dataset)
gen reads_newspaper = inlist(wb6a, 1, 2) if !missing(wb6a)
gen watches_tv      = inlist(wb6b, 1, 2) if !missing(wb6b)
gen media_exposure  = reads_newspaper + watches_tv if !missing(wb6a, wb6b)
label variable reads_newspaper "Mother reads newspaper/magazine at least weekly"
label variable watches_tv      "Mother watches television at least weekly"
label variable media_exposure  "Media exposure score (0=none to 2=both)"

* ICT
gen own_phone = (mt1 == 1) if !missing(mt1)
label variable own_phone "Mother personally owns a mobile phone"

gen mother_internet = (mt4 == 1) if !missing(mt4)
label variable mother_internet "Mother personally uses internet"

gen ict_empowerment = own_phone + mother_internet if !missing(mt1, mt4)
label variable ict_empowerment "ICT empowerment (0=none, 1=phone only, 2=phone+internet)"

* Domestic violence (may only exist in separate DV module)
capture gen experienced_violence = .
capture {
    foreach dv_var of varlist dv3a dv3b dv3c dv3d dv3e {
        replace dv_var = . if inlist(`dv_var', 7, 8, 9)
    }
    replace experienced_violence = 0 if !missing(dv3a)
    foreach dv_var of varlist dv3a dv3b dv3c dv3d dv3e {
        replace experienced_violence = 1 if `dv_var' == 1
    }
}
capture label variable experienced_violence "Mother experienced domestic physical violence"

* Parity
capture gen parity = wb17 if !missing(wb17)
capture replace parity = . if parity > 15
capture label variable parity "Total number of children ever born to mother"

capture gen high_parity = (parity >= 3) if !missing(parity)
capture label variable high_parity "Mother has 3 or more children (high parity)"

* Mother working
capture gen mother_working = (wb18 == 1) if !missing(wb18)
capture label variable mother_working "Mother is currently employed/working"

* ------------------------------------------------------------------------------
* 7.3 HOUSEHOLD AND SES VARIABLES
* ------------------------------------------------------------------------------

gen digital_access = (mt10 == 1 & mt11 == 1) if !missing(mt10, mt11)
label variable digital_access "Household has both mobile phone and internet access"

* Crowding index
capture confirm string variable hh12
if !_rc {
    gen hh12_num = .
    replace hh12_num = 1  if hh12 == "A"
    replace hh12_num = 2  if hh12 == "B"
    replace hh12_num = 3  if hh12 == "C"
    replace hh12_num = 4  if hh12 == "D"
    replace hh12_num = 5  if hh12 == "E"
    replace hh12_num = 6  if hh12 == "F"
    replace hh12_num = 7  if hh12 == "G"
    replace hh12_num = 8  if hh12 == "H"
    replace hh12_num = 9  if hh12 == "I"
    replace hh12_num = 10 if hh12 == "J"
    gen crowding_index = hh48 / hh12_num ///
        if hh12_num > 0 & !missing(hh48, hh12_num)
    drop hh12_num
}
else {
    gen crowding_index = hh48 / hh12 if hh12 > 0 & !missing(hh48, hh12)
}
replace crowding_index = . if crowding_index > 20
label variable crowding_index "Persons per sleeping room"

* WASH
gen safe_water  = inlist(ws1,  11,12,13,14,21,31,41,51,91) if !missing(ws1)
gen safe_toilet = inlist(ws11, 11,12,13,21,22)              if !missing(ws11)
gen wash_risk   = (safe_water==0 | safe_toilet==0)          if !missing(ws1, ws11)
label variable safe_water  "Household uses improved water source"
label variable safe_toilet "Household uses improved sanitation facility"
label variable wash_risk   "Inadequate water or sanitation (either)"

* Urban/Rural
capture confirm string variable hh6
if !_rc {
    gen hh6_num = .
    replace hh6_num = 1 if hh6 == "U"
    replace hh6_num = 2 if hh6 == "R"
    drop hh6
    rename hh6_num hh6
}
gen urban = (hh6 == 1) if !missing(hh6)
label variable urban "Urban residence (1=urban, 0=rural)"

* Female-headed household
capture confirm variable hh15
if !_rc {
    gen female_headed_hh = .
    capture replace female_headed_hh = 0 if hh15 == "M" | hh15 == 1
    capture replace female_headed_hh = 1 if hh15 == "F" | hh15 == 2
    label variable female_headed_hh "Household is female-headed"
}
else {
    gen female_headed_hh = .
    label variable female_headed_hh "Female-headed HH (source variable not found)"
}

* Social transfer
capture gen social_transfer = (st1 == 1) if !missing(st1)
capture label variable social_transfer "Household receives government social transfer"

* Clean cooking fuel
capture gen clean_fuel = inlist(eu1, 1, 2, 3, 4) if !missing(eu1)
capture label variable clean_fuel "Household uses clean cooking fuel"

* Asset count
gen asset_count = 0
foreach asset_var in hh12a hh12b hh12c hh12d hh12e hh12f hh12g hh12h {
    capture replace asset_count = asset_count + (`asset_var' == 1)
    capture replace asset_count = asset_count + (`asset_var' == "Y")
}
capture label variable asset_count "Number of household assets owned (0 to 8)"

* ------------------------------------------------------------------------------
* 7.4 HEALTHCARE UTILIZATION HISTORY
* ------------------------------------------------------------------------------

gen high_anc = (mn5 >= 4) if !missing(mn5)
label variable high_anc "Mother had 4 or more ANC visits"

gen facility_birth = inrange(mn20, 21, 31) if !missing(mn20)
label variable facility_birth "Child delivered in a health facility"

* ------------------------------------------------------------------------------
* 7.5 CHILD NUTRITION AND DEVELOPMENT
* ------------------------------------------------------------------------------

capture gen still_breastfed = (bd2 == 1) if !missing(bd2) & cage <= 23
capture replace still_breastfed = 1 if bd2 == "Y" & cage <= 23
capture label variable still_breastfed "Child is still breastfed (0-23 months)"

local food_groups bd4a bd4b bd4c bd4d bd4e bd4f bd4g bd4h
local fg_count = 0
foreach fg of local food_groups {
    capture confirm variable `fg'
    if !_rc local fg_count = `fg_count' + 1
}
if `fg_count' > 0 {
    gen dietary_score = 0
    foreach fg of local food_groups {
        capture replace dietary_score = dietary_score + (`fg' == 1)
        capture replace dietary_score = dietary_score + (`fg' == "Y")
    }
    gen min_diet_diversity = (dietary_score >= 5) if cage >= 6 & cage <= 23
    label variable dietary_score     "Number of food groups consumed (0-8)"
    label variable min_diet_diversity "Child meets minimum dietary diversity (5+ food groups)"
}

capture gen ecd_attendance = (ec7 == 1) if !missing(ec7) & cage >= 36
capture replace ecd_attendance = 1 if ec7 == "Y" & cage >= 36
capture label variable ecd_attendance "Child attends ECD programme (3-4 yrs)"

* ------------------------------------------------------------------------------
* 7.6 MATERNAL HEALTH BEHAVIOUR
* ------------------------------------------------------------------------------

capture gen skilled_attendant = inlist(mn17, 1, 2, 3) if !missing(mn17)
capture label variable skilled_attendant "Delivery attended by skilled health professional"

capture gen received_pnc = (pn4 == 1) if !missing(pn4)
capture label variable received_pnc "Mother received postnatal health check"

* Modern contraception
gen modern_contraception = 0
foreach cp_var in cp4a cp4b cp4c cp4d cp4e cp4f cp4g cp4h cp4i cp4j cp4k cp4l cp4m {
    capture replace modern_contraception = 1 if `cp_var' == 1
    capture replace modern_contraception = 1 if !missing(`cp_var') & `cp_var' != ""
}
capture replace modern_contraception = . if missing(cp2)
capture label variable modern_contraception "Mother currently uses modern contraceptive method"

* ------------------------------------------------------------------------------
* 7.7 HYGIENE VARIABLES
* hw1: 1=fixed place 2=mobile 3=no place
* hw2: 1=soap available 2=not
* hw3: 1=water available 2=not
* ------------------------------------------------------------------------------
capture gen handwash_soap  = (hw1 != 3 & hw2 == 1) if !missing(hw1, hw2)
capture gen handwash_water = (hw1 != 3 & hw3 == 1) if !missing(hw1, hw3)
capture gen good_hygiene   = (hw1 != 3 & hw2 == 1 & hw3 == 1) if !missing(hw1, hw2, hw3)
capture label variable handwash_soap  "Handwashing place with soap available"
capture label variable handwash_water "Handwashing place with water available"
capture label variable good_hygiene   "Adequate handwashing (place + soap + water)"

* ------------------------------------------------------------------------------
* 7.8 COMPOSITE: CARE ENGAGEMENT SCORE (0-5)
* ------------------------------------------------------------------------------
gen care_engagement = 0
foreach ce_var of varlist high_anc facility_birth {
    capture replace care_engagement = care_engagement + (`ce_var' == 1)
}
foreach ce_var in skilled_attendant received_pnc ever_vaccinated {
    capture replace care_engagement = care_engagement + (`ce_var' == 1)
}
label variable care_engagement "Prior formal health system engagement score (0-5)"

* ==============================================================================
* STEP 7b: KEEP ONLY VARIABLES THAT EXIST
* ==============================================================================

local keep_vars ""
foreach var in ///
    hh1 hh2 uf4 ///
    chweight hh6 hh7 ///
    ca1 ca14 ca16 ca17 ca18 ///
    ca6a  ca6b  ca6c  ca6d  ca6e  ca6h  ///
    ca6i  ca6j  ca6k  ca6l  ca6m  ca6n  ca6o  ca6p  ca6q  ca6r  ca6s  ca6w  ///
    ca21a ca21b ca21c ca21d ca21e ca21h ///
    ca21i ca21j ca21k ca21l ca21m ca21n ca21o ca21p ca21q ca21r ca21s ca21w ///
    haz2 whz2 waz2 ///
    cdob wdob wdobfc wb4 ///
    melevel windex5 ///
    mn5 mn7 mn20 ///
    dv1a dv1b dv1c dv1d dv1e ///
    ha2 ha3 ha4 ha5 ha6 ///
    ma11 mt10 mt11 ///
    ws1 ws11 hh48 ///
    provider_choice ari is_ill ///
    malnourished illness_severity is_firstborn magebrt ///
    teen_mother_at_birth birth_interval has_health_card ///
    cage child_male birth_registered child_disability ever_vaccinated ///
    health_literacy early_marriage teen_mother_now high_autonomy ///
    reads_newspaper watches_tv media_exposure ///
    own_phone mother_internet ict_empowerment ///
    digital_access crowding_index safe_water safe_toilet wash_risk urban ///
    female_headed_hh high_anc facility_birth care_engagement ///
    experienced_violence parity high_parity ///
    good_hygiene handwash_soap handwash_water ///
    clean_fuel asset_count still_breastfed ecd_attendance ///
    received_pnc modern_contraception {

    capture confirm variable `var'
    if !_rc {
        local keep_vars "`keep_vars' `var'"
    }
    else {
        di as error "  SKIPPED (not found): `var'"
    }
}

foreach opt_var in num_u5_hh min_diet_diversity dietary_score ///
                   skilled_attendant mother_working social_transfer {
    capture confirm variable `opt_var'
    if !_rc local keep_vars "`keep_vars' `opt_var'"
}

keep `keep_vars'

di "============================================================"
di " Variables kept:  `c(k)'"
di " Observations:    `c(N)'"
di "============================================================"

* ==============================================================================
* STEP 7c: VALUE LABELS — ALL VARIABLES
* ==============================================================================

* --- Binary Yes/No label ---
capture label drop yesno_lbl
label define yesno_lbl 0 "No" 1 "Yes"

* --- Provider choice ---
capture label drop prov_lbl
label define prov_lbl ///
    0 "No care sought"      ///
    1 "Public provider"     ///
    2 "Private provider"    ///
    3 "Pharmacy/Traditional"
label values provider_choice prov_lbl
label variable provider_choice "Healthcare provider type sought for sick child"

* --- Mother's education ---
capture label drop melevel_lbl
label define melevel_lbl ///
    0 "No education" 1 "Primary" 2 "Secondary" 3 "Higher"
label values melevel melevel_lbl
label variable melevel "Mother's highest education level"

* --- Wealth index ---
capture label drop windex5_lbl
label define windex5_lbl ///
    1 "Poorest" 2 "Second" 3 "Middle" 4 "Fourth" 5 "Richest"
label values windex5 windex5_lbl
label variable windex5 "Household wealth index quintile"

* --- Area of residence ---
capture label drop hh6_lbl
label define hh6_lbl 1 "Urban" 2 "Rural"
label values hh6 hh6_lbl
label variable hh6 "Area of residence"

* --- Division ---
capture label drop hh7_lbl
label define hh7_lbl ///
    10 "Barishal"   20 "Chattogram" 30 "Dhaka"    40 "Khulna" ///
    45 "Mymensingh" 50 "Rajshahi"   55 "Rangpur"  60 "Sylhet"
label values hh7 hh7_lbl
label variable hh7 "Division"

* --- Water source ---
capture label drop ws1_lbl
label define ws1_lbl ///
    11 "Piped into dwelling"  12 "Piped into yard/plot" ///
    13 "Piped to neighbour"   14 "Public tap/standpipe" ///
    21 "Tube well/borehole"   31 "Protected dug well"   ///
    32 "Unprotected dug well" 41 "Protected spring"     ///
    42 "Unprotected spring"   51 "Rainwater"            ///
    61 "Tanker truck"         71 "Cart with small tank" ///
    81 "Surface water"        91 "Bottled water"        ///
    96 "Other"
label values ws1 ws1_lbl
label variable ws1 "Main drinking water source"

* --- Sanitation ---
capture label drop ws11_lbl
label define ws11_lbl ///
    11 "Flush to piped sewer"     12 "Flush to septic tank"     ///
    13 "Flush to pit latrine"     14 "Flush to open drain"      ///
    15 "Flush to unknown place"   21 "Ventilated improved pit"  ///
    22 "Pit latrine with slab"    23 "Pit latrine without slab" ///
    31 "Composting toilet"        41 "Hanging toilet/latrine"   ///
    51 "No facility/bush/field"   96 "Other"
label values ws11 ws11_lbl
label variable ws11 "Type of sanitation facility"

* --- Household mobile/internet ---
capture label drop mt_yn_lbl
label define mt_yn_lbl 1 "Yes" 2 "No"
label values mt10 mt_yn_lbl
label values mt11 mt_yn_lbl
label variable mt10 "Household member has mobile phone"
label variable mt11 "Household has internet access"

* --- Child health card ---
capture label drop mn7_lbl
label define mn7_lbl 1 "Yes, card seen" 2 "Yes, card not seen" 3 "No"
label values mn7 mn7_lbl
label variable mn7 "Child has health/vaccination card"

* --- Place of delivery ---
capture label drop mn20_lbl
label define mn20_lbl ///
    11 "Home"                     12 "Other home"               ///
    21 "Government hospital"      22 "Government health centre" ///
    23 "Government health post"   26 "Other government"         ///
    31 "Private hospital/clinic"  32 "Private doctor"           ///
    33 "NGO facility"             36 "Other private"            ///
    96 "Other"
label values mn20 mn20_lbl
label variable mn20 "Place of delivery"

* --- ANC visits (continuous) ---
label variable mn5 "Number of ANC visits during pregnancy"

* --- Autonomy decision domains ---
capture label drop dv1_lbl
label define dv1_lbl ///
    1 "Respondent alone" 2 "Jointly with husband" ///
    3 "Husband alone"    4 "Someone else"          5 "Other"
label values dv1a dv1b dv1c dv1d dv1e dv1_lbl
label variable dv1a "Decision maker: own healthcare"
label variable dv1b "Decision maker: large household purchases"
label variable dv1c "Decision maker: daily household purchases"
label variable dv1d "Decision maker: visits to family/relatives"
label variable dv1e "Decision maker: what food to cook"

* --- Health literacy items ---
capture label drop ha_lbl
label define ha_lbl 1 "Yes" 2 "No" 8 "Don't know"
label values ha2 ha3 ha4 ha5 ha6 ha_lbl
label variable ha2 "Condoms reduce HIV transmission"
label variable ha3 "Healthy-looking person can have HIV"
label variable ha4 "HIV can transmit through breastfeeding"
label variable ha5 "HIV transmitted through mosquito bites (myth)"
label variable ha6 "HIV transmitted through sharing food (myth)"

* --- Continuous variables (no value labels needed, only variable labels) ---
label variable ma11         "Mother's age at first marriage (years)"
label variable wb4          "Current age of mother (years)"
label variable hh48         "Number of household members"
label variable cage         "Child's age in months"
label variable magebrt      "Mother's age at child's birth (years)"
label variable birth_interval "Months since mother's first child (proxy birth interval)"
label variable crowding_index "Persons per sleeping room"
label variable illness_severity "Number of concurrent illnesses (1 to 3)"
label variable health_literacy  "HIV/health knowledge score (0 to 5)"
label variable media_exposure   "Media exposure score (0=none to 2=both)"
label variable ict_empowerment  "ICT empowerment score (0=none to 2=phone+internet)"
label variable parity           "Total children ever born to mother"
label variable care_engagement  "Prior health system engagement score (0-5)"
label variable asset_count      "Number of household assets owned (0-8)"
label variable chweight         "Child survey weight"

* --- Child sex ---
capture label drop sex_lbl
label define sex_lbl 0 "Female" 1 "Male"
label values child_male sex_lbl

* --- ICT empowerment (ordinal) ---
capture label drop ict_lbl
label define ict_lbl 0 "None" 1 "Phone only" 2 "Phone and internet"
label values ict_empowerment ict_lbl

* --- Media exposure (ordinal) ---
capture label drop media_lbl
label define media_lbl 0 "None" 1 "One medium" 2 "Both media"
label values media_exposure media_lbl

* --- Illness severity (ordinal) ---
capture label drop ill_lbl
label define ill_lbl 1 "One illness" 2 "Two illnesses" 3 "Three illnesses"
label values illness_severity ill_lbl

* --- Apply Yes/No to all binary variables ---
foreach binvar of varlist ///
    ari is_ill malnourished is_firstborn teen_mother_at_birth ///
    has_health_card birth_registered child_disability ever_vaccinated ///
    early_marriage teen_mother_now high_autonomy ///
    reads_newspaper watches_tv own_phone mother_internet ///
    digital_access safe_water safe_toilet wash_risk urban ///
    female_headed_hh high_anc facility_birth ///
    good_hygiene handwash_soap handwash_water child_male {
    capture label values `binvar' yesno_lbl
}

foreach binvar in experienced_violence high_parity mother_working ///
    social_transfer clean_fuel still_breastfed ecd_attendance ///
    skilled_attendant received_pnc modern_contraception ///
    min_diet_diversity birth_registered {
    capture label values `binvar' yesno_lbl
}

di "All value labels applied."

* ==============================================================================
* STEP 8: SURVEY DESIGN DECLARATION
* ==============================================================================

cap drop strata_var
egen strata_var = group(hh7 hh6), label
label variable strata_var "Strata: Division x Urban/Rural"

svyset hh1 [pw=chweight], strata(strata_var)

di "Survey design declared."
svydes

* ==============================================================================
* STEP 9: FINAL CHECKS
* ==============================================================================

di "Final analytical N:"
count

di "Outcome distribution (weighted):"
svy: tab provider_choice

di "===== MISSING VALUES — ALL INDEPENDENT VARIABLES ====="
foreach var in ///
    cage child_male birth_registered child_disability ever_vaccinated ///
    malnourished illness_severity is_firstborn magebrt ///
    teen_mother_at_birth birth_interval has_health_card ///
    melevel windex5 urban female_headed_hh ///
    health_literacy early_marriage teen_mother_now high_autonomy ///
    reads_newspaper watches_tv media_exposure ///
    own_phone mother_internet ict_empowerment ///
    experienced_violence parity high_parity ///
    digital_access crowding_index safe_water safe_toilet wash_risk ///
    social_transfer clean_fuel asset_count ///
    high_anc facility_birth received_pnc ///
    modern_contraception care_engagement ///
    good_hygiene handwash_soap handwash_water ///
    still_breastfed ecd_attendance {
    capture {
        qui count if missing(`var')
        di "  `var': `r(N)' missing"
    }
}

di "Continuous variable summaries:"
sum cage magebrt birth_interval crowding_index illness_severity ///
    health_literacy media_exposure ict_empowerment parity ///
    care_engagement mn5 haz2 whz2 waz2 chweight

* ==============================================================================
* STEP 10: SAVE CLEANED DATASET
* ==============================================================================

notes drop _all
notes: Dataset: Bangladesh MICS6 (2019)
notes: Author: Syed Toushik Hossain, IHE Batch 15, University of Dhaka
notes: Population: children under 5 with diarrhea, fever, or ARI
notes: FIX: ucf* used for child disability (not cf*)
notes: FIX: hh15 used for sex of household head (not hh11)
notes: FIX: radio (wb6c) not available — media score is 0-2 only
notes: FIX: mt1 coded 0/1; cp4 is multi-variable; pn4 used for PNC
notes: FIX: hh12 string-decoded; ha2-ha6/br1 recoded from string

save "`out'MICS6_CleanedData_Toushik.dta", replace

di "============================================================"
di " DATA PREPARATION COMPLETE"
di " Saved: MICS6_CleanedData_Toushik.dta"
di " Total variables: `c(k)'"
di " Total observations: `c(N)'"
di "============================================================"