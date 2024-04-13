/*
MIT License

Copyright (c) 2014-2023 Universidade da Coruña

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include "papi.h"

#define MAX_EVENTS 32

int main (int argc, char **argv) {
    int retval,cid,rapl_cid=-1,numcmp;
    int i,code,enum_retval,seconds_interval,microseconds_interval,max_time;
    int num_events = 0;
    int EventSet = PAPI_NULL;
    long long values[MAX_EVENTS];
    char fifo_dir[256], fifo_pipe[256+11];
    char event_name[BUFSIZ];
    PAPI_event_info_t evinfo;
    const PAPI_component_info_t *cmpinfo = NULL;
    long long start_time,before_time,after_time;
    double elapsed_time,total_time;
    char events[MAX_EVENTS][BUFSIZ];
    char units[MAX_EVENTS][BUFSIZ];
    FILE *fp;

    seconds_interval = 1;
    max_time = 0;
    strcpy(fifo_dir, "/tmp");
	printf("Obtained %i args\n", argc);
	if (argc > 1) {
		if (argc == 2) {
			sscanf(argv[1], "%s", fifo_dir);
		} else if (argc == 3) {
			sscanf(argv[1], "%s", fifo_dir);
			sscanf(argv[2], "%i", &seconds_interval);
		} else if (argc == 4) {
			sscanf(argv[1], "%s", fifo_dir);
			sscanf(argv[2], "%i", &seconds_interval);
			sscanf(argv[3], "%i", &max_time);
		} else {
			fprintf(stderr, "Usage: %s [FIFO_DIR INTERVAL_SECONDS MAX_TIME_SECONDS]\n", argv[0]);
			exit(-1);
		}
	}

	snprintf(fifo_pipe, sizeof(fifo_pipe), "%s/power_pipe", fifo_dir);
    microseconds_interval = seconds_interval * 1e6;

    printf("FIFO directory: %s\n", fifo_dir);
    printf("FIFO pipe: %s\n", fifo_pipe);
    printf("Interval: %i s (%i us)\n", seconds_interval, microseconds_interval);
    printf("Max time: %i s\n", max_time);

    /* PAPI Initialization */
    retval = PAPI_library_init( PAPI_VER_CURRENT );
    if ( retval != PAPI_VER_CURRENT ) {
		fprintf(stderr, "PAPI_library_init failed\n");
		exit(-1);
    }

    numcmp = PAPI_num_components();

    for (cid=0; cid<numcmp; cid++) {
		if ((cmpinfo = PAPI_get_component_info(cid)) == NULL) {
			fprintf(stderr,"PAPI_get_component_info failed\n");
			exit(1);
		}

		if (strstr(cmpinfo->name, "rapl")) {
			rapl_cid=cid;
			printf("Found RAPL component at cid %d\n", rapl_cid);

			if (cmpinfo->disabled) {
				fprintf(stderr, "RAPL component disabled: %s\n", cmpinfo->disabled_reason);
				exit(-1);
			}
			break;
		}
    }

    /* Component not found */
    if (cid == numcmp) {
		fprintf(stderr, "Error! No RAPL component found!\n");
		exit(1);
    }

    /* Find Events */
    code = PAPI_NATIVE_MASK;
    enum_retval = PAPI_enum_cmp_event(&code, PAPI_ENUM_FIRST, cid);

    while (enum_retval == PAPI_OK) {
	retval = PAPI_event_code_to_name(code, event_name);
	if (retval != PAPI_OK) {
		fprintf(stderr, "Error translating %#x\n", code);
		exit(-1);
	}

	printf("Found event: %s\n", event_name);

	if (strstr(event_name, "ENERGY") != NULL && strstr(event_name, "ENERGY_CNT") == NULL) {
		strncpy(events[num_events], event_name, BUFSIZ);

	 	/* Find additional event information: unit, data type */
	        retval = PAPI_get_event_info(code, &evinfo);
            	if (retval != PAPI_OK) {
                	fprintf(stderr, "Error getting event info for %#x\n", code);
	                exit(-1);
        	}

            	strncpy(units[num_events],evinfo.units,sizeof(units[0])-1);
            	/* buffer must be null terminated to safely use strstr operation on it below */
            	units[num_events][sizeof(units[0])-1] = '\0';

            	num_events++;

            	if (num_events == MAX_EVENTS) {
                	fprintf(stderr, "Too many events! %d\n", num_events);
	                exit(-1);
            	}
        }

	enum_retval = PAPI_enum_cmp_event(&code, PAPI_ENUM_EVENTS, cid);
    }

    if (num_events == 0) {
    	fprintf(stderr, "Error! No RAPL events found!\n");
	exit(-1);
    }

    /* Create EventSet */
    retval = PAPI_create_eventset(&EventSet);
    if (retval != PAPI_OK) {
	fprintf(stderr, "Error creating EventSet\n");
        exit(-1);
    }

    for (i=0; i<num_events; i++) {
	printf("Saved event: %s\n", events[i]);
	retval = PAPI_add_named_event(EventSet, events[i]);
	if (retval != PAPI_OK) {
		fprintf(stderr, "Error adding event %s\n", events[i]);
        	exit(-1);
	}
    }


    printf("Starting measuring loop...\n");
    fflush(stdout);
    fflush(stderr);

    double energy, power;
	double power_pkg0 = 0, power_pkg1 = 0;
    //double energy_pp0_pkg0 = 0, power_pp0_pkg0 = 0, energy_pp0_pkg1 = 0, power_pp0_pkg1 = 0;
    //double energy_pkg0 = 0, energy_pkg1 = 0;
    char column_joules[40], column_watts[40], measure_energy[40], measure_power[40];
    start_time=PAPI_get_real_nsec();
    after_time=start_time;

    /* Main loop */
    while (1) {
		/* Start counting */
		before_time=PAPI_get_real_nsec();
		retval = PAPI_start(EventSet);
		if (retval != PAPI_OK) {
			fprintf(stderr, "PAPI_start() failed\n");
			exit(-1);
		}

		usleep(microseconds_interval);

		/* Stop counting */
		after_time=PAPI_get_real_nsec();
		retval = PAPI_stop(EventSet, values);
		if (retval != PAPI_OK) {
			fprintf(stderr, "PAPI_stop() failed\n");
					exit(-1);
		}

		total_time=((double)(after_time-start_time))/1.0e9;
		elapsed_time=((double)(after_time-before_time))/1.0e9;

        /*energy_pkg0 = 0;
        energy_pkg1 = 0;
		energy_pp0_pkg0 = 0;
        energy_pp0_pkg1 = 0;*/

        for (i=0; i<num_events; i++) {
            /* Energy consumption is returned in nano-Joules (nJ) */

            energy = ((double)values[i] / 1.0e9);
            power = energy / elapsed_time;

            strcpy(column_joules, events[i]);
            strcat(column_joules, "(J)");
            strcpy(column_watts, events[i]);
            strcat(column_watts, "(W)");

            printf("events[%i]=%s, values[%i]=%lli\n", i, events[i], i, values[i]);
            
			if (energy == 0)
				continue;

			if (strstr(events[i], "DRAM_")) {
				strcpy(measure_energy, "ENERGY_DRAM");
				strcpy(measure_power, "POWER_DRAM");
			} else if (strstr(events[i], "PP0_")) {
				strcpy(measure_energy, "ENERGY_PP0");
				strcpy(measure_power, "POWER_PP0");
				/*if (strstr(events[i], "PACKAGE0")) {
					energy_pp0_pkg0 = energy;
					power_pp0_pkg0 = power;
				} else if (strstr(events[i], "PACKAGE1")) {
					energy_pp0_pkg1 = energy;
					power_pp0_pkg1 = power;
				}*/
			} else if (strstr(events[i], "PP1_")) {
				strcpy(measure_energy, "ENERGY_PP1");
				strcpy(measure_power, "POWER_PP1");
			} else if (strstr(events[i], "PSYS_")) {
				strcpy(measure_energy, "ENERGY_PSYS");
				strcpy(measure_power, "POWER_PSYS");
			} else if (strstr(events[i], "PACKAGE_")) {
				strcpy(measure_energy, "ENERGY_PACKAGE");
				strcpy(measure_power, "POWER_PACKAGE");
				if (strstr(events[i], "PACKAGE0")) {
					//energy_pkg0 = energy;
					power_pkg0 = power;
					printf("Energy pkg0 %.3f, Power pkg0 %.3f\n", energy, power);
				} else if (strstr(events[i], "PACKAGE1")) {
					//energy_pkg1 = energy;
					power_pkg1 = power;
					printf("Energy pkg1 %.3f, Power pkg1 %.3f\n", energy, power);
				}
			} else {
				fprintf(stderr, "Error! Unexpected event %s found!\n", events[i]);
			}
			//printf("Measure: %s Column: %s Value: %.3f\n", measure_energy, column_watts, power);
        }

		// Open pipe to send values to bash client
		fp = fopen(fifo_pipe, "w");
		if (fp == NULL) {
			fprintf(stderr, "Error opening pipe: %s\n", fifo_pipe);
			exit(-1);
		}

		// Write values for both CPUs
		fprintf(fp, "%.3f %.3f\n", power_pkg0, power_pkg1);
		
		/*int chars_written = fprintf(fp, "%.3f %.3f\n", power_pkg0, power_pkg1);
		if (chars_written < 0) {
			printf("Error writing to file %s\n", fifo_pipe);
		} else {
			printf("Successfully sent %d characters to the file %s.\n", chars_written, fifo_pipe);
		}*/

		// Close pipe to remove lock
		fclose(fp); 
	}

	/*if (energy_pp0_pkg0 != 0) {
		printf("energy_pkg0 %.3f, energy_pp0_pkg0 %.3f\n", energy_pkg0, energy_pp0_pkg0);
		printf("Measure: UNCORE_POWER_PACKAGE Column: UNCORE_POWER:PACKAGE0(W) Value: %s\n", measure_energy, column_watts, power_pkg0 - power_pp0_pkg0);
	}

	if (energy_pp0_pkg1 != 0) {
		printf("energy_pkg1 %.3f, energy_pp0_pkg1 %.3f\n", energy_pkg1, energy_pp0_pkg1);
		printf("Measure: UNCORE_POWER_PACKAGE Column: UNCORE_POWER:PACKAGE1(W) Value: %s\n", measure_energy, column_watts, power_pkg1 - power_pp0_pkg1);
	}

	if (max_time > 0 && total_time >= max_time)
		break;*/
	
	if (fp != NULL) {
		fclose(fp);
	}

    printf("Finished loop. Total running time: %.4f s\n", total_time);    
    exit(0);
}