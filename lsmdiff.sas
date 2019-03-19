/**SOH*******************************************************************************************
Study #:                        General
Program Name:                   lsmdiff.sas
Purpose:                        To estimate LS means, LS Mean Differences
                                from a repeated measures model using PROC MIXED
Original Author:                Sean Wang
Date Initiated:                 04-Jan-2018
Responsibility Taken Over by:
Date Last Modified:             07-Feb-2018
Reason for Modification:        added option diag= for diagnostic plots
Date Last Modified:             11-Mar-2018
Reason for Modification:        adopt for PT009003
Date Last Modified:             19-Apr-2018
Reason for Modification:        added option outresid
Input data:
Output data:
External macro referenced:
Program Version #:              1.0
Assumptions:                    1) tvar is coded 1,2,...,&ntmt
                                2) visit is numeric (but -3, -2, -1, etc. are reserved for averages)

**EOH*******************************************************************************************/

%macro lsmdiff(
  data=,        /* name of input data set */
  out=,         /* name of output data set for display */
  outlsm=,      /* name of output data set for LS Means */
  outlsmdiff=,  /* name of output data set for LS Mean Differences */
  outresid=,    /* name of output data set for residuals */
  classvar=,    /* list of categorical variable specifications in the CLASS statement */
  byvar=,       /* list of by-group processing variable(s) */
  tvar=TRT01PN, /* name of the treatment variable */
  visit=AVISITN,/* name of the visit variable */
  keyvar=USUBJID,/*name of key variable */
  depvar=CHG,   /* name of the dependent variable */
  base=BASE,    /* name of the baseline variable */
  indepvar=,    /* list of effects on the right hand side of MODEL statement */
  reduced=%nrstr(&trtn | AVISITN),
                /* list of effects on the right hand side of reduced model */
  modelopt=%nrstr(ddfm=kr alpha=&alpha %sysfunc(ifc(&diag,vciry,))),
                /* Options for the MODEL statement */
  mixedopt=noclprint /*plots(maxpoints=none all)*/,
                /* Options for the PROC MIXED statement */
  repeated=%str(repeated AVISITN / type=un subject=usubjid),
                /* Repeated statement */
  om=,          /* OBSMARGIN option for the LSMEANS statement over selected visits */
  feed=0,       /* Pre-estimate covariance matrix using a reduced model or not*/
  diag=0,       /* Dispaly diagnostic plots or not */
  ntmt=3,       /* # of treatments */
  vlist=4 5 6 | 4 5 6 7 8 9,
                /* |-separated lists of selected visits to be averaged */
  alpha=0.05,   /* level of significance */
  nfmt=3.,      /* display format for n */
  meanfmt=7.3,  /* display format for mean */
  stdfmt=7.3,   /* display format for std dev */
  medianfmt=7.3,/* display format for median */
  minfmt=7.3,   /* display format for min */
  maxfmt=7.3,   /* display format for max */
  lsmfmt=7.3,   /* display format for LS means */
  lsmlfmt=6.3,  /* display format for the lower limit of LS means */
  lsmufmt=7.3,  /* display format for the upper limit of LS means */
  lsmsefmt=8.4, /* display format for the SE of LS means */
  lsmdfmt=7.3,    /* display format for LS mean differences */
  lsmdlfmt=6.3, /* display format for the lower limit of LS mean differences */
  lsmdufmt=7.3, /* display format for the upper limit of LS mean differences */
  lsmdsefmt=8.4,  /* display format for the SE of LS mean differences */
  pvalfmt=pvalue8.4
                /* display format for the p-values */
);
  %local i j;
  %local dsnames;
  %local nvlist weights;
  %let nvlist = %sysfunc(countw(&vlist,|));
  %do i=1 %to &nvlist;
    %let weights = &weights wgt&i;
  %end;
  %let dsnames = eff1 univbase univchg univall &weights outcov outmean outdiff outpred;
  %do i=1 %to %sysfunc(countw(&dsnames));
    %local %scan(&dsnames,&i);
    data;stop;run;  %let %scan(&dsnames,&i)=%scan(&syslast,-1,.);
  %end;

  %*prepare data for the summary statistics;
  data &eff1;
    set &data;
    _&visit=&visit;
    output;       *individual visits;
    %do i=1 %to &nvlist;
    if &visit in (%scan(&vlist,&i,|)) then do;
      _&visit=%eval(&i-2-&nvlist);    *selected visits;
      output;
    end;
    %end;
    _&visit=-1;   *all visits;
    output;
    drop &visit;
    rename _&visit=&visit;
  run;
  proc sort data=&eff1 nodupkey;
    by &byvar &visit &tvar &keyvar;
  run;

  %* univariate statistics;
  %macro univ(
    data=,
    byvar=,
    var=,
    out=
  );
    %local univ;
    data;stop;run;  %let univ = %scan(&syslast,-1,.);
    proc means data=&data noprint n mean median std min max;
      by &byvar;
      var &var;
      output out=&univ n=n mean=mean median=median std=sd min=min max=max;
    run;

    data &univ;
      set &univ;
      length stat1-stat5 $20;
      stat1 = put(n, &nfmt);
      stat2 = put(mean,&meanfmt);
      stat3 = put(sd, &stdfmt);
      stat4 = put(median,&medianfmt);
      stat5 = put(min,&minfmt)||'-'||left(put(max,&maxfmt));
    run;

    proc transpose data=&univ out=&out(rename=(col1=&var));
      by &byvar;
      var stat:;
    run;
    proc datasets nolist;
      delete &univ;
    quit;
  %mend univ;

  %*summarize base / chg;
  %univ(data=&eff1, byvar=&byvar &visit &tvar, var=&base, out=&univbase);
  %univ(data=&eff1(where=(&visit>=0)), byvar=&byvar &visit &tvar, var=&depvar, out=&univchg);

  data &univall;
    merge &univbase &univchg;
    by &byvar &visit &tvar _NAME_;
    &base = prxchange('s/(?<!\d)\-(0(\.0+)?)(?!\.|\d)/ $1/', -1, &base);  %* change -0.000 to 0.000;
    &depvar = prxchange('s/(?<!\d)\-(0(\.0+)?)(?!\.|\d)/ $1/', -1, &depvar);%* change -0.000 to 0.000;
  run;

  %*marginal weights;
  %if %sysevalf(%superq(om)=, boolean) %then %do;
    %do i=1 %to &nvlist;
      proc means data=&eff1(keep=&byvar &classvar) noprint nway completetypes;
        by &byvar;
        class &classvar;
        output out=&&wgt&i(drop=_type_ _freq_ where=(&visit in (%scan(&vlist, &i, |))));
      run;
    %end;
  %end;

  * fit the model;
  %if &feed %then %do;
  ods select none;
  proc mixed data=&eff1 noclprint;
    where &visit>=0;
    ods output CovParms=&outcov;
    by &byvar;
    class &classvar;
    model &depvar = %unquote(&reduced);
    &repeated;
  run;
  ods select all;
  %end;
  %if &diag %then ods graphics on;;
  proc mixed data=&eff1 %unquote(&mixedopt);
    where &visit>=0;
    ods output LSMEANS=&outmean DIFFS=&outdiff;
    by &byvar;
    class &classvar;
    model &depvar = &indepvar / %unquote(&modelopt) %if &diag %then outp=&outpred;;
    &repeated;
    %if &feed %then %do; parms / parmsdata=&outcov; %end;
    LSMEANS &tvar*&visit / cl pdiff alpha=&alpha;     %*LS Mean for each individual visits;
    LSMEAN &tvar / cl pdiff alpha=&alpha;              %*LS Mean Over all visits;
    %do i=1 %to &nvlist;
    LSMEAN &tvar / %if %sysevalf(%superq(om) ne, boolean) %then %scan(&om,&i); %else om=&&wgt&i;
                   e cl pdiff alpha=&alpha;     %*LS Mean Over selected visits;
    %end;
  run;
  %if %sysevalf(%superq(outresid) ne, boolean) %then %do;
    data &outresid;
      set &outpred;
    run;
  %end;
  %*reshape LS Means;
  data &outmean;
    set &outmean;
    if missing(&visit) then do;
      if Margins='Balanced' then &visit=-1;
      else do;
        %do i=1 %to &nvlist;
          if
          %if %sysevalf(%superq(om) ne, boolean) %then %do;
            %let j = %upcase(%scan(&om, &i));
            Margins in ("&j" "WORK.&j")
          %end;
          %else %do;
            Margins="WORK.&&wgt&i"
          %end;
          then &visit=%eval(-&nvlist+&i-2);
        %end;
      end;
    end;
    length LSMEAN $ 50;
    LSMEAN = put(Estimate, &lsmfmt) || ' (' || strip(put(StdErr, &lsmsefmt)) || ')@('
            || put(Lower, &lsmlfmt) || ', ' || put(upper, &lsmufmt) || ')';
    LSMEAN = prxchange('s/\-(0\.0+\D)/ $1/', -1, LSMEAN); %* change -0.000 to 0.000;
    LSMEAN = prxchange('s/(\()( +)/$2$1/', -1, LSMEAN); %* flip the left ( and the extra blanks before lower CI;
    LSMEAN = prxchange('s/(?<=\, ) +(?=\d|\-)//', -1, LSMEAN);  %* truncate the extra space between Lower/Upper CI;
  run;

  proc sort data=&outmean;
    by &byvar &visit &tvar;
  run;

  %*output ls means numeric values;
  %if %sysevalf(%superq(outlsm) ne, boolean) %then %do;
    data &outlsm;
      set &outmean(drop=LSMEAN);
    run;
  %end;

  %*reshape LS Mean Differences;
  data &outdiff;
    set &outdiff;
    where &visit=_&visit;
    if missing(&visit) then do;
      if Margins='Balanced' then &visit=-1;
      else do;
        %do i=1 %to &nvlist;
          if
          %if %sysevalf(%superq(om) ne, boolean) %then %do;
            %let j = %upcase(%scan(&om, &i));
            Margins in ("&j" "WORK.&j")
          %end;
          %else %do;
            Margins="WORK.&&wgt&i"
          %end;
          then &visit=%eval(-&nvlist+&i-2);
        %end;
      end;
    end;
    length LSMDIFF $ 50;
    LSMDIFF = put(Estimate, &lsmdfmt) || ' (' || strip(put(StdErr, &lsmdsefmt)) || ')@('
            || put(Lower, &lsmdlfmt) || ', ' || put(upper, &lsmdufmt) || ')@'
            || put(ProbT, &pvalfmt);
    LSMDIFF = prxchange('s/\-(0\.0+\D)/ $1/', -1, LSMDIFF); %* change -0.000 to 0.000;
    LSMDIFF = prxchange('s/(\()( +)/$2$1/', -1, LSMDIFF); %* flip the left ( and the extra blanks before lower CI;
    LSMDIFF = prxchange('s/(?<=\, ) +(?=\d|\-)//', -1, LSMDIFF);  %* truncate the extra space between Lower/Upper CI;
    LSMDIFF = prxchange('s/ \<(\.0+1)(?!\d)/<0$1/', 1, LSMDIFF);  %* replace p-value <.0001 with <0.0001;
  run;

  proc sort data=&outdiff;
    by &byvar &visit &tvar _&tvar;
  run;

  %if %sysevalf(%superq(outlsmdiff) ne, boolean) %then %do;
    data &outlsmdiff;
      set &outdiff(drop=LSMDIFF _&visit effect);
    run;
  %end;

  proc transpose data=&outdiff out=&outdiff(drop=_NAME_) prefix=LSMDIFF;
    by &byvar &visit &tvar;
    id _&tvar;
    var LSMDIFF;
  run;

  %*Combine LS means, LS mean differences;
  data &outdiff;
    merge &outmean &outdiff;
    by &byvar &visit &tvar;
    array _L[*] LSMEAN LSMDIFF2-LSMDIFF&ntmt;
    array _o[*] $20. _1-_&ntmt;
    do i=2 to dim(_L);  %* hide a few differences from display;
      if i=&tvar then _L[i] = 'Not Applicable';
      else if i<&tvar then _L[i] = 'Shown Above';
      else if missing(_L[i]) then put _all_;
    end;
    %* break into 3 rows for backward compatibility;
    do i=6 to 8;
      _NAME_='stat' || put(i, 1.);
      do j=1 to dim(_L);
        _o[j] = scan(_l[j], i-5, '@');
      end;
      output;
    end;
    keep &byvar &visit &tvar _NAME_ _1-_&ntmt;
  run;

  %*stack summary statistics on top of LS Means and mean differences;
  data &out;
    set &univall(in=in1) &outdiff;
    by &byvar &visit &tvar;

    if first.&visit then do;
      _n=0;
      _n1 + 10;
    end;
    if first.&tvar then _n+1;
    _page = ceil(_N/2);
    pg = _n1+_page;
    if not in1 then &depvar=_1; %* display LS means in the &depvar summary column;

    drop _1 _N _n1;
  run;

  %exit:
  proc datasets nolist;
    delete %do i=1 %to %sysfunc(countw(&dsnames));  %let j = %scan(&dsnames,&i);  &&&j %end;;
  quit;
%mend lsmdiff;
