-module(fingwb_msg_handler).
-behaviour(cowboy_websocket_handler).

-export([init/3]).
-export([websocket_init/3]).
-export([websocket_handle/3]).
-export([websocket_info/3]).
-export([websocket_terminate/3]).

-record(ws_state, {
	id
}).

init({tcp, http}, _Req, _Opts) ->
	{upgrade, protocol, cowboy_websocket}.

websocket_init(_TransportName, Req, _Opts) ->
	{WhiteBoardId, Req2} = cowboy_req:binding(whiteboard_id, Req),
	[ self() ! {join, Pid}|| Pid <- fingwb_whiteboard:watchers(WhiteBoardId)],
	ok = fingwb_whiteboard:watch(WhiteBoardId),
	ok = fingwb_whiteboard:notify(WhiteBoardId, {join, self()}),
	[ self() ! Message || Message <- fingwb_whiteboard:readArchive(WhiteBoardId)],
	{ok, Req2, #ws_state{id=WhiteBoardId}}.

websocket_handle(Data, Req, State = #ws_state{id=WbId}) ->
	ok = fingwb_whiteboard:publish(WbId, Data),
	{ok, Req, State}.

websocket_info({join, Pid}, Req, State) ->
	{reply, {text, jiffy:encode({[{<<"join">>, list_to_binary(pid_to_list(Pid))}]})}, Req, State};
websocket_info({leave, Pid}, Req, State) ->
	{reply, {text, jiffy:encode({[{<<"leave">>, list_to_binary(pid_to_list(Pid))}]})}, Req, State};
websocket_info(Message, Req, State) ->
	{reply, Message, Req, State}.

websocket_terminate(_Reason, _Req, #ws_state{id=WbId}) ->
	fingwb_whiteboard:notify(WbId, {leave, self()}),
	fingwb_whiteboard:unWatch(WbId).
