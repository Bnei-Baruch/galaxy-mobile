import 'package:dio/dio.dart';

typedef unsub = Function(List<dynamic>, bool);

typedef make = dynamic Function(
    List<dynamic>, dynamic, dynamic, dynamic, dynamic);

typedef switcher = Function(int, int);

class SwitchPageHelper {
  int PAGE_SIZE;
  bool muteOtherCams;
  make makeSubscription;
  switcher switchVideoSlots;
  unsub unsubscribeFrom;
  SwitchPageHelper(unsub unsubscriber, make makeSub, switcher Switcher,
      int pageSize, bool mute) {
    PAGE_SIZE = pageSize;
    muteOtherCams = mute;
    makeSubscription = makeSub;
    unsubscribeFrom = unsubscriber;
    switchVideoSlots = Switcher;

    if (unsubscribeFrom == null) {
      unsubscribeFrom = (list, camOnly) {
        print("unsubscribing : ${list.toString()}");
      };
    }

    if (makeSub == null) {
      makeSubscription = (list, bool1, bool2, bool3, bool4) {
        print("subscribing : ${list.toString()}");
      };
    }
  }
  void switchVideos(
    int page,
    List oldFeeds,
    List newFeeds,
  ) {
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
        .map((index) => (index != -1) ? newFeeds[index] : null)
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
        ? newVideoFeeds.forEach((feed) {
            var index = newVideoFeeds.indexOf(feed);
            if (feed != null && feed.isNotEmpty) feed["videoSlot"] = index;
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
      print('xxx subscribeFeeds:' +
          subscribeFeeds.toString() +
          ' unsubscribeFeeds' +
          unsubscribeFeeds.toString() +
          'switchFeeds' +
          switchFeeds.toString());
      (this.makeSubscription != null)
          ? this.makeSubscription(
              subscribeFeeds,
              /* feedsJustJoined= */ false,
              /* subscribeToVideo= */ true,
              /* subscribeToAudio= */ false,
              /* subscribeToData= */ false)
          : null;
      (this.unsubscribeFrom != null)
          ? this.unsubscribeFrom(
              unsubscribeFeeds.map((feed) => feed["id"]).toList(),
              /* onlyVideo= */ true)
          : null;
      switchFeeds.forEach((element) {
        (this.switchVideoSlots != null)
            ? this.switchVideoSlots(element["from"], element["to"])
            : null;
      }); //first(({ from, to }) => this.switchVideoSlots(from, to));
    } else {
      print(
          'Ignoring subscribe/unsubscribe/switch, we are at mute other cams mode.');
    }
  }
}
