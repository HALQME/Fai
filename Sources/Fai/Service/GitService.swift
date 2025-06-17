//
//  GitService.swift
//  Fai
//
//  Created by hal on 2025/06/17.
//

import Foundation
import Logging
import FoundationModels

/// A service class that provides Git repository operations and management functionality.
///
/// `GitService` encapsulates Git-related operations such as cloning repositories,
/// managing branches, committing changes, and other version control tasks.
/// This service acts as a wrapper around Git commands and provides a Swift-friendly
/// interface for interacting with Git repositories.
struct GitService {
    private let logger = Logger(label: "GitService")

    /// Retrieves the staged changes in the current Git repository.
    ///
    /// This method executes a Git command to fetch all changes that have been staged
    /// for the next commit. The staged changes represent files that have been added
    /// to the Git index using `git add`.
    ///
    /// - Returns: A string containing the staged changes output from Git
    /// - Throws: An error if the Git command fails or if there's an issue accessing the repository
    func getStagedChanges() async throws -> String {
        logger.info("Getting staged changes")
        return try await executeGitCommand(["diff", "--staged"])
    }

    /// Retrieves the version history for a specific file in the Git repository.
    ///
    /// This method fetches the commit history that affected the specified file, providing
    /// a chronological record of changes made to the file over time.
    ///
    /// - Parameter filePath: The relative path to the file within the repository for which
    ///   to retrieve the history. The path should be relative to the repository root.
    /// - Returns: A string containing the formatted file history, typically including
    ///   commit hashes, dates, authors, and commit messages for changes that affected the file.
    /// - Throws: An error if the file path is invalid, the file doesn't exist in the repository,
    ///   or if there's an issue accessing the Git repository or executing Git commands.
    ///
    /// - Note: The returned history format may vary depending on the Git command options used
    ///   internally. Common formats include one-line summaries or detailed commit information.
    func getFileHistory(filePath: String) async throws -> String {
        logger.info("Getting file history for: \(filePath)")
        return try await executeGitCommand(["log", "--follow", "--oneline", "-10", filePath])
    }

    /// Retrieves the commit history for the current repository.
    ///
    /// This method fetches a specified number of recent commits from the Git repository,
    /// providing a chronological history of changes.
    ///
    /// - Parameter count: The maximum number of commits to retrieve. Defaults to 20.
    /// - Returns: A string representation of the commit history.
    /// - Throws: An error if the Git operation fails or if the repository is not accessible.
    func getCommitHistory(count: Int = 20) async throws -> String {
        logger.info("Getting commit history")
        return try await executeGitCommand(["log", "--oneline", "-\(count)"])
    }

    /// Retrieves a list of files that are currently staged for commit in the Git repository.
    ///
    /// This method executes a Git command to fetch all files that have been added to the staging area
    /// and are ready to be committed. The staging area contains changes that will be included in the
    /// next commit operation.
    ///
    /// - Returns: An array of file paths representing the staged files. Each string contains the
    ///           relative path from the repository root to the staged file.
    /// - Throws: An error if the Git operation fails, such as when not in a Git repository,
    ///          Git is not installed, or there are permission issues accessing the repository.
    ///
    /// - Note: This is an asynchronous operation that may take time depending on the repository size
    ///         and the number of staged files.
    func getStagedFiles() async throws -> [String] {
        logger.info("Getting staged files")
        let output = try await executeGitCommand(["diff", "--staged", "--name-only"])
        return output.components(separatedBy: .newlines).filter { !$0.isEmpty }
    }

    /// Retrieves the name of the currently active Git branch.
    ///
    /// This method executes a Git command to determine which branch is currently
    /// checked out in the repository.
    ///
    /// - Returns: A string containing the name of the current Git branch
    /// - Throws: An error if the Git command fails or if the current directory
    ///   is not a valid Git repository
    func getCurrentBranch() async throws -> String {
        logger.info("Getting current branch")
        return try await executeGitCommand(["branch", "--show-current"])
    }

    /// Checks if the current directory is a Git repository.
    ///
    /// This method asynchronously determines whether the current working directory
    /// contains a valid Git repository by checking for the presence of Git metadata.
    ///
    /// - Returns: `true` if the current directory is a Git repository, `false` otherwise.
    /// - Note: This method performs asynchronous operations and should be called with `await`.
    func isGitRepository() async -> Bool {
        do {
            _ = try await executeGitCommand(["rev-parse", "--git-dir"])
            return true
        } catch {
            logger.warning("Not a git repository")
            return false
        }
    }

    /// Executes a Git command with the specified arguments asynchronously.
    ///
    /// This method runs a Git command using the provided arguments and returns the output as a string.
    /// The execution is performed asynchronously to avoid blocking the calling thread.
    ///
    /// - Parameter arguments: An array of strings representing the Git command arguments to execute.
    /// - Returns: A string containing the output from the executed Git command.
    /// - Throws: An error if the Git command execution fails or returns a non-zero exit code.
    private func executeGitCommand(_ arguments: [String]) async throws -> String {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output =
                String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                ?? ""

            if process.terminationStatus != 0 {
                throw GitError.commandFailed(arguments.joined(separator: " "), output)
            }

            return output
        } catch {
            logger.error("Git command failed: \(arguments.joined(separator: " "))")
            throw GitError.executionError(error)
        }
    }

    /// Retrieves a list of unstaged changes in the Git repository.
    ///
    /// This method asynchronously fetches all files that have been modified, added, or deleted
    /// but are not yet staged for commit in the current Git working directory.
    ///
    /// - Returns: A string containing the unstaged changes, typically in a format similar to
    ///           `git status --porcelain` output showing modified, added, and deleted files.
    /// - Throws: An error if the Git operation fails, such as when not in a Git repository
    ///          or if there are issues accessing the repository state.
    func getUnstagedChanges() async throws -> String {
        return try await executeGitCommand(["diff"])
    }

    /// Retrieves the current status of the Git repository.
    ///
    /// This method asynchronously fetches the status of the Git repository, providing information
    /// about the current state of the working directory and staging area.
    ///
    /// - Returns: A string representation of the repository status, including information about
    ///   modified files, staged changes, untracked files, and current branch state.
    /// - Throws: An error if the Git status operation fails, such as when the current directory
    ///   is not a Git repository or if there are issues accessing the repository.
    func getRepoStatus() async throws -> String {
        return try await executeGitCommand(["status", "--porcelain"])
    }

    /// Retrieves a list of all available branches from the Git repository.
    ///
    /// This method asynchronously fetches the names of all branches in the current Git repository,
    /// including both local and remote branches.
    ///
    /// - Returns: An array of strings containing the names of all branches in the repository.
    /// - Throws: An error if the Git operation fails or if the repository is not accessible.
    func getBranchList() async throws -> [String] {
        let output = try await executeGitCommand(["branch", "-a"])
        return output.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

enum GitError: Error, LocalizedError {
    case commandFailed(String, String)
    case executionError(Error)
    case notARepository
    case noStagedChanges

    var errorDescription: String? {
        switch self {
        case .commandFailed(let command, let output):
            return "Fail to execute Git command:\(command),\noutput:\(output)"
        case .executionError(let error):
            return "Catch Git execution error: \(error.localizedDescription)"
        case .notARepository:
            return "Not on a Git repository"
        case .noStagedChanges:
            return "No staged changes"
        }
    }
}

@Generable
struct CommitMessage{
    @Guide(description: "commit type of changes")
    var commitType: CommitType
    @Guide(description: "short abstract of git commit message. up to 50 characters.")
    var message: String
    @Guide(description: "details of git commit message. up to 250 characters.")
    var description: String
}

@Generable
enum CommitType {
    case fix,hotfix,add,update,change,clean,disable,remove,upgrade,revert

    var description: String {
        switch self {
            case .fix:
                return "bug fix"
            case .hotfix:
                return "critical bug hotfix"
            case .add:
                return "add new feature/file"
            case .update:
                return "update function"
            case .change:
                return "change function"
            case .clean:
                return "clean code"
            case .disable:
                return "disable feature"
            case .remove:
                return "remove feature"
            case .upgrade:
                return "upgrade library"
            case .revert:
                return "revert changes"
        }
    }
}
