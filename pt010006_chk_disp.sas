/*
Observation 895 in WORK.COMP not found in WORK.COMP_ADSL: USUBJID=PT010006-120005.
Observation 936 in WORK.COMP not found in WORK.COMP_ADSL: USUBJID=PT010006-132001.
*/
%prtraw(plate025, %str(id stcomp stdcrsn stldosdt), 120005);
%prtraw(plate033, %str(), 120005);

%prtraw(plate025, %str(id stcomp stdcrsn stldosdt), 132001);
%prtraw(plate033, %str(), 132001);

*** Study medication data;
data stmed;
  format dosedt yymmdd10.;
  set rawdata.plate033;
  where exstdat ^in (&missvalc);
  
  dosedt = input(exstdat, date11.);
  
  keep id dfseq dosedt;
run;

*** Check dfseq;
proc freq data=stmed;
  tables dfseq;
run;

proc sort data=stmed; by id dosedt;
run;

data dosed;
  set stmed;
  by  id dosedt;
  
  if  first.id;
  
  trtfl='Y';
  
  rename dosedt = trtsdt;
run;

proc freq data=dosed;
  tables trtfl;
run;

*** Those with Week 24 dosing data;
data week24;
  set stmed (where=(dfseq=12));
  keep id dfseq;
run;

************************;
*** End of Treatment ***;
************************;

*** EOT record;
data comp01;
  set rawdata.plate025;
  keep id stcomp stdcrsn;
run;

*** Check EOT page and week 24 dosing;
data comp;
  merge comp01 (in=a)
        week24 (in=b);
  by    id;
  
  if    (stcomp=1 and a) and ^b then put "INFO: Completer in EOT, but no week 24 dosing. " id= dfseq= ;
  if    b and stcomp=2 then put "ERROR1: Completed Week 24 dosing, but discontinued treatment. " id= stcomp= stdcrsn=;

  if    stcomp=1 or (stcomp^=2 and b) then complfl='Y';
  else  if stcomp=2 then complfl='N';
run;

********************;
*** End of Study ***;
********************;
%visit;

*** Records coming from visit page - refused follow-up;
data ref_fu;
  set visit;
  where fumethod=2;
  keep id fumethod;
run;

proc sort data=ref_fu nodupkey; by id; run;
  
*** Records coming from end of study page;  
data _eos;
  set rawdata.plate049;
  keep id dsyn;
run;

data eos;
  merge _eos (in=a)
        ref_fu (in=b);
  by    id;

  if    dsyn=1 and b then put "ERROR2: " id= dsyn= fumethod=;
  
  if    missing(dsyn) and b then dsyn=2;
  
run;

proc freq data=eos;
  tables dsyn;
run;

data adsl;
  merge dosed (in=a)
        comp  (in=b)
        eos   (in=c);
  by    id;
  
  if    a;
  
  if    complfl='Y' or dsyn=1 then comp06fl='Y';
  else  if dsyn=2 then comp06fl='N';
  
  length usubjid $ 15;
  
  usubjid = catx('-', 'PT010006', put(id, z6.));
run;

proc freq data=adsl;
  tables complfl comp06fl;
run;

proc freq data=anadata.adsl;
  where trtfl='Y';
  tables complfl comp06fl;
run;

proc compare data=adsl
             comp=anadata.adsl;
  where trtfl='Y';
  id    usubjid;
  var   complfl comp06fl;
run;
