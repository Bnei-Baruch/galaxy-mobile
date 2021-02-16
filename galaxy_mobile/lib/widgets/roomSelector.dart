import 'dart:async';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:galaxy_mobile/services/api.dart';
import 'package:provider/provider.dart';

class RoomSelector extends StatefulWidget {
  RoomSelector();

  @override
  State createState() => _RoomSelectorState();
}

class _RoomSelectorState extends State<RoomSelector> {
  Future<List<Room>> fetchRooms;
  Future<List<RoomData>> config;

  @override
  void initState() {
    super.initState();
    final api = Provider.of<Api>(context, listen: false);
    fetchRooms = api.fetchAvailableRooms();
    config = api.fetchConfig();
    print(config.hashCode);
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
              onChanged: (Room room) => print(room),
              showClearButton: true,
              // showSearchBox: true,
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
