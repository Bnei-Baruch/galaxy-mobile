
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

typedef LoaderResultBuilder<T> = Widget Function(BuildContext context, T result);
typedef LoadFunction<T> = T Function();

class LoaderController extends ChangeNotifier {
  void reload() {
    notifyListeners();
  }
}

class Loader<T> extends StatefulWidget {
  final LoaderResultBuilder resultBuilder;
  final LoadFunction load;
  // May be null.
  final LoaderController controller;
  final Widget loaderWidget;
  final bool loadOnInit;

  Loader({
    @required this.resultBuilder,
    @required this.load,
    this.controller,
    this.loadOnInit = false,
    this.loaderWidget = const Center(
      child: SizedBox(width: 30, height: 30, child: CircularProgressIndicator())
    )
  }) : assert(resultBuilder != null),
       assert(load != null),
       assert(loadOnInit != null),
       assert(loaderWidget != null);

  @override
  _LoaderState<T> createState() => _LoaderState<T>();
}

class _LoaderState<T> extends State<Loader<T>> {
  bool _isLoading;
  T _result;

  void runLoad() {
    if (_isLoading) {
      return;
    }
    setState(() {
      _isLoading = true;
    });
    widget.load().then((T result) {
      setState(() {
        _isLoading = false;
        _result = result;
      });
    });
  }

  @override
  void initState() {
    super.initState();
    if (widget.loadOnInit) {
      runLoad();
    }
    widget.controller?.addListener(runLoad);
  }

  @override
  void dispose() {
    widget.controller?.removeListener(runLoad);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
      ? widget.loaderWidget
      : widget.resultBuilder(context, _result);
  }
}