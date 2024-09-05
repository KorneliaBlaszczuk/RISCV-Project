#---------------------------------------------------------------
# Author: Kornelia B³aszczuk
# Project: Finding marker (no. 3)
#---------------------------------------------------------------

# MARKERS 
.eqv	BYTES_PER_ROW	960	# 24bites RGB
.eqv	MAX_FILE_SIZE	230522	# width * height + header_size
.eqv	RESULT_SIZE	200	# 4 bytes for each of max 50 markers
.eqv 	PIXEL_ARRAY_S	230400

.eqv	EXIT		10
.eqv	READ_STRING	8

# PRINTING
.eqv	PRINT_STRING	4
.eqv	PRINT_CHAR	11
.eqv	PRINT_INT	1

# FILE HANDLING
.eqv	OPEN_FILE	1024
.eqv	READ_FILE	63
.eqv	WRITE_FILE	64
.eqv	CLOSE_FILE	57

	.data
res_message:		.asciz "\n Pattern nr 3 found at: \n "
res:			.space	2 # for image_buffer to be aligned correctly
image_buffer:		.space	MAX_FILE_SIZE
result_buffer:		.space	RESULT_SIZE
fname:			.asciz	"source.bmp"
open_error: 		.asciz "Can not open the file!\n"
read_error:		.asciz "Can not read from the file!\n"

	.text
main:
	# reading file into buffer
	la	a0,	fname
	jal	read_to_buffer
	
	# a2 -> pixel array start address
	jal	get_pixel_array_start
	
	# a0 -> pixel array size
	li	a0,	PIXEL_ARRAY_S
	jal	analyze_pixels			# function that finds markers
	
	la	s1,	result_buffer		# iterates through result buffer
	add	s2,	s1,	a0		# s2 -> end of result buffer, we need it to stop when needed
	jal 	result_message			# returns a message 
	
result_loop:
	beq	s1,	s2,	result_loop_end	# if iterator = buffer end -> finish
	lw	a0,	(s1)		
	
	li	a1,	0x00ff0000		# setting red orb
	jal	set_orgb_at_address
	
	# prints coordinates of marker
	lw	a0,	(s1)			
	jal	print_coords
	
	addi	s1,	s1,	4		
	j	result_loop
	
result_loop_end:
	# saves changes to our file
	la	a0,	fname
	jal	save_to_file
	
	j	end

#=====================================================================================
# ANALYSIS OF PIXELS IN BMP FILE
analyze_pixels:
# Summary of how it works
# Iterates through every pixel in BMP image, using image which is buffer
# When occurance is found -> it saves it in result buffer

	# allocate stack space for saving callee-saved registers
	addi	sp,	sp,	-44
	sw	ra,	40(sp)
	sw,	s0,	36(sp)
	sw	s1,	32(sp)
	sw	s2,	28(sp)
	sw	s3,	24(sp)
	sw	s4,	20(sp)
	sw	s5,	16(sp)
	sw	s6,	12(sp)
	sw	s7,	8(sp)
	sw	s8,	4(sp)
	sw	s9,	(sp)
	
	mv	s2,	a0			# s2 -> array size
	
	la	s0,	result_buffer		# s0 -> result iterator
	mv	s1, 	a2			# s1 -> image buffer iterator 
	add	s2,	s1,	s2		# s2 -> pixel array end address
	li	s3,	0			# s3 -> point where arms cross
	li	s4,	0			# s4 -> thickness
	li	s5,	0x00000000		# s5 -> black color
	li	s6,	0			# s6 -> height
	li	s7,	0			# s7 -> width
	li	s8,	0			# s8 -> width thickness
	li	s9,	0			# s9 -> pixel after marker

	# stage 0
	next_black: # looking for the next black pixel
		bge	s1,	s2,	find_marker_end		# if pixel address is out of pixel array range - end
		mv	a0,	s1
		bge	a0,	s2,	find_marker_end
		jal	get_orgb_from_address			# a0 -> color of pixel
		bne	a0,	s5,	next			# if not black go to next pixel

		mv 	s3, 	s1				# place where arms are supposed to cross; we check it bellow
		li 	t5, 	3
		
	# stage 1
	height: 
		addi	a0,	s1,	BYTES_PER_ROW	# pixel up to which we currently are
		bge	a0,	s2,	height_end	
		jal	get_orgb_from_address		
		bne	a0,	s5,	height_end	# if not black -> measure thickness
		addi	t5,	t5,	3		# t5 - counter of height
		addi	s1,	s1,	BYTES_PER_ROW	# going row up
		j	height
			
	height_end:
		mv	s6, 	t5	# official height
		li 	t5,	3	# our starting value to count

	# stage 2
	thick:
		addi	a0,	s1,	3		# checking pixel next to current
		bge	a0,	s2,	thick_end	# if address qual or greater than end of pixel array - end of measuring
		jal	get_orgb_from_address		
		bne	a0,	s5,	thick_end	# if not black -> end of counting thickness
		addi	t5,	t5,	3		# t6 - thickness counter
		addi	s1,	s1,	3		# going to next pixel
		j	thick
			
				
	thick_end:
		mv 	s4, 	t5	# found thickness (need to see if it's different than width)
		li 	t5, 	3
		li	t3,	3
		mv 	s1, 	s3	# s1 is now in the pointer						
		
	# stage 3
	width:	
		# checking if pixel is last in row - if so then end counting
		sub	a0,	s1,	a2
		li	t3,	BYTES_PER_ROW
		rem	t6,	a0,	t3
		li	t3,	3
		div	t6,	t6,	t3	# x coordinate
		li	t3,	319
		beq	t6,	t3,	check	# if coordinate is 319 - pixel last in row
		
		# now we can count in normally
		addi	a0,	s1,	3
		bge	a0,	s2,	check		# if next pixel is out of pixel array - end counting
		jal	get_orgb_from_address		
		bne	a0,	s5,	check		# if not black - end of counting
		addi	t5,	t5,	3		# current width ++
		addi	s1,	s1,	3		# go to next pixel
		j	width
				
	check:
		bne	t5,	s6,	go_to_next_marker	# if height != width -> incorrect
		beq 	t5, 	s4, 	go_to_next_marker	# if width == thick -> incorrect

		mv 	s7, 	t5	# width
		mv	s9,	s1
		addi	s9,	s9,	3
		li 	t5, 	3	
		li	t6,	3

	# stage 4		
	thick_width:
		mv	t6,	s1
		# move s1 to t6 so we can use it later
		measure:
			addi	a0,	s1,	BYTES_PER_ROW		# going row up
			bge	a0,	s2,	thick_width_end	
			jal	get_orgb_from_address		
			bne	a0,	s5,	thick_width_end		# if not black -> end of counting
			addi	t5,	t5,	3			# t5 - thickness of width arm
			addi	s1,	s1,	BYTES_PER_ROW
			j	thick_width
				
	thick_width_end:
		mv 	s8, 	t5	# found thickness (need to see if it's different that width)
		mv 	s1, 	t6	# s1 is now in the pointer	
		
	check_inside:
		addi	s1,	s1,	3
		#mv	s9,	s1
		mv	s1,	s3
		mv	t3,	s3	# current column
		li	t6,	3
		li 	t5, 	3
		
		loop: # stage 5 - belowe width
			addi	a0,	s1,	BYTES_PER_ROW	# going row up
			bge	a0,	s2,	next_loop	# end of pixel array
			jal	get_orgb_from_address		
			bne	a0,	s5,	next_loop	# if not black -> check next
			addi	t5,	t5,	3		# t5 - height (checking if is the same as s6)
			addi	s1,	s1,	BYTES_PER_ROW
			j	loop
		next_loop:
			addi 	t3,	t3,	3
			mv	s1,	t3				# move our iterator to next column
			addi 	t6,	t6,	3			# next width
			bne	t5,	s6,	loop_end_incorrect
				
			li	t5,	3				# base t5
			bgt	t6,	s4,	loop_2
				
			j	loop
			
		loop_2: # stage 6 - below height
			addi	a0,	s1,	BYTES_PER_ROW	# going row up
			bge	a0,	s2,	next_loop_2	
			jal	get_orgb_from_address		
			bne	a0,	s5,	next_loop_2	# if not black -> end
			addi	t5,	t5,	3		
			addi	s1,	s1,	BYTES_PER_ROW
			j	loop_2
		next_loop_2:
			addi 	t3, 	t3, 	3
			mv	s1,	t3
			addi	t6,	t6,	3
			bne	t5,	s8,	loop_end_incorrect
				
			li	t5,	3
			bgt	t6,	s7,	loop_end_correct
				
			j 	loop_2
				
		loop_end_correct:
			mv	s1,	s9	# pointer to the pixel after last in marker
			j	check_outside
				
		loop_end_incorrect:
			mv	s1,	s9
			j	go_to_next_marker
				
	check_outside:
		# s9 -> pixel after marker
		li	t5,	3
		
		# check if pixel (after width arm) is first in row
		sub	a0,	s1,	a2
		li	t3,	BYTES_PER_ROW
		rem	t6,	a0,	t3
		li	t3,	3
		div	t6,	t6,	t3	# x	# check if next pixel is 0
		beqz	t6,	skip
			
		addi	t6,	s8,	6	# because it also takes pixels in cross
		addi	s1,	s1,	-960    # row down

		blt	s1,	a2,	skip
			
		border_1: # stage 8
			addi	a0,	s1,	BYTES_PER_ROW
			jal	get_orgb_from_address		
			beq	a0,	s5,	go_to_next_marker	# if black -> end
			beq	t5,	t6,	border_1_end
			addi	t5,	t5,	3			# t5 - height of border after width
			addi	s1,	s1,	BYTES_PER_ROW
			j	border_1
			
		skip:	# skip border_1 if pixel after mark is first in row
			add 	s1,	s3,	s8
			add	s1,	s1,	s4
				
		border_1_end:
			mv	s1,	s3		# s1 goes to the point where arms cross
			add	s1,	s1,	s4	# we add to it thickness of height
			li	t5,	960	
			mul	t6,	s8,	t5	# we go as many rows so we are at the white pixel where arms cross
			add	s1,	s1,	t6
				
			li	t5,	3
			sub	t6,	s6,	s8	# height - thickness of width
			addi 	t6,	t6,	3	
				
		border_2: # stage 8
			addi	a0,	s1,	BYTES_PER_ROW		# going row up
			bge	a0,	s2,	border_2_end	
			jal	get_orgb_from_address		
			beq	a0,	s5,	go_to_next_marker	# if black -> end
			beq	t5,	t6,	border_2_end
			addi	t5,	t5,	3			# t5 - counter
			addi	s1,	s1,	BYTES_PER_ROW
			j	border_2				
				
		border_2_end:
			li	t5,	3
			addi	s1,	s3,	-3
			addi	s1,	s1,	-960	# row down
			
			# checking if first pixel
			sub	a0,	s3,	a2
			li	t3,	BYTES_PER_ROW
			rem	t6,	a0,	t3
			li	t3,	3
			div	t6,	t6,	t3	# x
			li	t3,	0
			beq	t6,	t3,	skip_2	
				
			addi	t6,	s6,	6
			j	border_3
				
		skip_2:	# skip to the border before height
			add 	s1,	s3,	s8
			add	s1,	s1,	s4
			j 	border_3_end
				
		border_3: # stage 9
			addi	a0,	s1,	BYTES_PER_ROW		# going row up
			bge	a0,	s2,	border_3_end	
			jal	get_orgb_from_address		
			beq	a0,	s5,	go_to_next_marker	# if black -> end
			beq	t5,	t6,	border_3_end
			addi	t5,	t5,	3			# t5 - counter
			addi	s1,	s1,	BYTES_PER_ROW
			j	border_3
				
		border_3_end:
			li	t5,	3
			mv	t6,	s7
			mv	s1,	s3
			addi	s1,	s1,	-BYTES_PER_ROW	# row  down, belowe the point where arms cross
				
			blt	s1,	a2,	add_to_buffer

		border_4: # stage 10
			addi	a0,	s1,	3
			jal	get_orgb_from_address		
			beq	t5,	t6,	border_4_end
			beq	a0,	s5,	go_to_next_marker		
			addi	t5,	t5,	3		
			addi	s1,	s1,	3
			j	border_4
				
		border_4_end:
			mv	s1,	s9
			j	add_to_buffer
				
			
	add_to_buffer:
		# adding correct marker to result buffer
		sw	s3,	(s0)			# store pointer address in result buffer
		addi	s0,	s0,	4		# increment result buffer iterator; so we can add more
		j 	go_to_next_marker
				
	go_to_next_marker:
		# going to find next marker
		addi 	s1, 	s1, 	3
		bge	s1,	s2,	find_marker_end			
		j	next_black

	next:
		# used in finding next black pixel
		addi	s1,	s1,	3		# iterator += 3		
		j	next_black
			
	find_marker_end:
		# this function is important to empty stack 
		
		la	t0,	result_buffer	# start of result buffer
		sub	a0,	s0,	t0	# amount of marker we found -> end - start of an array
		
		 # restore saved registers before returning
		lw	ra,	40(sp)
		lw,	s0,	36(sp)
		lw	s1,	32(sp)
		lw	s2,	28(sp)
		lw	s3,	24(sp)
		lw	s4,	20(sp)
		lw	s5,	16(sp)
		lw	s6,	12(sp)
		lw 	s7, 	8(sp)
		lw	s8,	4(sp)
		lw	s9,	(sp)
		addi	sp,	sp,	44
		# return to caller
		jr	ra

#=====================================================================================
# FILE HANDLING
read_to_buffer:
# reads the contents of a bmp file into memory
# arguments:
	addi sp, sp, -4		#push $s1
	sw s1, 0(sp)
#open file
	li a7, OPEN_FILE
        la a0, fname		#file name 
        li a1, 0		#flags: 0-read file
        ecall
	mv s1, a0      # save the file descriptor
	
 # check for errors - if the file was opened
	li t0, -1             # t0 equal to -1 if the file wasn't found
	beq s1, t0, file_open_error
	
#read file
	li a7, READ_FILE
	mv a0, s1
	la a1, image_buffer
	li a2, MAX_FILE_SIZE
	ecall
	
#check for errors - during read operation
	beqz a0, file_read_error

#close file
	li a7, CLOSE_FILE
	mv a0, s1
        ecall
	
	lw s1, 0(sp)		#restore (pop) s1
	addi sp, sp, 4
	jr ra
		
save_to_file:
# saves contest of buffer to specified filepath
# a0 -> the size of the file or -1 (error)
# a1 -> error message address (if error occurred)

	# store ra
	addi	sp,	sp,	-4
	sw	ra,	(sp)
	
	# fetching file descriptor
	li	a1,	1
	li	a7,	OPEN_FILE
	ecall
	li	t0,	-1
	beq	a0,	t0,	file_open_error	# if a0 (file descriptor) equals -1, branch to file_open_error
	mv	t1,	a0			# move the file descriptor from a0 to t1 for later use
	# writing buffer data to file
	la	a1,	image_buffer		# load the address of image_buffer into a1
	li	a2,	MAX_FILE_SIZE		# load the maximum file size into a2
	li	a7,	WRITE_FILE		
	ecall
		
	mv	t2,	a0			# move the return value (size of written data) from a0 to t2
	# closing file
	mv	a0,	t1
	li	a7,	CLOSE_FILE
	ecall

	mv	a0,	t2			# a0 = size

end_save_to_file:
	# load ra 
	lw	ra,	(sp)
	addi	sp,	sp,	4
	jr	ra

get_pixel_array_start:
	# a0 -> pixel array start
	la	a2,	image_buffer		
	lw	t0,	10(a2)			# t0 -> offset to pixel array; bmp also has header, so we need to find start of pixels
						# bfOffBits
	add	a2,	a2,	t0		# start of our pixel array
	jr	ra
	
get_orgb_from_address:
# returns ORGB value of pixel stored at specified address
	addi	sp,	sp,	-4
	sw	ra, 	0(sp)
	
	mv	t0,	a0
	lbu	a0,	2(t0)			# load R
	
	slli	a0,	a0,	8		# make space for G
	lbu	t1,	1(t0)			# load G
	or	a0,	a0,	t1		# add G to a0
	
	slli	a0,	a0,	8		# make space for B
	lbu	t1,	(t0)			# load B
	or	a0,	a0,	t1		# add B to a0
	
	lw	ra,	0(sp)
	addi	sp,	sp,	4
	jr	ra
	
set_orgb_at_address:
	# a1 -> stores color
	# a0 -> address of pixel
	sb	a1,	(a0)			# store B
	
	srli	a1,	a1,	8		# move to G
	sb	a1,	1(a0)			# store G
	
	srli	a1,	a1,	8		# move to R
	sb	a1,	2(a0)			# store R
	jr	ra
	
print_coords:
# prints coords of red spots -> where the arms of marker are crossing
	# need to store a return address, beacuse otherwise we
	# have issues regarding it
	
	addi	sp,	sp,	-8
	sw	ra,	4(sp)
	sw	s1,	(sp)
	
	mv	s1,	a0		# address
	
	# address - start of pixel array
	sub	s1,	s1,	a2	
	li	t3,	BYTES_PER_ROW	
	rem	t0,	s1,	t3	# the offset within a row in bytes
	div	t1,	s1,	t3	# reversed y-coordinate of the pixel (from the end)
	
	li	t3,	3
	div	t0,	t0,	t3	# x coord
	li	t3,	239		
	sub	t1,	t3,	t1	# y coord
	
	# PRINTING
	mv	a0,	t0		# a0 = x coords
	li	a7,	PRINT_INT
	ecall
	
	li	a0,	'x'
	li	a7,	PRINT_CHAR
	ecall
	
	mv	a0,	t1		# a0 = y coords
	li	a7,	PRINT_INT
	ecall
	
	li	a0,	'\n'
	li	a7,	PRINT_CHAR
	ecall
	
	# load ra and s1
	lw	ra,	4(sp)
	lw	s1,	(sp)
	addi	sp,	sp,	8
	jr	ra
	
result_message:
	# Printing result message
	li 	a7, 	PRINT_STRING
	la	a0,	res_message
	ecall
	jr ra
	
file_open_error:
	la a1, open_error
	lw ra, (sp)
	addi sp, sp, 4
	j print_error
	
file_read_error:
	la a1, read_error
	lw ra, (sp)
	addi sp, sp, 4
	j print_error

print_error:
	mv	a0,	a1
	li	a7,	PRINT_STRING
	ecall
	j	end
end:
	li	a7,	EXIT
	ecall
