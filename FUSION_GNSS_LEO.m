%%
clear
clc

%%
%首先读取SP3文件
%以GL SP3文件为基础
fid1=fopen('GLwhu23022.sp3','r');
fid2=fopen('sp3_2024051','r');

fid3=fopen('GL2whu23022.sp3','w');

%写头文件
while ~feof(fid1)
    buff=fgetl(fid1);
    if strcmp(buff(1:5),'*  20')
        break;
    end
    %卫星数与prn号需要添加
    %后续自己贴上去叭

    %头文件完全复制低轨SP3文件
    fprintf(fid3,'%s \n',buff);
end

%读低轨文件主体 %添加后续低轨卫星
%读取低轨轨道钟差文件，并在过程中对GNSS高轨进行时间匹配
%时间对的上以后，将GNSS高轨卫星钟差全部用CLK的钟差替换，注意单位换算
%低轨卫星的则照常写
clkflag=0;

%记录匹配时间
year=0;mon=0;day=0;
hour=0;min=0;sec=0;
matchflag=0;

while ~feof(fid1)

    if strcmp(buff(1:5),'*  20')
        %首先匹配时间,找到高轨卫星钟差的文件体
        if clkflag==0
        while ~feof(fid2)
            buff2=fgetl(fid2);
            if strcmp(buff2(1:5),'*  20')
                clkflag=1;

                year=buff2(4:7);mon=buff2(9:10);
                day=buff2(12:13);hour=buff2(15:16);
                min=buff2(18:19);sec=buff2(21:29);
                break;
            end
        end
        end

        %然后把L 卫星前5分钟数据抄写，直到与clk文件匹配

        if clkflag==1
        if strcmp(buff(4:7),buff2(4:7))&&strcmp(buff(9:10),buff2(9:10))...
                &&strcmp(buff(12:13),buff2(12:13))&&strcmp(buff(15:16),buff2(15:16))...
                &&strcmp(buff(18:19),buff2(18:19))&&strcmp(buff(21:29),buff2(21:29))
            matchflag=1;
            fprintf(fid3,'%s \n',buff);
        end
        end

        %在L和G 时间完全匹配以后，以L为基准，将G的鼠标读写位置往下移动

    end 

    %
    if matchflag==0
        %复写刚刚读取低轨文件的时间
        fprintf(fid3,'%s \n',buff);
        buff=fgetl(fid1);
    end

    %如果时间匹配上了,开始改写lSP3 高轨卫星的钟差
    if matchflag==1
        %copy GL SP3
        n=1;
        for i=1:513
            buff=fgetl(fid1);
            if strcmp(buff(1:2),'P3')&&~(strcmp(buff(2:4),'300'))
                CLK_L3(n,1)=str2double(buff(48:60));
                n=n+1;
            end
            fprintf(fid3,'%s \n',buff);
        end

        n=1;
        %copy 92 leo sat
        while ~feof(fid2)
            buff2=fgetl(fid2);
            if strcmp(buff2(1:5),'*  20')
                buff=fgetl(fid1);
                break;
            end
            if strcmp(buff2(1:2),'P6')&&~(strcmp(buff2(2:4),'600'))
                lprn=buff2(1:4);
                
                s=strsplit(buff2,' ');

                pos(1)=str2double(cell2mat(s(1,2)));
                pos(2)=str2double(cell2mat(s(1,3)));
                pos(3)=str2double(cell2mat(s(1,4)));

                fprintf(fid3,'%4s %13.6f %13.6f %13.6f %13.6f \n',...
                    lprn,pos(1),pos(2),pos(3),CLK_L3(n));
                n=n+1;
            end
        end

        
    end
end



fclose(fid1);
fclose(fid2);
fclose(fid3);
