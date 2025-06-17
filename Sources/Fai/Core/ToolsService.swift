//
//  ToolsService.swift
//  Fai
//
//  Created by hal on 2025/06/17.
//

import FoundationModels

struct ToolsService {
    let aiTools = Extensions(tools: [])

    func searchTool(named name: String) -> [any Tool] {
        return self.aiTools.tools.filter { $0.name == name }.map { $0.tool }
    }

    func listTools() -> [String] {
        return self.aiTools.tools.map { $0.name }.sorted()
    }

    func getTools() -> [any Tool] {
        return self.aiTools.tools.map { $0.tool }
    }
}

// ツール一覧の型
struct Extensions {
    let tools: [Extension]
}

struct Extension {
    let tool: any Tool
    let name: String
    let description: String
    let parameters: GenerationSchema

    init(tool: any Tool) {
        self.tool = tool
        self.name = tool.name
        self.description = tool.description
        self.parameters = tool.parameters
    }
}
