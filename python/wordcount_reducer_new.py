#!/usr/bin/env python
#s reducer code will input a line of text and
#    output <word, total-count>
# ---------------------------------------------------------------
import sys

last_key      = None              #initialize these variables
running_total = 0
channel = 'ABC'
channel_count = 0
abc_found = None
# -----------------------------------
# Loop thru file
#  --------------------------------
for input_line in sys.stdin:
    input_line = input_line.strip()


    this_key, value = input_line.split("\t", 1)  #the Hadoop default is tab separates key value

    if value == channel:
         abc_found = True
         #print str(abc_found) + " first"
         continue

    else:
        value = int(value)           #int() will convert a string to integer (this program does no error checking)


    if last_key == this_key:     #check if key has changed ('==' islogical equalilty check

        running_total += value   # add value to running total

    else:
        if last_key and abc_found:

          #  print "we are here"
            print( "{0}\t{1}".format(last_key, running_total) )


        #print str(abc_found) + " second"                        #PRINTS FALSE
        running_total = value    #reset values
        last_key = this_key
        #print this_key                                          #Prints the key
        abc_found = False

if last_key == this_key:
     print( "{0}\t{1}".format(last_key, running_total))

