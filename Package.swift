import PackageDescription

let package = Package(
	name: "SlimaneHTTP",
	dependencies: [
    .Package(url: "https://github.com/noppoMan/Suv.git", majorVersion: 0, minor: 1),
    .Package(url: "https://github.com/noppoMan/HTTPParser.git", majorVersion: 0, minor: 1),
    .Package(url: "https://github.com/Zewo/Core.git", majorVersion: 0, minor: 1),
    .Package(url: "https://github.com/Zewo/CURIParser.git", majorVersion: 0, minor: 1),
    .Package(url: "https://github.com/Zewo/CHTTPParser.git", majorVersion: 0, minor: 1),
  ]
)
