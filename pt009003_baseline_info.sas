proc format;
  value trtn
        1 = "BFF MDI 320/9.6 µg"
        2 = "BFF MDI 160/9.6 µg"
        3 = "FF MDI 9.6 µg ";
        
  value count
        . = '0 exacerbations'
        1 = '1 exacerbation'
        2-high = '>=2 exacerbations';
run;

data copdhx;
  set rawdata.plate007 (keep=id hxcopdex copdexnu copdhosp copdexhs);
  length subjid $ 6;
  
  subjid = put(id, z6.);
run;

data copdhx;
  merge copdhx (in=a)
        anadata.adsl (keep=subjid trt01pn mittfl where=(mittfl='Y') in=b);
  by    subjid;
  
  if    a and b;
run;

proc freq data=copdhx;
  format copdexnu copdexhs count.;
  tables copdexnu /list missing;
  table  copdhosp * copdexhs / list missing;
run;
 
title "Baseline history of severe exacerbation, n(%)";
proc tabulate data=copdhx missing noseps;
  format  trt01pn trtn. copdexhs count.;
  class   trt01pn copdexhs;
  table   (copdexhs='COPDx Hx') ,
          (trt01pn=' ' all) * (n='n'*f=4.0 colpctn='%'*f=5.1)/rts=40 row=float;
run;  

title "Baseline history of M/S exacerbation, n(%)";
proc tabulate data=copdhx missing noseps;
  format  trt01pn trtn. copdexnu count.;
  class   trt01pn copdexnu;
  table   (copdexnu='M/S COPDx Hx') ,
          (trt01pn=' ' all) * (n='n'*f=4.0 colpctn='%'*f=5.1)/rts=40 row=float;
run;  
endsas;

proc sort data=anadata.adresmem out=resmem nodupkey;
  where paramcd='MDDOSE' and cmiss(base, aval, chg, fev1, baseeos, pvrev)=0 and mittfl='Y';
  by usubjid;
run;

title "Mean (SD) rescue medication use, puffs/day";
proc tabulate data=resmem noseps missing;
  format  trt01pn trtn.;
  class   trt01pn;
  var     base;
  table   (base='Baseline') * (n='n'*f=10.0 mean*f=11.1 std*f=11.1),
          (trt01pn=' ' all)/rts=40 row=float;
run;

proc sort data=anadata.adsgrqm out=sgrqm nodupkey;
  where paramcd='SGRQTOT' and cmiss(base, aval, chg, fev1post, baseeos, pvrev, icsuse)=0 and mittfl='Y' and anl01fl='Y';
  by usubjid;
run;

title "Mean (SD) SGRQ total score";
proc tabulate data=sgrqm noseps missing;
  format  trt01pn trtn.;  
  class   trt01pn;
  var     base;
  table   (base='Baseline') * (n='n'*f=10.0 mean*f=11.1 std*f=11.1),
          (trt01pn=' ' all)/rts=40 row=float;
run;
