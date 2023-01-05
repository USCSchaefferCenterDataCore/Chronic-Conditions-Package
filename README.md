# Chronic-Conditions-Package
The purpose of the Chronic Conditions Package is to analyze claims data and flag the presence of chronic conditions based on user-defined criteria. There are three main criteria for identifying chronic conditions in the claims data: qualifying diagnosis codes, location of diagnosis codes (e.g. inpatient, outpatient, skilled nursing facility, etc.), and the reference period in which to find the diagnoses (e.g. 2 years, 3 years). The final outputs will be yearly beneficiary level files with monthly condition and enrollment flags.
The package can be applied to any data source of with complete diagnosis and procedure information on patients during the analysis period.

### Notes
In 27v0, 27v1 and 30v0, the log will finish with an error referencing the following note: “49: LINE and COLUMN cannot be determined.” However this does not prevent the package from running correctly. Check future versions for cleaner versions of the log, updates to efficiency, and updates to coding definitions.

### Versions
<li> <strong>27v0</strong> - Definitions of the 27 chronic conditions as published by CCW on Aug 2017 </li>
<li> <strong>27v1</strong> - Definitions of the 27 chronic conditions as published by CCW on Feb 2022 </li>
<li> <strong>30v0</strong> - Definitions of the 30 chronic conditions as published by CCW on Feb 2022, only applies to ICD-10 period </li>

### Citation
If you use the package in your work, we ask that you cite the article which presents the package and shares examples on how to use it:
Ferido, P., Gascue, L.,  St. Clair, P. “How Sick Is My Cohort Of Patients? A General Approach To Identify Chronic Conditions”. 1063-2021 SAS Global Forum 2021.
https://communities.sas.com/t5/SAS-Global-Forum-Proceedings/How-Sick-Is-My-Cohort-Of-Patients-A-General-Approach-to-Identify/ta-p/726311

### Contact Information
Patricia Ferido  
pferido@usc.edu
