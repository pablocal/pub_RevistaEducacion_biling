*******************************************************
****** BilingDia - MI from PISA 15       **************
*******************************************************
//*// Syntax 2: MI prev analysis

// 0. Set-up
	clear all
	cd "E:\Rproj\BilingPISA"
	version 15

// 1. Get data
	use "data\ML_analysis.dta", clear
	fre region
	keep if inlist(region, 72409, 72416, 72415, 72404, 72411, 72417)


// 2. Sum data
	preserve
	drop w_*
	sum
	restore 

// 3. Missing data 
	misstable sum
	misstable patterns

	gen miss = 0
	foreach v in immig escs repeat age langn_r schsize lead schaut stratio schltype clsize {
	replace miss = 1 if `v' == .	
	}
	fre miss

	foreach v in region gender langn_r {
	tab `v' miss, row 
	}

	tabstat escs pv1math-schaut, by(miss) stat(mean sd) //sample imbalance in the basque country and worse pvmath.

// 4. Pre - multiple imputation set up 

	**4.1 Prepare variables 
		
		sort region w_fstuwt
		by region: egen wt_quint = xtile(w_fstuwt), nq(5) 
		by region: fre wt_quint 
		egen pvmath_imp = rowmean(pv1math-pv10math) 
		egen pvread_imp = rowmean(pv1read-pv10read)
		egen pvscie_imp = rowmean(pv1scie-pv10scie)
		tab schltype, gen(schltypecat)
	
		save "data\ML_to_imp_student.dta", replace

	**4.2 Prepare school file with means at school level

		preserve
		quietly: tab immig, gen(immig_)
		quietly: tab gender, gen(gender_)
		quietly: tab langn_r, gen(langn_)
		collapse (mean) gender_* immig_* scchange repeat age escs pvmath_imp pvread_imp pvscie_imp langtest_coof langn_*  ///
		 (first) schsize lead clsize stratio schltype region w_schgrnrabwt, by(cntschid)
		sort region w_schgrnrabwt
		by region: egen wt_sch_quint = xtile(w_schgrnrabwt), nq(5) 
		by region: fre wt_sch_quint 
		save "data\ML_to_imp_school.dta", replace
		restore

	**4.3 Prepare plausible values for mi merge
		gen pvmath = .
		gen pvread = .
		gen pvscie = .
		mi import wide, imputed(pvmath = pv1math-pv10math pvread = pv1read-pv10read pvscie = pv1scie-pv10scie) clear
		keep cntstuid pvmath pvread pvscie _*
		mi describe
		save "data\ML_imp_pv.dta", replace

// 5. Imputation at schools

	**5.1 Set impute (schools)	
		use "data\ML_to_imp_school.dta", clear 
		set seed 12589

		mi set wide
		mi register imputed schsize lead clsize stratio schltype  
		mi register regular region gender_1 immig_1 immig_2 scchange repeat escs pvmath_imp pvread_imp pvscie_imp langtest_coof langn_1 langn_2

	**5.2 Imputation of school characteristics

		mi impute chained (pmm, knn(7)) schsize lead stratio clsize (logit) schltype  = ///
 			c.gender_1 c.immig_1 c.immig_2 c.escs c.pvread_imp c.pvmath_imp c.pvscie_imp c.repeat c.age i.region ///
 			c.langtest_coof c.langn_1 c.langn_2 c.scchange  i.wt_sch_quint, ///
 			add(10) augment chaindots savetrace("data\MIconvergence_school.dta", replace) burnin(50) 
 			

 	**5.3 Imputation diagnostics at school level

 		**5.3.1 Convergence plots 

 			** convergence diagnostic **
			preserve
			use "data\MIconvergence_school.dta", replace
			reshape long @_mean @_sd, i(iter m) j(var) string
			renpfix _ est
			bys iter var: egen mean_mean = mean(estmean)
			bys iter var: egen mean_sd = mean(estsd)
			* Generate line plots - no systematic trend should be visible
			tw ///
			 || line mean_mean iter, lcol(red) sort ///
			 || line mean_sd iter, yaxis(2) lcol(blue) sort ///
			 ||, by(var, yrescale) name(conver_school, replace)
			restore
			** convergence diagnostic **
		
		**5.3.2 Post-imputation diagnostics

			*midiagplots schsize lead clsize stratio schltype, ksmirnov combine 

	**5.4 Prepare take-out file

		mi unregister region gender_1 immig_1 immig_2 scchange escs pvmath_imp pvread_imp pvscie_imp langtest_coof langn_1 langn_2 age repeat
		keep cntschid schsize lead clsize stratio schltype _* 
		save "data\ML_imp_school.dta", replace

// 6. Imputation at student level

	**6.1 Set impute (students)
		use "data\ML_to_imp_student.dta", clear 
		set seed 64782

		recode region (72415 72416 = 72415) , gen(region2)

		mi set wide
		mi register imputed schsize lead clsize stratio schltype immig escs age repeat  langn_r scchange 
		mi register regular gender pvmath_imp pvread_imp pvscie_imp langtest_coof wt_quint 

	**6.2 Imputation of school characteristics

		mi impute chained (pmm, knn(7)) escs schsize lead stratio (mlogit) immig langn_r (logit) repeat schltype  scchange = ///
 			i.gender c.pvread_imp c.pvmath_imp age c.pvscie_imp i.wt_quint i.langtest_coof, ///
 			add(10) augment chaindots  burnin(50) by(region)

 	**6.3 Imputation diagnostics at school level

 		**6.3.1 Convergence plots 

 			** convergence diagnostic **
			*preserve
			*use "data\MIconvergence_student.dta", replace
			*reshape long @_mean @_sd, i(iter m) j(var) string
			*renpfix _ est
			*bys iter var: egen mean_mean = mean(estmean)
			*bys iter var: egen mean_sd = mean(estsd)
			* Generate line plots - no systematic trend should be visible
			*tw ///
			* || line mean_mean iter, lcol(red) sort ///
			* || line mean_sd iter, yaxis(2) lcol(blue) sort ///
			* ||, by(var, yrescale) name(conver_student, replace)
			*restore
			** convergence diagnostic **
		
		**6.3.2 Post-imputation diagnostics

			*midiagplots escs immig langn_r, by(region)

	**6.4 Prepare take-out file

		mi unregister lead schsize lead clsize stratio schltype pvread_imp pvmath_imp pvscie_imp wt_quint 
		keep cntstuid cntschid region immig escs gender langn_r scchange langtest_coof age repeat ///
		  *scchange *langn_r *immig *escs *age *repeat *gender w_fstu* w_schgrnrabwt stratum _mi_miss
		save "data\ML_imp_student.dta", replace		

// 7. Prepare MI set for analysis

	**7.1 Get files

		 use "data\ML_imp_student.dta", clear
		 mi merge m:1 cntschid using "data\ML_imp_school.dta"
		 mi merge m:1 cntstuid using "data\ML_imp_pv.dta"

	**7.2 Prepare the scaled weight
		 sort cntschid
		 by cntschid: egen sum_wt = sum(w_fstuwt)
		 by cntschid: egen sum_n = sum(_n/_n)
		 gen scale_ind_wt = w_fstuwt/(sum_wt/sum_n)
		 list cntschid w_fstuwt w_schgrnrabwt sum_wt sum_n scale_ind_wt in 1/100

		 mi register regular cntschid w_fstuwt langtest_coof
		 mi describe 

	**7.3 Generate summary (school level) variables
		 mi passive: gen immig_dummy = 0
		 mi passive: replace immig_dummy = 1 if immig > 1

		 mi passive: gen langn_dummy = 0
		 mi passive: replace langn_dummy = 1 if langn_r == 2

		 mi passive: by cntschid: egen sch_escs = mean(escs)
		 mi passive: by cntschid: egen sch_immig = mean(immig_dummy)
		 mi passive: by cntschid: egen sch_langn = mean(langn_dummy) 

		 *check = OK.
		 list cntschid _1_sch_immig _1_immig in 1/60

	**7.4 Check RVI vars
		mi estimate: mean escs gender scchange repeat age schltype lead stratio clsize, over(region)
		mi estimate, vartable nocitable
		mi estimate, dftable

		mi estimate: prop langn_r, over(region)
		mi estimate, vartable nocitable	 

		mi estimate: prop immig, over(region)
		mi estimate, vartable nocitable	
	
// 8. Multilevel models

log using "logs\2 ML modelling.smcl", replace smcl
	**8.2 Models of *mins#lperif by region (Cataluña 72409, Pais Vasco, Navarra 72415, Baleares 72404, Valencia 72417, Galicia 72411)

	global regions 72409 72416 72415 72404 72411 72417
	global dep_vars "pvmath pvread pvscie"
	gen reg_labs = 1
	label define reg_labs 72409 "CAT" 72416 "PV" 72415 "NAV" 72417 "VAL" 72404 "BAL" 72411 "GAL"
	label values reg_labs reg_labs

	**8.2.2 pvmath - BY region AND subject
			
	foreach dep_var of global dep_vars {
		
		foreach region of global regions {  
				
				local reg_lab : label (reg_labs) `region'

				eststo `dep_var'_`reg_lab'_NULL: mi estimate, dots variance: mixed `dep_var' [pw=w_fstuwt] if region == `region' ///
									||cntschid: , pweight(w_schgrnrabwt) pwscale(size)  ///
									  mle
				
				**Compute base for R2
					matrix b = e(b_mi)
					global id_var_col = colnumb(b, "lns1_1_1:_cons")
					global l2_variance0 = exp(b[1, ${id_var_col}])^2
					global res_var_col = colnumb(b, "lnsig_e:_cons") 
					global Res_variance0 = exp(b[1, ${res_var_col}])^2

				
				eststo `dep_var'_`reg_lab'_langn: mi estimate, dots post variance: mixed `dep_var' i.langn_r   ///
										 [pw=w_fstuwt] if region == `region' ///
									||cntschid: , pweight(w_schgrnrabwt) pwscale(size) ///
									  mle
				estimates save models, append

				eststo `dep_var'_`reg_lab'_escs: mi estimate, dots post variance: mixed `dep_var' i.langn_r c.escs ///
										 [pw=w_fstuwt] if region == `region' ///
									||cntschid: , pweight(w_schgrnrabwt) pwscale(size) ///
									  mle
				estimates save models, append
				
				eststo `dep_var'_`reg_lab'_all: mi estimate, dots post variance: mixed `dep_var' i.langn_r c.escs i.immig i.gender i.scchange c.age i.repeat i.langtest_coof ///
										 i.schltype c.schsize c.lead c.stratio c.clsize  ///
										 c.sch_escs c.sch_immi c.sch_langn ///
										 [pw=w_fstuwt] if region == `region' ///
									||cntschid: , pweight(w_schgrnrabwt) pwscale(size) ///
									  mle
				estimates save models, append
				
				**MI commands 
					mi estimate, vartable nocitable
					mi estimate, dftable

				**Compute R2
					matrix b = e(b_mi)
					global id_var_col = colnumb(b, "lns1_1_1:_cons")
					global l2_var = exp(b[1, ${id_var_col}])^2
					global res_var_col = colnumb(b, "lnsig_e:_cons") 
					global Res_var = exp(b[1, ${res_var_col}])^2

					di "R2_level1 = " (${Res_variance0} - ${Res_var}) / ${Res_variance0}
					di "R2_level2 = " (${l2_variance0} - ${l2_var}) / ${l2_variance0}
					di "R2_overall = " ((${l2_variance0} + ${Res_variance0}) - (${l2_var} + ${Res_var})) / (${l2_variance0} + ${Res_variance0})

		  			}

		  				}


		  			eststo pvscie_VAL_all: mi estimate, dots post variance imputations(1 2 3 4 5 6 7 8 9) : mixed pvscie i.langn_r ///
		  			 c.escs i.immig i.gender i.scchange c.age i.repeat i.langtest_coof ///
										 i.schltype c.schsize c.lead c.stratio c.clsize  ///
										 c.sch_escs c.sch_immi c.sch_langn ///
										 [pw=w_fstuwt] if region == 72417 ///
									||cntschid: , pweight(w_schgrnrabwt) pwscale(size) ///
									  mle

global regions 72416 72415 72404 72411 72417

		
		foreach num of numlist  0/1 {
		
			foreach region of global regions {  

				if `num' == 1 {
					local a "C"
				}
				if `num' == 0 {
					local a "E"
				}
				
				local reg_lab : label (reg_labs) `region'

				eststo pvread`a'_`reg_lab'_NULL: mi estimate, dots variance: mixed pvread [pw=w_fstuwt] if region == `region' & langtest_coof == `num' ///
									|| cntschid: , pweight(w_schgrnrabwt) pwscale(size) ///
									  mle
				
				**Compute base for R2
					matrix b = e(b_mi)
					global id_var_col = colnumb(b, "lns1_1_1:_cons")
					global l2_variance0 = exp(b[1, ${id_var_col}])^2
					global res_var_col = colnumb(b, "lnsig_e:_cons") 
					global Res_variance0 = exp(b[1, ${res_var_col}])^2

				
				eststo pvread`a'_`reg_lab'_langn: mi estimate, dots post variance: mixed pvread i.langn_r   ///
										 [pw=w_fstuwt] if region == `region' & langtest_coof == `num' ///
									|| cntschid: , pweight(w_schgrnrabwt) pwscale(size) ///
									  mle
				estimates save models, append
				

				eststo pvread`a'_`reg_lab'_escs: mi estimate,  dots post variance: mixed pvread i.langn_r c.escs ///
										 [pw=w_fstuwt] if region == `region' & langtest_coof == `num' ///
									||cntschid: , pweight(w_schgrnrabwt) pwscale(size) ///
									  mle
				estimates save models, append


				eststo pvread`a'_`reg_lab'_all: mi estimate, dots post variance: mixed pvread i.langn_r c.escs i.immig i.gender i.scchange c.age i.repeat ///
										 i.schltype c.schsize c.lead c.stratio c.clsize  ///
										 c.sch_escs c.sch_immi c.sch_langn ///
										 [pw=w_fstuwt] if region == `region' & langtest_coof == `num' ///
									|| cntschid: , pweight(w_schgrnrabwt) pwscale(size) ///
									  mle
				estimates save models, append
				
				**MI commands 
					mi estimate, vartable nocitable
					mi estimate, dftable

				**Compute R2
					matrix b = e(b_mi)
					global id_var_col = colnumb(b, "lns1_1_1:_cons")
					global l2_var = exp(b[1, ${id_var_col}])^2
					global res_var_col = colnumb(b, "lnsig_e:_cons") 
					global Res_var = exp(b[1, ${res_var_col}])^2

					di "R2_level1 = " (${Res_variance0} - ${Res_var}) / ${Res_variance0}
					di "R2_level2 = " (${l2_variance0} - ${l2_var}) / ${l2_variance0}
					di "R2_overall = " ((${l2_variance0} + ${Res_variance0}) - (${l2_var} + ${Res_var})) / (${l2_variance0} + ${Res_variance0})

		  			}

		  				}

		  	**Modelos NAV y VAL all

		  	eststo pvreadC_NAV_all: mi estimate, dots post variance imputations(1 2 3 4 5 7 8 10): mixed pvread i.langn_r c.escs i.immig i.gender i.scchange c.age i.repeat ///
										 i.schltype c.schsize c.lead c.stratio c.clsize  ///
										 c.sch_escs c.sch_immi c.sch_langn ///
										 [pw=w_fstuwt] if region == 72415 & langtest_coof == 1 ///
									|| cntschid: , pweight(w_schgrnrabwt) pwscale(size) ///
									  mle


			eststo pvreadC_VAL_all: mi estimate, dots post variance: mixed pvread i.langn_r c.escs i.immig i.gender i.scchange c.age i.repeat ///
										 i.schltype c.schsize c.lead c.stratio c.clsize  ///
										 c.sch_escs c.sch_immi c.sch_langn ///
										 [pw=w_fstuwt] if region == 72417 & langtest_coof == 1 ///
									|| cntschid: , pweight(w_schgrnrabwt) pwscale(size) ///
									  mle


		  	global tablas se wide transform(ln*: exp(@) exp(@))         ///
 						    eqlabels("" "DT(Constante)" "DT(Residuos)", none)  booktabs   ///
 						    mlabels("Base" "Control ESCS" "Controles") ///
 						    refcat(2.langn_r "Lengua en casa (ref. español)" 2.immig "Inmigrante (ref. nativo)" 2.gender "Género (ref. mujer)" ///
 						    1.langtest_coof "Lengua prueba (ref. español)" 1.schltype "Titularidad centro (ref. público)", nolabel) ///
   							varlabels(_cons "Constante"  2.langn_r "Cooficial" 3.langn_r "Extranjera" ///
   							escs "Índice ESCS"  2.immig "Segunda generación" 3.immig "Tercera generación"  ///
   							2.gender "Hombre"  1.scchange "Cambio de centro" 1.langtest_coof "Cooficial" ///
   							age "Edad"  1.repeat "Repetir curso"  ///
   							1.schltype "Concertado" schsize "Alumnos centro" clsize "Tamaño clase" lead "Liderazgo" stratio "Ratio estudiantes profesor" ///
   							sch_escs "ESCS centro" sch_immig "% inmigrantes centro" sch_langn "% lengua cooficial centro")  ///
   							stats(F_mi df_avg_mi M_mi N, fmt(%9.2f %9.2f %9.0g %9.0g) labels(F "Grados de libertad" "Imputaciones" "Observaciones")) ///
    						varwidth(35) nobaselevels replace legend label collabels(none) float 

		// MODELOS CATALUÑA

		  		esttab pvmath_CAT_langn pvmath_CAT_escs pvmath_CAT_all using outputs\CAT_pvmath.tex, $tablas title("CATALUÑA - Matemáticas") 
				esttab pvread_CAT_langn pvread_CAT_escs pvread_CAT_all using outputs\CAT_pvread.tex, $tablas title("CATALUÑA - Lectura") 
    			esttab pvscie_CAT_langn pvscie_CAT_escs pvscie_CAT_all using outputs\CAT_pvscie.tex, $tablas title("CATALUÑA - Ciencia")

  		// MODELOS BALEARES

    		    esttab pvmath_BAL_langn pvmath_BAL_escs pvmath_BAL_all using outputs\BAL_pvmath.tex, $tablas title("BALEARES - Matemáticas") 
				esttab pvread_BAL_langn pvread_BAL_escs pvread_BAL_all using outputs\BAL_pvread.tex, $tablas title("BALEARES - Lectura") 
    			esttab pvscie_BAL_langn pvscie_BAL_escs pvscie_BAL_all using outputs\BAL_pvscie.tex, $tablas title("BALEARES - Ciencia") 

    	// MODELOS VALENCIA

    			esttab pvmath_VAL_langn pvmath_VAL_escs pvmath_VAL_all using outputs\VAL_pvmath.tex, $tablas title("VALENCIA - Matemáticas") 
				esttab pvread_VAL_langn pvread_VAL_escs pvread_VAL_all using outputs\VAL_pvread.tex, $tablas title("VALENCIA - Lectura") 
    			esttab pvscie_VAL_langn pvscie_VAL_escs pvscie_VAL_all using outputs\VAL_pvscie.tex, $tablas title("VALENCIA - Ciencia") 


    	// MODELOS GALICIA

    			esttab pvmath_GAL_langn pvmath_GAL_escs pvmath_GAL_all using outputs\GAL_pvmath.tex, $tablas title("GALICIA - Matemáticas") 
				esttab pvread_GAL_langn pvread_GAL_escs pvread_GAL_all using outputs\GAL_pvread.tex, $tablas title("GALICIA - Lectura") 
    			esttab pvscie_GAL_langn pvscie_GAL_escs pvscie_GAL_all using outputs\GAL_pvscie.tex, $tablas title("GALICIA - Ciencia") 

    	// MODELOS NAVARRA
				
				esttab pvmath_NAV_langn pvmath_NAV_escs pvmath_NAV_all using outputs\NAV_pvmath.tex, $tablas title("NAVARRA - Matemáticas")
				esttab pvread_NAV_langn pvread_NAV_escs pvread_NAV_all using outputs\NAV_pvread.tex, $tablas title("NAVARRA - Lectura")
    			esttab pvscie_NAV_langn pvscie_NAV_escs pvscie_NAV_all using outputs\NAV_pvscie.tex, $tablas title("NAVARRA - Ciencia")

        // MODELOS PAIS VASCO
				
				esttab pvmath_PV_langn pvmath_PV_escs pvmath_PV_all using outputs\PV_pvmath.tex, $tablas title("PAÍS VASCO - Matemáticas")
				esttab pvread_PV_langn pvread_PV_escs pvread_PV_all using outputs\PV_pvread.tex, $tablas title("PAÍS VASCO - Lectura")
    			esttab pvscie_PV_langn pvscie_PV_escs pvscie_PV_all using outputs\PV_pvscie.tex, $tablas title("PAÍS VASCO - Ciencia")

    	label define lang 1 "Español" 2"Cooficial" 3"Extranjera", replace		
    	label value langn_r lang

         coefplot (pvmath_CAT_langn, label(CAT)) (pvmath_PV_langn, label(PV)) (pvmath_NAV_langn, label(NAV)) ///
          (pvmath_VAL_langn, label(VAL)) (pvmath_GAL_langn, label(GAL)) (pvmath_BAL_langn, label(BAL)), bylabel(Modelo básico) ///
       || (pvmath_CAT_escs) (pvmath_PV_escs) (pvmath_NAV_escs) ///
          (pvmath_VAL_escs) (pvmath_GAL_escs) (pvmath_BAL_escs), bylabel(Control ESCS)  ///
       || (pvmath_CAT_all) (pvmath_PV_all) (pvmath_NAV_all) ///
          (pvmath_VAL_all) (pvmath_GAL_all) (pvmath_BAL_all), bylabel(Controles) ///
       ||, keep(2.langn_r 3.langn_r) xline(0) byopts( row(1) graphregion(color(white))) legend(rows(1)) xscale(range(-100 50)) ///
        name(coefplot_maths, replace)  
      graph export "E:\Rproj\BilingPISA\outputs\coefplot_maths.png", as(png) replace
      graph export "E:\Rproj\BilingPISA\outputs\coefplot_maths.eps", as(eps) replace 

         
         coefplot (pvread_CAT_langn, label(CAT)) (pvread_PV_langn, label(PV)) (pvread_NAV_langn, label(NAV)) ///
          (pvread_VAL_langn, label(VAL)) (pvread_GAL_langn, label(GAL)) (pvread_BAL_langn, label(BAL)), bylabel(Modelo básico) ///
       || (pvread_CAT_escs) (pvread_PV_escs) (pvread_NAV_escs) ///
          (pvread_VAL_escs) (pvread_GAL_escs) (pvread_BAL_escs), bylabel(Control ESCS)  ///
       || (pvread_CAT_all) (pvread_PV_all) (pvread_NAV_all) ///
          (pvread_VAL_all) (pvread_GAL_all) (pvread_BAL_all), bylabel(Controles) ///
       ||, keep(2.langn_r 3.langn_r) xline(0) byopts( row(1) graphregion(color(white))) legend(rows(1)) xscale(range(-100 50)) name(coefplot_read, replace)
       graph export "E:\Rproj\BilingPISA\outputs\coefplot_read.png", as(png) replace 
       graph export "E:\Rproj\BilingPISA\outputs\coefplot_read.eps", as(eps) replace 




        coefplot (pvscie_CAT_langn, label(CAT)) (pvscie_PV_langn, label(PV)) (pvscie_NAV_langn, label(NAV)) ///
          (pvscie_VAL_langn, label(VAL)) (pvscie_GAL_langn, label(GAL)) (pvscie_BAL_langn, label(BAL)), bylabel(Modelo básico) ///
       || (pvscie_CAT_escs) (pvscie_PV_escs) (pvscie_NAV_escs) ///
          (pvscie_VAL_escs) (pvscie_GAL_escs) (pvscie_BAL_escs), bylabel(Control ESCS)  ///
       || (pvscie_CAT_all) (pvscie_PV_all) (pvscie_NAV_all) ///
          (pvscie_VAL_all) (pvscie_GAL_all) (pvscie_BAL_all), bylabel(Controles) ///
       ||, keep(2.langn_r 3.langn_r) xline(0) byopts( row(1) graphregion(color(white))) legend(rows(1)) xscale(range(-100 50)) name(coefplot_science, replace)
       graph export "E:\Rproj\BilingPISA\outputs\coefplot_science.png", as(png) replace 
       graph export "E:\Rproj\BilingPISA\outputs\coefplot_science.eps", as(eps) replace 

    preserve   
    mi convert flong, clear
	misum pvmath pvread pvscie langn_r escs immig gender scchange age repeat langtest_coof ///
										 schltype schsize lead stratio clsize  ///
										 sch_escs sch_immi sch_langn  [iweight = w_fstuwt], m(10)
	restore
