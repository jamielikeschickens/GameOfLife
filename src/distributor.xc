/*
 * distributor.xc
 *
 *  Created on: Nov 19, 2014
 *      Author: jamie
 */

#include <platform.h>
#include <stdio.h>
#include "common.h"

void harvest_results(chanend to_worker_1, chanend to_worker_2, chanend to_worker_3, chanend to_worker_4);
void processImage(chanend c_in, chanend to_worker_1, chanend to_worker_2, chanend to_worker_3, chanend to_worker_4);

void distributor(chanend c_in, chanend c_out, chanend to_worker_1, chanend to_worker_2, chanend to_worker_3, chanend to_worker_4, chanend to_button_listener) {
	//This code is to be replaced – it is a place holder for farming out the work...

	int button;

	while (1) {
	    to_button_listener :> button;

        if (button == BUTTON_A) {
            processImage(c_in, to_worker_1, to_worker_2, to_worker_3, to_worker_4);
        } else if (button == BUTTON_C) {
	    }
	}
}

void processImage(chanend c_in, chanend to_worker_1, chanend to_worker_2, chanend to_worker_3, chanend to_worker_4) {
    printf("ProcessImage:Start, size = %dx%d\n", IMHT, IMWD);

    uchar val;
    for (int x = 0; x < IMWD + 2; ++x) {
        val = 0;
        to_worker_1 <: val;
    }

    // Send lines 1-5 to workers
    for (int y = 1; y <= 5; ++y) {
        for (int x = 0; x < IMWD + 2; ++x) {
            if (x == 0 || x == IMWD + 1) {
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

    for (int y = 6; y <= 9; ++y) {
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

    for (int y = 10; y <= 13; ++y) {
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

    for (int y = 14; y <= IMHT; ++y) {
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

    printf( "ProcessImage:Done...\n" );

    // Wait for workers to send back the overlapping lines so we can send them back out
    harvest_results(to_worker_1, to_worker_2, to_worker_3, to_worker_4);
}

void harvest_results(chanend to_worker_1, chanend to_worker_2, chanend to_worker_3, chanend to_worker_4) {
	while (1) {
        // Store the overlapping lines we send
        uchar worker_1_lines[2][IMWD+2];

        for (int i=0; i < IMWD+2; ++i) {
            to_worker_1 :> worker_1_lines[0][i];
            to_worker_1 :> worker_1_lines[1][i];
        }

        uchar worker_2_lines[2][IMWD+2];

        for (int i=0; i < IMWD+2; ++i) {
            to_worker_2 :> worker_2_lines[0][i];
            to_worker_2 :> worker_2_lines[1][i];
        }

        uchar worker_3_lines[2][IMWD+2];

        for (int i=0; i < IMWD+2; ++i) {
            to_worker_3 :> worker_3_lines[0][i];
            to_worker_3 :> worker_3_lines[1][i];
        }

        uchar worker_4_lines[2][IMWD+2];

        for (int i=0; i < IMWD+2; ++i) {
            to_worker_4 :> worker_4_lines[0][i];
            to_worker_4 :> worker_4_lines[1][i];
        }

        // Start sending the lines back out to workers
        //



        for (int i=0; i < IMWD+2; ++i) {
            // Worker 1's top line is all blanks so he can just
            // replace with blanks again
        	uchar val = 0;
        	to_worker_1 <: val;
            to_worker_1 <: worker_2_lines[0][i];
        }

        for (int i =0; i < IMWD+2; ++i) {
            to_worker_2 <: worker_1_lines[1][i];
            to_worker_2 <: worker_3_lines[0][i];
        }

        for (int i=0; i < IMWD+2; ++i) {
            to_worker_3 <: worker_2_lines[1][i];
            to_worker_3 <: worker_4_lines[0][i];
        }

        for (int i=0; i < IMWD+2; ++i) {
            uchar val = 0;
            to_worker_4 <: worker_3_lines[0][i];
            // Bottom row for 4 is blank as before so set those
            to_worker_4 <: val;

        }

        printf("One iteration done, overlapping lines sent back\n");
	}
}
