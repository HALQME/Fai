// The Swift Programming Language
// https://docs.swift.org/swift-book
//
// Swift Argument Parser
// https://swiftpackageindex.com/apple/swift-argument-parser/documentation

import ArgumentParser

@main
struct Fai: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "fai",
        abstract: "Foundation Models Framework CLI - A command-line tool using Apple Intelligence",
        discussion: """
            Fai is a tool that allows you to use AI functions from the command line
            using the Apple Intelligence Foundation Models Framework.

            Examples:
              fai chat "Hello, how are you?"
              fai chat --stream "Please generate a long text"
              fai status --verbose
            """,
        version: "0.1.0",
        subcommands: [
            ChatCommand.self,
            GenerateCommand.self,
            StatusCommand.self,
        ],
        defaultSubcommand: StatusCommand.self
    )
}
