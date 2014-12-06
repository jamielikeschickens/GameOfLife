/*
 * distributor.xc
 *
 *  Created on: Nov 19, 2014
 *      Author: jamie
 */

#include <platform.h>
#include <stdio.h>
#include "common.h"
#include "distributor.h"

void harvest_results(chanend c_out, chanend button_listener, chanend to_visaliser, chanend to_worker_1, chanend to_worker_2, chanend to_worker_3, chanend to_worker_4);
void processImage(chanend c_out, chanend c_in, chanend to_worker_1, chanend to_worker_2, chanend to_worker_3, chanend to_worker_4);
void receiveAllData(chanend c_out, chanend worker_1, chanend worker_2, chanend worker_3, chanend worker_4);

void distributor(chanend c_in, chanend c_out, chanend to_visualiser, chanend to_worker_1, chanend to_worker_2, chanend to_worker_3, chanend to_worker_4, chanend to_button_listener) {
	//This code is to be replaced – it is a place holder for farming out the work...

	int button;
	to_button_listener :> button;
	to_button_listener <: CONTINUE;

	while (button != BUTTON_A) {
		to_button_listener :> button;
		to_button_listener <: CONTINUE;
	}
    processImage(c_out, c_in, to_worker_1, to_worker_2, to_worker_3, to_worker_4);
    // Wait for workers to send back the overlapping lines so we can send them back out
    harvest_results(c_out, to_button_listener, to_visualiser, to_worker_1, to_worker_2, to_worker_3, to_worker_4);

    printf("Distributor temrinate\n");
}

void processImage(chanend c_out, chanend c_in, chanend to_worker_1, chanend to_worker_2, chanend to_worker_3, chanend to_worker_4) {
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

}

void terminate_all(chanend c_out, chanend to_button_listener, chanend to_visualiser, chanend to_worker_1, chanend to_worker_2, chanend to_worker_3, chanend to_worker_4) {
	int command = TERMINATE;
	to_worker_1 <: command;
	to_worker_2 <: command;
	to_worker_3 <: command;
	to_worker_4 <: command;
	c_out <: (uchar)command;
	to_visualiser <: -1; // Send -1 as it expects integer that at some point may equal TERMINATE
						 // however it never expects a negative number so we use this to signal terminate
	int c = TERMINATE;
	to_button_listener <: c;
}

void print_grid(chanend c_out, chanend to_button_listener, chanend to_worker_1, chanend to_worker_2, chanend to_worker_3, chanend to_worker_4) {
	// Export game
	uchar command = (uchar)RETURN_DATA;
	to_worker_1 <: command;
	to_worker_2 <: command;
	to_worker_3 <: command;
	to_worker_4 <: command;

	receiveAllData(c_out, to_worker_1, to_worker_2, to_worker_3, to_worker_4);
}

void harvest_results(chanend c_out, chanend to_button_listener, chanend to_visualiser, chanend to_worker_1, chanend to_worker_2, chanend to_worker_3, chanend to_worker_4) {
	unsigned int iteration_count = 0;
	int should_not_terminate = 1;

	while (should_not_terminate) {
		int isPaused = 0;

        uchar worker_1_lines[2][IMWD+2];
        uchar worker_2_lines[2][IMWD+2];
        uchar worker_3_lines[2][IMWD+2];
        uchar worker_4_lines[2][IMWD+2];

        int alive_cells_1;
        int alive_cells_2;
        int alive_cells_3;
        int alive_cells_4;

        int received_worker_1 = 0;
        int received_worker_2 = 0;
        int received_worker_3 = 0;
        int received_worker_4 = 0;

		int button;
		int command;

		while (received_worker_1 != 1 || received_worker_2 != 1 || received_worker_3 != 1 || received_worker_4 != 1) {
            select {
                case to_button_listener :> button:

                	if (button == BUTTON_B) {
                 		// Tell button listener to continue
                		to_button_listener <: CONTINUE;

                		int command_to_workers = 0;
                		isPaused = 1;
                		command_to_workers = PAUSE;
                        to_worker_1 <: command_to_workers;
                        to_worker_2 <: command_to_workers;
                        to_worker_3 <: command_to_workers;
                        to_worker_4 <: command_to_workers;

                		while (isPaused == 1) {
                			to_button_listener :> button;

                			if (button == BUTTON_B) {
                                to_button_listener <: CONTINUE;
                				isPaused = 0;
                				command_to_workers = UNPAUSE;
                                to_worker_1 <: command_to_workers;
                                to_worker_2 <: command_to_workers;
                                to_worker_3 <: command_to_workers;
                                to_worker_4 <: command_to_workers;
                			} else if (button == BUTTON_D) {
                				isPaused = 0;
                                should_not_terminate = 0;

                				terminate_all(c_out, to_button_listener, to_visualiser, to_worker_1, to_worker_2, to_worker_3, to_worker_4);

                                // We should terminate and so we're not waiting to receive from workers any longer
                                received_worker_1 = 1;
                                received_worker_2 = 1;
                                received_worker_3 = 1;
                                received_worker_4 = 1;
                			}
                		}

                	} else if (button == BUTTON_D) {
                        terminate_all(c_out, to_button_listener, to_visualiser, to_worker_1, to_worker_2, to_worker_3, to_worker_4);
                        should_not_terminate = 0;

                        // We should terminate and so we're not waiting to receive from workers any longer
                        received_worker_1 = 1;
                        received_worker_2 = 1;
                        received_worker_3 = 1;
                        received_worker_4 = 1;
                    } else if (button == NO_BUTTON) {
                            to_button_listener <: CONTINUE;
                    }
                    break;
                case to_worker_1 :> command:
                    // Store the overlapping lines we send
                    for (int i=0; i < IMWD+2; ++i) {
                        to_worker_1 :> worker_1_lines[0][i];
                        to_worker_1 :> worker_1_lines[1][i];
                    }

                	received_worker_1 = 1;
                    // Get alive cells count from worker after recieving lines
                    to_worker_1 :> alive_cells_1;

                    break;
                case to_worker_2 :> command:

                    for (int i=0; i < IMWD+2; ++i) {
                        to_worker_2 :> worker_2_lines[0][i];
                        to_worker_2 :> worker_2_lines[1][i];
                    }

                	received_worker_2 = 1;
                    to_worker_2 :> alive_cells_2;
                    break;
                case to_worker_3 :> command:
                    for (int i=0; i < IMWD+2; ++i) {
                        to_worker_3 :> worker_3_lines[0][i];
                        to_worker_3 :> worker_3_lines[1][i];
                    }

                	received_worker_3 = 1;
                    to_worker_3 :> alive_cells_3;
                    break;
                case to_worker_4 :> command:
                    for (int i=0; i < IMWD+2; ++i) {
                        to_worker_4 :> worker_4_lines[0][i];
                        to_worker_4 :> worker_4_lines[1][i];
                    }

                	received_worker_4 = 1;
                    to_worker_4 :> alive_cells_4;
                break;
            }
		}

		if (should_not_terminate == 1) {
            // Send visualiser alive cells after each iteration
            to_visualiser <: (alive_cells_1 + alive_cells_2 + alive_cells_3 + alive_cells_4);

            // Start sending the lines back out to workers
            //
            for (int i = 0; i < IMWD + 2; ++i) {
                // Worker 1's top line is all blanks so he can just
                // replace with blanks again
                uchar val = 0;
                to_worker_1 <: val;
                to_worker_1 <: worker_2_lines[0][i];
            }

            for (int i = 0; i < IMWD + 2; ++i) {
                to_worker_2 <: worker_1_lines[1][i];
                to_worker_2 <: worker_3_lines[0][i];
            }

            for (int i = 0; i < IMWD + 2; ++i) {
                to_worker_3 <: worker_2_lines[1][i];
                to_worker_3 <: worker_4_lines[0][i];
            }

            for (int i = 0; i < IMWD + 2; ++i) {
                uchar val = 0;
                to_worker_4 <: worker_3_lines[1][i];
                // Bottom row for 4 is blank as before so set those
                to_worker_4 <: val;

            }

            ++iteration_count;
		}
    }
}

void receiveAllData(chanend c_out, chanend worker_1, chanend worker_2, chanend worker_3, chanend worker_4) {
	for (int row=0; row < 4; ++row) {
		for (int column=0; column < IMWD; ++column) {
            uchar val;
            worker_1 :> val;
            c_out <: val;
		}
	}
	for (int row=0; row < 4; ++row) {
		for (int column=0; column < IMWD; ++column) {
            uchar val;
            worker_2 :> val;
            c_out <: val;
		}
	}

	for (int row=0; row < 4; ++row) {
		for (int column=0; column < IMWD; ++column) {
            uchar val;
            worker_3 :> val;
            c_out <: val;
		}
	}
	for (int row=0; row < 4; ++row) {
		for (int column=0; column < IMWD; ++column) {
            uchar val;
            worker_4 :> val;
            c_out <: val;
		}
	}
}
