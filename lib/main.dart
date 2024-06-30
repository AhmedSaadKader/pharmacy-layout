import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(PharmacyLayoutApp());
}

class PharmacyLayoutApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text('Pharmacy Layout'),
        ),
        body: PharmacyLayout(),
      ),
    );
  }
}

class PharmacyLayout extends StatefulWidget {
  @override
  _PharmacyLayoutState createState() => _PharmacyLayoutState();
}

class _PharmacyLayoutState extends State<PharmacyLayout> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<PharmacySection> sections = [];

  @override
  void initState() {
    super.initState();
    _loadSections();
  }

  void _loadSections() async {
    QuerySnapshot snapshot = await _firestore.collection('sections').get();
    setState(() {
      sections = snapshot.docs.map((doc) => PharmacySection.fromFirestore(doc)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Fixed elements
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 40,
            color: Colors.brown,
            child: Center(
              child: Text('Door', style: TextStyle(color: Colors.white)),
            ),
          ),
        ),
        // Other fixed elements (counter, desk, ladder, storage) ...

        // Draggable sections
        ...sections.map((section) => Positioned(
              left: section.position.dx,
              top: section.position.dy,
              child: Draggable<PharmacySection>(
                data: section,
                feedback: SectionWidget(section: section),
                childWhenDragging: Opacity(
                  opacity: 0.5,
                  child: SectionWidget(section: section),
                ),
                onDragEnd: (details) => _updateSectionPosition(section, details.offset),
                child: SectionWidget(
                  section: section,
                  onTap: () => _showProductList(context, section),
                ),
              ),
            )),
      ],
    );
  }

  void _updateSectionPosition(PharmacySection section, Offset newPosition) {
    setState(() {
      section.position = newPosition;
    });
    _firestore.collection('sections').doc(section.id).update({
      'position': {'x': newPosition.dx, 'y': newPosition.dy}
    });
  }

  void _showProductList(BuildContext context, PharmacySection section) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('${section.name} - ${section.type}'),
          content: StreamBuilder<DocumentSnapshot>(
            stream: _firestore.collection('sections').doc(section.id).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return CircularProgressIndicator();
              List<String> products = List<String>.from(snapshot.data!['products']);
              return SingleChildScrollView(
                child: ListBody(
                  children: products.map((product) => Text(product)).toList(),
                ),
              );
            },
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Add Product'),
              onPressed: () => _addProduct(context, section),
            ),
            TextButton(
              child: Text('Close'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  void _addProduct(BuildContext context, PharmacySection section) {
    TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Add Product to ${section.name}'),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(hintText: "Enter product name"),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Add'),
              onPressed: () {
                _firestore.collection('sections').doc(section.id).update({
                  'products': FieldValue.arrayUnion([controller.text])
                });
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}

class PharmacySection {
  final String id;
  final String name;
  final String type;
  Offset position;

  PharmacySection({required this.id, required this.name, required this.type, required this.position});

  factory PharmacySection.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map;
    return PharmacySection(
      id: doc.id,
      name: data['name'],
      type: data['type'],
      position: Offset(data['position']['x'], data['position']['y']),
    );
  }
}

class SectionWidget extends StatelessWidget {
  final PharmacySection section;
  final VoidCallback? onTap;

  const SectionWidget({Key? key, required this.section, this.onTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        height: 40,
        decoration: BoxDecoration(
          color: _getColor(section.type),
          border: Border.all(color: Colors.black),
        ),
        child: Center(
          child: Text(
            section.name,
            style: TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }

  Color _getColor(String type) {
    switch (type) {
      case 'Cosmetics':
        return Colors.pink;
      case 'Drugs':
        return Colors.blue;
      case 'Medical Supplies':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
