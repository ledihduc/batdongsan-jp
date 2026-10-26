const http = require("http");
const fs = require("fs");
const path = require("path");

const root = path.join(__dirname, "build", "web");
const port = Number(process.env.PORT || 5000);

const types = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".json": "application/json",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".svg": "image/svg+xml",
  ".wasm": "application/wasm",
};

http
  .createServer((req, res) => {
    const urlPath = decodeURIComponent(new URL(req.url, "http://localhost").pathname);
    let file = path.join(root, urlPath === "/" ? "index.html" : urlPath);

    if (!file.startsWith(root)) {
      res.writeHead(403);
      res.end("Forbidden");
      return;
    }

    fs.stat(file, (statErr, stat) => {
      if (statErr || !stat.isFile()) {
        file = path.join(root, "index.html");
      }

      fs.readFile(file, (readErr, data) => {
        if (readErr) {
          res.writeHead(404);
          res.end("Not found");
          return;
        }

        res.writeHead(200, {
          "Content-Type": types[path.extname(file)] || "application/octet-stream",
        });
        res.end(data);
      });
    });
  })
  .listen(port, "127.0.0.1");
