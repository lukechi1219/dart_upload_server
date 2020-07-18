import 'dart:io';

import 'package:args/args.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_static/shelf_static.dart';
import 'package:shelf_router/shelf_router.dart';

// For Google Cloud Run, set _hostname to '0.0.0.0'.
const _hostname = 'localhost';

void main(List<String> args) async {
  var parser = ArgParser()..addOption('port', abbr: 'p');
  var result = parser.parse(args);

  // For Google Cloud Run, we respect the PORT environment variable
  var portStr = result['port'] ?? Platform.environment['PORT'] ?? '8080';
  var port = int.tryParse(portStr);

  if (port == null) {
    stdout.writeln('Could not parse port value "$portStr" into a number.');
    // 64: command line usage error
    exitCode = 64;
    return;
  }

  var staticHtmlFolder = 'static' + Platform.pathSeparator;
  var staticHtmlHandler =
      createStaticHandler(staticHtmlFolder, defaultDocument: 'index.html');

  var router = Router()
    ..get('/hello', (shelf.Request request) {
      return shelf.Response.ok('hello-world');
    })
    ..get('/user/<user>', (shelf.Request request, String user) {
      return shelf.Response.ok('hello $user');
    })
    ..get('/home/', staticHtmlHandler)
    ..get('/', _echoRequest);

  var handler = const shelf.Pipeline()
      .addMiddleware(shelf.logRequests())
      .addHandler(router.handler);

  var server = await shelf_io.serve(handler, _hostname, port);
  print('Serving at http://${server.address.host}:${server.port}');
}

shelf.Response _echoRequest(shelf.Request request) =>
    shelf.Response.ok('Request for "${request.url}"');
