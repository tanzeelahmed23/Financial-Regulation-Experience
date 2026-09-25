-- !preview conn=DBI::dbConnect(RSQLite::SQLite())

---Select the first 10,000 records from the security movement files

SELECT * FROM wire_mvmt
WHERE case_no='case_no' AND firm_id='firm_id' LIMIT 10000;


--Make a note on how many account numbers that are in this blotter that aren't in the
--account profile. Consider the Account Profile the master file with the account number as
--the primary key that links these tables together so we can match transactions vs 
--customer profiles to flag transactions that don't adhere to investor suitability requirements

SELECT COUNT(standardized_net_purchase_sales.account) AS missing_count
FROM wire_mvmt t2
LEFT JOIN account_profile t1 ON t2.account = t1.Account_No
WHERE t1.field_name IS NULL;

--Make a note on how many representative identifiers that are in this blotter that aren't in the
--requested registered representative supplement. Consider this supplement the master file with the account number as
--the primary key that links these tables together so we can match transactions vs 
--their assigned registered representatives as a way to flag transactions that are not consistent
--with FINRA Know-Your_Client regulations, potential money laundering violations, or verify
--whether there are prohibited activities such as churning, excessive trading, excessive cancel/rebills


SELECT COUNT(wire_mvmt.rep_id) AS missing_rep
FROM wire_mvmt t2
LEFT JOIN reg_rep_supp t1 ON t2.account = t1.Account_No
WHERE t1.field_name IS NULL;

--Make sure the action type in this asset movement file matches standardized files

SELECT file_name, header_group, 
COUNT(CASE WHEN Action NOT IN ('Sent','Received','Not Provided') THEN 1 ELSE 0 END ) 
AS num_wrong_action_type FROM wire_mvmt WHERE case_no='case_no' AND firm_id='firm_id';

--The Action subtype must also match the proper standard values because the extracted
--and normalized data will be further split into four separate reports downstream
--when we send our structured, standardized data to the data-mart for our business stakeholders

SELECT file_name, header_group, 
COUNT(CASE WHEN Subtype NOT IN ('Wire','Check','Debit','Cash','ACH') THEN 1 ELSE 0 END ) 
AS num_wrong_action_type FROM wire_mvmt WHERE case_no='case_no' AND firm_id='firm_id';

--Make sure, if the money movement is in the form of checks that the necessary data
--for checks (i.e. who's writing the check, and the clearance date of the check)

SELECT file_name, header_group, 
COUNT (CASE WHEN payor_payee NOT IN ('Payor','Payee') THEN 1 ELSE 0 END) AS num_null_payor_payee
COUNT (CASE WHEN chk_clr_dt IS NULL THEN 1 ELSE 0 END) AS num_null_chk_clr_dt
FROM wire_mvmt WHERE case_no='case_no' AND firm_id='firm_id' AND Subtype in('Check');


--Compare firm provided values vs standard values as an additonal sanity check

SELECT DISTINCT file_name, header_group, Tran_Type, Action
FROM wire_mvmt WHERE case_no='case_no' AND firm_id='firm_id' LIMIT 10000;

--The Country Code should default to 'N/A' if we were not provided this information
--The Country Codes must also pass ISO-3166 Alpha-3 Country Codes

SELECT (CASE WHEN Bank_Country NOT IN
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
FROM wire_mvmt WHERE case_no='case_no' AND firm_id='firm_id';


--Make sure Critical values required by the business match default values, no nulls allowed.

SELECT COUNT (CASE WHEN Currency IS NULL AND Currency NOT IN ('N/A') THEN 1 ELSE 0 END) AS num_wrong_null_currencies),
       COUNT (CASE WHEN Wire_Date IS NULL THEN 1 ELSE 0 END) AS num_null_w,ire_Date,
       COUNT (CASE WHEN Scr_Date IS NULL THEN 1 ELSE 0 END) AS num_null_src_wire_Date,
       COUNT (CASE WHEN Account_No IS NULL THEN 1 ELSE 0 END) AS num_null_acct,
       COUNT (CASE WHEN Bank_Name IS NULL THEN 1 ELSE 0 END) AS num_null_bank_name,
       COUNT (CASE WHEN ABA IS NULL THEN 1 ELSE 0 END) AS num_null_aba,
       COUNT (CASE WHEN Amt IS NULL THEN 1 ELSE 0 END) AS num_null_amt,
       COUNT (CASE WHEN Src_Amt IS NULL THEN 1 ELSE 0 END) AS num_null_src_amt,
       COUNT (CASE WHEN Third_Party IS NULL THEN 1 ELSE 0 END) as num_null_third_pty,
       COUNT (CASE WHEN Tran_Type IS NULL THEN 1 ELSE 0 END) as num_null_trans,
       COUNT (CASE WHEN Source_Account_No IS NULL THEN 1 ELSE 0 END) as num_null_scr_acct,
       COUNT (CASE WHEN Customer_Name IS NULL THEN 1 ELSE 0 END) as num_null_cust_nm
FROM wire_mvmt WHERE case_no='case_no' AND firm_id='firm_id';


--Check for other null values, they may not be showstoppers for stakeholders
--But we should still make note of it in case stakeholders want to do a deeper dive.

SELECT COUNT(CASE WHEN Source_Account_No IS NULL THEN 1 ELSE 0 END) AS num_null_source_acct,
       COUNT(CASE WHEN Amt IS NULL THEN 1 ELSE 0 END) AS num_null_amt
FROM wire_mvmt WHERE case_no='case_no' AND firm_id='firm_id';

--Sanity check to make sure any information regarding the counter party of journal Tran_Types
--Matches expectations based on raw data validation upon the extraction phase of ETL

SELECT 
DISTINCT (file_name, header_group, Counterparty, Counterparty_Acct,Bank_Country,Bank_Name,ABA)
FROM wire_mvmt WHERE case_no='case_no' AND firm_id='firm_id' LIMIT 10000;




--use this clause for every new query you're writing to make sure you're querying
--from the right table

--FROM wire_mvmt WHERE case_no='case_no' AND firm_id='firm_id'


