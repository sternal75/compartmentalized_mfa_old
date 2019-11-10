function [parsed_update,annotedText] = writeCD(parsed,fname_out)
% Write the parsed CD model structure to a CD-compatible XML file.
%
% USAGE:
%
%    [parsed_update, annotedText] = writeCD(fname, parsed, fname_out)
%
% INPUTS:
%    fname:            The original XML file
%    parsed:           A parsed model structure generated by `parseCD` function.
%    fanme_out:        The name of the output XML file.
%
% OUTPUTS:
%    parsed_update:    An updated version of the parsed
%    annotedText:      A matlab variable storing the all the XML lines
%
% EXAMPLE:
%
%    aaa = writeXML('PD_140620_1.xml', parsePD,'text.html')
%
% .. Author: - Longfei Mao Oct/2014

if nargin<2 || isempty(fname_out)


    [fname_out, fpath]=uiputfile('*.xml','CellDesigner SBML Source File');
    if(fname_out==0)
        return;
    end
    f_out=fopen([fpath,fname_out],'w');
else
    f_out=fopen(fname_out,'w');
end

if isfield(parsed.r_info,'XMLtext');
    text=parsed.r_info.XMLtext;
else
    errordlg('The XMLtext doesn''t exit in the parsed model structure');
end


%%%%%%%%%%%%%%%%%%%%%%%%  modify

ref=readCD(parsed); %% read the the list of the reactions and associated information.
% ref=parsed.r_info;


r_c=size(ref.number)

%while ~feof(f_id);

%numOfLine=0;
%rem=fgets(f_id);numOfLine=numOfLine+1;

items={'width','color'};

for r=1:r_c(1,1); % the row number; the reaction number.


    for c=1:r_c(1,2); % the column number
        % numOfLine=numOfLine+1;
        %disp(numOfLine);

        if isnumeric(ref.number(r,c))&&ref.number(r,c)>0;
            num=ref.number(r,c) % the pre-identified row number
            %%% <read>


            %%
            for i=1:length(items); % the first round sets 'width'; the second round sets 'color'.

                subText=ref.(items{i})(r,c);
                %%% <write>
                reText=cellstr(text(num).str)
                %%% find location and replace it

             ToBeRplaced=position(reText,items{i})
                %%%
                %try
                if ~isstr(subText{1})  % test if subText{1} contains a string
                   warning('OK');
                   disp(subText{1});
                   subText{1}=num2str(subText{1}) % convert the double type into string type
                end

                text(num).str=strrep(text(num).str,ToBeRplaced,subText{1}) %% or subText{1}, exchangeable here.
                %catch

                disp(subText{1});

              % end

                % disp([numOfLine,subText,ToBeRplaced,text(numOfLine).str]);

                %disp(text(num).str);
                %disp(subText);
            end

        end
    end
end


annotedText=text;
parsed_update=parsed;
parsed_update.r_info=ref; % update r_info structure
parsed_update.r_info.XMLtext=text; % update XMLtext

%%%%%%%%%%%%%%%%%%%%%%%%  write to the file

for d=1:length(text);

    fprintf(f_out,'%s\n',char(text(d).str));

end

fclose(f_out);


end
