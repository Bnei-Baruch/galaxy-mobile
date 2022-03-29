
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
  final LoaderResultBuilder<T> resultBuilder;
  final LoadFunction load;
  // May be null.
  final LoaderController controller;
  final Widget loadingWidget;
  final bool loadOnInit;

  Loader({
    @required this.resultBuilder,
    @required this.load,
    this.controller,
    this.loadOnInit = true,
    this.loadingWidget = const Center(
      child: SizedBox(width: 30, height: 30, child: CircularProgressIndicator())
    )
  }) : assert(resultBuilder != null),
       assert(load != null),
       assert(loadOnInit != null),
       assert(loadingWidget != null);

  @override
  _LoaderState<T> createState() => _LoaderState<T>();
}

class _LoaderState<T> extends State<Loader<T>> {
  bool _isLoading = false;
  T _result;

  void runLoad() {
    if (_isLoading) {
      return;
    }
    setState(() {
      _isLoading = true;
    });
    widget.load().then((T result) {
      if (this.mounted) {
        setState(() {
          _isLoading = false;
          _result = result;
        });
      }
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
      ? widget.loadingWidget
      : widget.resultBuilder(context, _result);
  }
}
