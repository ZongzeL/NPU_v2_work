#NPUv2_256 additional pins
#FMC1_LPC_LA25_P
set_property PACKAGE_PIN C15     [get_ports ADDR[8]];
set_property IOSTANDARD LVCMOS25 [get_ports ADDR[8]];
#FMC1_LPC_LA25_N
set_property PACKAGE_PIN B15     [get_ports DINSWREG[1]];
set_property IOSTANDARD LVCMOS25 [get_ports DINSWREG[1]];
#FMC1_LPC_LA29_P
set_property PACKAGE_PIN B16     [get_ports DINSWREG[2]];
set_property IOSTANDARD LVCMOS25 [get_ports DINSWREG[2]];
#FMC1_LPC_LA29_N
set_property PACKAGE_PIN B17     [get_ports DINSWREG[3]];
set_property IOSTANDARD LVCMOS25 [get_ports DINSWREG[3]];
#FMC1_LPC_LA31_P
set_property PACKAGE_PIN A16     [get_ports CLKREG[1]];
set_property IOSTANDARD LVCMOS25 [get_ports CLKREG[1]];
#FMC1_LPC_LA31_N
set_property PACKAGE_PIN A17     [get_ports CLKREG[2]];
set_property IOSTANDARD LVCMOS25 [get_ports CLKREG[2]];
#FMC1_LPC_LA33_P
set_property PACKAGE_PIN A18     [get_ports CLKREG[3]];
set_property IOSTANDARD LVCMOS25 [get_ports CLKREG[3]];

#J1
#1 FMC1_LPC_LA00_CC_P
set_property PACKAGE_PIN K19     [get_ports ADDR[7]];                
set_property IOSTANDARD LVCMOS25 [get_ports ADDR[7]];    

#2 FMC1_LPC_LA10_P #3 FMC1_LPC_LA00_CC_N
set_property PACKAGE_PIN K20     [get_ports ADDR[6]];          
set_property IOSTANDARD LVCMOS25 [get_ports ADDR[6]];   

#3 FMC1_LPC_LA00_CC_N #5 FMC1_LPC_LA01_CC_P
set_property PACKAGE_PIN N19     [get_ports ADDR[5]];  
set_property IOSTANDARD LVCMOS25 [get_ports ADDR[5]];   

#4 FMC1_LPC_LA10_N #7 FMC1_LPC_LA01_CC_N
set_property PACKAGE_PIN N20     [get_ports ADDR[4]];  
set_property IOSTANDARD LVCMOS25 [get_ports ADDR[4]];   

#9 FMC1_LPC_LA02_P
set_property PACKAGE_PIN L21     [get_ports ADDR[3]];    
set_property IOSTANDARD LVCMOS25 [get_ports ADDR[3]];    

#11 FMC1_LPC_LA02_N
set_property PACKAGE_PIN L22     [get_ports ADDR[2]];       
set_property IOSTANDARD LVCMOS25 [get_ports ADDR[2]];     

#13 FMC1_LPC_LA03_P
set_property PACKAGE_PIN J20     [get_ports ADDR[1]];         
set_property IOSTANDARD LVCMOS25 [get_ports ADDR[1]];

#15 FMC1_LPC_LA03_N
set_property PACKAGE_PIN K21     [get_ports ADDR[0]];                 
set_property IOSTANDARD LVCMOS25 [get_ports ADDR[0]];      

#17 FMC1_LPC_LA04_P
set_property PACKAGE_PIN M21     [get_ports DACBL_SW];                   
set_property IOSTANDARD LVCMOS25 [get_ports DACBL_SW];        

#19 FMC1_LPC_LA04_N (DACBL_SW2)
set_property PACKAGE_PIN M22     [get_ports DACBL_SW2];                  
set_property IOSTANDARD LVCMOS25 [get_ports DACBL_SW2];       

#21 FMC1_LPC_LA05_P
set_property PACKAGE_PIN N17     [get_ports DACSEL_SW];                  
set_property IOSTANDARD LVCMOS25 [get_ports DACSEL_SW];       

#23 FMC1_LPC_LA05_N
set_property PACKAGE_PIN N18     [get_ports DACWL_SW];                 
set_property IOSTANDARD LVCMOS25 [get_ports DACWL_SW];        

#25 FMC1_LPC_LA06_P
set_property PACKAGE_PIN J18     [get_ports DACWLREFSW];                    
set_property IOSTANDARD LVCMOS25 [get_ports DACWLREFSW];     

#27 FMC1_LPC_LA06_N (DINREG)
set_property PACKAGE_PIN K18     [get_ports DINSWREG[0]];                     
set_property IOSTANDARD LVCMOS25 [get_ports DINSWREG[0]];        

#29 FMC1_LPC_LA07_P
set_property PACKAGE_PIN J15     [get_ports CLKREG[0]];                          
set_property IOSTANDARD LVCMOS25 [get_ports CLKREG[0]];       

#31 FMC1_LPC_LA07_N
set_property PACKAGE_PIN K15     [get_ports CLKADCSW];                      
set_property IOSTANDARD LVCMOS25 [get_ports CLKADCSW];      

#33 FMC1_LPC_LA08_P (CLKDAC1)
set_property PACKAGE_PIN J21     [get_ports CLKDAC];                      
set_property IOSTANDARD LVCMOS25 [get_ports CLKDAC];      

#35 FMC1_LPC_LA08_N
set_property PACKAGE_PIN J22     [get_ports CLKADC];                     
set_property IOSTANDARD LVCMOS25 [get_ports CLKADC];       

##37 FMC1_LPC_LA09_P
set_property PACKAGE_PIN M15     [get_ports SET];                          
set_property IOSTANDARD LVCMOS25 [get_ports SET];        

##39 FMC1_LPC_LA09_N
set_property PACKAGE_PIN M16     [get_ports RESET];                            
set_property IOSTANDARD LVCMOS25 [get_ports RESET];       

#02 FMC1_LPC_LA10_P
set_property PACKAGE_PIN L17     [get_ports DIN[7]];                         
set_property IOSTANDARD LVCMOS25 [get_ports DIN[7]];         

#04 FMC1_LPC_LA10_N
set_property PACKAGE_PIN M17     [get_ports DIN[6]];                       
set_property IOSTANDARD LVCMOS25 [get_ports DIN[6]];       

#06 FMC1_LPC_LA11_P
set_property PACKAGE_PIN R20     [get_ports DIN[5]];                          
set_property IOSTANDARD LVCMOS25 [get_ports DIN[5]];       

#08 FMC1_LPC_LA11_N
set_property PACKAGE_PIN R21     [get_ports DIN[4]];                     
set_property IOSTANDARD LVCMOS25 [get_ports DIN[4]];    

#10 FMC1_LPC_LA12_P
set_property PACKAGE_PIN N22     [get_ports DIN[3]];                      
set_property IOSTANDARD LVCMOS25 [get_ports DIN[3]];       

#12 FMC1_LPC_LA12_N
set_property PACKAGE_PIN P22     [get_ports DIN[2]];                      
set_property IOSTANDARD LVCMOS25 [get_ports DIN[2]];       

#14 FMC1_LPC_LA13_P
set_property PACKAGE_PIN P16     [get_ports DIN[1]];                           
set_property IOSTANDARD LVCMOS25 [get_ports DIN[1]];         

#16 FMC1_LPC_LA13_N
set_property PACKAGE_PIN R16     [get_ports DIN[0]];                        
set_property IOSTANDARD LVCMOS25 [get_ports DIN[0]];              

#18 FMC1_LPC_LA14_P
set_property PACKAGE_PIN J16     [get_ports ARST_ENREG];                          
set_property IOSTANDARD LVCMOS25 [get_ports ARST_ENREG];           

#20 FMC1_LPC_LA14_N
set_property PACKAGE_PIN J17     [get_ports ARST_WLREG];                             
set_property IOSTANDARD LVCMOS25 [get_ports ARST_WLREG];            

#22 FMC1_LPC_LA15_P
set_property PACKAGE_PIN P20     [get_ports ASET_ENREG];                            
set_property IOSTANDARD LVCMOS25 [get_ports ASET_ENREG];                

#24 FMC1_LPC_LA15_N
set_property PACKAGE_PIN P21     [get_ports ASET_WLREG];                             
set_property IOSTANDARD LVCMOS25 [get_ports ASET_WLREG];                     

#28 FMC1_LPC_LA16_N
set_property PACKAGE_PIN P15     [get_ports DISCHG];                                         
set_property IOSTANDARD LVCMOS25 [get_ports DISCHG];           

# J20
# Pin 1 FMC1_LPC_LA20_P
set_property PACKAGE_PIN G20     [get_ports DOUT[5]];
set_property IOSTANDARD LVCMOS25 [get_ports DOUT[5]];

# Pin 3 FMC1_LPC_LA20_N
set_property PACKAGE_PIN G21     [get_ports DOUT[3]];
set_property IOSTANDARD LVCMOS25 [get_ports DOUT[3]]; 

# Pin 5 FMC1_LPC_LA21_P
set_property PACKAGE_PIN F21     [get_ports DOUT[2]];
set_property IOSTANDARD LVCMOS25 [get_ports DOUT[2]]; 

# Pin 7 FMC1_LPC_LA21_N
set_property PACKAGE_PIN F22     [get_ports DOUT[1]];
set_property IOSTANDARD LVCMOS25 [get_ports DOUT[1]]; 

# Pin 9 FMC1_LPC_LA22_P
set_property PACKAGE_PIN G17     [get_ports DOUT[4]];                                         
set_property IOSTANDARD LVCMOS25 [get_ports DOUT[4]]; 

# Pin 11 FMC1_LPC_LA22_N
set_property PACKAGE_PIN F17     [get_ports DOUT[0]];                           
set_property IOSTANDARD LVCMOS25 [get_ports DOUT[0]]; 