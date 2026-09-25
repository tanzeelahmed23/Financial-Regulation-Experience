-- !preview conn=DBI::dbConnect(RSQLite::SQLite())

--These are the queries I wrote to standardize the data on registered representatives
--associated with the firm,not the real name of the file,
--all variables are changed to protect confidential information.
--This is a relatively smaller file for each exam, but we need to make sure
--all data transformations were mapped correctly so any activity we review
--is assigned to the proper representative.

SELECT * FROM reg_rep_supp;

--The following queries are to look for where we were authorized to treat nulls as
--"Not Provided" as a default standard to make note of this for stakeholders.
--This is to satisfy the technical requirements of multiple ETL pipelines.

SELECT COUNT(*)
FROM reg_rep_supp WHERE crd IS NULL OR crd in('Not Provided');

SELECT COUNT(*)
FROM rep_nm WHERE crd IS NULL OR crd in('Not Provided');

---For this sanity check, the rep identifier is the primary key and has the most scrutiny

SELECT COUNT(*) AS missing_rep_id
FROM rep_id WHERE crd IS NULL OR crd in('Not Provided');