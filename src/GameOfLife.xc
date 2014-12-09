/*
 * GameOfLxfe.xc
 *
 *  Created on: 7 Nov 2014
 *      Author: fc13269
 */

/////////////////////////////////////////////////////////////////////////////////////////
//
// COMS20001 - Assxgnment 2
//
/////////////////////////////////////////////////////////////////////////////////////////


#include <platform.h>
#include <stdio.h>
#include <stdint.h>
#include "common.h"
#include "pgmIO.h"
#include "distributor.h"

in port  buttons = PORT_BUTTON;
out port cled0 = PORT_CLOCKLED_0;
out port cled1 = PORT_CLOCKLED_1;
out port cled2 = PORT_CLOCKLED_2;
out port cled3 = PORT_CLOCKLED_3;
out port cledG = PORT_CLOCKLED_SELG;
out port cledR = PORT_CLOCKLED_SELR;

char infname[] = "/Users/jamie/Code/xc/GameOfLife/src/test16.pgm"; //put your input image path here, absolute path
char outfname[] = "/Users/jamie/Code/xc/GameOfLife/src/testout16.pgm"; //put your output image path here, absolute path

// Best to only display one at a time otherwise they will get mixed up in printing
#define SHOW_DATA_IN 0
#define SHOW_DATA_OUT 1

/////////////////////////////////////////////////////////////////////////////////////////
//
// Read xmage from pgm file with path and name infname[] to channel c_out
//
/////////////////////////////////////////////////////////////////////////////////////////
void DataInStream(char infname[], chanend c_out) {
	int res;
	uchar line[IMWD];
	printf("DataInStream:Start...\n");
	res = _openinpgm(infname, IMWD, IMHT);
	if (res) {
		printf("DataInStream:Error openening %s\n.", infname);
		return;
	}
	for (int y = 0; y < IMHT; y++) {
		_readinline(line, IMWD);
		uint8_t group_byte = 0;
		// Packs 8 bytes from data in into 8 bit integer from line and sends to distributor
		for (int x = 0; x < IMWD; x+=8) {
			for (int i=0; i < 8; ++i) {
#if SHOW_DATA_IN
                	printf("-%4.1d ", line[x+i]); //uncomment to show image values
#endif

                if (line[x + i] == 255) {


                    group_byte = group_byte | (1 << (7-i));

                }
			}
			c_out <: group_byte;
			group_byte = 0; // Clear the group byte for next 8 bits read
		}
#if SHOW_DATA_IN
		printf("\n"); //uncomment to show image values
#endif
	}
	_closeinpgm();
	printf("DataInStream:Done...\n");
	return;
}

void buttonListener(in port b, chanend to_distributor) {
    int r;
    int prevButton = 15;
    int should_not_terminate = 1;

    while (should_not_terminate) {
        b :> r; // check if some buttons are pressed
        //printf("Got some buttons\n");
        // Button debouncing
        if (prevButton == NO_BUTTON) {
        	if (r != NO_BUTTON) {
        		to_distributor <: r; // send button pattern to userAnt

        		// Check for termination command from distributor
        		int terminate_command;
        		to_distributor :> terminate_command;
        		//printf("We get our continue command\n");

        		if (terminate_command == TERMINATE) {
        			should_not_terminate = 0;
        		}
        	}
        }
        prevButton = r;
    }
    printf("Button listener terminate\n");
}

//DISPLAYS an LED pattern in one quadrant of the clock LEDs
int showLED(out port p, chanend fromVisualiser) {
	unsigned int lightUpPattern;
	int should_not_terminate = 1;

	while (should_not_terminate) {
        fromVisualiser :> lightUpPattern; //read LED pattern from visualiser process
        if (lightUpPattern == TERMINATE) {
        	should_not_terminate = 0;
        } else {
            p <: lightUpPattern; //send pattern to LEDs
        }
	}
	printf("Show led terminate\n");
    return 0;
}

void visualiser(chanend from_distributor, chanend toQuadrant0, chanend toQuadrant1, chanend toQuadrant2, chanend toQuadrant3) {
	cledG <: 1;
	unsigned int num;
	int should_not_terminate = 1;

	while (should_not_terminate) {
        from_distributor :> num;

        if (num == -1) {
        	printf("Enters visualiser shutdown\n");
        	// If we recieve -1 shut down LEDs and visualiser
        	should_not_terminate = 0;

        	unsigned int command = TERMINATE;
        	toQuadrant0 <: command;
        	toQuadrant1 <: command;
        	toQuadrant2 <: command;
        	toQuadrant3 <: command;

        } else {
            // LED bits = 0b01110000
            // Bits of int are opposite way for LED so swap them around then shfit to correct position
            // Probably a much more efficient way to do this

            // 0b0000 0111
            unsigned int old = num;

            // Clear bit
            num = (old & ~0x4);
            // Copy bit
            num = (num | ((old & 0x1) << 2));

            num = (num & ~0x1);
            num = (num | ((old & 0x4) >> 2));
            toQuadrant3 <: (num << 4) & 0x70;

            // 0b0011 1000
            num = (old & ~0x20);
            num = (num | ((old & 0x8) << 2));

            num = (num & ~0x8);
            num = (num | ((old & 0x20) >> 2));
            toQuadrant2 <: (num << 1) & 0x70;

            // 0b1 1100 0000
            num = (old & ~0x100);
            num = (num | ((old & 0x40) << 2));

            num = (num & ~0x40);
            num = (num | ((old & 0x100) >> 2));
            toQuadrant1 <: (num >> 2) & 0x70;

            // 0b1110 0000 0000
            num = (old & ~0x800);
            num = (num | ((old & 0x200) << 2));

            num = (num & ~0x200);
            num = (num | ((old & 0x800) >> 2));

            toQuadrant0 <: (num >> 5) & 0x70;
        }
	}
	printf("Visualiser terminate\n");
}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Start your implementation by changing this function to farm out parts of the image...
//
/////////////////////////////////////////////////////////////////////////////////////////

uint8_t applyRules(int row, int column, uchar grid[(IMHT/4)+2][IMWD/8]) {
	uint8_t group_byte = grid[row][column];
	uint8_t new_group_byte = 0;
	uint8_t alive_neighbours = 0;
	uint8_t top_byte;
	uint8_t bottom_byte;

	if (row > 0) {
		top_byte = grid[row-1][column];
	}
	if (row < IMHT) {
		bottom_byte = grid[row+1][column];
	}

	// Start counting 0 - 8 bits numbered left to right
	for (int i=0; i < 8; ++i) {
		// Clear alive neighbours for each iteration
		alive_neighbours = 0;

		// Clear everything but bit we're looking at
		uint8_t b = group_byte & (1 << (7-i));
		uint8_t is_alive = b >> (7-i);

		// Find neighbours
		// Top left neighbour
		uint8_t tl_is_alive;
		// Furthest left group byte furthest left bit
		if (column == 0 && i == 0) {
			// Top left is padding so return 0
			tl_is_alive = 0;
		} else if (i == 0) {
			// Furthest left bit, need previous group byte (furthest right bit)
			uint8_t prev_top_byte = grid[row-1][column-1];
			tl_is_alive = prev_top_byte & 0x1;
		} else {
			uint8_t tl = top_byte & (1 << ((7-i)+1));
			tl_is_alive = tl >> ((7-i)+1);
		}

		if (tl_is_alive) {
			++alive_neighbours;
		}

		// Top centre neighbour
		uint8_t tc_is_alive;
		uint8_t tc = top_byte & (1 << (7-i));
		tc_is_alive = tc >> (7-i);
		if (tc_is_alive) {
			++alive_neighbours;
		}

		// Top right neighbour
		uint8_t tr_is_alive;
		// Furthest right group byte furthest right bit
		if (column == ((IMWD/8)-1) && i == 7) {
			// Right left is padding so return 0
			tr_is_alive = 0;
		} else if (i == 7) {
			// Furthest right bit, need next group byte (furthest left bit)
			uint8_t next_top_byte = grid[row-1][column+1];
			tr_is_alive = (next_top_byte & 0x80) >> 7;
		} else {
			uint8_t tr = top_byte & (1 << ((7-i)-1));
			tr_is_alive = tr >> ((7-i)-1);
		}
		if (tr_is_alive) {
			++alive_neighbours;
		}

		// Centre left neighbour
		uint8_t cl_is_alive;
		// Furthest left group byte furthest left bit
		if (column == 0 && i == 0) {
			cl_is_alive = 0;
		} else if (i == 0) {
			// Furthest left bit, need previous group byte (furthest right bit)
			uint8_t prev_centre_byte = grid[row][column - 1];
			cl_is_alive = prev_centre_byte & 0x1;
		} else {
			uint8_t cl = group_byte & (1 << ((7 - i) + 1));
			cl_is_alive = cl >> ((7 - i) + 1);
		}

		if (cl_is_alive) {
			++alive_neighbours;
		}

		// Centre right neighbour
		uint8_t cr_is_alive;
		// Furthest right group byte furthest right bit
		if (column == ((IMWD/8)-1) && i == 7) {
			cr_is_alive = 0;
		} else if (i == 7) {
			// Furthest right bit, need next group byte (furthest left bit)
			uint8_t next_centre_byte = grid[row][column + 1];
			cr_is_alive = (next_centre_byte & 0x80) >> 7;
		} else {
			uint8_t cr = group_byte & (1 << ((7 - i) - 1));
			cr_is_alive = cr >> ((7 - i) - 1);
		}

		if (cr_is_alive) {
			++alive_neighbours;
		}

		// Bottom left neighbour
		uint8_t bl_is_alive;
		// Furthest left group byte furthest left bit
		if (column == 0 && i == 0) {
			// Bottom left is padding so return 0
			bl_is_alive = 0;
		} else if (i == 0) {
			// Furthest left bit, need previous group byte (furthest right bit)
			uint8_t prev_bottom_byte = grid[row+1][column-1];
			bl_is_alive = prev_bottom_byte & 0x1;
		} else {
			uint8_t bl = bottom_byte & (1 << ((7-i)+1));
			bl_is_alive = bl >> ((7-i)+1);
		}

		if (bl_is_alive) {
			++alive_neighbours;
		}

		// Bottom centre neighbour
		uint8_t bc_is_alive;
		uint8_t bc = bottom_byte & (1 << (7-i));
		bc_is_alive = bc >> (7-i);
		if (bc_is_alive) {
			++alive_neighbours;
		}

		// Bottom right neighbour
		uint8_t br_is_alive;
		// Furthest right group byte furthest right bit
		if (column == ((IMWD/8)-1) && i == 7) {
			// Right left is padding so return 0
			br_is_alive = 0;
		} else if (i == 7) {
			// Furthest right bit, need next group byte (furthest left bit)
			uint8_t next_bottom_byte = grid[row+1][column+1];
			br_is_alive = (next_bottom_byte & 0x80) >> 7;
		} else {
			uint8_t br = bottom_byte & (1 << ((7-i)-1));
			br_is_alive = br >> ((7-i)-1);
		}
		if (br_is_alive) {
			++alive_neighbours;
		}

		/*any live cell with fewer than two live neighbours dies
		 *any live cell with two or three live neighbours is unaffected
		 *any live cell with more than three live neighbours dies
		 **/
		uint8_t current_bit = group_byte & (1 << (7-i));
		uint8_t current_cell_is_alive = current_bit >> (7-i);
		if (current_cell_is_alive) {
			if (alive_neighbours == 2 || alive_neighbours == 3) {
				new_group_byte = new_group_byte | current_bit;
			}
		} else {
			if (alive_neighbours == 3) {
				new_group_byte = new_group_byte | (1 << (7-i));
			}
		}
	}
	return new_group_byte;
}

// Hamming weight is amount of 1's in a binary number, faster ways to do this (lookup tables etc)
// but this will do for now
int hamming_weight(uint8_t num) {
	int count = 0;
	for (int i=0; i < 8; ++i) {
		int x = (num & (1 << (7-i))) >> (7-i);
		if (x == 1) {
			++count;
		}
	}
	return count;
}

void worker(chanend to_distributor) {
    uchar grid[(IMHT/4)+2][IMWD/8]; // Divide by 8 for group bytes of cells
    int should_not_terminate = 1;

    for (int row = 0; row < (IMHT/4)+2; ++row) {
		for (int column = 0; column < (IMWD/8); ++column) {
			uint8_t val;
			to_distributor :> val;
			grid[row][column] = val;
		}
	}


	while (should_not_terminate) {
		int is_paused = 0;
		int command;


        uchar new_grid[(IMHT/4)][IMWD/8];
		for (int row = 1; row <= (IMHT/4); ++row) {
			for (int column = 0; column < (IMWD/8); ++column) {
                new_grid[row-1][column] = applyRules(row, column, grid);

                if (should_not_terminate == 1) {
                	to_distributor <: PAUSE;
                	to_distributor :> command;
                }
                if (command == PAUSE) {
                	int p = 1;
                	while (p == 1) {
                		printf("Paused\n");
                        to_distributor <: PAUSE;
                        to_distributor :> command;
                        if (command == CONTINUE) {
                        	p = 0;
                        } else if (command == TERMINATE) {
                        	should_not_terminate = 0;
                        	p = 0;
                        } else if (command == RETURN_DATA) {
                        	for (int row=1; row < (IMHT/4)+1; ++row) {
                        		for (int column=0; column < (IMWD/8); ++column) {
                        			to_distributor <: grid[row][column];
                        		}
                        	}
                        }
                	}
                } else if (command == TERMINATE) {
                	should_not_terminate = 0;
                } else if (command == RETURN_DATA) {
                	for (int row=1; row < (IMHT/4)+1; ++row) {
                		for (int column=0; column < (IMWD/8); ++column) {
                			to_distributor <: grid[row][column];
                		}
                	}
                }
                //printf("no longer paused\n");
			}
		}

		if (should_not_terminate == 1) {

			to_distributor <: FINISH_PROCESSING;
			to_distributor :> command; // Block until told to continue

			int alive_counter = 0;

			for (int row = 1; row < (IMHT/4)+1; ++row) {
				for (int column = 0; column < (IMWD/8); ++column) {
					// Take cell value and put back into grid
					grid[row][column] = new_grid[row-1][column];

					// Keep running count of alive cells encountered
					int group_weight = hamming_weight(grid[row][column]);
					alive_counter += group_weight;
				}
			}
			//printf("worker alive cells: %d\n", alive_counter);

			// Send top and bottom lines back to distributor so
			// they can be harvested


			for (int i = 0; i < IMWD/8; ++i) {

				to_distributor <: grid[1][i];
				to_distributor <: grid[(IMHT/4)][i];
			}

			to_distributor <: alive_counter;

			// Get our overlapping lines from the distributor
			for (int i = 0; i < IMWD/8; ++i) {
				uint8_t val;
				to_distributor :> val;
				grid[0][i] = val;
				to_distributor :> val;
				grid[(IMHT/4)+1][i] = val;
			}
		}
	}
    printf("worker terminate\n");
}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Write pixel stream from channel c_in to pgm image file
// /////////////////////////////////////////////////////////////////////////////////////////
void DataOutStream(char outfname[], chanend c_in) {
	int res;
	uchar line[IMWD];
	printf("DataOutStream:Start...\n");
	res = _openoutpgm(outfname, IMWD, IMHT);
	if (res) {
		printf("DataOutStream:Error opening %s\n.", outfname);
		return;
	}
	while (1) {
		int count = 0;
		int command;
		c_in :> command;

		if (command == TERMINATE) {
			// Terminate by returning
			_closeoutpgm();
			return;
		} else {
			printf("yo start printing\n");
			for (int y = 0; y < IMHT; y++) {
				for (int x = 0; x < IMWD/8; x++) {
					uint8_t group_byte;
					c_in :> group_byte;

					// Unpacks 8 bytes from byte sent each bit is a byte
					for (int i=0; i < 8; ++i) {
						uint8_t current_bit = group_byte & (1 << (7-i));
						//printf("%d\n", group_byte);
						if ((current_bit >> (7-i)) == 1) {

							line[(x*8) + i] = 255;
						} else {
							line[(x*8) + i] = 0;
						}
#if SHOW_DATA_OUT
						printf("-%4.1d ", line[(x*8)+i]); //uncomment to show image values
#endif
					}
				}

#if SHOW_DATA_OUT
				printf("\n");
				_writeoutline( line, IMWD );
#endif
			}
			++count;
		}
		printf( "DataOutStream%d:Done...\n", count);
	}
	return;
}

//MAIN PROCESS defining channels, orchestrating and starting the threads
int main(void) {
	chan c_inIO, c_outIO; //extend your channel definitions here

	chan worker_1, worker_2, worker_3, worker_4, to_distributor, quadrant0, quadrant1, quadrant2, quadrant3, to_visualiser; //helper channels for LED visualisation


	par //extend/change this par statement
	{
	    on stdcore[0]: buttonListener(buttons, to_distributor);
	    on stdcore[1]: DataInStream(infname, c_inIO);
	    on stdcore[0]: distributor(c_inIO, c_outIO, to_visualiser, worker_1, worker_2, worker_3, worker_4, to_distributor);
	    on stdcore[0]: worker(worker_1);
	    on stdcore[1]: worker(worker_2);
	    on stdcore[2]: worker(worker_3);
	    on stdcore[3]: worker(worker_4);
	    on stdcore[3]: DataOutStream( outfname, c_outIO );

	    on stdcore[0]: visualiser(to_visualiser, quadrant0, quadrant1, quadrant2, quadrant3);
	    on stdcore[0]: showLED(cled0,quadrant0);
	    on stdcore[1]: showLED(cled1,quadrant1);
	    on stdcore[2]: showLED(cled2,quadrant2);
	    on stdcore[3]: showLED(cled3,quadrant3);
	}
	return 0;
}
