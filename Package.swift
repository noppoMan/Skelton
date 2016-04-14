import PackageDescription

let package = Package(
    name: "SlimaneHTTPServer",
    dependencies: [
        .Package(url: "https://github.com/noppoMan/Suv.git", majorVersion: 0, minor: 2),
        .Package(url: "https://github.com/Zewo/HTTPParser.git", majorVersion: 0, minor: 4),
        .Package(url: "https://github.com/noppoMan/HTTP.git", majorVersion: 0, minor: 4),
    ]
)
