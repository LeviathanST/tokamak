const client = @import("ai/client.zig");
const agent = @import("ai/agent.zig");
const format = @import("ai/fmt.zig");

// Data types
pub const chat = @import("ai/chat.zig");
pub const embedding = @import("ai/embedding.zig");

// Client
pub const ClientConfig = client.Config;
pub const Client = client.Client;

// Agentic extension
pub const AgentOptions = agent.AgentOptions;
pub const Agent = agent.Agent;
pub const AgentRuntime = agent.AgentRuntime;
pub const AgentToolbox = agent.AgentToolbox;

// Utils
pub const stringify = format.stringify;
pub const stringifyAlloc = format.stringifyAlloc;
pub const Formatter = format.Formatter;
pub const fmt = format.fmt;
