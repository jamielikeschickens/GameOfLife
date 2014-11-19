/*
 * distributor.xc
 *
 *  Created on: Nov 19, 2014
 *      Author: jamie
 */

#include <platform.h>
#include <stdio.h>
#include "common.h"

void harvest_results(chanend c_out, chanend to_worker_1, chanend to_worker_2, chanend to_worker_3, chanend to_worker_4);

void distributor(chanend c_in, chanend c_out, chanend to_worker_1, chanend to_worker_2, chanend to_worker_3, chanend to_worker_4) {
	uchar val;
	printf("ProcessImage:Start, size = %dx%d\n", IMHT, IMWD);
	//This code is to be replaced – it is a place holder for farming out the work...

	for (int x=0; x < IMWD+2; ++x) {
		val = 0;
		to_worker_1 <: val;
	}

	// Send lines 1-5 to workers
	for (int y=1; y <= 5; ++y) {
		for (int x=0; x < IMWD+2; ++x) {
			if (x == 0 || x == IMWD+1) {
				// If we are at the sides send a padding cell
				val = 0;
				to_worker_1 <: val;

				// If we're on lines 4 or 5 also send the padding to worker 2
				if (y == 4 || y == 5) {
					val = 0;
					to_worker_2 <: val;
				}
			} else {
				// Else send the actual data
				c_in :> val;
				to_worker_1 <: val;

				// If we're reading lines 4 or 5 we need to send them to worker 2 as well
				if (y == 4 || y == 5) {
					to_worker_2 <: val;
				}
			}
		}
	}

	for (int y=6; y <=9; ++y) {
		for (int x = 0; x < IMWD + 2; ++x) {
			if (x == 0 || x == IMWD + 1) {
				// If we are at the sides send a padding cell
				val = 0;
				to_worker_2 <: val;

				if (y == 8 || y == 9) {
					val = 0;
					to_worker_3 <: val;
				}

			} else {
				// Else send the actual data
				c_in :> val;
				to_worker_2 <: val;

				// If we're reading lines 8 or 9 we need to send them to worker 3 as well
				if (y == 8 || y == 9) {
					to_worker_3 <: val;
				}
			}
		}
	}

	for (int y=10; y <= 13; ++y) {
		for (int x = 0; x < IMWD + 2; ++x) {
			if (x == 0 || x == IMWD + 1) {
				// If we are at the sides send a padding cell
				val = 0;
				to_worker_3 <: val;

				if (y == 12 || y == 13) {
					val = 0;
					to_worker_4 <: val;
				}

			} else {
				// Else send the actual data
				c_in :> val;
				to_worker_3 <: val;

				// If we're reading lines 12 or 13 we need to send them to worker 4 as well
				if (y == 12 || y == 13) {
					to_worker_4 <: val;
				}
			}
		}
	}

	for (int y=14; y <= IMHT; ++y) {
		for (int x = 0; x < IMWD + 2; ++x) {
			if (x == 0 || x == IMWD + 1) {
				// If we are at the sides send a padding cell
				val = 0;
				to_worker_4 <: val;
			} else {
				// Else send the actual data
				c_in :> val;
				to_worker_4 <: val;
			}
		}
	}

	// Send last buffer bytes
    for (int x = 0; x < IMWD + 2; ++x) {
		val = 0;
		to_worker_4 <: val;
	}

    harvest_results(c_out, to_worker_1, to_worker_2, to_worker_3, to_worker_4);

	printf( "ProcessImage:Done...\n" );
}

void harvest_results(chanend c_out, chanend to_worker_1, chanend to_worker_2, chanend to_worker_3, chanend to_worker_4) {

	// Start gathering data back and sending it to data out stream
	for (int row=0; row < 4; ++row) {
		for (int column=0; column < IMWD; ++column) {
			uchar val;
			to_worker_1 :> val;
			c_out <: val;
		}
	}

}
