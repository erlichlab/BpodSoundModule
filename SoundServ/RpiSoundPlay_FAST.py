# RaspberryPiAudioService main program
# Running on a RPi with high-performance sound card such as Pisound
# this program provide low-latency sound service to the bpod
# before starting the protocol, the MATLAB will sent the sound file to the pi using sync function
# then after starting the audio service, the pi will listening on the serial port,
# once it got serial input, it will send the audio output with short latency.
# By Jingjie Li in Erlich's Lab (jingjie.li@nyu.edu)

import serial
import time
import sys
import os
import sounddevice as sd
import numpy as np
import threading


class SoundServiceSimple(object):
    List_Sound_Num = list()
    num_files = 0
    ser = None
    Stim = None

    def __init__(self,List_Sound,volumelist,fs=48000):
        sd.default.samplerate=fs
        sd.default.device=2
        sd.default.latency=['low','low']
        self.num_files = len(List_Sound)
        self.List_Sound_Num = list()
        i=0
        for list_item in List_Sound:
            self.List_Sound_Num.append(list_item*volumelist[i])
            i+=1
        self.Stim = sd.OutputStream(dtype='float32')
        self.Stim.start()

    def serialstart(self):
        self.ser=serial.Serial("/dev/serial0", baudrate=115200, timeout=1.0)

    def StartSnd(self,event):
        while event.isSet()==0:
            rcv = self.ser.read(1)
            if rcv!= []:
                rcv = bytes.decode(rcv,'iso-8859-1')
                if len(rcv) > 0:
                    rcv = ord(rcv)
                    if 0 < rcv and rcv < self.num_files:
                        self.Stim.write(self.List_Sound_Num[rcv])
                        print("we got :",rcv," From Serial 1 Port")

    def KillSoundPlay(self):
        print("STOP Serial Listening")
        self.Stim.stop()
        self.Stim.close()

    def KillSerConn(self):
        if self.ser!=None:
            print("Now we close the serial port")
            self.ser.close()

class _CallbackContext(object):
    data = None
    output_channels = None
    output_dtype = None
    output_mapping = None
    play_num= None
    isPlay = None

    def __init__(self,loop,num_files):
        self.loop = loop
        self.blocksize = np.zeros(num_files,dtype = 'int32')
        self.frame = np.zeros(num_files,dtype = 'int32')
        self.frames=np.zeros(num_files,dtype = 'int32')

    def callback_enter(self, status, data):
        for i in self.play_num:
            self.blocksize[i] = min(self.frames[i] - self.frame[i], len(data))

    def write_outdata(self, outdata):
        # 'float64' data is cast to 'float32' here:
        global isPlay
        isPlay_out = isPlay#0.5*(isPlay+1)
        outdata *= 0
        for i in self.play_num:
            outdata[:self.blocksize[i], [0,1]]=outdata[:self.blocksize[i] \
                , [0,1]]+isPlay_out[i]*self.data[i][self.frame[i]:self.frame[i] + self.blocksize[i]]
            if self.loop[i] and self.blocksize[i] < len(outdata):
                self.frame[i] = 0
                outdata[self.blocksize[i]:]=outdata[self.blocksize[i]:] + \
                    isPlay_out[i]*self.data[i][self.frame[i]:self.frame[i] + \
                    len(outdata)-self.blocksize[i]]
                self.blocksize[i] = len(outdata)-self.blocksize[i]
            elif self.loop[i]==False and self.blocksize[i] < len(outdata):
                self.frame[i] = 0
                isPlay[i] = 0
                isPlay_out[i] = 0


        self.frame = isPlay_out * self.frame
        self.blocksize = isPlay_out * self.blocksize + (1-isPlay_out) * len(outdata)

    def callback_exit(self):
        if not self.blocksize[1]:
            print(self.frame)
            print(self.frames)
            print(self.blocksize)
            print(self.loop)
            raise CallbackAbort
        self.frame = self.blocksize + self.frame#increasing frame

def callback(outdata,frames,time,status):
    global isPlay,cb
    cb.play_num = np.where(isPlay==1)[0].tolist()
    cb.callback_enter(status, outdata)
    cb.write_outdata(outdata)
    cb.callback_exit()

class SoundServiceComp(object):
    List_Sound_Num = list()
    num_files = 0
    ser = None
    Stim = None
    def __init__(self,List_Sound,volumelist,Loop,fs=48000):
        sd.default.samplerate=fs
        sd.default.device=2
        sd.default.latency=['low','low']
        self.num_files = len(List_Sound)
        global isPlay,cb
        isPlay = np.zeros(self.num_files,dtype = 'int32')
        i=0
        self.List_Sound_Num = list()
        for list_item in List_Sound:
            self.List_Sound_Num.append(list_item*volumelist[i]) #set the volume
            i+=1
        # init callback class
        cb=_CallbackContext(loop=Loop,num_files=len(List_Sound))
        for i in range(self.num_files):
            cb.frames[i],_ = self.List_Sound_Num[i].shape
        cb.num_files = self.num_files
        cb.data=self.List_Sound_Num

    def serialstart(self):
        self.ser=serial.Serial("/dev/serial0", baudrate=115200, timeout=1.0)

    def SerialDect(self,event):
        global isPlay
        while event.isSet()==0:
            rcv = self.ser.read(1)
            if rcv!= []: #Not Recieving Anything
                rcv = bytes.decode(rcv,'iso-8859-1')
                if len(rcv) > 0:
                    rcv = ord(rcv)
                    if rcv == 255:
                        isPlay = 0*isPlay #give 255 to stop all
                    elif rcv > 0:
                        isPlay[rcv%128]=(rcv>=128)
                    print("we got :",rcv," From Serial 1 Port")
                else:
                    pass
        print("STOP Serial Listening")

    def StartSnd(self,serial_event):
        # open audio thread
        self.sd1 = sd.OutputStream(dtype='float32',callback=callback,blocksize=256)
        self.sd1.start()
        # open serial thread
        self.tser=threading.Thread(target=self.SerialDect,args=(serial_event,),name='serialdetect')
        self.tser.start()

    def KillSoundPlay(self):
        self.sd1.stop()
        self.sd1.close()

    def KillSerConn(self):
        if self.ser!=None:
            print("Now we close the serial port")
            self.ser.close()
