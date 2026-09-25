-- !preview conn=DBI::dbConnect(RSQLite::SQLite())

---Select the first 10,000 records from the security movement files

SELECT * FROM sec_mvmt
WHERE case_no='case_no' AND firm_id='firm_id' LIMIT 10000;


--Make a note on how many account numbers that are in this blotter that aren't in the
--account profile. Consider the Account Profile the master file with the account number as
--the primary key that links these tables together so we can match transactions vs 
--customer profiles to flag transactions that don't adhere to investor suitability requirements

SELECT COUNT(sec_mvmt.account) AS missing_count
FROM sec_mvmt t2
LEFT JOIN account_profile t1 ON t2.account = t1.Account_No
WHERE t1.field_name IS NULL;

--Make a note on how many representative identifiers that are in this blotter that aren't in the
--requested registered representative supplement. Consider this supplement the master file with the account number as
--the primary key that links these tables together so we can match transactions vs 
--their assigned registered representatives as a way to flag transactions that are not consistent
--with FINRA Know-Your_Client regulations, potential money laundering violations, or verify
--whether there are prohibited activities such as churning, excessive trading, excessive cancel/rebills


SELECT COUNT(sec_mvmt.rep_id) AS missing_rep
FROM sec_mvmt t2
LEFT JOIN reg_rep_supp t1 ON t2.account = t1.Account_No
WHERE t1.field_name IS NULL;


--Make sure the action type in this asset movement file matches standardized files

SELECT file_name, header_group, COUNT(CASE WHEN Action NOT IN ('Sent','Received','Not Provided') THEN 1 ELSE 0 END ) 
AS num_wrong_action_type FROM sec_mvmt 
WHERE case_no='case_no' AND firm_id='firm_id'
GROUP BY file_name, header_group;

--Compare firm provided values vs standard values as an additonal sanity check

SELECT DISTINCT file_name, header_group, Tran_Type, Action
FROM sec_mvmt WHERE case_no='case_no' AND firm_id='firm_id' LIMIT 10000;

--Make sure Critical values required by the business match default values, no nulls allowed.

SELECT COUNT(CASE WHEN Counterparty IS NULL THEN 1 ELSE 0 END) AS num_null_counteryparty,
      COUNT(CASE WHEN Counterparty_Acct IS NULL THEN 1 ELSE 0 END) AS num_null_counterparty_acct,
      COUNT (CASE WHEN Currency IS NULL AND Currency NOT IN ('N/A') THEN 1 ELSE 0 END) AS num_wrong_null_currencies),
      COUNT (CASE WHEN Sec_Date IS NULL THEN 1 ELSE 0 END) AS num_null_Sec_Date,
      COUNT (CASE WHEN Scr_Date IS NULL THEN 1 ELSE 0 END) AS num_null_src_Sec_Date,
      COUNT (CASE WHEN Account_No IS NULL THEN 1 ELSE 0 END) AS num_null_acct
FROM sec_mvmt WHERE case_no='case_no' AND firm_id='firm_id';


--Check for other null values, they may not be showstoppers for stakeholders
--But we should still make note of it in case stakeholders want to do a deeper dive.

SELECT COUNT(CASE WHEN Cusip IS NULL THEN 1 ELSE 0 END) AS num_null_cusip,
       COUNT(CASE WHEN Security_ID IS NULL THEN 1 ELSE 0 END) AS num_null_security_id,
       COUNT(CASE WHEN Source_Account_No IS NULL THEN 1 ELSE 0 END) AS num_null_source_acct,
       COUNT(CASE WHEN Description IS NULL THEN 1 ELSE 0 END) AS num_null_description,
       COUNT(CASE WHEN Ticker_Symbol IS NULL THEN 1 ELSE 0 END) AS num_null_symbol,
       COUNT(CASE WHEN Qty IS NULL THEN 1 ELSE 0 END) AS num_null_qty,
       COUNT(CASE WHEN Amt IS NULL THEN 1 ELSE 0 END) AS num_null_amt
FROM sec_mvmt WHERE case_no='case_no' AND firm_id='firm_id';

--Sanity check to make sure any information regarding the counter party of journal transactions
--Matches expectations based on raw data validation upon the extraction phase of ETL

SELECT DISTINCT (Counterparty, Counterparty_Acct)
FROM sec_mvmt WHERE case_no='case_no' AND firm_id='firm_id' LIMIT 10000;


--Check for corrupted security identifiers. They're supposed to be alphanumeric
--But often times we got corrupted files where identifiers that had the letter
--"E" would cause an alpha-numeric character to be in scientific notation
--Accounting for Special Characters that aren't escape characters in SQL language

SELECT (CASE WHEN Security_ID like '%!%' THEN 1 ELSE 0)+
      (CASE WHEN Security_ID like '%@%' THEN 1 ELSE 0)+
      (CASE WHEN Security_ID like '%#%' THEN 1 ELSE 0)+
      (CASE WHEN Security_ID like '%$%' THEN 1 ELSE 0)+
      (CASE WHEN Security_ID like '%^%' THEN 1 ELSE 0)+
      (CASE WHEN Security_ID like '%&%' THEN 1 ELSE 0)+
      (CASE WHEN Security_ID like '%*%' THEN 1 ELSE 0)+
      (CASE WHEN Security_ID like '%(%' THEN 1 ELSE 0)+
      (CASE WHEN Security_ID like '%)%' THEN 1 ELSE 0)+
      (CASE WHEN Security_ID like '%-%' THEN 1 ELSE 0)+
      (CASE WHEN Security_ID like '%+%' THEN 1 ELSE 0)+
      (CASE WHEN Security_ID like '%%%' THEN 1 ELSE 0)+
      (CASE WHEN Security_ID like '%~%' THEN 1 ELSE 0)+
      (CASE WHEN Security_ID like '%~%' THEN 1 ELSE 0)+
      (CASE WHEN Security_ID like '%~%' THEN 1 ELSE 0)+
      (CASE WHEN Security_ID like '%~%' THEN 1 ELSE 0)+
      (CASE WHEN Security_ID like '%{%' THEN 1 ELSE 0)+
      (CASE WHEN Security_ID like '%}%' THEN 1 ELSE 0)+
      (CASE WHEN Security_ID like '%[%' THEN 1 ELSE 0)+
      (CASE WHEN Security_ID like '%]%' THEN 1 ELSE 0)+
      (CASE WHEN Security_ID like '%|%' THEN 1 ELSE 0)+
      (CASE WHEN Security_ID like '%|%' THEN 1 ELSE 0)+
      (CASE WHEN Security_ID like '%:%' THEN 1 ELSE 0)+
      (CASE WHEN Security_ID like '%;%' THEN 1 ELSE 0)+
      (CASE WHEN Security_ID like '%"%' THEN 1 ELSE 0)+
      (CASE WHEN Security_ID like '%'%' THEN 1 ELSE 0)+
      (CASE WHEN Security_ID like '%<%' THEN 1 ELSE 0)+
      (CASE WHEN Security_ID like '%>%' THEN 1 ELSE 0)+
      (CASE WHEN Security_ID like '%,%' THEN 1 ELSE 0)+
      (CASE WHEN Security_ID like '%.%' THEN 1 ELSE 0)+
      (CASE WHEN Security_ID like '%=%' THEN 1 ELSE 0) AS num_corrupted_sec_id
FROM sec_mvmt
WHERE case_no='case_no' AND firm_id='firm_id';


--use this clause for every new query you're writing to make sure you're querying
--from the right table

--FROM sec_mvmt WHERE case_no='case_no' AND firm_id='firm_id'


