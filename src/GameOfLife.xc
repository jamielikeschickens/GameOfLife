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


// Best to only display one at a time otherwise they will get mixed up in printing
#define SHOW_DATA_IN 0
#define SHOW_DATA_OUT 0

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

/////////////////////////////////////////////////////////////////////////////////////////
//
// Start your implementation by changing this function to farm out parts of the image...
//
/////////////////////////////////////////////////////////////////////////////////////////

void worker(chanend to_distributor) {
	uchar grid[6][IMWD+2]; // Grid of 6x18 for buffer each side

	for (int row=0; row < 6; ++row) {
		for (int column=0; column < IMWD+2; ++column) {
			uchar val;
            to_distributor :> val;
			grid[row][column] = val;
		}
	}


	for (int row=1; row <= 4; ++row) {
		for (int column=1; column <= IMWD; ++column) {
			uchar val;
			val = grid[row][column];
			to_distributor <: val;
		}
	}



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
			c_in :> line[x];
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
int main() {
	char infname[] = "/Users/jamie/Code/xc/GameOfLife/src/test.pgm"; //put your input image path here, absolute path
	char outfname[] = "/Users/jamie/Code/xc/GameOfLife/src/testout.pgm"; //put your output image path here, absolute path
	chan c_inIO, c_outIO; //extend your channel definitions here

	chan worker_1, worker_2, worker_3, worker_4;

	par //extend/change thxs par statement
	{
		DataInStream(infname, c_inIO);
		distributor(c_inIO, c_outIO, worker_1, worker_2, worker_3, worker_4);
		worker(worker_1);
		worker(worker_2);
		worker(worker_3);
		worker(worker_4);
		DataOutStream( outfname, c_outIO );
	}
	printf("Main:Done...\n");
	return 0;
}
