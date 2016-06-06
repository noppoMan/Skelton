import PackageDescription

let package = Package(
    name: "Skelton",
    dependencies: [
        .Package(url: "https://github.com/noppoMan/Suv.git", majorVersion: 0, minor: 6),
        .Package(url: "https://github.com/noppoMan/HTTPParser.git", majorVersion: 0, minor: 8),
        .Package(url: "https://github.com/noppoMan/HTTP.git", majorVersion: 0, minor: 7)
    ]
)
