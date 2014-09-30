*** Self-defined function to get decimal points;
proc fcmp outlib=work.math.cmp;
  function decN(number $) ;
    /* Return number of REAL decimal places number is collected to */
    length _strNum $100 ;
    _strNum=cats(number) ;
    if ^(missing(_strNum) or anyalpha(_strNum) or indexc(_strNum, '<=>+-')) then _decLoc=findc(_strNum,'.') ;
    return (ifN(_decLoc,length(_strNum)-_decLoc,0,.)) ;
  endsub ;
run;

options cmplib=work.math;
