
// *********************************************************
// SHT xx driver
// by Alexander Yerezeyev, 2007
// e-mail: wapbox@bk.ru
// URL: http://alyer.frihost.net
//
// 
// 	s_write_byte	- write byte in r16 to SHTxx
// 	s_read_byte		- r16 read byte from SHTxx (r16=1 ACK, else noACK)
//  s_transstart	- generates a transmission start
//  s_connectionreset - reset connection
//	
// ********************************************************* 

//******************************************************
// Get Data From sensor and store it in OS format
//	INPUT:	r16 	- 0 TEMP
//					- 1 HUMI
//	OUPUT:
//******************************************************
s_GetData:	
	push r28		// save corrupted registes
	push r27
	push r26
	push r25
	push r24
	push r23
	push r22
	push r21
	push r20
	push r19
	push r18
	push r17	
	push Temp	// save TEMP/RH flag
	clr Temp			
	sts ErrorCnt, Temp	// clear Error counter
	ldi Temp, 1
	rcall s_measure		// read RH data from SHTxx
	rcall CRC_check01	// check CRC
	rcall s_Get_RH		// calculate physical RH%
	clr Temp			
	rcall s_measure		// read RH data from SHTxx
	rcall CRC_check01	// Check CRC

/*
	ldi Temp, 0x0D
	sts pValueH, Temp
	ldi Temp, 0x1B
	sts pValueL, Temp

	ldi Temp, 0x03
	sts pValueH, Temp
	ldi Temp, 0xED
	sts pValueL, Temp
*/
	rcall s_Get_Temp	// calculate physical Temperature	
	ldi Temp, 2
	rcall s_measure		// read Status Register from SHT
	rcall CRC_check02	// Check CRC
	rcall s_Get_Batt	// Get batery status
	lds Temp, ErrorCnt	// Check Error counters
	tst Temp
	breq sGet_noErrors
	ldi Temp, 1				// set Error flag
	rcall s_connectionreset	// reset connection
	// no Errors were occured
sGet_noErrors:
	sts pCommError, Temp	// save Error 
	pop Temp				// restore TEMP/RH flag	
	tst Temp				// compare TEMP/RH flag with 0
	ldi Temp, 0
	sts Flags, Temp			// clear OS Flags 
	brne sGet_process_HUMI	// TEMP/RH <> 0 then process as HUMI DATA
	clr Temp				// else process as TEMP DATA
	rcall OS_prepare		// prepare TEMP data in SRAM for Manchester encoding
	rjmp sGet_exit
sGet_process_HUMI:
	ldi Temp, 1
	rcall OS_prepare		// prepare HUMI data in SRAM for Manchester encoding
sGet_exit:
	rcall Manch_encoder		// Manchester encoding of DATA in TH32, TH1x, CRC-byte		
	pop r17					// restore corrupted registers
	pop r18
	pop r19
	pop r20
	pop r21
	pop r22
	pop r23
	pop r24
	pop r25
	pop r26
	pop r27
	pop r28
	ret




// *********************************************************
// WRITE BYTE to SHTxx
// INPUT: R16 - byte value
// out ErrorCnt=0 if OK
// ErrorCnt++ in case of Error during operation
// *********************************************************
s_write_byte:
	push Temp2
	sbi DDRB,DATA;	// DATA as output  
	sbi DDRB,SCK;	// SCK as output
	mov Temp2, Temp	// Temp2 - Byte Value
	ldi Temp, 8		// 8 Bits to shift
s0_loop1:
	push Temp
	lsl Temp2		// Shift transmitted byte left (Get current bit)
	brcc s0_0		// flag C = current bit
	sbi PORTB, DATA	// set DATA bit if C==1
	rjmp s0_lab0
s0_0:
	cbi PORTB, DATA // clear DATA bit if C==0
s0_lab0:
	ldi Temp,0x02
	rcall delay_Xus // wait 2 us
	sbi PORTB, SCK	// Set SCK
	ldi Temp,0x05	// wait 5 us
	rcall delay_Xus				
	cbi PORTB, SCK	// Clear SCK
	pop Temp		// Restore counter value
	dec Temp		// dec counter
	brne s0_loop1	// repeat loop until counter <>0

	sbi PORTB,DATA; // release DATA-line
	cbi DDRB,DATA; 	// DATA as input
	ldi Temp,0x02
	rcall delay_Xus	// wait 2 us				
	sbi PORTB,SCK;	// clk #9 for ack
	ldi Temp,0x05
	rcall delay_Xus	// pulswith approx. 5 us
	sbis PINB, DATA	// check if DATA is low/
	rjmp s0_OK		// DATA is low - ACK is OK
	rcall ErrorCntInc// else ACK is BAD - increment Error counter
s0_OK:
	cbi PORTB,SCK;	// clear SCK
	pop Temp2		// restore corupted registers
	ret				// return

//************************************************
// ErrorCntIncrementer
//************************************************
ErrorCntInc:
	lds Temp, ErrorCnt
	inc Temp
	sts ErrorCnt, Temp
	ret

//************************************************
// in Temp - us @4MHz
//************************************************
delay_Xus:
	push Temp
delay_X_loop:
	nop
	nop
	nop
	nop
	dec Temp
	brne delay_X_loop
	pop Temp
	ret

// *********************************************************
// READ BYTE from SHTxx
// INPUT: R16 = 1 ACK
//		  R16=0 no ACK 
// out ErrorCnt=0 if OK
// ErrorCnt++ in case of Error during operation
// *********************************************************

s_read_byte:
	push Temp2		// save corrupted register
	push Temp		// - save ACK info
	sbi DDRB, SCK;	// SCK as output
	sbi PORTB,DATA; // release DATA-line
	cbi DDRB,DATA;	// DATA as input
	clr Temp2		// clear Temp2 - input shift register
	ldi Temp, 8		// RX bits counter =8
s1_loop1:
	push Temp		// save counter value
	sbi PORTB, SCK	// Set SCK pin
	ldi Temp, 5		
	rcall delay_Xus	// Delay 5 us	
	sbic PINB, DATA	// if DATA pin ==0 rjmp s1_read0
	rjmp s1_read1	// if DATA pin ==1 rjmp s1_read1
s1_read0:
	clc				// clear C
	rol Temp2		// shift Temp2 <- C
	rjmp s1_lab1	// 0 bit received
s1_read1:
	sec				// set C
	rol Temp2		// shift Temp2 <- C
s1_lab1:			// 1 bit received
	cbi PORTB, SCK	// clear SCk bit (bit received)
	ldi Temp, 1
	rcall delay_Xus	// delay 1 us
	pop Temp		// restore bit counter
	dec Temp		// dec bit counter
	brne s1_loop1	// repeat until 8 bits received
	// now in Temp2 - readed value
	sbi DDRB, DATA	// configure DATA as output
	pop Temp  		// get ACK info
	tst Temp		// check ACK info 
	brne s1_ACK1	//	if <> 0
	sbi PORTB, DATA // if noACK set DATA pin
	rjmp s1_lab2
s1_ACK1:	
	cbi PORTB, DATA	// if ACK clear DATA pin
s1_lab2:
	ldi Temp, 1
	rcall delay_Xus
	sbi PORTB,SCK;	// SCK=1; //clk #9 for ack
	ldi Temp, 5
	rcall delay_Xus	// delay 5 us
	cbi PORTB, SCK	// SCK=0
	cbi DDRB, DATA	// configure DATA as input
	mov Temp, Temp2	// Temp <- received byte
	pop Temp2		// restore corrupted byte
	ret				// return

// *********************************************************
// TRANSMISSION START GENERATOR
//----------------------------------------------------------
// generates a transmission start
// 	_____ 		  ________
// DATA: |_______|
// 			___   ___
// SCK : ___| |___| |______
// *********************************************************
s_transstart:
	push Temp
	sbi DDRB, DATA; //DATA as output  
	sbi DDRB, SCK; //SCK as output 
	sbi PORTB,DATA;//DATA=1;
	cbi PORTB,SCK;// SCK=0; //Initial state
 	ldi Temp, 01
	rcall delay_Xus
	sbi PORTB,SCK;//SCK=1;
	rcall delay_Xus
	cbi PORTB,DATA;//DATA=0;
 	rcall delay_Xus
	cbi PORTB,SCK;//SCK=0;
 	rcall delay_Xus
	sbi PORTB,SCK;//SCK=1;
 	rcall delay_Xus
	sbi PORTB,DATA;//DATA=1;
 	rcall delay_Xus
	cbi PORTB,SCK;//SCK=0;
	pop Temp
	ret

// *********************************************************
// COMMUNICATION RESET
//----------------------------------------------------------------------------------
// communication reset: DATA-line=1 and at least 9 SCK cycles followed by transstart
// _____________________________________________________ ________
// DATA: |_______|
// 			_ 	 _ 	  _    _ 	_ 	 _ 	  _    _ 	_ 		___   ___
// SCK : __| |__| |__| |__| |__| |__| |__| |__| |__| |______| |___| |______
// *********************************************************

s_connectionreset:
	push Temp
	push Temp2

	sbi DDRB,DATA; //DATA as output  
	sbi DDRB, SCK; //SCK as output 
	sbi PORTB,DATA;cbr(PORTD,SCK);//DATA=1; SCK=0; //Initial state

	ldi Temp, 1
	rcall Delay_Xus
	ldi Temp, 9
loop:
	push Temp
	sbi PORTB,SCK;  //SCK=1;
	ldi Temp, 1
  	rcall Delay_Xus
  	cbi PORTB,SCK;  //SCK=0;
  	rcall Delay_Xus
	pop Temp
	dec Temp
	brne loop
	rcall s_transstart
	pop Temp2
	pop Temp
	ret


// ****************************************************************************
//	INPUT: 	r16 	= 0 Temperature measurement
//					= 1 Humidity measurement
//					= 2 Status egister reading
// 	OUTPUT: r16 - 	0 		OK
//					else - Error
//			SRAM:	pValueH	-MSB reading
//					pValueL -LSB reading
//					pCRC	-CRC reading
//					ErrorCnt++ in case of Error during operation
// ****************************************************************************
s_measure:
	push Temp2			// Save corrupted registers
	push Temp3
	rcall s_transstart; // transmission start
	clr Temp3			// Temp3 = 0 RH or TEMP else STATUS_REG
	tst Temp			// test R16
	breq s4_TEMP		// r16 = 0 measure temperature
	cpi Temp, 01		// r16 = 1 measure humidity
	breq s4_HUMI
						// else read status	register		
	ldi Temp3, 01			// Temp3 =1 STATUS_REG
	ldi Temp, STATUS_REG_R	// command code
	sts pCommand, Temp		// save command code
	rcall s_write_byte		// write command to SHT11
	rjmp s4_wait_data		// wait for data ready
	// measure humidity	
s4_HUMI:
	ldi Temp, MEASURE_HUMI  // command code
	sts pCommand, Temp		// save command code
	rcall s_write_byte		// write command to SHT11
	rjmp s4_wait_data		// wait for data ready

	// measure temperature
s4_TEMP:
	ldi Temp, MEASURE_TEMP	// command code
	sts pCommand, Temp		// save command code
	rcall s_write_byte		// write command to SHT11
	rjmp s4_wait_data		// wait for data ready

s4_wait_data:
	ldi Temp, 100			// 100us delay for DATA RAMP
	rcall delay_Xus
	// this loop wait 450 ms until DATA pin became LOW
	ldi Temp2, 1			//set error flag
	ldi Temp, 6
s4_loop1:
	push Temp
	ldi Temp, 255
s4_loop2:
	push Temp	
	ldi Temp, 255
s4_loop3:
	push Temp	
	sbis PINB, DATA			// check DATA state
	rjmp s4_loop_exit		// if LOW exit from loop
	pop Temp
	dec Temp
	brne s4_loop3	
	pop Temp
	dec Temp
	brne s4_loop2
	pop Temp
	dec Temp
	brne s4_loop1
	lds Temp, ErrorCnt
	inc Temp
	sts ErrorCnt, Temp
	rjmp s4_loop_exit2
	// end of DATA wait loop
s4_loop_exit:
	pop Temp
	pop Temp
	pop Temp
	clr Temp2				//clr error flag if DATA setted low in 450ms
s4_loop_exit2:	
	tst Temp3				// check TEMP3
	brne s_read_status_reg	// TEMP3 <> 0 - read status register
	// read measured data
	ldi Temp, 1 			// ACK
	rcall s_read_byte		// read MSB byte
	sts pValueH, Temp		// save MSB byte in SRAM
s_read_status_reg:
	ldi Temp, 1 			// ACK
	rcall s_read_byte		// read LSB byte
	sts pValueL, Temp		// save LSB byte in SRAM
	clr Temp 				// noACK
	rcall s_read_byte		// read CRC
	sts pCRC, Temp			// save CRC in SRAM
	tst Temp2				// read Error flag
	breq s4_exit			
	rcall ErrorCntInc		// if Error <>0 increment of Error counter
s4_exit:	
	pop Temp3				// restore corrupted registers
	pop Temp2
	ret						// return

// **********************************************
// CRC check algorith #1
// CRC calculation of pCommand, pValueH, pValueL and compare with pCRC
// INPUT SRAM:
//	pCommand - command code
//	pValueH	- MSB readout
//	pValueL	- LSB readout
//	pCRC	- CRC readout
// OUTPUT SRAM:
//	CRC_gen - calcualted CRC
// 	if (pCRC)== CRC_gen Temp =  0 else ErroCnt increment
// **********************************************

CRC_check01:
	push Temp2
	clr Temp			// clear CRC
	sts CRC_gen, Temp
	lds Temp, pCommand
	rcall CRC_generator
	sts CRC_gen, Temp
	lds Temp, pValueH
	rcall CRC_generator
	sts CRC_gen, Temp
	lds Temp, pValueL
	rcall CRC_generator
	rcall Byte_Rotator	// reverse calculated CRC
	sts CRC_gen, Temp	// save reversed CRC
	lds Temp2, pCRC
	sub Temp, Temp2
	breq CRC1_OK
	ldi Temp, 1
CRC1_OK:
	lds Temp2, ErrorCnt
	add Temp2, Temp
	sts ErrorCnt, Temp2
	pop Temp2
	ret
// **********************************************
// CRC check algorith#2
// CRC calculation of pCommand, pValueL and compare with pCRC
// INPUT SRAM:
//	pCommand - command code
//	pValueL	- LSB readout
//	pCRC	- CRC readout
// OUTPUT SRAM:
//	CRC_gen - calcualted CRC
// 	if (pCRC)== CRC_gen Temp =  0 else ErroCnt increment
// **********************************************

CRC_check02:
	push Temp2
	clr Temp
	sts CRC_gen, Temp
	lds Temp, pCommand
	rcall CRC_generator
	sts CRC_gen, Temp
	lds Temp, pValueL
	rcall CRC_generator
	rcall Byte_Rotator	// reverse calculated CRC
	sts CRC_gen, Temp
	lds Temp2, pCRC
	sub Temp, Temp2
	breq CRC2_OK
	ldi Temp, 1
CRC2_OK:
	lds Temp2, ErrorCnt
	add Temp2, Temp
	sts ErrorCnt, Temp2
	pop Temp2
	ret


//******************************************************
// CRC linear generator routine
// -----------------------------------------------------
// INPUT: 	Temp	- input Value
//			Temp3	- previous CRC state
// OUPUT:	Temp	- new calculated CRC
//******************************************************

CRC_generator:
	push Temp2
	push Temp3
	mov Temp2, Temp
	///Temp2 - value
	///Temp3 - CRC
	lds Temp3, CRC_gen
	ldi Temp, 8
CRC_loop:
	push Temp
	lsl Temp2
	brcs CRC_bit1
//here when measure bit 7 =0
CRC_bit0:	
	sbrc Temp3, 7
	rjmp CRC_bit01
//here when Mbit7=0 and Cbit7=0
CRC_bit00:	
	lsl Temp3
	rjmp CRC_next_bit	
//here when Mbit7=0 and Cbit7=1
CRC_bit01:
	lsl Temp3
	ldi Temp, 0b00110000
	eor Temp3, Temp
	sbr Temp3, 0b0000001
	rjmp CRC_next_bit			
//here when measure bit 7 =1
CRC_bit1:
	sbrc Temp3, 7
	rjmp CRC_bit11
//here when Mbit7=1 and Cbit7=0
CRC_bit10:
	lsl Temp3
	ldi Temp, 0b00110000
	eor Temp3, Temp
	sbr Temp3, 0b0000001
	rjmp CRC_next_bit			
//here when Mbit7=1 and Cbit7=1	
CRC_bit11:
	lsl Temp3
CRC_next_bit:
	pop Temp
	dec Temp
	brne CRC_loop		
	mov Temp, Temp3
	pop Temp3
	pop Temp2
	ret	


//******************************************************
//OS conversion
//in R16 = 	0 - Temp
//			1 - HUMI
//******************************************************		
OS_prepare:

	tst Temp
	ldi Temp, 0
	sts Flags, Temp
	brne OS_prepare_HUMI	
OS_prepare_TEMP:
	ldi Temp, 0b01001000
	sts Channel, Temp
	lds Temp, pTemp
	andi Temp, 0b00001111
	sts TH2, Temp
	lds Temp, pTemp
	andi Temp, 0b11110000
	swap Temp
	sts TH1, Temp
	lds Temp, pTemp_dec
	andi Temp, 0b11110000
	swap Temp
	sts TH3, Temp
	lds Temp, pTemp_sign
	tst Temp
	breq OS_prepare_Batt
Neg_TEMP:
	lds Temp, Flags
	sbr Temp, (1<<Sign)
	sts Flags, Temp
	rjmp OS_prepare_Batt
OS_prepare_HUMI:
	ldi Temp, 0b00001111
	sts Channel, Temp
	lds Temp, pHUMI
	andi Temp, 0b11110000
	swap Temp
	sts TH1, Temp
	lds Temp, pHUMI
	andi Temp, 0b00001111
	sts TH2, Temp
	lds Temp, pHUMI_dec
	andi Temp, 0b11110000
	swap Temp
	sts TH3, Temp
OS_prepare_Batt:
	lds Temp, pBattery
	tst Temp
	breq OS_prepare_CommError
	lds Temp, Flags
	sbr Temp, (1<<Batt)
	sts Flags, Temp
OS_prepare_CommError:
	lds Temp, pCommError
	tst Temp
	breq OS_prepare_exit
	lds Temp, Flags
	sbr Temp, (1<<ComError)
	sts Flags, Temp
OS_prepare_exit:
	ret

//******************************************************
// Convert RH data to physical value
// INPUT: pValueH, pValue L - MSB and LSB of readout
// OUTPUT: SRAM pHUMI - BCD coded RH% 1st and 2nd digits
//				pHUMI_dec - BCD coded 3d digit
//******************************************************
s_Get_RH:

	lds Temp, pValueH	// Temp = MSB
	lds Temp2, pValueL	// Temp2 = LSB
	push Temp
	push Temp2	
	lsr Temp		//2
	ror Temp2
	lsr Temp		//4
	ror Temp2
	lsr Temp		//8
	ror Temp2
	lsr Temp		//16
	ror Temp2	
	// Temp2 = Readout/16 	
	cpi Temp2, 108
	brlo SO_RH_lo108// branch if (Readout/16)<108 rjmp SO_RH_more108
SO_RH_more108:
//a=111	(Readout/26 > 108)
	//a=111
	ldi r16, 111	
	pop r20			// restore ValueL	
	pop r21			//rstore ValueH
	clr r22
	clr r23
	rcall Mul32b	// r20r21=111*a
//b=2893*16
	ldi r16, 0xD0
	ldi r17, 0xB4
	clr r18
	clr r19
	rcall Add32		//r20r21 = 111*readout+2893*16
	rjmp RH4096_rdy	// RH*4096 is ready
SO_RH_lo108:
//a=143	(Readout/26 <108)
	ldi r16, 143		
	pop r20			// restore ValueL	
	pop r21			//rstore ValueH
	clr r22
	clr r23
	rcall Mul32b	// r20r21=143*a
//b=-512*16=
	clr r16
	ldi r17, 0x20
	clr r18
	clr r19
	rcall Sub32		//r20r21 = 143*readout-512*16

RH4096_rdy:
	ldi r16, 10
	rcall Mul32b	//r20r21 = (4096*RH)*10
	ldi r16, 0x00
	ldi r17, 0x10
	rcall Div32w	//r20r21 = ((4096*RH)*10)/4096=10*RH%
	ldi r16, 5
	clr r17
	clr r18
	clr r19
	rcall Add32		//r20r21 = 10*RH%+5%
	ldi r16, 10
	rcall Div32b	// r20r21= (10*RH%+5%)/10
//	now r20r21 - RH%
	mov r16, r20 //r16 = r20 = low (RH%)
	cpi r16, 100 // compare r16 with 100
	brlo RH_lower100 // branch if r16<100
	ldi r16, 100
RH_lower100:
	clr r17
	rcall Bin2BCD16	//r21r20 = BCD (RH%) = {x x x x D1 D1 D1 D1} {D2 D2 D2 D2 D3 D3 D3 D3}
	// preforme r20 = r20 >> 4; r16 = (0x0F&R20)<<4
	clr r16			
	lsr r20
	ror r16
	lsr r20
	ror r16
	lsr r20
	ror r16
	lsr r20
	ror r16			// r20 = {0 0 0 0 D2 D2 D2 D2}; r16 = {D3 D3 D3 D3 0 0 0 0}	
	andi r21, 0b00001111
	swap r21			// r21 = {D1 D1 D1 D1 0 0 0 0}
	or r20, r21			// r20 = r20 | r21 = {D1 D1 D1 D1 D2 D2 D2 D2}
	sts pHUMI, r20		// save H1 H2
	sts pHUMI_dec, r16 	// save H3
//	ldi Temp, HUMI_ID
//	sts SensorID, Temp
	ret

//******************************************************
// Convert Temperature data to physical value
//
// INPUT: pValueH, pValue L - MSB and LSB of readout
// OUTPUT: SRAM pTEMP - BCD coded TEMPERATURE 1st and 2nd digits
//				pTEMP_dec - BCD coded TEMPERATURE 3d digit
//******************************************************
//******************************************************
s_Get_TEMP:

	lds r21, pValueH	//r21r20 - readout TEMP
	lds r20, pValueL
	clr r22
	clr r23
	ldi r16, 0x73		//
	ldi r17, 0x0f		// 3960+5 (for 3.0V)
	clr r18
	clr r19
	rcall Sub32sign		// r21r20 - r21r20-(3960-5) for 3.0V
	brtc Temp_pos		// branch if T cleared (positive temperature)
	ldi r16, 0x05		//
	clr r17		// 3960+5 (for 3.0V)
	clr r18
	clr r19
	rcall Add32		// r21r20= r21r20+5 for 3.0V
	ldi Temp, 0x01		// set Negative Temperature bit
	rjmp Temp_lab1
Temp_pos:
	clr Temp			// clear Negative Temperature bit
Temp_lab1:
	sts pTemp_sign, Temp	// store Negative Temperature flag
	rcall Bin2BCD20			// r21r20 = BCD (SO-(3960-5)) = {T1 T1 T1 T1 T2 T2 T2 T2} {T3 T3 T3 T3 xxxx}
	sts pTemp, r21			// store TH1TH2
	sts pTemp_dec, r20		// store TH3 in SRAM
//	ldi Temp, TEMP_ID
//	sts SensorID, Temp
	ret						//return

//******************************************************
// Conver BAttery status and store in SRAM
//******************************************************
s_Get_Batt:
	lds Temp, pValueL
	andi Temp, 0b01000000
	ldi Temp, 0
	breq s_Get_Batt_OK
	inc Temp
s_Get_Batt_OK:
	sts pBattery, Temp
	ret

.include "MAth32.asm"
	

