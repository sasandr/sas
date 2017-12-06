/**SOH***********************************************************************************
Study #:                        PT009002
Program Name:                   adexac.sas
Purpose:                        To create copd exacerbation analysis dataset
Original Author:                Chelsea Chen
Date Initiated:                 2017-10-27
Responsibility Taken Over by:
Date Last Modified:
Reason for Modification:
Input data:                     SDTM datasets: cm fa ho qs dm
                                ADaM dataset: adsl
Output data:
External macro referenced:      %trim2
SAS Version:                    V9.4
Program Version #:              1.0
Notes:                          If this program seems long-winded and convoluted, that's due to the 
                                changes of derivaiton of M/S COPD exacerbation algorithms in the 
                                SAP development.
***EOH**********************************************************************************/

%let subjid=002010;
%let id=PT009002-&subjid;

title "USUBJID=&id";

proc freq data=anadata.adexac;
  tables aphase;
run;

endsas;

proc freq data=tabdata.cm;
  where cmgrpid='PLATE039';
  tables cmcat * cmtrt / list missing;
run;

proc print data=rawdata.plate039 (drop=&dfvar sdv: obs=10) ;
  where id=&subjid;
  var id dfplate dfseq ab: cort:;
run;

proc print data=tabdata.cm;
  where cmgrpid='PLATE039' and usubjid="&id";;
run;


options nocenter errorabend;

%macro sday(var=, rfvar=, sdvar=);
  if nmiss(&var, &rfvar)=0 then &sdvar = (&var - &rfvar) + (&var >= &rfvar);
%mend sday;

%macro flag(varlst=, anlxxlst=);
  %let i = 1 ;
  %do %while(%scan(&varlst,&i,%str( )) NE %str( )) ;
    %let var     = %scan(&varlst,&i,%str( ));
    %let anlzzfl = %scan(&anlxxlst, &i, %str( ));
    if upcase(&var)='Y' then &anlzzfl='Y'; else call missing(&anlzzfl);
    %let i=%eval(&i+1);
  %end;
%mend flag;

proc format;
  value $ testcd
        COPDEX1 = 'DYSPNEA'
        COPDEX2 = 'SPUTUM'
        COPDEX3 = 'SPUTUMC'
        COPDEX4 = 'COUGH'
        COPDEX5 = 'WHEEZE'
        COPDEX6 = 'SORETHRT'
        COPDEX7 = 'COLD'
        COPDEX8 = 'FEVER';
run;

**********************************;
*** CRF COPD Exacerbation data ***;
**********************************;

*** Findings ***;
data _fa;
  set tabdata.fa (keep=usubjid facat faspid fatestcd faorres fadtc);
  where facat='EXACERBATION OF COPD' and fatestcd^='JUSTIFIC';
run;

data _fa;
  merge _fa (in=a)
        tabdata.dm (keep=usubjid dthdtc);
  by    usubjid;
  
  if    a;
  
  if    fatestcd='DEATH' and faorres='Y' then fadtc=dthdtc;
run;

proc sort data=_fa;
  by usubjid faspid;
run;

proc transpose data=_fa out=fa (drop=_name_ _label_);
  by  usubjid faspid;
  var faorres;
  id  fatestcd;
run;

proc transpose data=_fa(where=(^missing(fadtc))) out=fadtc (drop=_name_ _label_) suffix=d;
  by  usubjid faspid;
  var fadtc;
  id  fatestcd;
run;

data faall;
  merge fa
        fadtc;
  by    usubjid faspid;

  format fadt exadthdt yymmdd10.;
  spid  = input(faspid, best.);

  fadt  = input(exdiaald, yymmdd10.);
  
  exadthdt = input(deathd, yymmdd10.);
run;

*** Conmed ***;
data cm;
  set tabdata.cm (keep=usubjid cmcat cmtrt cmspid cmstdtc cmendtc cmoccur);
  where cmcat='EXACERBATION OF COPD (MODERATE OR SEVERE)';

  drop cmcat;
run;

proc sort data=cm; by usubjid cmspid; run;

data cmall;
  merge cm (where=(cmtrt='ANTIBIOTICS') rename=(cmoccur=aboccur cmstdtc=abstdtc cmendtc=abendtc))
        cm (where=(cmtrt='INJECTED AND/OR ORAL CORTICOSTEROIDS') rename=(cmoccur=ococcur cmstdtc=csstdtc cmendtc=csendtc));
  by    usubjid cmspid;

  spid  = input(cmspid, best.);

  format abstdt abendt csstdt csendt yymmdd10.;

  abstdt = input(abstdtc, ?? yymmdd10.);
  abendt = input(abendtc, ?? yymmdd10.);
  csstdt = input(csstdtc, ?? yymmdd10.);
  csendt = input(csendtc, ?? yymmdd10.);

  drop  cmtrt /*abstdtc abendtc csstdtc csendtc*/;
run;

*** Hospitalization ***;
data ho;
  set tabdata.ho (keep=usubjid hogrpid hospid hoterm hooccur hostdtc hoendtc);
  where hogrpid='PLATE039';

  drop hogrpid;
run;

proc sort data=ho; by usubjid hospid; run;

data hoall;
  merge ho (where=(hoterm='HOSPITALIZATION'))
        ho (where=(hoterm='EMERGENCY DEP > 24 HRS') rename=(hooccur=eroccur hostdtc=erstdtc hoendtc=erendtc));
  by    usubjid hospid;

  spid  = input(hospid, best.);

  format hsstdt hsendt erstdt erendt yymmdd10.;

  hsstdt = input(hostdtc, ?? yymmdd10.);
  hsendt = input(hoendtc, ?? yymmdd10.);
  erstdt = input(erstdtc, ?? yymmdd10.);
  erendt = input(erendtc, ?? yymmdd10.);

  drop  hoterm hostdtc hoendtc erstdtc erendtc;
run;

*** Combined;
data crf01;
  merge faall
        cmall
        hoall;
  by    usubjid spid;

  length sev acat2 $ 50;
  format astdt aendt yymmdd10.;

  acat2 = 'CRF';

  *** Analysis start date;
  if    nmiss(abstdt, csstdt)^=2 then astdt = min(abstdt, csstdt);
  else if ^missing(exadthdt) then astdt=exadthdt;
  
  *** Analysis end date;
  if    nmiss(abendt, csendt)^=2 then aendt = max(abendt, csendt);
  else  if ^missing(exadthdt) then aendt=exadthdt;

  *** Impute analysis end date;
  if ^missing(astdt) and missing(aendt) then do;
     put "INTO: " usubjid= abendt= csendt= hsendt= erendt=;
     aendt = max(abstdt, csstdt, astdt+9);
     aendtf = 'Y';
  end;

  if nmiss(astdt, aendt)=2 then delete;

  *** Create analysis flags;
  %flag(varlst  =exdiaal hooccur eroccur ococcur aboccur death cold fever sputumc sputum cough dyspnea wheeze sorethrt,
        anlxxlst=anl03fl anl07fl anl08fl anl09fl anl11fl anl13fl anl21fl anl22fl anl23fl anl24fl anl25fl anl26fl anl27fl anl28fl);
  
  if missing(csstdt) then call missing(anl09fl);
  if missing(abstdt) then call missing(anl11fl);

  if cats(anl21fl, anl22fl, anl23fl, anl24fl, anl25fl, anl26fl, anl27fl, anl28fl)>='YY' then sympfl='Y'; else sympfl=' ';
  if cats(anl23fl, anl24fl, anl26fl)>='Y' then msympfl='Y'; else msympfl=' ';
  
  if sympfl='Y' and msympfl='Y' then anl41fl='Y'; else anl41fl=' ';
  
  *** Determine COPD severity;
  if  (anl09fl='Y' or anl11fl='Y') and (anl07fl='Y' or anl08fl='Y' or anl13fl='Y') then sev='Severe';
  else if cmiss(anl09fl, anl11fl)=2 and anl13fl='Y' then sev='Severe';
  else if  (anl09fl='Y') or (anl11fl='Y') then sev='Moderate';
  
  if   death='N' and missing(exdiaal) then call missing(faspid);

  drop /*hostdtc hoendtc erstdtc erendtc*/ abstdtc abendtc csstdtc csendtc
       /*exdiaald*/
       /*exdiaal*/ hooccur eroccur /*fadt ococcur aboccur death cold fever sputumc sputum cough dyspnea wheeze sorethrt */;
run;

data crf02;
  set crf01;

  length acat1 $ 50;

  *** Populate severity categories (acat1);
  *** sevn is temporary numeric value to help sort from high intensity to low intensity;
  if  sev='Severe' then do;
      acat1 = 'Severe'; sevn=1; output;
      acat1 = 'Moderate-or-Severe'; sevn=2; output;
      acat1 = 'Mild-Moderate-or-Severe'; sevn=3; output;
  end;

  else if sev='Moderate' then do;
      acat1 = 'Moderate-or-Severe'; sevn=2; output;
      acat1 = 'Mild-Moderate-or-Severe'; sevn=3; output;
  end;
  

run;

proc sort data=crf02;
  by  usubjid astdt sevn acat1;
run;

*************************************;
*** eDiary COPD Exacerbation data ***;
*************************************;

*** eDiary COPD exacerbation selection criteria based on spec;
data crit;
  infile cards delimiter='|';
  length qstestcd $ 8
         orres  $ 100;
  input  qstestcd $
         orres $;
datalines;
COPDEX1|MORE BREATHLESS THAN USUAL
COPDEX2|MORE MUCUS (PHLEGM) THAN USUAL
COPDEX3|MUCUS (PHLEGM) WAS A DARKER OR A DIFFERENT COLOR THAN USUAL
COPDEX4|MORE COUGH THAN USUAL
COPDEX5|MORE WHEEZE THAN USUAL
COPDEX6|YES, I HAD A SORE THROAT
COPDEX7|YES, I HAD SYMPTOMS OF A COLD
COPDEX8|YES, I HAD A FEVER
;
run;

data qs01;
  set tabdata.qs;
  where qscat='COPDEX';

  length orres $ 100;
  format adt yymmdd10.;
  
  orres = upcase(strip(qsorres));
  adt = input(scan(strip(qsdtc), 1, 'T'), yymmdd10.);
  keep usubjid qstestcd qstest qscat adt qsorres qsdtc orres;
run;

proc sort data=qs01; by qstestcd orres; run;
proc sort data=crit; by qstestcd orres; run;

data qs02;
  merge qs01
        crit (in=a);
  by    qstestcd orres;
  if    a then faorres='Y';
  else  faorres=' ';

  length fatestcd $ 8;

  fatestcd = put(qstestcd, testcd.);
  
  drop qsorres orres qstestcd qstest;
run;

proc sort data=qs02;
  by usubjid qscat fatestcd adt faorres;
run;

data qs02;
  set qs02;
  by  usubjid qscat fatestcd adt;
  
  if  last.adt;
run;


proc sort data=qs02; by usubjid qscat adt; run;

*** Transpose data from long to wide;
proc transpose data=qs02 out=t_qs;
  by  usubjid qscat adt;
  id  fatestcd;
  var faorres;
run;

data diary;
  set t_qs;
  by  usubjid qscat adt;

  format astdt aendt yymmdd10.;
  astdt = adt;
  aendt = astdt;

  *** Create analysis flags;
  %flag(varlst  =cold fever sputumc sputum cough dyspnea wheeze sorethrt,
        anlxxlst=anl21fl anl22fl anl23fl anl24fl anl25fl anl26fl anl27fl anl28fl);

  if cats(anl21fl, anl22fl, anl23fl, anl24fl, anl25fl, anl26fl, anl27fl, anl28fl)>='YY' then sympfl='Y'; else sympfl=' ';
  if cats(anl23fl, anl24fl, anl26fl)>='Y' then msympfl='Y'; else msympfl=' ';
  
  if sympfl='Y' and msympfl='Y' then anl41fl='Y'; else anl41fl=' ';

  drop cold fever sputumc sputum cough dyspnea wheeze sorethrt _name_;
run;

proc sort data=diary; by usubjid anl41fl astdt; run;

*** Determine consecutive days;
data diary02;
  set diary;
  by  usubjid anl41fl astdt;

  retain block;

  if  first.anl41fl and anl41fl='Y' then block=0;

  diff=dif(astdt);
  lagflag=lag(anl41fl);

  if  first.anl41fl then do;
      call missing(diff, lagflag);
  end;

  if  ^(anl41fl='Y' and lagflag='Y' and diff=1) then block+1;

  if  missing(anl41fl) then block=.;

run;

proc sql noprint;
  create table diary03 as
  select *, count(*) as days
  from   diary02
  group  by usubjid, block
  order  by usubjid, astdt;
quit;

data diary04;
  set diary03;

  if  anl41fl='Y' and days>=2 then anl42fl='Y'; else call missing(anl42fl);

  drop lagflag diff days;

  length acat1 acat2 $ 50;

  acat2 = 'eDiary';

  *** sevn is temporary numeric value to help sort from high intensity to low intensity;
  if   anl42fl='Y' then do;
       acat1='Mild-Moderate-or-Severe';
       sevn=3;
  end;
  else do;
       acat1=' ';
       sevn=4;
  end;
run;

*** combine crf and diary data;
data adexac01;
  set crf02    (in=a)
      diary04  (in=b);

  *** type is a temp variable to help determine the source for composite events;
  type = a*1 + b*2;
run;

proc sort data=adexac01; by usubjid sevn astdt aendt; run;

*** Create necessary variables for composite events***;
data der01;
  set adexac01;
  by  usubjid sevn;

  retain collapse maxendt ;

  format prestdt preendt maxendt yymmdd10.;

  prestdt = lag(astdt);
  preendt = lag(aendt);
  maxendt  = max(maxendt, preendt);

  if preendt > astdt > .z and ^missing(acat1) then put usubjid= astdt= aendt= preendt=;

  *** Determine blocks of collapsible events;
  if first.sevn then do;
      call missing(prestdt, preendt, maxendt);
      new      = 'Y';
      collapse = 1;
  end;


  if (^missing(preendt) and intck('day', preendt, astdt) > 7 and intck('day', maxendt, astdt) > 7) then do;
      new      = 'Y';
      collapse + 1;
  end;
run;

*** This is only for QMS and QS records ***;
proc sort data=adexac01(where=(acat1 in ('Moderate-or-Severe' 'Severe'))) out=adexac01_1; 
  by usubjid astdt aendt; run;
run;

*** Collapse events with gap <=7 days to create composite records;
*** For Severe (QS) and Moderate-or-Severe (QMS) records;
data der01_1;
  set adexac01_1;
  by  usubjid astdt;

  retain collapse maxendt ;

  format prestdt preendt maxendt yymmdd10.;

  prestdt = lag(astdt);
  preendt = lag(aendt);
  maxendt  = max(maxendt, preendt);

  if preendt > astdt > .z and ^missing(acat1) then put usubjid= astdt= aendt= preendt=;

  *** Determine blocks of collapsible events;
  if first.usubjid then do;
      call missing(prestdt, preendt, maxendt);
      new      = 'Y';
      collapse = 1;
  end;


  if (^missing(preendt) and intck('day', preendt, astdt) > 7 and intck('day', maxendt, astdt) > 7) then do;
      new      = 'Y';
      collapse + 1;
  end;
run;

proc sql noprint;
  create table der02 as
  select *, count(*) as count
  from   der01
  group  by usubjid, sevn, acat1, collapse;
quit;


title2 "Collapsed records";
proc print data=der02;
  where usubjid in ("&id");
  var usubjid acat1 astdt aendt aendtf preendt anl: collapse: new sevn count;
run;

/* ================ Create composite records ====================== */
proc sql noprint;
  create table der03_0 as
  select usubjid, collapse, sevn, acat1,
         min(astdt)   as astdt format=yymmdd10.,
         max(aendt)   as aendt format=yymmdd10.,
         /*max(aendtf)  as aendtf,*/
         max(anl07fl) as anl07fl,
         max(anl08fl) as anl08fl,
         max(anl09fl) as anl09fl,
         max(anl11fl) as anl11fl,
         max(anl13fl) as anl13fl,
         max(type)              as type,
         count(distinct(acat2)) as source,
         max(count(distinct(spid)), count(distinct(astdt)), count(distinct(aendt))) as nrec
  from   der02 where sevn ^in (4)
  group  by usubjid, collapse, sevn, acat1;
quit;

title2 "der03_0";
proc print data=der03_0;
  where usubjid="&id";
  id usubjid;
  by usubjid;
run;

/* ================ Create composite records from QS/QMS events ====================== */
proc sql noprint;
  create table der03_1 as
  select usubjid, collapse, acat1,
         min(astdt)   as astdt format=yymmdd10.,
         max(aendt)   as aendt format=yymmdd10.,
         min(sevn)    as sevn,
         max(anl07fl) as anl07fl,
         max(anl08fl) as anl08fl,
         max(anl09fl) as anl09fl,
         max(anl11fl) as anl11fl,
         max(anl13fl) as anl13fl,
         max(type)              as type,
         count(distinct(acat2)) as source,
         max(count(distinct(spid)), count(distinct(astdt)), count(distinct(aendt))) as nrec
  from   der01_1 where sevn in (1,2)
  group  by usubjid, collapse;
quit;

proc sort data=der03_1 nodupkey;
  by usubjid collapse acat1 astdt aendt sevn anl07fl anl08fl anl09fl anl11fl anl13fl type source nrec;
run;

proc sort data=der02 out=_aendtf (keep=usubjid collapse sevn acat1 aendt aendtf);
  where sevn^=4;
  by usubjid collapse sevn acat1 aendt;
run;

data aendtf;
  set _aendtf;
  by usubjid collapse sevn acat1 aendt;
  if last.acat1;
run;

*** Add serious;
data der03;
  set der03_0 (in=inall)
      der03_1 (in=inms where=(sevn=1 and acat1='Severe' and nrec>1));
  
  order=inall*1 + inms*2;
run;

proc sort data=der03;
  by usubjid collapse sevn acat1 aendt;
run;

data der03;
  merge der03
        aendtf;
  by    usubjid collapse sevn acat1 aendt;
  
  drop  collapse;
run;

proc sort data=der03;
  by usubjid sevn acat1 astdt aendt aendtf nrec;
run;

data der03;
  set der03;
  by  usubjid sevn acat1 astdt aendt aendtf nrec;
  
  if  first.nrec;
run;

data der04;
  set der03;

  length acat2 $ 50;

  *** Derive variable acat2;
  if  source=1 and type=1 and sevn in (1,2) then acat2='CRF';
  if  source=1 and type=2 then acat2=' ';
  else if source=2 then acat2=' ';
run;

title2 "Combine all composites - after removing duplicate - #4";
proc print data=der04;
  where usubjid="&id";
run;

*** Combine non-composite records with composite records;
data adexac01;
  set der02 (in=a)
      der04(where=(nrec>1) in=b);
  
  if  (a and acat2='CRF' and new='Y' and count=1) or b then anl01fl='Y';

  if  anl01fl='Y' and b then anl51fl='Y'; else call missing(anl51fl);
    
run;

data derived;
  set adexac01(keep=usubjid sevn anl51fl astdt aendt);
  where anl51fl='Y' and sevn=1;
  
  rename astdt = serstdt aendt=serendt;
  
  dur = (aendt - astdt);
  
  drop anl51fl;
run;

title2 "Collapsed records - check anl01fl flag";
proc print data=adexac01;
  where usubjid="&id" and sevn=1;
  var usubjid acat1 acat2 astdt aendt source nrec type anl01fl;
run;

proc sort data=adexac01; by usubjid sevn; run;
proc sort data=derived; by usubjid sevn descending dur; run;
proc sort data=derived nodupkey; by usubjid sevn; run;
  
proc print data=derived;
  where usubjid="&id" and sevn=1;
run;
 
data adexac01;
  merge adexac01
        derived (in=b);
  by    usubjid sevn;
  
  if    anl01fl='Y' and (serstdt<=astdt and serendt>=aendt) and ^(serstdt=astdt and serendt=aendt) 
  then  call missing(anl51fl, anl01fl);
 
run;

title2 "Collapsed records - check anl01fl flag";
proc print data=adexac01;
  where usubjid="&id" and sevn=1;
  var usubjid faspid acat1 acat2 astdt aendt source nrec type anl01fl anl51fl;
run;

*** Merge dataset with adsl and dm to determine study days and if event is on or after first dose;
*** Only events on or after first dose will be eligible for first occurrence flag;

data adsl;
  set anadata.adsl (keep=studyid usubjid subjid siteid invnam age ageu sex sexn race racen agr country 
                         ittfl mittfl randfl complfl trtsdt trtedt trtdcdt doseedt randdt trt01a: trt01p: );
run;

data adexac02;
  merge adexac01 (in=a)
        adsl;
  by    usubjid;

  if    a;

  domain = 'ADEXAC';

  *** Treated subjects will have study day based on first dose;
  if ^missing(trtsdt) then do; 
     %sday(var=astdt, rfvar=trtsdt, sdvar=astdy); 
     %sday(var=aendt, rfvar=trtsdt, sdvar=aendy);
  end;
  
  *** Randomized but not treated subjects will have study day based on randomization date;
  else if ^missing(randdt) then do; 
    %sday(var=astdt, rfvar=randdt, sdvar=astdy);
    %sday(var=aendt, rfvar=randdt, sdvar=aendy);
  end;
  
  *** postfn variable to help create first occurrence flag;
  if astdy > 0 then postfn=1; else postfn=0;
  
run;

proc sort data=adexac02; by usubjid postfn sevn acat1 descending anl01fl astdt; run;

data adexac03;
  set adexac02;
  by  usubjid postfn sevn acat1;
  
  if  postfn=1 and first.acat1 and anl01fl='Y' then aoccfl='Y'; else aoccfl=' ';
run;

*** Assign occurrence flag for specific events;
%macro goccur(indsn=, zz=);
  proc sort data=&indsn; by usubjid postfn sevn acat1 descending anl01fl descending anl&zz.fl astdt; run;
    
  data &indsn;
    set &indsn;
    by  usubjid postfn sevn acat1 descending anl01fl;
    
    if  postfn=1 and first.acat1 and anl01fl='Y' and anl&zz.fl='Y' then aocc&zz.fl='Y'; else aocc&zz.fl=' ';
  run;
%mend goccur;

%goccur(indsn=adexac03, zz=07);
%goccur(indsn=adexac03, zz=08);
%goccur(indsn=adexac03, zz=09);
%goccur(indsn=adexac03, zz=11);
%goccur(indsn=adexac03, zz=13);
  
data adexac04;
  
  set adexac03;

  adurn = aendt - astdt + 1;

  if ^missing(adurn) then aduru='DAYS';

  length aphase $ 20;
  
  *** Derive analysis period;
  if ^missing(trtsdt) then do;
           if .z < astdt < trtsdt then aphase='SCREENING';
      else if astdt > doseedt > .z then aphase='FOLLOW_UP';
      else if ^missing(trtdcdt) and astdt > (trtdcdt+1) then aphase='POST-TREATMENT';
      else aphase='TREATMENT';            
  end;
  
  else if ^missing(randdt) then do;
           if .z < astdt < randdt then aphase='SCREENING';
      else if astdt >= randdt then aphase='FOLLOW_UP';
  end;
  
  else aphase='SCREENING';
  
  derived=anl51fl;
  
  if anl01fl='Y' then anl01fn=1;
  
  astdtf=' ';

  label
  domain  = 'Domain Abbreviation'
  ACAT1   = 'Analysis Category 1, Severity'
  ACAT2   = 'Source'
  ASTDT   = 'Analysis Start Date'
  ASTDY   = 'Analysis Start Day'
  AENDT   = 'Analysis End Date'
  AENDY   = 'Analysis End Day'
  AENDTF  = 'Analysis End Date Imputation Flag' 
  ADURN   = 'Analysis Duration (N)'
  ADURU   = 'Analysis Duration Units'
  APHASE  = 'Analysis Period'
  ANL01FL = 'Analysis Record Flag 01, Non Relapse'
  ANL01FN = 'Analyzed Record Flag 01 (N)'
  ANL03FL = 'Analysis Record Flag 03, eDiary Alert'
  ANL07FL = 'Analysis Record Flag 07, Hopitalization'
  ANL08FL = 'Analysis Record Flag 08, ER Visit'
  ANL09FL = 'Analysis Record Flag 09, Corticosteroids'
  ANL11FL = 'Analysis Record Flag 11, Antibiotics'
  ANL13FL = 'Analysis Record Flag 13, Led to Death'
  ANL21FL = 'Analysis Record Flag 21, Cold Symptoms'
  ANL22FL = 'Analysis Record Flag 22, Fever'
  ANL23FL = 'Analysis Record Flag 23, Mucus Color'
  ANL24FL = 'Analysis Record Flag 24, Mucus Volume'
  ANL25FL = 'Analysis Record Flag 25, Cough'
  ANL26FL = 'Analysis Record Flag 26, Short of Breath'
  ANL27FL = 'Analysis Record Flag 27, Wheezing'
  ANL28FL = 'Analysis Record Flag 28, Sore Throat'
  ANL41FL = 'Analysis Record Flag 41, Symptom Suffice'
  ANL42FL = 'Analysis Record Flag 42, Consecutive Day'
  ANL51FL = 'Analysis Record Flag 51, Composite Event'
  AOCCFL  = '1st Occurrence within Subject Flag'
  AOCC07FL= '1st Occurrence with Hospitalization'
  AOCC08FL= '1st Occurrence with ER > 24 Hrs'
  AOCC09FL= '1st Occurrence with Corticosteroid Use'
  AOCC11FL= '1st Occurrence with Antibiotic Use'
  AOCC13FL= '1st Occurrence Leading to Death'
  DERIVED = 'Record was Derived'
  hsstdt   = "Hospitalization Start Date"
  hsendt   = "Hospitalization End Date"
  erstdt   = "ER > 24 Hrs Start Date"
  erendt   = "ER > 24 Hrs Start Date"
  csstdt   = "Corticosteroid Use Start Date"
  csendt   = "Corticosteroid Use End Date"
  abstdt   = "Antibiotic Use Start Date"
  abendt   = "Antibiotic Use End Date"
  exadthdt = "Led-to-Death Date";
run;

%trim2(indsn=adexac04, outdsn=adexac04, keep_length=qscat trt01p hospid cmspid faspid);

proc sort data=adexac04; by usubjid sevn collapse anl01fl astdt aendt; run;
  
proc print data=adexac04;
  where usubjid="&id";
  var usubjid astdt aendt: acat1 acat2 anl01fl anl51fl;
run;

proc sql noprint;
  create table anadata.adexac (label="COPD Exacerbation Analysis Dataset") as
  select studyid, domain, usubjid, subjid, siteid, invnam, age, ageu, sex, sexn, agr, country, ittfl, mittfl, randfl, complfl,
         randdt, trtsdt, trtedt, trtdcdt, trt01p, trt01pn, acat1, acat2, faspid, hospid, cmspid, qscat,
         astdt, astdy, astdtf, aendt, aendy, aendtf, adurn, aduru, aphase,
         anl01fl, anl01fn, anl03fl, anl07fl, anl08fl, anl09fl, anl11fl, anl13fl, anl21fl, anl22fl, anl23fl, anl24fl, anl25fl, anl26fl, anl27fl, anl28fl,
         anl41fl, anl42fl, anl51fl, aoccfl, aocc07fl, aocc08fl, aocc09fl, aocc11fl, aocc13fl, derived, 
         hsstdt, hsendt, erstdt, erendt, csstdt, csendt, abstdt, abendt, exadthdt
  from   adexac04
  order  by USUBJID, ASTDT, ACAT1, ANL01FL, ACAT2, ANL42FL, ANL51FL, AENDT, faspid, hospid, cmspid;
quit;
  
proc print data=anadata.adexac;
  where usubjid="&id" and acat1 in ('Moderate-or-Severe' 'Severe');
  var usubjid astdt aendt acat1 acat2 anl01fl anl07fl anl42fl anl51fl;
run;