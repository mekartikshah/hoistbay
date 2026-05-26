void main() {
  // Simulate what the SDK does for deleteObject
  final bucket = 'my-bucket';
  final key = 'test folder/'; // A folder key with space
  
  final requestUri = '/${Uri.encodeComponent(bucket)}/${key.split('/').map(Uri.encodeComponent).join('/')}';
  print('requestUri: $requestUri');
  
  final endpointUrl = 'https://s3.ap-south-1.amazonaws.com';
  var uri = Uri.parse('$endpointUrl$requestUri');
  print('parsed uri.path: ${uri.path}');
  print('Uri.encodeFull(uri.path): ${Uri.encodeFull(uri.path)}');
  
  // Check if they match
  final fromSign = Uri.encodeFull(uri.path);
  print('Match: ${fromSign == requestUri}');
  
  // Now test with a simple key (no spaces)
  final key2 = 'testfolder/file.txt';
  final requestUri2 = '/${Uri.encodeComponent(bucket)}/${key2.split('/').map(Uri.encodeComponent).join('/')}';
  print('\nrequestUri2: $requestUri2');
  var uri2 = Uri.parse('$endpointUrl$requestUri2');
  print('parsed uri2.path: ${uri2.path}');
  print('Uri.encodeFull(uri2.path): ${Uri.encodeFull(uri2.path)}');
  print('Match2: ${Uri.encodeFull(uri2.path) == requestUri2}');
}
