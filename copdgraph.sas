%let subjid=059019;
%let id=PT010005-&subjid;

data copd;
  length acat2 $ 10;
  set anadata.adexac;
  /*
  where subjid in ("038004" "048025" "049018" "056016" "059019" "090016" "109017" "156003" "174008" "199017" "261001" 
                   "293001" "299027" "303019" "310022" "312033" "312042" "345002" "373009" "392005" "418019" "425017" 
                   "428013" "429004" "442002" "474013" "483069" "500008" "561014" "634002" "642005" "709002" "712018" 
                   "726013" "742003" "766010" "804007" "808011"); */
  where subjid="&subjid";
  spid=coalesce(cmspid, faspid, hospid);
  if missing(acat1) then delete;
  if acat1='Mild-Moderate-or-Severe' and acat2='CRF' then delete;
  ***if acat1='Moderate-or-Severe' and acat2='CRF' then delete;
  
  h2=RSKNDMIT-trtsdt+1;
  
  if missing(acat2) and acat1^='Mild' then acat2='Comp.';
  else if missing(acat2) then acat2='Mild Only';
run;

proc freq data=copd;
  tables acat1 * acat2 * derived / list missing;
run;

proc sort data=copd;
  by usubjid anl01fl acat1 astdt spid;
run;

proc sql noprint;
  select min(astdy) into: minday  from copd;
  select max(aendy) into: maxday  from copd;  
  select min(astdt) into: mindate  from copd;
  select max(aendt) into: maxdate  from copd;
quit;

proc format;
  value yxis
        1 = 'Severe'
        2 = 'Moderate'
        3 = 'Mild'
        4 = 'M/S'
        5 = 'Any Severity'
        6 = 'Symptom'
        7 = ' ';
run;

data copd;
  set copd;
  by  usubjid anl01fl acat1 astdt spid;
  
  if  missing(anl01fl) then y=6;
  if  ^missing(anl01fl) then do;
      if acat1='Mild' then y=3;
      if acat1='Moderate' then y=2;
      if acat1='Severe' then y=1;
      if acat1='Mild-Moderate-or-Severe' then y=5;
      if acat1='Moderate-or-Severe' then y=4;
  end;
run;


proc print data=copd;
  var usubjid spid anl01fl acat1 acat2 astdt aendt trtdcdt y rsk:;
run;

proc print data=anadata.adeffrem;
  where subjid="&subjid";
  var usubjid paramcd aval;
run;


ods rtf file="COPD Exacerbations.rtf";
proc sgplot data=copd noautolegend nocycleattrs;
  by usubjid;
    format y yxis.;
   refline 0 / axis=x lineattrs=(thickness=1 color=red);
   refline h2/ axis=x lineattrs=(thickness=1 color=red);
   
 
   /*--Draw the events--*/
   vector x=aendy y=y / xorigin=astdy yorigin=y noarrowheads lineattrs=(thickness=7px pattern=solid)
          transparency=0 group=acat2 name='Source';

 
   /*--Draw start and end events--*/
   **scatter x=astdy y=y / markerattrs=(size=13px symbol=trianglefilled);
   **scatter x=astdy y=y / markerattrs=(size=9px symbol=trianglefilled) group=acat2;
   **scatter x=aendy y=y / markerattrs=(size=13px symbol=trianglefilled);
   **scatter x=aendy y=y / markerattrs=(size=9px symbol=trianglefilled) group=acat1;
      
   /*--Assign dummy plot to create independent X2 axis--*/
   scatter x=astdt y=y /  markerattrs=(size=0) x2axis;
 
   /*--Assign axis properties data extents and offsets--*/
   yaxis LABEL='Type of COPD Exacerbations' GRID VALUES = (1, 2, 3, 4, 5, 6) min=0;
   xaxis grid label='Study Days' offsetmin=0.02 offsetmax=0.02 values=(&minday to &maxday by 7);
   x2axis notimesplit display=(nolabel) offsetmin=0.02 offsetmax=0.02 values=(&mindate to &maxdate);
            
   /*--Draw the legend--*/
   keylegend 'Source'/ title=' ';
run;
ods rtf close;
