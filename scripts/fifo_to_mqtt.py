#!/bin/python

import os
import argparse
import select
import sys
import signal
import paho.mqtt.client as mqtt

def signal_handler(signal, frame):
    global args
    global file
    file.close()
    os.remove(args.output_file)
    sys.exit(0)

par = argparse.ArgumentParser()
par.add_argument("--output-file", action="store", help="")
par.add_argument("--mqtt-url", action="store", default="127.0.0.1")
args = par.parse_args()

client = mqtt.Client()
client.connect(args.mqtt_url, 1883, 60)
client.loop_start()

signal.signal(signal.SIGINT, signal_handler)

try:
    os.remove(args.output_file)
except:
    pass

os.mkfifo(args.output_file)
file = open(args.output_file, "r")
try:
    while True:
        select.select([file], [], [file])
        data = file.read()
        if len(data) == 0:
            continue
        for l in data.split('\n'):
            l = l.strip().split("\t")
            if len(l) != 2:
                continue
            print(l)
            client.publish(l[0], l[1])
except Exception as ex:
    print(str(ex))
    signal_handler(None, None)

