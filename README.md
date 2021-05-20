# Chronic-Conditions-Package
The purpose of the Chronic Conditions Package is to analyze claims data and flag the presence of chronic conditions based on user-defined criteria. There are three main criteria for identifying chronic conditions in the claims data: qualifying diagnosis codes, location of diagnosis codes (e.g. inpatient, outpatient, skilled nursing facility, etc.), and the reference period in which to find the diagnoses (e.g. 2 years, 3 years). The final outputs will be yearly beneficiary level files with monthly condition and enrollment flags.
The package can also be applied to any other source of data where diagnosis and procedure information on patients during the analysis period is complete.

### V0 Notes
In V0, the log will finish with an error with the following reference: “49: LINE and COLUMN cannot be determined.” However this does not prevent the package from running correctly. Check future versions for cleaner versions of the log, updates to efficiency, and updates to coding definitions.

### Citation
If you use the package in your work, we ask that you cite the following article which also has more detailed information on how the package works:
https://communities.sas.com/t5/SAS-Global-Forum-Proceedings/How-Sick-Is-My-Cohort-Of-Patients-A-General-Approach-to-Identify/ta-p/726311

### Contact Information
Patricia Ferido  
pferido@healthpolicy.usc.edu
