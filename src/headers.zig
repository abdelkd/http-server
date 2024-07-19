const std = @import("std");
const mem = std.mem;
const Connection = std.net.Server.Connection;
const headers = @import("headers.zig");

pub const HTTPHeaders = struct {
    request_line: []const u8,
    method: []const u8,
    path: []const u8,
    protocol_version: []const u8,
};

pub const Header = struct {
    name: []const u8,
    value: []const u8,
};

const ParseRequestError = error{
    InvalidRequestLine,
};

pub const ServerErrors = error{
    NotFound,
    InternalServerError,
};

pub fn parseRequest(conn: *const Connection, recv_buf: []u8) ParseRequestError!headers.HTTPHeaders {
    var http_headers = HTTPHeaders{
        .path = undefined,
        .method = undefined,
        .request_line = undefined,
        .protocol_version = undefined,
    };

    var headers_iter = std.mem.tokenizeSequence(u8, recv_buf, "\r\n");
    http_headers.request_line = headers_iter.next() orelse return ParseRequestError.InvalidRequestLine;

    var request_line_iter = mem.tokenizeSequence(u8, http_headers.request_line, " ");
    http_headers.method = request_line_iter.next() orelse return ParseRequestError.InvalidRequestLine;
    http_headers.path = request_line_iter.next() orelse return ParseRequestError.InvalidRequestLine;
    http_headers.protocol_version = request_line_iter.next() orelse return ParseRequestError.InvalidRequestLine;

    _ = conn;

    return http_headers;
}
