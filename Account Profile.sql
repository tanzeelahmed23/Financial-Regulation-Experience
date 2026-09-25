-- !preview conn=DBI::dbConnect(RSQLite::SQLite())

--These are the queries I wrote to standardize client Account_No blotters
--not the real name of the file, all variables are changed to protect
--confidential information


--Confirm that the correct amount of records were extracted and transformed as
--the raw data file.

SELECT * FROM account_profile
WHERE case_no='case_no' AND firm_id='firm_id'
LIMIT 10000;

--Make a note on how many representative identifiers that are in this blotter that aren't in the
--requested registered representative supplement. Consider this supplement the master file with the account number as
--the primary key that links these tables together so we can match transactions vs 
--their assigned registered representatives as a way to flag transactions that are not consistent
--with FINRA Know-Your_Client regulations, potential money laundering violations, or verify
--whether there are prohibited activities such as churning, excessive trading, excessive cancel/rebills


SELECT COUNT(account_profile.rep_id) AS missing_rep
FROM account_profile t2
LEFT JOIN reg_rep_supp t1 ON t2.account = t1.Account_No
WHERE t1.field_name IS NULL;



--Confirm that no client Account_No numbers are null because it is the primary key
--and will cause a system error for downstream data-mart systems

SELECT COUNT(*) FROM account_profile
WHERE case_no='case_no' AND firm_id='firm_id'
AND Account_No IS NULL;

--Count Duplicate Accounts and how many iterations of those Account_No Numbers
--are present in a file where there is more than 1 Account_No Number.
--This is to preserve the requirements of 1:1 for the Account_No Field with all necessary
--information that will eventually be joined with other extracted files.
--I make note of files with duplicate accounts so we
--can provide transformation logic to properly de-duplicate rows based on Account_No
--information while retaining the most pertinent data for business stakeholders

SELECT Account_No, COUNT(*) AS total_count
FROM account_profile
GROUP BY Account_No HAVING COUNT(*) > 1;

--Count if there are any null representative identifiers so examiners
--can properly attribute activity to the corresponding representative.

SELECT COUNT(*)
FROM account_profile
WHERE case_no='case_no' AND firm_id='firm_id' AND Rep_ID IS NULL;

--Verify that input provided fields fit the standard values necessary
SELECT 
  COUNT (CASE WHEN Customer_Firm NOT IN('Customer','Firm') THEN 1 ELSE 0 END) AS num_wrong_cust_firm,
  COUNT (CASE WHEN Account_Purpose NOT IN('Customer Account_No','Firm Account_No') THEN 1 ELSE 0 END) AS num_account_purpose,
  COUNT (CASE WHEN Account_Source NOT IN('Customer Account_No','Firm Account_No') THEN 1 ELSE 0 END) AS num_account_source,
  COUNT (CASE WHEN Margin NOT IN('Cash','Margin','Not Provided') THEN 1 ELSE 0 END) AS num_wrong_cash_margin_ind,
  COUNT (CASE WHEN Discretionary_Classification NOT IN ('Limited','None','Full','POA') THEN 1 ELSE 0 END) AS num_wrong_discretionary_classification,
  COUNT (CASE WHEN Disecrtionary NOT IN ('Y','N','Not Provided') THEN 1 ELSE 0 END) AS num_wrong_discretionary,
  COUNT (CASE WHEN High_Risk NOT IN ('Y','N') THEN 1 ELSE 0 END) AS num_wrong_high_risk,
  COUNT (CASE WHEN PO_BOX NOT in ('Yes','No') THEN 1 ELSE 0 END) AS num_wrong_po_box,
  COUNT (CASE WHEN Employee NOT IN ('Y','N','Not Provided') THEN 1 ELSE 0 END) as num_wrong_employee,
  COUNT (CASE WHEN Income_Classification NOT IN('LESSTHAN50K - Less than or equal to $50K',
                                                  '50K-100K - Over $50K and less than or equal to $100K',
                                                  '100K-500K - Over  $100K and less than or equal to $500K',
                                                  '500K-1M - Over $500K and less than or equal to $1M',
                                                  '1M+ - Over $1M','REFUSED - Refused','NOTREQUESTED - Not Requested') THEN 1 ELSE 0) 
    AS num_wrong_income_classification,
  COUNT (CASE WHEN Liq_NW_Classification NOT IN('LESSTHAN50K - Less than or equal to $50K',
                                                  '50K-100K - Over $50K and less than or equal to $100K',
                                                  '100K-500K - Over  $100K and less than or equal to $500K',
                                                  '500K-1M - Over $500K and less than or equal to $1M',
                                                  '1M+ - Over $1M','REFUSED - Refused','NOTREQUESTED - Not Requested') THEN 1 ELSE 0) 
    AS num_wrong_liq_nw_classification,
  COUNT (CASE WHEN Net_Worth_Classification NOT IN('LESSTHAN50K - Less than or equal to $50K',
                                                  '50K-100K - Over $50K and less than or equal to $100K',
                                                  '100K-500K - Over  $100K and less than or equal to $500K',
                                                  '500K-1M - Over $500K and less than or equal to $1M',
                                                  '1M+ - Over $1M','REFUSED - Refused','NOTREQUESTED - Not Requested','Not Provided') THEN 1 ELSE 0) 
    AS num_wrong_net_worth_classification,
    
  COUNT (CASE WHEN Inv_Horization_Classification NOT IN('SHORTTERM - Short - Less than 5 years',
                                                        'INTERMEDIATE - Intermediate - Between 6 and 10 years',
                                                        'LONGTERM - Long - Between 11 and 15 years',
                                                        'VERYLONG - Very Long - Over 15 years', 'NA - Not Provided','Not Provided') THEN 1 ELSE 0)
    AS num_wrong_investment_horizon_classification, 
    
  COUNT (CASE WHEN Inv_Classification NOT IN('INCOME - Income','CONSERVATIVE - Conservative','CAPAPPRCN - Capital Appreciation',
                                                        'SHORTTERM - Short Term Capital Growth', 'TRADING - Trading and Speculation', 
                                                        'NA - Not Provided','Not Provided') THEN 1 ELSE 0)
    AS num_wrong_inv_classification,

  COUNT (CASE WHEN Option_Code NOT IN('LEVEL1 = Level1 - Covered Calls','LEVEL2 =Level2 - Protective Puts',
                                      'LEVEL3 = Level3 - Buy Call and Puts','LEVEL4 =Level4 - Straddles',
                                      'LEVEL5 = Level5 - Uncovered/Naked', 'LEVEL6 = Level6 - All Options',
                                      'NA = Not Applicable','Not Provided') THEN 1 ELSE 0) AS num_wrong_option_type
FROM account_profile
WHERE case_no='case_no' AND firm_id='firm_id';

--Make sure firm provided inputs are properly transformed to standardized outputs
--Specify the distinct headers and file names to make it easier to drill down
--on where to make the appropriate data transformation corrections

---Let's first check with who has discretionary related fields and make sure all
---columns logically match with the standardized values for "Discretion"

SELECT distinct(file_name, header,Discretionary_Classification,Discretionary,Discretionary_Description)
FROM account_profile WHERE case_no='case_no' AND firm_id='firm_id';

---Let's check the same for investor suitability fields with standardized values

SELECT distinct(file_name, header,Liq_NW,Liq_NW_Classification)
FROM account_profile WHERE case_no='case_no' AND firm_id='firm_id';

SELECT distinct(file_name, header,Net_Worth,Net_Worth_Classification)
FROM account_profile WHERE case_no='case_no' AND firm_id='firm_id';

SELECT distinct(file_name, header,Income,Income_Classification)
FROM account_profile WHERE case_no='case_no' AND firm_id='firm_id';

SELECT distinct(file_name, header,Inv_Horizon_Firm,Inv_Horizon_Classification)
FROM account_profile WHERE case_no='case_no' AND firm_id='firm_id';

SELECT distinct(file_name, header,Inv_Code,Inv_Classification,Inv_Description)
FROM account_profile WHERE case_no='case_no' AND firm_id='firm_id';

SELECT distinct(file_name, header,Source_Option,Option_Code,Option_Description)
FROM account_profile WHERE case_no='case_no' AND firm_id='firm_id';

--Let's double check if anything was mapped to the wrong "else" value or
--default value to make sure all firm-provided fields are appropriately mapped
--to their corresponding standardized values without any discrepancies
--make sure the firm provided columns make sense to match the default 
--"not provided" values and make logical sense before this is sent out
--to examiners and investigators


SELECT distinct(file_name, header,Liq_NW,Liq_NW_Classification)
FROM account_profile WHERE case_no='case_no' AND firm_id='firm_id'
AND Lid_NW_Classification in('Not Requested','NOTREQUESTED - Not Requested');

SELECT distinct(file_name, header,Net_Worth,Net_Worth_Classification)
FROM account_profile WHERE case_no='case_no' AND firm_id='firm_id'
AND Lid_NW_Classification in('Not Requested','NOTREQUESTED - Not Requested');

SELECT distinct(file_name, header,Income,Income_Classification)
FROM account_profile WHERE case_no='case_no' AND firm_id='firm_id'
AND Lid_NW_Classification in('Not Requested','NOTREQUESTED - Not Requested');

SELECT distinct(file_name, header,Inv_Horizon,Inv_Horizon_Classification)
FROM account_profile WHERE case_no='case_no' AND firm_id='firm_id'
AND Lid_NW_Classification in('Not Requested','NOTREQUESTED - Not Requested');

SELECT distinct(file_name, header,Inv_Code, Inv_Description,Inv_Classification)
FROM account_profile WHERE case_no='case_no' AND firm_id='firm_id'
AND Lid_NW_Classification in('Not Requested','NOTREQUESTED - Not Requested');

SELECT distinct(file_name, header,Source_Option, Option_Code,Option_Description)
FROM account_profile WHERE case_no='case_no' AND firm_id='firm_id'
AND Lid_NW_Classification in('Not Requested','NOTREQUESTED - Not Requested');

--These fields should not be null, and should have default values to "Not Provided"
--if the firm didn't provide them because they are not critical fields.
--However, these fields can provide additional context for our stakeholders
--when they do their reviews

SELECT (CASE WHEN Email IS NULL THEN 1 ELSE 0 END) AS num_null_email,
        (CASE WHEN Phone IS NULL THEN 1 ELSE 0 END) AS num_null_phone,
        (CASE WHEN Account_Description IS NULL THEN 1 ELSE 0 END) AS num_acct_desc,
        (CASE WHEN Account_Type IS NULL THEN 1 ELSE 0 END) AS num_null_acct_type,
        (CASE WHEN Rep_ID IS NULL THEN 1 ELSE 0 END) AS num_rep_id,
        (CASE WHEN Risk_Description IS NULL THEN 1 ELSE 0 END) as num_null_risk_desc
FROM account_profile
WHERE case_no='case_no' AND firm_id='firm_id';   

--The Country Code should default to 'N/A' if we were not provided this information
--The Country Codes must also pass ISO-3166 Alpha-3 Country Codes

SELECT (CASE WHEN Country NOT IN
  ('AFG','ALB','DZA','ASM','AND','AGO','AIA','ATA','ATG','ARG','ARM','ABW','AUS','CUW',	
  'AUT','AZE','BHS','BHR','BGD','BRB','BLR','BEL','BLZ','BEN','BMU','BTN','BOL','BES',
  'BIH','BWA','BVT','BRA','IOT','BRN','BGR','BFA','BDI','CPV','KHM','CMR','CAN','CYM',
  'CAF','TCD','CHL','CHN','CXR','CCK','COL','COM','COD','COG','COK','CRI','HRV','CUB',
  'CYP','CZE','CIV','DNK','DJI','DMA','DOM','ECU','EGY','SLV','GNQ','ERI','EST','SWZ',
  'ETH','FLK','FRO','FJI','FIN','FRA','GUF','PYF','ATF','GAB','GMB','GEO','DEU','GHA',
  'GIB','GRC','GRL','GRD','GLP','GUM','GTM','GGY','GIN','GNB','GUY','HTI','HMD','VAT',
  'HND','HKG','HUN','ISL','IND','IDN','IRN','IRQ','IRL','IMN','ISR','ITA','JAM','JPN',
  'JEY','JOR','KAZ','KEN','KIR','PRK','KOR','KWT','KGZ','LAO','LVA','LBN','LSO','LBR',
  'LBY','LIE','LTU','LUX','MAC','MDG','MWI','MYS','MDV','MLI','MLT','MHL','MTQ','MRT',
  'MUS','MYT','MEX','FSM','MDA','MCO','MNG','MNE','MSR','MAR','MOZ','MMR','NAM','NPU',
  'NPL','NLD','NCL','NZL','NIC','NER','NGA','NIU','NFK','MKD','MNP','NOR','OMN','PAK',
  'PLW','PSE','PAN','PNG','PRY','PER','PHL','PCN','POL','PRT','PRI','QAT','ROU','RUS',
  'RWA','REU','BLM','SHN','KNA','LCA','MAF','SPM','VCT','WSM','SMR','STP','SAU','SEN',
  'SRB','SYC','SLE','SGP','SXM','SVK','SVN','SLB','SOM','ZAF','SGS','SSD','ESP','LKA',
  'SDN','SUR','SJM','SWE','CHE','SYR','TWN','TJK','TZA','THA','TLS','TGO','TKL','TON',
  'TTO','TUN','TKM','TCA','TUV','TUR','UGA','UKR','ARE','GBR','UMI','USA','URY','UZB',
  'VUT','VEN','VNM','VGB','VIR','WLF','ESH','YEM','ZMB','ZWE','ALA','N/A')
  THEN 1 ELSE 0) AS num_invalid_country  
FROM account_profile WHERE case_no='case_no' AND firm_id='firm_id';


SELECT DISTINCT (file_name, header,zip)
FROM account_profile WHERE case_no='case_no' AND firm_id='firm_id';

SELECT DISTINCT (file_name, header, Address)
FROM account_profile WHERE case_no='case_no' AND firm_id='firm_id';

--One Clearing firm lists missing phone numbers as '000 000 0000', we need
--to double check and make sure they are properly mapped as "Not Provided"
--so stakeholders know the firm didn't submit truly complete data

SELECT file_name, header, COUNT(*) AS num_zero_phone_to_transform
FROM account_profile
WHERE case_no='case_no' AND firm_id='firm_id' AND Phone='000 000 0000'
GROUP BY file_name, header;

--Check Account_No Open, Close, and Account_No Age Dates
--Do a Sanity Check to make sure the Account_No Ages properly match
--the firm provided open and close dates

SELECT DISTINCT (file_name, header, Opened,Closed,Acct_Age) FROM account_profile
WHERE case_no='case_no' AND firm_id='firm_id';

--Check when the Customer was born vs the derived Customer Age formulas
--Do a Sanity Check to make sure the Account_No Ages properly match
--the firm provided open and close dates

SELECT DISTINCT (file_name, header, Birth,Age) FROM account_profile
WHERE case_no='case_no' AND firm_id='firm_id';


--Sanity Check on all Address Related Fields, make sure all the components match up

SELECT DISTINCT (file_name, header, Address, State, Country, Zip)
FROM account_profile WHERE case_no='case_no' AND firm_id='firm_id';

--Drill down further for sanity checks on individual address components

SELECT DISTINCT file_name, header, Address
FROM account_profile WHERE case_no='case_no' AND firm_id='firm_id';

SELECT DISTINCT file_name, header, State
FROM account_profile WHERE case_no='case_no' AND firm_id='firm_id';

SELECT DISTINCT file_name, header, Country
FROM account_profile WHERE case_no='case_no' AND firm_id='firm_id';

SELECT DISTINCT file_name, header, Zip
FROM account_profile WHERE case_no='case_no' AND firm_id='firm_id';

--Make sure that anything flagged for having a PO BOx was properly flagged
--Based on the provided customer address with this additional sanity check

SELECT DISTINCT PO_BOX, Address, Zip, Country
FROM account_profile WHERE case_no='case_no' AND firm_id='firm_id'
AND PO_BOX in('Yes') LIMIT 10000;


--use this clause for every new query you're writing to make sure you're querying
--from the right table

--FROM account_profile
--WHERE case_no='case_no' AND firm_id='firm_id'


