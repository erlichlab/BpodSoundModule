# RaspberryPiAudioService main program
# Running on a RPi with high-performance sound card such as Pisound
# this program provide low-latency sound service to the bpod
# before starting the protocol, the MATLAB will sent the sound file to the pi using sync function
# then after starting the audio service, the pi will listening on the serial port,
# once it got serial input, it will send the audio output with short latency.
# By Jingjie Li in Erlich's Lab (jingjie.li@nyu.edu)

import time
import RPi.GPIO as GPIO
import zmq
import numpy as np
import threading
import RpiSoundPlay_FAST #Contain methods that can play sounds and listening on the serial ports
import RpiSoundPlay_FAST_Socket

class PiAudioServer(object):
    WAV_list = list()
    Volume_list = list()
    Loop_list = list()
    fs = 48000
    Name_list = list()
    latency = "high"
    SoundServ = None
    GPIO.setmode(GPIO.BCM)
    GPIO.setup(17,GPIO.OUT)
    GPIO.output(17, False)

    def __init__(self,port=3335): #initilize the connection
        self.context = zmq.Context()
        self.socket = self.context.socket(zmq.REP)
        self.socket.bind("tcp://*:%s" % port)

    def StateCheck(self):
        # core function, recieve string command from matlab, to entering different sub-state
        # such as sync, modify, set delay, start audio output, close audio, and clear data
        str = self.socket.recv_string()
        isConn = (str=="READY?")
        isSync = (str=="SYNC?")
        isSyncDone = (str=="SYNCDONE")
        isMod = (str=="MODIFY")
        isLat = (str=="SETLATENCY")
        RunningService = (str=="RUN")
        RunningviaSocket = (str=="RUNSCK")
        STOPSerial = (str=="STOPSER")
        isClearAll = (str=="CLEARALL")
        if isConn:
            self.initConn()
            print("connect succ")
        elif isSync:
            print("prepar to recieve data")
            GPIO.output(17, True)#turn the amplifier's 12v power on
            self.SyncPrep()
            self.Sync()
        elif isSyncDone:
            self.isSyncComp()
            print("sync complete")
        elif isMod:
            self.Modify()
        elif isLat:
            self.SetLatency()
        elif RunningService:
            print("Start the RPI audio service")
            self.StartAudioServ()
        elif RunningviaSocket:
            self.StartSocketAudio()
        elif STOPSerial:
            self.StopSerial()
        elif isClearAll:
            GPIO.output(17, False)
            self.clearAll(True)
        else:
            pass

    def initConn(self):
        self.socket.send(b"OK")

    def SyncPrep(self):
        self.socket.send(b"SYNCPREP")

    def Modify(self):
        # modify the local audio list
        self.socket.send(b"MPREPARED")
        data = self.socket.recv_json()
        cmd = data["cmd"]
        name = data["name"]
        if cmd == "UPDATE": # update audio data/volume/loop info
            param = data["param"]
            val = data["val"]
            idx = self.Name_list.index(name)
            if param == "wav":
                wavdata = np.ascontiguousarray(np.array(val).T,dtype=np.float32)
                self.WAV_list[idx] = wavdata
            elif param == "volume":
                self.Volume_list[idx] = val
            elif param == "loop":
                self.Loop_list[idx] = val
            self.socket.send(b"UPDATED")
            print("we have updated %s" %name)
        elif cmd == "ADD": # add more audio data
            wav = data["wav"]
            vol = data["vol"]
            loop = data["loop"]
            self.Name_list.append(name)
            wavdata = np.ascontiguousarray(np.array(wav).T,dtype=np.float32)
            self.WAV_list.append(wavdata)
            self.Volume_list.append(vol)
            self.Loop_list.append(loop)
            self.socket.send(b"ADDED")
            print("we have added %s" %name)
        elif cmd == "DEL": # detele a audio data
            idx = self.Name_list.index(name)
            del self.Name_list[idx]
            del self.WAV_list[idx]
            del self.Loop_list[idx]
            del self.Volume_list[idx]
            self.socket.send(b"DELETED")
            print("we have deleted %s" %name)
        else:
            pass

    def SetLatency(self):
        self.socket.send(b"LATPREPARED")
        self.latency = self.socket.recv_string()
        self.socket.send(b"LATSET")

    def Sync(self):
        # using this to sync sounds library with the MATLAB
        self.clearAll() #Firstly clear the data
        self.fs = self.socket.recv_json()
        self.socket.send(b"FSGOT")
        #print(self.fs)
        #print(type(self.fs))
        while True:
            data = self.socket.recv_json()
            if isinstance(data,int):
                self.socket.send(b"DATAGOT")
                break
            else:
                wavdata = np.ascontiguousarray(np.array(data['wave']).T,dtype=np.float32)
                voldata = data['vol']
                loopdata = data['loop']
                name = data['name']
                print("%s data recieved" % name)
                self.WAV_list.append(wavdata)
                self.Loop_list.append(loopdata)
                self.Volume_list.append(voldata)
                self.Name_list.append(name)
                self.socket.send(b"NEXT")


    def SyncOld(self):
        # may not so useful
        #first recieving sampling rate(FS)
        self.fs = self.socket.recv_json()
        self.socket.send(b"FSGOT")
        print(self.fs)
        print(type(self.fs))
        ## recieving data loop
        while True:
            data = self.socket.recv_json()
            if isinstance(data,int):
                #data recv end
                self.socket.send(b"DATAGOT")
                break
            else:
                #convert and add data to the list
                data = np.ascontiguousarray(np.array(data).T,dtype=np.float32)
                self.WAV_list.append(data)
                self.socket.send(b"NEXT")
        ## recieving volume loop
        while True:
            data = self.socket.recv_json()
            if isinstance(data,int) and data==-1:
                #volume recv end
                self.socket.send(b"VOLGOT")
                break
            else:
                #convert and add volume to the list
                self.Volume_list.append(data)
                self.socket.send(b"NEXT")
        ## recieving "LOOP" loop
        while True:
            data = self.socket.recv_json()
            if isinstance(data,int) and data==-1:
                #loop info recv end
                self.socket.send(b"LOOPGOT")
                break
            else:
                #convert and add loop info to the list
                self.Loop_list.append(data)
                self.socket.send(b"NEXT")

    def isSyncComp(self):
        self.socket.send(b"DONE")

    def StartAudioServ(self):
        # another core methods, this will start the serial listening, then it can play sounds
        if self.latency == "low":#sum(self.Loop_list) == 0:
            # when someone set low latency, it will call this simpler function, but people cannot loop the sound or stop the sound
            sndserv = RpiSoundPlay_FAST.SoundServiceSimple(self.WAV_list,self.Volume_list,self.fs)
            sndserv.serialstart()
            snd_stop_event = threading.Event()
            sndser=threading.Thread(target=sndserv.StartSnd,args=(snd_stop_event,),name='soundservice')
            sndser.start()
        else:
            #otherwise, the latency will be slightly high(7ms), but people can maniplate the sound to loop, and to stop
            sndserv = RpiSoundPlay_FAST.SoundServiceComp(self.WAV_list,self.Volume_list,self.Loop_list,self.fs)
            sndserv.serialstart()
            snd_stop_event = threading.Event()
            sndserv.StartSnd(snd_stop_event)
            #sndser=threading.Thread(target=sndserv.StartSnd,args=(snd_stop_event,),name='soundservice')
            #sndser.start()
        self.socket.send(b"STARTED")
        str = self.socket.recv_string()
        if str=='STOP':
            snd_stop_event.set()
            time.sleep(1) # Waiting for the serial to be closed
            sndserv.KillSoundPlay()
            self.socket.send(b"STOPPED")
        else:
            snd_stop_event.set()
            sndserv.KillSoundPlay()
            self.socket.send(b"ERROR")
        self.SoundServ = sndserv;

    def StartSocketAudio(self):
        if self.latency == "low":
            sndserv = RpiSoundPlay_FAST_Socket.SoundServiceSimple(self.WAV_list,self.Volume_list,self.socket,self.fs)
        else:
            sndserv = RpiSoundPlay_FAST_Socket.SoundServiceComp(self.WAV_list,self.Volume_list,self.Loop_list,self.socket,self.fs)
        self.socket.send(b"STARTED")
        sndserv.StartSnd()
        self.socket.send(b"STOPPED")
        sndserv.KillSoundPlay()

    def StopSerial(self):
        self.SoundServ.KillSerConn()
        self.socket.send(b"SERIALSTOPPED")

    def clearAll(self, send=False):
        # clear all sound in the library
        print("we are going to clear all sounds")
        if send:
            self.socket.send(b"CLEAR")
        self.Name_list = list()
        self.WAV_list = list()
        self.Volume_list = list()
        self.Loop_list = list()
        self.fs = 48000

    def close(self):
        # close the conntction, only when we close the program
        self.socket.close


ctx = PiAudioServer(port=3335)

def main():
    while True:
        ctx.StateCheck()

if __name__=='__main__':
    try:
        main()
    except KeyboardInterrupt:
        print("Now we close the audio")
        GPIO.cleanup()
        ctx.close()
