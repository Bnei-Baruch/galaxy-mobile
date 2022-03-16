import 'package:flutter_logs/flutter_logs.dart';
import 'package:galaxy_mobile/screens/video_room/video_room_widget.dart';

typedef UnsubscribeFunction = Function(List<dynamic>, bool);

typedef MakeSubscriptionFunction = dynamic Function(
    List<dynamic>, dynamic, dynamic, dynamic, dynamic);

typedef PageSwitchFunction = Function(int, int);

typedef OnSwitchVideosCallback = Function(int page, int feedsLength);

class SwitchPageHelper {
  int pageSize;
  bool muteOtherCams;
  MakeSubscriptionFunction makeSubscription;
  PageSwitchFunction switchVideoSlots;
  UnsubscribeFunction unsubscribeFrom;
  OnSwitchVideosCallback onSwitchVideosCallback;

  SwitchPageHelper(
      UnsubscribeFunction unsubscribeFrom,
      MakeSubscriptionFunction makeSubscription,
      PageSwitchFunction switchVideoSlots,
      int pageSize,
      bool muteOtherCams,
      OnSwitchVideosCallback onSwitchVideosCallback) {
    this.pageSize = pageSize;
    this.muteOtherCams = muteOtherCams;
    this.switchVideoSlots = switchVideoSlots;
    this.onSwitchVideosCallback = onSwitchVideosCallback;

    if (unsubscribeFrom == null) {
      unsubscribeFrom = (list, camOnly) {
        FlutterLogs.logInfo("SwitchPageHelper", "SwitchPageHelper",
            "unsubscribe from: ${list.toString()}");
      };
    }
    this.unsubscribeFrom = unsubscribeFrom;

    if (makeSubscription == null) {
      makeSubscription = (list, bool1, bool2, bool3, bool4) {
        FlutterLogs.logInfo("SwitchPageHelper", "SwitchPageHelper",
            "subscribing top: ${list.toString()}");
      };
    }
    this.makeSubscription = makeSubscription;
  }

  void switchVideos(
    int page,
    List oldFeeds,
    List newFeeds,
  ) {
    FlutterLogs.logInfo(
        "SwitchPageHelper",
        "switchVideos",
        "switchVideos >> page: ${page.toString()} | "
            "pageSize: ${pageSize.toString()} | "
            "old feeds: ${oldFeeds.length.toString()} | "
            "new feeds: ${newFeeds.length.toString()}");

    List oldVideoSlots = List();
    for (int index = 0; index < pageSize; index++) {
      oldVideoSlots
          .add(oldFeeds.indexWhere((feed) => feed["videoSlot"] == index));
    }

    List oldVideoFeeds = oldFeeds.isNotEmpty
        ? oldVideoSlots
            .map((slot) => slot != -1 ? oldFeeds.elementAt(slot) : null)
            .toList()
        : List.empty();

    List newVideoSlots = List();
    for (int index = 0; index < pageSize; index++) {
      newVideoSlots.add((page * pageSize) + index >= newFeeds.length
          ? -1
          : (page * pageSize) + index);
    }

    FlutterLogs.logInfo(
        "SwitchPageHelper",
        "switchVideos",
        "oldVideoSlots: ${oldVideoSlots.toString()} | "
            "newVideoSlots: ${newVideoSlots.toString()}");

    List newVideoFeeds = newVideoSlots
        .map((index) => (index != -1) ? newFeeds[index] : null)
        .toList();

    // Update video slots.
    if (oldVideoFeeds.isNotEmpty) {
      oldVideoFeeds.forEach((feed) {
        if (feed != null) {
          feed["videoSlot"] = null;
        }
      });
    }
    if (newVideoFeeds.isNotEmpty) {
      newVideoFeeds.forEach((feed) {
        int index = newVideoFeeds.indexOf(feed);
        if (feed != null && feed.isNotEmpty) {
          feed["videoSlot"] = index;
        }
      });
    }

    FlutterLogs.logInfo(
        "SwitchPageHelper",
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
    if (newVideoFeeds.isNotEmpty) {
      newVideoFeeds.forEach((newFeed) {
        if (newFeed != null &&
            !oldVideoFeeds.any(
                  (oldFeed) =>
              oldFeed != null && oldFeed["id"] == newFeed["id"],
            )) {
          subscribeFeeds.add(newFeed);
        }
      });
    }

    if (oldVideoFeeds.isNotEmpty) {
      oldVideoFeeds.forEach((oldFeed) {
        if (oldFeed != null &&
            !newVideoFeeds.any((newFeed) =>
                newFeed != null && newFeed["id"] == oldFeed["id"])) {
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
          "SwitchPageHelper",
          "switchVideos",
          "subscribeFeeds: ${subscribeFeeds.toString()} | "
              "unsubscribeFeeds: ${unsubscribeFeeds.toString()} | "
              "switchFeeds: ${switchFeeds.toString()}");

      if (this.makeSubscription != null) {
        this.makeSubscription(
            subscribeFeeds,
            /* feedsJustJoined= */ false,
            /* subscribeToVideo= */ true,
            /* subscribeToAudio= */ false,
            /* subscribeToData= */ false);
      }
      if (this.unsubscribeFrom != null) {
        this.unsubscribeFrom(
            unsubscribeFeeds.map((feed) => feed["id"]).toList(),
            /* onlyVideo= */ true);
      }
      if (this.switchVideoSlots != null) {
        switchFeeds.forEach((element) {
          this.switchVideoSlots(element["from"], element["to"]);
        });
      }
      //first(({ from, to }) => this.switchVideoSlots(from, to));
    } else {
      FlutterLogs.logWarn("SwitchPageHelper", "switchVideos",
          "ignoring subscribe/unsubscribe/switch; other cams on mute mode");
    }

    if (onSwitchVideosCallback != null) {
      onSwitchVideosCallback(page, newFeeds.length);
    }
  }
}
