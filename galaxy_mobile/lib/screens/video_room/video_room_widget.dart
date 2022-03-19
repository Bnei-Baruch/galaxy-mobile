import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'package:flutter/material.dart';

import 'package:galaxy_mobile/models/main_store.dart';
import 'package:galaxy_mobile/services/keycloak.dart';
import 'package:galaxy_mobile/services/monitoring_isolate.dart';
import 'package:galaxy_mobile/widgets/directional_child.dart';
import 'package:flutter/foundation.dart';
import 'package:galaxy_mobile/utils/switch_page_helper.dart';
import 'package:galaxy_mobile/utils/utils.dart';
import 'package:janus_client/janus_client.dart';
import 'package:janus_client/utils.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:janus_client/Plugin.dart';
import 'package:mdi/mdi.dart';
import 'package:provider/provider.dart';
import 'package:flutter_logs/flutter_logs.dart';


import 'dart:async';

import 'package:synchronized/synchronized.dart';

import '../../foreground.dart';

typedef BoolCallback = Function(bool);
typedef UpdateUserCallback = Function(Map<String, dynamic> user);
typedef UpdateDots = Function(int position, int length);
// Since active user is always in the page, PAGE_SIZE is the number of remote
// feeds in the page.
final int PAGE_SIZE = 3;

int getNumPages(int feedCount) {
  return (feedCount / PAGE_SIZE).ceil();
}

// Given available feed count, get the last available page index to switch to.
// Lowest index is 0.
int getLastPageIndex(int feedCount) {
  int numPages = getNumPages(feedCount);
  return numPages == 0 ? 0 : numPages - 1;
}

class VideoRoom extends StatefulWidget {
  List<RTCVideoView> remote_videos = new List();
  String server;
  String token;
  int roomNumber;
  VoidCallback callExitRoomUserExists;
  VoidCallback updateGoingToBackground;
  VoidCallback onCurrentUserJoinedRoom;
  UpdateUserCallback updateGlxUserCB;
  User user;

  JanusClient _janusClient;
  RTCVideoRenderer _localRenderer = new RTCVideoRenderer();
  List<RTCVideoRenderer> _remoteRenderers = new List<RTCVideoRenderer>();
  Plugin pluginHandle;
  Plugin subscriberHandle;
  bool myAudioMuted = false;
  bool myVideoMuted = true;
  bool isQuestion = false;

  UpdateDots updateDots;
  var questionInRoom;

  MediaStream myStream;
  var remoteStream;
  _VideoRoomState state;

  int myid;
  int mypvtid;
  BoolCallback updateVideoState;
  VoidCallback RoomReady;
  bool myVideoNeedsRecreation = false;
  Plugin chatHandle;
  String janusName;
  String groupName;
  bool isFullScreen = false;
  List mainToIsolateStream;
  String streamingServer;

  String configuredStreams;

  void exitRoom() async {
    if (_janusClient != null) _janusClient.destroy();
    if (pluginHandle != null) pluginHandle.hangup();
    if (subscriberHandle != null) subscriberHandle.destroy();
    if (_localRenderer != null) {
      _localRenderer.srcObject = null;
      await _localRenderer.dispose();

    }
    if (_remoteRenderers != null && _remoteRenderers.isNotEmpty) {
      _remoteRenderers.map((e) => e.srcObject = null);
    }
    if (myStream != null) {
      myStream.getAudioTracks().first.setMicrophoneMute(false);
      myStream.getVideoTracks().first.enabled = false;
      myStream.getAudioTracks().first.enabled = false;
      myStream.dispose();
    }
    pluginHandle = null;
    subscriberHandle = null;
    questionInRoom = null;
    state.dispose();
    state = null;

  }

  @override
  _VideoRoomState createState() => _VideoRoomState();

  int getMyFeedId() {
    return myid;
  }

  bool getIsQuestion() {
    return isQuestion;
  }

  setIsQuestion(bool isQuestion) {
    this.isQuestion = isQuestion;
  }

  void mute() {
    myStream
        .getAudioTracks()
        .first
        .setMicrophoneMute(!myStream.getAudioTracks().first.muted);
    if (state != null && state.mounted)
      state.setState(() {
        myAudioMuted = !myAudioMuted;
      });
    else {
      myAudioMuted = !myAudioMuted;
    }
  }

  void toggleVideo() {
    FlutterLogs.logInfo("VideoRoom", "toggleVideo", "entering");
    myStream.getVideoTracks().first.enabled =
        !myStream.getVideoTracks().first.enabled;

    if (state != null && state.mounted) {
      state.setState(() {
        myVideoMuted = !myVideoMuted;
      });
    } else {
      myVideoMuted = !myVideoMuted;
    }
    FlutterLogs.logInfo("VideoRoom", "toggleVideo",
        "${myStream.getVideoTracks().first.toString()}");
  }

  bool toggleQuestion() {
    if (questionInRoom == null) {
      FlutterLogs.logInfo("VideoRoom", "toggleQuestion", "toggling...");
      if (state != null && state.mounted) {
        state.setState(() {
          isQuestion = !isQuestion;
        });
      } else {
        isQuestion = !isQuestion;
      }
      return true;
    } else {
      FlutterLogs.logWarn(
          "VideoRoom", "toggleQuestion", "question already set in room");
      return false;
    }
  }

  void setUserState(var user) {
    bool didFeedsUpdate = false;
    FlutterLogs.logInfo("VideoRoom", "setUserState", "user ${user.toString()}");
    if (state != null && state.mounted) {
      List roomFeeds = state.getFeeds();
      for (var feed in roomFeeds) {
        if (feed != null && feed['id'] == user['rfid']) {
          FlutterLogs.logInfo(
              "VideoRoom", "setUserState", "found user in feed ${roomFeeds}");
          FlutterLogs.logInfo(
              "VideoRoom", "setUserState", "before ${feed['cammute']}");

          feed['cammute'] = !user['camera'];

          FlutterLogs.logInfo(
              "VideoRoom", "setUserState", "after ${feed['cammute']}");
          feed['question'] = user['question'];

          setUserQuestionInRoom(user);
          didFeedsUpdate = true;

          if (state != null && state.mounted) {
            state.setState(() {
              FlutterLogs.logInfo("VideoRoom", "setUserState",
                  "call setstate for cammute update");
            });
          } else {
            FlutterLogs.logInfo("VideoRoom", "setUserState",
                "state not mounted");
          }
          break;
        } else {
          FlutterLogs.logInfo(
              "VideoRoom", "setUserState", "could not find user");
        }
      }
    }
    else {
      FlutterLogs.logInfo(
          "VideoRoom", "setUserState", "state not valid");
      if (state != null) {
        List roomFeeds = state.getFeeds();
        if (roomFeeds != null) {
          for (var feed in roomFeeds) {
            if (feed != null && feed['id'] == user['rfid']) {
              FlutterLogs.logInfo(
                  "VideoRoom", "setUserState",
                  "found user in feed ${roomFeeds}");

              FlutterLogs.logInfo(
                  "VideoRoom", "setUserState", "before ${feed['cammute']}");


              feed['cammute'] = !user['camera'];

              FlutterLogs.logInfo(
                  "VideoRoom", "setUserState", "after ${feed['cammute']}");
              feed['question'] = user['question'];

              setUserQuestionInRoom(user);
              didFeedsUpdate = true;
            }
          }
        }
      }
    }

    if (didFeedsUpdate) {
      state.onFeedsChanged(state.getFeeds());
    }
  }

  void setUserQuestionInRoom(var user) {
    if (user['question']) {
      questionInRoom = {'rfid': user['rfid']};
    } else if (questionInRoom != null &&
        questionInRoom['rfid'] == user['rfid']) {
      questionInRoom = null;
    }
  }

  void toggleAudioMode() {
    state.toggleAudioMode();
  }

  void setFullScreen(bool isFullScreen) {
    this.isFullScreen = isFullScreen;
    if (state != null) {
      state.setState(() {});
    }
  }
}

class _VideoRoomState extends State<VideoRoom> with WidgetsBindingObserver {
  List<MediaStream> remoteStream = new List<MediaStream>();
  List<Map> roomFeeds;
  List streams;
  bool creatingFeed = false;
  List feeds = List.empty();
  List newStreamsMids = List.empty(growable: true);
  bool muteOtherCams = false;
  int page = 0;
  bool initialized = false;
  int fromVideoIndex;
  int toVideoIndex;
  String signal = "good";
  bool recoverFromBackground = false;
  List<MediaDeviceInfo> cameras;

  set id(id) {}
  set subscription(List subscription) {}

  SwitchPageHelper switcher;

  List getFeeds() {
    return feeds;
  }

  void onFeedsChanged(feeds) {
    context.read<MainStore>().setFriendsInRoom(feeds.map<RoomUser>((feed) {
      bool camMuted = feed['cammute'] ?? false;
      bool micOn = feed['talking'] ?? false;
      String name = feed['display']['display'] ?? "";
      return RoomUser(
          id: feed['id'].toString(),
          name: name,
          camOn: !camMuted,
          micOn: micOn,
          // Feeds are always of friends and not the current user.
          isCurrentUser: false,
          timeJoined: feed["display"]["timestamp"]);
    }).toList());
  }


  @override
  void didChangeDependencies() async {
    // TODO: implement didChangeDependencies
    super.didChangeDependencies();
  }

  @override
  void initState() {
    FlutterLogs.logInfo(
        "VideoRoom", "initState", "");
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    switcher = SwitchPageHelper(unsubscribeFrom, makeSubscription,
        switchVideoSlots, PAGE_SIZE, muteOtherCams, widget.updateDots);
    widget.state = this;

    (context.read<MainStore>()).addListener(updateSignal);
  }

  void updateSignal() {

    if ((widget.state != null && widget.state.context != null)
        && (widget.state.context.read<MainStore>() as MainStore).signal != signal) {

        setState(() {
          signal = (widget.state.context.read<MainStore>()).signal;
        });

        FlutterLogs.logInfo(
            "VideoRoom", "signal changed", "$signal");
      }
  }

  @override
  void dispose() {

    WidgetsBinding.instance.removeObserver(this);
    (context.read<MainStore>() as MainStore).removeListener(updateSignal);
    if(widget.mainToIsolateStream != null)
    {
      if(widget.mainToIsolateStream[1] != null)
      {
        widget.mainToIsolateStream[1].send({"type": "stop"});
      }
      if(widget.mainToIsolateStream[0] != null)
      {
        widget.mainToIsolateStream[0].kill();
      }
    }

    super.dispose();
  }

  Future<void> initInfra() async {
    await initRenderers();
    await initPlatformState();
  }

  Future<void> initRenderers() async {
    int count = 0;
    while (count < 3) {
      widget._remoteRenderers.add(new RTCVideoRenderer());
      count++;
    }
    await widget._localRenderer.initialize();
    for (var renderer in widget._remoteRenderers) {
      await renderer.initialize();
    }
  }

  void switchPage(int page) {
    FlutterLogs.logInfo(
        "VideoRoom", "switchPage", "switch page to: ${page.toString()}");
    int numPages = getNumPages(feeds.length);
    // Normalize page, e.g., if it is -1 or too large...
    int normalizedPage = numPages == 0 ? 0 : (numPages + page) % numPages;
    switcher.switchVideos(normalizedPage, feeds, feeds);
    this.setState(() {
      this.page = normalizedPage;
    });
  }

  userFeeds(feeds) => feeds.map((feed) => feed["display"]["role"] == 'user');

  _newRemoteFeed(JanusClient janusClient, List<Map> feeds) async {
    roomFeeds = feeds;
    FlutterLogs.logInfo(
        "VideoRoom", "_newRemoteFeed", "remote plugin attached");
    janusClient.attach(Plugin(
        opaqueId: 'remotefeed_user',
        plugin: 'janus.plugin.videoroom',
        onMessage: (msg, jsep) async {
          FlutterLogs.logInfo(
              "VideoRoom", "_newRemoteFeed", "message: ${msg.toString()}");
          //update feed
          var event = msg["videoroom"];
          if (event == 'attached' ||
              (event == 'event' && msg['switched'] == 'ok') ||
              event == 'updated') {
            List midslist = (msg['streams'] as List)
                .map((stream) => {
                      "mid": stream["mid"],
                      "feed_id": stream["feed_id"],
                      "type": stream["type"]
                    })
                .toList();
            // newStreamsMids.addAll(midslist);
            FlutterLogs.logInfo("VideoRoom", "_newRemoteFeed",
                "got newStreamsMids ${midslist.toString()}");
            newStreamsMids = midslist;
          }

          if (jsep != null) {
            await widget.subscriberHandle.handleRemoteJsep(jsep);
            // var body = {"request": "start", "room": 2157};
            var body = {
              "request": "start",
              "room": widget.roomNumber,
            };
            await widget.subscriberHandle.send(
                message: body,
                jsep: await widget.subscriberHandle.createAnswer(
                  offerOptions: {"media": {"audioSend": false, "videoSend": false}}
                ),
                onSuccess: () {
                  FlutterLogs.logInfo("VideoRoom", "_newRemoteFeed",
                      "subscribe Handle onSuccess create answer and start");
                  creatingFeed = false;
                },
                onError: (error) {
                  FlutterLogs.logError("VideoRoom", "_newRemoteFeed",
                      "could not create answer: ${error.toString()}");
                });
          } else {
            FlutterLogs.logWarn(
                "VideoRoom", "_newRemoteFeed", "no jsep to answer");
          }
        },
        onSuccess: (plugin) {
          widget.subscriberHandle = plugin;
          var register = {
            "request": "join",
            "room": widget.roomNumber,
            "ptype": "subscriber",
            "streams": feeds,
          };

          FlutterLogs.logInfo("VideoRoom", "_newRemoteFeed",
              "requesting subscription to publishers...");
          widget.subscriberHandle.send(
            message: register,
            onSuccess: () async {
              FlutterLogs.logInfo("VideoRoom", "_newRemoteFeed",
                  "subscription to publishers successful");

              //set the pc and local streams to main store
              // Provider.of<MainStore>(context).setVideoRoomParams(widget.pluginHandle,widget.myStream);
              context.read<MainStore>().plugin = widget.pluginHandle;
              context.read<MainStore>().localStream = widget.myStream;

              Map<String, dynamic> userJson = widget.user.toJson();
              userJson["room"] = widget.roomNumber;
              userJson["group"] = widget.groupName;
              widget.mainToIsolateStream  = await initIsolate(context);
              context.read<MainStore>().setMonitorPort(widget.mainToIsolateStream[1]);
              //   // mainToIsolateStream = value,
              //   // mainToIsolateStream = value,
              widget.mainToIsolateStream[1].send({
                  "type": "updateSpec",
                  "spec": context.read<MainStore>().spec
              });
              widget.mainToIsolateStream[1].send({
                "type": 'setConnection',
                "user": userJson,
                // "localAudio": widget.myStream.getAudioTracks().first,
                // "localVideo": widget.myStream.getVideoTracks().first,
                // "plugin": context,
                "galaxyServer":context.read<MainStore>().activeStreamGateway.url,
                "janus":context.read<MainStore>().activeGateway.url,
                "version":context.read<MainStore>().version,
                "network":context.read<MainStore>().network.toString()

                // "userExtra": {},
                // "data": {}
              });
              widget.mainToIsolateStream[1].send({"type": "start"});
              // });
              widget.onCurrentUserJoinedRoom();
            },
            onError: (error) {
              FlutterLogs.logError("VideoRoom", "_newRemoteFeed",
                  "subscription to publishers FAILED: ${error.toString()}");
            },
          );
          widget.RoomReady();
        },
        onError: (error) {
          FlutterLogs.logError("VideoRoom", "plugin:'remotefeed_user", error);
        },
        onRemoteTrack: (stream, track, mid, on) {
          FlutterLogs.logInfo(
              "VideoRoom",
              "_newRemoteFeed",
              "got remote track with "
                  "mid: ${mid.toString()} | "
                  "trackId: ${track.toString()} | "
                  "isOn: ${on.toString()} | "
                  "streamId: ${stream.id.toString()} | "
                  "hasTracks: ${(stream as MediaStream).getVideoTracks().length.toString()} | "
                  "Ids: ${(stream as MediaStream).getVideoTracks().map((e) => e.toString())}");
          // print(
          //     'xxx got remote track with mid=$mid trackid=${track.toString()} , is on = $on stream with id=${stream.id} has tracks = ${(stream as MediaStream).getVideoTracks().length} with ids=${(stream as MediaStream).getVideoTracks().map((e) => e.toString())}');

          (stream as MediaStream).getVideoTracks().forEach((element) => {
                FlutterLogs.logInfo(
                    "VideoRoom",
                    "_newRemoteFeed",
                    "track ${element.id} | "
                        "isEnabled: ${element.enabled.toString()} |"
                        "isMuted: ${element.muted.toString()}")
              });
          if ((track as MediaStreamTrack).kind == "video" &&
              (track as MediaStreamTrack).enabled &&
              on) {
            setState(() {
              var midElement = newStreamsMids.firstWhere((element) =>
                  element["type"] == "video" && element["mid"] == mid);
              var feed = this.feeds.firstWhere(
                  (element) => element["id"] == midElement["feed_id"]);

              int trackIndex = (stream as MediaStream)
                  .getVideoTracks()
                  .indexWhere((element) => element.id == track.id);

              FlutterLogs.logInfo(
                  "VideoRoom",
                  "_newRemoteFeed",
                  "video slot is: ${feed["videoSlot"].toString()} | "
                      "track index : ${trackIndex.toString()}");

              feed["trackIndex"] = trackIndex;
              int slot = feed["videoSlot"];
              var lock = Lock();
              lock.synchronized(() async {
                Future.delayed(const Duration(milliseconds: 100), () {
                  setState(() {
                    widget._remoteRenderers.elementAt(slot).trackIndex =
                        trackIndex;
                    widget._remoteRenderers.elementAt(slot).srcObject =
                        stream; //remoteStream.elementAt(slot);

                    FlutterLogs.logInfo(
                        "VideoRoom",
                        "_newRemoteFeed",
                        "done set renderer stream for video slot: "
                            "${slot.toString()}");
                    // }

                    //check if mids changed place

                    var otherFeeds = this.feeds.where((element) =>
                        element["videoSlot"] != slot &&
                        element["videoSlot"] != null &&
                        element["videoSlot"] != -1);

                    FlutterLogs.logInfo(
                        "VideoRoom",
                        "_newRemoteFeed",
                        "other feeds ${otherFeeds.toString()} "
                            "and all feeds ${feeds.toString()}");

                    otherFeeds.forEach((element) {
                      // int index = element["videoSlot"];
                      // if (widget._remoteRenderers.elementAt(index).trackIndex !=
                      //     element["trackIndex"]) {
                      //   widget._remoteRenderers.elementAt(index).trackIndex =
                      //       element["trackIndex"];
                      //   widget._remoteRenderers.elementAt(slot).srcObject =
                      //       stream;
                      // }
                    });
                    // switch (otherFeeds.length) {
                    //   case 0:
                    //     widget._remoteRenderers.elementAt(0).srcObject = null;
                    //     widget._remoteRenderers.elementAt(1).srcObject = null;
                    //     widget._remoteRenderers.elementAt(2).srcObject = null;
                    //     break;
                    //   case 1:
                    //     widget._remoteRenderers.elementAt(1).srcObject = null;
                    //     widget._remoteRenderers.elementAt(2).srcObject = null;
                    //     break;
                    //   // case 2:
                    //   //   widget._remoteRenderers.elementAt(2).srcObject = null;
                    //   //   break;
                    // }
                  });
                });
                // );
                //   }
              });
              // }
            });
          }
          //});
        },
        slowLink: (uplink, lost, mid) {
          FlutterLogs.logWarn("VideoRoom", "plugin: remotefeed_user",
              "slowLink: uplink ${uplink} lost ${lost} mid ${mid}");
          if (widget.mainToIsolateStream != null && widget.mainToIsolateStream[1] != null) {
            (widget.mainToIsolateStream[1] as SendPort).send({
              "type": "slowLink",
              "direction": uplink ? "sending" : "receiving",
              "lost": lost});
          }
        },
        onIceConnectionState: (connection) {
          FlutterLogs.logWarn("VideoRoom", "onIceConnectionState",
            "state: $connection");
          if (widget.mainToIsolateStream != null && widget.mainToIsolateStream[1] != null) {
            (widget.mainToIsolateStream[1] as SendPort).send(
                {"type": "iceState", "state": connection
                    .toString()
                    .split('.')
                    .last
                    .toLowerCase()
                    .replaceFirst("rtciceconnectionstate", "")});
          }
        },
        onRenegotiationNeededCallback: (){
          FlutterLogs.logWarn("VideoRoom", "onRenegotiationNeededCallback",
              "_newRemoteFeed");

        }

      ,));
  }

  void updateFeeds(List newFeeds) {
   if (listEquals(feeds, newFeeds) == false) {
      feeds = newFeeds;
      onFeedsChanged(feeds);
   }
  }

  Future<void> initPlatformState() async {
    setState(() {
      widget._janusClient = JanusClient(iceServers: [
        RTCIceServer(
            url: "stun:galaxy.kli.one:3478", username: "", credential: ""),
      ], server: [
        widget.server,
      ], withCredentials: true, isUnifiedPlan: true, token: widget.token);
      widget._janusClient.connect(onSuccess: (sessionId) async {
        FlutterLogs.logInfo(
            "VideoRoom",
            "initPlatformState",
            "voila! connection established with session id as "
                "${sessionId.toString()}");
        // Map<String, dynamic> configuration = {
        //   "iceServers": widget._janusClient.iceServers.map((e) => e.toMap()).toList()
        // };

        widget._janusClient.attach(Plugin(
            opaqueId: widget.user.sub,
            plugin: 'janus.plugin.videoroom',
            onMessage: (msg, jsep) async {
              var event = msg['videoroom'];
              if (event != null) {
                if (event == 'joined') {
                  widget.myid = msg["id"];
                  var userJson = widget.user.toJson();
                  userJson.putIfAbsent("rfid", () =>  widget.myid);

                  widget.user = User.fromJson(userJson);

                  updateGxyUser(context, userJson);

                  // widget._onUpdateVideoStateCallback();


                  widget.mypvtid = msg["private_id"];
                  var publishersList = msg['publishers'];
                  if (publishersList != null) {
                    FlutterLogs.logInfo("VideoRoom", "initPlatformState",
                        "got publishers: ${publishersList.toString()}");

                    List<Map> subscription = new List<Map>();
                    final filteredList = List.from(publishersList);
                    filteredList.forEach((item) => {
                          if ((item["streams"] as List).length == 2)
                            {
                              subscription.add({
                                "feed": LinkedHashMap.of(item).remove("id"),
                                "mid": "1"
                              })
                            }
                        });

                    (publishersList as List).forEach((value) =>
                        value["display"] = (jsonDecode(value["display"])));
                    //( (l)  => l["display"] = (jsonDecode(l["display"])) as Map);
                    //          List newFeeds = sortAndFilterFeeds();
                    publishersList = Utils.sortAndFilterFeeds(publishersList);
                    List newFeeds = publishersList;
                    FlutterLogs.logInfo(
                        "VideoRoom",
                        "initPlatformState",
                        "New list of available publishers/feeds: "
                            "${newFeeds.toString()}");

                    //check if mhy user id is already in the room
                    newFeeds.forEach((element) {
                      if (element["display"]["id"] == widget.user.id) {
                        //notify on exit room
                        //request to disbale TRL-75
                        // widget.callExitRoomUserExists();
                      }
                    });

                    Set newFeedsIds = new Set();
                    // var tempset = newFeeds.map((feed) => feed["id"]).toSet();
                    newFeedsIds
                        .addAll(newFeeds.map((feed) => feed["id"]).toSet());
                    if (feeds != null &&
                        feeds.any((feed) => newFeedsIds.lookup(feed["id"]))) {
                      FlutterLogs.logInfo(
                          "VideoRoom",
                          "initPlatformState",
                          "new feed joining but one of the feeds already exist: "
                              "${newFeeds.toString()} | "
                              "${publishersList.toString()}");
                      return;
                    }
                    // Merge new feed with existing feeds and sort.
                    List newFeedsState =
                        feeds != null ? (feeds + newFeeds) : newFeeds;

                    updateFeeds(newFeedsState);
                    // Merge new feed with existing feeds and sort.
                    switcher.makeSubscription(
                        newFeeds,
                        /* feedsJustJoined= */ true,
                        /* subscribeToVideo= */ false,
                        /* subscribeToAudio= */ true,
                        /* subscribeToData= */ true);
                    switcher.switchVideos(
                        /* page= */ page,
                        List.empty(),
                        newFeedsState);
                  }
                } else if (event == 'talking') {
                  FlutterLogs.logInfo(
                      "VideoRoom", "initPlatformState", "talking");
                  final id = msg['id'];

                  FlutterLogs.logInfo("VideoRoom", "initPlatformState",
                      "user ${id.toString()} - is talking");
                  final feed = feeds.firstWhere((feed) => feed["id"] == id,
                      orElse: () => null);
                  if (feed == null) {
                    FlutterLogs.logWarn("VideoRoom", "initPlatformState",
                        "user ${id.toString()} not found");
                    return;
                  }
                  setState(() {
                    feed["talking"] = true;
                    onFeedsChanged(feeds);
                  });
                } else if (event == 'stopped-talking') {
                  FlutterLogs.logInfo(
                      "VideoRoom", "initPlatformState", "stopped-talking");
                  // const feeds = Object.assign([], this.state.feeds);
                  final id = msg['id'];
                  FlutterLogs.logInfo("VideoRoom", "initPlatformState",
                      "user ${id.toString()} - stop talking");
                  final feed = feeds.firstWhere((feed) => feed["id"] == id,
                      orElse: () => null);
                  if (feed == null) {
                    FlutterLogs.logWarn("VideoRoom", "initPlatformState",
                        "user ${id.toString()} not found");
                    return;
                  }
                  setState(() {
                    feed["talking"] = false;
                    onFeedsChanged(feeds);
                  });

                  // this.setState({ feeds });
                } else if (event == 'destroyed') {
                  FlutterLogs.logInfo(
                      "VideoRoom", "initPlatformState", "destroyed");

                  // The room has been destroyed
                  // Janus.warn('The room has been destroyed!');
                } else if (event == 'event') {
                  if (msg['configured'] == 'ok') {
                    FlutterLogs.logInfo(
                        "VideoRoom", "initPlatformState", "configured $msg");
                    FlutterLogs.logInfo(
                        "VideoRoom", "initPlatformState", "streams ${msg["streams"]}");

                    widget.configuredStreams = json.encode(msg["streams"]);
                    var userJson = widget.user.toJson();
                    widget.user = User.fromJson(userJson);
                    updateGxyUser(context, userJson);

                  } else if (msg['publishers'] != null &&
                      msg['publishers'] != null) {
                    FlutterLogs.logInfo(
                        "VideoRoom", "initPlatformState", "just joined");
                    // User just joined the room.
                    (msg['publishers'] as List).forEach((value) {
                      value["display"] = (jsonDecode(value["display"]));
                    });
                    var newFeeds = msg['publishers']
                        as List; //sortAndFilterFeeds(msg['publishers'] as List);
                    FlutterLogs.logInfo(
                        "VideoRoom",
                        "initPlatformState",
                        "new list of available publishers/feeds: "
                            "${newFeeds.toString()}");

                    Set newFeedsIds = new Set();
                    newFeedsIds
                        .addAll(newFeeds.map((feed) => feed["id"]).toSet());
                    if (feeds.any((feed) => newFeedsIds.contains(feed["id"]))) {
                      FlutterLogs.logWarn(
                          "VideoRoom",
                          "joinning",
                          "new feed joining but one of the feeds already exist: "
                              "${newFeeds.toString()}");
                      return;
                    }
                    // Merge new feed with existing feeds and sort.
                    var feedsNewState = feeds + newFeeds;
                    switcher.makeSubscription(
                        newFeeds,
                        /* feedsJustJoined= */ true,
                        /* subscribeToVideo= */ false,
                        /* subscribeToAudio= */ true,
                        /* subscribeToData= */ true);
                    switcher.switchVideos(
                        /* page= */ page,
                        feeds,
                        feedsNewState);
                    updateFeeds(feedsNewState);
                  } else if (msg['leaving'] != null && msg['leaving'] != null) {
                    // User leaving the room which is same as publishers gone.
                    final leaving = msg['leaving'];
                    FlutterLogs.logInfo("VideoRoom", "leaving",
                        "publisher: ${leaving.toString()} is leaving");
                    // const { feeds } = this.state;
                    switcher.unsubscribeFrom([leaving], /* onlyVideo= */ false);
                    List feedsNewState =
                        (feeds).where((feed) => feed["id"] != leaving).toList();
                    switcher.switchVideos(
                        /* page= */ page,
                        feeds,
                        feedsNewState);
                    updateFeeds(feedsNewState);
                    // After user has left, if the current page index is
                    // overflowing, go back one page.
                    if (page > getLastPageIndex(feedsNewState.length)) {
                      this.switchPage(page - 1);
                    }

                    FlutterLogs.logInfo("VideoRoom", "initPlatformState",
                        "publisher: ${leaving.toString()} left");
                  } else if (msg['unpublished'] != null &&
                      msg['unpublished'] != null) {
                    FlutterLogs.logInfo(
                        "VideoRoom", "initPlatformState", "unpublished");
                    // const unpublished = msg['unpublished'];
                    // Janus.log('Publisher unpublished: ', unpublished);
                    // if (unpublished === 'ok') {
                    // // That's us
                    // videoroom.hangup();
                    // return;
                    // }

                  } else if (msg['error'] != null && msg['error'] != null) {
                    FlutterLogs.logError(
                        "VideoRoom", "initPlatformState", msg['error']);
                    // if (msg['error_code'] === 426) {
                    // Janus.log('This is a no such room');
                    // } else {
                    // Janus.log(msg['error']);
                    // }
                  }
                }
              }
              if (jsep != null) {
                widget.pluginHandle.handleRemoteJsep(jsep);
              }
            },
            onSuccess: (plugin) async {
              // setState(() {
              await prepareAndRegisterMyStream(plugin);
            },
            slowLink: (uplink, lost, mid) {
              FlutterLogs.logWarn("VideoRoom", "plugin: janus.plugin.videoroom",
                  "slowLink: uplink ${uplink} lost ${lost} mid ${mid}");
              if(widget.mainToIsolateStream !=null && widget.mainToIsolateStream[0]!=null)
                  (widget.mainToIsolateStream[0] as SendPort).send({"type":"slowLink","direction":uplink ? "sending":"receiving","lost":lost});
            },
            onIceConnectionState:(connection){
              FlutterLogs.logWarn("VideoRoom", "onIceConnectionState",
                  "state: $connection");
              if(widget.mainToIsolateStream !=null && widget.mainToIsolateStream[0]!=null)

                (widget.mainToIsolateStream[1] as SendPort).send({"type":"iceState","state":connection.toString()});
            },
            onRenegotiationNeededCallback: () async {
              FlutterLogs.logWarn("VideoRoom", "onRenegotiationNeededCallback",
                  "videoroom");

            }
        ));
      }, onError: (e) {
        FlutterLogs.logError("VideoRoom", "plugin: janus.plugin.videoroom",
            "some error occurred: ${e.toString()}");
      });
    });
  }

  Future prepareAndRegisterMyStreamRecovery(Plugin plugin) async {
    FlutterLogs.logWarn("VideoRoom", "prepareAndRegisterMyStreamRecovery",
        "videoroom");
    //if( widget.myStream.getVideoTracks() != null &&  widget.myStream.active != true) {
      widget.pluginHandle = plugin;
    Map<String, dynamic> mediaConstraints = {
      "audio": true,
      "video": {
        "mandatory": {
          "minWidth":
          320, // Provide your own width, height and frame rate here
          "minHeight": 180,
          "minFrameRate": 15
        },
        "facingMode": "user",
        "optional": [],
      }
    };

    //plugin.webRTCHandle.pc.removeTrack(senders.firstWhere((sender) => sender.track.kind == "audio"));
    MediaStream stream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
    if(widget.myStream.getVideoTracks().first.enabled){
      widget.myStream.getVideoTracks().first.enabled = false;
    }
    widget.myStream = stream;
    widget.myStream
        .getAudioTracks()
        .first
        .setMicrophoneMute(true);

    setState(() {
      widget._localRenderer.srcObject = widget.myStream;
      widget.myAudioMuted = true;
      widget.myVideoMuted = true;
      widget.updateVideoState(true);
      widget.myStream.getVideoTracks().first.enabled = false;
    });

    Timer(Duration(seconds: 4),() async {
      var senders = await plugin.webRTCHandle.pc.senders;
      await ((senders.firstWhere((sender) => sender.track.kind == "video" )).replaceTrack(widget.myStream
        .getVideoTracks()
        .first));
      await ((senders.firstWhere((sender) => sender.track.kind == "audio" )).replaceTrack(widget.myStream
        .getAudioTracks()
        .first));
    });

  }
  Future prepareAndRegisterMyStream(Plugin plugin) async {
    FlutterLogs.logWarn("VideoRoom", "prepareAndRegisterMyStream-",
        "videoroom");
    widget.pluginHandle = plugin;
    MediaStream stream = await plugin.initializeMediaDevices();
    widget.myStream = stream;
    widget.myStream.getAudioTracks().first.setMicrophoneMute(true);
    widget.myStream.getVideoTracks().first.enabled =
        !widget.myVideoMuted;
    widget.myAudioMuted = true;
    widget.updateVideoState(true);

    setState(() {
      widget._localRenderer.srcObject = widget.myStream;
    });

    var register = {
      "request": "join",
      "room": widget.roomNumber,
      "ptype": "publisher",
      "display": jsonEncode({
        "id": widget.user.sub,
        "timestamp": DateTime.now().millisecondsSinceEpoch,
        "role": "user",
        "display": widget.user.givenName+"\u{1F4F1}"//0xF0 0x9F 0x93 0xB1"
      }) //'User test'
    };
    plugin.send(
        message: register,
        onSuccess: () async {
          var publish = {
            "request": "configure",
            "audio": true,
            "video": true,
            "bitrate": 90000
          };
          RTCSessionDescription offer =
              await plugin.createOffer(offerOptions: {
            "media": {
              "addVideo": true,
              "addAudio": true,
            }
          });
          plugin.send(
              message: publish, jsep: offer, onSuccess: () {});
        });
  }

  // Subscribe to feeds, whether already existing in the room, when I joined
  // or new feeds that join the room when I'm already in. In both cases I
  // should add those feeds to my feeds list.
  // In case of feeds just joined and |question| is set, we should notify the
  // new entering user by notifying everyone.
  // Subscribes selectively to different stream types |subscribeToVideo|, |subscribeToAudio|, |subscribeToData|.
  // This is required to stop and then start only the videos to save bandwidth.
  void makeSubscription(List newFeeds, feedsJustJoined, subscribeToVideo,
      subscribeToAudio, subscribeToData) {
    List<Map> subscription = List<Map>();
    newFeeds.forEach((feed) {
      //const { id, streams } = feed;
      var id = feed["id"];
      streams = feed["streams"];
      LinkedHashMap tempFeed = feed;

      var streamsFound =
          streams.where((v) => v["type"] == 'video' && v["codec"] == 'h264');
      tempFeed.putIfAbsent("video", () => streamsFound);
      tempFeed.putIfAbsent(
          "audio",
          () => streams
              .where((a) => a["type"] == 'audio' && a["type"] == 'opus'));
      tempFeed.putIfAbsent(
          "data", () => streams.where((d) => d["type"] == 'data'));
      tempFeed.putIfAbsent(
          "cammute", () => (feed["video"] == null) ? true : false);

      streams.forEach((stream) {
        if ((subscribeToVideo &&
                stream["type"] == 'video' &&
                stream["codec"] == 'h264') ||
            (subscribeToAudio &&
                stream["type"] == 'audio' &&
                stream["codec"] == 'opus') ||
            (subscribeToData && stream["type"] == 'data')) {
          subscription.add({"feed": id, "mid": stream["mid"]});
        }
      });
    });

    if (subscription.length > 0) {
      //this.
      subscribeTo(subscription);
      // if (feedsJustJoined) {
      // // Send question event for new feed, by notifying the whole room.
      // // FIXME: Can this be done by notifying only the joined feed?
      // setTimeout(() => {
      // if (this.state.cammuted) {
      // const msg = { type: 'client-state', user: this.state.user };
      // if (this.state.msg_protocol == 'mqtt') {
      // mqtt.send(JSON.stringify(msg), false, 'galaxy/room/' + this.state.room);
      // } else {
      // this.chat.sendCmdMessage(msg);
      // }
      // }
      // }, 3000);
      // }
    }
  }

  void subscribeTo(List<Map> subscription) {
    // New feeds are available, do we need create a new plugin handle first?
    FlutterLogs.logInfo("VideoRoom", "subscribeTo",
        "got subscription: ${subscription.toString()}");

    if (widget.subscriberHandle != null) {
      // var register = {
      //   "request": "join",
      //   "room": widget.roomNumber,
      //   "ptype": "subscriber",
      //   "streams": subscription,
      // };
      // widget.subscriberHandle.send(
      //   message: register,
      //   onSuccess: () async {
      //   },
      //   onError: (error) {
      //   },
      // );

      widget.subscriberHandle.send(
        message: {"request": 'subscribe', "streams": subscription},
        onSuccess: () {
          FlutterLogs.logInfo("VideoRoom", "subscribeTo",
              "successfully subscribed to streams: ${subscription.toString()}");
        },
        onError: (error) {
          FlutterLogs.logError("VideoRoom", "subscribeTo",
              "failed to subscribe to streams: ${error.toString()}");
        },
      );
      return;
    }

    // We don't have a handle yet, but we may be creating one already
    if (creatingFeed) {
      // Still working on the handle
      Future.delayed(
          Duration(milliseconds: 500), () => subscribeTo(subscription));
      return;
    }

    // We are not creating the feed, so let's do it.
    creatingFeed = true;
    _newRemoteFeed(widget._janusClient, subscription);
  }

  @override
  Widget build(BuildContext context) {
    final MainStore mainStore = context.read<MainStore>();
    final RoomArguments args = RoomArguments(
        mainStore.activeGateway.url,
        mainStore.activeGateway.token,
        mainStore.activeRoom.room.toInt(),
        mainStore.activeRoom.description,
        mainStore.activeUser,
        mainStore.activeGateway.name);

    // final RoomArguments args = ModalRoute.of(/context).settings.arguments;
    widget.roomNumber = args.roomNumber;
    widget.token = args.token;
    widget.server = args.server;//"https://gxydev.kli.one/janusgxy";//"https://gxydev.kli.one/janusgxy";//
    widget.user = args.user;
    widget.groupName = args.groupName;
    widget.janusName = args.janusName;
    if (widget.pluginHandle == null) {
      // ignore: unnecessary_statements
      // initInfra();
    }
    if (!initialized) {
      initialized = true;
      initInfra();
    }

    final double heightWithoutBars =
        MediaQuery.of(context).size.height
            - kBottomNavigationBarHeight
            - Scaffold.of(context).appBarMaxHeight;
    final double userGridHeight =
        MediaQuery.of(context).orientation == Orientation.portrait
            ? heightWithoutBars / 2
            : heightWithoutBars;
    final double userGridWidth =
        MediaQuery.of(context).orientation == Orientation.portrait
            ? MediaQuery.of(context).size.width
            : (MediaQuery.of(context).size.width / 2);

    final double itemHeight = userGridHeight / 2;
    final double itemWidth = userGridWidth / 2;
    int pageCount = getNumPages(feeds.length);

    FlutterLogs.logInfo(
        "VideoRoom",
        "VideoRoomWidget",
        "### itemWidth: $itemWidth | "
            "### itemHeight: $itemHeight");
    return widget.isFullScreen
        ? Container()
        : Container(
            alignment: Alignment.topCenter,
            height: userGridHeight,
            width: userGridWidth,
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.center,
                  child: GridView.count(
                    childAspectRatio: itemWidth / itemHeight,
                    children: [
                      // Render current user's item.
                      VideoGridItem(
                          videoRenderer: widget._localRenderer,
                          mirrorVideo: true,
                          displayName: widget.user.givenName ?? "",
                          itemWidth: itemWidth,
                          itemHeight: itemHeight,
                          shouldShowVideo: !widget.myVideoMuted,
                          isTalking: !widget.myAudioMuted,
                          hasQuestion: widget.isQuestion,
                          connectivitySignalStrength: signal),
                      // Render friends' items.
                      ...([0, 1, 2].map((slotIndex) {
                        RTCVideoRenderer slotRenderer = widget._remoteRenderers?.elementAt(slotIndex);
                        var slotFeed = feeds?.firstWhere((element) => element["videoSlot"] == slotIndex, orElse: () => null);
                        if (slotRenderer?.srcObject == null || slotFeed == null) {
                          return Container();
                        }

                        return VideoGridItem(
                          videoRenderer: slotRenderer,
                          displayName:  slotFeed["display"]["display"] ?? "",
                          shouldShowVideo: slotFeed["cammute"] == false && !muteOtherCams,
                          itemWidth: itemWidth,
                          itemHeight: itemHeight,
                          isTalking: slotFeed["talking"] == true,
                          hasQuestion: slotFeed["question"] == true);
                      }).toList()),
                    ],
                    primary: false,
                    padding: const EdgeInsets.all(0),
                    crossAxisSpacing: 0,
                    mainAxisSpacing: 0,
                    crossAxisCount: 2,
                  )
                ),
                if (pageCount > 1) Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    color: Colors.blue,
                    icon: DirectionalChild(
                        ltrChildBuilder: (context) => Icon(Icons.arrow_forward),
                        rtlChildBuilder: (context) => Icon(Icons.arrow_back)
                    ),
                    onPressed: () => switchPage(page + 1),
                  ),
                ),
                if (pageCount > 1) Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    color: Colors.blue,
                    icon: DirectionalChild(
                      ltrChildBuilder: (context) => Icon(Icons.arrow_back),
                      rtlChildBuilder: (context) => Icon(Icons.arrow_forward)
                    ),
                    onPressed: () => switchPage(page - 1),
                  ),
                ),

              ],
            ),
          );
  }

  void unsubscribeFrom(List ids, bool onlyVideo) {
    Set idsSet = new Set();
    idsSet.addAll(ids);
    var unsubscribe = {"request": 'unsubscribe', "streams": []};
    feeds.forEach((feed) {
      var isFeedFound = idsSet.any((id) => feed["id"] == id);
      if (isFeedFound == true) {
        var feedFound = idsSet.firstWhere((id) => feed["id"] == id);
        var feedToHandle =
            feeds.firstWhere((element) => element["id"] == feedFound);
        if (onlyVideo) {
          // Unsubscribe only from one video stream (not all publisher feed).
          // Acutally expecting only one video stream, but writing more generic code.
          (feedToHandle["streams"] as List)
              .where((stream) => stream["type"] == 'video')
              .map((stream) => ({"feed": feedFound, "mid": stream["mid"]}))
              .forEach(
                  (stream) => (unsubscribe["streams"] as List).add(stream));
        } else {
          // Unsubscribe the whole feed (all it's streams).
          (unsubscribe["streams"] as List).add({"feed": feedFound});
          //Janus.log('Unsubscribe from Feed ' + JSON.stringify(feed) + ' (' + feed.id + ').');
        }
      }
    });
    // Send an unsubscribe request.

    if (widget.subscriberHandle != null &&
        (unsubscribe["streams"] as List) != null &&
        (unsubscribe["streams"] as List).length > 0) {
      FlutterLogs.logInfo("VideoRoom", "unsubscribeFrom",
          "unsubscribe streams: ${unsubscribe.toString()}");
      widget.subscriberHandle.send(
          message: unsubscribe,
          onSuccess: () {
            FlutterLogs.logInfo("VideoRoom", "unsubscribeFrom",
                "unsubscribed successfully: ${unsubscribe.toString()}");
            if ((widget.state).mounted) setState(() {});
          },
          onError: (error) {
            FlutterLogs.logError("VideoRoom", "unsubscribeFrom",
                "unsubscribe failed: ${error.toString()}");
          });
    }
  }

  void switchVideoSlots(int from, int to) {
    fromVideoIndex = from - page * PAGE_SIZE;
    toVideoIndex = to - page * PAGE_SIZE;

    //switch current video items RTCVideo with the correct index
    // const stream = fromRemoteVideo.srcObject;
    // Janus.log(`Switching stream from ${from} to ${to}`, stream, fromRemoteVideo, toRemoteVideo);
    // Janus.attachMediaStream(toRemoteVideo, stream);
    // Janus.attachMediaStream(fromRemoteVideo, null);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.inactive:
        FlutterLogs.logInfo(
            "videoRoom", "didChangeAppLifecycleState", 'inactive');
        // if (!widget.myVideoMuted) {
          FlutterLogs.logInfo(
              "videoRoom", "didChangeAppLifecycleState",
              'number of video tracks = ${widget.myStream
                  .getVideoTracks()
                  .length}');
          widget.myStream
              .getVideoTracks()
              .first
              .enabled = false;
          setState(() {
            widget.myVideoMuted = true;
            widget.updateVideoState(true);
          });

          widget.updateGoingToBackground();
        // }

        break;
      case AppLifecycleState.resumed:
        FlutterLogs.logInfo(
            "videoRoom", "didChangeAppLifecycleState", 'resumed');
        FlutterLogs.logInfo("videoRoom", "didChangeAppLifecycleState",
            'pluginHandle is present = ${widget.pluginHandle != null}');
        stopForegroundService();
        restartSelfVideo();

        break;
      case AppLifecycleState.paused:
        FlutterLogs.logInfo(
            "videoRoom", "didChangeAppLifecycleState", 'paused');
        startForegroundService();

        break;
      case AppLifecycleState.detached:
        FlutterLogs.logInfo(
            "videoRoom", "didChangeAppLifecycleState", 'detached');
        stopForegroundService();
        break;
    }
  }

  Future<void> updateGxyUser(context, userData) async {
    userData["room"] = widget.roomNumber;
    userData["camera"] = widget.myVideoMuted;
    userData["group"] = widget.groupName;
    userData["role"] = "user";
    userData["janus"] = widget.janusName;
    userData["system"] = Platform.isAndroid ? "Android" : "iOS";
    userData["ip"] = await printIps();
    userData["country"] = Platform.localeName;
    userData["session"] = widget._janusClient.sessionId;
    userData["handle"] = widget.pluginHandle.handleId;
    userData["extra"] = {};
    userData["extra"]["streams"]= json.decode(widget.configuredStreams);
    print("## extra = ${widget.configuredStreams}");
    widget.updateGlxUserCB(userData);
  }

  Future<String> printIps() async {
    for (var interface in await NetworkInterface.list()) {
      print('== Interface: ${interface.name} ==');
      for (var addr in interface.addresses) {
        print(
            '${addr.address} ${addr.host} ${addr.isLoopback} ${addr.rawAddress} ${addr.type.name}');
        return addr.address;
      }
    }
  }

  void toggleAudioMode() {
    FlutterLogs.logInfo(
        "videoRoom", "toggleAudioMode", 'changing to ${!muteOtherCams}');
    var activeFeeds = feeds.where((feed) => feed["videoSlot"] != null).toList();
    if (!muteOtherCams) {
// Should hide/mute now all videos.
      switcher.muteOtherCams = true;
      muteOtherCams = true;
      // widget.myStream.getVideoTracks().first.enabled = false;
      // widget.myVideoMuted = true;
      switcher.unsubscribeFrom(
          activeFeeds.map((feed) => feed["id"]).toList(),
/* onlyVideo= */ true);
    } else {
      switcher.muteOtherCams = false;
      muteOtherCams = false;
      // widget.myStream.getVideoTracks().first.enabled = true;
      // widget.myVideoMuted = false;
// Should unmute/show now all videos.false,
      switcher.makeSubscription(
          activeFeeds,
/* feedsJustJoined= */ false,
/* subscribeToVideo= */ true,
/* subscribeToAudio= */ false,
/* subscribeToData= */ false);
//       switcher.switchVideos(this.page, feeds, feeds);

    }
    setState(() {});
  }

  void restartSelfVideo() async {
    FlutterLogs.logInfo("VideoRoom", "restartSelfVideo", "entering");
     Timer(Duration(seconds: 1), () {
       prepareAndRegisterMyStreamRecovery(widget.pluginHandle);
    });
  }

  void removeSelfVideo() {
    removeMyStreamWhenInBackground(widget.pluginHandle);
  }

  Future removeMyStreamWhenInBackground(Plugin plugin) async {
    if (widget.myStream?.getTracks() != null) {
      widget.myStream.getTracks().forEach((element) {
        element.enabled = false;
        element.stop();
      });
    }
    var publish = {
      "request": "configure",
    };
    RTCSessionDescription offer = await plugin.createOffer(offerOptions: {
      //  "mandatory":{
      // "audioRecv": false,
      // "videoRecv": false,
      // "audioSend": true,
      // "videoSend": true,
      // }
      "media": {
        "removeVideo": true,
        // "removeAudio": true,
      }
    });
    plugin.send(
      message: publish, jsep: offer, onSuccess: () {
      print("xxxz plugin offer success");
    }, onError: (error) {
      print("xxxz plugin offer error: ${error}");
    });
  }
}

class RoomArguments {
  final String janusName;
  final String server;
  final String token;
  final int roomNumber;
  final String groupName;
  final User user;
  RoomArguments(this.server, this.token, this.roomNumber, this.groupName,
      this.user, this.janusName);
}

class VideoGridItem extends StatelessWidget {
  final RTCVideoRenderer videoRenderer;
  final bool shouldShowVideo;
  final String displayName;
  final double itemWidth;
  final double itemHeight;
  final bool mirrorVideo;
  final bool isTalking;
  final bool hasQuestion;
  // If null, will not show signal strength.
  final String connectivitySignalStrength;

  VideoGridItem({
    @required this.videoRenderer,
    @required this.shouldShowVideo,
    @required this.displayName,
    @required this.itemWidth,
    @required this.itemHeight,
    this.mirrorVideo = false,
    this.isTalking = false,
    this.hasQuestion = false,
    this.connectivitySignalStrength
  }) : assert(videoRenderer != null),
       assert(shouldShowVideo != null),
       assert(displayName != null),
       assert(itemWidth != null),
       assert(itemHeight != null),
       assert(mirrorVideo != null),
       assert(isTalking != null),
       assert(hasQuestion != null);

  Widget build(BuildContext context) {
    return Container(
      height: itemHeight,
      decoration: BoxDecoration(
        // If talking, change border color.
        border: Border.all(
            color: isTalking
                ? Colors.lightGreen
                : Colors.black)
      ),
      child: Stack(
        children: [
          // Render the stream or show an icon.
          shouldShowVideo
              ? RTCVideoView(videoRenderer, mirror: mirrorVideo)
              : Align(
            alignment: Alignment.center,
            child: Icon(
              Icons.account_circle,
              color: Colors.white,
              size: min(itemHeight, itemWidth) - 60,
            ),
          ),
          // Render label
          Align(
            alignment: Alignment.bottomLeft,
            child: Row(
              children: [
                Icon(
                  Icons.mic_off,
                  color: isTalking
                      ? Colors.transparent
                      : Colors.red,
                  size: 18,
                ),
                Text(displayName),
                if (connectivitySignalStrength != null) Icon(
                  Mdi.signal,
                  size: 15,
                  color: connectivitySignalStrength == "good"
                      ? Colors.white
                      : Colors.red
                )
              ],
            ),
          ),
          // Show the question mark
          Align(
            alignment: Alignment.topRight,
            child: Container(
              margin: const EdgeInsets.only(top: 8.0, right: 8.0),
              child: Icon(
                Icons.live_help_rounded,
                color: hasQuestion
                    ? Colors.red
                    : Colors.transparent,
                size: 50,
              )
            )
          )
        ]
      )
    );
  }
}