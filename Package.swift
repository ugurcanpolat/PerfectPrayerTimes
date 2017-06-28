// swift-tools-version:3.1

import PackageDescription

let package = Package(
    name: "perfect-namazvakitleri" ,
    dependencies: [
        .Package(url: "https://github.com/PerfectlySoft/Perfect-HTTPServer.git", majorVersion: 2),
        .Package(url: "https://github.com/tid-kijyun/Kanna.git", majorVersion: 2)
     ],
    exclude: ["Resources"]
)
