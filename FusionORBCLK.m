%%
clear
clc

%%
%首先读取SP3文件
%以LEO SP3文件为基础
fid1=fopen('whu22924.sp3','r');
fid2=fopen('WUM0MGXFIN_20233480000_01D_30S_CLK.CLK','r');

fid3=fopen('GLwhu22924.sp3','w');

%写头文件
while ~feof(fid1)
    buff=fgetl(fid1);
    if strcmp(buff(1:5),'*  20')
        break;
    end

    %头文件完全复制低轨SP3文件
    fprintf(fid3,'%s \n',buff);
end

%读低轨文件主体 %改写文件钟差
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
            if strcmp(buff2(1:3),'AS ')
                clkflag=1;

                year=buff2(9:12);mon=buff2(14:15);
                day=buff2(17:18);hour=buff2(20:21);
                min=buff2(23:24);sec=buff2(26:34);
                break;
            end
        end
        end

        %然后把L 卫星前5分钟数据抄写，直到与clk文件匹配

        if clkflag==1
        if strcmp(buff(4:7),buff2(9:12))&&strcmp(buff(9:10),buff2(14:15))...
                &&strcmp(buff(12:13),buff2(17:18))&&strcmp(buff(15:16),buff2(20:21))...
                &&strcmp(buff(18:19),buff2(23:24))&&strcmp(buff(21:29),buff2(26:34))
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
        
        buff=fgetl(fid1);

        if strcmp(buff(1:5),'*  20')
            fprintf(fid3,'%s \n',buff);
            continue;
        end

        if strcmp(buff(1:2),'P2')||strcmp(buff(1:2),'P3')||strcmp(buff(1:2),'P4')...
                ||strcmp(buff(1:2),'P5')||strcmp(buff(1:2),'P6')
            fprintf(fid3,'%s \n',buff);
        else
            lprn=buff(1:4);
            s=strsplit(buff,' ');

            pos(1)=str2double(cell2mat(s(1,2)));
            pos(2)=str2double(cell2mat(s(1,3)));
            pos(3)=str2double(cell2mat(s(1,4)));

            aclkflag=0;
            while aclkflag==0
                %取GNSS高轨钟差
                
                if strcmp(buff2(4:6),lprn(2:4))
                    Gclk=str2double(buff2(41:59))*10E5;
                    aclkflag=1;
                else
                    buff2=fgetl(fid2);
                end
            end

            fprintf(fid3,'%4s %13.6f %13.6f %13.6f %13.6f \n',...
                lprn,pos(1),pos(2),pos(3),Gclk);

        end

        
        
    end
end



fclose(fid1);
fclose(fid1);
fclose(fid2);
