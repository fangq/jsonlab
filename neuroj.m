function [res, restapi, jsonstring] = neuroj(cmd, varargin)
%
%    [data, url, rawoutput] = neuroj(command, database, dataset, attachment, ...)
%
%    NeuroJSON.io client - browsing/listing/downloading/uploading data
%    provided at https://neurojson.io
%
%    author: Qianqian Fang (q.fang <at> neu.edu)
%
%    input:
%        command: a string, must be one of
%               'gui':
%                  - start a GUI and interactively browse datasets; the
%                    document tree is loaded without decoding JData
%                    constructs, so selecting a subkey reports the metadata
%                    of a _DataLink_ (database/document/path/size/hash and
%                    local cache status) or of a JData array (type, size,
%                    element count, complex/sparse flags, compression method
%                    and ratio). The toolbar can then download the linked
%                    file, preview or save the decoded data, and export the
%                    selected subtree to a JSON or binary JData file
%               'list':
%                  - if followed by nothing, list all databases
%                  - if database is given, list its all datasets
%                  - if dataset is given, list all its revisions
%               'info': return metadata associated with the specified
%                     database, dataset or attachment of a dataset
%               'get': must provide database and dataset name, download and
%                     parse the specified dataset or its attachment
%               'export': export a dataset to a local folder structure
%               'find':
%                  - if database is a string '/.../', find database by a
%                    regular expression pattern
%                  - if database is a struct, find database using
%                    NeuroJSON's search API
%                  - if dataset is a string '/.../', find datasets by a
%                    regular expression pattern
%                  - if dataset is a struct, find database using
%                    the _find API
%
%            admin commands (require database admin credentials):
%               'put': create database, create dataset under a dataset, or
%                     upload an attachment under a dataset
%               'delete': delete the specified attachment, dataset or
%                     database
%        jpath: a string in the format of JSONPath, see loadjson help
%
%    output:
%        data: parsed response data
%        url: the URL or REST-API of the desired resource
%        jsonstring: the JSON raw data from the URL
%
%    example:
%        neuroj('gui') % start neuroj client in the GUI mode
%
%        res = neuroj('list') % list all databases under res.database
%        res = neuroj('list', 'cotilab') % list all dataset under res.dataset
%        res = neuroj('list', 'cotilab', 'CSF_Neurophotonics_2025') % list all versions
%        res = neuroj('info') % list metadata of all datasets
%        res = neuroj('info', 'cotilab') % list metadata of a given database
%        res = neuroj('info', 'cotilab', 'CSF_Neurophotonics_2025') % list dataset header
%        [res, url, rawstr] = neuroj('get', 'cotilab', 'CSF_Neurophotonics_2025')
%        res = neuroj('export', 'cotilab', 'CSF_Neurophotonics_2025')
%        userinfo = inputdlg({'Username:', 'Password:'});
%        options = {'UserName', userinfo{1}, 'Password', userinfo{2});
%        res = neuroj('put', 'sandbox1d', 'newdoc', struct('Author', 'QF') 'weboptions', options);
%
% license:
%     BSD or GPL version 3, see LICENSE_{BSD,GPLv3}.txt files for details
%
% -- this function is part of JSONLab toolbox (http://neurojson.org/jsonlab)
%

if (nargin == 0)
    disp('NeuroJSON.io Client (https://neurojson.io)');
    fprintf('Format:\n\t[data, restapi] = neuroj(command, database, dataset, attachment, ...)\n\n');
    return
end

if (nargin == 1 && strcmp(cmd, 'gui'))
    handles.fmMain = figure('numbertitle', 'off', 'name', 'NeuroJSON.io Dataset Browser');
    tbTool = uitoolbar(handles.fmMain);

    % Create search panel (initially hidden) - takes top 50% when visible
    handles.pnSearch = uipanel(handles.fmMain, 'units', 'normalized', 'position', [0 0.5 1 0.5], 'visible', 'off', 'title', 'Dataset Search');

    % Column 1: Basic search
    col1 = 0.01;
    col1w = 0.08;
    col1e = 0.10;
    col1ew = 0.14;
    uicontrol(handles.pnSearch, 'style', 'text', 'string', 'Keyword:', 'units', 'normalized', 'position', [col1 0.88 col1w 0.08], 'HorizontalAlignment', 'right');
    handles.hKeyword = uicontrol(handles.pnSearch, 'style', 'edit', 'units', 'normalized', 'position', [col1e 0.88 col1ew 0.08]);
    uicontrol(handles.pnSearch, 'style', 'text', 'string', 'Database:', 'units', 'normalized', 'position', [col1 0.78 col1w 0.08], 'HorizontalAlignment', 'right');
    handles.hDatabase = uicontrol(handles.pnSearch, 'style', 'popupmenu', 'string', {'any', 'openneuro', 'abide', 'abide2', 'datalad-registry', 'adhd200'}, 'units', 'normalized', 'position', [col1e 0.78 col1ew 0.08]);
    uicontrol(handles.pnSearch, 'style', 'text', 'string', 'Dataset:', 'units', 'normalized', 'position', [col1 0.68 col1w 0.08], 'HorizontalAlignment', 'right');
    handles.hDataset = uicontrol(handles.pnSearch, 'style', 'edit', 'units', 'normalized', 'position', [col1e 0.68 col1ew 0.08]);
    uicontrol(handles.pnSearch, 'style', 'text', 'string', 'Gender:', 'units', 'normalized', 'position', [col1 0.58 col1w 0.08], 'HorizontalAlignment', 'right');
    handles.hGender = uicontrol(handles.pnSearch, 'style', 'popupmenu', 'string', {'any', 'male', 'female'}, 'units', 'normalized', 'position', [col1e 0.58 col1ew 0.08]);
    uicontrol(handles.pnSearch, 'style', 'text', 'string', 'Modality:', 'units', 'normalized', 'position', [col1 0.48 col1w 0.08], 'HorizontalAlignment', 'right');
    handles.hModality = uicontrol(handles.pnSearch, 'style', 'popupmenu', 'string', modalitylist(), 'units', 'normalized', 'position', [col1e 0.48 col1ew 0.08]);
    uicontrol(handles.pnSearch, 'style', 'text', 'string', 'Data type:', 'units', 'normalized', 'position', [col1 0.38 col1w 0.08], 'HorizontalAlignment', 'right');
    handles.hTypeName = uicontrol(handles.pnSearch, 'style', 'edit', 'units', 'normalized', 'position', [col1e 0.38 col1ew 0.08]);

    % Column 2: Age and counts
    col2 = 0.26;
    col2w = 0.08;
    col2e = 0.35;
    col2ew = 0.06;
    uicontrol(handles.pnSearch, 'style', 'text', 'string', 'Age min:', 'units', 'normalized', 'position', [col2 0.88 col2w 0.08], 'HorizontalAlignment', 'right');
    handles.hAgeMin = uicontrol(handles.pnSearch, 'style', 'edit', 'units', 'normalized', 'position', [col2e 0.88 col2ew 0.08]);
    uicontrol(handles.pnSearch, 'style', 'text', 'string', 'Age max:', 'units', 'normalized', 'position', [col2 0.78 col2w 0.08], 'HorizontalAlignment', 'right');
    handles.hAgeMax = uicontrol(handles.pnSearch, 'style', 'edit', 'units', 'normalized', 'position', [col2e 0.78 col2ew 0.08]);
    uicontrol(handles.pnSearch, 'style', 'text', 'string', 'Sess min:', 'units', 'normalized', 'position', [col2 0.68 col2w 0.08], 'HorizontalAlignment', 'right');
    handles.hSessMin = uicontrol(handles.pnSearch, 'style', 'edit', 'units', 'normalized', 'position', [col2e 0.68 col2ew 0.08]);
    uicontrol(handles.pnSearch, 'style', 'text', 'string', 'Sess max:', 'units', 'normalized', 'position', [col2 0.58 col2w 0.08], 'HorizontalAlignment', 'right');
    handles.hSessMax = uicontrol(handles.pnSearch, 'style', 'edit', 'units', 'normalized', 'position', [col2e 0.58 col2ew 0.08]);
    uicontrol(handles.pnSearch, 'style', 'text', 'string', 'Task min:', 'units', 'normalized', 'position', [col2 0.48 col2w 0.08], 'HorizontalAlignment', 'right');
    handles.hTaskMin = uicontrol(handles.pnSearch, 'style', 'edit', 'units', 'normalized', 'position', [col2e 0.48 col2ew 0.08]);
    uicontrol(handles.pnSearch, 'style', 'text', 'string', 'Task max:', 'units', 'normalized', 'position', [col2 0.38 col2w 0.08], 'HorizontalAlignment', 'right');
    handles.hTaskMax = uicontrol(handles.pnSearch, 'style', 'edit', 'units', 'normalized', 'position', [col2e 0.38 col2ew 0.08]);
    uicontrol(handles.pnSearch, 'style', 'text', 'string', 'Run min:', 'units', 'normalized', 'position', [col2 0.28 col2w 0.08], 'HorizontalAlignment', 'right');
    handles.hRunMin = uicontrol(handles.pnSearch, 'style', 'edit', 'units', 'normalized', 'position', [col2e 0.28 col2ew 0.08]);
    uicontrol(handles.pnSearch, 'style', 'text', 'string', 'Run max:', 'units', 'normalized', 'position', [col2 0.18 col2w 0.08], 'HorizontalAlignment', 'right');
    handles.hRunMax = uicontrol(handles.pnSearch, 'style', 'edit', 'units', 'normalized', 'position', [col2e 0.18 col2ew 0.08]);

    % Column 3: Name filters
    col3 = 0.43;
    col3w = 0.10;
    col3e = 0.54;
    col3ew = 0.12;
    uicontrol(handles.pnSearch, 'style', 'text', 'string', 'Task name:', 'units', 'normalized', 'position', [col3 0.88 col3w 0.08], 'HorizontalAlignment', 'right');
    handles.hTaskName = uicontrol(handles.pnSearch, 'style', 'edit', 'units', 'normalized', 'position', [col3e 0.88 col3ew 0.08]);
    uicontrol(handles.pnSearch, 'style', 'text', 'string', 'Session:', 'units', 'normalized', 'position', [col3 0.78 col3w 0.08], 'HorizontalAlignment', 'right');
    handles.hSessionName = uicontrol(handles.pnSearch, 'style', 'edit', 'units', 'normalized', 'position', [col3e 0.78 col3ew 0.08]);
    uicontrol(handles.pnSearch, 'style', 'text', 'string', 'Run name:', 'units', 'normalized', 'position', [col3 0.68 col3w 0.08], 'HorizontalAlignment', 'right');
    handles.hRunName = uicontrol(handles.pnSearch, 'style', 'edit', 'units', 'normalized', 'position', [col3e 0.68 col3ew 0.08]);

    % Column 4: Options
    col4 = 0.68;
    col4w = 0.08;
    col4e = 0.77;
    col4ew = 0.08;
    uicontrol(handles.pnSearch, 'style', 'text', 'string', 'Limit:', 'units', 'normalized', 'position', [col4 0.88 col4w 0.08], 'HorizontalAlignment', 'right');
    handles.hLimit = uicontrol(handles.pnSearch, 'style', 'edit', 'string', '25', 'units', 'normalized', 'position', [col4e 0.88 col4ew 0.08]);
    uicontrol(handles.pnSearch, 'style', 'text', 'string', 'Skip:', 'units', 'normalized', 'position', [col4 0.78 col4w 0.08], 'HorizontalAlignment', 'right');
    handles.hSkip = uicontrol(handles.pnSearch, 'style', 'edit', 'string', '0', 'units', 'normalized', 'position', [col4e 0.78 col4ew 0.08]);

    % Buttons
    uicontrol(handles.pnSearch, 'style', 'pushbutton', 'string', 'Search', 'units', 'normalized', 'position', [0.88 0.78 0.10 0.12], 'Callback', @(s, e) dosearch(handles.fmMain));
    uicontrol(handles.pnSearch, 'style', 'pushbutton', 'string', 'Clear', 'units', 'normalized', 'position', [0.88 0.63 0.10 0.12], 'Callback', @(s, e) clearsearch(handles.fmMain));
    uicontrol(handles.pnSearch, 'style', 'pushbutton', 'string', 'Close', 'units', 'normalized', 'position', [0.88 0.48 0.10 0.12], 'Callback', @(s, e) togglesearch(handles.fmMain));

    % Main panels - positions are all set by layoutgui() from handles.layout
    fixedfont = get(0, 'FixedWidthFontName');
    handles.lsDb = uicontrol(handles.fmMain, 'tooltipstring', 'Database', 'style', 'listbox', 'units', 'normalized');
    handles.lsDs = uicontrol(handles.fmMain, 'tooltipstring', 'Dataset', 'style', 'listbox', 'units', 'normalized');
    handles.lsJSON = uicontrol(handles.fmMain, 'tooltipstring', 'Data', 'style', 'listbox', 'units', 'normalized');
    handles.lsPeek = uicontrol(handles.fmMain, 'tooltipstring', 'Content of the highlighted item', 'style', 'listbox', 'units', 'normalized');
    handles.txValue = uicontrol(handles.fmMain, 'tooltipstring', 'Value', 'style', 'edit', 'max', 50, 'HorizontalAlignment', 'left', 'units', 'normalized');
    handles.txStatus = uicontrol(handles.fmMain, 'style', 'text', 'HorizontalAlignment', 'left', 'units', 'normalized', 'string', 'Press the refresh button to list the databases');

    % a fixed-width font keeps the right-aligned size column of each row lined up
    set([handles.lsDb, handles.lsDs, handles.lsJSON, handles.lsPeek, handles.txValue], 'fontname', fixedfont);

    handles.layout = defaultlayout();
    % built by concatenation, not preallocated: a uicontrol is a handle object
    % in MATLAB and cannot be assigned into a zeros() double array.
    % 'enable','off' keeps the bars from swallowing the click, so the figure
    % level WindowButtonDownFcn still sees it and can start a drag.
    handles.splitters = [];
    for i = 1:4
        handles.splitters = [handles.splitters, ...
                             uicontrol(handles.fmMain, 'style', 'frame', 'units', 'normalized', ...
                                       'backgroundcolor', [0.6 0.6 0.6], 'enable', 'off')];
    end
    handles.t0 = cputime;

    set(handles.lsDb, 'Callback', @(src, events) loadds(src, events, handles.fmMain));
    set(handles.lsDs, 'Callback', @(src, events) loaddsdata(src, events, handles.fmMain));
    set(handles.lsJSON, 'Callback', @(src, events) expandjsontree(src, events, handles.fmMain));
    set(handles.lsPeek, 'Callback', @(src, events) peekselect(src, events, handles.fmMain));

    set([handles.lsDb, handles.lsDs, handles.lsJSON, handles.lsPeek], ...
        'KeyPressFcn', @(src, events) navkeypress(src, events, handles.fmMain));

    % navigation tools
    addtoolbutton(tbTool, 'List databases', create_refresh_icon(), @(src, events) loaddb(src, events, handles.fmMain));
    addtoolbutton(tbTool, 'Search datasets', create_search_icon(), @(src, events) togglesearch(handles.fmMain));
    addtoolbutton(tbTool, 'Export the selected dataset to a folder', create_export_icon(), @(src, events) exportdataset(handles.fmMain));

    % value tools - enabled/disabled based on the selected node, see updateactions()
    handles.btDownload = addtoolbutton(tbTool, 'Download the file linked by _DataLink_', create_download_icon(), @(src, events) actdownload(handles.fmMain), 'on');
    handles.btPreview = addtoolbutton(tbTool, 'Preview the selected data', create_preview_icon(), @(src, events) actpreview(handles.fmMain));
    handles.btSaveAs = addtoolbutton(tbTool, 'Save the selected data as a local file', create_saveas_icon(), @(src, events) actsaveas(handles.fmMain));
    handles.btSubtree = addtoolbutton(tbTool, 'Export the selected subtree as JSON/binary JData (metadata only, _DataLink_ references are kept, not followed)', create_subtree_icon(), @(src, events) actexportsubtree(handles.fmMain));
    handles.btAttach = addtoolbutton(tbTool, 'Download every file linked below the selection', create_attach_icon(), @(src, events) actdownloadattachments(handles.fmMain));

    handles = buildmenus(handles);

    set(handles.fmMain, 'userdata', handles);
    set(handles.fmMain, 'WindowButtonDownFcn', @(src, events) splitterdown(handles.fmMain));
    set(handles.fmMain, 'WindowButtonUpFcn', @(src, events) splitterup(handles.fmMain));
    layoutgui(handles, false);
    updateactions(handles.fmMain);
    return
end

dbname = '';
if (~isempty(varargin))
    dbname = varargin{1};
end

dsname = '';
if (length(varargin) > 1)
    dsname = varargin{2};
end

attachment = '';
if (length(varargin) > 2)
    attachment = varargin{3};
end

opt = struct;
if (length(varargin) > 3)
    opt = varargin2struct(varargin{4:end});
end

serverurl = getenv('NEUROJSON_IO');

if (isempty(serverurl))
    serverurl = 'https://neurojson.io:7777/';
end

serverurl = jsonopt('server', serverurl, opt);
options = jsonopt('weboptions', {}, opt);
opt.weboptions = options;
rev = jsonopt('rev', '', opt);

cmd = lower(cmd);

restapi = serverurl;

if (strcmp(cmd, 'list'))
    restapi = [serverurl, 'sys/registry'];
    if (~isempty(dbname))
        restapi = [serverurl, dbname, '/', '_all_docs'];
        if (~isempty(dsname))
            restapi = [serverurl, dbname, '/', dsname, '?revs_info=true'];
        end
    end
    jsonstring = loadjson(restapi, opt, 'raw', 1);
    res = loadjson(jsonstring, opt);
    if (~isempty(dsname))
        res = res.(encodevarname('_revs_info'));
    elseif (~isempty(dbname))
        res.dataset = res.rows;
        res = rmfield(res, 'rows');
    end
elseif (strcmp(cmd, 'info'))
    restapi = [serverurl, '_dbs_info'];
    if (~isempty(dbname))
        restapi = [serverurl, dbname, '/'];
        if (~isempty(dsname))
            restapi = [serverurl, dbname, '/', dsname];
            if (~isempty(attachment))
                restapi = [serverurl, dbname, '/', dsname, '/', attachment];
            end
        end
    end
    if (~isempty(dsname) || ~isempty(attachment))
        res = loadjson(restapi, opt, 'header', 1);
        jsonstring = savejson('', res);
    else
        jsonstring = loadjson(restapi, opt, 'raw', 1);
        res = loadjson(jsonstring);
    end
elseif (strcmp(cmd, 'get'))
    if (isempty(dsname))
        error('get requires a dataset, i.e. document, name');
    end
    if (isempty(attachment))
        restapi = [serverurl, dbname, '/', dsname];
        if (~isempty(rev))
            restapi = [serverurl, dbname, '/', dsname, '?rev=' rev];
        end
    else
        restapi = [serverurl, dbname, '/', dsname, '/', attachment];
    end
    [res, jsonstring] = jdlink(restapi, opt);
elseif (strcmp(cmd, 'export'))
    if (isempty(dsname))
        error('export requires a dataset name');
    end

    % Ask user to choose export folder
    exportroot = uigetdir(pwd, 'Select folder to export dataset');
    if (exportroot == 0)
        res = [];
        restapi = '';
        jsonstring = '';
        return
    end

    % Load the dataset
    restapi = [serverurl, dbname, '/', dsname];
    if (~isempty(rev))
        restapi = [serverurl, dbname, '/', dsname, '?rev=' rev];
    end
    [data, jsonfile] = jdlink(restapi);
    if (iscell(jsonfile))
        jsonfile = jsonfile{1};
    end

    % Check if BIDS dataset by looking for BIDSVersion in dataset_description.json
    isBIDS = false;
    if (isstruct(data))
        % Try different possible key formats
        ddkeys = {'dataset_description.json', 'dataset_description_x2E_json', ...
                  encodevarname('dataset_description.json')};
        for i = 1:length(ddkeys)
            if (isfield(data, ddkeys{i}))
                ddcontent = data.(ddkeys{i});
                if (isstruct(ddcontent) && isfield(ddcontent, 'BIDSVersion'))
                    isBIDS = true;
                    break
                end
            end
        end
    end

    if (isBIDS)
        % Create dataset subfolder and perform folder reconstruction
        datasetfolder = fullfile(exportroot, dsname);
        if (~exist(datasetfolder, 'dir'))
            mkdir(datasetfolder);
        end
        exportdata(data, datasetfolder, dsname, data, jsonfile, datasetfolder);
        res = struct('exportpath', datasetfolder, 'status', 'success', 'type', 'BIDS');
    else
        % Not a BIDS dataset - just copy the cached JSON file
        [~, ~, fext] = fileparts(jsonfile);
        if (isempty(fext))
            fext = '.json';
        end
        destfile = fullfile(exportroot, [dsname, fext]);
        copyfile(jsonfile, destfile);
        res = struct('exportpath', destfile, 'status', 'success', 'type', 'JSON');
    end
elseif (strcmp(cmd, 'put'))
    if (isempty(dbname))
        error('put requires at least a database name');
    end
    restapi = [serverurl, dbname];
    putoption = weboptions(opt.weboptions{:});
    putoption.RequestMethod = 'post';
    putoption.MediaType = 'application/json';
    if (~isempty(dsname))
        if (isempty(attachment))
            error('must provide JSON input to upload');
        end
        if (ischar(attachment) && exist(attachment, 'file'))
            [afpath, afname, afext] = fileparts(attachment);
            attname = jsonopt('filename', [afname, afext], opt);
            restapi = [serverurl, dbname, '/' dsname '/' attname];
            res = websave(attname, restapi, weboptions('RequestMethod', 'put'));
        else
            restapi = [serverurl, dbname, '/_design/qq/_update/timestamp/' dsname];
            jsonstring = savejson('', attachment, 'compact', 1);
            res = webwrite(restapi, jsonstring, putoption);
        end
    else
        putoption.RequestMethod = 'put';
        res = webwrite(restapi, [], putoption);
    end
elseif (strcmp(cmd, 'delete'))
    if (isempty(dbname))
        error('put requires at least a database name');
    end
    deloption = weboptions(opt.weboptions{:});
    deloption.RequestMethod = 'delete';
    restapi = [serverurl, dbname];
    if (~isempty(dsname))
        restapi = [serverurl, dbname, '/', dsname];
        if (~isempty(attachment))
            restapi = [serverurl, dbname, '/', dsname, '/', attachment];
        end
    end
    res = webwrite(restapi, [], deloption);
elseif (strcmp(cmd, 'find'))
    if (isempty(dbname))
        error('find requires at least a search regular expression pattern');
    end
    if (~isempty(dbname))
        if (ischar(dsname) && dbname(1) == '/' && dbname(end) == '/')
            [dblist, restapi, jsonstring] = neuroj('list');
            res = {};
            for i = 1:length(dblist.database)
                if (~isempty(regexpi(savejson('', dblist.database{i}, 'compact', 1), dbname(2:end - 1), 'once')))
                    res{end + 1} = dblist.database{i};
                end
            end
        elseif (isstruct(dbname))
            param = join(cellfun(@(x) [x '=' dbname.(x)], fieldnames(dbname), 'UniformOutput', false));
            restapi = ['https://neurojson.org/io/search.cgi?' param{:}];
            jsonstring = loadjson(restapi, opt, 'raw', 1);
            res = loadjson(jsonstring, opt);
        elseif (~isempty(dsname) && ischar(dsname) && dsname(1) == '/' && dsname(end) == '/')
            [dslist, restapi, jsonstring] = neuroj('list', dbname);
            res = {};
            for i = 1:length(dslist.dataset)
                if (~isempty(regexpi(dslist.dataset(i).id, dsname(2:end - 1), 'once')))
                    res{end + 1} = dslist.dataset(i).id;
                end
            end
        elseif (~isempty(dsname) && (isstruct(dsname) || (ischar(dsname) && dsname(1) == '{' && dsname(end) == '}')))
            findoption = weboptions(opt.weboptions{:});
            findoption.RequestMethod = 'post';
            findoption.MediaType = 'application/json';
            restapi = [serverurl, dbname, '/_find'];
            if (isstruct(dsname))
                if (~isfield(dsname, 'selector'))
                    dsname.selector = {};
                end
                res = webwrite(restapi, savejson('', dsname, 'compact', 1), findoption);
            else
                res = webwrite(restapi, dsname, findoption);
            end
        end
    end
end

% --------------------------------------------------------------------------
function exportdata(data, currentfolder, parentkey, rootdata, cachefile, exportroot)
% Export data structure to folder hierarchy

if (nargin < 6)
    exportroot = currentfolder;
end
if (~isstruct(data))
    return
end

keys = fieldnames(data);
datainfo = struct();

for i = 1:length(keys)
    key = keys{i};
    val = data.(key);
    decodedkey = decodevarname(key);

    % First check if value is a _DataLink_ struct (regardless of key name)
    isDataLink = isstruct(val) && ...
        (isfield(val, '_DataLink_') || isfield(val, encodevarname('_DataLink_')));

    if (isDataLink)
        % Get the link URL
        if isfield(val, '_DataLink_')
            linkurl = val.('_DataLink_');
        else
            linkurl = val.(encodevarname('_DataLink_'));
        end

        % Determine destination path
        if (~isempty(regexp(decodedkey, '\.[^\.\/\\]+$', 'once')) && ~strcmp(decodedkey(1), '.'))
            % Key looks like a filename
            linkpath = fullfile(currentfolder, decodedkey);
        else
            % Key doesn't have extension
            linkpath = fullfile(currentfolder, decodedkey);
        end

        if (~isempty(linkurl))
            if (linkurl(1) == '$')
                resolveinternal(rootdata, linkurl, linkpath, exportroot);
            else
                [~, cachedfile] = jdlink(linkurl);
                if (iscell(cachedfile))
                    cachedfile = cachedfile{1};
                end
                if (~isempty(cachedfile))
                    createlink(cachedfile, linkpath);
                end
            end
        end

        % Check if it's a file (contains . with suffix, not starting with .)
    elseif (~isempty(regexp(decodedkey, '\.[^\.\/\\]+$', 'once')) && ~strcmp(decodedkey(1), '.'))
        filepath = fullfile(currentfolder, decodedkey);

        % .snirf file with SNIRFData
        if (myendswith(lower(decodedkey), '.snirf') && isstruct(val) && ...
            (isfield(val, 'SNIRFData') || isfield(val, encodevarname('SNIRFData'))))
            try
                if isfield(val, 'SNIRFData')
                    snirfdata = val.SNIRFData;
                else
                    snirfdata = val.(encodevarname('SNIRFData'));
                end
                savesnirf(snirfdata, filepath);
            catch
                savejson('', val, 'filename', filepath);
            end
            % .tsv file - convert JSON to TSV
        elseif (myendswith(lower(decodedkey), '.tsv') && isstruct(val))
            savestruct2tsv(val, filepath);
        elseif (ischar(val) || isstring(val))
            fid = fopen(filepath, 'w');
            if (fid > 0)
                fwrite(fid, val);
                fclose(fid);
            end
        elseif (isnumeric(val) || islogical(val))
            fid = fopen(filepath, 'wb');
            if (fid > 0)
                fwrite(fid, val);
                fclose(fid);
            end
        elseif (isstruct(val))
            % Struct without _DataLink_ - save as JSON
            savejson('', val, 'filename', filepath);
        else
            savejson('', val, 'filename', filepath);
        end

        % Metadata fields for .datainfo.json
    elseif (strcmp(decodedkey, '_id') || strcmp(decodedkey, '_rev') || ...
            ~isempty(regexp(decodedkey, '^Mesh', 'once')) || ...
            ~isempty(regexp(decodedkey, '^_Array.*_$', 'once')))
        datainfo.(key) = val;

        % Subfolder (struct without file extension in key name)
    elseif (isstruct(val))
        subfolder = fullfile(currentfolder, decodedkey);
        if (~exist(subfolder, 'dir'))
            mkdir(subfolder);
        end
        exportdata(val, subfolder, decodedkey, rootdata, cachefile, exportroot);
    end
end

if (~isempty(fieldnames(datainfo)))
    savejson('', datainfo, 'filename', fullfile(currentfolder, '.datainfo.json'));
end

% --------------------------------------------------------------------------
function resolveinternal(rootdata, jpathstr, destpath, exportroot)
% Resolve internal JSONPath reference - create relative symlink

try
    % Convert JSONPath to relative file path for symlink
    % Example: $.sub-6022.ses-1.nirs.sub-6022_ses-1_task-MA_run-01_channels\.tsv
    % becomes: sub-6022/ses-1/nirs/sub-6022_ses-1_task-MA_run-01_channels.tsv

    if (length(jpathstr) > 2 && strcmp(jpathstr(1:2), '$.') && ~isempty(exportroot))
        % Remove $. prefix
        pathpart = jpathstr(3:end);

        % Use same placeholder as jsonpath.m: replace \. with _0x2E_
        pathpart = strrep(pathpart, '\.', '_0x2E_');

        % Split by dots (path separators)
        parts = strsplit(pathpart, '.');

        % Restore dots in each part
        parts = cellfun(@(x) strrep(x, '_0x2E_', '.'), parts, 'UniformOutput', false);

        % Build relative path
        if (~isempty(parts))
            relpath = fullfile(parts{:});
            targetpath = fullfile(exportroot, relpath);

            % Calculate relative path from destpath's directory to target
            destdir = fileparts(destpath);

            % Ensure parent directory exists
            if (~isempty(destdir) && ~exist(destdir, 'dir'))
                mkdir(destdir);
            end

            % Calculate relative symlink target
            reltarget = relativepath(targetpath, destdir);

            % Create symlink
            createlink(reltarget, destpath);
            return
        end
    end

    % Fallback: resolve and save actual data using jdict/jsonpath
    jd = jdict(rootdata);
    resolved = jd.(jpathstr);
    if (isa(resolved, 'jdict'))
        resolved = resolved.v();
    end

    if (isempty(resolved))
        warning('Could not resolve jsonpath: %s', jpathstr);
        return
    end

    [~, ~, ext] = fileparts(destpath);

    % Ensure parent directory exists
    destdir = fileparts(destpath);
    if (~isempty(destdir) && ~exist(destdir, 'dir'))
        mkdir(destdir);
    end

    if (strcmpi(ext, '.tsv') && isstruct(resolved))
        savestruct2tsv(resolved, destpath);
    elseif (ischar(resolved) || isstring(resolved))
        fid = fopen(destpath, 'w');
        if (fid > 0)
            fwrite(fid, resolved);
            fclose(fid);
        end
    elseif (isstruct(resolved))
        savejson('', resolved, 'filename', destpath);
    else
        fid = fopen(destpath, 'wb');
        if (fid > 0)
            fwrite(fid, resolved);
            fclose(fid);
        end
    end
catch ME
    warning('Could not resolve internal link: %s - %s', jpathstr, ME.message);
end

% --------------------------------------------------------------------------
function relpath = relativepath(targetpath, basepath)
% Calculate relative path from basepath to targetpath

if (isempty(basepath))
    relpath = targetpath;
    return
end

% Normalize paths - get absolute paths
targetpath = getfullpath(targetpath);
basepath = getfullpath(basepath);

% Split into parts
if (ispc)
    sep = '\';
    targparts = strsplit(targetpath, {'\', '/'});
    baseparts = strsplit(basepath, {'\', '/'});
else
    sep = '/';
    targparts = strsplit(targetpath, '/');
    baseparts = strsplit(basepath, '/');
end

% Remove empty parts
targparts = targparts(~cellfun('isempty', targparts));
baseparts = baseparts(~cellfun('isempty', baseparts));

% Find common prefix length
commonlen = 0;
minlen = min(length(targparts), length(baseparts));
for j = 1:minlen
    if (strcmpi(targparts{j}, baseparts{j}))
        commonlen = j;
    else
        break
    end
end

% Build relative path
numdirs = length(baseparts) - commonlen;
numtargparts = length(targparts) - commonlen;
relparts = cell(1, numdirs + numtargparts);

for j = 1:numdirs
    relparts{j} = '..';
end

for j = 1:numtargparts
    relparts{numdirs + j} = targparts{commonlen + j};
end

if (isempty(relparts))
    relpath = '.';
else
    relpath = strjoin(relparts, sep);
end

% --------------------------------------------------------------------------
function fullpath = getfullpath(filepath)
% Get full absolute path

if (isempty(filepath))
    fullpath = pwd;
    return
end

% Check if already absolute
if (ispc)
    isabs = (length(filepath) >= 2 && filepath(2) == ':') || ...
            (length(filepath) >= 1 && (filepath(1) == '\' || filepath(1) == '/'));
else
    isabs = (length(filepath) >= 1 && filepath(1) == '/');
end

if (isabs)
    fullpath = filepath;
else
    fullpath = fullfile(pwd, filepath);
end

% --------------------------------------------------------------------------
function savestruct2tsv(data, filepath)
% Convert a struct with column arrays to TSV format

if (~isstruct(data))
    return
end
keys = fieldnames(data);
if (isempty(keys))
    return
end

% Get the length of the first column to determine number of rows
firstcol = data.(keys{1});
if (iscell(firstcol))
    nrows = length(firstcol);
elseif (isnumeric(firstcol) || islogical(firstcol))
    nrows = length(firstcol);
else
    nrows = 1;
end

fid = fopen(filepath, 'w');
if (fid < 0)
    return
end

% Write header
header = cellfun(@decodevarname, keys, 'UniformOutput', false);
fprintf(fid, '%s\n', strjoin(header, char(9)));

% Write data rows
for r = 1:nrows
    row = cell(1, length(keys));
    for c = 1:length(keys)
        coldata = data.(keys{c});
        if (iscell(coldata) && r <= length(coldata))
            val = coldata{r};
        elseif ((isnumeric(coldata) || islogical(coldata)) && r <= length(coldata))
            val = coldata(r);
        else
            val = coldata;
        end
        if (isnumeric(val))
            row{c} = num2str(val);
        elseif (islogical(val))
            row{c} = num2str(double(val));
        else
            row{c} = char(val);
        end
    end
    fprintf(fid, '%s\n', strjoin(row, char(9)));
end
fclose(fid);

% --------------------------------------------------------------------------
function createlink(target, linkname)
% Create a symbolic link (platform-dependent)

if (ispc)
    [status, ~] = system(['mklink "' linkname '" "' target '"']);
    if (status ~= 0)
        [status, ~] = system(['mklink /D "' linkname '" "' target '"']);
        %         if (status ~= 0)
        %             copyfile(target, linkname);
        %         end
    end
else
    [status, ~] = system(['ln -s "' target '" "' linkname '"']);
    %     if (status ~= 0)
    %         copyfile(target, linkname);
    %     end
end

% --------------------------------------------------------------------------
function tf = myendswith(str, suffix)
% Check if string ends with suffix (for older MATLAB compatibility)

if (length(str) >= length(suffix))
    tf = strcmp(str(end - length(suffix) + 1:end), suffix);
else
    tf = false;
end

% --------------------------------------------------------------------------
%  GUI construction helpers
% --------------------------------------------------------------------------

function bt = addtoolbutton(tbTool, tooltip, icondata, callback, separator)
% add a uipushtool to a toolbar; setting CData via set() works in both
% MATLAB and Octave, so no toolkit-specific branch is needed

if (nargin < 5)
    separator = 'off';
end
bt = uipushtool(tbTool, 'tooltipstring', tooltip, 'ClickedCallback', callback, 'separator', separator);
set(bt, 'CData', icondata);

% --------------------------------------------------------------------------
function layout = defaultlayout()
% cols: right edge of the database, dataset and JSON columns as fractions of
% the window width (the peek column takes the remainder); listtop: height of
% the list row; valuetop: top of the status bar

layout = struct('cols', [0.16, 0.38, 0.69], 'listtop', 0.28, 'statush', 0.035);

% --------------------------------------------------------------------------
function layoutgui(handles, showsearch)
% single source of truth for the panel geometry; the search panel takes the
% top half of the window and squeezes the browser panes into the bottom half

if (nargin > 1)
    setappdata(handles.fmMain, 'searchvisible', showsearch);
else
    showsearch = getappdata(handles.fmMain, 'searchvisible');
    if (isempty(showsearch))
        showsearch = false;
    end
end

layout = handles.layout;
if (showsearch)
    top = 0.5;
else
    top = 1;
end
set(handles.pnSearch, 'visible', onoffstr(showsearch));

sbar = layout.statush * top;
vtop = layout.listtop * top;            % top edge of the value pane
edges = [0, layout.cols, 1];
gap = 0.002;

set(handles.txStatus, 'position', [0, 0, 1, sbar]);
set(handles.txValue, 'position', [0, sbar, 1, vtop - sbar]);

lists = [handles.lsDb, handles.lsDs, handles.lsJSON, handles.lsPeek];
for i = 1:4
    width = max(0.01, edges(i + 1) - edges(i) - gap);
    set(lists(i), 'position', [edges(i), vtop, width, top - vtop]);
end

% three vertical splitters between the columns, one horizontal above the value pane
for i = 1:3
    set(handles.splitters(i), 'position', [edges(i + 1) - gap, vtop, gap, top - vtop]);
end
set(handles.splitters(4), 'position', [0, vtop - gap, 1, gap]);

% --------------------------------------------------------------------------
function active = splitterdown(hwin, pos)
% start dragging when the press landed on one of the splitter bars; pos may
% be supplied explicitly so the hit test can be exercised without a mouse

active = 0;
handles = get(hwin, 'userdata');
if (~isstruct(handles) || ~isfield(handles, 'splitters'))
    return
end
if (nargin < 2)
    pos = normalizedpointer(hwin);
end

for i = 1:4
    box = get(handles.splitters(i), 'position');
    % widen the hit area so a 0.002-wide bar is still grabbable
    pad = 0.006;
    if (pos(1) >= box(1) - pad && pos(1) <= box(1) + box(3) + pad && ...
        pos(2) >= box(2) - pad && pos(2) <= box(2) + box(4) + pad)
        active = i;
        break
    end
end
if (active == 0)
    return
end

setappdata(hwin, 'dragsplitter', active);
setappdata(hwin, 'dragprevmotion', get(hwin, 'WindowButtonMotionFcn'));
set(hwin, 'WindowButtonMotionFcn', @(src, events) splittermove(hwin));

% --------------------------------------------------------------------------
function pos = normalizedpointer(hwin)
% pointer position as a fraction of the figure, whatever units it uses

pos = get(hwin, 'currentpoint');
if (strcmp(get(hwin, 'units'), 'pixels'))
    pixpos = get(hwin, 'position');
    pos = [pos(1) / max(1, pixpos(3)), pos(2) / max(1, pixpos(4))];
end

% --------------------------------------------------------------------------
function splittermove(hwin, pos)
% drag the active splitter to pos (defaults to the current pointer); the
% explicit argument keeps the clamping testable without a real mouse

active = getappdata(hwin, 'dragsplitter');
if (isempty(active) || active == 0)
    return
end
handles = get(hwin, 'userdata');
if (nargin < 2)
    pos = normalizedpointer(hwin);
end

minsize = 0.06;
layout = handles.layout;
if (active <= 3)
    edges = [0, layout.cols, 1];
    lowbound = edges(active) + minsize;
    highbound = edges(active + 2) - minsize;
    layout.cols(active) = min(max(pos(1), lowbound), highbound);
else
    showsearch = getappdata(hwin, 'searchvisible');
    if (isempty(showsearch))
        showsearch = false;
    end
    top = 1;
    if (showsearch)
        top = 0.5;
    end
    layout.listtop = min(max(pos(2) / top, layout.statush + minsize), 1 - minsize);
end
handles.layout = layout;
set(hwin, 'userdata', handles);
layoutgui(handles);

% --------------------------------------------------------------------------
function splitterup(hwin)

active = getappdata(hwin, 'dragsplitter');
if (isempty(active) || active == 0)
    return
end
setappdata(hwin, 'dragsplitter', 0);
set(hwin, 'WindowButtonMotionFcn', getappdata(hwin, 'dragprevmotion'));

% --------------------------------------------------------------------------
function str = onoffstr(tf)

if (tf)
    str = 'on';
else
    str = 'off';
end

% --------------------------------------------------------------------------
function setenable(h, tf)

if (~isempty(h) && ishandle(h))
    set(h, 'enable', onoffstr(tf));
end

% --------------------------------------------------------------------------
function setbusy(hwin, isbusy)
% show progress by switching the figure pointer - unlike the previously used
% hidden msgbox, this is destroyed together with the browser window

if (~ishandle(hwin))
    return
end
if (isbusy)
    set(hwin, 'pointer', 'watch');
else
    set(hwin, 'pointer', 'arrow');
end
drawnow;

% --------------------------------------------------------------------------
function tf = isactivated(handles, event)
% a list entry is "activated" by a double-click or by pressing enter; the
% cputime test keeps the historical behavior of treating two rapid callbacks
% as a double-click on toolkits that do not report SelectionType

tf = strcmp(get(handles.fmMain, 'SelectionType'), 'open');
if (~tf)
    try
        tf = strcmp(event.Key, 'enter');
    catch
        tf = false;
    end
end
if (~tf)
    tf = (cputime - handles.t0) < 0.01;
end

% --------------------------------------------------------------------------
%  JData keyword lookup - the same keyword may appear under three different
%  field-name encodings: '_ArrayType_' (Octave), 'x0x5F_ArrayType_' (MATLAB,
%  produced by encodevarname) and 'x_ArrayType_' (other JData implementations)
% --------------------------------------------------------------------------

function [tf, key] = hasjkey(obj, name)
% the candidate list covers all four spellings, so a document saved by one
% environment stays readable in the other

tf = false;
key = '';
if (~isstruct(obj) && ~isa(obj, 'containers.Map'))
    return
end
cand = {name, encodevarname(name), ['x' name], ['x0x5F' name]};
for i = 1:length(cand)
    if (isa(obj, 'containers.Map'))
        found = isKey(obj, cand{i});
    else
        found = isfield(obj, cand{i});
    end
    if (found)
        tf = true;
        key = cand{i};
        return
    end
end

% --------------------------------------------------------------------------
function val = getjkey(obj, name, default)

if (nargin < 3)
    default = [];
end
val = default;
[tf, key] = hasjkey(obj, name);
if (~tf)
    return
end
if (isa(obj, 'containers.Map'))
    val = obj(key);
else
    val = obj(1).(key);
end

% --------------------------------------------------------------------------
%  tree navigation - the browsing position is a stack of keys rather than a
%  JSONPath string, so keys containing '.', '[', ']' or '"' need no escaping
% --------------------------------------------------------------------------

function val = getnode(root, pathstack)

val = root;
for i = 1:length(pathstack)
    key = pathstack{i};
    if (isa(val, 'jdict'))
        val = val.v();
    end
    if (isnumeric(key))
        if (iscell(val))
            val = val{key};
        else
            val = val(key);
        end
    elseif (isa(val, 'containers.Map'))
        val = val(key);
    elseif (isstruct(val) && isfield(val, key))
        val = val.(key);
    else
        val = [];
        return
    end
end

% --------------------------------------------------------------------------
function keylist = nodekeys(val)
% list the child keys of a container; scalar structs and maps yield names,
% cells and struct arrays yield numeric indices, leaves yield nothing

keylist = {};
if (isa(val, 'jdict'))
    val = val.v();
end
if (isa(val, 'containers.Map'))
    keylist = keys(val);
elseif (iscell(val) && ~isempty(val))
    keylist = num2cell(1:numel(val));
elseif (isstruct(val) && numel(val) == 1)
    keylist = fieldnames(val);
elseif (isstruct(val) && numel(val) > 1)
    keylist = num2cell(1:numel(val));
end
keylist = keylist(:)';

% --------------------------------------------------------------------------
function str = keylabel(key)

if (isnumeric(key))
    str = sprintf('[%d]', key);
else
    str = decodevarname(key);
end

% --------------------------------------------------------------------------
function str = pathstring(pathstack)

str = char(36);
for i = 1:length(pathstack)
    if (isnumeric(pathstack{i}))
        str = [str sprintf('[%d]', pathstack{i})];
    else
        str = [str '.' decodevarname(pathstack{i})];
    end
end

% --------------------------------------------------------------------------
function str = dimstring(dims)

str = sprintf('%d', dims(1));
for i = 2:length(dims)
    str = [str sprintf(' x %d', dims(i))];
end

% --------------------------------------------------------------------------
function str = humansize(bytes)

if (isempty(bytes) || ~isnumeric(bytes) || any(isnan(bytes)))
    str = 'unknown';
    return
end
bytes = double(bytes(1));
units = {'bytes', 'KiB', 'MiB', 'GiB', 'TiB'};
idx = 1;
while (bytes >= 1024 && idx < length(units))
    bytes = bytes / 1024;
    idx = idx + 1;
end
if (idx == 1)
    str = sprintf('%d bytes', round(bytes));
else
    str = sprintf('%.1f %s', bytes, units{idx});
end

% --------------------------------------------------------------------------
function vec = tovec(val)

if (iscell(val))
    val = val(cellfun(@(x) isnumeric(x) && ~isempty(x), val));
    if (isempty(val))
        vec = [];
        return
    end
    vec = cellfun(@(x) double(x(1)), val);
elseif (isnumeric(val))
    vec = double(val(:)');
else
    vec = [];
end

% --------------------------------------------------------------------------
function nbytes = jdtypebytes(typename)

typemap = {'int8', 1, 'uint8', 1, 'int16', 2, 'uint16', 2, 'int32', 4, ...
           'uint32', 4, 'int64', 8, 'uint64', 8, 'single', 4, 'double', 8, ...
           'char', 1, 'logical', 1, 'half', 2};
nbytes = 0;
if (~ischar(typename))
    return
end
pos = find(strcmpi(typemap(1:2:end), typename), 1);
if (~isempty(pos))
    nbytes = typemap{2 * pos};
end

% --------------------------------------------------------------------------
function params = urlparams(url)
% split the query string of a URL into a flat {name, value, ...} cell array

params = {};
if (~ischar(url))
    return
end
qpos = find(url == '?', 1);
if (isempty(qpos))
    return
end
items = regexp(url(qpos + 1:end), '[&;]', 'split');
for i = 1:length(items)
    eqpos = find(items{i} == '=', 1);
    if (isempty(eqpos) || eqpos == 1)
        continue
    end
    params{end + 1} = items{i}(1:eqpos - 1);
    params{end + 1} = urldecode_(items{i}(eqpos + 1:end));
end

% --------------------------------------------------------------------------
function str = urldecode_(str)
% percent-decoding without regexprep dynamic expressions, which Octave's
% regexprep does not support

str = strrep(str, '+', ' ');
pos = strfind(str, '%');
if (isempty(pos))
    return
end
out = '';
last = 1;
for i = 1:length(pos)
    if (pos(i) < last || pos(i) + 2 > length(str))
        continue
    end
    hexpair = str(pos(i) + 1:pos(i) + 2);
    if (isempty(regexp(hexpair, '^[0-9A-Fa-f]{2}$', 'once')))
        continue
    end
    out = [out str(last:pos(i) - 1) char(hex2dec(hexpair))];
    last = pos(i) + 3;
end
str = [out str(last:end)];

% --------------------------------------------------------------------------
function str = safename(str)

if (~ischar(str) || isempty(str))
    str = 'subtree';
    return
end
str = regexprep(str, '[^\w\-\.]', '_');

% --------------------------------------------------------------------------
%  node inspection - describe the selected value and decide which of the
%  download/preview/save-as toolbar actions apply to it
% --------------------------------------------------------------------------

function meta = nodemeta(val)

meta = emptymeta();

if (isa(val, 'jdict'))
    val = val.v();
end

if (isstruct(val) && numel(val) == 1)
    if (hasjkey(val, '_DataLink_'))
        meta = datalinkmeta(val);
        return
    end
    if (hasjkey(val, '_ArrayType_') || hasjkey(val, '_ArraySize_'))
        meta = jdarraymeta(val);
        return
    end
end

if (isstruct(val) || isa(val, 'containers.Map'))
    meta = objectmeta(val);
    return
end

meta.lines = valuelines(val);
if (ischar(val))
    meta.kind = 'text';
    meta.cansaveas = true;
    meta.canpreview = (length(val) > 200);
elseif (isnumeric(val) || islogical(val))
    meta.kind = 'numeric';
    meta.cansaveas = ~isempty(val);
    meta.canpreview = (numel(val) > 1);
elseif (iscell(val))
    meta.kind = 'cell';
    meta.cansaveas = true;
end

% --------------------------------------------------------------------------
function meta = emptymeta()

meta = struct('kind', 'value', 'lines', {{}}, 'url', '', 'cachefile', '', ...
              'candownload', false, 'canpreview', false, 'cansaveas', false);

% --------------------------------------------------------------------------
function meta = datalinkmeta(val)
% describe a _DataLink_ node: where it points, whatever metadata the URL
% carries (database/document/path/size/hash), and its local cache status

meta = emptymeta();
meta.kind = 'datalink';

linkurl = getjkey(val, '_DataLink_', '');
if (iscell(linkurl) && ~isempty(linkurl))
    linkurl = linkurl{1};
end
if (~ischar(linkurl))
    linkurl = '';
end
meta.url = linkurl;

if (~isempty(linkurl) && linkurl(1) == char(36))
    meta.lines = {infoline('Type:', '_DataLink_ (internal JSONPath reference)'), ...
                  infoline('Target:', linkurl)};
    return
end

lines = {infoline('Type:', '_DataLink_ (external resource)'), ...
         infoline('URL:', linkurl)};

% metadata carried as query parameters of a neurojson.org/io/stat.cgi link
knownnames = {'db', 'dbname', 'doc', 'docname', 'file', 'path', 'size', ...
              'hash', 'sha256', 'sha1', 'md5', 'etag', 'mtime', 'type'};
knownlabels = {'Database:', 'Database:', 'Document:', 'Document:', 'Path:', 'Path:', 'Size:', ...
               'Hash:', 'SHA-256:', 'SHA-1:', 'MD5:', 'ETag:', 'Modified:', 'Media type:'};
params = urlparams(linkurl);
hasdb = false;
for i = 1:2:length(params)
    pval = params{i + 1};
    pos = find(strcmpi(knownnames, params{i}), 1);
    if (isempty(pos))
        lines{end + 1} = infoline([params{i} ':'], pval);
        continue
    end
    if (strcmpi(params{i}, 'size'))
        readable = humansize(str2double(pval));
        if (~strcmp(readable, [pval ' bytes']))
            readable = sprintf('%s (%s bytes)', readable, pval);
        end
        pval = readable;
    elseif (~isempty(regexpi(params{i}, '^(db|dbname)$')))
        hasdb = true;
    end
    lines{end + 1} = infoline(knownlabels{pos}, pval);
end

% direct neurojson.io links carry the same metadata in the path instead
if (~hasdb)
    ref = regexp(linkurl, '^(https?|ftp)://neurojson\.io(:\d+)?/(?<db>[^/?]+)/(?<doc>[^/?]+)(/(?<file>[^?]+))?', 'names', 'once');
    if (~isempty(ref) && ~isempty(ref.db))
        lines{end + 1} = infoline('Database:', ref.db);
        lines{end + 1} = infoline('Document:', ref.doc);
        if (~isempty(ref.file))
            lines{end + 1} = infoline('Path:', ref.file);
        end
    end
end

% a link may also carry an inline _DataInfo_ sibling
datainfo = getjkey(val, '_DataInfo_', []);
if (isstruct(datainfo) && numel(datainfo) == 1)
    infokeys = fieldnames(datainfo);
    for i = 1:length(infokeys)
        lines{end + 1} = infoline([decodevarname(infokeys{i}) ':'], scalarstr(datainfo.(infokeys{i})));
    end
end

[meta.cachefile, cachestatus] = linkcachefile(linkurl);
lines{end + 1} = cachestatus;
if (isempty(meta.cachefile))
    meta.candownload = ~isempty(linkurl);
else
    meta.canpreview = true;
    meta.cansaveas = true;
end
meta.lines = lines;

% --------------------------------------------------------------------------
function [cachefile, status] = linkcachefile(linkurl)
% report where jdlink would place this URL locally and whether it is there

cachefile = '';
status = infoline('Cached:', 'unknown');
try
    [cachepath, filename] = jsoncache(linkurl);
catch
    return
end
if (~iscell(cachepath) && ischar(cachepath) && exist(cachepath, 'file'))
    cachefile = cachepath;
    finfo = dir(cachefile);
    status = infoline('Cached:', sprintf('%s (%s)', cachefile, humansize(finfo(1).bytes)));
elseif (iscell(cachepath) && ~isempty(cachepath) && ischar(filename))
    status = infoline('Cached:', sprintf('no, use the Download button (-> %s)', [cachepath{1} filesep filename]));
end

% --------------------------------------------------------------------------
function meta = jdarraymeta(val)
% describe a JData array construct without decompressing it

meta = emptymeta();
meta.kind = 'array';
meta.canpreview = true;
meta.cansaveas = true;

arraytype = getjkey(val, '_ArrayType_', '');
arraysize = tovec(getjkey(val, '_ArraySize_', []));
ziptype = getjkey(val, '_ArrayZipType_', '');
zipsize = tovec(getjkey(val, '_ArrayZipSize_', []));
iscomplexarray = ~isempty(getjkey(val, '_ArrayIsComplex_', [])) && any(tovec(getjkey(val, '_ArrayIsComplex_', 0)));
issparsearray = ~isempty(getjkey(val, '_ArrayIsSparse_', [])) && any(tovec(getjkey(val, '_ArrayIsSparse_', 0)));

lines = {infoline('Type:', 'JData array construct')};
if (ischar(arraytype) && ~isempty(arraytype))
    lines{end + 1} = infoline('Array type:', arraytype);
end
if (~isempty(arraysize))
    lines{end + 1} = infoline('Array size:', dimstring(arraysize));
    lines{end + 1} = infoline('Elements:', sprintf('%d', prod(arraysize)));
end

elembytes = jdtypebytes(arraytype);
rawbytes = [];
if (elembytes > 0 && ~isempty(arraysize))
    rawbytes = prod(arraysize) * elembytes * (1 + iscomplexarray);
    lines{end + 1} = infoline('Uncompressed:', humansize(rawbytes));
end

lines{end + 1} = infoline('Complex:', yesno(iscomplexarray));
lines{end + 1} = infoline('Sparse:', yesno(issparsearray));

arrayorder = getjkey(val, '_ArrayOrder_', '');
if (ischar(arrayorder) && ~isempty(arrayorder))
    if (strncmpi(arrayorder, 'r', 1))
        lines{end + 1} = infoline('Order:', 'r (row-major)');
    else
        lines{end + 1} = infoline('Order:', 'c (column-major)');
    end
end

arrayshape = getjkey(val, '_ArrayShape_', '');
if (~isempty(arrayshape))
    if (iscell(arrayshape) && ~isempty(arrayshape))
        arrayshape = arrayshape{1};
    end
    if (ischar(arrayshape))
        lines{end + 1} = infoline('Shape:', arrayshape);
    end
end

arraylabel = getjkey(val, '_ArrayLabel_', '');
if (~isempty(arraylabel))
    lines{end + 1} = infoline('Dim labels:', joinstrs(arraylabel));
end
arrayunits = getjkey(val, '_ArrayUnits_', '');
if (~isempty(arrayunits))
    lines{end + 1} = infoline('Units:', joinstrs(arrayunits));
end

if (ischar(ziptype) && ~isempty(ziptype))
    lines{end + 1} = infoline('Compression:', ziptype);
    if (~isempty(zipsize))
        lines{end + 1} = infoline('Pre-zip dims:', dimstring(zipsize));
    end
    zipbytes = zipdatabytes(getjkey(val, '_ArrayZipData_', []));
    if (~isempty(zipbytes))
        lines{end + 1} = infoline('Compressed:', humansize(zipbytes));
        if (~isempty(rawbytes) && zipbytes > 0)
            lines{end + 1} = infoline('Ratio:', sprintf('%.1fx', rawbytes / zipbytes));
        end
    end
else
    lines{end + 1} = infoline('Compression:', 'none');
end

chunks = getjkey(val, '_ArrayChunks_', []);
if (~isempty(chunks))
    lines{end + 1} = infoline('Chunks:', dimstring(tovec(chunks)));
end

meta.lines = lines;

% --------------------------------------------------------------------------
function nbytes = zipdatabytes(zipdata)
% payload size of _ArrayZipData_, which is base64 text in JSON and a raw
% byte array in binary JData

nbytes = [];
if (isempty(zipdata))
    return
end
if (iscell(zipdata))
    nbytes = sum(cellfun(@(x) numelbytes(x), zipdata));
else
    nbytes = numelbytes(zipdata);
end

% --------------------------------------------------------------------------
function nbytes = numelbytes(buf)

if (ischar(buf))
    nbytes = floor(length(buf) * 3 / 4);
elseif (isnumeric(buf))
    nbytes = numel(buf);
else
    nbytes = 0;
end

% --------------------------------------------------------------------------
function meta = objectmeta(val)

meta = emptymeta();
meta.kind = 'object';
meta.cansaveas = true;

if (isstruct(val) && numel(val) > 1)
    meta.lines = {infoline('Type:', sprintf('object array (%d elements)', numel(val))), ...
                  infoline('Keys:', joinstrs(cellfun(@decodevarname, fieldnames(val), 'UniformOutput', false)))};
    return
end

childkeys = nodekeys(val);
lines = {infoline('Type:', sprintf('object (%d keys)', length(childkeys)))};

% recognize the composite JData types the tree already icon-tags
if (hasjkey(val, 'NIFTIData'))
    lines{end + 1} = infoline('Content:', 'JNIfTI volume (NIFTIData)');
    meta.canpreview = true;
elseif (hasjkey(val, 'MeshVertex3') || hasjkey(val, 'MeshNode'))
    lines{end + 1} = infoline('Content:', 'JMesh surface/volume');
    meta.canpreview = true;
elseif (hasjkey(val, 'SNIRFData'))
    lines{end + 1} = infoline('Content:', 'SNIRF fNIRS recording');
end

previewkeys = childkeys;
if (length(previewkeys) > 12)
    previewkeys = previewkeys(1:12);
end
if (~isempty(previewkeys))
    labels = cellfun(@keylabel, previewkeys, 'UniformOutput', false);
    if (length(childkeys) > length(previewkeys))
        labels{end + 1} = '...';
    end
    lines{end + 1} = infoline('Keys:', joinstrs(labels));
end
meta.lines = lines;

% --------------------------------------------------------------------------
function lines = valuelines(val)

if (ischar(val))
    lines = {infoline('Type:', sprintf('string (%d characters)', length(val)))};
    if (length(val) > 400)
        lines{end + 1} = '';
        lines{end + 1} = [val(1:400) ' ...'];
    else
        lines{end + 1} = '';
        lines{end + 1} = val;
    end
elseif (isnumeric(val) || islogical(val))
    lines = {infoline('Type:', sprintf('%s array', class(val))), ...
             infoline('Size:', dimstring(size(val)))};
    if (~isempty(val) && isreal(val) && ~issparse(val))
        lines{end + 1} = infoline('Range:', sprintf('%g .. %g', min(double(val(:))), max(double(val(:)))));
    end
    if (numel(val) <= 20)
        lines{end + 1} = '';
        lines{end + 1} = mat2str(val, 6);
    end
elseif (iscell(val))
    lines = {infoline('Type:', sprintf('array (%d elements)', numel(val)))};
else
    lines = {infoline('Type:', class(val))};
end

% --------------------------------------------------------------------------
function str = infoline(label, value)

if (~ischar(value))
    value = scalarstr(value);
end
str = sprintf('%-14s %s', label, value);

% --------------------------------------------------------------------------
function str = scalarstr(val)

if (ischar(val))
    str = val;
elseif (isnumeric(val) || islogical(val))
    if (numel(val) <= 10)
        str = mat2str(val, 6);
    else
        str = sprintf('<%s %s>', dimstring(size(val)), class(val));
    end
elseif (iscell(val))
    str = joinstrs(val);
else
    str = ['<' class(val) '>'];
end

% --------------------------------------------------------------------------
function str = joinstrs(items)

if (ischar(items))
    str = items;
    return
end
if (~iscell(items))
    str = scalarstr(items);
    return
end
parts = cell(1, length(items));
for i = 1:length(items)
    if (ischar(items{i}))
        parts{i} = items{i};
    else
        parts{i} = scalarstr(items{i});
    end
end
str = strjoin(parts, ', ');

% --------------------------------------------------------------------------
function str = yesno(tf)

if (tf)
    str = 'yes';
else
    str = 'no';
end

% --------------------------------------------------------------------------
%  selection state
% --------------------------------------------------------------------------

function node = currentnode(hwin)
% describe the entry currently selected in the JSON tree; raw keys are kept
% in appdata so they never have to be recovered from the icon-prefixed
% display strings

node = struct('ok', false, 'key', '', 'label', '', 'value', [], ...
              'path', '', 'isparent', false, 'meta', emptymeta());

handles = get(hwin, 'userdata');
if (~isstruct(handles) || ~isfield(handles, 'lsJSON') || ~ishandle(handles.lsJSON))
    return
end
listkeys = getappdata(hwin, 'listkeys');
if (isempty(listkeys) || ~iscell(listkeys))
    return
end
idx = get(handles.lsJSON, 'value');
if (isempty(idx) || idx(1) < 1 || idx(1) > length(listkeys))
    return
end
key = listkeys{idx(1)};
if (ischar(key) && strcmp(key, '..'))
    node.isparent = true;
    return
end

pathstack = getappdata(hwin, 'pathstack');
if (~iscell(pathstack))
    pathstack = {};
end
node.key = key;
node.label = keylabel(key);
node.value = getnode(getappdata(hwin, 'rootdata'), [pathstack, {key}]);
node.path = pathstring([pathstack, {key}]);
node.meta = nodemeta(node.value);
node.ok = true;

% --------------------------------------------------------------------------
function name = selecteditem(hwin, hlist, appkey)
% raw (undecorated) name of the entry selected in the database/dataset list

name = '';
itemkeys = getappdata(hwin, appkey);
if (isempty(itemkeys) || ~iscell(itemkeys))
    return
end
idx = get(hlist, 'value');
if (isempty(idx) || idx(1) < 1 || idx(1) > length(itemkeys))
    return
end
name = itemkeys{idx(1)};

% --------------------------------------------------------------------------
function setlist(hwin, hlist, itemkeys, icontypes, appkey, annotations)
% fill a listbox with icon-decorated labels while keeping the raw keys

if (ischar(icontypes))
    icontypes = repmat({icontypes}, 1, length(itemkeys));
end
if (nargin < 6)
    annotations = repmat({''}, 1, length(itemkeys));
end
labels = cell(1, length(itemkeys));
for i = 1:length(itemkeys)
    labels{i} = create_row_string(icontypes{i}, keylabel(itemkeys{i}), annotations{i});
end
setappdata(hwin, appkey, itemkeys(:)');
set(hlist, 'string', labels, 'value', 1);

% --------------------------------------------------------------------------
function childnodes = listchildren(container)
% keys, icon types and short annotations of a container's children

keylist = nodekeys(container);
childnodes = struct('keys', {keylist}, 'icons', {cell(1, length(keylist))}, ...
                    'notes', {cell(1, length(keylist))});
for i = 1:length(keylist)
    try
        child = getnode(container, keylist(i));
        childnodes.icons{i} = detect_data_type(child);
        childnodes.notes{i} = nodeannotation(child);
    catch
        childnodes.icons{i} = 'data';
        childnodes.notes{i} = '';
    end
end

% --------------------------------------------------------------------------
function note = nodeannotation(val)
% short right-hand summary shown on a list row; deliberately cheap - it never
% decodes an array nor touches the cache

note = '';
if (isa(val, 'jdict'))
    val = val.v();
end
if (isstruct(val) && numel(val) == 1)
    if (hasjkey(val, '_DataLink_'))
        linkurl = getjkey(val, '_DataLink_', '');
        if (iscell(linkurl) && ~isempty(linkurl))
            linkurl = linkurl{1};
        end
        if (ischar(linkurl))
            if (~isempty(linkurl) && linkurl(1) == char(36))
                note = 'ref';
                return
            end
            tok = regexp(linkurl, '[&?]size=(\d+)', 'tokens', 'once');
            if (~isempty(tok))
                note = humansize(str2double(tok{1}));
            else
                note = 'link';
            end
        end
        return
    end
    if (hasjkey(val, '_ArrayType_') || hasjkey(val, '_ArraySize_'))
        arraysize = tovec(getjkey(val, '_ArraySize_', []));
        arraytype = getjkey(val, '_ArrayType_', '');
        if (~isempty(arraysize) && ischar(arraytype))
            note = sprintf('%s %s', dimstring(arraysize), arraytype);
        elseif (~isempty(arraysize))
            note = dimstring(arraysize);
        end
        return
    end
end
nchild = length(nodekeys(val));
if (nchild == 1)
    note = '1 item';
elseif (nchild > 1)
    note = sprintf('%d items', nchild);
elseif (ischar(val))
    note = sprintf('%d chars', length(val));
elseif ((isnumeric(val) || islogical(val)) && ~isempty(val))
    if (numel(val) == 1)
        note = scalarstr(val);
    else
        note = sprintf('%s %s', dimstring(size(val)), class(val));
    end
end

% --------------------------------------------------------------------------
function rendertree(hwin)
% list the children of the container at the current path stack

handles = get(hwin, 'userdata');
pathstack = getappdata(hwin, 'pathstack');
if (~iscell(pathstack))
    pathstack = {};
end
container = getnode(getappdata(hwin, 'rootdata'), pathstack);
kids = listchildren(container);
listkeys = kids.keys;
icontypes = kids.icons;
annotations = kids.notes;
if (~isempty(pathstack))
    listkeys = [{'..'}, listkeys];
    icontypes = [{'parent'}, icontypes];
    annotations = [{''}, annotations];
end
setlist(hwin, handles.lsJSON, listkeys, icontypes, 'listkeys', annotations);
shownodeinfo(hwin);

% --------------------------------------------------------------------------
function shownodeinfo(hwin)
% write the metadata of the selected node into the value pane and enable the
% toolbar actions that apply to it

handles = get(hwin, 'userdata');
node = currentnode(hwin);
if (node.ok)
    set(handles.txValue, 'string', [{infoline('Path:', node.path)}, node.meta.lines(:)']);
    setstatus(hwin, node.path);
elseif (node.isparent)
    set(handles.txValue, 'string', {infoline('Path:', pathstring(getappdata(hwin, 'pathstack'))), ...
                                    '', 'Open ".." to go back to the parent level.'});
end
showpeek(hwin, node);
updateactions(hwin);

% --------------------------------------------------------------------------
function showpeek(hwin, node)
% the 4th column previews the content of the highlighted node one level deep,
% without descending into it

handles = get(hwin, 'userdata');
if (~isfield(handles, 'lsPeek') || ~ishandle(handles.lsPeek))
    return
end
if (~node.ok)
    set(handles.lsPeek, 'string', {}, 'value', 1);
    setappdata(hwin, 'peekkeys', {});
    return
end
kids = listchildren(node.value);
if (isempty(kids.keys))
    set(handles.lsPeek, 'string', {}, 'value', 1);
    setappdata(hwin, 'peekkeys', {});
    return
end
setlist(hwin, handles.lsPeek, kids.keys, kids.icons, 'peekkeys', kids.notes);

% --------------------------------------------------------------------------
function peekselect(src, events, hwin)
% activating a peek row descends two levels at once: into the node highlighted
% in the JSON list, then onto the chosen child

handles = get(hwin, 'userdata');
activated = isactivated(handles, events);
if (activated)
    node = currentnode(hwin);
    peekkeys = getappdata(hwin, 'peekkeys');
    idx = get(handles.lsPeek, 'value');
    if (node.ok && ~isempty(peekkeys) && idx(1) >= 1 && idx(1) <= length(peekkeys))
        setbusy(hwin, true);
        try
            descendinto(hwin, node.key);
            selectkey(hwin, peekkeys{idx(1)});
        catch err
            setstatus(hwin, ['Cannot open this item: ' err.message]);
        end
        setbusy(hwin, false);
    end
end
handles.t0 = cputime;
set(hwin, 'userdata', handles);

% --------------------------------------------------------------------------
function descendinto(hwin, key)
% push one key onto the path stack and redraw the JSON list

pathstack = getappdata(hwin, 'pathstack');
if (~iscell(pathstack))
    pathstack = {};
end
setappdata(hwin, 'pathstack', [pathstack, {key}]);
rendertree(hwin);

% --------------------------------------------------------------------------
function selectkey(hwin, key)
% highlight a key in the JSON list and refresh the panes

handles = get(hwin, 'userdata');
listkeys = getappdata(hwin, 'listkeys');
if (isnumeric(key))
    pos = find(cellfun(@(x) isnumeric(x) && isequal(x, key), listkeys), 1);
else
    pos = find(cellfun(@(x) ischar(x) && strcmp(x, key), listkeys), 1);
end
if (~isempty(pos))
    set(handles.lsJSON, 'value', pos);
    shownodeinfo(hwin);
end

% --------------------------------------------------------------------------
function setstatus(hwin, msg)

handles = get(hwin, 'userdata');
if (isstruct(handles) && isfield(handles, 'txStatus') && ishandle(handles.txStatus))
    set(handles.txStatus, 'string', msg);
end

% --------------------------------------------------------------------------
function updateactions(hwin)

handles = get(hwin, 'userdata');
if (~isstruct(handles) || ~isfield(handles, 'btDownload'))
    return
end
node = currentnode(hwin);
hasdoc = node.ok || ~isempty(getappdata(hwin, 'rootdata'));
setenable(handles.btDownload, node.ok && node.meta.candownload);
setenable(handles.btPreview, node.ok && node.meta.canpreview);
setenable(handles.btSaveAs, node.ok && node.meta.cansaveas);
setenable(handles.btSubtree, hasdoc);
setenable(handles.btAttach, hasdoc);

if (isfield(handles, 'miDownload'))
    setenable(handles.miDownload, node.ok && node.meta.candownload);
    setenable(handles.miPreview, node.ok && node.meta.canpreview);
    setenable(handles.miSaveAs, node.ok && node.meta.cansaveas);
    setenable(handles.miSubtree, hasdoc);
    setenable(handles.miAttach, hasdoc);
end

% --------------------------------------------------------------------------
%  toolbar actions on the selected value
% --------------------------------------------------------------------------

function handles = buildmenus(handles)
% menu bar plus a context menu on the two data lists; every entry calls the
% same local action as the matching toolbar button

hwin = handles.fmMain;

mfile = uimenu(hwin, 'label', '&File');
uimenu(mfile, 'label', 'Save selected data as...', 'callback', @(src, ev) actsaveas(hwin));
uimenu(mfile, 'label', 'Export subtree (metadata only)...', 'callback', @(src, ev) actexportsubtree(hwin));
uimenu(mfile, 'label', 'Export dataset to a folder...', 'callback', @(src, ev) exportdataset(hwin));
uimenu(mfile, 'label', 'Download linked file', 'separator', 'on', 'callback', @(src, ev) actdownload(hwin));
uimenu(mfile, 'label', 'Download all linked files below selection...', 'callback', @(src, ev) actdownloadattachments(hwin));
uimenu(mfile, 'label', 'Close', 'separator', 'on', 'callback', @(src, ev) close(hwin));

mview = uimenu(hwin, 'label', '&View');
uimenu(mview, 'label', 'Refresh database list', 'callback', @(src, ev) loaddb([], [], hwin));
uimenu(mview, 'label', 'Toggle search panel', 'callback', @(src, ev) togglesearch(hwin));
uimenu(mview, 'label', 'Preview selected data', 'separator', 'on', 'callback', @(src, ev) actpreview(hwin));
uimenu(mview, 'label', 'Reset pane sizes', 'separator', 'on', 'callback', @(src, ev) resetlayout(hwin));

mhelp = uimenu(hwin, 'label', '&Help');
uimenu(mhelp, 'label', 'Open neurojson.org', 'callback', @(src, ev) web('https://neurojson.org', '-browser'));
uimenu(mhelp, 'label', 'About', 'callback', @(src, ev) msgbox(['NeuroJSON.io Dataset Browser' char(10) ...
                                                               'part of JSONLab - http://neurojson.org/jsonlab'], 'About'));

cmenu = uicontextmenu(hwin);
handles.miDownload = uimenu(cmenu, 'label', 'Download linked file', 'callback', @(src, ev) actdownload(hwin));
handles.miPreview = uimenu(cmenu, 'label', 'Preview', 'callback', @(src, ev) actpreview(hwin));
handles.miSaveAs = uimenu(cmenu, 'label', 'Save as...', 'callback', @(src, ev) actsaveas(hwin));
handles.miSubtree = uimenu(cmenu, 'label', 'Export subtree (metadata only)...', 'separator', 'on', 'callback', @(src, ev) actexportsubtree(hwin));
handles.miAttach = uimenu(cmenu, 'label', 'Download all linked files below...', 'callback', @(src, ev) actdownloadattachments(hwin));
set([handles.lsJSON, handles.lsPeek], 'uicontextmenu', cmenu);

% --------------------------------------------------------------------------
function resetlayout(hwin)

handles = get(hwin, 'userdata');
handles.layout = defaultlayout();
set(hwin, 'userdata', handles);
layoutgui(handles);

% --------------------------------------------------------------------------
function navkeypress(src, events, hwin)
% keyboard navigation shared by all four lists; up/down stay native

key = '';
try
    key = lower(events.Key);
catch
end
if (isempty(key) || ~ischar(key))
    return
end

handles = get(hwin, 'userdata');
handles.t0 = cputime;
set(hwin, 'userdata', handles);

if (strcmp(key, 'return') || strcmp(key, 'rightarrow'))
    activation = struct('Key', 'return');
    if (src == handles.lsJSON)
        expandjsontree(src, activation, hwin);
    elseif (src == handles.lsPeek)
        peekselect(src, activation, hwin);
    elseif (src == handles.lsDb)
        loadds(src, activation, hwin);
    elseif (src == handles.lsDs)
        loaddsdata(src, activation, hwin);
    end
elseif (strcmp(key, 'backspace') || strcmp(key, 'leftarrow'))
    pathstack = getappdata(hwin, 'pathstack');
    if (iscell(pathstack) && ~isempty(pathstack))
        setappdata(hwin, 'pathstack', pathstack(1:end - 1));
        rendertree(hwin);
    end
elseif (strcmp(key, 'f5'))
    loaddb([], [], hwin);
end

% --------------------------------------------------------------------------
function data = resolvenode(node)
% turn the raw (undecoded) node value into usable MATLAB data: follow a
% _DataLink_ to its cached file, or decode a JData construct on demand

data = node.value;
if (isa(data, 'jdict'))
    data = data.v();
end
if (strcmp(node.meta.kind, 'datalink'))
    if (isempty(node.meta.url))
        error('this _DataLink_ node carries no URL');
    end
    data = jdlink(node.meta.url);
    if (iscell(data) && numel(data) == 1)
        data = data{1};
    end
    return
end
if (isstruct(data) || iscell(data) || isa(data, 'containers.Map'))
    data = decodejdata(data);
end

% --------------------------------------------------------------------------
function data = decodejdata(data)
% _ArrayZipData_ payloads are base64 text when the document was parsed from
% JSON and raw bytes when it came from binary JData; jdatadecode has to be
% told which of the two it is looking at

if (zipdatastate(data) == 0)
    data = jdatadecode(data);
else
    data = jdatadecode(data, 'Base64', 1);
end

% --------------------------------------------------------------------------
function state = zipdatastate(data)
% 1: the first _ArrayZipData_ found is base64 text, 0: it is a byte array,
% -1: none found within the searched depth

zipdata = firstjkey(data, '_ArrayZipData_');
if (isempty(zipdata))
    state = -1;
else
    state = double(ischar(zipdata));
end

% --------------------------------------------------------------------------
function val = firstjkey(data, name, depth)
% value of the first occurrence of a JData keyword anywhere in a subtree,
% searched breadth-first up to a bounded depth so large trees stay cheap

if (nargin < 3)
    depth = 8;
end
val = [];
if (depth <= 0)
    return
end
if (iscell(data))
    for i = 1:numel(data)
        val = firstjkey(data{i}, name, depth - 1);
        if (~isempty(val))
            return
        end
    end
    return
end
if (isa(data, 'containers.Map'))
    mapkeys = keys(data);
    for i = 1:length(mapkeys)
        val = firstjkey(data(mapkeys{i}), name, depth - 1);
        if (~isempty(val))
            return
        end
    end
    return
end
if (~isstruct(data) || isempty(data))
    return
end
val = getjkey(data(1), name, []);
if (iscell(val) && ~isempty(val))
    val = val{1};
end
if (~isempty(val))
    return
end
childkeys = fieldnames(data(1));
for i = 1:length(childkeys)
    val = firstjkey(data(1).(childkeys{i}), name, depth - 1);
    if (~isempty(val))
        return
    end
end

% --------------------------------------------------------------------------
function actdownload(hwin)

node = currentnode(hwin);
if (~node.ok || ~node.meta.candownload)
    return
end

setbusy(hwin, true);
cachedfile = '';
try
    [~, cachedfile] = jdlink(node.meta.url);
    if (iscell(cachedfile) && ~isempty(cachedfile))
        cachedfile = cachedfile{1};
    end
catch err
    setbusy(hwin, false);
    errordlg(['Download failed: ' err.message], 'Download');
    return
end
setbusy(hwin, false);

shownodeinfo(hwin);
if (~isempty(cachedfile) && ischar(cachedfile))
    msgbox(['Downloaded to:' char(10) cachedfile], 'Download complete');
end

% --------------------------------------------------------------------------
function actpreview(hwin)

node = currentnode(hwin);
if (~node.ok || ~node.meta.canpreview)
    return
end

setbusy(hwin, true);
try
    data = resolvenode(node);
catch err
    setbusy(hwin, false);
    errordlg(['Cannot decode the selected data: ' err.message], 'Preview');
    return
end
setbusy(hwin, false);
try
    previewdata(data, node.label);
catch err
    errordlg(['Preview failed: ' err.message], 'Preview');
end

% --------------------------------------------------------------------------
function actsaveas(hwin)

node = currentnode(hwin);
if (~node.ok || ~node.meta.cansaveas)
    return
end

filters = {'*.json', 'JSON/JData file (*.json)'; ...
           '*.jdb', 'Binary JData file (*.jdb)'; ...
           '*.jnii', 'JNIfTI file (*.jnii)'; ...
           '*.mat', 'MATLAB/Octave data file (*.mat)'};
if (strcmp(node.meta.kind, 'datalink'))
    [~, linkname, linkext] = fileparts(node.meta.cachefile);
    defaultfile = [linkname linkext];
    filters = [{'*.*', 'Original downloaded file (*.*)'}; filters];
else
    defaultfile = [safename(node.label) '.json'];
end

[fname, fpath] = uiputfile(filters, 'Save the selected data as', defaultfile);
if (isequal(fname, 0) || isequal(fpath, 0))
    return
end
target = fullfile(fpath, fname);

setbusy(hwin, true);
try
    if (strcmp(node.meta.kind, 'datalink') && ~isempty(node.meta.cachefile))
        copyfile(node.meta.cachefile, target);
    else
        savevalue(resolvenode(node), target);
    end
catch err
    setbusy(hwin, false);
    errordlg(['Save failed: ' err.message], 'Save as');
    return
end
setbusy(hwin, false);
msgbox(['Saved to:' char(10) target], 'Save as');

% --------------------------------------------------------------------------
function links = subtreelinks(data)
% every external _DataLink_ URL below a subtree, internal $... references
% dropped; jsonpath does the recursive descent

links = {};
if (isempty(data))
    return
end
try
    found = jsonpath(data, [char(36) '.._DataLink_']);
catch
    found = {};
end
if (ischar(found))
    found = {found};
end
if (~iscell(found))
    return
end
for i = 1:numel(found)
    url = found{i};
    if (iscell(url) && ~isempty(url))
        url = url{1};
    end
    if (ischar(url) && ~isempty(url) && url(1) ~= char(36))
        links{end + 1} = url;
    end
end

% --------------------------------------------------------------------------
function nbytes = linkbytes(links)
% total advertised size of a set of links, read from the &size= parameter

nbytes = 0;
for i = 1:length(links)
    tok = regexp(links{i}, '[&?]size=(\d+)', 'tokens', 'once');
    if (~isempty(tok))
        nbytes = nbytes + str2double(tok{1});
    end
end

% --------------------------------------------------------------------------
function [data, label] = selectedsubtree(hwin)
% the selected node, or the whole loaded document when nothing is selected

node = currentnode(hwin);
if (node.ok)
    data = node.value;
    label = node.label;
else
    data = getappdata(hwin, 'rootdata');
    label = getappdata(hwin, 'dsname');
end

% --------------------------------------------------------------------------
function actdownloadattachments(hwin)
% explicit, opt-in bulk download of every file linked below the selection;
% nothing here is ever triggered by exporting a subtree

[data, label] = selectedsubtree(hwin);
if (isempty(data))
    msgbox('Please select a dataset or a subkey first', 'Download linked files', 'warn');
    return
end

setbusy(hwin, true);
links = subtreelinks(data);
setbusy(hwin, false);
if (isempty(links))
    msgbox(sprintf('No externally linked files were found below "%s".', label), 'Download linked files');
    return
end

% optional filter, applied the same way jdlink's 'regex' option does
answer = inputdlg({sprintf(['%d linked files found below "%s".' char(10) char(10) ...
                            'Only download those matching this pattern:'], length(links), label)}, ...
                  'Filter linked files', 1, {'.*'});
if (isempty(answer))
    return
end
pattern = strtrim(answer{1});
if (~isempty(pattern) && ~strcmp(pattern, '.*'))
    keep = ~cellfun(@(x) isempty(regexp(x, pattern, 'once')), links);
    links = links(keep);
    if (isempty(links))
        msgbox('No linked file matches that pattern.', 'Download linked files', 'warn');
        return
    end
end

ncached = 0;
for i = 1:length(links)
    [cachepath, ~] = linkcachefile(links{i});
    if (~isempty(cachepath))
        ncached = ncached + 1;
    end
end

prompt = sprintf(['Download %d linked files (%s in total)?' char(10) ...
                  '%d of them are already in the local cache and will be skipped by jdlink.'], ...
                 length(links), humansize(linkbytes(links)), ncached);
if (~strcmp(questdlg(prompt, 'Download linked files', 'Download', 'Cancel', 'Download'), 'Download'))
    return
end

downloadlinks(hwin, links);

% --------------------------------------------------------------------------
function downloadlinks(hwin, links)
% fetch a list of URLs one at a time so the waitbar can advance per file

nlinks = length(links);
donebytes = 0;
failed = {};
hbar = waitbar(0, 'Starting...', 'name', 'Downloading linked files');

for i = 1:nlinks
    [~, shortname] = fileparts(links{i});
    if (~ishandle(hbar))
        setstatus(hwin, sprintf('Download stopped after %d of %d files.', i - 1, nlinks));
        return
    end
    waitbar((i - 1) / nlinks, hbar, sprintf('File %d of %d (%s so far)%s%s', ...
                                            i, nlinks, humansize(donebytes), char(10), shortname));
    try
        [~, cachedfile] = jdlink(links{i}, 'showlink', 0, 'showsize', 0);
        if (iscell(cachedfile) && ~isempty(cachedfile))
            cachedfile = cachedfile{1};
        end
        if (ischar(cachedfile) && exist(cachedfile, 'file'))
            finfo = dir(cachedfile);
            donebytes = donebytes + finfo(1).bytes;
        end
    catch err
        failed{end + 1} = sprintf('%s: %s', shortname, err.message);
    end
end

if (ishandle(hbar))
    close(hbar);
end

summary = sprintf('Downloaded %d of %d linked files (%s).', nlinks - length(failed), nlinks, humansize(donebytes));
setstatus(hwin, summary);
shownodeinfo(hwin);
if (isempty(failed))
    msgbox(summary, 'Download linked files');
else
    msgbox([summary char(10) char(10) 'Failed:' char(10) strjoin(failed, char(10))], ...
           'Download linked files', 'warn');
end

% --------------------------------------------------------------------------
function actexportsubtree(hwin)
% export the selected subtree - or the whole dataset when nothing inside it
% is selected - to a JSON or binary JData file

handles = get(hwin, 'userdata');
node = currentnode(hwin);
if (node.ok)
    data = node.value;
    defaultname = safename(node.label);
else
    data = getappdata(hwin, 'rootdata');
    defaultname = safename(getappdata(hwin, 'dsname'));
end
if (isempty(data))
    msgbox('Please select a dataset or a subkey first', 'Export subtree', 'warn');
    return
end

filters = {'*.json', 'JSON/JData file (*.json)'; ...
           '*.jdb', 'Binary JData file (*.jdb)'; ...
           '*.jbids', 'JBIDS file (*.jbids)'; ...
           '*.ubj', 'UBJSON file (*.ubj)'};
nlinks = length(subtreelinks(data));
[fname, fpath] = uiputfile(filters, 'Export the selected subtree (metadata only)', [defaultname '.json']);
if (isequal(fname, 0) || isequal(fpath, 0))
    return
end
target = fullfile(fpath, fname);

setbusy(hwin, true);
try
    writesubtree(data, target);
catch err
    setbusy(hwin, false);
    errordlg(['Export failed: ' err.message], 'Export subtree');
    return
end
setbusy(hwin, false);

summary = ['Subtree exported to: ' target];
if (nlinks > 0)
    summary = sprintf('%s (metadata only; %d _DataLink_ references kept, not followed)', summary, nlinks);
else
    summary = [summary ' (metadata only)'];
end
setstatus(hwin, summary);
msgbox(regexprep(summary, ' \(', [char(10) '('], 'once'), 'Export subtree');

% --------------------------------------------------------------------------
function writesubtree(data, target)
% write a raw subtree to a container file; the JData constructs are decoded
% and re-encoded so that the output is valid in the target format - a base64
% _ArrayZipData_ string read from JSON cannot be written into binary JData -
% while the original compression method is preserved

ziptype = firstjkey(data, '_ArrayZipType_');
if (ischar(ziptype) && ~isempty(ziptype))
    savejd('', decodejdata(data), 'filename', target, 'compression', ziptype);
else
    savejd('', decodejdata(data), target);
end

% --------------------------------------------------------------------------
function savevalue(data, target)

if (~isempty(regexpi(target, '\.mat$', 'once')))
    neurojdata = data;
    save(target, 'neurojdata', '-mat');
elseif (~isempty(regexpi(target, '\.(json|jnii|jdt|jdat|jmsh|jnirs|jbids|bjd|bnii|jdb|jbat|bmsh|bnirs|pmat|ubj|yaml|msgpack|h5|hdf5|snirf)$', 'once')))
    savejd('', data, target);
elseif (ischar(data) || isa(data, 'uint8'))
    fid = fopen(target, 'wb');
    if (fid < 0)
        error('cannot write to %s', target);
    end
    fwrite(fid, data);
    fclose(fid);
else
    savejson('', data, 'filename', target);
end

% --------------------------------------------------------------------------
%  preview rendering
% --------------------------------------------------------------------------

function previewdata(data, label)

if (iscell(data) && numel(data) == 1)
    data = data{1};
end

niidata = getjkey(data, 'NIFTIData', []);
if (~isempty(niidata))
    previewarray(niidata, [label ' (NIFTIData)']);
    return
end

meshnode = getjkey(data, 'MeshVertex3', getjkey(data, 'MeshNode', []));
if (~isempty(meshnode))
    meshelem = [];
    elemkeys = {'MeshTri3', 'MeshSurf', 'MeshTet4', 'MeshElem'};
    for i = 1:length(elemkeys)
        meshelem = getjkey(data, elemkeys{i}, []);
        if (~isempty(meshelem))
            break
        end
    end
    previewmesh(meshnode, meshelem, label);
    return
end

if ((isnumeric(data) || islogical(data)) && numel(data) > 1)
    previewarray(data, label);
    return
end

previewtext(data, label);

% --------------------------------------------------------------------------
function previewarray(data, label)

if (issparse(data))
    data = full(data);
end
if (~isreal(data))
    data = abs(data);
    label = [label ' (magnitude)'];
end
if (islogical(data) || ~isa(data, 'double'))
    data = double(data);
end
if (numel(data) <= 1)
    previewtext(data, label);
    return
end

dims = size(data);
titlestr = sprintf('%s  [%s]', label, dimstring(dims));
fh = figure('numbertitle', 'off', 'name', ['Preview: ' label]);

if (sum(dims > 1) <= 1)
    plot(data(:));
    xlabel('index');
    grid('on');
    title(titlestr, 'interpreter', 'none');
elseif (length(dims) == 2)
    imagesc(data);
    axis('image');
    colorbar();
    xlabel(sprintf('dim 2 (%d)', dims(2)));
    ylabel(sprintf('dim 1 (%d)', dims(1)));
    title(titlestr, 'interpreter', 'none');
else
    data = reshape(data, dims(1), dims(2), []);
    nslice = size(data, 3);
    if (nslice < 2)
        imagesc(data(:, :, 1));
        axis('image');
        colorbar();
        title(titlestr, 'interpreter', 'none');
        return
    end
    setappdata(fh, 'volume', data);
    setappdata(fh, 'title', titlestr);
    ax = axes('parent', fh, 'units', 'normalized', 'position', [0.13 0.20 0.70 0.70]);
    txt = uicontrol(fh, 'style', 'text', 'units', 'normalized', 'position', [0.86 0.04 0.13 0.05]);
    slider = uicontrol(fh, 'style', 'slider', 'units', 'normalized', ...
                       'position', [0.13 0.04 0.70 0.05], ...
                       'min', 1, 'max', nslice, 'value', round(nslice / 2), ...
                       'sliderstep', [1, 10] / max(1, nslice - 1));
    set(slider, 'Callback', @(src, events) showslice(fh, ax, txt, round(get(src, 'value'))));
    showslice(fh, ax, txt, round(nslice / 2));
end

% --------------------------------------------------------------------------
function showslice(fh, ax, txt, idx)

vol = getappdata(fh, 'volume');
nslice = size(vol, 3);
idx = max(1, min(nslice, idx));
axes(ax);
imagesc(vol(:, :, idx));
axis('image');
title(sprintf('%s  slice %d/%d', getappdata(fh, 'title'), idx, nslice), 'interpreter', 'none');
set(txt, 'string', sprintf('%d/%d', idx, nslice));

% --------------------------------------------------------------------------
function previewmesh(meshnode, meshelem, label)

figure('numbertitle', 'off', 'name', ['Preview: ' label]);
if (~isempty(meshelem) && exist('plotmesh', 'file'))
    plotmesh(meshnode, meshelem);
elseif (~isempty(meshelem) && size(meshelem, 2) >= 3 && size(meshnode, 2) >= 3)
    patch('Faces', meshelem(:, 1:3), 'Vertices', meshnode(:, 1:3), ...
          'FaceColor', [0.7 0.75 0.85], 'EdgeColor', [0.2 0.2 0.2]);
    view(3);
    axis('equal');
elseif (size(meshnode, 2) >= 3)
    plot3(meshnode(:, 1), meshnode(:, 2), meshnode(:, 3), '.');
    axis('equal');
else
    plot(meshnode(:, 1), meshnode(:, 2), '.');
    axis('equal');
end
title(sprintf('%s  (%d nodes)', label, size(meshnode, 1)), 'interpreter', 'none');

% --------------------------------------------------------------------------
function previewtext(data, label)

if (ischar(data))
    str = data;
else
    try
        str = savejson('', data);
    catch
        str = scalarstr(data);
    end
end
fh = figure('numbertitle', 'off', 'name', ['Preview: ' label]);
uicontrol(fh, 'style', 'edit', 'max', 50, 'HorizontalAlignment', 'left', ...
          'units', 'normalized', 'position', [0 0 1 1], 'string', str);

% --------------------------------------------------------------------------
%  toolbar icons
% --------------------------------------------------------------------------

function icon_cdata = create_refresh_icon()

icon_cdata = ones(16, 16, 3) * 0.94;
blue = reshape([0.2 0.5 0.9], 1, 1, 3);
icon_cdata(4:5, 8:13, :) = repmat(blue, 2, 6, 1);
icon_cdata(6:7, 12:13, :) = repmat(blue, 2, 2, 1);
icon_cdata(8:9, 12:13, :) = repmat(blue, 2, 2, 1);
icon_cdata(10:11, 11:12, :) = repmat(blue, 2, 2, 1);
icon_cdata(12:13, 8:10, :) = repmat(blue, 2, 3, 1);
icon_cdata(12:13, 6:7, :) = repmat(blue, 2, 2, 1);
icon_cdata(10:11, 4:5, :) = repmat(blue, 2, 2, 1);
icon_cdata(8:9, 3:4, :) = repmat(blue, 2, 2, 1);
icon_cdata(3:4, 13:14, :) = repmat(blue, 2, 2, 1);
icon_cdata(5:6, 12:13, :) = repmat(blue, 2, 2, 1);
icon_cdata(5:6, 14:15, :) = repmat(blue, 2, 2, 1);

% --------------------------------------------------------------------------
function icon_cdata = create_search_icon()

icon_cdata = ones(16, 16, 3) * 0.94;
green = reshape([0.1 0.7 0.2], 1, 1, 3);
icon_cdata(4:5, 5:10, :) = repmat(green, 2, 6, 1);
icon_cdata(6:7, 4:5, :) = repmat(green, 2, 2, 1);
icon_cdata(6:7, 10:11, :) = repmat(green, 2, 2, 1);
icon_cdata(8:9, 4:5, :) = repmat(green, 2, 2, 1);
icon_cdata(8:9, 10:11, :) = repmat(green, 2, 2, 1);
icon_cdata(10:11, 5:10, :) = repmat(green, 2, 6, 1);
icon_cdata(11:13, 11:12, :) = repmat(green, 3, 2, 1);
icon_cdata(12:14, 12:13, :) = repmat(green, 3, 2, 1);

% --------------------------------------------------------------------------
function icon_cdata = create_export_icon()

icon_cdata = ones(16, 16, 3) * 0.94;
orange = reshape([0.9 0.5 0.1], 1, 1, 3);
icon_cdata(3:9, 7:9, :) = repmat(orange, 7, 3, 1);
icon_cdata(10:11, 5:11, :) = repmat(orange, 2, 7, 1);
icon_cdata(12:13, 6:10, :) = repmat(orange, 2, 5, 1);
icon_cdata(14, 7:9, :) = repmat(orange, 1, 3, 1);
icon_cdata(13:14, 3:13, :) = repmat(orange, 2, 11, 1);

% --------------------------------------------------------------------------
function icon_cdata = create_download_icon()
% a downward arrow landing on a tray - fetch the file behind a _DataLink_

icon_cdata = ones(16, 16, 3) * 0.94;
teal = reshape([0.0 0.55 0.6], 1, 1, 3);
icon_cdata(2:7, 7:10, :) = repmat(teal, 6, 4, 1);
icon_cdata(8, 5:12, :) = repmat(teal, 1, 8, 1);
icon_cdata(9, 6:11, :) = repmat(teal, 1, 6, 1);
icon_cdata(10, 7:10, :) = repmat(teal, 1, 4, 1);
icon_cdata(13:14, 3:13, :) = repmat(teal, 2, 11, 1);
icon_cdata(11:14, 3:4, :) = repmat(teal, 4, 2, 1);
icon_cdata(11:14, 12:13, :) = repmat(teal, 4, 2, 1);

% --------------------------------------------------------------------------
function icon_cdata = create_preview_icon()
% a small bar chart - render the selected array

icon_cdata = ones(16, 16, 3) * 0.94;
purple = reshape([0.45 0.25 0.7], 1, 1, 3);
icon_cdata(3:13, 3:4, :) = repmat(purple, 11, 2, 1);
icon_cdata(12:13, 3:14, :) = repmat(purple, 2, 12, 1);
icon_cdata(8:11, 6:7, :) = repmat(purple, 4, 2, 1);
icon_cdata(5:11, 9:10, :) = repmat(purple, 7, 2, 1);
icon_cdata(9:11, 12:13, :) = repmat(purple, 3, 2, 1);

% --------------------------------------------------------------------------
function icon_cdata = create_saveas_icon()
% a floppy/disk outline - write the decoded value to a local file

icon_cdata = ones(16, 16, 3) * 0.94;
navy = reshape([0.15 0.3 0.55], 1, 1, 3);
icon_cdata(3:4, 3:13, :) = repmat(navy, 2, 11, 1);
icon_cdata(3:13, 3:4, :) = repmat(navy, 11, 2, 1);
icon_cdata(3:13, 12:13, :) = repmat(navy, 11, 2, 1);
icon_cdata(12:13, 3:13, :) = repmat(navy, 2, 11, 1);
icon_cdata(3:7, 6:10, :) = repmat(navy, 5, 5, 1);
icon_cdata(9:12, 6:10, :) = repmat(navy, 4, 5, 1);

% --------------------------------------------------------------------------
function icon_cdata = create_subtree_icon()
% a branching tree with an outgoing arrow - export the selected subtree

icon_cdata = ones(16, 16, 3) * 0.94;
brown = reshape([0.6 0.35 0.1], 1, 1, 3);
icon_cdata(3:12, 4:5, :) = repmat(brown, 10, 2, 1);
icon_cdata(3:4, 4:8, :) = repmat(brown, 2, 5, 1);
icon_cdata(7:8, 4:8, :) = repmat(brown, 2, 5, 1);
icon_cdata(11:12, 4:8, :) = repmat(brown, 2, 5, 1);
icon_cdata(7:8, 10:14, :) = repmat(brown, 2, 5, 1);
icon_cdata(5:6, 12:13, :) = repmat(brown, 2, 2, 1);
icon_cdata(9:10, 12:13, :) = repmat(brown, 2, 2, 1);

% --------------------------------------------------------------------------
function icon_cdata = create_attach_icon()
% a stack of sheets with a down arrow - bulk fetch of the linked files

icon_cdata = ones(16, 16, 3) * 0.94;
slate = reshape([0.25 0.45 0.35], 1, 1, 3);
icon_cdata(2:3, 3:9, :) = repmat(slate, 2, 7, 1);
icon_cdata(4:10, 3:4, :) = repmat(slate, 7, 2, 1);
icon_cdata(9:10, 3:9, :) = repmat(slate, 2, 7, 1);
icon_cdata(2:10, 8:9, :) = repmat(slate, 9, 2, 1);
icon_cdata(6:11, 12:13, :) = repmat(slate, 6, 2, 1);
icon_cdata(12, 11:14, :) = repmat(slate, 1, 4, 1);
icon_cdata(13, 12:13, :) = repmat(slate, 1, 2, 1);

% --------------------------------------------------------------------------
function icontype = detect_data_type(dataobj)
% pick the list icon for a node from the JData keywords it carries

icontype = 'data';
if (isa(dataobj, 'jdict'))
    dataobj = dataobj.v();
end
if (~isstruct(dataobj) && ~isa(dataobj, 'containers.Map'))
    if (iscell(dataobj))
        icontype = 'folder';
    end
    return
end
try
    if (hasjkey(dataobj, '_DataLink_'))
        icontype = 'link';
    elseif (hasjkey(dataobj, '_ArrayType_') || hasjkey(dataobj, '_ArraySize_'))
        icontype = 'jdata';
    elseif (hasjkey(dataobj, '_MeshNode_') || hasjkey(dataobj, 'MeshNode') || hasjkey(dataobj, 'MeshVertex3'))
        icontype = 'mesh';
    elseif (hasjkey(dataobj, 'NIFTIData') || hasjkey(dataobj, 'NIFTIHeader'))
        icontype = 'nifti';
    elseif (hasjkey(dataobj, 'SNIRFData') || hasjkey(dataobj, 'nirs'))
        icontype = 'snirf';
    else
        icontype = 'folder';
    end
catch
    icontype = 'data';
end

% --------------------------------------------------------------------------
function display_string = create_row_string(icontype, text, annotation)
% one list row: icon, label padded to a fixed column, then a right-hand note.
% relies on the lists using a fixed-width font (set in the gui constructor)

display_string = create_icon_string(icontype, text);
if (nargin < 3 || isempty(annotation))
    return
end
labelwidth = 38;
if (length(display_string) < labelwidth)
    display_string = [display_string repmat(' ', 1, labelwidth - length(display_string))];
else
    display_string = [display_string '  '];
end
display_string = [display_string annotation];

% --------------------------------------------------------------------------
function display_string = create_icon_string(icontype, text)

ascii_icons = struct();
ascii_icons.database = '[DB]';
ascii_icons.folder = '[+]';
ascii_icons.jdata = '[J]';
ascii_icons.mesh = '[M]';
ascii_icons.nifti = '[N]';
ascii_icons.snirf = '[S]';
ascii_icons.data = '[-]';
ascii_icons.parent = '[..]';
ascii_icons.link = '[->]';
if (isfield(ascii_icons, icontype))
    display_string = [ascii_icons.(icontype) ' ' text];
else
    display_string = [ascii_icons.data ' ' text];
end

% --------------------------------------------------------------------------
%  browser callbacks
% --------------------------------------------------------------------------

function exportdataset(hwin)

handles = get(hwin, 'userdata');
dbname = selecteditem(hwin, handles.lsDb, 'dbkeys');
if (isempty(dbname))
    msgbox('Please select a database first', 'Export', 'warn');
    return
end
dsname = selecteditem(hwin, handles.lsDs, 'dskeys');
if (isempty(dsname))
    msgbox('Please select a dataset first', 'Export', 'warn');
    return
end

setbusy(hwin, true);
try
    res = neuroj('export', dbname, dsname);
catch err
    setbusy(hwin, false);
    msgbox(['Export failed: ' err.message], 'Export Error', 'error');
    return
end
setbusy(hwin, false);

if (~isempty(res) && isfield(res, 'exportpath'))
    setstatus(hwin, ['Dataset exported to: ' res.exportpath]);
    msgbox(['Dataset exported successfully to:' char(10) res.exportpath], 'Export Complete');
end

% --------------------------------------------------------------------------
function loaddb(src, event, hwin)

handles = get(hwin, 'userdata');
setbusy(hwin, true);
try
    dbs = neuroj('list');
    dbids = cellfun(@(x) x.id, dbs.database, 'UniformOutput', false);
    setlist(hwin, handles.lsDb, dbids, 'database', 'dbkeys');
    % offer the same databases in the search panel instead of a stale hard-coded list
    set(handles.hDatabase, 'string', [{'any'}, dbids(:)'], 'value', 1);
catch err
    setbusy(hwin, false);
    setstatus(hwin, ['Cannot list databases: ' err.message]);
    return
end
setbusy(hwin, false);

% --------------------------------------------------------------------------
function togglesearch(hwin)

handles = get(hwin, 'userdata');
layoutgui(handles, strcmp(get(handles.pnSearch, 'visible'), 'off'));

% --------------------------------------------------------------------------
function clearsearch(hwin)

handles = get(hwin, 'userdata');
editfields = {'hKeyword', 'hDataset', 'hTypeName', 'hAgeMin', 'hAgeMax', ...
              'hSessMin', 'hSessMax', 'hTaskMin', 'hTaskMax', 'hRunMin', 'hRunMax', ...
              'hTaskName', 'hSessionName', 'hRunName'};
for i = 1:length(editfields)
    set(handles.(editfields{i}), 'string', '');
end
set(handles.hDatabase, 'value', 1);
set(handles.hGender, 'value', 1);
set(handles.hModality, 'value', 1);
set(handles.hLimit, 'string', '25');
set(handles.hSkip, 'string', '0');

% --------------------------------------------------------------------------
function dosearch(hwin)

handles = get(hwin, 'userdata');
baseurl = 'https://neurojson.org/io/search.cgi';
param = {};

% simple 'field -> query parameter' pairs read from edit boxes
textfields = {'hKeyword', 'keyword'; 'hDataset', 'dsname'; ...
              'hTypeName', 'type'; 'hSessMin', 'sessmin'; 'hSessMax', 'sessmax'; ...
              'hTaskMin', 'taskmin'; 'hTaskMax', 'taskmax'; 'hRunMin', 'runmin'; ...
              'hRunMax', 'runmax'; 'hTaskName', 'task'; 'hSessionName', 'session'; ...
              'hRunName', 'run'};
for i = 1:size(textfields, 1)
    fieldvalue = strtrim(get(handles.(textfields{i, 1}), 'string'));
    if (~isempty(fieldvalue))
        param = [param, textfields{i, 2}, fieldvalue];
    end
end

% ages are sent as fixed-width hundredths of a year so they sort as strings
agefields = {'hAgeMin', 'agemin'; 'hAgeMax', 'agemax'};
for i = 1:size(agefields, 1)
    fieldvalue = strtrim(get(handles.(agefields{i, 1}), 'string'));
    if (~isempty(fieldvalue) && ~isnan(str2double(fieldvalue)))
        param = [param, agefields{i, 2}, sprintf('%05d', floor(str2double(fieldvalue) * 100))];
    end
end

database = popupvalue(handles.hDatabase);
if (~isempty(database))
    param = [param, 'dbname', database];
end
gender = popupvalue(handles.hGender);
if (~isempty(gender))
    param = [param, 'gender', gender(1)];
end
modality = modalitycode(popupvalue(handles.hModality));
if (~isempty(modality))
    param = [param, 'modality', modality];
end

param = [param, 'limit', strtrim(get(handles.hLimit, 'string')), ...
         'skip', strtrim(get(handles.hSkip, 'string'))];
setbusy(hwin, true);
try
    result = webread(baseurl, param{:});
catch err
    setbusy(hwin, false);
    setstatus(hwin, ['Search error: ' err.message]);
    return
end

hits = normalizehits(result);
if (isempty(hits) || issearcherror(result))
    setbusy(hwin, false);
    setstatus(hwin, 'No results found');
    return
end

[uniquedb, datasetsbydb, subjectmap] = groupsearchhits(hits);

if (~isempty(uniquedb))
    setlist(hwin, handles.lsDb, uniquedb, 'database', 'dbkeys');
    if (isKey(datasetsbydb, uniquedb{1}))
        setlist(hwin, handles.lsDs, datasetsbydb(uniquedb{1}), 'data', 'dskeys');
    end
end

clearjsontree(hwin);
totaldatasets = 0;
dbkeys = keys(datasetsbydb);
for i = 1:length(dbkeys)
    totaldatasets = totaldatasets + length(datasetsbydb(dbkeys{i}));
end
setstatus(hwin, sprintf('Found %d results from %d databases, %d datasets', ...
                        length(hits), length(uniquedb), totaldatasets));
setappdata(hwin, 'searchSubjects', subjectmap);
setappdata(hwin, 'searchDatasets', datasetsbydb);
setbusy(hwin, false);
togglesearch(hwin);

% --------------------------------------------------------------------------
function items = modalitylist()
% modality vocabulary of the neurojson.io search index, shown with readable
% labels; modalitycode() turns a label back into the short code that
% search.cgi matches on (the endpoint rejects the long form)

items = {'any', 'Structural MRI (anat)', 'fMRI (func)', 'DWI (dwi)', ...
         'Field maps (fmap)', 'Perfusion (perf)', 'MEG (meg)', 'EEG (eeg)', ...
         'Intracranial EEG (ieeg)', 'Behavioral (beh)', 'PET (pet)', ...
         'Microscopy (micr)', 'fNIRS (nirs)', 'Motion (motion)', ...
         'Behavioral data (behavdata)', 'Head position (hpi)', ...
         'Electrophysiology (ephys)', 'Atlas (atlas)'};

% --------------------------------------------------------------------------
function code = modalitycode(label)
% 'fNIRS (nirs)' -> 'nirs'; a bare code is returned unchanged

code = label;
if (isempty(code))
    return
end
token = regexp(code, '\(([^)]+)\)\s*$', 'tokens', 'once');
if (~isempty(token))
    code = token{1};
end

% --------------------------------------------------------------------------
function val = popupvalue(hpopup)
% selected popupmenu entry, or '' when it is left at the leading 'any'

val = '';
items = get(hpopup, 'string');
idx = get(hpopup, 'value');
if (isempty(items) || idx < 1 || idx > length(items))
    return
end
if (~strcmp(items{idx}, 'any'))
    val = items{idx};
end

% --------------------------------------------------------------------------
function tf = issearcherror(result)
% a query that matches nothing comes back as {"status":"error","msg":"empty
% output"} rather than as an empty array, so it must not be counted as a hit

tf = false;
if (ischar(result) || isa(result, 'string'))
    tf = ~isempty(regexp(char(result), '"status"\s*:\s*"error"', 'once'));
elseif (isstruct(result) && numel(result) == 1)
    tf = isfield(result, 'status') && ischar(result.status) && strcmp(result.status, 'error');
end

% --------------------------------------------------------------------------
function hits = normalizehits(result)
% MATLAB's webread parses a JSON array into a struct array while Octave's
% returns the response body verbatim; loadjson in turn yields either a struct
% array or a cell of structs depending on whether the records share keys, so
% reduce every one of those shapes to a cell array of scalar structs

hits = {};
if (ischar(result) || isa(result, 'string'))
    if (isempty(strtrim(char(result))))
        return
    end
    result = loadjson(char(result));
end
if (isstruct(result))
    hits = arrayfun(@(x) x, result(:)', 'UniformOutput', false);
elseif (iscell(result))
    hits = result(:)';
    hits = hits(cellfun(@isstruct, hits));
end

% --------------------------------------------------------------------------
function [uniquedb, datasetsbydb, subjectmap] = groupsearchhits(hits)
% collect the flat search.cgi hit list into database -> dataset -> subject maps

uniquedb = {};
datasetsbydb = containers.Map();
subjectmap = containers.Map();

for i = 1:length(hits)
    hit = hits{i};
    if (~isfield(hit, 'dbname') || ~isfield(hit, 'dsname'))
        continue
    end
    hitdb = hit.dbname;
    hitds = hit.dsname;
    hitkey = [hitdb '/' hitds];
    if (~any(strcmp(uniquedb, hitdb)))
        uniquedb{end + 1} = hitdb;
        datasetsbydb(hitdb) = {};
    end
    dslist = datasetsbydb(hitdb);
    if (~any(strcmp(dslist, hitds)))
        dslist{end + 1} = hitds;
        datasetsbydb(hitdb) = dslist;
    end
    if (~isKey(subjectmap, hitkey))
        subjectmap(hitkey) = {};
    end
    if (isfield(hit, 'subj'))
        subjects = subjectmap(hitkey);
        subjname = hit.subj;
        if (isnumeric(subjname))
            subjname = num2str(subjname);
        end
        if (~any(strcmp(subjects, subjname)))
            subjects{end + 1} = subjname;
            subjectmap(hitkey) = subjects;
        end
    end
end

% --------------------------------------------------------------------------
function clearjsontree(hwin)

handles = get(hwin, 'userdata');
set(handles.lsJSON, 'string', {}, 'value', 1);
setappdata(hwin, 'listkeys', {});
setappdata(hwin, 'pathstack', {});
setappdata(hwin, 'rootdata', []);
setappdata(hwin, 'subjectrows', {});
setappdata(hwin, 'subjectsource', {});
setappdata(hwin, 'peekkeys', {});
if (isfield(handles, 'lsPeek') && ishandle(handles.lsPeek))
    set(handles.lsPeek, 'string', {}, 'value', 1);
end
updateactions(hwin);

% --------------------------------------------------------------------------
function loadds(src, event, hwin)

handles = get(hwin, 'userdata');
if (isactivated(handles, event))
    dbname = selecteditem(hwin, handles.lsDb, 'dbkeys');
    setbusy(hwin, true);
    try
        searchdatasets = getappdata(hwin, 'searchDatasets');
        if (~isempty(searchdatasets) && isa(searchdatasets, 'containers.Map') && isKey(searchdatasets, dbname))
            setlist(hwin, handles.lsDs, searchdatasets(dbname), 'data', 'dskeys');
            clearjsontree(hwin);
        else
            dslist = neuroj('list', dbname);
            dslist.dataset = dslist.dataset(arrayfun(@(x) x.id(1) ~= '_', dslist.dataset));
            setlist(hwin, handles.lsDs, {dslist.dataset.id}, 'data', 'dskeys');
        end
        setappdata(hwin, 'dbname', dbname);
    catch err
        setstatus(hwin, ['Cannot list datasets: ' err.message]);
    end
    setbusy(hwin, false);
end

handles.t0 = cputime;
set(hwin, 'userdata', handles);

% --------------------------------------------------------------------------
function loaddsdata(src, event, hwin)

handles = get(hwin, 'userdata');
if (isactivated(handles, event))
    dsname = selecteditem(hwin, handles.lsDs, 'dskeys');
    % read the database from the list selection rather than from a cached
    % value, which a search result would otherwise leave unset
    dbname = selecteditem(hwin, handles.lsDb, 'dbkeys');
    if (isempty(dbname) || isempty(dsname))
        setstatus(hwin, 'Please select a database and a dataset first');
        return
    end
    setbusy(hwin, true);
    try
        % a search result lists the matching subjects instead of the document tree
        searchsubjects = getappdata(hwin, 'searchSubjects');
        hitkey = [dbname '/' dsname];
        subjects = {};
        if (~isempty(searchsubjects) && isa(searchsubjects, 'containers.Map') && isKey(searchsubjects, hitkey))
            subjects = searchsubjects(hitkey);
        end
        if (~isempty(subjects))
            clearjsontree(hwin);
            set(handles.lsJSON, 'string', cellfun(@(x) create_icon_string('data', ['sub-' x]), ...
                                                  subjects, 'UniformOutput', false), 'value', 1);
            setappdata(hwin, 'subjectrows', subjects);
            setappdata(hwin, 'subjectsource', {dbname, dsname});
            set(handles.txValue, 'string', sprintf(['Showing %d subjects matched in %s.' char(10) ...
                                                    'Open one to load the dataset at that subject.'], ...
                                                   length(subjects), hitkey));
        else
            loaddataset(hwin, dbname, dsname);
        end
    catch err
        setstatus(hwin, ['Cannot load dataset: ' err.message]);
    end
    setbusy(hwin, false);
end

handles.t0 = cputime;
set(hwin, 'userdata', handles);

% --------------------------------------------------------------------------
function loaddataset(hwin, dbid, dsname)
% load a document without decoding JData constructs, so the browser can show
% the _DataLink_/_ArrayType_ metadata and decode only what the user asks for

handles = get(hwin, 'userdata');
data = neuroj('get', dbid, dsname, '', 'jdatadecode', 0);

setappdata(hwin, 'rootdata', data);
setappdata(hwin, 'pathstack', {});
setappdata(hwin, 'dbname', dbid);
setappdata(hwin, 'dsname', dsname);
setappdata(hwin, 'subjectrows', {});
rendertree(hwin);
setstatus(hwin, sprintf('Loaded %s/%s (%d top-level keys)', dbid, dsname, length(nodekeys(data))));

% --------------------------------------------------------------------------
function expandjsontree(src, event, hwin)
% a single click reports the selected node, a double-click (or enter) steps
% into it when it is a container

handles = get(hwin, 'userdata');
activated = isactivated(handles, event);

if (~isempty(getappdata(hwin, 'rootdata')))
    if (~activated)
        shownodeinfo(hwin);
    else
        setbusy(hwin, true);
        try
            stepintonode(hwin);
        catch err
            setstatus(hwin, ['Cannot open this node: ' err.message]);
        end
        setbusy(hwin, false);
    end
elseif (activated && ~isempty(getappdata(hwin, 'subjectrows')))
    setbusy(hwin, true);
    try
        opensubject(hwin);
    catch err
        setstatus(hwin, ['Cannot open this subject: ' err.message]);
    end
    setbusy(hwin, false);
end

handles.t0 = cputime;
set(hwin, 'userdata', handles);

% --------------------------------------------------------------------------
function opensubject(hwin)
% a row of a search result names a subject rather than a document key; load
% the dataset it was matched in and step straight into that subject's subtree

handles = get(hwin, 'userdata');
subjects = getappdata(hwin, 'subjectrows');
source = getappdata(hwin, 'subjectsource');
idx = get(handles.lsJSON, 'value');
if (isempty(subjects) || length(source) < 2 || idx(1) < 1 || idx(1) > length(subjects))
    return
end

subjectkey = ['sub-' subjects{idx(1)}];
loaddataset(hwin, source{1}, source{2});

allkeys = nodekeys(getappdata(hwin, 'rootdata'));
pos = find(strcmp(cellfun(@keylabel, allkeys, 'UniformOutput', false), subjectkey), 1);
if (isempty(pos))
    setstatus(hwin, sprintf('%s is not a top-level key of %s/%s; showing the document root', ...
                            subjectkey, source{1}, source{2}));
    return
end
setappdata(hwin, 'pathstack', allkeys(pos));
rendertree(hwin);

% --------------------------------------------------------------------------
function stepintonode(hwin)
% descend into the selected container, or climb back up on '..'

node = currentnode(hwin);
pathstack = getappdata(hwin, 'pathstack');
if (~iscell(pathstack))
    pathstack = {};
end
if (node.isparent)
    setappdata(hwin, 'pathstack', pathstack(1:end - 1));
    rendertree(hwin);
elseif (node.ok && ~isempty(nodekeys(node.value)))
    descendinto(hwin, node.key);
else
    shownodeinfo(hwin);
end
