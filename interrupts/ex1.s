.syntax unified

.include "efm32gg.s"

/////////////////////////////////////////////////////////////////////////////
//
// Exception vector table
// This table contains addresses for all exception handlers
//
/////////////////////////////////////////////////////////////////////////////

.section .vectors

	.long   stack_top               /* Top of Stack                 */
	.long   _reset                  /* Reset Handler                */
	.long   dummy_handler           /* NMI Handler                  */
	.long   dummy_handler           /* Hard Fault Handler           */
	.long   dummy_handler           /* MPU Fault Handler            */
	.long   dummy_handler           /* Bus Fault Handler            */
	.long   dummy_handler           /* Usage Fault Handler          */
	.long   dummy_handler           /* Reserved                     */
	.long   dummy_handler           /* Reserved                     */
	.long   dummy_handler           /* Reserved                     */
	.long   dummy_handler           /* Reserved                     */
	.long   dummy_handler           /* SVCall Handler               */
	.long   dummy_handler           /* Debug Monitor Handler        */
	.long   dummy_handler           /* Reserved                     */
	.long   dummy_handler           /* PendSV Handler               */
	.long   dummy_handler           /* SysTick Handler              */

	/* External Interrupts */
	.long   dummy_handler
	.long   gpio_handler            /* GPIO even handler */
	.long   dummy_handler
	.long   dummy_handler
	.long   dummy_handler
	.long   dummy_handler
	.long   dummy_handler
	.long   dummy_handler
	.long   dummy_handler
	.long   dummy_handler
	.long   dummy_handler
	.long   gpio_handler            /* GPIO odd handler */
	.long   dummy_handler
	.long   dummy_handler
	.long   dummy_handler
	.long   dummy_handler
	.long   dummy_handler
	.long   dummy_handler
	.long   dummy_handler
	.long   dummy_handler
	.long   dummy_handler
	.long   dummy_handler
	.long   dummy_handler
	.long   dummy_handler
	.long   dummy_handler
	.long   dummy_handler
	.long   dummy_handler
	.long   dummy_handler
	.long   dummy_handler
	.long   dummy_handler
	.long   dummy_handler
	.long   dummy_handler
	.long   dummy_handler
	.long   dummy_handler
	.long   dummy_handler
	.long   dummy_handler
	.long   dummy_handler
	.long   dummy_handler
	.long   dummy_handler

.section .text

/////////////////////////////////////////////////////////////////////////////
//
// Reset handler
// The CPU will start executing here after a reset
//
/////////////////////////////////////////////////////////////////////////////

	.globl  _reset
	.type   _reset, %function
	.thumb_func
_reset: 
	ldr r1, =CMU_BASE // load CMU base addresses
	ldr r2, [r1, #CMU_HFPERCLKEN0] // Load current value of #CMU_HFPERCLKEN0

	// Enable GPIO Clock
	mov r3, #1
	lsl r3, r3, #CMU_HFPERCLKEN0_GPIO
	orr r2, r2, r3
	str r2, [r1, #CMU_HFPERCLKEN0]

	// Set GIPO high drive strength
	ldr r1, =GPIO_PA_BASE
	mov r2, #0x2
	str r2, [r1, #GPIO_CTRL]

	// Set pins 8-15 to output
	mov r2, #0x55555555
	str r2, [r1, #GPIO_MODEH]

	// Set pins 0-7 to input
	ldr r3, =GPIO_PC_BASE
	mov r2, #0x33333333
	str r2, [r3, #GPIO_MODEL]

	// Enable internal pull-up
	mov r2, #0xFF
	str r2, [r3, #GPIO_DOUT]

	// Reset game state
	// r7: ball position
	// r6: last input
	mov r6, #0 // Set last state
	mov r7, #40 // Set position


update: // Game loop
	bl check_input
	bl check_bounds
	bl render
	b update

render: // Toggles the LEDs based on the position stored in r7
	push {ip, lr}
	mov r2, #10
	udiv r1, r7, r2 // Set r1 = position/10
	add r1, r1, #8
	mov r2, #1
	lsl r1, r2, r1 // Bitshift 1 by r2+7 times
	eor r1, r1, #0xFF00 // Invert bits as 0 means LED on
	ldr r2, =GPIO_PA_BASE
	str r1, [r2, #GPIO_DOUT] // Write state to LEDs
	pop {ip, pc}

check_input:
	push {ip, lr}
	// Checks if left input was low last time and now is high
	ldr r5, =GPIO_PC_BASE
	ldr r4, [r5, #GPIO_DIN]
	and r1, r4, #0xFE // Isolate bit 1 of input in r1

	eor r2, r6, #0xFE
	and r2, r2, #0xFE

	and r3, r1, r2 // Logical AND together current input state and last input state

	cmp r3, #0
	beq left_input_done

	add r7, r7, #1 // Move 1 left
left_input_done:
	// Checks if right input was low last time and now is high
	and r1, r4, #0xBF // Isolate bit 7 of input in r1

	eor r2, r6, #0xBF 
	and r2, r2, #0xBF

	and r3, r1, r2  // Logical AND together current input state and last input state

	cmp r3, #0
	beq right_input_done

	sub r7, r7, #1 // Move 1 right
right_input_done:
	mov r6, r4 // Store input in last input
	pop {ip, pc}

check_bounds:
	push {ip, lr}
	cmp r7, #0
	bpl left_bounds_done
	// right player wins
	ldr r3, =0xF000 // Set blink on left LEDs
	bl blink
	mov r7, #40 // Reset position

	b right_bounds_done
left_bounds_done:
	cmp  r7, #80
	bmi right_bounds_done
	// left player wins
	ldr r3, =0x0F00 // Set blink on right LEDs
	bl blink
	mov r7, #40 // Reset position

right_bounds_done:
	pop {ip, pc}



blink: // Blinks the lights that are stored low in r3
	push {ip, lr}
	mov r1, #10 // The number of times LEDs should blink
	ldr r2, =GPIO_PA_BASE
	ldr r4, =0xFF00 // All LEDs off position

blink_loop:
	
	str r3, [r2, #GPIO_DOUT] // Write state to LEDs
	ldr r0, =400000 // Load the number of delays for delay function
	bl delay

	str r4, [r2, #GPIO_DOUT] // Write state to LEDs
	ldr r0, =400000 // Load the number of delays for delay function
	bl delay

	subs r1, r1, #1
	bne blink_loop

	pop {ip, pc}


delay: // Delays the program by the number of cycles stored in r0
	push {ip, lr}
delay_loop:
	subs r0, r0, #1
	bne delay_loop
	pop {ip, pc}

/////////////////////////////////////////////////////////////////////////////
//
// GPIO handler
// The CPU will jump here when there is a GPIO interrupt
//
/////////////////////////////////////////////////////////////////////////////

    .thumb_func
gpio_handler:  
	b .  // do nothing

/////////////////////////////////////////////////////////////////////////////

    .thumb_func
dummy_handler:  
	b .  // do nothing

