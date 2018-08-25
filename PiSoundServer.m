classdef PiSoundServer < SoundServ
    
    properties
        pi_ipaddress
        socket
        PiSounds = cell(1,3); 
    end
  
    
    properties (Access = protected)
        running_status = 0;
        to_delete = [];
        wav_changed = [];
        params_changed = [];
        connected = 0;
        server = 'localhost';
        port = 3335;
    end
    
    methods
        function obj = PiSoundServer(varargin)
            
            addJeroMQToPath();
            if nargin == 0
                %obj.server = db.getPiIP(){1};
                obj.server = utils.ini2struct('~/.dbconf').sound.ip;
                obj.port = utils.ini2struct('~/.dbconf').sound.port;
                if obj.server == 0
                    obj.server = 'localhost';
                end
                
            else
                [obj.port, varargin] = utils.inputordefault('port',obj.port,varargin);
                [obj.server, varargin] = utils.inputordefault('server',obj.server,varargin);

                %if ~isempty(varargin)
                    %fprintf(2,'Do not know what to do with %s',varargin{1:2:end})
                %end
            end
            
            reconnect(obj)
            
            load(obj, 'EmptySound' ,zeros(1,1000))
            
            global BpodSystem
            BpodSystem.PluginObjects.SoundServer = 'Rpi';
        end

        function obj = reconnect(obj)
            if ~isempty(obj.socket) 
                obj.socket.close();
            end

            import org.zeromq.ZMQ;
            context = ZMQ.context(1);
            obj.socket = context.socket(ZMQ.REQ);
            obj.socket.setReceiveTimeOut(5000) % 5 seconds
            obj.socket.connect(sprintf('tcp://%s:%d',obj.server,obj.port));
            fprintf('connected\n')
            pause(0.5)
            obj.socket.send('READY?');
            if ~obj.waitForOK(5)  % wait up to 5 seconds for ok.
                fprintf('Did not get OK. Now what?\n')
            end
                
        end
            
        function isSuss = setLatency(obj,delay)
            % use this function to set sound latency
            % If you want to get a super low latency (about-1.3ms). you can set
            % isSuss = obj.setLatency('low')
            % BUT under this condition, you CANNOT loop your sounds, you CANNOT
            % stop your sounds, it will only play once after each trigger
            % If you want to loop your sounds and to control its' stop, you
            % MUST set isSuss = obj.setLatency('high') (or you don't need to set, default is high)
            % the delay will be about 8ms
            isSuss = 0;
            if strcmp(delay,'low') || strcmp(delay,'high')
                obj.socket.send('SETLATENCY');
                obj.latency = delay;
                OK = waitForSTR(obj, 'str','LATPREPARED');
                if OK
                    obj.socket.send(delay);
                    OK = waitForSTR(obj, 'str','LATSET');
                    if OK
                        isSuss = 1;
                    end
                end
            else
                fprintf(2,'you must input high or low\n')
            end
        end
        
        function id = load(obj, name ,wav, varargin)
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
            %obj.PiSounds{obj.num_sounds,1} = obj.num_sounds;
            %obj.PiSounds{obj.num_sounds,2} = name;  
            %obj.PiSounds{obj.num_sounds,3} = wav;
            id = obj.num_sounds;
            obj.synced = 0;
        end
        
        function [id,isSuss] = AddSound(obj, name,wav, varargin)
        % add sound in the sound list and in the pi
        % [id,isSuss] = AddSound(obj, name,wav, varargin)
        % param_name can be wave,loop or vol
        % call it only when synced
           if obj.synced && ~obj.running_status
               [loop, varargin] = utils.inputordefault('loop',0,varargin);
               [vol, varargin] = utils.inputordefault('volume',0.5,varargin);
               [rep, varargin] = utils.inputordefault('repeation',1,varargin);
               [bal, varargin] = utils.inputordefault('balance',0,varargin);
               if size(wav,1)==1
                   wav = [wav;wav];
               end
               obj.num_sounds = obj.num_sounds + 1;
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
               balvec = repmat([0.5+0.5*bal;0.5-0.5*bal],1,size(wav,2));
               % then, get sync
               obj.socket.send('MODIFY');
               OK = waitForSTR(obj, 'str','MPREPARED');
               if OK
                    T = struct();
                    T.cmd = 'ADD';
                    T.name = name;
                    T.wav = repmat(wav.*balvec,1,rep);
                    T.loop = loop;
                    T.vol = vol;
                    obj.socket.send(jsonencode(T));
                    OK = waitForSTR(obj, 'str','ADDED');
                    if OK
                        isSuss = 1;
                        obj.synced = 1;
                    end
                end
           else
               fprintf(2, 'use obj.load(...) to add sound locally before sync\n')
               fprintf(2, 'or may be you are try to add something when running, stop the audio service first!\n')
               isSuss = 0;
               id = nan;
           end
        end
        
        function isSuss = sync(obj)
            
            soundnames = fieldnames(obj.SoundStruct);
            obj.socket.send('SYNC?');
            OK = waitForSTR(obj, 'str','SYNCPREP');
            isSuss = 0;
            if OK
                obj.socket.send(jsonencode(obj.SF));
                OK = waitForSTR(obj, 'str','FSGOT');
                if OK
                    for i=1:obj.num_sounds
                        strtemp = obj.SoundStruct.(soundnames{i});
                        % converte the wave vector using LR balance
                        balvec = repmat([0.5+0.5*strtemp.bal;0.5-0.5*strtemp.bal],1,size(strtemp.wave,2));
                        strtemp.wave = repmat(strtemp.wave.*balvec,1,strtemp.rep);
                        obj.socket.send(jsonencode(strtemp));
                        OK = waitForSTR(obj, 'str','NEXT');
                        if ~OK
                            isSuss = 0;
                            return
                        end
                    end
                    obj.socket.send(jsonencode(-1));
                    OK = waitForSTR(obj, 'str','DATAGOT');
                    if OK
                        obj.socket.send('SYNCDONE');
                        waitForSTR(obj, 'str','DONE');
                        isSuss = 1;
                        obj.synced = 1;
                    end
                end
            end
        end
        
        function id = GetSoundid(obj,soundname,playORstop)
            if nargin <1
                playORstop = 'stop';
            end
            if isfield(obj.SoundStruct,soundname)
                if strcmp(playORstop,'play') && strcmp(obj.latency,'high')
                    id = obj.SoundStruct.(soundname).soundid + 128;
                else
                    id = obj.SoundStruct.(soundname).soundid;
                end
            else
                id  = nan;
            end
        end
        
        function OK = waitForOK(obj, varargin)

            if nargin>1
                orig = obj.socket.getReceiveTimeOut();
                obj.socket.setReceiveTimeOut(1000*varargin{1});
            end
            msg = char(obj.socket.recvStr());
            if ~strcmp(msg,'OK') 
                OK = 0;
            else
                OK = 1;
            end
            if nargin>1
                obj.socket.setReceiveTimeOut(orig);
            end
        end
        
        function OK = waitForSTR(obj, varargin)
            [str, varargin] = utils.inputordefault('str','OK',varargin);
            [timeout, varargin] = utils.inputordefault('timeout',5,varargin);
            %if nargin>1
                %orig = obj.socket.getReceiveTimeOut();
            obj.socket.setReceiveTimeOut(1000*timeout);
            %end
            msg = char(obj.socket.recvStr());
            if ~strcmp(msg,str) 
                OK = 0;
            else
                OK = 1;
            end
            %if nargin>1
                %obj.socket.setReceiveTimeOut(orig);
            %end
        end
        
        function SF = getSF(obj,val)
            SF = val;
            obj.SF = val;
        end

        %function set.SF(obj, val)
        %end
        function OK = startServ(obj)
            if obj.synced
                obj.socket.send('RUN');
                OK = waitForSTR(obj, 'str','STARTED');
                obj.running_status = 1;
            else
                fprintf(2,'Do not run the audio service before sync')
                OK = 0;
            end
            % Send command to PiSound to play sound
        end
        
        function OK = closeServ(obj)
            obj.socket.send('STOP');
            OK = waitForSTR(obj, 'str','STOPPED');
            obj.running_status = 0;
        end
        
        function OK = startServSocket(obj)
            obj.socket.send('RUNSCK');
            OK = waitForSTR(obj, 'str','STARTED');
        end
        
        function OK = closeServSocket(obj)
            obj.socket.send(jsonencode('STOP'));
            OK = waitForSTR(obj, 'str','STOPPED');
        end
        
        function OK = play(obj, sndid)
            if ~isnumeric(sndid)
                id = find(strcmp(sndid, obj.sound_list));
                id = id-1;
            else
                id  = sndid;
            end
            
            % Send command to PiSound to play sound
            obj.socket.send(jsonencode(id));
            OK = waitForSTR(obj, 'str','PLAYED');
        end
        
        function OK = stop(obj, sndid)
            if ~isnumeric(sndid)
                id = find(strcmp(sndid, obj.sound_list));
                id = id-1;
            else
                id  = sndid;
            end
            OK = 0;
            if strcmp(obj.latency,'high')
                id  = id + 128;
                obj.socket.send(jsonencode(id));
                OK = waitForSTR(obj, 'str','PLAYED');
            end
            
            % Send command to PiSound to play sound
            
            
            % Send command to PiSound to stop sound
        end
        
        function isSuss = delete(obj, sndid, isSync)
            if nargin < 3
                isSync = 1;
            end
            isSuss = 0;
            if ~isnumeric(sndid)
                id = find(strcmp(sndid, obj.sound_list));
            else
                id = sndid;
            end
            rmname = obj.sound_list{id};
            % delete the sound in the sound struct
            obj.SoundStruct = rmfield(obj.SoundStruct,rmname);
            obj.sound_list(id) = [];
            for i=id:obj.num_sounds-1
                obj.SoundStruct.(obj.sound_list{i}).soundid = obj.SoundStruct.(obj.sound_list{i}).soundid - 1;
            end
            obj.num_sounds = obj.num_sounds-1;
            % Mark sound as deleted sound in the pi if Sync required
            if isSync && obj.synced
                obj.synced = 0;
                obj.socket.send('MODIFY');
                OK = waitForSTR(obj, 'str','MPREPARED');
                if OK
                    T = struct();
                    T.cmd = 'DEL';
                    T.name = rmname;
                    obj.socket.send(jsonencode(T));
                    OK = waitForSTR(obj, 'str','DELETED');
                    if OK
                        isSuss = 1;
                        obj.synced = 1;
                    end
                end
            elseif isSync && ~obj.synced
                fprintf(2,'You must sync the data first ! However this sound has been removed from the local table\n')
                obj.synced = 0;
                isSuss = 1;
            else
                obj.synced = 0;
                isSuss = 1;
            end
            
        end
        
        function isSuss = setParameter(obj, sndid, param_name, param_value, isSync)
        % change parameter in the sound list 
        % isSuss = setParameter(obj, sndid, param_name, param_value, isSync)
        % param_name can be wav,loop or volume
            if nargin < 5
                isSync = 1;
            end
            isSuss = 0;
            if ~isnumeric(sndid)
                id = find(strcmp(sndid, obj.sound_list));
            else
                id = sndid;
            end
            chgname = obj.sound_list{id};
            % modify local list
            obj.SoundStruct.(chgname).(param_name) = param_value;
            % sync modify
            if isSync && obj.synced
                obj.synced = 0;
                obj.socket.send('MODIFY');
                OK = waitForSTR(obj, 'str','MPREPARED');
                if OK
                    T = struct();
                    T.cmd = 'UPDATE';
                    T.name = chgname;
                    if ~strcmp(param_name,'rep') && ~strcmp(param_name,'bal')
                        T.param = param_name;
                        T.val = param_value;
                    elseif strcmp(param_name,'rep')
                        T.param = 'wav';
                        T.val = repmat(obj.SoundStruct.(chgname).wave,1,param_value);
                    elseif strcmp(param_name,'bal')
                        T.param = 'wav';
                        balvec = repmat([0.5+0.5*param_value;0.5-0.5*...
                            param_value],1,size(obj.SoundStruct.(chgname).wave,2));
                        T.val = obj.SoundStruct.(chgname).wave .* balvec;
                    end
                    obj.socket.send(jsonencode(T));
                    OK = waitForSTR(obj, 'str','UPDATED');
                    if OK
                        isSuss = 1;
                        obj.synced = 1;
                    end
                end
            elseif isSync && ~obj.synced
                fprintf(2,'You must sync the data first ! However this sound has been modified from the local table\n')
                obj.synced = 0;
                isSuss = 1;
            else
                obj.synced = 0;
                isSuss = 1;
            end
        end
        
        function deleteall(obj)
            obj.socket.send('CLEARALL');
            OK = waitForSTR(obj, 'str','CLEAR');
            obj.PiSounds = cell(1,3); 
            obj.SoundStruct =  struct();
            obj.SF = 48000;
            obj.num_sounds = 0;
            obj.synced = 0;
        end
        
        function closeConn(obj)
            obj.socket.send('STOPSER')
            waitForSTR(obj, 'str','SERIALSTOPPED');
            obj.socket.close();
        end
        function stopall(obj)
        end
        
        
        
        function sound_names = list(obj)
            sound_names = obj.sound_list;
        end
        
        
        
        
    end
end

function addJeroMQToPath()
jcp = javaclasspath('-all');

jarfile = 'jeromq.jar';

if isempty(cell2mat(regexp(jcp,jarfile)))
    % Mysql is not on the path
    this_file = mfilename('fullpath');
    [this_path] = fileparts(this_file);
    javaaddpath(fullfile(this_path,'..','..','Modules', jarfile));
end

end