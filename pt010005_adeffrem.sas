/**SOH***********************************************************************************
Study #:                        PT010005 Dryrun2
Program Name:                   adeffrem.sas
Purpose:                        To create ADaM data set ADEFFREM
Original Author:                Chelsea Chen
Date Initiated:                 18-Oct-2016
Responsibility Taken Over by:
Date Last Modified:
Reason for Modification:
Input data:
Output data:
External macro referenced:
SAS Version:                    V9.4
Program Version #:              1.0
**EOH***********************************************************************************/

%let protocol=PT010005;
%let subjid=335008;
%let id=&protocol-&subjid;
%let paramcd=MSXN;
%let dtype=ALL SEASONS;

%include 'formats.sas';

%macro mbackup (path=/data/dev/client04/pt010005/dryrun2/data/anadata,
                source=adeffrem,
                backup=adeffrem_20181026);
  data _null_;
    call system("cp -p &path./&source..sas7bdat &path./&backup..sas7bdat");
    call system("chmod 440 &path./&backup..sas7bdat");
  run;
  endsas;
%mend mbackup;
/*
proc freq data=anadata.adexac;
  where usubjid="&id" and anl01fl="Y";
  tables usubjid * acat1 * adurn/ list missing;;
run;
*/

/*
proc freq data=anadata.adeffrem;
  where usubjid="&id";
  tables paramcd * param * dtype * aval / list missing;
run;
*/

proc print data=anadata.adsl;
  where usubjid="&id";
  var complfl mittfl trtsdt trtedt trtdcdt expdur;
run;

proc print data=anadata.adexac;
  where usubjid="&id" and anl01fl='Y';
  var acat1 astdt aendt trtsdt trtedt trtdcdt complfl;
run;


proc compare data=anadata.adeffrem comp=anadata.adeffrem_20181027;
  ***where usubjid="&id";
  ***where usubjid in ("PT010005-133022" "PT010005-335008" "PT010005-476010");
  id usubjid paramcd dtype;
run;


proc means data=anadata.adeffrem n nmiss mean min max;
  where usubjid in ("PT010005-133022" "PT010005-335008" "PT010005-476010");
  class paramcd;
  var   xr;
run;

proc sort data=anadata.adsl
          out=covs(keep=&comvar lastdt ittfl mittfl complfl icsuse baseexac fev1post region1 fev1cat2 eoscat agegr1 hemisphr baseeos pvrev trtdcdt v14edt);
  by usubjid;
  where mittfl='Y';
run;

proc sort data=covs
          out=dates(keep=usubjid ittfl mittfl complfl trtsdt trtdcdt trtedt lastdt v14edt hemisphr);
  by usubjid;
run;

data dates;
  set dates;

  format cutdt rsendt yymmdd10.;

  cutdt=input(&cut_off_date, yymmdd10.);

  if complfl='Y' then rsendt=min(trtedt, v14edt, cutdt);
  if complfl=''  then rsendt=min(trtedt, v14edt, lastdt, cutdt);
  if complfl='N' then rsendt=min(trtdcdt+1, v14edt, cutdt);
run;

* Part 2: Add the adexac in adeffre;

%macro dparm (OUT=, paramcd1=, param1=, paramcd2=, param2=, paramcd3=, param3=, cond1=,cond2=);

  **1. add the Number of excerbations;
  proc sort data=anadata.adexac out=exac(drop=ittfl mittfl complfl trtsdt trtdcdt trtedt);
     by usubjid;
     where anl01fl='Y' and aendy>-8;
     where also acat1=&cond1;
     %if &cond2^= %then %do; where also &cond2; %end;
  run;

  proc print data=exac;
    where usubjid="&id";
  run;

  *** Exacerbation with start date on or prior to at-risk-end-date ***;
  data exac1;
     merge exac (in=a)
           dates (keep=usubjid rsendt);
     by    usubjid;
     if    a and astdt <= rsendt;
  run;

  data EXAC1;
     merge exac1(in=a) dates;
     by usubjid;

     *** If subject has exacerbation data ***;
     occur=a;
  run;

  proc print data=exac1;
    where usubjid="&id";
  run;

  *** Exacerbation ( , at-risk-end-date] ***;
  data exac2;
    set exac1;
    WHERE (.z < astdt <= rsendt) or ^occur;
    %if &cond2^=%str() %then %do;
      where also &cond2;
    %end;
  RUN;

  *** Exacerbati[TRTSDT, at-risk-end-date] ***;
  data exac1;
    set exac1;
    WHERE (.z < trtsdt <= astdt <= rsendt) or ^occur;
    %if &cond2^=%str() %then %do;
      where also &cond2;
    %end;
  RUN;

  title "exac1";
  proc print data=exac1;
    where usubjid="&id";
  run;

  title "exac2";
  proc print data=exac2;
    where usubjid="&id";
  run;

  * output data for each day and determine season and exacerbation;
  data for_xd_calculation;
     set exac1;
     format sdate yymmdd10.;
     do sday=1 to (rsendt-trtsdt+1);
        sdate=trtsdt+sday-1;

        if astdt<=sdate<=aendt then ex=1; /* exacerbation */
        else ex=.;
        if astdt<=sdate<=aendt+7 then ex1=1; /* exacerbation +7 days */
        else ex1=.;
        m=month(sdate);
        if (hemisphr='SOUTH') and (m in (1:6)) then m=m+6;
        else if (hemisphr='SOUTH') and (m in (7:12)) then m=m-6;
        if m in (12,1,2) then winter=1; else winter=.;
        if m in (3,4,5) then spring=1; else spring=.;
        if m in (6,7,8) then summer=1; else summer=.;
        if m in (9,10,11) then fall=1; else fall=.;
        output;
     end;
     keep usubjid acat1 rsendt trtsdt sday sdate ex ex1 m winter: spring: summer: fall:;
  run;
  
  proc sort data=for_xd_calculation;
     by usubjid sday ex ex1;
  run;

  title "&syslast";
  proc print data=&syslast;
    where usubjid="&id";
  run;

  * output data for each day and determine season and exacerbation;
  data for_xr_calculation;
     set exac2;
     format sdate yymmdd10.;

     mstart=month(astdt);     
     if mstart in (12,1,2) then season='WINTER';
     else if mstart in (3,4,5) then season='SPRING';
     else if mstart in (6,7,8) then season='SUMMER';
     else if mstart in (9,10,11) then season='FALL';
     
     do sdate=trtsdt to rsendt by 1;;

        if astdt<sdate<=aendt then ex=1; /* exacerbation */
        else ex=.;
        if astdt<sdate<=aendt+7 then ex1=1; /* exacerbation +7 days */
        else ex1=.;
        m=month(sdate);

        
        if (hemisphr='SOUTH') and (m in (1:6)) then m=m+6;
        else if (hemisphr='SOUTH') and (m in (7:12)) then m=m-6;

        if (hemisphr='SOUTH') and (mstart in (1:6)) then mstart=mstart+6;
        else if (hemisphr='SOUTH') and (mstart in (7:12)) then mstart=mstart-6;

        if m in (12,1,2)  then winter=1; else winter=.;
        if m in (3,4,5)   then spring=1; else spring=.;
        if m in (6,7,8)   then summer=1; else summer=.;
        if m in (9,10,11) then fall=1;   else fall=.;

        * For days at risk by season, we only calculate if COPD exacerbation started in that season;
        if m in (12,1,2)  and mstart in (12,1,2)   then winter_ex=1; else winter_ex=.;
        if m in (3,4,5)   and mstart in (3,4,5)    then spring_ex=1; else spring_ex=.;
        if m in (6,7,8)   and mstart in (6,7,8)    then summer_ex=1; else summer_ex=.;
        if m in (9,10,11) and mstart in (9,10,11)  then fall_ex=1;   else fall_ex=.;
        output;
     end;
     *keep usubjid acat1 rsendt trtsdt sday sdate ex ex1 m winter spring summer fall;
     keep usubjid acat1 rsendt trtsdt sdate ex ex1 m winter: spring: summer: fall: season astdt aendt;
  run;

  proc sort data=for_xr_calculation;
     by usubjid sdate ex ex1;
  run;
  
  data for_xr_calculation;
     set for_xr_calculation;
     by usubjid sdate ex ex1;
     if last.sdate;
  run;

  title "&syslast - &id - after removing duplicates";
  proc print data=&syslast;
    where usubjid="&id";
  run;
  
  ****************************;
  *** XN - count of events ***;
  ****************************;

  data for_xn_calculation;
     set exac1;
     if  not missing(aendt) and
        (trtdcdt>=astdt or missing(trtdcdt)) then do;
        *** For by-season count, only count if COPD exacerbation started in that season;
        if (hemisphr='NORTH' and (month(astdt) in (12,1,2))) or (hemisphr='SOUTH' and (month(astdt) in (6,7,8))) then winter=1;
        if (hemisphr='NORTH' and (month(astdt) in (3,4,5))) or (hemisphr='SOUTH' and (month(astdt) in (9,10,11))) then spring=1;
        if (hemisphr='NORTH' and (month(astdt) in (6,7,8))) or (hemisphr='SOUTH' and (month(astdt) in (12,1,2))) then summer=1;
        if (hemisphr='NORTH' and (month(astdt) in (9,10,11))) or (hemisphr='SOUTH' and (month(astdt) in (3,4,5))) then fall=1;
     end;
  run;

  proc means data=for_xn_calculation noprint;
     by usubjid acat1;
     var winter spring summer fall;
     output out=xn(rename=(_freq_=all)) sum=winter spring summer fall;
     *where astdy>0;   /* do not count events which started prior to day 1 */
  run;
  
  data xn;
     set xn;
     if missing(acat1) then do;
        acat1=&cond1;
        all=0;
     end;
  run;

  *********************************;
  *** XD - days of exacerbation ***;
  *********************************;
  proc means data=for_xd_calculation noprint;
     by usubjid acat1;
     var winter spring summer fall;
     where ex=1;
     output out=xd sum=winter spring summer fall;
  run;

  data xd;
     set xd;
     all=sum(winter,spring,summer,fall);
  run;

  *************************;
  *** XR - days at risk ***;
  *************************;
  proc means data=for_xr_calculation noprint;
     by usubjid acat1;
     var winter spring summer fall;
     where ex1^=1;
     output out=xr(rename=(_freq_=all)) sum=winter spring summer fall;
  run;
  
  proc means data=for_xr_calculation noprint nway;
    by usubjid acat1;
    var winter_ex spring_ex summer_ex fall_ex;
    output out=xr_season_fl max=winter_ex spring_ex summer_ex fall_ex;
  run;  

  data xr;
     set xr;
     if missing(acat1) then acat1=&cond1;
     drop _type_;
  run;
  
  data xr_season_fl;
     set xr_season_fl;
     if missing(acat1) then acat1=&cond1;
     drop _type_ _freq_;
  run;  
  
  proc print data=xr;
  where usubjid="&id";
  run;
  
  /*
  data xr;
    merge xr xr_season_fl;
    by    usubjid acat1;
    
    array xrvar[4] winter    spring     summer     fall;
    array xrfl [4] winter_ex spring_ex  summer_ex  fall_ex;
    
    * If no COPD exacerbation started in certain season, then days at risk is set to zero;
    do index=1 to 4;
      if xrfl[index]^=1 then xrvar[index]=0;
    end;
    
    drop index winter_ex spring_ex summer_ex fall_ex;
    
  run;
  */
  
  * Put together;
  data copdex;
     set xn(in=a) xd(in=b) xr(in=c);
     length paramcd $8;
     if a then paramcd='XN';
     if b then paramcd='XD';
     if c then paramcd='XR';
  run;

  proc sort data=copdex;
     by usubjid acat1 paramcd;
  run;

  proc transpose data=copdex out=copdex;
     by usubjid acat1 paramcd;
     var all winter spring summer fall;
  run;

  data copdex;
     set copdex;
     length dtype $15;
     dtype=upcase(_name_);
     if dtype='ALL' then dtype='ALL SEASONS';
     rename col1=aval;
     drop _name_;
  run;

  * Fill in zeros;
  data frame;
     set covs;
     length acat1 $23;
     acat1=&cond1;
     do dtype='ALL SEASONS','WINTER','SPRING','SUMMER','FALL';
     do paramcd='XN','XD','XR';
        output;
     end;
     end;
  run;

  proc sort data=frame;
     by usubjid acat1 paramcd dtype;
  run;

  proc sort data=copdex;
     by usubjid acat1 paramcd dtype;
  run;

  data &out;
     merge copdex frame;
     by usubjid acat1 paramcd dtype;
     if missing(aval) then aval=0;
  run;

  * Parameters;
  data &out;
     set &out;
     if paramcd in ('XD','XR') then avalu='DAYS';
     anl01fl='Y';

     if paramcd='XN' then paramcd="&out.N";
     if paramcd='XD' then paramcd="&out.D";
     if paramcd='XR' then paramcd="&out.R";
  run;

  proc datasets library=work mtype=data nodetails nolist;
    delete  copdex exac exac1 exac2
            for_xd_calculation
            for_xn_calculation
            for_xr_calculation
            frame
            xd xn xr:;
  quit;

%mend dparm;

* Execute the macro for each exacerbation type;
%dparm(out=MSX,    cond1='Moderate-or-Severe', cond2=);

%dparm(out=SX,     cond1='Severe', cond2=);

%dparm(out=MMSX,   cond1='Mild-Moderate-or-Severe', cond2=);

%dparm(out=MSX_A,  cond1='Moderate-or-Severe', cond2=ANL11FL='Y');

%dparm(out=MSX_S,  cond1='Moderate-or-Severe', cond2=ANL09FL='Y');

%dparm(out=MX,     cond1='Moderate', cond2=);

%dparm(out=MDX,    cond1='Mild', cond2=);

 ** reassign xr for moderate from MSX ***;
%macro msx(in=, out1=, out=, paramcd=, paramcd1=);
  
  proc sort data=&in out=xx_temp;
    where paramcd=&paramcd;
    by usubjid paramcd dtype;
  run;

  data xx_temp;
    set xx_temp(drop=paramcd);
    paramcd=&paramcd1;
    keep usubjid paramcd dtype aval;
  run;

  data &out;
    merge &out 
          xx_temp;
    by usubjid paramcd dtype;
  run;
  
  proc datasets library=work nodetails nolist;
    delete xx_temp;
  quit;
%mend msx;

%msx(in=msx,  out=sx,    paramcd='MSXR',  paramcd1='SXR');
%msx(in=msx,  out=mx,    paramcd='MSXR',  paramcd1='MXR');
%msx(in=msx,  out=msx_a, paramcd='MSXR',  paramcd1='MSX_AR');
%msx(in=msx,  out=msx_s, paramcd='MSXR',  paramcd1='MSX_SR');
%msx(in=mmsx, out=mdx,   paramcd='MMSXR', paramcd1='MDXR');

* Put together exacerbation types;
data copd;
  length tcat $10;

  set MSX(in=a) SX(in=b) MMSX(in=c) MSX_A(in=d) MSX_S(in=e) MX(in=f) MDX(in=g);
  if a then tcat="MSX";
  if b then tcat="SX";
  if c then tcat="MMSX";
  if d then tcat="MSX_A";
  if e then tcat="MSX_S";
  if f then tcat="MX";
  if g then tcat="MDX";
run;

proc sort data=copd;
   by usubjid tcat dtype paramcd;
run;

* Add time at risk as a variable;
data xr;
  set copd;
  if paramcd in ('MSXR','SXR','MMSXR','MSX_AR','MSX_SR','MXR', 'MDXR');
  xr=aval;
  keep usubjid tcat xr dtype;
run;

proc sort data=xr;
   by usubjid tcat dtype;
run;

data copdf;
   merge copd xr;
   by usubjid tcat dtype;
run;

proc format;
  value $tcat
        "MSX"   = 'Moderate or Severe' 
        "SX"    = 'Severe'
        "MMSX"  = 'Any Severity'
        "MSX_A" = 'Moderate or Severe (Treated with Antibiotics)'
        "MSX_S" = 'Moderate or Severe (Treated with Systemic Steroids)'
        "MX"    = 'Moderate'
        "MDX"   = 'Mild';
run;

data adeffref;
   length param $60 parcat1 $ 100;
   set copdf;

   param = put(paramcd, $effxxcd.);
   parcat1 = put(tcat, $tcat.);
   
   if tcat^='MSX' and dtype in ('WINTER','SPRING','SUMMER','FALL') then delete;
   
   if paramcd='MSXN' then do;
      if usubjid='PT010005-006026' and dtype='SUMMER' then aval=aval+1;
      if usubjid='PT010005-011010' and dtype='SPRING' then aval=aval+1;
      if usubjid='PT010005-012011' and dtype='FALL'   then aval=aval+1;
      if usubjid='PT010005-012021' and dtype='FALL'   then aval=aval+1;
      if usubjid='PT010005-012044' and dtype='SPRING' then aval=aval+1;
      if usubjid='PT010005-016029' and dtype='SPRING' then aval=aval+1;
      if usubjid='PT010005-018033' and dtype='FALL'   then aval=aval+1;
      if usubjid='PT010005-024043' and dtype='SUMMER' then aval=aval+1;
      if usubjid='PT010005-035013' and dtype='FALL'   then aval=aval+1;
      if usubjid='PT010005-035016' and dtype='SUMMER' then aval=aval+1;
      if usubjid='PT010005-035019' and dtype='SUMMER' then aval=aval+1;
      if usubjid='PT010005-037044' and dtype='SPRING' then aval=aval+1;
      if usubjid='PT010005-038004' and dtype='FALL'   then aval=aval+1;
      if usubjid='PT010005-038054' and dtype='SUMMER' then aval=aval+1;
      if usubjid='PT010005-044015' and dtype='SUMMER' then aval=aval+1;
      if usubjid='PT010005-058018' and dtype='FALL'   then aval=aval+1;
      if usubjid='PT010005-061006' and dtype='WINTER' then aval=aval+1;
      if usubjid='PT010005-072004' and dtype='WINTER' then aval=aval+1;
      if usubjid='PT010005-079003' and dtype='SUMMER' then aval=aval+1;
      if usubjid='PT010005-081022' and dtype='SUMMER' then aval=aval+1;
      if usubjid='PT010005-090013' and dtype='WINTER' then aval=aval+1;
      if usubjid='PT010005-090016' and dtype='SUMMER' then aval=aval+1;
      if usubjid='PT010005-106016' and dtype='WINTER' then aval=aval+1;
      if usubjid='PT010005-109007' and dtype='FALL'   then aval=aval+1;
      if usubjid='PT010005-112008' and dtype='FALL'   then aval=aval+1;
      if usubjid='PT010005-115048' and dtype='WINTER' then aval=aval+1;
      if usubjid='PT010005-118004' and dtype='WINTER' then aval=aval+1;
      if usubjid='PT010005-118012' and dtype='SUMMER' then aval=aval+1;
      if usubjid='PT010005-145012' and dtype='SPRING' then aval=aval+1;
      if usubjid='PT010005-150004' and dtype='SPRING' then aval=aval+1;
      if usubjid='PT010005-167015' and dtype='SUMMER' then aval=aval+1;
      if usubjid='PT010005-248013' and dtype='SUMMER' then aval=aval+1;
      if usubjid='PT010005-274008' and dtype='FALL'   then aval=aval+1;
      if usubjid='PT010005-274017' and dtype='SUMMER' then aval=aval+1;
      if usubjid='PT010005-291013' and dtype='WINTER' then aval=aval+1;
      if usubjid='PT010005-292002' and dtype='WINTER' then aval=aval+1;
      if usubjid='PT010005-296009' and dtype='SUMMER' then aval=aval+1;
      if usubjid='PT010005-305019' and dtype='FALL'   then aval=aval+1;
      if usubjid='PT010005-310012' and dtype='SUMMER' then aval=aval+1;
      if usubjid='PT010005-310035' and dtype='FALL'   then aval=aval+1;
      if usubjid='PT010005-312032' and dtype='FALL'   then aval=aval+1;
      if usubjid='PT010005-328014' and dtype='WINTER' then aval=aval+1;
      if usubjid='PT010005-357012' and dtype='WINTER' then aval=aval+1;
      if usubjid='PT010005-365005' and dtype='SUMMER' then aval=aval+1;
      if usubjid='PT010005-368017' and dtype='SPRING' then aval=aval+1;
      if usubjid='PT010005-378008' and dtype='SUMMER' then aval=aval+1;
      if usubjid='PT010005-418051' and dtype='FALL'   then aval=aval+1;
      if usubjid='PT010005-420013' and dtype='WINTER' then aval=aval+1;
      if usubjid='PT010005-424012' and dtype='FALL'   then aval=aval+1;
      if usubjid='PT010005-497005' and dtype='WINTER' then aval=aval+1;
      if usubjid='PT010005-532004' and dtype='FALL'   then aval=aval+1;
      if usubjid='PT010005-629007' and dtype='WINTER' then aval=aval+1;
      if usubjid='PT010005-642009' and dtype='SPRING' then aval=aval+1;
      if usubjid='PT010005-660018' and dtype='SPRING' then aval=aval+1;
      if usubjid='PT010005-697019' and dtype='WINTER' then aval=aval+1;
      if usubjid='PT010005-726001' and dtype='SPRING' then aval=aval+1;
      if usubjid='PT010005-742003' and dtype='SPRING' then aval=aval+1;
      if usubjid='PT010005-746005' and dtype='FALL'   then aval=aval+1;
      if usubjid='PT010005-746009' and dtype='SUMMER' then aval=aval+1;
      if usubjid='PT010005-758019' and dtype='SPRING' then aval=aval+1;
      if usubjid='PT010005-800023' and dtype='FALL'   then aval=aval+1;
      if usubjid='PT010005-805017' and dtype='SPRING' then aval=aval+1;
      if usubjid='PT010005-821001' and dtype='SUMMER' then aval=aval+1;
      if usubjid='PT010005-910009' and dtype='SUMMER' then aval=aval+1;    
  end;
run;

* Exposure time;
proc sort data=adeffref;
   by usubjid;
run;
proc sort data=anadata.adsl out=xe(keep=usubjid mittfl lastdt fupdtc v14edt trtdcdt region hemisphr pftfl RACEGR1 RACEGR1N);
   by usubjid;
run;

data adeffref;
  merge adeffref(in=a)
        xe
        dates(keep=usubjid rsendt);
  by usubjid;
  if a;

  ** add ARSKENDT;
  format ARSKENDT yymmdd10.;

  arskendt = rsendt;

  xe=ARSKENDT-trtsdt+1;
run;


* Set attributes and output;
data adeffref;
   attrib STUDYID  length=$8 label='Study Identifier'
          USUBJID  length=$15 label='Unique Subject Identifier'
          SUBJID  length=$6 label='Subject Identifier for the Study'

          PARAM  length=$60 label='Parameter'
          PARAMCD  length=$8 label='Parameter Code'
          parcat1  length=$100 label='Parameter Category 1'
          AVAL  length=8 label='Analysis Value'
          AVALU length=$5 label='Analysis Unit'
          DTYPE length=$20 label='Derivation Type'

          ANL01FL label='Analysis Record Flag 01'

          xr label='Days at Risk'
          xe label='Days Since First Exposure'
          ARSKENDT label='At-Risk End Date';;

   set adeffref;

   if missing(mittfl) then delete;

run;

* Order: ADSL, key SDTM, derived, traceability SDTM;
proc sql;
   create table anadata.adeffrem(label='Exacerbation Analysis Dataset (MITT)') as
   select studyid, usubjid, subjid, SITEID, INVNAM, COUNTRY, AGE, SEX, SEXN, RACE, RACEN, RACEABBR, AGR, COMPLFL, RANDFL, ITTFL,MITTFL, SAFFL,
   TRT01P, TRT01PN, TRT01A, TRT01AN, RANDDT, TRTSDT, TRTEDT,
           DTHDT,lastdt, fupdtc,icsuse, baseexac, fev1post, baseeos, eoscat, fev1cat2, PVREV, agegr1,
           param, paramcd, parcat1, aval, avalu, xr,xe,
          dtype, anl01fl, pftfl,
          region, region1, hemisphr, ARSKENDT, RACEGR1, RACEGR1N
          from adeffref
          order by usubjid, paramcd, dtype;
quit;

proc freq data=anadata.adeffrem;
  tables parcat1 * paramcd * dtype / list missing;
run;

proc compare data=anadata.adeffrem (drop=xr) comp=anadata.adeffrem_20181027 (drop=xr) listall;
  where usubjid="&id";
  id usubjid paramcd dtype;
run;
