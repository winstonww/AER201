      list p=16f877                 ; list directive to define processor
      #include <p16f877.inc>        ; processor specific variable definitions
      __CONFIG _CP_OFF & _WDT_OFF & _BODEN_ON & _PWRTE_ON & _HS_OSC & _WRT_ENABLE_ON & _CPD_OFF & _LVP_OFF
      #include <lcd.inc>			   ;Import LCD control functions from lcd.asm
      #include <rtc_macros.inc>
      ;**************************************************
      ;			RTC Variables
      ;**************************************************
	udata_shr
	RTCH	res 1	;const used in delay
	RTCM	res	1	;const used in delay
	RTCL	res	1	;const used in delay
      
    ;**************************************************
      ;			Equates
    ;**************************************************
      
      ;Following are the states
	;START equ 1 ;to: move and detect
	;MOVE_AND_DETECT	equ 2 ;to ARM_RETRACT if col < 50 , to: ANALYSE
	;ARM_RETRACT equ 3;to ARM_RETRACT_COMPLETE if microswitch = 1
	;ARM_RETRACT_COMPLETE equ 4; to ARM_EXTEND if tempmove == 50
	;ARM_EXTEND equ 5; to ARM_EXTNED_COMPLETE
	;ARM_EXTEND_COMPLETE equ 6; to ANALYSE_AND_SAVE_DATA
	;ANALYSE_AND_SAVE_DATA equ 7 ; to MOVE_AND_DETECT 
	;MOTOR_REVERSE equ 8 ; end
	;ENDSTATE equ 9 ; no longer stay in prompt 4 ; should stop all motors; end button;A
    
	
      ;**************************************************
      ;			Variables
      ;**************************************************
	cblock	0x21
		;count time variables
		COUNTH
		COUNTM	
		COUNTL	
		time_taken_counter_1
		time_taken_counter_10
		time_taken_1
		time_taken_10
		time_taken_100
		temp
		;number of instructions storag
		state
		Table_Counter
		;lcd_tmp	
		;lcd_d1
		;lcd_d2
		;com	
		;dat 	
		prompt_mode
	endc	

	;Declare constants for pin assignments (LCD on PORTD)
		#define	RS 	PORTD,2
		#define	E 	PORTD,3

         ORG       0x0000     ;RESET vector must always be at 0x00
         goto      init       ;Just jump to the main code section.
         

;***************************************
; Delay: ~160us macro
;***************************************
;LCD_DELAY macro
;	movlw   0xFF
;	movwf   lcd_d1
;	decfsz  lcd_d1,f
;	goto    $-1
;	endm


;***************************************
; Display macro
;***************************************
Display macro	Message
		local	loop_
		local 	end_
		clrf	Table_Counter
		clrw		
loop_	movf	Table_Counter,W
		call 	Message
		xorlw	B'00000000' ;check WORK reg to see if 0 is returned
		btfsc	STATUS,Z
			goto	end_
		call	WR_DATA
		incf	Table_Counter,F
		goto	loop_
end_
		endm
	 
; Increment_Cycle macro (1),(10),(100), (1000)
			;counter
		
		

;***************************************
; Initialize LCD
;***************************************
init
         clrf      INTCON         ; No interrupts
	 clrf      PCLATH
         bsf       STATUS,RP0     ; select bank 1
         clrf      TRISA          ; All port A is output
	 movlw	   b'00001000'	   ;RA3 input
	 movwf      TRISA  
         movlw     b'11110010'    ; Set required keypad inputs
         movwf     TRISB
         clrf      TRISC          ; All port C is output
         clrf      TRISD          ; All port D is output
	 ;Set SDA and SCL to high-Z first as required for I2C, RTC 
	 bsf	   TRISC,4		  
	 bsf	   TRISC,3
	 
	 ;Set up I2C for communication
	call 	   i2c_common_setup
	 rtc_resetAll
	 call Init_ADC
	 
         bcf       STATUS,RP0     ; select bank 0
         clrf      PORTA
         clrf      PORTB
         clrf      PORTC
         clrf      PORTD
          
         call      InitLCD  	  ;Initialize the LCD (code in lcd.asm; imported by lcd.inc)

;***************************************
; Main code
;***************************************
;test_left	Display		Welcome_Msg

;SwtichLine
;		call		Switch_Lines
;		Display		Welcome_Msg

;ChangeToQuestionMark
;		movlw		b'11001011'
;		call		WR_INS
;		movlw		"?"
;		call		WR_DATA

	 
 call Menu_message
test_left    
	     movlw		b'00011000'		;Move to the left
	     call		WR_INS
	     call		TenthS
	     call		TenthS 
	     movlw		0
	     movwf		time_taken_1
	     movlw		0
	     movwf		time_taken_10
	     movlw		0
	     movwf		time_taken_100
	     movlw		0x0A
	     movwf		time_taken_counter_1
	      movlw		0x0A
	     movwf		time_taken_counter_10
	   btfss		PORTB,1     ;Wait until data is available from the keypad
	     goto		test_left   ; bit =0 , go back to test_left
	    btfsc		PORTB,1
	     goto		$-1
	    swapf		PORTB,W     ;Read PortB<7:4> into W<3:0>
	    andlw		0x0F
	    movwf		prompt_mode ;nested conditional statement. 
	    btfss		prompt_mode,1 ;first bit is set, so either 1 or 2 
	    goto		$+4
	    btfss		prompt_mode,0
	    goto		show_prompt_3		
	    goto		show_prompt_4
	    btfss		prompt_mode,0
	    goto		show_prompt_1
	    goto		show_prompt_2
	   
	    goto test_left
	 
;***************************************
; To be displayed subroutines
	     
;These message is
;***************************************
Menu_message 	
	Display		Instruction_Main_1
	;call		Switch_Lines
	;Display		Instruction_Main_2
	return

			
show_prompt_1		call Clear_Display
			;Display	prompt_1
			
			rtc_read	0x01		;Read Address 0x01 from DS1307---min
			movf	0x77,w
			call	WR_DATA
			
			movfw	0x78
			call	WR_DATA
			
			;movlw			":"
			;call	WR_DATA
			movlw 0xB
			call KPHexToChar
			call WR_DATA
		
			;Get seconds
			rtc_read	0x00		;Read Address 0x00 from DS1307---seconds
			movf	0x77,w
			call	WR_DATA
			
			movf	0x78,w
			call	WR_DATA
			
;			movf time_taken_100, w
;			call  KPHexToChar
;			call WR_DATA
;			
;			movf time_taken_10, w
;			call  KPHexToChar
;			call WR_DATA
;			
;			movf time_taken_1, w
;			call  KPHexToChar
;			call WR_DATA
			
			
			
			
			;call WrtLCD
stay_in_prompt_1	;movlw		b'00011000'		;Remove this line and the line below to stop from moving left
			;call		WR_INS
			call		TenthS 
			call		TenthS
			call		TenthS
			call		TenthS
			call		TenthS
			call		TenthS
			call		TenthS
			call		TenthS
			call		TenthS
			call		TenthS
			call		increment_time_taken
			btfss		PORTB,1     ;test if keypad is pressed
			goto		update_prompt_1 ;bit = 0 stay in prompt 1
			btfsc		PORTB,1 ;wait until key is released
			goto		$-1 ;wait until key is released
			call Clear_Display ;clear  prompt 1
			call Menu_message  ; return to menu message
			goto test_left
			
update_prompt_1		call		show_prompt_1
			goto		stay_in_prompt_1

			
show_prompt_2		call Clear_Display
			Display	prompt_2
stay_in_prompt_2	;movlw		b'00011000'		;Remove this line and the line below to stop from moving left
			;call		WR_INS
			movlw		10
			call		TenthS       ;delay
			btfss		PORTB,1     ;test if keypad is pressed
			goto		stay_in_prompt_2 ;bit = 0 stay in prompt 1
			btfsc		PORTB,1 ;wait until key is released
			goto		$-1 ;wait until key is released
			call Clear_Display ;clear  prompt 1
			call Menu_message  ; return to menu message
			goto test_left
			
show_prompt_3		call Clear_Display
			Display	prompt_3
stay_in_prompt_3	;movlw		b'00011000'		;Remove this line and the line below to stop from moving left
			;call		WR_INS
			call		TenthS       ;delay
			btfss		PORTB,1     ;test if keypad is pressed
			goto		stay_in_prompt_3 ;bit = 0 stay in prompt 1
			btfsc		PORTB,1 ;wait until key is released
			goto		$-1 ;wait until key is released
			call Clear_Display ;clear  prompt 1
			call Menu_message  ; return to menu message
			goto test_left
			
show_prompt_4		call Clear_Display
			bcf PORTA, 3
			btfsc PORTA, 3
			goto $+5
			movlw 0x00
			call KPHexToChar
			call WR_DATA
			goto show_prompt_4
			movlw 0x01
			call KPHexToChar
			call WR_DATA
			goto show_prompt_4
			
			
			
stay_in_prompt_4	;finite state machine implementation
;Test_START		movf state, w
;			subwf START,w
;			movwf temp
;			btfsc temp,0
;			goto Test_MOVE_AND_DETECT
;			btfsc temp,1
;			goto Test_MOVE_AND_DETECT
;			btfsc temp,2
;			goto Test_MOVE_AND_DETECT
;			btfsc temp, 3
;			goto Test_MOVE_AND_DETECT
;			btfsc temp, 4
;			goto Test_MOVE_AND_DETECT
;			call START_Action
;			goto UPDATE
;			
;Test_MOVE_AND_DETECT	movf state, temp
;			subwf Test_MOVE_AND_DETECT,w
;			movwf temp
;			btfsc temp,0
;			goto Test_ARM_RETRACT
;			btfsc temp,1
;			goto Test_ARM_RETRACT
;			btfsc temp,2
;			goto Test_ARM_RETRACT
;			btfsc temp, 3
;			goto Test_ARM_RETRACT
;			btfsc temp, 4
;			goto Test_ARM_RETRACT
;			call MOVE_AND_DETECT_Action
;			goto UPDATE
;			
;Test_ARM_RETRACT	movf state, w
;			subwf Test_ARM_RETRACT,w
;			movwf temp
;			btfsc temp,0
;			goto Test_ARM_RETRACT_COMPLETE
;			btfsc temp,1
;			goto Test_ARM_RETRACT_COMPLETE
;			btfsc temp,2
;			goto Test_ARM_RETRACT_COMPLETE
;			btfsc temp, 3
;			goto Test_ARM_RETRACT_COMPLETE
;			btfsc temp, 4
;			goto Test_ARM_RETRACT_COMPLETE
;			call ARM_RETRACT_Action
;			goto UPDATE
;			
;Test_ARM_RETRACT_COMPLETE   movf state, w
;			subwf Test_ARM_RETRACT_COMPLETE,w
;			movwf temp
;			btfsc temp,0
;			goto Test_ARM_EXTEND
;			btfsc temp,1
;			goto Test_ARM_EXTEND
;			btfsc temp,2
;			goto Test_ARM_EXTEND
;			btfsc temp, 3
;			goto Test_ARM_EXTEND
;			btfsc temp, 4
;			goto Test_ARM_EXTEND
;			call ARM_RETRACT_COMPLETE_Action
;			goto UPDATE
;			
;Test_ARM_EXTEND		movf state, w
;			subwf Test_ARM_EXTEND,w
;			movwf temp
;			btfsc temp,0
;			goto Test_ARM_EXTEND_COMPLETE
;			btfsc temp,1
;			goto Test_ARM_EXTEND_COMPLETE
;			btfsc temp,2
;			goto Test_ARM_EXTEND_COMPLETE
;			btfsc temp, 3
;			goto Test_ARM_EXTEND_COMPLETE
;			btfsc temp, 4
;			goto Test_ARM_EXTEND_COMPLETE
;			call ARM_EXTEND_Action
;			goto UPDATE
;			
;Test_ARM_EXTEND_COMPLETE movf state, w
;			subwf Test_ARM_EXTEND_COMPLETE,w
;			movwf temp
;			btfsc temp,0
;			goto Test_ANALYSE_AND_SAVE_DATA
;			btfsc temp,1
;			goto Test_ANALYSE_AND_SAVE_DATA
;			btfsc temp,2
;			goto Test_ANALYSE_AND_SAVE_DATA
;			btfsc temp, 3
;			goto Test_ANALYSE_AND_SAVE_DATA
;			btfsc temp, 4
;			goto Test_ANALYSE_AND_SAVE_DATA
;			call ARM_EXTEND_COMPLETE_Action
;			goto UPDATE
;			
;			
;Test_ANALYSE_AND_SAVE_DATA movf state, w
;			subwf Test_ANALYSE_AND_SAVE_DATA,w
;			btfsc temp,0
;			movwf temp
;			goto Test_MOTOR_REVERSE
;			btfsc temp,1
;			goto Test_MOTOR_REVERSE
;			btfsc temp,2
;			goto Test_MOTOR_REVERSE
;			btfsc temp, 3
;			goto Test_MOTOR_REVERSE
;			btfsc temp, 4
;			goto Test_MOTOR_REVERSE
;			call ANALYSE_AND_SAVE_DATA_Action
;			goto UPDATE
;			
;Test_MOTOR_REVERSE	movf state, w
;			subwf Test_MOTOR_REVERSE,w
;			movwf temp
;			btfsc temp,0
;			goto Test_ENDSTATE
;			btfsc temp,1
;			goto Test_ENDSTATE
;			btfsc temp,2
;			goto Test_ENDSTATE
;			btfsc temp, 3
;			goto Test_ENDSTATE
;			btfsc temp, 4
;			goto Test_ENDSTATE
;			call MOTOR_REVERSE_Action
;			goto UPDATE
;
;Test_ENDSTATE		movf state, w
;			subwf Test_ENDSTATE,w
;			movwf temp
;			btfsc temp,0
;			goto DEFAULT
;			btfsc temp,1
;			goto DEFAULT
;			btfsc temp,2
;			goto DEFAULT
;			btfsc temp, 3
;			goto DEFAULT
;			btfsc temp, 4
;			goto DEFAULT
;			call ENDSTATE_Action
;			goto UPDATE
;			
;DEFAULT			nop
;			
UPDATE			goto test_left
			
	


;******************Actions associated with each state ********************
			
START_Action ;to: move and detect
			nop
			return
MOVE_AND_DETECT_Action;to ARM_RETRACT if col < 50 , to: ANALYSE
			nop
			return
			
ARM_RETRACT_Action ;to ARM_RETRACT_COMPLETE if microswitch = 1
			nop
			return
ARM_RETRACT_COMPLETE_Action; to ARM_EXTEND if tempmove == 50
			nop
			return
ARM_EXTEND_Action; to ARM_EXTNED_COMPLETE
			nop
			return
ARM_EXTEND_COMPLETE_Action; to ANALYSE_AND_SAVE_DATA
			nop
			return
ANALYSE_AND_SAVE_DATA_Action ; to MOVE_AND_DETECT 
			nop
			return
MOTOR_REVERSE_Action; end
			nop
			return
ENDSTATE_Action ; no longer stay in prompt 4 ; should stop all motors; end button;A
			nop
			return
			 
;***************************************
; Look up table
;***************************************

Welcome_Msg	
		movwf temp
		movlw HIGH Welcome_Msg_TableEntries
		movwf PCLATH
		movf temp, w
		addlw LOW Welcome_Msg_TableEntries
		btfsc STATUS,C
		    incf PCLATH,f
		movwf PCL
Welcome_Msg_TableEntries dt		"Hello World!", 0

;Alphabet
;		addwf	PCL,F
;		dt		"ABCDEFGHIJKLMNOPQRSTUVWXYZ",0
		
Instruction_Main_1
		movwf temp
		movlw HIGH Instruction_Main_TableEntries
		movwf PCLATH
		movf temp, w
		addlw LOW Instruction_Main_TableEntries
		btfsc STATUS,C
		    incf PCLATH,f
		movwf PCL
Instruction_Main_TableEntries	dt "A:start 1:time, 2:#barrels 3:dist" ,0
		
	
prompt_1
		movwf temp
		movlw HIGH prompt_1_TableEntries
		movwf PCLATH
		movf temp, w
		addlw LOW prompt_1_TableEntries
		btfsc STATUS,C
		    incf PCLATH,f
		movwf PCL
prompt_1_TableEntries	dt		"t=",0
		

prompt_2
		movwf temp
		movlw HIGH prompt_2_TableEntries
		movwf PCLATH
		movf temp, w
		addlw LOW prompt_2_TableEntries
		btfsc STATUS,C
		    incf PCLATH,f
		movwf PCL
prompt_2_TableEntries	dt		"3 short, 2 tall ",0
		

prompt_3
		movwf temp
		movlw HIGH prompt_3_TableEntries
		movwf PCLATH
		movf temp, w
		addlw LOW prompt_3_TableEntries
		btfsc STATUS,C
		    incf PCLATH,f
		movwf PCL
prompt_3_TableEntries		dt		"T100 S150 T300 ",0

prompt_4
		movwf temp
		movlw HIGH prompt_4_TableEntries
		movwf PCLATH
		movf temp, w
		addlw LOW prompt_4_TableEntries
		btfsc STATUS,C
		    incf PCLATH,f
		movwf PCL
		addwf	PCL,F
prompt_4_TableEntries		dt		"START!!!",0
KPHexToChar
		movwf temp
		movlw HIGH KPHexToChar_TableEntries
		movwf PCLATH
		movf temp, w
		addlw LOW KPHexToChar_TableEntries
		btfsc STATUS,C
		    incf PCLATH,f
		movwf PCL
 KPHexToChar_TableEntries         dt        "01234567890:*0#DKKKKK"			
						


;***************************************
; LCD control
;***************************************
Switch_Lines
		movlw	B'11000000'
		call	WR_INS
		return

Clear_Display
		movlw	B'00000001'
		call	WR_INS
		return
		
Left	movlw		b'00011000'		;Move to the left
		call		WR_INS
		call		TenthS
		goto		Left			;repeat operation	
		;goto	$
		return 
Display_2dig 
		;swapf		
		andlw		0x0F
		
increment_time_taken
		;call increment_time
		incf time_taken_1
		decfsz time_taken_counter_1, f ;see if time_taken_1 is 0 or not
		return
		movlw 0
		movwf time_taken_1
		movlw 0x0A
		movwf time_taken_counter_1
		incf time_taken_10
		decfsz time_taken_counter_10, f 
		return
		movlw 0
		movwf time_taken_10
		movlw 0x0A
		movwf time_taken_counter_10
		incf time_taken_100
		
		
		return
;***************************************
; Setup RTC with time defined by user
;***************************************
set_rtc_time

		rtc_resetAll	;reset rtc

		rtc_set	0x00,	B'10000000'

		;set time 
		rtc_set	0x06,	B'00010000'		; Year
		rtc_set	0x05,	B'00000100'		; Month
		rtc_set	0x04,	B'00000110'		; Date
		rtc_set	0x03,	B'00000010'		; Day
		rtc_set	0x02,	B'00010010'		; Hours
		rtc_set	0x01,	B'00110000'		; Minutes
		rtc_set	0x00,	B'00000000'		; Seconds
		return		 
		
		
;***************************************
; Delay 0.5s, Cycles = 250000
;***************************************
TenthS	
	local	TenthS_0
      movlw 0x50
      movwf COUNTH
      ;movlw 0x02
      ;movwf COUNTM
      movlw 0xC4
      movwf COUNTL

;5 cycles
TenthS_0
      decfsz COUNTH, f
      goto   $+2
      ;decfsz COUNTM, f
      ;goto   $+2
      decfsz COUNTL, f
      goto   TenthS_0
      goto $+1
      nop
      nop
		return
     		

;************************** LCD-related subroutines **************************


    ;*************************************************************************
;InitLCD
;	bcf STATUS,RP0
;	bsf E     ;E default high
;	
;	;Wait for LCD POR to finish (~15ms)
;	call lcdLongDelay
;	call lcdLongDelay
;	call lcdLongDelay
;
;	;Ensure 8-bit mode first (no way to immediately guarantee 4-bit mode)
;	; -> Send b'0011' 3 times
;	movlw	b'00110011'
;	call	WR_INS
;	call lcdLongDelay
;	call lcdLongDelay
;	movlw	b'00110010'
;	call	WR_INS
;	call lcdLongDelay
;	call lcdLongDelay
;
;	; 4 bits, 2 lines, 5x7 dots
;	movlw	b'00101000'
;	call	WR_INS
;	call lcdLongDelay
;	call lcdLongDelay
;
;	; display on/off
;	movlw	b'00001100'
;	call	WR_INS
;	call lcdLongDelay
;	call lcdLongDelay
;	
;	; Entry mode
;	movlw	b'00000110'
;	call	WR_INS
;	call lcdLongDelay
;	call lcdLongDelay
;
;	; Clear ram
;	movlw	b'00000001'
;	call	WR_INS
;	call lcdLongDelay
;	call lcdLongDelay
;	return
;   
;
;    ;ClrLCD: Clear the LCD display
;ClrLCD
;	movlw	B'00000001'
;	call	WR_INS
;    return
;
;    
;    ; Write command to LCD - Input : W , output : -
;  
;WR_INS
;	bcf		RS				;clear RS
;	movwf	com				;W --> com
;	andlw	0xF0			;mask 4 bits MSB w = X0
;	movwf	PORTD			;Send 4 bits MSB
;	bsf		E				;
;	call	lcdLongDelay	;__    __
;	bcf		E				;  |__|
;	swapf	com,w
;	andlw	0xF0			;1111 0010
;	movwf	PORTD			;send 4 bits LSB
;	bsf		E				;
;	call	lcdLongDelay	;__    __
;	bcf		E				;  |__|
;	call	lcdLongDelay
;	return
;
; 
;  
;    ; Write data to LCD - Input : W , output : -
;    
;WR_DATA
;	bsf		RS				
;	movwf	dat
;	movf	dat,w
;	andlw	0xF0		
;	addlw	4
;	movwf	PORTD		
;	bsf		E				;
;	call	lcdLongDelay	;__    __
;	bcf		E				;  |__|
;	swapf	dat,w
;	andlw	0xF0		
;	addlw	4
;	movwf	PORTD		
;	bsf		E				;
;	call	lcdLongDelay	;__    __
;	bcf		E				;  |__| 
;	return
;
;lcdLongDelay
;    movlw d'20'
;    movwf lcd_d2
;LLD_LOOP
;    LCD_DELAY
;    decfsz lcd_d2,f
;    goto LLD_LOOP
;    return

;*********************** ADC subroutines *****************************

;**********************************************************************
 Init_ADC   bsf		STATUS,RP0
	    bcf 	TRISD,1
	    bsf		TRISA,0

	    movlw	b'00001110'
	    movwf	ADCON1			;All digital input expect RA0, reference voltage Vdd Vss

	    bcf		STATUS,RP0
	    movlw	b'11000101'		;clock selected, ADC module turned on
	    movwf	ADCON0
	    return
	    


	  
	  END