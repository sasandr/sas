/**SOH***********************************************************************************
Study #:                        Utility
Program Name:                   aecount.sas
Purpose:                        To create utility program for count adverse events
Original Author:                Chelsea Chen
Date Initiated:                 01-Jul-2020
Responsibility Taken Over by:   
Date Last Modified:             
Reason for Modification:  
Input data:                                                     
Output data:            
External macro referenced:      
SAS Version:                    V9.4
Program Version #:              1.0
**EOH***********************************************************************************/

%macro aecount(indsn=,                  /* Input dataset */
               outdsn=,                 /* Output dataset */
               grpn=,                   /* Grouping variable, usually treatment, as displayed in table columns */
               byvar=,                  /* By variable, usually missing for overall, then by SOC/PT */
               dup=,                    /* Set to dup=nodupkdy to remove records with duplicate keys, usually when counting subjects */
               max=N,                   /* Toggle N/Y to keep maxinum (usu. grade) when removing duplicates */
               last=usubjid,            /* Last key variable when removing duplicates */
               xord=,                   /* Ordering variable 1 */
               yord=);                  /* Ordering variable 2 */

  %local dsnames;
  %let   dsnames = coded count;
  
  %do i=1 %to %sysfunc(countw(&dsnames));
    %local %scan(&dsnames,&i);
    data;stop;run;  %let %scan(&dsnames,&i)=%scan(&syslast,-1,.);
  %end; 
              
  %if &max=Y %then %do;
    proc sort data=&indsn out=&coded;
      by usubjid &byvar;
    run;

    data &coded;
      set &coded;
      by usubjid &byvar;
      if last.&last;
    run;
  %end;  
  %else %do;
    proc sort data=&indsn out=&coded &dup;
      by usubjid &grpn &byvar;
    run;
  %end;

  %if &byvar= %then %do;
    proc freq data=&coded noprint;
     table &grpn / out=&count(drop=percent);
    run;
  %end;
  %else  %do;
    proc sort data=&coded;
      by &byvar;
    run;

    proc freq data=&coded noprint;
      table &grpn / out=&count(drop=percent);
      by    &byvar;
    run;
  %end;
   
  data &outdsn;
    set &count;
    %if %sysevalf(%superq(xord) ne, boolean) %then xord=&xord;;
    %if %sysevalf(%superq(yord) ne, boolean) %then yord=&yord;;
  run;
  
  proc datasets nolist;
    delete %do i=1 %to %sysfunc(countw(&dsnames));  %let j = %scan(&dsnames,&i);  &&&j %end;;
  quit;
   
%mend aecount;
