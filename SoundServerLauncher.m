function [ obj ] = SoundServerLauncher( )
%SoundServerLauncher Function
%   Launch the sound service based on bpod system setting
%   If using Rpi in bpod settings, it will call PiSoundServer to generate
%   sound object
%   If using Psychsound, it will use PsychSoundServer() instead
%
%   Usage:
%   obj.Sounds = SoundServerLauncher( )
%   By Jingjie Li (jingjie.li@nyu.edu)
global BpodSystem

if strcmp(BpodSystem.PluginObjects.SoundServer,'Rpi')
    obj = PiSoundServer();
else
    obj = PsychSoundServer();
end

end

