import PackageDescription

let package = Package(
    name: "Skelton",
    dependencies: [
        .Package(url: "https://github.com/noppoMan/Suv.git", majorVersion: 0, minor: 8),
        .Package(url: "https://github.com/Zewo/HTTPParser.git", majorVersion: 0, minor: 9),
        .Package(url: "https://github.com/Zewo/HTTP.git", majorVersion: 0, minor: 8)
    ]
)
