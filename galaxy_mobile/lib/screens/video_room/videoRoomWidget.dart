import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:dots_indicator/dots_indicator.dart';
import 'package:flutter/material.dart';
import 'package:galaxy_mobile/models/mainStore.dart';
import 'package:galaxy_mobile/services/keycloak.dart';
import 'package:galaxy_mobile/services/monitoring_data.dart';
import 'package:galaxy_mobile/services/monitoring_isolate.dart';
import 'package:galaxy_mobile/utils/switch_page_helper.dart';
import 'package:janus_client/janus_client.dart';
import 'package:janus_client/utils.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:janus_client/Plugin.dart';
import 'package:provider/provider.dart';
import 'package:flutter_logs/flutter_logs.dart';
import 'package:flutter/services.dart';

import 'dart:async';

import 'package:synchronized/synchronized.dart';

import '../../foreground.dart';

typedef BoolCallback = Function(bool);
typedef UpdateUserCallback = Function(Map<String, dynamic> user);
final int PAGE_SIZE = 3;

class VideoRoom extends StatefulWidget {
  List<RTCVideoView> remote_videos = new List();
  String server;
  String token;
  int roomNumber;
  VoidCallback callExitRoomUserExists;
  UpdateUserCallback updateGlxUserCB;
  User user;

  JanusClient j;
  RTCVideoRenderer _localRenderer = new RTCVideoRenderer();
  List<RTCVideoRenderer> _remoteRenderer = new List<RTCVideoRenderer>();
  Plugin pluginHandle;
  Plugin subscriberHandle;
  bool myAudioMuted = false;
  bool myVideoMuted = false;
  bool isQuestion = false;

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

  void exitRoom() {
    if (j != null) j.destroy();
    if (pluginHandle != null) pluginHandle.hangup();
    if (subscriberHandle != null) subscriberHandle.destroy();
    if (_localRenderer != null) {
      _localRenderer.srcObject = null;
      // _localRenderer.dispose();
    }
    if (_remoteRenderer != null && _remoteRenderer.isNotEmpty) {
      _remoteRenderer.map((e) => e.srcObject = null);
      //_remoteRenderer.map((e) => e.dispose());
    }
    pluginHandle = null;
    subscriberHandle = null;
    questionInRoom = null;
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
    else
      myAudioMuted = !myAudioMuted;
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
    FlutterLogs.logInfo("VideoRoom", "setUserState", "user ${user.toString()}");
    List roomFeeds = state.getFeeds();
    for (var feed in roomFeeds) {
      if (feed != null && feed['id'] == user['rfid']) {
        FlutterLogs.logInfo("VideoRoom", "setUserState", "found user in feed");
        feed['cammute'] = !user['camera'];
        feed['question'] = user['question'];
        setUserQuestionInRoom(user);
        if (state != null) {
          state.setState(() {});
        }
        break;
      } else
        FlutterLogs.logInfo("VideoRoom", "setUserState", "could not find user");
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

  int tempConter = 0;

  List streams;

  bool creatingFeed = false;

  List feeds = List.empty();

  List newStreamsMids = List.empty(growable: true);

  bool muteOtherCams = false;

  int page = 0;

  bool initialized = false;

  int fromVideoIndex;

  int toVideoIndex;

  SendPort mainToIsolateStream;

  set id(id) {}

  set subscription(List subscription) {}

  SwitchPageHelper switcher;

  List getFeeds() {
    return feeds;
  }

  @override
  void didChangeDependencies() async {
    // TODO: implement didChangeDependencies
    super.didChangeDependencies();
  }

  @override
  void initState() {
    super.initState();
    final s = context.read<MainStore>();
    muteOtherCams = s.audioMode;
    WidgetsBinding.instance.addObserver(this);
    switcher = SwitchPageHelper(unsubscribeFrom, makeSubscription,
        switchVideoSlots, PAGE_SIZE, muteOtherCams);
    widget.state = this;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> initInfra() async {
    await initRenderers();
    await initPlatformState();
  }

  Future<void> initRenderers() async {
    int count = 0;
    while (count < 3) {
      widget._remoteRenderer.add(new RTCVideoRenderer());
      count++;
    }
    await widget._localRenderer.initialize();
    for (var renderer in widget._remoteRenderer) {
      await renderer.initialize();
    }
  }

  void switchPage(int page) {
    // Normalize page, e.g., if it is -1 or too large...
    FlutterLogs.logInfo(
        "VideoRoom", "switchPage", "switch page to: ${page.toString()}");
    int numPages = (feeds.length / PAGE_SIZE).ceil();
    this.page = numPages == 0 ? 0 : (numPages + page) % numPages;
    switcher.switchVideos(this.page, feeds, feeds);
  }

  sortAndFilterFeeds(List feeds) => feeds
      .where((feed) => !feed["display"]["role"].match("/^(ghost|guest)"))
      .toList()
      .sort((a, b) => a["display"]["timestamp"] - b["display"]["timestamp"]);

  userFeeds(feeds) => feeds.map((feed) => feed["display"]["role"] == 'user');

  _newRemoteFeed(JanusClient j, List<Map> feeds) async {
    roomFeeds = feeds;
    FlutterLogs.logInfo(
        "VideoRoom", "_newRemoteFeed", "remote plugin attached");
    j.attach(Plugin(
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
                jsep: await widget.subscriberHandle.createAnswer(),
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
              widget.RoomReady();
            },
            onError: (error) {
              FlutterLogs.logError("VideoRoom", "_newRemoteFeed",
                  "subscription to publishers FAILED: ${error.toString()}");
            },
          );
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
                    widget._remoteRenderer.elementAt(slot).trackIndex =
                        trackIndex;
                    widget._remoteRenderer.elementAt(slot).srcObject =
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
                      // if (widget._remoteRenderer.elementAt(index).trackIndex !=
                      //     element["trackIndex"]) {
                      //   widget._remoteRenderer.elementAt(index).trackIndex =
                      //       element["trackIndex"];
                      //   widget._remoteRenderer.elementAt(slot).srcObject =
                      //       stream;
                      // }
                    });
                    // switch (otherFeeds.length) {
                    //   case 0:
                    //     widget._remoteRenderer.elementAt(0).srcObject = null;
                    //     widget._remoteRenderer.elementAt(1).srcObject = null;
                    //     widget._remoteRenderer.elementAt(2).srcObject = null;
                    //     break;
                    //   case 1:
                    //     widget._remoteRenderer.elementAt(1).srcObject = null;
                    //     widget._remoteRenderer.elementAt(2).srcObject = null;
                    //     break;
                    //   // case 2:
                    //   //   widget._remoteRenderer.elementAt(2).srcObject = null;
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
        }));
  }

  Future<void> initPlatformState() async {
    setState(() {
      widget.j = JanusClient(iceServers: [
        RTCIceServer(
            url: "stun:galaxy.kli.one:3478", username: "", credential: ""),
      ], server: [
        widget.server,
      ], withCredentials: true, isUnifiedPlan: true, token: widget.token);
      widget.j.connect(onSuccess: (sessionId) async {
        FlutterLogs.logInfo(
            "VideoRoom",
            "initPlatformState",
            "voila! connection established with session id as "
                "${sessionId.toString()}");
        // Map<String, dynamic> configuration = {
        //   "iceServers": widget.j.iceServers.map((e) => e.toMap()).toList()
        // };

        widget.j.attach(Plugin(
            opaqueId: widget.user.sub,
            plugin: 'janus.plugin.videoroom',
            onMessage: (msg, jsep) async {
              var event = msg['videoroom'];
              if (event != null) {
                if (event == 'joined') {
                  updateGxyUser(context, widget.user.toJson());

                  // widget._onUpdateVideoStateCallback();
                  widget.myid = msg["id"];
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
                        widget.callExitRoomUserExists();
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

                    feeds = newFeedsState;
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
                      "user ${id.toString()} - stop talking");
                  final feed = feeds.firstWhere((feed) => feed["id"] == id,
                      orElse: () => null);
                  if (feed == null) {
                    FlutterLogs.logWarn("VideoRoom", "initPlatformState",
                        "user ${id.toString()} not found");
                    return;
                  }
                  setState(() {
                    feed["talking"] = true;
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
                        "VideoRoom", "initPlatformState", "configured");
                    // User published own feed successfully.
                    // const user = {
                    //   ...this.state.user,
                    //   extra: {
                    //     ...(this.state.user.extra || {}),
                    //     streams: msg.streams
                    //   }
                    // };
                    // this.setState({ user });
                    // if (this.state.muteOtherCams) {
                    //   this.camMute(/* cammuted= */ false);
                    //   this.setState({ videos: NO_VIDEO_OPTION_VALUE });
                    //   this.state.virtualStreamingJanus.setVideo(NO_VIDEO_OPTION_VALUE);
                    // }
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
                        feedsNewState,
                        /* feedsJustJoined= */ true,
                        /* subscribeToVideo= */ false,
                        /* subscribeToAudio= */ true,
                        /* subscribeToData= */ true);
                    switcher.switchVideos(
                        /* page= */ page,
                        feeds,
                        feedsNewState);
                    feeds = feedsNewState;
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
                    feeds = feedsNewState;
                    // this.setState({ feeds: feedsNewState }, () => {
                    if (page * PAGE_SIZE == feeds.length) {
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
              widget.pluginHandle = plugin;
              MediaStream stream = await plugin.initializeMediaDevices();
              widget.myStream = stream;
              widget.myStream.getAudioTracks().first.setMicrophoneMute(true);
              widget.myStream.getVideoTracks().first.enabled =
                  widget.myVideoMuted;
              widget.myAudioMuted = true;
              widget.updateVideoState(true);
              // });
              setState(() {
                widget._localRenderer.srcObject = widget.myStream;
              });
              //==> chat room can not added - infra does not support it yet == try to enter chat room, if user already exists then exit with error
              // widget.j.attach(Plugin(
              //     plugin: "janus.plugin.textroom",
              //     opaqueId: widget.user.id,
              //     onSuccess: (pluginHandle) {
              //       var request = {"request": "setup"};
              //       widget.chatHandle = pluginHandle;
              //       widget.chatHandle.send(
              //           message: request,
              //           onSuccess: () {
              //             FlutterLogs.logInfo("VideoRoom", "chatroom",
              //                 "successfully subscribed to chatroom");
              //           },
              //           onError: (err) {
              //             if (err == 420) {
              //               //user already in room
              //               showDialog(
              //                   context: context,
              //                   child: AlertDialog(
              //                     title: Text("User Already In Room"),
              //                   ));
              //               widget.exitRoom();
              //             }
              //           });
              //     },
              //     onError: (err){
              // FlutterLogs.logInfo("VideoRoom", "chatroom",
              // "error subscribed to chatroom ${err.toString()}");
              // }));
              var register = {
                "request": "join",
                "room": widget.roomNumber,
                "ptype": "publisher",
                "display": jsonEncode({
                  "id": widget.user.sub,
                  "timestamp": DateTime.now().millisecondsSinceEpoch,
                  "role": "user",
                  "display": widget.user.givenName
                }) //'User test'
              };
              plugin.send(
                  message: register,
                  onSuccess: () async {
                    var publish = {
                      "request": "configure",
                      "audio": true,
                      "video": true,
                      "bitrate": 2000000
                    };
                    RTCSessionDescription offer =
                        await plugin.createOffer(offerOptions: {
                      "mandatory": {
                        "OfferToReceiveAudio": true,
                        "OfferToReceiveVideo": true,
                      }
                    });
                    plugin.send(
                        message: publish, jsep: offer, onSuccess: () {});
                  });
            },
            slowLink: (uplink, lost, mid) {
              FlutterLogs.logWarn("VideoRoom", "plugin: janus.plugin.videoroom",
                  "slowLink: uplink ${uplink} lost ${lost} mid ${mid}");
            }));
      }, onError: (e) {
        FlutterLogs.logError("VideoRoom", "plugin: janus.plugin.videoroom",
            "some error occurred: ${e.toString()}");
      });
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
    _newRemoteFeed(widget.j, subscription);
  }

  // Unsubscribe from feeds defined by |ids| (with all streams) and remove it when |onlyVideo| is false.
  // If |onlyVideo| is true, will unsubscribe only from video stream of those specific feeds, keeping those feeds.
  // void unsubscribeFrom(ids, onlyVideo) {
  // const { feeds/*, feedStreams, index*/ } = this.state;
  // const idsSet                            = new Set(ids);
  // const unsubscribe                       = { request: 'unsubscribe', streams: [] };
  // feeds.filter(feed => idsSet.has(feed.id)).forEach(feed => {
  // if (onlyVideo) {
  // // Unsubscribe only from one video stream (not all publisher feed).
  // // Acutally expecting only one video stream, but writing more generic code.
  // feed.streams.filter(stream => stream.type === 'video')
  //     .map(stream => ({ feed: feed.id, mid: stream.mid }))
  //     .forEach(stream => unsubscribe.streams.push(stream));
  // } else {
  // // Unsubscribe the whole feed (all it's streams).
  // unsubscribe.streams.push({ feed: feed.id });
  // Janus.log('Unsubscribe from Feed ' + JSON.stringify(feed) + ' (' + feed.id + ').');
  // }
  // });
  // // Send an unsubscribe request.
  // const { remoteFeed } = this.state;
  // if (remoteFeed !== null && unsubscribe.streams.length > 0) {
  // remoteFeed.send({ message: unsubscribe });
  // }
  // }

  void switchVideos(int page, List oldFeeds, List newFeeds) {
    FlutterLogs.logInfo(
        "VideoRoom",
        "switchVideos",
        "switchVideos >> page: ${page.toString()} | "
            "pageSize: ${PAGE_SIZE.toString()} | "
            "old feeds: ${oldFeeds.length.toString()} | "
            "new feeds: ${newFeeds.length.toString()}");

    List oldVideoSlots = List();
    for (int index = 0; index < PAGE_SIZE; index++) {
      oldVideoSlots
          .add(oldFeeds.indexWhere((feed) => feed["videoSlot"] == index));
    }

    List oldVideoFeeds = oldFeeds.isNotEmpty
        ? oldVideoSlots
            .map((slot) => slot != -1 ? oldFeeds.elementAt(slot) : null)
            .toList()
        : List.empty();

    List newVideoSlots = List();
    for (int index = 0; index < PAGE_SIZE; index++) {
      newVideoSlots.add((page * PAGE_SIZE) + index >= newFeeds.length
          ? -1
          : (page * PAGE_SIZE) + index);
    }

    FlutterLogs.logInfo(
        "VideoRoom",
        "switchVideos",
        "oldVideoSlots: ${oldVideoSlots.toString()} | "
            "newVideoSlots: ${newVideoSlots.toString()}");

    List newVideoFeeds = newVideoSlots
        .map((index) => {if (index != -1) newFeeds.elementAt(index)})
        .toList();

    oldVideoFeeds.isNotEmpty
        ? oldVideoFeeds.forEach((feed) {
            if (feed != null) {
              feed["videoSlot"] = null;
            }
          })
        : null;

    newVideoFeeds.isNotEmpty
        ? newVideoFeeds.asMap().forEach((index, feed) {
            if (feed != null) feed["videoSlot"] = index;
          })
        : null;

    FlutterLogs.logInfo(
        "VideoRoom",
        "switchVideos",
        "oldVideoSlots: ${oldVideoSlots.toString()} | "
            "newVideoSlots: ${newVideoSlots.toString()}");
    // Cases:
    // old: [0, 1, 2] [f0, f1, f2], new: [3, 4, 5] [f3, f4, f5]                  Simple next page switch.
    // old: [3, 4, 5] [f3, f4, f5], new: [0, 1, 2] [f0, f1, f2]                  Simple prev page switch.
    // old: [-1, -1, -1] [null, null, null], new: [0, -1, -1] [f0, null, null]   First user joins.
    // old: [0, -1, -1] [f0, null, null], new: [0, 1, -1] [f0, f1, null]         Second user joins.
    // old: [3, 4, 5] [f3, f4, f5], new: [3, 4, 5] [f3, f5, f6]                  User f4 left.
    // old: [3, 4, 5] [f3, f4, f5], new: [3, 4, 5] [f3, fX, f4]                  User fX joins.

    List subscribeFeeds = [];
    List unsubscribeFeeds = [];
    List switchFeeds = [];
    newVideoFeeds.forEach((newFeed) {
      if (newFeed != null &&
          !oldVideoFeeds.any(
            (oldFeed) => oldFeed != null && oldFeed["id"] == newFeed["id"],
          )) {
        subscribeFeeds.add(newFeed);
      }
    });

    if (oldVideoFeeds.isNotEmpty) {
      oldVideoFeeds.forEach((oldFeed) {
        if (oldFeed != null &&
            newVideoFeeds.any((newFeed) =>
                newFeed != null && newFeed["id"] != oldFeed["id"])) {
          unsubscribeFeeds.add(oldFeed);
        }
      });
      oldVideoFeeds.asMap().forEach((oldIndex, oldFeed) {
        if (oldFeed != null) {
          int newIndex = newVideoFeeds.indexWhere(
              (newFeed) => newFeed != null && newFeed["id"] == oldFeed["id"]);
          if (newIndex != -1 && oldIndex != newIndex) {
            switchFeeds.add({
              "from": oldVideoSlots[oldIndex],
              "to": newVideoSlots[newIndex]
            });
          }
        }
      }); //forEach((oldFeed, oldIndex) => {
    }

    if (!muteOtherCams) {
      FlutterLogs.logInfo(
          "VideoRoom",
          "switchVideos",
          "subscribeFeeds: ${subscribeFeeds.toString()} | "
              "unsubscribeFeeds: ${unsubscribeFeeds.toString()} | "
              "switchFeeds: ${switchFeeds.toString()}");

      this.makeSubscription(
          subscribeFeeds,
          /* feedsJustJoined= */ false,
          /* subscribeToVideo= */ true,
          /* subscribeToAudio= */ false,
          /* subscribeToData= */ false);
      this.unsubscribeFrom(
          unsubscribeFeeds.map((feed) => feed["id"]).toList(),
          /* onlyVideo= */ true);
      switchFeeds.forEach((element) {
        this.switchVideoSlots(element["from"], element["to"]);
      }); //first(({ from, to }) => this.switchVideoSlots(from, to));
    } else {
      FlutterLogs.logWarn("VideoRoom", "switchVideos",
          "ignoring subscribe/unsubscribe/switch; other cams on mute mode");
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.read<MainStore>();
    final args = RoomArguments(
        s.activeGateway.url,
        s.activeGateway.token,
        s.activeRoom.room.toInt(),
        s.activeRoom.description,
        s.activeUser,
        s.activeGateway.name);

    // final RoomArguments args = ModalRoute.of(/context).settings.arguments;
    widget.roomNumber = args.roomNumber;
    widget.token = args.token;
    widget.server = args.server;
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
      Map<String, dynamic> userJson = widget.user.toJson();
      userJson["room"] = widget.roomNumber;
      userJson["group"] = "Test Room";
      initIsolate(context).then((value) => {
            mainToIsolateStream = value,
            mainToIsolateStream.send({
              "type": 'setConnection',
              "user": userJson,
              // "userExtra": {},
              // "data": {}
            }),
            mainToIsolateStream.send({"type": "start"})
          });
    }

    final double userGridHeight =
        MediaQuery.of(context).orientation == Orientation.portrait
            ? (MediaQuery.of(context).size.height / 3 * 2 - 140)
            : (MediaQuery.of(context).size.height);

    final double userGridWidth =
        MediaQuery.of(context).orientation == Orientation.portrait
            ? MediaQuery.of(context).size.width
            : (MediaQuery.of(context).size.width / 2);

    final double itemHeight = userGridHeight / 2;
    final double itemWidth = userGridWidth / 2;

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
                GridView.count(
                  childAspectRatio:
                      MediaQuery.of(context).orientation == Orientation.portrait
                          ? (itemWidth / itemHeight)
                          : (itemHeight / itemWidth),
                  children: [
                    Container(
                      decoration: BoxDecoration(
                          border: Border.all(
                              color: (widget.myAudioMuted != true)
                                  ? Colors.lightGreen
                                  : Colors.black)), //Colors.lightGreenAccent
                      child: Stack(
                        children: [
                          (widget.myVideoMuted)
                              ? RTCVideoView(widget._localRenderer)
                              : Align(
                                  alignment: Alignment.center,
                                  child: Icon(Icons.account_circle,
                                      color: Colors.white,
                                      size: itemWidth - 60)),
                          Align(
                            alignment: Alignment.bottomLeft,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.mic_off,
                                  color: (widget.myAudioMuted != true)
                                      ? Colors.transparent
                                      : Colors.red,
                                  size: 18,
                                ),
                                SizedBox(width: 5),
                                Text(widget.user.givenName),
                              ],
                            ),
                          ),
                          Align(
                              alignment: Alignment.topRight,
                              child: Container(
                                  margin: const EdgeInsets.only(
                                      top: 8.0, right: 8.0),
                                  child: Icon(
                                    Icons.live_help_rounded,
                                    color: widget.isQuestion
                                        ? Colors.red
                                        : Colors.transparent,
                                    size: 50,
                                  )))
                        ],
                      ),
                    ),
                    (widget._remoteRenderer != null &&
                            widget._remoteRenderer.elementAt(0) != null &&
                            widget._remoteRenderer.elementAt(0).srcObject !=
                                null &&
                            feeds.any((element) => element["videoSlot"] == 0))
                        ? Container(
                            decoration: BoxDecoration(
                                border: Border.all(
                                    color: (feeds.firstWhere((element) =>
                                                    element["videoSlot"] ==
                                                    0)["talking"] !=
                                                null &&
                                            feeds.firstWhere((element) =>
                                                    element["videoSlot"] ==
                                                    0)["talking"] ==
                                                true)
                                        ? Colors.lightGreen
                                        : Colors.black)),
                            child: Stack(children: [
                              (feeds.firstWhere((element) =>
                                              element["videoSlot"] ==
                                              0)["cammute"] ==
                                          false &&
                                      !muteOtherCams)
                                  // (true)
                                  // (widget._remoteRenderer
                                  //         .elementAt(0)
                                  //         .srcObject
                                  //         .getVideoTracks()
                                  //         .elementAt(widget._remoteRenderer
                                  //             .elementAt(0)
                                  //             .trackIndex)
                                  //         .enabled)
                                  ? RTCVideoView(
                                      widget._remoteRenderer.elementAt(0))
                                  : Align(
                                      alignment: Alignment.center,
                                      child: Icon(
                                        Icons.account_circle,
                                        color: Colors.white,
                                        size: itemWidth - 60,
                                      ),
                                    ),
                              Align(
                                alignment: Alignment.bottomLeft,
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.mic_off,
                                      color: (feeds.firstWhere((element) =>
                                                      element["videoSlot"] ==
                                                      0)["talking"] !=
                                                  null &&
                                              feeds.firstWhere((element) =>
                                                      element["videoSlot"] ==
                                                      0)["talking"] ==
                                                  true)
                                          ? Colors.transparent
                                          : Colors.red,
                                      size: 18,
                                    ),
                                    Text((feeds.isNotEmpty &&
                                            feeds.any((element) =>
                                                element["videoSlot"] == 0))
                                        ? feeds.firstWhere((element) =>
                                            element["videoSlot"] ==
                                            0)["display"]["display"]
                                        : ""),
                                  ],
                                ),
                              ),
                              Align(
                                  alignment: Alignment.topRight,
                                  child: Container(
                                      margin: const EdgeInsets.only(
                                          top: 8.0, right: 8.0),
                                      child: Icon(
                                        Icons.live_help_rounded,
                                        color: (feeds.firstWhere((element) =>
                                                        element["videoSlot"] ==
                                                        0)["question"] !=
                                                    null &&
                                                feeds.firstWhere((element) =>
                                                        element["videoSlot"] ==
                                                        0)["question"] ==
                                                    true)
                                            ? Colors.red
                                            : Colors.transparent,
                                        size: 50,
                                      )))
                            ]))
                        : Container(),

                    (widget._remoteRenderer != null &&
                            widget._remoteRenderer.elementAt(1) != null &&
                            widget._remoteRenderer.elementAt(1).srcObject !=
                                null &&
                            feeds.any((element) => element["videoSlot"] == 1))
                        ? Container(
                            decoration: BoxDecoration(
                                border: Border.all(
                                    color: (feeds.firstWhere((element) =>
                                                    element["videoSlot"] ==
                                                    1)["talking"] !=
                                                null &&
                                            feeds.firstWhere((element) =>
                                                    element["videoSlot"] ==
                                                    1)["talking"] ==
                                                true)
                                        ? Colors.lightGreen
                                        : Colors.black)),
                            child: Stack(
                              children: [
                                (feeds.firstWhere((element) =>
                                                element["videoSlot"] ==
                                                1)["cammute"] ==
                                            false &&
                                        !muteOtherCams)
                                    // (widget._remoteRenderer
                                    //         .elementAt(1)
                                    //         .srcObject
                                    //         .getVideoTracks()
                                    //         .elementAt(widget._remoteRenderer
                                    //             .elementAt(1)
                                    //             .trackIndex)
                                    //         .enabled)
                                    ? RTCVideoView(
                                        widget._remoteRenderer.elementAt(1))
                                    : Align(
                                        alignment: Alignment.center,
                                        child: Icon(
                                          Icons.account_circle,
                                          color: Colors.white,
                                          size: itemWidth - 60,
                                        ),
                                      ),
                                Align(
                                  alignment: Alignment.bottomLeft,
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.mic_off,
                                        color: (feeds.firstWhere((element) =>
                                                        element["videoSlot"] ==
                                                        1)["talking"] !=
                                                    null &&
                                                feeds.firstWhere((element) =>
                                                        element["videoSlot"] ==
                                                        1)["talking"] ==
                                                    true)
                                            ? Colors.transparent
                                            : Colors.red,
                                        size: 18,
                                      ),
                                      Text((feeds.isNotEmpty &&
                                              feeds.any((element) =>
                                                  element["videoSlot"] == 1))
                                          ? feeds.firstWhere((element) =>
                                              element["videoSlot"] ==
                                              1)["display"]["display"]
                                          : ""),
                                    ],
                                  ),
                                ),
                                Align(
                                    alignment: Alignment.topRight,
                                    child: Container(
                                        margin: const EdgeInsets.only(
                                            top: 8.0, right: 8.0),
                                        child: Icon(
                                          Icons.live_help_rounded,
                                          color: (feeds.firstWhere((element) =>
                                                          element[
                                                              "videoSlot"] ==
                                                          1)["question"] !=
                                                      null &&
                                                  feeds.firstWhere((element) =>
                                                          element[
                                                              "videoSlot"] ==
                                                          1)["question"] ==
                                                      true)
                                              ? Colors.red
                                              : Colors.transparent,
                                          size: 50,
                                        )))
                              ],
                            ))
                        : Container(),
                    (widget._remoteRenderer != null &&
                            widget._remoteRenderer.elementAt(2) != null &&
                            widget._remoteRenderer.elementAt(2).srcObject !=
                                null &&
                            feeds.any((element) => element["videoSlot"] == 2))
                        ? Container(
                            decoration: BoxDecoration(
                                border: Border.all(
                                    color: (feeds.firstWhere((element) =>
                                                    element["videoSlot"] ==
                                                    2)["talking"] !=
                                                null &&
                                            feeds.firstWhere((element) =>
                                                    element["videoSlot"] ==
                                                    2)["talking"] ==
                                                true)
                                        ? Colors.lightGreen
                                        : Colors.black)),
                            child: Stack(
                              children: [
                                (feeds.firstWhere((element) =>
                                                element["videoSlot"] ==
                                                2)["cammute"] ==
                                            false &&
                                        !muteOtherCams)
                                    // (widget._remoteRenderer
                                    //         .elementAt(2)
                                    //         .srcObject
                                    //         .getVideoTracks()
                                    //         .elementAt(widget._remoteRenderer
                                    //             .elementAt(2)
                                    //             .trackIndex)
                                    //         .enabled)
                                    ? RTCVideoView(
                                        widget._remoteRenderer.elementAt(2))
                                    : Align(
                                        alignment: Alignment.center,
                                        child: Icon(
                                          Icons.account_circle,
                                          color: Colors.white,
                                          size: itemWidth - 60,
                                        ),
                                      ),
                                Align(
                                  alignment: Alignment.bottomLeft,
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.mic_off,
                                        color: (feeds.firstWhere((element) =>
                                                        element["videoSlot"] ==
                                                        2)["talking"] !=
                                                    null &&
                                                feeds.firstWhere((element) =>
                                                        element["videoSlot"] ==
                                                        2)["talking"] ==
                                                    true)
                                            ? Colors.transparent
                                            : Colors.red,
                                        size: 18,
                                      ),
                                      Text((feeds.isNotEmpty &&
                                              feeds.any((element) =>
                                                  element["videoSlot"] == 2))
                                          ? feeds.firstWhere((element) =>
                                              element["videoSlot"] ==
                                              2)["display"]["display"]
                                          : ""),
                                    ],
                                  ),
                                ),
                                Align(
                                    alignment: Alignment.topRight,
                                    child: Container(
                                        margin: const EdgeInsets.only(
                                            top: 8.0, right: 8.0),
                                        child: Icon(
                                          Icons.live_help_rounded,
                                          color: (feeds.firstWhere((element) =>
                                                          element[
                                                              "videoSlot"] ==
                                                          2)["question"] !=
                                                      null &&
                                                  feeds.firstWhere((element) =>
                                                          element[
                                                              "videoSlot"] ==
                                                          2)["question"] ==
                                                      true)
                                              ? Colors.red
                                              : Colors.transparent,
                                          size: 50,
                                        )))
                              ],
                            ))
                        : Container()

                    // CarouselSlider(
                    //   height: 200.0,
                    //   autoPlay: true,
                    //   autoPlayInterval: Duration(seconds: 3),
                    //   autoPlayAnimationDuration: Duration(milliseconds: 800),
                    //   autoPlayCurve: Curves.fastOutSlowIn,
                    //   pauseAutoPlayOnTouch: Duration(seconds: 10),
                    //   aspectRatio: 2.0,
                    //   onPageChanged: (index) {
                    //     setState(() {
                    //       page = index;
                    //     });
                    //   },
                    //   items: feeds.map((feed) {
                    //     return Builder(builder: (BuildContext context) {
                    //       return Container(
                    //         height: MediaQuery.of(context).size.height * 0.30,
                    //         width: MediaQuery.of(context).size.width,
                    //         child: Card(
                    //           color: Colors.blueAccent,
                    //           child: Container(),
                    //         ),
                    //       );
                    //     });
                    //   }).toList(),
                    // ),
                  ],
                  primary: false,
                  padding: const EdgeInsets.all(0),
                  crossAxisSpacing: 0,
                  mainAxisSpacing: 0,
                  crossAxisCount: 2,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    color: Colors.blue,
                    icon: Icon(Icons.arrow_forward),
                    onPressed: () {
                      setState(() {
                        switchPage(page + 1);
                      });
                    },
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    color: Colors.blue,
                    icon: Icon(Icons.arrow_back),
                    onPressed: () {
                      setState(() {
                        switchPage(page - 1);
                      });
                    },
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: DotsIndicator(
                      dotsCount: (feeds.length / PAGE_SIZE).ceil() > 0
                          ? (feeds.length / PAGE_SIZE).ceil()
                          : 1,
                      position: page.toDouble()),
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
            if ((widget.state as State).mounted) setState(() {});
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
        if (widget.myVideoMuted) {
          widget.toggleVideo();
          widget.updateVideoState(!widget.myVideoMuted);
        }
        break;
      case AppLifecycleState.resumed:
        FlutterLogs.logInfo(
            "videoRoom", "didChangeAppLifecycleState", 'resumed');
        FlutterLogs.logInfo("videoRoom", "didChangeAppLifecycleState",
            'pluginHandle is present = ${widget.pluginHandle != null}');
        stopForegroundService();
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
    userData["session"] = widget.j.sessionId;
    userData["handle"] = widget.pluginHandle.handleId;
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

//audio only mode
// otherCamsMuteToggle = () => {
// const {feeds, muteOtherCams} = this.state;
// const activeFeeds = feeds.filter((feed) => feed.videoSlot !== undefined);
// if (!muteOtherCams) {
// // Should hide/mute now all videos.
// this.unsubscribeFrom(
// activeFeeds.map((feed) => feed.id),
// /* onlyVideo= */ true
// );
// this.camMute(/* cammuted= */ false);
// this.setState({videos: NO_VIDEO_OPTION_VALUE});
// this.state.virtualStreamingJanus.setVideo(NO_VIDEO_OPTION_VALUE);
// } else {
// // Should unmute/show now all videos.false,
// this.makeSubscription(
// activeFeeds,
// /* feedsJustJoined= */ false,
// /* subscribeToVideo= */ true,
// /* subscribeToAudio= */ false,
// /* subscribeToData= */ false
// );
// this.camMute(/* cammuted= */ true);
// this.setState({videos: VIDEO_240P_OPTION_VALUE});
// this.state.virtualStreamingJanus.setVideo(VIDEO_240P_OPTION_VALUE);
// }
// this.setState({muteOtherCams: !muteOtherCams});
// };
