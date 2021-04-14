import 'dart:collection';
import 'dart:convert';
import 'dart:ffi';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:galaxy_mobile/models/mainStore.dart';
import 'package:galaxy_mobile/services/authService.dart';
import 'package:galaxy_mobile/utils/switch_page_helper.dart';
import 'package:janus_client/janus_client.dart';
import 'package:janus_client/utils.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:janus_client/Plugin.dart';
import 'package:provider/provider.dart';

import 'dart:async';

import 'package:synchronized/synchronized.dart';

final int PAGE_SIZE = 3;

class VideoRoom extends StatefulWidget {
  List<RTCVideoView> remote_videos = new List();
  String server;
  String token;
  int roomNumber;

  User user;

  JanusClient j;
  RTCVideoRenderer _localRenderer = new RTCVideoRenderer();
  List<RTCVideoRenderer> _remoteRenderer = new List<RTCVideoRenderer>();
  Plugin pluginHandle;
  Plugin subscriberHandle;

  var remoteStream;
  // VideoRoom(String serverUrl, String token, int roomNumber)
  //     : this.roomNumber = roomNumber,
  //       this.token = token,
  //       this.server = serverUrl;

  void exitRoom() {
    j.destroy();
    pluginHandle.hangup();
    subscriberHandle.destroy();
    _localRenderer.srcObject = null;
    _localRenderer.dispose();
    _remoteRenderer.map((e) => e.srcObject = null);
    _remoteRenderer.map((e) => e.dispose());
    pluginHandle = null;
    subscriberHandle = null;
  }

  @override
  _VideoRoomState createState() => _VideoRoomState();
}

class _VideoRoomState extends State<VideoRoom> {
  List<MediaStream> remoteStream = new List<MediaStream>();
  MediaStream myStream;

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

  set id(id) {}

  set subscription(List subscription) {}

  SwitchPageHelper switcher;

  @override
  void didChangeDependencies() async {
    // TODO: implement didChangeDependencies
    super.didChangeDependencies();
  }

  @override
  void initState() {
    super.initState();
    switcher = SwitchPageHelper(unsubscribeFrom, makeSubscription,
        switchVideoSlots, PAGE_SIZE, muteOtherCams);
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
    print("xxx switch page to : " + page.toString());
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
    print('remote plugin attached');
    j.attach(Plugin(
        opaqueId: 'remotefeed_user',
        plugin: 'janus.plugin.videoroom',
        onMessage: (msg, jsep) async {
          print("xxx message: $msg");
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
            print("xxx got newStreamsMids ${midslist.toString()}");
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
                  print(
                      " xxx subscribe Handle onSuccess create answer and start");
                  creatingFeed = false;
                },
                onError: (error) =>
                    {print(" xxx could not create answer: $error")});
          } else {
            print("xxx no jsep to answer");
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
          print("Requesting to subscribe to publishers...");
          widget.subscriberHandle.send(
            message: register,
            onSuccess: () async {
              print("xxx onSuccess subscribe to publishers...");
            },
            onError: (error) {
              print("xxx onError subscribe to publishers..." + error);
            },
          );
        },
        onRemoteTrack: (stream, track, mid, on) {
          print(
              'xxx got remote track with mid=$mid trackid=${track.toString()} , is on = $on stream with id=${stream.id} has tracks = ${(stream as MediaStream).getVideoTracks().length} with ids=${(stream as MediaStream).getVideoTracks().map((e) => e.toString())}');

          (stream as MediaStream).getVideoTracks().forEach((element) => {
                print(
                    "xxx track ${element.id} is enabled=${element.enabled} and muted=${element.muted}")
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

              print("xxx video slot is: " +
                  feed["videoSlot"].toString() +
                  "track index : ${trackIndex}");
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
                    print("xxx done set renderer stream for video slot: " +
                        slot.toString());
                    // }

                    //check if mids changed place

                    var otherFeeds = this.feeds.where((element) =>
                        element["videoSlot"] != slot &&
                        element["videoSlot"] != null &&
                        element["videoSlot"] != -1);
                    print(
                        "xxx other feeds ${otherFeeds.toString()} and all feeds ${feeds.toString()}");
                    otherFeeds.forEach((element) {
                      int index = element["videoSlot"];
                      if (widget._remoteRenderer.elementAt(index).trackIndex !=
                          element["trackIndex"]) {
                        print("xxx retracking video");
                        widget._remoteRenderer.elementAt(index).trackIndex =
                            element["trackIndex"];
                        widget._remoteRenderer.elementAt(slot).srcObject =
                            stream;
                      }
                    });
                  });
                });
                // );
                //   }
              });
              // }
            });
          }

          //});
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
        debugPrint('voilla! connection established with session id as' +
            sessionId.toString());
        Map<String, dynamic> configuration = {
          "iceServers": widget.j.iceServers.map((e) => e.toMap()).toList()
        };

        widget.j.attach(Plugin(
            opaqueId: widget.user.sub,
            plugin: 'janus.plugin.videoroom',
            onMessage: (msg, jsep) async {
              var event = msg['videoroom'];
              if (event != null) {
                if (event == 'joined') {
                  if (msg["publishers"] != null) {
                    print('publisher on msg');
                    var list = msg["publishers"];
                    print('got publihers');
                    print(list);
                    List<Map> subscription = new List<Map>();
                    //    _newRemoteFeed(j, list[0]["id"]);
                    final filtereList = List.from(list);
                    filtereList.forEach((item) => {
                          if ((item["streams"] as List).length == 2)
                            {
                              subscription.add({
                                "feed": LinkedHashMap.of(item).remove("id"),
                                "mid": "1"
                              })
                            }
                        });

                    //Map.from(item)..forEach((key, value) => if(key != ("id")) ));
                    //need to keep the feeds currently in the room with the data they (present user), question, mute / unmute

                    //    _newRemoteFeed(j, subscription);

                    // User just joined the room.

                    (msg['publishers'] as List).forEach((value) =>
                        value["display"] = (jsonDecode(value["display"])));
                    //( (l)  => l["display"] = (jsonDecode(l["display"])) as Map);
                    //          List newFeeds = sortAndFilterFeeds();
                    List newFeeds = msg['publishers'];
                    print('New list of available publishers/feeds:' +
                        newFeeds.toString());
                    Set newFeedsIds = new Set();
                    var tempset = newFeeds.map((feed) => feed["id"]).toSet();
                    newFeedsIds
                        .addAll(newFeeds.map((feed) => feed["id"]).toSet());
                    if (feeds != null &&
                        feeds.any((feed) => newFeedsIds.lookup(feed["id"]))) {
                      print(
                          "New feed joining but one of the feeds already exist" +
                              newFeeds.toString() +
                              list.toString());
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

                    // this.setState({feeds: feedsNewState});
                  }
                } else if (event == 'talking') {
                  print("xxx talking");
                  final id = msg['id'];
                  print("User: ${id} - stop talking");
                  final feed = feeds.firstWhere((feed) => feed["id"] == id,
                      orElse: null);
                  if (feed == null) {
                    print("xxx Did not find user ${id}.");
                    return;
                  }
                  setState(() {
                    feed["talking"] = true;
                  });
                } else if (event == 'stopped-talking') {
                  print("xxx stopped-talking");
                  // const feeds = Object.assign([], this.state.feeds);
                  final id = msg['id'];
                  print("User: ${id} - stop talking");
                  final feed = feeds.firstWhere((feed) => feed["id"] == id,
                      orElse: null);
                  if (feed == null) {
                    print("xxx Did not find user ${id}.");
                    return;
                  }
                  setState(() {
                    feed["talking"] = false;
                  });

                  // this.setState({ feeds });
                } else if (event == 'destroyed') {
                  print("destroyed");

                  // The room has been destroyed
                  // Janus.warn('The room has been destroyed!');
                } else if (event == 'event') {
                  if (msg['configured'] == 'ok') {
                    print("configured");
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
                    print("xxx just joined");
                    // User just joined the room.
                    (msg['publishers'] as List).forEach((value) {
                      value["display"] = (jsonDecode(value["display"]));
                    });
                    var newFeeds = msg['publishers']
                        as List; //sortAndFilterFeeds(msg['publishers'] as List);
                    print('xxx New list of available publishers/feeds:' +
                        newFeeds.toString());
                    Set newFeedsIds = new Set();
                    newFeedsIds
                        .addAll(newFeeds.map((feed) => feed["id"]).toSet());
                    if (feeds.any((feed) => newFeedsIds.contains(feed["id"]))) {
                      print(
                          "xxx New feed joining but one of the feeds already exist" +
                              newFeeds.toString());
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

                    final leaving = msg["leaving"];
                    print("${leaving.toString()} leaving");
                    print('Publisher leaving: ' + leaving.toString());
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

                    print("${leaving.toString()} left");
                  } else if (msg['unpublished'] != null &&
                      msg['unpublished'] != null) {
                    print("unpublished");
                    // const unpublished = msg['unpublished'];
                    // Janus.log('Publisher unpublished: ', unpublished);
                    // if (unpublished === 'ok') {
                    // // That's us
                    // videoroom.hangup();
                    // return;
                    // }

                  } else if (msg['error'] != null && msg['error'] != null) {
                    print("error");
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
              myStream = stream;
              myStream.getAudioTracks().first.setMicrophoneMute(true);
              // });
              setState(() {
                widget._localRenderer.srcObject = myStream;
              });
              var register = {
                "request": "join",
                "room": widget.roomNumber,
                "ptype": "publisher",
                "display": //"igal test"

                    jsonEncode({
                  "id": widget.user.sub,
                  "timestamp": DateTime.now().millisecond,
                  "role": "user",
                  "display": widget.user.name
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
            }));
      }, onError: (e) {
        debugPrint('some error occured');
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
    print('xxx :: Got subscribtion: ' +
        subscription
            .toString()); //, !!this.state.remoteFeed, this.state.creatingFeed);
    if (widget.subscriberHandle != null) {
      // var register = {
      //   "request": "join",
      //   "room": widget.roomNumber,
      //   "ptype": "subscriber",
      //   "streams": subscription,
      // };
      // print("Requesting to subscribe to publishers...");
      // widget.subscriberHandle.send(
      //   message: register,
      //   onSuccess: () async {
      //     print("onSuccess subscribe to publishers...");
      //   },
      //   onError: (error) {
      //     print("onError subscribe to publishers..." + error);
      //   },
      // );

      widget.subscriberHandle.send(
        message: {"request": 'subscribe', "streams": subscription},
        onSuccess: () {
          print(
              "xxx onSuccess subscribe to streams " + subscription.toString());
        },
        onError: (error) {
          print("xxx error subscribe to streams : " + error);
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
    print('xxx switchVideos: page ' +
        page.toString() +
        ' PAGE_SIZE: ' +
        PAGE_SIZE.toString() +
        ' old  ' +
        oldFeeds.length.toString() +
        'new ' +
        newFeeds.length.toString());

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
    print("xxx oldvideoSlots: " + oldVideoSlots.toString());
    print("xxx newvideoslots: " + newVideoSlots.toString());

    List newVideoFeeds = newVideoSlots
        .map((index) => {if (index != -1) newFeeds.elementAt(index)})
        .toList();

    // Update video slots.
    // oldVideoFeeds.forEach((feed) => {
    //       if (feed != null) {feed["videoSlot"] = -1}
    //     });
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

    print("xxx oldVideoFeeds: " +
        oldVideoFeeds.toString() +
        " newVideoFeeds: " +
        newVideoFeeds.toString());
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
      print('xxx subscribeFeeds:' +
          subscribeFeeds.toString() +
          ' unsubscribeFeeds' +
          unsubscribeFeeds.toString() +
          'switchFeeds' +
          switchFeeds.toString());
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
      print(
          'Ignoring subscribe/unsubscribe/switch, we are at mute other cams mode.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.read<MainStore>();

    final args = RoomArguments(s.activeGateway.url, s.activeGateway.token,
        s.activeRoom.room.toInt(), s.activeUser);

    // final RoomArguments args = ModalRoute.of(/context).settings.arguments;
    widget.roomNumber = args.roomNumber;
    widget.token = args.token;
    widget.server = args.server;
    widget.user = args.user;
    if (widget.pluginHandle == null) {
      // ignore: unnecessary_statements
      // initInfra();
    }
    if (!initialized) {
      initialized = true;
      initInfra();
    }
    return
//         appBar: AppBar(
//           actions: [
//             IconButton(
//                 icon: Icon(
//                   Icons.call,
//                   color: Colors.greenAccent,
//                 ),
//                 onPressed: () async {
//                   await this.initRenderers();
//                   await this.initPlatformState();
// //                  -_localRenderer.
//                 }),
//             IconButton(
//                 icon: Icon(
//                   Icons.call_end,
//                   color: Colors.red,
//                 ),
//                 onPressed: () {
//                   j.destroy();
//                   pluginHandle.hangup();
//                   subscriberHandle.hangup();
//                   _localRenderer.srcObject = null;
//                   _localRenderer.dispose();
//                   _remoteRenderer.map((e) => e.srcObject = null);
//                   _remoteRenderer.map((e) => e.dispose());
//                   setState(() {
//                     pluginHandle = null;
//                     subscriberHandle = null;
//                   });
//                 }),
//             IconButton(
//                 icon: Icon(
//                   Icons.switch_camera,
//                   color: Colors.white,
//                 ),
//                 onPressed: () {
//                   if (pluginHandle != null) {
//                     pluginHandle.switchCamera();
//                   }
//                 })
//           ],
//           title: const Text('janus_client'),
//         ),

        // Row(children: [
        Container(
      alignment: Alignment.topCenter,
      height: MediaQuery.of(context).size.height / 3 * 2 - 140,
      child: Stack(
        children: [
          GridView.count(
            children: [
              Container(
                decoration: BoxDecoration(
                    border: Border.all(
                        color: Colors.black)), //Colors.lightGreenAccent
                child: RTCVideoView(
                  widget._localRenderer,
                ),
                // height: 200,
                // width: 200,
              ),
              (widget._remoteRenderer != null &&
                      widget._remoteRenderer.elementAt(0) != null &&
                      widget._remoteRenderer.elementAt(0).srcObject != null &&
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
                      child: Stack(
                        children: [
                          (feeds.firstWhere((element) =>
                                      element["videoSlot"] == 0)["cammute"] ==
                                  false)
                              ? RTCVideoView(
                                  widget._remoteRenderer.elementAt(0))
                              : CircleAvatar(
                                  child: Icon(
                                    Icons.account_circle,
                                    color: Colors.white,
                                  ), // Icon widget changed with FaIcon
                                  radius: 60.0,
                                  backgroundColor: Colors.cyan),
                          Align(
                            alignment: Alignment.bottomLeft,
                            child: Row(
                              children: [
                                (feeds.firstWhere((element) =>
                                                element["videoSlot"] ==
                                                0)["talking"] !=
                                            null &&
                                        feeds.firstWhere((element) =>
                                                element["videoSlot"] ==
                                                0)["talking"] ==
                                            true)
                                    ? Container()
                                    : Icon(
                                        Icons.mic_off,
                                        color: Colors.red,
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
                        ],
                      ))
                  : Text("Waiting...", style: TextStyle(color: Colors.white)),

              (widget._remoteRenderer != null &&
                      widget._remoteRenderer.elementAt(1) != null &&
                      widget._remoteRenderer.elementAt(1).srcObject != null &&
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
                          RTCVideoView(widget._remoteRenderer.elementAt(1)),
                          Align(
                            alignment: Alignment.bottomLeft,
                            child: Row(
                              children: [
                                (feeds.firstWhere((element) =>
                                                element["videoSlot"] ==
                                                1)["talking"] !=
                                            null &&
                                        feeds.firstWhere((element) =>
                                                element["videoSlot"] ==
                                                1)["talking"] ==
                                            true)
                                    ? Container()
                                    : Icon(
                                        Icons.mic_off,
                                        color: Colors.red,
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
                        ],
                      ))
                  : Text(
                      "Waiting...",
                      style: TextStyle(color: Colors.white),
                    ),
              (widget._remoteRenderer != null &&
                      widget._remoteRenderer.elementAt(2) != null &&
                      widget._remoteRenderer.elementAt(2).srcObject != null &&
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
                          RTCVideoView(widget._remoteRenderer.elementAt(2)),
                          Align(
                            alignment: Alignment.bottomLeft,
                            child: Row(
                              children: [
                                (feeds.firstWhere((element) =>
                                                element["videoSlot"] ==
                                                2)["talking"] !=
                                            null &&
                                        feeds.firstWhere((element) =>
                                                element["videoSlot"] ==
                                                2)["talking"] ==
                                            true)
                                    ? Container()
                                    : Icon(
                                        Icons.mic_off,
                                        color: Colors.red,
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
                        ],
                      ))
                  : Container(
                      color: Colors.black,
                      child: Text(
                        "Waiting...",
                        style: TextStyle(color: Colors.white),
                      ),
                    )

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
      print("xxx unsubscribing streams: $unsubscribe");
      widget.subscriberHandle.send(
          message: unsubscribe,
          onSuccess: () {
            print("xxx unsubscribed success" + unsubscribe.toString());
          },
          onError: (error) {
            print("xxx unsubcribed failed $error");
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
}

class RoomArguments {
  final String server;
  final String token;
  final int roomNumber;
  final User user;
  RoomArguments(this.server, this.token, this.roomNumber, this.user);
}

class VideoView {
  RTCVideoView view;
  Map streamMid;
  Text display;
}
// CarouselSlider(
// height: 200.0,
// autoPlay: true,
// autoPlayInterval: Duration(seconds: 3),
// autoPlayAnimationDuration: Duration(milliseconds: 800),
// autoPlayCurve: Curves.fastOutSlowIn,
// pauseAutoPlayOnTouch: Duration(seconds: 10),
// aspectRatio: 2.0,
// onPageChanged: (index) {
// setState(() {
// _currentIndex = index;
// });
// },
// items: cardList.map((card){
// return Builder(
// builder:(BuildContext context){
// return Container(
// height: MediaQuery.of(context).size.height*0.30,
// width: MediaQuery.of(context).size.width,
// child: Card(
// color: Colors.blueAccent,
// child: card,
// ),
// );
// }
// );
// }).toList(),
// ),
