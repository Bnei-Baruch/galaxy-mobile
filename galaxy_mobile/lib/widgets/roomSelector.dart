import 'dart:async';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:galaxy_mobile/services/api.dart';
import 'package:provider/provider.dart';

typedef RoomCallback = void Function(int roomNum, String server);

class RoomSelector extends StatefulWidget {
  RoomSelector(RoomCallback callback) : this.roomCallback = callback;
  RoomCallback roomCallback;
  int roomNumber;
  String serverName;
  @override
  State createState() => _RoomSelectorState();
}

class _RoomSelectorState extends State<RoomSelector> {
  Future<List<Room>> fetchRooms;

  @override
  void initState() {
    super.initState();
    final api = Provider.of<Api>(context, listen: false);
    fetchRooms = api.fetchAvailableRooms();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Room>>(
        future: fetchRooms,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return DropdownSearch<Room>(
              label: "Room",
              hint: "Select Room",
              items: snapshot.data,
              // onFind: (String filter) => getData(filter),
              itemAsString: (Room room) => room.description,
              onChanged: (Room room) => {
                print(room),
                widget.roomNumber = room.room.toInt(),
                widget.serverName = room.janus,
                widget.roomCallback(widget.roomNumber, widget.serverName)
              },
              // selectedItem: snapshot.data
              //     .firstWhere((element) => element.description == "PT 30"),
              showClearButton: true,
              showSearchBox: true,
              // searchBoxDecoration: InputDecoration(
              //   border: OutlineInputBorder(),
              //   contentPadding: EdgeInsets.fromLTRB(12, 12, 8, 0),
              //   labelText: "Search a group",
              // ),
            );
            // return Text("snapshot.data");
          } else if (snapshot.hasError) {
            return Text("${snapshot.error}");
          }

          // By default, show a loading spinner.
          return CircularProgressIndicator();
        });
  }
}
