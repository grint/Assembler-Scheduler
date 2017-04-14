signal void txt (void) { 
int i; 
i=0; 
printf("OS 1w \n"); 
while (i<30) { 
  twatch(CLOCK); 
  if (Ri0==0) { 
    printf("%i \n",i); 
    if (i==0) s0in = 'x' ;
    if (i==1) s0in = '1' ; 
    if (i==2) s0in = 'b' ;  
    if (i==3) s0in = 'x' ;  
    if (i==4) s0in = '0' ;
    if (i==5) s0in = 'c' ;  
    if (i==6) s0in = '2' ;  
    if (i==7) s0in = 'b' ;    
    if (i==9) s0in = '3' ;  
    if (i==15) s0in = 'c' ;
    if (i==16) s0in = 'b' ;  
    if (i==19) s0in = '4' ; 
    if (i==24) s0in = 'c' ;  

    i++; 
    } 
  } 
  printf("fertig \n");
} 
 
SLOG > os1w.dat
txt() 

