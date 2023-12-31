/***************************************************************************
 *                         Arrays of Arbitrary Bit Length
 *
 *   File    : bitarray.c
 *   Purpose : Provides functions for creation and manipulation of arbitrary
 *             length arrays of bits.
 *
 *             Bit arrays are implemented as arrays of unsigned chars.  Bit
 *             0 is the MSB of char 0, and the last bit is the least
 *             significant (non-spare) bit of the last unsigned long.
 *
 *             Example: array of 20 bits (0 through 19) with 8 bit unsigned
 *                      chars requires 3 unsigned chars (0 through 2) to
 *                      store all the bits.
 *
 *                        char       0       1         2
 *                               +--------+--------+--------+
 *                               |        |        |        |
 *                               +--------+--------+--------+
 *                        bit     01234567 8911111111111XXXX
 *                                           012345 6789
 *
 *   Author  : Michael Dipperstein
 *   Date    : January 30, 2004
 *
 ****************************************************************************
 *
 * Bitarray: An ANSI C library for manipulating arbitrary length bit arrays
 * Copyright (C) 2004, 2006-2007, 2014 by
 *   Michael Dipperstein (mdipperstein@gmail.com)
 *
 * This file is part of the bit array library.
 *
 * The bit array library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public License as
 * published by the Free Software Foundation; either version 3 of the
 * License, or (at your option) any later version.
 *
 * The bit array library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser
 * General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 ***************************************************************************/

/***************************************************************************
 *                             INCLUDED FILES
 ***************************************************************************/
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <limits.h>
#include <string.h>
#include "bitarray.h"

/***************************************************************************
 *                                 MACROS
 ***************************************************************************/

/* make LONG_BIT 64 if it's not defined in limits.h */
#ifndef LONG_BIT
/*#warning LONG_BIT not defined.  Assuming 64 bits.
 */
#define LONG_BIT 64
#endif

/* position of bit within character */
#define BIT_CHAR(bit)         ((bit) / LONG_BIT)

/* array index for character containing bit */
#define BIT_IN_CHAR(bit)      (1UL << (LONG_BIT - 1 - ((bit)  % LONG_BIT)))

/* number of characters required to contain number of bits */
#define BITS_TO_CHARS(bits)   ((((bits) - 1) / LONG_BIT) + 1)

/* most significant bit in a character */
#define MS_BIT                (1UL << (LONG_BIT - 1))

/***************************************************************************
 *                                FUNCTIONS
 ***************************************************************************/

/***************************************************************************
 *   Function   : BitArrayCreate
 *   Description: This function allocates a bit array large enough to
 *                contain the specified number of bits.  The contents of the
 *                array are not initialized.
 *   Parameters : bits - the number of bits in the array to be allocated.
 *   Effects    : allocates bit array from heap, or sets errno on failure.
 *   Returned   : pointer to allocated bit array or NULL if array may not
 *                be allocated.  errno will be set in the event that the
 *                array may not be allocated.
 ***************************************************************************/
bit_array_t *BitArrayCreate(const unsigned long bits)
{
	bit_array_t *ba;

	if (0 == bits)
	{
		errno = EDOM;
		return NULL;
	}

	/* allocate structure */
	ba = (bit_array_t *)malloc(sizeof(bit_array_t));

	if (ba == NULL)
	{
		/* malloc failed */
		errno = ENOMEM;
	}
	else
	{
		ba->numBits = bits;

		/* allocate array */
		ba->array = (unsigned long *)malloc(sizeof(unsigned long) *
				BITS_TO_CHARS(bits));

		if (ba->array == NULL)
		{
			/* malloc failed */
			errno = ENOMEM;
			free(ba);
			ba = NULL;
		}
	}

	return ba;
}

/***************************************************************************
 *   Function   : BitArrayDestroy
 *   Description: This function frees the memory allocated for a bit array.
 *   Parameters : ba - pointer to bit array to be freed
 *   Effects    : frees memory pointed to by bit array structure.
 *   Returned   : None
 ***************************************************************************/
void BitArrayDestroy(bit_array_t *ba)
{
	if (ba != NULL)
	{
		if (ba->array != NULL)
		{
			free(ba->array);
		}

		free(ba);
	}
}

/***************************************************************************
 *   Function   : BitArrayDump
 *   Description: This function dumps the contents of a bit array to the
 *                specified output stream.  The format of the dump is a
 *                series of bytes represented in hexadecimal.
 *   Parameters : ba - pointer to bit array to be dumped
 *                outFile - pointer to output steam to be used.  If NULL
 *                          stdout will be used.
 *   Effects    : Hexadecimal dump of array to outFile.
 *   Returned   : None
 *   NOTE: This function only works with 8 bit characters.
 ***************************************************************************/
void BitArrayDump(const bit_array_t *const ba, FILE *outFile)
{
	unsigned i;

	if ((ba == NULL) || (ba->numBits == 0))
	{
		return;         /* nothing to print */
	}

	if (outFile == NULL)
	{
		outFile = stdout;
	}

	fprintf(outFile, "%02lX", ba->array[0]);     /* first byte */

	for (i = 1; i < BITS_TO_CHARS(ba->numBits); i++)
	{
		/* remaining bytes with a leading space */
		fprintf(outFile, " %02lX", ba->array[i]);
	}
}

/***************************************************************************
 *   Function   : BitArraySetAll
 *   Description: This function sets every bit to 1 in the bit array passed
 *                as a parameter.  This is function uses ULONG_MAX, so it is
 *                crucial that the machine implementation of unsigned long
 *                utilizes all the bits in the memory allocated for an
 *                unsigned long.
 *   Parameters : ba - pointer to bit array
 *   Effects    : Each of the bits used in the bit array are set to 1.
 *                Unused (spare) bits are set to 0.
 *   Returned   : NONE
 ***************************************************************************/
void BitArraySetAll(const bit_array_t *const ba)
{
	unsigned bits;
	unsigned long mask;

	if (ba == NULL)
	{
		return;         /* nothing to set */
	}

	/* set bits in all bytes to 1 */
	memset((void *)(ba->array), ~0, 
			BITS_TO_CHARS(ba->numBits)*sizeof(unsigned long));

	/* zero any spare bits so increment and decrement are consistent */
	bits = ba->numBits % LONG_BIT;
	if (bits != 0)
	{
		mask = ULONG_MAX << (LONG_BIT - bits);
		ba->array[BIT_CHAR(ba->numBits - 1)] = mask;
	}
}

/***************************************************************************
 *   Function   : BitArrayClearAll
 *   Description: This function sets every bit to 0 in the bit array passed
 *                as a parameter.
 *   Parameters : ba - pointer to bit array
 *   Effects    : Each of the bits used in the bit array are set to 0.
 *   Returned   : NONE
 ***************************************************************************/
void BitArrayClearAll(const bit_array_t *const ba)
{
	if (ba == NULL)
	{
		return;         /* nothing to clear */
	}

	/* set bits in all bytes to 0 */
	memset((void *)(ba->array), 0, BITS_TO_CHARS(ba->numBits)*sizeof(unsigned long));
}

/***************************************************************************
 *   Function   : BitArraySetBit
 *   Description: This function sets the specified bit to 1 in the bit array
 *                passed as a parameter.
 *   Parameters : ba - pointer to bit array
 *                bit - bit to set
 *   Effects    : The specified bit in the bit array is set to 1.
 *   Returned   : 0 for success, -1 for failure.  errno will be set in the
 *                event of a failure.
 ***************************************************************************/
int BitArraySetBit(const bit_array_t *const ba, const unsigned int bit)
{
	if (ba == NULL)
	{
		return 0;       /* no bit to set */
	}

	if (ba->numBits <= bit)
	{
		errno = ERANGE;
		return -1;      /* bit out of range */
	}

	ba->array[BIT_CHAR(bit)] |= BIT_IN_CHAR(bit);
	return 0;
}

/***************************************************************************
 *   Function   : BitArrayClearBit
 *   Description: This function sets the specified bit to 0 in the bit array
 *                passed as a parameter.
 *   Parameters : ba - pointer to bit array
 *                bit - bit to clear
 *   Effects    : The specified bit in the bit array is set to 0.
 *   Returned   : 0 for success, -1 for failure.  errno will be set in the
 *                event of a failure.
 ***************************************************************************/
int BitArrayClearBit(const bit_array_t *const ba, const unsigned int bit)
{
	unsigned long mask;

	if (ba == NULL)
	{
		return 0;       /* no bit to set */
	}

	if (ba->numBits <= bit)
	{
		errno = ERANGE;
		return -1;      /* bit out of range */
	}

	/* create a mask to zero out desired bit */
	mask =  BIT_IN_CHAR(bit);
	mask = ~mask;

	ba->array[BIT_CHAR(bit)] &= mask;
	return 0;
}

/***************************************************************************
 *   Function   : BitArrayGetBits
 *   Description: This function returns a pointer to the array of unsigned
 *                char containing actual bits.  This function should be used
 *                with caution.  Manipulating the array of bits outside of
 *                the bit array function may have adverse effects.
 *   Parameters : ba - pointer to bit array
 *   Effects    : None
 *   Returned   : Pointer to array containing bits
 ***************************************************************************/
void *BitArrayGetBits(const bit_array_t *const ba)
{
	if (NULL == ba)
	{
		return NULL;
	}

	return ((void *)(ba->array));
}


/***************************************************************************
 *   Function   : BitArrayTestBit
 *   Description: This function tests the specified bit in the bit array
 *                passed as a parameter.  A non-zero will be returned if the
 *                tested bit is set.
 *   Parameters : ba - pointer to bit array
 *                bit - bit to test
 *   Effects    : None
 *   Returned   : Non-zero if bit is set, otherwise 0.  This function does
 *                not check the input.  Tests on invalid input will produce
 *                unknown results.
 ***************************************************************************/
int BitArrayTestBit(const bit_array_t *const ba, const unsigned int bit)
{
	return((ba->array[BIT_CHAR(bit)] & BIT_IN_CHAR(bit)) != 0);
}

/***************************************************************************
 *   Function   : BitArrayCopy
 *   Description: This function copies the contents of a source bit array
 *                into the destination.  If the two arrays are not the same
 *                size or either array pointer is NULL, a copy will not take
 *                place and errno will be set to EPERM.
 *   Parameters : dest - pointer to destination bit array
 *                src - pointer to source bit array
 *   Effects    : The contents of the source bit array are copied to the
 *                destination bit array.
 *   Returned   : 0 for success, -1 for failure.  errno will be set in the
 *                event of a failure.
 ***************************************************************************/
int BitArrayCopy(const bit_array_t *const dest, const bit_array_t *const src)
{
	if ((NULL == src) || (NULL == dest))
	{
		errno = EPERM;
		return -1;      /* no source array */
	}

	if (src->numBits != dest->numBits)
	{
		errno = EPERM;
		return -1;      /* source and destination are not the same size */
	}

	/* copy source to destination */
	memcpy((void *)(dest->array), (void *)(src->array),
			BITS_TO_CHARS(src->numBits)*sizeof(unsigned long));

	return 0;
}

/***************************************************************************
 *   Function   : BitArrayDuplicate
 *   Description: This function duplicates (creates and copies) the bit array
 *                passed as a parameter and returns a pointer to the
 *                duplicate.
 *   Parameters : src - pointer to bit array to be duplicated
 *   Effects    : A duplicate of the source bit array is created.
 *   Returned   : Pointer to duplicate of source or NULL on failure.  errno
 *                will be set in the event that the array may not be
 *                duplicated.
 ***************************************************************************/
bit_array_t *BitArrayDuplicate(const bit_array_t *const src)
{
	bit_array_t *ba;

	if (src == NULL)
	{
		errno = EPERM;
		return NULL;    /* no source array */
	}

	ba = BitArrayCreate(src->numBits);

	if (ba != NULL)
	{
		ba->numBits = src->numBits;
		BitArrayCopy(ba, src);
	}

	return ba;
}

/***************************************************************************
 *   Function   : ValidateArgs
 *   Description: This function validates the arguments passed in to the
 *                logical operation functions.  All pointers must be non-NULL
 *                and have the same array length.
 *   Parameters : dest - pointer to destination bit array
 *                src1 - pointer to first source bit array
 *                src2 - pointer to second source bit array
 *   Effects    : errno is set when arguments are invalid
 *   Returned   : 0 for success, -1 for failure.  errno will be set to EPERM
 *                in the event of a failure.
 ***************************************************************************/
int ValidateArgs(const bit_array_t *const dest,
		const bit_array_t *const src1,
		const bit_array_t *const src2)
{
	if ((NULL == src1) || (NULL == src2) || (NULL == dest))
	{
		errno = EPERM;
		return -1;      /* NULL source(s) and/or destination */
	}

	if ((src1->numBits != dest->numBits) || (src2->numBits != dest->numBits))
	{
		errno = EPERM;
		return -1;      /* source(s) and/or size mismatch */
	}

	return 0;
}

/***************************************************************************
 *   Function   : BitArrayAnd
 *   Description: This function performs a bitwise AND between two bit
 *                arrays, storing the results in a third bit array.  If the
 *                arrays are NULL or different sizes, no operation will
 *                will occur.
 *   Parameters : dest - pointer to destination bit array
 *                src1 - pointer to first source bit array
 *                src2 - pointer to second source bit array
 *   Effects    : dest will contain the results of a bitwise AND of src1 and
 *                src2 unless one array pointer is NULL or arrays are
 *                different sizes.
 *   Returned   : 0 for success, -1 for failure.  errno will be set in the
 *                event of a failure.
 ***************************************************************************/
int BitArrayAnd(const bit_array_t *const dest,
		const bit_array_t *const src1,
		const bit_array_t *const src2)
{
	unsigned i;

	if (0 != ValidateArgs(dest, src1, src2))
	{
		return -1;
	}

	/* AND array one unsigned long at a time */
	for(i = 0; i < BITS_TO_CHARS(dest->numBits); i++)
	{
		dest->array[i] = src1->array[i] & src2->array[i];
	}

	return 0;
}

/***************************************************************************
 *   Function   : BitArrayOr
 *   Description: This function performs a bitwise OR between two bit
 *                arrays, storing the results in a third bit array.  If the
 *                arrays are NULL or different sizes, no operation will
 *                will occur.
 *   Parameters : dest - pointer to destination bit array
 *                src1 - pointer to first source bit array
 *                src2 - pointer to second source bit array
 *   Effects    : dest will contain the results of a bitwise OR of src1 and
 *                src2 unless one array pointer is NULL or arrays are
 *                different sizes.
 *   Returned   : 0 for success, -1 for failure.  errno will be set in the
 *                event of a failure.
 ***************************************************************************/
int BitArrayOr(const bit_array_t *const dest,
		const bit_array_t *const src1,
		const bit_array_t *const src2)
{
	unsigned i;

	if (0 != ValidateArgs(dest, src1, src2))
	{
		return -1;
	}

	/* OR array one unsigned long at a time */
	for(i = 0; i < BITS_TO_CHARS(dest->numBits); i++)
	{
		dest->array[i] = src1->array[i] | src2->array[i];
	}

	return 0;
}

/***************************************************************************
 *   Function   : BitArrayXor
 *   Description: This function performs a bitwise XOR between two bit
 *                arrays, storing the results in a third bit array.  If the
 *                arrays are NULL or different sizes, no operation will
 *                will occur.
 *   Parameters : dest - pointer to destination bit array
 *                src1 - pointer to first source bit array
 *                src2 - pointer to second source bit array
 *   Effects    : dest will contain the results of a bitwise XOR of src1 and
 *                src2 unless one array pointer is NULL or arrays are
 *                different sizes.
 *   Returned   : 0 for success, -1 for failure.  errno will be set in the
 *                event of a failure.
 ***************************************************************************/
int BitArrayXor(const bit_array_t *const dest,
		const bit_array_t *const src1,
		const bit_array_t *const src2)
{
	unsigned i;

	if (0 != ValidateArgs(dest, src1, src2))
	{
		return -1;
	}

	/* XOR array one unsigned long at a time */
	for(i = 0; i < BITS_TO_CHARS(dest->numBits); i++)
	{
		dest->array[i] = src1->array[i] ^ src2->array[i];
	}

	return 0;
}

/***************************************************************************
 *   Function   : BitArrayNot
 *   Description: This function performs a bitwise NOT of one bit array
 *                storing the results in another bit array.  If the arrays
 *                are NULL or different sizes, no operation will will occur.
 *   Parameters : dest - pointer to destination bit array
 *                src - pointer to source bit array
 *   Effects    : dest will contain the results of a bitwise NOT of src
 *                unless one array pointer is NULL or arrays are different
 *                sizes.
 *   Returned   : 0 for success, -1 for failure.  errno will be set in the
 *                event of a failure.
 ***************************************************************************/
int BitArrayNot(const bit_array_t *const dest,
		const bit_array_t *const src)
{
	unsigned i;
	unsigned bits;
	unsigned long mask;

	if ((NULL == src) || (NULL == dest))
	{
		errno = EPERM;
		return -1;      /* NULL source and/or destination */
	}

	if (src->numBits != dest->numBits)
	{
		errno = EPERM;
		return -1;      /* size mismatch */
	}

	/* NOT array one unsigned long at a time */
	for(i = 0; i < BITS_TO_CHARS(dest->numBits); i++)
	{
		dest->array[i] = ~(src->array[i]);
	}

	/* zero any spare bits so increment and decrement are consistent */
	bits = dest->numBits % LONG_BIT;
	if (bits != 0)
	{
		mask = ULONG_MAX << (LONG_BIT - bits);
		dest->array[BIT_CHAR(dest->numBits - 1)] &= mask;
	}

	return 0;
}

/***************************************************************************
 *   Function   : BitArrayShiftLeft
 *   Description: This function shifts the bits in a bit array to the left
 *                by the amount of positions specified.
 *   Parameters : ba - pointer to the bit array 0 is the msb of the first
 *                     unsigned long in the bit array.
 *                shifts - number of bits to shift by.
 *   Effects    : The bit array data pointed to by ba is shifted to the left.
 *                New bits shifted in will be set to 0.
 *   Returned   : 0 for success, -1 for failure.  errno will be set in the
 *                event of a failure.
 ***************************************************************************/
int BitArrayShiftLeft(const bit_array_t *const ba, unsigned int shifts)
{
	unsigned i;
	unsigned j;
	unsigned chars;

	if (NULL == ba)
	{
		errno = EPERM;
		return -1;      /* not permitted on NULL array */
	}

	chars = shifts / LONG_BIT;      /* number of whole byte shifts */
	shifts = shifts % LONG_BIT;     /* number of bit shifts remaining */

	if (shifts >= ba->numBits)
	{
		/* all bits have been shifted off */
		BitArrayClearAll(ba);
		return 0;
	}

	/* first handle big jumps of bytes */
	if (chars != 0)
	{
		for (i = 0; (i + chars) <  BITS_TO_CHARS(ba->numBits); i++)
		{
			ba->array[i] = ba->array[i + chars];
		}

		/* now zero out new bytes on the right */
		for (i = BITS_TO_CHARS(ba->numBits); chars != 0; chars--)
		{
			ba->array[i - chars] = 0;
		}
	}

	/* now we have at most LONG_BIT - 1 bit shifts across the whole array */
	for (i = 0; i < shifts; i++)
	{
		for (j = 0; j < BIT_CHAR(ba->numBits - 1); j++)
		{
			ba->array[j] <<= 1;

			/* handle shifts across byte bounds */
			if (ba->array[j + 1] & MS_BIT)
			{
				ba->array[j] |= 0x01;
			}
		}

		ba->array[BIT_CHAR(ba->numBits - 1)] <<= 1;
	}

	return 0;
}

/***************************************************************************
 *   Function   : BitArrayShiftRight
 *   Description: This function shifts the bits in a bit array to the right
 *                by the amount of positions specified.
 *   Parameters : ba - pointer to the bit array 0 is the msb of the first
 *                     unsigned long in the bit array.
 *                shifts - number of bits to shift by.
 *   Effects    : The bit array data pointed to by ba is shifted to the
 *                right.  New bits shifted in will be set to 0.
 *   Returned   : 0 for success, -1 for failure.  errno will be set in the
 *                event of a failure.
 ***************************************************************************/
int BitArrayShiftRight(const bit_array_t *const ba, unsigned int shifts)
{
	unsigned i;
	unsigned j;
	unsigned long mask;
	unsigned chars;

	if (NULL == ba)
	{
		errno = EPERM;
		return -1;      /* not permitted on NULL array */
	}

	chars = shifts / LONG_BIT;      /* number of whole byte shifts */
	shifts = shifts % LONG_BIT;     /* number of bit shifts remaining */

	if (shifts >= ba->numBits)
	{
		/* all bits have been shifted off */
		BitArrayClearAll(ba);
		return 0;
	}

	/* first handle big jumps of bytes */
	if (chars > 0)
	{
		for (i = BIT_CHAR(ba->numBits - 1); i >= chars; i--)
		{
			ba->array[i] = ba->array[i - chars];
		}

		/* now zero out new bytes on the right */
		for (; chars > 0; chars--)
		{
			ba->array[chars - 1] = 0;
		}
	}

	/* now we have at most LONG_BIT - 1 bit shifts across the whole array */
	for (i = 0; i < shifts; i++)
	{
		for (j = BIT_CHAR(ba->numBits - 1); j > 0; j--)
		{
			ba->array[j] >>= 1;

			/* handle shifts across byte bounds */
			if (ba->array[j - 1] & 0x01)
			{
				ba->array[j] |= MS_BIT;
			}
		}

		ba->array[0] >>= 1;
	}

	/***********************************************************************
	 * zero any spare bits that are beyond the end of the bit array so
	 * increment and decrement are consistent.
	 ***********************************************************************/
	i = ba->numBits % LONG_BIT;
	if (i != 0)
	{
		mask = ULONG_MAX << (LONG_BIT - i);
		ba->array[BIT_CHAR(ba->numBits - 1)] &= mask;
	}

	return 0;
}

/***************************************************************************
 *   Function   : BitArrayIncrement
 *   Description: This function increments a bit array as if it is an
 *                unsigned value of the specified number of bits.
 *   Parameters : ba - pointer bit array to be incremented
 *   Effects    : ba will contain the results of an increment operation
 *                performed on itself.  Any spare bits in the array of
 *                unsigned longacters containing the bits will be set to 0.
 *   Returned   : 0 for success, -1 for failure.  errno will be set in the
 *                event of a failure.
 ***************************************************************************/
int BitArrayIncrement(const bit_array_t *const ba)
{
	int i;
	unsigned long maxValue;     /* maximum value for current char */
	unsigned long one;          /* least significant bit in current char */

	if (NULL == ba)
	{
		errno = EPERM;
		return -1;      /* not permitted on NULL array */
	}

	/* handle arrays that don't use every bit in the last character */
	i = (ba->numBits % LONG_BIT);
	if (i != 0)
	{
		maxValue = ULONG_MAX << (LONG_BIT - i);
		one = 1 << (LONG_BIT - i);
	}
	else
	{
		maxValue = ULONG_MAX;
		one = 1;
	}

	for (i = BIT_CHAR(ba->numBits - 1); i >= 0; i--)
	{
		if (ba->array[i] != maxValue)
		{
			ba->array[i] = ba->array[i] + one;
			return 0;
		}
		else
		{
			/* need to carry to next byte */
			ba->array[i] = 0;

			/* remaining characters must use all bits */
			maxValue = ULONG_MAX;
			one = 1;
		}
	}

	return 0;
}

/***************************************************************************
 *   Function   : BitArrayDecrement
 *   Description: This function decrements a bit array as if it is an
 *                unsigned value of the specified number of bits.
 *   Parameters : ba - pointer bit array to be decremented
 *   Effects    : ba will contain the results of a decrement operation
 *                performed on itself.  Any spare bits in the array of
 *                unsigned longacters containing the bits will be set to 0.
 *   Returned   : 0 for success, -1 for failure.  errno will be set in the
 *                event of a failure.
 ***************************************************************************/
int BitArrayDecrement(const bit_array_t *const ba)
{
	int i;
	unsigned long maxValue;     /* maximum value for current char */
	unsigned long one;          /* least significant bit in current char */

	if (NULL == ba)
	{
		errno = EPERM;
		return -1;      /* not permitted on NULL array */
	}

	/* handle arrays that don't use every bit in the last character */
	i = (ba->numBits % LONG_BIT);
	if (i != 0)
	{
		maxValue = ULONG_MAX << (LONG_BIT - i);
		one = 1 << (LONG_BIT - i);
	}
	else
	{
		maxValue = ULONG_MAX;
		one = 1;
	}

	for (i = BIT_CHAR(ba->numBits - 1); i >= 0; i--)
	{
		if (ba->array[i] >= one)
		{
			ba->array[i] = ba->array[i] - one;
			return 0;
		}
		else
		{
			/* need to borrow from the next byte */
			ba->array[i] = maxValue;

			/* remaining characters must use all bits */
			maxValue = ULONG_MAX;
			one = 1;
		}
	}

	return 0;
}

/***************************************************************************
 *   Function   : BitArrayCompare
 *   Description: This function compares two bit arrays.
 *   Parameters : ba1 - pointer to bit array
 *                ba2 - pointer to bit array
 *   Effects    : None
 *   Returned   : < 0 if ba1 < ba2 or ba1 is shorter than ba2
 *                0 if ba1 == ba2
 *                > 0 if ba1 > ba2 or ba1 is longer than ba2
 *
 * NOTE: with unsigned long only do checks that return a positive number
 * else it will be misleading
 ***************************************************************************/
unsigned long BitArrayCompare(const bit_array_t *ba1, const bit_array_t *ba2)
{
	unsigned i;

	if (ba1 == NULL)
	{
		if (ba2 == NULL)
		{
			return 0;                   /* both are NULL */
		}
		else
		{
			return -(ba2->numBits);     /* ba2 is the only Non-NULL*/
		}
	}

	if (ba2 == NULL)
	{
		return (ba1->numBits);          /* ba1 is the only Non-NULL*/
	}

	if (ba1->numBits != ba2->numBits)
	{
		/* arrays are different sizes */
		return (ba1->numBits - ba2->numBits);
	}

	for(i = 0; i <= BIT_CHAR(ba1->numBits - 1); i++)
	{
		if (ba1->array[i] != ba2->array[i])
		{
			/* found a non-matching unsigned long */
			return (ba1->array[i] - ba2->array[i]);
		}
	}

	return 0;
}
