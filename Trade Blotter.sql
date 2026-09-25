-- !preview conn=DBI::dbConnect(RSQLite::SQLite())

--These are the queries I wrote to standardize standard_net_purchase_files
--not the real name of the file, all variables are changed to protect
--confidential information

--Confirm that the correct amount of records were extracted and transformed as
--the raw data file.

SELECT * FROM std_trade_blttr
WHERE case_no='case_no' AND firm_id='firm_id'
LIMIT 10000;

--Confirm that no client account numbers are null because it is the primary key
--and will cause a system error for downstream data-mart systems

SELECT COUNT(*) FROM std_trade_blttr
WHERE case_no='case_no' AND firm_id='firm_id'
AND account IS NULL;


--Make a note on how many account numbers that are in this blotter that aren't in the
--account profile. Consider the Account Profile the master file with the account number as
--the primary key that links these tables together so we can match transactions vs 
--customer profiles to flag transactions that don't adhere to investor suitability requirements

SELECT COUNT(std_trade_blttr.account) AS missing_count
FROM std_trade_blttr t2
LEFT JOIN account_profile t1 ON t2.account = t1.Account_No
WHERE t1.field_name IS NULL;

--Make a note on how many representative identifiers that are in this blotter that aren't in the
--requested registered representative supplement. Consider this supplement the master file with the account number as
--the primary key that links these tables together so we can match transactions vs 
--their assigned registered representatives as a way to flag transactions that are not consistent
--with FINRA Know-Your_Client regulations, potential money laundering violations, or verify
--whether there are prohibited activities such as churning, excessive trading, excessive cancel/rebills


SELECT COUNT(std_trade_blttr.rep_id) AS missing_rep
FROM std_trade_blttr t2
LEFT JOIN reg_rep_supp t1 ON t2.account = t1.Account_No
WHERE t1.field_name IS NULL;

--Count if there are any null representative identifiers so examiners
--can properly attribute activity to the corresponding representative.

SELECT COUNT(*)
FROM std_trade_blttr
WHERE case_no='case_no' AND firm_id='firm_id' AND rep_id IS NULL;

--Verify that input provided actions matches the standard values for
--additonal output standardized columns for downstream data-mart.

SELECT DISTINCT Input_Action, Std_Action, Level_2_Std_Action
FROM std_trade_blttr
WHERE case_no='case_no' AND firm_id='firm_id';


--Verify that input provided fields fit the standard values necessary
SELECT 
  COUNT(CASE WHEN Std_Action NOT IN('Buy','Sell','Short Sale','Not Provided','Others')
    THEN 1 else 0 END) AS num_wrong_Std_Action,
  COUNT (CASE WHEN Solicit NOT IN('Solicited','UnSolicited','Not Provided')
    THEN 1 else 0 END) AS num_wrong_Solicit,
  COUNT (CASE WHEN Capacity NOT IN('Agency','Principal','Not Provided')
    THEN 1 else 0 END) AS num_wrong_Capacity,
  COUNT (CASE WHEN Level_2_Std_Action 
    NOT IN('Buy Open','Buy Close','Sell Open','Sell Close','Short Sale','Not Provided')
   THEN 1 else 0 END) AS num_wrong_Level_2_Std_Action,
  COUNT (CASE WHEN Capacity NOT IN('Agency','Principal','Not Provided')
    THEN 1 else 0 END) AS num_wrong_Capacity,
  COUNT (CASE WHEN Cancel NOT IN('Yes','No') THEN 1 else 0) AS num_wrong_cancel,
  COUNT (CASE WHEN Rebill NOT IN('Yes','No') THEN 1 else 0) AS num_wrong_rebill,
  COUNT (CASE WHEN Margin NOT IN('Cash','Margin','Not Provided') THEN 1 else 0) AS num_wrong_cash_margin_ind,
  COUNT (CASE WHEN Option_Type NOT IN('Call','Put','Not Provided') THEN 1 else 0) AS num_wrong_option_type
FROM std_trade_blttr
WHERE case_no='case_no' AND firm_id='firm_id';

--These fields should not be null, and should have default values to "Not Provided"
--if the firm didn't provide them because they are not critical fields.
--However, these fields can provide additional context for our stakeholders
--when they do their reviews

SELECT (CASE WHEN Asset IS NULL THEN 1 else 0 END) AS num_null_Assets,
        (CASE WHEN Subtype IS NULL THEN 1 else 0 END) AS num_null_Subtypes,
        (CASE WHEN Reporting IS NULL THEN 1 else 0 END) as num_null_reporting,
        (CASE WHEN Trade_ID IS NULL then 1 else 0 END) as num_null_trade_id
FROM std_trade_blttr
WHERE case_no='case_no' AND firm_id='firm_id';        

--There are critical numeric fields that we need to make note of 
--if there are null values, particularly when it comes to the trades themselves
--not the associated fees

SELECT (CASE WHEN Net_Amt IS NULL THEN 1 else 0 END) AS num_null_net_amt,
        (CASE WHEN Principal IS NULL THEN 1 else 0 END) AS num_null_principal,
        (CASE WHEN Price IS NULL THEN 1 else 0 END) as num_null_price,
        (CASE WHEN Quantity IS NULL then 1 else 0 END) as num_null_quantity,
        (CASE WHEN Order_Type IS NULL then 1 else 0 END) as num_null_order_type,
        (CASE WHEN Currency IS NULL then 1 else 0 END) as null_currency
FROM std_trade_blttr
WHERE case_no='case_no' AND firm_id='firm_id';  



--Confirm how many "trade as of" dates or processing_dates were null to
--confirm if the transformed data matches the raw data files

SELECT file_name, header, COUNT(*) AS num_null_as_of_date
FROM std_trade_blttr
WHERE case_no='case_no' AND firm_id='firm_id' AND As_Of_Date IS NULL
GROUP BY header;

--Confirm how many "settlement dates"" were null to
--confirm if the transformed data matches the raw data files

SELECT file_name, header, COUNT(*) AS num_null_settlement_date
FROM std_trade_blttr
WHERE case_no='case_no' AND firm_id='firm_id' AND Settlement_Date IS NULL
GROUP BY header;

--Confirm how many "trade dates"" were null to
--confirm if the transformed data matches the raw data files

SELECT file_name, header, COUNT(*) AS num_null_trade_date
FROM std_trade_blttr
WHERE case_no='case_no' AND firm_id='firm_id' AND Trade_Date IS NULL
GROUP BY header;

--Confirm how many "trade execution times"" were null to
--confirm if the transformed data matches the raw data files

SELECT file_name, header, COUNT(*) AS num_null_execution
FROM std_trade_blttr
WHERE case_no='case_no' AND firm_id='firm_id' AND Execution_Time IS NULL
GROUP BY header;


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
FROM std_trade_blttr
WHERE case_no='case_no' AND firm_id='firm_id';

--Make sure when you parse the Options Symbology Identifier, the sub-components
--properly match the format of OSI as follows:
    --Underlying symbol: The first part contains the root stock or index ticker 
        --(padded or up to 6 characters, usually matching the underlying Asset). 
    --Expiration date: Follows the format YYMMDD (Year, Month, Day)
    --Call/Put indicator: Uses a single character—C for a call option or P for a put option. 
    --Strike price: Expressed as an 8-digit number representing the dollar amount multiplied by 1,000, 
        --left-padded with zeros (e.g., 00022500 equals a $22.50 strike price). 
        
SELECT (Strike, Expiration, Option_Price, Option_Symbol, Sec_Desc)
FROM std_trade_blttr
WHERE case_no='case_no' AND firm_id='firm_id' AND OSI IS NOT NULL;

--Count null option expiration dates where the OSI Identifier was properly extracted

SELECT COUNT(*) FROM std_trade_blttr
WHERE case_no='case_no' AND firm_id='firm_id' AND OSI IS NOT NULL 
AND Expiration IS NULL;
  

--Make sure where Options were parsed that they logically match the Asset types
--for trades that were executed.

SELECT DISTINCT (Asset, Subtype, Sec_Desc, Strike, Expiration, Option_Price, Option_Symbol)
FROM std_trade_blttr
WHERE case_no='case_no' AND firm_id='firm_id' AND OSI IS NOT NULL;

--use this clause for every new query you're writing to make sure you're querying
--from the right table

--FROM std_trade_blttr
--WHERE case_no='case_no' AND firm_id='firm_id'


