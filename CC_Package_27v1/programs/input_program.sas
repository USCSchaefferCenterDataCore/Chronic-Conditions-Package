/*********************************************************************************************/
TITLE1 'Chronic Conditions Macro';

* AUTHOR: Patricia Ferido;

* DATE: 3/26/2018;

* PURPOSE: Run all programs related to Chronic Conditions Package;

options compress=yes nocenter ls=150 ps=200 errors=5 errorabend errorcheck=strict mprint merror
	mergenoby=warn varlenchk=error dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

****** Set up libnames - optional;

/********************************************************************************************************************
 Macro Variables -  Information needed for macro below;
* PROJHOME: project filepath to the Chronic_Conditions_Package folder;
* ID: Name of unique patient ID variable in claims data;
* MINYEAR First year of data that you want to process;
* MAXYEAR: Last year of data that you want to process;
* CLAIMS_DATA: Name of the cleaned claims data sets you want to process. If multiple, separate by a space;
* CREATE_ENR: Y/N - Y if enrollment files need to be created, N - if they already exist;
	* If Y, then define the following variables:;
		* CREATE_ENR_SHAPE: two possible inputs: A - annual files with monthly entries, P - single period file with beneficiary
		  entries per each unique period of continous enrollment (P). Note that multipe entries per beneficiary are allowed in P;
		* CREATE_ENR_FILEIN: provide input files of beneficiary enrollment information with libref;
		* ENR_PREFIX: name of the enrollment files you want to create with libref, yearly suffix will be added automatically;
		* ENR_VAR: name of enrollment variable you want to use (e.g. MA, FFS, enr), monthly suffix will be added automatically;
	* If N, then define the following variables:;
		* CREATE_ENR_SHAPE: leave blank;
		* CREATE_ENR_FILEIN: leave blank;
		* ENR_PREFIX: name of enrollment files with libref and without yearly suffix;
		* ENR_VAR: prefix of monthly enrollment variable in provided enrollment files;
* CLAIMS_OUT_PREFIX: Prefix for yearly output data sets, suffix will automatically be year. Don't forget to include libref if creating permanent;
* CUSTOM_ALGORITHM: Y/N - Y if input excel sheets have been modified and should be used, N if default chronic conditions should be used. Default is N;
* CUSTOM_SUFFIX: If Y is specified above, then this suffix will be added to specify your custom algorithms. Default is _custom;
* CUSTOM_COND: List of shorthand conditions to identify, default if left blank is all 27 original CCW conditions;
*******************************************************************************************************************/

****** Wrapper macro;
%include "idcond.sas";

****** Macro Function;
%idcond(projhome=,
				id=,
				minyear=,
				maxyear=,
				claims_data=,
				create_enr=,
				create_enr_shape=,
				create_enr_filein=,
				enr_prefix=,
				enr_var=,
				claims_out_prefix=,
				custom_algorithm=,
				custom_suffix=,
				custom_cond=);


****** Example;
/*%idcond(projhome=/disk/agedisk3/medicare.work/goldman-DUA51866/ferido-dua51866/CCW package/Chronic_Conditions_Package_5pct/,
					id=bene_id,
					minyear=2004,
					minyear=2016,
					claims_data=_ccproj.claims_test2002 _ccproj.claims_test2003 _ccproj.claims_test2004 _ccproj.claims_test2005 _ccproj.claims_test2006 _ccproj.claims_test2007 _ccproj.claims_test2008 _ccproj.claims_test2009 _ccproj.claims_test2010 _ccproj.claims_test2011 _ccproj.claims_test2012 _ccproj.claims_test2013 
					_ccproj.claims_test2014 _ccproj.claims_test2015 _ccproj.claims_test2016,
					create_enr=N,
					create_enr_shape=,
					create_enr_filein=,
					enr_prefix=enr.enrffs_,
					enr_var=ffsab,
					claims_out_prefix=_ccproj.chronic_conditions_,
					custom_algorithm=Y,
					custom_suffix=_T2DIAB,
					cond=T2DIAB); */

