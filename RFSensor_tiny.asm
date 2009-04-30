/**********************************************************************
	Wireless 433.92MHz Thermo - Hygro sensor
	with Oregon Scientific 1.0 protocol (seen as THN128 sensor)
	Works with SHT temp/hum sensors.
	fCPU: 4MHz

	See details on my web page http://alyer.frihost.net

	(c) Alexander Yerezeyev, 2007-2009
	e-mail: wapbox@bk.ru
	ICQ: 305206239


	To Do: add DIP switch support for manual channel setting

**********************************************************************/


.include "tn2313def.inc"

.def Temp	=r16;
.def Temp2	=r17;
.def Temp3	=r18;


.dseg
.org 0x060

EncodedBits:	.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00

// Data for storing measurements (must be equal to zero)
// Do not change
DataBits:		
CH_byte:	.db 0x00; 	// Channel # 0..2
TH32_byte:	.db 0x00;	// Digits 3 and 2
TH1X_byte:	.db 0x00;	// Digit 1
CRC_byte:	.db 0x00;	// CRC

// Temprorary buffers
// Do not change
TH1:		.db 0x00; 	// Digit 1
TH2:		.db 0x00; 	// Digit 2
TH3:		.db 0x00;	// Digit 3
Channel:	.db 0x00;	// Channel
FLags:		.db 0x00;	// Flags

// Service variables
// Do not change
TXbits_cnt:	.db 0x00;	// TX bits counter
Task_State:	.db 0x00; 	// current programm state
T_RH_sw:	.db 0x00; 	// Temperature/Humidity state
ErrorCnt:	.db 0x00; 	// Error Counter
pValueH:	.db 0x00;
pValueL:	.db 0x00;
pCRC:		.db 0x00;
pCommand:	.db 0x00;
pCommError:	.db 0x00;
pBattery:	.db 0x00;
CRC_gen:	.db 0x00

pHUMI:		.db 0x00
pHUMI_dec:	.db 0x00

pTEMP:		.db 0x00
pTEMP_dec:	.db 0x00
pTEMP_sign:	.db 0x00

SensorID:	.db 0x00;	// OS random sensor ID (00 - default)

// Bit numberss in OS v1 protocol
.equ	Batt 		=7;
.equ	Sign 		=5;
.equ	ComError	=6;


// I/O pins definitions
.equ	LED		=PB4; LED
.equ	SHTpwr	=PB0; POWER line for SHT11 sensor (I decided not to used it)	
.equ 	TX		=PB3; TX line for TLP434 
// data lines for SHT11
.equ	SCK 	=PB1; 
.equ	DATA 	=PB2;
.equ	TXPwr	=PD5;
.equ	noACK 	=0;
.equ 	ACK 	=1;

//adr command r/w for SHT11
.equ 	STATUS_REG_W =0x06 //000 0011 0
.equ 	STATUS_REG_R =0x07 //000 0011 1
.equ 	MEASURE_TEMP =0x03 //000 0001 1
.equ 	MEASURE_HUMI =0x05 //000 0010 1
.equ 	RESET =0x1e //000 1111 0
.equ	HUMI_ID	=0b00001110
.equ	TEMP_ID	=0b00001001

// Timing presets
.equ	Tact	=0x5A
.equ	dT		=17

.cseg
.org 0x0000
	rjmp main
.org 0x0004 
	rjmp TIM1_COMPA
.org 0x000D
	rjmp TIMER0_COMPA

main:		
	ldi Temp, low(RAMEND);
	out SPL, Temp
		
	clr ZH
	ldi ZL, low(RAMEND)+1	// point at last SRAM byte+1
	clr Temp2
	ldi Temp, 128			// RAM counter
SRAM_clear_loop:
	st -Z, Temp2			// Clear SRAM
	dec Temp
	brne SRAM_clear_loop	

	ldi Temp, (1<<TX)|(1<<SCK)|(1<<SHTpwr)|(1<<LED)
	out DDRB, Temp		// Set IO directions
	sbi DDRD, TXpwr		// Set IO directions for TX pwr

	sbi PORTB, SHTpwr 	// Turn ON SHT sensor pwr
	ldi Temp,(1<<WGM01);// Init T0 CTC mode
	out TCCR0A, Temp
	ldi Temp, (1<<OCIE0A)|(1<<OCIE1A);
	out TIMSK, Temp		//Enable T0A T1A interrupts
	ldi Temp, 0x09		// Initial delay for SHT turn-on
	rcall StartT1		
	sei					//Enable interrupts
	in Temp, MCUCR
	ori Temp, (1<<SE)
	out MCUCR, Temp		// Enable sleep mode
forever:
	sleep				// Just sleep in main cycle
	rjmp forever

//***************************************************
// Start T1 procedure
// in:	Temp 	- H OCR
// 		Temp2 	- L OCR
//***************************************************
StartT1:
	out OCR1AH, Temp
	out OCR1AL, Temp2
	clr Temp
	out TCNT1H, Temp
	out TCNT1L, Temp
	ldi Temp, (1<<WGM12)|(1<<CS12)|(1<<CS10)//1024 prescaler, set CTC mode
	out TCCR1B, Temp
	ret

//***************************************************
// Start TX process procedure
// when running from StartTX_again_1,
// then put in Temp desired bit latency	
//***************************************************
StartTX:
	clr Temp
	sts TXbits_cnt, Temp; // Clear transmiter bit counter @ start
StartTX_again:
	ldi Temp, Tact+dT;
StartTX_again_1:
	out OCR0A, Temp
	clr Temp
  	out TCNT0, Temp
	ldi Temp, (1<<CS01)|(1<<CS00); //64 prescaler// Set CTC Mode
  	out TCCR0B, Temp // Start T0A timer
    ret

//**********************************************
// T1 compare A interrupt handler
// Main Task Manager Timer
//**********************************************
TIM1_COMPA:

	push Temp	; 
 	in Temp, SREG
	push Temp
	push Temp2
	push Temp3
	clr Temp
	out TCCR1B, Temp //Stop T1
	
	lds Temp, Task_State	//Load CPU State Flag
	tst Temp				
	breq T1_case0			// State Flag: 0
	cpi Temp, 1
	breq T1_case1			// State Flag: 1
	cpi Temp, 2
	breq T1_case2			// State Flag: 2
	cpi Temp, 3	
	breq T1_case3			// State Flag: 3
	rjmp T1_exit1
// State Flag: 0 		
T1_case0:
	ldi Temp, 0b10000000
	out CLKPR, Temp
	ldi Temp, 0b00000000
	out CLKPR, Temp

	ldi Temp, 0x1E
	ldi Temp2, 0x83
	rcall startT1			// Let's give 2 seconds to get data from SHT
	lds Temp, T_RH_sw		// Load RH/Temperature switch bit
	andi Temp, 0b00000001	// Mask it
	push Temp				// Save on stack
	rcall s_GetData			// Goto SHT data process -> Manchester encoder
	pop Temp				// Restore RH/Temperature switch bit
	inc Temp				// Toggle it
	sts T_RH_sw, Temp		// Save it in SRAM
	rjmp T1_exit1			// End state 0 process
// State Flag: 1
T1_case1:
	cbi PORTB, LED
	rcall StartTX			// Start transmition of TEMP/HUMI 
	rjmp T1_exit1			//depended on Restore RH/Temperature switch bit
// State Flag: 2
T1_case2:
	rcall StartTX			// after 100ms  repeat transmition again
	rjmp T1_exit1
// State Flag: 3			// After TX finished - just wait for a new TX
T1_case3:
	cbi PORTD, TXpwr		// Turn OFF transmitter
	ldi Temp, 0b10000000
	out CLKPR, Temp
	ldi Temp, 0b00001000
	out CLKPR, Temp
	ldi Temp, 0x00			// high end
	ldi Temp2, 0xB5
T1_exit:
	rcall startT1			//Start T1
T1_exit1:
	lds Temp, Task_State	// Load Task_State counter
	inc Temp				// Task_State++
	cpi Temp,4				// Tasks_State=4 then Task_State=0
	brne T1_save_state
	clr Temp
T1_save_state:
	sts Task_State, Temp	//Store Task_State
	pop Temp3
	pop Temp2
	pop Temp
	out SREG, Temp
	pop Temp
	reti

//**********************************************
// T0 compare A interrupt handler
// This interrupt handler used for TX bits sync
//**********************************************
TIMER0_COMPA:
	push Temp	; 
 	in Temp, SREG
	push Temp
	push Temp2
	push Temp3
	push ZH
	push ZL

	clr Temp
	out TCCR0B, Temp		// Stop T0
		
	lds Temp, TXbits_cnt 	// load TX bits counter
	mov Temp3, Temp			// Temp3 - bit counter

	andi Temp, 0b00000111	
	push Temp 				// Get current bit number at Stack
	mov Temp, Temp3 	// load TX bits counter
	andi Temp, 0xF8			// get current byte number
	lsr Temp				
	lsr Temp
	lsr Temp				// now in Temp =current byte number
		
	clr ZH
	ldi ZL, EncodedBits		// Init pointer to Encoded bits array
	add ZL, Temp			// move pointer to current byte
	ld Temp, Z 				// load current byte

	pop Temp2 				// load in Temp2 current bit number
	inc Temp2

TX0_loop1:					// then shift left current byte
	lsl Temp				//	Temp2+1 times
	dec Temp2
	brne TX0_loop1			
							// now in C current bit value
TX0_lab1:					
	brcc TX0_TX0
	ldi Temp, Tact+dT
	sbi PORTB, TX			// set TX=1 if current bit=1
	rjmp TX0_lab2			
TX0_TX0:
	ldi Temp, Tact-dT
	cbi PORTB, TX			// set TX=0 if current bit=0
TX0_lab2:
	// load TX bits counter and increment it
	inc Temp3
	sts TXbits_cnt, Temp3	// save new TX bits counter

	cpi Temp3, 30			// 25th, 26th and 27th bits 
	breq TX0_sync1			// must have longer periods
	cpi Temp3, 31
	breq TX0_sync2
	cpi Temp3, 32
	breq TX0_sync3

	//cpi Temp3, 94		// TX nits counter = 92 then all bits are transmitted
	cpi Temp3, 99		// TX nits counter = 92 then all bits are transmitted
	breq TX0_all_send
// else Normal operation

	rcall StartTX_again_1
	rjmp TX0_exit

TX0_sync1:					// Latency for 25 bit
	//ldi Temp, 0x41 //0x43
	ldi Temp, 0x41
	out OCR0A, Temp
	rjmp TX0_startT0

TX0_sync2:
	//ldi Temp, 0x5A//0x5D			// Latency for 26 bit
	ldi Temp, 0x58 //0x43
	out OCR0A, Temp
	rjmp TX0_startT0

TX0_sync3:
	//ldi Temp, 0x51 //0x50			// Latency for 27 bit
	ldi Temp, 0x55
	out OCR0A, Temp
	rjmp TX0_startT0

TX0_all_send:
// if all bits to send are TXed then start T1 for 100 ms delay

	ldi Temp, 0x01
	ldi Temp2, 0x7E
	rcall StartT1			//100 ms delay after transmittion
	rjmp TX0_exit			// goto irq exit

TX0_startT0:				// start T0 at 256 divider for 25, 26, 27 bits
	clr Temp
  	out TCNT0, Temp
	ldi Temp, (1<<CS02);  	//256 prescaler Set CTC Mode
  	out TCCR0B, Temp

TX0_exit:					// restore corrupted registers and exir from IRQ
	pop ZL
	pop ZH
	pop Temp3
	pop Temp2
	pop Temp
	out SREG, Temp
	pop Temp
	reti


.include "Manchester_encoder.asm"
.include "SHTxx_driver.asm"

