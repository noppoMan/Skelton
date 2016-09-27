import PackageDescription

let package = Package(
    name: "Skelton",
    targets: [
        Target(name: "Performance", dependencies: ["Skelton"]),
        Target(name: "Skelton")
    ],
    dependencies: [
        .Package(url: "https://github.com/noppoMan/Suv.git", majorVersion: 0, minor: 13),
        .Package(url: "https://github.com/slimane-swift/HTTPCore.git", majorVersion: 0, minor: 1)
    ]
)
