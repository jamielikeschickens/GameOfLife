/*
 * common.h
 *
 *  Created on: Nov 19, 2014
 *      Author: jamie
 */

#ifndef COMMON_H_
#define COMMON_H_

#define DEBUG 1

#if !DEBUG
#define printf(...);
#endif

typedef unsigned char uchar;
#define IMHT 16
#define IMWD 16

#define BUTTON_A 14
#define BUTTON_B 13
#define BUTTON_C 11
#define BUTTON_D 7
#define NO_BUTTON 15

#endif /* COMMON_H_ */
