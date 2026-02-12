// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:walletwatch/services/expense_database.dart';

// class ShoppingListPage extends StatefulWidget {
//   const ShoppingListPage({super.key});

//   @override
//   State<ShoppingListPage> createState() => _ShoppingListPageState();
// }

// class _ShoppingListPageState extends State<ShoppingListPage> {
//   final _shopController = TextEditingController();
//   final _itemNameController = TextEditingController();
//   final _qtyController = TextEditingController(text: "1");

//   String _selectedUnit = "pcs";
//   final List<String> _units = ['pcs', 'kg', 'g', 'L', 'ml'];

//   /// item structure:
//   /// { name, qty, unit, checked, amount }
//   final List<Map<String, dynamic>> _items = [];

//   // ---------------- INIT ----------------
//   @override
//   void initState() {
//     super.initState();
//     _loadShoppingList();
//   }

//   // ---------------- LOAD FROM DB ----------------
//   Future<void> _loadShoppingList() async {
//     final data = await DatabaseHelper.instance.getActiveShoppingList();
//     if (data == null) return;

//     setState(() {
//       _shopController.text = data['shop'] ?? '';
//       _items
//         ..clear()
//         ..addAll(List<Map<String, dynamic>>.from(jsonDecode(data['items'])));
//     });
//   }

//   // ---------------- SAVE TO DB ----------------
//   Future<void> _saveShoppingList() async {
//     await DatabaseHelper.instance.insertShoppingList({
//       'uuid': 'ACTIVE_LIST',
//       'shop': _shopController.text.trim(),
//       'items': jsonEncode(_items),
//       'created_at': DateTime.now().toIso8601String(),
//     });
//   }

//   // ---------------- ADD ITEM ----------------
//   void _addItem() {
//     final name = _itemNameController.text.trim();
//     if (name.isEmpty) return;

//     final qty = _qtyController.text.trim().isEmpty ? "1" : _qtyController.text;

//     setState(() {
//       _items.add({
//         "name": name,
//         "qty": qty,
//         "unit": _selectedUnit,
//         "checked": false,
//         "amount": null,
//       });
//     });

//     _itemNameController.clear();
//     _qtyController.text = "1";
//     _saveShoppingList();
//   }

//   // ---------------- EDIT AMOUNT ----------------
//   Future<void> _editAmount(int index) async {
//     final controller = TextEditingController(
//       text: _items[index]["amount"]?.toString() ?? "",
//     );

//     final result = await showDialog<double>(
//       context: context,
//       builder: (_) => AlertDialog(
//         title: const Text("Enter Amount"),
//         content: TextField(
//           controller: controller,
//           keyboardType: const TextInputType.numberWithOptions(decimal: true),
//           decoration: const InputDecoration(prefixText: "₹ "),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text("Cancel"),
//           ),
//           ElevatedButton(
//             onPressed: () {
//               final value = double.tryParse(controller.text);
//               Navigator.pop(context, value);
//             },
//             child: const Text("Save"),
//           ),
//         ],
//       ),
//     );

//     if (result != null) {
//       setState(() {
//         _items[index]["amount"] = result;
//       });
//       _saveShoppingList();
//     }
//   }

//   //---------------------EDIT ITEM-----------------
//   Future<void> _editItem(int index) async {
//     final item = _items[index];

//     final nameController = TextEditingController(text: item["name"]);
//     final qtyController = TextEditingController(
//       text: item["qty"]?.toString() ?? "1",
//     );
//     String unit = item["unit"] ?? "pcs";

//     final result = await showDialog<bool>(
//       context: context,
//       builder: (_) => AlertDialog(
//         title: const Text("Edit Item"),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             TextField(
//               controller: nameController,
//               decoration: const InputDecoration(labelText: "Item name"),
//             ),
//             const SizedBox(height: 8),
//             TextField(
//               controller: qtyController,
//               keyboardType: TextInputType.number,
//               decoration: const InputDecoration(labelText: "Quantity"),
//             ),
//             const SizedBox(height: 8),
//             DropdownButtonFormField<String>(
//               value: unit,
//               items: _units
//                   .map((u) => DropdownMenuItem(value: u, child: Text(u)))
//                   .toList(),
//               onChanged: (v) => unit = v!,
//               decoration: const InputDecoration(labelText: "Unit"),
//             ),
//           ],
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context, false),
//             child: const Text("Cancel"),
//           ),
//           ElevatedButton(
//             onPressed: () => Navigator.pop(context, true),
//             child: const Text("Save"),
//           ),
//         ],
//       ),
//     );

//     if (result == true) {
//       setState(() {
//         item["name"] = nameController.text.trim();
//         item["qty"] = qtyController.text.trim().isEmpty
//             ? "1"
//             : qtyController.text.trim();
//         item["unit"] = unit;
//       });
//     }
//   }

//   //----------------------DELETE ITEM---------------
//   Future<void> _deleteItem(int index) async {
//     final confirm = await showDialog<bool>(
//       context: context,
//       builder: (_) => AlertDialog(
//         title: const Text("Delete Item"),
//         content: const Text("Are you sure you want to remove this item?"),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context, false),
//             child: const Text("Cancel"),
//           ),
//           ElevatedButton(
//             style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
//             onPressed: () => Navigator.pop(context, true),
//             child: const Text("Delete"),
//           ),
//         ],
//       ),
//     );

//     if (confirm == true) {
//       setState(() {
//         _items.removeAt(index);
//       });

//       if (_items.isEmpty) {
//         await DatabaseHelper.instance.clearShoppingList();
//         if (mounted) Navigator.pop(context, true);
//       }
//     }
//   }

//   // ---------------- UI ----------------
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("Shopping List"),
//         backgroundColor: Colors.blue,
//         foregroundColor: Colors.white,
//       ),
//       body: Column(
//         children: [
//           // ---------------- SHOP NAME ----------------
//           Padding(
//             padding: const EdgeInsets.all(16),
//             child: TextField(
//               controller: _shopController,
//               onChanged: (_) => _saveShoppingList(),
//               decoration: const InputDecoration(
//                 labelText: "Shop Name (optional)",
//                 prefixIcon: Icon(Icons.store),
//                 border: OutlineInputBorder(),
//               ),
//             ),
//           ),

//           // ---------------- ITEMS LIST ----------------
//           Expanded(
//             child: _items.isEmpty
//                 ? const Center(
//                     child: Text(
//                       "No items added yet",
//                       style: TextStyle(color: Colors.grey),
//                     ),
//                   )
//                 : ListView.builder(
//                     itemCount: _items.length,
//                     itemBuilder: (_, index) {
//                       final item = _items[index];
//                       final isChecked = item["checked"] == true;

//                       return Card(
//                         margin: const EdgeInsets.symmetric(
//                           horizontal: 16,
//                           vertical: 6,
//                         ),
//                         child: Padding(
//                           padding: const EdgeInsets.all(12),
//                           child: Row(
//                             children: [
//                               Checkbox(
//                                 value: isChecked,
//                                 activeColor: Colors.green,
//                                 onChanged: (val) {
//                                   setState(() {
//                                     item["checked"] = val;
//                                   });
//                                   _saveShoppingList();
//                                 },
//                               ),
//                               Expanded(
//                                 child: Column(
//                                   crossAxisAlignment: CrossAxisAlignment.start,
//                                   children: [
//                                     Text(
//                                       item["name"],
//                                       style: TextStyle(
//                                         fontWeight: FontWeight.w600,
//                                         decoration: isChecked
//                                             ? TextDecoration.lineThrough
//                                             : null,
//                                       ),
//                                     ),
//                                     Text(
//                                       "${item["qty"]} ${item["unit"]}",
//                                       style: const TextStyle(
//                                         fontSize: 12,
//                                         color: Colors.grey,
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                               ),
//                               Row(
//                                 children: [
//                                   // Amount (optional)
//                                   GestureDetector(
//                                     onTap: () => _editAmount(index),
//                                     child: Container(
//                                       padding: const EdgeInsets.symmetric(
//                                         horizontal: 10,
//                                         vertical: 6,
//                                       ),
//                                       decoration: BoxDecoration(
//                                         color: item["amount"] == null
//                                             ? Colors.grey.shade200
//                                             : Colors.green.shade100,
//                                         borderRadius: BorderRadius.circular(12),
//                                       ),
//                                       child: Text(
//                                         item["amount"] == null
//                                             ? "Add amount"
//                                             : "₹${item["amount"]}",
//                                         style: TextStyle(
//                                           fontSize: 13,
//                                           fontWeight: FontWeight.w600,
//                                           color: item["amount"] == null
//                                               ? Colors.black54
//                                               : Colors.green.shade800,
//                                         ),
//                                       ),
//                                     ),
//                                   ),

//                                   const SizedBox(width: 8),

//                                   // Edit
//                                   IconButton(
//                                     icon: const Icon(Icons.edit, size: 20),
//                                     color: Colors.blueGrey,
//                                     onPressed: () => _editItem(index),
//                                   ),

//                                   // Delete
//                                   IconButton(
//                                     icon: const Icon(
//                                       Icons.delete_outline,
//                                       size: 20,
//                                     ),
//                                     color: Colors.redAccent,
//                                     onPressed: () => _deleteItem(index),
//                                   ),
//                                 ],
//                               ),
//                             ],
//                           ),
//                         ),
//                       );
//                     },
//                   ),
//           ),

//           // ---------------- ADD ITEM INPUT ----------------
//           Padding(
//             padding: const EdgeInsets.all(16),
//             child: Column(
//               children: [
//                 Row(
//                   children: [
//                     Expanded(
//                       flex: 3,
//                       child: TextField(
//                         controller: _itemNameController,
//                         decoration: const InputDecoration(
//                           hintText: "Item name",
//                           border: OutlineInputBorder(),
//                         ),
//                       ),
//                     ),
//                     const SizedBox(width: 8),
//                     Expanded(
//                       flex: 2,
//                       child: TextField(
//                         controller: _qtyController,
//                         keyboardType: TextInputType.number,
//                         decoration: const InputDecoration(
//                           hintText: "Qty",
//                           border: OutlineInputBorder(),
//                         ),
//                       ),
//                     ),
//                     const SizedBox(width: 8),
//                     Expanded(
//                       flex: 2,
//                       child: DropdownButtonFormField<String>(
//                         value: _selectedUnit,
//                         items: _units
//                             .map(
//                               (u) => DropdownMenuItem(value: u, child: Text(u)),
//                             )
//                             .toList(),
//                         onChanged: (v) {
//                           setState(() => _selectedUnit = v!);
//                         },
//                         decoration: const InputDecoration(
//                           border: OutlineInputBorder(),
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//                 const SizedBox(height: 10),
//                 SizedBox(
//                   width: double.infinity,
//                   height: 46,
//                   child: OutlinedButton.icon(
//                     onPressed: _addItem,
//                     icon: const Icon(Icons.add),
//                     label: const Text("Add Item"),
//                   ),
//                 ),
//               ],
//             ),
//           ),

//           // ---------------- ADD TO EXPENSE ----------------
//           SafeArea(
//             child: Padding(
//               padding: const EdgeInsets.all(16),
//               child: SizedBox(
//                 width: double.infinity,
//                 height: 52,
//                 child: ElevatedButton(
//                   onPressed: _items.isEmpty
//                       ? null
//                       : () async {
//                           final result = await Navigator.pushNamed(
//                             context,
//                             '/add_expense',
//                             arguments: {
//                               "source": "shopping_list",
//                               "shop": _shopController.text.trim(),
//                               "items": _items,
//                             },
//                           );

//                           if (result == true) {
//                             Navigator.pop(context);
//                           }
//                         },
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.blue,
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(30),
//                     ),
//                   ),
//                   child: const Text(
//                     "Add to Expense",
//                     style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//                   ),
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   @override
//   void dispose() {
//     _shopController.dispose();
//     _itemNameController.dispose();
//     _qtyController.dispose();
//     super.dispose();
//   }
// }
