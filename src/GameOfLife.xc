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

char infname[] = "/Users/jamie/Code/xc/GameOfLife/src/test.pgm"; //put your input image path here, absolute path
char outfname[] = "/Users/jamie/Code/xc/GameOfLife/src/testout.pgm"; //put your output image path here, absolute path


// Best to only display one at a time otherwise they will get mixed up in printing
#define SHOW_DATA_IN 1
#define SHOW_DATA_OUT 1

typedef struct {
	int is_alive;
	uchar neighbours[8]; // Neighbours around the cell. Starts top left 0, by row.
} Cell;

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
		for (int x = 0; x < IMWD; x++) {
			c_out <: line[x];
#if SHOW_DATA_IN
			printf("-%4.1d ", line[x]); //uncomment to show image values
#endif
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

        // Button debouncing
        if (prevButton == NO_BUTTON) {
            to_distributor <: r; // send button pattern to userAnt

            // Check for termination command from distributor
            int terminate_command;
            to_distributor :> terminate_command;

             if (terminate_command == TERMINATE) {
                should_not_terminate = 0;
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
	int num;
	int should_not_terminate = 1;

	while (should_not_terminate) {
        from_distributor :> num;

        if (num == -1) {
        	// If we recieve -1 shut down LEDs and visualiser
        	should_not_terminate = 0;

        	int command = TERMINATE;
        	toQuadrant0 <: command;
        	toQuadrant1 <: command;
        	toQuadrant2 <: command;
        	toQuadrant3 <: command;

        } else {
            // LED bits = 0b01110000
            // Bits of int are opposite way for LED so swap them around then shfit to correct position
            // Probably a much more efficient way to do this

            // 0b0000 0111
            int old = num;

            // Clear bit
            num = (old & ~0x4);
            // Copy bit
            num = (num | ((old & 0x1) << 2));

            num = (num & ~0x1);
            num = (num | ((old & 0x4) >> 2));
            toQuadrant3 <: (num << 4);

            // 0b0011 1000
            num = (old & ~0x20);
            num = (num | ((old & 0x8) << 2));

            num = (num & ~0x8);
            num = (num | ((old & 0x20) >> 2));
            toQuadrant2 <: (num << 1);


            // 0b1 1100 0000
            num = (old & ~0x100);
            num = (num | ((old & 0x40) << 2));

            num = (num & ~0x40);
            num = (num | ((old & 0x100) >> 2));
            toQuadrant1 <: (num >> 2);

            // 0b1110 0000 0000
            num = (old & ~0x800);
            num = (num | ((old & 0x200) << 2));

            num = (num & ~0x200);
            num = (num | ((old & 0x800) >> 2));

            toQuadrant0 <: (num >> 5);
        }
	}
	printf("Visualiser terminate\n");
}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Start your implementation by changing this function to farm out parts of the image...
//
/////////////////////////////////////////////////////////////////////////////////////////

void applyRules(Cell *cell) {
    int aliveCellsCount = 0;
    for (int i = 0; i<8; ++i) {
        if (cell->neighbours[i] == 255) {
            aliveCellsCount++;
        }
    }

    /*any live cell with fewer than two live neighbours dies
     *any live cell with two or three live neighbours is unaffected
     *any live cell with more than three live neighbours dies
    **/
    if (cell->is_alive == 255) {
        if (aliveCellsCount < 2 || aliveCellsCount > 3) {
            cell->is_alive = 0;
        }
    }
    /*any dead cell
     *with exactly three live neighbours becomes alive
    **/
    else {
        if (aliveCellsCount == 3) {
            cell->is_alive = 255;
        }
    }
}

void worker(chanend to_distributor) {
    uchar grid[6][IMWD+2]; // Grid of 6x18 for buffer each side
    int should_not_terminate = 1;

    for (int row = 0; row < 6; ++row) {
		for (int column = 0; column < IMWD + 2; ++column) {
			uchar val;
			to_distributor :> val;
			grid[row][column] = val;
		}
	}

	while (should_not_terminate) {

		uchar command;
		to_distributor :> command;

		if (command == RETURN_DATA) {
			for (int row = 1; row < 5; ++row) {
				for (int column = 1; column < IMWD+1; ++column) {
					to_distributor <: grid[row][column];
				}
			}
		} else if (command == TERMINATE) {
			should_not_terminate = 0;
		} else {

			Cell cellGrid[4][IMWD];
			for (int row = 1; row < 5; ++row) {
				for (int column = 1; column < IMWD + 1; ++column) {
					Cell *cell = &(cellGrid[row - 1][column - 1]); //we use [row-1][column-1] to get to (0,0) to find the neighbours of the pixel at (1,1)
					cell->is_alive = grid[row][column];
					cell->neighbours[0] = grid[row + 1][column - 1];
					cell->neighbours[1] = grid[row + 1][column];
					cell->neighbours[2] = grid[row + 1][column + 1];
					cell->neighbours[3] = grid[row][column - 1];
					cell->neighbours[4] = grid[row][column + 1];
					cell->neighbours[5] = grid[row - 1][column - 1];
					cell->neighbours[6] = grid[row - 1][column];
					cell->neighbours[7] = grid[row - 1][column + 1];

					applyRules(cell);

				}
			}

			int alive_counter = 0;

			for (int row=1; row < 5; ++row) {
				for (int column=1; column < IMWD+1; ++column) {
					// Take cell value and put back into grid
					grid[row][column] = cellGrid[row-1][column-1].is_alive;

					// Keep running count of alive cells encountered
					if (cellGrid[row-1][column-1].is_alive == 255) {
						++alive_counter;
					}
				}
			}

			// Send top and bottom lines back to distributor so
			// they can be harvested
			for (int i = 0; i < IMWD + 2; ++i) {
				to_distributor <: grid[1][i];
				to_distributor <: grid[4][i];
			}

			to_distributor <: alive_counter;

			// Get our overlapping lines from the distributor
			for (int i = 0; i < IMWD + 2; ++i) {
				uchar val;
				to_distributor :> val;
				grid[0][i] = val;
				to_distributor :> val;
				grid[5][i] = val;
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

	int count = 0;
	for (int y = 0; y < IMHT; y++) {
		for (int x = 0; x < IMWD; x++) {
			uchar command;
			c_in :> command;
			if (command == TERMINATE) {
				// Terminate by returning from the function
				return;
			} else {
				line[x] = command;
			}
#if SHOW_DATA_OUT
			printf("-%4.1d ", line[x]); //uncomment to show image values
#endif
			++count;
		}
#if SHOW_DATA_OUT
		printf("\n");
#endif
		_writeoutline( line, IMWD );
	}
	_closeoutpgm();
	printf( "DataOutStream:Done...\n" );
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
	    on stdcore[2]: distributor(c_inIO, c_outIO, to_visualiser, worker_1, worker_2, worker_3, worker_4, to_distributor);
	    on stdcore[0]: worker(worker_1);
	    on stdcore[1]: worker(worker_2);
	    on stdcore[2]: worker(worker_3);
	    on stdcore[3]: worker(worker_4);
	    on stdcore[1]: DataOutStream( outfname, c_outIO );

	    on stdcore[0]: visualiser(to_visualiser, quadrant0, quadrant1, quadrant2, quadrant3);
	    on stdcore[0]: showLED(cled0,quadrant0);
	    on stdcore[1]: showLED(cled1,quadrant1);
	    on stdcore[2]: showLED(cled2,quadrant2);
	    on stdcore[3]: showLED(cled3,quadrant3);
	}
	return 0;
}
