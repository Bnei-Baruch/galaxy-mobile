import 'dart:collection';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:galaxy_mobile/services/authService.dart';
import 'package:janus_client/janus_client.dart';
import 'package:janus_client/utils.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:janus_client/Plugin.dart';

import 'dart:async';

class VideoRoom extends StatefulWidget {
  List<RTCVideoView> remote_videos = new List();
  String server;
  String token;
  int roomNumber;

  User user;

  // VideoRoom(String serverUrl, String token, int roomNumber)
  //     : this.roomNumber = roomNumber,
  //       this.token = token,
  //       this.server = serverUrl;

  @override
  _VideoRoomState createState() => _VideoRoomState();
}

class _VideoRoomState extends State<VideoRoom> {
  JanusClient j;
  RTCVideoRenderer _localRenderer = new RTCVideoRenderer();
  List<RTCVideoRenderer> _remoteRenderer = new List<RTCVideoRenderer>();
  Plugin pluginHandle;
  Plugin subscriberHandle;
  List<MediaStream> remoteStream = new List<MediaStream>();
  MediaStream myStream;

  List<Map> roomFeeds;

  var streams;

  bool creatingFeed = false;

  var feeds;

  Map newStreamsMids;

  set id(id) {}

  set subscription(List subscription) {}

  @override
  void didChangeDependencies() async {
    // TODO: implement didChangeDependencies
    super.didChangeDependencies();
  }

  @override
  void initState() {
    super.initState();
    initRenderers();
  }

  initRenderers() async {
    int count = 0;
    while (count < 4) {
      _remoteRenderer.add(new RTCVideoRenderer());
      count++;
    }
    await _localRenderer.initialize();
    for (var renderer in _remoteRenderer) {
      await renderer.initialize();
    }
    count = 0;
    // while (count < 4) {
    createLocalMediaStream("local").then((value) => remoteStream.add(value));
    //  count++;
    //  }
  }

  sortAndFilterFeeds(List feeds) => feeds
      .where((feed) => !feed["display"]["role"].match("/^(ghost|guest)"))
      .toList()
      .sort((a, b) => a["display"]["timestamp"] - b["display"]["timestamp"]);

  userFeeds(feeds) => feeds.filter((feed) => feed["display"]["role"] == 'user');

  _newRemoteFeed(JanusClient j, List<Map> feeds) async {
    roomFeeds = feeds;
    print('remote plugin attached');
    j.attach(Plugin(
        plugin: 'janus.plugin.videoroom',
        onMessage: (msg, jsep) async {
          //update feed
          if (msg["event"] == 'attached' ||
              (msg["event"] == 'event' && msg['switched'] == 'ok') ||
              msg["event"] == 'updated') {
            newStreamsMids = new Map.of(msg['streams'].map(
                (stream) => {"mid": stream["mid"], "feed_id": stream.feed_id}));
          }

          if (jsep != null) {
            await subscriberHandle.handleRemoteJsep(jsep);
            // var body = {"request": "start", "room": 2157};
            var body = {
              "request": "start",
              "room": widget.roomNumber,
            };
            await subscriberHandle.send(
                message: body,
                jsep: await subscriberHandle.createAnswer(),
                onSuccess: () {});
          }
        },
        onSuccess: (plugin) {
          setState(() {
            subscriberHandle = plugin;
          });
          var register = {
            "request": "join",
            "room": widget.roomNumber,
            "ptype": "subscriber",
            "streams": feeds,
          };
          print("Requesting to subscribe to publishers...");
          subscriberHandle.send(message: register, onSuccess: () async {});
        },
        onRemoteTrack: (stream, track, mid, on) {
          print('got remote track with mid=$mid');
          setState(() {
            if ((track as MediaStreamTrack).kind == "video" && on == true) {
              if (num.tryParse(mid).toInt() < 4) {
                remoteStream
                    .elementAt(num.tryParse(mid).toInt())
                    .addTrack(track, addToNative: true);
                print('added track to stream locally');
                _remoteRenderer
                        .elementAt(num.tryParse(mid as String).toInt())
                        .srcObject =
                    remoteStream.elementAt(num.tryParse(mid).toInt());
              }
            }
          });
        }));
  }

  Future<void> initPlatformState() async {
    setState(() {
      j = JanusClient(iceServers: [
        RTCIceServer(
            url: "stun:galaxy.kli.one:3478", username: "", credential: ""),
      ], server: [
        widget.server,
      ], withCredentials: true, isUnifiedPlan: true, token: widget.token);
      j.connect(onSuccess: (sessionId) async {
        debugPrint('voilla! connection established with session id as' +
            sessionId.toString());
        Map<String, dynamic> configuration = {
          "iceServers": j.iceServers.map((e) => e.toMap()).toList()
        };

        j.attach(Plugin(
            opaqueId: "videoroom_user",
            plugin: 'janus.plugin.videoroom',
            onMessage: (msg, jsep) async {
              if (msg["publishers"] != null) {
                print('publisher on msg');
                var list = msg["publishers"];
                print('got publihers');
                print(list);
                List<Map> subscription = new List<Map>();
                //    _newRemoteFeed(j, list[0]["id"]);
                final filtereList = List.from(list);
                filtereList.forEach((item) => {
                      subscription.add({
                        "feed": LinkedHashMap.of(item).remove("id"),
                        "mid": "1"
                      })
                    });
                //Map.from(item)..forEach((key, value) => if(key != ("id")) ));
                //need to keep the feeds currently in the room with the data they (present user), question, mute / unmute

                //  _newRemoteFeed(j, subscription);

                // User just joined the room.

                var decoder = jsonDecode(
                    "{\"id\":\"2834a16d-2204-4acc-85ff-a3cbd82d0414\",\"timestamp\":1613954128027,\"role\":\"user\",\"display\":\"shay\"}");
                msg['publishers']
                    .filter((l) => l["display"] = (jsonDecode(l["display"])));
                //          List newFeeds = sortAndFilterFeeds();
                List newFeeds = List();
                print('New list of available publishers/feeds:' +
                    newFeeds.toString());
                Set newFeedsIds = new Set();
                newFeedsIds.addAll(newFeeds.map((feed) => feed.id));
                if (feeds.some((feed) => newFeedsIds.lookup(feed["id"]))) {
                  print("New feed joining but one of the feeds already exist" +
                      newFeeds.toString() +
                      list.toString());
                  return;
                }
                // Merge new feed with existing feeds and sort.
                this.makeSubscription(
                    newFeeds,
                    /* feedsJustJoined= */ true,
                    /* subscribeToVideo= */ false,
                    /* subscribeToAudio= */ true,
                    /* subscribeToData= */ true);
                // this.switchVideos(/* page= */ this.state.page, userFeeds(feeds),
                //  userFeeds(feedsNewState));
                // this.setState({feeds: feedsNewState});
              }

              //need to handle disconnection of room feed

              //need to handle addition of room feed

              //need to handle change of status of feeds

              if (jsep != null) {
                pluginHandle.handleRemoteJsep(jsep);
              }
            },
            onSuccess: (plugin) async {
              // setState(() {
              pluginHandle = plugin;
              MediaStream stream = await plugin.initializeMediaDevices();
              myStream = stream;
              myStream.getAudioTracks().first.setMicrophoneMute(true);
              // });
              setState(() {
                _localRenderer.srcObject = myStream;
              });
              var register = {
                "request": "join",
                "room": widget.roomNumber,
                "ptype": "publisher",
                "display": //"igal test"

                    jsonEncode({
                  "id": widget.user.sub,
                  "timestamp": TimeOfDay.now().toString(),
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
                    RTCSessionDescription offer = await plugin.createOffer();
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
  void makeSubscription(newFeeds, feedsJustJoined, subscribeToVideo,
      subscribeToAudio, subscribeToData) {
    List<Map> subscription = List<Map>();
    newFeeds.forEach((feed, feedIndex) => () {
          //const { id, streams } = feed;
          String id = feed["id"];
          streams = feed["streams"];
          feed.video =
              !!streams.find((v) => v.type == 'video' && v.codec == 'h264');
          feed.audio =
              !!streams.find((a) => a.type == 'audio' && a.codec == 'opus');
          feed.data = !!streams.find((d) => d.type == 'data');
          feed.cammute = !feed.video;

          streams.forEach((stream) => () {
                if ((subscribeToVideo &&
                        stream.type == 'video' &&
                        stream.codec == 'h264') ||
                    (subscribeToAudio &&
                        stream.type == 'audio' &&
                        stream.codec == 'opus') ||
                    (subscribeToData && stream.type == 'data')) {
                  subscription.add({feed: id, "mid": stream.mid});
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
    print(' :: Got subscribtion: ' +
        subscription
            .toString()); //, !!this.state.remoteFeed, this.state.creatingFeed);
    if (pluginHandle != null) {
      pluginHandle
          .send(message: {"request": 'subscribe', streams: subscription});
    }

    // We don't have a handle yet, but we may be creating one already
    // if (creatingFeed) {
    //   // Still working on the handle
    //   setTimeout(() => {
    //   this.subscribeTo(subscription);
    //   }, 500);
    //   return;
    // }

    // We are not creating the feed, so let's do it.
    creatingFeed = true;
    _newRemoteFeed(j, subscription);
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

  @override
  Widget build(BuildContext context) {
    final RoomArguments args = ModalRoute.of(context).settings.arguments;
    widget.roomNumber = args.roomNumber;
    widget.token = args.token;
    widget.server = args.server;
    widget.user = args.user;
    return Scaffold(
        appBar: AppBar(
          actions: [
            IconButton(
                icon: Icon(
                  Icons.call,
                  color: Colors.greenAccent,
                ),
                onPressed: () async {
                  await this.initRenderers();
                  await this.initPlatformState();
//                  -_localRenderer.
                }),
            IconButton(
                icon: Icon(
                  Icons.call_end,
                  color: Colors.red,
                ),
                onPressed: () {
                  j.destroy();
                  pluginHandle.hangup();
                  subscriberHandle.hangup();
                  _localRenderer.srcObject = null;
                  _localRenderer.dispose();
                  _remoteRenderer.map((e) => e.srcObject = null);
                  _remoteRenderer.map((e) => e.dispose());
                  setState(() {
                    pluginHandle = null;
                    subscriberHandle = null;
                  });
                }),
            IconButton(
                icon: Icon(
                  Icons.switch_camera,
                  color: Colors.white,
                ),
                onPressed: () {
                  if (pluginHandle != null) {
                    pluginHandle.switchCamera();
                  }
                })
          ],
          title: const Text('janus_client'),
        ),
        body:
            // Row(children: [
            GridView.count(
          children: [
            Container(
              child: RTCVideoView(
                _localRenderer,
              ),
              height: 200,
              width: 200,
            ),
            (_remoteRenderer != null && _remoteRenderer.elementAt(0) != null)
                ? Stack(children: [
                    RTCVideoView(_remoteRenderer.elementAt(0)),
                    Align(
                      alignment: Alignment.bottomLeft,
                      child: Text("User name"),
                    ),
                  ])
                : Text("Waiting...", style: TextStyle(color: Colors.white)),
            (_remoteRenderer != null && _remoteRenderer.elementAt(1) != null)
                ? RTCVideoView(_remoteRenderer.elementAt(1))
                : Text(
                    "Waiting...",
                    style: TextStyle(color: Colors.white),
                  ),
            (_remoteRenderer != null && _remoteRenderer.elementAt(2) != null)
                ? RTCVideoView(_remoteRenderer.elementAt(2))
                : Text(
                    "Waiting...",
                    style: TextStyle(color: Colors.white),
                  ),
            (_remoteRenderer != null && _remoteRenderer.elementAt(3) != null)
                ? RTCVideoView(_remoteRenderer.elementAt(3))
                : Text(
                    "Waiting...",
                    style: TextStyle(color: Colors.white),
                  )
          ],
          primary: false,
          padding: const EdgeInsets.all(20),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          crossAxisCount: 2,
        ));
  }
}

class RoomArguments {
  final String server;
  final String token;
  final int roomNumber;
  final User user;
  RoomArguments(this.server, this.token, this.roomNumber, this.user);
}
