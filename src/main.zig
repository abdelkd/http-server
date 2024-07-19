const std = @import("std");
const mem = std.mem;
const net = std.net;
const headers = @import("headers.zig");
const serve = @import("serve.zig");
const response = @import("response.zig");

const ArgParseError = error{
    InvalidArgumentStruct,
    InvalidName,
    InvalidValue,
};

const ServerArgs = struct {
    routes_dir: []const u8,
    port: u16,
};

fn parseArgs() !ServerArgs {
    var args = std.process.args();
    defer args.deinit();

    var server_args = ServerArgs{
        .routes_dir = "./routes",
        .port = 4321,
    };

    while (args.next()) |arg| {
        if (!mem.startsWith(u8, arg, "--")) {
            continue;
        }

        var arg_iter = std.mem.tokenizeSequence(u8, arg, "=");
        var arg_name = arg_iter.next() orelse return ArgParseError.InvalidName;
        arg_name = mem.trimLeft(u8, arg_name, "--");
        const arg_value = arg_iter.next() orelse return ArgParseError.InvalidName;

        if (mem.eql(u8, arg_name, "routes-dir")) {
            server_args.routes_dir = arg_value;
            continue;
        }

        if (mem.eql(u8, arg_name, "port")) {
            server_args.port = try std.fmt.parseInt(u16, arg_value, 10);
            continue;
        }
    }

    return server_args;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const server_args = try parseArgs();

    const self_addr = try net.Address.resolveIp("127.0.0.1", server_args.port);
    var server = try self_addr.listen(.{
        .reuse_address = true,
    });

    std.debug.print("Server is running, listening on port: {}, for roues: {s}\n", .{ server_args.port, server_args.routes_dir });

    while (server.accept()) |conn| {
        defer conn.stream.close();

        var recv_buf: [4096]u8 = undefined;
        var recv_total: usize = 0;

        while (conn.stream.read(recv_buf[recv_total..])) |recv_len| {
            if (recv_len == 0) break;

            recv_total += recv_len;
            if (mem.containsAtLeast(u8, recv_buf[0..recv_total], 1, "\r\n\r\n")) {
                break;
            }
        } else |recv_err| {
            return recv_err;
        }

        const http_headers = headers.parseRequest(&conn, &recv_buf) catch {
            std.debug.print("failed to parse request", .{});
            continue;
        };

        std.debug.print("{s} - {s}\n", .{ http_headers.method, http_headers.path });

        serve.route(conn, http_headers, server_args.routes_dir, allocator) catch {
            try response.http404(conn);
        };
    } else |accept_err| {
        return accept_err;
    }
}
