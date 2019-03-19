/**SOH*******************************************************************************************
Study #:                        General
Program Name:                   ratediff.sas
Purpose:                        To estimate event rates for each treatment and rate ratios/differences
                                between treatment using Poisson or negative binomial regression;
Original Author:                Sean Wang
Date Initiated:                 06-Jan-2018
Responsibility Taken Over by:
Date Last Modified:             14-Mar-2018
Reason for Modification:        updated default values of ntmt to 3 for study PT009003
Date Last Modified:             23-Apr-2018
Reason for Modification:        Suppressed one-sided p-values
Date Last Modified:             07-Jun-2018
Reason for Modification:        to compute total exposure
Input data:
Output data:
External macro referenced:
Program Version #:              1.0
Assumptions:                    1) tvar is coded as 1,2,...,&ntmt
**EOH*******************************************************************************************/

%macro ratediff(
  data=,      /* name of input data set */
  out=,       /* name of output data set */
  classvar=,  /* list of categorical variable specifications in the CLASS statement */
  tvar=,      /* name of the treatment variable */
  countvar=,  /* name of the dependent variable: count of events */
  expvar=,    /* name of the exposure variable (converted in the time unit to be reported) */
  indepvar=,  /* list of independent variables to the right hand side of MODEL statement in PROC GENMOD */
  offset=lexp,/* name of exposure variable */
  modelopt=%nrstr(offset=lexp link=log dist=&dist alpha=&alpha),
              /* Options for the MODEL statement in PROC GENMOD */
  nlmixedopt=%nrstr(data=&data alpha=&alpha),
              /* options for PROC NLMIXED */
  dist=negbin,/* distribution, negbin or poisson */
  om=%nrstr(om=&data),
              /* OBSMARGIN for the LSMEANS statement in PROC GENMOD */
  alpha=0.05, /* level of significance */
  where=,     /* subset for model */
  ntmt=3,     /* # of treatments */
  nfmt=3.,    /* display format for n */
  expfmt=6.2, /* display format for total exposure */
  pctfmt=5.1, /* display format for % of subjects w/ event */
  rfmt=6.2,   /* display format for the unadjusted rate */
  arfmt=6.2,  /* display format for the adjusted rates */
  rsefmt=7.3, /* display format for the SE of rate */
  rlfmt=5.2,  /* display format for the lower limit of rate differences */
  rufmt=6.2,  /* display format for the upper limit of rate differences */
  pvalfmt=pvalue9.4
              /* display format for the p-value of odds ratios */
);
  %local i j;
  %local dsnames;
  %let dsnames = outN outlsm outlsmdiff outcoef outpe outratediff outpe1;
  %do i=1 %to %sysfunc(countw(&dsnames));
    %local %scan(&dsnames,&i);
    data;stop;run;  %let %scan(&dsnames,&i)=%scan(&syslast,-1,.);
  %end;

  *Raw rates;
  proc sql;
    create table &outN as
      select &tvar, count(*) as _N, sum(&countvar>0) as nsubj, sum(&countvar) as nevent, sum(&expvar) as exptot
      from &data
      group by &tvar;
  quit;

  data &outN;
    set &outN;
    length col $ 100;
    ord=0;  %* # of subjects at risk;
    col = put(_N, &nfmt.);
    output;
    ord=1;  %* # of subjects w/ events (% subjects w/ events) [# of events];
    col = put(nsubj,&nfmt)||' ('|| strip(put(nsubj/_N*100, &pctfmt.)) || ')@     ['|| strip(put(nevent,best.)) ||']';
    output;
    ord=2;  %* total # of expsure;
    col = put(exptot, &expfmt.);
    output;
    ord=3;  %* expected # of events per unit time;
    col = put(nevent/exptot, &rfmt.);
    output;
  run;
  proc sort data=&outN;
    by ord;
  proc transpose data=&outN out=&outN(drop=_name_) prefix=_;
    by ord;
    id &trtn;
    var col;
  run;

  *adjusted rates;
  proc genmod data=&data;
    %if %sysevalf(%superq(where) ne, boolean) %then where &where;;
    ods output LSMeans = &outlsm Diffs=&outlsmdiff Coef=&outcoef ParameterEstimates=&outpe;
    class &classvar;
    model &countvar = &indepvar / %unquote(&modelopt);
    lsmeans &tvar / %unquote(&om) e diff cl ilink;
  run;

  %*prepare parameter names, initial values, and linear combinatons to be estimated for NLMIXED;
  data &outpe1;
    merge &outpe(keep=Parameter LEVEL1 Estimate Df where=(Parameter^='Scale')) &outcoef(drop=Parameter);
    if df>0;
  run;

  data &outpe1;
    set &outpe1 end=eof;
    where parameter ne 'Dispersion';

    length modelstr $ 32767;
    retain modelstr;
    array lin[&ntmt] $1024. _temporary_;
    array c[&ntmt] row1-row&ntmt;

    length beta $ 32;
    beta=cats('b', _N_-1);
    if LEVEL1 ne ' ' then do;
      if vtypex(parameter)='C' then var = cats('(', parameter, '="', vvaluex(parameter), '")');
      else if vtypex(parameter)='N' then var = cats('(', parameter, '=', vvaluex(parameter), ')');
    end;
    else if Parameter = 'Intercept' then var=' ';
    else var = Parameter;

    modelstr = catx(' + ', modelstr, catx('*', beta, var)); %* the linear expression for NLMIXED;
    do i=1 to dim(lin);
      if c[i] = 1 then lin[i] = catx(' + ', lin[i], beta);
      else if c[i] ^= 0 then lin[i] = catx(' + ', lin[i], catx('*', beta, c[i]));
    end;
    output;
    if eof then do;
      call symputx('modelstr', modelstr);
      do i=1 to dim(lin);
        call symputx(cats('lincom',i), lin[i]);
      end;
      %if %lowcase(&dist) = negbin %then %do; %* overdispersion paramter for negative binomial only;
        set &outpe(keep=parameter estimate where=(parameter='Dispersion'));
        beta='k';
        output;
      %end;
    end;
    keep beta estimate;
    rename beta=parameter;
  run;
  /*
  Estimating rate differences (with confidence interval) using a Poisson model
  http://support.sas.com/kb/37/344.html
  The idea is similar even though we're using negative binomial regression
  */
  title2;
  proc nlmixed %unquote(&nlmixedopt);
    ods output AdditionalEstimates=&outratediff;
    %if %sysevalf(%superq(where) ne, boolean) %then where &where;;
    parms /data=&outpe1;

    eta=&modelstr %if %sysevalf(%superq(offset) ne, boolean) %then +&offset;;
    p = %if %lowcase(&dist)=negbin %then 1/(1+exp(eta)*k); %else exp(eta);;
    model &countvar ~ %if %lowcase(&dist)=negbin %then negbin(1/k,p); %else poisson(p);;
    %do i=1 %to &ntmt;
      estimate "&i" exp(&&lincom&i);
      %do j=%eval(&i+1) %to &ntmt;
        estimate "&i vs. &j" exp(&&lincom&i) - exp(&&lincom&j);
      %end;
    %end;
  run;

  *transpose rates w/ SE estimated from PROC GENMOD;
  data &outlsm;
    set &outlsm;
    retain ord 4;
    rate = exp(estimate);
    ratese = exp(estimate)*stderr;
    _r = put(rate, &arfmt) || ' (' || strip(put(ratese, &rsefmt)) || ')';
  run;

  proc transpose data=&outlsm out=&outlsm(drop=_name_) prefix=_;
    by ord;
    id &tvar;
    var _r;
  run;

  *Dispersion parameter w/ SE, negative binomial regression only;
  data &outpe;
    set &outpe;
    where Parameter='Dispersion';
    retain ord 5;
    _1 = put(estimate, &arfmt.) || ' (' || put(stderr, &rsefmt.) || ')@ ('
            || put(lowerwaldcl, &rlfmt.) || ', ' || put(upperwaldcl, &rufmt.) || ')';
    _1 = prxchange('s/(\()( +)/$2$1/', -1, _1); %* flip the left ( and the extra blanks before lower CI;
    _1 = prxchange('s/(?<=\, |\d ) +(?=\d|\-|\()//', -1, _1); %* truncate the extra blanks between Lower/Upper CI;
  keep ord _1;
  run;

  *Rate Ratios w/ SE & CI & p-values;
  data &outlsmdiff;
    set &outlsmdiff;
    retain ord 6;

    col = put(exp(Estimate), &arfmt) || ' (' || put(exp(Estimate)*StdErr, &rsefmt) || ')@('
           || put(exp(Lower), &rlfmt) || ', ' || put(exp(Upper), &rufmt) || ')@'
           || put(ProbZ, &pvalfmt);
           *|| '(' || put(probnorm(zvalue), &pvalfmt) || ')';
    col = prxchange('s/(\()( +)/$2$1/', -1, col); %* flip the left ( and the extra blanks before lower CI;
    col = prxchange('s/(?<=\, |\d ) +(?=\d|\-|\()//', -1, col); %* truncate the extra blanks between Lower/Upper CI;
  run;

  proc transpose data=&outlsmdiff out=&outlsmdiff(drop=_name_) prefix=_;
    by ord &tvar;
    id _&tvar;
    var col;
  run;

  *Rate Differences w/ SE & CI & p-values;
  data &outratediff;
    set &outratediff;
    where countw(Label)>1;
    retain ord 7;
    &tvar = input(scan(Label,1,' '), best.);
    _&tvar= input(scan(Label,-1,' '), best.);
    col = put(Estimate, &arfmt) || ' (' || put(StandardError, &rsefmt) || ')@('
            || put(Lower, &rlfmt) || ', ' || put(Upper, &rufmt) || ')';
    col = prxchange('s/\-(0\.0+\D)/ $1/', -1, col); %* change -0.0+ to 0.0+;
    col = prxchange('s/(\()( +)/$2$1/', -1, col); %* flip the left ( and the extra blanks before lower CI;
    col = prxchange('s/(?<=\, |\d ) +(?=\d|\-|\()//', -1, col); %* truncate the extra blanks between Lower/Upper CI;
  run;
  proc transpose data=&outratediff out=&outratediff(drop=_name_) prefix=_;
    by ord &tvar;
    id _&tvar;
    var col;
  run;

  *stack together;
  data &out;
    retain ord . &tvar .;
    array _r[*] $100. _1-_&ntmt;
    set &outN &outlsm &outpe &outlsmdiff(in=inrr) &outratediff(in=indiff);
    if inrr or indiff then do i=1 to dim(_r);
      if i=&tvar then _r[i] = 'Not Applicable';
      else if i<&tvar then _r[i] = 'Shown Above';
    end;
    drop i;
  run;

  %exit:
  proc datasets nolist;
    delete %do i=1 %to %sysfunc(countw(&dsnames));  %let j = %scan(&dsnames,&i);  &&&j %end;;
  quit;
%mend ratediff;
