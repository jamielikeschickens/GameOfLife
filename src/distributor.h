/*
 * distributor.h
 *
 *  Created on: Nov 19, 2014
 *      Author: jamie
 */

#ifndef DISTRIBUTOR_H_
#define DISTRIBUTOR_H_

#define RETURN_DATA 10
#define CONTINUE 20
#define PAUSE 30
#define TERMINATE 5 // Must be higher than 112 for LED visualiser not to terminate
#define FINISH_PROCESSING 50


void distributor(chanend c_in,  chanend c_out, chanend to_visualiser, streaming chanend to_worker_1, streaming chanend to_worker_2, streaming chanend to_worker_3, streaming chanend to_worker_4, chanend to_button_listener);


#endif /* DISTRIBUTOR_H_ */
