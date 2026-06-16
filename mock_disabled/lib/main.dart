import 'package:flutter/material.dart';
import 'dart:io';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OSK Mock A (Disabled)',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      home: const TestDashboardPage(),
    );
  }
}

class TestDashboardPage extends StatefulWidget {
  const TestDashboardPage({super.key});

  @override
  State<TestDashboardPage> createState() => _TestDashboardPageState();
}

class _TestDashboardPageState extends State<TestDashboardPage> {
  final List<String> _logs = [];
  final ScrollController _scrollController = ScrollController();
  final FocusNode _textFieldFocusNode = FocusNode();
  String _dropdownValue = 'Option 1';
  double _zoomScale = 1.0;
  Offset _zoomOffset = Offset.zero;

  @override
  void initState() {
    super.initState();
    _textFieldFocusNode.addListener(_handleTextFieldFocusChange);
    _log('App Started: OSK Guard DISABLED (Standard Flutter)');
  }

  @override
  void dispose() {
    _textFieldFocusNode.removeListener(_handleTextFieldFocusChange);
    _textFieldFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _log(String message) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    final logLine = '[$timestamp] $message';
    print(logLine); // Output to standard output (captured in terminal)
    setState(() {
      _logs.add(logLine);
      if (_logs.length > 200) {
        _logs.removeAt(0);
      }
    });
    // Scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  void _handleTextFieldFocusChange() {
    _log('FOCUS CHANGE: TextField hasFocus = ${_textFieldFocusNode.hasFocus}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OSK Mock A (Disabled / Standard Flutter)'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Listener(
        onPointerDown: (event) {
          _log('RAW POINTER DOWN: id=${event.pointer}, kind=${event.kind.name}, pos=${event.position}');
        },
        onPointerUp: (event) {
          _log('RAW POINTER UP: id=${event.pointer}, kind=${event.kind.name}, pos=${event.position}');
        },
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              Expanded(
                flex: 3,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Left panel: Widgets
                    Expanded(
                      flex: 1,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('1. Test Controls', style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 10),
                              TextField(
                                focusNode: _textFieldFocusNode,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  labelText: 'Enter text here',
                                  hintText: 'Tap to trigger OSK',
                                ),
                              ),
                              const SizedBox(height: 10),
                              DropdownButtonFormField<String>(
                                value: _dropdownValue,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  labelText: 'Select Option',
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'Option 1', child: Text('Option 1')),
                                  DropdownMenuItem(value: 'Option 2', child: Text('Option 2')),
                                  DropdownMenuItem(value: 'Option 3', child: Text('Option 3')),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _dropdownValue = val;
                                    });
                                    _log('DROPDOWN CHANGE: Selected $val');
                                  }
                                },
                              ),
                              const SizedBox(height: 15),
                              ElevatedButton(
                                onPressed: () {
                                  _log('BUTTON PRESS: Action Button clicked');
                                },
                                child: const Text('Action Button'),
                              ),
                              const SizedBox(height: 10),
                              ElevatedButton(
                                onPressed: () {
                                  _textFieldFocusNode.unfocus();
                                  _log('BUTTON PRESS: Force Unfocus clicked');
                                },
                                child: const Text('Force Unfocus'),
                              ),
                              const SizedBox(height: 10),
                              ElevatedButton(
                                onPressed: () {
                                  _log('BUTTON PRESS: Navigate to Page 2');
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const SecondPage()),
                                  );
                                },
                                child: const Text('Navigate to Page 2'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Right panel: Zoom Area
                    Expanded(
                      flex: 1,
                      child: Card(
                        color: Colors.blueGrey.shade900,
                        child: ClipRect(
                          child: GestureDetector(
                            onScaleStart: (details) {
                              _log('SCALE START: pointers=${details.pointerCount}, focalPoint=${details.focalPoint}');
                            },
                            onScaleUpdate: (details) {
                              setState(() {
                                _zoomScale = details.scale;
                              });
                              _log('SCALE UPDATE: scale=${details.scale.toStringAsFixed(2)}, rotation=${details.rotation.toStringAsFixed(2)}');
                            },
                            onScaleEnd: (details) {
                              _log('SCALE END');
                            },
                            child: Container(
                              alignment: Alignment.center,
                              color: Colors.transparent,
                              child: Transform.scale(
                                scale: _zoomScale,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.zoom_out_map, size: 48, color: Colors.blue),
                                    const SizedBox(height: 10),
                                    Text('Multi-touch Zoom Area', style: Theme.of(context).textTheme.titleSmall),
                                    Text('Pinch or pan here', style: TextStyle(color: Colors.grey.shade400)),
                                    const SizedBox(height: 5),
                                    Text('Current Scale: ${_zoomScale.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Bottom panel: Logs console
              Expanded(
                flex: 2,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('2. Live Logs (Captured)', style: Theme.of(context).textTheme.titleMedium),
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _logs.clear();
                                });
                              },
                              child: const Text('Clear'),
                            )
                          ],
                        ),
                        const Divider(),
                        Expanded(
                          child: ListView.builder(
                            controller: _scrollController,
                            itemCount: _logs.length,
                            itemBuilder: (context, index) {
                              return Text(
                                _logs[index],
                                style: const TextStyle(fontFamily: 'Courier', fontSize: 12),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SecondPage extends StatelessWidget {
  const SecondPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Second Page (Navigation Test)'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.info_outline, size: 64, color: Colors.deepPurple),
            const SizedBox(height: 20),
            Text(
              'This is the Second Page!',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32.0),
              child: TextField(
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'TextField on Page 2',
                  hintText: 'Tap to edit on Page 2',
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
}
