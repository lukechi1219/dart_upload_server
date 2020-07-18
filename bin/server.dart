import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_static/shelf_static.dart';
import 'package:shelf_router/shelf_router.dart';

import 'package:mime/mime.dart';

// For Google Cloud Run, set _hostname to '0.0.0.0'.
// const _hostname = 'localhost';
const _hostname = '192.168.5.122';
const fileStore = 'fileStore';
final staticHtmlFolder = 'static' + Platform.pathSeparator;

final staticHtmlHandler =
    createStaticHandler(staticHtmlFolder, defaultDocument: 'index.html');

/*
 *
 */
void main(List<String> args) async {
  //
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

  var router = setupRouter(staticHtmlHandler);

  var handler = const shelf.Pipeline()
      .addMiddleware(shelf.logRequests())
      .addHandler(router.handler);

  var server = await shelf_io.serve(handler, _hostname, port);

  print('Serving at http://${server.address.host}:${server.port}');
}

/*
 *
 */
Router setupRouter(shelf.Handler staticHtmlHandler) {
//
//  ..get('/hello', (shelf.Request request) {
//  return shelf.Response.ok('hello-world');
//  })
//  ..get('/user/<user>', (shelf.Request request, String user) {
//  return shelf.Response.ok('hello $user');
//  })
//
  return Router()
    // ..get('/', _echoRequest)
    // static
    ..get('/', staticHtmlHandler)
    ..get('/home/', staticHtmlHandler)
    ..get('/upload/', staticHtmlHandler)
    //
    ..get('/favicon.ico', staticHtmlHandler)
    // post
    ..post('/act/upload', handleActUpload);
}

/*
 *
 */
Future<shelf.Response> handleActUpload(shelf.Request request) async {
  //
//  print(request.headers);

  var contentType = HeaderValue.parse(request.headers['content-type']);
//  print(contentType);

  await for (MimeMultipart part in transformMultipart(request, contentType)) {
    //
    print(part.headers);

    if (part.headers.containsKey('content-disposition')) {
      //
      var contentDisposition =
          HeaderValue.parse(part.headers['content-disposition']);
      //
      print(contentDisposition);

      var filename = DateTime.now().microsecondsSinceEpoch.toString() +
          '_' +
          contentDisposition.parameters['filename'];

      await writeFile(filename, part);
    }
  }

  return shelf.Response.ok('Success',
      headers: {'Access-Control-Allow-Origin': '*'});
}

/*
 *
 */
Future writeFile(String filename, MimeMultipart part) async {
  final directory = Directory(fileStore);
  if (!await directory.exists()) {
    await directory.create();
  }
  final file = File(fileStore + Platform.pathSeparator + filename);
  var fileSink = file.openWrite();
  await part.pipe(fileSink);
  await fileSink.close();
}

/*
 *
 */
Stream<MimeMultipart> transformMultipart(
        shelf.Request request, HeaderValue contentType) =>
    request.read().transform(
        MimeMultipartTransformer(contentType.parameters['boundary']));

/*
 *
 */
shelf.Response _echoRequest(shelf.Request request) =>
    shelf.Response.ok('Request for "${request.url}"');
