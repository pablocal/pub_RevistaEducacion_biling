capture log close
log using "logs\0. Prepare data.smcl", replace
******************************************************
****** BilingDia - ML model from PISA 15 **************
*******************************************************
//*// Syntax 0: Data preparation 

// 0. Set-up
clear all
cd "E:\Rproj\BilingPISA"
version 15

// 1. Get data
use "data\student1_2015_ESP.dta", clear
merge 1:1 CNTSTUID using "data\student2_2015_ESP.dta"
drop _merge
merge 1:1 CNTSTUID using "data\student3_2015_ESP.dta"
drop _merge
merge 1:1 CNTSTUID using "data\student4_2015_ESP.dta"
drop _merge
merge m:1 CNTSCHID using "data\school_2015_ESP.dta"
drop _merge

rename * , lower //all vars to lower

// 2. Select sample (only those in 3rd year of secondary and exclude private schools)
// restrict analysis to regions with coofficial language
*fre st001d01t
*keep if st001d01t == 10
*fre st001d01t

fre region
keep if region != 72400
fre region

fre schltype
keep if schltype!= 1

*fre region
*keep if inlist(region, 72409, 72416, 72415, 72404, 72411, 72417)


// 3. Prepare variables

 ** 3.3 Independent vars at school level (school)

  		**leadership (school)
  			sum lead
  			mvdecode lead, mv(99)
  			sum lead

  		**school type (school)
  			fre schltype
        recode schltype (2=1 "Concertada") (3=0 "Public") (nonmiss = .), gen(schltype_r)
        drop schltype
        rename schltype_r schltype

  		**student teacher ratio (school)
  			sum stratio
  			mvdecode stratio, mv(999)
  			sum stratio

  		**school size (school)
  			sum schsize
  			replace schsize = . if schsize > 50000

  		**school autonomy (shcool)
  			sum schaut
  			mvdecode schaut, mv(999)
  			recode schaut (0/.249 = 1) (.25/.499 = 2) (.5/.7499 = 3) (.75/1 = 4) , gen(schaut4)
  			ta schaut schaut4
  			sum schaut

 ** 3.4 Independent vars at individual level (student)

		**gender (student)
			fre st004d01t
			rename st004d01t gender

		**immigation status (student)
         	fre immig
         	mvdecode immig, mv(9)

   	**socio-cultural status (student HH)
   		sum escs
   		hist(escs)

    **cambio escuela
      fre scchange
      recode scchange (0=0) (9 = .) (nonmis = 1) 

    **language at home 
       fre langn 
       recode langn (156 = 1 "Spanish") (852=3 "Foreign") (nonmiss = 2 "Coofficial") , gen(langn_r)

    **repeat 
      fre repeat
      mvdecode repeat, mv(9) 

    **edad
      fre age

   
    **language of test (student)
 	    	fre langtest_cog 
        recode langtest_cog (156 = 0) (nonmiss = 1) , gen(langtest_coof)
        ta langtest_coof langtest_cog
    

   
// 4. Save final file
keep cntstuid cntschid region gender immig escs minsL minsM minsS hrsL_out hrsM_out hrsS_out lead schsize schaut4 schltype scchange clsize ///
 stratio pv1math-pv10math pv1read-pv10read pv1scie-pv10scie langtest_coof w_fstu* w_schgrnrabwt stratum langn_r ///
 age repeat
save "data\ML_analysis.dta", replace
log close

