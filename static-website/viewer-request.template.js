function handler(event) {
  var request = event.request;
  var is_asset = (/\.[^\.]{2,}$/).test(request.uri);
  request.uri = is_asset ? request.uri : '/${root_object}';
  return request;
}
