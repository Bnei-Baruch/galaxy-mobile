import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:galaxy_mobile/models/mainStore.dart';
import 'package:galaxy_mobile/services/api.dart';
import 'package:provider/provider.dart';

class RoomSelector extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final rooms = context.select((MainStore s) => s.availableRooms);

    return DropdownSearch<Room>(
      label: "Room",
      hint: "Select Room",
      items: rooms,
      // onFind: (String filter) => getData(filter),
      itemAsString: (Room room) => room.description,
      onChanged: (Room room) => {
        print(room),
        context.read<MainStore>().setActiveRoom(room.room)
      },
      showClearButton: true,
      showSearchBox: true,
      searchBoxDecoration: InputDecoration(
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.fromLTRB(12, 12, 8, 0),
        labelText: "Search",
      ),
    );
  }
}
