classdef PsychSoundServer < SoundServ
    %UNTITLED2 Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        
    end
    
    methods
        function obj = PsychSoundServer(obj)
            PsychToolboxSoundServer('init_ifnot');
        end
        
        function isSuss = sync(obj)
            for i=1:obj.num_sounds
                PsychToolboxSoundServer('load',obj.SoundStruct.(obj.sound_list{i}).soundid+1,obj.SoundStruct.(obj.sound_list{i}).wave,'volume',...
                    obj.SoundStruct.(obj.sound_list{i}).vol,'balance',obj.SoundStruct.(obj.sound_list{i}).bal,'loop',obj.SoundStruct.(obj.sound_list{i}).loop,...
                    'repetitions',obj.SoundStruct.(obj.sound_list{i}).rep);
                % psych sound id start at 1
            end
            isSuss = 1;
        end
        function setSF(obj, val)
            obj.SF = val;
            PsychToolboxSoundServer('setSF',obj.SF);
            PsychToolboxSoundServer('init');
        end
        
        function id = GetSoundid(obj,soundname,playORstop)
            if nargin <3
                playORstop = 'play';
            end
            is = isfield(obj.SoundStruct,soundname);
            if is
                id = obj.SoundStruct.(soundname).soundid+1;
            else
                id  = nan;
            end
        end
        
        function [id,isSuss] = AddSound(obj, name,wav, varargin)
        % add sound in the sound list and in the pi
        % [id,isSuss] = AddSound(obj, name,wav, varargin)
        % param_name can be wave,loop or vol
        % call it only when synced
            isSuss=0;
            [loop, varargin] = utils.inputordefault('loop',0,varargin);
            [vol, varargin] = utils.inputordefault('volume',0.5,varargin);
            [rep, varargin] = utils.inputordefault('repeation',1,varargin);
            [bal, varargin] = utils.inputordefault('balance',0,varargin);
            if size(wav,1)==1
                wav = [wav;wav];
            end
            obj.num_sounds=obj.num_sounds+1;
            obj.SoundStruct.(name).soundid = obj.num_sounds-1;
            obj.SoundStruct.(name).name = name;
            obj.SoundStruct.(name).wave = wav;
            obj.SoundStruct.(name).loop = loop;
            obj.SoundStruct.(name).vol = vol;
            obj.SoundStruct.(name).rep = rep;
            obj.SoundStruct.(name).bal = bal;
            obj.sound_list{1,obj.num_sounds} = name;
            id = obj.num_sounds;
            PsychToolboxSoundServer('load',obj.SoundStruct.(obj.sound_list{id}).soundid+1, obj.SoundStruct.(obj.sound_list{id}).wave,'volume',...
                    obj.SoundStruct.(obj.sound_list{id}).vol,'balance',obj.SoundStruct.(obj.sound_list{id}).bal,'loop',obj.SoundStruct.(obj.sound_list{id}).loop,...
                    'repetitions',obj.SoundStruct.(obj.sound_list{id}).rep);
            isSuss=1;
        end
        
        function isSuss = setParameter(obj, sndid, param_name, param_value, isSync)
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
            T = struct();
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
            elseif strcmp(param_name,'wav')
                T.param = 'wav';
                T.val = param_value;
            else
                T.param = param_name;
                T.val = param_value;
            end
            PsychToolboxSoundServer('set',id, T.param,T.val);
        end
        function play(obj,soundid)
            PsychToolboxSoundServer('play',soundid);
        end
        
        function play_cell = PlaySound(obj,soundname,playORstop)
            if nargin <3
                playORstop = 'stop';
            end
            if strcmp(playORstop,'stop')
                snd_trigger = 'StopSound';
            else
                snd_trigger = 'PlaySound';
            end
            play_cell={snd_trigger,obj.GetSoundid(soundname,playORstop)};
        end
        
        function stop(obj,soundid)
            PsychToolboxSoundServer('stop',soundid);
        end
        
        function delete(obj,soundid)
            PsychToolboxSoundServer('delete',soundid);
        end
    end
    
    methods (Static = true)
        function stopAll()
            PsychToolboxSoundServer('stopall');
        end
    end
    
end

