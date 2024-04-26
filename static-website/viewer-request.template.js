function handler(event) {
  var request = event.request;
  var is_asset = (/\.[a-zA-Z0-9]{1,8}$/).test(request.uri);
  request.uri = is_asset ? request.uri : '/${root_object}';
  return request;
}
