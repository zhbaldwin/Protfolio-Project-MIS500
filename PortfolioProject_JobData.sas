/* ----------------------------------------------------------------- 
	zbaldwin
	MIS500
	CSU-Global_Campus 
	May 2020
	This 
	and convert to a SAS data set
   ----------------------------------------------------------------- */
/* ---------------------- Store SAS Data --------------------------- */
LIBNAME DATALOC '/folders/myfolders/MEPS/DATA';   
/***** --------------------------------------------------------  *****/
                                                          
/* ------------------ Location of SSP Data File -------------------- */
FILENAME h203 '/folders/myfolders/MEPS/h203ssp/h203.ssp';                                                
/***** --------------------------------------------------------  *****/ 

/* ------------- Import SAS Data File Into Work Space -------------  */
PROC CIMPORT DATA=DATALOC.H203 INFILE=h203;                                                                                             
RUN;
/***** --------------------------------------------------------  *****/

TITLE1 'AHRQ MEPS 2018 JOBS DATA (EMPLOYMENT) ';
TITLE2 ' ';

/***** THIS PROC SORT READS IN THE REQUIRED VARIABLES FROM THE *****/
/***** 2018 MEPS JOBS FILE FILE (HC-203) AND SUBSETS TO        *****/
/***** PERSONS WHO HAD A JOB ON OR BEFORE JANUARY 2018.        *****/

PROC SORT DATA= DATALOC.H203 (WHERE=            
            ((((PANEL = 22 AND RN = 3) OR (PANEL = 23 AND RN = 1)) AND
            (SUBTYPE IN (1, 2, 3, 4))) AND
            ((JSTRTY < 2018) OR (JSTRTM = 1 AND JSTRTY = 2018))))          
            NODUPKEY
            OUT= EMPSTART_POP (KEEP= DUPERSID);
    BY DUPERSID;
RUN;
/***** --------------------------------------------------------  *****/

/***** THIS PROC SORT OUTPUTS A JOBS FILE THAT IDENTIFIES      *****/
/***** THOSE WITH A JOB AT THE START OF 2018 WHO EITHER ADDED  *****/
/***** A JOB OR CHANGED JOBS.                                  *****/

PROC SORT DATA=DATALOC.H203 (KEEP= DUPERSID SUBTYPE JSTRTM JSTRTY JSTOPY JOBSIDX WHY_LEFT_M18)
         OUT= H203;
   BY DUPERSID;
RUN;

DATA CHNGJOB_POP (KEEP= DUPERSID);
   MERGE H203 (IN= A) EMPSTART_POP (IN= B);
   BY DUPERSID;
   IF (
      (SUBTYPE IN (3,4)) OR 
           ((SUBTYPE IN (1, 2)) AND
            (JSTRTY = 2018 AND (NOT (JSTRTM = 1))))) AND
      (A AND B) THEN OUTPUT; 
RUN;

PROC SORT DATA= CHNGJOB_POP NODUPKEY;
   BY DUPERSID;
RUN;
/***** --------------------------------------------------------  *****/

/***** CREATE A COMBINED DATA SET WHERE THE EMPSTART_POP PERSONS *****/
/***** AND THE CHNGJOB_POP PERSONS ARE DESIGNATED BY VARIABLES.  *****/

DATA CHNGINFO;
   MERGE H203 (IN= A) EMPSTART_POP (IN= B) CHNGJOB_POP (IN= C) ;
   BY DUPERSID;
   IF B
      THEN EMPSTART = 'YES';
   ELSE EMPSTART = 'NO';
   IF C
      THEN CHNGJOB = 'YES';
   ELSE CHNGJOB = 'NO';
   IF A THEN OUTPUT;
RUN;
/***** --------------------------------------------------------  *****/


/* - SQL Procs to clean up some of the arbitary data and filter     - */
/* - down the sample size ------------------------------------------ */
proc sql;
        delete from WORK.CHNGINFO
           where WHY_LEFT_M18 = -1;

proc sql;
        delete from WORK.CHNGINFO
           where JSTOPY < 0;
           
proc sql;
create table JOBCHNGINFO as
select *, JSTOPY-JSTRTY as YEARSWORKED, 0 as JOBCHANGE
from work.CHNGINFO
quit;

proc sql;
UPDATE work.JOBCHNGINFO
SET JOBCHANGE = 1
WHERE CHNGJOB='YES';
quit;

proc sql;
        delete from WORK.JOBCHNGINFO
           where ((YEARSWORKED < 0) OR (YEARSWORKED > 65));

/***** --------------------------------------------------------  *****/

/* - Test the Freq of occurence reasons for individuals            - */
/* - leaving positions --------------------------------------------- */
TITLE3 'REASON FOR CHANGING JOBS ON OR BEFORE JANUARY 2018,' ;
TITLE4 'PERCENT OF POSITION CHANGE ADDED OR STOPPED IN 2018';
TITLE5 ' ';

PROC FREQ DATA= JOBCHNGINFO;
   TABLES   WHY_LEFT_M18 CHNGJOB
   			WHY_LEFT_M18*CHNGJOB
            / LIST MISSING ;
RUN;

/***** --------------------------------------------------------  *****/

/* - Generate a Bar chart to review the distribution for reason   - */
/* - of switching jobs--------------------------------------------- */
Ods graphics on;
Proc freq data=JOBCHNGINFO order=freq;
Tables WHY_LEFT_M18/ plots=freqplot (type=bar scale=percent);
Run;
Ods graphics off;
/***** --------------------------------------------------------  *****/

/* - Generate a Bar chart to review the distribution to assess    - */
/* - what number of work year sees the most turnover -------------- */
proc sql;
create table ONLYJOBCHANGES as
select *
from work.JOBCHNGINFO
where JOBCHANGE = 1;
quit;

Ods graphics on;
Proc freq data=ONLYJOBCHANGES order=freq;
Tables YEARSWORKED/ plots=freqplot (type=bar);
Run;
Ods graphics off;
/***** --------------------------------------------------------  *****/

/* - Perform a Two Sample Test                                     - */
title 'Two Sample T-Test';

Ods graphics on;
proc ttest data=JOBCHNGINFO;
class JOBCHANGE; /* defines the grouping variable */
var YEARSWORKED; /* variable whose means will be compared */
run;
Ods graphics off;
/***** --------------------------------------------------------  *****/

/* - Perform a Paired T-Test pertaining to total years worked      - */
/* - before job change                                             - */

title 'T-Test Paired YEARSWORKED vs JOBCHANGE';

Ods graphics on;
proc ttest data=ONLYJOBCHANGES;
paired JSTOPY*YEARSWORKED; 
run;
Ods graphics off;
/***** --------------------------------------------------------  *****/

/***** Export Two Data Tables *****/
proc export 
  data=ONLYJOBCHANGES 
  dbms=xlsx 
  outfile="'/folders/myfolders/MEPS/DATA/JOBCHNGINFO.xlsx" 
  replace;
run;

proc export 
  data=JOBCHNGINFO 
  dbms=xlsx 
  outfile="'/folders/myfolders/MEPS/DATA/ONLYJOBCHANGES.xlsx" 
  replace;
run;
/***** ------------------       END     ----------------------  *****/