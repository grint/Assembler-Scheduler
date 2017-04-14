signal void txt (void) { 
int i; 
i=0; 
printf("OS 2 w \n"); 
while (i<30) { 
  twatch(CLOCK); 
  if (Ri0==0) { 
    printf("%i \n",i); 
    if (i==0) s0in = 'x' ;
    if (i==1) s0in = '9' ; 
    if (i==2) s0in = 'b' ;  
    if (i==3) s0in = 'x' ;  
    if (i==9) s0in = '8' ;  
    if (i==19) s0in = 'b' ;  
    if (i==20) s0in = 'b' ;  
    if (i==22) s0in = '1' ;  
    if (i==25) s0in = 'c' ;  
    if (i==26) s0in = 'c' ;  
    if (i==27) s0in = '2' ;  

    i++; 
    } 
  } 
  printf("fertig \n");
} 
 
SLOG > os2w.dat
txt() 

