/*
 * distributor.xc
 *
 *  Created on: Nov 19, 2014
 *      Author: jamie
 */

#include <platform.h>
#include <stdio.h>
#include <stdint.h>
#include <math.h>
#include "common.h"
#include "distributor.h"

timer t;
uint32_t start_time;
uint32_t end_time;

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
	t :> start_time;
    // Wait for workers to send back the overlapping lines so we can send them back out
    harvest_results(c_out, to_button_listener, to_visualiser, to_worker_1, to_worker_2, to_worker_3, to_worker_4);

    printf("Distributor temrinate\n");
}

void processImage(chanend c_out, chanend c_in, chanend to_worker_1, chanend to_worker_2, chanend to_worker_3, chanend to_worker_4) {
    printf("ProcessImage:Start, size = %dx%d\n", IMHT, IMWD);

    uint8_t val;
    for (int x = 0; x < IMWD; x+=8) {
        val = 0;
        to_worker_1 <: val;
    }

    // Send lines 1-5 to workers
    for (int y = 1; y <= (IMHT/4)+1; ++y) {
        for (int x = 0; x < IMWD; x+=8) {
            // Else send the actual data
            c_in :> val;
            to_worker_1 <: val;

            // If we're reading lines 4 or 5 we need to send them to worker 2 as well
            if (y == (IMHT/4) || y == (IMHT/4)+1) {
                to_worker_2 <: val;
            }
        }
    }

    for (int y = (IMHT/4)+2; y <= (IMHT/2)+1; ++y) {
        for (int x = 0; x < IMWD; x+=8) {
           // Else send the actual data
            c_in :> val;
            to_worker_2 <: val;

            // If we're reading lines 8 or 9 we need to send them to worker 3 as well
            if (y == (IMHT/2) || y == (IMHT/2)+1) {
                to_worker_3 <: val;
            }
        }
    }

    for (int y = (IMHT/2)+2; y <= (3*IMHT/4)+1; ++y) {
        for (int x = 0; x < IMWD; x+=8) {
           // Else send the actual data
            c_in :> val;
            to_worker_3 <: val;

            // If we're reading lines 12 or 13 we need to send them to worker 4 as well
            if (y == (3*IMHT/4) || y == (3*IMHT/4)+1) {
                to_worker_4 <: val;
            }
        }
    }

    for (int y = (3*IMHT/4)+2; y <= IMHT; ++y) {
        for (int x = 0; x < IMWD; x+=8) {
           // Else send the actual data
            c_in :> val;
            to_worker_4 <: val;
        }
    }

    // Send last buffer bytes
    for (int x = 0; x < IMWD; x+=8) {
        val = 0;
        to_worker_4 <: val;
    }

    printf( "ProcessImage:Done...\n" );

}

void terminate_all(chanend c_out, chanend to_button_listener, chanend to_visualiser, chanend worker_1, chanend worker_2, chanend worker_3, chanend worker_4) {
	// Wait for the next pause question then tell it to terminate
	int c;
	worker_1 :> c;
	worker_2 :> c;
	worker_3 :> c;
	worker_4 :> c;

	worker_1 <: TERMINATE;
	worker_2 <: TERMINATE;
	worker_3 <: TERMINATE;
	worker_4 <: TERMINATE;
	c_out <: TERMINATE;
	to_visualiser <: -1; // Send -1 as it expects integer that at some point may equal TERMINATE
						 // however it never expects a negative number so we use this to signal terminate
	to_button_listener <: TERMINATE;
}

void print_grid(chanend c_out, chanend to_button_listener, chanend worker_1, chanend worker_2, chanend worker_3, chanend worker_4) {
	// Wait for the next pause question then tell it to terminate
	int c;
	worker_1 :> c;
	worker_2 :> c;
	worker_3 :> c;
	worker_4 :> c;

	// Export game
	worker_1 <: RETURN_DATA;
	worker_2 <: RETURN_DATA;
	worker_3 <: RETURN_DATA;
	worker_4 <: RETURN_DATA;

	receiveAllData(c_out, worker_1, worker_2, worker_3, worker_4);
}

void harvest_results(chanend c_out, chanend to_button_listener, chanend to_visualiser, chanend to_worker_1, chanend to_worker_2, chanend to_worker_3, chanend to_worker_4) {
	unsigned int iteration_count = 0;
	int should_not_terminate = 1;

	while (should_not_terminate) {
        uint8_t worker_lines[8][IMWD/8];

        int alive_cells_1;
        int alive_cells_2;
        int alive_cells_3;
        int alive_cells_4;

        int workers_finished = 0;

		int cmd;
		int button;
		int is_paused = 0;

		while (workers_finished != 4) {
			// Give priority to button commands rather than recieving
			// data from workers
			[[ordered]]
			select {
				case to_button_listener :> button:
					if (button == BUTTON_B) {
						to_button_listener <: CONTINUE;
						printf("Button B pressed");
						if (is_paused == 0) {
							is_paused = 1;
							to_visualiser <: (int)floor(log(iteration_count)); // Display log of iteration count
						} else {
							is_paused = 0;
						}
					} else if (button == BUTTON_C) {
						printf("hello");
						to_button_listener <: CONTINUE;
						print_grid(c_out, to_button_listener, to_worker_1, to_worker_2, to_worker_3, to_worker_4);
					} else if (button == BUTTON_D) {
						terminate_all(c_out, to_button_listener, to_visualiser, to_worker_1, to_worker_2, to_worker_3, to_worker_4);
						workers_finished = 4;
						should_not_terminate = 0;
					}
                    break;
				case to_worker_1 :> cmd:
					if (cmd == PAUSE) {
						if (is_paused == 1) {
							to_worker_1 <: PAUSE;
						} else {
							to_worker_1 <: CONTINUE;
						}
						//printf("Still getting asked if we should pause\n");
					} else if (cmd == FINISH_PROCESSING) {
						++workers_finished;
					}
				break;
				case to_worker_2 :> cmd:
					if (cmd == PAUSE) {
						if (is_paused == 1) {
							to_worker_2 <: PAUSE;
						} else {
							to_worker_2 <: CONTINUE;
						}
					} else if (cmd == FINISH_PROCESSING) {
						++workers_finished;
					}
				break;
				case to_worker_3 :> cmd:
					if (cmd == PAUSE) {
						if (is_paused == 1) {
							to_worker_3 <: PAUSE;
						} else {
							to_worker_3 <: CONTINUE;
						}
					} else if (cmd == FINISH_PROCESSING) {
						++workers_finished;
					}
				break;
				case to_worker_4 :> cmd:
					if (cmd == PAUSE) {
						if (is_paused == 1) {
							to_worker_4 <: PAUSE;
						} else {
							to_worker_4 <: CONTINUE;
						}
					} else if (cmd == FINISH_PROCESSING) {
						++workers_finished;
					}
				break;
			}
		}

		if (should_not_terminate == 1) {
            workers_finished = 0;
            to_worker_1 <: CONTINUE;
            to_worker_2 <: CONTINUE;
            to_worker_3 <: CONTINUE;
            to_worker_4 <: CONTINUE;

            // Store the overlapping lines we send
            for (int i=0; i < IMWD/8; ++i) {
                to_worker_1 :> worker_lines[0][i];
                to_worker_1 :> worker_lines[1][i];
            }

            // Get alive cells count from worker after recieving lines
            to_worker_1 :> alive_cells_1;


            for (int i=0; i < IMWD/8; ++i) {
                to_worker_2 :> worker_lines[2][i];
                to_worker_2 :> worker_lines[3][i];
            }

            to_worker_2 :> alive_cells_2;

            for (int i=0; i < IMWD/8; ++i) {
                to_worker_3 :> worker_lines[4][i];
                to_worker_3 :> worker_lines[5][i];
            }

            to_worker_3 :> alive_cells_3;

            for (int i=0; i < IMWD/8; ++i) {
                to_worker_4 :> worker_lines[6][i];
                to_worker_4 :> worker_lines[7][i];
            }

            to_worker_4 :> alive_cells_4;

            // Send visualiser alive cells after each iteration
            to_visualiser <: (alive_cells_1 + alive_cells_2 + alive_cells_3 + alive_cells_4);

            // Start sending the lines back out to workers
            //
            for (int i=0; i < IMWD/8; ++i) {
                // Worker 1's top line is all blanks so he can just
                // replace with blanks again
                uchar val = 0;
                to_worker_1 <: val;
                to_worker_1 <: worker_lines[2][i];
            }

            for (int i=0; i < IMWD/8; ++i) {
                to_worker_2 <: worker_lines[1][i];
                to_worker_2 <: worker_lines[4][i];
            }

            for (int i=0; i < IMWD/8; ++i) {
                to_worker_3 <: worker_lines[3][i];
                to_worker_3 <: worker_lines[6][i];
            }

            for (int i=0; i < IMWD/8; ++i) {
                uint8_t val = 0;
                to_worker_4 <: worker_lines[5][i];
                // Bottom row for 4 is blank as before so set those
                to_worker_4 <: val;

            }
			++iteration_count;
			if (iteration_count == 100) {
				t :> end_time;
				float time_ms = (float)(end_time - start_time) / 100000.0;
				printf("100 iterations in %fms\n", time_ms);
			}
		}

    }
}

void receiveAllData(chanend c_out, chanend worker_1, chanend worker_2, chanend worker_3, chanend worker_4) {
	c_out <: RETURN_DATA;

	for (int row=0; row < (IMHT/4); ++row) {
		for (int column=0; column < IMWD/8; ++column) {
            uint8_t val;
            worker_1 :> val;
            c_out <: val;
		}
	}
	for (int row=0; row < (IMHT/4); ++row) {
		for (int column=0; column < IMWD/8; ++column) {
			uint8_t val;
            worker_2 :> val;
            c_out <: val;
		}
	}

	for (int row=0; row < (IMHT/4); ++row) {
		for (int column=0; column < IMWD/8; ++column) {
			uint8_t val;
            worker_3 :> val;
            c_out <: val;
		}
	}
	for (int row=0; row < (IMHT/4); ++row) {
		for (int column=0; column < IMWD/8; ++column) {
			uint8_t val;
            worker_4 :> val;
            c_out <: val;
		}
	}
}
