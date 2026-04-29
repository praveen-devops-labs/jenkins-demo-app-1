const http = require('http');

http.createServer((req, res) => {
  res.end("Hello from App1");
}).listen(3000);
