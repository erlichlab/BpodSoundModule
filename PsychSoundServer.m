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
        
        function id = GetSoundid(soundname,playORstop)
            if nargin <1
                playORstop = 'play';
            end
            is = isfield(obj.SoundStruct,soundname);
            if is
                id = obj.SoundStruct.(soundname).soundid;
            else
                id  = nan;
            end
        end
        
        function play(obj,soundid)
            PsychToolboxSoundServer('play',soundid+1);
        end
        
        function stop(obj,soundid)
            PsychToolboxSoundServer('stop',soundid+1);
        end
        
        function delete(obj,soundid)
            PsychToolboxSoundServer('delete',soundid+1);
        end
    end
    
    methods (Static = true)
        function stopAll()
            PsychToolboxSoundServer('stopall');
        end
    end
    
end

