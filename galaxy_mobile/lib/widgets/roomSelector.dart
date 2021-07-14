import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:galaxy_mobile/models/mainStore.dart';
import 'package:galaxy_mobile/services/api.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';

class RoomSelector extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final rooms = context.select((MainStore s) => s.availableRooms);
    final activeRoom = context.select((MainStore s) => s.activeRoom);

    // TODO: 2 options for drop down, this is more responsive.
    // final items = rooms.map((Room room) => DropdownMenuItem<String>(value: room.description, child: Text(room.description))).toList();
    // return SearchableDropdown.single(
    //     items: items,
    //     // value: selectedValue,
    //     label: "Room",
    //     hint: "Select room",
    //     searchHint: "Select room",
    //     onChanged: (value) {
    //         context.read<MainStore>().setActiveRoom(value);
    //     },
    //     isExpanded: true,
    //   );

    // TODO: the dropdown is slow, consider replace with another package.
    return DropdownSearch<Room>(
      mode: Mode.DIALOG,
      label: 'room'.tr(),
      hint: 'select_room'.tr(),
      items: rooms,
      selectedItem: activeRoom,
      // onFind: (String filter) => getData(filter),
      itemAsString: (Room room) => room.description,
      onChanged: (Room room) => {
        if (room == null) {
          context.read<MainStore>().setActiveRoom(null)
        } else {
          context.read<MainStore>().setActiveRoom(room.description)
        }
      },
      dropdownSearchDecoration: InputDecoration(
        filled: true,
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.fromLTRB(12, 12, 8, 0),
        fillColor: Colors.transparent //Theme.of(context).inputDecorationTheme.fillColor,
      ),
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
