part of flutter_parse_sdk;

class ParseFile extends ParseFileBase {
  /// Creates a new file
  ///
  /// {https://docs.parseplatform.org/rest/guide/#files/}
  ParseFile(this.file,
      {String name,
      String url,
      bool debug,
      ParseHTTPClient client,
      bool autoSendSessionId})
      : super(
          name: file != null ? path.basename(file.path) : name,
          url: url,
          debug: debug,
          client: client,
          autoSendSessionId: autoSendSessionId,
        );

  File file;

  Future<ParseFile> loadStorage() async {
    final Directory tempPath = await getTemporaryDirectory();

    if (name == null) {
      file = null;
      return this;
    }

    final File possibleFile = File('${tempPath.path}/$name');
    // ignore: avoid_slow_async_io
    final bool exists = await possibleFile.exists();

    if (exists) {
      file = possibleFile;
    } else {
      file = null;
    }

    return this;
  }

  @override
  Future<ParseFile> download() async {
    if (url == null) {
      return this;
    }

    final Directory tempPath = await getTemporaryDirectory();
    file = File('${tempPath.path}/$name');
    await file.create();
    final Response<List<int>> response = await _client.get<List<int>>(url, options: Options(responseType: ResponseType.bytes));
    await file.writeAsBytes(response.data);

    return this;
  }

  /// Uploads a file to Parse Server
  @override
  Future<ParseResponse> upload() async {
    if (saved) {
      //Creates a Fake Response to return the correct result
      final Map<String, String> response = <String, String>{
        'url': url,
        'name': name
      };
      return handleResponse<ParseFile>(
          this,
          Response<String>(data: json.encode(response), statusCode: 201),
          ParseApiRQ.upload,
          _debug,
          parseClassName);
    }

    final String ext = path.extension(file.path).replaceAll('.', '');
    final Map<String, String> headers = <String, String>{
      HttpHeaders.contentTypeHeader: getContentType(ext)
    };
    try {
      final String uri = _client.data.serverUrl + '$_path';
      final List<int> body = await file.readAsBytes();
      final Response<String> response = await _client.post<String>(uri,
          options: Options(headers: headers), data: body);
      if (response.statusCode == 201) {
        final Map<String, dynamic> map = json.decode(response.data);
        url = map['url'].toString();
        name = map['name'].toString();
      }
      return handleResponse<ParseFile>(
          this, response, ParseApiRQ.upload, _debug, parseClassName);
    } on Exception catch (e) {
      return handleException(e, ParseApiRQ.upload, _debug, parseClassName);
    }
  }
}
