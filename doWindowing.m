function [outputsig] = doWindowing(signal,SF)
%add a hanning window on the given signal 
%   sound signal can be either one channel or two channels
%   
duration = max(size(signal))/SF;
windowwidth=0.05;
if min(size(signal))<2
    if duration<windowwidth
        window = hanning(length(signal),'periodic')';
        outputsig = signal.*window;
    else
        window=0*signal+1;
        window_dump = hanning(SF*windowwidth,'periodic')';
        window(1:SF*windowwidth*0.5)=window_dump(1:SF*windowwidth*0.5);
        window(end-(SF*windowwidth*0.5+1):end)=window_dump(end-(SF*windowwidth*0.5+1):end);
        outputsig = signal.*window;
    end
elseif min(size(signal))==2
    ss = size(signal);
    if ss(1)==2
        outputsig=[doWindowing(signal(1,:),SF);doWindowing(signal(2,:),SF)];% call itself to compute each channel data
    else
        outputsig=[doWindowing(signal(:,1),SF),doWindowing(signal(:,2),SF)];   
    end
else
    outputsig=[];
    fprintf(2,'wrong input\n')
end
end

