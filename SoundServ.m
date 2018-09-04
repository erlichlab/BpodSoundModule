classdef (Abstract) SoundServ < dynamicprops
    %UNTITLED Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        SoundStruct =  struct();
        SF = 48000
    end
    
    properties (Access = protected)
        latency = 'high';
        sound_list = {};
        num_sounds = 0;
        synced = 0;
    end
    
    methods
        function id = load(obj, name ,wav, varargin)
            % to load sounds
            obj.num_sounds = obj.num_sounds + 1;
            [loop, varargin] = utils.inputordefault('loop',0,varargin);
            [vol, varargin] = utils.inputordefault('volume',0.5,varargin);
            [rep, varargin] = utils.inputordefault('repeation',1,varargin);
            [bal, varargin] = utils.inputordefault('balance',0,varargin);
            %soundid, sound wave, loop in a struct named sound name
            %obj.SoundStruct = setfield(obj.SoundStruct,name,struct());
            if size(wav,1)==1
                wav = [wav;wav];
            end
            obj.SoundStruct.(name).soundid = obj.num_sounds-1;
            obj.SoundStruct.(name).name = name;
            obj.SoundStruct.(name).wave = wav;
            obj.SoundStruct.(name).loop = loop;
            obj.SoundStruct.(name).vol = vol;
            obj.SoundStruct.(name).rep = rep;
            obj.SoundStruct.(name).bal = bal;
            obj.sound_list{1,obj.num_sounds} = name;
            id = obj.num_sounds;
            obj.synced = 0;
        end
        
        function id = GetSoundid(soundname,playORstop)
            id = nan;
        end
        function ok = setLatency(obj,latency)
            ok = true;
        end
        
        function isSuss = sync(obj)
            % sync the sound between local and server
            isSuss = 1;
        end
        
        function OK = startServ(obj)
            % RPi start listening on the serial port
            % leave this empty
            OK = 1;
        end
        
        function OK = closeServ(obj)
            % RPi start listening on the serial port
            % leave this empty
            OK = 1;
        end
        
        function closeConn(obj)
            % close socket connection
            % leave this empty
        end
        function SF = getSF(obj,val)
            % set or get SF
            global BpodSystem
            if strcmp(BpodSystem.PluginObjects.SoundServerInfo,'PiSound')
                SF = val;
                obj.SF = val;
            else
                PsychToolboxSoundServer('init_ifnot');
                SF = PsychToolboxSoundServer('getSF');
            end
        end
    end
    
    methods (Static = true)
        function str = trigger()
            global BpodSystem
            if strcmp(BpodSystem.PluginObjects.SoundServerInfo,'Rpi')
                str = 'Serial1Code';
            else
                str = 'PlaySound';
            end
            
        end
    end
    
end

