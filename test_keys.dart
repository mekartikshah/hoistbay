void main() {
  var key = "test folder/file.txt";
  print(Uri(path: '/bucket/${key.split('/').map(Uri.encodeComponent).join('/')}').path);
}
